#!/usr/bin/env bash
# PreToolUse guard: flags client code that sends userId; blocks in spinquest-rips-frontend, reminds in the other client repos.
source "${BASH_SOURCE[0]%/*}/run/emit.sh"
requireDeps block client-identity-guard jq
PAYLOAD="$(cat)"
source "${BASH_SOURCE[0]%/*}/run/payload.sh"

case "$(readToolName)" in
  Edit | Write | MultiEdit) ;;
  *) exit 0 ;;
esac

reminder="Client identity: identity comes from the token on the server; do not send userId from a client (workspace invariant 3)."
filePath="$(readFilePath)"
repo="$(resolveRepo "$filePath")"
case "$repo" in
  spinquest-rips-frontend | spinquest-frontend | spinquest-mobile-app) ;;
  *) exit 0 ;;
esac
case "$filePath" in
  */__tests__/* | *.test.* | *.spec.*) exit 0 ;;
esac
case "$filePath" in
  */api/* | */services/* | */clients/*) ;;
  *) exit 0 ;;
esac

grep -Eq '(^|[^[:alnum:]_])userId[[:space:]]*[:,}]|[?&]userId=' <<<"$(readNewContent)" || exit 0
if [[ "$repo" == spinquest-rips-frontend ]]; then
  blockWith client-identity-guard "$reminder"
fi
emitContext PreToolUse "$reminder"
exit 0
