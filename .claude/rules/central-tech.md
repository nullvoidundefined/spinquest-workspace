---
paths:
  - "central-tech/**"
---

# central-tech

`AGENTS.md` is the authority, and the `central-conventions` plugin skills (`service-conventions`, `package-conventions`, `service-consistency`, `release`) apply. Start at `reference/overview.md`, then `reference/tenancy.md` and `TODO.md`.

## Stack

pnpm workspace: `packages/*`, `vendor-stubs`, `parity`. TypeScript, CommonJS, `node:test`. Central services use express, drizzle and zod; propose no other library.

## Verify ladder

1. `pnpm lint`.
2. `pnpm typecheck`.
3. `pnpm test`.
4. `pnpm build`.
5. Docs: open every cited `path:line` before writing it.

## Where new code goes

- Settled decisions go to Notion. This repo holds drafts; a published draft is deleted or gets a retirement header pointing at the Notion URL.
- Packages: flat camelCase `src/` with `index.ts`; scripts exactly build/test/typecheck; `files: ["dist"]`; `"license": "UNLICENSED"`; `workspace:^` runtime deps; `tsconfig.test.json` with `outDir: dist-test`; a CHANGELOG.

## Conventions (observed)

- Tests: `node:test` + `node:assert/strict`; flat top-level `test('lowercase behaviour sentence')`; real local servers (`listen(0)` on 127.0.0.1) and fakes over mocks; cleanup in `try/finally` or `after`.
- `function` declarations over `const` arrows.
- `import type {}` when every name is a type, inline `type` otherwise; `node:` prefix on builtins; extensionless relative imports.
- UPPER_SNAKE constants stay in the module that uses them.
- Singletons: unexported class, exported camelCase instance.
- Logger `log.forOrigin('<service>.<layer>.<File>')`; lowercase message first, then fields; errors under `error`.
- HTTP error bodies `{ code: 'UPPER_SNAKE' }`; controllers refuse with early `return void res.status(4xx).json(...)`.
- `{ ok: true } | { ok: false; ... }` result unions inside a layer or package API.
- Catch binding `error`; bare `catch {` when unused.
- Packages take dependencies as defaulted parameters (`env = process.env`); services never copy this.

## Hard rules

- Pods hold no user or session state. This blocks a merge.
- A `reference/` file carries a `Verified <date> against <source>` line; bump it when adding a newer fact.
- One capability, one place: link to the owner's page instead of retelling.
- Never cite a private workspace path (`~/Projects/...`).
- Port Backend as is.

## Review norms

- No volatile counts in prose. Tense matches state; no heading pinned to a PR number.
- Qualify cross-repo PR refs (`auth-service#220`). Write "RIPS" in prose.
- Read untrusted input once and work from the snapshot.
- Consume async callbacks: `=> void` does not stop a promise.
- Byte budgets in bytes, not `.length`.
- README snippets compile.
- A new compose service joins the CI failure-log loop.
- Respect `engines.node`.
- No major changesets before launch.

## When to ask

- Anything `TODO.md` lists as waiting on someone: ask, never invent the answer.

Derived from PR reviews 2026-05-11 to 2026-11-11, plus `AGENTS.md`.
