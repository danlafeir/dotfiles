#!/usr/bin/env bash
# PreToolUse backstop for the "don't push without a passing pre-push-review"
# policy in global-claude.md / AGENTS.md. Blocks `git push` run as a Bash
# tool call unless push-review-gate.sh confirms the current diff has an
# up-to-date passing marker. Fails closed: any internal error blocks too.
# Companion to ../git-hooks/pre-push, which enforces the same check for
# pushes run outside Claude Code.

set -euo pipefail
# Deliberately not -E (errtrace): with it set, this trap fires inside the
# subshell bash forks for the `REASON=$(gate check ...)` capture below even
# though a nonzero exit there is the expected "blocked" case, not an error
# — errtrace propagates ERR into that subshell regardless of the `if !`
# around it. Plain -e still fails closed on any real top-level error.
trap 'echo "BLOCKED by push-review-pretooluse.sh: internal error - failing closed" >&2; exit 2' ERR

# Absolute, deployed-location reference rather than resolving relative to
# this script's own path — settings.json invokes this via an absolute path
# too, so there's no guarantee of a stable "next to me" layout to rely on.
GATE_SCRIPT="$HOME/.claude/hooks/push-review-gate.sh"

INPUT=$(cat)
TOOL_NAME=$(jq -r '.tool_name // empty' <<< "$INPUT")

[ "$TOOL_NAME" = "Bash" ] || exit 0

COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")
[ -z "$COMMAND" ] && exit 0

# Only care about an actual push: allow common flag prefixes between `git`
# and `push` (`git -C <dir> push`, `git -c x=y push`, `git --no-pager push`)
# without matching arbitrary later commands. Exempt --dry-run/-n/--help so
# those pass through untouched.
if ! grep -qiE '\bgit\s+(-C\s+\S+\s+|-c\s+\S+\s+|--git-dir=\S+\s+|--no-pager\s+)*push\b' <<< "$COMMAND"; then
  exit 0
fi
if grep -qiE '(--dry-run|--help)\b|(^|\s)-n(\s|$)' <<< "$COMMAND"; then
  exit 0
fi

# `git -C <dir> push` targets a different repo than the session's cwd — if
# we checked cwd here, this would be a one-line bypass of the whole gate
# (check an unrelated/unopted-in directory, push the real target anyway).
# Prefer an explicit -C argument over the hook's reported cwd.
EXPLICIT_DIR=""
if [[ "$COMMAND" =~ -C[[:space:]]+([^[:space:]]+) ]]; then
  EXPLICIT_DIR="${BASH_REMATCH[1]}"
fi

if [ -n "$EXPLICIT_DIR" ]; then
  CWD="$EXPLICIT_DIR"
else
  CWD=$(jq -r '.cwd // empty' <<< "$INPUT")
  [ -z "$CWD" ] && CWD="$PWD"
fi

# Opt-in, same flag ../git-hooks/install.sh sets: don't gate a repo that
# hasn't opted in. Without this, every Claude-Code-mediated push everywhere
# would be blocked the moment this hook is installed.
ENABLED=$(git -C "$CWD" config --bool push-review.enabled 2>/dev/null) || ENABLED=false
[ "$ENABLED" = "true" ] || exit 0

if [ ! -x "$GATE_SCRIPT" ]; then
  echo "BLOCKED by push-review-pretooluse.sh: $GATE_SCRIPT not found or not executable - run bootstrap-mac.sh" >&2
  exit 2
fi

if ! REASON=$("$GATE_SCRIPT" check "$CWD" 2>&1); then
  echo "BLOCKED by push-review-pretooluse.sh: $REASON" >&2
  echo "Policy: pushing requires a passing /pre-push-review for the current diff. Run /pre-push-review, address or acknowledge its findings, then push again." >&2
  exit 2
fi

exit 0
