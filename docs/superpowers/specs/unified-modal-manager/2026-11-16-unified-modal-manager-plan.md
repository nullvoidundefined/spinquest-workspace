# Unified modal manager: implementation plan to the first fix

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build CI and the test harness, the modal manager core, the bridge that makes "is anything open?" complete, and the Notifications port. That port is the first player-visible fix: notifications and free spins queue instead of overwriting each other, and free spins render on the right layer.

**Architecture:**

- **Store and host.** A vanilla zustand store holds open and queued modal entries, overlay reports and the current user id. One `ModalHost` per React root renders the open entries, with a scoped MUI theme per layer.
- **Bridge.** It reports every legacy modal mechanism into the store until each one is ported.
- **Notifications port.** It moves notifications and free spins onto queued definitions.

**Tech Stack:** React 18, TypeScript, zustand 4.5, MUI 5, react-router 6, TanStack Query, `@sentry/react` 8, Vitest 3 + jsdom, Playwright 1.60. There are no new packages.

**Spec:** [2026-11-16-unified-modal-manager-design.md](./2026-11-16-unified-modal-manager-design.md) · **PRD:** [2026-11-16-unified-modal-manager-prd.md](./2026-11-16-unified-modal-manager-prd.md)

**Repo:** `spinquest-frontend`. Every path and command in this plan is relative to that repo. Facts about current code were checked on 2026-11-20.

## Global Constraints

- **No new packages.**
- **No feature flags for the rollout.** A PR is rolled back by reverting it.
- **Named exports only.**
  - Constants are UPPER_SNAKE.
  - Value sets are `as const` objects with a PascalCase name and a union type of the same name, never `enum`.
  - Props are `interface <Name>Props`.
- **Env access** goes through `@/config/env`, with one exception: the debug-panel guard reads `import.meta.env` directly, so Vite can remove the panel from production builds (Task 4).
- **A new `VITE_APP_*` variable** is wired everywhere the build reads env. Grep an existing one (`VITE_APP_ENABLE_MERCH_STORE`) across `Dockerfile`, `docker-compose.yaml`, `.github/workflows/` and `.env.example`, and add the new one beside it.
- **Sentry calls** carry ids and counts only. They never carry notification text, user data or payloads (G7).
- **New user-facing strings** go through `t('key', 'English fallback')`, with the key in every locale file. Debug-panel labels are developer-only and may be literal.
- **Tests:**
  - Unit tests use `describe` + `it`, with explicit vitest imports.
  - Playwright specs use `test`, as the existing `e2e/` specs do.
  - Component tests query by role and text.
  - Each test must fail when the code it guards is broken (G1).
- **Before every PR:** `pnpm lint`, `pnpm typecheck` and `pnpm test` pass. From Phase 0 on, so does `pnpm test:e2e:ci`.

## Order, pausing and resuming

- **Order.** The four PRs land in order: Phase 0, then Core, then Bridge, then Notifications.
- **Safe stopping points.** Each PR leaves the app correct, so stopping after any merged PR is safe.
- **Within a PR,** every task ends in a commit that passes the checks above.
- **Later ports** each get their own plan when they're picked up. They are Purchase success, Nudges, Dialog stack and the rest, and each depends only on Core and Bridge.

## Review Focus

1. **A burst of socket notifications.** Three notifications arrive within a second. All three show, in order, and none is lost. Pinned in Task 2 (queue tests) and Task 9 (e2e).
2. **Redelivery.** The same notification id delivered twice shows once. Pinned in Task 2 (replace-by-key test) and Task 9.
3. **Logout with a queue.** When the user changes, every open and queued entry closes and its promise resolves. Pinned in Task 2 (auth flush).
4. **A render crash in a modal.** A throwing `dialog`-layer component closes, and the error is reported. A throwing gate-layer component shows the reload prompt and stays up. Pinned in Task 3.
5. **The debug panel in production.** A production build without the flag contains no panel code. Pinned in Task 4, Step 5.

