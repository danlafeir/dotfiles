#!/usr/bin/env bash
# Provision this machine from the dotfiles repo. Safe to re-run.
#
# Usage:
#   bootstrap.sh [--profile a,b] [--upgrade] [--skip-packages] [--dry-run]
#   bootstrap.sh doctor
#
# --profile   Profiles to apply (see profiles/). Saved to
#             ~/.config/dotfiles/profiles and reused by later runs. `base` is
#             always included. Default: the saved list, else just `base`.
# --upgrade   Also upgrade already-installed packages.
# --skip-packages  Link config only; install no packages or editor plugins.
# --dry-run   Print what would change and write nothing.
# doctor      Check that every link made by earlier runs is intact.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=lib/core.sh
. "$DOTFILES_DIR/lib/core.sh"

PROFILES_FILE="$CONFIG_DIR/profiles"
PROFILE_ARG=""
UPGRADE=false
SKIP_PACKAGES=false
COMMAND=bootstrap

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE_ARG="${2:?--profile needs a comma-separated list}"; shift 2 ;;
    --upgrade) UPGRADE=true; shift ;;
    --skip-packages) SKIP_PACKAGES=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    doctor) COMMAND=doctor; shift ;;
    -h|--help) sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) warn "Unknown argument: $1 (try --help)"; exit 2 ;;
  esac
done
export DRY_RUN

doctor() {
  local status=0 dest src
  [ -f "$PROFILES_FILE" ] && log "Active profiles: $(paste -sd, "$PROFILES_FILE")" \
    || log "Active profiles: none saved (base only)"
  if [ ! -f "$LINK_MANIFEST" ]; then
    warn "No link manifest at $LINK_MANIFEST; run bootstrap.sh first"
    return 1
  fi
  while IFS=$'\t' read -r dest src; do
    if [ ! -L "$dest" ]; then
      warn "MISSING   $dest (expected link to $src)"; status=1
    elif [ "$(readlink "$dest")" != "$src" ]; then
      warn "CHANGED   $dest -> $(readlink "$dest") (expected $src)"; status=1
    elif [ ! -e "$src" ]; then
      warn "BROKEN    $dest -> $src (target gone)"; status=1
    fi
  done < <(sort -u "$LINK_MANIFEST")
  [ "$status" -eq 0 ] && log "All links OK"
  return "$status"
}

resolve_profiles() {
  local list p seen=" "
  if [ -n "$PROFILE_ARG" ]; then
    list="$PROFILE_ARG"
  elif [ -f "$PROFILES_FILE" ]; then
    list="$(paste -sd, "$PROFILES_FILE")"
  else
    list="base"
  fi
  PROFILES=()
  for p in base ${list//,/ }; do
    case "$seen" in *" $p "*) continue ;; esac
    if [ ! -d "$DOTFILES_DIR/profiles/$p" ]; then
      warn "Unknown profile: $p (available: $(ls "$DOTFILES_DIR/profiles" | paste -sd, -))"
      exit 2
    fi
    seen="$seen$p "
    PROFILES+=("$p")
  done
}

if [ "$COMMAND" = doctor ]; then
  doctor
  exit $?
fi

case "$(uname -s)" in
  Darwin) PLATFORM=mac ;;
  Linux) PLATFORM=linux ;;
  *) warn "Unsupported platform: $(uname -s). See personal-windows/README.md for Windows."; exit 1 ;;
esac
# shellcheck source=/dev/null
. "$DOTFILES_DIR/lib/$PLATFORM.sh"

resolve_profiles
log "Profiles: ${PROFILES[*]}"
if [ -n "$PROFILE_ARG" ]; then
  run mkdir -p "$CONFIG_DIR"
  if [ "$DRY_RUN" != true ]; then
    printf '%s\n' "${PROFILES[@]}" > "$PROFILES_FILE"
  fi
fi

if [ "$DRY_RUN" != true ]; then
  mkdir -p "$CONFIG_DIR"
  : > "$LINK_MANIFEST"
fi

if [ "$SKIP_PACKAGES" != true ]; then
  install_shell_tooling
  platform_install_packages
fi
link_shell_config
if [ "$SKIP_PACKAGES" != true ]; then
  install_editor_plugins
fi
"$DOTFILES_DIR/link-local.sh"
choose_gpg_signing_key
link_ai_tools
link_gpg_ssh
if [ "$SKIP_PACKAGES" != true ]; then
  run_profile_setup
fi
log "Done. Run 'bootstrap.sh doctor' to verify."
