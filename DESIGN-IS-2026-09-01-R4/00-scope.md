# Design-Is R4 scope lock — final one-defect confirmation

Date: 2026-09-01
Repository: `/home/honey/worktrees/web-ionic-fidelity`
Candidate: current uncommitted `web/ionic-fidelity` working tree.

## Target and task

- Audit the final candidate after the sole post-R3 change: the Settings account-deletion summary now states that both a signed-in HOney session and a device-held post-control key are required to find/revoke published experiences (`apps/web-ionic/src/pages/SettingsPage.tsx:83-87`).
- Confirm new negative/positive integrity assertions (`apps/web-ionic/src/lib/copyIntegrity.test.ts:45-94`).
- Run bounded regression evidence only on unchanged structure, visuals, weight, and accessibility.
- Primary user/task remain: a student identifies Now/Next in about three seconds and reaches Timetable or Experiences without losing context (`docs/design/shared-product-design-invariants.md:11-22`).

## Evidence and constraints

- Current code, fresh verification results, current copy inventory, and six unchanged-layout images under `docs/web/evidence/ionic-fidelity/r3-candidate/`.
- `https://ionic.gaelisus.com` is stale and excluded from candidate scoring.
- Fresh reported gates: scoped lint pass, typecheck pass, Vitest 8 files/42 tests, `audit:copy` 407/1512, production build pass.
- Final build: entry 153.58 KiB raw/49.54 gzip; PublicApp 3.02/1.36; authenticated App 970.93/214.70.
- No real credentials, portal access, backend traffic, optional browser/build reruns, implementation edits, commit, push, or deploy.
- Preserve `apps/web`, iOS, backend/shared API/database, product behavior, brand and deployment topology.
- R1/R2/R3 scores are history only. R4 is independently scored with exact anchors, worst-instance and lower-score tie-breaker.
