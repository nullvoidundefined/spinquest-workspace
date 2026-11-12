---
paths:
  - "central-tech/**"
source: PR reviews 2026-05-11 to 2026-11-11, plus AGENTS.md
---

# central-tech

`AGENTS.md` is the authority for structure, verify steps and hard rules; the `central-conventions` plugin skills (`service-conventions`, `package-conventions`, `service-consistency`, `release`) apply. This file adds only what those lack.

## Verify ladder

1. `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm build`.
2. Docs: open every cited `path:line` before writing it.

## Conventions

- Tests: `node:test` + `node:assert/strict`; flat top-level `test('lowercase behaviour sentence')`; real local servers (`listen(0)` on 127.0.0.1) and fakes over mocks; cleanup in `try/finally` or `after`.
- `function` declarations over `const` arrows.
- `import type {}` when every name is a type, inline `type` otherwise; `node:` prefix on builtins; extensionless relative imports.
- UPPER_SNAKE constants stay in the module that uses them.
- Singletons: unexported class, exported camelCase instance.
- Logger `log.forOrigin('<service>.<layer>.<File>')`; lowercase message first, then fields; errors under `error`.
- HTTP error bodies `{ code: 'UPPER_SNAKE' }`; controllers refuse with early `return void res.status(4xx).json(...)`.
- `{ ok: true } | { ok: false; ... }` result unions inside a layer or package API.
- Catch binding `error`; bare `catch {` when the error is unused.
- Packages take dependencies as defaulted parameters (`env = process.env`); services do not.

## Hard rules

- Never cite a private workspace path (`~/Projects/...`).

## Review norms

- No volatile counts in prose. Tense matches state; no heading pinned to a PR number.
- Qualify cross-repo PR refs (`auth-service#220`).
- Read untrusted input once and work from the snapshot.
- Await or `.catch` every promise a callback returns; typing the callback `=> void` does not handle it.
- Measure byte budgets with `Buffer.byteLength`, not `.length`.
- README snippets compile.
- Stay inside the `engines.node` range: use no API newer than it allows.

## When to ask

- Anything `TODO.md` lists as waiting on someone: ask, never invent the answer.
