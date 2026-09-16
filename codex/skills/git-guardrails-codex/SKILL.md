---
name: git-guardrails-codex
description: Set up Codex hooks to block dangerous git commands (push, reset --hard, clean, branch -D, etc.) before they execute. Use when the user wants preventative git safety hooks in Codex.
---

# Setup Git Guardrails

Sets up a Codex `PreToolUse` hook that intercepts and blocks dangerous git commands before Codex executes them.

## What Gets Blocked

- `git push` (all variants including `--force`)
- `git reset --hard`
- `git clean -f` / `git clean -fd`
- `git branch -D`
- `git checkout .` / `git restore .`

When blocked, Codex sees a message explaining that the command is outside its authority.

## Steps

### 1. Ask scope

Ask the user whether to install for **this project only** (`.codex/hooks.json`) or **all projects** (`~/.codex/hooks.json`).

### 2. Copy the hook script

The bundled script is at: [scripts/block-dangerous-git.sh](scripts/block-dangerous-git.sh)

Copy it to the target location based on scope:

- **Project**: `.codex/hooks/block-dangerous-git.sh`
- **Global**: `~/.codex/hooks/block-dangerous-git.sh`

Make it executable with `chmod +x`.

### 3. Add hook to settings

Add to the appropriate settings file:

**Project** (`.codex/hooks.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$(git rev-parse --show-toplevel)\"/.codex/hooks/block-dangerous-git.sh",
            "statusMessage": "Checking git command"
          }
        ]
      }
    ]
  }
}
```

**Global** (`~/.codex/hooks.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.codex/hooks/block-dangerous-git.sh",
            "statusMessage": "Checking git command"
          }
        ]
      }
    ]
  }
}
```

If the hooks file already exists, merge the entry into `hooks.PreToolUse`. Do not overwrite other hooks. Tell the user to review and trust the hook with `/hooks` after installation.

### 4. Ask about customization

Ask if user wants to add or remove any patterns from the blocked list. Edit the copied script accordingly.

### 5. Verify

Run a quick test:

```bash
echo '{"tool_input":{"command":"git push origin main"}}' | <path-to-script>
```

Should exit with code 2 and print a BLOCKED message to stderr.
