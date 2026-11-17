# review-crew resource caps Implementation Plan

> **Outcome (2026-11-17):** superseded. What shipped is a fixed 2-worker test cap plus worktree cleanup (BetsphereORG/claude-skills#20) and the mutation-worktree fix (BetsphereORG/claude-skills#21). The free-memory sizing, agent waves, guard hook and fixer agent described here were built, measured and then dropped as more than the problem needed; that work is on the local `review-crew-test-guard-archive` branch in claude-skills.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Size every review-crew test run and agent wave from the machine's free memory, give fix agents a browser-free toolset, enforce the sizing with an agent-scoped hook, and clean up the mutation worktree, without disabling any test.

**Architecture:** A dependency-free Node module (`size.mjs`) turns free memory and core count into `test_workers`, `e2e_workers` and `agent_wave`; the captain runs it once at step 5 and writes the values to `context.md`. Agent prose (`tests.md`, new `fixer.md`) tells agents to pass the worker flags; a plugin-level `PreToolUse` hook (`guard.mjs`) denies unsized test commands from `review-crew:tests` and `review-crew:fixer` only. SKILL.md gains waves, the tests-last rule, the fixer agent and worktree cleanup.

**Tech Stack:** Node (ESM, no dependencies, `node:test`), Claude Code plugin markdown (agents, skills, `hooks/hooks.json`).

**Spec:** `/Users/iangreenough/Desktop/work/spinquest/docs/superpowers/specs/2026-11-17-review-crew-resource-caps-design.md`

**Repo:** `/Users/iangreenough/Desktop/work/spinquest/claude-skills`, branch `review-crew-resource-caps` off `main` (`b69e9fb`). Commit subjects follow the repo's plain-sentence style (`Run review-crew fixes in the background`), no conventional prefix.

## Global Constraints

- `test_workers = clamp(floor(free_gb / 3), 1, cores - 1)`.
- `e2e_workers = clamp(floor(free_gb / 6), 1, 4)`.
- `agent_wave = clamp(floor(free_gb / 2), 2, 10)`.
- Free memory: macOS `sysctl -n hw.memsize` times the free percentage from `memory_pressure`; Linux `MemAvailable` from `/proc/meminfo`. If the read fails, use total RAM divided by 2 and say so.
- No test the review runs today is skipped. Disabling a test to save memory is an anti-goal.
- The hook acts only when `agent_type` is exactly `review-crew:tests` or `review-crew:fixer`; it fails open (exit 0) on input it cannot parse; it checks that a worker flag is present, not its value.
- No new dependencies. Node scripts use only `node:` built-ins, like `report/render.mjs`.
- `plugin.json` version `0.4.0`, with a `CHANGELOG.md` line in the same PR.
- No em dashes (U+2014) in any file.

## Review Focus

1. A test command chained after `cd`, `&&`, `;` or `|` (`cd web && pnpm vitest run a.test.ts`): the hook checks each segment, so the runner segment is still caught. Pinned in Task 2.
2. Worker flag passed through a package script (`pnpm test -- --maxWorkers=2`, `pnpm test --maxWorkers 2`, `npm run test -- --maxWorkers=2`): allowed, not denied as unsized. Pinned in Task 2.
3. Memory read fails (no `memory_pressure`, Linux container without `/proc/meminfo`): sizing falls back to total RAM / 2, reports `source: "total/2"`, and the captain's message says so. Pinned in Task 1.
4. A review where the `tests` agent ran without a worktree (`mutation: no`) or was not selected: step 7 cleanup does nothing and raises no error. Pinned in Task 5.
5. Hook input with no `agent_type` (the driver's own session) or malformed JSON: exit 0, nothing printed. Pinned in Task 2.

---

### Task 1: Sizing module

**Files:**
- Create: `plugins/review-crew/skills/captain/sizing/size.mjs`
- Test: `plugins/review-crew/skills/captain/sizing/size.test.mjs`

**Interfaces:**
- Produces:
  - `computeSizing({ freeGb: number, cores: number }) -> { testWorkers: number, e2eWorkers: number, agentWave: number }`
  - `parseMemoryPressureFreePct(text: string) -> number | null` (reads `System-wide memory free percentage: 58%`)
  - `parseMeminfoAvailableGb(text: string) -> number | null` (reads `MemAvailable:  8123456 kB`)
  - CLI: `node size.mjs [--free-gb <n>]` prints one JSON line `{"free_gb":27.8,"cores":18,"test_workers":9,"e2e_workers":4,"agent_wave":10,"source":"memory_pressure"}`. `source` is one of `memory_pressure`, `meminfo`, `total/2`, `override`. `--free-gb` sets `source: "override"` (used by the acceptance runs).

- [ ] **Step 1: Write the failing tests**

```js
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { computeSizing, parseMemoryPressureFreePct, parseMeminfoAvailableGb } from './size.mjs'

test('sizes from free memory on an 18-core machine', () => {
  assert.deepEqual(computeSizing({ freeGb: 4, cores: 18 }), { testWorkers: 1, e2eWorkers: 1, agentWave: 2 })
  assert.deepEqual(computeSizing({ freeGb: 8, cores: 18 }), { testWorkers: 2, e2eWorkers: 1, agentWave: 4 })
  assert.deepEqual(computeSizing({ freeGb: 16, cores: 18 }), { testWorkers: 5, e2eWorkers: 2, agentWave: 8 })
  assert.deepEqual(computeSizing({ freeGb: 27, cores: 18 }), { testWorkers: 9, e2eWorkers: 4, agentWave: 10 })
})

test('never goes below one worker or a wave of two', () => {
  assert.deepEqual(computeSizing({ freeGb: 0.5, cores: 8 }), { testWorkers: 1, e2eWorkers: 1, agentWave: 2 })
})

test('caps test workers at cores - 1', () => {
  assert.equal(computeSizing({ freeGb: 60, cores: 4 }).testWorkers, 3)
})

test('treats a single core as one worker', () => {
  assert.equal(computeSizing({ freeGb: 60, cores: 1 }).testWorkers, 1)
})

test('parses the memory_pressure free percentage', () => {
  assert.equal(parseMemoryPressureFreePct('The system has 51539607552 (3145728 pages...)\nSystem-wide memory free percentage: 58%\n'), 58)
  assert.equal(parseMemoryPressureFreePct('no such line'), null)
})

test('parses MemAvailable in GB', () => {
  assert.equal(parseMeminfoAvailableGb('MemTotal: 16000000 kB\nMemAvailable:    8388608 kB\n'), 8)
  assert.equal(parseMeminfoAvailableGb(''), null)
})
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `node --test plugins/review-crew/skills/captain/sizing/`
Expected: FAIL, `Cannot find module` for `size.mjs`.

- [ ] **Step 3: Implement `size.mjs`**

File header comment (one line, like `render.mjs`). The three exports above, plus a CLI block that runs only when executed directly (`import.meta.url === pathToFileURL(process.argv[1]).href`). The CLI reads free memory in this order: `--free-gb` override; macOS (`execFileSync('memory_pressure')` and `os.totalmem()`); Linux (`readFileSync('/proc/meminfo')`); otherwise `os.totalmem() / 2` with `source: "total/2"`. Any thrown read moves to the next source. Cores from `os.availableParallelism()`. `free_gb` rounded to one decimal.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `node --test plugins/review-crew/skills/captain/sizing/`
Expected: PASS, 6 tests.

- [ ] **Step 5: Check the CLI on this machine**

Run: `node plugins/review-crew/skills/captain/sizing/size.mjs` then `node plugins/review-crew/skills/captain/sizing/size.mjs --free-gb 8`
Expected: first prints `"source":"memory_pressure"` with `free_gb` near the free percentage times total RAM; second prints `{"free_gb":8,...,"test_workers":2,"e2e_workers":1,"agent_wave":4,"source":"override"}`.

- [ ] **Step 6: Commit**

```bash
git add plugins/review-crew/skills/captain/sizing/
git commit -m "Size review-crew test workers and agent waves from free memory"
```

---

### Task 2: Guard hook

**Files:**
- Create: `plugins/review-crew/hooks/hooks.json`
- Create: `plugins/review-crew/hooks/guard.mjs`
- Test: `plugins/review-crew/hooks/guard.test.mjs`

**Interfaces:**
- Produces:
  - `decideCommand({ agentType: string | undefined, command: string }) -> { deny: false } | { deny: true, reason: string }`
  - `GUARDED_AGENT_TYPES = ['review-crew:tests', 'review-crew:fixer']`
  - CLI: reads hook JSON from stdin (`tool_input.command`, `agent_type`); on deny prints `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"<reason>"}}` and exits 0; otherwise prints nothing and exits 0.
- `hooks.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "node \"${CLAUDE_PLUGIN_ROOT}/hooks/guard.mjs\"" }]
      }
    ]
  }
}
```

Rules for `decideCommand`, per segment (split on `&&`, `||`, `;`, `|`):
- e2e segment: contains `playwright test`, `cypress run`, or a package script whose name contains `e2e` (`pnpm test:e2e`, `npm run test:e2e`). Needs `--workers` or `-j`.
- unit segment: otherwise contains the word `vitest` or `jest`, or a package script named `test` or `test:<x>` without `e2e` (`pnpm test`, `npm test`, `npm run test:unit`, `yarn test`). Needs `--maxWorkers` or `--max-workers`.
- Deny reasons: `review-crew: unit test runs must pass --maxWorkers=<test_workers> from context.md.` and `review-crew: e2e runs must pass --workers=<e2e_workers> from context.md, and only against localhost.`

- [ ] **Step 1: Write the failing tests**

```js
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { decideCommand } from './guard.mjs'

