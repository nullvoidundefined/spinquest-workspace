#!/usr/bin/env bash
# PostToolUse advisory: checks edited files against team review norms and relays every hit as one additionalContext message.
HOOKS="${BASH_SOURCE[0]%/*}"
WS="$(cd "$HOOKS/../.." && pwd)"
source "$HOOKS/run/payload.sh"
source "$HOOKS/run/emit.sh"
requireDeps advise review-norms-check jq

PAYLOAD="$(cat)"
filePath="$(readFilePath)"
[[ -n "$filePath" ]] || exit 0
repo="$(resolveRepo "$filePath")"
[[ -n "$repo" ]] || exit 0
toolName="$(readToolName)"
newContent="$(readNewContent)"
relPath="${filePath#"$WS/$repo"/}"

# Repo-relative files changed in the working tree or index; REVIEW_NORMS_DIFF_FILES (newline or space separated) overrides git.
listChangedFiles() {
  if [[ -n "${REVIEW_NORMS_DIFF_FILES+x}" ]]; then
    tr -s ' \n' '\n\n' <<<"$REVIEW_NORMS_DIFF_FILES"
    return 0
  fi
  git -C "$WS/$repo" diff --name-only 2>/dev/null
  git -C "$WS/$repo" diff --name-only --cached 2>/dev/null
}

isMigrationPath() { [[ "$repo" == Backend && "$relPath" == src/db/migration/* ]]; }

checkMigrationName() {
  isMigrationPath || return 0
  [[ "${relPath##*/}" =~ ^[0-9]+-[a-z0-9-]+\.ts$ ]] || echo "Backend migration filename must be <timestamp>-kebab-case.ts"
}

checkMigrationDown() {
  isMigrationPath || return 0
  [[ "$toolName" == Write ]] || return 0
  [[ "$newContent" == *"async down("* ]] || echo "Backend migration must define async down() so it can be reverted"
}

checkReqUrl() {
  [[ "$repo" == Backend && "$relPath" == *middleware* ]] || return 0
  grep -qE 'req\.url' <<<"$newContent" && echo "Backend middleware: req.url is unreliable behind routers; use req.path"
}

checkFetchSignal() {
  [[ "$repo" == Backend || "$repo" == central-tech ]] || return 0
  grep -qE 'fetch\(' <<<"$newContent" || return 0
  grep -q 'signal' <<<"$newContent" || echo "$repo: outbound fetch() needs a timeout signal (AbortSignal.timeout)"
}

checkViteEnvWiring() {
  [[ "$repo" == spinquest-frontend ]] || return 0
  grep -qE 'VITE_APP_[A-Z_]+' <<<"$newContent" || return 0
  listChangedFiles | grep -qx 'Dockerfile' || echo "frontend: new VITE_APP_* variable but Dockerfile has no matching build arg change"
}

checkLocaleParity() {
  [[ "$repo" == spinquest-frontend && "$relPath" == public/locales/en.json ]] || return 0
  local changed locale missing=()
  changed="$(listChangedFiles)"
  for locale in "$WS/$repo"/public/locales/*.json; do
    [[ "${locale##*/}" == en.json ]] && continue
    grep -qx "public/locales/${locale##*/}" <<<"$changed" || missing+=("${locale##*/}")
  done
  [[ ${#missing[@]} -eq 0 ]] || echo "frontend: en.json edited but locales not updated: ${missing[*]}"
}

checkNativeStyling() {
  [[ "$repo" == spinquest-mobile-app ]] || return 0
  grep -qE "StyleSheet\.create|#[0-9a-fA-F]{6}\b|import \{ Text \} from ['\"]react-native['\"]" <<<"$newContent" \
    && echo "mobile: StyleSheet.create, hex colour literal or raw RN Text; use theme tokens and shared Text (new code only)"
}

checkNumberEnv() {
  [[ "$repo" == central-tech ]] || return 0
  grep -q 'Number(process\.env' <<<"$newContent" && echo "central-tech: Number(process.env.X) yields NaN silently; parse and validate env numbers in config"
}

checkVerifiedHeader() {
  [[ "$repo" == central-tech && "$filePath" == *.md ]] || return 0
  [[ -f "$filePath" ]] || return 0
  local headerPattern='[Vv]erified( on)? [0-9]{4}-[0-9]{2}-[0-9]{2}'
  head -n 30 "$filePath" | grep -qE "$headerPattern" || return 0
  grep -qE "$headerPattern" <<<"$newContent" || echo "central-tech: doc carries a 'Verified <date>' header; re-verify and update it when changing claims"
}

hits=""
for check in checkMigrationName checkMigrationDown checkReqUrl checkFetchSignal checkViteEnvWiring checkLocaleParity checkNativeStyling checkNumberEnv checkVerifiedHeader; do
  line="$($check)"
  [[ -n "$line" ]] && hits+="${hits:+$'\n'}- $line"
done
[[ -n "$hits" ]] || exit 0
emitContext PostToolUse "Review norms (advisory):"$'\n'"$hits"
exit 0
