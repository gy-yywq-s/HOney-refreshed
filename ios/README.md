# HOney iOS (SwiftUI)

The HOney iOS app. Built and tested on the GitHub Actions **macOS runner** — there
is no local Xcode/Swift in the dev box, so the CI runner is the compile gate.

## Layout (four-band separation)

```
ios/
├── project.yml            # XcodeGen spec (do NOT hand-edit .xcodeproj)
├── HOney/
│   ├── App/               # composition root: entry, RootView, AppModel, services
│   ├── DesignSystem/      # Theme (tokens) + reusable components
│   ├── Models/            # Codable Honey API models + portal wire types + pure logic
│   ├── Services/          # Band 2/4 client logic — NO SwiftUI imports
│   │   ├── HoneyAPI.swift                 # typed Honey client, single-flight refresh-on-401
│   │   ├── SessionStore.swift             # Honey tokens in Keychain
│   │   ├── PortalAPI.swift                # direct-to-school portal (Access only)
│   │   ├── PortalSessionCoordinator.swift # the session actor (blueprint contract)
│   │   ├── KeychainCredentialVault.swift  # non-biometric device-only credential vault
│   │   ├── OwnershipKeyStore.swift        # device-only experience ownership keys
│   │   ├── Keychain.swift                 # generic Keychain wrapper
│   │   └── Coding.swift                   # shared JSON coders
│   ├── Features/          # Band 1 UI + view models (Auth, Home, Timetable, History,
│   │                      #   Experiences, Access, Settings, Main tab)
│   └── Resources/         # Assets.xcassets (AccentColor, AppIcon placeholder)
└── HOneyTests/            # xcodebuild-test runnable unit tests (pure logic only)
```

## XcodeGen flow (what CI runs)

The `.xcodeproj` is **generated**, never committed. Regenerate it from `project.yml`:

```sh
brew install xcodegen
xcodegen generate --spec ios/project.yml     # produces ios/HOney.xcodeproj

# Build + test on an iOS Simulator (iPhone 15, latest runtime)
xcodebuild build \
  -project ios/HOney.xcodeproj -scheme HOney \
  -destination 'platform=iOS Simulator,name=iPhone 15'

xcodebuild test \
  -project ios/HOney.xcodeproj -scheme HOney \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

The `HOney` scheme is configured for `xcodebuild test`: it builds the app target
plus the `HOneyTests` unit-test bundle (hosted by the app) and runs the test action.

## Notes

- **Bundle id:** `com.gaelisus.honey`. **Deployment target:** iOS 17. SwiftUI lifecycle,
  Swift 5.9, async/await + the Observation framework (`@Observable`).
- **Signing:** disabled for simulator build/test (`CODE_SIGNING_ALLOWED=NO`).
- **App icon:** intentionally a placeholder (see `HOney/Resources/APP_ICON_PLACEHOLDER.md`).
  Gary generates the final mark later via `codex exec` → imagegen. The in-app brand is
  the text wordmark "HOney" in a clean rounded system font (never a serif).
- **Tests** cover only pure logic that needs no simulator UI: the session coordinator
  (single-flight, replay policy, expiry, credential safety), portal wire decoding
  (incl. the door-list quirk), Front/Back door mapping + commuter `record_id = -2`,
  and next-lesson temporal formatting. UI is intentionally not unit-tested.
