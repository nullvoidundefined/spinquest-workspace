# Code conventions survey

Measured 2026-11-11 by read-only surveys of each repo (rg/grep counts, then ~15 representative
files read). A convention is followed by >=80% of the measured code; "mixed" is 50 to 80%.
Anything prettier, eslint or tsconfig already enforces is listed under "Tooling" and is never
restated as a rule. Source for the "Conventions (observed)" sections of `.claude/rules/*.md`.

Mixed-area default (approved): follow the direction recent code leans; with no clear lean, match
the surrounding file.

## Global

- CV1. Named exports only. Exceptions: expo-router route files (default export required),
  Storybook `export default meta`. (Backend 469/475, rips 655/655, central 100%, frontend recent 86/90.)
- CV2. Module-level constants in UPPER_SNAKE_CASE; an `as const` value set takes a PascalCase name
  with a same-name derived union (`export type X = (typeof X)[keyof typeof X]`) instead of `enum`.
- CV3. `interface` for object shapes; props interface named `<Name>Props`.
- CV4. Read env vars only through the repo's accessor (Backend `GetString`/`GetBool`/`GetInt` from
  `@services/EnvironmentConfig`; frontend `env` from `@/config/env`; rips `src/config/env.ts`;
  central `config/env.ts`).
- CV5. Cross-folder imports use the repo's path alias; `./` only for same-folder siblings.
  Exceptions: rips-native has no aliases (relative + `@betsphereorg/rips-core`); frontend is mixed
  (64% alias, recent code drifting relative).

## Clients (spinquest-frontend, spinquest-mobile-app, spinquest-rips-frontend)

- Tests: `describe` + `it`, never `test`; explicit `import { describe, it, expect, vi } from 'vitest'`;
  query by role and text, not test ids.
- spinquest-frontend and spinquest-mobile-app share an architecture:
  - HTTP calls in `src/lib/api/<domain>/index.ts` with `types.ts`, each an arrow
    `verbNoun(data, options?: AxiosRequestConfig) => customInstance<T>({ method, url, data }, options)`.
    Never call axios or fetch from a feature.
  - React Query hooks in `features/<f>/api/use-*.ts`, returning `useQuery(...)` / `useMutation(...)`
    directly; invalidation or `setQueryData` in `onSuccess`.
  - Query keys in `features/<f>/api/keys.ts` (frontend: `createQueryKeys`, 83%; mobile: hand-rolled
    `<feature>Keys`, mixed).
  - Stores: `use<Name>Store = create<XState>(...)` in `*.store.ts`; read with selectors
    (`useXStore((s) => s.field)`), `getState()` only outside React.
  - Forms: react-hook-form + `zodResolver`.
  - Routes from constants (`ROUTES.X` / `ROUTE_*`), not string paths.
  - Analytics through `trackEvent` with a registered event name.

### Deliberate differences (per-repo rules only, never shared)

| | spinquest-frontend | spinquest-mobile-app | spinquest-rips-frontend |
|---|---|---|---|
| Component declaration | `export const X = (...) =>` | `export const X: React.FC<XProps> = (...) =>` | `export function X` |
| Styling | MUI `sx` or `styled()` in sibling `styles.ts` | NativeWind `className`, `cva` + `cn` in ui primitives | web: Tailwind template literals + `<x>Classes.ts` Record maps; native: `StyleSheet.create` at file bottom |
| Test location | colocated `*.test.ts(x)` | colocated `*.test.ts` | `__tests__/` |
| React import | mixed | `import React from 'react'` | never default-import React |

## Backend

Conventions:
- Class modules PascalCase after the class (`XController.ts`, `XService.ts`, entity `X.ts`); utils camelCase.
- Repositories `camelCaseRepository.ts`, one `export const xRepository` singleton per file.
- Layout: endpoints `src/api/controllers/<main|admin|provider>/`, DTOs `src/api/validators/`,
  logic `src/services/<Domain>/`, entities `src/db/entity/<Domain>/`, repos
  `src/db/repository/<Domain>/`, errors `src/errors/<Domain>Error.ts`.
