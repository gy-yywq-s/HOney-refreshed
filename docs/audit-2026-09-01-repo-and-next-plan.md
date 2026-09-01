# HOney Refreshed — Repository Audit & Next Modification Plan

**Repository:** `gy-yywq-s/HOney-refreshed`  
**Reviewed branch:** `main`  
**Reviewed head:** `81589669c0c48031fe879440e6b1816317b8aa06`  
**Date:** 2026-09-01  
**Audit scope:** product specification, architecture documents, live-portal notes, backend/connector, shared contracts, Web implementation, iOS implementation, Experiences pipeline, design tokens and brand documentation.

---

## 0. Bottom line

The repository is **not a failed implementation**. Its strongest parts are the parts users do not directly see: portal integration, backend separation, timetable normalization, session coordination, typed Web/backend contracts, test discipline, and the basic Experiences data structure.

However, the repository currently conflates three very different levels of completion:

1. **implemented in code**;
2. **verified to satisfy a technical property**;
3. **approved as the intended product and design**.

The code and acceptance documents often treat level 1 as if it automatically proves levels 2 and 3. That is the main governance problem in the repo.

The current UI should be explicitly reclassified as a **functional presentation scaffold**, not as a nearly finished V1 design. Its generic quality is not only a matter of colors or polish. The product's distinctive philosophy has not been translated into a sufficiently concrete visual, verbal and interaction system. The code currently renders HOney mostly as a conventional card-based utility/dashboard, while the intended product is calmer, more personal, more school-native, more humane, and less institutional or technical.

At the same time, several issues currently described as UI shortcomings are actually product/state-machine problems and must be fixed before visual redesign:

- WebView portal expiry is not actually silently recovered.
- Timetable consent is preselected rather than actively granted.
- Experiences' optional nudge occurs after submission and auto-publication rather than before publication.
- A rephrase/fail-closed result can destroy the user's draft.
- iOS lacks a first-class private-note path.
- iOS sign-out deletes local ownership keys and permanently removes post control.
- Current Experiences submission is not protocol-unlinkable despite documentation claiming an unlinkable-credential architecture.
- The test corpus is too small for the confidence claimed by the acceptance document.

The correct next move is therefore **not** “polish the current screens.” It is:

1. reset the repo's truth/status model;
2. correct the P0 product/state/privacy mismatches;
3. create an executable Product Style Constitution and reproducible legacy baseline;
4. further separate Web presentation from client application logic;
5. prototype the canonical screens as a coherent system;
6. then replace the current UI against stable contracts.

---

# 1. Current maturity map

| Area | Current state | Recommendation |
|---|---|---|
| Portal API analysis | Strong and live-tested | Keep; extend only for WebView auth analysis |
| Native portal API session coordinator | Strong | Keep architecture; add WebView bridge |
| HOney backend/account model | Substantial | Keep; tighten consent/security details |
| Timetable import/normalization | Substantial and live-tested | Keep; formalize long-term history retention |
| Backend ↔ Web isolation | Strong | Keep |
| Shared TypeScript API contract | Good recent improvement | Keep; complete contract and generate Swift mirror |
| iOS presentation ↔ service separation | Reasonably good | Keep; refine view/application boundaries where needed |
| Web presentation ↔ application separation | Partial | Refactor before major UI rebuild |
| Experiences community philosophy | Strong in master spec | Productize in UI/copy/state machine |
| Experiences moderation implementation | Functional prototype with important mismatches | Rework submission flow before launch |
| Experiences anonymity | Stored-author minimization, not claimed protocol unlinkability | Implement real issuance flow or reduce claims |
| UI visual execution | Functional scaffold | Replace substantially |
| Product style system | Mostly tokens and generic components | Create a Product Style Constitution |
| Legacy continuity documentation | Mechanical and incomplete as a reusable design source | Rebuild as a reproducible visual baseline |
| Acceptance/status documentation | Overconfident | Replace with multi-axis verification states |

---

# 2. What is already good and should not be thrown away

## 2.1 Backend/client boundary

