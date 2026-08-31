# HOney

**HOney** is a student companion app (iOS + Web) for daily school life: your timetable at a
glance, campus gate access from your phone, and **Experiences** — an anonymous, verified peer
community about lessons, teachers, classrooms and canteen food.

The school's official portal stays what it is: the source of identity and timetable data. HOney
owns everything on top — its own accounts, normalized data, derived state and community — so the
product works even when the portal is slow, down, or logged out.

> Status: **V1 ground-up rebuild in progress.** Spec-driven; see
> [`docs/honey_master_spec_v1.md`](docs/honey_master_spec_v1.md) (the source of truth) and
> [`docs/decisions-2026-08-31.md`](docs/decisions-2026-08-31.md) (binding product refinements).

## What V1 ships

| Surface | Modules |
|---|---|
| **iOS** (Swift) | Home · Experiences · Timetable (Day view) · **Access** (direct-to-school gate control) |
| **Web** (TypeScript) | Home · Experiences · Timetable (+ admin dashboard; Access is capability-gated) |
| **Backend** (TypeScript/Node) | Honey accounts & sessions · school-portal connector · normalized timetable/history · Experiences community with anonymous, fail-closed moderation |

Deliberately **not** in V1: exams, week-view timetables, rankings, AI summaries, scalar ratings of
any human (only canteen dishes can carry a 1–5), or any server relay for Access operations.

## Architecture

Four responsibility bands, one-way dependencies (spec §1.5): a UI redesign must never force a
backend rewrite, and domain rules never live in view components.

```mermaid
flowchart LR
  subgraph Clients
    IOS[iOS app\nSwiftUI]
    WEB[Web app\nTypeScript + React]
  end
  subgraph Honey["Honey Core (TypeScript/Node)"]
    API[Honey Domain APIs\naccounts · sessions · data]
    EXP[Experiences services\neligibility · moderation · community]
    CONN[School Portal Connector\nBand 4]
  end
  PORTAL[(School portal\nexternal identity & data source)]

  IOS --> API
  WEB --> API
  IOS --> EXP
  WEB --> EXP
  API --> CONN
  CONN --> PORTAL
  IOS -. "Access operations\n(direct, never relayed)" .-> PORTAL
```

Key properties:

- **One login.** A school account is the only credential; a successful school login provisions or
  reconnects your Honey account. Honey, native-portal and WebView sessions stay independent —
  portal expiry never signs you out of Honey.
- **Zero manual re-login.** Normal portal token expiry is recovered silently (device-held
  credentials; single-flight re-auth; safe reads replay once, physical actions never do).
- **Anonymous by architecture.** Public experiences store **no author field**; eligibility uses
  one-time unlinkable credentials; moderation passes bind to content hashes, not people; users
  keep a device-held ownership key to revoke their own posts.
- **Fail-closed moderation, fast.** A deterministic policy engine + a narrowly-scoped LLM feature
  extractor issue signed publication passes; publication is async so the user never waits on a
  spinner. If moderation is unavailable, nothing publishes (drafts stay private) — never
  publish-first-review-later.

Per-stage documentation lives in [`docs/architecture/`](docs/architecture/):

| Stage | Doc | What it covers |
|---|---|---|
| M0 | [`m0-foundation.md`](docs/architecture/m0-foundation.md) | Monorepo layout, toolchain, CI |
| M1 | [`m1-portal-connector.md`](docs/architecture/m1-portal-connector.md) | Portal auth state machine, endpoints, failure matrix |
| M2 | [`m2-honey-core.md`](docs/architecture/m2-honey-core.md) | Accounts, sessions, consent, data API |
| M3 | [`m3-experiences.md`](docs/architecture/m3-experiences.md) | Anonymity model, entities, ops |
| ★ | [`moderation-pipeline.md`](docs/architecture/moderation-pipeline.md) | **The moderation pipeline** — layers, LLM constraints, pass mechanics |
| M5 | [`m5-web-and-deploy.md`](docs/architecture/m5-web-and-deploy.md) | Web app, admin dash, single-origin deploy |
| M4/M6 | *(added as each milestone lands)* | |

## Repository layout

```
packages/shared            Domain types + portal wire contract (the API of the boundaries)
packages/portal-connector  Band-4 school-portal connector (auth coordinator, endpoints, mock portal)
packages/backend           Honey Core backend (Fastify)
apps/web                   Web app (Vite + React)
ios/                       iOS app (Swift; built via GitHub Actions macOS runners)
design/                    Brand + design tokens
docs/                      Spec, decisions, per-stage architecture docs
```

## Development

```bash
pnpm install
pnpm -r build && pnpm -r typecheck && pnpm -r test
pnpm dev:backend   # or: pnpm dev:web
```

CI runs the same sequence on every push; iOS builds run on macOS runners (`.github/workflows/ios.yml`).

## License

MIT — see [LICENSE](LICENSE).
