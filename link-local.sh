#!/usr/bin/env bash
# Symlink every gitignored *.local / *.local.* file in this repo into $HOME
# at the same relative path (e.g. ./.zshrc.local -> ~/.zshrc.local).
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

while IFS= read -r -d '' src; do
  rel="${src#"$DOTFILES_DIR"/}"
  dest="$HOME/$rel"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "Skipping $rel: $dest exists and is not a symlink" >&2
    continue
  fi
  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
  echo "Linked $rel"
done < <(find "$DOTFILES_DIR" \
  \( -name .git -o -name .claude -o -path "$DOTFILES_DIR/.vim/undodir" -o -path "$DOTFILES_DIR/.vim/plugged" \) -prune -o \
  \( -name '*.local' -o -name '*.local.*' \) -print0)
