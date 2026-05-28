#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES_DIR="$DOTFILES_DIR/ai-tools/templates"
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

if [ -f "CLAUDE.md" ]; then
  printf "CLAUDE.md already exists. Overwrite? (y/N) "
  read -r answer
  [[ "$answer" != "y" ]] && exit 0
fi

cp "$TEMPLATE_FILE" CLAUDE.md
echo "Created CLAUDE.md from $1 template"
