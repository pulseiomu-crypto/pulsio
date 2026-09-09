# PulsIO — Frontend Definition (native build)

**The screen-by-screen document the native app is written from.** Scope: **October launch cut only.** Deferred features get a one-line "slots in here" note, not a full definition.

- Compiled: 2026-09-05
- Built on: the current app ([`pulsio-app-v1_18.html`](pulsio-app-v1_18.html)) + the decisions in [`SPEC.md`](SPEC.md), with the finish changes from [`RESTYLE-NOTES.md`](RESTYLE-NOTES.md) applied.
- Companion docs: `SPEC.md` (feature ledger + true status), `RESTYLE-NOTES.md` (restyle).

---

## 0. How to read this

Every screen/surface below defines, in order:
- **Elements** — what's on it and what each does
- **Data** — what it reads, with source status
- **Platforms** — iPhone vs iPad/desktop
- **Tiers** — how it changes by plan
- **Signed-out** — behaviour under the browse-freely / sign-in-to-act model (§4)
- **Ad slot** — where the ad sits and what suppresses it (§5)

**Data source status** (from SPEC): 🟢 wired & live · ⚙️ source exists in DB, not yet wired (native must wire it) · 🧮 computed on-device · ❌ no source exists (out of Oct cut) · ⏳ deferred feature.

---

## 1. Platforms & layouts

Two layouts. **iPhone** = mobile. **iPad and desktop share one layout.**

### iPhone (mobile)
- Full-bleed **map** is the base surface; it stays visible at all times.
- **Filters** = a single **collapsed chip** (tap to expand into a sheet).
- **Panels** (pulse result, report, news, etc.) open as **bottom sheets** with **peek / half / full** detents (iOS `presentationDetents` — custom-small / medium / large). Nonmodal where the map must stay interactive behind them (SPEC §8).
- The pulse dock sits above the home indicator in the safe area.

### iPad & desktop (shared)
- **Left sidebar** holds the **filters** permanently.
- **One panel slot on the right.** Filters do *not* live here — the right slot shows the **pulse result** by default context, and the **report form** or **pulse result replaces** whatever's there, restoring on close. The **report panel collapses rather than closes**, preserving anything typed (SPEC §7).
- Map fills the centre between sidebar and right panel.

> Full panel-behaviour spec: SPEC §7. Panel tabs for v1 are **Live** and **Report** only; **Alerts folds into the filters list**; **Guide returns with the itinerary builder (November, §9 of SPEC)**.

---

## 2. Design finish (applied restyle)

Per `RESTYLE-NOTES.md` — finish changes only, nothing in its Flag B changes:
- **0.5px** neutral hairlines (not 1px); teal still reserved for live/active.
- **Larger, softer radii** (toward 14–22px on cards/sheets/inputs).
- **Glow-based depth alongside** the existing shadow system (`--e-*`), not instead of it.
- **Wider mono tracking** on eyebrows/labels (~.2–.28em).
- **Longer ease-out** (`cubic-bezier(.2,.7,.2,1)`, ~.5–.9s) for panel/sheet/modal **entrances**; fast spring + press-`scale(.97)` stays for taps.
- **Stays (Flag B):** dense data rows, semantic colour coding, neutral hairlines, brighter secondary text (0.55), compressed ≤30px type scale, tactile motion.
- **Compliance baked in from the start (SPEC §8):** ≥44pt tap targets, safe-area insets, Dynamic Type, standard sheet nav (Cancel leading / Done trailing).

---

## 3. Tier model (October cut)

| Tier | Price | Pulses/day | Devices | Ads | Extras advertised |
|---|---|---|---|---|---|
| **Explorer** (free) | Free | 1 | 1 | Yes | — |
| **Traveller** (T1) | MUR 150/mo | 10 | 2 | No | Flights · Marine · Beach ⏳ |
| **Resident** (T2) | MUR 400/mo | Unlimited | 3 | No | History replay ⏳ · SMS alerts ⏳ |
| **Pro** | Custom | Unlimited | 5 | No | API ⏳ · white-label ⏳ · analytics ⏳ |

**What tier actually gates in the Oct cut:** pulse quota (1 / 10 / unlimited), ads (on for free, off for paid), device count. Everything marked ⏳ (Flights/Marine/Beach live layers, history replay, SMS, API, white-label, analytics) is **deferred** — advertised on the upgrade card but not built for October. Cyclone is **always free** (safety), regardless of tier or quota.

---

## 4. Signed-out model — browse freely, sign in to act

