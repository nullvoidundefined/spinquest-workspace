#!/usr/bin/env bash
# Checks the root CLAUDE.md and every .claude/rules file (features/ included) with checkRules.mjs, after proving checkRules flags each problem kind on a broken fixture set.
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RULES="$WS/.claude/rules"
CHECKER="$WS/.claude/hooks/run/checkRules.mjs"
CLAUDE_MD="$WS/CLAUDE.md"
EXPECTED_RULES=(clients services backend spinquest-frontend mobile-app rips-frontend central-tech personal-docs)
EXPECTED_FEATURES=(feature-flags signup-and-onboarding first-time-user-experience lobby promotions-and-bonuses notifications payments)
failures=0

report() { # <PASS|FAIL> <label> [detail]
  printf '%s %s%s\n' "$1" "$2" "${3:+ ($3)}"
  [[ "$1" == FAIL ]] && failures=$((failures + 1))
  return 0
}

writeBrokenFixtures() { # <dir>
  local dir="$1"
  mkdir -p "$dir/features"
  printf '# No frontmatter\n\nDerived from PR reviews 2026-05-11 to 2026-11-11.\n' > "$dir/no-paths.md"
  printf -- '---\npaths:\n  - "no-such-repo/**"\n---\n\nDerived from PR reviews 2026-05-11 to 2026-11-11.\n' > "$dir/bad-glob.md"
  printf -- '---\npaths:\n  - "Backend/**"\n---\n\nNo provenance here \xe2\x80\x94 and an em dash.\n' > "$dir/no-provenance.md"
  { printf -- '---\npaths:\n  - "Backend/**"\n---\n\nDerived from PR reviews 2026-05-11 to 2026-11-11.\n'; head -c 4200 /dev/zero | tr '\0' 'x'; } > "$dir/too-large.md"
  printf -- '---\npaths:\n  - "Backend/**"\n---\n\n## Hard rules\n\nDerived from PR reviews 2026-05-11 to 2026-11-11.\n' > "$dir/backend.md"
  printf -- '---\npaths:\n  - "Backend/**"\n---\n\nDerived from PR reviews 2026-05-11 to 2026-11-11.\n' > "$dir/features/wrong-provenance.md"
  printf -- '---\npaths:\n  - "Backend/**"\n---\n\nDerived from PR reviews 2026-05-11 to 2027-03-02.\n' > "$dir/later-date.md"
  printf -- '---\npaths:\n  - "Backend/**"\n---\n\nDistilled on 2027-03-02 from personal-docs/x.\n' > "$dir/features/later-date.md"
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
    "MISSING_HEADING $dir/backend.md ## Verify ladder" "MISSING_HEADING $dir/backend.md ## Conventions (observed)" \
    "NO_PROVENANCE $dir/features/wrong-provenance.md"; do
    if awk -v e="$expected" 'index($0, e) == 1 { found = 1 } END { exit !found }' <<< "$output"; then report PASS "checker/flags: ${expected%% *}"
    else report FAIL "checker/flags" "missing line: $expected"; fi
  done
  if grep -qxF "MISSING_HEADING $dir/backend.md ## Hard rules" <<< "$output"; then report FAIL "checker/present-heading" "flagged a heading that exists"
  else report PASS "checker/present-heading-not-flagged"; fi
  if grep -qE '^NO_PROVENANCE .*/(features/)?later-date\.md' <<< "$output"; then report FAIL "checker/later-date-passes" "later dates flagged"
  else report PASS "checker/later-date-passes"; fi
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

checkFeatureRules() {
  local name file
  for name in "${EXPECTED_FEATURES[@]}"; do
    file="$RULES/features/$name.md"
    if [[ ! -f "$file" ]]; then report FAIL "features/exists" "$name.md missing"; continue; fi
    report PASS "features/exists: $name"
    grep -qxF '## Invariants' "$file" && report PASS "features/$name/invariants" || report FAIL "features/$name/invariants" "heading missing"
    grep -qxF '## Gotchas' "$file" && report PASS "features/$name/gotchas" || report FAIL "features/$name/gotchas" "heading missing"
  done
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
checkFeatureRules
checkRootClaudeMd
echo "failures: $failures"
(( failures == 0 ))
