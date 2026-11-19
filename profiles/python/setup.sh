#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.zfunc"
# Completions are optional: a broken poetry install must not fail the bootstrap.
if command -v poetry >/dev/null; then
  tmp="$(mktemp)"
  if poetry completions zsh > "$tmp" 2>/dev/null; then
    mv "$tmp" "$HOME/.zfunc/_poetry"
  else
    rm -f "$tmp"
    echo "poetry completions failed; skipping" >&2
  fi
fi
exit 0
