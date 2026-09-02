# HOney
## Ground-Up Product & System Specification

**Version:** 1.3 (frozen; product decisions since 2026-09-01 live in `docs/product/product-and-style-constitution.md`; Experiences logic of record is policy v7 in `packages/backend/src/experiences/policy.ts`)  
**Date:** 2026-09-01  
**Status:** Product and architecture baseline for a full rebuild  
**Platforms:** iOS + Web  
**Primary principle:** Build only features with a clear, durable user purpose. Prefer one good path over multiple overlapping views.

---

# 0. Executive decisions

HOney is being rebuilt from the ground up. The previous **architecture** is not a compatibility target, but the previous HOney app remains an important **design reference**. Its overall visual character, product feel and recognisable identity should carry forward, while the new implementation is free to substantially improve UI hierarchy, interaction quality, component consistency, accessibility and cross-platform behavior. The **Access** module's proven product behavior remains the strongest direct legacy-parity target and will be ported/refined from the existing app bundle when that code is supplied.

The new product has two conceptual system layers:

1. **HOney Core** - HOney's own account system, backend, imported school data, derived product state, Experiences community, sessions and cross-platform APIs.
2. **School Portal Integration** - the school portal as an external identity/bootstrap provider and upstream data source. It is not HOney's product database and should not dictate HOney's internal architecture.

Across those system layers, implementation must also preserve a strict **presentation/application/backend separation**. End to end, responsibilities are divided into four bands:

1. **UI Presentation** - visual hierarchy, components, interaction rendering and platform-specific presentation;
2. **Client Application Logic** - screen/view state, user intents, navigation coordination, local-only state and adapters to backend contracts;
3. **HOney Backend Domain Logic** - accounts, imports, sync, derived product rules, Experiences eligibility/moderation/community rules and persistent HOney state;
4. **School Portal Integration** - upstream authentication and source/API translation.

A UI redesign must not require backend business logic to be rewritten merely because the visual presentation changed. Conversely, backend/domain rules must not live inside view components.

The school account is the only enrollment credential. Users do **not** create a separate HOney username/password. A successful school-account login automatically provisions or reconnects the corresponding HOney account. After that, HOney has its own account identity and session lifecycle.

V1 deliberately contains **no Exams module**.

V1 top-level iOS navigation is exactly:

- **Home**
- **Experiences**
- **Timetable**
- **Access**

V1 top-level Web navigation is:

- **Home**
- **Experiences**
- **Timetable**
- **Access only if direct browser-to-school-API access is technically supported by the school API**

Timetable has **one Day view only**. There is no Week view and no second alternative timetable representation.

Course/Lesson History exists as one shared secondary page. It is reachable from Timetable for browsing past lessons and from Experiences in selection mode when the user wants to record or publish an experience about something they previously attended.

Access is native-first and makes its operational school-API calls **directly from the client to the school API**. HOney's backend does not relay Access operations.

Home also contains a secondary **School Portal** entry that opens the official portal in a persistent iOS WebView. HOney, native portal API, and WebView portal authentication states remain separate; iOS silently restores expired portal sessions while the school's authentication requirements remain materially unchanged.

Experiences remains the major community layer specified in detail in Appendix A. Human entities and lessons have **no scalar rating**. Scalar ratings are allowed only for low-stakes, naturally rateable consumption objects such as canteen food items.

---

# 1. Product philosophy

## 1.1 Simplicity is an explicit product constraint

HOney should not accumulate features merely because the school portal exposes data or because a feature is technically easy to build.

A V1 feature should exist only when at least one of the following is true:

- it solves a recurring student task directly;
- it removes meaningful friction from a task students already perform;
- it is required infrastructure for another clearly valuable feature;
- it creates a clear social-information benefit in Experiences.

The default response to an unproven feature idea is **not in V1**.

This is why Exams is removed, Timetable is reduced to one view, Access is ported instead of expanded, and Course History is implemented as a shared secondary route rather than a new top-level product area.

## 1.2 HOney owns the product state

The school portal is a source, not HOney's runtime database.

Once a user explicitly agrees to import supported school data into HOney:

- HOney normalizes it into HOney's own data model;
- HOney can use it for clearly defined backend-derived features;
- HOney can serve the same imported state to iOS and Web;
- HOney remains usable when the school portal is temporarily unavailable, with stale-state labeling where relevant.

This avoids making every HOney feature a live wrapper around the portal and avoids forcing all derived behavior to run locally on a device.

## 1.3 No speculative analytics

The ability to store school data on HOney's backend is not permission to invent dashboards or analytics without a product purpose.

For V1, imported timetable data has three defined uses:

1. render the user's timetable;
2. compute Next Lesson and Course/Lesson History;
3. establish verified exposure for Experiences.

Additional server-side analysis requires a separately approved product use case.

## 1.4 Legacy design continuity, not legacy UI parity

The legacy HOney app is a **design source**, not a screen-by-screen implementation specification.

The rebuild should preserve what makes the existing product recognisably HOney while being willing to redesign any element whose hierarchy, interaction, legibility or usability can be materially improved. The intended result should feel like a more mature version of the same product, not either of these extremes:

- a pixel-for-pixel port constrained by old UI decisions; or
- an unrelated redesign that discards HOney's established visual character merely because the codebase is new.

### What should generally be preserved

When the legacy app/source/assets are available, treat the following as presumptive continuity targets:

- overall visual mood and brand character;
- the recognisable relationship among icon, typography, spacing and surface treatment;
- the restrained, simple feel of the existing product;
- interaction patterns that are already clear and efficient;
- distinctive legacy elements that users would reasonably recognise as part of HOney rather than incidental implementation details.

Preservation does **not** mean copying every measurement or control exactly.

### What should be actively improved

The rebuild may and should improve:

- information hierarchy;
- typography, spacing and density;
- component consistency;
- navigation clarity;
- touch targets and accessibility;
- loading, empty, stale-data and error states;
- transitions and motion where they communicate state;
- the relationship between Home, Experiences, Timetable and Access;
- responsive behavior on Web;
- platform-appropriate interaction differences between iOS and Web;
- any legacy flow that requires unnecessary steps or duplicates another view.

### Design decision rule

For each legacy pattern, classify it as one of:

- **Preserve** - the existing pattern is part of HOney's character and already works well;
- **Refine** - preserve the underlying feel/mental model but improve execution;
- **Replace** - the old pattern creates real UX cost or conflicts with the new information architecture.

The default should be **Refine**, not Preserve-at-all-costs and not Redesign-by-default.

### Cross-platform continuity

iOS and Web should share one design language - type scale, spacing logic, component family, surface hierarchy, icon treatment and brand tone - without pretending the platforms are identical. Native iOS behavior may remain more platform-native where appropriate; Web should be responsive and browser-native where that improves usability. Visual continuity is more important than identical control mechanics.

### Legacy Design Audit deliverable

When the legacy app bundle/source/assets are supplied, create a short **Legacy Design Audit** before implementing the new UI. It must contain:

1. screen inventory;
2. reusable visual tokens/components;
3. distinctive HOney design cues;
4. interaction patterns worth retaining;
5. known UI/UX weaknesses;
6. a `Preserve / Refine / Replace` decision for each major pattern;
7. a small set of reference screenshots used as the visual baseline for the rebuild.

This audit is a design input only. It must not reintroduce legacy architecture constraints.

## 1.5 Presentation, client logic and backend logic are separate contracts

HOney must be structured so that visual/UI work is cheap to change and cannot accidentally become the place where product rules live.

The client is therefore split conceptually into two distinct layers:

### UI Presentation layer

Owns only:

- typography, color, spacing and visual hierarchy;
- reusable visual components;
- animations and transitions;
- platform-specific controls and responsive layout;
- rendering loading/empty/error/stale states supplied by application state;
- collecting user gestures and turning them into typed user intents.

The presentation layer MUST NOT:

- implement portal token-refresh rules;
- decide import/sync policy;
- query raw School Portal schemas;
- decide Experiences eligibility or moderation outcomes;
- contain business-critical state machines that would be lost when a screen is redesigned.

### Client Application layer

Sits between UI and backend APIs. It owns:

- typed client/domain models;
- screen/view state and view-model/state-store logic;
- navigation orchestration;
- local caching needed for responsive UI;
- translating backend/domain results into presentation-ready state;
- invoking backend use cases in response to user intents;
- client-only behaviors such as iOS WebView/session presentation and direct Access networking where explicitly required.

It SHOULD be testable without rendering the actual UI. iOS and Web may implement this layer differently, but both must consume the same documented HOney backend contracts.

### HOney Backend Domain layer

Owns product truth and reusable business rules, including:

- HOney account/session rules;
- school import consent and sync rules;
- normalized timetable/history data;
- Next Lesson derivation where implemented server-side;
- Experiences exposure eligibility;
- moderation policy/action states;
- community persistence/reaction/report rules;
- account/data lifecycle.

Backend APIs MUST be **UI-agnostic**. They should expose domain resources, capabilities and state rather than encode one screen layout. A visual redesign, navigation change, or component replacement should normally require only client/presentation changes.

### Contract rule

The dependency direction is one-way:

```text
UI Presentation
      | user intents / view state
      v
Client Application Logic
      | typed API contracts
      v
HOney Backend Domain Logic
      | connector contracts
      v
School Portal Integration
```

Higher layers may depend on lower-layer contracts. Lower layers MUST NOT depend on a particular screen, component tree or navigation layout.

### Change-isolation acceptance test

For every major feature, HOney should be able to answer yes to both:

1. **Could we redesign this screen without rewriting the backend business rule?**
2. **Could we change the backend implementation while preserving the documented API contract and leave the UI behavior intact?**

If either answer is no without a genuine product-contract change, responsibilities are probably mixed and should be refactored before the feature is considered stable.

---

# 2. System model: two system layers

## 2.1 Layer A - HOney Core

HOney Core owns:

- HOney accounts;
- HOney sessions and refresh tokens;
- import consent state;
- normalized timetable data and lesson history;
- canonical teacher/course/room entities derived from imported school data;
- Experiences entities, content, reactions and anonymous eligibility mechanisms;
- Home page derived state such as Next Lesson;
- Web and iOS application APIs;
- settings, privacy controls and account lifecycle.

HOney Core must not depend on the school portal's database schema beyond the connector boundary.

## 2.2 Layer B - School Portal Integration

The School Portal Integration layer owns only:

- validating a school account when provisioning/reconnecting a HOney account;
- obtaining/refreshing school portal sessions or tokens;
- retrieving supported upstream data;
- translating upstream records into the normalized HOney import format;
- direct Access operations from clients where specified.

The portal is treated as a major third-party dependency, not as the product's permanent identity/session layer.

## 2.3 Architectural boundary

Conceptually:

```text
School Portal
  |  identity validation + upstream data
  v
School Integration Layer
  |  normalized import / connector state
  v
HOney Core Backend
  |  HOney account + imported state + Experiences
  +--------------------+
  |                    |
  v                    v
iOS App              Web App
```

Access is the intentional exception:

```text
iOS Client Application Logic  -------------------->  School Access API
          (direct client request; no HOney relay)
```

Even in this exception, the Access **UI component itself** does not own raw networking logic; direct school-API calls belong in the Access client application/service layer so the Access interface can still be redesigned independently.

---

# 3. Account and authentication model

## 3.1 No separate HOney registration form

