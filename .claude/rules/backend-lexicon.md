---
paths:
  - "Backend/src/**/*.ts"
source: codebase naming survey 2026-11-12
---

# Backend naming lexicon

This lexicon replaces the global verb lexicon and noun guidance (R-316, R-317) in Backend. New names follow it. Rename an existing name only on a line the change already touches.

## Verbs

| Verb | Use for | Instead of |
|---|---|---|
| `find` | A lookup that may return `null` or `[]` (`findOrderByMerchOrderId`) | `load`, `query` |
| `get` | A value that must exist, throwing when it does not, or a computed value | `retrieve` |
| `search` | A filtered, paginated admin list (`searchOrders`) | `list` with filters |
| `count` | A row count | |
| `fetch` | An outbound HTTP call to a third party (`fetchMetaProfile`) | `get`, `request` for these |
| `create` | A new row or entity, or a factory | `make` |
| `insert`, `upsert` | Repository writes | `create`, `save` in repositories |
| `add` | Incrementing an amount or appending to a collection (`addCoinsToBalance`) | `create` for these |
| `update`, `delete` | Changing or removing a row | `remove` |
| `mark` | A status transition (`markSent`, `markFailed`) | `set` for status |
| `apply` | Applying a bonus, webhook or rule to state (`applyDailyBonus`) | |
| `record` | Appending an audit or event row (`recordLockout`) | `save` for these |
| `assert` | Throwing when a condition fails (`assertMfaAvailable`) | `check`, `ensure` |
| `validate` | Checking a request body or input shape | `check` |
| `verify` | Checking a code, signature, token or webhook (`verifyTotp`) | `check` |
| `check` | Health checks only (`checkDatabase`) | |
| `send` | Email, SMS or push (`sendPhoneCode`) | `notify` |
| `request` | Starting a user-facing process, such as sending a code (`requestEmailVerification`) | |
| `generate` | Tokens, links, HMACs and other derived secrets | `create` for these |
| `sync` | Pulling third-party data into the database | |
| `reconcile` | Comparing with a provider's record and fixing drift | |
| `complete`, `confirm`, `cancel` | Finishing, confirming or cancelling a flow | |
| `handle` | A webhook or event handler (`handleKycEvent`) | |
| `to` | Mapping to another shape (`toResponse`) | `convert` |
| `withdraw`, `deposit` | Wallet and vault operations, including game-provider wallet calls | |

Booleans start with `is`, `has`, `can` or `should`. Controller methods use `get`, `create`, `update` and `delete` to match the HTTP method.

## Nouns

| Term | Means | Instead of |
|---|---|---|
| `user` | A person with an account | `customer`, `member`; `player` only in game-provider integrations |
| `admin` | An internal staff user | |
| `goldCoins`, `GC`, `sweepCoins`, `SC` | The two currencies | `sweeps` alone |
| `redemption` | Turning SC into a prize | `cashout`, `payout`, `withdrawal` |
| `purchase` | Buying a shop package | `buy` |
| `shopPackage` | A purchasable coin bundle | `bundle` |
| `product`, `order` | Merch catalogue items and orders | |
| `transaction` | A ledger row | `tx` |
| `em` | The `EntityManager` inside `isolatedTransaction` | `tx` |
| `manager` | An `EntityManager` parameter outside that callback | `tx`, `em` |
| `<thing>Amount` | A money or coin quantity (`betAmount`) | bare `amount` with two in scope |
| `error` | A caught error binding in new code | `err`, `e` |

## Where the frontend lexicon differs

- The frontend `get` covers HTTP `GET` wrappers; Backend uses `fetch` for outbound HTTP.
- The frontend bans `add`; Backend uses it to increment or append.
- The frontend money suffix is `Cents`; Backend uses `Amount`. A Backend value in integer cents still ends in `Cents`.
