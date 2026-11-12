# Feature rules source material

Extracted 2026-11-11 from the seven dossiers in `personal-docs/` (read against `Backend@PeterSons`
50cda2e7, `spinquest-frontend@main` 5b20ce8ad, `spinquest-mobile-app@master` fce425f0). Source for
`.claude/rules/features/*.md`. Globs were verified to match files on 2026-11-11. Brace globs
(`{a,b}`) must be expanded into one entry each when written into `paths:`. "(inferred)" marks a
line taken from a dossier "Inferred:" statement.

## feature-flags

Summary: three switching mechanisms: browser PostHog flags for anonymous visitors, server-evaluated
PostHog flags delivered to logged-in clients via `GET /flags` and the login response, and env-var
boot switches.

paths:
- `spinquest-frontend/src/features/feature-flags/**`
- `spinquest-frontend/src/store/feature-flags.ts`
- `spinquest-frontend/src/lib/api/flags/**`
- `spinquest-frontend/src/lib/{analytics.ts,posthog.tsx,posthog-device.ts}`
- `spinquest-frontend/src/features/auth/auth-identity-sync.ts`
- `spinquest-frontend/src/features/mfa/**`
- `Backend/src/services/FeatureFlagService.ts`
- `Backend/src/api/controllers/main/FlagsController.ts`
- `Backend/src/api/{express.ts,middlewares/requireOpsFlag.ts,decorators/ForProduct.ts}`
- `Backend/src/utils/analyticsDeviceId.ts`

Invariants:
- Only `feat-`, `exp-`, `perm-` keys with no `ops` segment reach the client; never relax `isClientSafeFlag`.
- Never read `ops-` keys on the frontend; `getFlag` returns the fallback for them.
- Read flags on the frontend only through `getFlag(key, fallback)` (a plain function, not a hook); keep the key in a constant (see `MFA_FEATURE_FLAG`).
- While authenticated with `ENABLE_SERVER_FLAGS` on, `getFlag` reads only the zustand store, never the SDK.
- The flag store is unpersisted; only `FlagsSync`, `useLogin` and `useSocialRegister` write it; `initAuthIdentitySync` clears it on logout.
- Backend reads fail closed: null client or error returns the caller's default (`false` for `ops-`).
- `resolveAuthFlags` never fails login: keep the try/catch, add the field only when defined.
- `decodeBool` treats only literal `false` as off; a string variant counts as on.
- Never flag a legal gate (GeoComply, blocked states, KYC redemption, AMOE, break-in-play) and never apply `requireOpsFlag` to one.
- Boot topology uses env vars, not flags (`ENABLE_*_API`, `PRODUCT`, `NEW_TERMS`).
- Call `getFlag` in leaf components, never in a layout that parents the game `<Outlet/>`.

Gotchas:
- Flags targeting person properties are silently omitted from the client payload (only `$device_id` is passed); use "Match by Device".
- `requireOpsFlag` has no call site although the runbook shows it wired.
- `ops-merch-redemption`, `ops-require-2fa`, `ops-singular-events` are read with real user ids, so percentage rollout buckets per user.
- Client MFA needs `ENABLE_MFA`, `ENABLE_SERVER_FLAGS` and `feat-mfa`; Backend needs only the flag. Nothing checks env consistency across repos.
- Cold store or a 401 refetch makes authenticated reads return the fallback; propagation can take about 10s plus 2 minutes.

Start here: `spinquest-frontend/src/lib/analytics.ts`, `spinquest-frontend/src/features/feature-flags/flags-sync.tsx`, `Backend/src/services/FeatureFlagService.ts`, `Backend/docs/feature-flags-runbook.md`.

## signup-and-onboarding

Summary: web signup is a two-step email/password form posting once to `POST /auth/social-signup`, which runs geo, captcha, age, terms and referral checks, creates the user in one transaction and runs IDComply; Sinch phone confirmation gates play.

paths:
- `spinquest-frontend/src/features/auth/**`
- `spinquest-frontend/src/lib/api/auth/**`
- `spinquest-frontend/src/app/providers/referral-code-provider.tsx`
- `spinquest-frontend/src/components/common/app-guards/**`
- `Backend/src/api/controllers/main/{AuthController,TermsController}.ts`
- `Backend/src/services/{AuthService,SocialOAuthService,TermsService,LoginCodeService}.ts`
- `Backend/src/services/{sinch,terms,kyc,affiliate}/**`
- `Backend/src/api/middlewares/custom/{GeoComply,BlockedStates}Middleware.ts`
- `Backend/src/utils/{geolocation,turnstile}.ts`

