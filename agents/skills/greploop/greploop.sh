#!/usr/bin/env bash
set -euo pipefail

# greploop.sh — Helper for the greploop skill.
# Subcommands for each mechanical step of the Greptile review loop.
# Requires: gh (authenticated), git, jq

POLL_INTERVAL=10
WAIT_TIMEOUT=600

# --- helpers ---

die() { echo "error: $*" >&2; exit 1; }
log() { echo "$*" >&2; }

require_tools() {
  for tool in gh git jq; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool is required but not found"
  done
}

detect_repo() {
  gh repo view --json owner,name -q '"\(.owner.login) \(.name)"' 2>/dev/null \
    || die "could not detect owner/repo — are you in a git repo with a GitHub remote?"
}

# --- subcommands ---

cmd_init() {
  local pr_number="${1:-}"
  local owner repo
  read -r owner repo <<< "$(detect_repo)"

  local json_query='{pr_number: .number, branch: .headRefName, head_sha: .headRefOid}'

  if [ -n "$pr_number" ]; then
    local pr_json
    pr_json=$(gh pr view "$pr_number" --json number,headRefName,headRefOid) \
      || die "could not find PR #$pr_number"
  else
    local pr_json
    pr_json=$(gh pr view --json number,headRefName,headRefOid 2>/dev/null) \
      || die "no PR found for the current branch"
  fi

  echo "$pr_json" | jq --arg owner "$owner" --arg repo "$repo" \
    '{owner: $owner, repo: $repo} + {pr_number: .number, branch: .headRefName, head_sha: .headRefOid}'
}

cmd_trigger() {
  local pr_number="${1:?usage: greploop.sh trigger <PR_NUMBER>}"
  local owner repo
  read -r owner repo <<< "$(detect_repo)"

  # Push latest changes
  local pushed=false
  if git push 2>&1 >&2; then
    pushed=true
  fi

  sleep 5

  # Check if Greptile is already running
  local greptile_state
  greptile_state=$(gh pr checks "$pr_number" --json name,state \
    | jq -r '[.[] | select(.name | test("greptile";"i"))] | first | .state // "NONE"') || greptile_state="NONE"

  local triggered=false
  if [ "$greptile_state" != "PENDING" ] && [ "$greptile_state" != "IN_PROGRESS" ]; then
    gh pr comment "$pr_number" --body "@greptile review" >/dev/null 2>&1
    triggered=true
    greptile_state="TRIGGERED"
  fi

  jq -n --argjson pushed "$pushed" --argjson triggered "$triggered" --arg state "$greptile_state" \
    '{pushed: $pushed, triggered: $triggered, greptile_state: $state}'
}

cmd_wait() {
  local pr_number="${1:?usage: greploop.sh wait <PR_NUMBER>}"
  local owner repo
  read -r owner repo <<< "$(detect_repo)"

  local head_sha
  head_sha=$(gh pr view "$pr_number" --json headRefOid -q .headRefOid)

  local elapsed=0
  while [ "$elapsed" -lt "$WAIT_TIMEOUT" ]; do
    local check_json
    check_json=$(gh api "repos/$owner/$repo/commits/$head_sha/check-runs" \
      --jq '[.check_runs[] | select(.name | test("greptile";"i"))] | first // empty' 2>/dev/null) || true

    if [ -z "$check_json" ]; then
      log "Waiting for Greptile check to appear... (${elapsed}s)"
      sleep "$POLL_INTERVAL"
      elapsed=$((elapsed + POLL_INTERVAL))
      continue
    fi

    local status conclusion
    status=$(echo "$check_json" | jq -r '.status // "queued"')
    conclusion=$(echo "$check_json" | jq -r '.conclusion // "pending"')

    if [ "$status" = "completed" ]; then
      jq -n --arg status "$status" --arg conclusion "$conclusion" --arg sha "$head_sha" \
        '{status: $status, conclusion: $conclusion, head_sha: $sha}'
      return 0
    fi

    log "Waiting for Greptile... (status: $status, ${elapsed}s)"
    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
  done

  die "timed out after ${WAIT_TIMEOUT}s waiting for Greptile check"
}

cmd_fetch_score() {
  local pr_number="${1:?usage: greploop.sh fetch-score <PR_NUMBER>}"
  local owner repo
  read -r owner repo <<< "$(detect_repo)"

  local score=-1
  local source="none"

  # Check PR reviews from greptile bot (most authoritative)
  local reviews
  reviews=$(gh api "repos/$owner/$repo/pulls/$pr_number/reviews" 2>/dev/null) || reviews="[]"

  local review_score
  review_score=$(echo "$reviews" \
    | jq -r '[.[] | select(.user.login | test("greptile";"i"))] | last | .body // ""' \
    | grep -oP '\d+/5' | tail -1 | cut -d/ -f1) || true

  if [ -n "$review_score" ]; then
    score=$review_score
    source="review"
  fi

  # Fall back to PR body
  if [ "$score" -eq -1 ]; then
    local body_score
    body_score=$(gh pr view "$pr_number" --json body -q .body \
      | grep -oP '\d+/5' | tail -1 | cut -d/ -f1) || true

    if [ -n "$body_score" ]; then
      score=$body_score
      source="body"
    fi
  fi

  jq -n --argjson score "$score" --arg source "$source" \
    '{score: $score, max_score: 5, source: $source}'
}

