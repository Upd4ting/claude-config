---
name: create-branch
description: Create a Git branch with a conventional, descriptive name. Use when the user explicitly asks to create a branch for the current work.
---

Inspect the current branch, worktree, and task context. Create a kebab-case branch using the most accurate prefix:

- `feat/` for a new capability
- `fix/` for a bug fix
- `refactor/` for behavior-preserving restructuring
- `docs/` for documentation
- `test/` for test-only changes
- `chore/` for maintenance

Do not discard or overwrite worktree changes. Report the created branch name.
