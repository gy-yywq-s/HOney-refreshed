# Access Legacy Parity Map

Required by master spec §21. Maps the legacy Access implementation
(`reference/legacy-ios/`, `AccessScreen` + `PortalStore` + `PortalAPI`) to the V1 rebuild, so the
proven behavior is preserved while the architecture is replaced. V1 Access is **native-first and
calls the school Access API directly from the client — Honey never relays** (§11.2, verified:
the backend exposes no Access route).

## Current screens & user actions

| Legacy screen/action | V1 equivalent | Port verdict |
|---|---|---|
| Apply-permit card (Start / End / Reason, Quick-Apply defaults, +1 midnight badge) | iOS `AccessView` apply-permit card | **Port (refined)** — same fields + quick-apply defaults; new visuals/tokens |
| All-permits list (status chips, collapse to N) | iOS permit list | **Port (refined)** |
| Open-gate: Commuter vs Exit-Permit route | iOS open-gate routes | **Port unchanged (behavior)** |
| Gate picker Front / Back | iOS `DoorChoice` picker | **Port unchanged** |
| Confirmation overlay (Change gate / Confirm / Cancel) | iOS confirm sheet | **Port (refined)** |
| Preview/live tag when real access disabled | iOS live/preview state | **Port** |

## Upstream endpoints & request patterns (direct client → school)

| Purpose | Method + path | Success rule | Notes preserved |
|---|---|---|---|
| Load permits | `GET /api/exit/get_student_list` | `status===0`, `data.rows` | unpaginated |
| Load gates | `GET /api/user/get_door_list` | **`status===1`, doors in `message[]`** | non-standard quirk kept |
| Apply permit | `POST /api/exit/add_record` `{start_time,end_time,note}` | `status===0 \|\| code===200` | default note "出门" |
| Open gate | `POST /api/exit/update_door_flag` `{record_id,status:1,door_id,indexcode}` | `status===0 \|\| code===200` | `door_id===indexcode`; **commuter `record_id=-2`**; NON-idempotent |

Auth header is the **raw token** (no `Bearer`). Front/Back gates are resolved against the live
door list by keyword matching (`front/main/大门/正门/前门` vs `back/后门`), falling back to
first/second entry — ported into the connector.

## Credential / token behavior

- Token in device Keychain (`AfterFirstUnlockThisDeviceOnly`, not synchronized).
- **Corrected from legacy** (legacy-gap list): expiry detected on HTTP 401 + `status:400001`
  (legacy only checked 403); availability failures preserve the session (legacy signed out on any
  error); silent re-login is **single-flight** (legacy logged in per-request); recovery
  credentials are **not biometric-bound** (legacy required Face ID every recovery); openDoor is
  **never auto-replayed** after a refresh (legacy replayed every operation).

## States & errors

Isolated Access error state — a failing Access API must not disturb Home/Timetable/Experiences
(§16.5). Door-open timeout → `outcomeUnknown`, **no automatic second POST** (the gate may have
physically opened; only the user retries). Empty/degraded door list → "Access temporarily
unavailable", no open attempt.

## Port-unchanged vs adapt

- **Unchanged (behavior/contract):** the four endpoint shapes + quirks, commuter sentinel,
  Front/Back mapping, permit status semantics (`0 pending / 1 approved / 2 rejected / 3 opened`),
  openable-permit window check.
- **Adapted (architecture):** networking moved out of the view into
  `PortalAPI` + `PortalSessionCoordinator` (actor) so the Access UI can be redesigned
  independently (§2.3, §20.33); durable door-key/PII caching removed; error/replay policy made
  explicit.

## Blocker note

The legacy app bundle used here is `reference/legacy-ios/` (present on the workspace, not vendored
into git). No additional legacy source is pending. Facts that only a real school **test account**
can confirm — exact token TTL, fresh-login success schema, real door-open success/timeout
envelope — remain flagged for pre-ship verification; the connector encodes the documented best
evidence and its mock reproduces every quirk above.