const tests = (command) => decideCommand({ agentType: 'review-crew:tests', command })

test('denies unsized unit runs from the tests agent', () => {
  for (const command of ['pnpm vitest run', 'npx vitest run src/a.test.ts', 'pnpm test', 'npm test', 'npx jest', 'cd web && pnpm vitest run a.test.ts'])
    assert.equal(tests(command).deny, true, command)
})

test('allows sized unit runs', () => {
  for (const command of ['pnpm vitest run --maxWorkers=2 a.test.ts', 'pnpm test -- --maxWorkers=2', 'pnpm test --maxWorkers 2', 'npm run test -- --maxWorkers=2', 'npx jest --max-workers=1'])
    assert.equal(tests(command).deny, false, command)
})

test('denies unsized e2e and allows sized e2e', () => {
  assert.equal(tests('pnpm test:e2e').deny, true)
  assert.equal(tests('npx playwright test e2e/login.spec.ts').deny, true)
  assert.equal(tests('pnpm test:e2e --workers=1').deny, false)
  assert.equal(tests('npx playwright test -j 2 e2e/login.spec.ts').deny, false)
})

test('applies to the fixer agent', () => {
  assert.equal(decideCommand({ agentType: 'review-crew:fixer', command: 'pnpm test' }).deny, true)
})

