# Dotfiles repo

Provisions dev tooling for any machine. Global agent instructions are `AGENTS.md`
(symlinked to `~/AGENTS.md` and `~/.claude/CLAUDE.md`); this file holds rules that
apply only when working inside this repo. `README.md` is the user-facing doc and
`docs/roadmap.md` records known gaps.

## Entry points

- `bootstrap.sh [--profile a,b] [--upgrade] [--skip-packages] [--dry-run]` and
  `bootstrap.sh doctor`. Never run it for real while testing: use
  `HOME=$(mktemp -d)` or `--dry-run`, because most repo files are live symlinks
  into the real `$HOME`.
- `tests/run.sh` runs everything against a throwaway `$HOME`. Run it before committing
  changes to `bootstrap.sh`, `lib/`, or `link-local.sh`.
- `~/.zshrc` is a symlink to `.zshrc`, so edits are live in the next shell: run
  `zsh -n .zshrc` after changing it.

## Layout rules

- `bootstrap.sh` orchestrates; `lib/core.sh` is platform-neutral; `lib/mac.sh` and
  `lib/linux.sh` only install packages. Keep OS-specific logic in the adapters.
- Create every symlink through `link` from `lib/common.sh` and every mutation through
  `run`, so `--dry-run` writes nothing and `doctor` sees the link.
- Profiles live in `profiles/<name>/`. Optional files: `brewfile`, `apt.txt`,
  `setup.sh`, `zsh.d/*.zsh` (sourced by `.zshrc` when active), `ai-tiers` (tiers of
  `ai-tools/` to link). `base` is always active. The active list is machine-local
  (`~/.config/dotfiles/profiles`), never committed.
- To add an agent or skill, drop it in `ai-tools/<tier>/agents/` or
  `ai-tools/<tier>/skills/<name>/`; bootstrap links it by glob. Do not rename or
  move `ai-tools/*/hooks/` files or the `~/.claude/hooks/` link names:
  `~/.claude/settings.json` points at them, and a dangling hook can block tool calls.

## `.local` files

Any file named `*.local` or `*.local.*` is gitignored and installed by `link-local.sh`
(run by `bootstrap.sh`). Never commit one; put machine-specific or private config there.

- Standalone (no base file): symlinked into `$HOME` at the same relative path.
- With a base (`foo.json` + `foo.local.json`): merged, local winning, into
  `.generated/<base>` (gitignored), and `~/<base>` links there. Text is concatenated
  base-then-local, so later lines win; `.json` is deep-merged. The output is generated:
  re-run `./link-local.sh` after editing either file.
- Exception: if the base already names its `.local` file (a source/include line, like
  `.zshrc` sourcing `~/.zshrc.local` or `.gitconfig` including `~/.gitconfig.local`),
  the base loads it, so the `.local` file is only symlinked. Keep that line last in the
  base so local wins.
- A real (non-symlink) file at the destination is skipped with a warning. `.claude/`,
  `.git/`, `.generated/`, `.vim/undodir`, `.vim/plugged` are not scanned.
- `.local` files are not in git: a new machine must recreate them, then re-run
  `./link-local.sh`.
