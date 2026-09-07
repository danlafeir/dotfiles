#!/usr/bin/env bash
# One-time per-repo opt-in for the push-review gate's git-level enforcement
# (blocks a plain terminal `git push`, not just one run through Claude
# Code — see ../hooks/push-review-pretooluse.sh for that side, which shares
# the same push-review.enabled flag this sets).
#
# Usage: install.sh [repo-root]   (defaults to the current directory)
#
# Symlinks pre-push into the repo's real .git/hooks/ directory (resolved via
# `git rev-parse --git-common-dir`, so this also works from a linked
# worktree). If a real (non-symlink) pre-push hook already exists there —
# e.g. from the `pre-commit` Python framework, or one written by hand — it's
# preserved as pre-push.pre-push-review-original so the installed hook can
# chain to it; this only happens once, on first install.

set -euo pipefail

REPO="${1:-$(pwd)}"
GIT_COMMON_DIR=$(git -C "$REPO" rev-parse --git-common-dir 2>/dev/null) || {
  echo "not a git repo: $REPO" >&2
  exit 1
}
# rev-parse --git-common-dir can return a path relative to $REPO.
case "$GIT_COMMON_DIR" in
  /*) : ;;
  *) GIT_COMMON_DIR="$REPO/$GIT_COMMON_DIR" ;;
esac

HOOKS_DIR="$GIT_COMMON_DIR/hooks"
mkdir -p "$HOOKS_DIR"
TARGET="$HOOKS_DIR/pre-push"
ORIGINAL="$HOOKS_DIR/pre-push.pre-push-review-original"
OUR_SCRIPT="$HOME/.claude/hooks/push-review-git-pre-push.sh"

if [ ! -e "$OUR_SCRIPT" ]; then
  echo "error: $OUR_SCRIPT not found — run bootstrap-mac.sh first" >&2
  exit 1
fi

if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
  if [ -e "$ORIGINAL" ]; then
    echo "error: $TARGET exists and $ORIGINAL already does too — resolve manually" >&2
    exit 1
  fi
  mv "$TARGET" "$ORIGINAL"
  echo "preserved existing hook: $ORIGINAL (will be chained)"
elif [ -L "$TARGET" ]; then
  RESOLVED=$(readlink "$TARGET")
  if [ "$RESOLVED" != "$OUR_SCRIPT" ]; then
    echo "error: $TARGET is already a symlink to $RESOLVED (not ours) - resolve manually" >&2
    exit 1
  fi
fi

ln -sf "$OUR_SCRIPT" "$TARGET"
git -C "$REPO" config push-review.enabled true

echo "push-review gate installed for $REPO"
echo "  - git-level (plain terminal push): $TARGET -> $OUR_SCRIPT"
echo "  - Claude-Code-level (PreToolUse):  already active, gated on the same flag"
echo "To pause without uninstalling: git -C '$REPO' config push-review.enabled false"
