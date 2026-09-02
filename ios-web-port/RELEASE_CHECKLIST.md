# HOneyNative release checklist (signed runtime proof)

The GitHub macOS lane builds and tests an **unsigned** simulator host, so
it cannot prove the Keychain paths (the Keychain tests `XCTSkip` there).
Every item below must be ticked on a **signed** build — Xcode on a Mac with
your Apple ID, on the simulator where noted and on a physical iPhone
otherwise — before a build is handed to anyone. Record the exact commit.

## Signed simulator lane (Xcode, ⌘U on a signed scheme)

- [ ] `KeychainSecretStoreTests` run (not skipped): round-trip, prefix
      enumeration, update in place, delete.
- [ ] `testOwnershipKeysOnTheKeychainExportAndImport` runs: keys are
      namespaced by account; export/import round-trips.
- [ ] `IdentityFreeTransportTests` and `NavigatorTests` pass.

## Physical iPhone (spec §28.5 end-to-end tasks, plus review items)

1. [ ] Sign in with the school test account and reach Home; relaunch —
       no login flash (session restored from the Keychain).
2. [ ] Settings › School connection shows the saved login; turn Stay
       connected off → the Keychain login is gone; turn it on → the sheet
       asks for it once; cancel → the toggle reflects the real state.
3. [ ] Portal: open School Portal — lands signed in. Kill the portal token
       (sign out on the website in Safari), reopen — silent recovery through
       the device coordinator, no HOney re-login.
4. [ ] Access: apply for a permit; open a gate from the **official website**;
       pull to refresh Access — the permit reads **Used** (confirms the
       `flag != 0` rule). Open a gate from the app — the same permit is not
       offered again until the list refreshes.
5. [ ] Access: with airplane mode after a successful load, pull to refresh —
       the cached permits stay visible, none can open a gate, the banner
       says so.
6. [ ] Timetable: Home Now/Next opens the correct date; Day → Week → Day
       keeps context; a fast step through several days never shows another
       day's lessons under the new header; cold launch opens Day.
7. [ ] Compose: pick a lesson, write, Keep private, relaunch, edit it.
8. [ ] Compose: publish; Your notes & posts shows it; the control key is in
       the Keychain (Settings › How anonymity works shows the count).
9. [ ] Compose with a Keychain failure simulated (device locked with
       `AfterFirstUnlock` not yet satisfied is hard to force — use the unit
       harness) — the journal replays on next launch.
10. [ ] Import the Web key export (Settings › How anonymity works › Import);
        counts match; re-import adds nothing.
11. [ ] Sign out, sign in as a **different** school account: no notes, no
        drafts, no recent contexts, no permits, the portal page is blank
        until opened, the first-share disclosure shows again.
12. [ ] Offline: cached timetable and private notes remain usable; the feed
        shows loaded posts; a public share fails honestly.
13. [ ] Dynamic Type at the largest accessibility size: Week becomes the
        day-by-day list; Explore's category control becomes a menu; nothing
        essential truncates.
14. [ ] VoiceOver pass: Home lesson card reads state → subject → time →
        teacher → room → relative time; a post reads context → provenance →
        body → reactions → options.
15. [ ] Reduce Motion: the progress fill updates without animation; a theme
        change switches without the crossfade.
16. [ ] Appearance: every Background × Accent pair applies at once across all
        five tabs, the open sheet and the status bar; nothing resets; relaunch
        paints the chosen surface at the first frame (no white/black flash).
17. [ ] Typography: Latin text is Source Sans 3 on every screen (compare the
        Web side by side); a mixed string such as `Edexcel Economics-U4 · 活动课老师`
        keeps its baseline; Text size Larger + the largest Dynamic Type still lays out.
18. [ ] The parity board (`WEB_VISUAL_FIDELITY.md`) has a Web/native pair
        for every core screen and Gary has approved the baseline.

## Evidence

Write the commit hash, device model, iOS version and the date next to each
ticked line in the pull request that proposes the release.