HOney should not expose conventional `Sign up` and `Create a HOney password` flows.

The primary entry action is:

> **Continue with school account**

The login UI is HOney-owned. The school portal is used behind that flow as the identity verifier.

## 3.2 First-time account provisioning

1. User enters school credentials in HOney's login UI.
2. HOney validates those credentials against the school portal.
3. HOney obtains a stable school identity key/profile sufficient to distinguish the student.
4. If no HOney account exists for that school identity, HOney creates one automatically.
5. HOney issues its own session credentials.
6. HOney presents the school-data import consent screen.
7. If the user consents, supported portal data is imported and normalized into HOney Core.

There is no separate sign-up decision after successful school authentication.

## 3.3 Returning login

A HOney session and a school-portal connection are separate states.

A returning user may therefore be:

- signed into HOney and connected to the portal;
- signed into HOney while the portal token has expired;
- signed into HOney with previously imported timetable data while portal refresh is temporarily unavailable.

Portal expiry must **not** sign the user out of HOney.

## 3.4 Three authentication/session concerns

HOney must treat the following as separate state even when they reuse the same underlying school credential:

1. **HOney session** - authenticates the user to HOney Core.
2. **Native Portal API session** - authenticates direct/native portal API requests and/or feeds the timetable connector.
3. **Official Portal WebView session** - authenticates the official school website rendered inside HOney.

These states must not be represented by one shared `isLoggedIn` flag. In particular:

- a HOney session may remain valid while either portal session has expired;
- expiry of the WebView session must not invalidate the native Portal API session;
- expiry of the native Portal API session must not invalidate the WebView session or HOney session;
- session artifacts may be synchronized between native API and WebView only when the real portal authentication model proves that they are interchangeable.

The invariant is:

> **Share credentials where appropriate; keep session state independently recoverable.**

## 3.5 Portal credential manager and silent re-authentication

The iOS app has a hard UX requirement:

> **If the official School Portal has not materially changed its authentication requirements, normal portal/session expiry must never require the user to manually enter school credentials again.**

After the initial successful school login, iOS must retain the minimum credential material necessary to reproduce the official login flow in Keychain or an equivalent OS-protected store. This may be a refresh token, durable session credential, or - only if the real portal requires it - the school username/password. The exact credential type is determined by the Portal Auth Analysis, not assumed in advance.

Recovery order:

```text
portal request/session becomes unauthenticated
        |
        +-- renewable token/session available -> refresh/renew
        |
        `-- full login required -> use Keychain credential silently
                                      |
                                      +-- success -> replace portal session and retry
                                      `-- cannot satisfy new auth requirement -> USER_ACTION_REQUIRED
```

Manual user action is acceptable only when the upstream authentication requirement has materially changed or the saved credential can no longer succeed, for example:

- school password changed;
- school account disabled/revoked;
- new mandatory MFA;
- CAPTCHA/human verification;
- mandatory password reset or new terms flow;
- portal login protocol materially changed;
- the user deliberately removed the saved credential.

Normal token expiry, cookie expiry, app restart, device restart, portal logout due solely to expiry, and native API 401/unauthenticated responses are **not** valid reasons to ask the user to type their password again.

HOney Core may store renewable portal session material when needed for server-side timetable synchronization. Whether HOney Core also needs a server-side full-login credential is intentionally left open until the real portal authentication flow is re-analysed. V1 must not duplicate raw password storage on the server merely for convenience if renewable upstream credentials or iOS-assisted renewal are sufficient.

## 3.6 Official Portal WebView session

HOney iOS includes the official School Portal as a secondary utility surface opened from Home. The portal is rendered as the official site inside a `WKWebView`; HOney does not recreate the portal's long-tail features.

### Persistent website state

Use a persistent `WKWebsiteDataStore`, not an ephemeral store, so ordinary portal cookies/local website state survive app restarts. HOney may additionally remember a safe `lastPortalURL` so reopening the portal can return the user to the last useful location.

Do not persist/restore as `lastPortalURL`:

- login pages;
- auth callback/transient URLs;
- temporary error pages;
- logout endpoints.

### Session reuse policy

Native API and WebView portal sessions may share session artifacts **only after Portal Auth Analysis confirms they use compatible credentials**. Session sharing is an optimization, not a product dependency.

Preferred order:

1. **Reuse/inject a valid portal cookie/token** into the WebView when the native login produces the same valid web session artifact.
2. Otherwise let the WebView keep its own persistent session and silently create a new web session using the same Keychain credential when it expires.
3. Use automated interaction with the official login form only as a fallback when the portal's web login cannot be reproduced safely at the HTTP/session layer.

The preferred technical shape, when compatible with the real portal, is:

```text
Keychain school credential
        |
        v
PortalSessionCoordinator
     /              \
    v                v
Native API        WebView session
 session        (WKWebsiteDataStore)
```

WebView cookies are managed through WebKit's own website data/cookie store. HOney should not assume that ordinary native HTTP cookie storage and WebView cookie storage are automatically identical. If explicit synchronization is used, it must be implemented deliberately after the auth flow is understood. [W3][W4]

### Detecting expiry inside the WebView

HOney should treat navigation to the known official login/auth state as a portal-session expiry signal. The app then:

1. captures the intended safe destination;
2. silently rebuilds a valid portal WebView session;
3. returns to the intended destination;
4. keeps the HOney account/session untouched.

The normal user experience should be a loading transition, not a visible manual login form.

## 3.7 Logout and disconnect are distinct

Settings must distinguish:

- **Sign out of HOney** - ends the current HOney session on that device/browser;
- **Disconnect school account** - removes/invalidates the current portal connection but does not delete the HOney account;
- **Delete HOney account** - deletes HOney-owned account data subject to the Experiences anonymity model and applicable retention rules.

---

# 4. Data import and consent

## 4.1 Explicit import consent

School authentication alone does not silently turn all portal data into HOney backend data.

After account provisioning, HOney presents a concise consent step describing what will be imported and why.

V1 consent domain:

### Timetable and lesson history

Purpose:

- timetable rendering;
- Next Lesson;
- Course/Lesson History;
- Experiences eligibility and contextual entry points.

Suggested UI language:

> **Import timetable and lesson history to HOney**  
> HOney will store your timetable in your HOney account so it can show your schedule across devices, keep your lesson history, and verify experiences you choose to share.

The user can revoke future syncing and delete imported timetable/history data from HOney settings.

## 4.2 Access data

V1 Access operations remain client-to-school and are not relayed through HOney Core.

Do **not** import Access history into HOney's backend merely because it is available. Access data may be added as a separate explicit import domain later only when a concrete product use case requires it.

This is a direct application of the simplicity rule: do not store data without a defined user-facing purpose.

## 4.3 No Exams import

V1 contains no Exams module, no Exams backend table, and no Exams import consent.

---

# 5. Timetable data model and sync

## 5.1 Canonical model

Upstream portal records must be normalized into HOney-owned entities rather than stored as opaque portal blobs.

Minimum normalized entities:

```text
HOneyUser
Teacher
Course
Room
LessonInstance
UserLessonExposure
SchoolConnection
ImportConsent
```

### `HOneyUser`

- `user_id`
- stable internal HOney identifier
- `school_identity_key`
- account status
- created/updated timestamps

### `Teacher`

- `teacher_id`
- portal/source identifier if available
- display name
- optional school department/role
- active/inactive status

### `Course`

- `course_id`
- source identifier
- course/subject name
- optional cohort/year metadata

### `Room`

- `room_id`
- display label
- optional building/area relationship

### `LessonInstance`

- `lesson_id`
- `course_id`
- `teacher_id` or teacher set
- `room_id`
- start time
- end time
- source record/version
- cancellation/change state if the portal exposes one

### `UserLessonExposure`

- `user_id`
- `lesson_id`
- enrollment/exposure state
- provenance/source

This relation is used for Timetable/History in HOney Core and for anonymous eligibility issuance in Experiences.

## 5.2 Raw portal payloads

V1 should not retain complete raw portal responses by default.

Store only:

- normalized values needed by the product;
- source identifiers needed for idempotent sync;
- sync/version metadata required to reconcile changes.

Temporary raw payloads may exist in process memory during normalization but should not become the product database.

## 5.3 Sync behavior

Timetable sync should be idempotent.

A successful sync:

1. retrieves the authoritative portal records available to the connector;
2. normalizes teachers/courses/rooms/lessons;
3. upserts records by stable source identifiers;
4. records user exposure;
5. updates `last_synced_at`;
6. does not create duplicate lesson instances on repeated syncs.

When the portal is unavailable or the token is expired:

- HOney continues showing the last imported timetable;
- the UI labels stale state only when it matters;
- HOney account and Experiences browsing remain available;
- re-authentication/sync failure is not treated as whole-app failure.

---

# 6. Information architecture

## 6.0 Shared visual and interaction language

All top-level surfaces should feel like one HOney product rather than independent feature mini-apps. Home, Experiences, Timetable, Access and the Portal WebView shell share the same visual system and navigation grammar.

The design system should be derived from the Legacy Design Audit rather than invented in isolation. At minimum it should define:

- typography roles and scale;
- spacing grid;
- corner/surface treatment;
- icon style;
- card/list/block hierarchy;
- selected/unselected navigation states;
- loading/skeleton behavior;
- empty/error/stale states;
- motion principles;
- responsive Web behavior.

The target is **recognisable continuity with materially better execution**.

## 6.1 iOS top-level navigation

Use a four-item bottom tab bar:

1. **Home**
2. **Experiences**
3. **Timetable**
4. **Access**

Do not add a fifth top-level tab for History, Teachers, Settings, Search, or Profile.

Account/settings are opened from the Home header/profile control.

## 6.2 Web top-level navigation

Use a compact top navigation:

1. **Home**
2. **Experiences**
3. **Timetable**
4. **Access** only when web direct-access capability has been proven and enabled

Settings/account live in the user menu rather than as a primary navigation destination.

## 6.3 Shared deep-link model

Entity and contextual routes should be stable across iOS and Web where the feature exists:

```text
/home
/experiences
/experiences/teacher/:id
/experiences/course/:id
/experiences/place/:id
/experiences/food/:id
/timetable
/history
/history/lesson/:id
/settings
```

The same conceptual route may render as a pushed native screen on iOS and a URL on Web.

---

# 7. Home

Home must remain deliberately small.

## 7.1 Required content

### A. Welcome

A compact greeting/header. No dashboard of statistics.

### B. Next Lesson

Display the next lesson from imported timetable data:

- course/subject;
- start time;
- teacher;
- room;
- simple temporal state such as `in 24 min`, `now`, or `no more lessons today`.

Tapping the card opens the lesson context/detail sheet.

### C. Experiences area

Home should expose Experiences without turning Home into a social feed.

Recommended V1 structure:

- **Share an experience** - one compact CTA, defaulting to recent eligible contexts;
- **Recent from your classes** - a small number of newest raw Experiences tied to teachers/courses the user has actually encountered;
- **Browse Experiences** - link to the Experiences tab.

No recommendation model is required. `Recent from your classes` can be a deterministic query ordered by publication time within the user's verified exposure set.

### D. School Portal

Home includes one secondary **School Portal** row/button that opens the official portal WebView.

