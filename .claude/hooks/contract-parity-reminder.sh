#!/usr/bin/env bash
# PostToolUse advisory: reminds to check env and spec parity after a contract-shaped file (env, router, routes, spec) is touched.
HOOKS="${BASH_SOURCE[0]%/*}"
source "$HOOKS/run/payload.sh"
source "$HOOKS/run/emit.sh"
requireDeps advise contract-parity-reminder jq

PAYLOAD="$(cat)"
filePath="$(readFilePath)"
[[ -z "$filePath" ]] && exit 0

isContract=0
[[ "${filePath##*/}" == .env.example ]] && isContract=1
case "$filePath" in
  */config/env.*|*/env.ts|*router.tsx|*/route/*|*/routes/*|*central-tech/spec/*) isContract=1 ;;
esac
[[ $isContract -eq 1 ]] || exit 0

emitContext PostToolUse "Contract touched: check .env.example, spec/, and git grep over *.md for the old and new names in this repo."
exit 0
