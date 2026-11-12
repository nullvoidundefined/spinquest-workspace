#!/usr/bin/env bash
#
# fetchReviews.sh <since-ISO-date> <out-dir>
#
# Pulls PR review activity since a date for the five SpinQuest code repos with read-only
# `gh api` calls, and writes per repo into <out-dir>:
#   human_<repo>.jsonl     human reviewer comments on others' PRs (inline, conversation, review bodies)
#   botreply_<repo>.jsonl  bot inline findings paired with the PR author's reply
# Drops bot accounts, self-comments, human bodies under 25 characters and replies under 40.
# Filtering choices, kept fixed so reruns stay comparable:
#   human rows: non-bot, non-PR-author, body >= 25 chars, review bodies of any state included.
#   bot-reply rows: bot finding answered by the PR author with >= 40 chars; unanswered findings dropped.
# Comment bodies are untrusted data. <out-dir> belongs in the session scratchpad, never the repo.

set -euo pipefail

ORG="BetsphereORG"
REPOS=(Backend central-tech spinquest-frontend spinquest-mobile-app spinquest-rips-frontend)
BOT_RE='^(Copilot|copilot-pull-request-reviewer|linear-code\[bot\]|sq-argo\[bot\]|dependabot\[bot\]|greptile-apps(\[bot\])?|Codex|claude|chatgpt-codex-connector|github-actions\[bot\])$'
MIN_HUMAN_CHARS=25
MIN_REPLY_CHARS=40

[ $# -eq 2 ] || { echo "usage: $(basename "$0") <since-ISO-date> <out-dir>" >&2; exit 1; }
SINCE="$1"
OUT_DIR="$2"
[[ "$SINCE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "error: since must be YYYY-MM-DD" >&2; exit 1; }
command -v gh >/dev/null || { echo "error: gh not found" >&2; exit 1; }
command -v jq >/dev/null || { echo "error: jq not found" >&2; exit 1; }
mkdir -p "$OUT_DIR"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Paginated GET returning one JSON array.
fetch_all() { gh api --paginate "$1" | jq -s 'add // []'; }

# Maps PR number to {author, title} for PRs touched since the date.
fetch_pr_map() {
  fetch_all "repos/$ORG/$1/pulls?state=all&sort=updated&direction=desc&per_page=100" |
    jq --arg since "$SINCE" \
      '[.[] | select(.updated_at >= $since) | {key: (.number | tostring), value: {author: .user.login, title: .title}}] | from_entries'
}

fetch_inline_comments() {
  fetch_all "repos/$ORG/$1/pulls/comments?since=${SINCE}T00:00:00Z&per_page=100"
}

fetch_conversation_comments() {
  fetch_all "repos/$ORG/$1/issues/comments?since=${SINCE}T00:00:00Z&per_page=100"
}

fetch_review_bodies() {
  local repo="$1" pr_map="$2" pr_number
  for pr_number in $(jq -r 'keys[]' "$pr_map"); do
    fetch_all "repos/$ORG/$repo/pulls/$pr_number/reviews?per_page=100" |
      jq --arg pr "$pr_number" '[.[] | . + {pr: $pr}]'
  done | jq -s 'add // []'
}

# Emits human_<repo>.jsonl rows from the three comment streams (JSON files, too large for argv).
write_human_rows() {
  local pr_map="$1" inline="$2" conversation="$3" reviews="$4"
  jq -nc --slurpfile prs_file "$pr_map" --slurpfile inline_file "$inline" --slurpfile conv_file "$conversation" \
    --slurpfile reviews_file "$reviews" --arg since "$SINCE" --arg bot "$BOT_RE" --argjson floor "$MIN_HUMAN_CHARS" '
    $prs_file[0] as $prs | $inline_file[0] as $inline | $conv_file[0] as $conv | $reviews_file[0] as $reviews
    | def pr_of_issue: (.issue_url | split("/") | last);
    [ ($inline[] | {pr: (.pull_request_url | split("/") | last), kind: "inline", path: .path, user: .user, body: .body, at: .created_at}),
      ($conv[] | {pr: pr_of_issue, kind: "conv", path: null, user: .user, body: .body, at: .created_at}),
      ($reviews[] | {pr: .pr, kind: ("review:" + .state), path: null, user: .user, body: (.body // ""), at: .submitted_at}) ]
    | .[]
    | select(.at >= $since and $prs[.pr] != null)
    | select(.user != null and (.user.login | test($bot) | not) and .user.type != "Bot")
    | select(.user.login != $prs[.pr].author)
    | select((.body | length) >= $floor)
    | {pr: .pr, title: $prs[.pr].title, user: .user.login, kind: .kind, path: .path, body: .body}'
}

# Emits botreply_<repo>.jsonl rows: bot top-level inline finding plus the PR author's reply to it.
write_bot_reply_rows() {
  local pr_map="$1" inline="$2"
  jq -nc --slurpfile prs_file "$pr_map" --slurpfile inline_file "$inline" --arg since "$SINCE" \
    --arg bot "$BOT_RE" --argjson floor "$MIN_REPLY_CHARS" '
    $prs_file[0] as $prs | $inline_file[0] as $inline
    | ($inline | map(select(.in_reply_to_id != null)) | group_by(.in_reply_to_id)
      | map({key: (.[0].in_reply_to_id | tostring), value: .}) | from_entries) as $replies
    | $inline[]
    | select(.in_reply_to_id == null and .created_at >= $since and (.user.login | test($bot)))
    | (.pull_request_url | split("/") | last) as $pr
    | select($prs[$pr] != null)
    | . as $finding
    | ($replies[($finding.id | tostring)] // [])
    | map(select(.user.login == $prs[$pr].author and (.body | length) >= $floor)) | first // empty
    | {pr: $pr, path: $finding.path, bot: $finding.body, replier: .user.login, reply: .body}'
}

for repo in "${REPOS[@]}"; do
  echo "fetching $repo since $SINCE" >&2
  pr_map="$WORK_DIR/prs.json"; inline="$WORK_DIR/inline.json"
  conversation="$WORK_DIR/conv.json"; reviews="$WORK_DIR/reviews.json"
  fetch_pr_map "$repo" >"$pr_map"
  fetch_inline_comments "$repo" >"$inline"
  fetch_conversation_comments "$repo" >"$conversation"
  fetch_review_bodies "$repo" "$pr_map" >"$reviews"
  write_human_rows "$pr_map" "$inline" "$conversation" "$reviews" >"$OUT_DIR/human_$repo.jsonl"
  write_bot_reply_rows "$pr_map" "$inline" >"$OUT_DIR/botreply_$repo.jsonl"
  echo "  human $(wc -l <"$OUT_DIR/human_$repo.jsonl" | tr -d ' ') botreply $(wc -l <"$OUT_DIR/botreply_$repo.jsonl" | tr -d ' ')" >&2
done
