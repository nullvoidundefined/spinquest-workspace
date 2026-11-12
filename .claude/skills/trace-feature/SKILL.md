---
name: trace-feature
description: Use to write a new feature dossier ("how does X work", "trace X") into personal-docs/, or to refresh an existing one with `refresh <dossier>`. Modes: trace (new dossier) and refresh (re-check citations and shas of an existing dossier).
---

# trace-feature

Input: a feature or question, or `refresh <dossier>`. Dossiers live in `personal-docs/` (tracked in the workspace repo: commit there, never inside the six repos).

## Trace mode

1. Record `branch@sha` of each relevant repo: `git -C <repo> rev-parse --abbrev-ref HEAD` and `git -C <repo> rev-parse --short HEAD`.
2. Dispatch one `repo-tracer` subagent per relevant repo, in parallel. Give each the feature, the repo, and the facts format. Check `personal-docs/feature-flows-index.md` first for an existing dossier.
3. Dispatch one `repo-tracer` pass over `central-tech` for the team verdict (`TODO.md`, `parity/`, `reference/`, bug docs). Record what was not found.
4. Write `personal-docs/<feature-slug>.md` in the dossier style below.
5. From the workspace root, run `node .claude/hooks/run/checkCitations.mjs personal-docs/<feature-slug>.md`. It prints `MISSING`, `OUT_OF_RANGE`, and `NO_HEADER` lines. Fix each, rerun until clean. If it cannot run (for example a denied permission prompt), say so in Not verified and do not claim citations were checked mechanically.
6. Add a row to `personal-docs/feature-flows-index.md`.

## Refresh mode

Input: `refresh <dossier>`.

1. Read the dossier header line for the old shas. If there is no header line, take the shas from its source sentence. If neither exists, record that and use current HEADs. Record the current `branch@sha` of each repo.
2. From the workspace root, run `node .claude/hooks/run/checkCitations.mjs <dossier>`. It catches only missing files, out-of-range lines, and a missing header. It cannot see a citation whose line moved but is still in range. If it cannot run (for example a denied permission prompt), say so and do not claim citations were checked mechanically.
3. Find moved-but-in-range citations with a `repo-tracer` pass over every cited area, or by diffing each repo from the old sha to the current sha (`git -C <repo> diff <old>..HEAD -- <cited files>`). An empty `git diff <old>..HEAD` under the current-HEAD fallback (no recorded old sha) is not evidence that nothing moved; a `repo-tracer` pass is then required. For each flagged or suspect claim, report: moved (new line), vanished, or still correct.
4. Rewrite the header shas and date. Add the source sentence if the dossier lacks one.
5. Offer to update `personal-docs/feature-flows-index.md` (the index is stale about native-app coverage).
6. Dry run: when told to report and not write, do steps 1 to 3 and print the findings. Write nothing.

## Dossier style

H1: `# <Feature>: how it works today`.

Opening: one dense paragraph, 3 to 5 sentences, stating the whole mechanism, the main endpoints in backticks, and the headline gap or "there is no X". Scope exclusions get their own short paragraph.

Header line after the opening: `Read from source on YYYY-MM-DD against <repo>@<sha>, <repo>@<sha>.`

H2s, in this order, exact text:

1. `## At a glance`
2. `## The flow`
3. `## States and data`
4. `## Configuration`
5. `## Edge cases and failure handling`
6. `## What the team has already said`
7. `## Gaps, oddities, and risks`
8. `## Not verified`

A feature may add an H2 where it needs one.

Rules:

- At a glance: table `| Piece | Path |` with backticked paths and lines.
- Citations: inline, in parentheses, backticked. Full workspace-relative path on first use, then the bare filename (`ShopPackageService.ts:95-113`) or `:line` for the same file. Ranges `:66-71`, lists `:14,29`. Every claim carries one. `(grep)` marks a finding that something is absent.
- The flow: numbered steps, "actor does X (`cite`)", present tense, 1 to 3 sentences each. H3s for sub-flows.
- Exactly one mermaid `sequenceDiagram`, after the main path's steps. Short participant aliases (`FE as Web client`). No ASCII art.
- Tables for States and data, Configuration (`| Key | Effect | Read at |`), and state machines (`| State | Set by | Component | Next |`).
- Reasoning, not reading: start the sentence with `Inferred:`. No parenthetical variants.
- "Dead", "unreachable", "no caller" always carry a grep or citation.
- Tone: neutral, evidence first, no praise, minimal hedging. Uncertainty goes in Not verified.
- What the team has already said: bullets, each citing `central-tech/<path>:line` with the verdict. End with what was not found.
- Gaps, oddities, and risks: bullets, each a lead sentence stating the problem, then evidence, then consequence.
- Not verified: deployed env and flag values, vendor behaviour, files skimmed or unread, "Runtime behavior: nothing was executed.", and, only if the checker ran, that citations were checked mechanically with a sample re-read by hand. If the checker did not run, say so here.
- Later additions: a paragraph `**Update YYYY-MM-DD (<what was read>):**` near the top plus an H3 inside The flow.
