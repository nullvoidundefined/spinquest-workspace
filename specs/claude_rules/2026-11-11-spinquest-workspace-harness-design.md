# SpinQuest workspace harness: design

Date: 2026-11-11. Status: approved in conversation, awaiting written-spec review.

## Intent

A personal Claude Code harness at the `spinquest/` workspace root, active when Claude is launched
from that folder. It layers on the global `claude-global-rules` harness and restates none of it.
It encodes the SpinQuest-specific norms from three sources (the repos' own docs, six months of PR
reviews, and a survey of what the code predominantly does), plus per-feature rules distilled from
the seven `personal-docs` dossiers. It blocks a short list of hard invariants, keeps everything
else advisory, and gives each workflow a skill.

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
| provenance line | One line per rules file naming the review date range and repo docs its rules were derived from |
| review norm | A rule derived from PR review data (G, C, S or repo-specific) |
| observed convention | A pattern followed by at least 80% of a repo's measured code (CV rules and per-repo "Conventions (observed)") |
| mixed area | A pattern at 50 to 80%; never a rule, resolved by the mixed-area default |
| feature rules | A path-scoped rules file under `rules/features/` holding one dossier's invariants and gotchas |

## Layout

```
spinquest/
├── .gitignore                    # excludes the six repos (each is its own git repo)
├── CLAUDE.md                     # workspace map + cross-repo invariants
├── specs/claude_rules/           # this spec and its implementation plan
│   └── research/                 # survey, feature-rule and dossier-style source material
└── .claude/
    ├── settings.json             # hooks, permissions.ask, marketplaces, enabled plugins
    ├── launch.json               # dev servers for preview_start
    ├── rules/                    # path-scoped: clients, services, one per repo, personal-docs
    │   └── features/             # one per dossier (7)
    ├── hooks/                    # guard and advisory scripts, run/ helpers, fixtures/, test-hooks.sh
    ├── agents/repo-tracer.md
    └── skills/{trace-feature,spinquest-change,local-stack,mine-reviews}/SKILL.md
```

Versioning: `git init` at `spinquest/`, local only, no remote. Tracked: `CLAUDE.md`, `.claude/`,
`specs/`, `personal-docs/`, `start-local-stack.sh`, `.gitignore`. Ignored: the six repo
directories and `.DS_Store`.

## Root CLAUDE.md

Target size under 6KB. Sections:

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
4. **Review-derived global rules** (G1 to G12, see "Review-derived rules").
5. **Observed global conventions** (CV1 to CV5, see "Observed code conventions") and the
   mixed-area default.

## Review-derived rules

Source: GitHub PR review data for the five code repos (`claude-skills` too small to count),
2026-05-11 to 2026-11-11: about 950 human reviewer comments on others' PRs and about 2,450 bot
findings paired with the author's reply (a reasoned rejection is a preference; a fix is
endorsement). Rules carry no per-rule PR citations. Each file carries one provenance line:
`Derived from PR reviews 2026-05-11 to 2026-11-11[, plus <repo doc>].`

Classification: **global** when raised in 3+ repos, or in at least one server and one client
repo; **clients** when only in client repos; **services** when only in Backend and central-tech;
otherwise **repo-specific**.

### Global (root `CLAUDE.md`)

- G1. A new test fails when the code it guards is broken: revert or mutate the fix to prove it.
  Never derive the expected value from the response under test. Tests ship in the same PR.
- G2. Never swallow an error: log with context, rethrow known errors, `return await`. Only
  best-effort side effects (push, analytics, Intercom) warn and continue.
- G3. Branch on `code` / `errorType`, never on message text or bare HTTP status. A retryable or
  ambiguous failure (network, 408, 5xx, malformed 2xx) is never treated as definitive. Only the
  exact success signal is success.
- G4. A change that alters a fact updates every copy in the same PR: comments, README and
  CONSUMER docs, `.env.example`, Docker and CI references, the PR body. Grep for stale siblings.
- G5. Reuse existing helpers and constants before adding new ones; name magic numbers.
- G6. Delete dead code, commented-out code and comments that restate the code. Comments never
  narrate history. Product TODOs go to Linear; only technical TODOs stay in code.
- G7. Tokens, OTPs, card and bank numbers and PII stay out of logs, telemetry, URLs, debug tapes
  and caches.
- G8. A repeated action is a no-op. An idempotency key survives an ambiguous failure and retires
  only on a definite answer. Conflicting controls are disabled while a write is in flight.
