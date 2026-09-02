# Deploying HOney

HOney runs as **one Node service** (API + built web SPA) **directly under the linux user
`honey`** on the droplet — a standalone deployment, not a hostd-managed site (Gary's call,
2026-08-31). hostd is only touched for the shared Cloudflare tunnel route (the documented
`config.base.yml` + `hostd tunnel-sync` path for non-hostd services).

## Layout

| What | Where |
|---|---|
| Production checkout | `/home/honey/app` (clone of this repo, branch `main`) |
| Persistent data (SQLite) | `/home/honey/data/honey.db` |
| Secrets env | `/home/honey/.secrets/honey.env` (0600: HONEY_SECRET, OPENROUTER_API_KEY, admin id, PORT=8871) |
| Service | systemd `honey.service`, `User=honey`, binds `127.0.0.1:8871` |
| Ingress | `honey.gaelisus.com` → tunnel rule in `/etc/cloudflared/config.base.yml` |

## Update to a new version

```bash
sudo -u honey bash -lc 'cd /home/honey/app && git pull &&   npx --yes pnpm@11.24.0 install --frozen-lockfile &&   npx --yes pnpm@11.24.0 -r build && npx --yes pnpm@11.24.0 --filter @honey/web build'
sudo systemctl restart honey && sleep 1 && curl -s https://honey.gaelisus.com/api/health
```

The production OpenRouter key is swapped later via the admin dash (sealed in the DB) or by
editing the secrets env. The historical hostd manifest draft lives in git history only.

## Development database reset (schema epoch change)

There is no migration across schema epochs (canonical school data, 2026-09-02): a database
from an earlier epoch makes the service refuse to start (`SchemaEpochError`). Reset it:

```bash
sudo systemctl stop honey
sudo -u honey bash -lc 'cd /home/honey/app && npx --yes pnpm@11.24.0 --filter @honey/backend db:reset:dev -- --yes'
sudo systemctl start honey && sleep 1 && curl -s https://honey.gaelisus.com/api/health
```

The script deletes the SQLite files, recreates the schema, imports the real fixture into a
throwaway account and asserts the canonicalization before exiting 0. Accounts are re-created by
signing in again (a school login is signup); the first sign-in re-imports the live timetable.
