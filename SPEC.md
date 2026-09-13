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
| **REPORT** tab | Pick category (10 types) + description, submit community report | `#tab-report` / `submitReport()` | `pulsio_reports` (write) | Table exists with full schema (confirmations, expiry, geo) — **not wired**; submit only fires a toast, writes nothing. **Full October definition in §11.** | 🟠 PARTIAL |

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
| `pulsio_cyclone` | Cyclone bulletins | 0 | — | 🟢 yes (none active) | 🔴 no — ⚠️ `class` check (0–5) is wrong vs official MMS classes; schema fix in §15 |
| `pulsio_fuel` | Fuel prices (mogas/diesel) | 2 | 2026-09-05 | 🟢 yes | 🔴 no |
| `pulsio_poi` | Points of interest (18 types: pharmacy, fuel, shelter, police…) | 942 | 2026-08-31 | 🟠 seeded, not on live cron | 🔴 no (map uses ~15 hardcoded markers) |
| `pulsio_marine` | Live ships (jsonb blob) | 0 | — | 🔴 empty | 🔴 no (markers hardcoded) |
| `pulsio_flights` | Live flights (jsonb blob) | 0 | — | 🔴 empty | 🔴 no (markers hardcoded) |
| `pulsio_events` | Events/happenings | 0 | — | 🟠 manual entry (NerveCentre, §13) — no scraping | 🟠 October: pulse panel + map (§13/§14) |

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
| `pulsio_reports` | Community reports (10 categories, confirmations, 2h expiry, geo, image) | 0 | 🔵 BACKEND-ONLY | Fully designed; frontend submit is a no-op toast. **Full October definition + moderation + schema deltas in §11.** |
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
| **Localisation (EN + FR)** | Settings, `profiles.language` | English only today; **French is in the October scope, Creole abandoned** (§22) | 🟠 PARTIAL (decided) |
| **Hotel referral program** | `pulsio_hotels`/`pulsio_referrals`, `referral_hotel` | DB only, no UI | 🔴 NOT BUILT (app) |
| **Events** | `pulsio_events`, score `events_score`, onboarding | Table empty; **now in October scope via manual entry in NerveCentre** (can't be scraped) — see §13 | 🟠 PARTIAL (decided) |
| **Admin Control Centre / NerveCentre** | Folder + migration | DB side live; app not built | 🔴 NOT BUILT (app) |
| **Android app** | `App Frontend Android/` | Empty folder | 🔴 NOT BUILT |
| **iOS/Mac app** | `App Frontend IOS:Mac OS/` | Empty folder | 🔴 NOT BUILT (**this rebuild**) |
| **Marketing website** | `pulsio` repo `index.html` + pricing/privacy/terms/refunds + `pulsio_waitlist` | Landing pages exist in repo | 🟢 LIVE (separate from app) |

### Known gaps the ledger carries (stated as fact, not open questions)

- **No location layer exists anywhere in the app.** There is no geolocation, no "nearest X" logic, no district resolution. Yet many features *assume* one: nearest station for "your" weather, nearest shelter, nearest pharmacy, CEB cuts filtered to the user's district, and all preference/priority-based personalisation. This is a foundational build item, not a wiring gap. **See §10 for the full location & district model — including the hard privacy rule (district only, never coordinates).**
- **PulsScore is only partly measured.** The `calculate_pulsscore` SQL function combines six components, but **four of the six aren't really measured**:
  - `traffic_score` and `air_score` — **hardcoded placeholder constants** inside the function.
  - `beach_score` — **derived from weather** (wind + UV), not independently observed.
  - `events_score` — read from `pulsio_events`, which is **empty**, so effectively a constant.
  - Only `weather_score` (and `safety_score`) reflect actual inputs. The headline PulsScore is therefore weather-dominated today; the six-factor breakdown shown in the UI overstates what's measured.
- **LIVE-tab fields without a source — now resolved by decision (§14):**
  - `USD/MUR` exchange rate and `Tide` — **dropped** from the pulse panel (no source, not worth building for October).
  - `Sunset` — **kept**, computed on-device from date + coordinates.
  - `Sea state` — **is** sourceable: MMS officially defines high (6–9m) / very high (9–14m) / phenomenal (>14m), so it comes from the cyclone/marine feed, **correcting the earlier "no source" note** (§15).
  - The freed rows are replaced with nearest CEB outage, community reports near you, cyclone status, and today's events (§14).

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

## 7. Panel behaviour (October scope)

**Status:** 🟠 TARGET DESIGN for October — differs from what's in `pulsio-app-v1_18.html` today (which has a fixed right panel with four tabs Live/Guide/Alerts/Report, and on mobile just widens that same panel to full width). Recording the locked October model so the rebuild targets it, not the current web layout.

### Desktop — one panel slot on the right
- There is **one** panel slot. **Filters live there by default.**
- The **report form** or the **pulse result** *replaces* the filters in that slot; **filters are restored when it closes.**
- The **report panel collapses rather than closes** — anything typed is preserved, never lost.

### Mobile — no sidebar
- **No sidebar.** Filters are a **collapsed chip.**
- Panels open as **bottom sheets** with **peek / half / full** detents (maps to iOS sheet detents — custom-small / medium / large).
- The detents exist so **the map stays visible after the pulse reveal** — the sheet never has to take the whole screen.

### v1 tabs: Live and Report only
- **Live** and **Report** are the only panel tabs for v1.
- **Alerts folds into the filters list** (not a standalone tab).
- **Guide returns later**, alongside the **itinerary builder** (see §9).

---

## 8. Apple HIG & App Store review compliance

Grounded in Apple's Human Interface Guidelines (read 2026-09-05 via the rendered pages at developer.apple.com/design/human-interface-guidelines — [Layout](https://developer.apple.com/design/human-interface-guidelines/layout), [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)) plus the App Store Review Guidelines for the enforced items. **Distinction that matters:** the HIG items below are *recommendations* Apple expects but rarely rejects for; the review items are *enforced at submission* — get them wrong and the app is rejected or crashes.

### HIG — recommended, and what affects our layout/build
| Item | Apple's guidance | Why it affects us |
|---|---|---|
| **Safe areas** | Respect system-defined safe areas, margins and guides; extend backgrounds/content to the display edges while keeping controls clear of the notch, Dynamic Island and home indicator. | Our full-bleed map + bottom fire dock + bottom sheets sit exactly where the home indicator and Dynamic Island are. Must use `safeAreaInsets` / `safeAreaLayoutGuide`. |
| **Minimum tap target** | Give every control a hit region of **at least 44×44 pt** (Accessibility). | Direct violation today (see below). Fire dock, tool bar, and dense LIVE rows must be resized. |
| **Sheet detents** | iOS sheets can be resizable (grabber, medium/large/custom detents); a **nonmodal** sheet lets people keep interacting with the parent view without dismissing it. Show one sheet at a time; use full-screen for complex/prolonged flows. | This is exactly the peek/half/full mobile model in §7 — implement with `presentationDetents`; nonmodal so the map behind stays interactive. |
| **Navigation patterns** | Use platform-standard navigation; place primary/back/close controls per platform convention (Cancel leading, Done trailing on sheets). | The report/pulse sheets and settings must follow standard sheet button placement, not the web app's custom `✕` chrome. |
| **Dynamic Type** | Support Dynamic Type so text scales to the user's chosen size; avoid fixed font sizes. | The web app is built on **fixed pixel sizes** (`text-[10px]`, `text-[11px]`, mono numerics). Native build must use text styles that scale. |

### App Store review — ENFORCED (not optional)
- **Account deletion** — *if we offer signup*, the app must let users **initiate account deletion from within the app** (Review Guideline 5.1.1(v)). We plan signup → this becomes mandatory.
- **In-App Purchase for digital goods** — pulse packs / tier subscriptions are digital goods and **must use Apple IAP** on iOS (Guideline 3.1.1); can't route iOS users to Paddle/NOWPayments for them. (Consistent with the payment routing in §4/§5.)
- **Privacy manifests + Nutrition Labels** — a `PrivacyInfo.xcprivacy` privacy manifest (declaring data collection and required-reason API use) and accurate App Privacy labels are required at submission.
- **Permission purpose strings** — every permission needs an `Info.plist` usage-description string or the app is rejected/crashes. **Location especially**: `NSLocationWhenInUseUsageDescription` (and a justified reason for any Always/background use). Apple scrutinises location at review, and users frequently decline it — see §9.

### Current layout is non-compliant (evidence)
- **Tap targets under 44pt** — tool-bar buttons are `min-w-[42px]` with `py-1` (~26–30pt tall); pulse counter `min-w-[28px]`; many LIVE/ALERTS tap rows are `text-[10px]/[11px]` single-line. All below 44×44 pt.
- **No safe-area handling at all** — zero `safe-area-inset` / `env(safe-area-inset-*)` usage; the viewport meta is `maximum-scale=1.0, user-scalable=no` with **no `viewport-fit=cover`**, so insets aren't even available and pinch-zoom is disabled (an accessibility problem in its own right).
- **No Dynamic Type** — all type is fixed-pixel.

> These are expected for a web prototype; they're logged here because the **native rebuild must fix them from the start**, not retrofit them.

---

## 9. November itinerary release (planned — NOT October scope)

**Status:** 🔵 PLANNED for the November itinerary release. Explicitly **not** in October scope. Recorded so it isn't lost.

- **Itinerary builder** — returns the **Guide** surface (see §7).
- **Live Activities + Dynamic Island** — show the **current stop and next stop** at a glance without opening the app.
- **Navigation hand-off** — hand off to **Apple Maps or Google Maps** for turn-by-turn; the **itinerary advances automatically** as the user reaches each stop.

### Constraints (record these)
- **Breaks platform parity.** Live Activities and Dynamic Island are **iOS-only** — no Android or web equivalent. This is the **first feature that breaks parity** across platforms; Android/web will need a different (lesser) treatment or none.
- **Requires background location + geofencing.** Auto-progression means detecting arrival at each stop **while the maps app owns the screen** after hand-off — so it needs **background location and geofencing**, not just when-in-use. Apple **scrutinises this permission at review** (§8), and **users often decline** it, so the feature must degrade gracefully when background location isn't granted (fall back to manual "next stop").

---

## 10. Location & district model

**Status:** 🔴 NOT BUILT — and **foundational**. Nothing in the app currently knows where the user is, yet many features assume it: nearest weather station for "your" temperature, nearest shelter, nearest pharmacy, CEB/CWA alerts for the user's district, and preference-based personalisation. This must be **designed in, not retrofitted.** (`pulsio_profiles.district` already exists — nullable free `text`, no default, **no check constraint** — but nothing sets it; the settings "District" control is a toast today.)

### The model — one field, source-agnostic
- The only location state is a **single `district` field** on the user's profile, valued as **one of Mauritius's nine districts**.
- **GPS fills it automatically when granted; the user picks it manually when not.**
- Everything downstream **reads that one field** — features don't care, and can't tell, which way it was set.
- The nine districts (constrain the column to these — it's currently unconstrained): **Port Louis, Pamplemousses, Rivière du Rempart, Flacq, Grand Port, Savanne, Plaines Wilhems, Moka, Rivière Noire (Black River).**
  *Applied 2026-09-13:* `pulsio_profiles.district` is CHECK-constrained to exactly these nine, spelled as the pipeline already writes them (`'Black River'`).

### Rodrigues — out of scope at launch (decided 2026-09-13)
- **PulsIO covers the main island at launch.** Rodrigues is a later addition, **once there is POI coverage worth having** — half-serving it would be worse than not claiming to. **The district list stays at nine.**
- **Consequence today:** the pipeline writes `pulsio_ceb.district = 'Rodrigues'` (9 rows at the time of writing). Those rows are simply **unreachable by district** — no profile can select Rodrigues, so no alert query matches them. They are harmless and must stay harmless: **every client model that carries a district decodes unknown values as `nil` rather than failing the row** (see `contracts/enums.json` → `district`), so a Rodrigues row never breaks a page of results. Do not add a CHECK on `pulsio_ceb.district`; the parser is external (§2 caveat) and the rows are correct data, just out of scope.
- **If Rodrigues is ever added:** the POI data must be built out first (shelters, hospitals, fuel, pharmacies, beaches — the same categories, with the same precision discipline as §19) — **not** just a tenth district value. Adding the option without the data would show an empty island with live alerts and nothing to act on.

### 🔒 Privacy constraint — HARD RULE (non-negotiable)
- **Store the district only. Never coordinates.** The server sees **one of nine district values, nothing finer** — ever.
- The app **may show the user their own live position** on the map (standard blue dot — their own data, shown back to them). Raw coordinates are **never sent to or stored on the server.**
- **Proximity is computed on-device.** Nearest shelter, nearest pharmacy, nearest weather station — all computed **on the device from the local POI data**; only the *result* is used. Coordinates never leave the phone.
- **Rationale (record):** Mauritius's **Data Protection Act 2017** is GDPR-modelled with an active Commissioner, and location is **personal data** under it. Storing continuous position would require a lawful basis, genuine consent, data minimisation and a retention policy — and **no v1 feature actually requires it.** District-only is **proportionate, defensible, and leaks nothing.** Revisit only for the **November itinerary live-tracking feature (§9)**, which will need proper legal review and a privacy policy regardless.

### Flow
1. **Onboarding explains why location helps** — *before* any system prompt.
2. **System permission request is asked in context, at the point of first use** — not cold on an early onboarding screen. Per Apple's HIG (§8), in-context prompts are declined far less often.
3. **Granted →** district is set automatically (derived on-device from GPS, then only the district string is stored).
4. **Declined →** show the district picker with **honest framing**, verbatim:
   > "PulsIO works best when it knows where you are. Without it, pick your district and we'll show alerts and conditions for that area."

   **Do not** tell users features will be unavailable — it isn't true when a fallback exists, and coercive permission framing is an **App Store review risk** (§8).
5. **District is editable in settings, permanently** — including for users who granted location. A tourist may want conditions where they're *headed*, and GPS near a district boundary can be wrong.

**If a user declines *and* skips the picker:** features that genuinely need a district show a **quiet inline prompt at the point of use** — "Set your district to see alerts near you" — rather than failing silently or nagging.

### What the district-only fallback still supports
| Feature | Works at district precision? | How |
|---|---|---|
| CEB power-cut alerts | ✅ | Published by district anyway (`pulsio_ceb.district`) |
| CWA water alerts | ✅ | Published by district anyway (`pulsio_cwa.district`) |
| "Your" weather | ✅ | Nearest of the **10 stations**, chosen on-device |
| Nearest shelter / pharmacy | ✅ | Computed on-device from local POI data |
| Community reports | ✅ (no location needed at all) | User taps the map to place them — lat/lng arrive with the submission (see §1) |

**What's lost without live coordinates:** sub-district precision and live tracking — **neither critical for v1.**

### Implementation notes
- **On-device proximity requires the POI set on the device.** Because "nearest X" is computed on the phone (the privacy rule forbids sending coordinates to the server), the app needs a **local copy of the POI set** (the ~806 active POIs) — the server can't answer "nearest shelter" for coordinates it's not allowed to receive.
- **Sync it, don't fetch per query.** The local POI copy should be **synced and cached on the device** (refreshed when the POI table changes), not fetched from the server on every proximity lookup — per-query fetching would be slow, would defeat offline use, and puts a location-shaped request pattern back on the network.
- **This local copy is the foundation of the offline mode we deferred.** A device-resident POI store + last-pulse cache *is* the offline substrate. So build the **sync layer properly** (versioned, incremental, resilient) rather than as a shortcut — it pays for both proximity now and offline later, and there's already an offline banner in the app anticipating it (see §1).
- **Constrain `district` to an enum of the nine districts.** The column is currently nullable free `text` with no check — it should be an enum / check-constrained to the nine district values, so bad or free-typed values can't enter and downstream reads are safe.

### Record for later
- **Manually-picked districts go stale** — tourists move between districts. Worth a **gentle prompt to update**, or **re-offering location** once the user has seen the value. (Ties to the November tracking work in §9, which is where finer location would be reconsidered — under legal review.)

---

## 11. Community Reports (October launch — full definition)

**Status today:** 🔴 stub. `pulsio_reports` has a full schema but 0 rows; the app's Report tab only fires a toast and writes nothing (§1, §4). This section is the **October build definition** — the feature ships in the launch cut.

### Submission is device-only (iPhone + iPad) — by design
Reporting **requires a camera and being physically at the incident**: you report a flooded road standing in front of it, not from a laptop. So:
- **iPhone and iPad create reports.** iPad qualifies — it has a camera and GPS, and Vision face-blurring works identically; the rule that matters is "camera + at the location," which iPad satisfies.
- **Desktop and web display reports on the map normally but cannot create them.** Where the report button would be, show a short line: *"Reports are submitted from the PulsIO mobile app."*
- **This is the first deliberate exception to the web-parity rule** — chosen, not a gap. Parity is the default; this is an intentional, documented divergence because the capture context only exists on a device with a camera in hand at the scene.

### Submission flow (iPhone + iPad)
1. Tap **Report**.
2. Pick **one of the ten locked categories** — icon grid, one tap (power_cut, water_cut, accident, hazard, flood, traffic, jellyfish, event, infrastructure, other).
3. **Map opens with a pin at current location, draggable** to correct it. (This is the one place raw coordinates are sent — the user explicitly places them; consistent with §10.)
4. **Take or attach a photo.**
5. Optional **one-line description**.
6. **Submit.**

**Photos are required in spirit** — Meg's position is the feature is useless without them. Treat a photo as effectively mandatory (a report without one is low-value and should be discouraged in the UI).

**Reports may be featured.** Good community reports are posted to PulsIO's own Instagram daily (the acquisition channel, §16). Add a line to the submission flow noting a report **may be featured**, and route anything to be amplified through the moderation layer first (§16).

### Photo handling — on-device, before upload
All of this happens **on the phone before anything is uploaded**:
- **Resize to ~1600px (~200KB).** Camera originals run 2–4MB and would burn Supabase storage and the user's mobile data.
- **Detect and blur faces** using Apple's **Vision framework** — native, free, offline. Because it runs on-device, **the unblurred original never leaves the phone**, which is the correct position under Mauritius's Data Protection Act 2017 (§10).
- **Optionally blur detected text regions** to catch number plates. This **will over-blur** (shop signs, etc.) — that is the **safe failure** for a two-hour incident report.
- Show a brief line in the submission UI **asking users not to photograph people.**
- ⚠️ **Claude cannot blur images** — it can only *describe* what's in them. The blurring **must be on-device** (Vision), never delegated to the moderation model.

### Three-layer moderation — a real system, not an afterthought
This is an **asset at exit**: acquirers worry about inheriting user-generated-content (UGC) liability, and a documented, working moderation stack is what de-risks that.

1. **Automatic (model).** Every photo passes a **Claude vision check before it goes live**: does it match the claimed category, does it contain identifiable people the blur missed, is it inappropriate. Cost ≈ a few cents per report. Fail → held from publish / routed to the operator queue.
2. **Community.** The existing **two-confirmation** mechanic to publish, **plus a flag action on every report**. **Two flags auto-hide** a report pending operator review.
3. **Operator.** A **moderation queue in NerveCentre** (§3): *pending*, *flagged*, *recently published*, with **one-tap remove** and **block-user**.

### `pulsio_moderation` — audit trail (new table, to add)
Log **every** moderation decision — the audit trail due diligence asks for. Proposed shape:

| Column | Type | Notes |
|---|---|---|
| `id` | bigint PK | |
| `report_id` | bigint FK → `pulsio_reports` | |
| `layer` | text | `auto` / `community` / `operator` |
| `actor` | text/uuid | model id, or flagging user's id, or operator id |
| `model_result` | jsonb | what the vision model returned (category match, people-detected, verdict, scores) |
| `action` | text | `published` / `held` / `flagged` / `auto_hidden` / `removed` / `user_blocked` |
| `reason` | text | free text / reason code |
| `created_at` | timestamptz | default `now()` |

**Related schema deltas on `pulsio_reports`:** add flag tracking (`flag_count int`, `flagged_by uuid[]`) and an **auto-hidden** state distinct from operator-removed (extend the `status` check with `hidden`; `removed` stays for operator action). **Block-user** sets a blocked flag on the profile so a blocked user's new reports are rejected/auto-hidden.

### Confirmation radius
A report is **confirmable only within 2km of the original pin.** District is too coarse — a Grand Baie report shouldn't be confirmable from the far side of Rivière du Rempart. (Distance is computed on-device from the confirming user's location; only the confirm action reaches the server.)

### Where reports appear
- **On the map** — as pins (published/confirmed only).
- **In the pulse result panel** — a summarised line, e.g. *"3 community reports near you"* (§ pulse result / FRONTEND §E).

### App Store review — UGC requirements (must be implemented, not just specced)
Apple requires any app with user-generated content to provide: **(1) a way to report objectionable content, (2) a way to remove it, and (3) the ability to block a user.** The three layers above satisfy all three — flag action (report), operator remove (remove), block-user (block). **Verify these are actually shipped and functional, not just written down here** — this is checked at review.

---

## 12. Segments (scope model)

**Decision:** replace the four-tab segment row (All / Tourist / Mauritian / Pro) with a **single pill in the top bar** showing the current mode; tap → a **sheet** to switch.
- Available modes are selectable; **Pro sits at the bottom with a lock** and one line on what it unlocks. Tapping Pro **opens the upgrade flow** (§18/upgrade).
- **Why a lock, not a greyed-out tab:** a greyed tab reads as *"this app is limited"*; a designed lock reads as *"there's more here."*
- **Segment becomes the parent scope**, with **filters nesting under it and showing live counts.** This makes the **empty-map problem structurally impossible** — you always see the scope's populated layers.
- Reclaims **~37px of mobile chrome** (the tab row).
- The **"remove ads" upgrade prompt should live in this moment** (selling T1 at the point of intent) rather than relying on the ad slot to do the selling.

---

## 13. Events (manual entry via NerveCentre)

**Decision:** events are **entered manually in NerveCentre** (§3) — Mauritian events live on Instagram stories and DMs and **cannot be scraped**. `pulsio_events` exists; it needs an admin form and app surfaces, both in the October cut.

**Events form (NerveCentre):** name · venue **or** location (click-to-place, like POIs) · start + end datetime · category · description · source link · active flag · **recurrence** (so "every Saturday" is entered once, not 52 times).

**Behaviour:**
- Events **auto-expire once they're over** (per end datetime / recurrence rule).
- **Today's events appear in the pulse result panel** (§14) and on the map.

---

## 14. Pulse result panel — composition & preference curation

**Row composition (October).** Four rows had no data source; resolved:
- **Drop** `USD/MUR` and `Tide` (no source, not worth building now).
- **Keep** `Sunset` — computed on-device from date + coordinates.
- **Replace** the rest with: **nearest CEB outage**, **community reports near you** ("3 near you", §11), **cyclone status** (§15), and **today's events** (§13).
- Retained sourced rows: temperature/feels-like/humidity/wind/UV (`pulsio_weather`, nearest station on-device), PulsScore (`pulsio_score`), fuel (`pulsio_fuel`), **sea state** (MMS-defined, §15).

**Preference-based curation — in scope for October.** Onboarding already collects preferences (§ onboarding), so **not using them is worse than not asking.**
- Preferences **reorder** the snapshot, they don't **filter** it: a commuter sees traffic first; a fisherman sees sea conditions first.
- **Default order** (signed-out, or anyone who skipped onboarding): **cyclone and outages first** (the urgent items), then weather, then the rest.
- Curation is pure ordering by stored priorities — it needs **no location** and no server round-trip.

---

## 15. Cyclone terminology & MMS wording

**Decision:** use the official **Mauritius Meteorological Services (MMS)** wording **exactly**. Record it here so the app and pipeline agree.

**Cyclone warning classes** (roman numerals):
- **Class I** — issued 36–48 hours before gusts of 120 km/h are expected.
- **Class II** — allows 12 hours of daylight before those gusts.
- **Class III** — allows 6 hours of daylight before.
- **Class IV** — gusts of 120 km/h recorded and expected to continue.
- **Safety Bulletin** — issued when lifting Class III or IV.
- **Termination** — risk abated, cyclone moving away.

**Storm classification** (separate axis from warning class):
tropical depression (51–62 km/h) · moderate tropical storm · severe tropical storm · tropical cyclone (118–165) · intense tropical cyclone (166+) · very intense tropical cyclone.

**Rain warnings:** heavy rain (25mm in 30 min) · heavy rain watch (issued 12–24 h ahead) · torrential rain (100mm widespread, continuing several hours).

**Sea state (officially defined → sourceable from MMS):** high (6–9m) · very high (9–14m) · phenomenal (>14m). This **corrects the earlier "sea state has no source"** note (§5) — it feeds the pulse panel (§14).

**⚠️ Schema fix required (`pulsio_cyclone`).** The `class` column is an integer check **0–5**, which does not match the official model. It needs to represent **warning class** (I–IV + Safety Bulletin + Termination) **separately** from **storm classification** (the six-step scale above) — i.e. two enum-constrained fields, not one 0–5 int. **This is a live table fed by the external `pulsio-backend` pipeline (SPEC caveat §2), so the migration and the parser must change together** — do not alter the constraint in isolation. *(Recorded here as a required change; not applied in this pass.)*

---

## 16. Shareable cards (the acquisition channel)

**Decision:** shareable cards are **the acquisition channel**, treated as a first-class feature — **three types**:
1. **Pulse result card** — the snapshot.
2. **PulsScore card** — **needs rebuilding**: it's currently hardcoded to `78` and shares as **plain text**, so it **cannot reach Instagram Stories at all** (§ PulsScore).
3. **Community report card** — for a specific incident (§11).

**Rules:**
- Cards stay **separate**, but the user can choose to **share more than one at once**.
- **All export as real images, not text**, carrying the **PulsIO name** and a **way back** for whoever receives it (link / QR).
- Produce a **1080×1920 Instagram-Stories** version **alongside** a **WhatsApp-shaped** one.
- These cards go on **PulsIO's own Instagram daily**, along with good community reports (§11) — so the report submission flow notes a report **may be featured**, and the **moderation layer (§11) checks anything before it's amplified.**

---

## 17. Device limits (stated, not enforced for October)

**Decision:** keep **"up to 3 devices"** as a tier benefit on the pricing page, but **do not build enforcement** for October.
- Enforcement needs device registration + management; **Apple restricts persistent identifiers**; and at MUR 150–400 **account sharing isn't a meaningful leak**. A legitimate user hitting a wall after changing phones costs more in support than the sharing does.
- **Do build "sign out of all devices"** in settings — that covers the real security case cheaply.
- **Revisit with evidence** if abuse actually appears. (Supersedes the device-count enforcement implied by the tier table in §3.)

---

## 18. Top-ups & subscriptions (IAP)

**Decision:** top-ups are offered on the **spent screen**, but **subscriptions lead** and top-ups are secondary — *"Traveller gives you 10 every month for MUR 150"* first, *"or buy 5 now for MUR 75"* beneath. Top-ups **cannibalise recurring revenue** if pushed too hard.
- **StoreKit types:** top-ups are **IAP consumables**; subscriptions are **auto-renewables**.
- **Critical:** because top-ups **never expire**, the balance **must be stored server-side against the account** (`pulsio_profiles.pulse_topup_balance` already exists), **not on the device** — otherwise a reinstall loses it, which becomes a refund request.

---

## 19. Shelters (verified vs approximate)

**Decision:** shelters are normally a POI category users toggle on; **during an active cyclone warning they become prominent** — surfaced in the pulse panel (§14), **shown on the map by default**, and **reachable without signing in** (per the emergency-unlock rule, § emergency).

**Precision split** (`pulsio_poi` type `shelter`, 149 rows = 13 + 136):
- **Only the 13 verified shelters appear as map pins.**
- **The 136 approximate ones appear in the searchable list only** (§20) — name, village, phone number, **no pin** — clearly labelled *"location approximate, call to confirm."*
- **Schema (added 2026-09-13):** `pulsio_poi.location_precision` ∈ {`exact`, `approximate`}. Previously `active = false` doubled as "approximate", which search couldn't tell apart from "closed"; now `active` means open/closed and `location_precision` means pin-worthy or not. All 149 shelters are `active`; 13 are `exact`.
- This gives users everything we know **without implying precision we don't have.**
- **NerveCentre task:** verifying an approximate shelter is a ~2-minute satellite check each — a good **pre-cyclone-season** job to delegate.

---

## 20. Search & the POI pin/search split

**Principle:** 942 POIs plotted at once would bury the live signals. **You browse a beach; you search for a pharmacy.**

**Pinned on the map:** beaches, landmarks, waterfalls, hikes, parks, viewpoints, airport, ferry terminals, marinas, hospitals, **verified shelters** (§19).

**Searchable only (no pins):** pharmacies, supermarkets, malls, police stations, clinics, towns.

**Toggleable layer, off by default:** fuel.

**Emergency-only (decided 2026-09-13):** helipads. Hidden normally; **plotted while a cyclone warning or emergency is active** (`pulsio_emergency_state`), the same trigger that makes shelters prominent (§19). **General pattern:** emergency-relevant categories surface during emergencies rather than cluttering the map the rest of the time — add future categories (e.g. evacuation points) to this list, not to the always-on set. Shelters: only rows with `location_precision = 'exact'` are ever pinned; the 136 approximate ones are search-only (§19 — a wrong shelter pin during a cyclone is dangerous). Not surfaced anywhere by this section: restaurant, hotel, market, other.

**Semantic colour:** see §24.

**Search surface:** find POIs by **name or category**, **sorted by distance**, each result showing **distance** and tapping through to the map. Distance is computed **on-device** (location privacy rule, §10). Search is also **where the 136 approximate shelters live** (§19).

---

## 21. Error & status messaging (P / U / S codes)

**Principle (final wording is a later copy pass, done in one go with the rest of the app's text):** the user sees **plain language and what to do about it**, with the **code small and muted underneath** — not *"Error P-103"* but *"You've used today's pulse. Next one at midnight."* with `P-103` beneath.
- **P codes** — mostly **expected states**; informative, **never alarming**.
- **U codes** — **always offer a next step**.
- **S codes** — **our fault**: apologise briefly, say whether it's temporary, and if **NerveCentre has posted a status notice** for that source (`pulsio_status`), **show that** instead of a generic message.

---

## 22. Localisation (English + French)

**Decision:** **English and French at launch; Creole is abandoned.**
- **Approach:** machine-translate, then have a **French-speaking Mauritian review** — pure machine translation reads wrong in ways native speakers notice, and clumsy French would undercut an app claiming to be for Mauritius.
- **Crucial:** **externalise all strings from day one in both codebases** (app + NerveCentre). Hardcoded strings would make any future language an archaeology project.
- **Meg's phrasing to honour:** *"se faire connaître"* (not *"notoriété"*); *"gagner en crédibilité"* (not *"adaptation rapide"*).

---

## 23. One-line summary per surface (for the rebuild triage)

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

## 24. Semantic colour (record)

Colour is meaning, not decoration. The one mapping, used by both clients (`DesignSystem/Semantics` on iOS):

| Colour | Token | Meaning |
|---|---|---|
| Sky `#4AB8FF` | `sky` | weather and marine conditions (humidity, sea state) |
| Amber `#F5A623` | `amber` | warnings (temperature extremes, CEB/CWA cuts) |
| Coral `#FF5A5A` | `coral` | danger and emergency — LIVE/alerts, hospitals, cyclone shelters |
| Green `#3ED96E` | `green` | good/safe, and fuel |
| Purple `#B09AFF` | `purple` | events, and Pro |
| Teal `#00D4A8` | `teal` | brand, live/active state, and tourist POIs (beaches, landmarks, waterfalls, hikes, parks, viewpoints) |
| White `#FFFFFF` | `transport` | **transport infrastructure** — airport, ferry terminals, marinas, flights (decided 2026-09-13; white reads as infrastructure rather than a condition, and is what the HTML app used for flights) |
| Bone @ 0.55 | `muted` | neutral / search-only categories |

Neutral hairlines stay neutral; teal is rationed to live/active (RESTYLE-NOTES §1).

---

*Compiled from `pulsio-app-v1_18.html`, Supabase project `beyplrfqhfklylmmrxmw` (24 tables, 5 migrations, 0 edge functions), and the on-disk Pulsio source tree. No fixes or plans proposed — ledger only, as requested.*