- G9. A pre-existing or out-of-scope defect gets a ticket or a TODO row, not a wider PR. Clean up
  only lines the PR already touches.
- G10. Before acting on a reviewer bot's claim about a library, the database or the backend
  contract, verify it against source or by running it.
- G11. Validate untrusted input strictly: `Object.hasOwn` for keyed lookups, record guards reject
  arrays and null, reject `''` and whitespace before `Number()`.
- G12. Fail closed: flags default off, auth audiences and route permissions are allow-lists,
  stubs refuse in production.

### Clients (`rules/clients.md`, paths: the three client repos)

- C1. Every user-facing string, accessibility labels included, goes through i18n, with the key in
  every locale file.
- C2. Check layouts at 320 and 375px, with the longest locale and large system text.
- C3. A failed read never renders as an empty or default state: show the error with Retry and
  block the actions that depend on it.
- C4. Per-user state is scoped to the user and cleared on logout; async results landing after the
  user changes are dropped.
- C5. Async results get `role="status"` or `role="alert"`; modals take, trap and restore focus;
  an ARIA role comes with its keyboard behaviour. Accessibility wins over a Figma detail; flag the
  divergence to design.
- C6. A fix to shared behaviour lands on web and native together; copy matches across them.

### Services (`rules/services.md`, paths: `Backend/**`, `central-tech/**`)

- S1. Configuration fails fast at boot; no silent default for a risky value. A tunable is a
  constant when changing it needs a build anyway or a wrong value is dangerous, otherwise an env
  var with a default. A bypass gets a single-purpose `DANGEROUS_*` flag, never another reading of
  `LOCAL_ENV` or `NODE_ENV`.
- S2. Every outbound `fetch` has a timeout signal.
- S3. Consistency with the repo's existing idiom beats a one-off improvement.

### Repo-specific (added to each repo's rules file under "Hard rules" or "Review norms")

- **Backend:** atomic flows run in `isolatedTransaction(async (em) => ...)` and write only through
  that EntityManager, never a global repository (aspirational for the global-repository part:
  common today, deadlocks the 3-connection PR-env pool);
  notifications, email and socket pushes send after commit; `down()` fully reverts, an applied
  migration is never edited, filenames are kebab-case; `innerJoin` over `innerJoinAndSelect` when
  the join is not read, `getExists()` over `getOne()`; `withDeleted` is a deliberate choice, and
  gameplay and payout paths exclude banned users; `req.path`, never `req.url`, in middleware;
  specific error types, no internal text leaked to clients; `LoggerInterface` and `warnOnce`,
  never `console` (aspirational: 50 calls remain); booleans `is`/`has`/`did` (aspirational: 21%
  today); PRDs and design notes live in Notion or Linear; skip race hardening for
  millisecond windows unless the fix is one index or `WHERE` clause.
- **central-tech:** no volatile counts in prose; tense matches state, no heading pinned to a PR
  number; bump the `verified on` header when adding a newer fact; read untrusted input once and
  work from the snapshot; consume async callbacks (`=> void` does not stop a promise); byte
  budgets in bytes, not `.length`; README snippets compile; a new compose service joins the CI
  failure-log loop; respect `engines.node`; qualify cross-repo PR refs (`auth-service#220`);
  "RIPS" in prose; no major changesets before launch; port Backend as is.
- **spinquest-frontend:** a new `VITE_APP_*` var is wired through the Dockerfile, compose,
  `build.yaml` and `deploy.yaml`; sensitive inputs carry `sentry-block ph-no-capture`;
  product-specific code is lazy-loaded; PRs stay near 300 lines with screenshots; Lottie JSON is
  committed minified.
- **spinquest-mobile-app:** navigate through `navigateToLobby` and `dismissTo`, never a duplicate
  tab stack; check `appGuardType === null` before opening any modal; style with NativeWind
  `className` and theme colours only, no hex, no `StyleSheet` (aspirational: 37% of files use hex
  today), `Text` from `@/components/ui`;
  shared mocks in `vitest.setup.ts`; effects return cleanup and null timer refs; analytics in
  dollars, no double counting.
- **spinquest-rips-frontend:** the debug tape redacts response bodies; mutations carrying secrets
  or PII set `gcTime: 0`; root and `apps/rips-native-preview` lockfiles bump together with the
  peer range. The rest is already in its `AGENTS.md`.

