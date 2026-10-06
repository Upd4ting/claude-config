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

Orca's `orca-cli` and `orchestration` skills are **not** tracked: Orca installs
and updates them itself (real directories in `~/.agents/skills`, aliased from
`~/.claude/skills`) and reports symlinks pointing elsewhere as missing.
`install.sh` leaves them alone. The Orca agent hooks it injects into
`claude/settings.json` are kept (they are no-ops on machines without Orca).

Deliberately **not** tracked: credentials, `settings.local.json`, MCP servers,
sessions, history and caches. Secrets such as tokens belong in
`~/.claude/settings.local.json` (`env` key), never in `claude/settings.json`.

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

## Cloud sessions (Claude Code on the web)

Cloud containers start without `~/.claude`, so neither these skills nor
`CLAUDE.md` are loaded. Add this to the environment's setup script (session
title bar → environment menu → Edit → Setup script) to install them in every
new session:

```sh
dir="$HOME/.claude-config"
if [ -d "$dir/.git" ]; then
  git -C "$dir" pull --ff-only
else
  git clone --depth 1 https://github.com/Upd4ting/claude-config.git "$dir"
fi && "$dir/install.sh" --claude || echo "warn: claude-config install failed"
```

The clone needs no credentials once this repository is public. A plugin that
fails to install only prints a warning.

`claude/settings.json` also carries a `SessionStart` hook that, in cloud
sessions only (`CLAUDE_CODE_REMOTE=true`), runs the project's executable
`.agents/setup` script if one exists. Use it to install project dependencies;
it runs on every session start, including resumes, so keep it idempotent.
Output goes to `~/.agents-setup.log`.
