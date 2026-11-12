#!/usr/bin/env bash
# PreToolUse guard: keeps spinquest-rips-frontend portable by confining fetch, env, session and DOM access to their allowed files.
source "${BASH_SOURCE[0]%/*}/run/emit.sh"
requireDeps block rips-boundary-guard jq
PAYLOAD="$(cat)"
source "${BASH_SOURCE[0]%/*}/run/payload.sh"

case "$(readToolName)" in
  Edit | Write | MultiEdit) ;;
  *) exit 0 ;;
esac

filePath="$(readFilePath)"
[[ "$(resolveRepo "$filePath")" == spinquest-rips-frontend ]] || exit 0
relPath="${filePath#*/spinquest-rips-frontend/}"
case "$relPath" in
  */__tests__/* | __tests__/* | *.test.*) exit 0 ;;
esac
newContent="$(readNewContent)"

# <rule description> <extended regex> <allowed path glob>...
enforceRule() {
  local description="$1" pattern="$2" allowedGlob
  shift 2
  grep -Eq -- "$pattern" <<<"$newContent" || return 0
  for allowedGlob in "$@"; do
    # shellcheck disable=SC2254
    case "$relPath" in $allowedGlob) return 0 ;; esac
  done
  blockWith rips-boundary-guard "$description not allowed in $relPath (RIPS portability boundary)"
}

enforceRule "fetch()" '(^|[^[:alnum:]_])fetch\(' \
  'packages/rips-core/*/api/client.ts' 'packages/rips-core/api/client.ts' \
  'src/features/auth/client.ts' 'src/features/debug/*'
enforceRule "import.meta.env" 'import\.meta\.env' 'src/config/env.ts'
enforceRule "import of @config/session" '@config/session' 'src/start.tsx' 'src/features/dev/*'
case "$relPath" in
  packages/rips-core/*)
    enforceRule "document/window/localStorage access" '(^|[^[:alnum:]_])(document|window|localStorage)\.' ;;
esac
exit 0
