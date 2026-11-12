# Non-production geo override and test-user act-as: consolidated plan

Status: exploration/planning spike. No production code. Read-only investigation of spinquest-frontend, Backend, auth-service, spinquest-admin, central-tech, compliance-service, argo-sbx and argo-staging, 2026-11-09 to 2026-11-10. control-plane was not read; every claim about it comes from central-tech docs. Deployed env values live in sops secrets and were not read.

Single source of truth. Supersedes `geolocation-override-exploration-plan.md` and `user-spoofing-exploration-plan.md` (both merged here, 2026-11-10). Deploy mechanics referenced below come from [`staging-deploys.md`](./staging-deploys.md), which stays a separate document.

## Scope

Let developers and QA work in non-production from outside a permitted US location (Part 1: location) and act as a chosen test player placed in a chosen US region (Part 2: identity). Non-production only and fail-closed: it must be impossible to trigger against production. Production geo gating is out of scope and must stay untouched.

## Environments

| Name | Hosts | Backend | Deploy | Central stack |
| --- | --- | --- | --- | --- |
| Legacy dev box | `main.dev.spinquest.com`, `fundist-dev.spinquest.com` | Legacy Backend (pm2, self-hosted runner) | Frontend `deploy-main.yaml`, Backend `deploy.yaml` on merge | No; the frontend has no compliance-client or `/v1/geo` calls |
| Staging | `staging-spinquest` namespace | Legacy Backend image `latest` | GitOps via `argo-staging`, `argocd-image-updater`, auto-sync | Removed: `argo-staging` main was reset on 2026-11-10 to the pre-2026-08-26 tree (SpinQuest-only) |
| sbx | `client.sbx.spinquest.com`, `backend.sbx.spinquest.com` | Backend image `latest` via argo-sbx | GitOps | Yes; whether the sbx Backend runs with central on is not confirmable (sops) |
| PR previews | `pr-<N>-backend.int.spinquest.com`, `pr-<N>-client.int.spinquest.com` | Shares staging's DB unless `db-fork` | `deploy-preview` label | As staging |

Correction to the earlier geo plan: it called the `main.dev` / `fundist-dev` hosts "deployed staging". Per `staging-deploys.md` those are the old dev box; staging is the separate `argo-staging` deployment.

# Part 1: Location (getting past GeoComply)

## What the client does today

- `executeGeoLocation` short-circuits only when `import.meta.env.DEV` is true, returning `dev-geo-bypass` (`spinquest-frontend/src/lib/api/geolocation/service.ts:118`). `pnpm dev:*` and `pnpm staging:*` run `vite`, so local runs are already bypassed.
- Deployed hosts are production builds (`build:base` -> `vite build`), so `DEV` is false and the full GeoComply path runs. They load the GeoComply staging SDK via `VITE_APP_GEOCOMPLY_URL` (`index.html:85`; deploy workflows and `start-local-stack.sh` use `https://stg-cdn.geocomply.com/264/gc-html5.js`).
- The client refuses first. On `OutsideUS` or `ForbiddenStates`, `service.ts:216` rejects before any backend call, so a tester outside the US hits the regional-error modal at login/signup. Every geo entry point (login, signup, game load, shop, redemption, socket, geo gate) funnels through `initializeGeoLocation`.
- The geoPackage the client sends is only evidence; the Backend's `/IPCheck` and `GeoComplyMiddleware` are authoritative. A frontend-only change cannot make a hosted environment agnostic unless the backend or simulator also cooperates.
- `src/config/env.ts` uses zod-preprocessed booleans (`ENABLE_SENTRY`, `ENABLE_POSTHOG`, `ENABLE_MFA`, `ENABLE_SERVER_FLAGS`). There is no geo flag today.
- `src/features/feature-flags/compliance-isolation.test.ts` (AC-10) forbids feature-flag code from gating geo. A build-time env flag does not trip that test, but expect the same objection in review.

## Does the backend gate server-side?