**Free to do signed-out:** browse the map + all filters/layers, **fire the 1 free daily pulse**, view the pulse result panel, read the news feed + detail, view PulsScore + open its share card, use the **emergency dial**, and set a **local device-only district** (via permission or picker, SPEC §10).

**Requires sign-in (an "act"):** submit a community report, confirm someone else's report, enable morning pulse/notifications ⏳, **upgrade or buy top-ups** (IAP needs an account), sync across devices, and **persist** preferences/district to the profile.

**Interaction:** attempting an act presents a **sign-in sheet**; on success, the original action **resumes** where it left off (e.g. the half-typed report is submitted). Never block browsing to force sign-in. Signed-out quota is tracked on-device (Keychain); signing in binds it to the server profile.

**Account:** sign in with **Google, Apple, or email magic link — no passwords.** Because we offer sign-up, **in-app account deletion is mandatory** (SPEC §8, Review 5.1.1(v)) — lives in Settings (§ screen I).

---

## 5. Ad slot — placement & suppression

**Placement:**
- **iPhone:** one **slim ad bar** directly under the top bar, full-width, above the map. Collapses to zero height when suppressed.
- **iPad/desktop:** ad occupies a **card pinned to the bottom of the left filters sidebar** — keeps the map and right panel clean.

Both carry a **"Remove ads ↑"** affordance → opens Upgrade (§ screen J).

**Suppressed (no ad shown) when any of:**
- Tier is **paid** (T1/T2/Pro).
- During the **pulse ceremony** (full-screen reveal, § screen D).
- On the **Emergency dial** (§ screen K) — never monetise safety.
- Behind **full-screen modals/sheets** (Upgrade, Settings, PulsScore share card).

**Signed-out** users are Explorer/free → **they see ads.**

> Location model, privacy rule, and on-device proximity: SPEC §10. Every "nearest X" below is computed **on-device** from the synced POI set; the server only ever sees a district. Weather "for you" = nearest of the 10 stations chosen on-device.

---

## 6. Screens

### A. Onboarding

**Elements**
- Step 1 — brand intro ("The island at your fingertips") + **Get started**.
- Step 2 — "What is a Pulse?" explainer (1 free pulse/day).
- Step 3 — **user type** (Mauritian / Tourist / Professional) + up to **3 priorities** (CEB / Weather / Traffic / News / Cyclone / Fuel).
- **Location rationale** screen — *explains why location helps before any system prompt* (SPEC §10 flow step 1). The system permission itself is **not** requested here; it's asked in-context at first use.

**Data** — writes `user_type`, `priorities`, `district` to profile when signed in ⚙️ (`pulsio_profiles`); held on-device until then.

**Platforms** — iPhone: full-screen paged flow. iPad/desktop: same content **centred in a modal card** over a dimmed map, not full-bleed.

**Tiers** — none (pre-tier). Everyone lands as Explorer/free.

**Signed-out** — this is the default first-run path; **no sign-in required** to finish onboarding or enter the app. Choices persist locally; sign-in later migrates them.

**Ad slot** — none during onboarding.

---

### B. Map screen & its states

**Elements**
- Full-bleed **MapLibre/native map** of Mauritius; custom markers; tap a marker → popup (name, type, key stats, actions).
- **Top bar:** logo (tap = recentre), **LIVE** badge, **pulse pips + count**, **PulsScore pill** (tap → PulsScore, § H), **tier pill** (tap → Upgrade), **profile** (tap → Settings if signed in, else sign-in).
- **Segment tabs** (All / Tourist / Mauritian / Pro) — filter POIs by audience (`seg`).
- **Filters** entry (chip on iPhone, sidebar on iPad/desktop — § C).
- **Pulse dock** (§ D) and **news ticker** (§ F) along the bottom.
- **Own-location blue dot** — the user's live position shown to them only; **coordinates never leave the device** (SPEC §10).

**States**
1. **Frosted (pre-pulse):** map blurred behind frost; prompt "Fire your pulse to reveal what's happening on the island." Markers hidden.
2. **Firing (ceremony):** § D — frost clears as the wavefront lands; markers light up as it reaches them.
3. **Revealed:** markers live; pulse result panel available; reveal timer running (free tier).
4. **Offline:** banner "Offline — showing your last pulse"; last cached pulse + synced POIs shown (SPEC §10 offline foundation).
5. **Back-online:** transient "Back online — data refreshing."

**Data**
- Markers: `pulsio_poi` ⚙️ (native reads the **on-device synced** POI set, SPEC §10; today hardcoded).
- Live alert pins (CEB/CWA/cyclone) ⚙️; news pins 🟢 (`pulsio_news` where geolocated — pinning design in SPEC §6).
- Live **flights / marine / traffic** layers ⏳ — **deferred**; not in the Oct cut (tables empty). The tool toggles for them slot in when feeds exist.