- Migrations `<timestamp>-kebab-case.ts`, raw `queryRunner.query` SQL.
- Services, controllers, middleware are `@Service()` classes with TypeDI constructor injection;
  never `Container.get`. Controllers: `@Service()` + `@JsonController(...)`; auth
  `@Authorized({ api, ... } as Auth)`.
- Logger injected: `@Logger(__filename) private logger: LoggerInterface`.
- async/await (1616 vs 8 `.then`).
- Throw typed errors: one `BaseError(code, message, data?)` subclass per domain, specific
  subclasses fix the status (see `src/errors/MerchError.ts`). Import from `@errors/*`.
- Validation: class-validator DTO classes bound with `@Body()` / `@QueryParams()` / `@Params()`.
- TypeORM: bigint ids typed `string`, PK default `flake_id()`; `timestamp with time zone`;
  money and points as `int8` cents with `LargeNumberTransformer`; repository methods or
  `createQueryBuilder`, raw `.query` rare.
- Transactions: `isolatedTransaction(async (em) => ...)` from `@db/isolatedTransaction`; use the
  EntityManager argument inside. (30 files; 24 of 26 recent additions.)
- Path aliases `@api @auth @db @errors @services @sockets @utils @validators` (96%).
- Tests under `tests/` mirroring `src/`; `<Source>.test.ts` and `<Source>.integration.test.ts`;
  `it` inside `describe`; integration tests hit the real DB via `dataSource` with
  `tests/fixtures/*.ts` seed/teardown, no `jest.mock`; unit tests pass hand-built stubs
  (`{ fn: jest.fn() } as unknown as X`); HTTP tests use `tests/helpers/testApp.ts`
  (`bootTestApp`, `mintUserToken`) with supertest; unique columns from crypto entropy, not faker.

Mixed (recent direction): `@errors` over routing-controllers HttpErrors; `interface` over `type`;
`as const` over `enum`; UPPER_SNAKE constants in `services/<Domain>/constants.ts`;
`ExtendedRepository`; `private readonly` injected fields; DTO suffix per binding
(`Body`/`Query`/`Response`); native `Date`, luxon only for ISO date-only parsing.

Observed gaps against documented norms: 50 `console` calls in 22 src files; booleans
`is/has/did` only 21% of 150; logger messages mostly interpolated with no context object;
`isolatedTransaction` swallows commit-hook errors.

Tooling: prettier (no semi, single quotes, width 80); eslint import-x/order, eqeqeq,
no-else-return, array-simple, no-public accessibility, no-shadow; tsconfig strict,
noUncheckedIndexedAccess; jest clearMocks/restoreMocks. Not enforced: no-console, alias imports,
boolean naming, logger shape.

## central-tech (packages, templates/service, vendor-stubs; real services are not on disk)

Conventions:
- Tests: `node:test` + `import assert from 'node:assert/strict'`, compiled to `dist-test`, run
  with `node --test`; flat top-level `test('lowercase behaviour sentence')`; fakes and real local
  servers (`createServer(...).listen(0)` on 127.0.0.1) over mocks; cleanup in `try/finally` or
  `after`; test files camelCase after a module or concern.
- `function` declarations over `const` arrows (92%).
- `import type {}` when every name is a type, inline `type` otherwise.
- `node:` prefix on builtins; extensionless relative imports (CommonJS).
- UPPER_SNAKE constants kept in the module that uses them.
- Singletons: unexported class, exported camelCase instance.
- Per-file logger `const boot = log.forOrigin('<service>.<layer>.<File>')`; message first,
  lowercase, then fields; errors under `error`.
- HTTP error bodies `{ code: 'UPPER_SNAKE' }`; controllers refuse with early
  `return void res.status(4xx).json(...)`.
- `{ ok: true } | { ok: false; ... }` result unions inside a layer or package API.
- Catch binding named `error`; bare `catch {` when unused.
- Packages (not services) take dependencies as defaulted parameters (`env = process.env`,
  injected `log`/`fetch`); services must not copy this.
