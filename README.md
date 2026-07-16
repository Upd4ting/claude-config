# claude-config

Portable backup of my entire Claude Code configuration, installable on any
machine with a single script. Live config files are **symlinked** to this
repo, so every change made through Claude Code (settings, skills, commands)
is tracked by git — commit and push to sync, pull and re-run `install.sh`
on the other machine.

## What is tracked

| Repo path                    | Live location            | Content                                    |
| ---------------------------- | ------------------------ | ------------------------------------------ |
| `claude/CLAUDE.md`           | `~/.claude/CLAUDE.md`    | Global user instructions                   |
| `claude/settings.json`       | `~/.claude/settings.json`| Permissions, model, hooks, language, etc.  |
| `claude/commands/`           | `~/.claude/commands/`    | Custom slash commands                      |
| `claude/skills-enabled.txt`  | `~/.claude/skills/*`     | Which skills are enabled in Claude Code    |
| `agents/skills/`             | `~/.agents/skills/`      | The full skills library                    |
| `agents/.skill-lock.json`    | `~/.agents/.skill-lock.json` | Skill provenance lock file             |
| `plugins/plugins.txt`        | (via `claude plugin`)    | Plugins to reinstall                       |

Deliberately **not** tracked: `~/.claude/.credentials.json` (secrets),
`settings.local.json` (machine-specific), MCP servers (machine-specific
paths, re-add with `claude mcp add` if needed), sessions/history/caches.

## Setup on a new machine

```sh
git clone <this-repo> ~/code/personnal/claude-config
cd ~/code/personnal/claude-config
./install.sh
```

Existing real files are moved to `~/.claude-config-backup-<timestamp>/`
before being replaced by symlinks.

## Daily workflow

Edit config as usual (through Claude Code or by hand) — the symlinks make
the changes land in this repo. Then:

```sh
cd ~/code/personnal/claude-config
git add -A && git commit -m "chore: update config" && git push
```

On the other machine: `git pull` (re-run `./install.sh` only if a symlink
was replaced by a real file, e.g. after a tool rewrote `settings.json`).

## Caveats

- `claude/settings.json` contains hooks pointing to
  `/home/upd4ting/.orca/agent-hooks/claude-hook.sh`. The hook command guards
  with `[ -f ... ]`, so it degrades gracefully on machines without Orca,
  but the absolute path assumes the same username.
- New skills added to `~/.agents/skills/` are tracked automatically; if you
  enable one in Claude Code, also add its name to
  `claude/skills-enabled.txt` so other machines pick it up.