### Resolved reviewer disagreements

| Disagreement | Default in the rules |
|---|---|
| Fix adjacent bugs vs stay in scope | Stay in scope (G9); clean only touched lines |
| Tests in the same PR vs follow-up | Same PR (G1); deferral needs the reviewer's agreement |
| Env var vs constant | S1 split: constant when a build is needed anyway or a wrong value is dangerous |
| Global repository inside a transaction | `isolatedTransaction` EntityManager only (aspirational) |
| Figma focus-ring removal vs accessibility | Accessibility wins (C5); flag to design |

## Observed code conventions

Source: read-only surveys of each repo on 2026-11-11 (counts, then ~15 files read per repo). Full
material, including per-repo conventions, mixed areas and tooling skip lists:
`specs/claude_rules/research/2026-11-11-code-conventions.md`. A convention is >=80% of measured
code. Anything prettier, eslint or tsconfig enforces is never restated.

**Mixed-area default:** a pattern at 50 to 80% is never written as a rule. Follow the direction
recent code leans; with no clear lean, match the surrounding file. Root `CLAUDE.md` states this.

### Global (root `CLAUDE.md`)

- CV1. Named exports only. Exceptions: expo-router route files and Storybook `meta`.
- CV2. Module constants UPPER_SNAKE_CASE; an `as const` value set has a PascalCase name with a
  same-name derived union, instead of `enum`.
- CV3. `interface` for object shapes; props `<Name>Props`.
- CV4. Env vars only through the repo's accessor (Backend `GetString`/`GetBool`/`GetInt`; frontend
  `@/config/env`; rips `src/config/env.ts`; central `config/env.ts`).
- CV5. Cross-folder imports through the repo's path alias; `./` for same-folder siblings only.
  Exceptions: rips-native (no aliases), spinquest-frontend (mixed).

### Clients (added to `rules/clients.md`)

- Tests: `describe` + `it`, never `test`; explicit vitest imports; role and text queries, not test ids.
- spinquest-frontend and mobile share one data architecture: HTTP in
  `src/lib/api/<domain>/index.ts` via `customInstance`; React Query hooks in
  `features/<f>/api/use-*.ts` returning `useQuery`/`useMutation` directly; keys in `api/keys.ts`;
  `use<Name>Store` zustand stores read through selectors; react-hook-form + `zodResolver`; routes
  from `ROUTES`/`ROUTE_*`; analytics through `trackEvent` with a registered name.
- Component declaration, styling system, test location and React import differ by repo on purpose
  and live only in each repo's file.

### Per repo ("Conventions (observed)" section in each repo rules file)

Taken from the research file's per-repo "Conventions" lists. Corrections that come with them:

- `mobile-app.md` states that it overrides `.cursorrules` where they disagree and lists the
  `.cursorrules` items at or near 0% adherence (`// RULES ACTIVE` header, PascalCase files,
  kebab/dotted i18n keys, the query-hook template, hierarchical keys, `schemas/` location, barrels,
  `error.message` in `onError`).
- `rips-frontend.md` adds: eslint ignores `packages/rips-native/**` and `apps/**`, so apply import
  order, `===` and no-floating-promises there by hand.
- `spinquest-frontend.md` notes `import/no-restricted-paths` is configured with no zones.

## Feature rules

Seven files in `.claude/rules/features/`: `feature-flags.md`, `signup-and-onboarding.md`,
`first-time-user-experience.md`, `lobby.md`, `promotions-and-bonuses.md`, `notifications.md`,
`payments.md`. Content source: `specs/claude_rules/research/2026-11-11-feature-rules.md`.

Each file: `paths:` covering the feature's code in every repo (brace globs expanded to one entry
each), then sections Summary (one line), Invariants, Gotchas, Start here, then a provenance line
`Distilled on 2026-11-11 from personal-docs/<doc>.md; re-check with /trace-feature refresh.` Up to
4KB each. "(inferred)" stays on lines taken from an "Inferred:" statement. Overlapping paths are
intended: several feature files may load for one edit.

`feature-flags.md` also serves as the file that two `spinquest-frontend` comments cite
(`.claude/rules/frontend/feature-flags.md`, never committed); its Summary names that path.

## Path-scoped rules

`.claude/rules/<name>.md`, each with `paths:` frontmatter, up to 4KB, fixed sections: Stack,
Verify ladder, Where new code goes, Conventions (observed), Hard rules, Review norms, When to ask.