Yes, fail-closed. `GeoComplyMiddleware` and `BlockedStatesMiddleware` guard login, social signup, `/shop/purchase`, `/shop/redemption`, FC game loads, merch orders and `/IPCheck/RefreshToken`. The apparent "stub package is rejected for a non-bypass account" is an unhandled error path, not a deliberate refusal: `decryptGeoPackage` swallows the failure and returns `{}` (`GeoComplyService.ts:190`), then `analyzeGeoPackage:132` dereferences undefined. Rewards are ungated today (`RewardsController.ts:24`, commented out), a pre-existing issue.

## The legacy backend bypass, and why it is not durable

`isGeoBypassRequest` (`Backend/src/utils/geolocation.ts:38`) passes any `@spinquest.com` email or any `GEO_WHITELIST` username; `isGeoBypassUser` (`geolocation.ts:23`) passes everyone when `LOCAL_ENV=true`. `GeoComplyMiddleware.ts:81` then sets the state to `CO`. Line numbers re-checked 2026-11-10.

The team records this as a bug being removed, not a supported feature:
- `central-tech/drafts/backend-bugs.md:73-74`: the `@spinquest.com` email is unverified at signup, and a `GEO_WHITELIST` username is claimable by the first registrant. Recorded fix: operator-granted, audited allowlist only; no username whitelist.
- `central-tech/drafts/legacy-parity-inventory.md:85-86`: same, plus the signup path also skips IDComply.
- `central-tech/drafts/backend-central-readiness.md:88`: staff and QA outside licensed states are meant to go on compliance's location-bypass list in control-plane.
- `central-tech/TODO.md:790`: with central on, central refuses legacy-bypassed staff on its own checks.

Related: Backend `POST /mock/geoPackage` mints a passing GeoComply package for any region and user id, gated only by `ENABLE_MOCKSERVICES_API`. Also recorded as a bug (`central-tech/drafts/backend-bugs.md:65`). Do not build on it.

## Location approaches

| Approach | Effort | Notes |
| --- | --- | --- |
| US VPN / US egress for testers | ~0 code | Needs team sign-off. Unknown whether GeoComply flags it (`proxy` outcome) or a WAF blocks non-US traffic. |
| B. Narrowed frontend flag: build-time `ALLOW_GEO_OVERRIDE` (zod boolean, default false) plus a per-browser opt-in | S (~half a day with review) | Real flow stays default; only an opt-in tester short-circuits. The Backend still gates, so it relies on the legacy bypass above, which closes at cutover. Production isolation unproven (open question 3). |
| A. Point non-prod at the GeoComply simulator | L | Simulator (`central-tech/vendor-stubs/geocomply/`) serves only `license.php`, `POST /sdk/package`, `POST /v1/locate`; no `gc-html5.js`, so `VITE_APP_GEOCOMPLY_URL` cannot point at it. Needs a new in-browser collector plus region picker. Wired for compliance-service only, not legacy Backend. |
| Control-plane location-bypass list (sanctioned successor) | Config only | Operator places one player in a region, action-logged. sbx/local only (`compliance-service/service/src/config.ts:147`, `testEnvironment`/`DEPLOYMENT_ENVIRONMENT`). Does nothing for the legacy dev box or staging. |

Simulator wiring: in argo-sbx, SpinQuest points at real GeoComply staging; cards, predictions and rips point at the simulator (`argo-sbx .../values-compliance.yaml:91-121`, `vendor-stubs/geocomply/README.md`). Per-tenant config is compliance-service env (`GEO_VENDOR_<TENANT>`, `GEOCOMPLY_<TENANT>_LICENSE_URL` plus keys), not control-plane. Control-plane only authors the per-player QA location bypass and test-mode runs, both sbx/local.

# Part 2: Identity (acting as a test player)

## What exists today

No impersonation, act-as or test-login path exists in Backend, auth-service or spinquest-admin (greps for `impersonat`, `loginAs`, `actAs`, `masquerade`, `test-login` returned nothing relevant).

