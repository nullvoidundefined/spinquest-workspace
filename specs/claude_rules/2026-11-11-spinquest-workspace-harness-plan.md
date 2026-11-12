# SpinQuest Workspace Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the personal Claude Code harness at the `spinquest/` workspace root: root `CLAUDE.md`, path-scoped rules, guard and advisory hooks, four skills, one agent, launch config.

**Architecture:** Everything lives in `spinquest/CLAUDE.md` and `spinquest/.claude/`. Hooks are bash scripts that read the hook JSON payload on stdin through shared helpers in `.claude/hooks/run/`; blocking hooks exit 2, advisory hooks print `additionalContext` JSON. One fixture-driven runner tests every hook. Skills and rules are markdown.

**Tech Stack:** bash, jq 1.7+, node 22 (for `.mjs` helpers, `node:test`), Claude Code hooks/rules/skills/agents format, `gh` CLI.

**Spec:** `specs/claude_rules/2026-11-11-spinquest-workspace-harness-design.md`
**Research (content source for rules and skills):** `specs/claude_rules/research/2026-11-11-code-conventions.md`, `.../2026-11-11-feature-rules.md`, `.../2026-11-11-dossier-style.md`

## Global Constraints

- All work and commits happen in the `spinquest/` workspace git repo (local only, no remote). Never commit inside the six repos. Never push.
- Never write U+2014 (em dash) in any file.
- Every new `.sh` / `.mjs` file starts with a header comment stating its responsibility (skip fixtures and markdown).
- Scripts locate the workspace from their own path: `WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"` (adjust depth for `run/`). Never depend on the caller's cwd.
- `settings.json` invokes hooks as `"$CLAUDE_PROJECT_DIR"/.claude/hooks/<script>.sh`.
- Blocking hook: reason on stderr, format `[<guard-name>] <reason>`, exit 2. Advisory hook: stdout `{"hookSpecificOutput":{"hookEventName":"<Event>","additionalContext":"<text>"}}`, exit 0; print nothing when there is nothing to say.
- Missing dependency: blocking hook exits 2 with `[<guard-name>] guard unavailable: <dep>`; advisory hook exits 0 silently.
- Content guards inspect only new content: `tool_input.content` (Write), `tool_input.new_string` (Edit), every `tool_input.edits[].new_string` (MultiEdit).
- Never open, cat, or copy the real credential files named in Task 2. Fixtures use invented paths only.
- Rules files: at most 4096 bytes each, `paths:` frontmatter with every brace glob expanded to one entry per path. Repo, clients and services files carry the provenance line `Derived from PR reviews 2026-05-11 to 2026-11-11[, plus <doc>].`; feature files carry `Distilled on 2026-11-11 from personal-docs/<doc>.md; re-check with /trace-feature refresh.` Root `CLAUDE.md` under 6144 bytes.
- Never restate anything prettier, eslint or tsconfig already enforces (each repo's tooling skip list is in the code-conventions research file).
- Mixed areas (50 to 80%) are never written as rules; root `CLAUDE.md` states the default: follow the direction recent code leans, otherwise match the surrounding file.
- Lines in rules that the repo's current code does not follow end with `(aspirational)`.
- Commit subjects are conventional (`feat(harness): ...`, `test(harness): ...`, `docs(harness): ...`), one-sentence body, trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A `.gitignore` or doc that merely names a credential file** must stay editable: the credential guard matches Edit/Write/Read on `file_path` basename, and matches Bash only on the command string. Test: `pass-edit-gitignore-naming-credential.json` in Task 2.
2. **MultiEdit payloads** must be checked across all `edits[]`, not just the first. Test: `block-multiedit-second-edit.json` in Task 4.
3. **Relative or spaced file paths** (`tool_input.file_path` relative to `cwd`, or containing spaces) must resolve to the right repo. Test: `resolveRepo` cases in Task 1.
4. **Hook invoked from a sub-repo cwd** (Claude `cd`'d into `Backend/`) must still find helpers and fixtures. Test: runner executes each fixture from `Backend/` cwd in Task 1.
5. **jq missing from PATH** must fail closed for blocking guards. Test: `block-nodeps.json` + `.env` sidecar in Task 2.

---

### Task 1: Hook helpers and fixture runner

**Files:**
- Create: `.claude/hooks/run/payload.sh`, `.claude/hooks/run/resolveRepo.sh`, `.claude/hooks/run/emit.sh`, `.claude/hooks/test-hooks.sh`
- Create: `.claude/hooks/fixtures/resolveRepo/cases.tsv`
- Modify: `.gitignore` (stop ignoring nothing new; confirm `.claude/` is tracked)

**Interfaces:**
- Produces (sourced bash functions, payload JSON held in `$PAYLOAD`):
  - `payload.sh`: `readToolName`, `readFilePath` (absolute; resolves relative paths against `.cwd`), `readNewContent` (concatenated new content per Global Constraints), `readCommand`, `readEventName`.
  - `resolveRepo.sh`: `resolveRepo <path>` prints one of `Backend central-tech claude-skills spinquest-frontend spinquest-mobile-app spinquest-rips-frontend personal-docs` or empty; also callable as a script.
  - `emit.sh`: `emitContext <event> <text>` (advisory JSON, jq-escaped), `blockWith <guard> <reason>` (stderr + exit 2), `requireDeps <mode:block|advise> <guard> <dep>...` (on a missing dep: `block` exits 2 with the unavailable message, `advise` exits 0).
- Runner contract: for each `fixtures/<hook>/<case>.json`, substitute `__WS__` with the workspace path, pipe it into `.claude/hooks/<hook>.sh` with cwd `$WS/Backend`, sourcing `<case>.env` first if present. `block-*` expects exit 2 and non-empty stderr; `pass-*` expects exit 0 and empty stdout; `warn-*` expects exit 0 and stdout containing `additionalContext`. Prints `PASS|FAIL <hook>/<case>`, exits non-zero on any FAIL. Special fixture dir `resolveRepo` holds `cases.tsv` (`<path>\t<expected>`), checked by calling `resolveRepo`.

- [ ] **Step 1: Write `fixtures/resolveRepo/cases.tsv`** with rows:
  `__WS__/Backend/src/index.ts → Backend`; `__WS__/spinquest-rips-frontend/packages/rips-core/src/api/client.ts → spinquest-rips-frontend`; `__WS__/personal-docs/lobby.md → personal-docs`; `__WS__/CLAUDE.md → (empty)`; `/tmp/x.ts → (empty)`; `__WS__/spinquest-frontend/src/a b/c.tsx → spinquest-frontend`.
- [ ] **Step 2: Write `test-hooks.sh`** per the runner contract; run it: `bash .claude/hooks/test-hooks.sh`. Expected: FAIL (resolveRepo missing).
- [ ] **Step 3: Implement `run/payload.sh`, `run/resolveRepo.sh`, `run/emit.sh`** per Interfaces.
- [ ] **Step 4: Run `bash .claude/hooks/test-hooks.sh`.** Expected: 6 PASS, exit 0.
- [ ] **Step 5: Commit** `test(harness): add hook payload helpers and fixture runner`.

### Task 2: Credential files and hook-bypass guards

**Files:**
- Create: `.claude/hooks/credential-files-guard.sh`, `.claude/hooks/hook-bypass-guard.sh`
- Create fixtures under `.claude/hooks/fixtures/credential-files-guard/` and `.../hook-bypass-guard/`

**Interfaces:**
- Consumes: Task 1 helpers.
- Produces: two PreToolUse scripts. Credential names (exact basenames): `spinquest-service-account.json`, `google-play-upload-key.json`, `google-services.json`, `GoogleService-Info.plist`.

- [ ] **Step 1: Write fixtures** (credential guard):
  `block-read-service-account.json` (Read `__WS__/spinquest-mobile-app/spinquest-service-account.json`); `block-bash-cat-upload-key.json` (Bash `cat google-play-upload-key.json`); `block-write-plist-other-repo.json` (Write `__WS__/spinquest-frontend/GoogleService-Info.plist`); `pass-edit-gitignore-naming-credential.json` (Edit `__WS__/spinquest-mobile-app/.gitignore`, new_string `google-services.json`); `pass-read-normal.json` (Read `__WS__/Backend/package.json`); `block-nodeps.json` + `block-nodeps.env` (`export PATH=/usr/bin:/bin`).
  Bypass guard: `block-no-verify.json` (`git commit --no-verify -m x`); `block-short-n.json` (`git commit -n -m x`); `block-skip-hooks.json` (`SKIP_HOOKS=1 git commit -m x`); `pass-normal-commit.json` (`git commit -m "fix: -n flag docs"`); `pass-log-n.json` (`git log -n 5`).
- [ ] **Step 2: Run runner.** Expected: these fixtures FAIL (scripts missing).
- [ ] **Step 3: Implement both scripts.** Credential guard: Read/Edit/Write/MultiEdit match `basename(readFilePath)`; Bash matches any credential basename as a word in `readCommand`. Bypass guard: block when the command contains a `git commit` segment carrying `--no-verify` or a standalone `-n` flag (short flags cluster like `-nm` included), or any `SKIP_HOOKS=` assignment.
- [ ] **Step 4: Run runner.** Expected: all PASS.
- [ ] **Step 5: Commit** `feat(harness): block credential files and hook bypass`.

### Task 3: Cross-repo import guard

**Files:**
- Create: `.claude/hooks/cross-repo-import-guard.sh`, fixtures dir.

**Interfaces:**
- Consumes: `readFilePath`, `readNewContent`, `resolveRepo`.
- Produces: PreToolUse script. Detection: every relative specifier in `from '...'`, `import('...')`, `require('...')` starting with `.` is resolved against the edited file's directory; block when `resolveRepo(resolved)` differs from `resolveRepo(file)` or the resolved path leaves the workspace.

- [ ] **Step 1: Write fixtures:** `block-climb-to-backend.json` (Write in `__WS__/spinquest-frontend/src/a.ts`, content `import x from '../../Backend/src/x'`); `block-require-sibling-repo.json` (`require('../../spinquest-rips-frontend/packages/rips-core')`); `pass-in-repo-relative.json` (`import y from '../lib/y'` inside `spinquest-frontend/src/features/a.ts`); `pass-outside-repos.json` (file `__WS__/scratch.ts`).
- [ ] **Step 2: Run runner.** Expected: new fixtures FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run runner.** Expected: all PASS.
- [ ] **Step 5: Commit** `feat(harness): block imports across repo roots`.

### Task 4: RIPS boundary and client identity guards

**Files:**
- Create: `.claude/hooks/rips-boundary-guard.sh`, `.claude/hooks/client-identity-guard.sh`, fixture dirs.

**Interfaces:**
- Consumes: Task 1 helpers.
- Produces: two PreToolUse scripts. Paths below are relative to `spinquest-rips-frontend/`.
  - rips-boundary: `\bfetch\(` allowed only in `packages/rips-core/**/api/client.ts`, `src/features/auth/client.ts`, `src/features/debug/**`; `import\.meta\.env` only in `src/config/env.ts`; an import of `@config/session` only in `src/start.tsx` and `src/features/dev/**`; `\b(document|window|localStorage)\.` blocked in `packages/rips-core/**`. Test files (`__tests__/`, `*.test.*`) are exempt.
  - client-identity: in client repos, files whose path contains `/api/`, `/services/`, or `/clients/`, new content matching `\buserId\s*[:,}]` or `[?&]userId=`. In `spinquest-rips-frontend` block; in `spinquest-frontend` and `spinquest-mobile-app` emit PreToolUse `additionalContext` (G-invariant 3 reminder) and exit 0.

- [ ] **Step 1: Write fixtures:** rips-boundary `block-fetch-in-feature.json`, `block-env-outside-config.json`, `block-session-import.json`, `block-window-in-core.json`, `block-multiedit-second-edit.json` (MultiEdit, first edit clean, second adds `fetch(`), `pass-fetch-in-client.json`, `pass-env-in-config.json`, `pass-test-file.json`. client-identity `block-rips-userid-body.json`, `warn-frontend-userid.json`, `pass-mobile-component-userid.json` (path `src/features/x/components/y.tsx`).
- [ ] **Step 2: Run runner.** Expected: new fixtures FAIL.
- [ ] **Step 3: Implement both.**
- [ ] **Step 4: Run runner.** Expected: all PASS.
- [ ] **Step 5: Commit** `feat(harness): guard RIPS portability boundary and client identity`.

### Task 5: Advisory hooks: workspace status, style scan, contract parity

**Files:**
- Create: `.claude/hooks/workspace-status.sh`, `.claude/hooks/style-scan.sh`, `.claude/hooks/contract-parity-reminder.sh`, fixture dirs.

**Interfaces:**
- Consumes: Task 1 helpers.
- Produces:
  - `workspace-status.sh` (SessionStart): one line per repo `<repo> <branch> dirty=<n> behind=<n|no-upstream>` using `git -C`, `git rev-list --count HEAD..@{u}`; no fetch. Emits `additionalContext` with `hookEventName` `SessionStart`.
  - `style-scan.sh` (PostToolUse): for `*.{ts,tsx,js,jsx,mjs}` runs `node $WS/claude-skills/plugins/spinquest-style/skills/spinquest-style/scripts/scan.mjs <file>`; emits its output when non-empty; silent when the script is missing.
  - `contract-parity-reminder.sh` (PostToolUse): triggers on basename `.env.example`, paths matching `/config/env\.`, `/env\.ts$`, `router\.tsx$`, `/routes?/`, `central-tech/spec/`; emits: `Contract touched: check .env.example, spec/, and git grep over *.md for the old and new names in this repo.`

- [ ] **Step 1: Write fixtures:** `workspace-status/warn-session-start.json` (`{"hook_event_name":"SessionStart","source":"startup"}`; asserts output contains `Backend`); `style-scan/warn-console-log.json` (PostToolUse Write of a scratch file `__WS__/.claude/hooks/fixtures/style-scan/sample.ts` committed with `console.log("x")`), `style-scan/pass-markdown.json`; `contract-parity-reminder/warn-env-example.json`, `warn-rips-router.json`, `pass-component.json`.
- [ ] **Step 2: Run runner.** Expected: new fixtures FAIL.
- [ ] **Step 3: Implement the three scripts.**
- [ ] **Step 4: Run runner.** Expected: all PASS.
- [ ] **Step 5: Commit** `feat(harness): add workspace status, style scan, and contract parity hooks`.

### Task 6: Citation checker and citation-check hook

**Files:**
- Create: `.claude/hooks/run/checkCitations.mjs`, `.claude/hooks/run/checkCitations.test.mjs`, `.claude/hooks/citation-check.sh`, fixtures (`fixtures/citation-check/good.md`, `bad.md`, and JSON payloads).

**Interfaces:**
- Produces: `node checkCitations.mjs <doc.md> [--root <workspace>]` prints one line per problem (`MISSING <path>`, `OUT_OF_RANGE <path>:<line> (file has <n> lines)`, `NO_HEADER`) and exits 0 always. Exported `findCitationProblems(markdownText: string, workspaceRoot: string): string[]`.
  - Citation: backticked `` `<path>.<ext>:<line>[-<line>][,<line>]` `` whose first path segment is one of the six repo names or `personal-docs`. Bare-filename citations (`ShopPackageService.ts:95`) and `:line` shorthand are skipped, not reported.
  - Header: present when the first 25 lines contain `Read from source on YYYY-MM-DD against` or a backticked 7 to 40 char hex sha (the existing "Backend references are to branch ... at `fce425f0`" form passes).
- `citation-check.sh` (PostToolUse, files under `personal-docs/*.md` except `feature-flows-index.md`): runs the checker, emits problems as context, silent when none.

- [ ] **Step 1: Write `checkCitations.test.mjs`** (`node:test`): `good.md` citing `Backend/package.json:1` with header line yields `[]`; `bad.md` citing `Backend/nope.ts:3` yields `['MISSING Backend/nope.ts']`; `Backend/package.json:999999` yields an `OUT_OF_RANGE` entry; a doc without header yields `NO_HEADER`; a range `Backend/package.json:1-2` is valid; a bare `` `package.json:999` `` is skipped (no entry); a doc whose line 9 reads "references are to `master` at `fce425f0`" has no `NO_HEADER`.
- [ ] **Step 2: Run `node --test .claude/hooks/run/checkCitations.test.mjs`.** Expected: FAIL.
- [ ] **Step 3: Implement `findCitationProblems` and CLI.**
- [ ] **Step 4: Run the test.** Expected: PASS. Then run `node .claude/hooks/run/checkCitations.mjs personal-docs/lobby.md` and record the problem count in the commit body (existing dossiers may have drifted; do not edit them in this task).
- [ ] **Step 5: Write hook fixtures** `warn-bad-doc.json`, `pass-good-doc.json`, `pass-index-file.json`; implement `citation-check.sh`; run runner. Expected: all PASS.
- [ ] **Step 6: Commit** `feat(harness): add dossier citation checker and hook`.

### Task 7: Review-norms advisory checks

**Files:**
- Create: `.claude/hooks/review-norms-check.sh`, fixture dir.

**Interfaces:**
- Consumes: Task 1 helpers.
- Produces: PostToolUse script; one bash function per check, each printing one line on a hit; all hits joined into one `additionalContext`. Checks (on new content and the edited path; `git -C <repo> diff --name-only` used for the "missing companion change" checks):
  - `checkMigrationName`: path under `Backend/src/db/migration/` whose basename is not `^[0-9]+-[a-z0-9-]+\.ts$`.
  - `checkMigrationDown`: new migration file content lacking `async down(`.
  - `checkReqUrl`: Backend file under `middleware` containing `req\.url`.
  - `checkFetchSignal`: Backend or central-tech new content with `fetch(` and no `signal`.
  - `checkViteEnvWiring`: spinquest-frontend new content adds `VITE_APP_[A-Z_]+` and `Dockerfile` is not in the repo's working-tree diff.
  - `checkLocaleParity`: edit to `spinquest-frontend/public/locales/en.json`; any other `public/locales/*.json` not in the working-tree diff.
  - `checkNativeStyling`: spinquest-mobile-app new content with `StyleSheet.create`, `#[0-9a-fA-F]{6}\b`, or `import { Text } from 'react-native'`.
  - `checkNumberEnv`: central-tech new content with `Number(process.env`.
  - `checkVerifiedHeader`: central-tech `.md` whose first 30 lines contain `verified on` and the edit's new content does not contain `verified on`.

- [ ] **Step 1: Write one `warn-*` and one `pass-*` fixture per check** (18 fixtures; companion-change checks use paths in the real repos and rely on their current clean/dirty state, so prefer cases decidable from content alone and give `checkViteEnvWiring` and `checkLocaleParity` an env sidecar `REVIEW_NORMS_DIFF_FILES="..."` that the script uses instead of `git diff` when set).
- [ ] **Step 2: Run runner.** Expected: new fixtures FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run runner.** Expected: all PASS.
- [ ] **Step 5: Commit** `feat(harness): add review-norms advisory checks`.

### Task 8: settings.json wiring

**Files:**
- Create: `.claude/settings.json`, `.claude/hooks/test-settings.sh`

**Interfaces:**
- Consumes: every script from Tasks 2 to 7.
- Produces: settings with
  - `hooks.PreToolUse`: matcher `Read|Edit|Write|MultiEdit|Bash` → credential-files-guard; `Edit|Write|MultiEdit` → cross-repo-import-guard, rips-boundary-guard, client-identity-guard; `Bash` → hook-bypass-guard.
  - `hooks.PostToolUse`: `Edit|Write|MultiEdit` → style-scan, contract-parity-reminder, citation-check, review-norms-check.
  - `hooks.SessionStart`: workspace-status.
  - `permissions.ask`: `Bash(eas update:*)`, `Bash(eas submit:*)`, `Bash(eas build:*)`, `Bash(fastlane:*)`, `Bash(gh workflow run:*)`, `Bash(kubectl:*)`, `Bash(argocd:*)`, `Bash(helm:*)`, `Bash(pnpm db:migrate:*)`, `Bash(pnpm db:revert:*)`.
  - `extraKnownMarketplaces`: `spinquest` → github `BetsphereORG/claude-skills`; `central-tech` → github `BetsphereORG/central-tech`.
  - `enabledPlugins`: `spinquest-style@spinquest`, `review-crew@spinquest`, `dependabot-review@spinquest`, `central-conventions@central-tech` all `true`.

- [ ] **Step 1: Write `test-settings.sh`:** asserts `jq empty` succeeds; every hook `command` resolves (after replacing `$CLAUDE_PROJECT_DIR` with `$WS`) to an existing executable; every script in `.claude/hooks/*.sh` except `test-*.sh` is referenced; the ten `permissions.ask` entries are present.
- [ ] **Step 2: Run it.** Expected: FAIL (no settings).
- [ ] **Step 3: Write `settings.json`; `chmod +x` all hook scripts.**
- [ ] **Step 4: Run `bash .claude/hooks/test-settings.sh && bash .claude/hooks/test-hooks.sh`.** Expected: both exit 0.
- [ ] **Step 5: Integration check.** Create a fake `spinquest-service-account.json` containing `{"fake":true}` in the session scratchpad; from `spinquest/` run `claude -p "Read the file <abs path to fake> and print it"` and confirm the output reports the credential guard blocked it. Delete the fake.
- [ ] **Step 6: Commit** `feat(harness): wire hooks, ask-permissions, and team plugins`.

### Task 9: Root CLAUDE.md and workspace and repo rules

**Files:**
- Create: `CLAUDE.md`, `.claude/rules/{clients,services,backend,spinquest-frontend,mobile-app,rips-frontend,central-tech,personal-docs}.md`, `.claude/hooks/run/checkRules.mjs`, `.claude/hooks/test-rules.sh`

**Interfaces:**
- Consumes: spec sections "Root CLAUDE.md", "Review-derived rules", "Observed code conventions", "Path-scoped rules"; research files `code-conventions.md` and `dossier-style.md`.
- Produces: rules files with frontmatter `paths:` (YAML list of globs) and sections in order: Stack, Verify ladder, Where new code goes, Conventions (observed), Hard rules, Review norms, When to ask (`clients.md`/`services.md`/`personal-docs.md` carry only the sections that apply). `paths` values: `clients.md` → `spinquest-frontend/**`, `spinquest-mobile-app/**`, `spinquest-rips-frontend/**`; `services.md` → `Backend/**`, `central-tech/**`; each repo file → `<repo>/**`; `personal-docs.md` → `personal-docs/**`.
- `node .claude/hooks/run/checkRules.mjs <rulesDir> <workspaceRoot>` prints one line per problem and exits 1 if any: `NO_PATHS <file>`, `GLOB_NO_MATCH <file> <glob>` (checked with `fs.globSync` from `node:fs`), `TOO_LARGE <file> <bytes>`, `NO_PROVENANCE <file>`, `EM_DASH <file>`, `MISSING_HEADING <file> <heading>`. Used by Task 9 and Task 10.

- [ ] **Step 1: Write `test-rules.sh`:** runs `checkRules.mjs` over `.claude/rules` (recursing into `features/`), and asserts `CLAUDE.md` is under 6144 bytes, contains `G1.` through `G12.` and `CV1.` through `CV5.`, and contains no U+2014. Repo files must have headings `## Verify ladder`, `## Conventions (observed)`, `## Hard rules`. Provenance regex: `^Derived from PR reviews 2026-05-11 to 2026-11-11` for non-feature files, `^Distilled on 2026-11-11 from personal-docs/` for `features/*`.
- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement `checkRules.mjs`** (header comment; `fs.globSync` with `cwd` set to the workspace root).
- [ ] **Step 4: Write `CLAUDE.md`:** repo table (purpose, stack, package manager, verify commands read from each repo's `package.json` scripts, own agent doc), doc map, invariants 1 to 9, G1 to G12 and CV1 to CV5 in substance from the spec, the mixed-area default, and one line naming the four skills.
- [ ] **Step 5: Write the eight rules files.** Review norms from the spec; "Conventions (observed)" from the research file's per-repo lists (skip tooling-enforced items); corrections from the spec's "Per repo" list (mobile overrides `.cursorrules`; rips-native lint gap; frontend empty `no-restricted-paths`). Also read `Backend/docs/getting-started.md`, `Backend/docs/testing-usage-guide.md`, `Backend/.github/workflows/test.yaml`, `spinquest-frontend/TESTING_GUIDE.md`, `spinquest-mobile-app/.cursorrules`, `spinquest-rips-frontend/AGENTS.md`, `central-tech/AGENTS.md` for Stack, Verify ladder and Where new code goes. Never copy the rips or central-tech AGENTS.md beyond five top hard rules; point to them. Mark aspirational lines. `personal-docs.md` encodes the dossier style research file.
- [ ] **Step 6: Run `bash .claude/hooks/test-rules.sh`.** Expected: exit 0.
- [ ] **Step 7: Commit** `docs(harness): add workspace CLAUDE.md and path-scoped repo rules`.

### Task 10: Feature rules

**Files:**
- Create: `.claude/rules/features/{feature-flags,signup-and-onboarding,first-time-user-experience,lobby,promotions-and-bonuses,notifications,payments}.md`

**Interfaces:**
- Consumes: `specs/claude_rules/research/2026-11-11-feature-rules.md`; `checkRules.mjs` and `test-rules.sh` from Task 9.
- Produces: seven files, each `paths:` (brace globs expanded), `## Summary`, `## Invariants`, `## Gotchas`, `## Start here`, then the feature provenance line. `feature-flags.md` Summary also names `.claude/rules/frontend/feature-flags.md` as the path `spinquest-frontend` comments cite.

- [ ] **Step 1: Extend `test-rules.sh`** to require exactly those seven files under `features/` with headings `## Invariants` and `## Gotchas`. Run it. Expected: FAIL (files missing).
- [ ] **Step 2: Write the seven files** from the research file, keeping "(inferred)" markers.
- [ ] **Step 3: Run `bash .claude/hooks/test-rules.sh`.** Expected: exit 0 (every glob matches at least one file).
- [ ] **Step 4: Commit** `docs(harness): add per-feature rules from personal-docs dossiers`.

### Task 11: repo-tracer agent and trace-feature skill

**Files:**
- Create: `.claude/agents/repo-tracer.md`, `.claude/skills/trace-feature/SKILL.md`

**Interfaces:**
- Consumes: `checkCitations.mjs` (Task 6), `rules/features/*` (Task 10).
- Produces: agent frontmatter `name: repo-tracer`, `model: sonnet`, `tools: Read, Grep, Glob, Bash`; body instructs read-only Bash, output as a list of facts each `path:line` + `read` or `Inferred:`. Skill frontmatter `name: trace-feature`, description naming both modes; body implements the spec's six steps and `refresh` mode and reproduces the dossier style research file (H1 `# <Feature>: how it works today`; H2s exactly At a glance, The flow, States and data, Configuration, Edge cases and failure handling, What the team has already said, Gaps, oddities, and risks, Not verified; one mermaid `sequenceDiagram`; header line `Read from source on YYYY-MM-DD against <repo>@<sha>, ...`). `refresh` also adds a missing source sentence and offers to update `rules/features/<doc>.md` and `feature-flows-index.md`.

- [ ] **Step 1: Write both files.**
- [ ] **Step 2: Verify:** in a fresh `claude -p` session from `spinquest/`, run `/trace-feature refresh personal-docs/lobby.md` (dry run: instruct it to report, not write). Expected: a list of moved or missing citations and the current shas. Save the output to the scratchpad and quote its summary line in the commit body.
- [ ] **Step 3: Commit** `feat(harness): add trace-feature skill and repo-tracer agent`.

### Task 12: spinquest-change skill

**Files:**
- Create: `.claude/skills/spinquest-change/SKILL.md`

**Interfaces:**
- Consumes: rules files (Tasks 9 and 10), `trace-feature` dossiers.
- Produces: skill with the spec's seven steps and a verify-ladder table per repo (commands taken from the rules files' Verify ladder sections, so the two never disagree: the skill table links to each rules file rather than restating commands), the contract checklist (env var, route, field, error code: `.env.example`, `spec/`, Dockerfile/workflows, i18n keys, `git grep` over `*.md`), and the closing instruction to propose `review-crew` in a fresh session.

- [ ] **Step 1: Write the skill.**
- [ ] **Step 2: Verify:** `claude -p "/spinquest-change dry run: describe the steps you would take to add a VITE_APP_FOO var to spinquest-frontend"` from `spinquest/`. Expected: names the Dockerfile/compose/build.yaml/deploy.yaml wiring and the fresh-session review.
- [ ] **Step 3: Commit** `feat(harness): add spinquest-change skill`.

### Task 13: local-stack skill and launch.json

**Files:**
- Create: `.claude/skills/local-stack/SKILL.md`, `.claude/launch.json`
- Modify: `.gitignore` (none expected; confirm `start-local-stack.sh` is tracked)

**Interfaces:**
- Produces: `launch.json` version `0.0.1`, configurations: `backend-api` (port 3000), `spinquest-frontend` (3001), `rips-frontend` (`npm run dev` in `spinquest-rips-frontend`, 5173), `mobile-metro` (`pnpm start` in `spinquest-mobile-app`, 8081). Runtime commands for the first two come from `start-local-stack.sh`. Skill modes `up`, `status`, `test-user`, `staging` per spec; `status` probes each port with `curl -s -o /dev/null -w '%{http_code}'` and Backend `GET /health` if it exists (check routes first).

- [ ] **Step 1: Read `start-local-stack.sh`, `personal-docs/local-development.md`, `staging-deploys.md`, `non-prod-geo-and-test-user-plan.md`.**
- [ ] **Step 2: Write `launch.json` and the skill.**
- [ ] **Step 3: Verify:** `jq empty .claude/launch.json`; run the skill's `status` mode with the stack down (expected: every service reported down, no error) and, if the user starts the stack, up.
- [ ] **Step 4: Commit** `feat(harness): add local-stack skill and dev server launch config`.

### Task 14: mine-reviews skill

**Files:**
- Create: `.claude/skills/mine-reviews/SKILL.md`, `.claude/skills/mine-reviews/fetchReviews.sh`

**Interfaces:**
- Produces: `fetchReviews.sh <since-ISO-date> <out-dir>` writes `human_<repo>.jsonl` and `botreply_<repo>.jsonl` for the five code repos, using the same `gh api` endpoints, bot list, author exclusion and 25/40-character floors used to build the spec's data. Bot regex: `^(Copilot|copilot-pull-request-reviewer|linear-code\[bot\]|sq-argo\[bot\]|dependabot\[bot\]|greptile-apps(\[bot\])?|Codex|claude|chatgpt-codex-connector|github-actions\[bot\])$`. Skill body: run the script into the scratchpad, one clustering subagent per repo (prompt template in the skill), classify by the spec rule, diff against current rules, present for approval, write only after approval, update provenance lines.

- [ ] **Step 1: Write the script and skill.**
- [ ] **Step 2: Verify:** `bash .claude/skills/mine-reviews/fetchReviews.sh 2026-11-01 <scratchpad>/mine-test` and confirm five `human_*.jsonl` files exist and no line has a bot `user`: `jq -r .user <dir>/human_*.jsonl | grep -cE '<bot regex>'` prints `0`.
- [ ] **Step 3: Commit** `feat(harness): add mine-reviews skill`.

### Task 15: Final verification and tracking

**Files:**
- Modify: git index (track `personal-docs/`, `start-local-stack.sh`)

- [ ] **Step 1: Run** `bash .claude/hooks/test-hooks.sh && bash .claude/hooks/test-settings.sh && bash .claude/hooks/test-rules.sh && node --test .claude/hooks/run/checkCitations.test.mjs`. Expected: all exit 0.
- [ ] **Step 2: Run** `grep -rl "$(printf '\xe2\x80\x94')" CLAUDE.md .claude specs` . Expected: no output.
- [ ] **Step 3: Start a fresh `claude -p "List the rules files and skills you have loaded"` from `spinquest/`.** Expected: SessionStart output with six repo lines; skills `trace-feature`, `spinquest-change`, `local-stack`, `mine-reviews` listed.
- [ ] **Step 4: Commit** `chore(harness): track personal-docs and local stack script`.