This is deliberately not another bottom tab. It is a doorway to official long-tail functionality that HOney has chosen not to rebuild. The WebView should restore its persistent website state and, where safe, the last useful portal URL. Portal-session expiry must be recovered silently as defined in Section 3.6.

## 7.2 Explicit non-goals for Home

Do not add:

- exams/countdowns;
- attendance analytics;
- school news;
- streaks;
- productivity widgets;
- generic activity feed;
- portal diagnostics unless there is an actionable connection error.

---

# 8. Timetable

## 8.1 One Day view only

Timetable V1 contains **one representation: Day view**.

There is no Week view and no alternative grid view.

Required elements:

- current selected date;
- previous/next-day navigation and/or horizontal date swipe;
- vertically ordered lesson blocks;
- start/end time;
- subject/course;
- teacher;
- room.

The visual language may be ported/refined from the legacy HOney timetable where useful, but the information architecture is new and the Week view is intentionally removed.

## 8.2 Lesson interaction

Tapping a lesson opens a lightweight lesson detail/sheet rather than a new top-level page.

Minimum actions:

- **View teacher experiences**
- **View course experiences**
- **Share or record an experience**

The third action opens the Experiences composer with the lesson context already selected.

## 8.3 History entry

Timetable includes one secondary `History` action in the page header.

History is not another timetable representation. It is a record of lessons the user has already had.

---

# 9. Course / Lesson History

## 9.1 Purpose

History solves two concrete tasks:

1. let the user find classes/teachers they previously had;
2. provide a natural verified-context picker when the user wants to record or publish an Experience later rather than immediately after class.

## 9.2 One shared page, two modes

The same History screen is reused in two contexts.

### Browse mode

Entry: `Timetable -> History`

Purpose: browse past lessons.

### Selection mode

Entry: `Experiences -> Share -> From your history`

Purpose: select a lesson/teacher/course as the context for a contribution.

Do not build two separate history UIs.

## 9.3 Required UI

- chronological lesson list;
- grouping by date or month;
- search;
- filter by teacher;
- filter by course/subject;
- tap a lesson for its context/detail sheet.

Optional derived counts such as `42 lessons with Ms X` may be shown only when they make selection easier; they should not become an analytics dashboard.

---

# 10. Experiences entry architecture

The detailed community, moderation, privacy and publication rules are normative in Appendix A. This section defines how Experiences fits into the whole HOney product.

## 10.1 Top-level Experiences page

Required structure:

### Search

Search teachers, courses, places and food items.

### From your classes

A raw chronological feed scoped to entities in the user's verified lesson/course history.

No ranking by likes, sentiment, controversy or engagement.

### Browse

Simple object categories such as:

- Teachers
- Courses
- Places
- Food

### Share

A persistent, visible `Share` action.

## 10.2 Share entry flow

The first question is not `Who do you want to rate?`

It is:

> **What do you want to share or record an experience about?**

Then offer:

1. **Recent lessons** - fastest route;
2. **Your history** - opens History in selection mode;
3. **Teachers / courses you've had** - verified from imported exposure;
4. **Places & things** - classrooms, canteen, facilities, food.

After context selection, the user chooses to:

- save privately; or
- proceed toward anonymous public sharing under the Experiences rules.

## 10.3 Human and lesson ratings

There is **no 1-5 rating** for:

- teachers;
- lessons;
- courses;
- classrooms;
- general facilities.

These use raw experiences, tags/context and verified match/mismatch reactions only.

Scalar rating is permitted only for low-stakes objects with a naturally unitary consumption judgment, with **canteen food items** as the V1 example.

## 10.4 Contextual entry points

Experiences can be entered from:

- Home `Share an experience`;
- Experiences tab;
- Timetable lesson detail;
- History lesson detail;
- Teacher/course/place/food entity page.

All routes resolve to the same composer and policy pipeline.

---

# 11. Access

## 11.1 V1 strategy

Access is intentionally **not redesigned from first principles in this specification**.

When the legacy app bundle/code is supplied:

- use the legacy Access UI and behavior as the primary reference;
- preserve its proven mental model and overall HOney feel;
- refine visual execution, hierarchy, states and accessibility where the rebuild can make them clearly better;
- adapt the module to the new HOney account/navigation shell and code architecture without forcing pixel parity.

The legacy code is a behavior reference, not a requirement to preserve old backend architecture.

## 11.2 Network boundary

On iOS, Access school-API operations must be sent **directly from the app to the school's Access API**.

HOney Core must not relay these operational calls.

Reasons are architectural simplicity and avoiding an unnecessary server intermediary for an interaction that can be completed directly by the client.

## 11.3 Backend storage

V1 does not import Access history into HOney Core merely for completeness.

If a later feature needs Access-derived backend state, it requires:

- a defined user-facing purpose;
- a separate data-model decision;
- explicit import consent.

## 11.4 Web capability gate

A normal browser `fetch()`/XHR call to a different origin is permitted only when the target school API's CORS policy allows the HOney web origin. Credentialed cross-origin requests additionally require explicit credential support, and an `Authorization`-header request that triggers preflight cannot be worked around by frontend code if the target server does not cooperate. [W1][W2]

Therefore:

- **Default:** Access is absent from Web.
- **Enable Web Access only if tested against the real school endpoint and confirmed to support the required CORS/authentication behavior.**
- HOney must not introduce a server relay merely to obtain Web parity for Access.

If the capability test passes, Web may use the same conceptual Access module with browser-to-school direct requests. If it fails, iOS remains the only Access surface.

---

# 12. Web and iOS parity

## 12.1 Shared product state

The following are HOney Core features and should be shared across iOS and Web:

- HOney account/session;
- imported timetable;
- Next Lesson;
- History;
- Experiences browsing;
- Experiences publishing;
- Experiences reactions;
- settings and import consent where applicable.

## 12.2 Platform-specific behavior

### iOS

- four bottom tabs;
- Home includes the official School Portal WebView as a secondary route;
- the school credential needed for unchanged upstream re-authentication is retained in Keychain so normal portal expiry never requires manual login again;
- HOney session, Native Portal API session and WebView Portal session remain separate state;
- native/WebView portal session artifacts may be synchronized only when the analysed auth protocol supports it;
- Access direct-to-school integration;
- native notification/OS integrations may be added only with a separate explicit product requirement.

### Web

- responsive navigation;
- same HOney backend data for timetable/history/Experiences;
- portal reconnection may require re-entering school credentials;
- Access omitted unless the direct browser capability gate passes.

## 12.3 Experiences moderation parity

Web and iOS use the same Experiences publication protocol.

The browser/app does not hold the LLM provider API key. The client sends candidate content to a HOney-controlled moderation issuer. The issuer runs the constrained moderation pipeline once and, if the content passes, returns a short-lived pass bound to the exact content hash and policy version. The Community API verifies that pass; it does **not** run the LLM a second time.

This preserves policy parity without trusting browser JavaScript and without double-running the semantic moderation model.

---

# 13. Core backend data model

## 13.1 Account and school connection

```text
honey_users
- user_id
- school_identity_key
- status
- created_at
- updated_at

school_connections
- user_id
- school_id
- portal_subject_id/source_user_id
- encrypted_portal_token (if retained)
- token_expires_at
- connection_status
- last_authenticated_at
- last_sync_at

import_consents
- user_id
- domain
- status
- granted_at
- revoked_at
```

V1 `domain` values:

- `timetable_history`

No `exams` domain exists.

## 13.2 School-derived entities

```text
teachers
courses
rooms
lesson_instances
user_lesson_exposures
```

These are HOney-owned normalized records with source identifiers for reconciliation.

## 13.3 Course History is a view, not a new source of truth

Course/Lesson History should be derived from imported `lesson_instances` plus `user_lesson_exposures` where the lesson has ended.

Do not maintain a separate manually synchronized history database unless performance later requires a materialized view.

## 13.4 Experiences entities

Experiences uses the same canonical teacher/course/room objects wherever possible. Do not create a duplicate `experience_teachers` directory disconnected from the Timetable model.

Community content stores no ordinary author field, as specified in Appendix A.

---

# 14. Service and API boundaries

A simple logical service split is sufficient. It need not imply separate machines or deployment stacks.

All HOney backend APIs MUST be stable, typed **product/domain contracts**, not ad-hoc endpoints shaped around a particular screen. UI composition, tab placement, card layout and visual component structure are client concerns. Backend responses may expose domain state/capabilities needed by a screen, but MUST NOT require a specific UI implementation to remain valid.

## 14.1 HOney Auth / Account API

Responsibilities:

- school-account validation orchestration;
- HOney account provisioning;
- HOney sessions;
- settings/account lifecycle.

## 14.2 School Connector

Responsibilities:

- portal authentication/session management;
- timetable retrieval;
- normalization input;
- portal connection status.

Does **not** relay iOS Access operations.

## 14.3 HOney Data API

Responsibilities:

- imported timetable/history storage;
- Home Next Lesson query;
- History queries;
- teacher/course/room directory queries.

## 14.4 Experiences Eligibility Issuer

Responsibilities:

- verify that the authenticated HOney user has the required exposure;
- issue one-time scoped unlinkable eligibility credentials;
- avoid placing a persistent author identifier into the public contribution path.

## 14.5 Experiences Moderation Issuer

Responsibilities:

- receive candidate text without requiring author identity;
- run deterministic checks + constrained LLM feature extraction;
- fail closed on semantic uncertainty/coded/evasive/injection content;
- issue a short-lived content-bound moderation pass on success.

## 14.6 Experiences Community API

Responsibilities:

- verify eligibility credential;
- verify moderation pass/content hash/policy version;
- store raw public content without an author field;
- serve entity feeds and reactions.

---

# 15. Privacy and data boundaries

## 15.1 HOney account data

HOney intentionally stores user-linked timetable/history data after explicit import consent because that state powers defined account features.

This is not treated as anonymous data.

## 15.2 Experiences content

Experiences deliberately has a stronger separation:

- public post records do not contain HOney user IDs;
- eligibility and publication use one-time unlinkable credentials from V1;
- moderation passes are bound to content, not author identity;
- application logs must not be designed to reconstruct `student -> post` linkage;
- HOney does not claim impossible network-level anonymity simply because a direct network request may expose connection metadata in transit.

The product should expose a legible privacy/data map explaining this distinction to users.

## 15.3 No privacy theatre

HOney should say precisely what it does, not use vague `completely anonymous` wording.

Acceptable statement:

> HOney uses your school account to verify that you are eligible to contribute. Published Experiences are stored without your school account attached to them, and HOney does not maintain an application record designed to map a published Experience back to its author.

---

# 16. Failure states

## 16.1 School portal unavailable

- HOney account remains usable.
- Last imported timetable/history remains visible.
- Next Lesson is based on last imported data and may show `Last synced` when stale.
- Experiences browsing remains available.
- Contribution eligibility remains available for already imported exposure data.
- New upstream sync waits for reconnection.

## 16.2 Native Portal API session/token expired

- silently refresh/renew when possible;
- otherwise silently reproduce the official login using the Keychain credential;
- replace the native portal session and retry the failed operation where safe;
- do not sign the user out of HOney;
- ask for manual school authentication only when the saved credential cannot satisfy the current upstream auth requirement.

## 16.3 Official Portal WebView session expired

