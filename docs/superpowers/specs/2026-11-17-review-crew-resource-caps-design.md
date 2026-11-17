# review-crew resource caps

2026-11-17 · Ian Greenough

> **Outcome (2026-11-17):** superseded. What shipped is a fixed 2-worker test cap plus worktree cleanup (BetsphereORG/claude-skills#20) and the mutation-worktree fix (BetsphereORG/claude-skills#21). The free-memory sizing, agent waves, guard hook and fixer agent described here were built, measured and then dropped as more than the problem needed; that work is on the local `review-crew-test-guard-archive` branch in claude-skills.

Make review-crew's memory use scale to the machine it runs on, so a full review finishes on a
weaker laptop, without disabling any test it runs today.

## Problem

A teammate reported in Slack that a review-crew review of spinquest-frontend used all of their
laptop's RAM, and suspected claude-in-chrome. Their machine and review target are unknown. The
plugin is at 0.3.0 (`BetsphereORG/claude-skills`, `plugins/review-crew`).

The captain starts up to 10 review agents in one message (SKILL.md step 6), then one verifier per
12 findings (step 8), then one background fix agent per fix (step 10, Background fixes). Nothing
limits how many run at once, or how many workers their test commands start.

## Measurement

### The review

A `full` review of `merch` vs `main` (255 changed `src/` files, no PR) on Ian's machine (18 cores,
48 GB), 2026-11-17 10:16 to 10:26, sampled every 3 seconds (`vm_stat`, `memory_pressure`, `ps`).
The captain picked 8 review agents and 3 verifiers, with `test_mode: run` and `mutation: yes`. It
stopped at the published report; no fix agents ran.

| Phase | Time | What used memory | Free memory |
|---|---|---|---|
| Baseline | 10:16 | Claude app processes 3.6 GB | 58% |
| Review agents | 10:17 to 10:23 | The `tests` agent's vitest: up to 20 processes, 3.2 GB, from 10:18:56 to 10:21:09 | 56% at the low point |
| Verify and report | 10:23 to 10:26 | No tests. Claude app processes up to 5.1 GB (+1.5 GB over baseline) | 56 to 57% |

- Only the `tests` agent ran tests: the 72 changed test files (1141 tests), then 5 mutation runs,
  all `vitest run`. It did not run the full suite or any e2e test.
- The other agents ran no commands, except `style`'s read-only `spinquest-style` scan.
- No Playwright, Chromium or claude-in-chrome process started. The only new browser processes were
  short-lived tab renderers of the driver's own Google Chrome.
- The `tests` agent's worktree was left behind at `.claude/worktrees/agent-<id>`.

### Vitest worker counts

The same 72 test files, run directly with `node_modules/.bin/vitest run` on the same machine. All
runs passed 1141 of 1141 tests.

| `--maxWorkers` | Time | Slowdown | Peak vitest memory |
|---|---|---|---|
| default (17) | 13 s | 1.0x | 3.3 GB |
| 8 | 14 s | 1.1x | 2.0 GB |
| 4 | 20 s | 1.5x | 1.2 GB |
| 3 | 23 s | 1.8x | 1.2 GB |
| 2 | 32 s | 2.5x | 0.9 GB |
| 1 | 59 s | 4.5x | 0.6 GB |

Roughly 0.45 GB for the vitest main process plus about 0.2 GB per worker. Past 8 workers, extra
workers buy almost no time and cost about 0.2 GB each.

### What this shows

1. Memory comes from two places of similar size: vitest workers (3.2 GB for about 2 minutes) and
   the subagents themselves (1.5 GB across the review and verify phases).
2. A targeted run is enough to spike. Vitest 3.2.6 uses `cpus - 1` workers outside watch mode
   (from the vitest source), and 72 files fill all of them.
3. The worker count is the cheapest lever: 4 workers cut vitest memory by 63% for a 1.5x slower
   run; 1 worker cuts it by 82% for 4.5x.
4. Nothing in this run supports the claude-in-chrome theory.

## Findings from the code

Checked against claude-skills `main` (`b69e9fb`) and spinquest-frontend `merch`.

- All 11 review agents declare `tools: Read, Grep, Glob, Bash`, which excludes MCP tools.
- `verifier.md` forbids running tests or the app.
- No file in the plugin mentions e2e, Playwright or a browser.
- Background fix agents are `general-purpose`, so they inherit every tool, claude-in-chrome
  included.
- The e2e specs load `.env.test` and log in through the real login form. Deposits, redemption and
  self-exclusion mock their money endpoints with `page.route`, but the auth fixture forwards
  `/users` to the real server and 6 of the 10 specs mock nothing. Playwright has no `webServer`
  and defaults to `"50%"` of cores as workers, one Chromium each.
- CI runs unit tests on every PR in Backend, spinquest-rips-frontend and central-tech. It runs
  none in spinquest-frontend or spinquest-mobile-app.

## Goals