- Packages: flat camelCase `src/` with `index.ts` entry; package.json scripts exactly
  build/test/typecheck, CommonJS, `files: ["dist"]`, `"license": "UNLICENSED"`, `workspace:^`
  runtime deps, `tsconfig.test.json` with `outDir: dist-test`, a CHANGELOG.
- Commits `type(scope): lowercase summary (#PR)`.

Adherence gaps: vendor-stubs keeps zod schemas in controllers without the `Schema` suffix and reads
`process.env` outside `config/env.ts`; no `constants.ts` exists anywhere; packages carry doc
blocks despite "no comments by default"; `packages/environment` and `packages/tenants` lack a README.

Tooling: prettier (no semi, single quotes, width 80); eslint import-x/order, eqeqeq,
consistent-type-definitions; tsconfig strict, noUncheckedIndexedAccess, noUnusedLocals.

## spinquest-frontend

Conventions:
- Components `export const Name = (...) =>`; props `interface NameProps`.
- Folder components: implementation in `index.tsx`, sibling `styles.ts`, `index.test.tsx`.
- Hooks `use-<thing>.ts`, `export const useThing = () =>`.
- Feature anatomy: `components/`, `api/` (query hooks), `hooks/`, stores `*.store.ts`, `constants.ts`.
- Routes: `route.factory.ts(x)` exporting `<feature>RouteFactory: RouteFactory` with lazy pages.
- MUI only: `sx` or `styled()` in `styles.ts`; no `className`, no tailwind.
- i18n: `useTranslation` from `@/hooks/translation/use-translation` (not `react-i18next`);
  always `t('key', 'English fallback')`.
- Toasts: `toast.error` / `toast.success` from `react-toastify`.
- Constants SCREAMING_SNAKE; app-wide in `src/lib/constants/*.ts`, feature in `features/<f>/constants.ts`.
- Flags via `getFlag(key, fallback)` from `@/lib/analytics`; analytics via `trackEvent({ event, ... })`.
- Tests colocated `*.test.ts(x)`; `vi.mock('@/...')` with `vi.hoisted`; no msw; hooks tested
  with `renderHook` and a per-test `QueryClientProvider` (`retry: false`).
- e2e: role/text queries, `test.describe`, API mocks via `page.route` in
  `e2e/fixtures/*.mock-api.ts`, flow helpers in `e2e/utils/<area>.ts`.
- Stories CSF3 beside the component.

Mixed: `React.FC<P>` vs annotated parameter (54/46); alias vs relative imports; i18n key style
(recent leans snake_case); `Query`/`Mutation` hook suffix (56%); `handleApiError` vs
`useHandleFundistErrors`.

Notes: 971 hex literals across 250 files; `import/no-restricted-paths` is on with no zones (enforces
nothing).

Tooling: prettier (single quotes, width 80); eslint check-file kebab-case files and folders,
import/order, no-console (error allowed), no-explicit-any, react-hooks, jsx-a11y, testing-library,
vitest, playwright; tsconfig strict; commitlint conventional.

## spinquest-mobile-app

Conventions:
- Route files thin: `export default function <Name>Screen()` wrapping the page in
  `<AppLayout preset=... >` and rendering a feature `<XPage/>`.
- Components `export const X: React.FC<XProps> = (...) =>` (recent 60 vs 3).
- HTTP and React Query per the shared client architecture above; keys `<feature>Keys` in
  `api/keys.ts`.
- Stores `use<Name>Store` in kebab `*.store.ts`; persist only when needed with
  `createJSONStorage(() => AsyncStorage)` and `name: '<thing>-store'`.
- Logging `getLogger(ns?)` from `@/utils/logger`, data as second argument, never `console`.
- Crashes via `reportCrash(error, ErrorType.X)` from `@/utils/crash-reporting`; never Crashlytics directly.
- Analytics `trackEvent(AnalyticsEvents.X, { snake_case_params })`; names in `lib/firebase/analytics-events.ts`.
- Feedback via `showErrorNotification` / `showSuccessNotification` / `showToast` from
  `@/lib/notifications`; messages from `translate('ns:key')` or `getApiErrorMessage(error) ?? translate('common:error')`.
