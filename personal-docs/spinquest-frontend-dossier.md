# SpinQuest frontend: new-joiner dossier

Baseline audited on 2026-11-09 against tracked `main` at `5b20ce8ad` (package version 0.0.419). This is a source, configuration, and reachable Git history review, plus (from revision 5) one scratch production build, a local `tsc`/ESLint/Vitest run, and `git blame` line ownership. No browser flows, backend policies, deployment status, branch protection settings, or credential rotation were verified. Remote-tracking branches describe local Git snapshots. Text-search counts are inventories and depend on their patterns. Risk ratings and phase boundaries are editorial judgments.

**Revision 4:** Every repo-checkable claim was re-run against the code and Git history on 2026-11-09 and the errors found were corrected. Section 9 now states problem, fix, and value for each finding. The web-sourced claims in section 1 were not re-checked.

**Revision 5 (2026-11-10):** This file is now the single source of truth for the frontend audit. Revision 5 merges a second forensic pass (stack and complexity, dead code, security, authorship). Changes:
- **Runtime confirmation.** Finding 35 (Veriff secret in the bundle) and finding 1 (chunking) were confirmed with a canary build.
- **Suite results.** The test and lint suites were run; results are in section 6.
- **Authorship.** Section 8 gains line ownership and identity anomalies.
- **New findings.** Section 9 gains findings 43 to 55.
- **Not done.** The correctness-bug pass did not finish, so section 9 has no new bug findings from it.

Related personal docs (separate topics, not merged):
- [`non-prod-geo-and-test-user-plan.md`](./non-prod-geo-and-test-user-plan.md)
- [`staging-deploys.md`](./staging-deploys.md) (covers how the GHCR, Argo and dev-box deploy lanes relate)
- [`local-development.md`](./local-development.md)

---

## 1. Company dossier

The frontend establishes which integrations and policy displays are wired. Current operating terms, corporate roles, vendor contracts, and regulatory status require independent evidence.