**Platforms** — iPhone: edge-to-edge, controls in safe area, filters chip. iPad/desktop: map inset between left sidebar and right panel slot.

**Tiers** — free sees ads + reveal timer; paid removes both. Deferred paid layers (flights/marine) don't appear in Oct.

**Signed-out** — full map browse + segments + filters + the daily free pulse all work. Blue-dot location works locally.

**Ad slot** — visible (free/signed-out) except during the ceremony (§5).

---

### C. Filters panel

**Elements**
- **Layer toggles** for what's on the map: POI categories (beach, shelter, pharmacy, police, supermarket, fuel, hospital/clinic, etc.), **alerts** (CEB, CWA, cyclone), news pins, community reports.
- **Alerts list folded in** (SPEC §7): the active CEB/CWA/cyclone items as a scrollable list; tap → fly-to on map.
- **Segment** control mirror (All / Tourist / Mauritian / Pro).
- Per-item live counts where available ("CEB · 2 zones").

**Data** — POI categories from on-device POI set ⚙️; alerts from `pulsio_ceb` / `pulsio_cwa` / `pulsio_cyclone` ⚙️ (empty lists render as "all clear").

**Platforms**
- **iPhone:** filters are a **collapsed chip**; tap → opens as a **bottom sheet** (peek/half/full). Map stays visible behind.
- **iPad/desktop:** filters live **permanently in the left sidebar**; the ad card pins to its bottom (§5).

**Tiers** — layer set is the same across tiers in Oct (the tier-locked flights/marine layers are deferred). No gating here for October.

**Signed-out** — fully usable; toggles are view state, no account needed.

**Ad slot** — iPad/desktop: the sidebar ad card lives at the sidebar's foot. iPhone: the top ad bar remains behind the filter sheet.

---

### D. Pulse dock & ceremony

**Elements**
- **Fire button** (the dock), a **PULSE** label, and an availability line ("1 available" / cooldown).
- Tapping fires a pulse if quota remains; if spent → opens the **spent/top-up** prompt (→ § J).

