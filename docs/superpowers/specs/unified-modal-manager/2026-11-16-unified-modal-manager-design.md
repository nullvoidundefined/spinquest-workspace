# FE Spec: Unified Modal Manager

2026-11-16 · Ian Greenough

Exported from [Notion](https://app.notion.com/p/41aa274ca95d81e0a479e943c97ac3a7) on 2026-11-20 (page last edited 2026-11-17). Comment threads stay on the Notion page.

## Summary

This spec defines one modal manager for spinquest-frontend: one store, one host and one way to open a modal. Today there are eight separate overlay mechanisms that do not know about each other. A second socket notification silently replaces the first, and code that asks "is anything open?" checks three sources and still misses most modals.

The manager follows one rule: **stack what the player opens, queue what the system opens, and let one ordered list of layers decide what sits on top.** The app already behaves this way, and its z-index constants already encode the order. The work is therefore a consolidation, with one deliberate behavior change: system-opened modals queue instead of overwriting each other.

Delivery is three phases of small PRs:

- **Phase 0** (half a day to a day) makes CI run tests and builds the test harness.
- **Phase 1** lays a two-PR foundation, then ports one modal flow per PR, writing that flow's tests just before switching it. Every port is independent: it can ship in any order, wait, or be skipped.
  - The first visible fix lands about **2–3 days** in.
  - The four ports that fix something take **3.5–5.5 days** with the foundation.
  - Porting everything takes **6.5–10 days**.
- **Phase 2** (1.5–2 days) moves "seen" state from the browser to the backend.

These are engineer days with an LLM coding agent, including review and QA (see Level of effort).

## Current state

Eight overlay mechanisms exist, and none coordinates with the others. Findings are from `spinquest-frontend` at commit `beb49afab`.

| Mechanism | Where | How it behaves | Scale |
| --- | --- | --- | --- |
| Route-backed desktop overlays | `features/smart-modal-navigation/` | One slot, opened by `openPath` / `openOverlay` or a deep link. Breakpoint-gated. The in-game shop overlay owns a history entry | 20 routes |
| Promise-based dialog stack | `components/common/dialogs/` (`useDialogs`) | A stack. Opening the same component again replaces the open one, and the replaced promise never settles | 15 calling files. The provider is mounted twice, nested, in the main app, and once in the journey app |
| Per-feature Zustand stores | MFA (4), email and phone verification, location (2), purchase success, notification, free spin | One slot each. Some hold only an open flag and payload. Others also hold flow state: the MFA challenge store is a state machine driven by an API gate | 11 stores; 12 hosts always mounted in `app-layout.tsx` |
| App guard store | `store/app-guard.ts`, `components/common/app-guards/` | One slot shared by all guard types; the latest open wins. Opened by `lib/api/interceptors.ts` and by `AppGuardProvider` effects. Rendered only under the dashboard layout | 7 types defined, 6 ever opened |
| URL search parameter | `features/auth/components/reset-password-modal/` | `?modal=reset-password` plus a token | 1 modal |
| Page/modal wrappers | `responsive-modal-page-wrapper/` (sets `isDesktopModalOpen` in `ModalContext`), `responsive-page-modal-wrapper/` | Component-owned open state | 26 files |
| Local `useState` with MUI | Feature components | Invisible to everything else | 13 files |
| Guided tours | Casino FTUE (own portal layer and store), cards FTUE | Sequenced by hand with phone verification and the cards welcome offer | 2 tours |

**An order already exists.** z-index constants in `lib/constants/ui.ts` and `features/mfa/constants.ts` decide which overlay covers which. From top to bottom:

1. MFA challenge: 10,100 ("nothing may cover it")
2. Other MFA dialogs: 10,050
3. GeoComply hints: 10,001 (dead code that this spec deletes)
4. Terms re-acceptance: 1601
5. Phone verification: 1600
6. Casino tour: 1500
7. App guards: 1401
8. Lifted page modals: 1400
9. Default dialogs: 1300

The manager keeps this order.

Four things are broken today:

- **Lost events.** The notification and free-spin stores hold one slot each. A second socket message overwrites the one on screen.
- **Wrong layer.** The free-spin modal sets z-index 1200, so it renders under any other open dialog.
- **No shared open state.** `use-lobby-hero-bob.ts` combines `useHasOpenDialogs()`, the route-overlay store and `ModalContext` to learn whether a modal covers the lobby. It still misses the store-driven modals, the guards and local dialogs.
- **Split dialog stack.** Because `DialogsProvider` is nested, `useDialogs()` resolves to a different stack depending on where the caller sits.

## Goals and non-goals

**Goals**

- **Player experience first.** No player misses a modal that is required for them, and no player sees a one-time modal again after dealing with it.
- One way to open a modal, usable from React and from sockets and API interceptors.
- No system-opened modal is silently lost.
- One `useIsAnyModalOpen()` that sees every managed modal and every overlay that reports in.
- One place for "seen" state.
- Each flow moves in its own PR, which also deletes that flow's old code. Any flow can be postponed or left alone without affecting the rest.

**Non-goals**

- Redesigning modal visuals or the sheet and page-modal primitives.
- Changing route-backed overlays, their URLs or deep links. They only report their open state.
- Guided tours, and the cards FTUE state, which belongs to the cards API.
- Scheduling for promotional modals (idle-only display, frequency caps, expiry). No modal needs it today.
- An app-wide z-index cleanup (date pickers, landing page, spinner). It is unrelated to modals.
- Migrating local `useState` dialogs. They move when their files are next touched.
- Feature flags for the rollout (see Rollout).

## Design

The manager is a Zustand store plus one host component. It generalises the dialog stack the repo already has. `useDialogs` has the right shape (component, payload, promise), but it lives in React context, so sockets and interceptors cannot call it, and it has no layers or queue.

```ts
interface ModalDefinition<P, R> {
  id: string;                              // also the key for seen state
  component: LazyExoticComponent<ModalComponent<P, R>>;
  layer: ModalLayer;                       // what it paints above (see Layers)
  queued?: boolean;                        // system-opened: one at a time
  key?: (payload: P) => string;            // distinct instances, e.g. one per notification id
  showOn?: (pathname: string) => boolean;  // default: every route
  once?: { gate?: 'dismissed' | 'shown' }; // show once per player; gate defaults to 'dismissed'
}

openModal<P, R>(def: ModalDefinition<P, R>, payload: P): Promise<R | undefined>;
closeModal<P, R>(def: ModalDefinition<P, R>, result?: R): void;
useModal<P>(def: ModalDefinition<P, unknown>): { isOpen: boolean; payload?: P };
getModal<P>(def: ModalDefinition<P, unknown>): { isOpen: boolean; payload?: P }; // the same, outside React
isSeen(def: ModalDefinition<unknown, unknown>): boolean;
useIsAnyModalOpen(): boolean;
useReportOverlay(isOpen: boolean, layer?: ModalLayer): void; // for overlays the manager does not own
```

Definitions live beside their feature (`export const mfaChallenge = defineModal({...})`), so payload and result types reach every caller. Components receive `{ open, payload, onClose }`, the contract `DialogsProvider` uses today, and keep their own markup.

### How modals open

1. **Stack.** `openModal` shows a modal at once, on top of whatever is open in its layer, and the modal beneath stays visible. This is today's behavior, and nested flows depend on it: an API gate opens the MFA challenge from inside whichever modal made the request.
2. **Queue.** A definition marked `queued` is one the system opens: socket notifications, free spins, purchase success.
   - These show one at a time, in arrival order.
   - They wait while a higher layer is showing, whether the manager owns it or it only reports in.
   - They do not wait for player-opened modals or route overlays, so a payment result still appears during checkout and inside a game.
   - At most 5 wait. Overflow drops the oldest and reports it to Sentry.
3. **Layers.** One ordered list in `lib/constants/ui.ts` becomes the only source of modal z-index values. Each port deletes its flow's own constant. The host applies a layer's z-index through a scoped MUI theme, so a modal, and the menus and pickers inside it, need no z-index of their own.

### Layers

| Layer (bottom to top) | z-index | Modals |
| --- | --- | --- |
| `dialog` | 1300 (MUI default); 1400 for page modals configured as lifted | Everything on the dialog stack: lobby modals, regional restriction, responsible gaming, giveaway info, shop package, language and others. Also email verification, location permission and reset password. Queued: notifications, free spins, purchase success |
| `guard` | 1401 | Ban, self-exclusion, KYC age, KYC multiple sessions, KYC multiple failed |
| `phoneVerification` | 1600 | Phone verification. While the phone is unconfirmed it is a hard gate and cannot be dismissed |
| `terms` | 1601 | Terms re-acceptance |
| `mfa` | 10,050 | MFA setup, disable and prompt |
| `mfaChallenge` | 10,100 | MFA challenge. It holds a live request, so nothing may cover it |

The values are today's, so overlays the manager does not own keep their place between layers:

- lifted page modals (1400)
- the casino tour (1500)
- the Veriff iframe, game loader and spinner (9999)

### Rules

- **Opening the same modal again replaces it.**
  - An entry is identified by its definition and optional `key`.
  - Opening an identity that is already open or waiting swaps in the new payload, and resolves the earlier promise with `undefined`.
  - This matches the guard store and dialog stack today. It also absorbs repeated opens from parallel refused requests and from Strict Mode.
- **Every promise settles.** It resolves with the modal's result, or with `undefined` if the entry was replaced, dropped or flushed.
- **Dismissal belongs to the component.** Guards render no close control, and phone verification ignores dismissal while the phone is unconfirmed. The manager adds no dismissal rules of its own.
- **Flow state stays with the feature.** The manager knows only what is open and in what order. A store that holds a step or a state machine keeps it. Only its open flag moves, and code that reads the flag switches to `useModal` or `getModal`.
- **Triggers stay mounted.** Some modals decide for themselves when to open: phone verification from the player's state, reset password from the URL. Today that logic sits inside components that are always mounted. A port moves it into a small always-mounted trigger, because the manager mounts a modal only while it is open.
- **`showOn` scopes a modal to routes.** Guards use it to keep rendering only under the dashboard layout. An entry opened elsewhere waits, as guard state does today.
- **`once` modals wait for the player.** Seen state is unknown until `/users` resolves, so a `once` modal never opens before then.
- **Auth changes flush everything.** When the user id changes (logout, session revocation, cross-tab sign-out), every entry closes and its promise resolves.

### Coexistence

The manager runs beside the old mechanisms for as long as needed. Any flow can be ported, postponed or left alone for good. Three things make a half-finished migration safe:

- **Same layers.** Layers use today's z-index values, so a ported modal and an unported one stack exactly as they do now.
- **Everything reports in.**
  - The shared modal shells call `useReportOverlay` themselves: the page/modal wrappers, sheets, `StyledDialog`, the confirm dialog and the dialog-stack provider.
  - One bridge file reports for what is left: each legacy store, the guard store, the route-overlay store and the tours, each with its layer.
  - From the day the bridge lands, `useIsAnyModalOpen()` is complete, and queued modals wait for unported gates too.
- **The bridge is the to-do list.** Porting a flow deletes its line from the bridge. Shared code (the dialog stack, the guard store, `seen-once.ts`) is deleted by whichever port removes its last user.

### Rendering

- **One host per root.** Each React root mounts one `<ModalHost />`: `AppLayout` for the main app, and the journey app, where the merch store runs and opens dialogs. A page load only ever has one root.
- **Loading.** The host lazy-loads components for the `dialog` layer on first open. Components for the gate layers (`guard`, `phoneVerification`, `terms`) are bundled eagerly, as they are today, so a failed chunk load can never hide a gate.
- **Error boundaries.** An error boundary around each entry reports a render failure to Sentry. It closes a broken `dialog`-layer modal, and replaces a broken gate with a reload prompt, so a gate is never skipped.
- **MUI behaviour.** MUI's own backdrop, scroll lock, focus trap and transitions stay as they are. A closed entry stays mounted until its exit transition ends, as the dialog stack does today.

## Flow coverage

Every modal flow in the codebase was checked against the design. Each row lists who opens the flow, the behavior a port must keep, and the part of the design that keeps it.

| Flow | Opened by | What must hold | Covered by |
| --- | --- | --- | --- |
| Payment notifications | Socket (`notifications-socket-provider.tsx`), `use-link-money-customer.ts` | Bursts and redelivery; must show during checkout and inside a game | `queued`, `key` per notification |
| Free spin | Socket | Navigates to the game on accept; today it renders under other dialogs | `queued`, `dialog` layer |
| Purchase success | `use-checkout-web-outcome.ts`, after checkout settles | Shows inside a game; navigates to the lobby on close | `queued` |
| MFA prompt | `offerMfa()` at the end of redemption, vault deposit and withdraw | Returns at once whether it showed; runs the caller's deferred work on close; seen when shown; opens MFA setup from inside | `mfa` layer, `once` with gate `shown`, `isSeen`, the settled promise |
| Merch welcome | Merch page mount, in the main app and the journey app | Seen when shown; opens once despite Strict Mode | `once` with gate `shown`; a host in each root |
| Dialog stack, 15 callers | Player actions, the guard effect and Fundist errors (lobby KYC), the socket (lobby congrats) | Awaited results (the card pickers return ids); callbacks in the payload; dialogs opened in sequence; one component with several payload types (lobby modal); nested opens (merch ineligible opens email verification); runs in the journey app; some dialogs are lifted to 1400 by their wrapper | `openModal` has the same shape; the replace rule; settled promises; components keep their wrapper |
| App guards (5 dialogs) | `lib/api/interceptors.ts`, `AppGuardProvider` effects | One slot, latest wins; only on dashboard routes; other code reads the open guard and its meta (self-exclusion date) | `guard` layer, `showOn`, the replace rule, `useModal` |
| Terms re-acceptance | Interceptor (login gate and other checkpoints), the `termsCurrent` effect | Restarts at the intro for a new checkpoint; closes itself when nothing is pending; KYC verification waits for it | `terms` layer, replace with a new payload, `useModal` |
| MFA challenge | An API gate mid-request; the login flow, which reuses it as the login-code screen | The gate steers it through a handle; login hooks read its open flag outside React; closing cancels the request; opens MFA disable from inside | `mfaChallenge` layer; the store keeps its state machine; `getModal` |
| MFA setup and disable | Account row, the MFA prompt, the MFA challenge | Step state | `mfa` layer; the stores keep their steps |
| Email verification | Account list, redemption, Fundist errors after a redirect, the merch ineligible modal | Opens on top of the modal that asked for it | The stack |
| Phone verification | Its own effect for unconfirmed players; account page, MFA row, game cards, Fundist errors, redemption | Hard gate while unconfirmed; redirects to the lobby; hands off to the casino tour; dismissible once confirmed | `phoneVerification` layer; a mounted trigger; dismissal in the component |
| Location permission | `lib/api/geolocation/service.ts`, outside React | Steps and a success callback set by the service | `openModal` is callable anywhere; the store keeps its step |
| Reset password | The URL (`?modal=reset-password` and a token), read inside its host | Opens from an emailed link | A mounted trigger |
| GeoComply hints | Nothing. Its only call is commented out | – | Not ported. It is deleted as dead code |
| Route overlays (20 routes) | `openPath` / `openOverlay`, deep links; includes login, vault and the in-game shop | URL, history and breakpoints unchanged | Report only |
| Shell-based and local dialogs | Component state: redemption modals, OTP entry, shop iframe, official rules, tournament modals and others | Unchanged | Shells report; not ported |
| Tours | Casino FTUE store; cards FTUE, which then opens the welcome offer | Sequencing unchanged | Report only |

Toasts, the notification popover, Intercom and the Veriff iframe are not modals in this sense and are untouched.

## Seen state

Seen state records that a player has already had a one-time modal, so it is not shown again. It moves in two steps: into one central map in the browser (Phase 1), then onto the backend (Phase 2).

### Today

Two modals keep seen state, both in `localStorage` through `utils/seen-once.ts`.

| Modal | Key | Marked |
| --- | --- | --- |
| MFA prompt | `sq:mfa-prompt-seen:<userId>` | When shown, on purpose. The code comment says the offer "is a nudge, not something to keep re-asking" |
| Merch store welcome | `sq:merch-welcome-seen:<userId>` | When shown |

Both show again on a new device or browser, or after storage is cleared. When storage is blocked, `seen-once.ts` falls back to memory, so "once" becomes once per page load.

Two things look similar but are out of scope:

- Terms acceptance, KYC and ban status come from the backend on every load.
- The cards FTUE flags belong to the mocked cards API.

### The rule

A definition with `once` shows once per player. The manager records two events: `shown` (the modal is on screen) and `dismissed`. `once.gate` picks which event stops the modal from showing again, and defaults to `'dismissed'`. The MFA prompt and merch welcome set `'shown'` to keep today's behavior. A caller can ask first with `isSeen(def)`: `offerMfa()` needs that to keep returning whether the prompt was shown.

### Phase 1: one central map (frontend)

One versioned `localStorage` key, `sq:modal-state:v1`, holds seen state for every modal, shaped `{ [userId]: { [modalId]: { shownAt, dismissedAt } } }`. Only the manager reads or writes it.

- **Backfill.** When a nudge is ported, its existing key is copied into the map on first load and deleted. The old keys carry no time, so both fields get the import time. The same PR switches that modal to read the map, so no flag is lost in between.
- **Blocked storage.** The map keeps the in-memory fallback that `seen-once.ts` has.
- **Two tabs.** The key is re-read before each write, so tabs do not overwrite each other's entries.

### Phase 2: the backend

The backend becomes the store, so seen state follows the player across devices. The backend ships first, then the frontend switches to it, and later drops the map.

**Backend contract**

- **Table.** `user_modal_state`: `user_id`, `modal_key`, `shown_at`, `dismissed_at`. Primary key `(user_id, modal_key)`.
- **Read.** `GET /users` gains `modalState: Record<modalKey, { shownAt, dismissedAt }>`, so boot needs no extra request.
- **Write.** `POST /users/me/modal-events` takes `{ events: [{ key, event: 'shown' | 'dismissed', at? }] }`.
  - It is idempotent: the earliest time for each event wins.
  - It accepts only allowlisted keys.
  - It stamps the time itself when `at` is absent.

**Frontend switch**

1. **Switch.**
   - After `/users` resolves, the frontend posts any map entries the backend lacks, with their times, through the same endpoint.
   - From then on, `once` reads `user.modalState`, updates it optimistically and posts each event.
   - It keeps writing the map too, so reverting the switch is safe.
2. **Remove the map, 90 days later.** The map, its storage adapter and both backfills are deleted.

**Edge cases**

- **Shared devices.** Entries are stored per user id and never attributed to another player. Leftover entries go when the map is deleted.
- **Failed writes.** Until the map is removed, it still holds the event, and the next load posts it again. After that, a lost write means the modal can show once more, at worst.
- **Logged-out players.** `once` needs a user id. No one-time modal is shown to logged-out players today.

## Delivery plan: PR stack

Delivery is three phases of small pull requests:

- **Phase 0** sets up CI and the test harness, and changes no product code.
- **Phase 1** lays a two-PR foundation, after which every modal flow is its own port. A port writes its flow's tests, then switches the flow. It can ship in any order, wait, or never happen, without affecting the others (see Coexistence).
- **Phase 2** moves seen state to the backend, and needs only the nudges port.

Build hours are engineer hours with an LLM coding agent. Review and manual QA are counted separately (see Level of effort).

### Phase 0: CI and test harness

No tests run in CI today. The workflows only build and deploy, and the pre-commit hook runs typecheck and lint. Phase 0 fixes that and builds the fixtures every port will use. It writes no flow tests: each port writes its own, just before it switches (see Tests first).

| PR | Scope | Done when | Build hours |
| --- | --- | --- | --- |
| CI and harness | A CI job that runs Vitest and the mocked Playwright specs on every PR. Playwright fixtures for mocked API and socket responses and seeded `localStorage`, following the existing `e2e/fixtures/*.mock-api.ts` pattern | A failing test blocks a merge | 3–5 |

### Phase 1: frontend

**Foundation.** These two PRs come first. Neither changes what a player sees.

| PR | Scope | Done when | Build hours |
| --- | --- | --- | --- |
| Core | The store, `defineModal`, `openModal` / `closeModal`, the selectors, the queue and replace rules, `showOn`, `once` with the central-map adapter, and the auth flush. The layer list in `lib/constants/ui.ts`, with the existing z-index constants now reading from it. `<ModalHost />` in `AppLayout` and the journey app, with the scoped theme and error boundary. Unit tests for every rule. A dev-only debug panel (see QA plan) | No visible change. The production bundle contains no panel code | 5–8 |
| Bridge | `useReportOverlay`, called by the shared shells and by the dialog-stack provider. One bridge file that reports for every legacy store, the guard store, the route-overlay store and both tours, each with its layer. `use-lobby-hero-bob.ts` uses `useIsAnyModalOpen()` only | The lobby hero goes quiet under every modal, including guards and store-driven ones | 1.5–2.5 |

**Ports.** Each row is one PR, independent of the others. The first four fix something. The rest only bring a flow onto the common path, so they can wait or be skipped.

**Tests first.** Every port starts by writing tests for how its flow behaves today, and getting them green on the old code. Then it switches the flow, and the same tests must stay green. The tests can be the port's first commit or a small PR of their own. No flow is tested before its port is due. A flow's tests assert whichever of these apply:

1. **A gate always appears** on its trigger, on the routes where it opens today, and cannot be dismissed.
2. **A system-opened modal shows** on its trigger, which is a mocked socket message or API response.
3. **A one-time modal stays hidden once seen**, across reloads, and opens once when unseen.
4. **A player-opened modal opens on demand**, including from deep links and from inside other modals.
5. **A known defect is labelled, not locked in.** The overwritten second notification gets a test marked as a known defect, and the notifications port flips it.

Build hours below include each flow's tests.

| Port | What moves | What it gains | Risk | Build hours |
| --- | --- | --- | --- | --- |
| Notifications | Notification and free spin become queued definitions, keyed per notification. The call in `use-link-money-customer.ts` moves too. Deletes both stores, both host mounts and the 1200 z-index | Fixes lost notifications and the free-spin layer | Low | 2–3.5 |
| Purchase success | A queued definition, opened from `use-checkout-web-outcome.ts`. Deletes the store and its host mount | Queues with notifications instead of overlapping them | Low | 1.5–2 |
| Nudges and seen state | The MFA prompt and merch welcome become definitions with `once: { gate: 'shown' }`, and their seen keys move into the central map. `offerMfa()` keeps its signature and `onClose` contract. Either nudge can move alone. Deletes `mfa-prompt.store.ts`, its host mount, `prompt-seen.ts` and `merch-store/seen.ts`; `utils/seen-once.ts` goes with the second nudge | One store for seen state. Required for Phase 2 | Low | 2.5–4 |
| Dialog stack | The 15 calling files call `openModal()`, together or a few at a time. `components/common/dialogs/` and its three provider mounts go with the last caller | Callable outside React, settled promises, one stack instead of two nested ones | Low | 4–5.5 |
| Location permission | The dialog becomes a definition. The store keeps its step and callback. `lib/api/geolocation/service.ts` is unchanged | Common path only | Low | 1.5 |
| Reset password | A definition, plus a mounted trigger that reads the URL | Common path only | Low | 1.5 |
| Email verification | A definition. The store keeps its step | Common path only | Low | 1.5 |
| MFA setup and disable | Two definitions on the `mfa` layer. The stores keep their steps | Common path only | Low | 1.5 |
| MFA challenge | A definition on the `mfaChallenge` layer. The store keeps its state machine, and the API gate's `controller.open()` contract does not change. The open-flag reads in the login hooks switch to `getModal` | Common path only | Medium | 2–3 |
| Phone verification | A definition on the `phoneVerification` layer, plus a mounted trigger that keeps the hard gate, the lobby redirect and the hand-off to the casino tour | Common path only | High | 2–3 |
| Guards and terms | One unit, because they share a slot. Five guard dialogs and the terms flow become definitions scoped by `showOn`. `lib/api/interceptors.ts` calls `openModal()`, and the three files that read guard state use `useModal()`. Deletes `store/app-guard.ts` and the never-opened plain-KYC type | Common path only | High. Ships alone (see Rollout) | 4–7 |
| GeoComply hints | Not a port. The dialog has no live opener, so it is deleted: its store, component, host mount, the 10,001 z-index and the commented-out call in `lib/api/geolocation/service.ts` | Removes dead code | Low | 0.5 |

Every port also updates the existing unit tests of the module it moves, deletes that module's z-index constant, and removes its line from the bridge.

**Closing sweep (1–2 hours).** Run this whenever the work stops, whether after four ports or all of them:

- [ ] For each ported flow, a search for its removed store, helpers and host mount returns no hits.
- [ ] The bridge file lists exactly the flows that were not ported.
- [ ] Shared code with no users left is gone: the dialog stack, the guard store, `seen-once.ts`.
- [ ] `pnpm typecheck`, `pnpm lint`, every ported flow's tests and the full Playwright suite pass.

### Phase 2: seen state on the backend

Phase 2 needs the nudges port and nothing else from Phase 1.

| PR | Scope | Done when | Build hours |
| --- | --- | --- | --- |
| B1. Table and read (backend) | `user_modal_state` entity and migration; `modalState` attached to the `/users` response | The field is present for every player | 2–4 |
| B2. Events endpoint (backend) | `POST /users/me/modal-events`: batched, idempotent, allowlisted keys, with integration tests | Repeat calls change nothing | 2–4 |
| Switch (frontend) | Backfill from the map, read from `user.modalState`, keep writing the map (see Seen state) | A nudge seen on one device stays hidden on another. The nudges tests stay green | 2–3 |
| Remove the map (frontend) | 90 days after the switch: delete the map, its adapter and both backfills | No modal state in `localStorage` | 1 |

The backend hours were checked against the Backend repo (Express and TypeORM, at commit `639bdeaa`). `UserService` already attaches computed fields such as `mfaEnabled` and `termsCurrent` to the `/users` response, so `modalState` follows an existing pattern, and controllers already have integration tests to copy.

### Rollout

**Decision: no feature flags.** Each PR ships on its own and is rolled back by reverting it.

- Each port is small and independent, so a revert is quick and touches one flow.
- Each flow's tests are written before its port and run in CI, so regressions are caught before merge.
- A flag would keep a flow's old and new paths side by side, and add a deletion PR for it.
- Server flags load after first render (`FlagsSync`), and guards can open from API interceptors before then. A flag on modal routing would itself cause bugs.

Three safeguards stand in for flags:

1. **Stopping is always safe.** After the foundation, the app works with any subset of ports (see Coexistence).
2. **The guards and terms port ships alone.** It deploys at a low-traffic time, after staging sign-off on every gate, with someone watching errors for the first hours and a revert prepared.
3. **The Phase 2 switch keeps writing the map.** Reverting it never loses seen state.

If the business ever needs to switch off a gate change faster than a revert and redeploy allow, add a flag to the guards and terms port only. It should default to the old path until flags load, and stay fixed for the session.

## QA plan

Every behavior a player can notice is checked automatically where possible, and by hand where not. Each PR description lists the rows it re-checked. A row applies only once its flow is ported.

| Area | What must hold | Automated | By hand | Re-checked by |
| --- | --- | --- | --- | --- |
| Gates | Terms, required phone verification and the five guards appear on their trigger, on the same routes as today, cannot be dismissed, and sit above other modals | The port's Playwright tests | Staging accounts in each state | Guards and terms; Phone verification |
| KYC-required and regional dialogs | They open on their trigger, and their close behavior is unchanged | The port's tests | Debug panel | Dialog stack |
| Seen state | A nudge already seen never returns, across reloads, the map backfill and the backend switch. An unseen one appears once. Entries stay per player on a shared device | The port's seen tests; backfill tests | A second browser profile after the switch | Nudges; Phase 2 |
| Stacking | A modal opened from inside another sits on top, and the parent stays. The MFA challenge is above everything and completes its request | Unit tests; e2e for a challenge during redemption | A password change on staging | Core; Dialog stack; MFA challenge |
| Queue | Two notifications both show, in order. A redelivered one does not duplicate. A payment result appears during checkout and inside a game | Unit tests; concurrency e2e spec | An in-game purchase on staging | Core; Notifications; Purchase success |
| Deferred work | `offerMfa()` reports whether it showed, and the caller's deferred work runs after close | Unit tests | Redemption, vault deposit and withdraw | Nudges |
| Mixed state | A ported modal and an unported one stack as they do today. Queued modals wait for an unported gate | Unit tests for the bridge | Debug panel, with a legacy guard open | Bridge; every port |
| Route overlays | Back closes the in-game shop overlay. Deep links and breakpoints behave as today | Deep-link tests, written with the bridge | Resize and rotate with an overlay open | Bridge |
| Auth changes | Logout, session revocation and cross-tab sign-out close everything | `cross-tab-auth-sync.spec.ts`, extended | – | Core |
| Merch journey | The ineligible modal and the welcome open inside the app WebView | `journey-app.test.tsx`, extended | An app build | Core; Dialog stack; Nudges |
| Menus and focus | Menus and pickers inside a modal open above it. Focus stays in the top modal | – | Keyboard pass on desktop and phone, in Chrome and Safari | Core; each port with a form |

**Debug panel (Core PR).** A development- and staging-only overlay that lists every definition, opens any of them with a sample payload, and shows what is open and what is queued. It makes the by-hand rows quick to reproduce. It loads only behind an environment flag, and must not ship in the production bundle, because it can open gates.

## Pros and cons

The change is worth making for the queue, the shared open state and the retired dialog stack. Porting the gates is the risky part, and it is optional.

| Pros | Cons |
| --- | --- |
| No lost notifications or free-spin awards | Two ways to open a modal coexist for as long as any flow is unported |
| One `useIsAnyModalOpen()` that is complete from the bridge PR onward | The bridge is extra code that lives until the last flow moves |
| The work can stop after any port, and the app is still correct | Porting the gates and the MFA challenge carries risk for no functional gain |
| One way to open a modal from sockets, services and interceptors | Every ported feature depends on one store |
| Seen state follows the player across devices (Phase 2) | The first visible fix comes after two to three days of groundwork |
| `dialog`-layer modals load on first use, not at startup | A first open waits for its chunk |

## Gotchas

The manager is small. The risk is in what the existing modals quietly rely on. Each gotcha applies only when its flow is ported.

| # | Gotcha | Why it bites | Handling |
| --- | --- | --- | --- |
| 1 | An API gate drives the MFA challenge | `lib/api/gates/mfa-gate.ts` opens the challenge mid-request and steers it through a handle (`awaitSubmission`, `setVerifying`, `close`) | The port changes only where the dialog renders. The store, the handle and the gate stay |
| 2 | Triggers live inside always-mounted hosts | Phone verification decides when to open from an effect inside its dialog component, and reset password reads the URL inside its own. Both are mounted at all times today | Each port adds a mounted trigger (see Rules). The port's tests pin both modes of phone verification |
| 3 | Open flags are read from outside | Login hooks read the MFA challenge's `isOpen` through `getState()`. KYC verification checks whether the terms flow is open | The port switches each reader to `getModal` or `useModal` |
| 4 | Callers wait on modals | `offerMfa(onClose)` defers a caller's work until the prompt closes, and dialog-stack callers `await` results. Today a replaced dialog's promise never settles | Every promise settles (see Rules). The nudges port keeps the `offerMfa()` contract |
| 5 | Guards and terms share one slot today | A later guard replaces an open terms flow, or the reverse. As separate definitions both can be open, with terms on top | Accepted change: the player clears terms, then sees the guard. Listed as an open question |
| 6 | Guards render only on dashboard routes | `AppGuardProvider` is mounted under the dashboard layout, so a guard opened on an auth or shop page waits. The standalone shop page also serves the in-app checkout | `showOn` keeps this. Changing it is an open question |
| 7 | Some dialogs are lifted by their wrapper | Dialog-stack dialogs built on the page/modal wrapper can be configured to sit at 1400, above ordinary dialogs | Components keep their wrapper and its configuration. The scoped theme does not override it |
| 8 | Repeated opens | Strict Mode runs effects twice in development, and each parallel refused request calls the interceptor | The replace rule makes repeats harmless |
| 9 | Two React roots | `main.tsx` renders the journey app in place of `App` for journey URLs, with its own providers | Each root mounts a host. A development assertion fires if two hosts mount in one document |
| 10 | Focus follows open order, not layer | MUI traps focus in the most recently opened dialog, even when a higher layer covers it. This happens today | Queued modals wait for higher layers. Player-opened ones behave as they do now |
| 11 | Browser history | The in-game shop overlay owns a history entry, so Back can close it | The manager never touches history. Route overlays only report |

## Level of effort

The recommended path is about **5.5–8.5 engineer days**: Phase 0, the foundation, the four ports that fix something, and Phase 2. Porting every flow brings it to **8.5–13 days**.

The first visible fix, queued notifications, lands after about **2–3 days**: the CI harness, the two foundation PRs and the notifications port. Writing each flow's tests with its port, instead of all up front, brings that about a day earlier.

| Scope | Build | Review | Manual QA | Days |
| --- | --- | --- | --- | --- |
| Phase 0: CI and test harness | 3–5 h | 0.25 day | – | 0.5–1 |
| Phase 1, recommended: foundation, four ports with their tests, closing sweep | 17.5–26.5 h | 0.5–1 day | 0.5–1 day | 3.5–5.5 |
| Phase 1, the remaining ports with their tests | 14.5–20.5 h | 0.5–1 day | 0.5–1 day | 3–4.5 |
| Phase 2: seen state on the backend | 7–12 h | 0.5 day, with QA | – | 1.5–2 |

PRs merge one after another, so expect about two weeks of calendar time for the recommended path with normal review turnaround.

**What the hours mean.**

- An LLM coding agent writes each PR's code in well under an hour.
- The build hours are the engineer's: directing the agent, reading the diff, running the flow in a browser, correcting what is subtly wrong, and updating unit tests. 27 existing test files cover the modules that can move.
- Review is the reviewer's time, at 30–60 minutes per PR.

**Where the estimate can move**

- **CI.** If the existing Playwright specs need a live API, the CI job starts with Vitest and the new mocked specs only.
- **Gates.** QA for the guards and terms port needs staging accounts in banned, self-excluded and KYC-failed states. Without them it grows.
- **Backend.** The Phase 2 backend hours follow an existing pattern in the Backend repo, but nothing was built or run to confirm them.

## Open questions

- [ ] Guards render only under the dashboard layout today. If they are ported, keep that, or show them on every route, including the standalone shop page that serves the in-app checkout? The spec keeps it.
- [ ] If guards and terms are ported, is it acceptable that terms and another guard can both be open, with terms on top? Today the later one replaces the earlier.
- [ ] Should the socket-opened lobby "congrats" modal join the queue? The spec leaves it on the stack, as today.
