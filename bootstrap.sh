#!/usr/bin/env bash
# Clones any missing SpinQuest repo into this workspace. Safe to re-run.
set -euo pipefail

cd "$(dirname "$0")"

ORG_URL="git@github.com:BetsphereORG"
REPOS=(
  Backend
  central-tech
  claude-skills
  spinquest-frontend
  spinquest-mobile-app
  spinquest-rips-frontend
)

for repo in "${REPOS[@]}"; do
  if [[ -d "$repo/.git" ]]; then
    echo "ok      $repo"
  else
    echo "clone   $repo"
    git clone "$ORG_URL/$repo.git" "$repo"
  fi
done

for repo in Backend spinquest-frontend; do
  if [[ ! -f "$repo/.env" ]]; then
    echo "missing $repo/.env (copy it from your other machine; see $repo/.env.example)"
  fi
done
