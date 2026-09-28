---
name: notion-review
description: >-
  Process the Notion tasks that teammates put in "Waiting Review": answer the GitHub issues
  they point to, review and merge their PRs, release npm packages when a batch warrants it,
  then update each task (Done only when its work is actually merged) and notify the assignee.
  Use when the user asks to "do the reviews", "review Alessandro's tasks", "traite les
  waiting review", or invokes $notion-review [names...].
---

# Notion Review

Clear the review queue that teammates leave in Notion. Each task links to GitHub issues
and/or PRs; the task says what the assignee expects from the maintainer (the user).

Three rules carry most of this skill's value:

- **Nothing public before the plan is approved** (§3). Collecting and reviewing is
  read-only; comments, merges, releases and Notion updates come after.
- **Done means merged.** A task goes to Done only when every PR it links is merged (and
  released, when a release was expected). Answering an issue never closes a task.
- **Always tell the assignee.** Every task you touch gets a Notion comment that mentions
  them, whatever its new status.

## Config

Adjust here if the workspace changes; nothing else in this skill hardcodes these.

| Key                    | Value                                                      |
| ---------------------- | ---------------------------------------------------------- |
| Tasks data source      | `collection://20f326d4-9ecb-8188-8e63-000b8cd8d8da`        |
| Review status          | `Waiting Review`                                           |
| Done status            | `Done` (also set `Completed on` to today)                  |
| Back-to-assignee status| `In Progress`                                              |
| Local clones           | `~/projects/<repo>` (clone there if missing)               |
| Release workflows      | `.github/workflows/release*.yml`, `workflow_dispatch`, input `channel=latest` |

If a status name above no longer exists in the data source schema, stop and ask.

## 1. Pick the people

People come from the arguments (`$notion-review alessandro marie`). Resolve each name with
the Notion users lookup; ask if a name matches several users.

With no argument, query the data source for tasks in the review status, count them per
assignee, and ask the user (multi-select) whom to review, showing the counts.

## 2. Collect (read-only)

1. Query the tasks: review status AND assignee in the selected users (SQL mode,
   `Assignee LIKE '%<user-id>%'` per user).
2. For each task, fetch the page and its comments with the Notion MCP tools
   (`include_all_blocks: true`). Extract:
   - every GitHub issue / PR URL, in the content and in comments;
   - the **expectation**: what the assignee asks of the maintainer. Teammates often write
     it under a heading such as "Attendu du mainteneur"; otherwise infer it from the text.
     The expectation wins over the link type (e.g. an issue whose expectation is "pick
     option A/B/C" needs a decision, not a generic answer).
3. Enrich every link with `gh`:
   - PR: `gh pr view <url> --json state,isDraft,mergeable,reviewDecision,statusCheckRollup,baseRefName,headRefName,title,body,closingIssuesReferences`
   - Issue: `gh issue view <url> --json state,title,body,comments,author`. If the last
     comment is from the user and answers the question, the issue is already handled.
4. Classify each link: `pr-open`, `pr-merged`, `pr-closed`, `issue-needs-answer`,
   `issue-answered`, `issue-closed`. A task with nothing actionable left (all merged /
   answered) goes straight to the Notion update step.

## 3. Plan — approval gate

Present one table per repo, in execution order:

| Task | Link | State | Planned action | Release? |
| ---- | ---- | ----- | -------------- | -------- |

Ordering rules:

- **Dependencies first.** An interface / library package is merged and released before
  the modules that consume it; a PR that another PR's description says it depends on goes
  first.
- **Release once per repo, after the last PR of the batch** on that repo. Never release in
  the middle of a batch.
- **Release only if it makes sense**: the repo publishes an npm package (`private` not
  true, a release workflow exists) and the batch contains user-facing changes
  (`feat`, `fix`, `perf`, or a breaking change). `docs` / `chore` / `test` / `ci` alone:
  no release. When the task explicitly asks for a release, follow it unless it is clearly
  wrong, and say why if you disagree.
- Monorepos with several release workflows (e.g. `release.yml` + `release-interface.yml`):
  pick by which package directories the batch touched; interface first.

Wait for explicit approval. The user may drop items or change actions; re-show the table
if the changes are substantial.

## 4. Execute

When native subagents are available and authorized, run PR reviews in parallel (one per PR,
read-only, each returning a verdict and findings); otherwise review them one by one. Everything that writes — comments, merges, releases — runs sequentially in plan
order.

### Issue that needs an answer

1. Read the issue, its comments and the relevant code in the local clone (pull first).
2. Draft the reply in English: answer the question, make the decision if one is asked
   (with the reason), or point to where to look. Short and actionable.
3. **Show the draft to the user**; post only after approval:
   `gh issue comment <url> --body-file <file>`.
4. Task → back-to-assignee status (unless it also has open PRs still in this run).

### Open PR

1. Check out the PR in the local clone (`gh pr checkout <n>`), after a clean `git status`.
   Do not touch uncommitted work: if the clone is dirty, use a temporary worktree.
2. Review with the `$code-review` skill: fixed point = `origin/<base>`, spec = the issues the
   PR closes / the task description. Add CI status and mergeability. If the repo lacks the
   docs that skill expects, run the same two axes (Standards, Spec) directly.
3. **Show the verdict to the user**: approve, or request changes with the concrete
   findings. Post only after approval.
   - Approve → `gh pr review <url> --approve`, then `gh pr merge <url>` with the merge
     method the repo allows (check `gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed`;
     prefer squash) and `--delete-branch`. Merges approved in the plan need no second
     confirmation. Never merge with failing CI or conflicts: report instead.
   - Changes needed → `gh pr review <url> --request-changes --body-file <file>` (English).
     Task → back-to-assignee status.
4. Return the clone to its default branch.

### Release

After the last PR of a repo's batch is merged, and only if the plan marked it:

1. **Confirm with the user** (repo, workflow, channel, commits since the last tag:
   `git log $(git describe --tags --abbrev=0)..origin/<default> --oneline`).
2. `gh workflow run <workflow> --repo <owner/repo> --ref <default> -f channel=latest`.
3. Watch it to completion (`gh run list --workflow <workflow> --limit 1`, then
   `gh run watch <id> --exit-status`). Report the published version from the run or the new
   tag. A failed release means the tasks depending on it are **not** Done.

## 5. Update Notion

For every task touched, decide the status from the final state of *all* its links:

| Final state of the task's links                                   | Status                 |
| ----------------------------------------------------------------- | ---------------------- |
| Every PR merged (+ release done when expected), no open question  | Done + `Completed on`  |
| Some issue answered, or some PR got "request changes"              | back-to-assignee       |
| Skipped, blocked (CI red, conflict, release failed), or undecided | unchanged              |

Then add a page-level Notion comment that mentions the assignee
(`<mention-user url="user://<id>"/>`) and lists what was done, with links: PRs merged,
released version, issue answered, changes requested (one line on what to fix). Write it in
the task's language. Comment even when the status is unchanged, explaining what blocks.

## 6. Report

End with a short summary per person: tasks moved to Done, sent back (and why), left
untouched (and why), releases published with versions. Include the Notion and GitHub links.