| Where | What | Gate |
| --- | --- | --- |
| auth-service `PUT /v1/internal/auth/players/{id}/password` | Operator sets a known password, revokes sessions, writes `player.set_password` to `action_log` | `OPERATOR_SET_PASSWORD=on`; `qaSwitchOn` calls `refuseInProduction`, a boot fault in production (`service/src/config/qaSwitch.ts`, `config/env.ts:75-89`) |
| auth-service and compliance test mode | Control-plane-signed `x-test-mode` token, 15 minutes, lifts captcha and rate limits, stubs vendors, enables fixed login codes; can be bound to one player | Boots only in `sandbox` and `local` (`central-tech/packages/service-runtime/src/testMode.ts`) |
| compliance QA location bypass | See Part 1 | sbx/local only |
| Backend `feature/auth-central` | Relays `x-test-mode` to auth and compliance | `CENTRAL_TEST_MODE_RELAY`, `sandbox`/`local` only (`src/auth/centralAuthConfig.ts`) |
| spinquest-frontend `feature/auth-central` | Debug-only QA panel taking the token from `#testMode=` (`src/features/test-mode/`, `src/features/debug/install.tsx`) | `VITE_APP_DEBUG_PANEL` sets `__APP_DEBUG__` in `vite.config.ts` |
| Backend `POST /mock/geoPackage` | See Part 1 | `ENABLE_MOCKSERVICES_API` alone; recorded bug |

spinquest-admin talks only to legacy Backend `/admin/*`; staff auth is moving to control-plane (`services/porting/auth.md`), so the admin panel is the wrong home.

## How a session is minted

- **Legacy Backend.** `UserService.generateUserToken` signs HS256 with `JWT_SECRET_KEY`. No `exp`, no session row. Admin and player tokens share type and key. A legacy act-as token would never expire and would be indistinguishable from a real login, so nothing is proposed for legacy Backend.
- **auth-service.** `SessionStartService.startSession(userId, audience, path)` writes `auth.sessions` and mints a 15-minute RS256 access token (`services/session/tokens.ts`). `SessionPath` is a closed union (`login`, `federated`, `federated-signup`, `guest`, `signup`, `exchange`). No actor field, no `act` claim. Refresh re-mints from the row. auth-service owns issuance after migration.
- On `feature/auth-central` the frontend store holds a marker and the session lives in auth's refresh cookie, not `{ user, authToken }`.

## Recommended act-as design (central stack only)

1. **control-plane.** "Act as" on the test-mode page: pick player and region. It sets the player's geo outcome, mints a player-bound test-mode token, asks auth for an act-as code, and opens the frontend with both in the URL fragment.
2. **auth-service.** `POST /v1/internal/auth/players/{id}/act-as`, operator-signed, returns a single-use code valid ~60 seconds; a public redeem route trades it for a session. New `SessionPath` `'act-as'`, `actor` column on `auth.sessions`, `act` claim, `player.act_as` in `action_log`, ~1 hour session cap.
3. **spinquest-frontend (`feature/auth-central`).** `debug/install.tsx` takes `#actAs=`, redeems it, QA panel shows an "acting as" banner.

Identity and region compose on the player id: auth's `sub` is the player id, compliance keys location on player and session, and a player-bound test-mode token is refused for any other player (`TEST_MODE_PLAYER_MISMATCH`). One control-plane action sets both. If SpinQuest moves to the simulator, `simulatorCollector`'s `playerId()` reads the signed-in id with no extra wiring.

Interim, zero new code, sbx only: set the test player's password with the operator route, sign in with a test-mode token, place the player with the location bypass. Destroys the player's password and sessions; throwaway accounts only.

## Fail-closed layers

- Build-time: `VITE_APP_DEBUG_PANEL` -> `__APP_DEBUG__`; a production bundle drops the code.
- Backend: new `OPERATOR_ACT_AS=on` through `qaSwitchOn`, tightened to the `sandbox`/`local` allow-list on `DEPLOYMENT_ENVIRONMENT`; unset or unknown environment refuses to boot.
- Further: routes mounted only when on (404 otherwise); `/v1/internal/` off public ingress; control-plane-signed operator assertion; control-plane permission (e.g. `qa.act-as`).
- Add a mutation-corpus entry and a CI check that production values never carry the switch.

## Changes per repo

| Repo | Minimal change | Effort |
| --- | --- | --- |
| auth-service | Act-as and redeem routes, switch, session column and migration, `act` claim, `action_log` label and migration, spec, mutation entries | M |
| control-plane | "Act as" on the test-mode page with player, region, permission | M (unread) |
| spinquest-frontend (`feature/auth-central`) | Redeem `#actAs=`, banner | S |
| auth-backend package | Expose `act` to verifiers | S |
| Backend (`feature/auth-central`) | Optionally refuse redemptions and withdrawals when `act` is present | S |
| argo-sbx | `OPERATOR_ACT_AS=on` in sbx values only | S |
| compliance-service, spinquest-admin, Backend `PeterSons` | None | none |

