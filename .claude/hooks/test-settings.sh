#!/usr/bin/env bash
# Asserts .claude/settings.json is valid JSON, every hook command resolves to an
# executable, every hook script is wired, and the ask-permissions and credential guard registration are present.
WS="${BASH_SOURCE[0]%/*}/../.."
WS="$(cd "$WS" && pwd)"
SETTINGS="$WS/.claude/settings.json"
failures=0
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }

jq empty "$SETTINGS" 2>/dev/null || { fail "settings.json missing or invalid JSON"; exit 1; }

commands="$(jq -r '.hooks // {} | .[][] | .hooks[].command' "$SETTINGS")"

while IFS= read -r command; do
  [ -z "$command" ] && continue
  resolved="${command//\$CLAUDE_PROJECT_DIR/$WS}"
  resolved="${resolved//\"/}"
  [ -x "$resolved" ] || fail "hook command not executable: $command"
done <<< "$commands"

for script in "$WS"/.claude/hooks/*.sh; do
  name="${script##*/}"
  case "$name" in test-*) continue ;; esac
  grep -qF "/.claude/hooks/$name" <<< "$commands" || fail "hook script not wired: $name"
done

for rule in 'Bash(eas update:*)' 'Bash(eas submit:*)' 'Bash(eas build:*)' 'Bash(fastlane:*)' \
  'Bash(gh workflow run:*)' 'Bash(kubectl:*)' 'Bash(argocd:*)' 'Bash(helm:*)' \
  'Bash(pnpm db:migrate:*)' 'Bash(pnpm db:revert:*)' \
  'Bash(pnpm update:*)' 'Bash(pnpm submit:*)' 'Bash(pnpm release:*)' 'Bash(pnpm build:prod:*)' 'Bash(pnpm build:staging:*)' 'Bash(pnpm build:preview:*)' 'Bash(pnpm build:testflight:*)' 'Bash(pnpm rebuild:*)' 'Bash(pnpm fastlane:*)' 'Bash(bundle exec fastlane:*)' 'Bash(npx eas:*)' 'Bash(pnpm exec eas:*)' 'Bash(pnpm typeorm migration:*)'; do
  jq -e --arg rule "$rule" '.permissions.ask // [] | index($rule)' "$SETTINGS" >/dev/null || fail "missing ask rule: $rule"
done

jq -e '.hooks.PreToolUse[] | select(.hooks[].command | test("credential-files-guard")) | .matcher
  | select(test("Read") and test("Grep") and test("Bash"))' "$SETTINGS" >/dev/null || fail "credential guard not registered under PreToolUse with Read, Grep and Bash matcher"

[ "$failures" -eq 0 ] && echo "settings OK" && exit 0
exit 1
