# PulsIO — Architecture

**The last planning document before Swift.** How the system is shaped so it stays easy to change.

- Compiled: 2026-09-09
- Companion docs: [`SPEC.md`](SPEC.md) (feature ledger + true status), [`FRONTEND.md`](FRONTEND.md) (screen-by-screen), [`RESTYLE-NOTES.md`](RESTYLE-NOTES.md) (visual finish).
- Section references like "§10" point to `SPEC.md`.

---

## 0. Governing principle

**Everything must be easy to update and add to, with clean departmental separation.** One concern lives in one place; changing it touches one place.

The **pipeline already embodies this** — one parser per source, a runner that orchestrates, one module owning data access, a monitor, a parse cache. Adding a source is adding a parser and registering it. Nothing else moves.

The **current HTML app is the opposite** — 2,880 lines where markup, state, data access, business rules, and a canvas animation share one scope; the only wired feature (news) sits beside hardcoded values that only *look* live. **That entanglement is what we're replacing** — not the design language, the structure.

Two consequences drive every decision below:
1. **Logic lives in Supabase wherever possible** — written once, read by every client.
2. **Contracts are defined once** — both clients implement the same models, tiers, error codes and API surface rather than each inventing its own.

---

## 1. Overall shape — three departments

```
                    ┌───────────────────────────────────────────┐
                    │                 SUPABASE                    │
                    │  (the shared brain — logic lives here)      │
   pipeline ──────▶ │  Postgres tables · SQL functions · views    │ ◀────── clients read
   writes rows      │  RLS · Auth · Storage (report photos)       │         via RPC/PostgREST
                    └───────────────────────────────────────────┘
        ▲                          ▲                         ▲
        │                          │                         │
 ┌──────┴───────┐        ┌─────────┴────────┐       ┌────────┴─────────┐
 │  pulsio-     │        │   iOS (SwiftUI)  │       │   Web            │
 │  backend     │        │   thin client    │       │   thin client    │
 │  (ingestion) │        │                  │       │                  │
 │  + NerveCentre│       └──────────────────┘       └──────────────────┘
 │  (admin)     │
 └──────────────┘
```

### What lives where

**Supabase — the shared brain.** Tables (§2 of SPEC), **SQL functions and views that hold the rules**, Row-Level Security, Auth (**Google, Apple, and email magic link — no passwords anywhere**), Storage (moderated report photos). Already present: `calculate_pulsscore`, `confirm_report(report_id, confirmer_id)`, `expire_old_reports()`, `reset_daily_pulses()`, a waitlist rate-limit trigger. This is the pattern to extend — see §2.

**Pipeline (`pulsio-backend`).** Ingestion only: six parsers (weather, ceb, cwa, news, cyclone, fuel), a runner, a monitor, a parse cache; runs under pm2 on the Mac Mini (SPEC §2). Writes rows; owns no presentation.

**NerveCentre — the admin/operator surface.** Runs under pm2 as **`pulsio-nervecentre` on port 4747**, co-located with the pipeline on the Mac Mini. It reads/writes the same Supabase and is **not** part of either consumer client. It now carries the **events form** (§13) and the **moderation queue + block-user** (§11), so it's load-bearing, not a footnote. *(Its source is **not present on this machine** — no `~/pulsio-backend`, no pm2 here — so whether it shares the `pulsio-backend` repo and what stack it's built in is **unverified from here; confirm on the Mac Mini.** Wherever it lives, it consumes the same shared contracts (§3) as the clients.)*

**Clients (iOS, Web) — thin presentation over shared logic.** They render what the brain computes and handle only what is inherently device- or platform-local:
- location → district resolution and **on-device proximity** (§10);
- on-device photo pipeline (resize + Vision blur, §11) — iOS/iPad only;
- the pulse animation (§4 below);
- store payments (IAP on Apple; Paddle/NOWPayments on web);
- rendering, navigation, and platform chrome.

**The rule of thumb:** if a change to a *rule* would otherwise have to be made in three places (iOS, web, and again in the pipeline), it belongs in Supabase. If it's about *how something looks or feels on this device*, it belongs in the client.