The repository correctly treats `/api/*` JSON contracts as the boundary between clients and backend. Web and backend now share `packages/shared/src/api/contract.ts`, and neither side imports the other's implementation. This means a visual rebuild does not need a backend rewrite.

Keep:

- `packages/shared`
- `packages/portal-connector`
- `packages/backend`
- `apps/web`
- `ios/HOney`
- the principle that backend responses describe domain state rather than screen layout

Do not interpret this as proof that **Web UI presentation and Web application logic** are fully separated; they are not yet.

## 2.2 Native portal session coordinator

`PortalSessionCoordinator.swift` has the right architecture:

- single-flight silent re-login;
- proactive refresh near expiry;
- safe reads retried once;
- physical/non-idempotent gate actions never automatically replayed;
- network/server failures do not erase credentials;
- only actual credential rejection or interactive challenge asks for user action.

This is one of the strongest parts of the repo and should be the basis for official Portal WebView recovery as well.

## 2.3 Portal facts and timetable import

The live-portal regression work has produced useful verified facts:

- portal API token TTL is roughly 24 hours;
- no refresh token exists, so a full re-login is required after expiry;
- the main lesson-table endpoint contains broad current/future-term coverage;
- weekly schedule has a limited historical window and needs special handling;
- Web Access is not viable because the actual response lacks required CORS permission.

The importer now upserts canonical lessons, teachers, rooms and user exposure and does not delete old rows during normal sync. That is a good foundation for HOney-owned history.

## 2.4 Access safety behavior

Access keeps networking out of the SwiftUI view and isolates failures to the feature. The non-idempotent gate-open behavior and confirmation are handled conservatively. The module can be visually rebuilt without changing the connector/session semantics.

## 2.5 Experiences' strongest conceptual decisions

Keep these decisions:

- raw-first content;
- no scalar ratings for teachers, lessons or classrooms;
- dish-only rating allowlist;
- verified exposure;
- no replies/DMs/follower system;
- reactions do not determine ranking or visibility;
- serious matters are outside the public feed;
- no ordinary author column on public Experiences;
- no normal human moderation queue;
- deterministic policy authority rather than free-form LLM authority;
- fail-closed behavior;
- ownership capability so a contributor can revoke their anonymous post.

These are real product decisions and should survive the UI rewrite.

---

# 3. P0 mismatches to fix before treating the product as stable

## 3.1 Official Portal WebView silent login is not implemented

The current `PortalWebView.swift` persists a `WKWebView` and a safe URL, which is useful. But when it sees HTTP 401/419, it only cancels navigation and reloads the same URL once.

It does not:

- call `PortalSessionCoordinator`;
- perform a full portal login with Keychain credentials;
- inject a compatible cookie/token into `WKHTTPCookieStore`;
- detect a 302 redirect or HTTP-200 login page;
- automate the official login form as fallback;
- restore the intended URL after rebuilding the session.

Therefore the requirement “normal Portal WebView expiry never asks for manual login” is currently **not implemented**.

### Required change

Create a `PortalWebSessionBridge` in the client application/service layer.

Its behavior should be determined after one focused Portal Web Auth Analysis:

1. identify the official site's actual login request;
2. identify cookie/localStorage/session artifacts;
3. determine whether the raw API token is accepted by the web portal;
4. determine whether native login can produce a web cookie;
5. map login-page/redirect detection;
6. implement one of:
   - native login -> cookie injection -> reload intended URL;
   - independent WebView HTTP login -> persistent WebView session;
   - form automation only as fallback.

`PortalWebController` should request a session from this bridge; it should not contain authentication logic itself.

## 3.2 Import consent currently defaults to yes

Both Web and iOS initialize timetable consent as selected:

- Web: `useState(true)`
- iOS: `@State private var importTimetable = true`

The master spec requires active, non-preselected import consent. This is a direct product mismatch.

### Required change

Prefer an actual two-step first-login flow:

1. authenticate/provision HOney account;
2. separate import explanation and active choice.

At minimum, default the control to false. The two-step flow is cleaner because “sign in” and “copy school data into HOney” are conceptually different decisions.

## 3.3 Experiences optional nudge is not a nudge

