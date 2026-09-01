# Decisions — 2026-09-01 (post-audit)

> **HISTORICAL (2026-09-01, product-v2 freeze).** This document records an experiment round or a
> superseded decision. It is evidence, not binding direction. The source-of-truth hierarchy is
> defined in `docs/status/current.md`; current design direction lives in
> `docs/design/web-lab.md` / `docs/design/ios-lab.md` under `docs/design/shared-product-design-invariants.md`.

Gary reviewed the repository against `audit-2026-09-01-repo-and-next-plan.md` and adopted it as the
binding next-phase instruction, with **two amendments that override the audit where they conflict**:

## 1. UI = copy the legacy design wholesale

The newly designed UI is rejected ("太丑了"). Instead of the audit's Product Style Constitution /
new canonical-screen design track (audit §6–§7, Phases 2 & 4), the V1 UI **directly reproduces the
legacy iOS design in full** — layout, composition, typography rhythm, color, iconography, the serif
wordmark, motion, the whole visual system. Web mirrors the same legacy design language. Redesign is
deferred ("之后要改再说").

Consequences:
- The earlier "never copy legacy code" rule is **lifted for the UI/presentation layer only**.
  Legacy SwiftUI views may be ported verbatim (adapted to the new service/application layer).
  Bands 2–4 (client app logic, backend, portal integration) still never copy legacy code.
- The codex→imagegen brand-generation track is **on hold**; the legacy brand identity (icon,
  serif wordmark) is the live brand.
- The audit's P0 **product/state-machine fixes remain required first** (consent, drafts, nudge,
  private notes, ownership keys, reports, unlinkability, WebView bridge, contract cleanup) — they
  define the states the ported UI must render.

## 2. `HOney` casing has zero tolerance

No occurrence of `HOney` (capital H, lowercase o) may exist anywhere — code, docs, spec headings,
UI copy, comments, commit messages. Acceptable forms are exactly two:
- `HOney` (canonical), or
- all-lowercase `honey` where capitals are genuinely impossible (package names, URLs, DB
  identifiers, the linux user, domains).

A repo-wide sweep enforces this and it stays enforced (CI grep gate).
