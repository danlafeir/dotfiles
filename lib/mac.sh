#!/usr/bin/env bash
# macOS adapter: Homebrew packages. Sourced by bootstrap.sh.

platform_install_packages() {
  if ! command -v brew >/dev/null 2>&1; then
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  if [ "$UPGRADE" = true ]; then
    run brew upgrade
  fi
  local p
  for p in "${PROFILES[@]}"; do
    if [ -f "$DOTFILES_DIR/profiles/$p/brewfile" ]; then
      run brew bundle --file "$DOTFILES_DIR/profiles/$p/brewfile"
    fi
  done
}