---

## PR 1: CI and test harness (Phase 0)

Branch: `chore/modal-phase-0-ci-harness`, from `main`. No product code changes.

### Task 1: Placeholder env, mocked e2e harness and CI job

**Files:**
- Create:
  - `.env.ci`: committed placeholders for every key `src/config/env.ts` requires, with `VITE_APP_PRODUCT=casino` and every `ENABLE_*` flag `false`.
  - `e2e/fixtures/app-shell.mock-api.ts`
  - `e2e/fixtures/socket.mock.ts`
  - `e2e/fixtures/storage.ts`
  - `e2e/harness.spec.ts`
- Modify:
  - `vite.config.ts`: `test.env` uses `loadEnv(mode, process.cwd(), '')`, so `vitest --mode ci` reads `.env.ci`.
  - `playwright.config.ts`: add a `webServer` running `cross-env VITE_APP_PRODUCT=casino vite --mode ci --port 3001 --strictPort`, with `reuseExistingServer: !process.env.CI`.
  - `package.json` scripts:
    - `"test:ci": "vitest run --mode ci"`
    - `"test:e2e:ci": "playwright test --grep @mocked"`
  - `.github/workflows/build.yaml`: a new job (see Step 6).

**Interfaces:**
- Produces:
  - `export const mockAppShell = async (page: Page, options?: { user?: Partial<User>; signedIn?: boolean }) => void`
    - Fulfils `*/**/users` with `MOCK_USER` (from `e2e/utils/auth.ts`) merged with `options.user`, plus balance, flags and any other request the lobby makes on first load.
    - Answers any other `*/**/api*` request with a 501 whose body names the path, and records it.
    - `signedIn` (default `true`) seeds the persisted auth store through `seedStorage`.
  - `export const getUnmockedRequests = (page: Page): string[]`
  - `export const mockSocket = async (page: Page) => { emit: (event: string, payload: unknown) => Promise<void> }`
    - Uses `page.routeWebSocket` on the socket URL.
    - Answers the Engine.IO handshake (`0{...}`) and the Socket.IO connect (`40`).
    - `emit` sends `42["<event>",<payload>]`.
  - `export const seedStorage = async (page: Page, entries: Record<string, string>) => void`. It runs `page.addInitScript` to write `localStorage` before the app boots.

- [ ] **Step 1: Write `.env.ci`.** No real keys.
- [ ] **Step 2: Write the fixtures.** Follow the `e2e/fixtures/*.mock-api.ts` pattern: an exported async function calling `page.route('*/**/<path>', (route) => route.fulfill({ json }))`.
- [ ] **Step 3: Write `e2e/harness.spec.ts`,** tagged `@mocked`:
  - `test('loads the signed-in lobby against the mocked API')`. Call `mockAppShell(page)`, go to `/`, and expect the balance in the top bar. Expect `getUnmockedRequests(page)` to be empty.
  - `test('delivers a socket notification to the app')`. Call `mockSocket(page)`, then `emit('notification', { id: 'n1', title: 'Purchase Confirmed', text: '…', … })`. Expect the toast `notifications-socket-provider.tsx` shows for `'Purchase Confirmed'`.
- [ ] **Step 4: Run** `pnpm test:e2e:ci`. Expect PASS. If the lobby makes requests the shell doesn't mock, add them until `getUnmockedRequests` is empty.
- [ ] **Step 5: Run the unit suite.** Run `pnpm test:ci`.
  - For each failing test, fix it if the cause is the env or the setup.
  - Otherwise mark it `it.skip`, with a ticket in a `// TODO(<ticket>)` comment (G9). List each skip in the PR body.
