# Storybook setup and redeem pilot: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade Storybook to 10.x and make it run without a backend, with fake data, fixed sign-in state, a language dropdown, story tests in CI and internal hosting. Then cover the UI tier and the redeem pilot (SB-00a to SB-03).

**Architecture:**
- **Providers.** The preview renders the app's side-effect-free `CoreProviders`, which `AppProvider` also uses.
- **Fixtures.** A fixture adapter on the shared `api` axios instance, installed in the global `beforeEach`, serves each story's `parameters.api`.
- **State.** Presets seed zustand stores, and `withFlags` replaces `posthog.getFeatureFlag`.
- **Story tests.** `@storybook/addon-vitest` runs every story in headless Chromium, with a11y in report-only mode.
- **To-do list.** A test builds the import graph and keeps the to-do list exact.
- **Hosting.** Storybook is served from `main` as an nginx image.

**Tech Stack:** Storybook 10.x (react-vite), `storybook/test`, `@storybook/addon-vitest` with Vitest browser mode (Playwright Chromium), React 18, MUI 5, TanStack Query, zustand 4.5, axios, i18next, Vitest 3, GitHub Actions, Docker/nginx.

**Spec:** [2026-11-19-storybook-stories-design.md](./2026-11-19-storybook-stories-design.md)

**Repo:** `spinquest-frontend`. Every path and command in this plan is relative to that repo.

## Global Constraints

- **Packages:**
  - Storybook 10.x, pinned exactly to what `storybook upgrade` resolves within the `pnpm-workspace.yaml` policies.
  - `@storybook/addon-vitest` and the browser-mode provider its installer adds.
  - Nothing else, and never `msw`.
  - Play functions import from `storybook/test`.
- **Env:**
  - Storybook reads only `.storybook/env/.env`, never the repo-root `.env`.
  - Its values are `VITE_APP_PRODUCT=casino`, `VITE_APP_ENABLE_SERVER_FLAGS=false`, `VITE_APP_ENABLE_POSTHOG=false`, `VITE_APP_ENABLE_SENTRY=false` and `VITE_APP_USE_MERCH_MOCKS=false`, plus a dummy value for every other key `src/config/env.ts` requires.
- **Scope:**
  - A component gets a story file when it is reachable from `src/main.tsx`, public, and not a screen. That is about 245 files.
  - **Public** means imported from two or more files, from one file outside its own folder, or a top-level modal.
  - **Screens** are route entries under `src/features`. They get no story, and their direct children count as public.
  - **Private sub-pieces** are covered by their parent's stories.
  - `UNSTORIED` (Task 8) lists exactly the files each batch must story.
- **Story files:**
  - A story file sits beside its component and uses CSF3. `meta` sets `title` and `component`, and is the default export.
  - UI and Shared metas add `tags: ['autodocs']`.
  - Stories are typed `StoryObj<typeof Component>`.
  - Export names are state names: `Default`, `Loading`, `Error`, `Empty`, `Mobile320`, `German`, and variant names.
  - Shared args go in meta `args`, and variants spread them. Use `render` only for what args can't express.
  - A story that can't run in the test browser gets `tags: ['!test']`, with a comment giving the reason.
- **Titles:** `UI/<Name>`, `Shared/<Name>`, `Shared/Layouts/<Name>` and `Features/<Feature>/<Name>`. Sidebar order is `['UI', 'Shared', 'Features', '*']`.
- **Fixtures:**
  - No story reaches the network. A request without a fixture fails the story, naming its key.
  - No fixture returns a 401 or a gate code (MFA, geo).
  - Error fixtures use the backend's error shape, including `code`.
  - Shared fixtures go in `src/fixtures/<domain>`, typed with the real response types.
- **Strings:** component text goes through i18n. Story-only labels may be literal.
- **Repo conventions:** named exports (except Storybook `meta`), UPPER_SNAKE constants, and `interface` for props, named `<Name>Props`.
- **PRs:** one PR per batch. Story PRs add at most 30 stories. Each batch has one Linear sub-issue under the Storybook parent issue.
- **Before every PR:** `pnpm lint`, `pnpm typecheck` and `pnpm storybook:build` pass. From SB-00b on, so do `pnpm test:storybook` and `pnpm vitest run --project=unit .storybook`.

## Order, pausing and resuming

- **SB-00a, then SB-00b.** After those, SB-00c, SB-01a, SB-01b, SB-02 and SB-03 each depend only on them, and can land in any order. SB-00c needs only SB-00a.
- **Every task ends in a commit that leaves `main` green.** Stopping between any two tasks is safe.
- **Partial PRs.** A story PR may merge part of its batch. The rest stays in `UNSTORIED`.
- **Resuming** means picking any batch whose files are still in `UNSTORIED`.

## Story checklist

| Component | Stories |
|---|---|
| Every component | `Default`, and one story per meaningful prop variant |
| Reads data | + `Loading` (fixture `respond({ delay: 'never' })`), `Error` (with Retry), `Empty` |
| Layout-sensitive | + `Mobile320` (`globals: { viewport: { value: 'mobile320' } }`), `German` (`globals: { locale: 'de' }`) |
| Has behaviour | + a `play` function that drives the behaviour and asserts the outcome |

