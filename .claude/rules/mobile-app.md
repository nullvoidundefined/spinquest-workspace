---
paths:
  - "spinquest-mobile-app/**"
source: PR reviews 2026-05-11 to 2026-11-11, plus .cursorrules, .husky/ and eas.json
---

# spinquest-mobile-app

This file overrides `.cursorrules` where they disagree. Ignore these `.cursorrules` items, which the code does not follow: the `// RULES ACTIVE` header, PascalCase component files, kebab or dotted i18n keys, the `{data, isLoading, error}` query-hook template, hierarchical `lists/list()/details/detail()` keys, `schemas/<f>.schemas.ts`, barrel imports, `error.message` in `onError`, and the `Info.plist` version steps.

## Stack

Expo, React Native, expo-router, NativeWind 4, TanStack Query, zustand, vitest (node environment, no component rendering). pnpm. Release builds via EAS.

## Verify ladder

1. `pnpm lint` (`--max-warnings 0`).
2. `pnpm typecheck`.
3. `pnpm test` (logic only).
4. Real path in the iOS Simulator (`pnpm ios` builds locally, or Metro via `pnpm start`), then one failure path.

## Where new code goes

- Route files in `src/app/`; feature code in `src/features/<f>/` (`api/`, `components/`, `hooks/`, `store/`).
- App-wide stores in `src/store/`; HTTP in `src/lib/api/<domain>/`; UI primitives in `src/components/ui/`.
- Shared native mocks in `vitest.setup.ts`, not per test.

## Conventions

- Route files are thin: `export default function <Name>Screen()` wrapping `<AppLayout preset=...>` around a feature `<XPage/>`.
- Components `export const X: React.FC<XProps> = (...) =>`; `import React from 'react'`.
- Query keys `<feature>Keys` in `api/keys.ts`.
- Persist a store only when needed: `createJSONStorage(() => AsyncStorage)`, `name: '<thing>-store'`.
- Log with `getLogger(ns?)` from `@/utils/logger`, data as the second argument.
- Report crashes with `reportCrash(error, ErrorType.X)` from `@/utils/crash-reporting`, never Crashlytics directly.
- Analytics `trackEvent(AnalyticsEvents.X, { snake_case_params })`; names in `lib/firebase/analytics-events.ts`.
- Feedback via `showErrorNotification` / `showSuccessNotification` / `showToast` from `@/lib/notifications`, text from `translate('ns:key')` or `getApiErrorMessage(error) ?? translate('common:error')`.
- i18n keys `ns:camelKey`, always namespaced, never dotted.
- Forms `useForm` + `zodResolver` + `<Controller>`, `mode: 'onChange'`.
- UI primitives use `cva` and `cn` from `@/utils/cn`.
- Handlers `handleX`; press targets `TouchableOpacity`.
- Tests colocated `*.test.ts`.

## Hard rules

- New code styles with NativeWind `className` and theme colours: no hex literals, no `StyleSheet`. Convert existing files only when the PR already rewrites them.
- New code takes `Text` from `@/components/ui`, never `react-native`.
- The app version source is `package.json`; pre-commit bumps the patch. Never edit `Info.plist` versions by hand.
- Effects return cleanup and null their timer refs.
