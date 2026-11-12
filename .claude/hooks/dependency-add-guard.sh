#!/usr/bin/env bash
# PreToolUse guard: asks the user before any command that installs a named package (pnpm/npm/yarn/bun add or install <pkg>, expo install) or any package.json edit that adds a dependency name.
source "${BASH_SOURCE[0]%/*}/run/emit.sh"
requireDeps block dependency-add-guard jq
PAYLOAD="$(cat)"
source "${BASH_SOURCE[0]%/*}/run/payload.sh"

GUARD=dependency-add-guard
REASON='Adding a package needs administrator approval. Allow only if the user confirms that approval exists.'
VALUE_OPTIONS=' -C --dir --filter -F --prefix --cwd --workspace --registry '
VERSION_VALUE='"([@A-Za-z0-9._/-]+)"[[:space:]]*:[[:space:]]*"(\^|~|>|<|=|\*|[0-9]|workspace:|npm:|file:|link:|git|github:|https?:|latest|next)'

askUser() { # <detail>
  jq -cn --arg reason "[$GUARD] $REASON $1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  exit 0
}

listSegments() {
  sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g; s/(&&|\|\||;|\|)/\n/g" <<<"$1"
}

# Prints the first argument after the install subcommand that is not a flag, if any.
findPackageArgument() { # <tokens...>
  local manager="" subcommand="" token skipNext=0
  for token in "$@"; do
    if (( skipNext )); then skipNext=0; continue; fi
    if [[ -z "$manager" ]]; then
      [[ "$token" =~ ^(pnpm|npm|yarn|bun|npx|bunx)$ ]] && manager="$token"
      continue
    fi
    if [[ -z "$subcommand" ]]; then
      [[ "$VALUE_OPTIONS" == *" $token "* ]] && { skipNext=1; continue; }
      [[ "$token" == -* || "$token" == exec || "$token" == expo || "$token" == global ]] && continue
      [[ "$token" =~ ^(add|install|i|in|isntall)$ ]] || return 0
      subcommand="$token"
      continue
    fi
    [[ "$token" == -* ]] && continue
    printf '%s' "$token"
    return 0
  done
}

checkCommand() {
  local command segment tokens package
  command="$(readCommand)"
  [[ -z "$command" ]] && return 0
  while IFS= read -r segment; do
    read -ra tokens <<<"$segment"
    package="$(findPackageArgument "${tokens[@]}")"
    [[ -n "$package" ]] && askUser "Command installs: $package"
  done <<<"$(listSegments "$command")"
}

listExistingKeys() { # <file>
  [[ -f "$1" ]] || return 0
  jq -r '[paths(scalars, objects) | .[-1] | strings] | unique[]' "$1" 2>/dev/null
}

listAddedNames() { # <new content>
  grep -oE "$VERSION_VALUE" <<<"$1" | sed -E 's/^"([^"]+)".*/\1/' | sort -u
}

checkManifestEdit() {
  local filePath existingKeys name
  filePath="$(readFilePath)"
  [[ "$(basename "$filePath")" == package.json && "$filePath" != */node_modules/* ]] || return 0
  existingKeys="$(listExistingKeys "$filePath")"
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    grep -qxF "$name" <<<"$existingKeys" || askUser "package.json gains: $name"
  done <<<"$(listAddedNames "$(readNewContent)")"
}

case "$(readToolName)" in
  Bash) checkCommand ;;
  Edit|Write|MultiEdit) checkManifestEdit ;;
esac
exit 0
