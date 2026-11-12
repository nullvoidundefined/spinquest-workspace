# SpinQuest workspace harness: design

Date: 2026-11-11. Status: approved in conversation, awaiting written-spec review.

## Intent

A personal Claude Code harness at the `spinquest/` workspace root, active when Claude is launched
from that folder. It layers on the global `claude-global-rules` harness and restates none of it.
It encodes the SpinQuest-specific norms already observed across the six repos, blocks a short list
of hard invariants, keeps everything else advisory, and gives three workflows a skill each.

Success means:

- Every session starts with the workspace map and the state of each repo.
- A repo's rules load only when Claude touches that repo.
- The hard invariants below cannot happen without the hook firing.
- Cross-repo feature tracing, implementing a change, and local stack/staging each have a skill.

Out of scope: team distribution (a later lift into `claude-skills` is possible but not designed
here), per-repo `CLAUDE.md` files inside the six repos, Linear/ticket workflows.

## Domain vocabulary

| Term | Meaning |
|---|---|
| workspace | The `spinquest/` folder: six independent git repos plus `personal-docs/` |
| repo | One of `Backend`, `central-tech`, `claude-skills`, `spinquest-frontend`, `spinquest-mobile-app`, `spinquest-rips-frontend` |
| client repo | `spinquest-frontend`, `spinquest-mobile-app`, `spinquest-rips-frontend` |
| dossier | A feature-flow document in `personal-docs/` in the fixed layout (see `trace-feature`) |
| citation | A `path:line` reference in a dossier or rules file |
| hard invariant | A rule a PreToolUse hook blocks |
| advisory | A hook that injects context and never blocks |
| verify ladder | A repo's ordered verification steps: lint, typecheck, test, build, real path, failure path |
| team verdict | What central-tech `TODO.md`, `parity/` or `reference/` already decided |
| aspirational | A rule the repo's current code does not yet follow; tagged `(aspirational)` in rules files |

## Layout

```
spinquest/
├── .gitignore                    # excludes the six repos (each is its own git repo)
├── CLAUDE.md                     # workspace map + cross-repo invariants
├── docs/superpowers/specs/       # this spec
└── .claude/
    ├── settings.json             # hooks, permissions.ask, marketplaces, enabled plugins
    ├── launch.json               # dev servers for preview_start
    ├── rules/                    # path-scoped, one per repo + personal-docs
    ├── hooks/                    # guard and advisory scripts, run/ helpers, fixtures/, test-hooks.sh
    ├── agents/repo-tracer.md
    └── skills/{trace-feature,spinquest-change,local-stack}/SKILL.md
```

Versioning: `git init` at `spinquest/`, local only, no remote. Tracked: `CLAUDE.md`, `.claude/`,
`docs/`, `personal-docs/`, `start-local-stack.sh`, `.gitignore`. Ignored: the six repo
directories and `.DS_Store`.

## Root CLAUDE.md

Target size about 3KB. Sections:

1. **Repo table.** Each repo: what it is, stack, package manager, verify commands, where its own
   agent doc lives (`central-tech/AGENTS.md`, `spinquest-rips-frontend/AGENTS.md`,
   `spinquest-mobile-app/.cursorrules`, none for Backend and spinquest-frontend).
2. **Doc map.** central-tech `reference/overview.md`, `reference/tenancy.md`, `TODO.md`, `parity/`;
   `personal-docs/feature-flows-index.md`; `personal-docs/local-development.md`.
3. **Cross-repo invariants.** Each sourced from at least one repo:
   1. Verify before asserting. Open a file before citing `file:line`. Mark reasoning "Inferred:".
   2. Before proposing a Backend-dependent change, check the team verdict in central-tech.
   3. Identity is resolved server-side from the token. A client never sends a `userId`.
   4. Branch on an error's `code`, never its message text.
   5. Pods hold no user or session state.
   6. Production is named (`DEPLOYMENT_ENVIRONMENT`), never inferred; unset means production.
   7. One capability, one place; link instead of retelling.
   8. An agent review runs in a fresh session, never the session that wrote the code.
   9. Each repo is its own git repo: commit inside it, no imports across repo roots.