- i18n keys `ns:camelKey`, always namespaced, no dotted nesting.
- Forms `useForm` + `zodResolver` + `<Controller>`, `mode: 'onChange'`.
- UI primitives use `cva` and `cn` from `@/utils/cn`.
- Handlers `handleX`; press targets `TouchableOpacity`.
- Navigation `const router = useRouter()`; tab routes only via `navigateToLobby`,
  `replaceTabRouteForBottomTab`, `dismissToHref` (lint-enforced).
- Tests colocated `*.test.ts`, node environment (logic only), explicit vitest imports, global
  native mocks in `vitest.setup.ts`.
- `import React from 'react'`; no `any`.

`.cursorrules` items at or near 0% adherence (the rules file overrides them): `// RULES ACTIVE`
header; PascalCase component files; kebab-case and dotted translation keys; query-hook template
destructuring `{data, isLoading, error}`; hierarchical `lists/list()/details/detail()` keys;
`schemas/<f>.schemas.ts`; barrel imports; `onError` using `error.message`.

Mixed: query-key shape (recent leans hand-rolled); hook filename suffix (recent leans none);
styling `className` vs inline `style` (lean className, inline for dynamic values); hex vs theme
tokens (37% of files use hex, recent code adds more); `translate()` over `tx=`; logger namespace
(lean namespaced).

Tooling: prettier (width 80); eslint check-file kebab, import/order, type imports last,
`no-restricted-syntax` on tab-route calls; tsconfig strict; lint-staged with
`--max-warnings 0`; pre-commit `tsc --noEmit` and version bump. Not enforced: no-console, inline
styles, colour literals, no-empty.

## spinquest-rips-frontend

Conventions (undocumented in its AGENTS.md):
- Tests in `__tests__/`, `*.test.ts(x)`; helpers `fake*.ts` or `*TestKit.tsx`; titles lowercase
  prose without "should"; MSW overrides via `server.use(http.get(apiUrl(...)))`; render with
  `renderWithProviders` from `@/test/render`.
- rips-core utils `<camel>.util.ts` exporting one `export class <Pascal>Util` of static methods.
- Feature helpers in `features/<f>/utils/<camelName>.ts` as plain functions.
- Feature display text in `utils/<feature>Vocabulary.ts` as `Record<EnumFromCore, string>` maps,
  same name on web and native.
- Components `export function`; helpers and handlers as `function` declarations.
- Pages `<Name>Page.tsx` at the feature root; native screens `Rips<Name>Screen.tsx`.
- rips-core query hooks return `export interface Use<Name>Result` shaped
  `{ data..., isLoading: isPending, error: string | null }`, never raw `useQuery`; mutation hooks
  return `useMutation(...)` with invalidation in `onSuccess`/`onSettled`; `queryFn` passes `signal`.
- Endpoints: `export const <domain>Api = { method: (params, options?) => apiClient.get<T>(...) }`
  in `api/endpoints/<domain>.ts`.
- No `clsx`/`cva`/`cn`: template literals plus `<component>Classes.ts` `Record<Variant, string>` maps.
- Never default-import React.

Adherence gaps against its AGENTS.md: explicit return types on exported web components 17%
(recent 2/57); rips-native import order 89% and `== null` in 11 lines because eslint ignores
`packages/rips-native/**` and `apps/**`; history comments in 28 files (mostly rips-core hooks).

Tooling: prettier (width 160, semicolons); eslint (src and rips-core only) import-x/order,
consistent-type-imports, no-explicit-any, eqeqeq, no-floating-promises; tsconfig strict,
noUncheckedIndexedAccess, verbatimModuleSyntax. Not covered: rips-native and
apps/rips-native-preview (apply import order, `===`, no-floating-promises by hand).
