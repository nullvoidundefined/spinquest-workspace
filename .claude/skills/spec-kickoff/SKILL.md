---
name: spec-kickoff
description: Use when handed a product spec, Notion Specs row, Linear ticket or Figma link to start a task. Gathers the spec, ticket and designs, writes a kickoff brief, prepares the branch, then hands off to /spinquest-change.
---

# spec-kickoff

Input: a Notion spec URL, a Linear issue ID (`GRO-11`), or a Figma link. Output: a kickoff brief in `specs/` and a local branch, ready for `/spinquest-change`. Read only until step 6; write no app code here.

## Steps

1. **Spec.** Fetch it with the Notion MCP. If it is a row in the Specs database (`collection://a5848a11-1478-44f1-98a8-1970ed1581c9`), read `Status`, `Type`, `Product`, `Pod`, `Doc link`, `Figma Link (Desktop)`, `Figma Link (Mobile)`, `Linear Link`, `Target Release`. Follow `Doc link` when the spec lives in a Google Doc. A `Status` of Discovery means the spec is not final: say so in the brief.
2. **Ticket.** With the Linear MCP, open the linked issue or project and list issues assigned to `me`. Take `gitBranchName` from the issue. No ticket: draft one with `/create-linear-ticket` (Triage, confirm before posting) and stop until it exists.
3. **Designs.** For each Figma link, create a Figma session, then pull design context and a screenshot per frame (follow the Figma plugin's design-to-code skill when installed). Map each element to an existing component (`@/components/ui`, the feature's components, MUI) and colours to `src/lib/theme` tokens, never new hex literals. Desktop and mobile frames both count. If Figma refuses access, run `whoami`, report the seat and file, and stop: never rebuild a screen from a description.
4. **Context.** Name the repo(s). Check the team verdict in `central-tech` (`TODO.md`, `parity/`) for anything Backend-dependent. Read the feature's dossier in Notion (links in `.claude/notion-docs.md`). Confirm every endpoint the screens need exists in Backend `PeterSons`; a missing one is a cross-repo change (one session per repo).
5. **Brief.** Write `specs/<ISSUE-ID>-<slug>.md` with: links (spec, ticket, frames); acceptance criteria quoted from the spec; screens and states (loading, empty, error, gold-coins-only, logged out); components reused or new; API calls and query keys; feature flag (`feat-` key, default off) if the spec implies a rollout; i18n keys; analytics events; tests to add; open questions for product and design. Show the brief and wait for approval.
6. **Branch.** In the repo: `git fetch`, branch from the up-to-date base (`origin/main`, or the feature branch the ticket names, such as `origin/merch`) using `gitBranchName`. Never push.
7. **Hand off.** Start `/spinquest-change` with the brief. Open questions go to the spec owner or the ticket, not into guesses in code.

## Stop conditions

- An MCP is missing: tell the user to run `claude mcp list` and add Notion, Linear or Figma; do not scrape pages instead.
- The spec contradicts the code or a `central-tech` verdict: list the conflict in the brief and ask.
