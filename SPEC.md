# PulsIO — Feature Ledger

**The single source of truth for what PulsIO is and what state each piece is in.**
Compiled from real evidence, not chat memory, ahead of the native iOS rebuild.

- **Last compiled:** 2026-09-05
- **Evidence base:**
  - Frontend: [`pulsio-app-v1_18.html`](pulsio-app-v1_18.html) (2,880 lines — the current web/PWA app)
  - Backend schema + live data: Supabase project `beyplrfqhfklylmmrxmw` (region eu-west-3), queried directly
  - Pipeline: inferred from what it writes (see the blunt caveat below)
- **Author's note:** Status here is deliberately harsh. "Not built" is stated plainly. Where a feature was likely designed but I can't find it in code, it is flagged, not omitted.

---

## ⚠️ Read this first — three facts that reframe everything

1. **The app is a demo shell with one real data feed.** Of every live surface in the frontend, **exactly one** reads real data from the backend: the **news feed** (`pulsio_news`). Everything else you see — temperature, PulsScore, humidity/wind/UV, fuel price, FX rate, CEB cuts, cyclone status, beach guide, all map markers (POIs, traffic, flights, ships) — is **hardcoded** in the HTML/JS. It looks live (it even has a pulsing "LIVE" badge); it is not.

2. **The data pipeline lives in a separate repo and runs continuously on hardware.** It is **not** Supabase Edge Functions (zero are deployed) and it is **not** a black box. The pipeline is the `pulsio-backend` repo — on GitHub at [`pulseiomu-crypto/pulsio-backend`](https://github.com/pulseiomu-crypto/pulsio-backend) and checked out on the owner's **Mac Mini at `~/pulsio-backend`**, running **continuously under pm2**. That is why the tables were written to on 2026-09-05. It consists of **six parsers** (weather, ceb, cwa, news, cyclone, fuel), a **runner**, a **monitor**, and a **parse cache**. *(This ledger was compiled on the MacBook Air, where `pulsio-backend` isn't checked out — hence the pipeline internals below are described from the schema it writes and the owner's account of it, not read line-by-line from the parser source.)*

3. **The backend is far ahead of the frontend.** The database contains 24 tables — a scored index, 942 POIs, 16,904 weather readings, an admin/monitoring layer, a hotel-referral system, user/billing/reports schema. The frontend consumes almost none of it. The product's real capability lives in the DB; the app hasn't been wired to it yet.

---

## Status legend

| Badge | Meaning |
|---|---|
| 🟢 **LIVE** | Works end to end — real data source, wired, functioning |
| 🟡 **HARDCODED** | Built and visible in UI, but showing static/fake data (a real source often exists but isn't wired) |
| 🟠 **PARTIAL** | Some of it built; key pieces missing (e.g. UI exists, no persistence) |
| 🔴 **NOT BUILT** | Not present in code |
| 🔵 **BACKEND-ONLY** | Data/table exists and may be populated, but no frontend consumes it |
| ❓ **UNVERIFIED** | Likely designed/intended per surrounding evidence; not found in code — confirm before assuming absent |

---

## 1. Frontend feature ledger

Surface names refer to `pulsio-app-v1_18.html`.

### Core shell & navigation

| Feature | What it does | Surface | Data source needed | Source exists & works? | Status |
|---|---|---|---|---|---|
| Onboarding flow | 3 steps: intro → "what is a pulse" → pick user type (Mauritian/Tourist/Pro) + up to 3 priorities | `#onboarding` (ob1/ob2/ob3) | User profile (`pulsio_profiles.user_type`, `priorities`, `district`) | Table exists, **not written to** — choices saved to `localStorage` only | 🟠 PARTIAL |
| Top bar | Logo/recentre, LIVE badge, pulse pips, PulsScore pill, tier pill, profile btn | `#topbar` | — (chrome) | n/a | 🟢 LIVE (as UI) |
| Segment tabs | All / Tourist / Mauritian / Pro — filters map markers by audience | `#segments` | Marker `seg` tags | Filters the **hardcoded** marker list client-side | 🟡 HARDCODED |
| Map | MapLibre GL base map of Mauritius, custom markers, fly-to, popups | `#map-container` | Map tiles + marker data | Map renders; marker data is hardcoded | 🟡 HARDCODED |
| Tool bar (layers) | Toggle Map / Weather / Panel / Traffic / Flights / Marine layers | bottom `.tbtn` row | Layer data per type | Toggles visibility of **hardcoded** markers; Flights/Marine/Traffic gated by tier | 🟡 HARDCODED |
| Right panel | Slide-in panel hosting LIVE/GUIDE/ALERTS/REPORT tabs | `#rpanel` | per-tab (below) | Panel works; contents mostly static | 🟠 PARTIAL |
| Offline / online banners | Show "offline — last pulse" and "back online" states | `#offline-banner`, `#online-banner` | `navigator.onLine` | Client-side connectivity only | 🟠 PARTIAL |
| Ad bar | "Sponsored" strip + "Remove ads ↑" upsell | `#adbar` | Ad inventory | Single hardcoded sponsor line; toggled off by tier | 🟡 HARDCODED |
| Debug tier switcher | Force free/T1/T2 via `?debug` | `#tier-switcher` | — | Works; test-only, "remove before production" | 🟢 LIVE (dev tool) |

### The Pulse (the signature interaction)

| Feature | What it does | Surface | Data source needed | Source exists & works? | Status |
|---|---|---|---|---|---|
| Fire Pulse button | Tap to "fire a pulse" — triggers reveal ceremony | `#firebtn` / `firePulse()` | — | Works client-side | 🟢 LIVE (as interaction) |
| PulseFX animation | Liquid metaball → island wave that clears frost & lights markers as the wavefront hits them | `#pulsefx` canvas + `mauritius-heightmap.png` | Baked heightmap asset | Fully built, elaborate, real | 🟢 LIVE |
| Pulse quota / pips | Free = 1/day, T1 = 10, T2 = 999; countdown to next pulse | pips + `#pcount` / `tierConfig` | `pulsio_profiles.pulses_remaining`, `pulsio_pulses` log | Tables exist; **not wired** — quota is client-side `localStorage` + timer, resets locally, no server truth | 🟠 PARTIAL |
| "Spent" state | Button dims when out of pulses; prompts top-up/upgrade | `markSpent()` / `#spent-modal` | quota state | Client-side only | 🟠 PARTIAL |

### Right-panel tabs

| Feature | What it does | Surface | Data source needed | Source exists & works? | Status |
|---|---|---|---|---|---|
| **LIVE** tab | Temp, PulsScore, humidity, wind, UV, sea state, tide, sunset, fuel MUR/L, USD/MUR, CEB cuts, cyclone | `#tab-live` | `pulsio_weather`, `pulsio_score`, `pulsio_fuel`, `pulsio_ceb`, `pulsio_cyclone` (+ needs: FX, tide, sea state, sunset sources — **none exist**) | Sources exist & live for weather/score/fuel/ceb/cyclone — **none wired**; every value is static HTML (e.g. `27°C`, score `78`, fuel `63.20`, FX `45.82`). `USD/MUR`, `tide`, `sea state` have **no source**; `sunset` is computable but unproduced. Also needs a **location layer** (which station is "yours") that doesn't exist. | 🟡 HARDCODED |
| **GUIDE** tab | Best beach today, lagoon/snorkel/jellyfish/crowd status, emergency | `#tab-guide` | Beach/marine model, `pulsio_reports` (jellyfish) | No beach model built; all static | 🟡 HARDCODED |
| **ALERTS** tab | CEB cuts, CWA low-pressure, cyclone station status | `#tab-alerts` | `pulsio_ceb`, `pulsio_cwa`, `pulsio_cyclone` | Sources exist (CEB has 146 rows) — **not wired**; alerts are static list | 🟡 HARDCODED |
| **REPORT** tab | Pick category (10 types) + description, submit community report | `#tab-report` / `submitReport()` | `pulsio_reports` (write) | Table exists with full schema (confirmations, expiry, geo) — **not wired**; submit only fires a toast, writes nothing | 🟠 PARTIAL |

### News

| Feature | What it does | Surface | Data source needed | Source exists & works? | Status |
|---|---|---|---|---|---|
| News ticker | Scrolling headlines strip above tool bar | `#news-ticker` | `pulsio_news` | **Yes — wired** (`loadNews()` → top 6 headlines) | 🟢 **LIVE** |
| News modal | Full scrollable feed, category color-coded, 50 latest | `#news-modal` / `renderNews()` | `pulsio_news` | **Yes — wired** (real query, ordered by `published_at`) | 🟢 **LIVE** |
| News detail | Headline, source, time, excerpt, "read at source ↗" | `#news-detail` | `pulsio_news` row | **Yes — wired**; opens `source_url` | 🟢 **LIVE** |

> News is the **only** end-to-end feature in the app. 499 articles across 10 categories, pipeline last wrote 2026-09-05. Input is HTML-escaped before render (`esc()`).

### Accounts, billing, settings

| Feature | What it does | Surface | Data source needed | Source exists & works? | Status |
|---|---|---|---|---|---|
| Sign up | Create account modal | `#signup-modal` | Supabase Auth + `pulsio_users`/`pulsio_profiles` | **Stub** — sets `localStorage.pulsio_signedup=1`; no real auth (0 users in DB) | 🟠 PARTIAL |
| Log in | Login modal | `#login-modal` | Supabase Auth | **Stub** — code comment: *"In production: Supabase signInWithPassword"* | 🟠 PARTIAL |
| Tiers / upgrade | 4 plans: Explorer (free) / Traveller MUR150 / Resident MUR400 / Pro (custom) | `#upgrade-modal` / `setTier()` | `pulsio_users.tier`, payment provider | Switches tier client-side only; no billing, no persistence | 🟠 PARTIAL |
| Top-up pulse packs | Buy 5/15/30 pulse packs | `#topup-modal` / `purchaseTopup()` | Payment provider + `pulse_topup_balance` | **Stub** — comment: *"triggers Paddle checkout or NOWPayments"*; just increments local counter | 🔴 NOT BUILT (payment) |
| Payment method UI | Card / mobile-money selector | `.pay-method` | Payment provider | Visual only, no integration | 🔴 NOT BUILT |
| Settings modal | Devices, notifications, morning pulse, language, district, top-up, sign out | `#settings-modal` | `pulsio_profiles` | UI built; each control is display-only or fires a toast | 🟠 PARTIAL |
| Morning Pulse | Daily summary at chosen time + toggle | `#morning-modal` | `pulsio_profiles.morning_pulse_*` + push/SMS/email delivery | Time/toggle saved to `localStorage`; **no notification delivery of any kind built** | 🟠 PARTIAL |
| Language (en/fr/cr) | Language selector | settings `<select>` | i18n strings | Fires a toast; **no translations built** (app is English-only) | 🔴 NOT BUILT |
| District selector | Set home district | settings | `pulsio_profiles.district` | Toast only | 🟠 PARTIAL |
| Device management | "1 of N devices" per tier | settings | `pulsio_profiles.device_count` | Display string only; no device tracking | 🟠 PARTIAL |
| Sign out | — | settings | Auth | Labeled **"coming soon"** in code | 🔴 NOT BUILT |
| Score overlay | PulsScore breakdown (weather/safety/beach/traffic/air/events) | `#score-overlay` / `openScore()` | `pulsio_score` (has all sub-scores) | Source exists & live — **not wired**; breakdown is hardcoded. Note the score itself is only partly measured: traffic & air are placeholder constants, beach is derived from weather, events reads an empty table (see §5) | 🟡 HARDCODED |
| Emergency modal | Emergency numbers (999/114 etc.) | `#emergency-modal` | — | Static numbers | 🟡 HARDCODED |

---

## 2. Backend data pipeline ledger (Supabase)

Project `beyplrfqhfklylmmrxmw`. Row counts and freshness observed 2026-09-05.
**Pipeline source:** the `pulsio-backend` repo ([`pulseiomu-crypto/pulsio-backend`](https://github.com/pulseiomu-crypto/pulsio-backend)), running under pm2 on the owner's Mac Mini (`~/pulsio-backend`) — six parsers + runner + monitor + parse cache. Status below = observed output of that live process (not read from parser source in this pass; see caveat #2).

| Table | Purpose | Rows | Last write | Pipeline running? | Consumed by app? |
|---|---|---:|---|---|---|
| `pulsio_news` | Island news feed (has `lat`/`lng`, currently **never populated** — see §6 for the pinning design) | 499 | 2026-09-05 | 🟢 yes | 🟢 **yes** |
| `pulsio_weather` | Per-station weather (10 stations) | 16,904 | 2026-09-05 | 🟢 yes | 🔴 no (LIVE tab hardcoded) |
| `pulsio_score` | Computed PulsScore + 6 sub-scores (via `calculate_pulsscore`; 4 of 6 not really measured — see §5) | 1,692 | 2026-09-05 | 🟢 yes (computed) | 🔴 no (topbar `78` hardcoded) |
| `pulsio_ceb` | Power-cut outages | 146 | 2026-09-04 | 🟢 yes | 🔴 no |
| `pulsio_cwa` | Water supply issues | 0 | — | 🟢 yes (no active events) | 🔴 no |
| `pulsio_cyclone` | Cyclone bulletins | 0 | — | 🟢 yes (none active) | 🔴 no |
| `pulsio_fuel` | Fuel prices (mogas/diesel) | 2 | 2026-09-05 | 🟢 yes | 🔴 no |
| `pulsio_poi` | Points of interest (18 types: pharmacy, fuel, shelter, police…) | 942 | 2026-08-31 | 🟠 seeded, not on live cron | 🔴 no (map uses ~15 hardcoded markers) |
| `pulsio_marine` | Live ships (jsonb blob) | 0 | — | 🔴 empty | 🔴 no (markers hardcoded) |
| `pulsio_flights` | Live flights (jsonb blob) | 0 | — | 🔴 empty | 🔴 no (markers hardcoded) |
| `pulsio_events` | Events/happenings | 0 | — | 🔴 empty | 🔴 no UI |

> **Pipeline sources actively logging** (`pulsio_pipeline` run log, 10,157 rows): `news`, `weather`, `cwa`, `ceb`, `fuel`, `cyclone` — running roughly every ~10 min. `score` is computed on the same cadence. `poi` was bulk-seeded (last touched Aug 31). `marine`/`flights`/`events` have **no pipeline feeding them yet**.

---

## 3. Admin / monitoring layer ("NerveCentre" / Control Centre)

Migration `nervecentre_log_and_status` + the empty `Pipeline/Control Centre app admin/` folders (Frontend + Backend + Records) point to a planned internal ops console. The **database side exists and is being written to**; the **app side is not built** (folders empty, no code found).

| Table | Purpose | Rows | Status |
|---|---|---:|---|
| `pulsio_pipeline` | Per-run pipeline log (source, status, records, duration) | 10,157 | 🔵 BACKEND-ONLY |
| `pulsio_log` | System log (info/warn/error) | 12,194 | 🔵 BACKEND-ONLY |
| `pulsio_alerts` | Internal ops alerts (severity, resolved) | 872 | 🔵 BACKEND-ONLY |
| `pulsio_analytics` | Metric time-series | 1,264 | 🔵 BACKEND-ONLY |
| `pulsio_status` | Per-source health (operational/degraded/down) | 3 | 🔵 BACKEND-ONLY |
| `pulsio_errors` | Error capture | 0 | 🔵 BACKEND-ONLY |
| **Control Centre app** | Admin UI to view all the above | — | 🔴 NOT BUILT (folders empty) |

---

## 4. Users, billing & growth schema (built in DB, unused by app)

| Table | Purpose | Rows | Status | Notes |
|---|---|---:|---|---|
| `pulsio_users` | Account + tier + daily pulse quota + `stripe_customer_id` | 0 | 🔵 BACKEND-ONLY | `stripe_customer_id` is **legacy** from an early draft. Actual payment routing is decided: Apple IAP (iOS), Google Play Billing (Android), Paddle + NOWPayments (web). |
| `pulsio_profiles` | Profile: display name, type, district, tier, pulses, morning-pulse prefs, language, priorities, device count, `referral_hotel` | 0 | 🔵 BACKEND-ONLY | FK to `auth.users` — real auth was intended |
| `pulsio_pulses` | Log of each pulse fired (geo, tier, source app/api/scheduled) | 0 | 🔵 BACKEND-ONLY | `source='api'` implies a planned API; `'scheduled'` implies morning-pulse automation |
| `pulsio_reports` | Community reports (10 categories, confirmations, 2h expiry, geo, image) | 0 | 🔵 BACKEND-ONLY | Fully designed; frontend submit is a no-op toast |
| `pulsio_hotels` | Hotel partner program (slug, tracking code, tier starter/partner/premium) | 0 | 🔵 BACKEND-ONLY | Referral/QR growth channel — **no UI anywhere** |
| `pulsio_referrals` | Hotel → user referral + conversion tracking | 0 | 🔵 BACKEND-ONLY | Ties to `pulsio_hotels` + `referral_hotel` on profile |
| `pulsio_waitlist` | Marketing waitlist email capture | 1 | 🟢 (website) | Belongs to the marketing site, not the app |

---

## 5. Designed / promised but NOT built — flag list

These are features the product **promises** (in tier descriptions, schema, or folder structure) that have **no working implementation**. Per your warning, absence from code ≠ not part of the product — verify each against the design lock.

| Promised feature | Where promised | Reality | Status |
|---|---|---|---|
| **Live flights layer** | Tool bar, Traveller tier ("Flights") | `pulsio_flights` table empty; markers hardcoded (3 fake flights) | 🔴 NOT BUILT (data) |
| **Live marine/ships layer** | Tool bar, Traveller tier ("Marine") | `pulsio_marine` empty; markers hardcoded (3 fake ships) | 🔴 NOT BUILT (data) |
| **Live traffic** | Tool bar, LIVE tab | No traffic source table at all; markers hardcoded | 🔴 NOT BUILT |
| **Beach/lagoon intelligence** | GUIDE tab, Traveller tier ("Beach") | No model, no source table; all static | 🔴 NOT BUILT |
| **SMS alerts** | Resident tier | No SMS integration | 🔴 NOT BUILT |
| **History replay** | Resident tier | No implementation; time-series data does exist to support it | 🔴 NOT BUILT |
| **API access** | Pro tier; `pulsio_pulses.source='api'` | No API layer found | 🔴 NOT BUILT |
| **White-label / business analytics** | Pro tier | Not built | 🔴 NOT BUILT |
| **Morning Pulse delivery** | Onboarding, signup success ("we'll send you a morning pulse at 7am"), `source='scheduled'` | Prefs stored locally; no push/SMS/email delivery mechanism | 🔴 NOT BUILT |
| **Real auth** | Signup/login modals | localStorage flag only | 🔴 NOT BUILT |
| **Payments** | Upgrade + top-up | Stub in app; provider **decided** — Apple IAP (iOS), Google Play Billing (Android), Paddle + NOWPayments (web). Schema's `stripe_customer_id` is legacy from an early draft, not the plan. | 🔴 NOT BUILT (integration) |
| **Multi-language (fr/cr)** | Settings, `profiles.language` | English only | 🔴 NOT BUILT |
| **Hotel referral program** | `pulsio_hotels`/`pulsio_referrals`, `referral_hotel` | DB only, no UI | 🔴 NOT BUILT (app) |
| **Events layer** | `pulsio_events`, score `events_score`, onboarding | Table empty, no UI, no pipeline | 🔴 NOT BUILT |
| **Admin Control Centre / NerveCentre** | Folder + migration | DB side live; app not built | 🔴 NOT BUILT (app) |
| **Android app** | `App Frontend Android/` | Empty folder | 🔴 NOT BUILT |
| **iOS/Mac app** | `App Frontend IOS:Mac OS/` | Empty folder | 🔴 NOT BUILT (**this rebuild**) |
| **Marketing website** | `pulsio` repo `index.html` + pricing/privacy/terms/refunds + `pulsio_waitlist` | Landing pages exist in repo | 🟢 LIVE (separate from app) |

### Known gaps the ledger carries (stated as fact, not open questions)

- **No location layer exists anywhere in the app.** There is no geolocation, no "nearest X" logic, no district resolution. Yet many features *assume* one: nearest station for "your" weather, nearest shelter, nearest pharmacy, CEB cuts filtered to the user's district, and all preference/priority-based personalisation. This is a foundational build item, not a wiring gap.
- **PulsScore is only partly measured.** The `calculate_pulsscore` SQL function combines six components, but **four of the six aren't really measured**:
  - `traffic_score` and `air_score` — **hardcoded placeholder constants** inside the function.
  - `beach_score` — **derived from weather** (wind + UV), not independently observed.
  - `events_score` — read from `pulsio_events`, which is **empty**, so effectively a constant.
  - Only `weather_score` (and `safety_score`) reflect actual inputs. The headline PulsScore is therefore weather-dominated today; the six-factor breakdown shown in the UI overstates what's measured.
- **Several LIVE-tab fields have no source at all:**
  - `USD/MUR` exchange rate — no FX table, no pipeline source.
  - `Tide` and `Sea state` — no source table or feed.
  - `Sunset` — computable (astronomical), but nothing currently produces it.
  These are build-from-scratch, not disconnected feeds.

### ❓ Still open — confirm against the design lock

- **Pulse quota model** — free timer is 60s in code (`timerMs:60000`) but onboarding says "1 pulse per **day**" and schema has `pulses_reset_at` (date). Confirm the real quota/reset rule.
- **Segments vs POI `seg` field** — `pulsio_poi.seg` exists (audience tagging) implying POIs were meant to be segment-filtered from DB; confirm this is the intended source for the map (vs the hardcoded list).

---

## 6. News map pinning (design spec — NOT built)

**Status:** 🔴 NOT BUILT. `pulsio_news` has `lat`/`lng` columns but **nothing populates them today** — every news row currently lands with null coordinates, so no news can appear on the map. This section records the locked approach for how a news pin *should* be created, so it isn't lost again.

### The approach — extract with Claude, verify against the POI table

The news parser already makes a Claude call per article. That existing call gains **two fields**:

1. **Place name** — a Mauritian place explicitly named in the headline, if one is clearly mentioned.
2. **Confidence level** — how sure the extraction is.

Claude **must be allowed to return nothing.** Most articles (national politics, economy, sport) have no location, and a `null` is the *correct* answer there — not a failure to be filled in.

The extracted name is then **matched against `pulsio_poi`** — the real coordinate source. A pin is created **only on a match**:

- Match found → use the POI's verified `lat`/`lng` for the pin.
- Claude returns a name that **isn't** in the table → **no pin.** The model's own recollection of Mauritian geography is explicitly **not** treated as a source of truth; only the POI table's verified coordinates are.

This deliberately **mirrors the cyclone-shelter approach**: extract structured facts from unstructured text, verify against a real coordinate source, and record confidence per row.

### The coordinate source (`pulsio_poi`)

- Used as the verified place gazetteer: **793 real places** for matching, **including all 31 towns** with verified coordinates.
- *(Observed in DB 2026-09-05 for reconciliation: table holds **942 rows total, 806 active, all 942 geocoded, all 31 towns present**. The 793 is the intended verified-place matching set; the surplus rows are inactive/other-type POIs. Confirm which exact predicate defines the 793 before implementing the match.)*

### Constraints (locked — record these)

- **Unambiguous only.** Pin only where the location is unambiguous. Ambiguous or low-confidence extractions get **no pin**, never a guess. A wrong pin on a map people rely on **during emergencies** is worse than no pin at all. This is the governing principle.
- **Expected yield: ~⅓ of articles at most** are pinnable. A low pin rate is expected and correct, not a bug.
- **No new Claude call.** Location extraction **rides on the existing news Claude call** — do not add a second call. But note the cost asymmetry: **news is deliberately uncached and runs every cycle**, so unlike the other parsers, added tokens here are paid **on every run**. Keep the added prompt/output minimal.
- **Community reports need none of this.** Users tap the map to place a report, so `lat`/`lng` arrive with the submission — extraction/verification applies to news only, not `pulsio_reports`.

---

## 7. One-line summary per surface (for the rebuild triage)

- **News** → the only thing that actually works. Port it as-is (schema is stable).
- **ALERTS panel** → closest to pure wiring: all three sources exist and are live (`pulsio_ceb`, `pulsio_cwa`, `pulsio_cyclone`). Low risk.
- **LIVE panel** → mixed. The hard part (real data existing) is done for weather, score, fuel, CEB, cyclone — those are low-risk to consume. But ~4 displayed fields have **no source and must be built** (USD/MUR, tide, sea state, sunset), the PulsScore breakdown overstates what's measured, and showing "your" weather needs a **location layer that doesn't exist**. Not "just wiring."
- **GUIDE panel** → build. No beach/lagoon model or source exists; all static today.
- **Rebuild caveat** → none of the current HTML wiring carries into Swift. What the existing data sources buy you is **lower risk and fewer unknowns**, not less code — every consumer (Supabase client, models, decoding, UI binding) is written from scratch in the native app.
- **Map markers** → replace hardcoded array with `pulsio_poi` (942 rows, segment-tagged) + real flights/marine/traffic feeds (don't exist yet).
- **Pulse mechanic + PulseFX** → fully built client-side; needs server-backed quota (`pulsio_profiles`/`pulsio_pulses`).
- **Accounts / billing / reports / morning pulse** → schema ready, app side is stubs → **build**.
- **Admin Control Centre** → DB ready, app never built → **build**.
- **Pipeline** → **exists and runs**: `pulseiomu-crypto/pulsio-backend`, pm2 on the Mac Mini (`~/pulsio-backend`) — six parsers + runner + monitor + parse cache. Not in this repo and not on the MacBook Air, so read it there before the rebuild depends on its behavior.

---

*Compiled from `pulsio-app-v1_18.html`, Supabase project `beyplrfqhfklylmmrxmw` (24 tables, 5 migrations, 0 edge functions), and the on-disk Pulsio source tree. No fixes or plans proposed — ledger only, as requested.*
