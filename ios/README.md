# PulsIO — iOS

SwiftUI app, structured per [`../ARCHITECTURE.md`](../ARCHITECTURE.md) §4.

## Build & run

```sh
brew install xcodegen        # once
cd ios && xcodegen           # generates PulsIO.xcodeproj from project.yml (the .xcodeproj is git-ignored)
open PulsIO.xcodeproj        # then ⌘R on any iPhone/iPad simulator
```

CLI equivalent:

```sh
xcodebuild -project PulsIO.xcodeproj -scheme PulsIO -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project PulsIO.xcodeproj -scheme PulsIO -destination 'platform=iOS Simulator,name=iPhone 17' test
```

`project.yml` is the source of truth for the project; **do not** hand-edit the generated `.xcodeproj`
(re-run `xcodegen` after adding files or targets). Supabase URL/key and the signing team live in
`Config/Shared.xcconfig`. Simulator builds need no team; device builds and archives do.

## Layout (departments)

```
PulsIO/
  App/            shell: @main, composition root (AppEnvironment), navigation registration (RootView)
    Session/      app-level state: SessionStore (auth + profile + emergency flag), AccessPolicy, AccessGate,
                  DistrictStore (the one location field: district + how it was set), PulseStore (today's quota + spend)
  Contracts/      row models + fixed enums mirroring the schema / contracts/*.json — not feature code
  Data/           the ONE data department: SupabaseGateway + repositories (all network here)
    Auth/         AuthRepository — the only file that knows Supabase Auth
    Sync/         POISync — pulls poi_changes_since deltas into the POIStore
  Platform/       device services: Auth/AppleSignInNonce, POIStore/ (GRDB on-device POI set),
                  Location/ (LocationService — CoreLocation; DistrictResolver — GPS→district on-device)
  Map/            MapSurface protocol (project/unproject/camera/markers) + MapLibreSurface (the only MapLibre import) + MapStyle
  PulseFX/        the ceremony: Choreography (pure timing/motion), Terrain (baked heightmap), Renderer (pure render(t)),
                  Controller (camera/marker side effects), Overlay (TimelineView + Canvas)
  DesignSystem/   tokens (Palette, Typography, Metrics), components, semantic mappings — the finish, once
  Features/       one folder per screen: View + ViewModel; a feature knows its repository, nothing else
  Localization/   Localizable.xcstrings (EN + FR) — no string literals in views
  Resources/      Info.plist, entitlements, asset catalog
PulsIOTests/      unit tests (Swift Testing)
PulsIOUITests/    simulator smoke tests (XCUITest); some steps opt in via env — see AuthSmokeTests
```

All departments from ARCHITECTURE §4 now exist.

## The pulse

**Rules live in Supabase** (migration `pulse_rules`), so web behaves identically:
- `pulsio_tier_rules` — Explorer 1/day · Traveller 10 · Resident ∞ · Pro ∞ (plus ads/device max), public-read.
- `pulse_status()` — where the caller stands: tier, used today, quota remaining, top-up balance, next reset,
  `can_pulse`. Quota is **derived from the pulse log** (pulses paid from quota since Mauritius midnight) — no
  counter to reset, no cron (none is installed; `reset_daily_pulses()` was never scheduled).
- `consume_pulse(p_district)` — serialised per user; pays from quota, then from `pulse_topup_balance`
  (server-side, never on the device — SPEC §18); logs to `pulsio_pulses` with `paid_from`; raises `P-100`
  (sign in) / `P-103` (spent) in the Postgres error detail, mirrored in `contracts/errors.json`.
- `pulsio_pulses` has a CHECK that `lat`/`lng` are null: a coordinate can never be logged (SPEC §10).
- Granting top-up credits is the IAP server-verification job — not built yet; the spend side is.

**Client:** `PulseStore` (refresh/fire/countdown) → `PulseDock` (button with the liquid core at rest,
PULSE label, "N available" / "Spent · next hh:mm" / "Sign in to pulse") → `AccessGate.perform(.firePulse)`
→ `consume_pulse` → the ceremony → `PulseSpentSheet` on P-103.

