# Running SpinQuest locally

The single source of truth for running the Backend API and the frontend on this machine. The runner is [start-local-stack.sh](start-local-stack.sh) in this folder. Verified 2026-11-10: a full `up` served the API and the frontend with HTTP 200 about 27 seconds after launch, with no errors in the log.

## What runs where

| Piece | Repo | Command | Port |
|---|---|---|---|
| Postgres 17 and Redis 7.4 | `Backend/docker-compose.yaml` | `docker compose up -d`, run from `Backend/` (data lives in `Backend/data/`) | 5432, 6379 |
| Backend API | `Backend/` | `pnpm db:migrate`, then `pnpm start` (ts-node-dev, restarts on changes, debugger on 9229) | 3000 |
| Frontend | `spinquest-frontend/` | `pnpm dev:casino` or `pnpm dev:cards` (Vite, opens a browser tab) | 3001 |

## Using the script

The script finds the `Backend` and `spinquest-frontend` checkouts in this order: `$SPINQUEST_WORKSPACE_DIR`, the script's own folder, then `~/Desktop/work/spinquest`. It can run from anywhere.

```bash
./start-local-stack.sh
```

```bash
./start-local-stack.sh up cards
```

```bash
./start-local-stack.sh check
```

```bash
./start-local-stack.sh down
```

- `up` (the default) starts the casino product; `up cards` starts cards instead.
- Ctrl-C stops the API and frontend. Postgres and Redis keep running until `down`.
- `check` lists `.env` keys the local stack needs but lacks. It prints names, never values.
- `up` steps, in order: switch to Node 24, create or check `.env` files, start Docker Desktop if needed, install dependencies when `node_modules` is missing, start Postgres and Redis and wait for Postgres, run migrations, start the API and frontend with `[api]` and `[web]` prefixed output.

## Toolchain

- **Node 24.** `Backend/.nvmrc` pins 24.16.0 and the frontend's pins 24.10.0. The machine default is Node 22, so the script switches through nvm.
- **pnpm.** Backend pins 11.5.2 and a global pnpm 12 switches to it automatically. The frontend pins 10.34.5, which a newer global pnpm refuses under the repo's trust policy, so the script runs the frontend through `corepack pnpm`.
- **Docker Desktop.** The script starts it and waits up to 120 seconds.

## Env files

On first run the script copies each repo's `.env.example` to `.env` and adds local values. It never edits an existing `.env`.

- **Backend:** `API_URL` and `APP_URL` for ports 3000 and 3001, `CORS_ORIGINS` listing both, `TURNSTILE_HOSTNAMES` including `localhost`, a generated `MFA_SECRET_ENC_KEY`, `OPTIMOVE_BRAND_ID=0`, and the placeholder `dev` for keys the code requires but `.env.example` omits (Apple, Google and Meta OAuth IDs, `RECENT_CATEGORY_ID`, the four S3 keys). A missing one throws when its service is first constructed.
- **Frontend:** `VITE_APP_API_URL=http://localhost:3000`, the staging GeoComply SDK URL for `VITE_APP_GEOCOMPLY_URL` (a blank value crashes Vite on `index.html`), and an empty `VITE_APP_INTERCOM_APP_ID`.

Known gaps in the frontend's `.env.example` (from [spinquest-frontend-dossier.md](spinquest-frontend-dossier.md), section 7): it omits `VITE_APP_PRODUCT` (the `dev:*` scripts inject it) and `VITE_APP_INTERCOM_APP_ID`, and lists `VITE_APP_SENTRY_DSN` twice. The frontend README's "Node.js (>= 20.x)" is wrong; use 24.

## Not covered

- The Temporal arena worker (`pnpm arena:worker`) is not started. Run it separately for arena work.
- `compliance-service` and `central-tech` are not part of the local stack; the Backend boots without them.
- A backgrounded copy of the script ignores Ctrl-C. Stop it with `kill -TERM <pid>`.

## Related docs

- [staging-deploys.md](staging-deploys.md): how merges reach staging and what deploys do to the staging database.
- [spinquest-frontend-dossier.md](spinquest-frontend-dossier.md): frontend architecture, tests and documentation staleness.
