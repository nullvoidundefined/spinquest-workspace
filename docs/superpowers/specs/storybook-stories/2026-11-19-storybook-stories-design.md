# Storybook stories, batch by batch

Plain-language summary: [PRD](./2026-11-19-storybook-stories-prd.md). Implementation plan for setup and the pilot: [plan](./2026-11-19-storybook-stories-plan.md).

Repo: `spinquest-frontend`. Paths in this spec are relative to that repo unless they say otherwise.

## Summary

This spec sets up Storybook in spinquest-frontend, then adds stories for the 244 components the app uses that are worth looking at on their own. That is roughly 750–1,000 stories. Whole screens are left for later. The stories serve three purposes:

- **Design review and docs.** Designers and developers see every state of a component without running the app.
- **Dev sandbox.** UI can be built and tweaked without the local stack, against realistic, deterministic data.
- **Behaviour and accessibility checks.** Story tests render every story in a real browser and run its interaction test. Accessibility problems are reported.

Delivery is in three steps:

1. **Setup:** a set-up PR, a story-tooling PR, a CI evaluation and a story-prompt hook.
2. **Pilot:** the UI tier and the redeem flow.
3. **Batches:** 32 independent batches of at most 30 stories each.

Nothing Storybook-related runs in CI or deploys until the evaluation approves it.

## Current state

