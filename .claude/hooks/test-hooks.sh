#!/usr/bin/env bash
# Fixture runner: replays hook payload fixtures against hook scripts and checks exit code, stderr and stdout per case prefix (block, pass, warn, ask) (optional <case>.expect lists substrings stdout must contain).
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOKS="$WS/.claude/hooks"
FIXTURES="$HOOKS/fixtures"
failures=0

report() { # <PASS|FAIL> <label> [detail]
  printf '%s %s%s\n' "$1" "$2" "${3:+ ($3)}"
  [[ "$1" == FAIL ]] && failures=$((failures + 1))
}

checkResolveRepo() {
  if ( set -e; source "$HOOKS/run/resolveRepo.sh" ); then report PASS "resolveRepo/source-status"
  else report FAIL "resolveRepo/source-status" "sourcing returned non-zero"; fi
  local cases="$FIXTURES/resolveRepo/cases.tsv" n=0 path expected actual
  while IFS=$'\t' read -r path expected || [[ -n "$path" ]]; do
    n=$((n + 1))
    path="${path//__WS__/$WS}"
    actual="$(bash "$HOOKS/run/resolveRepo.sh" "$path" 2>/dev/null)"
    if [[ "$actual" == "$expected" ]]; then report PASS "resolveRepo/$n"
    else report FAIL "resolveRepo/$n" "path=$path expected='$expected' got='$actual'"; fi
  done < "$cases"
}

runFixture() { # <hook> <fixture json>
  local hook="$1" file="$2" case stdout stderr code verdict
  case="$(basename "$file" .json)"
  local envFile="${file%.json}.env" errFile; errFile="$(mktemp)"
  local payload; payload="$(<"$file")"; payload="${payload//__WS__/$WS}"
  stdout="$(
    cd "$WS/Backend" || exit 99
    [[ -f "$envFile" ]] && source "$envFile"
    printf '%s' "$payload" | /bin/bash "$HOOKS/$hook.sh" 2>"$errFile"
  )"
  code=$?
  stderr="$(cat "$errFile")"; rm -f "$errFile"
  case "$case" in
    block-*) [[ $code -eq 2 && -n "$stderr" ]] && verdict=PASS || verdict=FAIL ;;
    pass-*)  [[ $code -eq 0 && -z "$stdout" ]] && verdict=PASS || verdict=FAIL ;;
    warn-*)  [[ $code -eq 0 && "$stdout" == *additionalContext* ]] && verdict=PASS || verdict=FAIL ;;
    ask-*)   [[ $code -eq 0 && "$stdout" == *'"permissionDecision":"ask"'* ]] && verdict=PASS || verdict=FAIL ;;
    *) verdict=FAIL ;;
  esac
  local expectFile="${file%.json}.expect" expected
  if [[ -f "$expectFile" ]]; then
    while IFS= read -r expected || [[ -n "$expected" ]]; do
      [[ -z "$expected" || "$stdout" == *"$expected"* ]] || { verdict=FAIL; report FAIL "$hook/$case" "stdout missing '$expected'"; return; }
    done < "$expectFile"
  fi
  report "$verdict" "$hook/$case" "exit=$code"
}

for dir in "$FIXTURES"/*/; do
  hook="$(basename "$dir")"
  if [[ "$hook" == resolveRepo ]]; then checkResolveRepo; continue; fi
  for file in "$dir"*.json; do
    [[ -e "$file" ]] && runFixture "$hook" "$file"
  done
done

[[ $failures -eq 0 ]]
