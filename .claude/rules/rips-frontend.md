---
paths:
  - "spinquest-rips-frontend/**"
---

# spinquest-rips-frontend

`AGENTS.md` (loaded through the repo's `CLAUDE.md`) is the authority; read its Hard rules, Where new code goes and Verifying a change before editing. This file adds only what it lacks.

## Stack

React 19, Vite, Tailwind 4, React Router, TanStack Query via `packages/rips-core`; native screens in `packages/rips-native`, Expo preview in `apps/rips-native-preview`. npm, not pnpm.

## Verify ladder

1. `npm run lint:check`.
2. `npm run prettier:check`.
3. `npm test`.
4. `npm run build` (`tsc -b` then `vite build`).
5. Real path: `npm run dev:local:status`, then the browser pane on :5173 (native: `npm run dev:local:native`), then one failure path.

## Where new code goes

See the `AGENTS.md` table. Default: `src/features/<feature>/`; portable data layer in `packages/rips-core/`.

## Conventions (observed)

- Tests in `__tests__/`; helpers `fake*.ts` or `*TestKit.tsx`; titles lowercase prose without "should".
- MSW overrides via `server.use(http.get(apiUrl(...)))`; render with `renderWithProviders` from `@/test/render`.
- Components `export function`; helpers and handlers are `function` declarations.
- Pages `<Name>Page.tsx` at the feature root; native screens `Rips<Name>Screen.tsx`.
- rips-core utils `<camel>.util.ts` exporting one `export class <Pascal>Util` of static methods.
- Feature helpers in `features/<f>/utils/<camelName>.ts` as plain functions.
- Display text in `utils/<feature>Vocabulary.ts` as `Record<EnumFromCore, string>`, same name on web and native.
- rips-core query hooks return `Use<Name>Result` `{ data..., isLoading: isPending, error: string | null }`, never raw `useQuery`; `queryFn` passes `signal`.
- Endpoints `export const <domain>Api = { ... }` in `api/endpoints/<domain>.ts`.
- No `clsx`/`cva`/`cn`: template literals plus `<component>Classes.ts` `Record<Variant, string>` maps.
- eslint ignores `packages/rips-native/**` and `apps/**`: apply import order, `===` and no-floating-promises there by hand.

## Hard rules

Top five from `AGENTS.md`:

- `fetch` lives only in `packages/rips-core` `api/client.ts` (plus the listed bypasses).
- No `userId` in any request.
- No `import.meta.env` outside `src/config/env.ts`.
- Never import `@config/session` outside `src/start.tsx` and `src/features/dev/`.
- Branch on `body.code`, never message text; narrow with `instanceof ApiError`.

## Review norms

- The debug tape redacts response bodies.
- Mutations carrying secrets or PII set `gcTime: 0`.
- Root and `apps/rips-native-preview` lockfiles bump together with the peer range.

## When to ask

See `AGENTS.md` "When to ask the user".

Derived from PR reviews 2026-05-11 to 2026-11-11, plus `AGENTS.md`.
