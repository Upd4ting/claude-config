---
name: commit
description: Commit current changes with a conventional commit message. Use when the user explicitly asks Codex to commit the work.
---

Inspect the worktree and staged changes, then use `$committing` to create the commit. Preserve unrelated user changes, verify the intended files, and do not push unless the user also asks for a push.
