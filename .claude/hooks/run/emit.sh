#!/usr/bin/env bash
# Sourced output helpers: advisory context JSON, blocking exit 2, and fail-closed dependency checks.

emitContext() { # <event> <text>
  jq -cn --arg event "$1" --arg text "$2" '{hookSpecificOutput:{hookEventName:$event,additionalContext:$text}}'
}

askWith() { # <guard> <reason>: forces a permission prompt in every permission mode
  jq -cn --arg reason "[$1] $2" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  exit 0
}

blockWith() { # <guard> <reason>
  printf '[%s] %s\n' "$1" "$2" >&2
  exit 2
}

requireDeps() { # <block|advise> <guard> <dep>...
  local mode="$1" guard="$2" dep
  shift 2
  for dep in "$@"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      [[ "$mode" == block ]] && blockWith "$guard" "guard unavailable: $dep"
      exit 0
    fi
  done
}
