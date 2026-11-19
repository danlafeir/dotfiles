# Roadmap: portability and opt-in profiles

Goal: provision any machine (mac, linux, windows) from this repo, with
local overrides and opt-in profiles for personal versus professional use.
This is a review of the repo as of 2026-11-19; items are ordered by value.

## Concrete bugs

These break a fresh machine today.

1. **`init-claude` alias hardcodes `~/dev/dotfiles`** (`.aliases`), but
   `install.sh` unpacks to `~/.dotfiles`. Derive the path from the
   symlink target or export `DOTFILES_DIR` from `.zshrc`.
2. **`.zshrc` runs `pyenv init` unconditionally**, but pyenv is only in
   the opt-in python brewfile. A fresh shell prints an error. Same for
   nvm, which no brewfile installs. Guard each with `command -v` or move
   them into per-profile snippets.
3. **Tools write into the tracked `.zshrc`.** It is a symlink into the
   repo, so Rancher Desktop's managed block (with `/Users/dan` baked in)
   and `language-specific/python/bootstrap.sh` both dirty the repo. That
   script also duplicates the pyenv block already in `.zshrc` and has a
   typo (`ifpath+=` for `fpath+=`). Move tool-injected config to
   `~/.zshrc.local`.
4. **`.gpg-agent.conf` hardcodes `/opt/homebrew/bin/pinentry-mac`**, which
   is wrong on Intel macs and on linux.
5. **`brew upgrade` on every bootstrap** makes a re-run slow and can
   change versions unexpectedly. Gate it behind a flag.
6. **`bootstrap-mac.sh` has no `set -euo pipefail`**, so a failed step is
   silently skipped. `install.sh` always calls the mac script; it should
   dispatch on `uname`.
7. **`.gitignore` ignores `bin` and `out`** repo-wide, so a `bin/` of
   scripts could never be committed.

## Portability

- **Linux and Windows are stubs.** Split the bootstrap into a
  platform-neutral core (symlinks, `link-local.sh`, ai-tools, git/gpg
  config) and thin platform adapters (package manager, pinentry path,
  paths). Most of the current script is already neutral.
- **Replace hand-written symlink lists with a manifest or globs.**
  Adding an agent or skill means editing `bootstrap-mac.sh` in several
  places; `for f in ai-tools/developer/agents/*.md` removes that and the
  risk of an unlinked file.
- **Prefer `git clone` over the tarball in `install.sh`.** The tarball
  update never deletes removed files and leaves no history to `git pull`.
- **Stop hardcoding the home path** in generated config. The hooks
  template already substitutes `$HOME` at bootstrap; do the same
  elsewhere.
- **Idempotence and a dry run.** A `--dry-run` that prints planned links,
  and a `doctor` command that reports broken or missing links, would make
  re-running safe on a machine you don't remember configuring.

## Opt-in profiles

The `personal` argument is the only built-in opt-in; everything else is
a manual command. Proposal:

```
profiles/
  base/         brewfile, links.txt           always applied
  personal/     brewfile, zsh.d/*.zsh
  work/         brewfile, zsh.d/*.zsh
  infra/        brewfile
  python/       brewfile, zsh.d/pyenv.zsh
```

- The active set lives in `~/.config/dotfiles/profiles` (one name per
  line, machine-local, not committed). `./bootstrap --profile work,infra`
  writes it; later runs reuse it.
- Each profile can contribute a brewfile, symlinks, and shell snippets
  that `.zshrc` sources from `zsh.d/` when the profile is active. That
  removes the unconditional `pyenv` and `nvm` lines.
- Apply the same idea to `ai-tools/`: link the `manager/` tier only on
  machines that opt in, and let a work profile add its own agents and
  settings without touching the personal set.
- Keep `.local` files as the escape hatch for one-off, machine-specific
  tweaks; profiles are for reusable bundles.

## Verification

- **No tests or CI.** Add `shellcheck` over all scripts, a bats test for
  `link-local.sh` (merge, skip, idempotence), and a CI job that runs the
  bootstrap on a clean macOS runner and, once it exists, a linux
  container.
- Track `ai-tools/` hooks with the same tests: the secret guard and push
  gate fail closed, which is worth proving rather than assuming.

## Housekeeping

- Split global from repo-specific instructions. `AGENTS.md` is both the
  global file loaded in every project and this repo's own instructions,
  so repo-specific text (like the `.local` section) is loaded
  everywhere. Move it to a `CLAUDE.md` in this repo or into `docs/`.
- Untrack `.vim/.netrwhist`, which is editor noise.
- Rename `personal-mac/brewfile` (it is the base set) or move it to
  `base/`; the `personal-` prefix suggests the opposite.
- `brew "docker"` and `cask "rancher"` in `infrastructure/brewfile`
  overlap, since Rancher Desktop supplies a docker CLI.
