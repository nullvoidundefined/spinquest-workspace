---
paths:
  - "Backend/**"
source: PR reviews 2026-05-11 to 2026-11-11, plus docs/getting-started.md and docs/testing-usage-guide.md
---

# Backend

## Stack

Node + TypeScript, Express with routing-controllers, TypeDI, TypeORM on Postgres 17, Redis, Socket.IO, jest. pnpm only (`only-allow pnpm`). Repo docs: `docs/getting-started.md`, `docs/testing-usage-guide.md`.

## Verify ladder

1. `pnpm lint` (runs `eslint --fix`).
2. `pnpm build` (tsc). There is no separate typecheck script.
3. `pnpm test` (unit; skips `*.integration.test.ts`).
4. `pnpm test:integration:ci` (throwaway Postgres and Redis in Docker; same as CI).
5. Migration change: `pnpm db:migrate`, `pnpm db:generate --check`, `pnpm db:revert` (CI runs all three).
6. Real path: `/local-stack up`, call the endpoint, then one failure path.

## Where new code goes

- Endpoints `src/api/controllers/main/` or `admin/`; third-party callbacks in `src/api/controllers/<vendor>/`.
- DTOs `src/api/validators/`; vendor payload validators `src/validators/<vendor>/`.
- Logic `src/services/<Domain>/` (older services sit flat in `src/services/`); entities `src/db/entity/`; repositories `src/db/repository/`. Match the casing of the folder you add to.
- Errors `src/errors/<Domain>Error.ts`; migrations `src/db/migration/`.
- Tests `tests/` mirroring `src/`: `<Source>.test.ts`, `<Source>.integration.test.ts`.

## Conventions

- Class modules PascalCase after the class; repositories `<x>Repository.ts` exporting one singleton.
- `@Service()` classes with TypeDI constructor injection; `Container.get` only in composition roots (`src/index.ts`, `src/auth/authorizationChecker.ts`, `src/temporal/activities.ts`).
- Controllers `@JsonController(...)`; auth `@Authorized({ api, ... } as Auth)`.
- Logger `@Logger(__filename) private logger: LoggerInterface`.
- Throw a `BaseError(code, message, data?)` subclass from `@errors/*`, one per domain.
- class-validator DTO classes bound with `@Body()` / `@QueryParams()` / `@Params()`.
- bigint ids typed `string`, PK default `flake_id()`; `timestamp with time zone`; amounts as `int8` integer cents with `LargeNumberTransformer` (`src/db/transformers/LargeIntTransformer.ts`).
- Migrations use raw `queryRunner.query` SQL.
- Integration tests hit the real DB with `tests/fixtures/*.ts` and no `jest.mock`; HTTP tests use `bootTestApp` and `mintUserToken` from `tests/helpers/testApp.ts` with supertest.
- Unit tests pass hand-built stubs `{ fn: jest.fn() } as unknown as X`.
- In new fixtures, build values for unique columns from crypto entropy, not faker.

## Hard rules

- Atomic flows run in `isolatedTransaction(async (em) => ...)` from `@db/isolatedTransaction`. New code inside it writes only through `em`, never a global repository.
- Send notifications, email and socket pushes after commit.
- Migration `down()` fully reverts. Never edit an applied migration. New migration filenames: `<timestamp>-kebab-case.ts`.
- New code updates with explicit `repository.update(...)`, not `.save()` on a fetched entity.
- New middleware reads `req.path`, not `req.url` (the query string breaks prefix checks). Leave existing `req.url` reads alone unless the PR touches them.
- Throw specific error types; never leak internal text to clients.
- New code logs through `LoggerInterface`, never `console`.
- A check-then-write on shared state runs inside one transaction with a conditional `WHERE` or a lock.

## Review norms

- `innerJoin` over `innerJoinAndSelect` when the join is not read; `getExists()` over `getOne()`.
- PRDs and design notes go to Notion or Linear, not the repo.

## When to ask

- Before `pnpm db:migrate` / `db:revert` against anything but a local DB.
