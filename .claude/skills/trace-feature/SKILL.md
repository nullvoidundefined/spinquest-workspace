---
name: trace-feature
description: Use to write a new feature dossier ("how does X work", "trace X") and publish it to Notion, or to refresh an existing one with `refresh <feature>`. Modes: trace (new dossier) and refresh (re-check citations and shas of an existing dossier).
---

# trace-feature

Input: a feature or question, or `refresh <feature>`. Dossiers live in Notion as child pages of the SpinQuest feature flows page (links in `.claude/notion-docs.md`). `personal-docs/<feature-slug>.md` is a working draft only: write it, check it, publish it, then delete it. Needs the Notion MCP; if it is missing, stop and say so.

## Publishing a draft to Notion

- Title: the H1 text. Content: the draft without the H1.
- Notion markdown: escape `|` inside table cells (`\|`), keep raw `<tag>` text inside backticks, and use `<toggle>` rather than `<details>`.
- New dossier: create a page with parent page `417a274ca95d81f38267f808ac7e62ba` (SpinQuest feature flows). Existing dossier: replace the page content.
- Fetch the page afterwards and check the tables, the mermaid block and the header line survived.
- Only after a clean publish, delete the draft. If the checker or the publish failed, keep the draft and say why.

## Trace mode

1. Record `branch@sha` of each relevant repo: `git -C <repo> rev-parse --abbrev-ref HEAD` and `git -C <repo> rev-parse --short HEAD`.
2. Check `.claude/notion-docs.md` and the SpinQuest feature flows page for an existing dossier. If one exists, use refresh mode instead.
3. Dispatch one `repo-tracer` subagent per relevant repo, in parallel. Give each the feature, the repo, and the facts format.
4. Dispatch one `repo-tracer` pass over `central-tech` for the team verdict (`TODO.md`, `parity/`, `reference/`, bug docs). Record what was not found.
5. Write the draft `personal-docs/<feature-slug>.md` in the dossier style below.
6. From the workspace root, run `node .claude/hooks/run/checkCitations.mjs personal-docs/<feature-slug>.md`. It prints `MISSING`, `OUT_OF_RANGE`, and `NO_HEADER` lines. Fix each, rerun until clean. If it cannot run (for example a denied permission prompt), say so in Not verified and do not claim citations were checked mechanically.
7. Publish the draft as a new page (see Publishing).
8. Add a row for the new page to the index table on the SpinQuest feature flows page, and a row to `.claude/notion-docs.md`.
9. Delete the draft.

## Refresh mode

Input: `refresh <feature>`.

1. Find the page in `.claude/notion-docs.md` and fetch it. Write it to `personal-docs/<feature-slug>.md` as a draft: put the title back as the H1, turn `<code>x</code>` into backticks and `<b>x</b>` into `**x**`, and unescape `\|` in tables.
2. Read the header line for the old shas. If there is no header line, take the shas from its source sentence. If neither exists, record that and use current HEADs. Record the current `branch@sha` of each repo.
3. From the workspace root, run `node .claude/hooks/run/checkCitations.mjs personal-docs/<feature-slug>.md`. It catches only missing files, out-of-range lines, and a missing header. It cannot see a citation whose line moved but is still in range. If it cannot run (for example a denied permission prompt), say so and do not claim citations were checked mechanically.
4. Find moved-but-in-range citations with a `repo-tracer` pass over every cited area, or by diffing each repo from the old sha to the current sha (`git -C <repo> diff <old>..HEAD -- <cited files>`). An empty `git diff <old>..HEAD` under the current-HEAD fallback (no recorded old sha) is not evidence that nothing moved; a `repo-tracer` pass is then required. For each flagged or suspect claim, report: moved (new line), vanished, or still correct.
5. Fix the draft, rewrite the header shas and date, and add the source sentence if missing. Rerun the checker until clean.
6. Publish by replacing the page content (see Publishing), offer to update the index row, then delete the draft.
7. Dry run: when told to report and not write, do steps 1 to 4, print the findings, delete the draft, and write nothing to Notion.

## Dossier style

H1: `# <Feature>: how it works today`.

Opening: one dense paragraph, 3 to 5 sentences, stating the whole mechanism, the main endpoints in backticks, and the headline gap or "there is no X". Scope exclusions get their own short paragraph.

Header line after the opening: `Read from source on YYYY-MM-DD against <repo>@<sha>, <repo>@<sha>.`

H2s, in this order, exact text:

1. `## At a glance`
2. `## Architecture`
3. `## API`
4. `## The flow`
5. `## States and data`
6. `## Configuration`
7. `## Edge cases and failure handling`
8. `## What the team has already said`
9. `## Gaps, oddities, and risks`
10. `## Not verified`

A feature may add an H2 where it needs one.

Rules:

- At a glance: table `| Piece | Path |` with backticked paths and lines.
- Architecture: how the slice is structured (layers, modules, ownership across repos), cited like any claim.
- API: table of endpoints or events the feature exposes or consumes (`| Method | Path | Handler | Notes |`). If there is none, say so with a grep.
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