### Repo topology
- **`pulsio`** (this repo) holds **the landing page, the web app, the iOS app, the shared `contracts/` (§3), and the docs.** iOS and web are siblings in one repo, so the CI diff gate over `contracts/` runs across both in one place.
- **`pulsio-backend`** holds the pipeline (and, on the Mac Mini, the NerveCentre process — repo membership unconfirmed, above).
- One repo for the two clients is what makes "define contracts once" cheap: no submodule/package-publish dance — both import the same `contracts/` directory.

---

## 2. Push logic into Supabase

`calculate_pulsscore` is the pattern; several rules already follow it. The target is that **every cross-client rule is a database function or view**, and clients call it rather than reimplement it.

| Rule / decision | Today | Target home |
|---|---|---|
| PulsScore composition | `calculate_pulsscore` ✅ | keep; fix so unmeasured sub-scores are honest (SPEC §5) |
| Report confirmation | `confirm_report()` ✅ | extend to **enforce the 2km radius server-side** (§11) — never trust a client's distance for a write |
| Report expiry | `expire_old_reports()` ✅ | keep (scheduled) |
| Daily pulse reset | `reset_daily_pulses()` ✅ | keep (scheduled) |
| **Pulse availability / spend** | client `localStorage` | `has_pulse_available(user)` + `consume_pulse(user)` RPC — one authority for quota/tier (§ SPEC pulse) |
| **Shelter trust split** | — | a **view** exposing verified (pinned) vs approximate (list-only) shelters (§19), so no client decides trust |
| **Preference ordering** | not built | a function/view returning the **ordered pulse-panel sections** for a user's priorities (§14) — reorder, not filter |
| **Pulse-panel assembly** | hardcoded HTML | an **RPC/view that returns the assembled snapshot** for a district (weather, nearest CEB, reports-near-you count, cyclone, today's events) so clients render a generic ordered list |
| **Moderation transitions** | none | functions for flag → two-flag **auto-hide**, operator remove, block-user; every decision logged to `pulsio_moderation` (§11) |
| **Tier rules** | scattered constants | a **table** (or one function) mapping tier → {pulses/day, ads, device max, features}; clients read it (§3, §17) |

**Trust boundary (important):** on-device proximity is fine for *UX* (what to show you), but any **write** that depends on location (a report confirmation within 2km) must be **re-checked in the database**, because a client can lie about where it is. Client-side distance is a convenience; the server is the authority.

**Auth posture:** providers are **Google, Apple, and email magic link — no passwords.** Browse-freely / sign-in-to-act (SPEC §4) is enforced by **RLS** — public read on live data, writes gated to authenticated users. Rule-bearing functions that need to bypass RLS use `SECURITY DEFINER` deliberately and narrowly (current functions are `INVOKER`; revisit per function).

---

## 3. Shared contracts — defined once, implemented twice

iOS and web must stay at feature parity across two codebases and two languages. They **cannot share code**, so they **share contracts**. A single **`contracts/` source of truth lives in the `pulsio` repo** (§1 topology), and — because iOS and web are siblings in that repo — both import it directly and the CI gate runs over one directory. Both clients (and NerveCentre) generate their own bindings from it.

Three kinds of contract, three mechanisms:

1. **Data shapes (row/DTO types).** The **Postgres schema is the source of truth.**
   - Web: `supabase gen types typescript` → generated TS types (first-party, committed).
   - iOS: **hand-written Swift models, guarded by the CI diff gate** — the decided approach. Rationale (the "whichever you'd actually maintain" test): PostgREST's OpenAPI output is quirky and `openapi-generator`'s Swift is awkward to live with — more than a day to tame and then own. Instead, keep the Swift structs by hand and make CI honest: a **schema-coverage check** diffs the committed `supabase gen types` output (the schema's field sets) against the Swift models and **fails when they diverge** (a new/renamed/removed column that the Swift side didn't track). Manual to write, mechanically policed against drift. Revisit if the model surface grows enough that hand-maintenance costs more than taming the generator.
2. **Rule data that isn't a row shape** — **tier rules, error codes (P/U/S, §21), and the fixed enums** (report categories, cyclone warning classes §15, POI pin/search split §20). These live as **hand-authored machine-readable files** in `contracts/` (JSON/YAML), and a codegen step emits **a Swift enum/struct and a TS const** from each. One edit, both clients regenerate.
3. **API surface** — the set of RPCs/views clients may call, named and typed. Generated from the OpenAPI spec alongside the data shapes; treated as the boundary — clients call only what's listed.

**CI enforces no drift:** generated files are checked in; a CI job regenerates and fails if they differ from what's committed. A rule changed in SQL but not in `contracts/` (or vice-versa) breaks the build rather than shipping a parity bug.

```
contracts/
  schema/           # migrations = source of truth for data shapes
  openapi.json      # PostgREST surface → generated Swift + TS clients
  tiers.json        # tier → limits/features         ┐ hand-authored,
  errors.json       # P/U/S codes → message keys      │ codegen to
  enums.json        # categories, cyclone classes…     ┘ Swift + TS
  strings/          # copy source of truth (see §6)
```

---

## 4. The SwiftUI app's internal structure

**Feature-modular, with one data department** — the pipeline's shape, applied to the client.

```
App/            app shell: launch, session, adaptive layout (iPhone vs iPad/desktop-shared)
Contracts/      generated types + tier/error/enum constants (from §3) — never hand-edited
Data/           the ONE data department: repositories + SupabaseGateway (all network here)
Platform/       device services: LocationDistrict · Proximity(POIStore) · PhotoPipeline(Vision)
                · Payments(StoreKit) · Notifications
Map/            MapSurface protocol + concrete adapter (project/unproject, markers, camera)
PulseFX/        pure render(t) animation module (§5) — depends only on Map/ contract
Features/       one folder per surface, each = View + ViewModel(+state) + strings
  Map/ Filters/ Segments/ PulseDock/ PulseResult/ News/ Report/ PulsScore/
  Search/ Shelters/ Settings/ Upgrade/ Emergency/
DesignSystem/   tokens, components (the RESTYLE-NOTES finish lives here, once)
Localization/   string catalogs (§6)
```

**Rules of separation:**
- **Views never touch the network.** A `View` renders its `ViewModel`; the `ViewModel` calls a **repository** in `Data/`; the repository calls a Supabase RPC/view. A feature knows its repository, nothing else.
- **Freshness is polling, not Realtime (decided for October).** The pipeline runs every ~10 minutes, so clients fetch on-pulse plus a light background refresh; no Supabase Realtime subscriptions. Realtime solves a problem we don't have yet — **revisit only if community reports need to appear without a re-pulse** (§10.9).
- **State is local by default.** Per-feature observable state (Observation / `@Observable`). Only genuinely global state — session, tier, preferences, resolved district — is app-level and injected through the environment.
- **The map SDK is MapLibre (decided), behind `MapSurface`.** iOS uses **MapLibre GL Native**; web uses **MapLibre GL JS** — one map family across the parity build (MapKit was rejected to avoid maintaining two map abstractions, and because the pulse animation is already written against `project/unproject`). Features and PulseFX still depend only on the `MapSurface` protocol (`project()`, `unproject()`, marker positions, camera), so the SDK stays swappable in principle and the animation stays portable.
- **The design finish lives in `DesignSystem/` once** — 0.5px hairlines, radii, glow, tracking, entrance easing (RESTYLE-NOTES) are tokens/components, not per-view literals.

**Adding a feature (screen) touches only:** a new folder in `Features/` (View + ViewModel), one **navigation registration** in `App/`, a repository method in `Data/` *if* it needs new data, and string keys in `Localization/`. **No other feature is edited.** That is the test (§7).

---

## 5. The pulse animation module

PulseFX is already the right shape and stays a **standalone module**: a **pure `render(t)`** that paints the liquid-metaball → island-wave, given a set of world points and a projection.

- **Map-agnostic.** It receives `project(lngLat) → screenPoint` and `unproject(screenPoint) → lngLat` from `MapSurface` (§4), plus a marker provider and `onReveal` / `onDone` callbacks. It holds **no reference to the map SDK, Supabase, or any feature.**
- **Inputs:** the marker set to light up (from the current map state) and the frame clock `t`. **Outputs:** frames + lifecycle callbacks that the host uses to clear frost and open the result panel.
- **Portability:** because the contract is just `project/unproject` + a canvas/`CADisplayLink` surface, the same module logic ports to web (Canvas + the web map's projection) — a genuine shared *concept*, even if the code is per-language.
- **Where it plugs in:** the Map feature owns a `MapSurface`; the PulseDock feature triggers `PulseFX.fire(...)`; PulseFX draws on a sibling overlay layer above the map, below chrome. No feature-to-feature coupling.

---

## 6. Localisation

**Strings externalised from day one, in both codebases** — a hardcoded string is a defect from commit one (SPEC §22: EN + FR at launch, Creole dropped).

- **Single copy source of truth** in `contracts/strings/` (keyed EN + FR). Codegen emits the platform-native forms: an **iOS String Catalog (`.xcstrings`)** and a **web i18n JSON**, both keyed identically so parity is structural.
- **iOS:** no string literals in views — every user-facing string is a catalog key. FR machine-translated, then reviewed by a French-speaking Mauritian; honour Meg's phrasing (`se faire connaître`, `gagner en crédibilité` — §22).
- **CI lint** fails on hardcoded user-facing strings and on keys present in one language but missing in the other.
- Error/status **messages** (§21) are string keys referenced by the P/U/S codes in `contracts/errors.json`, so a code maps to reviewed copy in both languages.

---

## 7. The "clean addition" test

The structure is working only if these hold. Each is the concrete acceptance test for "this was a clean addition."

**Add a new data source** (say, air quality) should touch **only**:
1. **Pipeline:** one new parser + one line registering it in the runner.
2. **Supabase:** one new table (+ include it in the pulse-panel assembly view/RPC if it appears there).
3. **`contracts/`:** the row type (regenerates both clients) + any new enum/error entry.
4. **Each client:** the panel is **data-driven**, so a new sourced row is a *registration/config* entry, not new plumbing — the client renders a generic ordered section it gets from the assembly RPC (§2).

> If adding a source forces edits to unrelated features or bespoke UI per source, the panel isn't data-driven enough — that's the smell to catch in review.

**Add a new screen** should touch **only**: one `Features/` module (View + ViewModel), one navigation registration, a `Data/` repository method if new data is needed, and string keys. **Zero edits to other features.**

---

## 8. How the on-device POI store & sync works

The location privacy rule (§10) forbids sending coordinates to the server, so **proximity is computed on-device** — which requires the POI set to **live on the device**, and makes it the **foundation of the deferred offline mode** (§10 implementation notes). So it's built properly, not as a shortcut.

- **Local store: GRDB (SQLite) — decided** (SwiftData's bulk-sync/deletion story is too rough for ~942 POIs). Holds the synced POI set (~806 active) with coordinates, plus the 10 weather-station coordinates and the shelter verified/approximate split (§19).
- **Sync layer (versioned, incremental, resilient):** a Supabase view/RPC like `poi_changes_since(version)` returning inserts/updates/**deactivations** since the client's last version. The client stores the high-water version, pulls deltas on launch/foreground and on a light schedule, and applies them transactionally. POIs are **read-only reference data**, so there are no write conflicts — the hard part is honouring **deletions/deactivations**, not merges.
- **Proximity:** nearest shelter/pharmacy/station and Search distances (§20) are computed **locally** against this store; only a *result* (or nothing) is used. The server sees a district, never coordinates.
- **Offline substrate:** POI store + last-pulse cache = the offline mode. The offline banner already anticipates it (SPEC §1). Reference data serves offline directly; live data shows "last pulse" with its timestamp.

---

## 9. How the web app mirrors this — without duplicating it

Web is a **thin client over the same brain and the same contracts**, not a re-implementation of the rules.

- **Shared, not duplicated:** every rule (pulse availability, shelter trust, preference ordering, panel assembly, moderation, tiers) is a Supabase function/view both clients call. Both consume the **same generated types, tier/error/enum constants, and strings** (§3, §6). Parity is enforced by shared contracts + shared logic, not by copying code.
- **What legitimately differs (platform glue only):**
  - **Reports:** web is **display-only** (§11) — no camera, no Vision, no photo pipeline, no create flow.
  - **Payments:** web uses **Paddle/NOWPayments**; Apple uses **IAP** (§18). Both write the same entitlement/tier the same way.
  - **Proximity:** still client-side (browser geolocation) under the same privacy rule; distance computed in-browser.
  - **Layout:** web uses the iPad/desktop-shared layout (sidebar + right panel, FRONTEND §1).
  - **Animation:** same PulseFX *concept* over the web map's `project/unproject` (§5).
- **The mental model:** iOS and web are two skins with identical wiring diagrams. If a feature behaves differently between them for any reason other than the platform-glue list above, that's a bug, not a variation.

**Web framework — decided (ratified 2026-09-10): React + TypeScript, built with Vite.** Reasons: it has the strongest first-party support for the two SDKs this build leans on — **MapLibre GL JS** and **supabase-js** — the largest hiring/AI-assistance pool, and a component model that maps cleanly onto the feature-module structure in §4 (a `Features/` folder per surface, repositories in a `Data/` layer, generated types from `contracts/`). SvelteKit was the considered alternative (smaller bundle, less boilerplate) and was set aside for ecosystem depth. TS is a given since `contracts/` generates TypeScript. The web app lives at `web/` in this repo, sibling to `ios/` (§1 topology).

---

## 10. Where the structure will come under pressure

Named honestly, because this is where it breaks first.

1. **The pulse-panel assembly + preference ordering.** It aggregates the most sources and is the most tempting place to hardcode "if source X, render row Y." If it isn't genuinely data-driven (server returns ordered sections; client renders generically), it becomes the app's god-object. **First and most likely failure point.**
2. **The `MapSurface` abstraction.** `project/unproject` is clean in 2D, but tilt/3D, camera animation timing, and marker draw-order can still differ between **MapLibre GL Native (iOS)** and **MapLibre GL JS (web)** even within one SDK family. The pulse animation is exactly where a leaky projection contract shows up as a visual glitch.
3. **Contract drift across two languages.** Generated types are safe; the **hand-authored** tier/error/enum/string files are where drift creeps in if someone edits SQL or copy without regenerating. The CI gate is load-bearing — if it's ever disabled "temporarily," parity rots silently.
4. **The trust boundary on location.** Client-side proximity for UX vs server-side re-check for confirmations (2km, §11) is a line that will be blurred under time pressure ("just trust the client's distance"). If it blurs, confirmations become spoofable.
5. **Sync correctness.** Incremental sync rots at **deletions/deactivations** and version bumps — a shelter downgraded, a POI deactivated, a coordinate corrected. Read-only data makes it tractable, but "why is a closed pharmacy still on my map offline" is the classic symptom.
6. **"Push logic into Supabase" vs device-context logic.** Preference ordering *could* be a DB function, but the inputs (priorities) and some context (which station is nearest) are client-side. The DB-owned vs client-owned line will be re-argued per feature; without a stated heuristic (§1) it drifts case by case.
7. **IAP ↔ server tier truth.** Receipt validation, restore, and the server being the single source of tier truth invite races (entitlement granted on-device before the server records it). Where "am I paid?" is answered — client cache vs server — needs to be one place.
8. **RLS as the app grows.** Pushing logic into the DB means auth correctness lives in RLS + `SECURITY DEFINER` functions. Browse-freely/sign-in-to-act is simple now; moderation, blocking, and operator actions add policy surface that's easy to get subtly wrong.
9. **Polling vs Realtime.** October is polling (every ~10 min, §4). This is fine until a class of data needs to appear **without a re-pulse** — community reports are the likely trigger (someone reports a flood; nearby users should see it promptly). That's the moment to add Realtime for that one table, not before — noted so it's a deliberate later choice, not a scramble.

---

*Planning document; the iOS scaffold in `ios/` is the first code built against it (2026-09-10). Built on SPEC.md + FRONTEND.md; grounded in the live Supabase function set (`calculate_pulsscore`, `confirm_report`, `expire_old_reports`, `reset_daily_pulses`) and the `pulsio-backend` pipeline shape.*