test('ignores the main session and other agents', () => {
  for (const agentType of [undefined, 'general-purpose', 'tests', 'review-crew:verifier'])
    assert.equal(decideCommand({ agentType, command: 'pnpm test:e2e' }).deny, false, String(agentType))
})

test('ignores commands that are not test runs', () => {
  for (const command of ['git diff HEAD', 'grep -rn vitest.config src', 'cat package.json'])
    assert.equal(tests(command).deny, false, command)
})
```

Plus two CLI tests that spawn `node guard.mjs` with `spawnSync` and `input`:
- `{"agent_type":"review-crew:tests","tool_input":{"command":"pnpm test"}}` prints JSON whose `hookSpecificOutput.permissionDecision` is `"deny"`, exit 0.
- `not json` prints nothing, exit 0.

Note: `grep -rn vitest.config src` must not count as a unit run. Match `vitest`/`jest` only as the command word or after `npx`, `pnpm`, `pnpm exec`, `yarn`, `bunx`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `node --test plugins/review-crew/hooks/`
Expected: FAIL, `Cannot find module` for `guard.mjs`.

- [ ] **Step 3: Implement `guard.mjs` and `hooks.json`**

File header comment. `decideCommand` returns `{ deny: false }` at once when `agentType` is not in `GUARDED_AGENT_TYPES`. CLI wraps `JSON.parse` in try/catch and exits 0 on any error.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `node --test plugins/review-crew/hooks/`
Expected: PASS, all tests.

- [ ] **Step 5: Prove the tests can fail**

Temporarily replace the `GUARDED_AGENT_TYPES` check with `true`, run `node --test plugins/review-crew/hooks/`, expect `ignores the main session and other agents` to FAIL. Restore it. Then temporarily drop the e2e rule, expect `denies unsized e2e and allows sized e2e` to FAIL. Restore it. Rerun: PASS.

- [ ] **Step 6: Confirm `agent_type` for plugin agents**

Add `appendFileSync('/tmp/review-crew-hook.log', JSON.stringify({ agent_type: input.agent_type }) + '\n')` at the top of the CLI. Start `claude --plugin-dir plugins/review-crew` in a scratch repo, run `/review-crew:captain quick` on a one-line change with `+tests`, and read the log. Also run a Bash command in the main session.
Expected: the `tests` agent's calls log `"review-crew:tests"`, the main session logs `null`/absent. If the tests agent logs anything else, stop and follow the spec's "If `agent_type` does not match" rule. Remove the logging line.

- [ ] **Step 7: Commit**

```bash
git add plugins/review-crew/hooks/
git commit -m "Require worker flags on review-crew test commands"
```

---

### Task 3: Sized test runs in the tests agent

**Files:**
- Modify: `plugins/review-crew/agents/tests.md` (Input, Run the tests, Mutation check)

**Interfaces:**
- Consumes: `context.md` keys `test_workers`, `e2e_workers`, `free_gb` (Task 5 writes them).

- [ ] **Step 1: Edit the Input section**

Add: `context.md` gives `test_workers` and `e2e_workers`. Every test command passes them: unit and integration runs `--maxWorkers=<test_workers>` (vitest and jest), e2e runs `--workers=<e2e_workers>`. A command without the flag is blocked by the plugin's hook.

- [ ] **Step 2: Edit Run the tests**

Steps 1 to 3 keep their logic; each command gains `--maxWorkers=<test_workers>`. Add step 4, **E2E**: when the diff changes e2e specs or the flows they cover and the repo has e2e tests, read the base URL (`PLAYWRIGHT_BASE_URL`, else the config's `baseURL`). Run the changed specs with `--workers=<e2e_workers>` only if the host is `localhost` or `127.0.0.1` and `curl -sf <baseURL>` succeeds. Otherwise add a `note` finding: the e2e specs need the local stack, with the spec paths. Never run e2e against any other host. Renumber the old step 4.

- [ ] **Step 3: Edit Mutation check step 4**

"Run the tests that cover it, with `--maxWorkers=<test_workers>`."

- [ ] **Step 4: Verify**

Run: `grep -n "maxWorkers\|e2e_workers\|localhost" plugins/review-crew/agents/tests.md`
Expected: the Input rule, each run step, the e2e step and the mutation step. Read the whole section once for contradictions with the CI-green rule in step 1.

- [ ] **Step 5: Commit**

```bash
git add plugins/review-crew/agents/tests.md
git commit -m "Size review-crew test runs to free memory"
```

---

### Task 4: Fixer agent

**Files:**
- Create: `plugins/review-crew/agents/fixer.md`
- Modify: `plugins/review-crew/skills/captain/SKILL.md` (step 10, Background fixes, item 1)

**Interfaces:**
- Produces: subagent type `review-crew:fixer`, frontmatter `name: fixer`, `tools: Read, Grep, Glob, Bash, Edit, Write, Skill`.

- [ ] **Step 1: Write `agents/fixer.md`**

Frontmatter as above, with a `description` in the style of the other agents (`Review-crew agent. Applies one verified finding's fix...`). Body: the input (bundle path and one finding: `id`, `file`, `line`, `defect`, `failure`, `fix`); the four rules moved verbatim from SKILL.md step 10 item 1; test runs use `--maxWorkers=<test_workers>` from `context.md` and e2e follows the `tests.md` localhost rule; never check the UI in a browser, and when a fix needs a visual check, say so in the result line.

