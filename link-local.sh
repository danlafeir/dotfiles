#!/usr/bin/env bash
# Install every gitignored *.local / *.local.* file into $HOME at the same
# relative path (e.g. ./.zshrc.local -> ~/.zshrc.local).
#
# If a base file exists next to it (.zshrc for .zshrc.local, foo.json for
# foo.local.json), the two are merged with the .local content taking
# precedence, written to .generated/<base> (gitignored), and ~/<base> links
# there. A base that already names its .local file (a source/include line)
# loads it itself, so that .local file is only symlinked, not merged. Text files: base then local, so later lines win. .json: deep merge,
# local values win. Re-run after editing either file.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
GEN_DIR="$DOTFILES_DIR/.generated"

link() {
  local src="$1" rel="$2" dest="$HOME/$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "Skipping $rel: $dest exists and is not a symlink" >&2
    return
  fi
  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
}

while IFS= read -r -d '' src; do
  rel="${src#"$DOTFILES_DIR"/}"
  base_rel="$(sed -E 's/\.local(\.|$)/\1/' <<<"$rel")"
  base="$DOTFILES_DIR/$base_rel"

  if [ ! -f "$base" ] || grep -qF "$(basename "$rel")" "$base"; then
    link "$src" "$rel"
    echo "Linked $rel"
    continue
  fi

  out="$GEN_DIR/$base_rel"
  mkdir -p "$(dirname "$out")"
  if [[ "$rel" == *.json ]]; then
    jq -s '.[0] * .[1]' "$base" "$src" > "$out"
  else
    { cat "$base"; printf '\n'; cat "$src"; } > "$out"
  fi
  link "$out" "$base_rel"
  echo "Merged $base_rel + $rel"
done < <(find "$DOTFILES_DIR" \
  \( -name .git -o -name .claude -o -name .generated -o -path "$DOTFILES_DIR/.vim/undodir" -o -path "$DOTFILES_DIR/.vim/plugged" \) -prune -o \
  \( -name '*.local' -o -name '*.local.*' \) -print0)