The policy has a `publish_nudge` lane, but the current asynchronous service immediately publishes it after background moderation. The user never sees the nudge before publication and never chooses “add context” versus “publish as is.”

This contradicts the intended product rule that low-information, low-harm speech remains publishable **after an optional pre-publication prompt**.

### Required change

Replace `publish_nudge` auto-publication with a client-visible preflight result:

```text
CHECK -> NUDGE
       -> Add context
       -> Publish as is
       -> Save privately
```

Only an explicit publish confirmation should produce the final public write.

## 3.4 Rephrase/fail-closed can destroy the user's draft

The current server initially stores a pending row, then clears its body on `rephrase_required`, `blocked`, or `failed_closed`. The client does not first persist an authoritative local draft. The “My contributions” page therefore tells the user that the text was not kept and asks them to try again.

This violates a central product promise: rejected public publication should not erase the user's own experience.

### Required change

The client should save the draft locally before any public attempt. Every non-publish outcome returns the user to that exact draft.

For both iOS and Web:

- draft saved before moderation request;
- `EDIT_REQUIRED` highlights the issue while preserving text;
- `UNCERTAIN_REPHRASE` preserves text;
- `FAILED_CLOSED` preserves text;
- `OUT_OF_SCOPE` offers keep-private/delete/channel guidance;
- successful publication may keep or delete the local draft according to explicit user choice.

## 3.5 iOS does not implement first-class private notes

The iOS composer has only Cancel/Post. The Six Checks are rendered in full, but the required `Save privately` path is absent.

### Required change

Add a local private-note repository and make `Keep private` a normal peer action alongside `Share`.

The product should not force the user to decide at the beginning whether they are “writing a public review.” The natural sequence is:

```text
record experience -> keep private or share -> publication preflight
```

## 3.6 iOS sign-out deletes ownership keys

`AppModel.signOut()` clears `ownershipKeyStore`. This means signing out permanently removes the student's ability to revoke/reconfirm their own anonymous posts.

That is not a harmless local cleanup; it changes the user's rights over their content.

### Required change

- Do not clear ownership keys on ordinary sign-out.
- On account deletion, separately explain the consequence and ask whether the user wants to export/preserve or intentionally destroy local post-control capabilities.
- Use Keychain/device-local durable storage rather than session lifecycle storage.

## 3.7 Current Experiences submission is not protocol-unlinkable

The public table has no author field, which is good. But the current route is authenticated and sends `honeyId + body` into the same service. Dedup/reaction marks are server-generated HMACs over `honeyId` and scope. This is not the one-time unlinkable eligibility-credential architecture described by the master spec.

The acceptance document acknowledges this as a substitute but then says the privacy property is met. That overstates what exists.

### Required decision

Because the intended product already chose cryptographic unlinkability from V1, implement the actual three-step shape:

1. authenticated eligibility issuer issues a scoped unlinkable token;
2. moderation issuer receives text/context but no HOney identity and returns a content-bound pass;
3. unauthenticated/pseudonymous community publish endpoint verifies both artifacts and stores the post.

If this is deferred, all UI/docs must immediately downgrade the claim to:

> “Published posts are stored without an author ID.”

Do not display “anonymous by construction” or claim Privacy Pass-style unlinkability until it is actually true.

## 3.8 The moderation pipeline stores content before moderation

Current behavior is:

```text
insert pending row with body -> run moderation -> publish or clear body
```

This conflicts with the stated “pre-publication / do not receive or persist serious content” posture and creates unnecessary pending-state complexity.

### Recommended change

Use two explicit calls:

```text
POST /api/experiences/check
-> publish | nudge | cooldown | edit | blocked | out_of_scope | uncertain

POST /api/experiences/publish
-> requires content-bound pass + eligibility token
```

At this project scale, a short purposeful moderation wait is better than a hidden asynchronous workflow that creates pending rows, polling, lost drafts and fake nudges.

## 3.9 Reports accept free text despite having no human-review workflow

The report route and UI allow an optional note, and the admin contract exposes that note. This creates an uncontrolled second UGC channel which can contain exactly the sensitive allegations and PII that the primary flow attempts to exclude.

### Required change

