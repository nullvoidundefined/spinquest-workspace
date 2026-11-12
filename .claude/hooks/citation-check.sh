#!/usr/bin/env bash
# PostToolUse advisory: runs the citation checker on an edited personal-docs dossier and emits any problems as context.
HOOKS="${BASH_SOURCE[0]%/*}"
source "$HOOKS/run/payload.sh"
source "$HOOKS/run/emit.sh"
requireDeps advise citation-check jq node

PAYLOAD="$(cat)"
filePath="$(readFilePath)"
case "$filePath" in
  */personal-docs/feature-flows-index.md) exit 0 ;;
  */personal-docs/*.md) ;;
  *) exit 0 ;;
esac
[[ -f "$filePath" ]] || exit 0

workspaceRoot="$(cd "$HOOKS/../.." && pwd)"
problems="$(node "$HOOKS/run/checkCitations.mjs" "$filePath" --root "$workspaceRoot")"
[[ -z "$problems" ]] && exit 0

emitContext PostToolUse "Citation problems in ${filePath##*/}: ${problems//$'\n'/; }. Re-read the cited source and fix the citation or the claim."
exit 0
