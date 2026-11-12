---
paths:
  - "spinquest-frontend/**"
  - "spinquest-mobile-app/**"
  - "spinquest-rips-frontend/**"
source: PR reviews 2026-05-11 to 2026-11-11, plus a code survey on 2026-11-11
---

# Client repos

## Conventions

- Unit tests: `describe` + `it`, never `test`; explicit `import { describe, it, expect, vi } from 'vitest'`. Component tests query by role and text; add a test id only when neither works.
- spinquest-frontend and spinquest-mobile-app share one data architecture:
  - HTTP in `src/lib/api/<domain>/` through `customInstance<T>(...)`, as arrow `verbNoun(data, options?)`. Features never call axios or fetch directly.
  - React Query hooks in `features/<f>/api/use-*.ts` return `useQuery(...)` / `useMutation(...)` directly; invalidate or `setQueryData` in `onSuccess`.
  - Query keys in `features/<f>/api/keys.ts`.
  - Stores `use<Name>Store = create<XState>(...)`; read through selectors, `getState()` only outside React.
  - Forms: react-hook-form + `zodResolver`.
  - Routes from `ROUTES.X` / `ROUTE_*` constants, never string paths.
  - Analytics through `trackEvent`; event names come from a constant, never a literal at the call site.
- Component declaration, styling, test location and React import differ per repo on purpose; follow the repo's file, never copy across repos.

## Review norms

- Every user-facing string, accessibility labels included, goes through i18n, with the key in every locale file.
- Check layouts at 320 and 375px, with the longest locale and large system text.
- A failed read never renders as an empty or default state: show the error with Retry and block the actions that depend on it.
- Scope per-user state to the user and clear it on logout; drop async results that land after the user changes.
- Async results get `role="status"` or `role="alert"`; modals take, trap and restore focus; an ARIA role comes with its keyboard behaviour. Accessibility wins over a Figma detail; flag the divergence to design.
- A fix to shared behaviour lands on web and native together; copy matches across them.
