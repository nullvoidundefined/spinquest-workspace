# SpinQuest workspace

Six independent git repos plus `personal-docs/`. Repo rules load from `.claude/rules/` when you touch that repo.

Inside these repos, this file and `.claude/rules/` override the global rules where they conflict: keep the existing `lib/`, `utils/` and `api/` folders, each repo's log call shape, each repo's catch-binding style, and the naming lexicons in `frontend-lexicon.md` and `backend-lexicon.md`.

## Repos

| Repo | What | Stack | PM | Verify | Agent doc |
|---|---|---|---|---|---|
| `Backend` | Core API, auth today | Express, routing-controllers, TypeORM, Postgres 17, Redis | pnpm | `lint`, `build` (tsc), `test`, `test:integration:ci` | none |
| `central-tech` | Central services drafts, packages, parity | express, drizzle, zod; `node:test` | pnpm | `lint`, `typecheck`, `test`, `build` | `AGENTS.md` |
| `spinquest-frontend` | Casino web client | React 18, Vite, MUI, React Query | pnpm | `lint`, `typecheck`, `test`, `build`, `test:e2e` | none |
| `spinquest-mobile-app` | Casino native app | Expo, React Native, NativeWind | pnpm | `lint`, `typecheck`, `test` | `.cursorrules` |
| `spinquest-rips-frontend` | RIPS web module plus `rips-core` and `rips-native` | React 19, Vite, Tailwind 4 | npm | `lint:check`, `prettier:check`, `test`, `build` | `AGENTS.md` |
| `claude-skills` | Team Claude plugin marketplace | markdown | none | none | `README.md` |

## Doc map

- `central-tech/reference/overview.md`, then `reference/tenancy.md`: the central map.
- `central-tech/TODO.md` and `central-tech/parity/`: what the team has decided or is waiting on.
- Feature dossiers, local stack and deploy docs: Notion, links in `.claude/notion-docs.md` (needs the Notion MCP).
- `personal-docs/`: `start-local-stack.sh` plus in-progress `/trace-feature` drafts only.

## Cross-repo invariants

1. Verify before asserting. Open a file before citing `file:line`. Start reasoning you did not read with "Inferred:".
2. Before proposing a Backend-dependent change, check the team verdict in central-tech.
3. Identity is resolved server-side from the token. A client never sends a `userId`.
4. Branch on an error's `code`, never its message text.
5. Pods hold no user or session state.
6. Production is named (`DEPLOYMENT_ENVIRONMENT`), never inferred; unset means production.
7. One capability, one place; link instead of retelling.
8. Run an agent review in a fresh session, never the session that wrote the code.
9. Each repo is its own git repo: commit inside it, never import across repo roots.
10. Adding a package needs administrator approval. This covers runtime and dev dependencies, Expo modules, and ESLint, Babel or Vite plugins. Never add one for convenience: first solve the need with existing code, an existing dependency or a platform API. If none fits, stop and present the need, what you tried, and the package's license, maintenance and size, then add it only after the user confirms approval. `dependency-add-guard` asks before any install command or `package.json` addition.

## Review norms

- G1. A new test fails when the code it guards is broken: revert or mutate the fix to prove it. Never derive the expected value from the response under test. Tests ship in the same PR.
- G2. Never swallow an error: log with context, rethrow known errors, `return await` inside `try` so the rejection is caught. Only best-effort side effects (push, analytics, Intercom) warn and continue.
- G3. Branch on `code` / `errorType`, never message text or bare HTTP status. A retryable or ambiguous failure (network, 408, 5xx, malformed 2xx) is never definitive. Only the exact success signal is success.
- G4. A change that alters a fact updates every copy in the same PR: comments, README and CONSUMER docs, `.env.example`, Docker and CI references, the PR body. Grep for stale siblings.
- G5. Reuse existing helpers and constants before adding new ones; name magic numbers.
- G6. Delete dead code, commented-out code and comments that restate the code. Comments never narrate history. Product TODOs go to Linear; only technical TODOs stay in code.
- G7. Keep tokens, OTPs, card and bank numbers and PII out of logs, telemetry, URLs, debug tapes and caches.
- G8. A repeated action is a no-op. An idempotency key survives an ambiguous failure and retires only on a definite answer. Disable conflicting controls while a write is in flight.
- G9. A pre-existing or out-of-scope defect gets a ticket or a TODO row, not a wider PR. Clean up only lines the PR already touches.
- G10. Before acting on a reviewer bot's claim about a library, the database or the backend contract, verify it against source or by running it.
- G11. Validate untrusted input strictly: `Object.hasOwn` for keyed lookups, record guards reject arrays and null, reject `''` and whitespace before `Number()`.
- G12. Fail closed: flags default off, auth audiences and route permissions are allow-lists, stubs refuse in production.

## Conventions

- CV1. New modules use named exports only. Exceptions: expo-router route files and Storybook `meta`. Leave existing default exports alone.
- CV2. Module constants UPPER_SNAKE_CASE. An `as const` value set takes a PascalCase name with a same-name derived union, never `enum`. Exception: spinquest-mobile-app, where `enum` is the norm.
- CV3. `interface` for object shapes; props `<Name>Props`.
- CV4. New code reads env vars only through the repo's accessor: Backend `GetString`/`GetBool`/`GetInt`, frontend `@/config/env`, rips `src/config/env.ts`, central `config/env.ts`.
- CV5. Cross-folder imports through the repo's path alias; `./` for same-folder siblings only. Exceptions: rips-native (no aliases), spinquest-frontend (mixed).

Where code is mixed, follow the surrounding file.

## Skills

`/spec-kickoff` (spec, ticket and Figma to a kickoff brief and branch), `/trace-feature` (dossiers), `/spinquest-change` (implement a change), `/local-stack` (local stack and staging), `/mine-reviews` (refresh review norms).