- **Stories.** Storybook 8.6 is installed, with 7 stories. All are in `src/components/ui/`, and each is a bare `Default`.
- **No story renders.** [SQ-1154](https://linear.app/social-gaming-room/issue/SQ-1154/bugfix-get-storybook-in-spinquest-frontend-rendering-stories-again) tracks three failures, and there may be more behind the third:
  1. `.storybook/main.ts` lists `@storybook/addon-docs`, which is not a direct dependency.
  2. `.storybook/preview.tsx` imports `../src/app/app-provider`, which no longer exists. `AppProvider` lives in `src/app/providers/index.tsx`.
  3. `src/config/env.ts` throws `Invalid env provided: PRODUCT: Required`. This happens even with `.env` copied in and `VITE_APP_PRODUCT=casino` added, so the cause is unconfirmed. The app gets `VITE_APP_PRODUCT` from `cross-env` in its scripts.
- **Config.** `.storybook/main.ts` is CommonJS and uses `react-docgen-typescript`.
- **CI and docs.** Nothing builds or publishes Storybook. [docs/storybook.md](../../../../spinquest-frontend/docs/storybook.md) describes CI and deployment that don't exist.

## Goals

- Storybook works without a backend, and never touches a real server, socket or analytics SDK.
- Each of the 244 [listed components](#appendix-the-244-components) ends up with a story file beside it, covering its rows of the [story checklist](#story-checklist). 7 of them already have a bare story, so `UNSTORIED` starts with 237 entries, and SB-01a and SB-01b bring those 7 up to the checklist.
- `pnpm test:storybook` fails for any story that crashes or fails its interaction test. Accessibility violations are reported, never failing.
- Nobody's builds or deploys get slower. Storybook stays out of CI and deploys until SB-00c approves it.
- When Claude creates a new component, it asks whether to generate a story for it.

## Non-goals

- **Visual regression snapshots.** Revisit before a MUI upgrade or a broad restyle.
- **Screens.** Route-level pages get no stories for now. Their content is covered through their child components.
- **Stories for unused code,** such as the parked landing variants and orphaned files.
- **Moving or renaming component files.**
- **Fixing bugs found while writing stories.** Each one gets a ticket (G9).

## Constraints

- **Storybook 10.x.** The upgrade from 8.6 is approved. It is pinned to the version the official `storybook upgrade` resolves within the `pnpm-workspace.yaml` policies.
  - **Added:** `@storybook/addon-docs`, which is a separate package on 10.x, and `@storybook/addon-vitest`, with the browser-mode provider its installer adds.
  - **Removed:** `addon-essentials`, `addon-actions`, `addon-links` and `node-logger`. Core covers them.
  - **Interaction API.** It comes from `storybook/test` in core.
  - **Package approval.** The approval above covers the Storybook upgrade only. `@storybook/addon-vitest` pulls in more packages (the browser-mode provider, Playwright and a Chromium download, and possibly a Vitest upgrade). Under workspace invariant 10, SB-00a and SB-00b each stop before installing anything new and present the exact package list, with license, maintenance and size, for administrator approval.
  - **Nothing beyond that list.** No MSW: the repo blocks it in `pnpm-workspace.yaml`.
- **Storybook 10 requirements:**
  - ESM `main.ts`.
  - Node 20.19+ or 22.12+. `.nvmrc` pins 24.10.0.
  - A `moduleResolution` that supports the `types` export condition. SB-00a switches `tsconfig` from `"Node"` to `"bundler"`.
- **The app:**
  - `src/config/env.ts` throws when a required `VITE_APP_*` value is missing.
  - All HTTP goes through the `api` axios instance in `src/lib/api/api-client.ts`, behind the auth interceptors and the gate loop.
- **Review norms:**
  - i18n strings
  - layouts at 320 and 375px
  - the longest locale
  - failed reads that show Retry
- **PR size.** At most 30 stories per PR. The cap wins over batch size: a batch counts its stories from the [checklist](#story-checklist), and one that would exceed 30 is split in two. Layout-sensitive batches (SB-08, SB-18, SB-31, SB-34 and the modal-heavy ones) are the likely splits, because each such component takes 5–7 stories.

## Approaches considered

| Decision | Chosen | Rejected, and why |
|---|---|---|
| Backend data for stories | A fixture adapter on `api`: one mechanism for queries and mutations, with no package | Seeding the React Query cache, because mutations need a second mechanism. MSW, because the repo blocks it |
| Storybook version | Upgrade to 10.x first, so every story is written once against current APIs | Staying on 8.6, which needs an extra package and a hand-built test harness, then a migration of every story |
| Running story tests | `@storybook/addon-vitest` in real Chromium | `composeStories` in jsdom, which has no layout and is hand-wired. `test-runner`, which the addon supersedes |
| Sidebar tiers | UI, Shared, Features, matching folders that exist | Atomic Design, which needs a judgement call on every file |
| Hosting | Self-hosted on the dev cluster, if SB-00c approves it | Chromatic, because its main feature is visual regression, which is out of scope |
| Order | A pilot on the redeem flow first | Pure bottom-up, which meets the hard problems last |

## Design

### Scope

The 244 components in the [appendix](#appendix-the-244-components) came from a scan of the import graph on 2026-11-20. A component is in scope when:

- **It is in use:** reachable from `src/main.tsx`, including through routes and lazy imports.
- **It is public:** imported from two or more files, or from outside its own folder, or a top-level modal.
- **It is not a screen.** A screen is a component a `route.factory` lazy-loads. A screen's direct children are counted as public instead.

The scan found 580 component files and left out about 336:

- **About 190 private sub-pieces,** each imported by one file in its own folder. Their parent's stories cover them.
- **50 screens.**
- **48 unreachable files.** These include 40 parked landing variants. They also include 7 orphaned files, which each get a dead-code ticket: six in `spinquest-cards` and `responsible-gaming/components/policy`.
- **About 48 others:** non-visual files, mobile and desktop variants, skeletons and loaders, wrappers, icon sets, hooks, and the GeoComply hints dialog, which has no live opener.

New components are caught by the [story prompt hook](#story-prompt-hook), not by re-running the scan.

### Tiers and sidebar

| Tier | Source | `title` |
|---|---|---|
| UI | `src/components/ui` | `UI/<Name>` |
| Shared | `src/components/common`, `src/components/layouts`, `src/components/errors` | `Shared/<Name>` |
| Features | `src/features/<feature>` | `Features/<Feature>/<Name>` |

The preview sets `storySort.order` to `['UI', 'Shared', 'Features', '*']`.

### Story files

- **Location.** A story file sits beside its component: `index.stories.tsx`, or `<name>.stories.tsx`.
- **CSF3.**
  - `meta` is `{ title, component }`, and is the default export.
  - UI and Shared metas add `tags: ['autodocs']`.
  - Stories are typed `StoryObj<typeof Component>`.
- **Names.** Export names are the state names: `Default`, `Loading`, `Error`, `Empty`, `Mobile320`, `German`, and variant names.
- **Interactive.** Every story is driven by args, so the Controls panel can change its inputs.
  - Props are args. Shared args go in meta `args`, and variants spread them. `render` is only for what args can't express.
  - A data-reading story also exposes its key data values as args, such as amounts, counts, statuses and error codes. Its `parameters.api` is then a function of those args, so changing a control refetches with the new values.
- **Skipping tests.** A story that can't run in the test browser gets `tags: ['!test']`, with a comment giving the reason.
- **Fixtures.** Shared fixtures go in `src/fixtures/<domain>`, typed with the real response types.
- **Strings.** A component's text comes through i18n. Story-only labels may be literal.

### Anatomy of a story

`docs/storybook.md` has an "Anatomy of a story" section, written precisely enough for Claude to follow when it generates a story.

- **It walks through a real example:** `.storybook/examples/reward-claim-card.tsx`, a small teaching component, and its `reward-claim-card.stories.tsx`.
  - The stories file is tagged `!dev`, so it stays out of the sidebar, but it runs in the story tests. If an API drifts, typecheck or a test fails.
  - The component reads `GET /storybook-example/reward`, has a Claim button that POSTs, and has an error state with Retry and an empty state.
  - Its text uses keys that already exist in `en.json` and `de.json`.
- **The stories come in a fixed order:**
  1. imports
  2. fixtures
  3. meta, with `argTypes` for the prop controls and the data controls
  4. `Default`
  5. a prop variant
  6. `Loading`, `Error` (with a Retry play) and `Empty`
  7. `Mobile320` and `German`
  8. `Claim`, with a play function
- **The doc section follows the same order,** mapping each story to its checklist row.
- **It ends with a short don't list:**
  - no real network calls
  - no 401s or gate codes
  - no mocking away the component's own logic
  - no literal copy in components

### Story checklist

| Component | Stories |
|---|---|
| Every component | `Default`, and one story per meaningful prop variant |
| Reads data | + `Loading`, `Error` (with Retry), `Empty` |
| Layout-sensitive (layouts, modals, sheets, rows, page sections) | + `Mobile320`, `German` |
| Has behaviour (submit, Retry, open and close, tabs, OTP, steppers) | + a `play` function that drives the behaviour and asserts the result |

- **Play functions:**
  - They use `storybook/test`, and query by role and name.
  - They use `screen` for MUI dialogs, popovers and menus, which portal to `document.body`.
  - Callbacks are `fn()` spies.
- **Parents and sub-pieces.** A parent's stories reach its private sub-pieces' states.
- **a11y.** An accessibility violation inside a component gets a ticket and a note in its story's `parameters.docs.description`.

### Providers

- **`CoreProviders`.** `src/app/providers/core-providers.tsx` holds the providers with no side effects:
  - `StyledEngineProvider`
  - `ThemeProvider`
  - `I18nextProvider`
  - `HelmetProvider`
  - `DialogsProvider`
  - `CookiesProvider`
- **Shared with the app.** `AppProvider` and the Storybook preview both render `CoreProviders`, so they can't drift apart.
- **What the preview adds:**
  - a fresh `QueryClient` per story, with retries off
  - a `MemoryRouter` configured by `parameters.router`
  - `AppToastContainer`
- **Left out:** PostHog, `FlagsSync`, the socket providers, `ReferralCodeProvider` and the auth effects. A component that needs one of their contexts gets a stub in its story.

### Environment

Storybook never reads the repo-root `.env`, which holds real keys.

- **Placeholder env file.** `main.ts` points Vite's `envDir` at a committed `.storybook/env/.env`. It holds:
  - `VITE_APP_PRODUCT=casino`
  - every `ENABLE_*` flag, and `USE_MERCH_MOCKS`, set to `false`
  - a dummy value for every other required key
- **Product alias.** `vite.config.ts` reads `process.env.VITE_APP_PRODUCT` for the product alias, so `main.ts` starts with `process.env.VITE_APP_PRODUCT ??= 'casino'`.
- **Casino build.** Storybook builds as casino. The `spinquest-cards` stories say so in their docs description.

### Fixtures, sign-in and flags

- **Fixture adapter.** The preview's global `beforeEach` swaps `api.defaults.adapter` for one that answers from `parameters.api`, and restores it afterwards.
  - **Live data controls.** `parameters.api` is either an object or a function of the story's args. The adapter builds the fixtures from the current args each time a request is made. When the args change, the story decorator gives the story a fresh `QueryClient`, so it refetches.
  - **Keys** are `'METHOD /path'`, ignoring the query string.
  - **A plain value** is a 200 response body.
  - **`respond({ status, data, delay: 'never' })`** sets a status or a body. With `delay: 'never'`, the request never settles, which is how `Loading` stories work. The wrapper is branded, so a body with its own `status` field, such as a redemption, is never mistaken for it.
  - **An unmatched request** fails, and the preview's `afterEach` fails the story, naming the key.
  - **No 401s or gate codes.** Fixtures never return them, because the auth interceptor and the gate loop react to them.
- **Docs pages.** `api` is a singleton, so `parameters.docs.story.inline: false` renders each story on a docs page in its own iframe.
- **Storage.** The global `beforeEach` clears `localStorage` and `sessionStorage`. Store seeds reset to `getInitialState()` in their cleanup.
- **Sign-in.** `signedIn` seeds the auth token, the user and the balance. `signedOut` clears them.
- **Flags.** `withFlags({ key: value })` stands in for `posthog.getFeatureFlag` for one story.

### Language and viewport

- **Language dropdown.** The toolbar has a language dropdown built from `languages` in `src/features/language/utils/options.ts`. It shows the app's 11 languages, with the app's labels and in the app's order. The default is English.
- **Pinning a language.** A story pins one with `globals: { locale: 'de' }`.
- **Locale files.** `staticDirs: ['../public']` serves `/locales`.
- **Viewports.** 320×640 and 375×812 viewports are registered. A story pins one with `globals: { viewport: { value: 'mobile320' } }`.

### Story tests

- **The Vitest addon.** `@storybook/addon-vitest` adds a `storybook` Vitest project.
  - `pnpm test:storybook` renders every story tagged `test` in headless Chromium, and runs its `play` function.
  - The existing unit tests become the `unit` project, and `pnpm test` keeps running only them.
- **Accessibility is report-only.** `parameters.a11y.test` is `'todo'`.
- **The local check.** `pnpm storybook:check` runs typecheck, `storybook build --test`, the story tests and the `.storybook` unit tests. Every Storybook PR pastes its output in the PR body.

### The to-do list

- **The list.** `.storybook/unstoried.ts` exports `UNSTORIED`: the [appendix](#appendix-the-244-components) as a list of paths, grouped by batch ID. It leaves out the 7 files that already have bare stories, which SB-01a and SB-01b bring up to the checklist. Each batch deletes its own entries.
- **The test.** `.storybook/unstoried.test.ts` checks two things: every listed path exists, and none of them has a story yet. That keeps the list honest.
- **Done.** The rollout is done when the list is empty.

### CI and deploys

No Storybook step goes into any CI or deploy workflow until SB-00c has measured what it would cost.

- **What SB-00c measures,** locally:
  - the time for `storybook build --test`, the Chromium download and `pnpm test:storybook`, at the pilot's story count, projected to the full rollout
  - the same against the duration of the `build` job
- **What it decides,** recorded in this spec:
  - whether PRs get a Storybook check
  - whether Storybook is hosted
- **Where approved jobs go.** They go in a separate `.github/workflows/storybook.yaml`, with path filters (`src/**`, `public/locales/**`, `.storybook/**`, `package.json` and `pnpm-lock.yaml`). Never `build.yaml` or the deploy workflows.
- **Hosting, if approved:**
  - An nginx image built from `main`, using the app's base image and `default.conf`, is pushed to `ghcr.io/<org>/spinquest-frontend-storybook`.
  - A DevOps ticket covers the Argo app and a non-public dev URL.
  - The image is only built in CI, from the placeholder env.

### Story prompt hook

When Claude creates a new component in spinquest-frontend, it asks whether to generate a story.

- **Where it lives.** `.claude/hooks/story-prompt.sh` in the workspace repo, wired under `PostToolUse` like `style-scan.sh`, with fixtures for `test-hooks.sh`.
- **When it fires.** All of these must hold:
  - A `Write` created the file: the tool response's type is `create`.
  - The file is a `.tsx` under `src/components` or `src/features`.
  - It is not a test, story, styles, route factory, hook or config file.
  - No story sits beside it.
- **What it does.** It adds context telling Claude to ask the user:
  - **Yes:** Claude writes the story, following `docs/storybook.md`.
  - **No:** Claude adds the file to `UNSTORIED`.
  - **Private sub-piece or screen:** Claude says no story is needed.
- **Who gets it.** SB-00d first checks that workspace hooks load in a session started inside `spinquest-frontend`. If they don't, the hook ships in the team's `claude-skills` plugin instead.

## Delivery plan

Every PR leaves the app working. Stories are additive, and nothing in the app imports them.

**How batches work:**

- **Dependencies.** Every batch depends only on SB-00a and SB-00b. Batch IDs are labels, not an order.
- **Size and tracking.** A batch is one PR of at most 30 stories, with one Linear sub-issue.
- **Flexible.** A batch can be split, merged (never above the 30-story cap), moved, paused part-way or skipped. The to-do list shows exactly what is left.
- **Shared fixtures.** A batch that needs a shared fixture creates it. Whichever batch lands second reuses it.

### Phase 0: setup

| PR | Scope | Done when | Hours | Risk |
|---|---|---|---|---|
| SB-00a | **Set up Storybook.** Fixes SQ-1154. Upgrade to 10.x, pinned, with `@storybook/addon-docs`. `moduleResolution: "bundler"`. ESM `main.ts` with `react-docgen`, `staticDirs` and the placeholder env. `CoreProviders`, used by `AppProvider` and the preview. `storySort`. The `storybook:check` script. No CI changes | Storybook starts on 10.x. The 7 existing stories render with no env error. The static build contains no value from the root `.env` | 5–9 | Standard: a major upgrade, plus a `moduleResolution` change |
| SB-00b | **Story tooling.** Fixture adapter, sign-in and flag presets, storage reset. Language dropdown and viewports. The Vitest addon, with a11y report-only. The to-do list and its test. `docs/storybook.md` rewritten | A missing fixture fails a story, naming the key. A German story renders German. The to-do list test passes | 6–9 | Standard: the first Vitest browser-mode setup |
| SB-00c | **CI and hosting evaluation.** Measure locally, decide, and record the decision here. If approved: `storybook.yaml` and hosting. Best after the pilot | The decision is recorded. If approved, the new workflow is green | 2–4, plus DevOps | Standard: it adds to shared CI |
| SB-00d | **Story prompt hook,** in the workspace repo | Creating a component prompts. Editing a file, creating a test and creating a story don't | 1–2 | Standard |

### Phase 1: UI tier and redeem pilot

| PR | Scope | Stories | Hours |
|---|---|---|---|
| SB-01a | UI leaves (8 files), plus bringing the existing stories up to the checklist | about 25 | 1.5–2.5 |
| SB-01b | UI with behaviour (7 files) | about 25 | 1.5–2.5 |
| SB-02 | Redeem components (8 files) | about 30 | 4–6 |
| SB-03 | Redemption dialog (7 files) | about 25 | 4–6 |
| SB-04 | **Go/no-go.** Review hours per PR, stories per file, and whether parents reached their sub-pieces' states. Update this spec | — | 1 |

### Phase 2: batches

The order is a suggestion: shared building blocks first, then the money paths.

| ID | Tier | Scope | Files |
|---|---|---|---|
| SB-05 | Shared | Basics: action and modal-header icon buttons, coin toggle, social coins, data not found, timer, toast, payment status | 8 |
| SB-06 | Shared | Navigation and lists: pagination, tabs, routed tabs, row header, sub-page side bar, scroll box, state selector | 8 |
| SB-07 | Shared | Cards and rows: game card and item, shop card, casino type content, address overview, error page | 6 |
| SB-08 | Shared | Modals: confirm, page modal, sheet, the two responsive wrappers with the overlay and mobile title | 8 |
| SB-09 | Shared | Layouts: app, base, dashboard and responsive app layouts | 4 |
| SB-10 | Shared | Navigation chrome: desktop side nav, top bar and header, footer and its parts | 7 |
| SB-11 | Features | Casino lobby: casino content, FTUE, lobby view, category tabs, group screen, recent wins, flying coin | 7 |
| SB-12 | Features | Casino game: game footer, game-unavailable dialog, error images, background surface, responsive content | 5 |
| SB-13 | Features | Shop package modal: package item and detail, Apple Pay, crypto pay, Link Money and its row | 6 |
| SB-14 | Features | Shop checkout: checkout flow, payment page, purchase success, shop content, iframe dialog, package header | 6 |
| SB-15 | Features | Merch browse: catalog, filters, store hero, balance pill, cart button, quantity stepper, merch state, toast | 8 |
| SB-16 | Features | Merch product, cart and checkout | 6 |
| SB-17 | Features | Merch order and modals | 7 |
| SB-18 | Features | Auth sign-in and register | 8 |
| SB-19 | Features | Auth forms and form controls | 8 |
| SB-20 | Features | Account page and account settings | 7 |
| SB-21 | Features | Auth verification dialogs | 6 |
| SB-22 | Features | MFA challenge | 7 |
| SB-23 | Features | MFA flows and KYC | 6 |
| SB-24 | Features | Affiliate campaigns | 8 |
| SB-25 | Features | Affiliate commissions and funds | 6 |
| SB-26 | Features | Affiliate users and retention | 4 |
| SB-27 | Features | Cards tournaments shell | 4 |
| SB-28 | Features | Cards tournaments tabs | 5 |
| SB-29 | Features | Cards collection and card info | 8 |
| SB-30 | Features | Cards home | 6 |
| SB-31 | Features | Landing (live) | 9 |
| SB-32 | Features | Landing promotion | 5 |
| SB-33 | Features | Location, language, notifications and terms | 8 |
| SB-34 | Features | Vault and VIP | 9 |
| SB-35 | Features | Transactions and history | 8 |
| SB-36 | Features | Sports, promotions and AMOE | 6 |

### Level of effort

These are engineer hours with an LLM coding agent, plus 30–45 minutes of review per PR. SB-04 replaces them with measured numbers.

| Scope | Days |
|---|---|
| Phase 0 and Phase 1 (recommended first) | 5–6.5 |
| Each Phase 2 batch | about 0.3 |
| All 32 Phase 2 batches | 8–13 |

### Closing sweep

Run this whenever the work stops:

- [ ] `UNSTORIED` matches what's left, and its test passes.
- [ ] Every merged batch's Linear sub-issue is closed.
- [ ] Every `!test` tag and every reported a11y violation has a ticket.
- [ ] `pnpm lint` and `pnpm storybook:check` pass on `main`.
- [ ] `docs/storybook.md` matches what exists.

## Left to the builder

- The exact Storybook 10.x version, and the browser-mode provider.
- Stubs for contexts from left-out providers.
- Which prop variants are meaningful, and edge cases of the checklist rows.
- Moving a file to a neighbouring batch.

## Appendix: the 244 components

Paths are under `src/`. Each group is one batch and one entry in `UNSTORIED`.

### SB-01a: UI leaves (8)

- `components/ui/button/app-button.tsx`
- `components/ui/button/app-loading-button.tsx`
- `components/ui/form/index.tsx`
- `components/ui/image/image.tsx`
- `components/ui/linear-progress/linear-progress.tsx`
- `components/ui/loading-button/loading-button.tsx`
- `components/ui/spinner/spinner.tsx`
- `components/ui/text-divider/text-divider.tsx`

### SB-01b: UI with behaviour (7)

- `components/ui/info-tooltip/info-tooltip.tsx`
- `components/ui/otp-code-input/otp-code-input.tsx`
- `components/ui/popover/popover.tsx`
- `components/ui/slider/slider.tsx`
- `components/ui/swiper-slider/index.tsx`
- `components/ui/switch/switch.tsx`
- `components/ui/tabs/tabs.tsx`

### SB-02: Redeem components (8)

- `features/wallet/components/redeem/new-redemption-modal/index.tsx`
- `features/wallet/components/redeem/primitives/redeem-page-container.tsx`
- `features/wallet/components/redeem/primitives/redeem-surface-card.tsx`
- `features/wallet/components/redeem/redeem-history-modal.tsx`
- `features/wallet/components/redeem/redeemable-balance-card.tsx`
- `features/wallet/components/redeem/redemption-history-card.tsx`
- `features/wallet/components/redeem/redemption-submitted-modal.tsx`
- `features/wallet/components/redeem/verification-checks.tsx`

### SB-03: Redemption dialog (7)

- `features/wallet/components/redemptions/components/payment-details.tsx`
- `features/wallet/components/redemptions/redeem-bank-transfer-dialog/components/bank-page/index.tsx`
- `features/wallet/components/redemptions/redeem-bank-transfer-dialog/components/card-page/index.tsx`
- `features/wallet/components/redemptions/redeem-bank-transfer-dialog/components/crypto-page/index.tsx`
- `features/wallet/components/redemptions/redeem-bank-transfer-dialog/components/default-page/index.tsx`
- `features/wallet/components/redemptions/redeem-bank-transfer-dialog/components/redemption-response-dailog/redemption-response-dialog.tsx`
- `features/wallet/components/redemptions/redeem-bank-transfer-dialog/components/shared/redemption-form-shared/index.tsx`

### SB-05: Shared basics (8)

- `components/common/action-icon-button.tsx`
- `components/common/coin-toggle/coin-toggle.tsx`
- `components/common/data-not-found.tsx`
- `components/common/modal-header-icon-button.tsx`
- `components/common/payment-status/index.tsx`
- `components/common/social-coins/index.tsx`
- `components/common/timer.tsx`
- `components/common/toast.tsx`

### SB-06: Shared navigation and lists (8)

- `components/common/app-pagination/index.tsx`
- `components/common/app-tabs/index.tsx`
- `components/common/overlay-scroll-box/index.tsx`
- `components/common/pagination-buttons.tsx`
- `components/common/routed-tabs/index.tsx`
- `components/common/row-header/index.tsx`
- `components/common/state-selector/index.tsx`
- `components/common/sub-page-side-bar/index.tsx`

### SB-07: Shared cards and rows (6)

- `components/common/casino-type-content.tsx`
- `components/common/games-row/game-card.tsx`
- `components/common/games-row/game-item.tsx`
- `components/common/shop-slider-row/shop-card.tsx`
- `components/common/user-address-overview/index.tsx`
- `components/errors/main.tsx`

### SB-08: Shared modals (8)

- `components/common/confirm-action-modal/index.tsx`
- `components/common/page-modal-sheet/index.tsx`
- `components/common/page-modal/index.tsx`
- `components/common/responsive-modal-page-wrapper/components/mobile-page-title.tsx`
- `components/common/responsive-modal-page-wrapper/components/modal-overlay.tsx`
- `components/common/responsive-modal-page-wrapper/responsive-modal-page-wrapper.tsx`
- `components/common/responsive-page-modal-wrapper/responsive-page-modal-wrapper.tsx`
- `components/common/responsive-sheet-modal/index.tsx`

### SB-09: Layouts (4)

- `components/layouts/app-layout.tsx`
- `components/layouts/base-layout.tsx`
- `components/layouts/dashboard-layout.tsx`
- `components/layouts/responsive-app-layout/index.tsx`

### SB-10: Navigation chrome (7)

- `components/layouts/desktop-side-nav/index.tsx`
- `components/layouts/footer/components/amoe-button.tsx`
- `components/layouts/footer/components/desktop-footer.tsx`
- `components/layouts/footer/components/responsive-footer.tsx`
- `components/layouts/footer/index.tsx`
- `components/layouts/top-bar/header/index.tsx`
- `components/layouts/top-bar/index.tsx`

### SB-11: Casino lobby (7)

- `features/casino/components/casino-content/index.tsx`
- `features/casino/components/casino-ftue/casino-ftue.tsx`
- `features/casino/components/lobby-view/casino-lobby-category-tabs/index.tsx`
- `features/casino/components/lobby-view/casino-lobby-group-screen/index.tsx`
- `features/casino/components/lobby-view/casino-lobby-recent-wins/index.tsx`
- `features/casino/components/lobby-view/casino-lobby-view/index.tsx`
- `features/casino/components/lobby-view/flying-coin.tsx`

### SB-12: Casino game (5)

- `features/casino/components/error-images/index.tsx`
- `features/casino/components/game/game-footer.tsx`
- `features/casino/components/game/game-unavailable/game-unavailable-dialog.tsx`
- `features/casino/components/shared/casino-background-surface/index.tsx`
- `features/casino/components/shared/casino-responsive-content/index.tsx`

### SB-13: Shop package modal (6)

- `features/shop/components/shop-package-modal/apple-pay/index.tsx`
- `features/shop/components/shop-package-modal/crypto-pay/index.tsx`
- `features/shop/components/shop-package-modal/link-money/app-instant-bank-transfer-row.tsx`
- `features/shop/components/shop-package-modal/link-money/index.tsx`
- `features/shop/components/shop-package-modal/package-detail.tsx`
- `features/shop/components/shop-package-modal/shop-package-item.tsx`

### SB-14: Shop checkout (6)

- `features/shop/components/checkout-flow-modal/index.tsx`
- `features/shop/components/checkout-payment-page/index.tsx`
- `features/shop/components/purchase-success-modal/index.tsx`
- `features/shop/components/shop-content/index.tsx`
- `features/shop/components/shop-iframe-dialog.tsx`
- `features/shop/components/shop-package-page/shop-package-header.tsx`

### SB-15: Merch browse (8)

- `features/merch-store/components/balance-pill.tsx`
- `features/merch-store/components/browse/filter-disclosure.tsx`
- `features/merch-store/components/cart-button.tsx`
- `features/merch-store/components/catalog/index.tsx`
- `features/merch-store/components/merch-state.tsx`
- `features/merch-store/components/quantity-stepper.tsx`
- `features/merch-store/components/store-hero.tsx`
- `features/merch-store/components/toast.tsx`

### SB-16: Merch product, cart and checkout (6)

- `features/merch-store/components/cart/cart-states.tsx`
- `features/merch-store/components/cart/index.tsx`
- `features/merch-store/components/cart/insufficient-sc.tsx`
- `features/merch-store/components/checkout/index.tsx`
- `features/merch-store/components/checkout/out-of-stock-modal.tsx`
- `features/merch-store/components/product/index.tsx`

### SB-17: Merch order and modals (7)

- `features/merch-store/components/desktop-modal.tsx`
- `features/merch-store/components/ineligible-modal/index.tsx`
- `features/merch-store/components/order/action.tsx`
- `features/merch-store/components/order/confirmation.tsx`
- `features/merch-store/components/order/layout.tsx`
- `features/merch-store/components/order/summary.tsx`
- `features/merch-store/components/welcome-modal/index.tsx`

### SB-18: Auth sign-in and register (8)

- `features/auth/components/auth-page/auth-tabs.tsx`
- `features/auth/components/auth-page/login-form/index.tsx`
- `features/auth/components/auth-page/password-field.tsx`
- `features/auth/components/auth-page/register-flow.tsx`
- `features/auth/components/auth-page/register-steps/step-one/index.tsx`
- `features/auth/components/auth-page/register-steps/step-two/index.tsx`
- `features/auth/components/auth-page/validation-help.tsx`
- `features/auth/components/forms/forgot-password-form.tsx`

### SB-19: Auth forms and form controls (8)

- `features/auth/components/account-locked-alert.tsx`
- `features/auth/components/forms/change-email-form.tsx`
- `features/auth/components/forms/change-phone-form.tsx`
- `features/auth/components/forms/change-username-form.tsx`
- `features/auth/components/forms/form-controls/form-button.tsx`
- `features/auth/components/forms/form-controls/form-input.tsx`
- `features/auth/components/forms/form-controls/info-display.tsx`
- `features/auth/components/forms/form-controls/password-input.tsx`

### SB-20: Account page and account settings (7)

- `features/auth/components/account-dialog/account-settings/update-email/common-otp-form.tsx`
- `features/auth/components/account-dialog/account-settings/update-email/email-confirmed-status.tsx`
- `features/auth/components/account-dialog/account-settings/update-phone/common-phone-otp-form.tsx`
- `features/auth/components/account-page/account-list-item.tsx`
- `features/auth/components/account-page/account-modal-header/index.tsx`
- `features/auth/components/account-page/account-page.tsx`
- `features/auth/components/account-page/deactivate-account-modal/index.tsx`

### SB-21: Auth verification dialogs (6)

- `features/auth/components/common/otp-verification-modal.tsx`
- `features/auth/components/common/phone-otp.tsx`
- `features/auth/components/login-required-modal/index.tsx`
- `features/auth/components/reset-password-modal/index.tsx`
- `features/auth/components/verify-email-dialog/index.tsx`
- `features/auth/components/verify-number-otp/index.tsx`

### SB-22: MFA challenge (7)

- `features/mfa/components/challenge/index.tsx`
- `features/mfa/components/challenge/login-code-sent-toast.tsx`
- `features/mfa/components/challenge/login-code-step.tsx`
- `features/mfa/components/shared/mfa-error-state.tsx`
- `features/mfa/components/shared/mfa-resend-code.tsx`
- `features/mfa/components/shared/mfa-support-link.tsx`
- `features/mfa/components/shared/turnstile-host.tsx`

### SB-23: MFA flows and KYC (6)

- `features/kyc/components/kyc-required-dialog/index.tsx`
- `features/kyc/components/verify-button/index.tsx`
- `features/mfa/components/account/mfa-account-row.tsx`
- `features/mfa/components/disable/index.tsx`
- `features/mfa/components/prompt/index.tsx`
- `features/mfa/components/setup/index.tsx`

### SB-24: Affiliate campaigns (8)

- `features/affiliate-program/components/affiliate-tabs/index.tsx`
- `features/affiliate-program/components/campaigns/components/crypto-campaigns.tsx`
- `features/affiliate-program/components/campaigns/components/new-campaign-modal/index.tsx`
- `features/affiliate-program/components/campaigns/components/social-campaigns.tsx`
- `features/affiliate-program/components/campaigns/primitives/campaign-details-stats.tsx`
- `features/affiliate-program/components/campaigns/primitives/referral-link-cell.tsx`
- `features/affiliate-program/components/campaigns/primitives/stat-item.tsx`
- `features/affiliate-program/components/contact-us/contact-us-form.tsx`

### SB-25: Affiliate commissions and funds (6)

- `features/affiliate-program/components/commissions/crypto-commission.tsx`
- `features/affiliate-program/components/commissions/social-casino.tsx`
- `features/affiliate-program/components/funds/components/rewards-table.tsx`
- `features/affiliate-program/components/funds/components/social-funds-footer.tsx`
- `features/affiliate-program/components/funds/funds-table.tsx`
- `features/affiliate-program/components/funds/primitives/amount-with-coin.tsx`

### SB-26: Affiliate users and retention (4)

- `features/affiliate-program/components/referred-users/primitives/label-value.tsx`
- `features/affiliate-program/components/referred-users/referred-user-table.tsx`
- `features/affiliate-program/components/retention-program/crypto-retention-program.tsx`
- `features/affiliate-program/components/retention-program/social-retention-program.tsx`

### SB-27: Cards tournaments shell (4)

- `features/spinquest-cards/components/tournaments-page/hero/tournament-hero-card/index.tsx`
- `features/spinquest-cards/components/tournaments-page/overview/leader-podium/index.tsx`
- `features/spinquest-cards/components/tournaments-page/shell/tournament-tabs/index.tsx`
- `features/spinquest-cards/components/tournaments-page/shell/tournaments-page-shell/index.tsx`

### SB-28: Cards tournaments tabs (5)

- `features/spinquest-cards/components/tournaments-page/battles/battles-tab/index.tsx`
- `features/spinquest-cards/components/tournaments-page/leaderboard/leaderboard-row/index.tsx`
- `features/spinquest-cards/components/tournaments-page/leaderboard/leaderboard-tab/index.tsx`
- `features/spinquest-cards/components/tournaments-page/modals/replay-modal/index.tsx`
- `features/spinquest-cards/components/tournaments-page/modals/terms-conditions-modal/index.tsx`

### SB-29: Cards collection and card info (8)

- `features/spinquest-cards/components/card-info-page/card-affinity-info-overlay/index.tsx`
- `features/spinquest-cards/components/card-info-page/card-info-card.tsx`
- `features/spinquest-cards/components/card-info-page/card-info-content.tsx`
- `features/spinquest-cards/components/card-info-page/card-info-header.tsx`
- `features/spinquest-cards/components/my-cards/collection-view.tsx`
- `features/spinquest-cards/components/my-cards/pick-collection-card-dialog/pick-collection-card-dialog.tsx`
- `features/spinquest-cards/components/my-cards/pick-deck-slot-dialog/pick-deck-slot-dialog.tsx`
- `features/spinquest-cards/components/my-cards/picker-dialog-shell/picker-dialog-shell.tsx`

### SB-30: Cards home (6)

- `features/casino/components/lobby-view/product-lobby-hero-cards.tsx`
- `features/spinquest-cards/components/cards-ftue/ftue-anchor/ftue-anchor.tsx`
- `features/spinquest-cards/components/common/card-menu-section/card-menu-section.tsx`
- `features/spinquest-cards/components/common/cards/cards.tsx`
- `features/spinquest-cards/components/home/cards-hero-cta/index.tsx`
- `features/spinquest-cards/components/shared/cards-page-surface/index.tsx`

### SB-31: Landing (live) (9)

- `features/landing/landing-page.tsx`
- `features/landing/primitives/official-rules-link/index.tsx`
- `features/landing/primitives/official-rules-link/official-rules-content.tsx`
- `features/landing/variants/legacy-home/components/footer/index.tsx`
- `features/landing/variants/legacy-home/components/navbar/index.tsx`
- `features/landing/variants/legacy-home/components/section1/index.tsx`
- `features/landing/variants/legacy-home/components/section2/index.tsx`
- `features/landing/variants/legacy-home/components/section3/index.tsx`
- `features/landing/variants/legacy-home/index.tsx`

### SB-32: Landing promotion (5)

- `features/landing-promotion/components/games/index.tsx`
- `features/landing-promotion/components/home-card/index.tsx`
- `features/landing-promotion/components/secured-payment/index.tsx`
- `features/landing-promotion/components/social-banner/index.tsx`
- `features/landing-promotion/components/testimonials/index.tsx`

### SB-33: Location, language, notifications and terms (8)

- `features/language/components/language-modal/language-modal.tsx`
- `features/location/components/gold-coins-only-purchase-warning-modal/index.tsx`
- `features/location/components/location-permission/location-permission-dialog.tsx`
- `features/notifications/components/free-spin-modal/index.tsx`
- `features/notifications/components/notification-modal/index.tsx`
- `features/notifications/components/notifications-popover/index.tsx`
- `features/terms/components/terms-document-body.tsx`
- `features/terms/components/terms-email-notice.tsx`

### SB-34: Vault and VIP (9)

- `features/vault/components/common/coin-input.tsx`
- `features/vault/components/common/currency-toggle.tsx`
- `features/vault/components/vault-modal/deposit.tsx`
- `features/vault/components/vault-modal/withdraw.tsx`
- `features/vip-club/components/overview/all-ranks/index.tsx`
- `features/vip-club/components/overview/leveling-system/index.tsx`
- `features/vip-club/components/overview/user-level/index.tsx`
- `features/vip-club/components/rank-medals/index.tsx`
- `features/vip-club/components/vip-side-bar/index.tsx`

### SB-35: Transactions and history (8)

- `features/transactions/components/common/transaction-tabs.tsx`
- `features/transactions/components/common/transactions-list.tsx`
- `features/transactions/components/deposits/deposits-table.tsx`
- `features/transactions/components/withdrawals/withdrawals-table.tsx`
- `features/user-history/components/common/history-common.tsx`
- `features/user-history/components/history-card.tsx`
- `features/user-history/components/history-mobile/index.tsx`
- `features/user-history/components/history-table/index.tsx`

### SB-36: Sports, promotions and AMOE (6)

- `features/amoe/components/amoe-content/index.tsx`
- `features/promotions/components/daily-bonus-banner.tsx`
- `features/promotions/components/first-time-offer-banner.tsx`
- `features/sports/components/event-accordion/index.tsx`
- `features/sports/components/side-search-bar/index.tsx`
- `features/sports/components/sports-cta/index.tsx`
