---
paths:
  - "spinquest-rips-frontend/**"
source: PR reviews 2026-05-11 to 2026-11-11, plus AGENTS.md
---

# spinquest-rips-frontend

`AGENTS.md` (loaded through the repo's `CLAUDE.md`) is the authority for stack, structure, the verify ladder, hard rules and when to ask. Read it before editing. This file adds only what it lacks.

## Verify ladder

Follow `AGENTS.md` "Verifying a change", then check the real path in the browser pane on :5173 (native: `npm run dev:local:native`) and one failure path.

## Conventions

- Test helpers `fake*.ts` or `*TestKit.tsx`; titles lowercase prose without "should".
- MSW overrides via `server.use(http.get(apiUrl(...)))`; render with `renderWithProviders` from `@/test/render`.
- Components `export function`; helpers and handlers are `function` declarations.
- Pages `<Name>Page.tsx` at the feature root; native screens `Rips<Name>Screen.tsx`.
- rips-core utils `<camel>.util.ts` exporting one `export class <Pascal>Util` of static methods.
- Feature helpers in `features/<f>/utils/<camelName>.ts` as plain functions.
- Display text in `utils/<feature>Vocabulary.ts` as `Record<UnionFromCore, string>`, same name on web and native.
- rips-core query hooks return `Use<Name>Result` `{ data..., isLoading: isPending, error: string | null }`, never raw `useQuery`.
- Endpoints `export const <domain>Api = { ... }` in `api/endpoints/<domain>.ts`.
- No `clsx`/`cva`/`cn`: template literals plus `<component>Classes.ts` `Record<Variant, string>` maps.
- eslint ignores `packages/rips-native/**` and `apps/**`: apply import order, `===` and no-floating-promises there by hand.

## Hard rules

- Mutations carrying secrets or PII set `gcTime: 0`.
- Root and `apps/rips-native-preview` lockfiles bump together with the peer range.