cmd_fetch_comments() {
  local pr_number="${1:?usage: greploop.sh fetch-comments <PR_NUMBER>}"
  local owner repo
  read -r owner repo <<< "$(detect_repo)"

  local cursor=""
  local all_comments="[]"

  while true; do
    local cursor_arg=""
    if [ -n "$cursor" ]; then
      cursor_arg=", after: \"$cursor\""
    fi

    local result
    result=$(gh api graphql -f query="
      query {
        repository(owner: \"$owner\", name: \"$repo\") {
          pullRequest(number: $pr_number) {
            reviewThreads(first: 100${cursor_arg}) {
              pageInfo { hasNextPage endCursor }
              nodes {
                id
                isResolved
                comments(first: 1) {
                  nodes {
                    body
                    path
                    author { login }
                  }
                }
                line
                diffSide
              }
            }
          }
        }
      }
    ") || die "GraphQL query failed"

    local page_comments
    page_comments=$(echo "$result" | jq '[
      .data.repository.pullRequest.reviewThreads.nodes[]
      | select(.isResolved == false)
      | select(.comments.nodes[0].author.login | test("greptile";"i"))
      | {
          thread_id: .id,
          path: .comments.nodes[0].path,
          line: .line,
          body: .comments.nodes[0].body,
          author: .comments.nodes[0].author.login
        }
    ]')

    all_comments=$(jq -s '.[0] + .[1]' <(echo "$all_comments") <(echo "$page_comments"))

    local has_next
    has_next=$(echo "$result" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')

    if [ "$has_next" = "true" ]; then
      cursor=$(echo "$result" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor')
    else
      break
    fi
  done

  echo "$all_comments"
}

cmd_reply() {
  local pr_number="${1:?usage: greploop.sh reply <PR_NUMBER> <THREAD_ID> <MESSAGE>}"
  local thread_id="${2:?usage: greploop.sh reply <PR_NUMBER> <THREAD_ID> <MESSAGE>}"
  local message="${3:?usage: greploop.sh reply <PR_NUMBER> <THREAD_ID> <MESSAGE>}"

  local result
  result=$(gh api graphql -f query="
    mutation(\$threadId: ID!, \$body: String!) {
      addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: \$threadId, body: \$body}) {
        comment { id }
      }
    }
  " -f threadId="$thread_id" -f body="$message") || die "failed to reply to thread $thread_id"

  local comment_id
  comment_id=$(echo "$result" | jq -r '.data.addPullRequestReviewThreadReply.comment.id')

  jq -n --arg thread_id "$thread_id" --arg comment_id "$comment_id" \
    '{thread_id: $thread_id, comment_id: $comment_id}'
}

cmd_resolve() {
  local pr_number="${1:?usage: greploop.sh resolve <PR_NUMBER>}"
  local owner repo
  read -r owner repo <<< "$(detect_repo)"

  # Get unresolved greptile thread IDs
  local threads_json
  threads_json=$(cmd_fetch_comments "$pr_number")

  local thread_ids
  thread_ids=$(echo "$threads_json" | jq -r '.[].thread_id')

  if [ -z "$thread_ids" ]; then
    jq -n '{resolved_count: 0, thread_ids: []}'
    return 0
  fi

  local resolved_ids="[]"
  local batch=""
  local count=0
  local batch_num=0

  while IFS= read -r tid; do
    [ -z "$tid" ] && continue
    count=$((count + 1))
    batch="${batch}  t${count}: resolveReviewThread(input: {threadId: \"$tid\"}) { thread { isResolved } }"$'\n'
    resolved_ids=$(echo "$resolved_ids" | jq --arg id "$tid" '. + [$id]')

    if [ "$count" -ge 20 ]; then
      gh api graphql -f query="mutation {
$batch}" >/dev/null 2>&1 || log "warning: batch resolve failed"
      batch=""
      count=0
      batch_num=$((batch_num + 1))
    fi
  done <<< "$thread_ids"

  # Flush remaining batch
  if [ -n "$batch" ]; then
    gh api graphql -f query="mutation {
$batch}" >/dev/null 2>&1 || log "warning: batch resolve failed"
  fi

  local total
  total=$(echo "$resolved_ids" | jq 'length')

  jq -n --argjson count "$total" --argjson ids "$resolved_ids" \
    '{resolved_count: $count, thread_ids: $ids}'
}

usage() {
  cat >&2 <<'EOF'
Usage: greploop.sh <command> [args]

Commands:
  init [PR_NUMBER]         Detect PR context from current branch
  trigger <PR_NUMBER>      Push and trigger Greptile review
  wait <PR_NUMBER>         Poll until Greptile check completes
  fetch-score <PR_NUMBER>  Extract latest confidence score
  fetch-comments <PR_NUMBER>  List unresolved Greptile comments
  reply <PR_NUMBER> <THREAD_ID> <MESSAGE>  Reply to a review thread
  resolve <PR_NUMBER>      Resolve all Greptile review threads

Requires: gh (authenticated), git, jq
EOF
}

# --- main ---

require_tools

case "${1:-}" in
  init)           cmd_init "${@:2}" ;;
  trigger)        cmd_trigger "${@:2}" ;;
  wait)           cmd_wait "${@:2}" ;;
  fetch-score)    cmd_fetch_score "${@:2}" ;;
  fetch-comments) cmd_fetch_comments "${@:2}" ;;
  reply)          cmd_reply "${@:2}" ;;
  resolve)        cmd_resolve "${@:2}" ;;
  -h|--help)      usage ;;
  *)              usage; exit 1 ;;
esac