**Ceremony** (keep the PulseFX set-piece — SPEC's one working showpiece)
- Liquid metaball → island-wave animation; **frost clears on impact**; markers light as the wavefront reaches each.
- On completion: reveal the map and make the **pulse result panel** (§ E) available; start the reveal/cooldown timer for free tier.

**Data** — quota is **server-backed** for signed-in users ⚙️ (`pulsio_profiles.pulses_remaining`, logged to `pulsio_pulses`); on-device for signed-out. Reset rule per SPEC §5 open item (confirm daily vs timer).

**Platforms** — iPhone: dock pinned in the bottom safe area; ceremony full-screen. iPad/desktop: dock centred under the map; ceremony plays over the map, panel opens in the right slot on completion.

**Tiers** — free: 1/day + reveal timer + spent state. T1: 10/day. T2/Pro: unlimited (no spent state, no timer). Cyclone data is reachable regardless (safety).

**Signed-out** — the **1 free daily pulse works without sign-in** (tracked on-device). Running out prompts sign-in/upgrade only as the path to *more*, never to browse.

**Ad slot** — **suppressed during the ceremony** (§5), restored after.

---

### E. Pulse result panel (LIVE)

**Elements** — the post-pulse snapshot. Dense data rows (Flag B):
- Temperature + feels-like; Humidity; Wind; UV; Sunset; Fuel MUR/L; **PulsScore** (tap → § H); **CEB cuts** (tap → map); **Cyclone** status.
- Rows are tap-through to the map or the relevant detail where sensible.

**Data**
- Weather rows ⚙️ `pulsio_weather` (nearest station, on-device pick).
- PulsScore ⚙️ `pulsio_score`. Fuel ⚙️ `pulsio_fuel`. CEB ⚙️ `pulsio_ceb`. Cyclone ⚙️ `pulsio_cyclone`.
- **Sunset** 🧮 computed on-device.
- **USD/MUR, Tide, Sea state** ❌ **no source** — **out of the Oct cut**; omit rather than show a hardcoded value (SPEC §5). They slot in when a feed exists.
- Beach/lagoon guide rows ⏳ — deferred (Guide returns in November).

**Platforms** — iPhone: bottom sheet, opens at **half** after the reveal so the map stays visible; drag to **full** for the complete list, **peek** to glance. iPad/desktop: fills the **right panel slot** (the "Live" tab).

**Tiers** — content identical across tiers; free tier's panel is subject to the reveal timer (re-fire needed after it lapses).

**Signed-out** — fully viewable after the free pulse. No sign-in to read.

**Ad slot** — iPhone: top ad bar remains above the sheet (free). iPad/desktop: sidebar ad unaffected. Suppressed for paid.

---

### F. News feed & detail

**Elements**
- **Ticker** along the bottom of the map (top ~6 headlines); tap → opens the feed.
- **Feed** — scrollable list, category colour-coded, 50 latest; tap an item → detail.
- **Detail** — headline, source, time, excerpt, **"Read at source ↗"** (opens `source_url` in-app browser/Safari).

**Data** — 🟢 **`pulsio_news`** — the one fully-wired feature today. Ordered by `published_at`, limit 50. Headlines/excerpts HTML-escaped. Geolocated items also drive **news map pins** (SPEC §6).

**Platforms** — iPhone: feed + detail as bottom sheets (full detent for the feed). iPad/desktop: feed opens in the right panel slot or a modal; detail as a modal card.

**Tiers** — none; news is free for all tiers and signed-out.

**Signed-out** — fully readable, including detail and source-out. No account needed.

**Ad slot** — feed may carry the standard slim ad for free/ signed-out at the list head; suppressed for paid. Detail view: no inline ad.

---

### G. Community report submission

**Elements**
- Category picker (10 types: power cut, water cut, accident, hazard, flood, traffic, jellyfish, event, infrastructure, other).
- Optional description (textarea); optional photo.
- **Location = tap the map to place the report** — lat/lng arrive with the submission (SPEC §10; this is the one place raw coordinates are sent, because the user explicitly places them).
- **Submit**; helper: "Reports need 2 confirmations to go live on the map."
- Others can **confirm** a pending report from its map popup.

**Data** — writes `pulsio_reports` ⚙️ (native must actually persist; today it's a toast stub — SPEC §1). Confirmations update `confirmations` / `confirmed_by`; 2h expiry per schema.

**Platforms** — **submission is device-only: iPhone + iPad** (SPEC §11 — the first deliberate web-parity exception; the rule is "camera + physically at the incident," which both satisfy; Vision blurring works identically on iPad).
- **iPhone:** opens as a bottom sheet (the "Report" panel); flow per SPEC §11 (category → draggable pin → photo → optional line → submit). The report sheet **collapses rather than closes** so a half-written report survives (SPEC §7).
- **iPad:** same create flow, presented in the shared iPad/desktop layout (report replaces filters in the right panel slot; collapses rather than closes, SPEC §7).
- **Desktop / web:** **display reports on the map, but cannot create them.** Where the report button would be, show: *"Reports are submitted from the PulsIO mobile app."*

**Tiers** — available to all tiers equally (community feature, not gated).

**Moderation & photo handling** — three-layer moderation (auto/community/operator), on-device photo resize + Vision face/text blur, and the `pulsio_moderation` audit trail are fully defined in **SPEC §11**. Note the App Store UGC requirements (report / remove / block) must be shipped, not just specced.

**Signed-out** — **this is an "act."** Browsing/reading reports is free; **submitting or confirming requires sign-in** (§4). Tapping Submit while signed-out → sign-in sheet → resume submission with the drafted content and placed pin intact. Confirmation is limited to **within 2km of the report pin** (SPEC §11).

**Ad slot** — no inline ad within the report form; the layout's standard ad (top bar / sidebar) follows the usual suppression rules.

---

### H. PulsScore & share card

**Elements**
- **Score view** — the number out of 100 + label ("Great day on the island") and the **six sub-scores** (weather, safety, beach, traffic, air, events) as bars.
- **Honesty note:** only weather (and safety) are truly measured; traffic & air are placeholder constants, beach is derived from weather, events reads an empty table (SPEC §5). Present the composite; don't over-claim the breakdown. *(Consider showing only substantiated sub-scores until the rest have real inputs — flagged for the product call.)*
- **Share card** — a generated image (score + label + date + brand) for social; **Share** via the system share sheet.

**Data** — ⚙️ `pulsio_score` (+ sub-scores). Share card rendered on-device from that row.

**Platforms** — iPhone: full-screen sheet; share via `UIActivityViewController`. iPad/desktop: modal card; share via the system sheet / download.

**Tiers** — visible to all tiers and signed-out. No gating.

**Signed-out** — viewable and shareable without sign-in (it's browsing, and the share card is public-facing by design).

**Ad slot** — none over the score/share card (full-screen modal suppresses ads, §5).

---

### I. Settings & account

**Elements**
- **Account:** sign in with **Google, Apple, or email magic link (no passwords)**; when signed in — display name, tier, **manage subscription** (→ system IAP management), **Sign out**, **Sign out of all devices** (SPEC §17), and **Delete account** (mandatory in-app, SPEC §8).
- **District** — editable permanently (SPEC §10 step 5); shows current source (GPS/manual); re-request location option.
- **Devices** — "N of {tier max}" (device management is display-oriented for Oct; enforcement per tier).
- **Notifications / Morning Pulse** ⏳ — toggle + time picker present, but **delivery is deferred**; setting persists to profile, no push sent in Oct (SPEC §5). Label honestly ("coming soon") rather than implying delivery.
- **Language** — en only for Oct; fr/cr ⏳ deferred (don't present a non-functional switch as working).
- **Top up pulses** → § J.

**Data** — `pulsio_profiles` ⚙️ (district, prefs, tier, device_count); subscription state via IAP.

**Platforms** — iPhone: full-screen settings sheet. iPad/desktop: modal or right-panel settings; grouped list.

**Tiers** — subscription row reflects current tier + upgrade path; device count max varies by tier.

**Signed-out** — the profile button opens **sign-in** rather than settings. Local-only district and app preferences are still adjustable in a reduced settings view; account-bound items require sign-in.

**Ad slot** — none (settings is a full-screen modal, §5).

---

### J. Upgrade flow

**Elements**
- **Plan chooser** — Explorer / Traveller / Resident / Pro cards (§3) with price + what each unlocks.
- **Top-up packs** — one-off pulse packs (5 / 15 / 30) for users who don't want a subscription.
- **Purchase** → **Apple IAP** on iPhone/iPad (SPEC §4/§8: digital goods must use IAP; Stripe in schema is legacy; Paddle/NOWPayments are the **web** routes, not native).
- Success state → updates tier/quota; dismiss back to map.

**Data** — entitlements via **StoreKit/IAP**; tier mirrored to `pulsio_profiles.tier` ⚙️ after validation.

**Platforms** — iPhone: full-screen sheet. iPad/desktop: modal card. IAP sheet is system-presented on both.

**Tiers** — this is the surface that changes tiers. Pro is "custom / contact" rather than a self-serve purchase in Oct.

**Signed-out** — purchasing is an **act** → requires sign-in first (IAP needs an account to bind the entitlement), then resumes. Viewing plans/prices is free.

**Ad slot** — none over the upgrade modal (§5); note the whole point is removing ads for paid tiers.

---

### K. Emergency dial

**Elements**
- Quick-dial list of Mauritius emergency numbers (Police 999, SAMU 114, fire, coastguard, etc.) — tap to call via `tel:`.
- Optional: **nearest** hospital / clinic / pharmacy / police, computed **on-device** from the POI set (SPEC §10), each tappable to call or route.

**Data** — emergency numbers are **static reference data** (hardcoded is correct here — they don't change). Nearest-facility uses the on-device POI set ⚙️.

**Platforms** — iPhone: bottom sheet or full-screen list, large 44pt+ call targets. iPad/desktop: modal / right-panel list.

**Tiers** — available to **all tiers and signed-out**, always. Never gated, never metered.

**Signed-out** — fully available; no sign-in, ever. Safety surface.

**Ad slot** — **never** on the emergency dial (§5).

---

## 7. Deferred — where each piece slots in (not defined here)

| Deferred feature | Slots into |
|---|---|
| **Guide** panel (beach/lagoon intelligence) | November, with the **itinerary builder** (SPEC §9) — returns as the 3rd panel tab |
| **Itinerary builder + Live Activities/Dynamic Island + maps hand-off** | November release (SPEC §9); iOS-first, breaks parity |
| **Live flights / marine / traffic** layers | Map tool toggles (§ B) once feeds exist; advertised on T1 today |
| **History replay** | T2 feature; time-series data already exists to support it |
| **SMS alerts** | T2 feature; needs SMS integration |
| **Morning Pulse delivery** (push/SMS/email) | Settings toggle exists (§ I); delivery mechanism deferred |
| **Multi-language (fr/cr)** | Settings language switch (§ I); en only for Oct |
| **API / white-label / analytics** | Pro tier; not self-serve in Oct |
| **USD/MUR · tide · sea state** rows | Pulse result panel (§ E) once a data source exists (SPEC §5) |
| **Hotel referral program** | No consumer screen; backend/admin only (SPEC §4) |

---

*Scope: October launch cut. Built from the current app + SPEC.md decisions, with RESTYLE-NOTES.md finish applied. Deferred items are pointers, not definitions.*
