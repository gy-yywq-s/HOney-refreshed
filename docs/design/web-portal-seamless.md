# Web School Portal — seamless connection & saved progress (2026-09-01)

Gary's directive: the web School Portal must match the iOS app's **seamless
connection** (never make the user reconnect for a routine time-out) and
**saved progress** (state survives navigation and reloads).

## Constraint that shapes the design
The OASIS portal is token-based with a **~24h token and NO refresh token**
(`docs/regressions-2026-09-01.md`): surviving expiry *requires* a full
re-login. iOS achieves "never ask again" by holding the school credentials in
the **Keychain** and silently re-logging in, then handing the fresh token to
the backend (`/api/portal/token`). The backend deliberately **stores no school
password** (`app.ts` `emptyVault`; importer marks `portal_reconnect_required`
on expiry). Web Access (opening gates from the browser) is separately **off**
— the portal's GET responses carry no `Access-Control-Allow-Origin`, so a
browser cannot read them.

Therefore the *only* faithful web analog of iOS seamlessness is to let the
**browser play the Keychain's role**: hold the credentials device-locally and
silently replay them to the same `/api/auth/login` the manual sign-in already
uses. There is no token-only shortcut — without a refresh token, seamlessness
across expiry is impossible without stored credentials.

## Design

### Seamless connection (opt-in, OFF by default)
- **Store** (`apps/web/src/lib/portalCredentials.ts`): school username/password,
  AES-GCM encrypted at rest, key in the same origin's localStorage — the exact
  posture and honest threat model of the private-notes store
  (`ownershipKeys.ts`). A browser is a weaker vault than the iOS Keychain
  (same-origin script / XSS can read it); the opt-in copy says so plainly.
- **Silent reconnect** (`api.syncSeamless()`): a sync that returns
  `portal_reconnect_required` and finds authorized credentials silently
  re-logs in (same `/api/auth/login`, password transient — backend still
  stores nothing) and retries the sync once. A manual prompt appears **only**
  when the credentials are actually rejected or the portal raises an
  interactive challenge — the iOS invariant, verbatim.
- **Opt-in points**: the first-login consent step ("Stay connected on this
  device", unchecked), and Settings → School connection (Turn on / Turn off).
  The `ReconnectDialog` (now a fallback) also offers to keep the login.
- **Lifecycle**: `portalCredentials.clear()` on sign-out and on account
  deletion's "erase everything"; opt-out clears immediately.

### Saved progress
- **Session** persists in localStorage (already true) → reloads stay signed in.
- **Data** is served instantly from the keyed in-memory SWR cache
  (`useApi`, 2026-09-01) and revalidated in the background; a failed
  revalidation keeps the cached view. Sync/publish/consent/disconnect
  invalidate the right prefixes.
- **Standalone PWA** (`manifest` scope `/` + service worker): the installed
  app keeps every route and opens instantly offline with its last shell.

## What is NOT done (honest boundary)
- No Web Access (gate opening) — CORS-blocked, stays capability-gated off.
- The backend still stores no password and gains no new credential surface;
  everything added here lives in the browser and is opt-in.
- No background reconnect while the tab is closed — the browser can only run
  the silent re-login while the app is open (a phone can do more; this is the
  honest web limit).
