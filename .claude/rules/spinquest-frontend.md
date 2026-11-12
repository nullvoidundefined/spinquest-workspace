---
paths:
  - "spinquest-frontend/**"
source: PR reviews 2026-05-11 to 2026-11-11, plus TESTING_GUIDE.md
---

# spinquest-frontend

## Stack

React 18, TypeScript, Vite 6, MUI 5 + Emotion, TanStack Query + axios, zustand, react-router 6, i18next, vitest + Testing Library, Playwright, Storybook. pnpm. No agent doc; testing background in `TESTING_GUIDE.md`.

## Verify ladder

1. `pnpm lint` (`eslint src`).
2. `pnpm typecheck` (pre-commit runs it).
3. `pnpm test` (vitest). CI does not run it; run it yourself.
4. `pnpm build`, plus `pnpm build:cards` when shared code changes.
5. `pnpm test:e2e` (Playwright) when a flow changes.
6. Real path: `/local-stack up`, open it in the browser pane, then one failure path.

## Where new code goes

- Feature code in `src/features/<f>/`: `components/`, `api/` (query hooks, `keys.ts`), `hooks/`, `*.store.ts`, `constants.ts`.
- Feature routes in `route.factory.ts(x)` with lazy pages; match the export shape of the neighbouring factories.
- HTTP in `src/lib/api/<domain>/`; app-wide constants in `src/lib/constants/*.ts`; env in `src/config/env.ts`.
- Folder component: `index.tsx`, sibling `styles.ts`, `index.test.tsx`; stories CSF3 beside it.

## Conventions

- Components `export const Name = (...) =>` with `interface NameProps`.
- Hooks `use-<thing>.ts` exporting `export const useThing = () =>`.
- Style with MUI: `sx`, or `styled()` in the sibling `styles.ts`. No Tailwind; no new `className` styling.
- i18n through `useTranslation` from `@/hooks/translation/use-translation`, not `react-i18next`; write `t('key', 'English fallback')`.
- Toasts `toast.error` / `toast.success` from `react-toastify`.
- Flags `getFlag(key, fallback)` from `@/lib/analytics`, with the key in a constant.
- New query keys with `createQueryKeys`.
- Unit tests colocated; `vi.mock('@/...')` with `vi.hoisted`; no msw; hooks via `renderHook` with a per-test `QueryClientProvider` (`retry: false`).
- e2e mocks via `page.route` in `e2e/fixtures/*.mock-api.ts`; flow helpers in `e2e/utils/<area>.ts`.
- `import/no-restricted-paths` has no zones and enforces nothing; keep feature boundaries by hand.

## Hard rules

- A new build-time `VITE_APP_*` var is wired through every place the build reads env: grep an existing var across `Dockerfile`, `docker-compose.yaml` and `.github/workflows/` and add the new one beside it.
- Sensitive inputs carry `sentry-block ph-no-capture`.

## Review norms

- Keep PRs near 300 lines, with screenshots for UI.
- Commit Lottie JSON minified.
