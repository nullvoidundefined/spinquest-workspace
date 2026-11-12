---
paths:
  - "Backend/src/api/controllers/apps/**"
  - "Backend/src/services/Providers/**"
  - "Backend/src/services/CommonService.ts"
  - "Backend/src/api/middlewares/custom/**"
  - "Backend/src/db/entity/Wallet/**"
  - "spinquest-frontend/src/features/casino/**"
  - "spinquest-frontend/src/lib/api/fundist/**"
  - "spinquest-mobile-app/src/features/casino/**"
  - "spinquest-mobile-app/src/lib/api/fundist/**"
  - "spinquest-mobile-app/src/components/lobby/**"
---

## Summary

The lobby is the casino lobby, which lists the catalogue (groups, merchants, games from `/apps/*`, Redis-cached) and launches via `POST /apps/load/:gameId`; the vendor URL renders in a web iframe or mobile WebView; balance arrives over socket event `balance`.

## Invariants

- `/apps/load` gate order: auth, GeoComply, BlockedStates (FC only), cards+GC refusal, FC missing or GC-only state, phone verified.
- Currency values are `GC` and `FC`; geo middlewares run only for `?currency=FC`.
- The cards product refuses GC launches on the Backend and needs non-empty `ALLOWED_STATES` at boot.
- Lists require `enabled` and `providerEnabled` plus an enabled merchant.
- Merchant state restrictions apply twice: lists use the guessed state, launch uses the verified state.
- Every launch writes a `sweepium.session` row, a 30-minute Redis session and a `recent` upsert.
- Launch response shape stays `{ url, allow, reload, grantId }`; web relies on `reload` for Alea free spins.
- Balance reaches clients only via socket `balance` to room `usr<userId>`; the wallet debit is a conditional `UPDATE ... >= :value`.
- Recent wins come live through `subRecentWins` / room `recentWins` / event `wins`.
- `VITE_APP_PRODUCT` (build-time) and `PRODUCT` (runtime) must agree: FE `casino`, BE `sweeps`.

## Gotchas

- GC launches skip geo, so `state` is `''` and merchant restrictions never apply to GC.
- `getFinalUrl` (Sweepium, PeterSons) swallows fetch errors and returns a dead URL after session rows are written.
- `GET /apps/wins` returns `[]` from an early return; only the socket supplies wins.
- Mobile ignores `reload`, `grantId`, `allow` and hard-codes `Origin`/`Referer` to the production web origin.
- Mobile pings `POST /rewards/checkPromo`, which does not exist on Backend `PeterSons`.

## Start here

`Backend/src/api/controllers/apps/AppsController.ts`, `Backend/src/services/Providers/wallet/GameService.ts`, `spinquest-frontend/src/features/casino/components/game/index.tsx`, `spinquest-mobile-app/src/app/(tabs)/index.tsx`.

Distilled on 2026-11-11 from personal-docs/lobby.md; re-check with /trace-feature refresh.
