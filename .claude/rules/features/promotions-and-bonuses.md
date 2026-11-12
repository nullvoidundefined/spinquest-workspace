---
paths:
  - "Backend/src/api/controllers/main/RewardsController.ts"
  - "Backend/src/api/controllers/main/ShopPackageController.ts"
  - "Backend/src/api/controllers/main/AmoeController.ts"
  - "Backend/src/api/controllers/main/AffiliateController.ts"
  - "Backend/src/services/RewardsService.ts"
  - "Backend/src/services/ShopPackageService.ts"
  - "Backend/src/services/AsyncShopPackageService.ts"
  - "Backend/src/services/amoe/**"
  - "Backend/src/services/admin/AmoeService.ts"
  - "spinquest-frontend/src/features/promotions/**"
  - "spinquest-frontend/src/features/casino/components/lobby-view/casino-lobby-hero/**"
  - "spinquest-frontend/src/lib/api/rewards/**"
  - "spinquest-mobile-app/src/lib/api/rewards/**"
  - "spinquest-mobile-app/src/features/promotions/**"
  - "spinquest-mobile-app/src/features/giveaway/**"
  - "spinquest-mobile-app/src/features/casino/api/use-*daily-bonus*.ts"
---

## Summary

Promotions and bonuses have no promotion engine (the `promotion` schema was dropped); promotions are `json_config` reward tables (daily bonus, login streak, wheel, push bonus, signup bonus), `shop_package.discount` offers, AMOE codes and admin grants, and copy hardcoded in clients.

## Invariants

- `applyDailyBonus` runs in a `SERIALIZABLE` transaction; a partial claim is a multiple of `maximum / 10`.
- Daily bonus state is derived (cycle sum of `daily_bonus` transactions vs `json_config.daily_bonus`); there is no claim table.
- Set `user.lastDailyBonus` only on the first claim of a cycle.
- Daily bonus and AMOE credit `playThrough` of 3x the sweeps amount.
- Keep both claim routes: banners use `GET /rewards/dailyBonus/claim`, mobile lobby taps use the POST.
- `checkShopPackage` hides offers per user flags (`newPlayerOffer`, `first15minutes`, `oneTime50KGC`) and packages over $500 unless `liftedLimit`; logged-out users get none.
- The free 50K offer (`price === 0`) updates exactly one row or throws.
- Ledger types are fixed in `Transaction.ts`; never invent one without the entity.

## Gotchas

- Any `/rewards/*` URL returns 401 for users with unverified phone or email (prefix check); the FE does not pre-check.
- Geo and blocked-state middleware on rewards is commented out, while the shop applies it.
- Giveaway constants are duplicated in web and mobile: two deploys per change.
- `first_15_minutes` has no FE `OFFERS` constant; landing offer text is JSX, not linked to `shop_package`.
- AMOE amounts are constructor literals: a Backend deploy to change.

## Start here

`Backend/src/services/RewardsService.ts`, `Backend/src/services/ShopPackageService.ts`, `spinquest-frontend/src/features/casino/components/lobby-view/casino-lobby-hero/use-daily-bonus-bubble.ts`, `spinquest-mobile-app/src/lib/api/rewards/index.ts`.

Distilled on 2026-11-11 from personal-docs/promotions-and-bonuses.md; re-check with /trace-feature refresh.
