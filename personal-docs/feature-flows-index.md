# SpinQuest feature flows

How seven features work today, read from source on 2026-11-10 against `Backend@PeterSons`
(50cda2e7) and `spinquest-frontend@main` (5b20ce8ad). Each document follows the same layout:
summary, at a glance, the flow (with a diagram), states and data, configuration, edge cases,
what the team has already said in `central-tech`, gaps and risks, and what could not be
verified.

| Document | Covers |
|---|---|
| [feature-flags.md](feature-flags.md) | The three switching mechanisms: client-side PostHog, server-evaluated PostHog, and env switches. Every flag key found in code |
| [signup-and-onboarding.md](signup-and-onboarding.md) | Anonymous visitor to usable account: signup, verification, terms, geo, KYC triggers, and what "onboarded" means per action |
| [first-time-user-experience.md](first-time-user-experience.md) | The casino and cards tours, one-time shop offers, first-deposit events, and where a new first-time experience would plug in |
| [lobby.md](lobby.md) | Catalogue loading, categories, game launch per provider, the iframe, live balance and wins, casino versus cards |
| [promotions-and-bonuses.md](promotions-and-bonuses.md) | Inventory of every promotion and bonus type, where each is defined, and how it is surfaced and claimed |
| [notifications.md](notifications.md) | Device-token storage for push, the in-app socket and bell path, and every notification trigger found |
| [payments.md](payments.md) | Purchases through Paytech and LinkMoney, redemption, admin review, webhooks, the ledger, and status tables |

## How far to trust these

- Every file and line citation was checked mechanically: the file exists and the line is in
  range. That does not prove the sentence beside it is right.
- A sample of the headline claims in each document was re-read against the source by hand.
  The rest is one careful pass, not a second review.
- Sentences starting "Inferred:" were reasoned, not read.
- Nothing here reflects deployed configuration, vendor dashboards, or the native app, none of
  which are in the workspace. Each document lists its own unverified items at the end.
- Line numbers go stale as the code moves. Re-check a citation before relying on it.
