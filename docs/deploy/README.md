# Deploying HOney

HOney runs as **three Node services behind one small edge proxy**, all **directly under the linux
user `honey`** on the droplet — a standalone deployment, not a hostd-managed site (Gary's call,
2026-08-31). hostd is only touched for the shared Cloudflare tunnel route (the documented
`config.base.yml` + `hostd tunnel-sync` path for non-hostd services). The process/database map and
why it is split this way: [`../architecture/community-process.md`](../architecture/community-process.md).

## Layout

| What | Where |
|---|---|
| Production checkout | `/home/honey/app` (clone of this repo; dev stage tracks `integration/product-v2`) |
| Edge (public port, the tunnel's target) | systemd `honey-edge.service` → `127.0.0.1:8871` (`packages/edge`; unit in `systemd/`) |
| Core (accounts, school data, issuer, vault + the web app) | systemd `honey.service` → `127.0.0.1:8872`; `/home/honey/data/honey.db` + `vault.db` |
| Community (identity-free posts) | systemd `honey-community.service` → `127.0.0.1:8873`; `/home/honey/data/community.db` |
| Core secrets env | `/home/honey/.secrets/honey.env` (0600: HONEY_SECRET, HONEY_INTERNAL_SECRET, admin id, HONEY_DB_PATH, PORT=8872) |
| Community secrets env | `/home/honey/.secrets/community.env` (0600: HONEY_COMMUNITY_SECRET, HONEY_INTERNAL_SECRET, OPENROUTER_API_KEY, HONEY_COMMUNITY_DB_PATH, HONEY_KEYS_DIR) — never HONEY_SECRET |
| Service keys | `/home/honey/data/keys/` (0700): `issuer.jwk.json` (blind-eligibility issuer, 0600, never in git; `pnpm --filter @honey/backend issuer:keygen` with the service env loaded) + the public descriptors written for peer processes |
| Control Vault | `/home/honey/data/vault.db` (ciphertext only; a separate file from `honey.db` by design) |
| Ingress | `honey.gaelisus.com` → tunnel rule in `/etc/cloudflared/config.base.yml` |

## Update to a new version

```bash
sudo -u honey bash -lc 'cd /home/honey/app && git pull &&   npx --yes pnpm@11.24.0 install --frozen-lockfile &&   npx --yes pnpm@11.24.0 -r build && npx --yes pnpm@11.24.0 --filter @honey/web build'
sudo systemctl restart honey honey-community honey-edge && sleep 3 \
  && curl -s https://honey.gaelisus.com/api/health && curl -s https://honey.gaelisus.com/community/health
```

Unit files live in `docs/deploy/systemd/` (copy to `/etc/systemd/system/`, `systemctl daemon-reload`,
`enable --now`). Each unit hides the other services' database files with `InaccessiblePaths=`.

The production OpenRouter key is swapped later via the admin dash (sealed in the DB) or by
editing the secrets env. The historical hostd manifest draft lives in git history only.

## Development database reset (schema epoch change)

There is no migration across schema epochs (canonical school data, 2026-09-02): a database
from an earlier epoch makes the service refuse to start (`SchemaEpochError`). Reset it:

```bash
sudo systemctl stop honey
# The service env carries HONEY_DB_PATH — without it the script would reset ./honey.db in the checkout.
sudo -u honey bash -lc 'set -a; . /home/honey/.secrets/honey.env; set +a; cd /home/honey/app && npx --yes pnpm@11.24.0 --filter @honey/backend db:reset:dev -- --yes'
sudo systemctl start honey && sleep 3 && curl -s https://honey.gaelisus.com/api/health
```

The script deletes the SQLite files, recreates the schema, imports the real fixture into a
throwaway account and asserts the canonicalization before exiting 0. Accounts are re-created by
signing in again (a school login is signup); the first sign-in re-imports the live timetable.