- Every test run a review-crew agent makes is sized to the memory free on the machine.
- Agents run in fewer parallel waves when free memory is low.
- No test the review runs today is skipped. A slower review on a weaker laptop is acceptable.
- Fix agents cannot open a browser.
- A review leaves nothing behind in the repo.

## Non-goals

- Limiting the driver's own sessions. The guard applies only to review-crew's `tests` and
  `fixer` agents.
- Changing the verifier, the report, or the walkthrough.
- Changing which tests the `tests` agent selects. It keeps today's full-suite and targeted logic.

## Anti-goals

- Disabling or skipping a test to save memory.
- A cap that hides a failing test as a pass.
- A guard that blocks commands in the driver's own conversation or in other plugins' agents.

## Approaches considered

For sizing:

1. **Fixed worker cap** (`--maxWorkers=4` everywhere). Simple, but too slow for nothing on a big
   machine and still too much on a busy small one.
2. **Profiles by free memory** (large, medium, small with fixed values). Scales, but in steps, and
   a table of magic numbers to maintain.
3. **A formula from free memory (chosen).** One rule, continuous, read at the moment the review
   starts, so a laptop busy with a browser and an editor gets fewer workers.

Total RAM was considered instead of free RAM: predictable per machine, but it gives a 16 GB laptop
with 10 GB in use the same workers as an idle one, which is the case that runs out.

For enforcement:

1. **Prose rules in the agent files.** Rejected as the only control: an agent can improvise a
   command no rule mentions.
2. **A hook in the agent's frontmatter.** Rejected: Claude Code ignores the `hooks` field on
   agents shipped in a plugin.
3. **Prose rules plus a plugin-level hook filtered by `agent_type` (chosen).** Acts only for
   `review-crew:tests` and `review-crew:fixer`. Cost: a short Node process on every Bash call
   while the plugin is enabled (measured: about 20ms warm, 90ms cold).

## Changes

One PR to claude-skills. `plugin.json` goes to 0.4.0 with a `CHANGELOG.md` line in the same PR,
the way every earlier change shipped.

1. **Read free memory once.** At step 5 (Context bundle), before any agent starts, the captain
   reads free memory: on macOS, `sysctl -n hw.memsize` times the free percentage from
   `memory_pressure`; on Linux, `MemAvailable` from `/proc/meminfo`. It also reads the core count
   (`sysctl -n hw.ncpu`, `nproc`). If the memory read fails, it uses total RAM divided by 2 and
   says so. It writes `free_gb`, `cores`, `test_workers`, `e2e_workers` and `agent_wave` to
   `context.md`, and tells the driver in one line:
   `8 GB free, 10 cores: tests use 2 workers, agents run 3 at a time.`