- [ ] **Step 6: Add the `test` CI job.**
  - `if: github.event_name == 'pull_request'`, `runs-on: ubuntu-latest`.
  - Use the pinned `actions/checkout`, `actions/setup-node` (Node 24) and `pnpm/action-setup` SHAs from `deploy-main.yaml`.
  - Run, in order:
    1. `pnpm install --frozen-lockfile`
    2. `pnpm typecheck`
    3. `pnpm lint`
    4. `pnpm test:ci`
    5. `pnpm exec playwright install --with-deps chromium`
    6. `pnpm test:e2e:ci`
  - Upload `playwright-report/` when the job fails.
- [ ] **Step 7: Prove it blocks (G1).**
  - Push a throwaway commit with a failing assertion in `harness.spec.ts`. Expect the `test` job to fail.
  - Revert it. Put both run URLs in the PR body.
- [ ] **Step 8: Commit.** `ci: run unit and mocked e2e tests on pull requests`

---

## PR 2: Core

Branch: `feat/modal-manager-core`, from `main` after PR 1 merges. No visible change.

### Task 2: Layers, definitions, store and rules

**Files:**
- Modify: `src/lib/constants/ui.ts` and `src/features/mfa/constants.ts`
- Create, all in `src/lib/modals/`:
  - `types.ts`
  - `define-modal.ts`
  - `modal.store.ts`
  - `seen-state.ts`
  - `index.ts`, which re-exports the public API
- Test:
  - `src/lib/modals/modal.store.test.ts`
  - `src/lib/modals/seen-state.test.ts`

**Interfaces:**
- Produces, in `src/lib/constants/ui.ts`:
  - `export const ModalLayer = { Dialog: 'dialog', Guard: 'guard', PhoneVerification: 'phoneVerification', Terms: 'terms', Mfa: 'mfa', MfaChallenge: 'mfaChallenge' } as const`, and `export type ModalLayer`.
  - `export const MODAL_LAYER_ORDER: readonly ModalLayer[]`, bottom to top in the order above.
  - `export const MODAL_LAYER_Z_INDEX: Record<ModalLayer, number> = { dialog: 1300, guard: 1401, phoneVerification: 1600, terms: 1601, mfa: 10_050, mfaChallenge: 10_100 }`.
  - `GUARD_DIALOG_Z_INDEX`, `PHONE_VERIFICATION_Z_INDEX`, `TERMS_DIALOG_Z_INDEX`, `MFA_DIALOG_Z_INDEX` and `MFA_CHALLENGE_Z_INDEX` read from `MODAL_LAYER_Z_INDEX`. Their values don't change.
- Produces, in `types.ts`:
  - `interface ModalProps<P, R> { open: boolean; payload: P; onClose: (result?: R) => void }`
  - `type ModalComponent<P, R> = ComponentType<ModalProps<P, R>>`
  - `interface ModalDefinition<P, R>`, exactly as in the spec. It adds `debugPayload?: P` for the debug panel. `component` is `ModalComponent<P, R> | LazyExoticComponent<ModalComponent<P, R>>`, because gate layers pass eager components.
- Produces, in `define-modal.ts`:
  - `export const defineModal = <P, R = void>(def: ModalDefinition<P, R>): ModalDefinition<P, R>`. It registers `def` in a module registry.
  - `export const getModalDefinitions = (): readonly ModalDefinition<unknown, unknown>[]`
- Produces, in `modal.store.ts`:
  - Every function the spec lists, with the spec's signatures: `openModal`, `closeModal`, `useModal`, `getModal`, `isSeen`, `useIsAnyModalOpen` and `useReportOverlay(isOpen: boolean, layer: ModalLayer = ModalLayer.Dialog)`.
  - `export const setModalUserId = (userId: string | null) => void`
  - `export const useModalEntries = (): readonly ModalEntry[]`
  - `export const MODAL_QUEUE_LIMIT = 5`
  - `export const MODAL_UNMOUNT_DELAY_MS = 1000`. This is the dialog stack's current `unmountAfter`.
  - `ModalEntry = { entryId: string; def; payload; open: boolean }`. `entryId` is `def.id`, or `` `${def.id}:${def.key(payload)}` ``.
