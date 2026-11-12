---
paths:
  - "Backend/**"
---

# Backend

## Stack

Node + TypeScript, Express with routing-controllers, TypeDI, TypeORM on Postgres 17, Redis, Socket.IO, jest. pnpm only (`only-allow pnpm`). Repo doc: `docs/getting-started.md`, `docs/testing-usage-guide.md`.

## Verify ladder

1. `pnpm lint` (runs `eslint --fix`).
2. `pnpm build` (tsc). There is no separate typecheck script.
3. `pnpm test` (unit; skips `*.integration.test.ts`).
4. `pnpm test:integration:ci` (throwaway Postgres and Redis in Docker; same as CI).
5. Migration change: `pnpm db:migrate`, `pnpm db:generate --check`, `pnpm db:revert` (CI runs all three).
6. Real path: `/local-stack up`, call the endpoint, then one failure path.

## Where new code goes

- Endpoints `src/api/controllers/<main|admin|provider>/`; DTOs `src/api/validators/`.
- Logic `src/services/<Domain>/`; entities `src/db/entity/<Domain>/`; repos `src/db/repository/<Domain>/`.
- Errors `src/errors/<Domain>Error.ts`; migrations `src/db/migration/`.
- Tests `tests/` mirroring `src/`: `<Source>.test.ts`, `<Source>.integration.test.ts`.

## Conventions (observed)

- Class modules PascalCase after the class; repos `xRepository.ts` with one exported singleton.
- `@Service()` classes with TypeDI constructor injection; never `Container.get`.
- Controllers `@JsonController(...)`; auth `@Authorized({ api, ... } as Auth)`.
- Logger `@Logger(__filename) private logger: LoggerInterface`.
- Throw one `BaseError(code, message, data?)` subclass per domain, from `@errors/*`.
- class-validator DTO classes bound with `@Body()` / `@QueryParams()` / `@Params()`.
- bigint ids typed `string`, PK default `flake_id()`; `timestamp with time zone`; money and points `int8` cents with `LargeNumberTransformer`.
- Migrations use raw `queryRunner.query` SQL.
- Integration tests hit the real DB with `tests/fixtures/*.ts`, no `jest.mock`; HTTP tests use `tests/helpers/testApp.ts` (`bootTestApp`, `mintUserToken`) with supertest.
- Unit tests pass hand-built stubs `{ fn: jest.fn() } as unknown as X`.
- Unique columns from crypto entropy, not faker.

## Hard rules

- Atomic flows run in `isolatedTransaction(async (em) => ...)` from `@db/isolatedTransaction`.
- Inside it, write only through `em`, never a global repository (aspirational).
- Send notifications, email and socket pushes after commit.
- Migration `down()` fully reverts. Never edit an applied migration. Filenames `<timestamp>-kebab-case.ts`.
- Update with explicit `repository.update(...)`, not `.save()` on a fetched entity (aspirational).
- Gameplay and payout paths exclude banned users; `withDeleted` is a deliberate choice.
- Middleware reads `req.path`, never `req.url`.
- Throw specific error types; never leak internal text to clients.
- Log through `LoggerInterface`, never `console` (aspirational: about 50 calls remain).

## Review norms

- `innerJoin` over `innerJoinAndSelect` when the join is not read; `getExists()` over `getOne()`.
- PRDs and design notes go to Notion or Linear, not the repo.
- Skip race hardening for millisecond windows unless the fix is one index or `WHERE` clause.

## When to ask

- Before `pnpm db:migrate` / `db:revert` against anything but a local DB.

Derived from PR reviews 2026-05-11 to 2026-11-11, plus `docs/getting-started.md` and `docs/testing-usage-guide.md`.
