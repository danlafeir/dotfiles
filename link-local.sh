#!/usr/bin/env bash
# Install every gitignored *.local / *.local.* file into $HOME at the same
# relative path (e.g. ./.zshrc.local -> ~/.zshrc.local).
#
# If a base file exists next to it (.zshrc for .zshrc.local, foo.json for
# foo.local.json), the two are merged with the .local content taking
# precedence, written to .generated/<base> (gitignored), and ~/<base> links
# there. A base that already names its .local file (a source/include line)
# loads it itself, so that .local file is only symlinked, not merged. Text
# files: base then local, so later lines win. .json: deep merge, local values
# win. Re-run after editing either file. Honors DRY_RUN=true.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

ROOT="${LINK_LOCAL_ROOT:-$SCRIPT_DIR}"
GEN_DIR="$ROOT/.generated"

while IFS= read -r -d '' src; do
  rel="${src#"$ROOT"/}"
  base_rel="$(sed -E 's/\.local(\.|$)/\1/' <<<"$rel")"
  base="$ROOT/$base_rel"

  if [ ! -f "$base" ] || grep -qF "$(basename "$rel")" "$base"; then
    link "$src" "$HOME/$rel" skip
    log "Linked $rel"
    continue
  fi

  out="$GEN_DIR/$base_rel"
  if [ "$DRY_RUN" = true ]; then
    log "[dry-run] merge $base_rel + $rel -> $out"
  else
    mkdir -p "$(dirname "$out")"
    if [[ "$rel" == *.json ]]; then
      jq -s '.[0] * .[1]' "$base" "$src" > "$out"
    else
      { cat "$base"; printf '\n'; cat "$src"; } > "$out"
    fi
  fi
  link "$out" "$HOME/$base_rel"
  log "Merged $base_rel + $rel"
done < <(find "$ROOT" \
  \( -name .git -o -name .claude -o -name .generated -o -path "$ROOT/.vim/undodir" -o -path "$ROOT/.vim/plugged" \) -prune -o \
  \( -name '*.local' -o -name '*.local.*' \) -print0)
