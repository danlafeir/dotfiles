#!/usr/bin/env bash
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/danlafeir/dotfiles/main/install.sh -o install.sh
#   bash install.sh [bootstrap.sh options, e.g. --profile base,personal]
#
# Must be downloaded and run as a file (not piped) — the bootstrap has
# interactive prompts that don't work through a pipe.
#
# Clones the repo to ~/.dotfiles when git is available (so later updates are
# `git pull`); otherwise falls back to a tarball, which has no history.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
REPO_URL="https://github.com/danlafeir/dotfiles.git"
TARBALL_URL="https://github.com/danlafeir/dotfiles/archive/refs/heads/main.tar.gz"

fetch_tarball() {
  local tarball
  tarball="$(mktemp "${TMPDIR:-/tmp}/dotfiles.XXXXXX")"
  curl -fsSL "$TARBALL_URL" -o "$tarball"
  mkdir -p "$DOTFILES_DIR"
  tar -xzf "$tarball" --strip-components=1 -C "$DOTFILES_DIR"
  rm "$tarball"
}

if [ -d "$DOTFILES_DIR/.git" ]; then
  echo "Updating $DOTFILES_DIR"
  git -C "$DOTFILES_DIR" pull --ff-only
elif [ -d "$DOTFILES_DIR" ]; then
  echo "Updating tarball install at $DOTFILES_DIR (no git history)"
  fetch_tarball
elif command -v git >/dev/null 2>&1; then
  echo "Cloning dotfiles to $DOTFILES_DIR"
  git clone "$REPO_URL" "$DOTFILES_DIR"
else
  echo "git not found; downloading a tarball to $DOTFILES_DIR"
  fetch_tarball
fi

exec bash "$DOTFILES_DIR/bootstrap.sh" "$@"
