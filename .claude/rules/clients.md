---
paths:
  - "spinquest-frontend/**"
  - "spinquest-mobile-app/**"
  - "spinquest-rips-frontend/**"
---

# Client repos

## Conventions (observed)

- Unit tests: `describe` + `it`, never `test`; explicit `import { describe, it, expect, vi } from 'vitest'`; query by role and text, not test ids.
- spinquest-frontend and spinquest-mobile-app share one data architecture:
  - HTTP only in `src/lib/api/<domain>/index.ts` (+ `types.ts`) as arrow `verbNoun(data, options?) => customInstance<T>(...)`. Never call axios or fetch from a feature.
  - React Query hooks in `features/<f>/api/use-*.ts` return `useQuery(...)` / `useMutation(...)` directly; invalidate or `setQueryData` in `onSuccess`.
  - Query keys in `features/<f>/api/keys.ts`.
  - Stores `use<Name>Store = create<XState>(...)` in `*.store.ts`; read through selectors, `getState()` only outside React.
  - Forms: react-hook-form + `zodResolver`.
  - Routes from `ROUTES.X` / `ROUTE_*` constants, never string paths.
  - Analytics through `trackEvent` with a registered event name.
- Component declaration, styling, test location and React import differ per repo on purpose; follow the repo file, never copy across repos.

## Review norms

- C1. Every user-facing string, accessibility labels included, goes through i18n, with the key in every locale file.
- C2. Check layouts at 320 and 375px, with the longest locale and large system text.
- C3. A failed read never renders as an empty or default state: show the error with Retry and block the actions that depend on it.
- C4. Scope per-user state to the user and clear it on logout; drop async results that land after the user changes.
- C5. Async results get `role="status"` or `role="alert"`; modals take, trap and restore focus; an ARIA role comes with its keyboard behaviour. Accessibility wins over a Figma detail; flag the divergence to design.
- C6. A fix to shared behaviour lands on web and native together; copy matches across them.

Derived from PR reviews 2026-05-11 to 2026-11-11, plus a code survey on 2026-11-11.