- [ ] **Step 2: Edit SKILL.md step 10 item 1**

"On `fix`, start one `review-crew:fixer` agent in the background. Give it the bundle path and the full finding." Remove the rule bullets now in `fixer.md`.

- [ ] **Step 3: Verify**

Run: `grep -n "general-purpose" plugins/review-crew/skills/captain/SKILL.md; grep -n "spinquest-style" plugins/review-crew/agents/fixer.md`
Expected: no `general-purpose` match; one `spinquest-style` match in `fixer.md`.

- [ ] **Step 4: Commit**

```bash
git add plugins/review-crew/agents/fixer.md plugins/review-crew/skills/captain/SKILL.md
git commit -m "Run review-crew fixes in a fixer agent without browser tools"
```

---

### Task 5: Captain sizing, waves and cleanup

**Files:**
- Modify: `plugins/review-crew/skills/captain/SKILL.md` (Arguments, step 5, step 6, step 7, step 8)

**Interfaces:**
- Consumes: `node ${CLAUDE_PLUGIN_ROOT}/skills/captain/sizing/size.mjs [--free-gb <n>]` JSON (Task 1).
- Produces: `context.md` keys `free_gb`, `cores`, `test_workers`, `e2e_workers`, `agent_wave`, `sizing_source`.

- [ ] **Step 1: Arguments**

Add `[--max-parallel <n>] [--free-gb <n>]`. `--max-parallel` overrides `agent_wave`; `--free-gb` overrides the memory read (for testing a smaller machine).

- [ ] **Step 2: Step 5, Context bundle**

