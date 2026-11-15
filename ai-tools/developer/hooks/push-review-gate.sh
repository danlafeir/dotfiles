#!/usr/bin/env bash
# Shared check for the push-review gate. Both enforcement layers —
# push-review-pretooluse.sh (a Claude Code PreToolUse hook) and
# ../git-hooks/pre-push (a real git hook) — call this script rather than
# each computing the diff hash themselves, so they can never disagree about
# what counts as "reviewed." Caller-agnostic contract: exit 0 = pass,
# exit 1 = block (for any reason, including internal errors — fails closed).
# A one-line human-readable reason is always printed to stdout.
#
# Usage:
#   push-review-gate.sh check <repo-root>
#   push-review-gate.sh range <repo-root>
#   push-review-gate.sh classify <repo-root>
#   push-review-gate.sh mark-passed <repo-root> [--findings-file <path>]
#
# `range` prints the commit range the gate treats as "what's about to be
# pushed", so callers that need to list or diff those commits (the
# pre-push-review skill) share this script's definition of it.
#
# `classify` prints `deployed` or `light`. A range is `light` only when every
# changed path is documentation, tests, or build/CI config — none of which
# ship in a deployed artifact — and `check` passes those pushes without a
# recorded review. Anything unrecognised counts as `deployed`, so a path the
# patterns below don't know about fails closed into requiring the review.
#
# `mark-passed` is only ever meant to be run by the `pre-push-review` skill,
# after it has shown the user its aggregated findings, the user has fixed or
# explicitly acknowledged them, and the user has walked through every commit
# in the range. The marker records those commit SHAs and `check` requires
# them to still match the range: the diff hash alone covers only the
# cumulative diff, so an amended message or reordered commits with the same
# net content would otherwise keep a pass for commits the user never saw.

set -euo pipefail
# Deliberately not -E (errtrace): with it set, this trap fires inside the
# subshell bash forks for command substitution even when the failing
# command's exit status is being handled normally (derive_range's
# `if mb=$(git merge-base ...)` expects merge-base to fail when there's no
# common ancestor) — errtrace propagates ERR into that subshell regardless
# of the outer if/&&/! exemptions, so it fires on routine, non-error
# failures too. Plain -e still fails closed on any real top-level error.
trap 'echo "push-review-gate.sh: internal error - failing closed"; exit 1' ERR

STATE_DIR="${CLAUDE_STATE_DIR:-$HOME/.claude/state}/pre-push-review"

usage() {
  echo "Usage: $(basename "$0") check <repo-root>" >&2
  echo "       $(basename "$0") range <repo-root>" >&2
  echo "       $(basename "$0") classify <repo-root>" >&2
  echo "       $(basename "$0") mark-passed <repo-root> [--findings-file <path>]" >&2
  exit 1
}

[ $# -ge 2 ] || usage
MODE="$1"
REPO_ARG="$2"
shift 2

REPO_ROOT=$(git -C "$REPO_ARG" rev-parse --show-toplevel 2>/dev/null) || {
  echo "not a git repo: $REPO_ARG"
  exit 1
}

# Deliberately NOT the same fallback as pre-push-audit/document-changes
# Step 1 ("merge-base HEAD main"): that self-merges when the checked-out
# branch IS main with no upstream configured (this user's normal
# commit-directly-to-main workflow, or any freshly-initialized repo before
# its first push) and silently produces an always-empty diff — tolerable
# for an advisory audit, fatal for a gate that's supposed to block a push.
derive_range() {
  if git -C "$REPO_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    echo '@{u}..HEAD'
    return
  fi
  local mb ref
  for ref in refs/remotes/origin/main refs/remotes/origin/master; do
    if git -C "$REPO_ROOT" rev-parse --verify "$ref" >/dev/null 2>&1 \
      && mb=$(git -C "$REPO_ROOT" merge-base HEAD "$ref" 2>/dev/null); then
      echo "${mb}..HEAD"
      return
    fi
  done
  # No upstream and no remote-tracking branch to compare against at all
  # (e.g. a repo that has never been pushed): review the entire current
  # history, since all of it is about to become the first push.
  local empty_tree
  empty_tree=$(git -C "$REPO_ROOT" hash-object -t tree /dev/null)
  echo "${empty_tree}..HEAD"
}

diff_hash() {
  git -C "$REPO_ROOT" diff "$1" | shasum -a 256 | awk '{print $1}'
}

range_commits() {
  git -C "$REPO_ROOT" rev-list --reverse "$1"
}

marker_path() {
  local id
  id=$(printf '%s' "$REPO_ROOT" | shasum -a 256 | awk '{print $1}')
  echo "$STATE_DIR/$id.json"
}

# Dependency manifests, lockfiles, Dockerfiles and deploy/infra config are
# deliberately absent: they change what ships, so they stay `deployed`.
# --no-renames lists both sides of a move, so renaming src/ code into docs/
# can't hide the deleted source path.
is_non_deployed_path() {
  case "$1" in
    *.md|*.mdx|*.rst|*.adoc|docs/*|doc/*|LICENSE*|CHANGELOG*) return 0 ;;
    test/*|tests/*|*/test/*|*/tests/*|__tests__/*|*/__tests__/*) return 0 ;;
    spec/*|*/spec/*|testdata/*|*/testdata/*|*/fixtures/*) return 0 ;;
    *_test.go|*_test.py|test_*.py|*/test_*.py|*.test.*|*.spec.*) return 0 ;;
    .github/*|.gitlab-ci.yml|.circleci/*|Makefile|*/Makefile|justfile) return 0 ;;
    .pre-commit-config.yaml|.editorconfig|.gitignore|.gitattributes) return 0 ;;
  esac
  return 1
}

