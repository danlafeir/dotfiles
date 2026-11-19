#!/usr/bin/env bash
# Shared helpers for bootstrap.sh and link-local.sh. Source, don't execute.

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
LINK_MANIFEST="$CONFIG_DIR/links"
DRY_RUN="${DRY_RUN:-false}"

log() { echo "$*"; }

warn() { echo "$*" >&2; }

# Runs a mutating command, or only prints it under --dry-run.
run() {
  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] $*"
    return 0
  fi
  "$@"
}

# link SRC DEST [skip]
# Symlinks DEST to SRC and records it in the manifest that `doctor` checks.
# A real file already at DEST is moved to DEST.pre-dotfiles, or left alone
# with a warning when the third argument is "skip".
link() {
  local src="$1" dest="$2" mode="${3:-backup}"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    if [ "$mode" = skip ]; then
      warn "Skipping $dest: exists and is not a symlink"
      return 0
    fi
    if [ -e "$dest.pre-dotfiles" ]; then
      warn "Skipping $dest: exists, and $dest.pre-dotfiles is already taken"
      return 0
    fi
    run mv "$dest" "$dest.pre-dotfiles"
  fi
  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] link $dest -> $src"
    return 0
  fi
  mkdir -p "$(dirname "$dest")" "$CONFIG_DIR"
  ln -sfn "$src" "$dest"
  printf '%s\t%s\n' "$dest" "$src" >> "$LINK_MANIFEST"
}