- detect the official login/auth state;
- preserve the intended safe destination;
- silently rebuild the WebView session using compatible shared session artifacts or the Keychain credential;
- reload/return to the intended destination;
- do not affect the HOney session;
- if the portal has introduced MFA/CAPTCHA/password reset/new login requirements, enter `USER_ACTION_REQUIRED` instead of attempting fragile infinite automation.

## 16.4 Experiences moderation unavailable

- fail closed for new public posts;
- allow local/private recording;
- browsing remains available;
- do not publish first and review later.

## 16.5 Access API unavailable

- Access tab shows an isolated Access error state;
- Home/Timetable/Experiences remain unaffected.

---

# 17. Settings

Settings should remain secondary and compact.

Required sections:

### Account

- school identity/profile summary;
- sign out;
- delete HOney account.

### School connection

- connected/reconnect status;
- last successful sync;
- disconnect school portal.

### Imported data

- timetable/history consent status;
- stop future sync;
- delete imported timetable/history data.

### Experiences

- community principles;
- privacy/anonymity explanation;
- private notes management where needed;
- report/help information.

No settings section should exist for Exams.

---

# 18. Explicit V1 non-goals

The following are intentionally outside V1 unless separately re-approved:

- Exams;
- timetable Week view;
- alternative timetable visualization;
- attendance analytics;
- productivity/study planning;
- generic school news feed;
- social profiles/followers/DMs;
- teacher reply system;
- teacher scalar ratings;
- lesson scalar ratings;
- facility scalar ratings;
- AI summaries of teachers;
- teacher rankings;
- Access server relay;
- storing Access history in HOney backend without a concrete use case;
- speculative analysis merely because imported data exists.

---

# 19. Primary user journeys

## 19.1 First launch

```text
Open HOney
-> Continue with school account
-> School credentials validated
-> HOney account auto-created
-> HOney session issued
-> Import timetable/history? [clear consent]
-> Sync
-> Home
```

## 19.2 Daily iOS use

```text
Home
-> Next Lesson
-> optional Experiences content
-> School Portal (official WKWebView)

or

Timetable
-> Day view
-> lesson
-> View Experiences / Share or record

or

Experiences
-> Search / browse / share

or

Access
-> direct school API flow
```

## 19.3 Share something about an old class

```text
Experiences
-> Share
-> Your history
-> find lesson / teacher / course
-> compose
-> Save privately OR publish
-> Experiences policy pipeline
```

## 19.4 Web user

```text
Sign into HOney
-> Home / Experiences / Timetable use HOney backend state
-> reconnect school portal only when refresh requires it
-> Access appears only if browser direct-access capability is enabled
```

---

# 20. Acceptance criteria

The ground-up HOney V1 is product-complete only when all of the following are true:

1. School-account login automatically provisions/reconnects a HOney account.
2. No separate HOney password-registration flow exists.
3. HOney session lifetime is independent from Native Portal API and WebView Portal session lifetimes.
4. iOS securely retains the credential material required to reproduce the unchanged official portal login flow.
5. Normal native portal token/cookie expiry never asks the iOS user to manually enter school credentials again.
6. Home provides a secondary official School Portal WebView entry.
7. The WebView uses persistent website data and can restore a safe last portal location.
8. Normal WebView portal-session expiry is detected and silently recovered without affecting HOney login.
9. Native Portal API and WebView sessions are not assumed to be identical; sharing/synchronization is enabled only when the analysed portal authentication model supports it.
10. Manual portal login is required only when the upstream authentication requirement materially changes or the retained credential becomes invalid.
11. Timetable/history import requires explicit consent.
12. Imported timetable is normalized into HOney-owned backend entities.
13. Home contains only Welcome, Next Lesson, a small Experiences area, and the secondary School Portal entry.
14. Timetable has one Day view and no Week view.
15. History is one reusable secondary page used by both Timetable and Experiences.
16. Tapping a lesson provides a direct route into relevant Experiences and the composer.
17. iOS top-level navigation is Home / Experiences / Timetable / Access.
18. Access behavior is ported from the legacy implementation when supplied.
19. iOS Access calls the school API directly; HOney does not relay Access operations.
20. Web contains Home / Experiences / Timetable.
21. Web Access is enabled only if direct browser-to-school API compatibility is proven; otherwise it is absent.
22. Exams does not exist in V1 navigation, backend model, consent or import.
23. Experiences has no teacher/lesson/course scalar rating.
24. Food item rating is the only approved V1 scalar-rating class.
25. Experiences eligibility derives from imported lesson exposure without public author identity.
26. App and Web use the same Experiences moderation/publication protocol.
27. Community publication fails closed when moderation is unavailable or uncertain.
28. No public Experiences post stores an ordinary HOney author field.
29. The user-facing privacy page explains the actual account/import/community data boundaries.
30. UI Presentation, Client Application Logic and HOney Backend Domain Logic are implemented as distinct responsibility layers.
31. Backend domain rules are testable without rendering iOS/Web UI.
32. Major UI redesigns can preserve existing backend API/domain contracts unless the product contract itself changes.
33. Access direct-school networking is isolated from Access view components in a client service/application layer.
34. No additional V1 feature is added without a concrete product purpose.
35. A Legacy Design Audit has been completed from the supplied legacy app/source/assets before final UI implementation.
36. Major legacy patterns are explicitly classified as Preserve, Refine or Replace.
37. iOS and Web share a coherent HOney design language while allowing platform-appropriate interaction differences.
38. The rebuilt product is recognisably continuous with legacy HOney in overall feel, without requiring pixel-level UI parity.
39. Known legacy UX weaknesses are not retained solely for familiarity.

---

# 21. Legacy app design and Access dependency

The exact Access behavior and the legacy visual system are intentionally not reconstructed from memory in this document.

**Pending implementation input:** the existing HOney app bundle/source code and available visual assets.

When provided, first create the `Legacy Design Audit` defined in §1.4, then create a focused `Access Legacy Parity Map` containing:

- current screens;
- current user actions;
- upstream endpoints and request patterns;
- credential/token behavior;
- states/errors;
- pieces to port unchanged;
- pieces that must be adapted to the new HOney shell.

Until that map exists, this master specification's Access requirement is behavioral inheritance plus direct client-to-school networking.

---

# 22. Current external technical constraint: Web direct Access

[W1] MDN Web Docs, **Cross-Origin Resource Sharing (CORS)**. Browsers restrict script-initiated cross-origin requests unless the target server returns the required CORS headers. Credentialed requests require explicit server participation; Authorization-header preflights cannot be bypassed by frontend code when the target does not allow them. https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS

[W2] MDN Web Docs, **Access-Control-Allow-Credentials** / credentialed requests. Cross-origin credentials require the target response to explicitly permit credentials and the requesting origin. https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Access-Control-Allow-Credentials

[W3] Apple Developer Documentation, **WKWebsiteDataStore**. WebKit website data storage is the authoritative store for WKWebView website data; HOney should use the persistent/default store for the official portal surface. https://developer.apple.com/documentation/webkit/wkwebsitedatastore

[W4] Apple Developer Documentation, **WKHTTPCookieStore**. WKWebView cookies are managed through WebKit's cookie store and can be accessed/synchronized deliberately when HOney's analysed portal auth protocol requires it. https://developer.apple.com/documentation/webkit/wkhttpcookiestore

---

# Appendix A - HOney Experiences normative sub-specification

The following Experiences specification is part of the HOney V1 baseline. Where the master specification and this appendix address the same navigation/account topic, the master specification controls. Community culture, content boundaries, moderation, anonymous publication, reactions and Experiences privacy are controlled by this appendix.

# HOney Experiences
## Final Product, Community, Moderation and Privacy Specification

**Version:** 1.0  
**Date:** 2026-09-01  
**Status:** Product baseline for implementation  
**Scope:** The Experiences community layer of HOney. In this master specification it is a normative sub-specification; HOney account, timetable/history and access architecture are specified in the main document.

---

## 0. Executive summary

HOney Experiences is a student-to-student, anonymous, raw-first information layer for school life. It allows verified students to share what it was like to have a teacher, take a course, sit in a classroom, use a facility, or eat a particular canteen item. Teachers are a major primary entity, not a hidden or secondary subject; however, the product is deliberately not a teacher verdict, complaint system, disciplinary channel or popularity ranking.

The product rests on four principles:

1. **Different audiences are legitimate.** A student may reasonably tell peers something that they do not need or want to say directly to the person being discussed.
2. **Experience has two-sided value.** A contribution can help other students understand the school, and it can also matter to the contributor as an act of voice and self-expression. A user does not need to pretend that helping others is their only reason for sharing.
3. **Respect does not require positivity or perfect articulation.** Strongly negative, mixed and hard-to-explain feelings are legitimate. Specificity is encouraged because it helps readers, but inability to explain a feeling does not erase its value.
4. **Scope makes anonymity defensible.** HOney only publishes the class of speech for which it is prepared to defend anonymous participation. Serious matters that require investigation, safeguarding, discipline or emergency action do not enter the public feed at all.

This produces a simple governance model:

> **More context, fewer verdicts.**  
> **Verified exposure, not verified truth.**  
> **Negative is allowed. Cruelty is not.**  
> **You do not have to turn your experience into advice. You can simply say what it was like.**

The public system is raw-first: compliant original contributions remain directly browsable. HOney does not create an overall teacher rating, AI summary, teacher leaderboard, or algorithmic "truth" score. Like/dislike reactions are allowed only from students with relevant verified exposure and are never used for ranking or moderation.

The normal moderation path contains **no human review**. The system uses deterministic rules plus an LLM as a constrained feature extractor. The LLM never decides policy in free-form language and has no tools. Unknown, coded, evasive or semantically uncertain content fails closed and asks the user to rephrase. Serious content is blocked from public HOney and the student is shown appropriate school channels. High-arousal ordinary opinion may be held privately for 24 hours and can be published after the user actively reconfirms.

HOney's privacy goal is strong but legible rather than mystical. The public community database has no author field. Eligibility and publication use one-time unlinkable credentials modeled on Privacy Pass-style authenticators. A separate moderation issuer can see the text needed for semantic checking but does not need the student's identity; it signs a short-lived pass bound to the exact content hash. The community service verifies that pass and does not run the LLM a second time. HOney does not claim network-level anonymity against a global traffic observer; it does commit not to store an application-level author-content relation or logs designed to reconstruct one.

Experiences is available in both the native app and a web surface. The same publication protocol and rules apply to both. The LLM provider API key remains server-side.

---

# Part I - Product philosophy and community culture

## 1. Product role

### 1.1 What Experiences is

Experiences is a **context-bounded peer testimony system**. It turns ordinary student-to-student exchange about school life into a persistent, searchable shared memory.

Examples of legitimate uses include:

- "She is genuinely one of the nicest teachers here, but I find being cold-called by her stressful."
- "I cannot fully explain why, but I often feel tense in this class."
- "He explains proofs very clearly but moves much faster than the textbook."
- "Room 403 is always too warm in the afternoon."
- "The curry is good but the queue is usually not worth it."

A contribution may be useful because it helps a future student. It may also be worth sharing because the experience mattered to the contributor and the contributor wants to put it into a shared social record in an appropriate way.

### 1.2 What Experiences is not

Experiences is not:

- a formal complaint or whistleblowing system;
- a safeguarding, disciplinary or emergency-response channel;
- a teacher feedback inbox;
- a system in which teachers respond to students;
- an investigation service or arbiter of facts;
- a forum for rating or discussing students;
- an anonymous chat room;
- a debate-thread system;
- a "hot-or-not" system for people;
- a teacher ranking or a single scalar measure of teacher quality;
- a place where anonymity makes otherwise unacceptable conduct acceptable.

