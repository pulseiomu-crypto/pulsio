// Layer 1 of report moderation (SPEC §11): a Claude vision check before anything goes live.
// Called by the app right after submit_report(). Runs with the submitter's JWT (must own the report) and
// records the verdict through record_model_verdict() with the service role. Without ANTHROPIC_API_KEY the
// report is HELD for the operator queue — never published by default.
//
// The photo has already been face/text-blurred on the device; the model only ever sees the blurred copy.
// Deployed as `moderate-report` (verify_jwt on). Secret to set in the dashboard: ANTHROPIC_API_KEY.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const MODEL = "claude-sonnet-5";
const CATEGORIES: Record<string, string> = {
  power_cut: "a power cut (dark streets, CEB crews, downed lines, dead traffic lights)",
  water_cut: "a water supply cut (dry taps, tankers, CWA works)",
  accident: "a road accident",
  hazard: "a hazard (fallen tree, debris, open drain, landslip)",
  flood: "flooding (water over a road or property)",
  traffic: "heavy traffic or a road closure",
  jellyfish: "jellyfish or a beach/sea hazard",
  event: "a public event (gathering, market, festival)",
  infrastructure: "broken infrastructure (pothole, streetlight, signage, pavement)",
  other: "some other local incident",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";

  // Who is asking — must be the report's author.
  const asUser = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData } = await asUser.auth.getUser();
  const user = userData?.user;
  if (!user) return json({ error: "unauthorized" }, 401);

  let reportId: number;
  try {
    const body = await req.json();
    reportId = Number(body.report_id);
    if (!Number.isFinite(reportId)) throw new Error();
  } catch {
    return json({ error: "report_id required" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey);
  const { data: report, error } = await admin.from("pulsio_reports").select("*").eq("id", reportId).single();
  if (error || !report || report.user_id !== user.id) return json({ error: "not found" }, 404);
  if (report.status !== "pending") return json({ status: report.status, note: "already decided" });

  const record = async (model: string, result: unknown, pass: boolean, reason: string) => {
    const { error: rpcError } = await admin.rpc("record_model_verdict", {
      p_report_id: reportId, p_model: model, p_result: result, p_pass: pass, p_reason: reason,
    });
    if (rpcError) console.error("record_model_verdict", rpcError);
  };

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    await record("unavailable", null, false, "ANTHROPIC_API_KEY not configured — held for operator review");
    return json({ status: "pending", verdict: "unavailable" });
  }

  // Fetch the (already blurred) photo.
  const photoUrl = `${supabaseUrl}/storage/v1/object/public/report-photos/${report.image_path}`;
  const photo = await fetch(photoUrl);
  if (!photo.ok) {
    await record("unavailable", { photo_status: photo.status }, false, "photo unreadable — held");
    return json({ status: "pending", verdict: "unavailable" });
  }
  const bytes = new Uint8Array(await photo.arrayBuffer());
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  const data = btoa(binary);

  const category = String(report.category);
  const prompt =
    `A member of the public in Mauritius submitted this photo as a community incident report.\n` +
    `Claimed category: "${category}" — ${CATEGORIES[category] ?? "a local incident"}.\n` +
    `Their description: ${report.description ? JSON.stringify(report.description) : "(none)"}.\n\n` +
    `Faces and text may already be blurred; that is expected. Judge only what you can see.\n` +
    `Answer with JSON only, no prose: {"matches_category": boolean, "people_identifiable": boolean, ` +
    `"inappropriate": boolean, "confidence": number between 0 and 1, "notes": short string}.\n` +
    `matches_category is true if the photo plausibly shows the claimed kind of incident (be lenient about ` +
    `angle and quality). people_identifiable is true only if a real person's face is clearly recognisable. ` +
    `inappropriate is true for nudity, gore, hate symbols, or content unrelated to a local incident (memes, selfies, screenshots).`;

  let verdict: { matches_category?: boolean; people_identifiable?: boolean; inappropriate?: boolean; confidence?: number; notes?: string } = {};
  let raw = "";
  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "content-type": "application/json", "x-api-key": apiKey, "anthropic-version": "2023-06-01" },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 300,
        messages: [{ role: "user", content: [
          { type: "image", source: { type: "base64", media_type: "image/jpeg", data } },
          { type: "text", text: prompt },
        ] }],
      }),
    });
    const out = await res.json();
    if (!res.ok) throw new Error(JSON.stringify(out).slice(0, 300));
    raw = (out.content ?? []).filter((c: { type: string }) => c.type === "text").map((c: { text: string }) => c.text).join("\n");
    const match = raw.match(/\{[\s\S]*\}/);
    verdict = match ? JSON.parse(match[0]) : {};
  } catch (e) {
    await record(MODEL, { error: String(e).slice(0, 500) }, false, "model call failed — held for operator review");
    return json({ status: "pending", verdict: "error" });
  }

  const pass = verdict.matches_category === true && verdict.people_identifiable !== true && verdict.inappropriate !== true &&
    (typeof verdict.confidence !== "number" || verdict.confidence >= 0.5);
  const reason = pass ? "passed model check" :
    verdict.inappropriate ? "inappropriate content" :
    verdict.people_identifiable ? "identifiable people the blur missed" :
    verdict.matches_category === false ? "photo does not match category" : "low confidence";
  await record(MODEL, { ...verdict, raw: raw.slice(0, 1000) }, pass, reason);
  return json({ status: pass ? "unconfirmed" : "pending", verdict: pass ? "pass" : "fail", reason });
});