For V1, use category-only reports. If context is ever necessary, it must pass the same prepublication privacy/serious-content checks and have a defined consumer. Do not collect prose that nobody is supposed to manually investigate.

## 3.10 Acceptance documentation overclaims completion

`docs/acceptance.md` marks WebView silent recovery, nudge, privacy architecture and all launch gates as passed; it also uses an internal “Rams score” to declare the UI good enough despite the founder explicitly rejecting the UI.

The document also contains stale statements: live portal facts have since been confirmed, while some supposedly complete product flows remain placeholders.

### Required change

Replace binary PASS with separate fields:

- `Specified`
- `Implemented`
- `Covered by automated test`
- `Verified against live portal`
- `Security/privacy property demonstrated`
- `Founder product-approved`
- `Pilot-validated`

A design is not accepted because a subagent assigned it 25/30. Founder sign-off and user-task validation are separate gates.

---

# 4. Contract and data corrections

## 4.1 The TypeScript contract is good but not complete

Current remaining drift/weaknesses include:

- `EntityType` excludes Course even though the master IA lists Courses as a browsable Experiences object;
- `PublicExperience` exposes internal `status`, `status_detail`, and `policy_version` despite public feeds containing published content only;
- many fields such as provenance/status remain arbitrary strings;
- the route accepts `before` pagination while `ExperiencesFeedParams` does not;
- service errors such as `temporarily_suspended` and `target_required` are not in `SubmitExperienceError`;
- report route accepts any category string despite a typed union in the contract;
- the Swift model remains a hand-maintained mirror rather than generated from the contract.

### Required change

Split contracts into:

- public feed DTO;
- own-submission lifecycle DTO;
- moderation preflight DTO;
- final publish DTO;
- admin/ops DTO.

Generate OpenAPI or JSON Schema from the TypeScript contract and use code generation for Swift where practical. If Swift remains manual, add fixture/contract tests that decode real backend JSON in iOS CI.

## 4.2 “From your classes” must be a backend/domain query

Web currently downloads a general newest feed and filters it in the component using the user's teacher/course directory. This means:

- older relevant posts can disappear merely because they are outside the latest global limit;
- unnecessary content is fetched;
- product/domain filtering lives in a UI helper;
- Web and iOS can drift.

### Required change

Add a domain endpoint such as:

```text
GET /api/experiences/from-my-classes?before=&limit=
```

The backend should use verified exposure to produce the chronological slice. The UI only renders it.

## 4.3 Course is missing as a first-class Experiences entity

Current registry types are Teacher, Room and Dish. Courses exist only as context IDs, while the master spec says users can search/browse course experiences.

### Required decision

For a simple V1, use four conceptual targets:

- Lesson
- Teacher
- Course
- Place / Food item

Do not expand immediately into dozens of school entity types. But Course should either become first-class now or be removed from the promised V1 IA. The current half-state is confusing.

## 4.4 History deep-link is a placeholder

`/history/lesson/:id` currently renders the generic History list. Either implement the actual lesson-detail route or remove the route until it exists. Reserved routes should not count as completed acceptance criteria.

## 4.5 Long-term Course History must accumulate in HOney

The school API has a limited historical window in one endpoint. The importer currently upserts and does not delete historical rows, which is good, but the product contract should explicitly state:

- HOney keeps previously imported completed lessons after the upstream window stops returning them;
- periodic sync gradually forms HOney's durable course history;
- first-time users can only receive the historical range still available from the portal;
- no UI should imply that a new account has complete multi-year history when it does not.

This matters directly to retrospective Experiences eligibility.

---

# 5. Security and lifecycle corrections

## 5.1 Web HOney sessions should not live entirely in localStorage

Both access and refresh tokens are currently stored in `localStorage`, so any same-origin script injection can take the entire durable session.

Recommended end state:

- rotating refresh token in a Secure, HttpOnly, SameSite cookie;
- access token in memory or short-lived cookie depending architecture;
- CSRF protections appropriate to the chosen cookie flow;
- explicit device/session list only if later useful.

This is a security improvement, not a visual redesign dependency, but should be done before broad release.

