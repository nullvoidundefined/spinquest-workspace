---
paths:
  - "Backend/src/services/Payments/**"
  - "Backend/src/services/ShopPackageService.ts"
  - "Backend/src/services/AsyncShopPackageService.ts"
  - "Backend/src/services/PaymentSessionService.ts"
  - "Backend/src/api/controllers/paytech/**"
  - "Backend/src/api/controllers/linkmoney/**"
  - "Backend/src/api/controllers/aeropay/**"
  - "Backend/src/api/controllers/main/ShopPackageController.ts"
  - "Backend/src/services/admin/PaymentService.ts"
  - "Backend/src/api/controllers/admin/PaymentsController.ts"
  - "Backend/src/db/entity/Payment/**"
  - "Backend/src/db/entity/Linkmoney/**"
  - "spinquest-frontend/src/features/shop/**"
  - "spinquest-frontend/src/features/wallet/**"
  - "spinquest-frontend/src/features/transactions/**"
  - "spinquest-frontend/src/lib/api/shop/**"
  - "spinquest-frontend/src/lib/api/link-money/**"
  - "spinquest-frontend/src/lib/api/transaction-history/**"
  - "spinquest-mobile-app/src/features/shop/**"
  - "spinquest-mobile-app/src/features/wallet/**"
  - "spinquest-mobile-app/src/lib/api/shop/**"
---

## Summary

Payments work as follows: purchases (Paytech card and Apple Pay, LinkMoney ACH) credit coins only from the Backend webhook through `addCoinsToBalance`; redemptions debit SC atomically then pay out through Paytech, with an admin step for ACH.

## Invariants

- `diamonds`, prices and limits are integer cents (50_00 = 50 SC, 1 SC = 1 USD); convert to dollars only at the vendor boundary.
- Credit purchase value only through `addCoinsToBalance` inside a SERIALIZABLE transaction.
- "`xtime` is null" is the already-credited guard; set `xtime` only in the transaction that credits.
- Read price and coin amounts from the DB package by id; checkout URL `price`, `goldCoins`, `diamonds` are display only.
- `body.packageId` must match the session; consume the payment nonce with `GETDEL` before the charge.
- Verify the Paytech webhook with HMAC-SHA256 over `rawBody` using `PAYTECH_WEBHOOK_KEY` before acting.
- Only the Backend webhook decides a purchase; iframe redirect, `payment-success` message and client polling never credit.
- Paytech credits on `COMPLETED`; LinkMoney credits on `AUTHORIZED`.
- Every balance move writes a `Transaction` row: two `purchase` rows per credit, a `claim` debit per redemption, a flip to `withdraw` on approve or complete, a new `claim` credit on rollback.
- Debit redemptions only through the atomic `UPDATE ... WHERE FLOOR(diamonds - playThrough) >= amount`.
- Admin acts only on `WITHDRAWAL` rows in `CHECKOUT`; reject sets `CANCELLED` and calls `rollbackClaim`.
- Do not build on `GET /balance/shop/redemption` or `/redemptionRate` (inferred: crypto redemption removed).

## Gotchas

- The LinkMoney webhook has no signature check (`LINKMONEY_WEBHOOK_KEY` never read): a forged `payment.authorized` credits coins.
- Webhooks write `state` unconditionally; a redemption `COMPLETED` then `DECLINED` is refunded; LinkMoney failures after `AUTHORIZED` never reverse.
- A payout call that throws leaves the row in `CHECKOUT`, so admin approval can run twice.
- The daily purchase cap is checked at payment creation but incremented at credit, so parallel checkouts each pass.
- Mobile purchases load the web checkout in a WebView: a web checkout change is a mobile change.

## Start here

`Backend/src/services/ShopPackageService.ts`, `Backend/src/services/AsyncShopPackageService.ts`, `Backend/src/services/Payments/paytech/PaytechService.ts`, `Backend/src/api/controllers/main/ShopPackageController.ts`.

Distilled on 2026-11-11 from personal-docs/payments.md; re-check with /trace-feature refresh.
