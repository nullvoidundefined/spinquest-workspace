---
paths:
  - "spinquest-frontend/**"
---

# spinquest-frontend

## Stack

React 18, TypeScript, Vite 6, MUI 5 + Emotion, TanStack Query + axios, zustand, react-router 6, i18next, vitest + Testing Library, Playwright, Storybook. pnpm. No agent doc; background in `personal-docs/spinquest-frontend-dossier.md` and `TESTING_GUIDE.md`.

## Verify ladder

1. `pnpm lint` (`eslint src`).
2. `pnpm typecheck` (pre-commit runs it).
3. `pnpm test` (vitest). CI never runs it; run it yourself. A timezone-dependent test passes only with `TZ=UTC`.
4. `pnpm build` (casino; `build:cards` for cards). CI runs only this build.
5. `pnpm test:e2e` (Playwright) when a flow changes.
6. Real path: `/local-stack up`, open it in the browser pane, then one failure path.

## Where new code goes

- Feature code in `src/features/<f>/`: `components/`, `api/` (query hooks, `keys.ts`), `hooks/`, `*.store.ts`, `constants.ts`.
- Feature routes in `route.factory.ts(x)` exporting `<feature>RouteFactory: RouteFactory` with lazy pages.
- HTTP in `src/lib/api/<domain>/`; app-wide constants in `src/lib/constants/*.ts`; env in `src/config/env.ts`.
- Folder component: `index.tsx`, sibling `styles.ts`, `index.test.tsx`; stories CSF3 beside it.

## Conventions (observed)

- Components `export const Name = (...) =>` with `interface NameProps`.
- Hooks `use-<thing>.ts` exporting `export const useThing = () =>`.
- MUI only: `sx` or `styled()` in `styles.ts`; no `className`, no Tailwind.
- i18n through `useTranslation` from `@/hooks/translation/use-translation`, never `react-i18next`; always `t('key', 'English fallback')`.
- Toasts `toast.error` / `toast.success` from `react-toastify`.
- Flags `getFlag(key, fallback)` from `@/lib/analytics`.
- Query keys with `createQueryKeys`.
- Unit tests colocated; `vi.mock('@/...')` with `vi.hoisted`; no msw; hooks via `renderHook` with a per-test `QueryClientProvider` (`retry: false`).
- e2e mocks via `page.route` in `e2e/fixtures/*.mock-api.ts`; flow helpers in `e2e/utils/<area>.ts`.
- `import/no-restricted-paths` is configured with no zones and enforces nothing; keep feature boundaries by hand.

## Hard rules

- A new `VITE_APP_*` var is wired through the `Dockerfile`, `docker-compose.yaml`, `build.yaml` and every `deploy-*.yaml` workflow.
- Sensitive inputs carry `sentry-block ph-no-capture` (aspirational).
- Product-specific code is lazy-loaded.

## Review norms

- Keep PRs near 300 lines, with screenshots for UI.
- Commit Lottie JSON minified.

## When to ask

- Before any deploy workflow run (`gh workflow run` asks).

Derived from PR reviews 2026-05-11 to 2026-11-11, plus `TESTING_GUIDE.md` and `personal-docs/spinquest-frontend-dossier.md`.
