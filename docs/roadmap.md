# Roadmap

Goal: provision any machine (mac, linux, windows) from this repo, with local
overrides and opt-in profiles for personal versus professional use. Reviewed
2026-11-19; the items below marked done were implemented that day.

## Done

- `init-claude` alias derives its path from `DOTFILES_DIR` (exported by `.zshrc`)
  instead of hardcoding `~/dev/dotfiles`.
- `pyenv` setup moved into the `python` profile and guarded; the Rancher PATH block
  that hardcoded `/Users/dan` is gone. Rancher re-adds it to `~/.zshrc` unless its PATH
  management is set to manual in its preferences; move any such block to `~/.zshrc.local`.
- `pinentry-program` is generated from the detected binary instead of a hardcoded
  Homebrew path.
- `brew upgrade` only runs with `--upgrade`; `bootstrap.sh` runs under
  `set -euo pipefail`; `install.sh` dispatches through `bootstrap.sh` and clones with
  git (tarball fallback).
- `.gitignore` no longer ignores `bin`; `.vim/.netrwhist` is untracked.
- Platform-neutral core plus `mac` (Homebrew) and `linux` (apt) adapters.
- Profiles (`base`, `personal`, `infra`, `python`, `manager`) with a machine-local
  active list; AI tiers are profile-gated; agents and skills are linked by glob.
- `--dry-run` and `bootstrap.sh doctor`.
- `tests/run.sh` and GitHub Actions CI (shellcheck, tests on linux and macOS, a clean
  linux bootstrap).
- Dotfiles-specific agent rules moved from the global `AGENTS.md` to this repo's
  `CLAUDE.md`.

## Unverified

- The Linux adapter and the `provision-linux` CI job have not been run: there was no
  Linux host or working container daemon when they were written. Expect first-run fixes
  (package names in `profiles/*/apt.txt`, the oh-my-zsh installer, headless
  `vim +PlugInstall`).
- CI has not run at all; it needs a push.
- `bootstrap.sh` has never been run for real since the rewrite, only against a
  temporary `$HOME`.

## Remaining

- **Windows.** Still a manual guide plus a stub. A PowerShell adapter reading
  `personal-windows/packages.config` would match the mac and linux adapters.
- **Profile coverage on Linux.** Only `base` has an `apt.txt`; `infra`, `python` and
  `personal` have brewfiles only.
- **`manager` tier is empty.** The profile exists so the mechanism is in place.
- **Overlap in `profiles/infra/brewfile`:** `brew "docker"` and `cask "rancher"`.
  Rancher Desktop ships a docker CLI, so the formula is probably redundant; a judgment
  call left as is.
- **Rename `.vim/.vim` in `.gitignore`.** It looks like a truncated `.viminfo`.
- **nvm** is still configured in `.zshconfig` rather than a profile snippet.
- **Removing a link.** Stale links for files deleted from the repo are not pruned;
  `doctor` reports them as broken.
