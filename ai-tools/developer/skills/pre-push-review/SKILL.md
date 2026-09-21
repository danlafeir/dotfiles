---
name: pre-push-review
description: Runs security, performance, database-integrity, and design/correctness review agents over local commits before a push, then walks the user through every commit's diff one at a time — with the option to question any diff in the context of the surrounding code — and only then records a pass/fail decision that the push-review gate (a Claude Code PreToolUse hook and a global git pre-push hook) checks before allowing `git push` to run. Report-only — it never edits files or folds anything into a commit, since findings like "this migration has no rollback" can't be auto-applied the way a dependency bump can. Use when the user asks to "review before I push", "run the push gate", "check my changes before pushing", "walk me through my commits", or runs `/pre-push-review` — not for dependency CVEs or lint findings (that's `pre-push-audit`) and not for reuse/simplification cleanups (that's the built-in `/code-review`).
---

# /pre-push-review

Runs four read-only review agents — security, performance, database
integrity, and design/correctness — over the commits about to be pushed, then
walks you through every commit's diff yourself, one at a time, and records
whether the push-review gate should let the push through. The agents' default
outcome is "nothing found"; the walkthrough is never skipped — the gate only
passes once you've been through every commit in the range.

This skill never writes to the repo. If a finding or a flagged commit needs a
code change, you make that change and re-run this skill afterward — the
gate's record is keyed to the exact diff and commit list, so a changed diff
or rewritten commits always need a fresh pass and a fresh walkthrough.

## Step 0 — sanity check

Confirm you're in a git repo (`git rev-parse --is-inside-work-tree`). If
not, tell the user this skill needs a git repo and stop. No dirty-worktree
check is needed — this skill never touches the working tree.

## Step 1 — pick the commit range