### 1.3 Primary product posture

The product should feel like students talking normally and carefully among peers, not like an institutional evaluation form and not like an attack board.

The intended social model is:

> "This is what it was like for me. It may be useful to you. It is not the whole person, and it does not have to be."

---

## 2. Four moral foundations

### 2.1 Foundation A - Different audiences are legitimate

James Rachels argues that privacy helps make different kinds of social relationships possible because people legitimately reveal different information to different people. Helen Nissenbaum's theory of contextual integrity likewise treats privacy as the appropriateness of an information flow within a particular social context, rather than as a requirement that information be absolutely secret. [R1][R2]

For HOney, these are distinct social acts:

- `student -> peer`: sharing context about school life;
- `student -> teacher`: giving interpersonal feedback;
- `student -> school administration`: making an institutional report.

The fact that a teacher is the subject of a statement does not make the teacher the intended audience of every conversation about that statement.

**Product consequence:** Experiences is student-facing. HOney does not provide teacher reply tools, teacher-facing review dashboards, or a normal mechanism that converts peer speech into an author-identification request.

**Community phrase:**

> **The subject of a conversation is not automatically its audience.**

### 2.2 Foundation B - Experience has value for the listener and the speaker

Research on gossip as cultural learning emphasizes that third-party stories transmit social knowledge and let people learn beyond their own direct observation. Research on the social sharing of emotion shows that people commonly share emotionally significant experiences with others and that this process has interpersonal and social functions; it is not merely information transfer. Speaker-centered theories of expression also recognize an expressive interest in stating one's views and experiences, not only in producing a useful outcome for an audience. [R3][R4][R5]

HOney therefore does **not** require a contributor's motive to be purely altruistic.

A user may post because:

- another student might benefit;
- they want their experience to exist in the shared record;
- something was uncomfortable and they want to express that fact appropriately;
- they want to articulate a mixed judgment;
- they simply want to say what school felt like to them.

This is not the same as endorsing "venting" as an anger-management technique. A 2024 meta-analysis found that popular catharsis-style venting does not reliably reduce anger or aggression, and social-sharing research likewise does not support the simple claim that sharing automatically produces emotional recovery. [R4][R6]

**Product consequence:** HOney validates expression, but it separates expression from impulsive publication. Private notes are always available; high-arousal ordinary speech may cool for 24 hours before public release.

**Community phrases:**

> **Your experience does not have to become advice to matter.**

> **You can simply say what it was like for you.**

### 2.3 Foundation C - Respect does not require positivity

Philosophical work on gossip does not support the rule that talking about an absent person is inherently wrong. Westacott instead evaluates considerations such as deliberate falsehood, breach of confidence and expected harm. Fabre likewise treats gossip as morally complex: it can have valuable relational and social functions, while some forms fail to show the concern and respect owed to persons. [R7][R8]

HOney therefore allows:

- praise without evidence essays;
- strong negative opinion;
- mixed evaluations;
- feelings that cannot be fully decomposed into observable facts;
- contradictory experiences from different students.

HOney does not require:

- a positive sentence to "balance" every negative one;
- pros and cons;
- neutrality;
- the wording one would use in a direct face-to-face conversation;
- a fully reasoned argument before a feeling can be shared.

The boundary is not negativity. The boundary is avoidable humiliation, dehumanization, privacy invasion, manipulation, reckless serious allegation, or content whose real-world consequences exceed what this platform is designed to bear.

**Community phrase:**

> **Negative is allowed. Cruelty is not.**

### 2.4 Foundation D - Scope makes anonymity defensible

Kathleen Wallace's account of anonymity highlights its relationship to both privacy and accountability. HOney resolves that tension at the publication boundary rather than by making anonymity conditional after publication. [R9]

HOney's own synthesis is:

> **HOney only publishes speech for which anonymous protection remains morally defensible.**

If a type of content is serious enough that HOney itself would feel unable to defend anonymous public dissemination, that content should not enter public Experiences in the first place.

This means:

- moderation acts on content before public persistence;
- ordinary disagreement does not justify identifying a contributor;
- an inappropriate post is blocked or removed, not deanonymized;
- serious allegations are routed away from public HOney rather than published first and investigated later;
- normal product logic contains no author-disclosure branch.

**Community phrase:**

> **HOney protects the speaker by first being strict about what HOney itself is willing to publish.**

---

## 3. Six moral concerns

The following six concerns synthesize the recurring concerns in Westacott, Fabre, privacy theory and mature review-platform rules. They are the normative source of HOney's executable rules. [R2][R7][R8][R10][R11]

### 3.1 Falsehood and fabrication

The system cannot prove ordinary truth, but it should not facilitate deliberate fabrication, fake exposure, impersonation or coordinated false consensus.

### 3.2 Epistemic recklessness

A feeling, preference or impression may be stated strongly as one's own. A factual or causal claim should not be stated more confidently than the contributor has reason to know. Higher-consequence claims require a stricter publication boundary.

### 3.3 Breach of confidence and privacy

Being relevant to school life does not make another person's private information fair game. Student identity, family matters, medical information, private relationships, contact details and confidential disclosures do not belong in the public community.

### 3.4 Malice, humiliation and objectification

Strong criticism is compatible with respect. Speech whose main purpose is ridicule, sexualization, dehumanization, targeted humiliation or a pile-on is not.

### 3.5 Disproportionate harm

Some claims carry consequences that an anonymous review system cannot responsibly host even when they may be true. If the appropriate next step is investigation, protection, discipline, evidence preservation or emergency action, HOney is not the right public channel.

### 3.6 Context and audience mismatch

A statement can be acceptable in one context and inappropriate in another. HOney is specifically a verified student peer context about school experience. Private information, institutional casework and content about students as rated objects are outside that context.

---

## 4. The Six Checks - user-facing community rules

These six checks are the simple public expression of the concerns above. They should appear contextually in onboarding, composer prompts and error messages rather than as a mandatory six-checkbox ritual.

### Check 1 - **Mine?**

> **Is this your own experience?**

Share what you experienced, observed, thought or felt. Do not publish rumors or someone else's private story.

### Check 2 - **How sure?**

> **Are you describing what you know, or what you infer?**

Feelings can be stated as feelings. Impressions can be stated as impressions. Do not turn an uncertain inference into a high-stakes factual verdict.

### Check 3 - **Some context?**

> **Can you add anything that helps another student understand?**

Specificity usually increases usefulness. It is encouraged, not required for low-harm experience. "I cannot fully explain it, but..." is a legitimate form of testimony.

### Check 4 - **Private?**

> **Does this reveal something that is not yours to publish?**

Do not expose another student's identity, contact information, family, medical information, relationships, confidential disclosure or unnecessary identifying detail.

### Check 5 - **Still human?**

> **Are you sharing an experience, or only turning someone into an object of attack?**

Strong criticism is allowed. Slurs, sexualization, dehumanization, appearance attacks, humiliating nicknames, threats and dogpiling are not.

### Check 6 - **Bigger than HOney?**

> **Would this reasonably require investigation, safeguarding, discipline or urgent action?**

If yes, it does not belong in the public Experiences feed. HOney shows the appropriate school channels but does not relay the report.

---

## 5. Culture is a product surface, not a policy page

A large field experiment in online discussions found that visibly announcing community rules increased compliance and newcomer participation. HOney should therefore make the intended social norm visible in the product, not hide it in Terms. [R12]

### 5.1 Core community language

The following short statements are canonical and may be reused across the interface:

> **More context, fewer verdicts.**

> **People are more than one experience. Experiences still matter.**

> **You do not have to turn your experience into advice. You can simply say what it was like for you.**

> **Specificity helps. Feelings still count.**

> **Negative is allowed. Cruelty is not.**

> **Verified exposure, not verified truth.**

> **If it needs investigation, HOney is not the right public channel.**

### 5.2 Landing-page statement

Recommended copy:

> **People are more than one experience. Experiences still matter.**  
> HOney is a place for students to share what school felt like to them - good, bad, mixed, or hard to explain. Add context when you can. You do not need to turn every experience into advice.  
>  
> HOney verifies relevant school exposure where possible; it does not certify every interpretation as fact. No single contribution is a verdict.

### 5.3 Composer posture

Default prompt:

> **What do you want to share about this experience?**

Secondary helper:

> Anything another student might find useful to know? Specific context helps, but it is okay if what you have is only a feeling.

This deliberately avoids making "help another student" the sole reason to publish.

### 5.4 What the product should not say

Avoid:

- "Be nice."
- "Only say what you would say to their face."
- "Make sure your review is fair."
- "Always give pros and cons."
- "Think about how the teacher will feel before posting."
- "Use HOney to vent."

The first group creates unnecessary self-censorship; the last falsely frames the product as a catharsis mechanism.

---

# Part II - Information architecture and contribution model

## 6. Entities

### 6.1 V1 entity types

- **Teacher**
- **Lesson**
- **Course / subject**
- **Classroom**
- **Building / school area**
- **Canteen**
- **Food item**
- **Study space**
- **Facility**
- **School service**
- **Activity / event**

Teachers are a prominent primary entity. HOney does not disguise the fact that students want to browse experiences about particular teachers.

### 6.2 Relationships

Examples:

`Teacher -> Course -> Lesson`

`Building -> Classroom`

`Canteen -> Food item`

A contribution has one primary entity and may carry contextual entities and metadata.

Example:

- Primary: Teacher A
- Context: Further Mathematics, Year 12, Autumn 2026
- Provenance: verified prior exposure

A different contribution from the same lesson may use Room 403 as the primary entity.

### 6.3 Human-entity boundary

- Teachers may be named primary entities.
- Students must never be searchable, ratable or creatable entities.
- User-created person entities are not allowed.
- For non-teaching staff, V1 should generally attach service experiences to the office/service rather than creating person profiles unless an explicit product decision expands scope.
- Reviews must not identify or evaluate other students.

---

## 7. Contribution types

### 7.1 Lesson-linked experience

After a completed timetable lesson, HOney may offer an experience entry point. The contribution is text-first. There is **no 1-5 lesson rating**.

A student may:

- write and publish a raw experience;
- save a private note only;
- do nothing.

The lesson serves as verified context, not as a numerical score event.

### 7.2 Retrospective experience

HOney may invite students with substantial verified prior exposure to write a broader retrospective experience about a teacher or course.

The invitation is useful for both cold start and longitudinal context.

Public provenance may say:

`Verified retrospective experience`

This means only that HOney verified meaningful prior exposure. It does not mean the contributor is an expert, trusted reviewer or official representative.

### 7.3 General school experience

For places and objects where the portal cannot prove precise usage, HOney may allow contributions from authenticated students with honest provenance such as:

`Verified school member`

HOney must not label this `Verified use` unless actual exposure was verified.

### 7.4 Private note

Every contribution may remain private.

Private note is a first-class product function, not a quarantine for bad speech.

Requirements:

- always available from compose;
- editable and deletable;
- not public;
- preferably local-only by default;
- re-enters the current publication checks whenever the user later chooses to publish;
- out-of-scope serious content may remain private if the user wishes.

---

## 8. Rating policy

HOney should be unusually cautious with scalar ratings.

