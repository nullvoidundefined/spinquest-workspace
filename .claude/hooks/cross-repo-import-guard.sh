#!/usr/bin/env bash
# PreToolUse guard: blocks relative imports in TS/JS files whose resolved path lands in a different repo root than the edited file.
source "${BASH_SOURCE[0]%/*}/run/emit.sh"
requireDeps block cross-repo-import-guard jq
PAYLOAD="$(cat)"
source "${BASH_SOURCE[0]%/*}/run/payload.sh"

case "$(readToolName)" in
  Edit | Write | MultiEdit) ;;
  *) exit 0 ;;
esac

filePath="$(readFilePath)"
[[ -z "$filePath" ]] && exit 0
case "$filePath" in
  *.ts | *.tsx | *.js | *.jsx | *.mjs | *.cjs) ;;
  *) exit 0 ;;
esac
fileRepo="$(resolveRepo "$filePath")"
fileDir="${filePath%/*}"

# Relative specifiers from `from '..'`, `import('..')`, `require('..')`.
specifierPattern="(from[[:space:]]*|import[[:space:]]*\\(|require[[:space:]]*\\()[[:space:]]*['\"](\\.[^'\"]*)['\"]"
remaining="$(readNewContent)"
while [[ "$remaining" =~ $specifierPattern ]]; do
  specifier="${BASH_REMATCH[2]}"
  remaining="${remaining#*"${BASH_REMATCH[0]}"}"
  resolvedPath="$(normalizePath "$fileDir/$specifier")"
  if [[ "$(resolveRepo "$resolvedPath")" != "$fileRepo" ]]; then
    blockWith cross-repo-import-guard "import '$specifier' crosses a repo root; share code through a published package, not a relative path"
  fi
done
exit 0
