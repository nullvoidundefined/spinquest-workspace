#!/usr/bin/env bash
# Checks the root CLAUDE.md and every .claude/rules file with checkRules.mjs, after proving checkRules flags each problem kind on a broken fixture set.
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RULES="$WS/.claude/rules"
CHECKER="$WS/.claude/hooks/run/checkRules.mjs"
CLAUDE_MD="$WS/CLAUDE.md"
EXPECTED_RULES=(clients services backend spinquest-frontend mobile-app rips-frontend central-tech personal-docs frontend-lexicon backend-lexicon)
failures=0
REVIEW_SOURCE='source: PR reviews 2026-05-11 to 2026-11-11'

report() { # <PASS|FAIL> <label> [detail]
  printf '%s %s%s\n' "$1" "$2" "${3:+ ($3)}"
  [[ "$1" == FAIL ]] && failures=$((failures + 1))
  return 0
}

writeBrokenFixtures() { # <dir>
  local dir="$1"
  mkdir -p "$dir/nested"
  printf '# No frontmatter\n' > "$dir/no-paths.md"
  printf -- '---\npaths:\n  - "no-such-repo/**"\n%s\n---\n' "$REVIEW_SOURCE" > "$dir/bad-glob.md"
  printf -- '---\npaths:\n  - "Backend/**"\n---\n\nNo provenance here \xe2\x80\x94 and an em dash.\n' > "$dir/no-provenance.md"
  { printf -- '---\npaths:\n  - "Backend/**"\n%s\n---\n' "$REVIEW_SOURCE"; head -c 4200 /dev/zero | tr '\0' 'x'; } > "$dir/too-large.md"
  printf -- '---\npaths:\n  - "Backend/**"\n%s\n---\n\n## Hard rules\n' "$REVIEW_SOURCE" > "$dir/backend.md"
  printf -- '---\npaths:\n  - "Backend/**"\n---\n' > "$dir/nested/no-source.md"
  printf -- '---\npaths:\n  - "Backend/**"\nsource: PR reviews 2026-05-11 to 2027-03-02\n---\n' > "$dir/later-date.md"
  printf -- '---\npaths:\n  - "Backend/**"\n%s\n---\n\n- Never X (aspirational).\n' "$REVIEW_SOURCE" > "$dir/meta-phrase.md"
  printf -- '---\npaths:\n  - "Backend/**"\n%s\n---\n\n- 37%% of files.\n' "$REVIEW_SOURCE" > "$dir/volatile-count.md"
  printf -- '---\npaths:\n  - "Backend/**"\n%s\n---\n' "$REVIEW_SOURCE" > "$dir/review-source-lexicon.md"
  printf -- '---\npaths:\n  - "Backend/**"\nsource: codebase naming survey 2026-11-12\n---\n' > "$dir/survey-lexicon.md"
}

checkCheckerCatchesProblems() {
  local dir output expected
  dir="$(mktemp -d)"
  writeBrokenFixtures "$dir"
  output="$(node "$CHECKER" "$dir" "$WS" 2>&1)"
  if [[ $? -eq 1 ]]; then report PASS "checker/exit-1-on-problems"
  else report FAIL "checker/exit-1-on-problems"; fi
  for expected in "NO_PATHS $dir/no-paths.md" "GLOB_NO_MATCH $dir/bad-glob.md no-such-repo/**" \
    "NO_PROVENANCE $dir/no-provenance.md" "EM_DASH $dir/no-provenance.md" "TOO_LARGE $dir/too-large.md " \
    "MISSING_HEADING $dir/backend.md ## Verify ladder" "MISSING_HEADING $dir/backend.md ## Conventions" \
    "META_PHRASE $dir/meta-phrase.md" "META_PHRASE $dir/volatile-count.md" \
    "NO_PROVENANCE $dir/nested/no-source.md" "NO_PROVENANCE $dir/review-source-lexicon.md"; do
    if awk -v e="$expected" 'index($0, e) == 1 { found = 1 } END { exit !found }' <<< "$output"; then report PASS "checker/flags: ${expected%% *}"
    else report FAIL "checker/flags" "missing line: $expected"; fi
  done
  if grep -qxF "MISSING_HEADING $dir/backend.md ## Hard rules" <<< "$output"; then report FAIL "checker/present-heading" "flagged a heading that exists"
  else report PASS "checker/present-heading-not-flagged"; fi
  if grep -qE '^NO_PROVENANCE .*/later-date\.md' <<< "$output"; then report FAIL "checker/later-date-passes" "later dates flagged"
  else report PASS "checker/later-date-passes"; fi
  if grep -qE '^NO_PROVENANCE .*/survey-lexicon\.md' <<< "$output"; then report FAIL "checker/survey-lexicon-passes" "survey source flagged"
  else report PASS "checker/survey-lexicon-passes"; fi
  rm -rf "$dir"
}

checkRulesFiles() {
  local name output
  for name in "${EXPECTED_RULES[@]}"; do
    [[ -f "$RULES/$name.md" ]] && report PASS "rules/exists: $name" || report FAIL "rules/exists" "$name.md missing"
  done
  output="$(node "$CHECKER" "$RULES" "$WS" 2>&1)"
  if [[ $? -eq 0 ]]; then report PASS "rules/checkRules-clean"
  else report FAIL "rules/checkRules-clean" "$(tr '\n' ';' <<< "$output")"; fi
}

checkRootClaudeMd() {
  local bytes n
  [[ -f "$CLAUDE_MD" ]] || { report FAIL "CLAUDE.md/exists"; return; }
  bytes="$(wc -c < "$CLAUDE_MD" | tr -d ' ')"
  (( bytes < 6144 )) && report PASS "CLAUDE.md/size ($bytes bytes)" || report FAIL "CLAUDE.md/size" "$bytes bytes"
  for n in $(seq 1 12); do grep -q "G$n\." "$CLAUDE_MD" || report FAIL "CLAUDE.md/G$n" "missing"; done
  for n in $(seq 1 5); do grep -q "CV$n\." "$CLAUDE_MD" || report FAIL "CLAUDE.md/CV$n" "missing"; done
  grep -q $'\xe2\x80\x94' "$CLAUDE_MD" && report FAIL "CLAUDE.md/em-dash" || report PASS "CLAUDE.md/no-em-dash"
}

checkCheckerCatchesProblems
checkRulesFiles
checkRootClaudeMd
echo "failures: $failures"
(( failures == 0 ))