### 8.1 Forbidden scalar ratings

V1 must not provide a 1-5, star, percentage or equivalent scalar rating for:

- teachers;
- individual lessons;
- courses taught by a person;
- teacher personality or teaching quality;
- any student;
- any other human being.

HOney also must not infer a hidden teacher score from reactions or sentiment.

### 8.2 Allowed scalar ratings

Scalar ratings are enabled only by an explicit entity-type allowlist when two conditions hold:

1. interpersonal/reputational stakes are low; and
2. an overall consumption judgment is intuitively meaningful.

**V1 allowlist:** `FOOD_ITEM` only.

A canteen dish may therefore have an optional 1-5 overall item rating alongside raw comments.

Facilities remain text/tags only in V1. A future version may add a clearly labeled facility dimension only after separate product review; scalar rating must never silently spread from objects back to human entities.

---

## 9. Raw-first browsing

### 9.1 Raw-first definition

> **Every compliant contribution remains directly browsable in the user-approved wording in which it was published.**

Raw-first does not mean unfiltered. It means HOney does not replace compliant user speech with an algorithmic interpretation.

HOney must not:

- replace raw text with an AI summary;
- generate an overall teacher verdict;
- generate teacher star averages;
- rank best/worst teachers;
- rank reviews by sentiment;
- hide a minority experience because it is unpopular;
- silently rewrite or "polish" a user's wording.

### 9.2 Required filters

At minimum:

- primary entity type;
- teacher;
- subject/course;
- year group;
- academic year/term;
- lesson-linked vs retrospective;
- location/context;
- provenance;
- coarse publication period;
- full-text search.

### 9.3 Sorting

Allowed:

- newest;
- oldest;
- chronological by lesson/term;
- selected contextual slice.

Not allowed in V1:

- most liked;
- most disliked;
- controversial;
- trending;
- sentiment;
- teacher rank.

### 9.4 Contradiction is a feature, not an error

If one student says "extremely patient" and another says "I found her impatient," both may remain. HOney does not need to resolve the contradiction.

---

## 10. Reactions

HOney may display simple `Like` / `Dislike` reactions, visually as thumbs-up and thumbs-down, with a clear explanation that they are **experiential resonance**, not fact checking.

Requirements:

1. Only a student with relevant verified exposure may react.
2. One active reaction per eligible user per contribution.
3. A reaction can be changed or removed.
4. Reactions never change sorting.
5. Reactions never change visibility.
6. Reactions never trigger removal.
7. Reactions never create an entity-level score.
8. A dislike is not a report.
9. Reactor identities are never shown.
10. The composer never shows reaction counts, reducing conformity pressure before a user forms their own account.

Recommended tooltip:

> **Reactions come from students with relevant experience. They show whether a post resonates with their experience, not whether it is objectively true.**

For small cohorts, exact reaction counts may be hidden until a minimum count is reached.

---

# Part III - Publication policy and automated moderation

## 11. Principle: no human moderation in the normal flow

HOney's normal community pipeline has no manual review queue.

There is no state called:

- `PENDING_HUMAN_REVIEW`
- `WAITING_FOR_MODERATOR`
- `ESCALATE_TO_ADMIN`
- `IDENTIFY_AUTHOR`

Operational shutdown is separate from content flow.

This is a deliberate departure from platforms such as RateMyProfessors, which use human moderators, and from the Santa Clara Principles' recommendation of human appeal. HOney adopts those sources' useful rule clarity and transparency lessons, but does not copy their human moderation model because it conflicts with the intended privacy, scale and operational design. [R10][R13]

---

## 12. Publication state machine

```text
LOCAL_DRAFT
    |-- SAVE_PRIVATE -> PRIVATE_NOTE
    |
    `-- TRY_TO_PUBLISH
            -> CLIENT_PREFLIGHT
            -> STATELESS_SEMANTIC_MODERATION
            -> DETERMINISTIC_POLICY_ENGINE
                    |-- PUBLISH_NOW
                    |-- OPTIONAL_NUDGE
                    |-- COOLDOWN_24H
                    |-- EDIT_REQUIRED
                    |-- PROHIBITED
                    |-- OUT_OF_SCOPE
                    `-- UNCERTAIN_REPHRASE
```

No public persistence occurs before a publishable state is reached.

---

## 13. Action states

### 13.1 PUBLISH_NOW

Ordinary compliant speech.

Examples:

- "Super nice teacher."
- "I find his lessons boring."
- "I cannot fully explain it, but I often feel tense in this class."
- "She explains integration extremely clearly but moves very fast."
- "Room 403 is always too hot."

### 13.2 OPTIONAL_NUDGE

Low-harm content where additional context would improve usefulness but is not required.

Prompt:

> **Anything that led you to feel this way?**  
> A concrete example can help others understand. You can still publish this as it is.

Buttons:

`Add context` - `Publish as is` - `Save privately`

Examples:

- "He is annoying."
- "Best teacher."
- "The classroom is bad."

### 13.3 COOLDOWN_24H

High-arousal or sweeping hostile opinion that remains within ordinary opinion rather than serious allegation.

The cooling period is not a finding that the opinion is wrong or inappropriate. It separates immediate emotional arousal from a deliberate public decision. Research supports pre-posting friction as behaviorally meaningful, while catharsis research cautions against treating immediate venting as inherently beneficial. The exact 24-hour duration is HOney's product choice, not a scientific constant. [R6][R14]

During cooldown:

- the text remains private;
- user may edit/delete;
- nothing is automatically published;
- after 24 hours the user must actively reconfirm;
- the current policy is run again;
- if it remains ordinary opinion, the user can publish.

Recommended copy:

> **This can still be your experience. Publishing it can wait.**  
> We saved it privately. If you still want to share it after the cooling period, you can decide again.

Examples:

- "I HATE THIS PERSON SO MUCH, worst human here!!!"
- "I am so angry I never want to see this teacher again."

A simple strong opinion such as "probably the worst teacher I have had" should normally receive a nudge rather than mandatory cooldown unless combined with high-arousal signals.

### 13.4 EDIT_REQUIRED

The underlying experience may be publishable, but the current text includes a correctable rule violation.

Examples:

- hearsay: "Everyone says he..."
- directed profanity/name-calling;
- unnecessary student-identifying detail;
- phone/email/address;
- irrelevant URL or promotion;
- quoting another review to start a fight;
- unnecessary private detail.

The UI points to the relevant span and rule. It does **not** automatically rewrite the text.

### 13.5 PROHIBITED

The content is incompatible with the community in its current purpose or form.

Examples:

- credible threats or encouragement of harm;
- slurs/hate speech;
- dehumanization;
- targeted sexualization;
- doxxing;
- humiliating attacks on appearance/body/private life;
- impersonation;
- coordinated harassment/dogpiling;
- spam/manipulation;
- repeated attempts to bypass the publication boundary.

The content is not publicly stored.

### 13.6 OUT_OF_SCOPE

Content whose reasonable next step is investigation, safeguarding, protection, disciplinary action, evidence preservation or urgent safety action.

Examples include:

- alleged sexual misconduct;
- physical abuse or serious violence;
- credible serious threats;
- stalking;
- bribery or deliberate grade tampering;
- serious protected-trait discrimination allegations;
- child-safety matters;
- severe food/building safety incidents requiring action;
- other serious conduct HOney cannot responsibly turn into anonymous public review content.

This category is not "probably false." It applies even when the allegation may be true.

The UI says:

> **This sounds more serious than something HOney Experiences is designed to publish.**  
> HOney will not publish or send this text to the school. You can keep it privately, delete it, or use one of the school channels below.

The product provides static information for the student's mentor, safeguarding lead or appropriate office. HOney does not relay the allegation.

### 13.7 UNCERTAIN_REPHRASE

HOney cannot confidently determine what a phrase means or whether it sits within the publication boundary.

Examples:

- possible coded slur;
- unusual school-specific euphemism with hostile context;
- heavy obfuscation/homoglyphs;
- unsupported language or mixed language that the model cannot confidently interpret;
- ambiguous encoded content;
- suspected filter-evasion phrase;
- prompt-injection style text that makes classification unreliable;
- low semantic coherence.

Uncertainty is itself a publish-blocking signal.

Copy:

> **HOney could not confidently understand part of this wording.**  
> Say it more directly before publishing. Your draft remains private.

The system should not disclose detailed detector logic that would make bypass easier.

---

## 14. Concrete boundary examples

The following examples are part of the canonical regression test suite:

- **"She is an incredibly nice teacher."** - `Publish / nudge`. General but low harm.
- **"His lessons are really boring."** - `Publish`. Ordinary learning experience.
- **"I can't explain it, but I feel nervous in his lessons."** - `Publish`. First-person feeling has value.
- **"She gets impatient when people need something explained twice."** - `Publish`. Ordinary behavioral impression.
- **"He made a joke about my accent and I felt embarrassed."** - `Publish`. Firsthand event plus own reaction.
- **"Probably the worst teacher I've had."** - `Publish / nudge`. Strong opinion, not serious allegation.
- **"Worst human alive I HATE HIM!!!"** - `24h cooldown`. High-arousal sweeping opinion.
- **"He is a fucking idiot."** - `Edit required`. Directed profanity/insult.
- **"Everyone knows he targets weak students."** - `Edit required`. Hearsay; user must state own experience.
- **"He sometimes speaks more sharply to me than to others and I am not sure why."** - `Publish`. Bounded experience/inference.
- **"He deliberately lowers marks for students of X ethnicity."** - `Out of scope`. Serious discrimination/grade allegation.
- **"He is racist."** - `Out of scope`. High-consequence character/conduct allegation.
- **"He touched me inappropriately."** - `Out of scope`. Safeguarding matter.
- **"He sometimes stands very close to me and that makes me uncomfortable."** - `Publish`. Experience/feeling without misconduct verdict.
- **"Her daughter lives at..."** - `Prohibited`. Private/family information.
- **"Room 402 smells bad and is always hot."** - `Publish`. Ordinary facility experience.
- **"The fire exit is blocked and this building is unsafe."** - `Out of scope`. Requires immediate safety action.
- **"The noodles taste awful."** - `Publish`. Ordinary food experience.
- **"I became seriously ill after eating this and think the kitchen poisoned me."** - `Out of scope`. Serious food-safety allegation.

---

## 15. Coded slurs, evasive language and semantic uncertainty

Regex is necessary but insufficient. OWASP's current prompt-injection guidance documents encoding, Unicode smuggling, misspellings, typoglycemia and other obfuscation strategies, and recommends defense in depth rather than a single pattern filter. [R15]

HOney's rule is not "the model can identify every code word." No model can reliably know every new local euphemism. The rule is:

> **The model may abstain, and HOney treats unresolved semantic uncertainty as a reason not to publish.**

### 15.1 Normalization layer

Before semantic classification:

- Unicode normalization;
- zero-width/invisible-character detection;
- excessive whitespace normalization;
- obvious homoglyph detection;
- repeated-character normalization for classification only;
- encoded-text detection where practical;
- markup stripping for moderation representation;
- preservation of original text for the user's draft.

### 15.2 Deterministic lexical layer

Maintain explicit lists/patterns for:

- known slurs;
- threats;
- direct contact information;
- high-confidence PII forms;
- obvious spam/URLs where prohibited;
- known local abuse vocabulary once discovered.

