---
name: local-stack
description: Use to run or inspect the SpinQuest local stack. Modes are up (start Backend and frontend), status (probe every service), test-user (non-prod user with geo override), staging (deploy walkthrough).
---

# local-stack

Input: a mode (`up`, `status`, `test-user`, `staging`). Default `status`. Sources: `personal-docs/start-local-stack.sh` (local), and in Notion (links in `.claude/notion-docs.md`): Running SpinQuest locally, How SpinQuest staging deploys work, and the non-production geo override and test-user plan. Re-read the one you need; do not rely on this summary for details.

## up

1. Run `personal-docs/start-local-stack.sh check`. Report missing `.env` key names, never values.
2. Tell the user to run `personal-docs/start-local-stack.sh` (or `up cards`) in their own terminal. It switches to Node 24, starts Docker Desktop, Postgres and Redis, runs migrations, then starts the API (3000) and frontend (3001).
3. Run `status` once the user confirms it is up.
4. For one service only, use `.claude/launch.json` (`backend-api`, `spinquest-frontend`, `rips-frontend`, `mobile-metro`). Those entries need Node 24 on PATH and Postgres and Redis already running.
5. The mobile app is verified in the iOS Simulator, not the browser pane; `mobile-metro` starts Metro only.
6. `down` stops Postgres and Redis. Not started by the script: the Temporal arena worker (`pnpm arena:worker`), compliance-service, central-tech.

## status

Probe each service. Every probe must work with the stack down; a failed probe is a result, not an error.

```bash
for entry in backend-api:3000 spinquest-frontend:3001 rips-frontend:5173 mobile-metro:8081; do
  name=${entry%%:*}; port=${entry##*:}
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "http://localhost:$port/" || true)
  case "$code" in 000|"") state=down;; *) state="up (HTTP $code)";; esac
  echo "$name :$port $state"
done
curl -s --max-time 2 http://localhost:3000/status/health || echo "backend health: unreachable"
nc -z localhost 5432 >/dev/null 2>&1 && echo "postgres :5432 up" || echo "postgres :5432 down"
nc -z localhost 6379 >/dev/null 2>&1 && echo "redis :6379 up" || echo "redis :6379 down"
```

Report one line per service. `/status/health` (StatusController) returns `{status, database, redis}`; a Backend that is up with `database: disconnected` is a finding. The Backend may answer 404 on `/` and still be up.

## test-user

1. Read the Notion page for the non-production geo override and test-user plan first. It is a planning spike, not a shipped feature.
2. Local runs already bypass GeoComply on the client (`import.meta.env.DEV`). The Backend gates server-side; the `@spinquest.com` email and `GEO_WHITELIST` bypasses are recorded bugs, never durable.
3. Deployed non-prod (sbx, staging, PR previews): present the plan's options and open decision questions; do not invent a path. The act-as design applies to the central stack on sbx only.
4. Never create an account on a production host. Never use `POST /mock/geoPackage` or the legacy bypass as a recommendation. Use throwaway accounts only.
5. Do not enter credentials; the user types them.

## staging

Walkthrough only; read the Notion page How SpinQuest staging deploys work first.

1. Explain the flow: merge to the default branch (`PeterSons` for Backend, `main` for spinquest-frontend), CI builds a GHCR image, the image updater commits the digest to `argo-staging`, ArgoCD syncs.
2. State the database facts: a Backend deploy runs pending migrations in place, no backup first, no automatic rollback, and a failed deploy can leave the schema half migrated.
3. Check the doc's "Two things in flux" and "Not verified" sections and say what is unconfirmed.
4. Run no deploy command unless the user asks. `gh workflow run`, `kubectl`, `argocd`, `helm`, `pnpm db:migrate` and `pnpm db:revert` hit `permissions.ask`; show the command and wait for approval.