Overall: M.

## Act-as risks

- **Session security.** Code travels in the URL fragment: single-use, short-lived. Refresh must re-mint `act` from the session row.
- **Audit.** Session start is only a log line today; the `action_log` row and `actor` column are required.
- **Who can be acted as.** No user model has a test-user flag. If sbx holds mirrored production players, act-as exposes their data.
- **Real side effects.** `central-tech/drafts/per-player-vendors.md`: sbx Sinch uses production credentials, so an acted-as player can trigger a real SMS.

# Shared risks and open questions

## Production isolation (blocks Part 1 option B)

Every frontend image is built by `.github/workflows/build.yaml` on merge and tagged `latest` on the default branch; staging and sbx both pull that image. No production workflow exists on spinquest-frontend `main` and no production GitOps repo was found. `central-tech/drafts/promotion.md` plans digest promotion sbx -> staging by reviewed PR, not yet in effect. If production promotes the same image, a build-time flag cannot separate the environments; the flag would have to be a runtime config or the image built per environment.

## Decision questions

1. Is the control-plane location-bypass list the intended path for QA/developers outside licensed states, and should it cover the legacy dev box and staging or only sbx? (Test mode refuses outside `sandbox`/`local`; staging had central removed on 2026-11-10.) Recommendation: sbx-only.
2. Given the legacy `@spinquest.com` / `GEO_WHITELIST` bypass is being removed, is a stop-gap wanted for the legacy hosts before cutover, or should effort go straight to sbx/central?
3. How are production frontend bundles built and promoted? See Production isolation.
4. Is a US VPN or US egress an acceptable, blessed way to reach non-prod?
5. Which players may be acted as: an allowlist, or only accounts created by a QA run? Does sbx hold mirrored production players?
6. Should money routes (redemptions, withdrawals) refuse a session carrying `act`?
7. How should a player be placed in NY or CA? `/v1/locate` stub outcomes are `US-NJ`, `US-CO`, `US-NV`, `US-WA`, `CA-ON`; the simulator accepts any ISO 3166-2 region, but SpinQuest is not on it.
8. Does SpinQuest on sbx stay on real GeoComply staging or move to the simulator? This decides which region mechanism both Part 1 and Part 2 drive.
9. Is the zero-code interim act-as path acceptable for QA now, given it resets the player's password?

## Verification questions

10. What actually blocks testers today? No one has reproduced the failure from a non-US location.
11. Does Cloudflare or a WAF block non-US traffic to non-prod hosts, and is VPN/proxy traffic flagged?
12. What are the dev, staging and sbx Backend values for `GEO_WHITELIST`, `LOCAL_ENV`, `ENVIRONMENT`, `ENABLE_CENTRAL`, `CENTRAL_TEST_MODE_RELAY`, `TEST_MODE_JWKS`? (sops)
13. Does the GeoComply staging SDK return a usable package from outside the US at all?
14. Does compliance's location bypass still require a real package from the browser, or does it place the player on its own? Can it place a player in a blocked state, to test the denial path?
15. Does control-plane's test-mode page work as `central-tech/drafts/spinquest-scenario-testing.md` describes? Repo not read.
16. Is `central-tech/TODO.md:498` stale? It says the location bypass has had no environment guard since compliance-service#205; the code read on 2026-11-09 gates it (`config.ts:147`).

## Recommendation

Bring this to the team as findings and questions, not a committed fix.

- The one finding independent of all unknowns: the client rejects on `OutsideUS` before any server-side bypass can apply, so a frontend change is probably needed whichever location mechanism is chosen.
- Ask first whether a US VPN is acceptable; it needs no code.
- Do not build on the legacy Backend bypass or `/mock/geoPackage` as durable solutions, and add no act-as path to legacy Backend.
- If act-as is wanted, specify the auth-service route first (security-sensitive); decision questions 1 and 5 block it.
- Confirm decision questions 1 through 4 before writing any location code.
