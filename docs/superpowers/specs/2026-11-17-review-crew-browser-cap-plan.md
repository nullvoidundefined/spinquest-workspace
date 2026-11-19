# review-crew browser cap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix agents don't use claude-in-chrome unless the driver chooses `fix browser`, and only one browser fix runs at a time.

**Architecture:** Instructions only, in `plugins/review-crew/skills/captain/SKILL.md` step 10: one new walkthrough answer, one extra rule in the fix-agent rules, one new Background fixes item for the queue. No code, no hook.

**Tech Stack:** Claude Code plugin markdown.

**Spec:** `/Users/iangreenough/Desktop/work/spinquest/docs/superpowers/specs/2026-11-17-review-crew-browser-cap-design.md`

**Repo:** `/Users/iangreenough/Desktop/work/spinquest/claude-skills`, new branch `review-crew-browser-cap` cut from `origin/review-crew-mutation-worktree-sha` (BetsphereORG/claude-skills#21), in its own worktree under `~/Desktop/work/worktrees/`. One commit, plain-sentence subject, like the repo's other commits.

## Global Constraints

- Plain `fix` stays the default and means no browser.
- The new answer is exactly `fix browser`.
- Plain-fix rule text: "Do not use the browser. If the fix needs a visual check, say so in your result: `Needs a visual check: <what to look at>`."
- Browser-fix rule text: "You may use the browser to check this fix. Close every tab you opened before you report back."
- Queue message: `Fix #<n> queued behind #<m> (browser).`
- Version `0.3.4`, with a `CHANGELOG.md` line after `0.3.3`.
- The captain's own browser use is out of scope; nothing about it changes.
- No em dashes (U+2014) in any file.

## Review Focus

1. A `fix browser` agent pauses with a question (Background fixes item 5) while holding the browser: the next `fix browser` keeps waiting until that agent finishes, not just until it pauses. Pinned in Task 1 step 3.
2. `fix browser` on a file that a plain fix still has open: the same-file queue (item 2) applies too, so the fix waits for whichever frees up last. Pinned in Task 1 step 3.
3. A `fix browser` agent that fails or errors before closing its tabs: the captain's result line says the browser fix failed, so the driver knows tabs may be left open. Pinned in Task 1 step 2.
4. The driver answers `fix browser` on a finding that isn't a UI change: allowed; the agent just doesn't need the browser. No rule needed.
5. Style fixes queued behind substantive fixes (item 2) keep their order; the browser queue adds to it, it doesn't replace it. Pinned in Task 1 step 3.

---

### Task 1: The rule in SKILL.md

**Files:**
- Modify: `plugins/review-crew/skills/captain/SKILL.md` (step 10: the walkthrough answers list and the Background fixes section)

**Interfaces:**
- Produces: the `fix browser` answer and the browser queue, used by Task 3's manual check.

- [ ] **Step 1: Add the answer.** In the walkthrough answers, after `fix`, add:
  `- \`fix browser\`: like \`fix\`, but the fix agent may check its fix in the browser (see Background fixes).`
- [ ] **Step 2: Add the rule to item 1 (Start).** Add one bullet to the rules the captain gives every fix agent: the plain-fix text for `fix`, the browser-fix text for `fix browser` (both verbatim from Global Constraints). In item 4 (Results), add: when a `fix browser` agent fails, say so, because its tabs may still be open.
- [ ] **Step 3: Add the queue.** New item after item 2 (One file, one agent): **One browser fix at a time.** If a `fix browser` agent is still open, including one paused on a question, queue the new `fix browser` and start it when the first finishes. It also follows the one-file queue in item 2. Item 3 (Tell the driver) gains the queue message from Global Constraints. Renumber the items after it.
- [ ] **Step 4: Verify.**
  Run: `grep -n "fix browser\|queued behind #.*(browser)\|Needs a visual check\|Close every tab" plugins/review-crew/skills/captain/SKILL.md`
  Expected: the answer, both rule texts, the queue item and the queue message. Then read step 10 end to end once; the item numbers run in order and nothing else in it changed.

### Task 2: Release and PR

**Files:**
- Modify: `plugins/review-crew/.claude-plugin/plugin.json` (`version` to `0.3.4`)
- Modify: `plugins/review-crew/CHANGELOG.md` (one `0.3.4` line after `0.3.3`)

- [ ] **Step 1: Bump and log.** CHANGELOG line: fix agents no longer use the browser unless the driver chooses `fix browser`; one browser fix runs at a time and closes its tabs.
- [ ] **Step 2: Verify.**
  Run: `grep -rc $'\u2014' plugins/review-crew | grep -v ':0$'; git diff --stat origin/review-crew-mutation-worktree-sha`
  Expected: no em dashes; 3 files changed (`SKILL.md`, `plugin.json`, `CHANGELOG.md`).
- [ ] **Step 3: Commit** as one commit: "Keep review-crew fix agents off the browser unless the driver asks, one at a time".
- [ ] **Step 4: Push and open a draft PR** only after Ian confirms. Base `review-crew-mutation-worktree-sha`; first line `**Depends on:** BetsphereORG/claude-skills#21. Merge that first, then retarget this PR to \`main\`.`; a short Summary and Test section in the repo's style.

### Task 3: Manual check in the driver's desktop session

A headless session has no claude-in-chrome, so this needs Ian's desktop session with the Chrome extension connected, and the branch loaded with `--plugin-dir`. No commits.

- [ ] **Step 1: Start the memory sampler** watching Chrome's renderer processes.
- [ ] **Step 2: Run a `full` review of a frontend branch with UI findings.** In the walkthrough, choose plain `fix` on two UI findings, then `fix browser` on two more, back to back.
- [ ] **Step 3: Check.**
  Expected:
  - plain `fix`: no new Chrome tabs, and a `Needs a visual check: …` line where relevant;
  - `fix browser`: the second shows `Fix #<n> queued behind #<m> (browser).` and starts only when the first finishes;
  - no tabs left open after each browser fix;
  - Chrome's memory rises only during a browser fix.
- [ ] **Step 4: Record** the result in the PR's Test section.