## 5.2 Private-note “encryption” on Web must be described honestly

The note ciphertext and AES key are stored in the same localStorage. This protects against casual plaintext search/dumps but not against same-origin script access or full browser-profile access.

The code comments are honest; the user-facing copy should be equally precise. Do not imply strong cryptographic isolation.

## 5.3 Technical concepts should not dominate the user experience

“Ownership key,” “policy version,” “anonymous by construction,” and moderation status should be available in a detailed privacy/help view, not foregrounded on the main community page.

Users should primarily understand:

- HOney verifies relevant experience;
- public posts are not attached to their school account;
- their device holds the control needed to remove their own post;
- clearing/moving devices can affect that control.

The implementation model should be legible, but it should not become the product's emotional identity.

---

# 6. Why the current UI feels wrong

The UI is not merely “unfinished.” It is built from a visual grammar that is too generic for the intended product.

## 6.1 What currently exists

The design system currently defines:

- a cool-blue palette;
- system typography;
- a spacing scale;
- rounded corners;
- shadows/material-like surfaces;
- generic Card, Button, Banner, Empty State and List Row components.

This is a valid implementation foundation, but it is only a **token kit**, not a product style.

## 6.2 What is missing

There is no strong executable definition of:

- how HOney should feel emotionally;
- what makes a screen recognisably HOney beyond blue and rounded cards;
- what information receives visual dominance;
- when a card is semantically justified;
- how time, school context and human testimony should be represented;
- how much technical/privacy language appears at each level;
- how Home, Timetable, Experiences and Access each have a distinct “screen signature” while remaining one product;
- which visual patterns are explicitly anti-HOney.

As a result, almost every surface is a stack of bordered cards with headings, chips and buttons. That looks like a competent SaaS prototype, not a distinctive personal school companion.

## 6.3 The product philosophy lives in the spec but not in the interface

The Experiences spec contains strong phrases:

- More context, fewer verdicts.
- People are more than one experience. Experiences still matter.
- Specificity helps. Feelings still count.
- Negative is allowed. Cruelty is not.

The current hub instead foregrounds:

> “Anonymous by construction — posts carry no author, and your keys stay on this device.”

The current composer displays all Six Checks on every post. This turns a cultural space into a compliance form. Culture should be established through page posture, examples, progressive hints and the content itself; rules should appear contextually when relevant.

## 6.4 Legacy continuity has been reduced too far

The current audit defines legacy continuity mainly as:

- cool-blue color family;
- translucent rounded cards;
- Access mental model;
- Timetable Day view.

That is too shallow to preserve “overall feel.” It omits composition, typography rhythm, density, motion, use of negative space, hierarchy, icon character, and the emotional relationship between screens.

The audit also references a local `reference/legacy-ios/` directory that is not present in the repository, so another contributor cannot reproduce or challenge the audit.

## 6.5 Brand documents conflict

Current sources simultaneously say:

- legacy serif identity is dropped;
- several generated wordmarks/icons await selection;
- the current iOS bundle uses a legacy `HOney_icon_v2` asset;
- the master spec asks for recognisable continuity;
- user-facing casing must be `HOney`, while several master headings still say `HOney`.

This must be resolved into one canonical brand decision rather than left as parallel experiments.

---

# 7. Product Style Constitution to add before redesign

Create `docs/product-style.md`. It should be binding in the same way as the product spec, not an inspiration note.

## 7.1 Proposed style pillars

### 1. Calm, not vacant

Use space and restraint, but do not hide useful context. A screen should have one clear focal object rather than many equal cards.

### 2. Personal, not social-media-like

HOney is about *my school day* and a shared memory of school life. No follower grammar, engagement bait, trending, popularity theatre or avatar-led feed.

### 3. Quietly academic, not institutional

The product can feel serious, thoughtful and precise without looking like a school administration system, enterprise dashboard or formal evaluation form.

### 4. Humane, not sentimental

Acknowledge ambiguity, discomfort and mixed experience. Do not use cute positivity, moralizing instructions, or sterile policy language as the dominant voice.

### 5. Context-rich, not metric-heavy

