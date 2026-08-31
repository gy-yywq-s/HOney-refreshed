# HOney V1 — product decisions from Gary (2026-08-31, overrides/refines spec where stated)

These are binding refinements on top of `honey_master_spec_v1.md`. Where silent, the spec controls.

## Experiences meta-object scoping
- Reviewable/experience-able objects in V1 are limited to: **lesson**, **individual classroom**,
  **individual teacher**, **individual canteen dish (food item)**.
- A lesson experience is NOT pre-classified as being "about" teacher/course/room. It simply carries
  its lesson context (teacher, course content, classroom are all related); **filtering** can later
  surface it under a specific course / teacher / room etc. ("select all related").
- Teachers / courses / classrooms accumulate **organically from imported student timetables**.
- Standalone entities can ALSO be **imported independently by the admin**; the entity set is the
  **union** (dedup/merge with organic ones). Import tooling must be genuinely good — the admin UX
  matters ("it is me using it" — Gary).

## Eligibility
- **Own lessons:** every student always has the right to review their own attended lessons.
- **Standalone objects (teacher/classroom/dish):** admin configures who is eligible; default logic
  follows the spec (verified exposure), but **admin can override with other rules and can invite**.
  Admin can also **close standalone-object review for everyone** (global off switch).

## User-side history, revoke, re-review — WITHOUT server-held identity
- Users must see their **own submission history** (public experiences together with private notes;
  private visually differentiated).
- Users can **revoke** or **re-review**. One review per lesson per user. Standalone-object
  re-review rules are more complex — **backend supports it; final product rules wait for Gary**
  (admin can close standalone permissions globally meanwhile).
- Anonymity mechanism: server stores **no author identity**. At publish time the client generates
  and stores a **local ownership key** (per-post capability/secret, e.g. an edit-token or keypair);
  revocation/re-review presents that key. Settings must warn: **these keys live only on-device —
  if deleted, control over those posts is gone forever.**

## Moderation LLM (OpenRouter)
- Priority: **fast and low-cost**; multiple models benchmarked (latency, strict-JSON compliance,
  judgment sanity); pick a fast default, keep model configurable via admin dash.
- Test key is ephemeral (revoked after testing); production key set in admin dash. Server-side only.

## Ops
- GitHub Actions: use freely (billing is fine per Gary) — push branches, let CI run.

## HOney account provisioning (Gary, later same night)
- No standalone signup: **school-portal login + import IS signup**. On first successful login,
  assign a random **honeyId** (6 chars, unambiguous alphabet, collision-checked) as the user's
  Honey identity.
- Engineering standard: optimal solution within feasible/no-high-cost range for every technical
  detail; standard library first (`node:sqlite` for storage, `node:crypto` for ids/tokens/crypto).
