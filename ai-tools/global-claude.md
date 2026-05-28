# Global AI Preferences

## Commit discipline
- Commit after each self-contained change: a function added, a bug fixed, a config updated
- Keep commits small and focused — one logical unit per commit
- Write commit messages that explain why, not what
- Never batch unrelated changes into one commit
- If a change is guarded by passing tests or is pure refactor, commit without asking

## When to proceed vs pause for review

Proceed autonomously:
- Refactoring covered by existing tests
- Boilerplate, scaffolding, generated code
- Research, summaries, explanations
- Reversible local changes (edits, test runs, installs)
- Renaming, reorganizing, formatting

Pause and confirm before proceeding:
- Net-new user-defined logic: new features, new algorithms, new data models
- Destructive or irreversible operations: deletions, migrations, force pushes, drops
- Security-sensitive changes: auth, permissions, secrets, tokens
- Infrastructure changes that affect live systems
- Public API or interface changes that affect callers
- Unfamiliar territory: new framework, new domain, new external dependency

## Code style
- No comments unless the WHY is non-obvious — a hidden constraint, a workaround, a subtle invariant
- No error handling for impossible cases; trust internal guarantees
- No premature abstractions — three similar lines is better than a helper
- Prefer editing existing files to creating new ones
- No half-finished implementations; no backwards-compatibility shims for removed code
