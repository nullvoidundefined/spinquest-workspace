#!/usr/bin/env bash
# Maps an absolute path to its workspace repo name (or empty); sourceable as resolveRepo or runnable as a script.

# Collapses "." and ".." segments of an absolute path in pure bash (no realpath -m on macOS).
normalizePath() {
  local segment out=() IFS=/
  for segment in $1; do
    case "$segment" in
      ''|.) ;;
      ..) [[ ${#out[@]} -gt 0 ]] && unset 'out[${#out[@]}-1]' ;;
      *) out+=("$segment") ;;
    esac
  done
  printf '/%s\n' "${out[*]}"
}

resolveRepo() {
  local ws repo target
  target="$(normalizePath "$1")"
  ws="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  for repo in Backend central-tech claude-skills spinquest-frontend spinquest-mobile-app spinquest-rips-frontend personal-docs; do
    case "$target" in
      "$ws/$repo"|"$ws/$repo"/*) printf '%s\n' "$repo"; return 0 ;;
    esac
  done
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then resolveRepo "${1:-}"; fi