**Play functions:**

- Import `expect`, `userEvent`, `within`, `waitFor` and `fn` from `storybook/test`.
- Query by role and name.
- Use `screen` for MUI dialogs, popovers and menus.
- Callbacks are `fn()` spies.

**Parents and sub-pieces.** A parent's stories reach its private sub-pieces' states.

**a11y.** It is report-only. Ticket each violation inside a component, and note the ticket in that story's `parameters.docs.description`.

## Review Focus

1. **Request with no fixture.** The story must fail, and the message must name `"METHOD /path"`. Pinned in Task 4 (unit test) and Task 7 (probe story).
2. **State leaking between stories.** A story after a `signedIn` story must start signed out, with empty storage. Pinned in Task 5.
3. **Language leaking between stories.** A `German` story must not leave the next story in German. Pinned in Task 6: an unset locale resolves to English.
4. **Real keys in the hosted build.** No value from the root `.env` may appear in `storybook-static`. Pinned in Task 2, Step 7.
5. **Fixture bodies with a `status` field.** A redemption with `status: 'PENDING'` is data, not an HTTP status. Pinned in Task 4.

---

## PR SB-00a: upgrade and start

Branch: `chore/storybook-sb-00a`, from `main`. This PR fixes [SQ-1154](https://linear.app/social-gaming-room/issue/SQ-1154/bugfix-get-storybook-in-spinquest-frontend-rendering-stories-again). Link the issue in the PR.

### Task 1: Extract `CoreProviders`

**Files:**
- Create: `src/app/providers/core-providers.tsx`
- Modify: `src/app/providers/index.tsx`
- Test: `src/app/providers/core-providers.test.tsx`

**Interfaces:**
- Produces: `export const CoreProviders = ({ children }: CoreProvidersProps) => JSX.Element`, with `interface CoreProvidersProps { children: React.ReactNode }`.
- Nesting, outermost first:
  1. `StyledEngineProvider`
  2. `ThemeProvider` (`theme` from `@/lib/theme`)
  3. `I18nextProvider` (`i18n` from `@/lib/i18n`)
  4. `HelmetProvider`
  5. `DialogsProvider`
  6. `CookiesProvider` (`defaultSetOptions={{ path: '/' }}`)

- [ ] **Step 1: Write the failing test.** `describe('CoreProviders')`, with `it('provides theme, i18n, dialogs and helmet to children')`:
  - Render a probe inside `CoreProviders`.
  - The probe calls `useTheme()`, `useTranslation()` (from `@/hooks/translation/use-translation`) and `useDialogs()`, and renders `<Helmet><title>probe</title></Helmet>`.
  - Assert that it renders, that `useDialogs()` returns an object with an `open` function, and that `useTheme().palette.primary.main` equals `theme.palette.primary.main` from `@/lib/theme`.
  - Mock `@/lib/i18n` to the test i18next instance.
- [ ] **Step 2: Run** `pnpm vitest run src/app/providers/core-providers.test.tsx`. Expect FAIL, because the module isn't found.
- [ ] **Step 3: Implement `CoreProviders`.** `AppProvider` then renders, outermost first:
  1. `PostHogProviderWrapper`
  2. `FlagsSync`, beside `CoreProviders`
  3. `CoreProviders`, wrapping `SocketProvider`
  4. `NotificationsSocketProvider`
  5. `ReferralCodeProvider`
  6. `children`

  `AppToastContainer`, the merch toasts, the dev devtools and every effect in `AppProvider` stay where they are, inside the i18n scope.
- [ ] **Step 4: Run** `pnpm vitest run src/app/providers` and `pnpm typecheck`. Expect PASS.
- [ ] **Step 5: Commit.** `refactor(providers): extract side-effect-free CoreProviders`

### Task 2: Upgrade Storybook, config, placeholder env and preview

**Files:**
- Modify:
  - `package.json` and `pnpm-lock.yaml`: Storybook 10.x and `eslint-plugin-storybook` to match. Scripts: `lint` becomes `eslint src .storybook`, `storybook` becomes `cross-env VITE_APP_PRODUCT=casino storybook dev -p 6006`, and `storybook:build` becomes `cross-env VITE_APP_PRODUCT=casino storybook build`.
  - `tsconfig.json`: `moduleResolution: "bundler"`, and `".storybook"` in `include`.
  - The 7 existing story files: imports and types for 10.x.
- Create:
  - `.storybook/env/.env`
  - `.storybook/decorators/story-providers.tsx`
  - `.storybook/viewports.ts`
- Rewrite:
  - `.storybook/main.ts`: ESM, `export default`, typed `StorybookConfig`.
  - `.storybook/preview.tsx`

**Interfaces:**
- Consumes: `CoreProviders` from Task 1.
- Produces:
  - `export const withStoryProviders: Decorator`. It renders `CoreProviders` around these:
    - a `QueryClientProvider` with a fresh `QueryClient({ defaultOptions: { queries: { retry: false, refetchOnWindowFocus: false }, mutations: { retry: false } } })`, created per story mount with `useState`
    - a `MemoryRouter` configured by `parameters.router?: { initialEntries?: string[]; path?: string }`. With `path`, the story renders inside `<Routes><Route path={path} element={story} /></Routes>`.
    - `AppToastContainer`
  - `export const STORY_VIEWPORTS`:
    - `mobile320`: `{ name: 'Mobile 320', styles: { width: '320px', height: '640px' } }`
    - `mobile375`: `{ name: 'Mobile 375', styles: { width: '375px', height: '812px' } }`

- [ ] **Step 1: Upgrade.**
  - Run `pnpm dlx storybook@10 upgrade`.
  - Accept its automigrations for 8 → 9 → 10. Decline any that add addons this plan doesn't list.
  - Pin every `storybook` and `@storybook/*` version exactly.
  - Remove `@storybook/addon-essentials`, `@storybook/addon-actions`, `@storybook/addon-links` and `@storybook/node-logger`.
  - Make `@storybook/addon-docs` a direct devDependency at the same pinned version. Today `main.ts` lists it without it being installed, which is the first SQ-1154 failure.
  - Update `eslint-plugin-storybook` to the matching version. If that version doesn't support the legacy `.eslintrc.cjs`, keep 0.8, say so in the PR and file a ticket.
  - If the `pnpm-workspace.yaml` policies refuse a version, take the newest one they accept, and record it.
- [ ] **Step 2: Switch module resolution.**
  - Set `moduleResolution` to `"bundler"`, run `pnpm typecheck` and fix the fallout.
  - If that takes more than about 2 hours, stop and report the error count and the kinds of errors.
- [ ] **Step 3: Write `main.ts`.**
  - The first line is `process.env.VITE_APP_PRODUCT ??= 'casino';`.
  - `stories: ['../src/**/*.stories.@(ts|tsx)', './checks/*.stories.tsx']`.
  - `addons: ['@storybook/addon-docs', '@storybook/addon-a11y']`. Task 7 adds `@storybook/addon-vitest`.
  - `framework: { name: '@storybook/react-vite', options: {} }`.
  - `staticDirs: ['../public']`.
  - `typescript: { reactDocgen: 'react-docgen' }`.
  - `viteFinal` sets `envDir` to the absolute path of `.storybook/env`.
- [ ] **Step 4: Write `.storybook/env/.env`.**
  - It holds every key `EnvSchema` requires, with placeholders such as `VITE_APP_API_URL=http://storybook.invalid`, plus the five values in Global Constraints.
  - No real key may appear.
- [ ] **Step 5: Write `preview.tsx`.**
  - `decorators: [withStoryProviders]`.
  - `parameters.options.storySort.order: ['UI', 'Shared', 'Features', '*']`.
  - `parameters.docs.story.inline: false`.
  - `parameters.viewport.options: STORY_VIEWPORTS`.
  - No `parameters.actions.argTypesRegex`, and no `app-provider` import.
- [ ] **Step 6: Verify the stories render.**
  - Run `pnpm storybook`, open each of the 7 existing stories in the browser pane, and check the console.
  - Expect every story to render, and no `Invalid env provided` error. That error is the third SQ-1154 failure.
  - If it still appears, find out where Storybook's Vite config loses the env before changing anything else:
    - Log `config.envDir`, `config.envPrefix` and `config.define` from `viteFinal`.
    - Check whether `vite.config.ts`'s `loadEnv`/`define` block is applied.
  - Record the cause in the PR body.
  - Then run `pnpm storybook:build`. Expect success, with `storybook-static/index.json` listing the 7 stories.
- [ ] **Step 7: Verify that no real key leaks.**
  - Run ``grep -rlF "$(grep '^VITE_APP_SENTRY_DSN=' .env | cut -d= -f2-)" storybook-static``. Expect no output.
  - If the local `.env` has no such key, use any other `VITE_APP_*` value from it.
- [ ] **Step 8: Verify the rest.** Run `pnpm lint`, `pnpm typecheck` and `pnpm test`. Expect PASS.
- [ ] **Step 9: Commit,** in two commits:
  - `chore(storybook): upgrade to Storybook 10` (Steps 1–2)
  - `chore(storybook): ESM config, placeholder env and story providers`

### Task 3: CI job

**Files:** Modify `.github/workflows/build.yaml`.

- [ ] **Step 1: Add the `storybook` job.**
  - `if: github.event_name == 'pull_request'`, `runs-on: ubuntu-latest`, `permissions: contents: read`.
  - Steps:
    1. Check out the PR head SHA, using the `build` job's pinned checkout action.
    2. Set up Node 24 with `actions/setup-node`, and pnpm with `pnpm/action-setup`, both pinned as in `deploy-main.yaml`.
    3. `pnpm install --frozen-lockfile`
    4. `pnpm typecheck`
    5. `pnpm storybook:build --test`
- [ ] **Step 2: Verify.**
  - Push the branch and open the SB-00a PR.
  - Check that the `storybook` job is green, and put its run URL in the PR body.
- [ ] **Step 3: Commit.** `ci(storybook): build Storybook and typecheck on pull requests`

---

## PR SB-00b: data, checks and the to-do list

Branch: `chore/storybook-sb-00b`, from `main` after SB-00a merges.

### Task 4: Fixture adapter

**Files:**
- Create: `.storybook/fixtures/fixture-adapter.ts`
- Test: `.storybook/fixtures/fixture-adapter.test.ts`
- Modify: `vite.config.ts` `test.include`, adding `'.storybook/**/*.test.ts'`.

**Interfaces:**
- Produces:
  - `export type FixtureMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE'`
  - `export type FixtureKey = \`${FixtureMethod} /${string}\``
  - `export interface FixtureResponse { status?: number; data?: unknown; delay?: number | 'never' }`
  - `export const respond = (response: FixtureResponse): BrandedFixtureResponse`. The brand is a module-private symbol.
  - `export type ApiFixtures = Partial<Record<FixtureKey, unknown>>`
  - `export const createFixtureAdapter = (fixtures: ApiFixtures): AxiosAdapter`
  - `export const installFixtureAdapter = (fixtures: ApiFixtures): (() => void)`. It swaps `api.defaults.adapter` (`api` from `@/lib/api/api-client`) and returns the restore function.
  - `export const takeFixtureMisses = (): string[]`. It returns the keys of unmatched requests since the last call, and clears them.
- Key rules:
  - A request's key is `METHOD + ' ' + pathname`. The pathname comes from `axios.getUri(config)`, with `baseURL` and the query string removed.
  - A fixture key containing `?` matches the pathname plus query exactly, and is tried first.

- [ ] **Step 1: Write the failing tests.** In `describe('createFixtureAdapter')`:
  - `it('resolves a plain value with status 200 and the value as data')`
  - `it('treats a plain body with its own status field as data')`: the fixture `{ id: 'r1', status: 'PENDING' }` resolves with `response.status === 200` and `response.data.status === 'PENDING'`.
  - `it('rejects with an AxiosError carrying status and data for respond({ status: 422, data })')`
  - `it('matches a ?query key exactly before the bare path')`
  - `it('ignores the query string for a bare-path key')`
  - `it('never settles for delay: "never"')`: race it against a 50 ms timer, and the timer wins.
  - `it('rejects an unmatched request and logs console.error naming "GET /users/me"')`
  - `it('records the miss for takeFixtureMisses and clears it after reading')`

  In `describe('installFixtureAdapter')`:
  - `it('restores the original api adapter on cleanup')`
- [ ] **Step 2: Run** `pnpm vitest run .storybook/fixtures`. Expect FAIL, because the module isn't found.
- [ ] **Step 3: Implement.**
  - A status of 400 or more rejects with `new AxiosError(message, AxiosError.ERR_BAD_RESPONSE, config, {}, response)`.
  - An unmatched request is logged with `console.error('[storybook fixtures] No fixture for "<key>"')`, recorded, and rejected with code `'ERR_NO_FIXTURE'`.
- [ ] **Step 4: Run** the same tests. Expect PASS.
- [ ] **Step 5: Commit.** `feat(storybook): fixture adapter for the shared api client`

### Task 5: Storage reset, sign-in presets and flags

**Files:**
- Create:
  - `src/fixtures/user.ts`
  - `src/fixtures/balance.ts`
  - `.storybook/presets/storage.ts`
  - `.storybook/presets/session.ts`
  - `.storybook/presets/flags.ts`
- Test: `.storybook/presets/presets.test.ts`
- Modify: `.storybook/preview.tsx`

**Interfaces:**
- Produces:
  - `export const USER_FIXTURE: User`, typed with `User` from `@/types/user`.
  - `export const BALANCE_FIXTURE: GetBalance200`, typed with the type `src/store/balance.ts` imports.
  - `export const clearStorage = (): void`. It clears `localStorage` and `sessionStorage`.
  - `export const STORY_AUTH_TOKEN = 'storybook-token'`
  - `export const signedIn = (): (() => void)`.
    - It sets `authStore` to `{ user: USER_FIXTURE, authToken: STORY_AUTH_TOKEN }`, and calls `useBalanceStore.getState().setBalance(BALANCE_FIXTURE)`.
    - Its cleanup resets both stores to `getInitialState()`, in replace mode.
  - `export const signedOut = (): (() => void)`. It resets both stores and returns a no-op.
  - `export const withFlags = (flags: Record<string, string | boolean>) => (): (() => void)`.
    - It replaces `posthog.getFeatureFlag` (from `posthog-js`) with a lookup in `flags`. A missing key returns `undefined`.
    - Cleanup restores the original.

- [ ] **Step 1: Write the failing tests:**
  - `it('clearStorage empties localStorage and sessionStorage')`
  - `it('signedIn makes hasAuthSession() true and its cleanup makes it false')`
  - `it('signedIn cleanup restores the balance store initial state')`
  - `it('withFlags makes getFlag return the seeded value, and the fallback after cleanup')`: `getFlag('storybook-test-flag', false)` from `@/lib/analytics` is `true`, then `false`.
  - `it('withFlags leaves ops- keys at their fallback')`
- [ ] **Step 2: Run** `pnpm vitest run .storybook/presets`. Expect FAIL.
- [ ] **Step 3: Implement** the fixtures and the three modules.
- [ ] **Step 4: Run** the same tests. Expect PASS.
- [ ] **Step 5: Wire up the preview.**
  - A preview-level `beforeEach(context)` calls `clearStorage()` and returns `installFixtureAdapter(context.parameters.api ?? {})`.
  - A preview-level `afterEach` throws ``new Error(`Requests with no fixture: ${misses.join(', ')}`)`` when `takeFixtureMisses()` is not empty.
- [ ] **Step 6: Commit.** `feat(storybook): storage reset, signedIn/signedOut and withFlags presets`

### Task 6: Language dropdown

**Files:**
- Create:
  - `.storybook/locale.ts`
  - `.storybook/checks/locale.stories.tsx`
- Test: `.storybook/locale.test.ts`
- Modify: `.storybook/preview.tsx`

**Interfaces:**
- Produces:
  - `export const LOCALE_TOOLBAR_ITEMS = languages.map(({ code, label }) => ({ value: code, title: label }))`, with `languages` from `@/features/language/utils/options`.
  - `export const DEFAULT_LOCALE = LanguageCode.English`
  - `export const resolveLocale = (value: unknown): LanguageCode`. It returns `value` if it is a known `LanguageCode`, and `DEFAULT_LOCALE` otherwise.
  - `export const withLocale: Decorator`. When `i18n.language` differs from `resolveLocale(context.globals.locale)`, it calls `i18n.changeLanguage`, then renders the story.

- [ ] **Step 1: Write the failing tests:**
  - `it('builds one toolbar item per app language, in the picker order with its labels')`: the items deep-equal `languages` mapped to `{ value, title }`, and the first title is `'普通话'`.
  - `it('resolves an unset or unknown locale to English')`
  - `it('resolves "de" to German')`
- [ ] **Step 2: Run** `pnpm vitest run .storybook/locale.test.ts`. Expect FAIL.
- [ ] **Step 3: Implement** `locale.ts`. In `preview.tsx`:
  - Add `globalTypes.locale = { description: 'Language', toolbar: { title: 'Language', icon: 'globe', items: LOCALE_TOOLBAR_ITEMS, dynamicTitle: true } }`.
  - Add `initialGlobals: { locale: DEFAULT_LOCALE }`.
  - Prepend `withLocale` to `decorators`.
- [ ] **Step 4: Add the check story.** `.storybook/checks/locale.stories.tsx` is tagged `['!dev', '!autodocs']`, so it only runs in tests.
  - It renders `t('<key>')` for one key present in both `en.json` and `de.json`.
  - Its `German` story sets `globals: { locale: 'de' }`, and its `play` asserts the German string. That also proves `/locales` loads in the test browser.
- [ ] **Step 5: Run** the tests and `pnpm storybook:build`. Expect PASS.
- [ ] **Step 6: Commit.** `feat(storybook): language dropdown from the app's language list`

### Task 7: Story tests and CI

**Files:**
- Install: run `pnpm storybook add @storybook/addon-vitest`. It adds the addon, the browser-mode provider, `.storybook/vitest.setup.ts` and a test project.
- Modify:
  - `vite.config.ts` `test`: two projects.
    - `unit`: today's jsdom configuration, including `.storybook/**/*.test.ts`.
    - `storybook`: `storybookTest({ configDir: '.storybook' })`, in browser mode with headless Chromium.
  - `package.json` scripts: `"test": "vitest run --project=unit"` and `"test:storybook": "vitest run --project=storybook"`.
  - `.storybook/preview.tsx`: `parameters.a11y.test: 'todo'`.
  - `.github/workflows/build.yaml`: the `storybook` job runs these after the build:
    1. `pnpm exec playwright install --with-deps chromium`
    2. `pnpm test:storybook`
    3. `pnpm vitest run --project=unit .storybook`

**Interfaces:**
- Consumes: the preview annotations from Tasks 2, 5 and 6, and `takeFixtureMisses` from Task 4.

- [ ] **Step 1: Install and configure.** Follow the installer, then shape the configuration into the two projects above. `pnpm test` must keep running exactly the existing unit tests.
- [ ] **Step 2: Run** `pnpm test:storybook`.
  - Expect PASS for the 7 existing stories and the locale check.
  - If the locale check fails, `staticDirs` or the placeholder env isn't reaching the test project. Fix that before going on.
- [ ] **Step 3: Prove a missing fixture fails (G1).**
  - Add a throwaway `src/components/ui/spinner/probe.stories.tsx` whose component calls `api.get('/storybook/missing')` on mount.
  - Run `pnpm test:storybook`. Expect FAIL with `Requests with no fixture: GET /storybook/missing`.
  - Delete the probe.
- [ ] **Step 4: Check a11y reporting.**
  - Give an existing story an image with no `alt`.
  - Run `pnpm test:storybook`. Expect PASS, with the violation reported.
  - Revert.
- [ ] **Step 5: Check docs-page isolation by hand.**
  - In `pnpm storybook`, put two stories with different `parameters.api` on one docs page.
  - Confirm each shows its own data, and record the result in the PR body.
- [ ] **Step 6: Run** `pnpm test:storybook`, `pnpm test`, `pnpm lint` and `pnpm typecheck`. Expect PASS.
- [ ] **Step 7: Commit.** `test(storybook): run every story in Chromium with the Vitest addon`

### Task 8: The to-do list

**Files:**
- Create:
  - `.storybook/import-graph.ts`
  - `.storybook/unstoried.ts`
- Test:
  - `.storybook/import-graph.test.ts`
  - `.storybook/unstoried.test.ts`

**Interfaces:**
- Produces, in `.storybook/import-graph.ts`:
  - `buildImportGraph(sources: Record<string, string>): Map<string, Set<string>>`. It maps each file to the files it imports.
    - It covers static `import` and `export … from`, and dynamic `import()`.
    - It resolves `@/` and relative specifiers, including `index.ts(x)`, and looks through `index.ts` barrels.
    - It adds both `product-lobby-hero` variants for the alias in `vite.config.ts`.
  - `reachableFrom(entry: string, graph): Set<string>`
  - `findScreens(sources: Record<string, string>, graph): Set<string>`. It returns the `.tsx` files under `src/features` that a `route.factory.ts(x)` or `src/app/routes/index.tsx` loads with `import()`.
  - `isInScope(file: string, graph, screens: Set<string>): boolean`. The file is reachable, is not a screen, and is public.
    - **Public:** imported from two or more files, or from one file outside its parent folder, or from a screen.
    - **Private:** a file with exactly one importer, where that importer is not a screen and sits in the same folder or under the file's parent folder.
- Produces, in `.storybook/unstoried.ts`:
  - `export type BatchId = \`SB-${string}\``
  - `export const UNSTORIED: Record<BatchId, readonly string[]>`. In-scope files without a story, grouped by the spec's batch IDs (`SB-01a` to `SB-35`).
  - `export const NOT_STORIED: Record<string, string>`. Each path maps to its reason: the spec's non-visual files, skeletons, loaders, wrappers and icon sets.
  - `export const COVERED_BY: Record<string, string>`. Each path maps to the story file that covers it, for example a `mobile.tsx` and its pair.
- Rules:
  - **Component file:** a `.tsx` under `src/components` or `src/features` that is not `*.test.tsx`, `*.stories.tsx` or `styles.tsx`.
  - **Storied:** `<folder>/<basename>.stories.tsx` exists, or the file is a key in `COVERED_BY`.
  - **Source text:** the test reads every source file with `import.meta.glob('/src/**/*.{ts,tsx}', { query: '?raw', import: 'default', eager: true })`.

- [ ] **Step 1: Write the graph tests.** In `describe('import graph')`:
  - `it('resolves @/ and relative specifiers and index barrels')`
  - `it('follows dynamic import() for reachability')`
  - `it('treats a file imported only by a sibling as private')`
  - `it('treats a file imported from two files as public')`
  - `it('treats a file imported only from another feature folder as public')`
  - `it('treats a route entry under src/features as a screen and leaves it out')`
  - `it('treats a screen's direct child as public')`
- [ ] **Step 2: Write the list tests,** each naming the offending path:
  - `it('every in-scope file is storied or listed')`
  - `it('no file in UNSTORIED already has a story')`
  - `it('every listed path exists')`
  - `it('no path appears in more than one list')`

  The test also prints how many private, unreachable and screen files it left out.
- [ ] **Step 3: Run** `pnpm vitest run --project=unit .storybook`. Expect FAIL.
- [ ] **Step 4: Implement** `import-graph.ts`.
- [ ] **Step 5: Seed `unstoried.ts`.**
  - Generate the in-scope list once, and group it by the spec's batch tables.
  - The 7 existing stories stay out of it.
  - Run the tests. Expect PASS.
- [ ] **Step 6: Prove it fails when it should (G1).** Add a throwaway `src/components/ui/spinner/probe.tsx`, then check four cases:
  1. Import it from both `spinner.tsx` and `switch.tsx`. Expect FAIL, naming `probe.tsx`.
  2. Import it from `spinner.tsx` only. Expect PASS, because it is private.
  3. Import it from nothing. Expect PASS, because it is unreachable.
  4. Add a story beside a listed file. Expect FAIL, naming that file.

  Revert everything.
- [ ] **Step 7: Report the counts and orphans.**
  - Put the in-scope, private, screen and unreachable counts in the PR body, beside the spec's 2026-11-19 scan.
  - File a dead-code ticket for each unreachable file that isn't a parked landing variant.
- [ ] **Step 8: Commit.** `test(storybook): enforced to-do list of components without stories`

### Task 9: Developer docs

**Files:** Rewrite `docs/storybook.md`.

- [ ] **Step 1: Rewrite the doc.** Describe the setup as built, with a short example for each topic in the spec's [Developer docs](./2026-11-19-storybook-stories-design.md#developer-docs) section. That includes:
  - scope and the to-do list
  - the rule that a new in-scope component ships with a story or a line in `UNSTORIED`

  Link the spec.
- [ ] **Step 2: Commit.** `docs(storybook): document the story setup`

---

## PR SB-00c: hosting

Branch: `chore/storybook-sb-00c`, from `main` after SB-00a merges.

### Task 10: Storybook image from `main`

**Files:**
- Create: `Dockerfile.storybook`
- Modify:
  - `.github/workflows/build.yaml`
  - `.dockerignore`, only if it excludes `storybook-static`

- [ ] **Step 1: Write `Dockerfile.storybook`.**
  - `FROM nginxinc/nginx-unprivileged:1.28.0-alpine`, the app's base image.
  - `COPY storybook-static /frontend`, then `COPY default.conf /etc/nginx/conf.d/default.conf`.
  - `EXPOSE 8080`.
- [ ] **Step 2: Add the `storybook-image` job.**
  - `if: github.event_name == 'push' && github.ref == 'refs/heads/main'`, with `permissions: contents: read, packages: write`.
  - Steps:
    1. Checkout.
    2. Node 24 and pnpm, pinned as in Task 3.
    3. `pnpm install --frozen-lockfile`
    4. `pnpm storybook:build`
    5. `docker/login-action` and `docker/metadata-action`, pinned as in the `build` job.
    6. `docker/build-push-action`, with `file: Dockerfile.storybook`, image `${{ env.REGISTRY }}/${{ github.repository }}-storybook`, and tags `type=raw,value=sha-{{sha}}` and `type=raw,value=latest`.
  - The build step uses no secrets.
- [ ] **Step 3: Verify locally.**
  - Run `pnpm storybook:build && docker build -f Dockerfile.storybook -t storybook-local . && docker run --rm -p 8080:8080 storybook-local`.
  - Open `http://localhost:8080`, check that Storybook loads, then stop the container.
- [ ] **Step 4: Write the DevOps ticket in the PR body.** It asks for:
  - an Argo application for `ghcr.io/<org>/spinquest-frontend-storybook:latest` on port 8080
  - an ingress at the agreed dev host (proposed: `storybook.dev.spinquest.com`)
  - access restricted like the other dev hosts, with no public access
- [ ] **Step 5: Commit.** `ci(storybook): publish the Storybook image from main`

---

## PRs SB-01a and SB-01b: UI tier

There are two PRs, each branched from `main` after SB-00b merges, and they can land in either order:

- **SB-01a**, Task 11: leaves, about 25 stories, on `chore/storybook-sb-01a`.
- **SB-01b**, Task 12: behaviour, about 25 stories, on `chore/storybook-sb-01b`.

Each story file is titled `UI/<Name>`. The 7 existing story files are brought up to the conventions in place.

| Component | PR | Stories beyond `Default` and variants |
|---|---|---|
| `button/app-button.tsx` | SB-01a | One per `variant` and `color`, plus `Disabled` |
| `button/app-loading-button.tsx` | SB-01a | `Loading` |
| `loading-button/loading-button.tsx` | SB-01a | `Loading` |
| `form/index.tsx` (covers its labeled field) | SB-01a | `WithError` |
| `image/image.tsx` | SB-01a | `BrokenSource` |
| `linear-progress/linear-progress.tsx`, `spinner/spinner.tsx`, `text-divider/text-divider.tsx` | SB-01a | — |
| `info-tooltip/info-tooltip.tsx` | SB-01b | play: hover and focus show the tooltip |
| `popover/popover.tsx` | SB-01b | play: opens on its trigger, Escape closes it, and focus returns to the trigger |
| `otp-code-input/otp-code-input.tsx` | SB-01b | play: typing 6 digits calls `onComplete` with them, and pasting fills every box |
| `slider/slider.tsx` | SB-01b | play: ArrowRight raises the value and calls `onChange` |
| `switch/switch.tsx` | SB-01b | play: a click toggles `checked` and calls `onChange` |
| `tabs/tabs.tsx` | SB-01b | play: clicking the second tab shows its panel, and ArrowRight moves focus |
| `swiper-slider/index.tsx` (covers its navigation buttons) | SB-01b | play: next and previous move the slide; plus `Mobile320` |

### Task 11: UI leaves (SB-01a)

- [ ] **Step 1: Write the stories** for the SB-01a rows.
- [ ] **Step 2: Remove from the to-do list.** Delete `UNSTORIED['SB-01a']`.
- [ ] **Step 3: Run** `pnpm test:storybook`, `pnpm vitest run --project=unit .storybook`, `pnpm lint` and `pnpm typecheck`. Expect PASS. Ticket any a11y violation inside a component.
- [ ] **Step 4: Commit and open the PR.** `docs(storybook): UI tier stories, leaves`

### Task 12: UI behaviour (SB-01b)

- [ ] **Step 1: Write the stories and play functions** for the SB-01b rows.
- [ ] **Step 2: Prove a play function can fail (G1).** In `switch.stories.tsx`, temporarily assert that `checked` is `false` after the click. Expect `pnpm test:storybook` to FAIL. Revert.
- [ ] **Step 3: Remove from the to-do list.** Delete `UNSTORIED['SB-01b']`.
- [ ] **Step 4: Run** the four checks from Task 11, Step 3. Expect PASS, and ticket any a11y violations.
- [ ] **Step 5: Commit and open the PR.** `docs(storybook): UI tier stories, behaviour`

---

## PR SB-02: redeem components

Branch: `chore/storybook-sb-02`, from `main` after SB-00b merges.

### Task 13: Redeem fixtures and stories

**Files:**
- Create:
  - `src/fixtures/wallet/`: `redemptions.ts`, `redemption-limits.ts`, `verification.ts` and `index.ts`
  - one story file beside each file in `UNSTORIED['SB-02']`, titled `Features/Wallet/<Name>`. These are the in-scope files in `src/features/wallet/components/redeem/`:
    - `new-redemption-modal/index.tsx`
    - `redeemable-balance-card.tsx`
    - `redemption-history-card.tsx`
    - `redeem-history-modal.tsx`
    - `redemption-submitted-modal.tsx`
    - `verification-checks.tsx`
    - `primitives/redeem-page-container.tsx`
    - `primitives/redeem-surface-card.tsx`

**Interfaces:**
- Consumes: `signedIn`, `respond`, `parameters.api` and the story checklist.
- Produces: fixture constants that SB-03 reuses, each typed with its response type from `src/lib/api`:
  - `REDEMPTIONS_FIXTURE`
  - `REDEMPTIONS_EMPTY_FIXTURE`
  - `REDEMPTION_LIMITS_FIXTURE`
  - `REDEMPTION_ERROR_FIXTURE`: a backend error body with `code`
  - one verification fixture per state

- [ ] **Step 1: Map the requests.**
  - Read the hooks the redeem components call: `src/features/wallet/api/use-redemption*`, `src/features/transactions/api/use-withdrawals*`, and the `@/features/auth/api` hooks.
  - List every `METHOD /path` in a comment at the top of `src/fixtures/wallet/index.ts`.
- [ ] **Step 2: Write the fixtures.** No 401s, and no MFA or geo gate codes.
- [ ] **Step 3: Write the stories.** Every story uses `beforeEach: [signedIn]`.
  - **Reads data** (`Loading`, `Error`, `Empty`): balance card, history card, history modal, verification checks.
  - **Layout-sensitive** (`Mobile320`, `German`): the four modals and the page container.
  - **Has behaviour:** `new-redemption-modal` gets these play functions:
    - An amount above the balance shows the validation message.
    - With the POST fixture set to `respond({ delay: 'never' })`, submitting disables the submit button.
    - `Error` shows the error, and Retry resends the request. Assert this with the fixture's call count or a `fn()` spy.
  - **Parents covering sub-pieces:**
    - The modal's stories reach its address and payment-method sections' validation errors.
    - A story reaches the redemption-limit modal through the flow that opens it.
  - **`verification-checks`** gets one story per verification state.
  - **Batch size.** If the batch passes 30 stories, split it into SB-02a and SB-02b. Each removes its own files from `UNSTORIED`.
- [ ] **Step 4: Remove from the to-do list.** Delete `UNSTORIED['SB-02']`.
- [ ] **Step 5: Run** the four checks from Task 11, Step 3. Expect PASS, and ticket any a11y violations.
- [ ] **Step 6: Commit and open the PR.** `docs(storybook): redeem component stories`

---

## PR SB-03: redemption dialog

Branch: `chore/storybook-sb-03`, from `main` after SB-00b merges. If SB-02 hasn't merged, this batch creates the `src/fixtures/wallet` constants it needs, and whichever batch lands second reuses them.

### Task 14: Redemption dialog stories

**Files:**
- Create: one story file beside each file in `UNSTORIED['SB-03']`, titled `Features/Wallet/<Name>`. These are the in-scope files in `src/features/wallet/components/redemptions/`:
  - the bank-transfer dialog's `default-page`, `bank-page`, `card-page` and `crypto-page`
  - `redemption-response-dialog`
  - `payment-details`
  - `redemption-form-shared`

**Interfaces:**
- Consumes: `src/fixtures/wallet` (from Task 13, or created here), `signedIn` and `respond`.

- [ ] **Step 1: Map the requests** for `redemptions/`, and add any missing fixtures to `src/fixtures/wallet`.
- [ ] **Step 2: Write the stories.** Every story uses `beforeEach: [signedIn]`.
  - **The four pages** are layout-sensitive and have behaviour.
    - The bank and card pages' play functions cover their private forms: submitting empty shows the required-field errors, and a valid submit calls the mutation. Assert with the fixture's call count or a `fn()` spy.
    - The crypto page's play covers its private crypto select: choosing an option updates the selection.
  - **`redemption-response-dialog`** gets one story per response outcome.
  - **`payment-details` and `redemption-form-shared`** are leaves.
- [ ] **Step 3: Remove from the to-do list.** Delete `UNSTORIED['SB-03']`.
- [ ] **Step 4: Run** the four checks from Task 11, Step 3. Expect PASS, and ticket any a11y violations.
- [ ] **Step 5: Commit and open the PR.** `docs(storybook): redemption dialog stories`
- [ ] **Step 6: Record the pilot's numbers for the go/no-go.** In the last pilot PR's body, record:
  - hours per PR
  - stories per story file
  - the fixture count
  - any private sub-piece whose states its parent couldn't reach
  - any pain points with the presets or the adapter

  SB-04 uses these to update the spec.
