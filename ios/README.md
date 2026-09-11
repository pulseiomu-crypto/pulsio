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
  Contracts/      row models + fixed enums mirroring the schema / contracts/*.json — not feature code
  Data/           the ONE data department: SupabaseGateway + repositories (all network here)
  DesignSystem/   tokens (Palette, Typography, Metrics) + semantic mappings — the finish, defined once
  Features/       one folder per screen: View + ViewModel; a feature knows its repository, nothing else
  Localization/   Localizable.xcstrings (EN + FR) — no string literals in views
  Resources/      Info.plist, asset catalog
PulsIOTests/      unit tests
```

Departments not yet populated (they arrive with their first feature): `Platform/` (location, proximity,
photo pipeline, StoreKit, notifications), `Map/` (MapSurface + MapLibre adapter), `PulseFX/`.

## Rules (from ARCHITECTURE §4)

- Views never touch the network. View → ViewModel → repository → Supabase.
- State is local to a feature by default; only session/tier/preferences/district are app-level.
- Adding a screen touches: one `Features/` folder, one line in `App/RootView.swift`, a repository method if
  it needs new data, and string keys. Nothing else.
