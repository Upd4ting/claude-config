---
name: create-pr
description: Commit current changes, push the branch, and open a pull request. Use when the user explicitly asks Codex to create or submit a PR.
---

1. Inspect the worktree, staged changes, branch, remote, and relevant diff.
2. Use `$committing` to create any required conventional commits.
3. Run the relevant verification for the changed scope.
4. Push the current branch only after the user's request authorizes it and required approval succeeds.
5. Create the pull request with the repository's PR template when present. Otherwise include a concise summary and a test plan; mark the test plan `N/A` only when no meaningful verification applies.
6. Return the PR URL and any verification caveats.

Never include secrets or unrelated local changes.
