# HOneyNative — the iPhone port of the current Web

Clean-room SwiftUI reimplementation of HOney's Web product at
`integration/product-v2 @ 2d1b562` (spec: *HOney current Web → iPhone native
port v1.0*, 2026-09-02). Nothing from the old `ios/` target is compiled,
imported or used as authority — `scripts/check-no-reuse.sh` enforces it in CI.

```
ios-web-port/
  project.yml            XcodeGen definition (run `xcodegen generate`; the .xcodeproj is not committed)
  HOneyCore/             Swift package, no UIKit: wire DTOs, API clients, domain rules, composer
                         state machine, feed paging, stores, portal client — builds and tests on Linux
  HOneyNative/           the SwiftUI app: App (environment, tabs, deep links), Core (Keychain, design
                         tokens, components), Features (Login, Home, Portal, Experiences, Timetable,
                         Access, Settings), Resources (icon, wordmark, OASIS mark)
  HOneyNativeTests/      simulator tests: Keychain, identity-free transport, deep-link router
  WEB_PORT_DELTA.md      later Web changes, classified before they may enter
  TRACEABILITY.md        Web file → native file
```

## Build

On a Mac with Xcode 16: `brew install xcodegen`, then in this directory
`xcodegen generate` and open `HOneyNative.xcodeproj`. Signing is automatic with
no team baked in. iOS 17+, iPhone, portrait.

Without a Mac: the `iOS web port` GitHub workflow runs the Core tests on
Linux (Swift 6.1) and builds + tests the app on a macOS runner on every push
touching `ios-web-port/`.

## Contract parity

`packages/shared/src/api/fixtures.ts` holds typed literals checked against
`contract.ts` at compile time; `pnpm --filter @honey/shared fixtures:write`
regenerates `packages/shared/fixtures/api/*.json`; the TypeScript test pins the
JSON to the literals and `HOneyCoreTests/FixtureDecodingTests` decodes the
same files into the Swift DTOs. A breaking change fails both sides.

## Session and secrets

HOney session, school login (default on, Settings opt-out), portal session and
post control keys live in the Keychain (this device only, no iCloud Keychain).
Private notes and composer drafts live in Application Support with complete
file protection, per HOney account. The publish call goes through a separate
client on an ephemeral, cookie-less session and never carries the session.
