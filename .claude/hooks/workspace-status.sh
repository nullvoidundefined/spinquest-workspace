#!/usr/bin/env bash
# SessionStart advisory: one read-only status line (branch, dirty count, commits behind upstream) per workspace repo.
HOOKS="${BASH_SOURCE[0]%/*}"
WS="$(cd "$HOOKS/../.." && pwd)"
source "$HOOKS/run/emit.sh"
requireDeps advise workspace-status jq git

lines=""
for repo in Backend central-tech claude-skills spinquest-frontend spinquest-mobile-app spinquest-rips-frontend; do
  [[ -d "$WS/$repo" ]] || continue
  branch="$(git -C "$WS/$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)" || continue
  dirty="$(git -C "$WS/$repo" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  behind="$(git -C "$WS/$repo" rev-list --count 'HEAD..@{u}' 2>/dev/null)" || behind="no-upstream"
  lines+="$repo $branch dirty=$dirty behind=$behind"$'\n'
done

[[ -n "$lines" ]] && emitContext SessionStart "Workspace status (no fetch; behind is vs last fetched upstream):
${lines%$'\n'}"
exit 0