- Produces, in `seen-state.ts`:
  - `export const MODAL_SEEN_STORAGE_KEY = 'sq:modal-state:v1'`
  - `readSeen(userId: string, modalId: string): { shownAt?: string; dismissedAt?: string }`
  - `markSeen(userId: string, modalId: string, event: 'shown' | 'dismissed'): void`. It re-reads the key before each write. If storage throws, it falls back to an in-memory map, the same way `utils/seen-once.ts` does.

**Rules** (from the spec):

- **Stack.** A non-queued entry opens at once.
- **Queue.**
  - A queued entry waits while any open entry or overlay report is on a layer above `dialog`, and while another queued entry is open.
  - Queued entries show one at a time, in arrival order.
  - Above `MODAL_QUEUE_LIMIT` waiting entries, the oldest is dropped and resolved with `undefined`. The drop is reported with `captureMessage('modal_queue_overflow', { extra: { droppedId: entryId } })` from `@sentry/react`.
- **Replace.** Opening an `entryId` that is already open or waiting swaps the payload and resolves the earlier promise with `undefined`.
- **`once`.**
  - Opening a `once` definition while `userId` is null waits until a user id is set.
  - Opening it when it is already seen resolves `undefined` at once.
  - The store records `shown` when the entry first opens and `dismissed` on close. `once.gate`, which defaults to `'dismissed'`, decides which event counts as seen.
- **Auth flush.** When `setModalUserId` changes the id from one non-null value to another value, null included, every entry closes and every promise resolves with `undefined`. The first change, from null to an id, is not a flush.
- **`showOn`.** It is applied by the host (Task 3). The store keeps the entry.

- [ ] **Step 1: Write the failing store tests,** one `it` per rule:
  - `it('opens a non-queued modal at once and resolves with its result on close')`
  - `it('stacks a second non-queued modal above the first')`
  - `it('shows queued modals one at a time in arrival order')`
  - `it('holds the queue while a guard-layer entry or report is open')`
  - `it('does not hold the queue for dialog-layer entries or reports')`
  - `it('replaces an entry with the same key and resolves the earlier promise with undefined')`
  - `it('keeps two entries with different keys')`
  - `it('drops the oldest waiting entry past the limit, resolves it and reports it')`: mock `@sentry/react`.
  - `it('holds a once modal until a user id is set')`
  - `it('does not reopen a once modal after it is seen, per gate')`, with one case for `'shown'` and one for `'dismissed'`.
  - `it('flushes every entry when the user id changes')`
  - `it('does not flush on the first user id')`
  - `it('useIsAnyModalOpen is true for an open entry or a report')`
- [ ] **Step 2: Write the failing seen-state tests:**
  - `it('stores events per user and modal under sq:modal-state:v1')`
  - `it('keeps another tab's entry when writing')`
  - `it('falls back to memory when storage throws')`
- [ ] **Step 3: Run** `pnpm vitest run src/lib/modals`. Expect FAIL.
- [ ] **Step 4: Implement** the layers, `types.ts`, `define-modal.ts`, `seen-state.ts` and `modal.store.ts`.
- [ ] **Step 5: Run** `pnpm vitest run src/lib/modals src/features/mfa src/components/common/app-guards`, then `pnpm typecheck`. Expect PASS, with the existing z-index users unchanged.
- [ ] **Step 6: Commit.** `feat(modals): modal manager store, layers and rules`

### Task 3: `ModalHost`

**Files:**
- Create:
  - `src/lib/modals/modal-host.tsx`
  - `src/lib/modals/modal-error-boundary.tsx`
- Modify:
  - `src/components/layouts/app-layout.tsx`: mount `<ModalHost />` beside the legacy hosts.
  - `src/app/journeys/journey-app.tsx`: mount `<ModalHost />` inside `JourneyLayout`, where the router context exists.
  - Every locale file in `public/locales/`: the reload-prompt keys.
