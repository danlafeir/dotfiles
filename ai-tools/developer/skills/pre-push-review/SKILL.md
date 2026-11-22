---
name: pre-push-review
description: Required before pushing changes to deployed code (docs-, test-, and build-config-only pushes skip it). Runs the required security, documentation, and design/correctness review agents — plus optional performance and database-integrity agents on request — over local commits before a push, then walks the user through every commit's diff one at a time — with the option to question any diff in the context of the surrounding code — and only then records a pass/fail decision that the push-review gate (a Claude Code PreToolUse hook and a global git pre-push hook) checks before allowing `git push` to run. Report-only — it never edits files or folds anything into a commit, since findings like "this migration has no rollback" can't be auto-applied the way a dependency bump can. Use when the user asks to "review before I push", "run the push gate", "check my changes before pushing", "walk me through my commits", or runs `/pre-push-review` — not for dependency CVEs or lint findings (that's `pre-push-audit`) and not for reuse/simplification cleanups (that's the built-in `/code-review`).
---

# /pre-push-review

Required when a push changes deployed code; skipped for pushes that only
touch documentation, tests, or build/CI config. For a push that needs it,
runs three required read-only review agents — security, documentation, and
code design/correctness — over the commits about to be pushed (performance
and database-integrity agents are optional extras), then walks you through every commit's diff yourself, one at a time, and records
whether the push-review gate should let the push through. The agents' default
outcome is "nothing found"; the walkthrough is never skipped — the gate only
passes once you've been through every commit in the range.

