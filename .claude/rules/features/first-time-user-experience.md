---
paths:
  - "spinquest-frontend/src/features/casino/components/casino-ftue/**"
  - "spinquest-frontend/src/features/spinquest-cards/components/cards-ftue/**"
  - "spinquest-frontend/src/features/spinquest-cards/api/**"
  - "spinquest-frontend/src/features/auth/components/verify-number-otp/**"
  - "spinquest-frontend/src/features/landing/primitives/sticky-offer-badge/**"
  - "spinquest-frontend/src/features/landing/sections/welcome-offer-bar/**"
  - "Backend/src/services/ShopPackageService.ts"
  - "Backend/src/services/AsyncShopPackageService.ts"
  - "Backend/src/services/Payments/**"
  - "Backend/src/services/Cards/**"
  - "Backend/src/services/socketEmiter/ActionService.ts"
---

## Summary

First-time user experience consists of two guided tours (casino lobby tour, in-memory, after phone confirmation; cards tour on a localStorage mock), server-driven one-time shop offers on `User` boolean columns, and first deposit marked by `PaymentTransaction.xtime = 1`.

## Invariants

- Phone verification first, tour second: activate the casino tour only when `isPhoneConfirmed` is true at signup success or after the verify dialog confirms.
- `activate()` forces the gold coin and resets to step 0; replays only call `activate()`.
- New prompts check `useIsCasinoFtueActive()` so they do not collide with the tour.
- The tour skips offer steps only after the shop finishes loading with no `new_player_offer` package.
- Logout calls the casino store `reset()`.
- One-time offer eligibility lives in `checkShopPackage`; keep the flag writes in sync (`ShopPackageService` free path, `AsyncShopPackageService` paid path and package swap).
- Every payment provider sets `xtime` on COMPLETED deposits; `xtime === 1` drives the deduped Singular FTD, the Meta pixel and the `first_purchase` socket event.
- A "seen" marker that must survive devices or reach native uses a `User` column plus a migration.
- Gate tour rollouts with `feat-`/`exp-` flags via `getFlag`.

## Gotchas

- Casino tour state is lost on refresh; a user confirming their phone in a later session never sees the tour (inferred).
- The cards key `cards.ftue.state.v1` is not user-scoped (inferred); the welcome pack is granted only in browser memory.
- Backend `CardAcquisitionService.welcomeBundle` has no route or caller.
- Neither tour fires analytics events.
- Landing "one time offer" copy is static and ignores `newPlayerOffer`.

## Start here

`spinquest-frontend/src/features/casino/components/casino-ftue/casino-ftue.store.ts`, `spinquest-frontend/src/features/casino/components/casino-ftue/components/casino-ftue-controller.tsx`, `spinquest-frontend/src/features/spinquest-cards/components/cards-ftue/cards-ftue-controller.tsx`, `Backend/src/services/ShopPackageService.ts`.

Distilled on 2026-11-11 from personal-docs/first-time-user-experience.md; re-check with /trace-feature refresh.
