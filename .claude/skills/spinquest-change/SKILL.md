---
name: spinquest-change
description: Use to implement a change in any SpinQuest repo (Backend, central-tech, spinquest-frontend, spinquest-mobile-app, spinquest-rips-frontend, claude-skills). Covers verdict check, implementation, verify ladder, contract checklist, cross-repo split, and fresh-session review.
---

# spinquest-change

## Steps

1. Name the repo. Its rules file in `.claude/rules/` loads by path.
2. Check the team verdict in `central-tech` (`TODO.md`, `parity/`) before any Backend-dependent change. Then read the relevant dossier in `personal-docs/` (see `personal-docs/feature-flows-index.md`).
3. Implement through `superpowers:test-driven-development`. Spinquest-style applies via the hook.
4. Run the repo's verify ladder from the table below, in order. End with the real path in the browser pane or simulator and one failure path.
5. Run the contract checklist when an env var, route, field, or error code changes.
6. A change spanning repos: name each other repo's change and propose one session per repo.
7. Close by proposing `review-crew` in a fresh session. Do not self-review.

## Verify ladder

Commands live in each rules file's `## Verify ladder`. Run those, not a remembered copy.

| Repo | Ladder |
|---|---|
| Backend | `.claude/rules/backend.md` |
| central-tech | `.claude/rules/central-tech.md` |
| spinquest-frontend | `.claude/rules/spinquest-frontend.md` |
| spinquest-mobile-app | `.claude/rules/mobile-app.md` |
| spinquest-rips-frontend | `.claude/rules/rips-frontend.md` |
| claude-skills | `claude plugin validate .` and `claude plugin validate plugins/<name>` (per `claude-skills/README.md`) |

Real path: `/local-stack up`, then the browser pane (web) or simulator (mobile).

## Contract checklist

For each changed env var, route, field, or error code, check every place it is declared or consumed:

- `.env.example` in the repo (add the var, never open `.env`).
- `spec/` (OpenAPI or schema files) for routes, fields, and error codes.
- `Dockerfile`, compose files, and `.github/workflows/` (build args, env wiring). The web clients wire env through the Dockerfile `ARG`/`ENV`, `docker-compose.yaml`, `build.yaml`, and each `deploy-*.yaml`; check all of them for a new build-time var.
- i18n keys for any new user-facing string or error code, in every locale file.
- `git grep` over `*.md` for the old and new name, to update docs that mention it.
- Callers in the other repos: `git grep` the name across the workspace.
