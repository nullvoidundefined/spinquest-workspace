# review-crew browser cap

2026-11-17 · Ian Greenough

## Intent

Keep review-crew's fix agents from opening claude-in-chrome unless the driver asks for it, and
from using it more than one at a time when they do.

**Why:** Danek and Chris Connors both suspect claude-in-chrome caused the memory problem that
locked Chris's laptop during a review. Chris usually skips browser checks and tests visually by
hand, but sometimes wants the agent to use the browser. BetsphereORG/claude-skills#20 capped the
test workers; this covers the browser.

## What exists today

- Review agents and verifiers cannot use a browser: their `tools:` lists exclude MCP tools.
- Fix agents are `general-purpose` (SKILL.md step 10, Background fixes) and get every tool,
  claude-in-chrome included. Nothing tells them whether to use it, and nothing coordinates them.
- The captain already queues fixes that touch the same file (Background fixes, item 2).
- claude-in-chrome drives the driver's one real Chrome. Parallel users mean more tabs in that
  browser, not more browsers.
- A headless `claude -p` session has no claude-in-chrome, so none of #20's measured reviews could
  have started it.

## Goals

- By default, a fix agent never opens the browser. When a fix needs a visual check, it says so,
  and the driver checks by hand.
- The driver can ask for a browser check on a specific fix.
- At most one fix agent uses the browser at a time, and it closes the tabs it opened.

## Non-goals

- The captain's own browser use. It runs in the driver's session, under the driver's control.
- Making browser use safe (local app, local API). That is a separate decision from memory.
- Any new code or hook.

## Approaches

1. **Off by default, opt in per fix (chosen).** Fix agents are told not to use the browser.
   A new walkthrough answer, `fix browser`, lets that one fix use it. One browser fix at a time;
   a second `fix browser` waits for the first. Matches how Chris works, and no fix agent opens
   Chrome unless the driver asks.
2. **Always allowed, one at a time.** Every fix may use the browser, but only one at a time; the
   others report "Needs a visual check". Rejected: it still opens Chrome on fixes nobody wanted
   checked, which is what Danek and Chris suspect.
3. **A hook that enforces a lock.** Rejected: a lock across background agents is complex, and
   #20 already dropped a command-checking hook as more than the problem needed.

## Decisions

- **Walkthrough answers** (SKILL.md step 10): add `fix browser`, "start a fix agent that may check
  its fix in the browser". Plain `fix` stays the default.
- **Background fixes, item 1:** every fix agent gets one more rule. For a plain `fix`: "Do not use
  the browser. If the fix needs a visual check, say so in your result:
  `Needs a visual check: <what to look at>`." For `fix browser`: "You may use the browser to check
  this fix. Close every tab you opened before you report back."
- **Background fixes, new item (one browser fix at a time):** if a `fix browser` agent is still
  open, a new `fix browser` waits in the queue, like fixes on the same file, and starts when the
  first finishes. The captain says `Fix #4 queued behind #2 (browser).`
- **Version** 0.3.4 with a `CHANGELOG.md` line. Stacked on BetsphereORG/claude-skills#21 (0.3.3),
  so the versions stay in merge order.

## Verification

A headless session cannot use claude-in-chrome, so this needs the driver's desktop session with
the Chrome extension connected: a review of a frontend branch where the driver chooses `fix` on
two UI findings and `fix browser` on two more, with the memory sampler watching Chrome's renderer
processes.

- Plain `fix`: no new Chrome tabs; results say "Needs a visual check" where relevant.
- `fix browser`: one fix uses the browser at a time; the second waits; the tabs are closed after.

## Left to the builder

The exact wording of the rules and the queue message, as long as they say the above.
