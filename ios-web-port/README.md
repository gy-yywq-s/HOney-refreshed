# HOneyNative — the iPhone port of the current Web

Clean-room SwiftUI reimplementation of HOney's Web product at
`integration/product-v2 @ 9cbedf6`, aligned to `cebb399` on 2026-09-04 (`WEB_PORT_DELTA.md`) (port spec v1.0 + *visual fidelity spec v2.0*,
2026-09-02): the Web's font (Source Sans 3), sentence casing, four Backgrounds, seven
Accent schemes, four Text sizes and component grammar, reproduced before any native
reinterpretation (`WEB_VISUAL_FIDELITY.md`). Nothing from the old `ios/` target is compiled,
imported or used as authority — `scripts/check-no-reuse.sh` enforces it in CI.

```
ios-web-port/
  project.yml            XcodeGen definition (run `xcodegen generate`; the .xcodeproj is not committed)
  HOneyCore/             Swift package, no UIKit: wire DTOs, API clients, domain rules, composer
                         state machine, feed paging, stores, portal client — builds and tests on Linux
  HOneyNative/           the SwiftUI app: App (environment, tabs, deep links), Core (Keychain, design
                         tokens, components), Features (Login, Home, Portal, Experiences, Timetable,
                         Access, Settings), Resources (icon, wordmark, OASIS mark)
  HOneyNativeTests/      simulator tests: Keychain, identity-free transport, deep-link router,
                         portal delegate, typography, appearance persistence, text-case audit,
                         and the visual fixture snapshots (published to `ios-web-port-evidence`)
  WEB_PORT_DELTA.md      later Web changes, classified before they may enter
  WEB_VISUAL_FIDELITY.md the visual fidelity ledger (Web source → native, class, evidence)
  TRACEABILITY.md        Web file → native file
```

## Build

On a Mac with Xcode 16: `brew install xcodegen`, then in this directory
`xcodegen generate` and open `HOneyNative.xcodeproj`. Signing is automatic with
no team baked in. iOS 17+, iPhone, portrait.

Without a Mac: the `iOS web port` GitHub workflow runs the Core tests on
Linux (Swift 6.1) and builds + tests the app on a macOS runner on every push
touching `ios-web-port/`. The macOS lane renders the contract fixtures through the
real shell at 390 × 844 in the required themes and force-pushes the PNGs to the
`ios-web-port-evidence` branch, readable without a token on the public repo.

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

## Anonymous Control v2 and canonical school data (2026-09-03)

`integration/product-v2` (spec 3e44152e groups 1–4) is merged in. The wire is the canonical
contract (`Lesson.subjectName/courseName/classSectionName`; titles are `lesson.title`) and the
identity-free Community v2 protocol. `HOneyCore/Sources/HOneyCore/CommunityV2/` is the Swift
implementation (key hierarchy, Control Vault, wrappers, recovery words, pairing, partially-blind
RSA client over BigInt) — see `docs/architecture/anonymous-control-v2.md` § iOS. Dependencies:
swift-crypto, attaswift/BigInt (resolved through HOneyCore's Package.swift; the app target links
them transitively). The v1 ownership-key store, publication journal and key export/import are gone:
post controls travel through the vault (recovery words · another device), never as a file.
