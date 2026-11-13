#!/usr/bin/env bash
# Sourced helpers that read fields from the Claude Code hook JSON held in $PAYLOAD (requires jq).

source "$(dirname "${BASH_SOURCE[0]}")/resolveRepo.sh"

readEventName() { jq -r '.hook_event_name // empty' <<<"$PAYLOAD"; }
readToolName() { jq -r '.tool_name // empty' <<<"$PAYLOAD"; }
readCommand() { jq -r '.tool_input.command // empty' <<<"$PAYLOAD"; }

# Absolute file path; relative paths resolve against .cwd.
readFilePath() {
  local filePath cwd
  filePath="$(jq -r '.tool_input.file_path // empty' <<<"$PAYLOAD")"
  [[ -z "$filePath" ]] && return 0
  if [[ "$filePath" == /* ]]; then
    normalizePath "$filePath"
  else
    cwd="$(jq -r '.cwd // empty' <<<"$PAYLOAD")"
    normalizePath "${cwd%/}/$filePath"
  fi
}

# New content only: Write content, Edit new_string, every MultiEdit edits[].new_string.
readNewContent() {
  jq -r '[.tool_input.content, .tool_input.new_string, (.tool_input.edits[]?.new_string)] | map(select(. != null)) | join("\n")' <<<"$PAYLOAD"
}

# Command text with quoted strings removed and segments split onto separate lines.
listSegments() {
  sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g; s/(&&|\|\||;|\|)/\n/g" <<<"$1"
}
