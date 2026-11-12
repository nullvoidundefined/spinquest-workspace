# Dossier style

Derived 2026-11-11 from the seven dossiers and `personal-docs/feature-flows-index.md`. Source for
`.claude/rules/personal-docs.md` and the `trace-feature` skill.

## Canonical structure

H1: `# <Feature>: how it works today`.

H2s in order:

1. `## At a glance`
2. `## The flow`
3. `## States and data`
4. `## Configuration`
5. `## Edge cases and failure handling`
6. `## What the team has already said`
7. `## Gaps, oddities, and risks`
8. `## Not verified`

A feature may add an H2 where it needs one (FTUE: "Where a new first-time experience would fit"
before States; promotions: "Inventory" before The flow; notifications: "Notification types and
triggers").

## Rules

- Opening: one dense paragraph of 3 to 5 sentences stating the whole mechanism, the main endpoints
  in backticks, and the headline gap or "there is no X". Scope exclusions get their own short
  paragraph.
- Source sentence after the opening, naming branch and sha per repo, e.g. "Backend references are
  to branch `PeterSons` (effectively Backend main); mobile references are to
  `spinquest-mobile-app` `master` at `fce425f0`." New dossiers use the header line
  `Read from source on YYYY-MM-DD against <repo>@<sha>, <repo>@<sha>.`
- Later additions: a paragraph `**Update YYYY-MM-DD (<what was read>):**` near the top, plus an H3
  inside The flow.
- At a glance: a table `| Piece | Path |` with backticked paths and lines.
- Citations: inline, in parentheses, backticked; full workspace-relative path on first use, then
  the bare filename (`ShopPackageService.ts:95-113`) or `:line` for the same file. Ranges `:66-71`,
  lists `:14,29`. Every claim carries one. `(grep)` marks a finding that something is absent.
- The flow: numbered steps, "actor does X (`cite`)", present tense, 1 to 3 sentences each; H3s for
  sub-flows.
- Exactly one mermaid `sequenceDiagram` per flow, after the main path's steps; short participant
  aliases (`FE as Web client`). No ASCII art.
- Tables for At a glance, States and data, Configuration (`| Key | Effect | Read at |`), and state
  machines (`| State | Set by | Component | Next |`).
- Inferred: a sentence beginning `Inferred:` marks reasoning, not reading. Never the parenthetical
  variants.
- Tone: neutral, evidence first, no praise, minimal hedging; uncertainty goes in Not verified.
  "Dead", "unreachable", "no caller" always carry a grep or citation.
- What the team has already said: bullets each citing `central-tech/<path>:line` with the verdict;
  end with what was not found.
- Gaps: bullets, each a lead sentence stating the problem, then evidence, then consequence.
- Not verified: deployed env and flag values, vendor behaviour, files skimmed or unread, and
  "Runtime behavior: nothing was executed."
- Trust bar (from the index): citations checked mechanically (file exists, line in range); a sample
  of claims re-read by hand; say so in Not verified.

## Known inconsistencies (fix on refresh, not now)

- feature-flags, signup-and-onboarding, first-time-user-experience lack the source sentence.
- `feature-flows-index.md` says nothing covers the native app; four dossiers now do.
- H1 suffix wording varies; `Inferred` marker format varies; payments numbers its gaps.
