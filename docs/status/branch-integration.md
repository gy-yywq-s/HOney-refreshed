# Branch integration note — product-v2 pass

Date: 2026-09-01. Source: `docs/research/design-audits/repo-review-v3-2026-09-01.md` §1.

## Topology at freeze

```text
43d662c (shared merge base)
  ├── main @ 09c9562            (+6)   stable engineering skeleton, policy v6
  │     └── build/v1 @ 52b49d6  (+9)   Web PWA / cache / portal continuity / assets
  └── codex/ios-editorial-redesign @ 585e35c  (+5, diverged)  iOS hardening donor
```

Rollback tags: `review/main-09c9562`, `review/build-52b49d6`,
`review/codex-ios-585e35c`, `archive/preview-audit-p0`.

## Decisions

- **`integration/product-v2` branched from `build/v1`** — the linear latest base.
  All product-v2 work (backend contract fixes, moderation reorder, Experiences
  domain reset, Web presentation reset) lands here. The dev site
  (honey.gaelisus.com) deploys from this branch; `main` is only fast-forwarded
  after owner approval of the new core screens.
- **Codex branch is a donor, not a mergeable head.** It is 15 commits behind
  build/v1 and lacks policy v6 + all Web continuity work. Its
  behavior/performance work (TimetableRepository cache, Portal WebView state
  machine, Access state separation, local-store recovery, tests) will be ported
  file-by-hunk — never `git merge`. Its visual/product choices (four surfaces,
  placeholder wordmark, Home/Experiences composition) are NOT ported.
  **The iOS UI track is Gary's own right now; Claude holds off on all iOS work
  (including the donor ports) until Gary reopens it.**
- **`preview/audit-p0` archived** as a tag; the branch is no longer a work,
  acceptance, or merge base.

## Order of work on integration/product-v2 (non-iOS scope)

1. Phase 0 — this freeze + source-of-truth docs. ✅
2. §12.15 P0 contract correctness: login/consent contract split, report
   tri-state re-evaluation, reaction eligibility namespace, account-private
   reaction state.
3. §11 moderation ordered enforcement (Standing → Expression → Scope → Timing).
4. Phase 3 domain reset: Course first-class, experience_associations, complete
   PublicExperience payload, cursor feed with scopes.
5. Web presentation reset (web lab candidate A): feed-first Experiences,
   simplified Home, quiet type/palette, mobile screen-composition pass.
6. Privacy-truth copy alignment + external LLM disclosure.
7. Full tests + deploy; hold `main` for owner approval.
