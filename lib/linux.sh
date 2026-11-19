#!/usr/bin/env bash
# Linux adapter: apt packages listed in each active profile's apt.txt.
# Sourced by bootstrap.sh.

platform_install_packages() {
  if ! command -v apt-get >/dev/null 2>&1; then
    warn "apt-get not found; install the packages in profiles/*/apt.txt yourself"
    return 0
  fi
  local sudo="" p
  [ "$(id -u)" -ne 0 ] && sudo="sudo"
  local pkgs=()
  for p in "${PROFILES[@]}"; do
    if [ -f "$DOTFILES_DIR/profiles/$p/apt.txt" ]; then
      while IFS= read -r pkg; do
        [ -n "$pkg" ] && pkgs+=("$pkg")
      done < "$DOTFILES_DIR/profiles/$p/apt.txt"
    fi
  done
  [ "${#pkgs[@]}" -eq 0 ] && return 0
  # shellcheck disable=SC2086
  run $sudo apt-get update
  if [ "$UPGRADE" = true ]; then
    # shellcheck disable=SC2086
    run $sudo apt-get upgrade -y
  fi
  # shellcheck disable=SC2086
  run $sudo apt-get install -y "${pkgs[@]}"
}
