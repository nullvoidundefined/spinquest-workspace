---
paths:
  - "personal-docs/**"
source: personal-docs dossiers 2026-11-11
---

# personal-docs dossiers

Dossiers live in Notion (links in `.claude/notion-docs.md`). Files here are working drafts only: `/trace-feature` writes, checks, publishes and then deletes them. Never treat a local draft as the source. `start-local-stack.sh` is the one permanent file.

## Hard rules

- H1 `# <Feature>: how it works today`.
- H2s in order: At a glance, Architecture, API, The flow, States and data, Configuration, Edge cases and failure handling, What the team has already said, `Gaps, oddities, and risks`, Not verified. Add an extra H2 only where the feature needs one.
- Opening: one dense paragraph of 3 to 5 sentences: the whole mechanism, the main endpoints in backticks, the headline gap or "there is no X". Scope exclusions get their own short paragraph.
- Then the source line: `Read from source on YYYY-MM-DD against <repo>@<sha>, <repo>@<sha>.`
- Every claim carries a citation: inline, in parentheses, backticked. Full workspace-relative path on first use, then the bare filename or `:line`. Ranges `:66-71`, lists `:14,29`. `(grep)` marks a finding that something is absent.
- Open the file before citing a line. The citation hook checks file and line range.
- Reasoning that was not read starts a sentence with `Inferred:`. Never a parenthetical variant.
- "Dead", "unreachable" and "no caller" always carry a grep or citation.

## Conventions

- At a glance: table `| Piece | Path |` with backticked paths and lines.
- The flow: numbered steps, "actor does X (`cite`)", present tense, 1 to 3 sentences each; H3s for sub-flows.
- Exactly one mermaid `sequenceDiagram` per flow, after the main path's steps, with short participant aliases (`FE as Web client`). No ASCII art.
- Tables for States and data, Configuration (`| Key | Effect | Read at |`) and state machines (`| State | Set by | Component | Next |`).
- What the team has already said: bullets each citing `central-tech/<path>:line` with the verdict; end with what was not found.
- Gaps: bullets, each a lead sentence naming the problem, then evidence, then consequence.
- Not verified: deployed env and flag values, vendor behaviour, files skimmed or unread, and "Runtime behavior: nothing was executed." State the trust bar: citations checked mechanically, a sample re-read by hand.
- Later additions: a `**Update YYYY-MM-DD (<what was read>):**` paragraph near the top plus an H3 inside The flow.
- Tone: neutral, evidence first, minimal hedging; uncertainty goes in Not verified.
