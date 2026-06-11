#!/usr/bin/env bash
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/danlafeir/dotfiles/main/install.sh -o install.sh
#   bash install.sh [personal]
#
# Must be downloaded and run as a file (not piped) — the bootstrap has
# interactive prompts that don't work through a pipe.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
REPO="https://github.com/danlafeir/dotfiles/archive/refs/heads/main.tar.gz"

if [ -d "$DOTFILES_DIR" ]; then
  echo "Dotfiles already exist at $DOTFILES_DIR — updating."
  TARBALL=$(mktemp /tmp/dotfiles.XXXXXX.tar.gz)
  curl -fsSL "$REPO" -o "$TARBALL"
  tar -xzf "$TARBALL" --strip-components=1 -C "$DOTFILES_DIR"
  rm "$TARBALL"
else
  echo "Downloading dotfiles to $DOTFILES_DIR"
  TARBALL=$(mktemp /tmp/dotfiles.XXXXXX.tar.gz)
  curl -fsSL "$REPO" -o "$TARBALL"
  mkdir -p "$DOTFILES_DIR"
  tar -xzf "$TARBALL" --strip-components=1 -C "$DOTFILES_DIR"
  rm "$TARBALL"
fi

bash "$DOTFILES_DIR/bootstrap-mac.sh" "${1:-}"
