# claude-config

Portable backup of my Claude Code and Codex configuration, installable on any
machine with a single script. Live config files and skills are **symlinked**
to this repo, so every change is tracked by git — commit and push to sync,
pull and re-run `install.sh` on the other machine.

## What is tracked

| Repo path                 | Live location                    | Content                                   |
| ------------------------- | -------------------------------- | ----------------------------------------- |
| `claude/CLAUDE.md`        | `~/.claude/CLAUDE.md`            | Claude Code global instructions           |
| `claude/settings.json`    | `~/.claude/settings.json`        | Permissions, model, language, etc.        |
| `claude/commands/`        | `~/.claude/commands/`            | Custom slash commands                     |
| `claude/skills/<name>/`   | `~/.claude/skills/<name>`        | Claude Code skills                        |
| `plugins/plugins.txt`     | (via `claude plugin install`)    | Claude Code plugins to reinstall          |
| `codex/AGENTS.md`         | `~/.codex/AGENTS.md`             | Codex global instructions                 |
| `codex/skills/<name>/`    | `~/.agents/skills/<name>`        | Codex skills                              |
| `agents/.skill-lock.json` | `~/.agents/.skill-lock.json`     | Skill provenance lock file                |

Every skill directory under `claude/skills/` or `codex/skills/` is installed;
delete a directory to disable a skill.

The two skill trees are intentionally separate copies. Many skills share an
origin, but the Codex versions use `$skill` invocation, Codex-native tools,
and drop Claude-only frontmatter (`disable-model-invocation`,
`user-invocable`). Some skills exist on one side only (`claude-handoff` /
`codex-handoff`, `git-guardrails-claude-code` / `git-guardrails-codex`,
Codex `commit` / `create-*` skills that mirror Claude's slash commands).
`skill-creator` is Claude-only because Codex bundles its own.

Deliberately **not** tracked: credentials, `settings.local.json`, MCP servers,
sessions, history and caches.

## Setup on a new machine

```sh
git clone git@github.com:Upd4ting/claude-config.git ~/code/personnal/claude-config
cd ~/code/personnal/claude-config
./install.sh            # both; or ./install.sh --claude / --codex
```

Existing real files are moved to `~/.agent-config-backup-<timestamp>/` before
being replaced by symlinks. Unrelated skills already present in the target
skill directories are left alone; stale links to removed repo skills are
cleaned up.

## Daily workflow

Edit config as usual — the symlinks make the changes land in this repo. Then:

```sh
cd ~/code/personnal/claude-config
git add -A && git commit -m "chore: update config" && git push
```

On the other machine: `git pull`, then re-run `./install.sh` if skills were
added, removed or renamed (or if a tool replaced a symlink with a real file).

## Runtime dependencies

`notion-cli` requires `ntn`.

## Proton Pass SSH agent

On this Linux setup, Proton Pass exposes its SSH agent at:

```text
~/.ssh/proton-pass-ssh-agent.sock
```

Processes that do not inherit `SSH_AUTH_SOCK` can still use it explicitly:

```sh
SSH_AUTH_SOCK="$HOME/.ssh/proton-pass-ssh-agent.sock" git pull
```
