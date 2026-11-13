#!/usr/bin/env bash
# PreToolUse guard: blocks git commit/push segments that skip hooks (--no-verify, -n), SKIP_HOOKS= or HUSKY=0 assignments, and -c core.hooksPath= overrides.
source "${BASH_SOURCE[0]%/*}/run/emit.sh"
requireDeps block hook-bypass-guard jq
PAYLOAD="$(cat)"
source "${BASH_SOURCE[0]%/*}/run/payload.sh"

gitPrefix='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--[a-z-]+(=[^[:space:]]+)?))*[[:space:]]+'
commitStart="${gitPrefix}commit([[:space:]]|\$)"
pushStart="${gitPrefix}push([[:space:]]|\$)"
bypassFlag='(^|[[:space:]])(--no-verify|-[a-zA-Z]*n[a-zA-Z]*)([[:space:]]|$)'
longBypassFlag='(^|[[:space:]])--no-verify([[:space:]]|$)'

command="$(readCommand)"
[[ -z "$command" ]] && exit 0
segments="$(listSegments "$command")"

[[ "$segments" =~ (^|[^A-Za-z0-9_])SKIP_HOOKS= ]] && blockWith hook-bypass-guard "SKIP_HOOKS is not allowed"

[[ "$command" =~ (^|[^A-Za-z0-9_])HUSKY=[\"\']?0 ]] && blockWith hook-bypass-guard "HUSKY=0 is not allowed"
shopt -s nocasematch
[[ "$command" =~ (^|[[:space:]])-c[[:space:]]*[\"\']?core\.hookspath= ]] && blockWith hook-bypass-guard "core.hooksPath override is not allowed"
shopt -u nocasematch

while IFS= read -r segment; do
  if [[ "$segment" =~ $commitStart && "$segment" =~ $bypassFlag ]]; then
    blockWith hook-bypass-guard "git commit must not skip hooks (--no-verify / -n)"
  fi
  if [[ "$segment" =~ $pushStart && "$segment" =~ $longBypassFlag ]]; then
    blockWith hook-bypass-guard "git push must not skip hooks (--no-verify)"
  fi
done <<<"$segments"
exit 0
