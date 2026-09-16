#!/usr/bin/env bash
# Installs the Claude Code and Codex configuration from this repository.
# Live config files and skills are symlinked to the repo, so edits stay
# tracked by git. Existing real files are backed up before being replaced.
#
# Usage: ./install.sh [--claude] [--codex]   (default: both)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.agent-config-backup-$(date +%Y%m%d-%H%M%S)"

install_claude=false
install_codex=false
for arg in "$@"; do
  case "$arg" in
    --claude) install_claude=true ;;
    --codex) install_codex=true ;;
    *) echo "usage: $0 [--claude] [--codex]" >&2; exit 1 ;;
  esac
done
if ! $install_claude && ! $install_codex; then
  install_claude=true
  install_codex=true
fi

backup() {
  local path="$1"
  local relative="${path#"$HOME"/}"
  mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
  mv "$path" "$BACKUP_DIR/$relative"
  echo "backed up: $path -> $BACKUP_DIR/$relative"
}

link() {
  local source="$1" target="$2"
  mkdir -p "$(dirname "$target")"
  if [ -L "$target" ]; then
    if [ "$(readlink -f "$target")" = "$(readlink -f "$source")" ]; then
      return
    fi
    rm "$target"
  elif [ -e "$target" ]; then
    backup "$target"
  fi
  ln -s "$source" "$target"
  echo "linked:    $target -> $source"
}

# Links every skill of <source_dir> into <target_dir>, one symlink per skill,
# and removes links left behind by skills that were deleted or renamed.
link_skills() {
  local source_dir="$1" target_dir="$2"
  mkdir -p "$target_dir"

  local skill
  for skill in "$source_dir"/*/; do
    skill="$(basename "$skill")"
    if [ ! -f "$source_dir/$skill/SKILL.md" ]; then
      echo "error: missing $source_dir/$skill/SKILL.md" >&2
      exit 1
    fi
    link "$source_dir/$skill" "$target_dir/$skill"
  done

  local entry
  for entry in "$target_dir"/*; do
    [ -L "$entry" ] || continue
    if [ ! -e "$entry" ] || { [[ "$(readlink "$entry")" == "$REPO_DIR"/* ]] && [ ! -d "$source_dir/$(basename "$entry")" ]; }; then
      rm "$entry"
      echo "removed:   stale skill link $entry"
    fi
  done

  echo "skills:    $(find "$source_dir" -mindepth 1 -maxdepth 1 -type d | wc -l) linked in $target_dir"
}

if $install_claude; then
  echo "== Claude Code"
  link "$REPO_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  link "$REPO_DIR/claude/settings.json" "$HOME/.claude/settings.json"
  link "$REPO_DIR/claude/commands" "$HOME/.claude/commands"
  link_skills "$REPO_DIR/claude/skills" "$HOME/.claude/skills"

  if command -v claude >/dev/null 2>&1; then
    while IFS= read -r plugin; do
      [ -n "$plugin" ] || continue
      claude plugin install "$plugin" || echo "warn: failed to install plugin '$plugin'"
    done <"$REPO_DIR/plugins/plugins.txt"
  else
    echo "warn: claude CLI not found, skipping plugins (see plugins/plugins.txt)"
  fi
fi

if $install_codex; then
  echo "== Codex"
  # Older installs linked the whole directory; per-skill links keep other
  # skills (and Codex's bundled skill-creator) untouched.
  if [ -L "$HOME/.agents/skills" ]; then
    rm "$HOME/.agents/skills"
  fi
  link "$REPO_DIR/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
  link "$REPO_DIR/agents/.skill-lock.json" "$HOME/.agents/.skill-lock.json"
  link_skills "$REPO_DIR/codex/skills" "$HOME/.agents/skills"
fi

echo "done:      restart Claude Code / Codex to pick up new skills"