Parse `$ARGUMENTS`:
- A commit SHA, range (`abc123..def456`), or `HEAD` → use it verbatim.
- Nothing given → ask the gate script, which owns the definition of "what's
  about to be pushed" so the review and the gate can't disagree on it:

  ```
  ~/.claude/hooks/push-review-gate.sh range <repo-root>
  ```

  (That's the deployed location `bootstrap-mac.sh` symlinks to — this skill
  runs inside whatever project repo you're reviewing, not inside the
  dotfiles repo, so the source-tree path `ai-tools/developer/hooks/...`
  won't exist there.)

  **Don't** derive it yourself with `git merge-base HEAD main` the way
  `pre-push-audit`/`document-changes` do — if the checked-out branch itself
  is `main` with no upstream (the normal state for this user's
  commit-directly-to-main workflow before a remote is configured), that
  self-merge-bases and silently yields an empty range every time.

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

## Step 4 — confirm findings before continuing

If every invoked agent reports zero findings, tell the user which agents
ran and that nothing turned up, then go straight to Step 5. Don't ask a
confirmation question with nothing to confirm — this mirrors
`document-changes`' "zero proposals" handling.

Otherwise show all findings (grouped by agent) before asking anything.

Use AskUserQuestion (up to 4 options per question, multiSelect on, group by
agent if there are more than 4, ask multiple questions in one call rather
than guessing which ones matter): "Which of these do you want to address
before pushing?" Selecting a finding means *not yet* — you plan to fix it.
Leaving a finding unselected means you've reviewed it and are explicitly
accepting the push as-is despite it — the same "unselected = accepted"
convention `pre-push-audit` and `document-changes` already use, just
inverted in meaning (there, unselected = declined; here, unselected =
acknowledged-and-fine).

If anything was selected, skip Step 5 and go to Step 6: the fix will change
the diff, so a walkthrough now would be reviewing commits that are about to
change.

## Step 5 — walk the user through every commit

This is the human review the gate exists to guarantee: the user sees each
commit's diff, in order, and can question any of them before approving it.
The agents catch patterns; this catches "I didn't mean to commit that" and
"I don't understand why this changed."

**Which commits.** Always the gate's range, never `$ARGUMENTS`:

```
git rev-list --reverse "$(~/.claude/hooks/push-review-gate.sh range <repo-root>)"
```

`mark-passed` records exactly this list and the gate re-derives it at push
time, so walking a narrower list would let the marker claim commits the user
never saw. (If `$ARGUMENTS` named a different range, the agents reviewed that
range but the walkthrough still covers this one.) Oldest first; say the count
up front ("7 commits, oldest first").

**Show each diff in your own message.** Bash output isn't reliably visible to
the user, so a `git show` in a tool call would put the diff in front of you
and nothing in front of them. Fetch with Bash, then reproduce it in your
reply text.

For each commit *i* of *N*:

1. **Fetch.** `git show --no-patch --format='%h %s%n%an, %ad%n%n%b' --date=short <sha>`
   for the header and `git show --stat --format= <sha>` for the stat. If the
   stat shows more than ~400 changed lines, fetch the patch per file
   (`git show --format= <sha> -- <path>`) rather than all at once;
   otherwise `git show --format= <sha>`.

2. **Post one message per commit** (a very large one may span several
   consecutive messages, one or more files each): a heading with position,
   short SHA and subject (`### Commit 3/7 — a1b2c3d Add retry to fetch`),
   author/date and body when there is one, the stat, then the patch in a
   `diff` fence. Rules:
   - **Verbatim.** Don't paraphrase, reorder, or trim hunks — the user is
     relying on this as the review artifact.
   - **Fence longer than any backtick run in the patch** (usually four
     backticks). Diffs of markdown, skills, and docs routinely contain
     triple-backtick fences that would close a shorter one early.
   - **One permitted elision:** lockfiles, generated/vendored files, and
     binary files. Show their stat line and write "content elided
     (lockfile)" so nothing is hidden silently; show the content if asked.
   - **No unsolicited commentary or summary.** The user asked to read the
     diff; explanation is opt-in, via the question in step 3.

3. **Ask** with AskUserQuestion — one question, header `Commit 3/7`, options:
   - "Looks good — next commit" (on the last commit: "Looks good — finish")
   - "Ask a question"
   - "Flag this commit"

   Free text via "Other" is welcome too: treat it as a question about this
   commit, or as "stop" if that's what it says.

4. **Handle the answer:**
   - **Looks good** → next commit.
   - **Ask a question** → if the question hasn't been typed yet, end your
     turn with a plain "What would you like to know about this commit?" and
     wait. Answer it (below), then repeat step 3 for the same commit — there
     may be follow-ups.
   - **Flag** → remember `<short-sha> <subject>` plus any concern the user
     voiced, and keep going: they can flag several commits and fix them
     together in one pass.
   - **Stop** → end the walkthrough and go to Step 6; nothing gets recorded.

**Answering in context.** A diff rarely explains itself, so ground answers
in the repo:
- Read touched files as they were at that commit (`git show <sha>:<path>`),
  not the working tree — later commits in the range may have changed the
  same code; if they did, say so.
- Look at callers and usages (Grep/Read), the file's history
  (`git log -p -- <path>`, `git blame`), and whether the commit message's
  stated intent matches what the diff actually does.
- Separate what you verified from what you inferred.
- Stay read-only. If the answer turns up a problem, say so and suggest
  flagging it; don't fix it here.

## Step 6 — record the decision

- **Record nothing** if a finding was selected to fix (Step 4), any commit
  was flagged, or the user stopped the walkthrough. Do **not** run
  `mark-passed`. Tell the user what blocks the push — the selected findings
  and/or the flagged commits with any concern they gave — and that it stays
  blocked until they make the changes and re-run `/pre-push-review`, which
  will review the new diff fresh and walk it again.
- **Otherwise** — every commit approved, every finding absent or
  acknowledged — run:

  ```
  ~/.claude/hooks/push-review-gate.sh mark-passed <repo-root>
  ```

  If the user acknowledged any findings, first write the full list from
  Step 4 (as shown to the user) to a scratch file and add
  `--findings-file <scratch-file>`, so the marker keeps an audit trail of
  what was waived and why. The marker records the diff hash and the commit
  SHAs walked in Step 5.

## Step 7 — wrap up

Report: which agents ran (and which were skipped, per Step 2, and why),
what each found, what the user chose to fix vs. acknowledge, how many
commits were approved and which were flagged (or that the walkthrough was
stopped early), and whether a passing marker was written. If the push is
still blocked, say so plainly and name the specific findings and flagged
commits blocking it.