This skill never changes code. Its one write is the first-run NFR file
(Step 2), which it commits on its own so the walkthrough covers it. If a finding or a flagged commit needs a
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

  (That's the deployed location `bootstrap.sh` symlinks to — this skill
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

## Step 2 — decide whether review applies, and which agents to run

First ask the gate whether this push needs a review at all — it owns the
definition, and `check` uses the same answer, so the skill and the gate can't
disagree:

```
~/.claude/hooks/push-review-gate.sh classify <repo-root>
```

- **`light`** — every changed path is documentation, tests, or build/CI
  config (including lockfiles and Dockerfiles), so nothing deployed changes. Tell the user no review is required
  and the gate will pass this push on its own. Do not run agents, do not walk
  the commits, do not run `mark-passed`; stop here. (If the user explicitly
  asked for a review of a light range anyway, continue as for `deployed`.)
- **`deployed`** — at least one path may ship (source, dependency manifests,
  deploy/infra config, or anything the classifier doesn't recognise). Continue: this review is required.

**First run — declare the repo's non-functional requirements.** Only reached
for a `deployed` push, so a documentation-only (or test/build-only) push never
triggers it and the config never turns a light push into a reviewed one. If
`docs/nfrs.md` exists, or `git config --get push-review.nfrs` is `false`
(the user opted this repo out), skip this block. Otherwise this is the repo's
first review: work out which NFRs matter, and save them so every later review
checks against them.

1. **Inspect the repo.** Read the manifests and layout (`package.json`,
   `pyproject.toml`, `go.mod`, `Dockerfile`, `*.tf`, framework configs), the
   README, CI and deploy config, and `git log --oneline -20`. Decide what it
   is (often several): public website, HTTP API, internal service, data
   pipeline or migrations, CLI or library, infrastructure-as-code, app,
   tooling. Note concrete facts to cite: where URLs are defined, where logs
   and metrics go, where secrets are read, what runs on a schedule, how it is
   deployed.
2. **Propose candidates** from this menu, only those the evidence supports
   (roughly eight at most), each with a one-line reason citing the file that
   told you:

   | NFR | Applies when | Typical risk in a diff |
   |---|---|---|
   | Availability and rollback | anything deployed | change that cannot be rolled back, a deploy-order dependency, a new single point of failure |
   | URL and API stability | public site or API | a route renamed or removed without a redirect, a response field removed, a changed status code |
   | SEO | public website | lost title/description, canonical or sitemap changes, noindex, links to moved pages |
   | Security and privacy | auth, user data, secrets, third-party calls | new PII stored or logged, a widened permission, a new outbound domain, a token in a URL |
   | Performance | request paths, queries, bundles | an unbounded query, a heavier page or bundle, a new blocking call on a hot path |
   | Reliability of dependencies | external calls, queues, webhooks | no timeout, unbounded retry, a non-idempotent handler |
   | Data integrity | schemas, migrations, pipelines | a destructive migration, no backfill, a lossy transform |
   | Observability | services, jobs | a new failure path with no log or metric, an alert that will now fire or go silent |
   | Accessibility | UI | missing labels or alt text, keyboard traps, contrast |
   | Compatibility | libraries, CLIs, browsers, OSes | a breaking public interface, a dropped platform or version |
   | Cost | cloud resources, paid APIs | a new always-on resource, an uncapped call to a metered API |
   | Maintainability | any | undocumented operational steps, a new manual runbook step |

3. **Confirm.** AskUserQuestion (multiSelect, up to 4 options per question,
   several questions in one call): "Which of these NFRs should every push to
   this repo be checked against?" Selected = on the list. Include an option
   in the first question, "None — don't ask again for this repo", which runs
   `git config push-review.nfrs false` and skips the rest of this block. Then
   ask once whether any repo-specific requirement is missing and whether any
   has a concrete target ("p95 under 300ms", "no URL change without a 301").
   A target the user gives goes in verbatim; never invent one.
4. **Write `docs/nfrs.md`** (create `docs/` if needed), one `##` section per
   NFR in exactly this shape:

   ```markdown
   # Non-functional requirements

   Checked by `/pre-push-review` (via `nfr-review-agent`) on every push that
   changes deployed code. Edit this file to revise the list.

   ## URL stability

   - **Why it matters here:** <one line, repo-specific>
   - **Target:** <the user's number or rule, or "none declared">
   - **How to check a diff:** <real paths, commands or signals from this repo>
   - **Out of scope:** <what the reviewer should not flag>
   ```

   No generic advice: "How to check" must name things that exist in this repo.
5. **Commit it alone** per the global commit conventions (subject like
   "Declare non-functional requirements for pre-push review", body with the
   value, the docs change and the non-functional impact, `Tested: not run`).
   Then re-run `push-review-gate.sh range` and re-list the commits: the new
   commit is part of what is about to be pushed, so Step 5 must walk it and
   `nfr-review-agent` runs against the file this run just wrote. Do not push.

Get the changed files with `git diff --name-only --diff-filter=ACMR <range>`.

**Required agents** — always run for a `deployed` range:

- **`security-review-agent`**
- **`documentation-agent`** — report-only here: it proposes doc updates for
  public-interface changes and writes nothing, same as under
  `document-changes`. Its default outcome is zero proposals. Pass it the repo
  root and commit list like the others; its proposals are findings for Step 4,
  and applying them is the user's call afterward (or via `document-changes`).
- **`design-review-agent`** — code design and correctness.

**Per-repo agent** — runs whenever `docs/nfrs.md` exists at the repo root,
including right after the first-run setup above:

- **`nfr-review-agent`** — checks the range against that file (availability,
  URL stability, SEO, security/privacy, performance, and whatever else the
  repo listed). If the file is absent (the user opted out), skip the agent
  and say so in the final report.

**Optional agents** — not part of the required review. Run one only when
`$ARGUMENTS` asks for it (`performance`, `db`) or the user says so; otherwise
skip it and say so in the report. Use these heuristics to *suggest* it in the
report when it would plausibly have mattered, without running it:

- **`db-integrity-agent`** — worth suggesting if a changed path looks like a
  migration or schema file: `migrations/`, `db/migrate/`, `alembic/versions/`,
  `prisma/schema.prisma`, `schema.rb`, `**/migrations/*.py`, or a `.sql`
  file under a directory whose name contains "migrat".
- **`performance-review-agent`** — worth suggesting if real source files
  changed that touch queries, loops over external input, or async/IO paths.

Say plainly in the final report which optional agents were skipped (and
which you'd suggest running) rather than silently omitting them.

## Step 3 — spin up the review agents

Call the Agent tool once per agent selected in Step 2 (the three required
ones, `nfr-review-agent` when `docs/nfrs.md` exists, plus any optional ones
that were requested), **in a single message
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

   **Merge commits** (`git show --no-patch --format=%P <sha>` lists two or
   more parents) need different commands: `git show` prints a combined diff
   that is *empty* for a clean merge, so the user would get a file list, a
   blank diff, and an approval prompt for a commit they never saw. Instead
   fetch `git log --oneline <sha>^1..<sha>` (the commits it brings in) and
   `git diff --stat <sha>^1 <sha>` / `git diff <sha>^1 <sha>` (everything it
   changes relative to the branch it landed on), and say in the heading that
   it's a merge.

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

Report: whether the push was classified `light` (and so skipped) or
`deployed`, which agents ran (and whether the repo has `docs/nfrs.md`) (and which optional ones were skipped, and why),
what each found, what the user chose to fix vs. acknowledge, how many
commits were approved and which were flagged (or that the walkthrough was
stopped early), and whether a passing marker was written. If the push is
still blocked, say so plainly and name the specific findings and flagged
commits blocking it.
