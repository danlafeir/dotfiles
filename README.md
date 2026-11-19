# dotfiles

Portable dev tooling and machine provisioning: shell, editor, git, and
AI-agent configuration that follows me from machine to machine, with
room for per-machine and personal-versus-professional variation.

## Bootstrap

```bash
./bootstrap.sh                          # base profile (or the saved list)
./bootstrap.sh --profile personal,infra # pick profiles; saved for next time
./bootstrap.sh --dry-run                # print what would change, write nothing
./bootstrap.sh --skip-packages          # link config only
./bootstrap.sh --upgrade                # also upgrade installed packages
./bootstrap.sh doctor                   # check every link made by earlier runs
```

On a blank machine, download `install.sh` and run `bash install.sh [bootstrap options]`.
It clones the repo to `~/.dotfiles` (tarball fallback if git is missing) and runs
`bootstrap.sh`. macOS (Homebrew) and Linux (apt, untested) are supported; Windows is a
manual guide in `personal-windows/README.md` and `bootstrap-windows.bat` is a stub.

The bootstrap is meant to be re-run: it symlinks rather than copies, so edits to
linked files are live. A real file already at a destination is moved to
`<name>.pre-dotfiles`.

### What it does, in order

1. Installs packages for the active profiles (`brew bundle` per
   `brewfile` on macOS; `apt-get install` from each `apt.txt` on Linux), then oh-my-zsh.
2. Symlinks shell, git, vim, tmux dotfiles into `$HOME`; links vim and neovim to the
   same config and installs plugins.
3. Runs `link-local.sh` (see [Local customization](#local-customization)).
4. Picks a GPG signing key and writes it to `~/.gitconfig.local`.
5. Links the AI tooling into `~/.claude` (see [AI tooling](#ai-tooling)).
6. Generates `~/.gnupg/gpg-agent.conf` with the detected pinentry path and links the
   SSH config.
7. Runs each active profile's `setup.sh`.

## Profiles

Opt-in bundles live in `profiles/<name>/`; `base` is always on. The active list is
saved in `~/.config/dotfiles/profiles` (machine-local, not committed).

| Profile | Adds |
| --- | --- |
| `base` | Core tools (brewfile/apt.txt) and the `all-purpose` and `developer` AI tiers. |
| `personal` | Personal apps (brewfile). |
| `infra` | kubernetes, helm, terraform, docker/Rancher (brewfile). |
| `python` | pyenv, pipx (brewfile), a shell snippet for pyenv and completions, `setup.sh`. |
| `manager` | Links the `manager` AI tier (empty today). |

A profile directory may contain: `brewfile`, `apt.txt`, `setup.sh`, `zsh.d/*.zsh`
(sourced by `.zshrc`), and `ai-tiers` (one tier per line). To add a profile, create the
directory and run `./bootstrap.sh --profile <name>`.

## Layout

| Path | Purpose |
| --- | --- |
| `bootstrap.sh`, `lib/` | Entry point; `core.sh` is platform-neutral, `mac.sh` and `linux.sh` install packages. |
| `profiles/` | Opt-in bundles (see above). |
| `.zshrc`, `.zshconfig`, `.aliases`, `.functions` | Shell. `.zshrc` sources profile snippets and the other files, then `~/.zshrc.local` last. |
| `.gitconfig`, `.vimrc` + `.vim/`, `.tmux.conf` | Git (includes `~/.gitconfig.local`), vim/neovim, tmux. |
| `.gpg-agent.conf`, `.ssh_config` | Source for `~/.gnupg/gpg-agent.conf` and `~/.ssh/config`. |
| `ai-tools/` | Claude Code agents, skills, hooks and project templates, split by audience. |
| `AGENTS.md`, `CLAUDE.md` | Global agent instructions (symlinked to `~/AGENTS.md` and `~/.claude/CLAUDE.md`); rules for working in this repo. |
| `link-local.sh` | Installs gitignored `.local` files. |
| `tests/run.sh` | Tests against a throwaway `$HOME`. |

## Local customization

Anything named `*.local` or `*.local.*` is gitignored and installed by
`./link-local.sh`, which the bootstrap runs. Use it for machine-specific
or private config.

- **Base file that sources its local file** (`.zshrc` sources
  `~/.zshrc.local`; `.gitconfig` includes `~/.gitconfig.local`): the
  `.local` file is symlinked into `$HOME` and the base loads it itself.
  Keep that line last so local wins.
- **Base file that doesn't** (`foo.json` + `foo.local.json`): the two
  are merged with local taking precedence into `.generated/`
  (gitignored), and `$HOME` links there. Text is concatenated
  base-then-local; JSON is deep-merged. Re-run `./link-local.sh` after
  editing either file.
- **No base**: just symlinked to the same relative path.
- A real file where a standalone `.local` would link is skipped with a warning; a real
  file where a merged base lands is moved to `<name>.pre-dotfiles`.
  `.claude/`, `.git/`, `.generated/`, `.vim/undodir` and `.vim/plugged`
  are skipped.

`.local` files are not in git, so a new machine must recreate them.

## Per-repo opt-ins

```bash
~/.claude/hooks/push-review-install-hook.sh   # per repo: push-review gate
init-claude <template>                        # per project: AGENTS.md from a template
```

## AI tooling

`ai-tools/` is split by audience and linked into `~/.claude` by the
bootstrap:

- `all-purpose/`: applies to any session. Currently the secret-store
  guard hook (blocks reading or writing real secrets via secret-store
  CLIs or credential files).
- `developer/`: the review agents (security, design, documentation,
  performance, db-integrity, dependency audit), the `pre-push-review`,
  `pre-push-audit` and `document-changes` skills, the push-review gate
  (a Claude Code hook plus a per-repo git `pre-push` hook), and
  `templates/` for per-project `AGENTS.md`.
- `manager/`: reserved, empty. Linked only when the `manager` profile is active.

To add an agent or skill, drop it in the matching tier (`agents/<name>.md` or
`skills/<name>/`); bootstrap links tiers by glob. Hooks are linked by explicit name
because `~/.claude/settings.json` references those paths.

The `all-purpose` and `developer` tiers are listed in `profiles/base/ai-tiers`.

Settings: the bootstrap merges only the `PreToolUse` key of
`~/.claude/settings.json` from `ai-tools/developer/hooks/settings-hooks.json`
and backs up the previous file to `settings.json.bak`.

## Known gaps

See [docs/roadmap.md](docs/roadmap.md) for what is done and what remains.

## GPG setup

```bash
gpg --default-new-key-algo rsa4096 --gen-key
gpg --list-secret-keys --keyid-format=long
gpg --armor --export <replace with value after rsa4096/> | pbcopy
```

## References
* https://docs.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#adding-your-ssh-key-to-the-ssh-agent