- Test: `src/lib/modals/modal-host.test.tsx`

**Interfaces:**
- Consumes: `useModalEntries`, `closeModal` and `setModalUserId` from Task 2.
- Produces: `export const ModalHost = () => JSX.Element`.
  - **User id.** It sets the store's user id from `useCurrentUser().data?.id ?? null`, which covers journey users.
  - **What it renders.** It renders entries whose `def.showOn` passes for `useLocation().pathname`, ordered by `MODAL_LAYER_ORDER`. Each entry renders inside:
    1. a `ThemeProvider` whose theme is the app theme with `zIndex.modal` set to its layer's value
    2. `Suspense` with a `null` fallback
    3. `ModalErrorBoundary`
  - **Exit transitions.** A closed entry stays mounted with `open: false` for `MODAL_UNMOUNT_DELAY_MS`.
  - **One host per document.** In development, mounting a second host logs `console.error`.
- `ModalErrorBoundary`:
  - It reports the error with `captureException(error, { tags: { modalId } })`.
  - On the `dialog` layer, it closes the entry.
  - On the gate layers (`guard`, `phoneVerification`, `terms`), it renders a dialog with a reload button, `t('modals.reloadPrompt.title', …)`. It never closes the entry.

- [ ] **Step 1: Write the failing tests,** rendering `ModalHost` inside a `MemoryRouter` and the app theme:
  - `it('renders an opened modal and removes it after close and the unmount delay')`, using fake timers.
  - `it('applies the layer z-index to the modal')`: render a test definition that shows an MUI `Dialog`, and assert the root's computed `z-index` is `1401` for a `guard` definition.
  - `it('waits to render an entry until showOn matches the route')`
  - `it('closes a dialog-layer modal that throws and reports it')`
  - `it('shows the reload prompt for a gate-layer modal that throws')`
- [ ] **Step 2: Run** `pnpm vitest run src/lib/modals/modal-host.test.tsx`. Expect FAIL.
- [ ] **Step 3: Implement** the host and the boundary, and mount them in both roots. Add the reload-prompt keys to every locale file.
- [ ] **Step 4: Run** `pnpm test:ci`, including `journey-app.test.tsx`. Expect PASS.
- [ ] **Step 5: Commit.** `feat(modals): ModalHost with scoped layers and error boundary`

### Task 4: Debug panel

**Files:**
- Create:
  - `src/lib/modals/debug-panel/index.tsx`
  - `src/lib/modals/debug-panel/load-debug-panel.ts`
- Modify:
  - `src/config/env.ts`: add `ENABLE_MODAL_DEBUG_PANEL`, a boolean defaulting to `false`.
  - `.env.example` and `.env.ci`
  - `Dockerfile`, `docker-compose.yaml` and `.github/workflows/build.yaml`: add `VITE_APP_ENABLE_MODAL_DEBUG_PANEL` beside `VITE_APP_ENABLE_MERCH_STORE`, and anywhere else the grep finds it.
  - `src/lib/modals/modal-host.tsx`: render the lazy panel when enabled.

**Interfaces:**
- Produces: `export const ModalDebugPanel = () => JSX.Element`. It lists `getModalDefinitions()`, opens a definition with its `debugPayload`, and shows the open and queued entries.
- `load-debug-panel.ts`:
  - It exports `MODAL_DEBUG_PANEL_ENABLED = import.meta.env.VITE_APP_ENABLE_MODAL_DEBUG_PANEL === 'true'`. This is the one direct `import.meta.env` read, and a comment says why.
  - It exports a `lazy()` import that `ModalHost` uses only when the flag is true.

