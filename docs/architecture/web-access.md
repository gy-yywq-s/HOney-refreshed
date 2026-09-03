# Web Access — the isolated Access Service

Status: implemented 2026-09-03 on `integration/product-v2` (spec
`HOney_web_access_canonical_data_anonymous_control_v2_implementation_spec_20260903`, Part II).
The Dash switch ships **OFF**; the controlled real-gate verification (§26.3) is Gary's
physical step and is recorded in `docs/status/` when done.

## What it is

A student signed in to the web can open a school gate or manage exit permits from the
**Access** tab. The physical request is made by a separate process — the Access Service —
that holds no account, no password and no database of anyone's, and can reach exactly one
network origin: the school portal.

```
browser ──(Access-Capability header, no cookies)──▶ edge :8871 ──▶ Access :8874 ──▶ portal
   │                                                                    ▲
   └──(HOney session)──▶ Core :8872 ── signs capability, seals portal session to Access ──┘
```

## Capability (spec §17)

`POST /api/access/session` (Core, authenticated) returns a short-lived capability:

- body: `version 1`, `audience "honey-web-access"`, `capabilityId`, `subject` (an HMAC
  pseudonym of the account under Core's seal key — never the honeyId), `schoolId`,
  `portalStudentId`, `issuedAt`, `expiresAt` (≤ 10 min and ≤ the portal token's own expiry),
  `sealedPortalSession`;
- the portal session (`{ token, tokenExpiresAt, portalStudentId, schoolId }`) is
  **HPKE-sealed** (X25519-HKDF-SHA256 / AES-256-GCM, info `honey/access/portal-session`,
  AAD = `capabilityId`) to the Access Service's public key;
- the envelope is **Ed25519-signed** over the RFC 8785 canonical body by Core's
  `core-signing` key.

Keys live in the keys directory (`/home/honey/data/keys/` in deployment): Core writes
`core-signing.private.json` (0600) + `core-signing.public.json`; the Access Service writes
`access-sealing.private.json` (0600) + `access-sealing.public.json` on first start. Each
process reads only the other's *public* file. The browser carries the capability opaque to it.

Every "not now" answer from `/api/access/session` (`no_school_connection`,
`portal_reconnect_required`, `access_unavailable`) is `200 { ok: false, error }` — a 401
would read as a lost HOney session to the web client, and it is not one.

## The Access Service (spec §16, §18–§23)

`packages/access-service/` — Fastify on loopback `:8874`, own SQLite file (`access.db`):

| table | holds | never holds |
|---|---|---|
| `access_settings` | `WEB_ACCESS_ENABLED` (default off) | — |
| `access_operations` | id, subject **hash**, kind, gate key, permit record id, state, commit-secret **hash**, non-identifying payload (permit window/reason), stage timestamps, outcome code, upstream status class, service version | portal token, capability, commit secret, name/email/honeyId, upstream bodies |
| `access_latency_samples` | kind, duration, warm flag, version | — |

The edge sends only `/access/bootstrap`, `/access/operations/*` and `/access/health` to this
process; every other `/access/*` path is a screen of the web app (`/access`,
`/access/permits/new`) and deep-links like any other.

Public routes (all require `Access-Capability`; a stray `Cookie`/`Authorization` is refused
as a misrouted request):

| route | does |
|---|---|
| `GET /access/bootstrap` | warms the portal connection, reads identity (day student?), doors, permits; returns routes and ETA labels |
| `POST /access/operations/open/prepare` | **fresh** door + permit/identity reads; one active operation per subject; returns `operationId` + one-time `commitSecret` (60 s) |
| `POST /access/operations/permit/prepare`, `…/withdraw/prepare` | same shape for permit requests / withdrawals |
| `POST /access/operations/:id/commit` (`Access-Commit`) | claims PREPARED→COMMITTED atomically, dispatches **exactly once**, streams NDJSON progress |
| `GET /access/operations/:id` | journal state for a client that lost the stream |

State machine: `PREPARED → COMMITTED → DISPATCHING → WAITING_FOR_SCHOOL → CONFIRMED |
REJECTED | OUTCOME_UNKNOWN`, or `PREPARED → EXPIRED | PAUSED`, or `… → NOT_SENT`.

- **Never retried.** The connector's mutation path makes one attempt; the service never
  re-sends; the web client never re-commits — on a lost stream it polls status.
- **not_sent vs unknown.** A failure is `NOT_SENT` only when the request provably never left
  the process (egress refused; DNS/connect/TLS-handshake failure, traced through
  `AsyncLocalStorage`). A timeout, a reset, a 5xx or an unexpected error after that is
  `OUTCOME_UNKNOWN` — the student is told to check the gate before trying again.
- **Restart recovery.** On start, rows in `COMMITTED/DISPATCHING/WAITING_FOR_SCHOOL` become
  `OUTCOME_UNKNOWN / service_restarted`; `PREPARED` rows expire. Shutdown drains in-flight
  dispatches (≤ 15 s; `TimeoutStopSec=20`) so their outcome is journaled.
- **Pause.** The switch is read at prepare and again at commit (before dispatch). A commit on
  a paused switch journals `PAUSED` and sends nothing; a dispatch already on the wire is not
  interrupted.
- **ETA** (`Usually 1–2 seconds`) is the median–p90 of the last 100 successful operations of
  that kind; below 5 samples it says "Usually a few seconds". No fabricated numbers.
- Progress stream copy (`PROGRESS_COPY`) states what is true: accepted → sending → waiting for
  the school → confirmed / declined / not sent / no answer.

Egress: the app-layer guard (`guardedFetch`) refuses any origin but the configured portal
origin before a connection is attempted; the unit adds `IPAddressDeny=any` +
`IPAddressAllow=localhost` + the portal's address(es).

Internal admin (loopback + `x-honey-internal`, the edge 404s `/internal/*`):
`GET /internal/admin/status`, `POST /internal/admin/enabled`, `GET /internal/admin/journal`
(rows without subject or secret). Core proxies these for the Dash (`/api/admin/access*`).

## Web (spec §21–§22, §25)

- `apps/web/src/lib/access/client.ts` — capability cache (refreshed 30 s before expiry),
  `credentials: "omit"` on every Access call, NDJSON reader, status polling on a lost stream,
  `describeAccessFailure` (every line says whether anything was sent).
- `pages/AccessPage.tsx` — gates with the route that can open one now (day student, or the
  most recent approved unused permit inside its window), exit permits (status chip from
  `displayStatus`, withdraw for pending), one `ConfirmDialog` per physical action
  (`Open 正门 Front Gate? Day student. This sends a physical gate request.`), then
  `AccessProgress` (stages, real elapsed time, ETA, terminal line).
- `pages/access/NewPermitPage.tsx` — the portal's quick default prefilled (now → +2 h, 出门),
  school-zone times.
- Dash › **Web Access** panel — reachable / enabled / version / egress origin / in-progress /
  unknown-today / typical open; confirmed switch.
- Rules shared with iOS: `packages/shared/src/access/rules.ts` (`isOpenable`, `isConsumed`,
  `displayStatus`, `permitTone`, `quickPermitDraft`, …) mirrors `AccessRules.swift`.

## Verification

- `packages/access-service/src/access.test.ts` — capability guard, in-memory-only session,
  bootstrap, fresh-read prepare rules, one-active-per-subject, streamed commit, subject
  isolation, permit apply/withdraw, admin gate, egress guard, ETA label, and the
  **eleven-injection matrix** (`src/testing/injection.ts`).
- Transcript: `pnpm --filter @honey/access-service exec tsx scripts/failure-injection.ts <out.md>`
  → `docs/status/web-access-failure-injection-<date>.md`.
- Live: `/root/claude-work/design-audit/` probes exercise bootstrap and prepare against
  honey.gaelisus.com; they never commit a gate request (spec: the controlled real verification
  is a human step with the switch on, then off).
