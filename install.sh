#!/usr/bin/env bash
# Installs the Claude config from this repo onto the current machine.
# Strategy: symlink the live config files to this repo, so any future edit
# is immediately tracked by git. Existing real files are backed up first.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.claude-config-backup-$(date +%Y%m%d-%H%M%S)"

backup_and_link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dst" "$BACKUP_DIR/$(basename "$dst")"
    echo "backed up: $dst -> $BACKUP_DIR/"
  fi
  ln -sfn "$src" "$dst"
  echo "linked:    $dst -> $src"
}

# --- Core Claude Code config ---
backup_and_link "$REPO_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
backup_and_link "$REPO_DIR/claude/settings.json" "$HOME/.claude/settings.json"
backup_and_link "$REPO_DIR/claude/commands" "$HOME/.claude/commands"

# --- Skills library (shared agent skills under ~/.agents) ---
backup_and_link "$REPO_DIR/agents/skills" "$HOME/.agents/skills"
backup_and_link "$REPO_DIR/agents/.skill-lock.json" "$HOME/.agents/.skill-lock.json"

# --- Enable the selected skills in Claude Code ---
mkdir -p "$HOME/.claude/skills"
while IFS= read -r skill; do
  [ -n "$skill" ] || continue
  ln -sfn "../../.agents/skills/$skill" "$HOME/.claude/skills/$skill"
done <"$REPO_DIR/claude/skills-enabled.txt"
echo "skills:    $(wc -l <"$REPO_DIR/claude/skills-enabled.txt") enabled in ~/.claude/skills"

# --- Plugins (requires the claude CLI) ---
if command -v claude >/dev/null 2>&1; then
  while IFS= read -r plugin; do
    [ -n "$plugin" ] || continue
    claude plugin install "$plugin" || echo "warn: failed to install plugin '$plugin'"
  done <"$REPO_DIR/plugins/plugins.txt"
else
  echo "warn: claude CLI not found, skipping plugins (see plugins/plugins.txt)"
fi

echo ""
echo "Done."
