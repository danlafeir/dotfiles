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

## Verified

- 2026-11-19: `bootstrap.sh --profile base` in an `ubuntu:24.04` (arm64) container:
  packages, oh-my-zsh, links, `doctor`, a re-run, a login `zsh`, and `tests/run.sh` all
  pass. This found and fixed a bad step order (oh-my-zsh ran before curl existed).
- 2026-11-19: `bootstrap.sh --profile base,python` on macOS against a throwaway `$HOME`:
  found and fixed the oh-my-zsh `ZSH` clash, `brew bundle` upgrading regardless of
  `--upgrade`, and `setup.sh` failing on a broken poetry.

## Unverified

- CI has not run; it needs a push (the shellcheck job in particular, since shellcheck
  was not available locally).
- The `personal` and `infra` profiles have not been run end to end, and only `base`
  has been exercised on Linux (x86 is untested).
- `bootstrap.sh` has not been run against the real `$HOME` since the rewrite.

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
