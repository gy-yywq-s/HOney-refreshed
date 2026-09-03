# Web Access failure-injection run — 2026-09-03

Service version: b4c89dd. Driven through the real HTTP surface of the Access Service against the in-process mock portal (spec §26.2). Each injection uses a fresh journal and a fresh mock portal; the door-request column is the number of physical requests the mock actually received.

Result: **11/11 passed**.

| # | Injection | Expected | Observed | Journal | Door requests | Student saw | Pass |
|---|---|---|---|---|---|---|---|
| 1 | switch off at prepare: WEB_ACCESS_ENABLED=false (default) | 423 access_paused; no operation; 0 door requests | 423 access_paused | none | 0 | Web Access is paused right now. Nothing was sent. | ✅ |
| 2 | paused between prepare and commit: switch → off after prepare | 423 access_paused; journal PAUSED; 0 door requests | 423 access_paused | PAUSED / access_paused | 0 | Web Access was paused before this was sent. Nothing was sent. | ✅ |
| 3 | wrong commit secret: Access-Commit header does not match | 403 commit_secret_invalid; journal stays PREPARED; 0 door requests | 403 commit_secret_invalid | PREPARED | 0 | This confirmation is no longer valid. Nothing was sent. | ✅ |
| 4 | expired prepare: clock +61 s between prepare and commit | 409 operation_not_prepared; journal EXPIRED; 0 door requests | 409 operation_not_prepared | EXPIRED / prepare_expired | 0 | This confirmation expired. Nothing was sent. Start again. | ✅ |
| 5 | double commit: two simultaneous commits with the right secret | both streams end confirmed; exactly 1 door request; journal CONFIRMED | 200/200 confirmed/confirmed | CONFIRMED / confirmed | 1 | Done. The school confirmed. | ✅ |
| 6 | school rejects: portal answers status:1 'no permission' | stream ends rejected WITH the school's words; journal REJECTED/portal_rejected; 1 door request | 200 rejected detail="no permission" | REJECTED / portal_rejected | 1 | The school declined this request. Nothing was opened. — no permission | ✅ |
| 7 | school does not answer: portal holds the door request past the 300 ms timeout | stream ends outcome_unknown; journal OUTCOME_UNKNOWN/timeout; exactly 1 door request (no retry) | 200 outcome_unknown | OUTCOME_UNKNOWN / timeout | 1 | The school did not answer. Check the gate before trying again. | ✅ |
| 8 | school gateway error: portal answers 5xx after the request reached it (the mock's 5xx hook answers before its door counter, so the count reads 0) | stream ends outcome_unknown (a 5xx does not prove nothing happened); journal OUTCOME_UNKNOWN | 200 outcome_unknown | OUTCOME_UNKNOWN / serverUnavailable | 0 | The school did not answer. Check the gate before trying again. | ✅ |
| 9 | school unreachable: portal process stopped before commit (ECONNREFUSED) | stream ends not_sent; journal NOT_SENT | 200 not_sent | NOT_SENT / not_sent | 0 | Nothing was sent to the school. | ✅ |
| 10 | egress refused: allowlist excludes the portal origin | 503 service_unavailable; 0 portal requests; nothing else contacted | 503 service_unavailable | none | 0 | Web Access can't reach the school right now. Nothing was sent. | ✅ |
| 11 | restart while waiting: service restarted with the operation WAITING_FOR_SCHOOL | journal OUTCOME_UNKNOWN/service_restarted after restart; status says so; door request count unchanged (1) | WAITING_FOR_SCHOOL → OUTCOME_UNKNOWN; status 200 OUTCOME_UNKNOWN | OUTCOME_UNKNOWN / service_restarted | 1 | The school did not answer. Check the gate before trying again. | ✅ |

No injection produced a second physical request. Every path that did not reach the school says so (`not_sent`); every path where the school's answer is missing says `outcome_unknown` and is never retried by the service.