| Topic | Evidence and limits |
|---|---|
| Operator and registration | `public/mdx/responsible-gaming/en.mdx:3` names Social Gaming Room LLC. The operator’s September 25, 2026 Privacy Policy identifies the same entity dba SpinQuest. Indexed June 2025 terms give a California registered office and separate mail-in address. No registry filing was independently verified. [Privacy Policy](https://spinquest.com/privacy/privacy-policy) |
| Leadership, launch, and catalogue | Affiliate reports conflict on leadership and conflate company founding and product launch dates. The repo provides no evidence for a CEO, CTO, founding date, launch date, current catalogue size, or exhaustive provider roster. Prior affiliate attributions are unverified. |
| Coin model, age, and mail-in entry | Indexed June 2025 operator rules describe Gold Coins and promotional Sweep Coins, an 18+ baseline, a daily claim without a guaranteed amount in the cited text, and a mail-in method credited with five Sweep Coins. These are dated terms. The general AMOE UI lives in `src/features/amoe`. The exact current daily award and current general mail-in rules remain unverified. [Indexed Sweepstakes Rules](https://spinquest.com/privacy/sweepstakes-rules) |
| Redemption minimum | The frontend hard-codes 50 SC in three wallet locations. This verifies the client threshold only. Current backend limits, method-specific limits, and operative rules remain unverified. |
| Eligibility | The 500K Giveaway has a frontend exclusion list at `src/features/landing/primitives/official-rules-link/rules-text.ts:103`, including California, Indiana, Maine, Oklahoma, and Tennessee in addition to several states cited by affiliates. It applies to that promotion, with a separate 21+ condition for its trip component. General Terms and Sweepstakes Rules are retrieved via `GET /terms` and document URLs (`src/lib/api/terms/index.ts:5-9,29-36`). The geo gate reacts to backend challenges, which does not reveal the server's jurisdiction matrix. |
| Payments, KYC, and geo | Code wires Apple Pay JS, AeroPay, Link Money, Veriff, and GeoComply. Paytech and Fyntek appear in purchase status code. Fundist naming and API wiring support an integration inference. Accepted card networks, enabled methods per customer, and the vendors’ contractual roles remain unverified. |
| Other product surfaces | The cards feature directory (`src/features/spinquest-cards`) has 112 tracked files at this baseline, merch is on a separate branch snapshot, and the production sports parent redirects. These facts establish repository surfaces. Public launch or availability remains unverified. |
| Regulatory action | The frontend provides no regulatory record. A targeted official-domain search did not produce an order naming SpinQuest. That search leaves enforcement status open. |

---

## 2. Codebase overview and complexity rating

**Verdict: mid-level difficulty. A large, integration-heavy React SPA whose difficulty is breadth (compliance, payments, two products, real-time balance), not depth.**

### Stack

| Concern | Choice | Evidence |
|---|---|---|
| Framework | React ^18.3.1, TypeScript ^5.4.5 | `package.json:68`, `:145` |
| Build | Vite ^6.4.5, `@vitejs/plugin-react` with Emotion babel plugin | `package.json:146`, `vite.config.ts:81-86` |
| UI | MUI ^5.16.7 + Emotion; framer-motion, swiper, keen-slider, lottie | `package.json:37-48,56,61,86` |
| State | zustand ^4.5.2 (27 store files; 7 in `src/store`, 20 in features) | `package.json:89` |
| Server state | TanStack Query ^5.32 + axios ^1.20 | `package.json:51,54` |
| Router | react-router-dom ^6.30.6, `createBrowserRouter` wrapped by Sentry | `src/app/routes/index.tsx:44` |
| Forms | react-hook-form + zod | `package.json:74,88` |
| i18n | i18next, locales in `public/locales`, legal text as MDX in `public/mdx` | `src/lib/i18n.ts:1-3` |
| Tests | vitest ^3.2.6 + jsdom + Testing Library; Playwright ^1.60; Storybook ^8.6 | `package.json:98-111,141,150` |
| Tooling | ESLint 8 (legacy `.eslintrc.cjs`), prettier, husky, lint-staged, commitlint | `package.json:126` |
| Runtime | pnpm 10.34.5, Node 24.10.0 | `package.json:152`, `.nvmrc` |

### Size

| Metric | Value | Command |
|---|---|---|
| Tracked files | 1,895 | `git ls-files \| wc -l` |
| TS/TSX under `src/` | 1,266 files, 115,495 lines | `git ls-files 'src/*.ts' 'src/*.tsx' \| xargs cat \| wc -l` |
| Unit test files | 107 | `git ls-files src \| grep -cE '\.test\.tsx?$'` |
| E2E specs | 10 | `git ls-files e2e \| grep -c spec.ts` |
| Feature folders | 26 | `ls src/features \| wc -l` |
| Route factories | 19 modules exporting 20 registered values (plus 1 test) | `git ls-files \| grep route.factory` |
| Assets | 493 files under `src/assets` (26% of the repo), 31 MB; `public/` 4.1 MB | `git ls-files src/assets \| wc -l`; `du -sh` |
| Growth | 69,355 lines in 897 files at `c04edc73` (2026-07-23, the commit central-tech's client review was written against) to 115,495 in 1,266 at HEAD: +66% in about 3.5 months, mostly `landing`, `mfa` and `spinquest-cards` | `git show <commit>:<file> \| wc -l` over `git ls-tree` |
| Built output | 2 JS files, 1.87 MB and 2.91 MB raw (709 KB and 776 KB gzip); `dist/` 22 MB | scratch `vite build`, 2026-11-10 |

Largest features by file count: auth 146, casino 123, spinquest-cards 112, landing 88, affiliate-program 70, mfa 69, shop 55, wallet 52.

### Build and deploy shape

- **Product switch.** `VITE_APP_PRODUCT` is `casino` or `cards` (`src/config/env.ts:48`). It is shallow: one Vite alias swaps the lobby hero (`vite.config.ts:21-38`), cards routes return `[]` in a casino build (`src/features/spinquest-cards/route.factory.tsx:6`), and `isCardsProduct`/`isCasinoProduct` appear in 4 non-test files.
- **Chunks.** Two named manual buckets, `vendor` and `core` (`vite.config.ts:59-65`). A scratch build emitted exactly 2 JS files, so no route is lazily loaded over the network. See finding 1.
- **Container.** Multi-stage `Dockerfile` on `node:24-alpine`, 18 Vite configuration build args and a build-only `NODE_OPTIONS` arg, served by `nginxinc/nginx-unprivileged` on 8080 (`Dockerfile:69,78`). A Helm chart lives in `charts/client`.
- **Workflows.**

| File | Trigger | Does | Checks |
|---|---|---|---|
| `build.yaml` | push `main`/`cards`, PRs, manual dispatch | Build and push Docker image (also on PRs); a second cards image on pushes to `cards` | Production TypeScript compile through `build:base`; no test or lint step |
| `deploy-main.yaml` | push `main` | `pnpm version patch` (skipped on `[skip-version]`), build, copy `dist` to the host directory `spinquest-frontend-main-dev` | Production TypeScript compile through `build:base`; no test or lint step |
| `deploy-cards.yaml` | push `cards` | Same with `build:cards` | Production TypeScript compile through `build:base`; no test or lint step |
| `deploy-merch.yaml` | push `merch` | `build:casino` from the merch branch | Production TypeScript compile through `build:base`; no test or lint step |
| `security.yaml` | PRs to `main`, push `main` | `pnpm audit --audit-level=high` | Dependency audit |

- **Version bot.** 406 "GitHub Actions" commits on main (235 `Bump version`, 171 `Bump cards version`), starting 2025-03-19 (`61c4a8bb7`). That is 19% of all commits; filter them out of any history query.
- **Runners and targets.** The three deploy workflows run on a `self-hosted` runner (`deploy-main.yaml:12`); `build.yaml` and `security.yaml` use `ubuntu-latest`. The cards lane serves `cards.dev.spinquest.com` (`deploy-cards.yaml:71-76`). The repo has 2 git tags.
- **Duplicate scripts.** Both `ts:check` (`package.json:22`) and `typecheck` (`package.json:32`) exist and run the same compile, with the flags in a different order; the pre-commit hook uses `typecheck`.
- **Two deploy paths coexist**: workflows copy `dist` to a host path, while `charts/` and Flux commits describe a Kubernetes path. The host paths are named `spinquest-frontend-main-dev` and `cards.dev.spinquest.com`, which suggests the workflow lanes are dev environments. Which path serves production is unverified: ask.

### Integration surface

| Area | Vendor | Wiring | Loaded via |
|---|---|---|---|
| Payments | Fundist API; Apple Pay JS; AeroPay; Link Money/AeroSync | `src/features/shop/components/checkout-payment-page/index.tsx:362-367`; `shop-package-modal/link-money/index.tsx:388` | API; script tag `index.html:83`; `aerosync-web-sdk` is declared (`package.json:53`) but has 0 imports in `src`, and no script tag or loader for it was found; the cited `link-money/index.tsx:388` is only the widget's mount `<div>` |
| KYC | Veriff in-context SDK | `src/features/kyc/hooks/use-kyc-verification.ts:2` | npm |
| Geolocation | GeoComply, fingerprint fallback | `src/lib/api/geolocation/service.ts:57`, `src/lib/api/gates/geo-gate.ts` | script tags `index.html:84-85`, including a 160 KB vendored `public/geotoken.js` |
| Analytics | PostHog; Google Tag Manager | `src/lib/analytics.ts:1`; `src/main.tsx:16` (hardcoded id) | npm |
| Errors | Sentry v8 | `src/lib/sentry.ts:19` | npm |
| Games | Provider iframe, URL from backend. Fundist appears to be the platform and game aggregator behind the API (`src/hooks/use-handle-fundist-errors.ts`, dev API host in the staging script at `package.json:12`); 49 tracked files mention it | `src/features/casino/components/game/index.tsx:145` | iframe |
| Real time | socket.io-client ^4.8.3 into the balance store, with an 8-second optimistic window (`src/store/balance.ts:20`, `OPTIMISTIC_WINDOW_MS = 8000`) | `src/lib/socket/index.tsx:43,72-74` | npm |
| Bot protection | Cloudflare Turnstile | `src/components/common/cloudflare-turnstile/cloudflare-turnstile.tsx:70` | dynamic script |
| Support | Intercom with backend JWT | `src/lib/intercom.tsx:5` | npm |
| Feature flags | With server flags enabled, authenticated users use server values or fallback. Otherwise the PostHog path applies | `src/store/feature-flags.ts:1-40` | npm |

### Complexity rating

Present: a compliance surface spread over many features (geo gates, KYC, MFA, responsible gaming, AMOE, terms re-acceptance); three visible checkout methods (card, Link Money, and availability-gated Apple Pay); a socket-driven balance store; an iframe game host with a documented guardrail against re-rendering the game outlet (`src/store/feature-flags.ts:19-22`); a gate-and-retry loop around every API call (`src/lib/api/api-client.ts:41`).

Absent: `git grep -lE "WebGL|<canvas|getContext\(|new Worker|OffscreenCanvas" -- src` returns nothing. No SSR, no custom bundler plugins, no algorithmic core. Animation is off-the-shelf. Many feature folders are thin REST screens.

---

## 3. Code epochs

Seven editorial phases over the observed history. The 2025 H2 lull and later cards integration are visible in reachable commits. Monthly counts use author dates.

| # | Dates | Non-merge commits per month, excluding identified bots | Dominant authors | What happened | Representative commits | Debt left behind (still at HEAD) |
|---|---|---|---|---|---|---|
| 1 | 2024-08-15 to 2024-10 | 40, 176, 117 | Rishabh, Nanda | 224-file scaffold (Vite 5, MUI 5, yarn, husky, commitlint, Storybook), then casino, vault, sports, shop | `57360cc05`, `2835719f8`, `cd68f422e` | Direct pushes to main; keen-slider still a dependency (`package.json:61`) |
| 2 | 2024-11 to 2025-02 | 179, 58, 33, 54 | Rishabh, Prashant, Nanda | PR merges already present (`4ee98297d`, 2024-10-08, PR #2), Sentry and analytics (`3089b840c`), swiper replaces keen-slider (`74c997edc`) | as listed | Slider migration never finished (`src/components/ui/slider/slider.tsx:17`) |
| 3 | 2025-03 to 2025-05 | 210, 48, 53 | Rishabh, Prashant, Nanda | KYC rewrite (`84c10912c`), version-bump bot (`61c4a8bb7`), Playwright suite (`f99718528`), `TESTING_GUIDE.md` (`1206a3f01`) | as listed | E2E suite written then left; `[skip-version]` escape hatches in commit messages |
| 4 | 2025-06 to 2025-12 | 24, 26, 11, 6, 10, 27, 16 | Nanda, Rishabh, Prashant | Maintenance lull: 120 human commits against 97 bot commits over seven months. Docker and nginx first added (`4d9d5b49b`, 2025-09-04) | `8405eacc1` | `nginx.conf` (listen 3000) and `default.conf` (listen 8080) both at root |
| 5 | 2026-01 to 2026-03 | 34, 22, 20 | Luke Greenleaf, gishmel | Helm chart (`3bab311b4`), workflow rework (`112dbcc3c`), Flux (`7fd5d30de`), PR environments (`de2a66b96`) | as listed | `charts/` untouched since 2026-03-24 (`c26bca1e5`); Luke's last main commit is 2026-03-26 and gishmel's is 2026-03-02 |
| 6 | 2026-04 to 2026-10 | 35, 23, 28, 122, 22, 10, 25 | Rishabh, Nanda, Prashant; Chris Connors on merch | Cards product on a long-lived branch (`f79f902d5`), pnpm migration (`1badb8cfe`, 2026-05-21), reskin and shop-as-modal (`59628f77d`, `2b83b7012`), smart-modal-navigation, dependabot and supply-chain hardening, a unit-test expansion (34 of the current test paths first added in July 2026) | as listed | Cards hooks on mock services; three modal systems; 926 remote branches |
| 7 | 2026-11 (now) | 23 so far | Rishabh, Nanda, Prashant | Cards merged to main (`8886b3b5d`, PR #742, 2026-11-05) after branch integration work; one deploy workflow per branch (`62853bc3b`); dead-code removal (`303f1bc6a`); new landing feature (`38ccbb17e`) | as listed | Merch still unmerged |

### Where we are now

`git rev-list --left-right --count origin/main...origin/cards` gives `39 1`: cards is integrated as a feature, while the branch still has one unique commit and a separate configured deploy lane. `origin/merch` is 131 commits ahead of main and 0 behind (220 files, +25,925 lines; Chris Connors 103 commits, connors-sgr 14, Rishabh 8). The count comes from the local remote-tracking ref.

A second in-flight branch: `origin/feature/auth-central` is 24 commits ahead of main and 79 behind (`git rev-list --left-right --count origin/main...origin/feature/auth-central` gives `79 24`). The branch's `VITE_APP_ENABLE_CENTRAL_AUTH` flag (7 files there) does not appear in main’s source or workflows. The branch snapshot is separate from shipped behavior.

Further history details: the scaffold shipped plop generators and orval OpenAPI codegen (`git grep plop 57360cc05 -- package.json`), both removed on 2026-08-13 (plop in `c1b5e4044`, orval in `62025dfb4`), which is why the README still documents their scripts; seasonal theme commits landed during the lull (Thanksgiving, `93c7da404`, 2025-11-26); a Google OAuth refactor (PR #210) was reverted on 2026-01-09 (`4fc9af505`); the infra phase included an ArgoCD attempt (`ecf0b9a06`) before Flux. July 2026 has 214 non-merge commits, 122 excluding the identified bots. The earliest reachable PR merge by author date is 2024-10-08 (`4ee98297d`, PR #2); the first squash subject carrying a PR number is 2024-12-11 (`5ec1b0abf`, #31).

Old and new coexisting in the tree:

| Concern | Old | New |
|---|---|---|
| Carousel | keen-slider: `src/components/ui/slider/slider.tsx:17`, plus a type import in live code at `src/components/common/games-row/utils.ts:2` | swiper: `src/components/ui/swiper-slider/index.tsx`; plus a hand-rolled one at `src/features/landing/primitives/game-carousel/index.tsx:48-51` |
| Modals | `useDialogs` context (`src/components/common/dialogs/dailogs-context.tsx`), raw MUI Dialogs | `src/features/smart-modal-navigation/` |
| Lottie runtime | `lottie-react` (2 importing files, mocked in 16 tests) | `@lottiefiles/dotlottie-*` (10 non-test files reference it) |
| OTP input | raw `MuiOtpInput` (`src/features/auth/components/common/phone-otp.tsx:295`), `react-otp-input` (`src/features/amoe/components/amoe-content/index.tsx:2`) | `src/components/ui/otp-code-input/otp-code-input.tsx` |
| Auth guard | `ProtectedRoute` component (`src/features/auth/protected-route.tsx`) | loader (`src/app/routes/auth-loader.ts:6-27`) |
| Lint | `.eslintrc.cjs` on ESLint 8 (end of life) | no flat config yet |
| Deploy | host-directory copy in workflows | `charts/`, Flux |
| MUI majors | `@mui/material` ^5.16.7 | `@mui/icons-material` ^6.1.2 (`package.json:45`) |

---

## 4. Architecture and code quality

**Verdict: B-. Core plumbing is disciplined and consistent; the failures are at the edges: mocks in production paths, a route error element that probably renders blank, and a theme that the newest code ignores.**

### Feature structure

Features follow `api/`, `components/`, `hooks/`, store, `route.factory`, but loosely:

| Feature | api | hooks | store | route.factory | Tests / all files (tests included) |
|---|---|---|---|---|---|
| auth | Y | Y | `stores/` plus loose `auth.store.ts` | two | 21 / 146 |
| casino | Y | Y | `store/` | Y | 8 / 123 |
| shop | no (hooks hold queries) | Y | Y, plus a `lib/` | Y, not lazy | 3 / 55 |
| wallet | Y | no | no | Y | 8 / 52 |
| mfa | Y | Y | `stores/` | no | 14 / 69 |
| spinquest-cards | Y (mock-backed) | Y | no | function form | 0 / 112 |
| landing | no | Y | no | Y | 3 / 88 (`sections/`, `primitives/`, `variants/`) |

Six of 26 features have a root index module (five `.ts` and one `.tsx`), so features deep-import each other (487 matching absolute feature import lines inside `src/features`, including same-feature imports and tests). 33 non-test files in `lib`, `components`, `store`, `utils`, and `hooks` import upward from features, for example `src/lib/api/interceptors.ts:3-4`.

**Cross-feature imports and cycles:**
- **Imports into other features' internals.** 191 non-test cross-feature import lines bypass a public barrel.
- **Heaviest edges.** mfa→auth (21), affiliate→auth (15), casino→auth (13).
- **Two-way feature dependencies.** auth↔mfa, auth↔kyc, auth↔casino, shop↔wallet, and casino↔shop. For example, `src/features/auth/api/use-register.ts:4` imports the casino FTUE store.
- **Runtime import cycles.** There are 4, covering 21 files (type-only imports excluded):
  - A 10-file loop from `auth/api/use-login.ts` through kyc and the casino lobby modal into `lib/socket/index.tsx`.
  - A 5-file loop `lib/api/api-client.ts` → `gates` → `geolocation/service.ts` → `geolocation/api.ts`.
  - The casino lobby-view barrel ↔ leaderboard.
  - `components/ui/form/index.tsx` ↔ `labeled-field.tsx`.

**ESLint does not enforce any of this.** `.eslintrc.cjs:57` enables `'import/no-restricted-paths': ['error']` with no `zones`, so the rule does nothing, and `import/no-cycle` is not configured (see finding 52).

### API and data fetching

- One axios instance (`src/lib/api/api-client.ts:15`). `customInstance` (`:41`) runs each request through `executeWithGates`, which resolves server challenges (geo, MFA) and replays the request. This is the most important mechanism to understand.
- Interceptors (`src/lib/api/interceptors.ts`): Bearer token from the auth store (`:16-26`); revoked sessions call `endRevokedSession()` and throw (`:48-51`). Guard handling covers terms (`:53-62`) and 500s whose `errorMessage` is `ban`, `kyc_*`, or `break|<date>` (`:65-80`).
- No generic bearer-token refresh was found. GeoComply has a separate `/IPCheck/RefreshToken` endpoint (`src/lib/api/geolocation/api.ts:50`). Shared message helpers exist in `src/utils/errors/api-error.ts:50-74` and `handle-api-error.ts:23`; the interceptor does not normalize every error.
- Query hooks cluster in feature API and hook folders and in `src/lib/api`. There are exceptions, including `src/features/feature-flags/flags-sync.tsx:37`. Component code generally consumes hooks.
- Query keys: a `createQueryKeys` helper (`src/utils/query-keys.ts:8`) backs 10 of the 12 tracked `keys.ts` modules. Eight literal-key occurrences include repeated operations, for example `['shop-items']` at `src/features/shop/components/shop-package-page/index.tsx:138`.
- Defaults: `staleTime` 60s, `retry: false`, `refetchOnWindowFocus: false` (`src/config/react-query.ts`).

### State, routing, errors

- State split is mostly deliberate: zustand for client state, Query for server state. Four stores use `persist`: auth, UI, geolocation, and balance. 8 files call `createContext`.
- The socket provider holds a module-level singleton and writes balance straight into zustand (`src/lib/socket/index.tsx:29-47,72-74`).
- Routing: three layout groups, auth loader, 18 of 19 factory modules declare lazy routes (19 of 20 registered values), plus both lazy layouts.
- **Route errors (inferred, not run).** `errorElement: <ErrorBoundary />` at `src/app/routes/index.tsx:86` passes a wrapper around Sentry’s React boundary with no children. Router-caught errors are not thrown inside it, there is no `useRouteError` anywhere, and there are 0 `captureException` calls. Likely result: a blank page and no Sentry event when a loader throws. To confirm: throw in a loader on a dev build.
- 106 `catch` sites, 0 empty. 38 non-test `console.*` calls, one of which logs the typo `'onGeoChecki'` (`src/lib/socket/index.tsx:84`).
- **Sentry automatic capture is available when enabled.** `tracePropagationTargets: ['localhost']` and `tracesSampleRate: 1.0` (`src/lib/sentry.ts:32-33`): trace headers propagate only to localhost and the configured trace sample rate is 100% of eligible transactions. Vite disables source maps and makes the upload plugin opt-in (`vite.config.ts:45,115-126`). Verify symbolication and actual ingest before making claims about production observability.
- **The auth token is persisted to localStorage.** The zustand `persist` config partialises `user` and `authToken` (`src/features/auth/auth.store.ts:39-61`) while the axios client also sends cookies (`withCredentials: true`). This sends credentials alongside bearer auth. Which cookies the server accepts for authentication is unverified. Any same-origin injected script can read the persisted token. To confirm: whether the cookie alone could carry the session.
- The user object lives twice: in the persisted auth store and in the `authKeys.currentUser` query cache (cross-tab sync depends on the store copy).
- Env: zod schema fails fast (`src/config/env.ts:42-97`). `VERIFF_API_KEY` is a `VITE_` variable (`:55`) and therefore public; confirm it is a publishable key.

### i18n, styling, hygiene

- i18n is broadly followed (901 `t('...')` calls, 823 of them in `.tsx` files). The exception is `src/features/landing`: 9 of the 10 hardcoded JSX strings found, plus `primitives/official-rules-link/rules-text.ts`, 974 lines of English legal text with 0 `t(` calls.
- Styling is MUI-centric, with CSS imports and other styling paths (1,497 `sx={`, 850 `styled(`). About 1,240 six-digit hex literals in `.ts`/`.tsx` files sit outside `src/lib/theme` (2,045 if tests, SVG, and three-digit forms are counted).
- Type discipline: `strict: true`, 0 `@ts-ignore`, 0 `@ts-expect-error`, 0 `as any`, 16 `as unknown as`, 24 `eslint-disable` (8 of them `react-hooks/exhaustive-deps`).
- File names are uniformly kebab-case, with misspellings baked into paths: `auth/api/ues-request-email-verification-query.ts`, `components/common/dialogs/dailogs-context.tsx`, `fixtures/self-execution-duration.ts` (exclusion), `vip-club/api/user-fetch-level.ts` (`use-`).

### Largest multi-concern files

| Lines | File | Mixes |
|---|---|---|
| 974 | `src/features/landing/primitives/official-rules-link/rules-text.ts` | legal copy as a TS string |
| 821 | `src/features/spinquest-cards/api/mock-data.ts` | mock data in a production path |
| 623 | `src/features/casino/hooks/use-lobby-hero-bob.ts` | 16 `useState`, 14 `useEffect`: animation, sound, data |
| 552 | `src/components/layouts/top-bar/header/components/sub-components.tsx` | several components |
| 536 / 510 | `shop-package-modal/link-money/index.tsx`, `apple-pay/index.tsx` | payment state machine, UI, cache invalidation |
| 483 | `src/features/shop/components/checkout-payment-page/index.tsx` | checkout flow and UI |

Duplication: at least six local currency formatters exist beside the shared `src/utils/coin-format.ts`, for example `formatAmount` at `src/features/transactions/components/common/transactions-list.tsx:43`, `src/features/user-history/components/history-card.tsx:59`, `src/features/wallet/components/redeem/redemption-history-card.tsx:15`, and `redemption-submitted-modal.tsx:35`, and `formatCoins` at `src/features/casino/components/casino-ftue/components/coachmark-offer-card.tsx:23`. The shared UI layer is mostly bypassed: 104 files import `@/components/ui` against about 490 importing `@mui/material` directly (488 from the package root, 512 with subpaths). Also, 18 `mobile.tsx` siblings re-implement desktop sections (for example `landing/sections/get-the-app-band/index.tsx` and `mobile.tsx`, 141 and 142 lines).

### Does production code ship mocks? Yes.

- **Cards.** 9 non-test files import `./mock-service` with no toggle in the cards path, for example `src/features/spinquest-cards/api/use-cards-collection.ts:4`. `mock-service.ts` is a 536-line in-memory backend with simulated latency (`NETWORK_DELAY_MS = 40`, `mock-service.ts:30`); pack purchases are fake; a stale `TODO(FTUE testing)` sits above a debug constant that is already `false` (`:34-37`). Introduced in `ffebad485` (PR #440, 2026-04-10) and extended in `808491452` (PR #500). Whether a real cards backend exists is the first thing to ask.
- **Affiliate program.** `src/features/affiliate-program/api/use-funds.ts:8-14` resolves a fixture after a 3-second `setTimeout`. Other fixture paths include `use-campaigns.ts` and `user-referred-users.ts`. The mock and live campaigns hooks share a query key (see finding 38).
- **VIP.** `src/features/vip-club/api/user-fetch-level.ts:12,29` falls back to `MOCK_USER_EXP = 0` when real experience data is unavailable. This is a UI fallback.
- No MSW anywhere.

### Read these eight files first

| Path | Why |
|---|---|
| `src/app/index.tsx` | QueryClient, root boundary, router creation |
| `src/app/providers/index.tsx` | Provider order |
| `src/app/routes/index.tsx` | Layout groups, lazy loading, loaders |
| `src/config/env.ts` | Every env var and the product flag |
| `src/lib/api/api-client.ts` | Axios instance and the gate-retry loop |
| `src/lib/api/interceptors.ts` | Auth header and error-to-guard mapping |
| `src/lib/socket/index.tsx` | Real-time events into balance, modals, analytics |
| `src/features/auth/auth.store.ts` | Token source of truth |

---

## 5. Competing approaches to consolidate

**Verdict: most concerns have a dominant approach. Real duplication is in five places: colour tokens, modals, OTP inputs, carousels, and the product split.**

"Newest" is the date the most recently added file using the approach was added. Caveat: `f2311c78f` (2026-05-04, 544 files) re-added many files, so that date often means "touched by the reskin merge".

| Concern | Approach: files / occurrences (newest) | Representative | Classification |
|---|---|---|---|
| State | zustand: 27 stores, 159 hook calls (2026-10-28). Context: 8 files (2026-05-04). Query cache writes: 18 / 31. URL params: 23 / 46 (2026-10-28). Cookies: `react-cookie` and `js-cookie`, 2 importing files each. Raw storage: 6 files (2026-10-28) | `src/features/mfa/stores/turnstile-slot.store.ts:1`; `src/app/providers/referral-code-provider.tsx:2`; `src/utils/session.ts:1` | Deliberate layering; two cookie libraries and raw storage are drift |
| Styling | `sx`: 325 / 1,497. `styled`: 167 / 850. Inline `style`: 92 / 191. CSS imports: 9. Theme palette reads: 54 / 138 (newest 2026-07-18). Hex literals outside theme: about 1,242 (2026-11-04) | `src/features/landing/sections/what-is-spinquest/styles.ts:10` | `sx` plus `styled` is deliberate; hardcoded colour is drift and growing: `landing` has 214 hex literals and 0 theme reads |
| Animation | framer-motion 15 files (2026-11-04); keyframes 11; MUI transitions 6; lottie-react 2 importers (2026-07-20); dotLottie 10 (2026-07-20) | `src/features/casino/components/casino-ftue/hooks/use-lottie-intro-then-loop.ts:6` | Lottie: unfinished migration toward dotLottie. Rest: drift by author |
| Carousel | swiper 7 files (2026-05-04); keen-slider 1 runtime consumer (2024-09-26) plus a `KeenSliderOptions` type import in live `games-row/utils.ts:2`; hand-rolled 1 (2026-11-04) | see section 3 | keen-slider runtime is a dead remnant, but its types are still used by live code; the hand-rolled one is new drift |
| UI layer | `@/components/ui` primitives: 104 importing files; direct `@mui/material`: about 490 | n/a | Thin layer, mostly bypassed |
| Data fetching | hooks in `features/*/api` 71 files; in `features/*/hooks` 5; inline in `.tsx` 2; raw `fetch` 5 (assets, terms) | `src/features/feature-flags/flags-sync.tsx:37` | Deliberate, consistent |
| Forms, OTP | react-hook-form 32 files; `OtpCodeInput` 7 consumers (2026-10-28); raw `MuiOtpInput` 1 (2025-02-05); `react-otp-input` 1 (2026-07-01) | see section 3 | Unfinished migration toward `OtpCodeInput` |
| Navigation | `useNavigate` 47 files; `Link` 15; `window.location` writes in 8 files (hard resets, error recovery, and external bank links); internal `<a href>` 0 | `src/features/auth/end-revoked-session.ts:25` | Consistent |
| Modals | `useSmartModalNavigation` 16 files (2026-11-04); `useDialogs` 15 call sites, 33 importing files (2026-11-04); `responsive-modal-page-wrapper` 37 files (2026-07-08); raw MUI Dialog/Modal 13 (2026-11-04) | `src/features/landing/sections/site-footer/footer.tsx:14` | Drift: every system is still receiving new files |
| Toasts | react-toastify only, 49 files, no wrapper | `src/features/mfa/components/challenge/login-code-sent-toast.tsx:40` | One library, scattered call sites |
| Dates | dayjs 5 files; native `Date` 27 files; `Intl` 10 | `src/features/auth/components/auth-page/utils/date-of-birth.ts:1` | Drift, low risk |
| Env | `@/config/env` 21 files; direct `import.meta.env` 2 files, both `.DEV` | `src/utils/domain/is-social-casino.ts:4` | Consolidated |
| Icons | svgr `?react` 156 files; `.svg` URL imports 29; `@mui/icons-material` 17; inline JSX `<svg>` in 6 files | n/a | svgr dominant; the rest is drift |
| Product split | one build alias, product flag reads in 4 non-test files, `isSocialCasino` (always true in production: `src/utils/domain/is-social-casino.ts:11`, `return true \|\| host.endsWith('.com')`), long-lived branches | `vite.config.ts:22-34` | Unfinished migration from branches to trunk plus flag |

Outside Vite dev mode, `isSocialCasino` is always true and the sports parent redirects (`src/features/sports/route.factory.tsx:10-11`), which makes the `sports` feature and its only keen-slider consumer unreachable in production.

### Top eight consolidations

| # | Direction | Effort | Blast radius |
|---|---|---|---|
| 1 | Colour literals into theme tokens, starting with `features/landing` and the five most repeated values (`#FFFFFF` 188, `#C1C5CD` 108, `#88B6E9` 89) | L | About 268 files; visual regressions only |
| 2 | One modal system on smart-modal-navigation; retire the dialogs context and raw Dialogs | L | About 80 files; deep links, focus, back button |
| 3 | Merge `merch` behind the product or feature flag | M | 220 files; deploy workflow |
| 4 | Delete the constant `isSocialCasino` branch, the sports route, `ui/slider`, and the `keen-slider` and `vaul` dependencies | S | About 9 files, including replacing the keen-slider option types in `games-row/utils.ts`. To confirm: dev use of `SOCIAL_CASINO=false` |
| 5 | One OTP input | S | 3 to 4 files; phone verification and AMOE |
| 6 | One Lottie runtime (dotLottie) | S | 2 files plus 16 test mocks |
| 7 | One carousel (the swiper wrapper) | S | Landing only |
| 8 | Inline `style` into `sx`, and one `notify` module over react-toastify | M | 92 + 49 files; mechanical |

---

## 6. Test suite

**Verdict: C-. The tests that exist are mostly behaviour-driven and free of the usual rot, but nothing runs them automatically, 12 of 26 features have none, and the money paths are shallow.**

### Automation

The checked-in workflows run production TypeScript through `build:base` (`package.json:15`, `tsc --project tsconfig.build.json && vite build`). This config excludes unit tests, e2e, stories, and testing setup. No checked-in hook or workflow invokes Vitest or Playwright. CI lacks a separate full-project typecheck and lint job. `.husky/pre-commit` invokes `pnpm typecheck` and lint-staged. `.husky/pre-push` runs a production dependency audit.

**Local run at `5b20ce8ad` (2026-11-10):**

| Check | Result |
|---|---|
| `npx tsc --noEmit -p tsconfig.json` | Exit 0 |
| `npx eslint src` | 0 errors, 0 warnings |
| `npx vitest run` | 881 of 882 tests pass, in 106 of 107 files |

The one failure is timezone-dependent. `social-referred-user-body.test.tsx` expects `01-01-2025`, but on a US-timezone machine it renders the previous day. It passes with `TZ=UTC`. See finding 46.

The suite is healthy today, but nothing keeps it that way. Also, Storybook does not build (finding 48).

### Coverage map (test files / non-test source files)

| Area | Tests / src | Area | Tests / src |
|---|---|---|---|
| auth | 21 / 125 | spinquest-cards | 0 / 112 |
| mfa | 14 / 55 | location | 0 / 20 |
| casino | 8 / 115 | notifications | 0 / 19 |
| wallet | 8 / 44 | vault | 0 / 17 |
| affiliate-program | 4 / 66 | vip-club | 0 / 16 |
| shop | 3 / 52 | landing-promotion | 0 / 16 |
| landing | 3 / 85 | user-history | 0 / 14 |
| terms | 3 / 15 | responsible-gaming | 0 / 13 |
| kyc | 1 / 9 | sports | 0 / 11 |
| `src/lib` | 14 / 75 | amoe, language, promotions | 0 / 7 each |
| `src/components` | 8 / 155 | `src/store` | 1 / 8 |

The map counts tracked TS/TSX paths, including declarations. Its denominator is non-test files; the feature table in section 4 uses all files, tests included. Other feature rows are home 1/2, smart-modal-navigation 2/16, privacy-policy 2/4, feature-flags 3/1, and transactions 2/12. There are 107 test files and 1,159 non-test TS/TSX files, a 9.2% ratio. No runtime coverage was measured.

### High-risk surfaces

| Surface | State | Evidence |
|---|---|---|
| Shop checkout | Thin | 3 files; `checkout-flow-modal/index.test.tsx` has 5 cases, all about back-button visibility. No dedicated Apple Pay or Link Money state-machine suites located. The checkout outcome hook has behavioral tests |
| Redemption | Partial | 8 files; `redeem-page.test.tsx:109-127` asserts stubbed children echo props. No dedicated submit-mutation test was found |
| Auth | Best covered | `src/features/auth/cross-tab-sync.test.ts` (11 cases on storage events), auth store, interceptors |
| MFA and gates | Good | 14 files plus `src/lib/api/gates/*` tests (lockout, `execute-with-gates`) |
| KYC | One file, 4 cases | `use-kyc-verification.test.tsx:105-133`. Declined and resubmission events untested |
| Geolocation | Partial | Service and `api-client.test.ts:112-180` replay are tested; `src/features/location` and `src/store/geolocation.ts` are not |
| Game launch | None | No dedicated unit test file found |
| Socket and balance | Partial | No dedicated provider/store suite. `use-checkout-web-outcome.test.tsx:114-157` exercises the real balance store with a simulated socket update and asserts checkout reconciliation. |

### Quality

A 12-file sample: about 9 behaviour-driven, 3 mock-echo leaning. This is a sample, not a statistic. Behaviour example: `cross-tab-sync.test.ts:86-95` asserts the store's user after a storage event. Mock-echo example: `redeem-page.test.tsx:119-126`, which asserts props echoed back by stubbed children.

Anti-patterns: 0 `.skip`/`.only`, 0 snapshots, 0 `as any`, 0 files without `expect`, 11 `setTimeout` lines in 8 files. The structural weakness is mocking: 295 `vi.mock(` calls in 73 of the 107 test files, all module-level; `@/hooks/translation/use-translation` is mocked 37 times and `@/config/env` 24 times. No MSW setup was found. Interceptor and gate behavior have targeted tests. No live full-stack coverage was verified.

Infrastructure: config is the `test:` block in `vite.config.ts:142-157`; `src/testing` holds only `setup-tests.ts`; there are no shared render helpers or factories; coverage is istanbul with an `html` reporter and no thresholds.

### End to end

10 Playwright specs, 43 tests. Eight were last touched on 2025-05-20 or 2025-06-24, before the 2026-07 reskin and shop-as-modal rework; `cross-tab-auth-sync` (2026-05-11) and `daily-bonus` (2026-06-26) are newer. Nothing invokes them, and the `webServer` block in `playwright.config.ts:60` is commented out, so an app must already be running. The default base URL uses port 3001 and can be overridden with `PLAYWRIGHT_BASE_URL`. `e2e/utils/auth.ts:27-28` falls back to hard-coded test credentials when the env vars are unset, and `.env.test` is tracked in git (contents not read): ask whether those accounts are disposable. `login.spec.ts` and `redemption.spec.ts` predate MFA and Turnstile. Whether the old specs still pass is unverified; `shop.spec.ts` targets a checkout UI that was since rebuilt.

### Timeline

Oldest reachable additions of the 107 current test paths (without rename following): August and September 2024, one each; March 2025, one; March 2026, three; May through November 2026, 3, 12, 34, 7, 8, 29, and 8. Unit tests predate the 2026 expansion.

---

## 7. Documentation staleness

The README and testing guides contain concrete setup and automation errors.

"Last touched" below is the last commit to the file. For several docs that commit was a repo-wide sweep (the 2026-05-21 pnpm migration, the 2026-07-14 dead-code removal), so the real content is older: several baseline docs were added on 2025-03-19 (`fc7a4db20`). Testing, data-fetching, and security files have later commits.

| Doc | Last touched | Author | Assessment |
|---|---|---|---|
| `README.md` | 2026-05-21 | Rishabh | Badly stale |
| `TESTING_GUIDE.md` | 2026-05-21 | Rishabh | Automation claims conflict with the checked-in workflows |
| `docs/configuration.md` | 2025-03-19 | Nanda | Current, thin |
| `docs/version-control.md` | 2025-03-19 | Nanda | Mildly stale |
| `docs/state-management.md` | 2025-03-19 | Rishabh | Current, incomplete (3 of 7 stores) |
| `docs/styling.md` | 2025-03-19 | Rishabh | Current, thin |
| `docs/storybook.md` | 2026-05-21 | Rishabh | Current (only 7 stories exist) |
| `docs/testing.md` | 2026-05-21 | Rishabh | Mildly stale |
| `docs/data-fetching.md` | 2026-07-14 (content 2025-03-19) | Rishabh | Badly stale |
| `docs/security.md` | 2026-10-28 | Nanda | Mildly stale |
| `e2e/README.md` | 2026-05-21 | Rishabh | Mildly stale |
| `.env.example` | 2026-11-04 | Nanda | Mildly stale |
| PR template | 2025-05-27 | Rishabh | Generic |

Code under `src/` last changed 2026-11-05.

### Most misleading statements

| Statement | Correct fact |
|---|---|
| README: `pnpm gen:component`, `gen:dialog`, `openapi:local`, `openapi:prod` | No such scripts. Generators were removed in `c1b5e4044` (PR #709) |
| README tree lists `generators` and `Openapi` | Neither directory exists |
| README: served by "nginx:otel" on port 80 with the AWS CLI | `Dockerfile:69` uses `nginxinc/nginx-unprivileged:1.28.0-alpine`; `Dockerfile:78` exposes 8080; `grep -i aws Dockerfile` is empty |
| `TESTING_GUIDE.md:7,10`: branch from `release` | No `release` ref is visible in the inspected local snapshot. Deploys trigger on `main`, `cards`, `merch` |
| `docs/version-control.md`: bump commits carry `[skip ci]` | `deploy-main.yaml:99` commits without it on main |
| `docs/security.md:101` cites `deploy.yaml` | Split into three files by `62853bc3b` on 2026-11-05 |
| `docs/testing.md`: fixtures and custom renderers in `src/testing/` | The directory holds only `setup-tests.ts`. The same doc also advertises missing `test:watch` and `test:e2e:file` scripts. |
| `e2e/README.md`: `pnpm test:e2e:file`, `auth-example.spec.ts` | Neither exists |
| `docs/data-fetching.md:20,57,80,180`: samples call raw `fetch('/api/users/...')`, read `isLoading` from a mutation, use `pageParam = 0` | Typical own-backend requests go through `customInstance` (`src/lib/api/api-client.ts:41`), and the mutation and infinite-query idioms are React Query v4, while the repo is on v5 |
| `README.md:22`: "Node.js (>= 20.x)" | `.nvmrc` is v24.10.0 and the Dockerfile uses `node:24-alpine` |
| `TESTING_GUIDE.md:193-199,248`: checks "must pass", with a note to set up CI to run them | The wording is aspirational. CI runs dependency auditing and production TypeScript compilation. No checked-in CI step runs tests, lint, or a separate full-project typecheck. |
| `.env.example` lists `VITE_APP_SENTRY_DSN` twice | Verified with `grep -oE "^VITE_APP_[A-Z_]+" .env.example \| sort \| uniq -d` |
| `.env.example` as a setup template | It omits required `VITE_APP_PRODUCT` and `VITE_APP_INTERCOM_APP_ID` (`src/config/env.ts:48,58`). The usual dev/build scripts inject the product. An unset Intercom app ID still fails runtime schema validation. |

AI-instruction files: none tracked on main, by design. `.gitignore:63-64` ignores `AGENTS.md` and `CLAUDE.md` (added 2026-05-08 in `6ee3d749ba`), so any such files are local. `src/store/feature-flags.ts:7` and `src/lib/posthog-device.ts:6` cite `.claude/rules/frontend/feature-flags.md`, which was not found in reachable Git history. `origin/chore/add-claude-md` only adds a `.gitignore` line (`1bb7cff9a`). See section 8 for AI tooling signals. `.cursor` rules existed from 2025-05-07 and were removed in `8be265e91` (2026-08-13).

The PR template has five generic headings; whether merged PR bodies use it was not checked. There is no CHANGELOG, CONTRIBUTING, CODEOWNERS, or ADR folder.

**Still worth reading:** `docs/security.md` for pnpm supply-chain policy, with stale deploy workflow names and CI claims, and `e2e/README.md` for e2e setup, with stale script and example paths. Do not learn data fetching from `docs/data-fetching.md`: its code samples teach patterns the repo does not use. For data fetching, read `src/features/casino/api/keys.ts` and a neighbouring hook instead.

---

## 8. Contributors

The three leading contributor groups account for 1,350 of 1,452 non-merge commits after excluding identified bots (93%). The Helm chart last changed on main on 2026-03-24. Repository history establishes contribution patterns and dates. Titles, employment, ownership, and availability need separate evidence.

Identities were merged from `git log main --format='%an|%ae'`. Assessments rest on a handful of sampled commits per person and describe the commits, not the people. Line counts depend on the exclusion filter: Rishabh's deletions range from about 67,000 to 79,000 across reasonable filters.

| Person (git identities) | Non-merge | Merges | +/- lines (no lockfiles, assets) | First / last | Main areas | Via PR (upper bound) | Conventional | Test-touching 2024 / 2025 / 2026 |
|---|---|---|---|---|---|---|---|---|
| Rishabh Rawat (`Ris`, `risrawat90`, `Rishabh Rawat`) | 796 | 171 | +129,110 / -78,986 | 2024-08-15 / 2026-11-05 | components, lib, auth, casino, root config | 55% | 92% | 1% / 1% / 27% |
| Nanda (`Nanda`, `Nandakr145`) | 328 | 23 | +82,606 / -33,389 | 2024-08-23 / 2026-11-04 | components, casino, auth, shop | 86% | 91% | 0% / 1% / 28% |
| Prashant Singh (`Prashant Singh`, `inboxpk222`) | 226 | 45 | +41,763 / -23,769 | 2024-10-02 / 2026-11-05 | components, casino, wallet, shop | 85% | 90% | 0% / 1% / 11% |
| Sawyer Charles | 36 | 1 | +3,463 / -1,181 | 2024-09-06 / 2026-10-14 | lib, `.github`, auth | 67% | 67% | 0% / 0% / 27% |
| Luke Greenleaf (two spellings) | 35 | 21 | +1,607 / -762 | 2026-01-09 / 2026-03-26 | `.github`, `charts` | 97% | 100% | 0 |
| gishmel | 16 | 0 | +275 / -211 | 2026-02-13 / 2026-03-02 | `.github`, `charts` | 100% | 100% | 0 |
| Stanislaw Gebala | 3 | 0 | +38 / -3 | 2026-10-01 / 2026-10-14 | cards CI | 100% | 100% | 0 |

"Via PR" counts subjects containing `#NNN` anywhere, or commits off the first-parent line. Local merges also pass that test, so it overstates review, mostly for Rishabh (125 local merges, 29 titled "fix: merge conflicts"). Git does not record approvers.

**AI tooling signals.** Git records AI use only where a commit keeps a co-author trailer, so no authorship percentage is measurable.

- **Trailers on main:** 9 commits, under 1% of the 1,452. Claude: Stanislaw 3, Sawyer 2, and the cards merge `8886b3b5d`. Copilot: Prashant 2 (Copilot Autofix) and Sawyer 1.
- **Trailers across all local refs:** 150 commits carry Claude trailers, all dated 2026-09 to 2026-11, and 133 of them are reachable from neither `main` nor `origin/merch`. Stanislaw Gebala has 103 (two identities) and Nilson Nascimento 29. There are no Cursor or Codex trailers.
- **Untracked agent files:** `.gitignore:63-64` ignores `AGENTS.md` and `CLAUDE.md`, and two source comments cite an uncommitted `.claude/rules` file (section 7). Cursor rules were tracked from 2025-05-07 to 2026-08-13.
- **Style shift (a proxy, not proof):** among lines added to `src` TS/TSX, comment lines rose from 1.5% in 2024 H2 to 7.1% in 2026 H2, and em-dash lines from 0.04 to 7.44 per thousand, for all three core authors. Commit bodies over 200 characters rose from 0% to 47% of commits.
- **Reading:** code from 2024 and 2025 looks human-first. From about May 2026 the core team's output looks heavily LLM-assisted and deliberately untracked.

### Line ownership at HEAD

`git blame -w` over every tracked TS/TSX file in `src/` (115,495 lines), with identities merged by a local mailmap:

| Author | Lines | Share |
|---|---:|---:|
| Rishabh Rawat | 54,751 | 47% |
| Nanda | 30,763 | 27% |
| Prashant Singh | 23,372 | 20% |
| Sawyer Charles | 2,523 | 2% |
| Lucas Bittencurt | 2,039 | 2% (inflated: the revert-and-reland of PR #499 re-attributes `src/lib` lines) |
| Vishal | 1,978 | 2% (one commit, `f7bcd77da`) |
| Everyone else | 70 | <0.1% |

Luke Greenleaf and gishmel own 0 lines in `src/`; their work is in `.github/` and `charts/`.

**Per-area ownership (top owner and share):**

| Owner | Areas |
|---|---|
| Rishabh | components (68%), auth (70%), casino (45%), lib (46%), wallet (70%), vault (86%), vip-club (92%) |
| Nanda | mfa (100%), spinquest-cards (45%), sports (88%) |
| Prashant | landing (99%) |
| Lucas Bittencurt | feature-flags (100%) |

Single-owner areas are the clearest bus-factor risks: mfa (8.4k lines), landing (8.7k) and feature-flags.

### Identity anomalies (ask, do not assume)

Git shows these patterns. It cannot show why. Possible explanations include a shared machine, a copied git config, rebases done on someone else's machine, or one person using two accounts.

- **Shared committer identity.** 675 commits across all refs, from 2024-10-02 to 2026-11-06, have the committer `inboxpk222@gmail.com <risrawat90@gmail.com>`. That is Prashant's handle as the name and Rishabh's email.
  - Most are Prashant's own commits: 382 as `inboxpk222` and 183 as `Prashant Singh`.
  - 38 are Rishabh's (noreply identity) and 11 are Nanda's.
  - 8 commits also use this pair as the author.
- **Crossed GitHub identity on merges.** Three merges on 2026-11-04 (`88ec15076`, `2b7b000f1`, `710530b57`, PRs #854 to #856) have the author `connors-sgr <85271171+risrawat90@users.noreply.github.com>`. The display name is Chris Connors's, but the noreply email carries Rishabh's GitHub user ID.
- **Bot authorship used for a human commit.** `aa821e72a` (2026-03-05, bottom-bar restyle, 8 files, not on main) has the author `GitHub Actions` and the committer Nandakr145. This is harmless here, but it shows that commit authorship is spoofable: no commits are signed except GitHub web merges (592 of 2,125 carry a GitHub signature).
- **Unconfigured machine.** `Geek <geek@Geeks-MacBook-Pro.local>` made 11 branch-only commits in October 2026 (cards tournaments, FTUE, "dummy commit to trigger CI").

**Location signal.** 1,359 of the 1,452 identified-human non-merge commits on main carry a `+0530` timezone (India). The remainder are mostly US timezones from the infrastructure and later contributors.

### Major contributors

- **Rishabh Rawat: largest recorded contributor and frequent integrator.** Top author in every `src` area and in root config (115 of 167 commits there); designed the current CI (`62853bc3b`). Early work shows sound TypeScript judgement (`adc26344a`, 2024-08-16, turned `no-explicit-any` to `error` and typed the API client) alongside weak hygiene: about 45% of commits carry no PR marker. Recent work is stronger: `1fca92ee7` (PR #676) has a structured body tracing behaviour per payment method.
- **Nanda: feature contributions in UI and components.** Early commits carry inline styles and stray `console.log` (`edad59392`, 2024-08-23). Recent work consolidates: `267e994eb` (PR #687) merges four modal-sheet copies into one helper with seven tests, and `303f1bc6a` removes 1,305 lines of unreachable code and assets. Their test-touching share went from 0% to 28%.
- **Prashant Singh: feature developer, wallet, casino, shop.** Vaguest early subjects of the three (`336fd1103` "fix: responsive fix"). Recent `739c1f758` (PR #739) rewrites OTP tests around cooldown behaviour, while carrying over an existing hardcoded `#88B6E9`. Lowest 2026 test share of the core three (11%). Author of the newest feature, `landing` (`38ccbb17e`).
- **Sawyer Charles: integrations and compliance, low volume, long span.** Terms re-acceptance (`1de2fd52f`), geolocation polling with correct interval cleanup (`7eb0b3273`), Intercom JWT sessions with a 314-line test (`6ae669977`). Some PRs bundle unrelated changes (PR #749 rewrote the lockfile for a minor bump).
- **Luke Greenleaf and gishmel: infrastructure contributors in the observed history.** Helm chart with sealed-secret template (`3bab311b4`), PR environment manager (`71ebcdc1d`).

### Minor contributors

| Person | Note |
|---|---|
| Chris Connors (also `connors-sgr`) | 117 commits on `origin/merch` including merges (90 non-merge), since 2026-09-28. Active, but not yet on main |
| Nilson Nascimento | No commits on main. 29 commits with Claude co-author trailers on unmerged branches, 2026-09 to 2026-11 |
| AdityaVerma10 | 3 commits, 2024-08-22 to 2024-08-23. No later main commit observed |
| rahul (`agxiata.com`) | 1 commit, 2024-08-16. Company domain; an agency link to the core team is unverified |
| Rad Peev (`gohyber.com`, agency domain) | 1 commit, socket reconnect fix `6d3917596`, 2025-03-14 |
| Piotr Kuczynski (`toptal.com`, freelancer platform) | 1 commit `05f74edc9`, 2025-07-01 |
| Vishal | Mobile payment webview `f7bcd77da`, 2026-05-22 |
| Chris Danek | 2026-06-01 hardening: pinned Actions to SHAs (`9e383b3d2`); moved a hardcoded Sentry auth token to env (`a3bde29b9`). That token remains in git history; ask whether it was rotated |
| Lucas Bittencurt | PostHog identity fix: pushed to main, reverted, relanded via PR #499 (2026-06-25) |

### Recent activity in local refs (as of 2026-11-09)

- **Recent contributors** (commits since 2026-09-14): Nanda 22, Rishabh 14, Prashant 13, Sawyer 6, Stanislaw 3; Chris Connors on merch.
- **Earlier last observed contributions:** Luke (last 2026-03-26), gishmel (2026-03-02), AdityaVerma10, rahul, Rad Peev, Piotr; one-off contributors Vishal, Chris Danek, Lucas (4 to 6 months silent).

### Team dynamics

Git activity is concentrated in root build configuration and charts, with no checked-in CODEOWNERS. A numeric bus factor or current maintainer assignment would require team confirmation.

| Half-year | Non-merge commits, excluding identified bots | Terminal PR number in subject | Test-touching commits |
|---|---:|---:|---:|
| 2024 H2 | 570 | 1 | 3 |
| 2025 H1 | 422 | 90 | 5 |
| 2025 H2 | 96 | 57 | 0 |
| 2026 H1 | 162 | 75 | 7 |
| 2026 H2 to snapshot | 202 | 199 | 68 |

Method: reachable main, author dates, excluding GitHub Actions and Dependabot. A terminal `(#NNN)` is a subject marker. First-parent ancestry and commit subject cannot establish direct pushes, PR review, or approvers. Test-touching means a changed `.test.` or `.spec.` file and does not measure coverage. The late-2026 test-touching share is 68/202 (34%). Rishabh's 796 non-merge commits represent 55% of this identified-human denominator.

---

## 9. Findings and fixes

Each finding states the problem, the proposed fix, and the value of fixing it. Fixes are directions, not patches: check the "To confirm" column before acting. Every location was re-read at `5b20ce8ad`; nothing here was reproduced at runtime.

- **Priority.** P1: security, money, or release-safety exposure; verify first. P2: a real defect or risk with bounded impact. P3: hygiene.
- **Effort.** S: under a day. M: a few days. L: a week or more.
- **Numbering.** Finding numbers are stable across revisions, so they are not in priority order. Numbers 30, 31, and 32 are retired (see the end of this section).

### P1: verify first

| # | Where | Problem | Fix | Value | Effort | To confirm |
|---|---|---|---|---|---|---|
| 35 | `.github/workflows/deploy-main.yaml:59,77`, `deploy-cards.yaml:80`, `deploy-merch.yaml:49`; `src/config/env.ts:21,35`; `charts/client/values.yaml:137` | **Confirmed at runtime (rev 5).** The Veriff shared secret is written to `.env` as a `VITE_APP_` variable. `env.ts` spreads `import.meta.env`, so Vite inlines every prefixed value into the bundle. A scratch build with a canary value produced `VITE_APP_VERIFF_SHARED_SECRET_KEY:"<canary>"` as a literal in two `dist/assets/*.js` files. Per central-tech `drafts/legacy-parity-compliance.md:140`, this key signs the Backend's outbound Veriff calls (webhooks use the separate master secret). A visitor holding it plus the public API key can make signed Veriff API calls as SpinQuest, which likely includes reading KYC decisions. **A fix exists and was never merged:** `71c52386d` (Rishabh, 2026-05-26) sits only on `origin/feat/social-signup-fixes`. | Land or redo `71c52386d`: drop the three `echo` lines and the values.yaml entry, and read named keys in `env.ts` instead of spreading. Rotate the secret. | A server-side signing secret stops being downloadable by any visitor. | S | Whether the repo secret is the production Veriff integration or a dev one. Grep a deployed `main.dev` bundle for the key name only. |
| 43 | `src/features/auth/hooks/use-login-form.ts:198-202`; `src/app/routes/root-loader.ts:41-46`; `register-flow.tsx:272-276`; `src/lib/analytics.ts:10,28` | Every login, registration and root load pushes the full `User` object to the GTM dataLayer, and login also pushes the JWT signature (`login_session`). The `User` object holds email, name, DOB, phone, state, KYC session ID and status, ban, and payment-provider IDs. `analytics.ts` strips these keys for PostHog only; its own TODO says they should not go to the dataLayer either. Any tag in container `GTM-MGDSQLNX`, including ones marketing adds later, can read them. | Push an opaque `user_id` only. Apply the PostHog filter to the dataLayer too. | PII and KYC identifiers stop flowing to third-party tags, and the leaked KYC session IDs stop feeding the risk in finding 35. | S | Which tags and triggers in the container read the dataLayer; whether a DPA covers them. |
| 44 | Git history: `vite.config.ts`, added `3089b840c`/`25d76ab25` (2024-11-29), removed `a3bde29b9` (2026-06-01) | A Sentry org auth token (`sntrys_` prefix, 188 characters) was hard-coded for 18 months and remains readable in `main`'s history. Neither the commit message nor central-tech records a rotation. | Revoke it in Sentry if it is still active. History rewriting is optional once it is revoked. | Anyone with a clone (contractors, forks, laptops) loses the ability to act on the Sentry org. | S | Sentry → Auth Tokens: is the token active, and what are its scopes. |
| 3 | `.github/workflows/` | No workflow runs unit tests, e2e, lint, or a full-project typecheck. The only compile is the production build, which excludes test files. The version-bump step itself commits with `--no-verify`. | Add a PR job that runs the unit tests (with `TZ` pinned), lint, and `pnpm typecheck`. | Regressions and type errors in tests are caught before merge instead of on one developer's machine. | S | Answered in rev 5: the suite runs in about 16 s and passes except one timezone-dependent test (section 6). Still to confirm: which status checks branch protection requires. |
| 4 | `src/app/routes/index.tsx:86` | `errorElement` is a Sentry boundary rendered with no children, and nothing calls `useRouteError`. A loader or route error likely renders a blank page and reports nothing (inferred, not run). | Add a route error component that reads `useRouteError`, renders a fallback, and reports to Sentry. | Users get a recoverable error screen and the team sees the failure. | S | Throw in a loader on a dev build. |
| 6 | `src/features/spinquest-cards/api/use-cards-collection.ts:4` and 8 more hooks | Nine hooks import `./mock-service`, a 536-line in-memory backend, with no toggle. Pack purchases in the cards build are simulated. | Wire the real API, or gate the mock behind an explicit flag that cannot be on in production. | The cards product cannot ship with fake purchases and collections. | M | Whether a cards API exists. |
| 27 | `src/features/auth/auth.store.ts:39-61` | The bearer token is persisted to localStorage, where any script on the origin can read it. The axios client also sends cookies. Rev 5 found three aggravating factors:<br>• **The token never expires.** Backend `generateUserToken` signs it with no `expiresIn` (central-tech `the-legacy-session.md` records the same).<br>• **Logout does not revoke it.** `use-logout.ts` makes no server call.<br>• **No CSP, and five third-party script sources.** Apple Pay, GeoComply, `geotoken.js` (finding 45), GTM, and the Intercom/PostHog/Sentry SDKs all share the origin, and none uses SRI.<br>So one malicious tag or compromised script yields a permanent account takeover. | Raise it with the backend owners and move to cookie-only sessions if the server supports it. Do not change it unilaterally: cross-tab sync reads this storage. | An injected or compromised third-party script can no longer exfiltrate a session token. | M | Whether the cookie alone can carry the session. |

### P2: real defects with bounded impact

| # | Where | Problem | Fix | Value | Effort | To confirm |
|---|---|---|---|---|---|---|
| 1 | `vite.config.ts:59-65` | **Measured (rev 5).** `manualChunks` returns `vendor` or `core` for every module, so lazily imported routes are merged into `core`. The build emits exactly 2 JS files: 1.87 MB and 2.91 MB raw, about 1.49 MB gzip combined, all downloaded on first load. | Return `undefined` for app code and group only vendors. | Route-level code splitting takes effect, which shrinks the initial download. | S | Rebuild after the change and compare against the 2-file baseline. |
| 2 | `src/app/index.tsx:21`; `src/hooks/translation/use-translation.ts:26` | The router is memoised on `t`, but `tWithFallback` is a new function on every render, so the memo never holds and the router is recreated whenever `App` re-renders. | Give the translation function a stable identity, or create the router outside render. | Router state is not discarded and loaders are not re-run on a language or namespace change. The frequency is unmeasured. | S | How often `App` re-renders in practice. |
| 5 | `src/lib/socket/index.tsx:95,104-111`; `src/features/casino/components/leaderboard/recentwins-socket-provider.tsx:61` | `socket.on('reconnect', ...)` listens for an event the Manager emits, not the socket, so it likely never fires. `socket.on('error', ...)` at `:97` has the same problem: v4 reports connection failures as `connect_error`. Cleanup calls `socket.off(event)` with no handler, which removes every listener for that event. [Socket.IO client docs](https://socket.io/docs/v4/client-socket-instance/) | Drop the `reconnect` listener (the `connect` handler already runs on reconnection) and pass the handler to each `off`. | Dead code goes, and one provider's cleanup cannot silently unsubscribe a future second listener. | S | Force a reconnect; check reauthentication and room resubscription. |
| 7 | `src/features/affiliate-program/api/use-funds.ts:8-14` | The affiliate funds hook resolves a fixture after a 3-second `setTimeout`. `use-campaigns.ts` does the same. | Wire the API or hide the screen. | Users stop seeing placeholder financial data presented as real. | S | Product intent. |
| 9 | `src/components/common/games-row/game-item.tsx:90,98,106` | Three game-tile branches are clickable `<Stack>` elements with no role, tab stop, or key handler. | Render a button or link. | Keyboard and screen-reader users can launch games. | S | Focus, Enter, and Space behaviour. |
| 13 | `src/features/casino/hooks/use-lobby-hero-bob.ts:74` | `useBalanceStore()` is called without a selector, so the lobby hero re-renders on every socket balance push. | Select only the two actions it uses. | Fewer re-renders of a 623-line animation hook during play. Unmeasured. | S | React profiler during a balance push. |
| 14 | `src/features/shop/hooks/use-shop.ts:52-56` | Purchase-status polling stops only on a terminal status. With the global `retry: false` it keeps polling through errors until unmount. | Add an error budget or backoff. | Request volume is bounded during an outage and the user gets a clear failure state. | S | Intended behaviour on persistent server errors. |
| 15 | `src/features/spinquest-cards/components/store-page/purchase-tab/index.tsx:65` | `(pack.spinCoinsBack \|\| 0) * 100` converts with floating-point arithmetic and can yield fractional cents. | Use the existing `toCentsFromCoin` (`src/utils/coin-format.ts:42`). | Amounts on a money path are exact and follow one conversion rule. | S | None. |
| 16 | `redeem-page.tsx:31`, `verification-checks.tsx:10`, `new-redemption-modal/hooks/use-redemption-amount.ts:11` | `const MIN_REDEEM_AMOUNT = 50;` is defined three times. | One constant, ideally supplied by the server. | The redemption minimum cannot drift between screens. | S | Whether the backend exposes the limit. |
| 21 | `src/features/auth/session-revoked-notice.ts:4,8,9` | `sessionStorage` is used unguarded, and `endRevokedSession` calls it before `resetAuth()`. If storage throws, the revoked session is never cleared. | Guard it as `src/features/mfa/prompt-seen.ts:17-18` does. | A revoked session is always ended, even when storage is blocked. | S | None. |
| 26 | `src/lib/sentry.ts:32-33` | `tracePropagationTargets` is `['localhost']`, so no trace headers reach the real API. `tracesSampleRate` is 1.0. | Set the propagation target to the API origin and choose a production sample rate. | Frontend traces link to backend traces, and quota is not spent on sampling every transaction. | S | Whether the API accepts the trace headers, current event volume, and symbolication. |
| 34 | `e2e/utils/auth.ts:27-28` | Fallback credentials are hard-coded in a tracked file. | Require the environment variables and fail fast without them. | No credentials in git and no accidental runs against a shared account. | S | Whether the accounts are test-only; rotate if not. |
| 36 | `Dockerfile:75`; `default.conf`; `charts/client/values.yaml:104,112`; `docker-compose.yaml` | The image ships `default.conf`, which has no `/health` route, so `try_files` answers the chart's probes with `index.html` and a 200. It also sets no security headers (no CSP, HSTS, `frame-ancestors`/X-Frame-Options, nosniff, Referrer-Policy) and no gzip. The health route, gzip and three of those headers all live in the unused `nginx.conf`. Port drift: `default.conf` listens on 8080, while `docker-compose.yaml` maps 3000 and the chart's `containerPort` is 80. | Merge everything into one config: `/health`, gzip, and the headers including `frame-ancestors`. Align the ports. Delete the unused file. | Probes become meaningful, purchase, redeem and MFA screens can no longer be framed for clickjacking, and `docker compose up` works. | S | Probe the built image; `curl -I` each origin to see whether Cloudflare or the ingress already adds the headers. |
| 45 | `public/geotoken.js`; `index.html:84` | A 160 KB javascript-obfuscator file of unknown provenance runs same-origin on every page, with access to `localStorage['auth']`. Sawyer Charles added it in `ef2729a0b` (2026-01-30, PR #391); it defines `window._sqlcollect`, which `geolocation/service.ts` calls. No vendor name, version or integrity record is kept. | Record the vendor and version, or load it from the vendor's versioned URL with SRI. Watch its network egress. | The team can say what this script collects and where it sends it. | S | Ask the PR #391 author for the source; run it and log its requests. |
| 46 | `src/features/affiliate-program/components/referred-users/components/social-referred-user-body.test.tsx:80` | The only failing unit test fails because of the machine's timezone. The date renders a day early west of UTC. | Pin `TZ` in the Vitest config, or make the fixture timezone-neutral. | The suite gives the same answer on every machine, which finding 3's CI job needs. | S | Whether `formatDate` is meant to show local or UTC dates. |
| 47 | `.gitignore:44` | `**/__tests__/` is ignored. The 8 existing files there are tracked, but any new test placed in a `__tests__` folder is silently left out of commits. | Remove the line. | New tests reach the repo. | S | `git check-ignore -v src/x/__tests__/a.test.ts`. |
| 48 | `.storybook/preview.tsx:6`; `.storybook/main.ts:9` | Storybook cannot build: it imports `../src/app/app-provider`, which does not exist, and uses `@storybook/addon-docs`, which is not declared. | Point the import at `src/app/providers` and declare the addon, or remove Storybook. | The 7 stories, and `docs/storybook.md`, describe something that runs. | S | `pnpm storybook:build`. |
| 49 | `pnpm-workspace.yaml` (`trustPolicy: no-downgrade`); `package.json` `packageManager: pnpm@10.34.5` | `pnpm audit` and `pnpm outdated` fail locally with "High-risk trust downgrade for pnpm@10.34.5". The `security.yaml` audit gate and the pre-push hook run the same command. | Pin a pnpm release that passes the trust policy, or vet and allowlist this one. | The supply-chain gate described in `docs/security.md` actually runs. | S | Recent `security.yaml` run logs: is the job green, failing, or skipped. |
| 37 | `.github/workflows/deploy-main.yaml:103-110` (same pattern in cards and merch) | The deploy deletes the live asset directory, then copies the new build in place. During the copy the site is partly missing, clients on the old build fail to load lazy chunks, and there is no rollback. | Copy to a versioned directory, switch a symlink, and keep the previous release. | No broken window on deploy, and rollback is one step. | S | Whether the directory is served directly, and whether this lane is dev or production. |
| 38 | `src/features/affiliate-program/api/use-campaigns.ts:20`; `use-social-campaigns.ts:13` | A fixture-backed hook and a server-backed hook share `affiliateProgramKeys.campaigns`, so whichever resolves first is served to both components. | Give each dataset its own key and review the mutation invalidations. | Each screen gets its own data shape, and fixture data cannot render in the live list. | S | Mount both consumers with a warm QueryClient. |
| 39 | `src/features/auth/cross-tab-sync.ts:42-56`; `auth-identity-sync.ts:64-69`; `src/features/wallet/api/use-redemption.ts:40-42` | A direct switch from account A to account B in another tab rehydrates without a reload. Server flags are cleared only on logout, and wallet query keys are not scoped to the user, so B's tab may show A's cached data. Static candidate, not reproduced. | Reload, or clear the query cache and flags, on any change of user id, not only on logout. | One account's wallet data and flags are never shown to another. | S | Reproduce with two tabs and populated caches; check request lifetimes on the shared socket. |
| 40 | `docs/security.md:138`; `src/lib/api/contact/types.ts:27-36` | A Zod advisory is suppressed on the grounds that the repo has no array schemas, but `socialLinks` is an uncapped `z.array`. | Correct the rationale and cap the array length. | The suppression rests on a true statement, and the one array input is bounded. | S | Affected versions, and whether the input crosses a trust boundary. |
| 41 | Last 60 non-merge commits on main | Eight of nine `fix`-prefixed commits that touch source have no test change in the same commit (ten of eleven if unconventional "Fix" subjects are counted). Several are copy or CSS fixes where no test is expected; `109a45516` (iframe scrolling) and `4eda2d724` (promotion currency format) are behavioural. | Ask for a regression test on behavioural fixes, through the PR template or review. | Fixed bugs stay fixed. | S | Whether existing tests already cover the two behavioural examples. |
| 42 | `src/features/shop/components/checkout-payment-page/index.tsx:117-137` | Standalone checkout receives `sessionToken` and `paymentNonce` in the URL. The page strips them before paint, but the initial request has already carried them to the server and anything that logs URLs. | Prefer a handoff that keeps credentials out of URLs, if the issuance contract permits it. | Payment-authorising values stay out of access logs, telemetry, and analytics. | M | Token lifetime and single-use behaviour; what records the original URL. |

### P3: hygiene

| # | Where | Problem | Fix | Value | Effort | To confirm |
|---|---|---|---|---|---|---|
| 8 | `src/components/ui/form/index.tsx:249,260,291` | `FormPasswordInput` declares icon components inside its render function, and its toggle buttons lack `aria-label`. The component has no consumers in `src`. | Delete it, or inline the JSX and label the buttons before anyone reuses it. | Less dead code, and a future consumer does not inherit a remount or accessibility defect. | S | That `origin/merch` does not use it. |
| 10 | `src/features/affiliate-program/components/campaigns/components/social-campaigns.tsx:73-74` | Campaign accordions use `key={index}`, and the mapped data falls back to a constant id of `'1'`. | Key by a real unique id and remove the constant fallback. | Accordion state stays attached to the right campaign when the list changes. | S | Whether the API always returns ids. |
| 11 | 11 files, for example `src/utils/sort-by.ts:1` | Default and named imports from CommonJS `lodash` (7 and 4 files) pull in the whole library for seven functions. | Use per-method imports, as `popover.tsx` already does with `lodash/isNil`. | A smaller vendor chunk. The size is unmeasured. | S | Bundle analyser before and after. |
| 12 | `package.json:49,53,64,70,87` | `@mui/x-date-pickers`, `aerosync-web-sdk`, `vaul`, `react-device-detect`, and `material-ui-popup-state` have no imports anywhere in the repo. | Remove them. | A smaller install and fewer audit alerts. | S | That AeroSync is not loaded another way (no loader was found); re-check on `origin/merch`. |
| 17 | `src/features/casino/hooks/use-bob-sounds.ts:65-71` | Five `document` listeners added to unlock audio are never removed. | Remove them after the first unlock. | No handler keeps running on every click and key press. | S | None. |
| 18 | `src/lib/api/geolocation/service.ts:214` | `console.log` prints the IP-check result in production. It is one of 38 non-test console calls. | Route through a dev-gated logger. | Geolocation status is not exposed in user consoles. | S | None. |
| 19 | `src/features/location/components/geocomply-hints/geocompy-hints-dialog.tsx:182` | `dangerouslySetInnerHTML` renders hint text with no sanitiser in the repo. The only caller is commented out. | Delete the dialog, or sanitise before re-enabling it. | A latent XSS sink is removed. | S | None. |
| 20 | `src/main.tsx:16` | The Google Tag Manager container id is hard-coded, so every environment that runs it reports to one container. | Move it to environment configuration. | Dev and staging traffic stay out of production analytics. | S | Which deployed environments execute it. |
| 22 | `.lintstagedrc.json` | lint-staged runs `eslint --fix` and then `eslint` on every staged file, on top of a full typecheck per commit. | Drop the second run. | Faster commits. | S | None. |
| 23 | `pnpm.json` | A root `pnpm.json` holds overrides that differ from `package.json` `pnpm.overrides`. Nothing reads it, and the lockfile follows `package.json`. | Delete it. | One source of truth for security overrides. | S | `pnpm why form-data`. |
| 24 | `package.json:45`; `tsconfig.json:13` | `@mui/icons-material` is on ^6 while `@mui/material` is on ^5. `moduleResolution` is `Node`. | Align the MUI majors and move to `Bundler`. | No peer mismatch, and type resolution matches what Vite does. | S | None. |
| 25 | `.env.example`; `src/utils/domain/is-social-casino.ts:11` | The template omits the required `VITE_APP_PRODUCT` and `VITE_APP_INTERCOM_APP_ID`, so a fresh copy fails boot validation. `isSocialCasino` returns `true \|\| ...`. | Fix the template and delete the constant branch. | New joiners boot on the first try, and a dead branch is gone. | S | Dev use of `SOCIAL_CASINO=false`. |
| 28 | `src/app/providers/index.tsx:61` | `HelmetProvider` is mounted, but no `<Helmet>` exists in `src`. | Add per-route titles, or remove the provider and the dependency. | Either real page titles or one fewer dependency. | S | None. |
| 29 | `src/features/casino/components/casino-ftue/hooks/use-ftue-target-rects.ts:66` | The tour re-measures its targets on a 500 ms interval while it is open. | Use `ResizeObserver`. | No timer polling layout. Minor. | S | None. |
| 33 | `package.json:22,32` | `ts:check` and `typecheck` run the same compile with the flags in a different order. | Keep one. | No doubt about which script is canonical. | S | None. |
| 50 | knip@5 inventory (rev 5) | Dead code beyond findings 8, 12 and 28:<br>• **39 unused files after false positives.** Clusters: `spinquest-cards` `cards-ftue/**` (14), `store-page/**` (4), `cards-hero-cta` (3), 7 `tournaments-page` subcomponents, `crypto-pay/index.tsx` (caller commented out), `responsible-gaming/components/policy/index.tsx`.<br>• **Unused exports.** 148 exports and 110 exported types; 19 re-exports in `smart-modal-navigation` alone.<br>• **Dead assets.** 33 assets (about 2 MB) are referenced only from dead files; `public/home.html` and `public/icons/visibility.svg` are referenced nowhere.<br>• **Undeclared tools.** `commitizen` (`pnpm commit`) and `@storybook/addon-docs`.<br>Keep `landing/variants/variant-1/*` until the giveaway ends on Dec 31 (`landing-page.tsx:6-10`). | Delete the clusters, then add knip to CI with a `knip.json` that declares the Vite alias and `public/geotoken.js`. | Fewer files to read and a smaller repo. | M | `tsc` and a build after removal; re-check `origin/merch`. |
| 51 | `src/assets/images/tournaments/*.png`, `icons/sq-card-character.png` | Five source PNGs are 2.2 to 3.3 MB each. `vite-plugin-minipic` converts them at build time, so the repo carries the weight. | Commit WebP sources. | Faster clones. Minor. | S | `dist` size before and after. |
| 52 | `.eslintrc.cjs:57` | `import/no-restricted-paths` has no `zones`, and `import/no-cycle` is off, so the layering in `docs/` is not enforced (section 4). | Add zones (shared layers must not import features; features import each other through barrels) and `import/no-cycle`. | The 4 cycles and 191 deep cross-feature imports stop growing. | M | Run once in warn mode to size the backlog. |
| 53 | `src/features/casino/components/game/index.tsx:145-156`; `src/features/shop/components/shop-iframe-dialog.tsx:193,272` | The game iframe has no `sandbox` and takes its `allow` list from the server. The payment iframe accepts `COPY_TO_CLIPBOARD` from any page loaded inside it, including third-party provider pages (outcome messages are origin-checked; clipboard messages are only source-checked), and it grants `clipboard-read`. | Hard-code the game `allow` list and trial a sandbox. Origin-check clipboard messages and drop `clipboard-read`. | A provider page cannot overwrite the player's clipboard or receive permissions it was not meant to have. | S | Test sandbox flags against each game provider. |
| 54 | Remote branches | 926 remote branches: 517 have had no commit in over 6 months, 162 are merged into `origin/main`, and 159 are both. Only 2 tags exist, against version 0.0.419. `origin/cards-staging` is 82 behind and 135 ahead of main. | Prune the 159 stale merged branches, review the rest, and tag releases from the bump workflow. | Branch lists become readable, and every deployed build has a tag. | S | Whether any automation reads old branches. |
| 55 | Commit signing | Only GitHub web merges are signed, and authorship is demonstrably spoofable (section 8, `aa821e72a`). | Require signed commits on `main`, or enable vigilant mode. | Authorship in history becomes trustworthy. | S | Team agreement. |

### Retired numbers

- **30** (`refetchInterval` in `src/lib/intercom.tsx:68` and `wallet/api/use-redemption.ts:71`): no defect was shown. JWT refresh and a 30-second exchange-rate poll are reasonable until someone measures a cost.
- **31** (anchors with `target="_blank"`): withdrawn. Comparing aggregate counts of `target` and `rel` attributes cannot establish a missing `rel` on any individual link.
- **32** (image alt text): withdrawn. Both cited images have alt text.

### Existing safeguards and limits

- Environment validation is centralized. The two direct `import.meta.env` uses outside the config read `.DEV`. Client-prefixed values are public build inputs.
- Package policy includes minimum release age, trust policy, and pinned workflow actions. The repository does not establish branch protection or whether all jobs passed.
- Both layouts and 18 of 19 factory modules have lazy declarations. The manual chunk callback may erase their network-level benefit.
- Query defaults are centralized. Observed polling queries have `enabled` predicates, but these predicates do not necessarily bound retries or request lifetime.
- Coin helpers use integer cents at key boundaries. Some components still have local formatters and direct conversions.
- The app uses client navigation for many routes, and internal full-page navigation is intentional in revoked-session and logout paths (`end-revoked-session.ts:25`, `use-logout.ts:24`).
- Sentry wraps the router and profiles App. Route-caught errors need separate handling, and production capture, propagation, and symbolication remain unverified.
- Chart references to `file://` and a committed chart archive occurred historically. Neither is present at the audited commit.

---

## 10. Summary for a new joiner

1. Read `src/app/index.tsx`, `src/app/routes/index.tsx`, `src/config/env.ts`, `src/lib/api/api-client.ts`, and the auth store and cross-tab tests. The API gate loop is bounded. Its order and errors matter when adding a server challenge.
2. Use the checked-in Node pin and actual package scripts. The README's generators, part of the testing guide, and old data-fetching examples are stale. Start with the casino query keys and adjacent hooks for working examples.
3. The production build compiles application TypeScript. The checked-in workflows have no unit, e2e, or lint job. Run the relevant checks before relying on an apparent CI pass.
4. Cards uses an in-memory service in its enabled product path. Affiliate mixes fixture and server-backed data, while VIP has a zero fallback. Confirm the source of each screen's data before changing it.
5. Shop and wallet mix payment flow with UI. Tests cover some checkout reconciliation and redemption logic. Live payment, reconnect, and route-error behavior remain unverified.
6. A push to main triggers the configured workflow. Version bump is conditional. The checked-in host copy and container paths do not establish which path serves production.
7. Do these first:
   - **Veriff secret (finding 35).** Get it out of the bundle and rotate it. The fix commit already exists.
   - **GTM data push (finding 43).** Stop sending user objects to the dataLayer.
   - **Sentry token (finding 44).** Confirm it was revoked.

   Then test account-switch isolation and the deployment probes, add CI tests and lint, and fix chunking.

## Audit evidence and limits

Inventory and history are pinned to `5b20ce8ad` and the locally available refs. Source references verify static behavior. Revision 5 adds one scratch production build (sentinel env, built outside the repo), a local `tsc`/ESLint/Vitest run, a knip run and `git blame` ownership. Network chunk timing, live eligibility, actual releases, external services, which environments receive which secret, and whether test credentials or historical tokens remain active are unresolved. The rev 5 correctness-bug pass over money and compliance flows stopped before reporting, so it is not reflected here.
