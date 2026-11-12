---
paths:
  - "spinquest-frontend/src/features/auth/**"
  - "spinquest-frontend/src/lib/api/auth/**"
  - "spinquest-frontend/src/app/providers/referral-code-provider.tsx"
  - "spinquest-frontend/src/components/common/app-guards/**"
  - "Backend/src/api/controllers/main/AuthController.ts"
  - "Backend/src/api/controllers/main/TermsController.ts"
  - "Backend/src/services/AuthService.ts"
  - "Backend/src/services/SocialOAuthService.ts"
  - "Backend/src/services/TermsService.ts"
  - "Backend/src/services/LoginCodeService.ts"
  - "Backend/src/services/sinch/**"
  - "Backend/src/services/terms/**"
  - "Backend/src/services/kyc/**"
  - "Backend/src/services/affiliate/**"
  - "Backend/src/api/middlewares/custom/GeoComplyMiddleware.ts"
  - "Backend/src/api/middlewares/custom/BlockedStatesMiddleware.ts"
  - "Backend/src/utils/geolocation.ts"
  - "Backend/src/utils/turnstile.ts"
---

## Summary

Signup and onboarding on web is a two-step email/password form posting once to `POST /auth/social-signup`, which runs geo, captcha, age, terms and referral checks, creates the user in one transaction and runs IDComply; Sinch phone confirmation gates play.

## Invariants

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

## Gotchas

- Signup does not start phone verification; the dialog sends the first code. A client skipping the dialog creates an account that cannot load games.
- The signup bonus comes from the `signup_bonus` json_config row (GC and diamonds only); `SIGNUP_*_COINS_BONUS` env keys are never read.
- `useRegister` and `/auth/signup` are dead; the live route is `/auth/social-signup`.
- Web KYC checks `sessionStatus === 'approved'`; Backend checks `status === 'VERIFIED'`.
- The verification email is sent before IDComply, outside the transaction, with uncaught send errors; the `confirmUserPhone` "already confirmed" guard is commented out.

## Start here

`spinquest-frontend/src/features/auth/components/auth-page/register-flow.tsx`, `Backend/src/api/controllers/main/AuthController.ts`, `Backend/src/services/AuthService.ts`, `spinquest-frontend/src/features/auth/components/verify-number-otp/index.tsx`.

Distilled on 2026-11-11 from personal-docs/signup-and-onboarding.md; re-check with /trace-feature refresh.
