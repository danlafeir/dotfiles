---
name: pre-push-audit
description: Scans a project's dependencies for known vulnerabilities and runs static analysis over files changed in local commits, before you push. Spins up the `pre-push-audit-agent` subagent to find real advisories (never recalled from memory) and lint findings; confirms with you before touching anything; applies approved dependency bumps, runs the test suite, and folds the fix into the right commit (amend, fixup, or a new `fix(deps):` commit — never a pushed commit). Static analysis findings are reported only, not auto-fixed. Use when the user asks to "audit dependencies", "check for vulnerable packages", "scan for CVEs", "run static analysis on my changes", or wants a pre-push security check on packages — not for reviewing your own code's logic for vulnerabilities (that's the `security-review` skill).
---

# /pre-push-audit

Checks two things before a push: whether any dependency in the project has a
known vulnerability, and whether the files touched by local commits trip any
static analysis tool. It proposes; you approve; only then does it touch
anything. The default outcome for static analysis is "reported, not fixed" —
this skill's write path is for dependency bumps only.

## Step 0 — sanity checks

Confirm you're in a git repo (`git rev-parse --is-inside-work-tree`). If not,
tell the user this skill needs a git repo and stop.

Check `git status --porcelain`. If it's non-empty, stop and ask the user to
commit or stash (`git stash -u`) first. Step 8 stages and amends whatever is
in the index at fold time — an unrelated staged or dirty file would get
silently absorbed into a dependency-fix commit.

## Step 1 — pick the commit range

Parse `$ARGUMENTS`:
- A commit SHA, range (`abc123..def456`), or `HEAD` → use it verbatim.
- Nothing given → derive a default:
  1. If an upstream is configured (`git rev-parse --abbrev-ref --symbolic-full-name @{u}` succeeds), use `@{u}..HEAD`.
  2. Otherwise, try `git merge-base HEAD main` or `git merge-base HEAD master` and use `<merge-base>..HEAD`.
  3. If neither applies, fall back to just the last commit, `HEAD~1..HEAD`.

List the commits: `git log --reverse --format='%H %s' <range>`. If the list
is empty, tell the user there's nothing local to audit and stop.

The dependency scan itself covers the whole project regardless of range (see
the agent's Part 1) — the range only determines which commits are eligible
fold targets and which files static analysis covers.

## Step 2 — mark which commits are safe to amend

For each commit, determine whether it's already pushed:

- No upstream configured → nothing is pushed; all commits are amend-safe.
- Upstream exists → a commit is **pushed** if `git merge-base --is-ancestor <sha> @{u}` succeeds. Pushed commits must never be amended. Track this per commit.

## Step 3 — spin up the audit agent

Call the Agent tool with `subagent_type: "pre-push-audit-agent"`. Give it the
repo root (`git rev-parse --show-toplevel`) and the commit list from Step 1
(sha + subject). Let it run its own scans — don't pre-summarize the diff or
the dependency tree for it.

## Step 4 — handle the result

If the agent reports zero dependency findings and zero static analysis
findings, tell the user what was scanned (ecosystems, tools, file count) and
that nothing turned up. Stop here.

Otherwise, show the user both sections of the agent's report before asking
anything: the dependency findings and the static analysis findings. The
static analysis section is informational from here on — you will not ask to
apply fixes for it, only report it in the final summary.

## Step 5 — confirm which dependency bumps to apply

This is the gate that keeps a scan from turning into an unreviewed write.
Every dependency bump needs explicit approval.

Use AskUserQuestion to let the user pick which findings to fix (up to 4
options per question, multiSelect on; group by ecosystem if there are more
than 4, ask multiple questions in one call rather than guessing which ones
matter). Show each option as `<package> <current> → <fixed>` with the
advisory id.

Anything not selected is dropped. If nothing is selected, say so, remind the
user of the static analysis findings from Step 4, and stop — that's a
normal, successful outcome, not a failure.

## Step 6 — apply approved bumps

For each approved finding, bump the package using the ecosystem's own
tooling rather than hand-editing the lockfile:
- npm/pnpm/yarn → `npm install <pkg>@<fixed>` (or the pnpm/yarn equivalent) so the lockfile regenerates correctly
- Python → `pip install -U "<pkg>==<fixed>"` and regenerate the lock (`poetry update <pkg>` / `pip-compile` as the project uses) — this mutates whatever Python environment is currently active, so confirm a project venv is activated before running it, not the system interpreter
- Go → `go get <pkg>@<fixed>` then `go mod tidy`
- Rust → `cargo update -p <pkg> --precise <fixed>`
- Ruby → `bundle update <pkg>`
- PHP → `composer update <pkg>`

Batch all approved bumps in the same ecosystem into one tool invocation
where the tool supports it, rather than one process spawn per package.

## Step 7 — run tests before folding anything

Their commit discipline is "keep main green." A dependency bump that hasn't
been test-run is not safe to fold into history.

Detect the project's test command (`package.json` `scripts.test`, a `Makefile`
`test` target, `pytest`/`go test ./...`/`cargo test` as applicable) and run
it. If tests pass, continue to Step 8. If tests fail:
- Stop. Do not commit or amend.
- Leave the bump changes in the working tree (uncommitted) so the user can
  inspect them.
- Report which bump broke which test, and let the user decide whether to
  investigate, pin a different version, or back out — since `git status` is
  clean going into Step 6 (checked in Step 0), reverting is a plain
  `git checkout -- <manifest> <lockfile>` at this point, but confirm with
  the user before running it rather than doing it unasked.

## Step 8 — fold into commits

Resolve fold targets **per manifest/lockfile pair, not per package.**
Multiple approved bumps against the same `package.json`/lockfile land in the
same file; `git add` can't split them by package, and lockfile hunks for
different packages are often entangled by transitive resolution anyway. So:

1. For each manifest/lockfile pair with at least one approved bump, check
   whether any commit **in the audited range** touched that pair:
   `git log --format='%H' <range> -- <manifest>`.
2. If none did → the whole pair's bumps are a pre-existing-vulnerability fix,
   unrelated to what's being pushed. Always a new commit — bundling it into
   someone's feature commit is exactly the batching their commit discipline
   forbids.
3. If commits in range did touch the pair, take the most recent one that did
   and classify it same as before:
   - **HEAD + unpushed** — stage the pair and `git commit --amend --no-edit`.
   - **Mid-stack + unpushed** — ask the user (AskUserQuestion) whether to
     `git commit --fixup=<sha>` + `GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash <sha>~1`, or land it as a new commit instead — default to
     recommending the new commit, since rewriting non-HEAD history is
     higher-risk than it looks. If you do rebase, re-derive any SHAs you
     computed for other manifest/lockfile pairs afterward — the rebase
     changes them.
   - **Already pushed** — never amend. Fall through to a new commit.

New-commit message format: `fix(deps): bump <pkg1>, <pkg2>, ... (<advisory ids>)`.

Process one manifest/lockfile pair fully (fold, and re-derive SHAs if you
rebased) before moving to the next.

**Never push automatically.** Pushing is a separate, explicit action left to
the user's normal workflow — that holds even though this skill's whole
purpose is prep for a push.

## Step 9 — wrap up

Report: what was scanned (ecosystems + tools, changed-file count + static
analysis tools), which dependency findings were fixed (amended / fixup /
new commit, and why) vs. declined, and the full static analysis findings
list again for the user to address manually. Remind them nothing was
pushed.