- [ ] **Step 1: Write the failing test.** `it('renders the panel only when the flag is on')`: stub `import.meta.env` with `vi.stubEnv`.
- [ ] **Step 2: Implement** the panel and wire the env var into every file above.
- [ ] **Step 3: Run** the test. Expect PASS.
- [ ] **Step 4: Check by hand.** Run `VITE_APP_ENABLE_MODAL_DEBUG_PANEL=true pnpm dev`. The panel opens a test definition. Record a screenshot in the PR.
- [ ] **Step 5: Prove it is gone from production.**
  - Run `pnpm build` with the flag unset.
  - Run `grep -rl "ModalDebugPanel" dist`. Expect no output.
  - Put the command and its output in the PR body.
- [ ] **Step 6: Commit and open the PR.** `feat(modals): dev and staging debug panel`

---

## PR 3: Bridge

Branch: `feat/modal-manager-bridge`, from `main` after PR 2 merges.

### Task 5: Shells and the dialog stack report in

**Files:**
- Modify:
  - `src/features/auth/components/login-required-modal/styles.ts`
  - `src/features/auth/components/common/otp-verification-modal.tsx`
  - the giveaway promo modal's `styles.ts`
  - `src/components/common/responsive-modal-page-wrapper/components/modal-overlay.tsx`
  - `src/components/common/page-modal/index.tsx`
  - `src/components/common/confirm-action-modal/index.tsx`
  - `src/components/common/dialogs/dialogs-provider.tsx`
  - `src/features/spinquest-cards/components/cards-ftue/cards-ftue-controller.tsx`
- Test: `src/lib/modals/report-overlay.test.tsx`

**Interfaces:**
- Consumes: `useReportOverlay` and `ModalLayer` from Task 2.
- Changes:
  - **`StyledDialog`.** The styled root becomes `StyledDialogRoot = styled(Dialog)(…)`. The exported name is kept: `export const StyledDialog = (props: DialogProps) => { useReportOverlay(props.open); return <StyledDialogRoot {...props} />; }`. `styled(StyledDialog)` in `terms/components/styles.ts` keeps working.
  - **The two private copies** get the same wrapper.
  - **Calls with no layer**, so they report on `dialog`:
    - `ModalOverlay` calls `useReportOverlay(true)` while mounted.
    - `PageModal` calls `useReportOverlay(visible)`.
    - `ConfirmActionModal` calls `useReportOverlay(open)`.
    - `DialogsProvider` calls `useReportOverlay(stack.some((d) => d.open))`.
  - **The cards FTUE controller** calls `useReportOverlay(tourOpen || offerOpen, ModalLayer.Guard)`. Tours sit at 1500, above guards, so they hold the queue the same way a guard does.

- [ ] **Step 1: Write the failing tests.** For each shell, rendering it open makes `useIsAnyModalOpen()` true, and closing it makes it false:
  - `it('StyledDialog reports while open')`
  - `it('PageModal reports while visible')`
  - `it('ModalOverlay reports while mounted')`
  - `it('ConfirmActionModal reports while open')`
  - `it('DialogsProvider reports while a dialog is open')`
- [ ] **Step 2: Run** them. Expect FAIL.
- [ ] **Step 3: Implement** the reports.
- [ ] **Step 4: Run** `pnpm test:ci`. Expect PASS.
- [ ] **Step 5: Commit.** `feat(modals): shared shells and the dialog stack report open state`

### Task 6: The legacy bridge and the lobby hero

**Files:**
- Create: `src/lib/modals/legacy-bridge.tsx`
- Modify:
  - `src/components/layouts/app-layout.tsx`: mount `<LegacyModalBridge />`.
  - `src/features/casino/hooks/use-lobby-hero-bob.ts`
- Test:
  - `src/lib/modals/legacy-bridge.test.tsx`
  - `src/features/casino/hooks/use-lobby-hero-bob.test.ts`, created or extended