Invariants:
- Keep signup middleware order: `CheckIPAuthMiddleware`, `GeoComplyMiddleware`, `BlockedStatesMiddleware`, `PixelMiddleware`.
- Verify Turnstile with action `signup` for every source except `ios`/`android`.
- User, `Balance`, `UserTermsHistory` and the user's referral campaign are created in one DB transaction.
- With `NEW_TERMS` on, every active `SIGNUP` terms id is required; the client sends all active ids and keeps submit disabled while terms load.
- The client obtains the GeoComply package before posting and aborts signup on geo failure.
- IDComply failure soft-deletes with `deletedReason: 'idComply'` and returns 403.
- Phone confirmation sets `isPhoneConfirmed` and copies `phoneNumberNew` to `phoneNumber`; a unique collision soft-deletes with `phoneLock`.
- `User.isVerified()` is phone-only and gates game load and `/rewards/`; redeem also needs confirmed email, `VERIFIED` KYC, geo and MFA.
- The phone dialog is a hard, non-dismissable gate and waits for an active FTUE.
- Bypass codes stay forced empty in production.
- A social provider's email must match the body email; provider `emailVerified` sets `isEmailConfirmed`.

Gotchas:
- Signup does not start phone verification; the dialog sends the first code. A client skipping the dialog creates an account that cannot load games.
- The signup bonus comes from the `signup_bonus` json_config row (GC and diamonds only); `SIGNUP_*_COINS_BONUS` env keys are never read.
- `useRegister` and `/auth/signup` are dead; the live route is `/auth/social-signup`.
- Web KYC checks `sessionStatus === 'approved'`; Backend checks `status === 'VERIFIED'`.
- The verification email is sent before IDComply, outside the transaction, with uncaught send errors; the `confirmUserPhone` "already confirmed" guard is commented out.

Start here: `spinquest-frontend/src/features/auth/components/auth-page/register-flow.tsx`, `Backend/src/api/controllers/main/AuthController.ts`, `Backend/src/services/AuthService.ts`, `spinquest-frontend/src/features/auth/components/verify-number-otp/index.tsx`.

## first-time-user-experience

Summary: two guided tours (casino lobby tour, in-memory, after phone confirmation; cards tour on a localStorage mock), server-driven one-time shop offers on `User` boolean columns, and first deposit marked by `PaymentTransaction.xtime = 1`.

paths:
- `spinquest-frontend/src/features/casino/components/casino-ftue/**`
- `spinquest-frontend/src/features/spinquest-cards/components/cards-ftue/**`
- `spinquest-frontend/src/features/spinquest-cards/api/**`
- `spinquest-frontend/src/features/auth/components/verify-number-otp/**`
- `spinquest-frontend/src/features/landing/{primitives/sticky-offer-badge,sections/welcome-offer-bar}/**`
- `Backend/src/services/{ShopPackageService,AsyncShopPackageService}.ts`
- `Backend/src/services/Payments/**`
- `Backend/src/services/Cards/**`
- `Backend/src/services/socketEmiter/ActionService.ts`

Invariants:
- Phone verification first, tour second: activate the casino tour only when `isPhoneConfirmed` is true at signup success or after the verify dialog confirms.
- `activate()` forces the gold coin and resets to step 0; replays only call `activate()`.
- New prompts check `useIsCasinoFtueActive()` so they do not collide with the tour.
- The tour skips offer steps only after the shop finishes loading with no `new_player_offer` package.
- Logout calls the casino store `reset()`.
- One-time offer eligibility lives in `checkShopPackage`; keep the flag writes in sync (`ShopPackageService` free path, `AsyncShopPackageService` paid path and package swap).
- Every payment provider sets `xtime` on COMPLETED deposits; `xtime === 1` drives the deduped Singular FTD, the Meta pixel and the `first_purchase` socket event.
- A "seen" marker that must survive devices or reach native uses a `User` column plus a migration.
- Gate tour rollouts with `feat-`/`exp-` flags via `getFlag`.

Gotchas:
- Casino tour state is lost on refresh; a user confirming their phone in a later session never sees the tour (inferred).
- The cards key `cards.ftue.state.v1` is not user-scoped (inferred); the welcome pack is granted only in browser memory.
- Backend `CardAcquisitionService.welcomeBundle` has no route or caller.
- Neither tour fires analytics events.
- Landing "one time offer" copy is static and ignores `newPlayerOffer`.

Start here: `spinquest-frontend/src/features/casino/components/casino-ftue/casino-ftue.store.ts`, `.../casino-ftue/components/casino-ftue-controller.tsx`, `spinquest-frontend/src/features/spinquest-cards/components/cards-ftue/cards-ftue-controller.tsx`, `Backend/src/services/ShopPackageService.ts`.