Time, course, teacher, room and provenance are useful context. Scores, dashboards, status chips and numerical summaries should be rare.

### 6. Familiar, not trapped by legacy

Preserve the recognisable icon/blue family/overall restraint and the strongest mental models. Rebuild hierarchy, typography, motion and interaction where the old product is weak.

## 7.2 Binding composition rules

- One primary focal object per screen.
- Do not put every section inside a Card.
- Use cards only for genuine self-contained objects/actions.
- Prefer continuous layouts, dividers and spatial hierarchy for lists/timelines.
- Content appears before technical provenance or privacy explanation.
- Show status only when it changes what the user can do.
- Avoid all-caps overlines/chips as a default hierarchy device.
- Keep primary actions singular; secondary actions recede.
- Use color primarily for state and identity, not decoration everywhere.
- Technology/privacy explanations are one tap deeper unless immediately needed for informed choice.

## 7.3 Anti-patterns

Explicitly mark these as anti-HOney:

- card-dashboard composition;
- generic SaaS admin aesthetic on student surfaces;
- every page beginning with a huge title plus primary button;
- policy/cryptography language as homepage copy;
- large collections of pills/chips/segmented controls;
- showing multiple equally prominent actions;
- turning Experiences into a moderation-status workflow;
- giving every lesson/entity a score;
- relying on pale blue alone to create identity.

## 7.4 Screen signatures

### Home — “today at a glance”

Next Lesson is the visual center. Welcome is quiet, not a dashboard title. Experiences appears as one human prompt or a small contextual glimpse, not a full card feed. School Portal is a low-priority utility route.

### Timetable — “the rhythm of a day”

Use a continuous temporal rail/timeline. Lesson blocks belong to the day rather than appearing as unrelated cards. Current time and gaps should be meaningful. Date navigation should feel lightweight.

### Experiences — “a shared memory, read slowly”

Text and context lead. Teacher/entity browsing should feel closer to reading a thoughtful archive than scanning a social feed. Privacy is visible but not the headline. No engagement-first layout.

### Compose — “record first, publish deliberately”

The first act is writing/recording an experience. Private/public is a deliberate outcome. Rules emerge only when relevant. The user always retains the draft.

### Access — “one decisive real-world action”

The primary gate action is obvious and safe. Permit application/history is progressively disclosed. The interface should feel immediate and confident, not like a dashboard form.

### Login — “one calm doorway”

One clear school-account action, followed by separate data-import consent. Avoid presenting architecture explanations as a wall of footnotes.

---

# 8. Frontend architecture to prepare for the redesign

## 8.1 Web: backend separation is good, UI/application separation is incomplete

Current pages directly call APIs, own loading/error state, filter domain data, resolve names, maintain reaction state and construct report workflows. `pages/experiences/shared.tsx` mixes:

- API hooks;
- product/domain filtering;
- name resolution;
- UI components;
- reactions;
- reporting.

A full visual rewrite would therefore still risk rewriting behavior.

### Recommended feature structure

```text
apps/web/src/features/experiences/
  domain/
    models.ts
    copy.ts
    selectors.ts
  application/
    useExperiencesHub.ts
    useExperienceComposer.ts
    useMyContributions.ts
    useExperienceEntity.ts
  ui/
    ExperiencesHubPage.tsx
    ExperienceText.tsx
    EntityHeader.tsx
    ComposeSurface.tsx
```

Likewise for Home, Timetable and Access-capability state.

Pages should render a presentation-ready view model and dispatch typed intents. They should not decide “from my classes,” eligibility, publication-state semantics or storage lifecycle.

## 8.2 Web CSS

Split the single large stylesheet into:

- `tokens.css` — generated;
- `foundations.css` — typography/reset/layout primitives;
- `components/*` — truly reusable UI primitives;
- `features/*` — feature compositions;
- `admin/*` — admin-only visual system.

Do not carry generic `.card` everywhere into the redesign.

## 8.3 Token source of truth

`tokens.css` currently says it is manually mirrored from `tokens.json`; Swift Theme is also hand-copied. This is not a real single source.

Add a small checked-in generator:

