---
paths:
  - "spinquest-frontend/src/features/feature-flags/**"
  - "spinquest-frontend/src/store/feature-flags.ts"
  - "spinquest-frontend/src/lib/api/flags/**"
  - "spinquest-frontend/src/lib/analytics.ts"
  - "spinquest-frontend/src/lib/posthog.tsx"
  - "spinquest-frontend/src/lib/posthog-device.ts"
  - "spinquest-frontend/src/features/auth/auth-identity-sync.ts"
  - "spinquest-frontend/src/features/mfa/**"
  - "Backend/src/services/FeatureFlagService.ts"
  - "Backend/src/api/controllers/main/FlagsController.ts"
  - "Backend/src/api/express.ts"
  - "Backend/src/api/middlewares/requireOpsFlag.ts"
  - "Backend/src/api/decorators/ForProduct.ts"
  - "Backend/src/utils/analyticsDeviceId.ts"
---

## Summary

Feature flags use three switching mechanisms: browser PostHog flags for anonymous visitors, server-evaluated PostHog flags delivered to logged-in clients via `GET /flags` and the login response, and env-var boot switches. This file also stands in for `.claude/rules/frontend/feature-flags.md`, the path two spinquest-frontend comments cite (that file was never committed).

## Invariants

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

## Gotchas

- Flags targeting person properties are silently omitted from the client payload (only `$device_id` is passed); use "Match by Device".
- `requireOpsFlag` has no call site although the runbook shows it wired.
- `ops-merch-redemption`, `ops-require-2fa`, `ops-singular-events` are read with real user ids, so percentage rollout buckets per user.
- Client MFA needs `ENABLE_MFA`, `ENABLE_SERVER_FLAGS` and `feat-mfa`; Backend needs only the flag. Nothing checks env consistency across repos.
- Cold store or a 401 refetch makes authenticated reads return the fallback; propagation can take about 10s plus 2 minutes.

## Start here

`spinquest-frontend/src/lib/analytics.ts`, `spinquest-frontend/src/features/feature-flags/flags-sync.tsx`, `Backend/src/services/FeatureFlagService.ts`, `Backend/docs/feature-flags-runbook.md`.

Distilled on 2026-11-11 from personal-docs/feature-flags.md; re-check with /trace-feature refresh.
