# How SpinQuest staging deploys work

Audited 2026-11-10 from the workflow files in `Backend`, `spinquest-frontend`, `central-tech`, and the `argo-staging` and `argo-sbx` repos on GitHub. This describes what the repos declare. The live cluster was not inspected.

## Summary

Staging is GitOps. Merging to the default branch deploys to staging with no human step in between. A backend deploy applies pending schema migrations to the staging database in place. The data is never wiped, restored or reseeded.

## The deploy flow (backend and frontend)

1. **Merge to the default branch.** That is `PeterSons` for Backend and `main` for spinquest-frontend.
2. **CI builds and pushes an image to GHCR.** `.github/workflows/build.yaml` in each repo tags it with the branch name, `sha-<7 chars>`, and `latest`. Only the default branch gets `latest`.
3. **The image updater notices the new `latest` digest.** `argocd-image-updater` runs in the staging cluster and commits the new digest into `products/spinquest/envs/staging/values-backend.yaml` or `values-client.yaml` on `argo-staging` main. Those commits read "build: automatic update of spinquest-staging-backend".
4. **ArgoCD syncs automatically.** The `spinquest-staging-backend` and `spinquest-staging-client` Applications have automated sync with prune and self-heal, and deploy into the `staging-spinquest` namespace.
5. **Backend migrations run first.** See the database section below.

## Things the team should know

- **Nothing gates the image on tests.** Backend's `build.yaml` does not depend on `test.yaml`, so any merge that builds reaches staging. Branch protection may require tests before merge; that was not checked.
- **Config changes go through `argo-staging`.** Values and chart changes are a PR there. Secrets are SOPS files applied by hand with `scripts/secret.sh`, not by Argo.
- **PR previews are separate.** Adding the `deploy-preview` label to a Backend or frontend PR creates `pr-<N>-backend.int.spinquest.com` or `pr-<N>-client.int.spinquest.com`. Without the `db-fork` label the preview shares staging's database and skips migrations.
- **The old dev box still deploys on the same merges.** Backend's `deploy.yaml` (pm2 on a self-hosted runner) and the frontend's `deploy-main.yaml` push to `fundist-dev.spinquest.com` and `main.dev.spinquest.com`. That is not staging.

## What happens to the staging database on a deploy

Frontend deploys do not touch the database. On each backend deploy:

1. **A migration Job runs before the new pods roll.** It is an ArgoCD PreSync hook using the new image, defined in `products/spinquest/charts/backend/templates/migration-job.yaml` in `argo-staging`.
2. **It lists migrations first.** An init container runs `npm run db:show`, which prints applied and pending migrations and fails early if the database is unreachable.
3. **It applies whatever is pending.** `npm run db:migrate` is TypeORM `migration:run` over the files in `Backend/src/db/migration` (121 on 2026-11-10). If nothing is pending, it is a no-op.
4. **The Deployment rolls only if the Job succeeds.** There are no retries and a 10 minute limit.

Schema changes come only from those migration files: `synchronize` is `false` in `Backend/src/db/dataSource.ts`, so entities never auto-alter tables.

### Database risks

- **A failed deploy can leave the schema half migrated.** `dataSource.ts` sets `migrationsTransactionMode: 'each'`, so each migration commits on its own. If the third of five fails, the first two stay applied while the old pods keep serving. The chart comment saying the schema "hasn't changed" on failure only holds when the first pending migration is the one that fails.
- **There is no automatic rollback.** Nothing runs `db:revert`. Reverting the image leaves the newer schema in place.
- **No backup is taken before a migration.** Backups are on a schedule only: a weekly full on Sunday 01:00 and incrementals on the other days, stored on a volume in the same cluster.
- **A migration affects more than staging.** PR previews without the `db-fork` label share this database, so a destructive migration merged to `PeterSons` changes the schema under every open preview. The latest migration, `drop-promotion-domain`, is that kind.

## Two things in flux

- **Staging was rolled back on 2026-11-10.** At 05:18 UTC Sawyer reset `argo-staging` main to the pre-2026-08-26 tree. The commit message says central, rips, predictions, the collectors and the CI were removed, with secrets and SpinQuest image tags kept current. The previous tree is on the `archive/main-2026-11` branch, so staging is SpinQuest-only for now.
- **The plan is to drop the image updater on staging.** `central-tech/drafts/promotion.md` (Stan, 2026-11-03 and 2026-11-05) describes promoting the exact digest that ran on sbx to staging through a reviewed PR, by hand first and with Kargo later. That is not in effect for SpinQuest: the updater config is still on `argo-staging` main.

## Not verified

- There was no cluster or Argo access, so this is what the repos declare, not what is running.
- No image updater commit had landed on `argo-staging` main between the reset and the time of this audit, so the updater firing again is unconfirmed.
- Job logs and the migrations table were not read, so which migrations staging has actually applied is unknown.
- Whether branch protection requires passing tests before merge was not checked.
