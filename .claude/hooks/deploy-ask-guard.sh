#!/usr/bin/env bash
# PreToolUse guard: forces a permission prompt, in every permission mode, before Bash segments that deploy, submit, push an OTA update or run a migration.
source "${BASH_SOURCE[0]%/*}/run/emit.sh"
requireDeps block deploy-ask-guard jq
PAYLOAD="$(cat)"
source "${BASH_SOURCE[0]%/*}/run/payload.sh"

GUARD=deploy-ask-guard
envPrefix='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
runnerPrefix="${envPrefix}(pnpm|npm|yarn)([[:space:]]+(run|-w|(-C|--dir|--filter|--prefix)[[:space:]]+[^[:space:]]+))*[[:space:]]+"
gatedScript='(update|submit|release|rebuild):[a-z:]+|build:(dev|staging|preview|prod|testflight)[a-z:]*|fastlane:(beta|upload)|db:(migrate|revert)'
easRemote="${envPrefix}((npx|yarn|pnpm[[:space:]]+(exec|dlx))[[:space:]]+)?eas[[:space:]]+(update|submit|build)([[:space:]]|\$)"
fastlaneRun="${envPrefix}(bundle[[:space:]]+exec[[:space:]]+)?fastlane([[:space:]]|\$)"
typeormMigration='typeorm[^[:space:]]*[[:space:]]+migration:(run|revert)'

isGatedSegment() { # <segment>
  [[ "$1" =~ ${runnerPrefix}(${gatedScript})([[:space:]]|$) ]] && return 0
  [[ "$1" =~ $easRemote && ! "$1" =~ (^|[[:space:]])--local([[:space:]]|$) ]] && return 0
  [[ "$1" =~ $fastlaneRun || "$1" =~ $typeormMigration ]]
}

command="$(readCommand)"
[[ -z "$command" ]] && exit 0
while IFS= read -r segment; do
  isGatedSegment "$segment" && askWith "$GUARD" "Deploys, submits, pushes an OTA update or runs a migration: ${segment#"${segment%%[![:space:]]*}"}"
done <<<"$(listSegments "$command")"
exit 0