```text
design/tokens/tokens.json
  -> apps/web/src/styles/generated-tokens.css
  -> ios/HOney/DesignSystem/GeneratedTokens.swift
```

But do this **after** the Product Style Constitution and visual direction are decided; otherwise code generation only freezes the wrong tokens more efficiently.

## 8.4 iOS

The iOS View/ViewModel/Services split is a good base. Keep it.

Before visual redesign:

- move reusable product state out of views where it affects behavior;
- add a proper private-note repository/use case;
- wire WebView session recovery through a service;
- create feature-specific components instead of using generic `Card` as the main grammar;
- add SwiftUI previews/fixtures for canonical states.

## 8.5 Admin surface

The admin dashboard is an operational tool with a different audience. It should not define the student product style. Prefer a separate route shell and CSS scope; a separate Web entry/bundle can come later if useful.

---

# 9. Recommended screen redesign order

Do not redesign every current page independently. First design a small canonical set that establishes the whole system:

1. **Login + import consent**
2. **Home**
3. **Timetable Day view + lesson detail**
4. **Experiences hub**
5. **Teacher/entity page**
6. **Record/private/publish composer and all action states**
7. **Access primary flow**
8. **Web responsive adaptation of the same system**

The composer is especially important because it expresses the community philosophy more clearly than the feed itself.

For each canonical screen, require:

- normal state;
- loading state;
- empty state;
- recoverable error;
- stale/portal-offline state where applicable;
- Dynamic Type/narrow viewport;
- dark mode;
- reduced motion.

---

# 10. Moderation corpus and validation

The current regression corpus is far too small for the acceptance document's confidence. It contains only a small set of lexical/feature/live cases.

Before pilot, expand it to a deliberately balanced corpus, not merely more harmful examples.

Suggested minimum starting composition:

- ordinary positive statements;
- ordinary harsh negative statements;
- mixed/nuanced statements;
- hard-to-explain discomfort;
- low-information comments;
- high-arousal opinions;
- hearsay;
- privacy/PII;
- serious/out-of-scope allegations;
- Chinese;
- English;
- Chinese-English code-switching;
- school slang;
- euphemisms/coded attacks;
- Unicode/spacing/emoji obfuscation;
- prompt injection/evasion;
- quoted suspicious text that should not false-positive;
- urgent facility/food safety examples.

The acceptance claim should be:

> “zero misses in the versioned critical regression suite”

not:

> “zero serious content can ever publish.”

---

# 11. Prioritized modification plan

## Phase 0 — Freeze feature expansion and reset truth

Do not add new product features or polish the current UI.

Actions:

- label current Web/iOS UI as `functional scaffold`;
- replace `docs/acceptance.md` with multi-axis status;
- reconcile README, master spec, decisions, architecture docs and code;
- remove stale “remaining work is only external” language;
- change current “anonymous by construction” claims until actual unlinkability ships;
- mark WebView silent recovery as open;
- mark product design as not founder-approved.

## Phase 1 — Fix P0 state/product/privacy behavior

Order:

1. consent flow/default;
2. local draft preservation on both platforms;
3. iOS private notes;
4. moderation preflight + real nudge;
5. remove pending-before-moderation persistence;
6. ownership-key lifecycle/sign-out fix;
7. remove free-text reports;
8. actual unlinkable eligibility/publish split;
9. Portal Web Auth Analysis + WebView bridge;
10. contract cleanup.

Do these before a large UI implementation because they determine the screens and states the design must support.

## Phase 2 — Establish the real design source of truth

Create:

- `docs/product-style.md`;
- `design/legacy-baseline/` with selected screenshots and annotations;
- `design/screen-principles.md` or canonical screen specs;
- one canonical brand decision for icon, wordmark and `HOney` casing;
- explicit anti-patterns;
- platform adaptation rules.

Archive or clearly label unselected generated brand concepts so they are not mistaken for live directions.

## Phase 3 — Refactor frontend application boundaries

Web:

- extract feature application hooks/view-models;
- move “from your classes” to backend domain API;
- split `shared.tsx`;
- split CSS;
- separate admin styling;
- complete or remove placeholder routes.

iOS:

- preserve ViewModel/service structure;
- add missing product use cases;
- keep session and domain logic out of views;
- add preview fixtures.

## Phase 4 — Prototype and approve canonical screens

Create a coherent prototype of the eight canonical surfaces before production styling. Evaluate it against the Product Style Constitution and actual legacy references.

Design acceptance is:

- founder-approved as recognisably HOney;
- task-complete;
- internally coherent across iOS/Web;
- not merely a high numerical score from an automated design audit.

## Phase 5 — Implement the new presentation layer

Replace current screen composition while preserving stable application/backend contracts.

Only change API contracts where Phase 1 discovered a genuine product-contract issue.

## Phase 6 — Closed pilot

Use actual students to check:

- whether Home is immediately useful;
- whether Timetable reads faster than the portal;
- whether users understand private record vs public share;
- whether Experiences feels humane rather than institutional;
- whether users interpret reactions as resonance, not truth;
- whether culture emerges from examples without forcing an essay;
- whether Access remains fast and safe.

---

# 12. Concrete issue backlog

## P0 — Product correctness / trust

- `[PORTAL] Complete real Web Portal auth analysis`
- `[PORTAL][iOS] Implement PortalWebSessionBridge; replace reload-only expiry handling`
- `[CONSENT] Separate first login from timetable import consent; default unselected`
- `[EXPERIENCES] Preserve local draft before every publication attempt`
- `[EXPERIENCES] Add first-class private notes on iOS`
- `[EXPERIENCES] Replace async pending-row pipeline with preflight + final publish`
- `[EXPERIENCES] Make optional nudge require user choice`
- `[EXPERIENCES] Keep ownership keys across ordinary sign-out`
- `[PRIVACY] Implement actual unlinkable eligibility/publication credentials or downgrade copy`
- `[REPORTS] Remove optional free-text report note`
- `[CONTRACT] Split public/own/moderation/publish DTOs and close error/field drift`
- `[DOCS] Replace binary acceptance scoreboard and correct false PASS states`
- `[BRAND] Make `HOney` the canonical user-facing casing everywhere`
- `[DESIGN] Write Product Style Constitution before visual implementation`

## P1 — Product quality and maintainability

- `[EXPERIENCES] Add Course as first-class entity or explicitly remove it from V1 promise`
- `[EXPERIENCES] Add backend from-my-classes endpoint`
- `[HISTORY] Implement lesson deep-link/detail or remove placeholder route`
- `[TIMETABLE] Document durable accumulated history and first-login coverage limits`
- `[WEB] Move page behavior into feature application hooks/view-models`
- `[WEB] Split Experiences shared.tsx and app.css`
- `[WEB][SECURITY] Replace durable localStorage session tokens with HttpOnly-cookie architecture`
- `[DESIGN] Add reproducible legacy screenshot baseline`
- `[DESIGN] Resolve icon/wordmark/serif/generated-concept conflicts`
- `[DESIGN] Generate Web and Swift tokens from one approved source`
- `[MODERATION] Expand bilingual/adversarial/cultural corpus substantially`
- `[IOS] Add contract fixtures or generate models from OpenAPI/JSON Schema`

## P2 — Only after pilot

- broader non-teacher entities;
- facility ratings or additional numerical systems;
- additional analytics;
- stronger network anonymity relay;
- expanded admin workflows;
- features beyond Home/Timetable/Access/Experiences.

---

# 13. Definition of the next good checkpoint

The next checkpoint should **not** be “the UI looks better.” It should be reached when:

1. the repo honestly says which properties are implemented and which are not;
2. the six P0 Experiences states preserve the user's draft and behave as the product intends;
3. consent is genuinely active;
4. Portal WebView recovery has a tested real authentication path;
5. privacy wording matches the actual protocol;
6. Web presentation can be replaced without rewriting API/domain behavior;
7. one Product Style Constitution and one legacy visual baseline can guide any future designer;
8. canonical iOS screens are founder-approved before broad implementation.

At that point, the existing backend and connector become a reliable foundation rather than a constraint, and the UI can be rebuilt as the actual HOney product instead of being polished as a generic scaffold.
