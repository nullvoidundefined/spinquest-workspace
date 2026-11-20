# Storybook stories, batch by batch

Plain-language summary: [PRD](./2026-11-19-storybook-stories-prd.md). Implementation plan for setup and the pilot: [plan](./2026-11-19-storybook-stories-plan.md).

Repo: `spinquest-frontend`. Paths in this spec are relative to that repo unless they say otherwise.

## Summary

This spec gives spinquest-frontend a working Storybook, then adds stories for every component the app actually uses and that has a reason to be looked at on its own. That is about 245 story files and roughly 750–1,000 stories. Whole screens are left for later. The stories serve three purposes:

- **Design review and docs.** Designers and developers see every state of a component without running the app.
- **Dev sandbox.** UI can be built and tweaked without the local stack, against realistic, deterministic data.
- **Behaviour and accessibility checks.** CI renders every story in a real browser and runs its interaction test. The a11y addon reports violations on every story.

Delivery is a short foundation, a pilot on the redeem flow, then 31 independent batches of at most 30 stories each. Every batch can ship in any order, wait, or be skipped.

## Current state

- Storybook 8.6 is installed, with 7 stories. All are in `src/components/ui/`, and each is a bare `Default`.
- No story renders. [SQ-1154](https://linear.app/social-gaming-room/issue/SQ-1154/bugfix-get-storybook-in-spinquest-frontend-rendering-stories-again) tracks three failures, which surface one after another. There may be more behind the third.
  1. `.storybook/main.ts` lists `@storybook/addon-docs`, which is not a direct dependency, so Vite can't resolve `@storybook/addon-docs/preview`.
  2. `.storybook/preview.tsx` imports `../src/app/app-provider`, which no longer exists. `AppProvider` lives in `src/app/providers/index.tsx`.
  3. `src/config/env.ts` throws `Invalid env provided: PRODUCT: Required`. This still happens with `.env` copied in and `VITE_APP_PRODUCT=casino` appended, so the cause is not yet confirmed. The app gets `VITE_APP_PRODUCT` from `cross-env` in its scripts, and `vite.config.ts` uses `loadEnv` and a `define` block.
- `.storybook/main.ts` is CommonJS, lists legacy addons, and uses `react-docgen-typescript`.
- Nothing builds or publishes Storybook. CI does not build it, and [docs/storybook.md](../../../spinquest-frontend/docs/storybook.md) describes CI and deployment that don't exist.

## Goals

- A Storybook that never touches a real server, socket or analytics SDK.
- One story file beside each in-scope component (see [Scope](#scope)), covering its rows of the [story checklist](#story-checklist).
- A sidebar grouped by tier, in a fixed order: UI, Shared, Features.
- A PR is blocked by any story that fails to compile, render or pass its interaction test. Accessibility violations are reported, never blocking.
- The latest Storybook from `main` at one internal, non-public URL.
- The approach is proven on one real flow before the rest of the rollout.

## Non-goals

- **Visual regression snapshots.** Revisit before a MUI upgrade or a broad restyle. `@playwright/test`, already installed, can screenshot a built Storybook.
- **Moving or renaming component files** to fit the tiers.
- **Fixing component bugs found while writing stories.** Each one gets a ticket (G9).
- **Stories for unused code.** Parked landing variants and orphaned components get no stories.
- **Screens.** Route-level pages (the components a `route.factory` lazy-loads) get no stories for now. Their content is covered through their child components (see [Scope](#scope)). Screens are a later option.

## Anti-goals

- A story that makes a real network request, opens a socket or sends analytics.
- A story that passes only because it mocks away the component's own logic.
- A story provider that drifts from the app's own provider tree.
- Any package beyond the ones listed under [Dependencies](#dependencies).

## Constraints

### Dependencies

- **Storybook 10.x.** The upgrade from 8.6 is approved. It takes the version the official `storybook upgrade` resolves within the `pnpm-workspace.yaml` policies (`minimumReleaseAge`, `strictDepBuilds`, `trustPolicy`), pinned exactly.
- **Added:** `@storybook/addon-docs`, which is a separate package on 10.x and is listed in `main.ts`. Also `@storybook/addon-vitest`, and the Vitest browser-mode provider its installer adds.
- **Updated:** `eslint-plugin-storybook`, to the version that matches.
- **Removed:** `@storybook/addon-essentials`, `@storybook/addon-actions`, `@storybook/addon-links` and `@storybook/node-logger`. Core covers what they did.
- **Interaction API.** It comes from `storybook/test` in core. `@storybook/test` is never added.
- **No MSW.** `msw` is blocked in `pnpm-workspace.yaml` (`allowBuilds: msw: false`), and the frontend rules say "no msw".
- **pnpm is strict.** Story files import only direct dependencies.

### Storybook 10 requirements

- `main.ts` must be ESM.
- Node must be 20.19+ or 22.12+. `.nvmrc` pins 24.10.0, and CI uses Node 24.
- `tsconfig` `moduleResolution` must support the `types` export condition. Today it is `"Node"`, so SB-00a switches it to `"bundler"`.

### The app

- **Env.** `src/config/env.ts` throws at import when a required `VITE_APP_*` variable is missing, and `__APP_VERSION__` comes from Vite `define`. Storybook must load the project Vite config and a complete set of env values.
- **HTTP path.** All HTTP goes through the `api` axios instance in `src/lib/api/api-client.ts`, behind the auth interceptors and the gate loop in `src/lib/api/gates`.
- **Client review norms:**
  - i18n strings
  - layouts at 320 and 375px
  - the longest locale
  - failed reads that show Retry rather than empty or default content
- **PR size.** At most 30 stories, inside the frontend rule of about 300 lines.

## Approaches considered

### Backend data for stories

| Approach | Trade-off | Verdict |
|---|---|---|
| **Fixture adapter** on `api` | No package. One mechanism covers queries and mutations, and a request without a fixture fails the story. The interceptors and gates still run, so fixtures are typed against the real response types | **Chosen** |
| Seed the React Query cache | No package, and the `createQueryKeys` factories keep keys right. But mutations and imperative calls need a second mechanism, and stories skip the real request path | Rejected |
| MSW with `msw-storybook-addon` | Network-level interception. Blocked by the repo | Rejected |

### Storybook version

| Approach | Trade-off | Verdict |
|---|---|---|
| **Upgrade to 10.x first** | A few hours in SB-00a. Every story is then written once against current APIs, and gets `storybook/test` in core, the stable Vitest addon and a smaller install | **Chosen** |
| Stay on 8.6 | No upgrade now. But it needs `@storybook/test` as an extra package and a hand-built jsdom test harness, and every story is migrated later | Rejected |

### Running stories in CI

| Approach | Trade-off | Verdict |
|---|---|---|
| **`@storybook/addon-vitest`** | Storybook's recommended runner. It renders every story and runs its `play` function in real Chromium through Vitest browser mode, with a11y checks | **Chosen** |
| `composeStories` in jsdom | No browser download. But jsdom has no layout and unreliable contrast, and the story lifecycle has to be wired up by hand | Rejected |
| `@storybook/test-runner` | The older Playwright runner, which the Vitest addon supersedes | Rejected |

### Tier names

Atomic Design's atoms, molecules, organisms and pages would mean a judgement call on every file, and "components" would clash with `src/components/`. The tiers map to folders that already exist.

### Order of work

A purely bottom-up order would meet the hard problems late, after the whole rollout was committed: providers, fixtures, gates and flags. A pilot on the redeem flow meets them first.

### Hosting

Chromatic's main value is visual regression, which is out of scope. Without that, it is a paid third-party host for a static site the existing infrastructure already serves. Storybook is self-hosted.

## Design

### Scope

A component gets its own story file when it is **in use** and **public**, and is not a screen:

- **In use.** It is reachable from `src/main.tsx` through static imports, dynamic `import()` and the product alias in `vite.config.ts`.
- **Public.** At least one of these holds:
  - it is imported from two or more files
  - it is imported from one file outside its own folder (a feature entry point)
  - it is a top-level modal
- **Screens are left out.** A screen is a route entry under `src/features`: a component a `route.factory` lazy-loads. Its direct children count as public instead, so the screen's content is still covered. Routed layouts in `src/components/layouts` are Shared components, not screens.
- **Private sub-pieces** are imported by exactly one file in their own folder, where that file is not a screen. Their parent's stories cover them, and must reach their states. A sub-piece gets its own story file only when it has a state its parent can't reach.
- **Never their own story file:**
  - mobile and desktop variants, covered by their pair's story file
  - skeletons and loaders, shown in their parent's `Loading` story
  - animation and transition wrappers
  - icon sets: each set gets one gallery story
  - the [non-visual files](#non-visual-files)

A scan on 2026-11-19 found:

| Group | Files |
|---|---|
| Component files (`.tsx` under `src/components` and `src/features`, excluding tests and `styles.tsx`) | 580 |
| Public but unreachable | 48 |
| Screens (route entries under `src/features`) | 50 |
| Direct children of screens, promoted to public | 50 |
| In scope, after the exclusions above | about 245 |

The unreachable files are:

- **40 parked landing variants.** `landing-page.tsx` serves only `variants/legacy-home`, so the `giveaway-500k` and `variant-1` variants, with their sections and primitives, are not imported.
- **7 orphaned files**, each of which gets a dead-code ticket: six in `spinquest-cards` (`store-page`, `store-page/purchase-tab` and four `tournaments-page` pieces), and `responsible-gaming/components/policy`.
- **1 other file.**

The authoritative list is the to-do list, which SB-00b generates and every CI run checks (see [The to-do list](#the-to-do-list)). Two changes are picked up automatically:

- If a parked variant is switched back on, its components become reachable, and the test asks for their stories.
- If screens are taken on later, changing the screen rule there brings them into scope.

### Tiers and sidebar

Tiers set the sidebar `title` and the order of work. They never move files.

| Tier | Source | `title` |
|---|---|---|
| UI | `src/components/ui/*` | `UI/<Name>` |
| Shared | `src/components/common/*`, `src/components/layouts/*`, `src/components/errors` | `Shared/<Name>`, `Shared/Layouts/<Name>` |
| Features | `src/features/<feature>/**` | `Features/<Feature>/<Name>` |

- **Sidebar order.** The preview sets `parameters.options.storySort.order` to `['UI', 'Shared', 'Features', '*']`. If screens are added later, they take a `Screens/<Feature>/<Name>` tier after Features.
- **Story ids.** A story's id, and so its URL, comes from its `title` and export name. A story that is linked from tickets or Figma pins `id` on its meta, so a rename doesn't break the link.

### Story files

- **Location.** A story file sits beside its component: `index.stories.tsx` next to `index.tsx`, or `<name>.stories.tsx` next to `<name>.tsx`.
- **CSF3.** `meta` is `{ title, component }` and is the file's default export, which CV1 allows. Stories are typed `StoryObj<typeof Component>`.
- **Docs pages.** UI and Shared metas add `tags: ['autodocs']`. Features metas don't: their docs pages would load one iframe per story (see [Fixture adapter](#fixture-adapter)), and they are reviewed story by story.
- **Args.**
  - Args shared by most stories go in meta `args`.
  - Variants spread another story's args, for example `{ ...Default.args, disabled: true }`.
  - `ReactNode` props go through `argTypes.mapping`.
  - `render` is only for what args can't express.
- **Names.** Export names are the state names: `Default`, `Loading`, `Error`, `Empty`, `Mobile320`, `German`, and variant names. `name` is only for a display string that differs.
- **Exclusions.** A story that can't run in the test browser gets `tags: ['!test']`, with a comment beside it giving the reason.
- **Mobile and desktop pairs** share one story file.
- **Fixtures.**
  - Shared fixtures live in `src/fixtures/<domain>`, typed with the real response types from `src/lib/api`.
  - A fixture used by one story file sits beside it.
- **Strings.** Text a component renders comes through i18n, as in production. Story-only labels may be literal.

### Story checklist

Each component gets every row that applies to it.

| Component | Stories |
|---|---|
| **Every component** | `Default`, and one story per meaningful prop variant |
| **Reads data** | + `Loading`, `Error` (with Retry) and `Empty` |
| **Layout-sensitive** (layouts, modals, sheets, rows, page sections) | + `Mobile320` and `German` |
| **Has behaviour** (submit, Retry, open and close, tabs, OTP, steppers) | + a `play` function that drives the behaviour and asserts the result. For example: Retry refetches, submit disables while pending, a modal traps and returns focus |

Play functions:

- They import `expect`, `userEvent`, `within`, `waitFor` and `fn` from `storybook/test`.
- They query by role and name.
- They use `canvas` for content inside the story, and `screen` for MUI dialogs, popovers and menus, which portal to `document.body`.
- Shared setup reuses another story's play: `await Default.play(context)`.
- Callbacks are `fn()` spies.

A parent's stories also reach the states of its private sub-pieces. For example, the new-redemption modal's stories show the validation errors of its address and payment-method sections.

When the a11y addon reports a violation inside the component itself, the batch files a ticket and notes it in the story's `parameters.docs.description`. The batch doesn't fix it (G9).

### Providers

`src/app/providers/core-providers.tsx` exports `CoreProviders`, the providers with no side effects:

- `StyledEngineProvider`
- `ThemeProvider`
- `I18nextProvider`
- `HelmetProvider`
- `DialogsProvider`
- `CookiesProvider`

`AppProvider` renders `CoreProviders` inside its side-effect providers. The story decorator renders `CoreProviders` too, so a provider added there reaches stories automatically. On top of it, the decorator adds:

- a fresh `QueryClient` per story, with retries and refetch-on-focus off
- `MemoryRouter`, configured by `parameters.router` (`initialEntries` and an optional `path`)
- `AppToastContainer`

The side-effect providers stay out of Storybook:

- PostHog
- `FlagsSync`
- the socket providers
- `ReferralCodeProvider`
- the auth sync effects

A component that needs one of their context values gets a story-local stub provider.

### Environment and product

Storybook never reads the repo-root `.env`. That file holds real keys, and a build bakes every `VITE_APP_*` value into the static output, which is hosted.

- **Placeholder env.** A committed `.storybook/env/.env` holds placeholder values, and `main.ts` points Vite's `envDir` at that folder. It sets:
  - `VITE_APP_PRODUCT=casino`
  - `VITE_APP_ENABLE_SERVER_FLAGS=false`
  - `VITE_APP_ENABLE_POSTHOG=false`
  - `VITE_APP_ENABLE_SENTRY=false`
  - `VITE_APP_USE_MERCH_MOCKS=false`
  - a dummy value for every other required key
- **Product alias.** `vite.config.ts` reads `process.env.VITE_APP_PRODUCT` for the product alias before env files load. So `main.ts` begins with `process.env.VITE_APP_PRODUCT ??= 'casino'`.
- **Casino build.** Storybook runs as casino, the same default the tests use. Product-aliased files, such as the lobby hero, show their casino variant. `spinquest-cards` stories say in `parameters.docs.description` that they render in the casino build and are not for cards design sign-off. A separate cards build is a later decision.

### Fixture adapter

`.storybook/fixtures/fixture-adapter.ts` serves each story's `parameters.api`:

- **Installed before render.** The preview's global `beforeEach` installs it, before the story renders. It saves `api.defaults.adapter`, replaces it, and restores it in the `beforeEach` cleanup.
- **Keys.** A key is `'METHOD /path'`, with the path relative to `baseURL`, and the query string is ignored. A key containing `?` matches the query string exactly, and is tried first.
- **Values.**
  - A plain value is the response body, with status 200.
  - `respond({ status, data, delay })` sets the status, the body or a delay. It is a branded wrapper, so a body with its own `status` field, such as a redemption, is never mistaken for it.
  - `delay: 'never'` returns a promise that never settles, which is how `Loading` stories work.
- **Unmatched requests.**
  - The request fails with an error naming the missing key, and it is logged.
  - The adapter records the miss, and the preview's global `afterEach` fails the story.
  - So a missing fixture fails the story even when the component catches the error and renders its error state.
- **Error shape.** Error fixtures use the backend's error shape, including `code`, because components branch on it (G3).
- **No 401s and no gate codes.**
  - The auth interceptor and the gate loop react to them.
  - Storybook doesn't register the MFA gate and doesn't run GeoComply.
  - Gate UI, such as the MFA challenge and the location prompts, is storied directly in its own batch.
- **Merch.** Merch fixtures take their values from `src/fixtures/merch`. `VITE_APP_USE_MERCH_MOCKS` stays off, so only one mocking path is in play.
- **Docs pages.**
  - `api` is a module-level singleton, so the preview sets `parameters.docs.story.inline: false`. Each story on a docs page then renders in its own iframe, with its own fixtures.
  - SB-00b checks this isolation by hand.
  - The cost is that Controls don't live-update inside docs-page iframes. They still work on the story canvas.

### Client state, sign-in and flags

- **Stores.**
  - Stories seed zustand stores in a meta- or story-level `beforeEach`.
  - The cleanup puts each store back to its `getInitialState()`.
  - The adapter, store and flag cleanups are returned from `beforeEach` explicitly. Storybook resets `fn()` spies itself.
- **Storage.**
  - These stores persist to `localStorage`: `auth.store`, `store/ui`, `store/balance`, `store/geolocation` and merch's placed-order store.
  - The preview's global `beforeEach` clears `localStorage` and `sessionStorage` before every story.
- **Sign-in.** `.storybook/presets/` holds `signedIn` and `signedOut`. `signedIn` seeds only the auth token, the user and the wallet balance, from `src/fixtures`. A story seeds anything else it needs itself.
- **Flags.**
  - `withFlags({ key: value })` replaces `posthog.getFeatureFlag` for one story, and restores it in cleanup. That is the path `getFlag` takes in production whenever server flags are off, and it works signed in or out.
  - `VITE_APP_ENABLE_SERVER_FLAGS` stays `false`.
  - `ops-*` keys always return their fallback, by design.

### Language and viewport

- **Language dropdown.** The toolbar has a language dropdown: a `locale` global in `globalTypes`.
  - Its items are built from `languages` in `src/features/language/utils/options.ts`, the list the in-app picker uses, so the two can't drift (G5).
  - It shows the 11 languages with the app's labels, in the app's order: 普通话, English, Español, Français, Português, Русский, Bahasa Indonesia, Deutsch, 日本語, Türkçe, Tiếng Việt.
  - The default is English, which is also the i18n fallback.
  - The choice applies to every story until it is changed.
  - A decorator calls `i18n.changeLanguage` whenever the global changes.
  - A story pins a language with `globals: { locale: 'de' }`.
- **Locale files.** `staticDirs: ['../public']` serves `/locales/*.json`, in the browser and in story tests.
- **Viewports.** 320×640 and 375×812 viewports are registered with the viewport addon. A story pins one with `globals: { viewport: { value: 'mobile320' } }`.
- **Toolbar.** Any story can be switched to any language or viewport from the toolbar.

### Story tests and CI

- **The Vitest addon.** `@storybook/addon-vitest` adds a `storybook` Vitest project. `pnpm test:storybook` runs it.
  - It renders every story tagged `test`, which is the default, in headless Chromium.
  - Each story goes through Storybook's lifecycle: loaders, `beforeEach`, render, `play`, `afterEach`.
  - A story fails when it throws, when a `play` assertion fails, or when it makes a request with no fixture.
- **The unit project.** The existing unit tests become the `unit` Vitest project. `pnpm test` keeps running exactly those. The to-do list test and the `.storybook` unit tests run there too.
- **Accessibility is report-only.**
  - The preview sets `parameters.a11y.test: 'todo'`.
  - Violations show in the Storybook UI and the test output, but never fail a run.
  - Contrast is checked in a real browser, so it is reliable.
  - Moving to `'error'` later is a one-line change.
- **The `storybook` CI job.** `.github/workflows/build.yaml` gets a `storybook` job that runs on pull requests.
  - It runs `pnpm typecheck`, `pnpm storybook:build --test`, `pnpm exec playwright install --with-deps chromium`, `pnpm test:storybook` and the `.storybook` unit tests.
  - It uses only the committed placeholder env, so it can be made a required check.
- **The whole unit suite.** Making all of `pnpm test` a CI gate is a separate ticket (G9).

### Hosting

Storybook is self-hosted on the dev cluster from `main`, the same way the app is hosted.

- **This repo:**
  - `Dockerfile.storybook` copies the static build into the nginx image the app uses.
  - A `build.yaml` job, on every push to `main`, builds Storybook and pushes `ghcr.io/<org>/spinquest-frontend-storybook`, tagged `sha-<sha>` and `latest`.
  - The image is only built in CI, from the placeholder env.
- **Infra repo (DevOps):**
  - An Argo application and ingress serve the image at a stable dev URL, for example `storybook.dev.spinquest.com`.
  - The URL is not public, because Storybook shows unreleased and flag-gated UI. Access control matches the other dev hosts.
- **Later options:**
  - per-PR Storybook previews, through the ApplicationSet that already creates `pr-<n>` app previews
  - a cards build
  - screen stories

### Developer docs

[docs/storybook.md](../../../spinquest-frontend/docs/storybook.md) describes the setup as built:

- tiers and titles
- scope and the to-do list
- `CoreProviders`
- `parameters.api` and `respond()`
- `signedIn`, `signedOut` and `withFlags`
- `parameters.router`
- the language dropdown and viewports
- the story checklist
- play functions and the `!test` tag
- `pnpm test:storybook`, a11y in report-only mode, and the CI job
- hosting

`main.ts` sets `typescript.reactDocgen: 'react-docgen'`. `react-docgen-typescript` runs the TypeScript compiler over every component and slows down as the story count grows.

## Delivery plan

Delivery comes in three phases of small PRs:

- **Phase 0:** the foundation, landed in order.
- **Phase 1:** the UI tier and a pilot that measures the real cost.
- **Phase 2:** independent batches.

Stopping after any merged PR is safe. Stories are additive: nothing in the app imports them, and every merged state builds, renders and passes CI.

### How batches stay independent

- **Only Phase 0 is a dependency.** Every batch depends on SB-00a and SB-00b only. Batch IDs are labels, not an order.
- **Shared fixtures.** A batch that needs a shared fixture creates it in `src/fixtures/<domain>`. If another open batch adds the same fixture, whichever lands second reuses it when it rebases.
- **A batch is one PR** of at most 30 stories, with one Linear sub-issue under the Storybook parent issue. Linear holds status. This spec holds scope.
- **Flexible.** A batch can be split, merged with a small neighbour, moved anywhere in the order, paused part-way or skipped. A partial batch merges what is done, and the rest stays on the to-do list.
- **Resuming** means picking any batch whose components are still on the to-do list.

### The to-do list

`.storybook/unstoried.ts` is the to-do list:

- **`UNSTORIED`** lists the in-scope component files without a story, grouped by batch ID.
- **`NOT_STORIED`** lists the files that never get their own story file, each with a reason.
- **`COVERED_BY`** maps a file to the story file that covers it, for example a `mobile.tsx` to its pair's story file.

`.storybook/unstoried.test.ts` builds the import graph from the source. It applies the [scope](#scope) rules itself, so no list of private sub-pieces, screens or unreachable files is kept by hand, and it prints how many of each it left out. It fails when:

- an in-scope file has no story and isn't in `UNSTORIED`, `NOT_STORIED` or `COVERED_BY`
- a file in `UNSTORIED` already has a story
- a listed file no longer exists

SB-00b seeds the list. Each batch deletes its own entries. A PR that adds an in-scope component adds its story, or adds one line to `UNSTORIED` where the reviewer sees it. The rollout is done when the list is empty.

### Phase 0: foundation

These land in order. None of them changes what a user sees.

| PR | Scope | Done when | Build hours | Risk |
|---|---|---|---|---|
| SB-00a | **Upgrade and start.** Fixes SQ-1154. Storybook 10.x via `storybook upgrade`, pinned, with `@storybook/addon-docs` as a direct dependency. `moduleResolution: "bundler"`, with typecheck fallout fixed. `eslint-plugin-storybook` to match. ESM `main.ts` with `react-docgen`, `staticDirs` and the placeholder env. `CoreProviders`, used by `AppProvider` and the preview. `storySort`. `.storybook` in `tsconfig` and lint. The `storybook` CI job (typecheck and build) | Storybook starts on 10.x, and the 7 existing stories render with no env error. The CI job is green. The static build contains no value from the root `.env` | 5–9 | Medium: a major upgrade, and the `moduleResolution` change can surface typecheck errors app-wide |
| SB-00b | **Data and checks.** Fixture adapter and miss check. `signedIn`, `signedOut` and `withFlags`. Storage reset. Language dropdown and viewports. `@storybook/addon-vitest` in Chromium, with a11y report-only. The to-do list and its test. CI runs both. `docs/storybook.md` rewritten | A story with a missing fixture fails, naming the key. A story pinned to German renders German. The dropdown lists 11 languages. The to-do list test passes with every in-scope file listed | 6–9 | Medium: first Vitest browser-mode setup in this repo |
| SB-00c | **Hosting.** `Dockerfile.storybook` and the push-to-`main` image job, plus a DevOps ticket for the Argo app, the non-public ingress and the URL. Needs only SB-00a | The image is on GHCR, and the URL serves Storybook behind dev access control | 1.5–2.5, plus DevOps | Low |

### Phase 1: UI tier and redeem pilot

SB-01a, SB-01b, SB-02 and SB-03 need only Phase 0 and can land in any order. SB-04 follows the pilot.

| PR | Scope | Done when | Build hours | Risk |
|---|---|---|---|---|
| SB-01a | `components/ui`, leaves: buttons, form, image, linear progress, spinner, text divider. The existing stories are brought up to the checklist | Their entries are gone from `UNSTORIED` | 1.5–2.5 | Low |
| SB-01b | `components/ui`, behaviour: info tooltip, popover, OTP input, slider, switch, tabs, swiper slider | Their entries are gone from `UNSTORIED`, and the play functions pass | 1.5–2.5 | Low |
| SB-02 | **Redeem components.** New-redemption modal (its sections are private sub-pieces), redeemable balance card, redemption history card, history modal, submitted modal, verification checks, page container and surface card. No gate-code stories | Their entries are gone from `UNSTORIED`. Loading, Error with Retry, Empty, the modal's validation and submit-while-pending are all covered | 4–6 | Medium: the first data-heavy stories, and the first test of parents covering sub-pieces |
| SB-03 | **Redemption dialog.** The bank-transfer dialog's pages (default, bank, card, crypto), the response dialog, payment details and the shared form | Their entries are gone from `UNSTORIED`. The forms' required-field errors and submit are covered | 4–6 | Medium |
| SB-04 | **Go/no-go.** Review the pilot: hours per PR, stories per file, and whether parent stories reached their sub-pieces' states. Update this spec and the Phase 2 estimates | This spec carries measured numbers | 1 | — |

### Phase 2: independent batches

Each batch is one PR of at most 30 stories. File counts are in-scope files from the 2026-11-19 scan. The order is a suggestion: shared building blocks and the money paths come first.

| ID | Tier | Scope | ~Files |
|---|---|---|---|
| SB-05 | Shared | Buttons and small displays: action-icon-button, modal-header-icon-button, coin-toggle, social-coins, data-not-found, timer, toast, payment-status | 8 |
| SB-06 | Shared | Navigation and lists: app-pagination, pagination-buttons, app-tabs, routed-tabs, row-header, sub-page-side-bar, overlay-scroll-box, state-selector | 8 |
| SB-07 | Shared | Cards and rows: games-row (game card, game item), shop-slider-row card, casino-type-content, user-address-overview, `errors/main` | 6 |
| SB-08 | Shared | Modals: confirm-action-modal, page-modal, page-modal-sheet, responsive-sheet-modal, responsive-modal-page-wrapper, responsive-page-modal-wrapper | 7 |
| SB-09 | Shared | Layouts: app, base, dashboard and responsive-app layouts, desktop side nav, top bar, footer | 9 |
| SB-10 | Features | Casino lobby: lobby view, category tabs, group screen, recent wins, flying coin, casino content, casino FTUE | 7 |
| SB-11 | Features | Casino game and surfaces: game footer, game-unavailable dialog, error images, background surface, responsive content | 5 |
| SB-12 | Features | Shop package modal: package item and detail, Apple Pay, crypto pay, Link Money and its instant-transfer row | 6 |
| SB-13 | Features | Shop checkout: checkout-flow modal, checkout payment page, purchase success, shop content, shop iframe dialog, package page header | 6 |
| SB-14 | Features | Merch browse: catalog, filter disclosure, store hero, balance pill, cart button, quantity stepper, merch state, toast | 8 |
| SB-15 | Features | Merch product, cart and checkout: product, cart, cart states, insufficient SC, checkout, out-of-stock modal | 6 |
| SB-16 | Features | Merch order and modals: order action, confirmation, layout and summary, desktop modal, ineligible modal, welcome modal | 7 |
| SB-17 | Features | Auth sign-in and register: auth tabs, login form, password field, register flow and steps, validation help, forgot-password form | 8 |
| SB-18 | Features | Auth forms: change email, phone and username forms, form button, input, info display, password input, account-locked alert | 8 |
| SB-19 | Features | Account: account page, list item, modal header, deactivate modal, email and phone OTP forms, email-confirmed status | 7 |
| SB-20 | Features | Auth verification dialogs: OTP verification modal, phone OTP, login required, reset password, verify email, verify number | 6 |
| SB-21 | Features | MFA challenge: challenge, login-code step and toast, error state, resend code, support link, Turnstile host | 7 |
| SB-22 | Features | MFA flows and KYC: prompt, setup, disable, account row, KYC-required dialog, verify button | 6 |
| SB-23 | Features | Affiliate campaigns: affiliate tabs, crypto and social campaigns, new-campaign modal, campaign stats, referral-link cell, stat item, contact-us form | 8 |
| SB-24 | Features | Affiliate funds and commissions: crypto and social commission, funds table and footer, rewards table, amount with coin | 6 |
| SB-25 | Features | Affiliate users and retention: referred-user table, label value, crypto and social retention program | 4 |
| SB-26 | Features | Cards tournaments shell: shell, tabs, hero card, leader podium | 4 |
| SB-27 | Features | Cards tournaments tabs: battles, leaderboard and its row, replay modal, terms modal | 5 |
| SB-28 | Features | Cards collection: collection view, collection and deck-slot pickers, picker shell, card info content, header, affinity overlay and card | 8 |
| SB-29 | Features | Cards home: cards, card menu section, cards hero CTA, page surface, FTUE anchor, cards lobby hero | 6 |
| SB-30 | Features | Landing, live: landing page, legacy-home with its navbar, three sections and footer, official rules link and content | 10 |
| SB-31 | Features | Landing promotion: games, home card, secured payment, social banner, testimonials | 5 |
| SB-32 | Features | Location, language, notifications and terms: location permission, GC-only warning, GeoComply hints, language modal, free-spin modal, notification modal, notifications popover, terms body and email notice | 9 |
| SB-33 | Features | Vault and VIP: coin input, currency toggle, vault deposit and withdraw, user level, rank medals, all ranks, leveling system, VIP side bar | 9 |
| SB-34 | Features | Transactions and history: transaction tabs and list, deposits and withdrawals tables, history card, common, mobile and table | 8 |
| SB-35 | Features | Sports, promotions and AMOE: event accordion, side search bar, sports CTA, daily-bonus banner, first-time-offer banner, AMOE content | 6 |

### Closing sweep

Run this whenever the work stops, whether after the pilot or after the last batch:

- [ ] `UNSTORIED` lists exactly the in-scope files without a story, and the to-do list test passes on `main`.
- [ ] Every merged batch's Linear sub-issue is closed. An open one says what is left.
- [ ] Every `!test` tag has its reason, and a ticket where it hides a defect.
- [ ] Every a11y violation reported in the test output has a ticket.
- [ ] `pnpm lint`, `pnpm typecheck`, `pnpm test:storybook` and `pnpm storybook:build` pass, and the hosted Storybook shows the latest `main`.
- [ ] `docs/storybook.md` matches what exists.

### Level of effort

Build hours are engineer hours with an LLM coding agent. They cover directing it, reading the diff, checking stories in the browser and fixing what is subtly wrong. Review is 30–45 minutes per PR. SB-04 replaces these estimates with measured numbers.

| Scope | Build | Review | Days |
|---|---|---|---|
| Phase 0 | 12.5–20.5 h | 0.5 day | 2–3 |
| Phase 1 | 12–18 h | 0.5 day | 2–3 |
| Phase 2, per batch | 1.5–3 h | 30–45 min | about 0.3 |
| Phase 2, all 31 batches | 46–93 h | 2–3 days | 8–13 |

The recommended path is Phase 0 and Phase 1 (about **4.5–6 days**), then the go/no-go. Phase 2 can then run one batch at a time alongside other work.

## Coordination with the modal manager spec

The [FE Spec: Unified Modal Manager](https://app.notion.com/p/41aa274ca95d81e0a479e943c97ac3a7) touches the same files in two places:

- **CI.**
  - Its Phase 0 adds a Vitest and Playwright job to `build.yaml`, and SB-00a adds the `storybook` job to the same file. Whichever lands second extends the other's work.
  - Once the full unit suite runs in CI, the `.storybook` unit tests join that run.
- **Providers.**
  - Once its Core PR lands, the story decorator also mounts `<ModalHost />`, and stories of ported modals open through `openModal`.
  - The port that retires the dialog stack removes `DialogsProvider` from `CoreProviders` in the same PR (G4).

## Non-visual files

These never get a story file. The to-do list carries them in `NOT_STORIED`:

- `common/app-guards`, `common/error-boundary`, `common/dialogs` (provider), `common/cloudflare-turnstile`
- `feature-flags/flags-sync`, `notifications/notifications-socket-provider`, `casino/leaderboard/recentwins-socket-provider`, `smart-modal-navigation/direct-desktop-modal-host`
- `terms/terms-reacceptance-guard`, `auth/protected-route`, `responsible-gaming/responsible-gaming-mdx-loader`, `affiliate-program/context/*`
- hooks and config in `.tsx` files, such as `use-redemption-response-dialog.tsx` and `ftue-steps.config.tsx`
- every `route.factory.ts(x)`
- screens, for now (see [Scope](#scope))

## Left to the builder

- The exact Storybook 10.x version, and the browser-mode provider the Vitest addon's installer chooses.
- The stub shape for a context a component needs from a side-effect provider.
- Which prop variants are meaningful, and edge cases of "layout-sensitive" and "has behaviour".
- Moving a file between neighbouring batches when the to-do list's grouping and this table disagree.
