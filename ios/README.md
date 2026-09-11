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
    Session/      app-level identity: SessionStore (auth + profile + emergency flag), AccessPolicy, AccessGate
  Contracts/      row models + fixed enums mirroring the schema / contracts/*.json — not feature code
  Data/           the ONE data department: SupabaseGateway + repositories (all network here)
    Auth/         AuthRepository — the only file that knows Supabase Auth
  Platform/       device services; today: Auth/AppleSignInNonce (CryptoKit)
  DesignSystem/   tokens (Palette, Typography, Metrics), components, semantic mappings — the finish, once
  Features/       one folder per screen: View + ViewModel; a feature knows its repository, nothing else
  Localization/   Localizable.xcstrings (EN + FR) — no string literals in views
  Resources/      Info.plist, entitlements, asset catalog
PulsIOTests/      unit tests (Swift Testing)
PulsIOUITests/    simulator smoke tests (XCUITest); some steps opt in via env — see AuthSmokeTests
```

Departments not yet populated (they arrive with their first feature): `Map/` (MapSurface + MapLibre
adapter), `PulseFX/`.

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

Authentication → Providers — **still to do**
- **Apple**: enable; add `mu.pulsio.app` to *Authorized Client IDs* (native flow — no Services ID/secret needed).
- **Google**: enable with a *Web application* OAuth client ID + secret from Google Cloud; add the Supabase
  callback `https://beyplrfqhfklylmmrxmw.supabase.co/auth/v1/callback` as an authorised redirect URI there.

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
# sends a real email; the code is either autofilled (macOS Mail + AutoFill on this Mac types it into the
# focused one-time-code field) or read from the inbox and written to the file
TEST_RUNNER_MAGIC_LINK_EMAIL=you@example.com TEST_RUNNER_MAGIC_LINK_CODE_FILE=/tmp/code.txt \
  xcodebuild ... test -only-testing:PulsIOUITests/AuthSmokeTests/testEmailCodeSignInEndToEnd
TEST_RUNNER_SIGN_OUT=1        xcodebuild ... -only-testing:PulsIOUITests/AuthSmokeTests/testSignOut
TEST_RUNNER_SIGN_OUT_ALL=1    xcodebuild ... -only-testing:PulsIOUITests/AuthSmokeTests/testSignOutOfAllDevices
TEST_RUNNER_DELETE_ACCOUNT=1  xcodebuild ... -only-testing:PulsIOUITests/AuthSmokeTests/testDeleteAccount
```

Verified 2026-09-11 on iPhone 17 / iOS 26.5: gate → email → link + code → session → profile row created by
the trigger → Account sheet → sign out (`scope=local`) → sign out everywhere (`scope=global`) → delete
account (auth.users, sessions, identities and profile all gone).
