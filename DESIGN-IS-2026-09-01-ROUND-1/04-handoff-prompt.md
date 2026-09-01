# Design Is — Round 1 /make-plan Handoff

````
/make-plan Refine HOney Ionic Web/PWA based on a Dieter Rams audit (total 20/30).

Verdict paragraph (quoted from 03-verdict.md):
> REFINE — At 20/30 with no zero-scored principle, the Ionic Web/PWA has strong product bones and a restrained long-lasting system, but it cannot pass the 23-point acceptance threshold until honesty/state truth, accessibility detail, and responsive visual coherence are repaired.

Keep (already strong, do NOT touch in this pass):
- Principle #2 (useful) scored 3 — Evidence: apps/web-ionic/src/App.tsx:54-95 and apps/web-ionic/src/pages/ExperiencesPage.tsx:68-95. Regression check: run the browser matrix and confirm Home → Experiences → Compose/private/share and Timetable → lesson → lesson-bound Compose remain direct, with no new decoy step.
- Principle #7 (long-lasting) scored 3 — Evidence: apps/web-ionic/src/theme/variables.css:1-65, apps/web-ionic/src/theme/app.css:184-305, and apps/web-ionic/src/components/Wordmark.tsx:1-3. Regression check: confirm the approved /wordmark.png remains exact and grep/render for no gradients, glass, large radii, decorative motion, or card-wall regression.

Fix in priority order (top 3–5 moves from the audit, verbatim):
1. Principle #6 — Honest: Make Composer claims derive from real persisted state: add Saving/Saved/Failed state, preserve cooldown retry data and a resume action, distinguish publish success from ownership-key save failure, and disclose current OpenRouter/fallback/retention/region truth. Evidence: apps/web-ionic/src/pages/ComposePage.tsx:68-77,84-91,108-116,130,157,159; apps/web-ionic/src/pages/MinePage.tsx:71-78; apps/web-ionic/src/pages/PrivacyPage.tsx:4; docs/architecture/moderation-external-processing.md:12-18,26-40.
2. Principles #4/#2 — Understandable/useful: Make the context picker’s organized complete list include current/recent lessons, or remove lesson from the promise; replace internal “context” wording and keep Match/Different visible beside counts. Evidence: apps/web-ionic/src/pages/ComposePage.tsx:49-65,125-141; apps/web-ionic/src/components/ExperiencePost.tsx:102-106.
3. Principle #8 — Thorough: Raise every repeated feed action to at least 44px, replace failing faint text contrast, expose exactly one active main landmark, and make the skip link target unique and programmatically focusable. Evidence: apps/web-ionic/src/theme/app.css:19-35,69-70,260,263-266,289,303-304; apps/web-ionic/src/App.tsx:38-95.
4. Principles #3/#5 — Aesthetic/unobtrusive: Move the fixture disclosure out of compact-title collision, reconcile the 222px rail token with rendered width, remove duplicate desktop branding, and constrain Explore controls to the reading composition. Evidence: apps/web-ionic/src/theme/variables.css:17; apps/web-ionic/src/theme/app.css:149-162,205-208; docs/web/evidence/ionic-browser-2026-09-01/compact-375x667-experiences.png.
5. Principles #9/#8 — Environmental/thorough: Add route-level lazy splitting, ensure service-worker responses cannot be edge-cached for four hours, and resolve Cloudflare-injected-script CSP noise without weakening the strict application CSP. Evidence: apps/web-ionic/vite.config.ts:8-31; apps/web-ionic/server.mjs:21-28; current bundle 1,334,582 bytes raw / 305,258 bytes gzip and two current Chromium CSP console errors.

Out of scope for this refine pass: backend code or API-contract changes; iOS UI; the existing apps/web information architecture; claims based on live backend data; replacing the approved wordmark or established paper/ink/blue visual grammar.

Deliverables for the plan:
- Per-fix: target files, exact change, verification step
- Token/spec changes consolidated in one place
- Regression checklist for every "Keep" item above
- Current tests for persistence failure, cooldown resume, lesson picker completeness, skip-link focus, landmark count, touch targets, contrast, CSP console, service-worker cache headers, and all three viewport classes
- A fresh design-is review after deployment; repeat refine/review until total is at least 23/30

Anti-patterns to guard against (specific to REFINE):
- Adding new abstractions where a direct change suffices
- Restyling areas that already scored 3
- Scope creep into structural redesign (if structure must change, this should be REDESIGN, not REFINE)
- Letting fixes mutate principles outside the priority list
````