## Path-scoped rules

`.claude/rules/<name>.md`, each with `paths:` frontmatter, 1 to 3KB, fixed sections: Stack,
Verify ladder, Where new code goes, Hard rules, When to ask.

| File | paths | Source |
|---|---|---|
| `backend.md` | `Backend/**` | `Backend/docs/`, `package.json` scripts, `.github/workflows/`, `eslint.config.mjs`; mostly `(aspirational)` |
| `spinquest-frontend.md` | `spinquest-frontend/**` | `personal-docs/spinquest-frontend-dossier.md`, `TESTING_GUIDE.md`, husky, workflows; mostly `(aspirational)` |
| `mobile-app.md` | `spinquest-mobile-app/**` | `.cursorrules` (including iOS version bump rules), husky, `eas.json` |
| `rips-frontend.md` | `spinquest-rips-frontend/**` | Points at the repo's `AGENTS.md` (auto-loaded via its `CLAUDE.md`); top five hard rules only |
| `central-tech.md` | `central-tech/**` | Points at `AGENTS.md` and the central-conventions skills; drafts vs Notion rule |
| `personal-docs.md` | `personal-docs/**` | Dossier layout, header line format, "Inferred:" convention, trust section |

## Hooks

Scripts are bash with `jq`. `hooks/run/resolveRepo.sh` maps an absolute path to its repo name.
Blocking hooks exit 2 with a one-line reason naming the rule. Advisory hooks print
`hookSpecificOutput.additionalContext` JSON and exit 0. Nothing here duplicates a global hook
(R-101 prod DB, R-102 `.env*`, R-207 em dash, commit message, verification gate).

### Blocking (PreToolUse)

| Script | Matcher | Blocks |
|---|---|---|
| `credential-files-guard.sh` | Read, Edit, Write, Bash | Any reference to `spinquest-service-account.json`, `google-play-upload-key.json`, `google-services.json`, `GoogleService-Info.plist`, in any repo |
| `cross-repo-import-guard.sh` | Edit, Write | New content with an import specifier that resolves outside the file's own repo root |
| `rips-boundary-guard.sh` | Edit, Write under `spinquest-rips-frontend/` | `fetch(` outside `packages/rips-core/**/api/client.ts`, `src/features/auth/client.ts`, `src/features/debug/**`; `import.meta.env` outside `src/config/env.ts`; `@config/session` import outside `src/start.tsx` and `src/features/dev/**`; `document`/`window`/`localStorage` inside `packages/rips-core/**` |
| `client-identity-guard.sh` | Edit, Write in client repos | A `userId` key added in new content of an API module: blocks in rips, advisory in spinquest-frontend and mobile (existing `lib/api` code uses `userId`) |
| `hook-bypass-guard.sh` | Bash | `git commit` with `--no-verify` or `-n`; any command setting `SKIP_HOOKS` |

Guards inspect only the new content (`new_string` / `content`), so existing violations do not
block unrelated edits.

### Ask before running (`permissions.ask`)

`Bash(eas update:*)`, `Bash(eas submit:*)`, `Bash(eas build:*)`, `Bash(fastlane:*)`,
`Bash(gh workflow run:*)`, `Bash(kubectl:*)`, `Bash(argocd:*)`, `Bash(helm:*)`,
`Bash(pnpm db:migrate:*)`, `Bash(pnpm db:revert:*)`.

### Advisory

| Script | Event | Behavior |
|---|---|---|
| `workspace-status.sh` | SessionStart | One line per repo: branch, dirty file count, commits behind its upstream from local refs (no fetch) |
| `style-scan.sh` | PostToolUse Edit/Write, `*.{ts,tsx,js,jsx,mjs}` | Runs `claude-skills/plugins/spinquest-style/skills/spinquest-style/scripts/scan.mjs` on the file; feeds findings back; silent when clean or the script is missing |
| `contract-parity-reminder.sh` | PostToolUse Edit/Write on `.env.example`, env/config modules, route files, `spec/**` | Reminds: `.env.example`, `spec/`, and `git grep` over `*.md` must match |
| `citation-check.sh` | PostToolUse Edit/Write under `personal-docs/` | Calls `hooks/run/checkCitations.mjs`: each `path:line` resolves to an existing file with the line in range; the header "read from source on <date> against <repo>@<sha>" is present. Reports misses |