## lobby

Summary: the casino lobby lists the catalogue (groups, merchants, games from `/apps/*`, Redis-cached) and launches via `POST /apps/load/:gameId`; the vendor URL renders in a web iframe or mobile WebView; balance arrives over socket event `balance`.

paths:
- `Backend/src/api/controllers/apps/**`
- `Backend/src/services/Providers/**`
- `Backend/src/services/CommonService.ts`
- `Backend/src/api/middlewares/custom/**`
- `Backend/src/db/entity/Wallet/**`
- `spinquest-frontend/src/features/casino/**`
- `spinquest-frontend/src/lib/api/fundist/**`
- `spinquest-mobile-app/src/features/casino/**`
- `spinquest-mobile-app/src/lib/api/fundist/**`
- `spinquest-mobile-app/src/components/lobby/**`

Invariants:
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

Gotchas:
- GC launches skip geo, so `state` is `''` and merchant restrictions never apply to GC.
- `getFinalUrl` (Sweepium, PeterSons) swallows fetch errors and returns a dead URL after session rows are written.
- `GET /apps/wins` returns `[]` from an early return; only the socket supplies wins.
- Mobile ignores `reload`, `grantId`, `allow` and hard-codes `Origin`/`Referer` to the production web origin.
- Mobile pings `POST /rewards/checkPromo`, which does not exist on Backend `PeterSons`.

Start here: `Backend/src/api/controllers/apps/AppsController.ts`, `Backend/src/services/Providers/wallet/GameService.ts`, `spinquest-frontend/src/features/casino/components/game/index.tsx`, `spinquest-mobile-app/src/app/(tabs)/index.tsx`.

## promotions-and-bonuses

Summary: no promotion engine (the `promotion` schema was dropped); promotions are `json_config` reward tables (daily bonus, login streak, wheel, push bonus, signup bonus), `shop_package.discount` offers, AMOE codes and admin grants, and copy hardcoded in clients.

paths:
- `Backend/src/api/controllers/main/{Rewards,ShopPackage,Amoe,Affiliate}Controller.ts`
- `Backend/src/services/{Rewards,ShopPackage,AsyncShopPackage}Service.ts`
- `Backend/src/services/amoe/**`
- `Backend/src/services/admin/AmoeService.ts`
- `spinquest-frontend/src/features/promotions/**`
- `spinquest-frontend/src/features/casino/components/lobby-view/casino-lobby-hero/**`
- `spinquest-frontend/src/lib/api/rewards/**`
- `spinquest-mobile-app/src/lib/api/rewards/**`
- `spinquest-mobile-app/src/features/{promotions,giveaway}/**`
- `spinquest-mobile-app/src/features/casino/api/use-*daily-bonus*.ts`

Invariants:
- `applyDailyBonus` runs in a `SERIALIZABLE` transaction; a partial claim is a multiple of `maximum / 10`.
- Daily bonus state is derived (cycle sum of `daily_bonus` transactions vs `json_config.daily_bonus`); there is no claim table.
- Set `user.lastDailyBonus` only on the first claim of a cycle.
- Daily bonus and AMOE credit `playThrough` of 3x the sweeps amount.
- Keep both claim routes: banners use `GET /rewards/dailyBonus/claim`, mobile lobby taps use the POST.
- `checkShopPackage` hides offers per user flags (`newPlayerOffer`, `first15minutes`, `oneTime50KGC`) and packages over $500 unless `liftedLimit`; logged-out users get none.
- The free 50K offer (`price === 0`) updates exactly one row or throws.
- Ledger types are fixed in `Transaction.ts`; never invent one without the entity.

Gotchas:
- Any `/rewards/*` URL returns 401 for users with unverified phone or email (prefix check); the FE does not pre-check.
- Geo and blocked-state middleware on rewards is commented out, while the shop applies it.
- Giveaway constants are duplicated in web and mobile: two deploys per change.
- `first_15_minutes` has no FE `OFFERS` constant; landing offer text is JSX, not linked to `shop_package`.
- AMOE amounts are constructor literals: a Backend deploy to change.

Start here: `Backend/src/services/RewardsService.ts`, `Backend/src/services/ShopPackageService.ts`, `spinquest-frontend/src/features/casino/components/lobby-view/casino-lobby-hero/use-daily-bonus-bubble.ts`, `spinquest-mobile-app/src/lib/api/rewards/index.ts`.

## notifications

