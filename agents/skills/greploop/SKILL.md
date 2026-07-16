---
name: greploop
description: >
  Iteratively improves a GitHub PR until Greptile gives 5/5 confidence with zero
  unresolved comments. Uses greploop.sh for mechanical steps (trigger, wait, fetch,
  resolve, reply) and Claude for fixing comments.
compatibility: Requires git, gh (GitHub CLI) authenticated, jq, and Greptile installed on the repo.
allowed-tools: Bash(gh:*) Bash(git:*) Bash(bash:*)
---

# Greploop

Iteratively fix a GitHub PR until Greptile gives a perfect review: 5/5 confidence, zero unresolved comments.

Uses the helper script `greploop.sh` (located alongside this skill file) for each mechanical step. The script outputs JSON to stdout.

## Inputs

- **PR number** (optional): If not provided, detect the PR for the current branch.

## Instructions

### 0. Locate the helper script

The helper script is at the same path as this skill file:

```bash
GREPLOOP="$(dirname "SKILL_FILE_PATH")/greploop.sh"
```

Replace `SKILL_FILE_PATH` with the absolute path to this SKILL.md file. Use `bash "$GREPLOOP" <command> [args]` for all greploop commands below.

### 1. Initialize

```bash
bash "$GREPLOOP" init [PR_NUMBER]
```

Returns JSON with `owner`, `repo`, `pr_number`, `branch`, `head_sha`. Store `pr_number` for subsequent commands.

Switch to the PR branch if not already on it.

### 2. Loop

Repeat the following cycle. **Max 5 iterations** to avoid runaway loops.

#### A. Trigger Greptile review

```bash
bash "$GREPLOOP" trigger $PR_NUMBER
```

Pushes the current branch and posts `@greptile review` if Greptile is not already running. Returns `{pushed, triggered, greptile_state}`.

#### B. Wait for Greptile check

```bash
bash "$GREPLOOP" wait $PR_NUMBER
```

Polls every 10 seconds (up to 10 minutes) until the Greptile check run completes. Returns `{status, conclusion, head_sha}`.

#### C. Fetch confidence score

```bash
bash "$GREPLOOP" fetch-score $PR_NUMBER
```

Returns `{score, max_score, source}`. The score comes from PR reviews (preferred) or PR body (fallback). A score of `-1` means no score was found.

#### D. Fetch unresolved comments

```bash
bash "$GREPLOOP" fetch-comments $PR_NUMBER
```

Returns a JSON array of unresolved Greptile inline comments:

```json
[
  {
    "thread_id": "...",
    "path": "src/auth.ts",
    "line": 45,
    "body": "Consider rate limiting this endpoint",
    "author": "greptile-apps[bot]"
  }
]
```

#### E. Check exit conditions

Stop the loop if **any** of these are true:

- Confidence score is **5/5** AND the comments array is **empty** → SUCCESS
- Max iterations reached → report current state

#### F. Fix actionable comments

For each unresolved Greptile comment:

1. Read the file at `path` around `line` and understand the comment in context.
2. Determine if it's actionable (code change needed) or informational.
3. If actionable, make the fix.
4. If informational or a false positive, draft a short reply explaining why no change is needed (e.g., "This is intentional because…", "Already handled by…"). Keep track of each `thread_id` and its drafted reply for step F2.

#### F2. Check for changes and get user approval

After processing all comments, check whether any code was actually modified:

```bash
git diff
```

**Present a review to the user** covering both aspects:

- **Code changes** (if any): list each comment that was addressed and what was changed.
- **Drafted replies** (if any): for each informational/false-positive comment, show the thread (file, line, Greptile's comment) and the proposed reply text. Note that replies will be posted under the user's GitHub account.

The user can:
- Approve everything as-is.
- Edit reply wording or request code change modifications.
- Skip individual replies (thread will be resolved silently without a reply).

After the user requests any modifications, **go back to the top of step F2** (re-check `git diff`). This ensures that if edits result in no remaining changes, the correct path is taken.

Once approved:

1. **Post approved replies** for each thread that has an approved reply:

    ```bash
    bash "$GREPLOOP" reply $PR_NUMBER <THREAD_ID> "<APPROVED_MESSAGE>"
    ```

2. Proceed to step G (resolve threads).

**If no code changes exist after approval:**
- After posting replies and resolving threads, **exit the loop** — do not commit or re-trigger Greptile.
- Note in the final report that all comments were resolved as informational.

**If code changes exist after approval:**
- Continue to step G → H (resolve, commit, push, re-trigger).

#### G. Resolve threads

```bash
bash "$GREPLOOP" resolve $PR_NUMBER
```

Batch-resolves all unresolved Greptile review threads via GraphQL. Returns `{resolved_count, thread_ids}`.

#### H. Commit and push

**Only execute this step if code changes were approved in step F2.**

```bash
git add -A
git commit -m "address greptile review feedback (greploop iteration N)"
git push
```

Wait briefly for checks to start:

```bash
sleep 5
```

Then go back to step **A**.

### 3. Report

After exiting the loop, summarize:

| Field              | Value   |
| ------------------ | ------- |
| Platform           | GitHub  |
| Iterations         | N       |
| Final confidence   | X/5     |
| Comments resolved  | N       |
| Remaining comments | N       |

## Output format

```
Greploop complete.
  Platform:      GitHub
  Iterations:    2
  Confidence:    5/5
  Resolved:      7 comments
  Remaining:     0
```

If not fully resolved:

```
Greploop stopped after 5 iterations.
  Confidence:    4/5
  Resolved:      12 comments
  Remaining:     2

Remaining issues:
  - src/auth.ts:45 — "Consider rate limiting this endpoint"
  - src/db.ts:112 — "Missing index on user_id column"
```