2. **Size test workers from free memory.**

   ```
   test_workers = clamp(floor(free_gb / 3), 1, cores - 1)
   ```

   | Free memory | `test_workers` | Vitest memory (measured) | Slowdown on the measured run |
   |---|---|---|---|
   | 4 GB | 1 | 0.6 GB | 4.5x |
   | 8 GB | 2 | 0.9 GB | 2.5x |
   | 16 GB | 5 | about 1.4 GB | about 1.4x |
   | 27 GB (Ian's machine at 58% free) | 9 | about 2.2 GB | about 1.1x |

   Vitest stays near 10% of free memory. `tests.md` and the new `fixer.md` say every unit or
   integration test run passes `--maxWorkers=<test_workers>` (vitest and jest both take the flag):
   the full suite, targeted runs and mutation runs.
3. **Run e2e sized and only against a local stack.** The `tests` agent may run the changed e2e
   specs when the repo has them, with `--workers=<e2e_workers>`, where
   `e2e_workers = clamp(floor(free_gb / 6), 1, 4)`, since each Playwright worker is a full
   Chromium. It runs them only when `PLAYWRIGHT_BASE_URL` (or the config's `baseURL`) points at
   `localhost` or `127.0.0.1` and the app answers there. Otherwise it adds a `note` finding that
   the e2e specs need the local stack, and names them. This keeps a review from logging in to a
   real backend on its own.
4. **Run agents in waves when memory is low.**

   ```
   agent_wave = clamp(floor(free_gb / 2), 2, 10)
   ```

   The captain starts review agents in waves of `agent_wave`, and verifier batches the same way.
   When `agent_wave` is smaller than the number of selected agents, the `tests` agent runs alone
   in the last wave, so its workers never overlap the other agents. `--max-parallel <n>`
   overrides `agent_wave`.
5. **A `review-crew:fixer` agent.** New `agents/fixer.md` with
   `tools: Read, Grep, Glob, Bash, Edit, Write, Skill`. `Skill` is there because the fix rules
   use `spinquest-style`. SKILL.md step 10 starts `review-crew:fixer` in the background instead of
   `general-purpose`. The fix rules move from SKILL.md into the agent file; SKILL.md keeps the
   queueing, telling, results and question flow. The fixer runs tests with the same worker rule
   and never opens a browser: when a fix needs a visual check, its result line says so and the
   driver checks by hand.
6. **The sizing hook.** `hooks/hooks.json` registers a `PreToolUse` hook on `Bash` that runs
   `node "${CLAUDE_PLUGIN_ROOT}/hooks/guard.mjs"`. The script reads the hook input
   from stdin and:
   - exits 0 at once unless `agent_type` is `review-crew:tests` or `review-crew:fixer`;
   - denies (JSON `permissionDecision: "deny"`) a `vitest`, `jest` or `pnpm`/`npm`/`yarn` `test`
     command without `--maxWorkers`, and a `playwright test` or `test:e2e` command without
     `--workers`;
   - says in the deny reason which flag to add and where the value is (`context.md`).

   It checks that the flag is present, not its value. The script is Node with no dependencies,
   like `report/render.mjs`. A fixture test, `hooks/guard.test.mjs`, runs with
   `node --test` and covers each deny case, a sized run that passes, and the same commands
   passing for the main session and for another agent type. claude-skills has no CI, so the PR
   description records the `node --test` output and the reviewer runs it by hand.
7. **Clean up the mutation worktree.** After the `tests` agent returns, the captain (SKILL.md
   step 7, Collect) removes its worktree with `git worktree remove --force` once the findings are
   read. A worktree that cannot be removed is reported to the driver with its path.

**If `agent_type` does not match.** If the logged hook input shows `agent_type` missing, unprefixed,
or different under `isolation: "worktree"`, drop change 6 and ship the rest as prose only. Never
widen the guard to the whole plugin. Record the observed value in the PR.

## Builder's calls

- The divisors (3 for tests, 6 for e2e, 2 for agent waves). They are starting points from one
  machine; the e2e and wave divisors are not measured. Adjust from the after-measurements and
  record the final formulas in SKILL.md and `tests.md`.
- Where the memory read lives: a few lines of shell in SKILL.md, or a small `profile.mjs` beside
  `report/render.mjs`.
- How the `tests` agent checks that the local app answers before e2e (a `curl` to the base URL is
  enough).
- The exact command-matching rules in the guard, as long as the fixture cases pass. Commands
  chained with `&&`, `;` or `|` are checked per segment.
- Fail open (exit 0) on hook input the guard cannot parse: a parse bug must not break every Bash
  call in the driver's session.
- Wording of the `note` findings, the deny reasons and the one-line sizing message.

## Acceptance criteria

- [ ] A plugin agent's `agent_type` in the hook input is exactly `review-crew:tests` /
      `review-crew:fixer` (log one call to confirm before relying on the match).
- [ ] `node --test plugins/review-crew/hooks/` passes, and fails when the `agent_type` check or a
      deny rule is removed.
- [ ] Re-run the measured review (`full`, `merch` vs `main`, same sampler) three times, with
      `--max-parallel` and a forced `free_gb` of 27, 8 and 4 (a test override for the memory
      read). Record peak vitest memory, peak Claude app memory, lowest free memory and total time
      for each. Vitest peaks at `test_workers + 1` processes, and every test and mutation result
      matches the unsized run.
- [ ] At `free_gb` 4, peak memory added over baseline (vitest plus Claude app growth) is under
      2 GB.
- [ ] No test the unsized review ran is missing from a sized review.
- [ ] With the local stack down, a review of a branch that changes an e2e spec adds the "needs
      the local stack" note and starts no browser. With it up on localhost, the changed specs run
      with `--workers=<e2e_workers>`.
- [ ] No Chrome or Chromium process whose parent is the Claude Code session starts during a
      review, a verify or a fix, except Playwright workers in a sized e2e run against localhost.
- [ ] After the review, `git worktree list` shows no review-crew worktree.
- [ ] In the driver's own conversation, with the plugin enabled, `pnpm test` and `pnpm test:e2e`
      are not blocked.
- [ ] A fix that the rules say needs `spinquest-style` still loads the skill.
- [ ] A `full` review of a Backend PR still runs the targeted tests and the mutation check.
- [ ] `quick` behaves as it does today.

## Follow-ups outside this PR

- spinquest-frontend has no CI test job, so its unit suite runs only when someone runs it by
  hand. Adding a `pnpm test` job to its CI is the durable fix; it lands in that repo and needs
  team agreement. Same for spinquest-mobile-app, which has no CI workflows.
- `pnpm` in spinquest-frontend refuses to start: "High-risk trust downgrade for `pnpm@10.34.5`
  (possible package takeover)", from the `packageManager` pin in `package.json`. Investigate
  before anyone runs `pnpm install` there.
- spinquest-frontend tracks `.env.test` in git, and the e2e specs read `TEST_USERNAME` and
  `TEST_PASSWORD` from it. Ticket it for review of whether those are real credentials.
- The measured review's security agent reported that the Veriff webhook secret is built into the
  client JS on dev deployments (pre-existing). Track it from that review's report.