Summary: in-app notifications are `notifications` rows pushed by a Postgres trigger and `LISTEN emitter` over Socket.IO to web and mobile bells; push is sent by Optimove from the mobile app; the Backend only stores FCM tokens.

paths:
- `Backend/src/services/socketEmiter/**`
- `Backend/src/sockets/**`
- `Backend/src/services/{Notification,FirebaseMessage}Service.ts`
- `Backend/src/api/controllers/{main,admin}/NotificationController.ts`
- `Backend/src/db/entity/{Notification,NotificationReceived,FirebaseMessage}.ts`
- `spinquest-frontend/src/features/notifications/**`
- `spinquest-frontend/src/lib/{api/notification,socket}/**`
- `spinquest-mobile-app/src/features/notifications/**`
- `spinquest-mobile-app/src/lib/{notifications,optimove,firebase}/**`
- `spinquest-mobile-app/src/hooks/use-optimove-push-handlers.ts`

Invariants:
- The listener runs only when `API_TYPE === 'Fundist'` and `FORK_ZERO` are set; other processes insert but never emit.
- The listener emits only `type === 'toast'` rows (event `notification`) or rows with a `command` (event `command`).
- `popup` rows (free spins, push bonus) are emitted directly after commit; the listener ignores them.
- `notification` and `command` go to room `usr<userId>`; the client acks `notificationReceived { notificationId, multi, userId }`.
- `receivedAt` is the soft-delete column; global rows (`userId` null) record reads in `notifications_received`.
- FE presentation is keyed on title strings: changing a Backend title changes or breaks which modal or toast appears.
- Mobile push priorities: `critical`, `gameplay` (default), `engagement`, `promotional`; opened pushes navigate via the payload's custom `url`, not Optimove's `notification.url`.
- The Backend token upsert reads `appDeviceId` and `fcmToken`, only when `source !== 'web'`.

Gotchas:
- FE matcher `❌ Failed` never matches Backend `❌ Purchase Failed`; `Redemption Confirmed` and `Deposit Failed` titles have no live source.
- `notificationReceived` has no ownership check and `multi` arrives undefined, so a global row can be soft-deleted for everyone.
- No replay on reconnect; missed rows appear on the next `GET /notification`.
- Mobile sends `deviceId` and `token` (Backend reads other names) and never sets `pushNotifications`, so `push_notification_bonus` is never paid.
- `tray` rows and global rows are never delivered live (inferred: room `usrnull`).

Start here: `Backend/src/services/socketEmiter/DBEmitterService.ts`, `Backend/src/sockets/controllers/CommonController.ts`, `spinquest-frontend/src/features/notifications/components/notifications-socket-provider.tsx`, `spinquest-mobile-app/src/hooks/use-optimove-push-handlers.ts`.

## payments

Summary: purchases (Paytech card and Apple Pay, LinkMoney ACH) credit coins only from the Backend webhook through `addCoinsToBalance`; redemptions debit SC atomically then pay out through Paytech, with an admin step for ACH.

paths:
- `Backend/src/services/Payments/**`
- `Backend/src/services/{ShopPackageService,AsyncShopPackageService,PaymentSessionService}.ts`
- `Backend/src/api/controllers/{paytech,linkmoney,aeropay}/**`
- `Backend/src/api/controllers/main/ShopPackageController.ts`
- `Backend/src/{services/admin/PaymentService.ts,api/controllers/admin/PaymentsController.ts}`
- `Backend/src/db/entity/{Payment,Linkmoney}/**`
- `spinquest-frontend/src/features/{shop,wallet,transactions}/**`
- `spinquest-frontend/src/lib/api/{shop,link-money,transaction-history}/**`
- `spinquest-mobile-app/src/features/{shop,wallet}/**`
- `spinquest-mobile-app/src/lib/api/shop/**`

Invariants:
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

Gotchas:
- The LinkMoney webhook has no signature check (`LINKMONEY_WEBHOOK_KEY` never read): a forged `payment.authorized` credits coins.
- Webhooks write `state` unconditionally; a redemption `COMPLETED` then `DECLINED` is refunded; LinkMoney failures after `AUTHORIZED` never reverse.
- A payout call that throws leaves the row in `CHECKOUT`, so admin approval can run twice.
- The daily purchase cap is checked at payment creation but incremented at credit, so parallel checkouts each pass.
- Mobile purchases load the web checkout in a WebView: a web checkout change is a mobile change.

Start here: `Backend/src/services/ShopPackageService.ts`, `Backend/src/services/AsyncShopPackageService.ts`, `Backend/src/services/Payments/paytech/PaytechService.ts`, `Backend/src/api/controllers/main/ShopPackageController.ts`.
