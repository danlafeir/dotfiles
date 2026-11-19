#!/usr/bin/env bash
# Tests for bootstrap.sh and link-local.sh. Everything runs against a
# throwaway $HOME; no packages are installed. Usage: tests/run.sh
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILED=0

pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; FAILED=1; }
check() { # check DESC COMMAND...
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi
}
expect_fail() { # expect_fail DESC COMMAND...
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then fail "$desc"; else pass "$desc"; fi
}
sandbox() { env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u DOTFILES_DIR HOME="$1" "${@:2}"; }

# --- link-local.sh -----------------------------------------------------
ROOT="$TMP/root"; H="$TMP/home1"; mkdir -p "$ROOT/sub" "$H"
echo 'base=1' > "$ROOT/x.conf";            echo 'local=2' > "$ROOT/x.local.conf"
echo '{"k":{"a":1,"b":1}}' > "$ROOT/y.json"; echo '{"k":{"b":2}}' > "$ROOT/y.local.json"
echo 'source ~/.rc.local' > "$ROOT/.rc";    echo 'x' > "$ROOT/.rc.local"
echo solo > "$ROOT/sub/z.local"
echo keep > "$ROOT/w.local";               echo mine > "$H/w.local"
run_ll() { sandbox "$H" env LINK_LOCAL_ROOT="$ROOT" "$REPO/link-local.sh"; }
run_ll >/dev/null 2>&1

check "text base+local are concatenated, local last" \
  bash -c "[ \"\$(cat $H/x.conf)\" = \"\$(printf 'base=1\n\nlocal=2')\" ]"
check "json is deep-merged with local winning" \
  bash -c "[ \"\$(jq -c .k.b $H/y.json)\" = 2 ] && [ \"\$(jq -c .k.a $H/y.json)\" = 1 ]"
check "base that sources its local file is linked, not merged" \
  bash -c "[ \"\$(readlink $H/.rc.local)\" = $ROOT/.rc.local ] && [ ! -e $H/.rc ]"
check "standalone .local is linked at its relative path" \
  bash -c "[ \"\$(readlink $H/sub/z.local)\" = $ROOT/sub/z.local ]"
check "existing real file is not overwritten" \
  bash -c "[ \"\$(cat $H/w.local)\" = mine ] && [ ! -L $H/w.local ]"
check "second run succeeds and output is unchanged" \
  bash -c "before=\$(cat $H/x.conf); LINK_LOCAL_ROOT=$ROOT HOME=$H $REPO/link-local.sh >/dev/null 2>&1 && [ \"\$before\" = \"\$(cat $H/x.conf)\" ]"
rm -rf "$ROOT/.generated"

# --- bootstrap.sh ------------------------------------------------------
H2="$TMP/home2"; mkdir -p "$H2"
sandbox "$H2" "$REPO/bootstrap.sh" --dry-run --skip-packages --profile base,manager >/dev/null 2>&1
check "dry-run writes nothing to \$HOME" bash -c "[ -z \"\$(ls -A $H2)\" ]"

sandbox "$H2" "$REPO/bootstrap.sh" --skip-packages --profile base,manager >/dev/null 2>&1
check "bootstrap links the shell config" test -L "$H2/.zshrc"
check "bootstrap links agents from active tiers" test -L "$H2/.claude/agents/security-review-agent.md"
check "bootstrap links hooks under their settings.json names" test -L "$H2/.claude/hooks/secret-store-guard.sh"
check "bootstrap merges PreToolUse hooks into settings.json" \
  bash -c "jq -e '.hooks.PreToolUse | length > 0' $H2/.claude/settings.json"
check "bootstrap saves the active profiles" \
  bash -c "[ \"\$(paste -sd, $H2/.config/dotfiles/profiles)\" = base,manager ]"
check "gpg-agent.conf is a real file, not a link into the repo" \
  bash -c "[ -f $H2/.gnupg/gpg-agent.conf ] && [ ! -L $H2/.gnupg/gpg-agent.conf ]"
check "doctor passes after bootstrap" sandbox "$H2" "$REPO/bootstrap.sh" doctor
rm "$H2/.zshrc"
expect_fail "doctor fails when a link is missing" sandbox "$H2" "$REPO/bootstrap.sh" doctor
check "re-running bootstrap repairs the link" \
  bash -c "HOME=$H2 $REPO/bootstrap.sh --skip-packages >/dev/null 2>&1 && HOME=$H2 $REPO/bootstrap.sh doctor >/dev/null 2>&1"
expect_fail "unknown profile is rejected" sandbox "$H2" "$REPO/bootstrap.sh" --dry-run --profile nope
expect_fail "unknown flag is rejected" sandbox "$H2" "$REPO/bootstrap.sh" --bogus

[ "$FAILED" -eq 0 ] && echo "All tests passed" || { echo "Some tests failed"; exit 1; }
