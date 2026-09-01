# Round 1 refinement execution

The Round 1 `20/30 · REFINE` handoff was executed after the sign-in and HTTPS
stability fix at `a000fc0`.

## Product truth

- Composer draft copy now moves through `Saving`, `Saved`, and explicit failure
  based on the actual `localStorage` write.
- A successful public publish is no longer reported as failed when the device
  cannot persist its private ownership key. The public state and local-control
  failure are shown separately, with an in-memory retry action.
- Cooldown notes retain target, label, body, and timestamp, and expose a
  `Continue draft` action from Mine.
- The picker includes deduplicated current/recent lessons as well as the full
  entity directory. Reaction labels remain visible beside counts.
- Privacy copy names OpenRouter, the Mistral/DeepSeek fallback path, verbatim
  candidate-text transfer, unverified provider retention, and unpinned region.

## Accessibility and responsive craft

- One stable, focusable `main#main-view` owns the active app; retained Ionic
  pages no longer duplicate main landmarks or skip-target IDs.
- The light `--honey-faint` token is `#73746f` (`4.71:1` on white).
- Repeated feed actions are at least `44px` in both dimensions.
- The fixture disclosure no longer collides with compact headers; the desktop
  rail is pinned to the 222px token; Home does not repeat the wordmark beside
  the rail; Explore controls and results share the 710px reading spine.

## Runtime and edge behavior

- App pages use route-level `React.lazy` chunks. The production build emits
  named page chunks instead of placing every page in the entry module.
- `sw.js` receives origin, generic CDN, and Cloudflare-specific `no-store`
  directives plus `Service-Worker-Allowed: /`.
- SPA HTML receives `Cache-Control: no-cache, no-transform`. Cloudflare states
  that `no-transform` prevents JavaScript Detections injection, avoiding the
  CSP noise without weakening `script-src 'self'` or changing zone-wide Bot
  Fight settings.

## Verification before deployment

- TypeScript: pass.
- Vitest: 10 tests pass.
- Playwright: 13 tests pass at compact mobile, regular mobile, and desktop.
- Production PWA build: pass; route chunks emitted; service worker generated.
- Full Ionic source ESLint: pass (repository package-type warning only).
- Strict-CSP and no-gradient/no-glass/no-large-radius grammar retained.

Live edge headers, Cloudflare HTML injection, screenshots, and the Round 2
design-is score are post-deployment gates.
