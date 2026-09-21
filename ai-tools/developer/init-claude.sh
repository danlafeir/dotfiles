#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATES_DIR="$DOTFILES_DIR/ai-tools/developer/templates"
AVAILABLE=$(ls "$TEMPLATES_DIR" | sed 's/\.md//' | tr '\n' ' ')

if [ -z "${1:-}" ]; then
  echo "Usage: init-claude <template>" >&2
  echo "Available: $AVAILABLE" >&2
  exit 1
fi

TEMPLATE_FILE="$TEMPLATES_DIR/$1.md"
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Unknown template: $1" >&2
  echo "Available: $AVAILABLE" >&2
  exit 1
fi

if [ -f "AGENTS.md" ]; then
  printf "AGENTS.md already exists. Overwrite? (y/N) "
  read -r answer
  [[ "$answer" != "y" ]] && exit 0
fi

cp "$TEMPLATE_FILE" AGENTS.md
echo "Created AGENTS.md from $1 template"

if [ -f "CLAUDE.md" ]; then
  echo "Note: CLAUDE.md exists here, so Claude Code reads it instead of AGENTS.md. Add '@AGENTS.md' to it, or remove it." >&2
fi