**Onboarding (FRONTEND §A).** Five steps in `Features/Onboarding`: intro (BrandMark + Wordmark over
`Atmosphere` — the web's glows, 25 drifting motes and CRT scanline, all deterministic, still under Reduce
Motion) → what is a pulse (the real idle liquid core) → what matters to you (user type + up to 3 priorities
as `SelectableChip`s with SF Symbols, no emoji) → why location helps (explanation only; the system prompt
stays in-context at the locate button, SPEC §10) → the map in four beats. Skippable from step two. Rendered
as an overlay (not a presentation) so it is on screen from the first frame; iPad gets the centred card.
`PreferencesStore` holds user type, priorities and completion on the device (onboarding runs signed-out) and
reconciles to `pulsio_profiles` on sign-in — profile wins if it has priorities, else the device's are pushed.
The pulse panel reads priorities from this store. UI test: `OnboardingTests` (needs a fresh install).

**The result panel (SPEC §14, ARCHITECTURE §6).** `pulse_snapshot(p_district, p_station, p_priorities)`
assembles and ORDERS the rows server-side and returns them as JSON; `PulsePanelView` renders them
generically (label/detail are localisation keys, values carry unit codes, tone is a §24 token) — adding a
sourced row is a change in the function, not in the clients. The three client-side inputs (§10.6) are
passed in: the district (`DistrictStore`), the nearest of the 10 weather stations (picked on-device from
`weather_stations()` against the last fix or the district's POI centroid), and the profile's priorities
(reorder, never filter; default = cyclone, outages, reports, weather, score, fuel, events, sunset). Sunset is
a `computed` row the server orders and the device fills (`Platform/Sun/SunCalculator`). Cyclone wording is
the MMS vocabulary in `contracts/enums.json` (`mms.*` keys). Hosting (SPEC §7): compact widths get a bottom
sheet with peek/half/full detents and background interaction so the island stays visible; regular widths get
the right-hand panel slot. Opt-in UI test: `TEST_RUNNER_PANEL_FLOW=1` (+ `PANEL_FIRST_ROW=<key>` to assert
the reorder) on a signed-in simulator with a pulse available.

**PulsScore & share cards (SPEC §16).** `pulsscore_breakdown()` returns the latest score with the six
components, each carrying `weight`, `score`, `basis` (measured / derived / placeholder) and tone, plus a
`verdict_key` (named bands in `contracts/enums.json`). `calculate_pulsscore()` was fixed to count only live
CEB outages and the Mauritius day for events. `PulsScoreRing` draws weights as arc lengths (30/25/20/10/8/7)
filled to each score in its semantic colour; basis is line style — solid / reduced opacity / dashed — so the
honesty is in the drawing, and the screen and card both say "3 of 6 factors are measured live today".
Cards: `Features/Share` — `CardChrome` (wordmark, LIVE date/district, footer with pulsio.mu + QR tagged
`?ref=card&t=<type>`), `PulsScoreCard`, `PulseResultCard`, `ReportCard`, rendered by `ImageRenderer` at 3×
to exactly 1080×1920 (Stories) or 1080×1080 (WhatsApp), shared as PNGs via `ShareLink` (several at once).
`ReportFeatureNotice` carries the "may be featured, moderated first" copy for the report form to come.
Debug builds: `SHARE_REPORT_SAMPLE=1` adds a sample report card to the panel's share sheet. Unit tests render
all six cards and check pixel sizes; set `TEST_RUNNER_CARD_OUTPUT_DIR` to keep the PNGs.

**PulseFX — the port.** 1:1 from the web module: ten phases over 7.45 s, `render(t)` a pure function of
time drawn into a SwiftUI `Canvas` inside `TimelineView(.animation)`. No Metal: the terrain wave is vertex
displacement (three 220-point rings sampled from the heightmap, masked to the baked island silhouette with
`clipToLayer`), not per-pixel; the only per-pixel work is the one-off bake of mask + hillshade relief. The
metaballs use `alphaThreshold ∘ blur` on the discs' composite (filters apply in reverse order of addition)
plus an un-thresholded halo pass and a `clipToLayer`-confined sheen. `project`/`unproject` come from
`MapSurface` per frame — the entire map dependency. Camera out/in and marker lighting (pins light as the
wavefront reaches them, via a `lit` feature attribute) are side effects in `PulseFXController`, outside
`render(t)`. Reduced Motion skips the ceremony. Debug builds accept `PULSEFX_PREVIEW=1` to play it without
spending. Opt-in UI test: `TEST_RUNNER_PULSE_FLOW=1` on a signed-in, unspent free-tier simulator.

## Map & POIs

- **Basemap**: ESRI World Dark Gray canvas (raster, keyless; Carto's keyless tiles are watermarked now),
  darkened toward the palette in `Map/MapStyle.swift`. Max zoom 16 (ESRI's limit).
- **POIs live on the device** (`Platform/POIStore`, GRDB, SPEC §10/ARCHITECTURE §8) and are synced by
  version: `poi_changes_since(p_since, p_limit)` returns inserts/updates/deactivations and tombstones in
  `version` order; `POISync` pages until caught up and stores the high-water mark. Runs on launch and on
  foreground. The RPC is SECURITY DEFINER on purpose — table RLS hides `active=false` rows, but devices must
  learn about deactivations, and the 136 approximate shelters (active=false) are needed for search-only
  display. Migration: `poi_versioned_sync`.
- **What's plotted** is a contract (`contracts/enums.json` → `POIDisplayRules`, SPEC §20): pinned =
  beach, landmark, waterfall, hike, park, viewpoint, airport, ferry, marina, hospital, shelter — shelters only
  with `location_precision = exact` (the 13; the 136 approximate ones are search-only, never pinned);
  layer (off by default) = fuel; search-only = pharmacy, supermarket, mall, police, clinic, town;
  **emergency-only** = helipad (plotted while `pulsio_emergency_state` is active — the general pattern for
  emergency-relevant categories). restaurant/hotel/market/other stay hidden.
- **Colour is meaning** (SPEC §24, `DesignSystem/Semantics/POIType+Tint.swift`): teal tourist, white
  transport infrastructure (airport, ferry, marina, helipad), coral emergency (hospital, shelter — shelters
  emphasised with a light stroke), green fuel.
- **Attribution**: "POI © OpenStreetMap contributors · Basemap © Esri" is always on screen (ODbL), plus
  MapLibre's ⓘ button carrying ESRI's full credit line.
- Not yet: search, segment tabs, map labels for pins (needs a glyph server), Rodrigues.

## Location & district (SPEC §10)

- **One field, nine values.** `DistrictStore` holds `district` + `source` (`gps` | `manual`), persisted in
  UserDefaults always and to `pulsio_profiles.district` when signed in (CHECK-constrained to the nine, spelled
  as the pipeline writes them — `'Black River'`). Sign-in reconciles: the profile's district wins if set,
  otherwise the device's choice is pushed up.
- **Hard privacy rule, enforced by shape:** `LocationService` hands a coordinate to exactly two consumers —
  the map SDK (blue dot, drawn by MapLibre itself) and `DistrictResolver`, which turns it into a district
  on-device by voting among the nearest POIs in the local store and drops it. `ProfileRepository.updateDistrict`
  is the only location write and takes a `District`. Nothing stores or sends a coordinate.
- **Flow:** the locate button / district chip is the in-context point of first use → `LocationPrimerSheet`
  explains why *before* the system prompt → granted: resolve + blue dot; declined: `DistrictPickerSheet` with
  SPEC §10's verbatim framing (never "features unavailable") and a Settings deep link. District is editable
  permanently from the chip and from Account.
- `DistrictResolver` is a nearest-POI vote (766/942 POIs carry a district); swap in district polygons behind
  the same call if boundary precision ever matters.
- Opt-in UI tests: `TEST_RUNNER_LOCATION_FLOW=allow|deny` after `xcrun simctl location <udid> set -20.3162,57.5203`
  and `xcrun simctl privacy <udid> reset location mu.pulsio.app`.

## Auth — browse freely, sign in to act

Three doors, no passwords: **Sign in with Apple** (native, `AuthenticationServices` → Supabase ID-token),
**Google** (Supabase OAuth via the system web-auth session — no Google SDK), **email** (magic link *and* a
6-digit code from the same email; the code exists because mail-provider link scanners consume single-use
links — observed with Gmail on 2026-09-11).

- `AccessPolicy` (pure, unit-tested) decides per `Act`; `AccessGate` presents `SignInSheet` and resumes the
  act after sign-in. Browsing is never an `Act`. Cyclone alerts / shelters open to signed-out users while
  `pulsio_emergency_state` says an emergency is active.
- Supabase side (migration `auth_profiles_deletion_emergency_state`): `on_auth_user_created` trigger →
  `pulsio_profiles` row with free-tier defaults; `delete_own_account()` (SECURITY DEFINER, `authenticated`
  only) deletes `auth.users` and everything cascading; `pulsio_emergency_state` view (public-read).
- Callback deep link: `pulsio://auth-callback` (Info.plist `CFBundleURLTypes`, handled in `PulsIOApp.onOpenURL`).

### Supabase dashboard configuration (done 2026-09-11 unless marked)

Authentication → URL Configuration — **done**: Site URL `https://pulsio.mu`; `pulsio://auth-callback` on the redirect list.
Authentication → SMTP — **done**: custom SMTP via Google Workspace (`noreply@pulsio.mu`).
Authentication → Email Templates — **done**: *Confirm signup* and *Magic Link* both carry `{{ .Token }}`.
Note the project's email OTP length is **8 digits** (Auth → Settings); the app accepts 6–10.

Authentication → Providers
- **Google** — **done** (2026-09-12): Web-application OAuth client in Google Cloud with the Supabase callback
  `https://beyplrfqhfklylmmrxmw.supabase.co/auth/v1/callback` as redirect URI; enabled in Supabase with the
  client ID + secret. Verified end to end on the simulator: web-auth sheet → Google consent →
  `pulsio://auth-callback` → session with `provider=google`, profile `display_name` seeded from Google's name.
  Note: Supabase's OAuth state expires after **5 minutes** — a login that takes longer lands on the Site URL
  with `OAuth state has expired`; the user just retries.
- **Apple** — **still to do** (blocked on the Developer membership clearing): enable; add `mu.pulsio.app` to
  *Authorized Client IDs* (native flow — no Services ID/secret needed).

Apple Developer (for Sign in with Apple to work at all, simulator included)
- Register App ID `mu.pulsio.app` with the *Sign in with Apple* capability; put the Team ID in
  `Config/Shared.xcconfig` (`DEVELOPMENT_TEAM`). The entitlement is already in `PulsIO.entitlements`.

## Rules (from ARCHITECTURE §4)

- Views never touch the network. View → ViewModel → repository → Supabase.
- State is local to a feature by default; only session/tier/preferences/district are app-level.
- Adding a screen touches: one `Features/` folder, one line in `App/RootView.swift`, a repository method if
  it needs new data, and string keys. Nothing else.

## Running the auth smoke tests end to end

Signed-out checks run with the normal `test` action. The stateful ones opt in through `TEST_RUNNER_*`
environment variables (xcodebuild forwards them to the runner) and expect a specific simulator state:

```sh
# sends a real email; the code is either typed into the simulator by hand, or read from the inbox and
# written to the file for the test to type
TEST_RUNNER_MAGIC_LINK_EMAIL=you@example.com TEST_RUNNER_MAGIC_LINK_CODE_FILE=/tmp/code.txt \
  xcodebuild ... test -only-testing:PulsIOUITests/AuthSmokeTests/testEmailCodeSignInEndToEnd
TEST_RUNNER_GOOGLE_SIGN_IN=1  xcodebuild ... -only-testing:PulsIOUITests/AuthSmokeTests/testGoogleSignIn   # you complete Google's login in the simulator
TEST_RUNNER_SIGN_OUT=1        xcodebuild ... -only-testing:PulsIOUITests/AuthSmokeTests/testSignOut
TEST_RUNNER_SIGN_OUT_ALL=1    xcodebuild ... -only-testing:PulsIOUITests/AuthSmokeTests/testSignOutOfAllDevices
TEST_RUNNER_DELETE_ACCOUNT=1  xcodebuild ... -only-testing:PulsIOUITests/AuthSmokeTests/testDeleteAccount
```

Verified 2026-09-11 on iPhone 17 / iOS 26.5: gate → email → link + code → session → profile row created by
the trigger → Account sheet → sign out (`scope=local`) → sign out everywhere (`scope=global`) → delete
account (auth.users, sessions, identities and profile all gone). Google door verified 2026-09-12 the same way.
