#!/usr/bin/env bash
# PreToolUse guard: blocks reading or writing the four credential files, by file tool path, Grep/Glob path or pattern, or Bash command word. Comparisons are case-insensitive (APFS).
source "${BASH_SOURCE[0]%/*}/run/emit.sh"
requireDeps block credential-files-guard jq
PAYLOAD="$(cat)"
source "${BASH_SOURCE[0]%/*}/run/payload.sh"

credentialNames=(spinquest-service-account.json google-play-upload-key.json google-services.json GoogleService-Info.plist)

shopt -s nocasematch

blockCredential() { blockWith credential-files-guard "refusing to touch credential file: $1"; }

checkFilePath() {
  local filePath name
  filePath="$(readFilePath)"
  for name in "${credentialNames[@]}"; do
    [[ "${filePath##*/}" == "$name" ]] && blockCredential "$name"
  done
}

# Grep/Glob: the path basename, plus a file glob (Grep glob, Glob pattern) that names a credential file.
checkSearch() {
  local searchPath searchGlob name
  searchPath="$(jq -r '.tool_input.path // empty' <<<"$PAYLOAD")"
  if [[ "$(readToolName)" == Glob ]]; then
    searchGlob="$(jq -r '.tool_input.pattern // empty' <<<"$PAYLOAD")"
  else
    searchGlob="$(jq -r '.tool_input.glob // empty' <<<"$PAYLOAD")"
  fi
  for name in "${credentialNames[@]}"; do
    [[ "${searchPath##*/}" == "$name" ]] && blockCredential "$name"
    [[ "$searchGlob" == *"$name"* ]] && blockCredential "$name"
  done
}

checkCommand() {
  local command name escaped
  command="$(readCommand)"
  for name in "${credentialNames[@]}"; do
    escaped="${name//./\\.}"
    [[ "$command" =~ (^|[^A-Za-z0-9_.-])${escaped}($|[^A-Za-z0-9_-]) ]] && blockCredential "$name"
  done
}

case "$(readToolName)" in
  Read | Edit | Write | MultiEdit) checkFilePath ;;
  Grep | Glob) checkSearch ;;
  Bash) checkCommand ;;
esac
exit 0
