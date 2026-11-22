---
name: nfr-setup
description: One-time per-repo setup that works out which non-functional requirements (NFRs) matter for this repo — availability, security/privacy, performance, SEO, URL stability, observability, accessibility, cost, and so on — by inspecting what the repo actually is, confirms the list with the user, and writes it to docs/nfrs.md so `pre-push-review` checks every push against it. Use when the user asks to "set up NFRs", "what non-functional requirements should I care about in this repo", "configure the pre-push review for this repo", or runs `/nfr-setup`. Re-run to revise the list.
---

# /nfr-setup

Produces `docs/nfrs.md`: the repo's committed list of non-functional
requirements. `/pre-push-review` reads it and runs `nfr-review-agent` against
the commits being pushed. The list is the product of this skill; the user
decides what is on it. Default to a short list: an NFR nobody will check is
noise.

## Step 0 — sanity check

Confirm a git repo (`git rev-parse --is-inside-work-tree`). If `docs/nfrs.md`
exists, read it and treat this run as a revision: keep what the user already
chose, and only propose additions, removals, or fixes to stale "how to check"
lines.

## Step 1 — work out what the repo is

Read, don't guess. Look at the manifest and layout (`package.json`,
`pyproject.toml`, `go.mod`, `Dockerfile`, `*.tf`, framework configs), the
README, CI config, deploy config, and `git log --oneline -20`. Decide which
of these it is (often several): public website, HTTP API, internal service,
data pipeline or migrations, CLI or library, infrastructure-as-code,
mobile/desktop app, dotfiles or tooling. Note concrete facts you will cite
later: where URLs are defined, where logs and metrics go, where secrets are
read, what runs on a schedule, what is deployed and how.

## Step 2 — propose candidate NFRs

Pick from this menu only what the evidence in Step 1 supports. For each one
you keep, write down the repo-specific risk and how a reviewer would check it.

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

Cap the proposal at roughly eight. Say why each applies in one line, citing
the file that told you.

## Step 3 — confirm with the user

Use AskUserQuestion (multiSelect, up to 4 options per question, group the
candidates across several questions in one call): "Which of these NFRs should
every push to this repo be checked against?" Selected = on the list.
Unselected = left out. Then ask once, as plain text if there is nothing
better to offer as options, whether any repo-specific requirement is missing
and whether any has a concrete target (for example "p95 under 300ms",
"99.9% monthly", "no URL changes without a 301"). A number the user gives
goes into the file verbatim; never invent a target.

## Step 4 — write docs/nfrs.md

Create `docs/` if needed. One `##` section per NFR, in this shape, so the
agent and a human reader can both use it:

```markdown
# Non-functional requirements

Checked by `/pre-push-review` (via `nfr-review-agent`) on every push that
changes deployed code. Revise with `/nfr-setup`.

## URL stability

- **Why it matters here:** <one line, repo-specific>
- **Target:** <user's number or rule, or "none declared">
- **How to check a diff:** <concrete: files, commands, or signals to look at>
- **Out of scope:** <what the reviewer should not flag>
```

Keep each section to those four lines. "How to check" must name real paths,
commands or signals from this repo. Do not write generic advice.

## Step 5 — opt the repo in and commit

Tell the user what you found: whether the repo has `push-review.enabled`
(`git config --get push-review.enabled`). If it is not `true`, say the NFR
check only runs when `/pre-push-review` runs, and that
`~/.claude/hooks/push-review-install-hook.sh` makes the push gate require it;
do not run that script yourself, the user chooses whether to opt in.

Commit `docs/nfrs.md` on its own, per the commit conventions in the global
instructions: subject like "Declare non-functional requirements for pre-push
review", a body covering the value, the docs change, and the non-functional
impact (none at runtime), and `Tested: not run`. Do not push.

## Notes

- This skill writes one file and makes one commit. It never changes code.
- Revisiting: a stale line (a path that no longer exists, an NFR the repo
  outgrew) is a reason to re-run this skill, and `nfr-review-agent` flags
  those as `[nfr-file]` findings.