Run the sizing script once, write its six values to `context.md`, and tell the driver one line: `<free_gb> GB free, <cores> cores: tests use <test_workers> workers, agents run <agent_wave> at a time.` When `source` is `total/2`, add `(free memory unreadable; using half of total RAM)`.

- [ ] **Step 3: Step 6, Select and run**

Replace "start all of them in one message" with: start the selected agents in waves of `agent_wave`, each wave in one message, the next wave when the previous one returns. When `agent_wave` is smaller than the number of selected agents, the `tests` agent runs alone in the last wave.

- [ ] **Step 4: Step 7, Collect**

Add item 5: when the `tests` agent ran in a worktree, remove it with `git worktree remove --force <path>` after its findings are saved. When it did not, skip. A worktree that cannot be removed is reported to the driver with its path.

- [ ] **Step 5: Step 8, Verify**

"Start the verifier batches in waves of `agent_wave`" in place of "all in one message".

- [ ] **Step 6: Verify**

Run: `grep -n "agent_wave\|size.mjs\|worktree remove\|max-parallel" plugins/review-crew/skills/captain/SKILL.md`
Expected: matches in Arguments, step 5, 6, 7 and 8. Read steps 5 to 8 end to end once.

- [ ] **Step 7: Commit**

```bash
git add plugins/review-crew/skills/captain/SKILL.md
git commit -m "Run review-crew agents in memory-sized waves and clean up the mutation worktree"
```

---

### Task 6: Version, changelog and README

**Files:**
- Modify: `plugins/review-crew/.claude-plugin/plugin.json` (`version`)
- Modify: `plugins/review-crew/CHANGELOG.md`
- Modify: `README.md` (review-crew row: mention the sizing and `--max-parallel`)

- [ ] **Step 1: Bump and log**

`"version": "0.4.0"`. CHANGELOG line in the existing style: `- **0.4.0** (<merge date>) - The captain sizes test workers and agent waves from free memory (`sizing/size.mjs`), so a full review fits a smaller laptop without skipping tests. A plugin hook blocks unsized test commands from the tests and fixer agents. Fixes run in a new `fixer` agent with no browser tools. The mutation worktree is removed after the review.`

- [ ] **Step 2: Verify**

Run: `node -p "require('./plugins/review-crew/.claude-plugin/plugin.json').version"; grep -rc $'\u2014' plugins/review-crew README.md | grep -v ':0$'`
Expected: `0.4.0`; the second command prints nothing.

- [ ] **Step 3: Commit**

```bash
git add plugins/review-crew/.claude-plugin/plugin.json plugins/review-crew/CHANGELOG.md README.md
git commit -m "Release review-crew 0.4.0"
```

---

### Task 7: Measured acceptance runs

Manual, on Ian's machine, with the branch loaded via `claude --plugin-dir plugins/review-crew`. Reuse the sampler from the spec's measurement (`ram-probe/sample.sh`, recreate it if the scratchpad was cleared). No commits.

- [ ] **Step 1: Three sized reviews**

In spinquest-frontend on `merch`, run `/review-crew:captain full --free-gb 27`, then `--free-gb 8`, then `--free-gb 4`, each stopped at the published report, with the sampler running.
Expected per run: vitest peaks at `test_workers + 1` processes; the tests agent's targeted and mutation results match the 0.3.0 run (72 files, 1141 tests, same mutation findings); at `--free-gb 4`, vitest plus Claude app growth over baseline is under 2 GB.

- [ ] **Step 2: Profile message**

Run once with no `--free-gb`. Expected: the one-line message's `free_gb` matches `memory_pressure` at that moment.

- [ ] **Step 3: e2e both ways**

On a branch that touches an e2e spec: with the local stack down, expect the "needs the local stack" note and no Chromium in `pstree`. With `/local-stack up` on localhost, expect the changed specs to run with `--workers=<e2e_workers>`.

- [ ] **Step 4: Cleanup, driver, Backend, quick**

- `git worktree list` after each run: no `.claude/worktrees/agent-*`.
- In the main session with the plugin on: `pnpm test` and `pnpm test:e2e` are not blocked.
- A `fix` on a style finding loads `spinquest-style`.
- `/review-crew:captain full` on a Backend PR still runs targeted tests and the mutation check, with `--maxWorkers`.
- `/review-crew:captain quick` behaves as on 0.3.0.

- [ ] **Step 5: Record**

Put the four runs' numbers (peak vitest, peak Claude app, lowest free memory, total time) and the `node --test` output in the PR description. Tune the divisors only if a run misses its target, and update the spec's formulas to match.
