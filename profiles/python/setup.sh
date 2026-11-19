#!/usr/bin/env bash
set -euo pipefail

command -v pipx >/dev/null && pipx ensurepath
mkdir -p "$HOME/.zfunc"
command -v poetry >/dev/null && poetry completions zsh > "$HOME/.zfunc/_poetry"
exit 0