**Interfaces:**
- Produces: `export const LegacyModalBridge = () => null`. It has one `useReportOverlay` call per legacy mechanism, each reading its store's open flag:

  | Mechanism | Store | Layer |
  |---|---|---|
  | MFA challenge | `useMfaChallengeStore` | `mfaChallenge` |
  | MFA setup | `useMfaSetupStore` | `mfa` |
  | MFA disable | `useMfaDisableStore` | `mfa` |
  | MFA prompt | `useMfaPromptStore` | `mfa` |
  | Phone verification | `usePhoneVerificationStore` | `phoneVerification` |
  | Email verification | `useEmailVerificationStore` | `dialog` |
  | Location permission | `useLocationPermissionStore` | `dialog` |
  | GeoComply hints | `useGeoComplyHintsStore` | `dialog` (dead code; deleted by its own PR) |
  | Purchase success | `usePurchaseSuccessStore` | `dialog` |
  | Notification | `useNotificationModalStore` | `dialog` |
  | Free spin | `useFreeSpinDialogStore` | `dialog` |
  | App guards | `useAppGuard`, `type === TERMS` | `terms` |
  | App guards | `useAppGuard`, any other type | `guard` |
  | Route overlays | `useDesktopModalStore`, `modalPath !== null` | `dialog` |
  | Casino tour | `useIsCasinoFtueActive()` | `guard` (see Task 5) |

  The component holds only this list. Each port deletes its own line.
- `use-lobby-hero-bob.ts`: `canPlayHeroSounds` uses `useIsAnyModalOpen()` in place of `useHasOpenDialogs()`, the desktop-modal store and `ModalContext`.

- [ ] **Step 1: Write the failing tests:**
  - `it('reports each legacy store on its layer')`: table-driven. For each store, set it open, then assert `useIsAnyModalOpen()`, and assert the queue is held for layers above `dialog`.
  - `it('lobby hero pauses when a guard is open')`: render the hook with `openAppGuard(AppGuardType.BAN)`, and expect `canPlayHeroSounds` to be false. This fails today, because the hook misses guards.
- [ ] **Step 2: Run** them. Expect FAIL.
- [ ] **Step 3: Implement** the bridge and switch the hook.
- [ ] **Step 4: Write the deep-link e2e** in `e2e/route-overlays.spec.ts`, tagged `@mocked`:
  - On a desktop viewport with `mockAppShell`, open one route overlay from `features/smart-modal-navigation` by its deep-link URL.
  - Expect its dialog to be visible. After `page.goBack()`, expect it to be gone.
- [ ] **Step 5: Run** `pnpm test:ci` and `pnpm test:e2e:ci`. Expect PASS.
- [ ] **Step 6: Commit and open the PR.** `feat(modals): legacy bridge, complete useIsAnyModalOpen`

---

## PR 4: Notifications port

Branch: `fix/modal-notifications-queue`, from `main` after PR 3 merges. This is the first visible fix.

### Task 7: Tests for today's behaviour

**Files:** Create `e2e/notifications.spec.ts`, tagged `@mocked`.

**Interfaces:**
- Consumes: `mockAppShell`, `mockSocket` and `getUnmockedRequests` from Task 1.
- Payloads follow `Notification` in `src/lib/api/notification/types.ts`.

- [ ] **Step 1: Write the specs:**
  - `test('shows a purchase-approved notification')`: emit `notification` with `title: 'Purchase Approved'`. Expect the dialog with that notification's text.
  - `test('shows a free-spin award and goes to the game')`: emit `notification` with `command: 'freeSpins'` and `data: { gameId: 42, gameImg, replacement: false }`. Click its play button, and expect the URL `/casino/games/42`.
  - `test('shows a link-money payment result')`: visit `/?customerId=c1&paymentStatusCode=0`. Expect the success notification.
  - `test('shows both of two notifications sent back to back')`: emit two notifications 100 ms apart. Expect the first; close it, then expect the second. Mark it `test.fail()` with the comment `known defect: the second overwrites the first`.
  - `test('shows a free spin above an open dialog')`: open the language modal from the UI, then emit a free spin. Click its play button, which fails while it is covered. Mark it `test.fail()` with the comment `known defect: free spin renders at z-index 1200`.
  - `test('shows a redelivered notification once')`: emit the same id twice, close the dialog, and expect no second dialog. Mark it `test.fail()` if it fails today.