`checkCitations.mjs` is shared with `trace-feature`.

### Plugins (`settings.json`)

`extraKnownMarketplaces`: `spinquest` (BetsphereORG/claude-skills) and `central-tech`
(BetsphereORG/central-tech). `enabledPlugins`: `spinquest-style`, `review-crew`,
`dependabot-review` from `spinquest`; `central-conventions` from `central-tech`.

### Hook testing

`hooks/fixtures/<script>/{block,pass}.json`: one PreToolUse/PostToolUse payload each.
`hooks/test-hooks.sh` pipes every fixture into its script and asserts exit code 2 for `block`
and 0 for `pass` (advisory: asserts the context text is present for `block`, absent for `pass`).
The suite must be green before the harness is considered done.

## Skills and agent

### `trace-feature`

Input: a feature or question, or `refresh <dossier>`.

1. Record `branch@sha` of each repo.
2. Dispatch one `repo-tracer` subagent per relevant repo in parallel.
3. Dispatch one central-tech pass for the team verdict.
4. Write the dossier in the fixed layout: summary, at a glance, the flow (with a diagram), states
   and data, configuration, edge cases, what central-tech says, gaps and risks, not verified.
5. Run `checkCitations.mjs`; fix misses.
6. Add a row to `personal-docs/feature-flows-index.md`.

`refresh` re-runs step 1 and 5 on an existing dossier, rewrites the header shas, and lists claims
whose cited lines moved or vanished for re-reading.

`.claude/agents/repo-tracer.md`: read-only (Read, Grep, Glob, read-only Bash), model Sonnet.
Returns facts, each with `path:line` and labelled `read` or `Inferred:`.

### `spinquest-change`

1. Name the repo; its rules file loads by path.
2. Check the team verdict, then the relevant dossier.
3. Implement through superpowers test-driven-development; spinquest-style applies via the hook.
4. Run the repo's verify ladder from the per-repo table in the skill, ending with the real path in
   the browser pane or simulator and one failure path.
5. Contract checklist when env vars, routes, fields or error codes change.
6. A change spanning repos names each other repo's change and proposes one session per repo.
7. Close by proposing `review-crew` in a fresh session; no self-review.

### `local-stack`

Wraps `start-local-stack.sh`, `local-development.md`, `staging-deploys.md`,
`non-prod-geo-and-test-user-plan.md`. Modes: `up`, `status` (port and health probe per service),
`test-user` (non-prod user with geo override per the plan doc), `staging` (deploy walkthrough;
commands hit `permissions.ask`).

`.claude/launch.json` defines Backend API (port 3000) and spinquest-frontend (port 3001) per
`start-local-stack.sh`, rips-frontend (5173) per its `vite.config.ts`, and mobile Metro (8081,
the Expo default; `pnpm start` runs `expo start --dev-client` with no port override). The mobile
app is verified in the iOS Simulator, not the browser pane; its launch entry exists for Metro only.

### Skill verification

Run `trace-feature refresh` on one existing dossier and `local-stack status` against a running
stack; keep both outputs as evidence.

## Error handling

- A hook whose dependency is missing (`jq`, `node`, the scan script) exits 0 silently for
  advisory hooks and exits 2 with "guard unavailable: <dep>" for blocking hooks, so a broken guard
  is never silently open.
- `resolveRepo.sh` returns empty for paths outside the six repos; repo-specific guards then pass.
- `workspace-status.sh` skips a repo with no upstream and says so.

## Risks and costs

- Rules files for Backend and spinquest-frontend are distilled, not owned by those repos; they
  drift. Each carries a "distilled on <date> from <sources>" line.
- Regex guards miss creative forms (`globalThis.fetch`, aliased imports). They catch the common
  case; review-crew catches the rest.
- `style-scan` adds latency to every TS edit; it is advisory and scoped to the edited file.
- Enabling team plugins from settings needs your GitHub credentials for the private marketplaces.