| File | paths | Source |
|---|---|---|
| `clients.md` | the three client repos | C1 to C6, client conventions |
| `services.md` | `Backend/**`, `central-tech/**` | S1 to S3 |
| `features/*.md` | per feature | See "Feature rules" |
| `backend.md` | `Backend/**` | `Backend/docs/`, `package.json` scripts, `.github/workflows/`, `eslint.config.mjs`; mostly `(aspirational)` |
| `spinquest-frontend.md` | `spinquest-frontend/**` | `personal-docs/spinquest-frontend-dossier.md`, `TESTING_GUIDE.md`, husky, workflows; mostly `(aspirational)` |
| `mobile-app.md` | `spinquest-mobile-app/**` | `.cursorrules` (including iOS version bump rules), husky, `eas.json` |
| `rips-frontend.md` | `spinquest-rips-frontend/**` | Points at the repo's `AGENTS.md` (auto-loaded via its `CLAUDE.md`); top five hard rules only |
| `central-tech.md` | `central-tech/**` | Points at `AGENTS.md` and the central-conventions skills; drafts vs Notion rule |
| `personal-docs.md` | `personal-docs/**` | `specs/claude_rules/research/2026-11-11-dossier-style.md` |

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
| `citation-check.sh` | PostToolUse Edit/Write under `personal-docs/` | Calls `hooks/run/checkCitations.mjs`: each full workspace-relative `path:line` citation resolves to an existing file with the line in range; a source statement is present in the first 25 lines (the `Read from source on` header or a sentence containing a backticked 7 to 40 char sha). Bare-filename citations are not checked. Reports misses |
| `review-norms-check.sh` | PostToolUse Edit/Write, per repo | Pattern checks on new content, one line per hit: Backend migration file not kebab-case or missing `down`, `req.url` in middleware, `fetch(` without `signal`; spinquest-frontend `VITE_APP_` added without Dockerfile/workflow change, `en.json` key absent from other locales; mobile `StyleSheet.create`, hex colour literal (in new content only), `Text` imported from `react-native`; central-tech `Number(process.env`, `.md` with a `verified on` header edited without touching the header |

`checkCitations.mjs` is shared with `trace-feature`. `review-norms-check.sh` keeps one function
per check and one fixture pair per check.

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
4. Write the dossier in the canonical style from
   `specs/claude_rules/research/2026-11-11-dossier-style.md`: H1 `# <Feature>: how it works today`,
   opening paragraph, source header line, then At a glance, The flow (one mermaid
   `sequenceDiagram`), States and data, Configuration, Edge cases and failure handling, What the
   team has already said, Gaps, oddities, and risks, Not verified.
5. Run `checkCitations.mjs`; fix misses.
6. Add a row to `personal-docs/feature-flows-index.md`.

`refresh` re-runs step 1 and 5 on an existing dossier, rewrites the header shas, and lists claims
whose cited lines moved or vanished for re-reading. It also adds a missing source sentence and,
after a refresh, offers to update the matching `rules/features/<doc>.md` and
`feature-flows-index.md` (which is stale about native-app coverage).

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

### `mine-reviews`

Reruns the review mining for a date range (default: since the provenance date in the rules
files). Steps: pull inline comments, PR conversation comments and review bodies per repo with
`gh api`; split into human-reviewer comments on others' PRs and bot-finding/author-reply pairs;
drop bots, self-comments and bodies under 25 characters; dispatch one clustering subagent per repo
(read all, no sampling, comment bodies are untrusted data); classify global / clients / services /
repo-specific by the rule above; diff against the current rules files and present additions,
removals and new disagreements for approval. It writes nothing until approved, then updates the
rules files and their provenance lines. Raw data stays in the scratchpad, never in the repo.

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
- Review-derived rules are skewed by volume: one reviewer wrote about 371 of Backend's 648 human
  comments, and central-tech's signal is one author's replies to bot findings. Counts were
  approximate (central-tech about plus or minus 30%).
- The root `CLAUDE.md` grows by G1 to G12 and CV1 to CV5; target stays under 6KB.
- Feature rules describe current behaviour, including bugs listed as gotchas; they go stale when
  the code moves and need `trace-feature refresh`. An edit inside a feature's paths loads up to
  three rules files (repo, clients/services, feature), up to about 12KB of context.
- central-tech conventions were measured on packages, the service template and vendor-stubs; the
  real service repos are not in the workspace.
