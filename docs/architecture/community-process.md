# Process, database and redaction map

**Since:** 2026-09-02 (spec Part III §29, Part II §16). Three application processes on one machine,
one reverse proxy, four SQLite files. The process that knows the account cannot read posts; the
process that stores posts cannot resolve an account; the process that opens gates can read neither.

```mermaid
flowchart LR
    T[Cloudflare tunnel] --> E[honey-edge :8871<br/>packages/edge]
    E -->|/api/* · web app<br/>cookies/authorization pass| C[HOney Core :8872<br/>packages/backend]
    E -->|/community/*<br/>Cookie, Authorization, account & Core request ids REMOVED| M[HOney Community :8873<br/>packages/community-service]
    E -->|/access/*<br/>only Access-Capability / Access-Commit| A[Access Service :8874<br/>packages/access-service]
    C --> CDB[(honey.db)]
    C --> VDB[(vault.db)]
    M --> MDB[(community.db)]
    A --> ADB[(access.db)]
    C -. issuer.public.json (keys dir) .-> M
    C -. loopback + internal secret: /internal/admin/* .-> M
    C -. loopback + internal secret: /internal/admin/* .-> A
    A -->|typed allowlisted calls| P[(School portal)]
```

## Who may open what

| Process | Opens | Never opens | Imports |
|---|---|---|---|
| Core (`honey.service`) | `honey.db`, `vault.db` | `community.db`, `access.db` | `@honey/shared`, `@honey/portal-connector` |
| Community (`honey-community.service`) | `community.db` | `honey.db`, `vault.db`, `access.db` | `@honey/shared` only (test: no Core/connector import) |
| Access (`honey-access.service`) | `access.db` | `honey.db`, `vault.db`, `community.db` | `@honey/shared`, `@honey/portal-connector` |
| Edge (`honey-edge.service`) | nothing | everything | standard library only |

systemd enforces the file rule with `InaccessiblePaths=` (the other services' database files are
hidden from each unit) on top of the configuration rule (each process is only told its own path).
Environment files are separate: `honey.env` (Core: `HONEY_SECRET`, `HONEY_INTERNAL_SECRET`, admin id,
paths), `community.env` (`HONEY_COMMUNITY_SECRET`, `HONEY_INTERNAL_SECRET`, `OPENROUTER_API_KEY`,
`HONEY_COMMUNITY_DB_PATH`, `HONEY_KEYS_DIR`), `access.env` (Access: its own secret, portal origin,
`HONEY_INTERNAL_SECRET`). Community never receives `HONEY_SECRET` (the core seal key) and Core never
receives Community's.

## Identity-free boundary (`/community/*`)

Removed at the edge **and** refused by the service (`redaction.ts`): `Cookie`, `Authorization`,
`X-HOney-Account`, `X-HOney-User`, `X-HOney-Session`, `X-Request-Id`, `X-Correlation-Id`, plus the
edge's own client-address headers. Community generates a fresh local request id per request; its
log line is `{id, route class, status, ms}` — no path, query, body, header, tag or key. Core's
Fastify logger is off; the edge logs `{id, lane, status, ms}`.

Community's public and admin DTOs are allowlists; a test asserts none of `author_tag`,
`posting_public_key`, `control_public_key`, `client_nonce`, `content_hash`, `reactor_tag`,
`reporter_tag` appears in a response.

## What each database holds about a person

| File | Account-linked | Post-linked | Bridge |
|---|---|---|---|
| `honey.db` | accounts, sessions, school connection, exposures, invite marks, issuance marks (HMAC of account·scope·day) | — | none: no post id, token value or tag |
| `vault.db` | `owner_locator` = HMAC(server, honeyId) | — | ciphertext only; roots exist on clients |
| `community.db` | — | posts, associations, reactions, reports, reservations, suspensions by authorTag | none: no honeyId, no account FK, no session |
| `access.db` | `subject_hash` (from the capability's short-lived pseudonym) | — | no name, email, honeyId, token or password |

Redaction of the raw school data: rosters are cut at the import adapter; `students` never enters any
table; class labels are stored as term · group type only.
