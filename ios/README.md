# HOney iOS

SwiftUI app (iOS 17+). Four-band architecture: `DesignSystem/`, `Services/` (no SwiftUI),
`Features/` (views + view models), `Models/`.

## Current signed-in experience

- Home keeps the current/next lesson as the focal object on a continuous tonal surface; class
  Experiences, Share, Access and School Portal remain secondary.
- Settings exposes six persisted Surface palettes directly, including the earlier warm-paper and
  original-blue directions. Every palette tunes its own light/dark interaction and detail colors.
- Timetable uses explicit date controls and one card per lesson. Each card always shows a teacher
  name or the honest `Teacher not listed` fallback; broad swipe-to-change-day is intentionally absent.
- Refresh is local and explicit rather than whole-screen pull-to-refresh. Previously loaded content
  stays visible when a refresh fails.
- Next lesson, History, Timetable, Experience targets and Experience feeds use app-scoped freshness
  caches, same-key request coalescing and stale-response guards. Account, consent and school-data
  changes invalidate the affected caches.

## Run on your iPhone (Mac + Xcode)

1. **Clone** the repo and open **`ios/HOney.xcodeproj`** in Xcode (double-click).
   *(The project is committed, so no tooling is needed to open it.)*
2. **Connect your iPhone** by cable and select it as the run destination (top bar).
3. **Signing is automatic and no team is baked in** — Xcode uses your own Apple ID.
   - If Signing shows a team is required: Xcode ▸ Settings ▸ Accounts ▸ add your Apple ID
     (a **free** personal account works), then in the target's *Signing & Capabilities* tab
     make sure "Automatically manage signing" is on. Your personal team is selected for you.
   - You do **not** need a paid Apple Developer Program membership to run it on your own device.
4. Press **Run (⌘R)**. First install: on the phone, trust the developer under
   Settings ▸ General ▸ VPN & Device Management.

> The app icon is HOney's (reused from the previous app). The bundle id is
> `com.gaelisus.honey`; if another app on your account already uses it, change it in
> *Signing & Capabilities* — automatic signing handles the rest.

## Regenerate the project (optional)

`ios/project.yml` (XcodeGen) is the source of truth; `HOney.xcodeproj` is a committed snapshot.
After changing `project.yml`, refresh it with:

```
brew install xcodegen   # once
cd ios && xcodegen generate
```

CI (`.github/workflows/ios.yml`) regenerates the project and runs `xcodebuild test` on a
macOS runner for every change under `ios/`.