classify_range() {
  local path
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    if ! is_non_deployed_path "$path"; then
      echo deployed
      return
    fi
  done < <(git -C "$REPO_ROOT" diff --name-only --no-renames "$1")
  echo light
}

case "$MODE" in
  range)
    derive_range
    ;;

  classify)
    classify_range "$(derive_range)"
    ;;

  check)
    RANGE=$(derive_range)
    if [ "$(classify_range "$RANGE")" = light ]; then
      echo "range $RANGE changes only docs, tests, or build config - no /pre-push-review needed"
      exit 0
    fi
    HASH=$(diff_hash "$RANGE")
    MARKER=$(marker_path)

    if [ ! -f "$MARKER" ]; then
      echo "no /pre-push-review run recorded for $REPO_ROOT - run /pre-push-review first"
      exit 1
    fi

    STORED_HASH=$(jq -r '.diff_hash // empty' "$MARKER")
    PASSED=$(jq -r '.passed // false' "$MARKER")

    if [ "$STORED_HASH" != "$HASH" ]; then
      echo "diff has changed since the last /pre-push-review run (range $RANGE) - re-run it"
      exit 1
    fi
    if ! jq -e 'has("walked_commits")' "$MARKER" >/dev/null; then
      echo "last /pre-push-review run predates the commit walkthrough - re-run it"
      exit 1
    fi
    STORED_COMMITS=$(jq -r '.walked_commits[]' "$MARKER")
    CURRENT_COMMITS=$(range_commits "$RANGE")
    if [ "$STORED_COMMITS" != "$CURRENT_COMMITS" ]; then
      echo "commits in range $RANGE changed since the last commit walkthrough - re-run /pre-push-review"
      exit 1
    fi
    if [ "$PASSED" != "true" ]; then
      echo "last /pre-push-review run for this diff did not pass"
      exit 1
    fi

    echo "pre-push-review passed for $REPO_ROOT (range $RANGE)"
    exit 0
    ;;

  mark-passed)
    FINDINGS_FILE=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --findings-file)
          FINDINGS_FILE="$2"
          shift 2
          ;;
        *)
          usage
          ;;
      esac
    done

    RANGE=$(derive_range)
    HASH=$(diff_hash "$RANGE")
    COMMITS=$(range_commits "$RANGE")
    mkdir -p "$STATE_DIR"
    MARKER=$(marker_path)
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if [ -n "$FINDINGS_FILE" ] && [ -f "$FINDINGS_FILE" ]; then
      jq -n --arg repo "$REPO_ROOT" --arg hash "$HASH" --arg range "$RANGE" \
        --arg ts "$TIMESTAMP" --arg commits "$COMMITS" --rawfile findings "$FINDINGS_FILE" \
        '{repo_root: $repo, diff_hash: $hash, range: $range, timestamp: $ts, passed: true, walked_commits: ($commits | split("\n") | map(select(. != ""))), acknowledged_findings: $findings}' \
        > "$MARKER"
    else
      jq -n --arg repo "$REPO_ROOT" --arg hash "$HASH" --arg range "$RANGE" \
        --arg ts "$TIMESTAMP" --arg commits "$COMMITS" \
        '{repo_root: $repo, diff_hash: $hash, range: $range, timestamp: $ts, passed: true, walked_commits: ($commits | split("\n") | map(select(. != ""))), acknowledged_findings: null}' \
        > "$MARKER"
    fi

    echo "pre-push-review marker written for $REPO_ROOT (diff hash ${HASH:0:12}...)"
    ;;

  *)
    usage
    ;;
esac
