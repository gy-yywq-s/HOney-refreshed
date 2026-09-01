# Live-portal regressions fixed (2026-09-01)

Found and fixed while validating against the **real** OASIS portal with a school test account.
Credentials are never recorded here or in the repo — they are the account holder's private
information; this note uses `<test-account>` as a placeholder.

## 1. Timetable import failed entirely (500 `schemaIncompatible`)

**Symptom.** After login with import consent, no lessons appeared: Timetable, Next Lesson and
History were all empty; `POST /api/sync` returned `500 {"message":"schemaIncompatible"}`.

**Root cause.** The portal only serves schedules for the **past ~2 weeks**. Older weeks return
`{ status: 1, message: "只能查看过去两周内的课表" }` — a legitimately unavailable week, not a
schema error. The connector's `weeklySchedule` required `status === 0` and otherwise threw
`schemaIncompatible`. The import window was `[-8 weeks, +4 weeks]`, so the very first (out-of-range)
week threw and aborted the whole sync.

**Fix.**
- `packages/portal-connector/src/api.ts` — `weeklySchedule` now treats any non-zero status (with a
  valid `data` object) as an **empty/unavailable week** and returns no lessons, instead of throwing.
- Import no longer fans out 13 weekly requests. Per real-portal behavior, `get_lesson_table`
  returns the **entire current + future term with real times in one request**, so it is the primary
  source; the weekly schedule is fetched only for the **past 2 weeks + current week** (history +
  per-section class data + the few current lessons the table omits), merged by `lesson_id`
  (`normalizeTableLessons` + `mergeLessonsById`). Requests: **13 → 4**; coverage: partial → full term.

**Verification (live).** `sync` imports **126 lessons**; Timetable, Next Lesson, History and the
directory all populate. Regression test: mock portal returns the out-of-range `status:1` for early
weeks and the connector treats it as empty (`coordinator.test.ts`).

## 2. `POST /api/sync` rejected an empty body (400)

**Symptom.** Bodyless action `POST /api/sync` sent with `Content-Type: application/json` and an
empty body → `400 FST_ERR_CTP_EMPTY_JSON_BODY`.

**Fix.** `packages/backend/src/app.ts` registers a content-type parser that treats an empty
`application/json` body as `{}`. Regression test: empty-body sync returns 200 (`app.test.ts`).

## 3. `studentId 0088` did not become admin

**Symptom.** The account whose school id is `0088` was not granted admin (no dash access).

**Root cause.** `user_info.id` is the **numeric** id (e.g. `88` — leading zeros stripped), stored as
`"88"`, while the admin was configured as `"0088"`. The string compare `"88" === "0088"` was false.

**Fix (per the account holder's rule: bind admin at registration, don't re-verify each request).**
- `is_admin` is now a **stored flag** on `honey_users` (migration 005), computed **once at
  provisioning** with a leading-zero-tolerant match (`"0088"` ≡ `88`). `isAdmin()` reads the stored
  flag — no per-request re-derivation. Accounts created before the column are corrected on their
  next login (the reconnect path re-syncs the flag).

**Verification (live).** `<test-account>` login returns `isAdmin: true`; `GET /api/admin/overview`
returns 200 with the dash payload. Regression test: `"0088"` config matches the mock portal id `88`
(`app.test.ts`); non-admins still get 403.

## Confirmed portal facts (previously only inferred)

- **Login success schema** is a top-level `{ token }` (not `{status,data,token}`); the connector
  already read the top-level token, so no change needed.
- **Token TTL ≈ 24h** (login → `exp` ~24h later), consistent with the connector's safety-window model.
- **Web Access CORS:** the OPTIONS preflight is permissive (the portal reflects the requesting
  origin and allows the `Authorization` header), **but the actual GET response carries no
  `Access-Control-Allow-Origin`**, so a browser would block the response body. Verdict: Web Access
  stays capability-gated **off** (spec §11.4) — now evidence-backed, not merely assumed.
