# Deploying HOney

HOney ships as **one Node service** (the backend serves `/api/*` and the built web
SPA with client-side-routing fallback). Target: **honey.gaelisus.com** on the droplet
via hostd/Croft.

## One-time, by Gary

1. Set secret values on the droplet:
   ```
   hostd secret set honey HONEY_SECRET          # long random string
   hostd secret set honey OPENROUTER_API_KEY    # production OpenRouter key
   ```
2. Deploy by copying [`honey.yaml`](honey.yaml) into the control repo
   `gy-yywq-s/droplet-hosting` as `sites/honey.yaml` and pushing a commit whose message
   carries a fresh `hostd-code:` trailer (6 digits from the **hostd-deploy** authenticator),
   or `croft.deploy({...}, code="NNNNNN")`.

Then check `status/honey.json` in the control repo — `ok` means live.

## What the manifest guarantees

- **Persistence**: SQLite lives in `$HOSTD_DATA_DIR` (survives deploys); nothing else does.
- **Port contract**: the service binds `127.0.0.1:$PORT` (hostd sets `$PORT`).
- **Single origin**: web + API share `honey.gaelisus.com`, so the browser makes only
  same-origin calls — no CORS to configure. (This is unrelated to the school-portal CORS
  question, which still gates Web Access — see the spec §11.4.)
- **Admin**: `HONEY_ADMIN_STUDENT_ID=0088` → studentId 0088 is the dash admin.

## Local production check

```
pnpm install && pnpm -r build && pnpm --filter @honey/web build
HONEY_DB_PATH=/tmp/honey.db node packages/backend/dist/server.js
# → serves API + web on http://127.0.0.1:8080
```