### 15.3 Semantic layer

The semantic classifier may emit features such as:

- `possible_coded_abuse`
- `possible_evasion`
- `semantic_opacity`
- `hostile_targeting`
- `serious_allegation`
- `firsthand_basis`
- `privacy_risk`
- `institutional_consequence`
- `injection_attempt`
- `uncertainty`

Any sufficiently high unresolved uncertainty routes to `UNCERTAIN_REPHRASE`, not to public posting and not to human review.

---

## 16. Prompt-injection-resistant moderation design

HOney's moderation LLM is intentionally not an agent.

It has:

- no tools;
- no database access;
- no school credentials;
- no ability to publish;
- no signing key;
- no ability to modify policy;
- no free-form moderation action.

It reads untrusted review text and returns only a fixed schema.

### 16.1 Untrusted data separation

The moderation prompt explicitly places the review inside a data field and states that all instructions inside that field are content to classify, not commands. OWASP recommends structured separation between system instructions and untrusted user data. [R15]

### 16.2 LLM output schema

Illustrative schema:

```json
{
  "firsthand_basis": "yes | no | unclear",
  "claim_modes": [
    "feeling",
    "opinion",
    "firsthand_event",
    "behavior_pattern",
    "hearsay",
    "serious_allegation"
  ],
  "entity_relevance": "relevant | irrelevant | unclear",
  "specificity": "none | some | high",
  "hostile_arousal": "low | medium | high",
  "institutional_consequence": "ordinary | investigation | safeguarding | discipline | urgent_safety",
  "possible_coded_abuse": false,
  "possible_evasion": false,
  "injection_attempt": false,
  "semantic_uncertainty": "low | medium | high",
  "contains": {
    "profanity": false,
    "targeted_insult": false,
    "threat": false,
    "hate_or_slur": false,
    "dehumanisation": false,
    "sexualisation": false,
    "personal_information": false,
    "student_identification": false,
    "private_information": false,
    "spam_or_coordination": false
  },
  "evidence_spans": []
}
```

The model does not output `ALLOW=true`.

### 16.3 Deterministic policy engine

Example logic:

```text
if institutional_consequence != ordinary:
    OUT_OF_SCOPE
else if threat or hate_or_slur or dehumanisation or sexualisation:
    PROHIBITED
else if personal_information or student_identification or hearsay:
    EDIT_REQUIRED
else if injection_attempt or possible_evasion or possible_coded_abuse:
    UNCERTAIN_REPHRASE
else if semantic_uncertainty != low:
    UNCERTAIN_REPHRASE
else if high_arousal_rule_triggered:
    COOLDOWN_24H
else if specificity == none:
    OPTIONAL_NUDGE
else:
    PUBLISH_NOW
```

The signing service accepts only the deterministic engine's result.

### 16.4 No trust in model self-confidence alone

HOney must not rely on a single scalar such as `confidence=0.97`. Uncertainty is constructed from multiple observable signals: unsupported language, semantic opacity, injection/evasion features, inconsistent structured fields, unknown encoded content and model abstention.

### 16.5 Model failure behavior

If the classifier is unavailable, returns invalid schema, uses an unsupported language, or is otherwise unreliable:

`Save privately / try later`

not

`Publish and inspect later`.

---

# Part IV - Privacy, eligibility and publication protocol

## 17. Privacy goal

HOney should provide strong application/protocol unlinkability without making an impossible claim of absolute network anonymity.

### 17.1 What HOney commits to

- Published Experiences are not stored with the student's school account ID.
- The community database has no `author_id` field.
- Normal admin tooling cannot query "who wrote this?"
- Community logs are not designed to record `IP/session -> post_id/body` linkages.
- Rejected/out-of-scope text is not persisted in the community database.
- Eligibility and publication are separated by privacy-preserving one-time credentials.
- The public post cannot be linked to the issuance flow from protocol data alone when the chosen credential scheme provides unlinkability.

### 17.2 What HOney does not claim

HOney does not claim that:

- nobody on the internet can ever observe connection metadata;
- a global traffic observer cannot perform timing correlation;
- the wording itself cannot reveal the author socially;
- network-level anonymity equivalent to Tor is provided.

### 17.3 User-facing privacy language

Recommended:

> **HOney uses your school account to check whether you are eligible to contribute. Published Experiences are stored without your school identity attached. HOney does not maintain an author field for public Experiences or application logs designed to identify who wrote a particular post.**

Additional note:

> **People who know the situation may still guess who you are from what you choose to write.**

---

## 18. Eligibility credentials

Experiences depends on HOney's authenticated portal layer and timetable history.

For eligible human/course contexts, the identity service verifies exposure and issues a one-time anonymous credential. Privacy Pass is an IETF-standard family of unlinkable authenticators designed so that a client can prove it obtained an authorization token without letting the relying party link redemption to issuance. HOney may implement Privacy Pass directly or use the same architectural primitive. [R16][R17]

Credential scope examples:

- `lesson:<lesson_id>:post`
- `teacher:<teacher_id>:retrospective:<term>:post`
- `teacher:<teacher_id>:react`
- `course:<course_id>:post`
- `school:general:facility_post`

Credentials are:

- single-use where contribution count should be limited;
- scoped;
- short-lived where appropriate;
- not a persistent public pseudonym.

The issuer verifies identity/exposure; the community service verifies the anonymous credential.

---

## 19. Semantic moderation issuer

Because the semantic classifier uses a cloud LLM API, the provider API key remains server-side. The browser/app never receives it.

The moderation service is a **stateless policy issuer**:

1. Client sends the proposed text and public context to moderation.
2. The moderation service runs normalization, deterministic checks, LLM feature extraction and deterministic policy mapping.
3. If the result is publishable, it signs a short-lived moderation pass bound to the exact canonical content and context.
4. If not publishable, it returns the action state; prohibited/out-of-scope text is not persisted.

The moderation service does not need the user's school identity.

### 19.1 Content-bound pass

The pass must bind at least:

- hash of canonical exact text;
- primary entity;
- allowed public context hash;
- moderation policy version;
- issuance time;
- expiry;
- nonce.

Conceptually:

```text
Sign_mod(
  SHA256(canonical_text),
  entity_id,
  context_hash,
  policy_version,
  issued_at,
  expires_at,
  nonce
)
```

A safe text cannot be swapped for a different text after moderation.

---

## 20. Community acceptance

The community service does **not** run the LLM again.

It verifies:

1. eligibility credential is valid for the requested scope;
2. moderation pass signature is valid;
3. content hash matches the exact received body;
4. context matches the signed context;
5. policy version is currently accepted;
6. expiry is valid;
7. nonce/credential has not been replayed.

Only then is the post stored.

Stored community record contains:

```text
Experience
- experience_id
- primary_entity_id
- primary_entity_type
- contextual_entities[]
- provenance_type
- public_context
- public_time_bucket
- raw_body
- topic_tags[]
- state
- edited_flag
- reaction_counts
```

It does not contain:

```text
- author_user_id
- school_account_id
- student_name
- student_email
- roster identity
- device identifier
- author IP
```

Precise infrastructure metadata may transiently exist at the network layer, but HOney should not intentionally persist it in a form linked to a public post.

---

## 21. Abuse restriction without author-linked public posts

App-store UGC policies expect platforms to be able to restrict abusive users. HOney can do this without creating an author field for published posts. Apple and Google Play both require robust UGC safeguards, reporting and user restriction capabilities. [R18][R19]

Recommended design:

- The identity service may track **counts/categories of failed prohibited publication attempts** per authenticated account without receiving the prohibited text.
- The moderation service can report an opaque issuance ticket plus high-confidence violation category to the identity service; the identity service knows the account behind the ticket but not the text.
- Repeated high-confidence prohibited attempts may suspend future community credential issuance.
- This does not create a link between a successfully published Experience and an account.

If an already published post is later removed under a revised rule, HOney may be unable to identify and suspend its author by design. The remedy is content removal, filter correction and, if necessary, community shutdown. This trade-off is explicit.

---

# Part V - Reports, shutdown and community operations

## 22. Reports

Reports are rule-based, not disagreement-based.

Report reasons:

1. Personal or identifying information
2. Threat, hate or targeted harassment
3. Sexualization or inappropriate personal content
4. Hearsay/fake/manipulated experience
5. Serious content that belongs outside HOney
6. Spam/coordinated content
7. Other specific guideline violation

A separate option:

> **I just disagree with this**

must not create a moderation report. It redirects to the reaction or to writing an independent experience.

### 22.1 Automated re-evaluation

Because the normal flow has no human moderation:

1. A report invokes automated re-evaluation under the latest policy.
2. High-confidence violation -> quarantine/remove.
3. Policy pass -> content remains.
4. Report count alone never removes content.
5. School/teacher reports use exactly the same rule engine; they receive no special truth status.
6. No report creates an author lookup.

### 22.2 User notice

If the contributor later sees their own post removed through their private local reference, HOney should explain:

- the rule category;
- whether a policy update was involved;
- whether the user can edit and re-submit.

There is no manual appeal queue. For ordinary editable cases, the practical appeal is revision and re-submission. HOney should publish this limitation honestly.

The Santa Clara Principles are useful as a transparency benchmark for clear rules, notice, automated-system disclosure and measurement, even though HOney intentionally does not adopt their human-review recommendation. [R13]

---

## 23. Shutdown is outside the moderation flow

HOney should prefer temporary loss of community functionality to operating a community whose consequences it cannot safely contain. This is consistent with Safety by Design's emphasis on provider responsibility, user autonomy and transparency. [R20]

Required operational controls:

- `DISABLE_NEW_PUBLICATIONS`
- `DISABLE_REACTIONS`
- `HIDE_PUBLIC_EXPERIENCES`
- `FREEZE_ENTITY:<id>`
- `PRIVATE_NOTES_ONLY_MODE`

Possible triggers:

- moderation service outage;
- policy-version mismatch;
- confirmed critical false negative;
- prompt-injection/filter bypass in the wild;
- coordinated dogpiling;
- unexpected school-wide conflict;
- privacy boundary/logging incident;
- inability to satisfy platform UGC requirements.

Shutdown never requires identifying authors.

---

## 24. Seed cohort and norm formation

Early participants strongly influence what later users perceive as normal. Matias's field experiment supports making community norms visible; HOney should also make them visible through actual early content. [R12]

### 24.1 Seed cohort

Invite a small group of students who:

- have substantial school experience;
- are known to normally speak in good faith;
- can provide positive, negative and mixed opinions;
- represent different years, subjects and social circles;
- are comfortable saying "I do not know" or "I cannot fully explain it" when appropriate.

Selection based partly on founder trust is acceptable for seeding culture. It should not be presented as epistemic authority.

Seed contributors receive no:

- trusted badge;
- official reviewer label;
- ranking weight;
- special reaction weight;
- public status.

### 24.2 Seed corpus requirements

Before broad release, public content should visibly include:

- straightforward praise;
- straightforward criticism;
- mixed evaluation;
- specific uncomfortable experience;
- hard-to-explain feeling;
- legitimate disagreement between contributors;
- lesson-linked experience;
- retrospective experience;
- classroom/facility/canteen content;
- short comments as well as nuanced long comments.

Do not seed only highly polished, philosophically nuanced reviews. That would create the false norm that a user must write an essay before a feeling is legitimate.

### 24.3 Invitation posture