- [ ] **Step 2: Run** `pnpm test:e2e:ci`. Expect PASS. The `test.fail()` specs pass by failing.
- [ ] **Step 3: Commit.** `test(notifications): pin notification and free-spin behaviour`

### Task 8: Move notifications and free spins onto the manager

**Files:**
- Create: `src/features/notifications/modals.ts`
- Modify:
  - `src/features/notifications/components/notification-modal/index.tsx`
  - `src/features/notifications/components/free-spin-modal/index.tsx`
  - `src/features/notifications/components/notifications-socket-provider.tsx`
  - `src/features/shop/hooks/use-link-money-customer.ts`
  - `src/components/layouts/app-layout.tsx`: remove the two hosts.
  - `src/lib/modals/legacy-bridge.tsx`: remove the two lines.
- Delete:
  - `src/features/notifications/components/notification-modal/store.ts`
  - `src/features/notifications/components/free-spin-modal/store.ts`

**Interfaces:**
- Produces, in `modals.ts`:
  - `export interface NotificationModalPayload { type: 'success' | 'error' | 'info'; notification: Notification }`
  - `export interface FreeSpinModalPayload { notificationId: string; gameId: number; gameImage: string; title: string; description: string; replacement?: boolean }`
  - `export const notificationModal = defineModal<NotificationModalPayload>({ id: 'notification', component: lazy(…NotificationDialog), layer: ModalLayer.Dialog, queued: true, key: (p) => p.notification.id, debugPayload })`
  - `export const freeSpinModal = defineModal<FreeSpinModalPayload>({ id: 'free-spin', component: lazy(…FreeSpinDialog), layer: ModalLayer.Dialog, queued: true, key: (p) => p.notificationId, debugPayload })`
- Changes:
  - Both components take `ModalProps<Payload>` and call `onClose()` where they called the store's `close()`.
  - `FreeSpinDialog` drops `sx={{ zIndex: 1200 }}`. It keeps its coin switch and its `navigate` to `ROUTES.CASINO_GAMES`.
  - `NotificationDialog` renders the dialog with `open` instead of returning `null`, so it gets an exit transition.
  - The socket provider calls `openModal(notificationModal, …)` and `openModal(freeSpinModal, { notificationId: notification.id, … })`. The title-based branching is unchanged.
  - `use-link-money-customer.ts` calls `openModal(notificationModal, …)`.

- [ ] **Step 1: Find every other user** with `grep -rn "useNotificationModalStore\|useFreeSpinDialogStore\|notification-modal/store\|free-spin-modal/store" src`. Every hit is in a file listed above.
- [ ] **Step 2: Implement** the definitions, the component changes and the callers. Delete the stores, the two hosts and the two bridge lines.
- [ ] **Step 3: Flip the known defects.** Remove `test.fail()` from the back-to-back, free-spin-on-top and redelivery specs.
- [ ] **Step 4: Run** `pnpm test:e2e:ci`. Expect every notifications spec to PASS.
- [ ] **Step 5: Prove the flip is real (G1).**
  - Temporarily set `queued: false` on `notificationModal`. Expect the back-to-back spec to FAIL.
  - Revert.
- [ ] **Step 6: Run** `pnpm lint`, `pnpm typecheck` and `pnpm test:ci`. Expect PASS. Then search for the deleted stores and the hosts: expect no hits.
- [ ] **Step 7: Commit and open the PR.** `fix(notifications): queue notifications and free spins on the modal manager`
  - The PR body lists the QA rows it re-checked: **Queue** and **Mixed state**.
  - By hand on staging: an in-game purchase shows its result inside the game.

