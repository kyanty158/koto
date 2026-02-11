# KOTO Native iOS App

The Flutter MVP has now been migrated to a SwiftUI-first implementation. Native source, data layer, notifications, and subscription flow all live inside the Swift package and the new Xcode project.

## Repository Layout

- `KotoApp/` — Xcode project (`KotoApp.xcodeproj`) that ships the iOS app and shared UI / UI test targets.
- `ios-native/` — Swift Package containing the production modules (Core Data stack, features, services) and Swift package unit tests.
- `legacy/flutter/` — Archived Flutter sources that previously powered the MVP.
- `docs/ios_swift_architecture.md` — High level architecture notes.

## Building & Running

1. Open `KotoApp/KotoApp.xcodeproj` in Xcode 15 or later.
2. The `KotoApp` scheme already links the `KotoApp` Swift package and sets `KotoAppScene` as the entry point.
3. Run on an iOS 15+ simulator; notification permissions are requested on first launch, and notification actions deep-link into the edit sheet.
4. The Settings tab exposes the new StoreKit-based Pro upgrade flow.

## Tests

### Swift Package (Core Data, business logic)

```bash
cd ios-native
SWIFT_MODULECACHE_PATH=.build/swift-module-cache \
CLANG_MODULE_CACHE_PATH=.build/clang-module-cache \
swift test
```

### Xcode Unit & UI Tests

```bash
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  clean test
```

The Swift Package suite now covers Core Data create/update/delete flows, Basic tier reminder quotas, reminder preset calculations, and the Xcode UI suite verifies the tab layout plus the Pro paywall entry point.

## CI

GitHub Actions (`.github/workflows/ios.yml`) runs the Swift package tests followed by an iOS simulator build/test for the `KotoApp` scheme on every push and pull request targeting `main`.
