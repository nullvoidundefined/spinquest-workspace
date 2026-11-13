---
paths:
  - "spinquest-frontend/src/**/*.ts"
  - "spinquest-frontend/src/**/*.tsx"
source: codebase naming survey 2026-11-12
---

# spinquest-frontend naming lexicon

This lexicon replaces the global verb lexicon and noun guidance (R-316, R-317) in spinquest-frontend. New names follow it. Rename an existing name only on a line the change already touches. Backend has its own lexicon in `backend-lexicon.md`, which lists where the two differ.

## Verbs

| Verb | Use for | Instead of |
|---|---|---|
| `get` | Synchronous derivation, and `GET` wrappers in `lib/api` | `fetch`, `retrieve` |
| `post`, `put`, `patch`, `delete` | `lib/api` wrappers: HTTP method, then resource (`postAuthLogin`) | `send`, `submit` in `lib/api` |
| `request` | Asking the server to start a process, such as sending a code (`requestEmailVerification`) | |
| `load` | Async load of an asset, script or document (`loadLottieJson`) | `get` for async work |
| `preload` | Warming a cache without using the result | |
| `read` | Reading browser storage, the DOM or an SDK (`readPersistedFtueState`) | `get` for these |
| `use` | Hooks only: `use<Resource>Query`, `use<Action>Mutation`, `use<Domain>Store` | |
| `handle` | An event handler defined in a component (`handleClose`) | |
| `on` | An event-handler prop or callback parameter (`onClose`) | `handle` for props |
| `open`, `close` | A modal, dialog, popover or panel | `show`, `hide` for these |
| `show` | A toast or inline message | |
| `dismiss` | Closing something and remembering the choice | |
| `mark` | Persisting a seen or shown flag (`markMfaPromptSeen`) | |
| `create` | A factory: schema, router, styles, client | `make`, `add` |
| `build` | Assembling a payload or rows from inputs | |
| `initialize` | One-time startup of an SDK or listener | `init`, `setup` |
| `format` | A value to a display string (`formatCoins`) | |
| `describe` | An error or state to a user-facing message (`describeApiError`) | `format` for messages |
| `to` | A pure type or unit conversion (`toSeconds`) | `convert` |
| `resolve` | Picking one value from several inputs or fallbacks | |
| `validate` | Local input validation | `check` |
| `verify` | Confirming with the server or an SDK | `check` |
| `render` | A function returning JSX inside a component | |
| `notify` | Posting a message to a host window or SDK | |
| `goTo` | Route navigation (`goToLobby`) | `navigate` for routes |
| `delete` | Persisted or server data | `remove`, except DOM nodes and listeners |

Booleans start with `is`, `has`, `can` or `should`. Query loading flags are `is<Thing>Loading`; mutation flags are `is<Thing>Pending`.

## Nouns

| Term | Means | Instead of |
|---|---|---|
| `user` | The signed-in person | `customer`, `member`; `player` only for other people shown in game or leaderboard UI |
| `account` | The user's settings and status | `profile` |
| `goldCoins`, `GC` | The play currency | |
| `sweepCoins`, `SC` | The redeemable currency | `sweepstakesCoins`, `sweeps` alone |
| `coins` | Either currency | `credits` |
| `redeem`, `redemption` | Turning SC into a prize | `cashout`, `payout`; `withdrawal` only where the API uses it |
| `purchase` | Buying a package | `buy`, `order` |
| `checkout` | The payment UI flow | |
| `package` | A purchasable coin bundle | `bundle`, `product` |
| `offer` | A targeted or time-limited package | |
| `shop` | The coin shop UI | `store`, which means a zustand store |
| `kyc` | Identity verification; `veriff` only inside the Veriff integration | |
| `verification` | Email or phone code checks | |
| `error` | A caught error binding | `err`, `e` |
| `<amount>Cents` | Money in integer minor units (`priceCents`) | `<amount>Usd` for new code |
| `<query>Keys` | A `createQueryKeys` object (`cardsKeys`) | |
