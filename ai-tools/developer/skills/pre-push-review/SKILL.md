---
name: pre-push-review
description: Runs security, performance, database-integrity, and design/correctness review agents over local commits before a push, then records a pass/fail decision that the push-review gate (a Claude Code PreToolUse hook and a global git pre-push hook) checks before allowing `git push` to run. Report-only — it never edits files or folds anything into a commit, since findings like "this migration has no rollback" can't be auto-applied the way a dependency bump can. Use when the user asks to "review before I push", "run the push gate", "check my changes before pushing", or runs `/pre-push-review` — not for dependency CVEs or lint findings (that's `pre-push-audit`) and not for reuse/simplification cleanups (that's the built-in `/code-review`).
---

# /pre-push-review

Runs four read-only review agents — security, performance, database
integrity, and design/correctness — over the commits about to be pushed, and
records whether the push-review gate should let the push through. The
default outcome is "nothing found, pass recorded" — only real findings
require a decision from you.

This skill never writes to the repo. If a finding needs a code change, you
make that change and re-run this skill afterward — the gate's record is
keyed to the exact diff, so a changed diff always needs a fresh pass.

## Step 0 — sanity check

Confirm you're in a git repo (`git rev-parse --is-inside-work-tree`). If
not, tell the user this skill needs a git repo and stop. No dirty-worktree
check is needed — this skill never touches the working tree.

## Step 1 — pick the commit range

Parse `$ARGUMENTS`:
- A commit SHA, range (`abc123..def456`), or `HEAD` → use it verbatim.
- Nothing given → derive a default:
  1. If an upstream is configured (`git rev-parse --abbrev-ref --symbolic-full-name @{u}` succeeds), use `@{u}..HEAD`.
  2. Otherwise, if `refs/remotes/origin/main` or `refs/remotes/origin/master` exists, use `<merge-base of HEAD and that ref>..HEAD`.
  3. Otherwise (no upstream and no remote-tracking branch at all — e.g. a repo that's never been pushed), use the full history: diff against the empty tree.

  **Do not** fall back to `git merge-base HEAD main` against a *local*
  branch named `main`/`master` the way `pre-push-audit`/`document-changes`
  do — if the checked-out branch itself is `main` with no upstream (the
  normal state for this user's commit-directly-to-main workflow before a
  remote is configured), that self-merge-bases and silently yields an empty
  range every time. `ai-tools/developer/hooks/push-review-gate.sh` uses the corrected
  logic above; keep this skill's range derivation in sync with it
  conceptually — Step 6 delegates the actual hashing to that script, so
  they can't drift on what "the diff" means, but Step 1's range still
  needs to match it for the commit list and path-scoping below to reflect
  the true diff.

List the commits: `git log --reverse --format='%H %s' <range>`. If the list
is empty, tell the user there's nothing local to review and stop.

## Step 2 — decide which agents to run

Get the changed files: `git diff --name-only --diff-filter=ACMR <range>`.
These are heuristics, not a hard science — tune them over time rather than
treating them as exact:

- **`design-review-agent`** — always run. Correctness issues can show up
  anywhere, and this agent is cheap.
- **`db-integrity-agent`** — only if at least one changed path looks like a
  migration or schema file: `migrations/`, `db/migrate/`, `alembic/versions/`,
  `prisma/schema.prisma`, `schema.rb`, `**/migrations/*.py`, or a `.sql`
  file under a directory whose name contains "migrat".
- **`security-review-agent`** and **`performance-review-agent`** — run
  unless every changed file is docs/asset/fixture-shaped (`*.md`, `docs/**`,
  images, `test/fixtures/**`, lockfiles with no accompanying manifest
  change). Run them whenever at least one real source file changed.

If a category's trigger condition isn't met, don't call that agent at all —
say so plainly in the final report rather than silently omitting it.

## Step 3 — spin up the review agents

Call the Agent tool once per agent selected in Step 2, **in a single message
with multiple tool calls** (they're independent, read-only investigations —
same pattern as running several Explore agents in parallel). Give each one
the repo root (`git rev-parse --show-toplevel`) and the commit list from
Step 1. Let each agent read the diffs itself — don't pre-summarize.

## Step 4 — handle a clean result

If every invoked agent reports zero findings, tell the user which agents
ran and that nothing turned up, then run:

```
~/.claude/hooks/push-review-gate.sh mark-passed <repo-root>
```

(That's the deployed location `bootstrap-mac.sh` symlinks to — this skill runs
inside whatever project repo you're reviewing, not inside the dotfiles repo,
so the source-tree path `ai-tools/developer/hooks/...` won't exist there.)

Report the result and stop. Don't ask a confirmation question with nothing
to confirm — this mirrors `document-changes`' "zero proposals" handling.

## Step 5 — confirm findings before deciding

If there's at least one finding, show all of them (grouped by agent) before
asking anything.

Use AskUserQuestion (up to 4 options per question, multiSelect on, group by
agent if there are more than 4, ask multiple questions in one call rather
than guessing which ones matter): "Which of these do you want to address
before pushing?" Selecting a finding means *not yet* — you plan to fix it.
Leaving a finding unselected means you've reviewed it and are explicitly
accepting the push as-is despite it — the same "unselected = accepted"
convention `pre-push-audit` and `document-changes` already use, just
inverted in meaning (there, unselected = declined; here, unselected =
acknowledged-and-fine).

## Step 6 — record the decision

- **Anything was selected** (the user wants to fix something first): do
  **not** run `mark-passed`. Tell the user which findings remain
  outstanding and that the push stays blocked until they're resolved — make
  the fix, then re-run `/pre-push-review`, which will see the new diff and
  review it fresh.
- **Nothing was selected** (everything's acknowledged): write the
  acknowledged findings (the full list from Step 5, as shown to the user)
  to a scratch file and run:

  ```
  ~/.claude/hooks/push-review-gate.sh mark-passed <repo-root> --findings-file <scratch-file>
  ```

  This records a passing marker for the current diff, including the
  acknowledged findings as an audit trail of what was waived and why.

## Step 7 — wrap up

Report: which agents ran (and which were skipped, per Step 2, and why),
what each found, what the user chose to fix vs. acknowledge, and whether a
passing marker was written. If the push is still blocked, say so plainly
and name the specific findings blocking it.
