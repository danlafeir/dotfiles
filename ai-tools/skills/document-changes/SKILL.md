---
name: document-changes
description: Checks local git commits for changes to a project's public interface and proposes keeping README.md, docs/, and API specs (OpenAPI etc.) in sync — written for a reader who only knows the public interface, with deeper dives for genuinely complex concepts. Spins up the `documentation-agent` subagent to draft proposals, always confirms with the user before writing anything (default is zero doc changes, to avoid drowning the project in documentation), then applies what's approved and folds it into the right commit. Use when the user asks to "document my changes", "update the docs for this", "sync docs with my commits", "keep the docs current", or runs `/document-changes`.
---

# /document-changes

Keeps documentation honest about what local commits actually changed, without
turning every commit into a documentation commit. The default outcome is "no
changes needed" — only public-interface changes clear the bar, and nothing
gets written without the user picking it.

This is a deliberate, scoped exception to "never batch unrelated changes into
one commit": docs describing a change belong *with* that change, so folding
approved doc edits back into the commit they document is the point, not a
violation of commit discipline.

## Step 0 — sanity checks

Confirm you're in a git repo (`git rev-parse --is-inside-work-tree`). If not,
tell the user this skill needs a git repo and stop.

## Step 1 — pick the commit range

Parse `$ARGUMENTS`:
- A commit SHA, range (`abc123..def456`), or `HEAD` → use it verbatim.
- Nothing given → derive a default:
  1. If an upstream is configured (`git rev-parse --abbrev-ref --symbolic-full-name @{u}` succeeds), use `@{u}..HEAD`.
  2. Otherwise, try `git merge-base HEAD main` or `git merge-base HEAD master` and use `<merge-base>..HEAD`.
  3. If neither applies (no upstream, no main/master, or nothing ahead), fall back to just the last commit, `HEAD~1..HEAD`.

List the commits: `git log --reverse --format='%H %s' <range>`. If the list
is empty, tell the user there's nothing local to document and stop.

## Step 2 — mark which commits are safe to amend

For each commit, determine whether it's already pushed:

- No upstream configured → nothing is pushed; all commits are amend-safe.
- Upstream exists → a commit is **pushed** if `git merge-base --is-ancestor <sha> @{u}` succeeds. Pushed commits must never be amended — amending published history forces a rewrite everyone downstream has to deal with. Track this per commit; you'll need it in Step 5.

## Step 3 — spin up the documentation agent

Call the Agent tool with `subagent_type: "documentation-agent"`. Give it the
repo root (`git rev-parse --show-toplevel`) and the commit list from Step 1
(sha + subject). Let it read the diffs itself — don't pre-summarize the
changes for it.

## Step 4 — handle the result

If the agent reports zero proposals, tell the user which commits were
reviewed and that no documentation changes were needed. Stop here — don't
ask a confirmation question with nothing to confirm.

Otherwise, summarize each proposal to the user in a few words (file + the one-line WHY) before asking anything, so the confirmation step isn't the first time they see what's proposed.

## Step 5 — confirm before writing anything

This is the gate that keeps documentation from piling up — the default is
**no changes**, and every proposal needs explicit approval.

Use AskUserQuestion to let the user pick which proposals to apply (up to 4
options per question, multiSelect on; group proposals by target file if
there are more than 4, and ask multiple questions in one call rather than
guessing which ones matter). If a proposal targets a commit that is not
HEAD and not yet pushed (a mid-stack commit), also ask separately whether to
rebase the doc change into that commit or just add it as a new commit at
HEAD — default to recommending the new commit, since rewriting non-HEAD
history is higher-risk than it looks.

Anything not selected is dropped. If nothing is selected, say so and stop —
that's a normal, successful outcome, not a failure.

## Step 6 — apply approved proposals

For each approved proposal: read the target file first (if it exists), find
the right insertion point, and edit surgically — insert or update the
proposed section without clobbering unrelated content. Create the file only
if the proposal says "new file."

## Step 7 — fold into commits

Group approved proposals by their originating commit, then per commit:

- **HEAD, unpushed** — stage the files and `git commit --amend --no-edit`.
- **Mid-stack, unpushed, user chose rebase** — use `git commit --fixup=<sha>` followed by `git rebase -i --autosquash <sha>~1` (non-interactively: `GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash <sha>~1`).
- **Mid-stack, unpushed, user chose new commit** — fall through to the pushed case below.
- **Pushed** — never amend. Make a new commit (`docs: <short description>`, mentioning which commit it documents) and tell the user explicitly that the source commit was already pushed, so a new commit was used instead of an amend.

Batch multiple approved files targeting the same commit into a single
amend/commit rather than one per file.

**Never push automatically.** Pushing — even a plain fast-forward push after
an unpushed amend — is a separate, explicit action left to the user's normal
workflow.

## Step 8 — wrap up

Report: which commits were reviewed, which were amended vs. got new "docs:"
commits (and why, if a pushed commit forced the new-commit path), and which
proposals the user declined. Remind the user nothing was pushed.
