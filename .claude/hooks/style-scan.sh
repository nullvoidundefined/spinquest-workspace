#!/usr/bin/env bash
# PostToolUse advisory: runs the team spinquest-style scanner on edited JS/TS files and relays its findings.
HOOKS="${BASH_SOURCE[0]%/*}"
WS="$(cd "$HOOKS/../.." && pwd)"
source "$HOOKS/run/payload.sh"
source "$HOOKS/run/emit.sh"
requireDeps advise style-scan jq node

SCANNER="$WS/claude-skills/plugins/spinquest-style/skills/spinquest-style/scripts/scan.mjs"
[[ -f "$SCANNER" ]] || exit 0

PAYLOAD="$(cat)"
filePath="$(readFilePath)"
case "$filePath" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs) ;;
  *) exit 0 ;;
esac
[[ -f "$filePath" ]] || exit 0

report="$(node "$SCANNER" "$filePath" 2>/dev/null)"
[[ -z "$report" || "$report" == *$'\nclean.' ]] && exit 0
emitContext PostToolUse "$report"
exit 0