Recommended:

> **You have had substantial experience with this part of school. We are inviting you to help establish what honest, normal student-to-student sharing looks like on HOney. Positive, negative, mixed or difficult-to-explain experiences are all useful. We are not asking for a particular kind of review.**

---

# Part VI - App and web surfaces

## 25. Delivery surfaces

Experiences is available in both:

- HOney native app;
- HOney web application.

The web surface lowers friction for students who want to browse or contribute without installing the app. Timetable is available from HOney's imported backend data on both surfaces. Access remains native-first and is enabled on the web only if the school API permits direct browser-side calls without a HOney relay.

### 25.1 Parity requirements for Experiences

Both app and web must support:

- authenticated student access;
- browsing/filtering/search;
- raw contributions;
- private draft before publish (web may use device/browser local encrypted storage where practical);
- automated moderation workflow;
- one-time eligibility credentials;
- reactions;
- reports;
- community/privacy explanations.

The same moderation issuer and community acceptance protocol apply to both. Browser code is not trusted to assert that moderation passed; only a signed moderation pass is accepted.

### 25.2 Teacher access posture

HOney does not provide a teacher/staff community interface. It cannot promise that teachers never see screenshots or borrowed student access. The product promise is about intended access and author privacy, not impossible social secrecy.

---

# Part VII - Quality, testing and launch gates

## 26. Moderation test philosophy

NIST's AI Risk Management Framework emphasizes pre-deployment and ongoing testing, quantitative/qualitative measurement, uncertainty, benchmarks and documented performance. [R21]

HOney must maintain a versioned, human-authored regression corpus even though runtime moderation has no human queue.

### 26.1 Required test dimensions

- ordinary praise;
- ordinary harsh criticism;
- mixed experience;
- hard-to-explain discomfort;
- factual claim vs inference;
- serious allegation vs bounded discomfort;
- hearsay;
- PII/student identification;
- slurs/profanity;
- coded/euphemistic abuse;
- Chinese;
- English;
- Chinese-English code switching;
- school slang;
- misspellings/obfuscation;
- Unicode/homoglyphs/zero-width characters;
- prompt injection;
- quoted prompt-injection phrases;
- sarcasm;
- embedded URLs/markup;
- high-arousal ordinary opinion;
- facility/food safety boundary;
- contradictory legitimate experiences.

### 26.2 Critical launch gates

The fixed critical suite must have:

- zero known serious/out-of-scope examples incorrectly published;
- zero known direct threats/slurs/doxxing examples incorrectly published;
- zero known prompt-injection examples able to change the policy engine or obtain a valid pass;
- 100% schema-valid model outputs under supported conditions;
- fail-closed behavior on classifier outage/invalid output;
- no systematic blocking of ordinary negative experience;
- verified content-hash binding and replay protection;
- verified absence of author fields in community storage;
- verified absence of application logs that deliberately combine post body/post ID with account identity;
- working kill switches.

These are test-suite gates, not claims of zero error in the real world.

### 26.3 Continuous evaluation

Every policy/model update must:

- increment policy version;
- re-run the regression suite;
- record changed outcomes;
- preserve rollback capability;
- include new discovered bypass examples;
- separately inspect language/code-switching performance.

---

## 27. Product acceptance criteria

Experiences v1 is not ready for broad release until all of the following are true:

1. Teacher/course/lesson/classroom/canteen/facility entity models work.
2. Teachers remain prominent browsable entities without scalar human ratings.
3. Food-item rating is the only scalar rating enabled in V1.
4. Lesson-linked and retrospective contributions have clear provenance.
5. Private note is first-class.
6. User-facing culture statements are present in onboarding/composer/report flows.
7. Low-harm vague content receives at most an optional nudge.
8. High-arousal ordinary opinion can enter 24-hour cooling-off.
9. Serious/out-of-scope content cannot enter the public feed.
10. Uncertain/coded/evasive content fails closed and asks for direct rephrasing.
11. All compliant raw text remains directly browsable.
12. No AI summary or teacher aggregate score exists.
13. Reactions require relevant exposure and do not affect ranking/visibility.
14. Reports do not function as disagreement votes.
15. Runtime moderation contains no human-review queue.
16. LLM has no tools, publishing authority or signing key.
17. Deterministic policy engine, not the LLM, chooses action state.
18. Cloud model API key is server-side only.
19. Moderation runs once; community service verifies a signed content-bound pass rather than rerunning the LLM.
20. Eligibility uses scoped one-time unlinkable credentials.
21. Community database contains no author field.
22. Admin tooling contains no normal author-lookup function.
23. Privacy/data-flow explanation is visible to users.
24. App and web use the same publication rules.
25. Automated reporting/re-evaluation and kill switches work.
26. Regression/adversarial test suite passes launch gates.
27. App-store UGC requirements have been reviewed against the final implementation.

---

# Part VIII - Source integration and departures

## 28. How external sources are used

HOney does not copy any one platform or ethical framework wholesale. The sources serve different roles:

- **Rachels / Nissenbaum** - adopts audience differentiation and context-appropriate information flow; does not define privacy as absolute secrecy.
- **Baumeister / Rimé / speaker-expression theory** - adopts the social-learning and first-person value of sharing experience; does not claim that sharing is automatically therapeutic.
- **Westacott / Fabre** - adopts the view that third-person talk is conditionally assessable and that falsehood, confidence, harm and respect matter; does not treat all third-person talk as wrong.
- **Wallace** - adopts the privacy/accountability dimensions of anonymity; does not use conditional deanonymization as ordinary moderation.
- **CHI employee voice** - adopts civility, validity, safety, egalitarianism, anonymity, slowness and controlled access as design goals; does not adopt its runtime human-moderation model.
- **RateMyProfessors** - adopts firsthand focus, no hearsay, the principle that negative review is not itself a violation, and routing serious matters elsewhere; does not adopt mandatory human moderation, teacher reply, scalar professor ratings or pro/con balancing.
- **Apple / Google Play UGC** - adopts filtering, reporting, abuse restriction and clear rules; does not design people as popularity objects.
- **Santa Clara Principles** - adopts rule clarity, transparency, notice and measurement of automated moderation; does not make human appeal a normal HOney runtime requirement.
- **eSafety Safety by Design** - adopts provider responsibility, user autonomy, transparency and emergency controls; does not take on a broad institutional case-handling role.
- **NIST AI RMF / OWASP** - adopts testing, uncertainty, structured untrusted-data handling and prompt-injection defense; does not treat LLM output as self-authorizing policy.
- **IETF Privacy Pass** - adopts the unlinkable authorization primitive; does not claim global network anonymity.

---

# References

**[R1]** Rachels, James. "Why Privacy Is Important." *Philosophy & Public Affairs* 4(4), 1975, pp. 323-333. JSTOR stable 2265077. https://www.jstor.org/stable/2265077

**[R2]** Nissenbaum, Helen. "Privacy as Contextual Integrity." *Washington Law Review* 79, 2004, p. 119. https://digitalcommons.law.uw.edu/wlr/vol79/iss1/10/

**[R3]** Baumeister, Roy F., Liqing Zhang, and Kathleen D. Vohs. "Gossip as Cultural Learning." *Review of General Psychology* 8(2), 2004, pp. 111-121. DOI: 10.1037/1089-2680.8.2.111. https://doi.org/10.1037/1089-2680.8.2.111

**[R4]** Rimé, Bernard. "Emotion Elicits the Social Sharing of Emotion: Theory and Empirical Review." *Emotion Review* 1(1), 2009, pp. 60-85. DOI: 10.1177/1754073908097189. https://doi.org/10.1177/1754073908097189

**[R5]** Stanford Encyclopedia of Philosophy. "Freedom of Speech," section on speaker theories and expressive interests. https://plato.stanford.edu/entries/freedom-speech/

**[R6]** Kjærvik, Sophie L., and Brad J. Bushman. "A meta-analytic review of anger management activities that increase or decrease arousal: What fuels or douses rage?" *Clinical Psychology Review* 109, 2024, 102414. DOI: 10.1016/j.cpr.2024.102414. https://doi.org/10.1016/j.cpr.2024.102414

**[R7]** Westacott, Emrys. "The Ethics of Gossiping." *International Journal of Applied Philosophy* 14(1), 2000, pp. 65-90. DOI: 10.5840/ijap20001418. https://doi.org/10.5840/ijap20001418

**[R8]** Fabre, Cécile. "The Morality of Gossip: A Kantian Account." *Ethics* 134(1), 2023, pp. 32-56. DOI: 10.1086/725811. https://doi.org/10.1086/725811

**[R9]** Wallace, Kathleen A. "Anonymity." *Ethics and Information Technology* 1(1), 1999, pp. 21-31. DOI: 10.1023/A:1010066509278. https://doi.org/10.1023/A:1010066509278

**[R10]** RateMyProfessors. "Guidelines." Current page accessed 2026-09-01. https://www.ratemyprofessors.com/guidelines

**[R11]** Google Maps User-Contributed Content Policy. "Prohibited and Restricted Content." https://support.google.com/contributionpolicy/

**[R12]** Matias, J. Nathan. "Preventing harassment and increasing group participation through social norms in 2,190 online science discussions." *PNAS* 116(20), 2019, pp. 9785-9789. DOI: 10.1073/pnas.1813486116. https://doi.org/10.1073/pnas.1813486116

**[R13]** The Santa Clara Principles on Transparency and Accountability in Content Moderation. https://www.santaclaraprinciples.org/

**[R14]** Katsaros, Matthew et al. Research on pre-posting reconsideration prompts and offensive social-media content, 2021. arXiv:2112.00773. https://arxiv.org/abs/2112.00773

**[R15]** OWASP Cheat Sheet Series. "LLM Prompt Injection Prevention." Current page accessed 2026-09-01. https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html

**[R16]** IETF RFC 9577. "The Privacy Pass HTTP Authentication Scheme," 2024. https://www.rfc-editor.org/rfc/rfc9577.html

**[R17]** IETF RFC 9578. "Privacy Pass Issuance Protocols," 2024. https://www.rfc-editor.org/rfc/rfc9578.html

**[R18]** Apple. "App Review Guidelines," section 1.2 User-Generated Content. Current page accessed 2026-09-01. https://developer.apple.com/app-store/review/guidelines/

**[R19]** Google Play. "User Generated Content" policy. Current page accessed 2026-09-01. https://support.google.com/googleplay/android-developer/answer/9876937

**[R20]** Australian eSafety Commissioner. "Safety by Design." Current page accessed 2026-09-01. https://www.esafety.gov.au/industry/safety-by-design

**[R21]** NIST AI Resource Center. AI Risk Management Framework, Measure function. Current page accessed 2026-09-01. https://airc.nist.gov/airmf-resources/airmf/5-sec-core/

**[R22]** Abdulgalimov, Dinislam, et al. "Designing for Employee Voice." *Proceedings of CHI 2020*, Article 157. DOI: 10.1145/3313831.3376284. https://doi.org/10.1145/3313831.3376284

---

## Final internal definition

> **HOney Experiences is a student-to-student shared memory of school life. It protects room for praise, criticism, discomfort, uncertainty and self-expression without pretending that every experience is a final verdict. Culture makes nuance normal; executable rules keep the public boundary appropriate; pre-publication moderation keeps serious harm outside; privacy architecture prevents public content from being stored as a student record.**
