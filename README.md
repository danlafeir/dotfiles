# dotfiles

Portable dev tooling and machine provisioning: shell, editor, git, and
AI-agent configuration that follows me from machine to machine, with
room for per-machine and personal-versus-professional variation.

## Bootstrap

```bash
./bootstrap-mac.sh            # core setup
./bootstrap-mac.sh personal   # core + personal brewfile
```

Or on a blank Mac: download `install.sh` and run `bash install.sh [personal]`
(it unpacks the repo to `~/.dotfiles`, then runs the bootstrap).
`bootstrap-linux.sh` and `bootstrap-windows.bat` are stubs; see
[docs/roadmap.md](docs/roadmap.md). Windows has a manual guide in
`personal-windows/README.md`.

`bootstrap-mac.sh` is meant to be re-run: it symlinks rather than copies,
so repo edits to symlinked files are live.

### What it does, in order

1. Installs oh-my-zsh and Homebrew if missing, runs `brew upgrade`, then
   `brew bundle` on `personal-mac/brewfile` (plus `brewfile.personal`
   when `personal` is passed).
2. Symlinks shell, git, vim, tmux dotfiles into `$HOME`; links vim and
   neovim to the same config and installs plugins.
3. Runs `link-local.sh` (see [Local customization](#local-customization)).
4. Picks a GPG signing key and writes it to `~/.gitconfig.local`.
5. Links the AI tooling into `~/.claude` (see [AI tooling](#ai-tooling)).
6. Links the GPG agent and SSH config.

## Layout

| Path | Purpose |
| --- | --- |
| `.zshrc`, `.zshconfig`, `.aliases`, `.functions` | Shell. `.zshrc` sources the other three, then `~/.zshrc.local` last. |
| `.gitconfig`, `.vimrc` + `.vim/`, `.tmux.conf` | Git (includes `~/.gitconfig.local`), vim/neovim, tmux. |
| `.gpg-agent.conf`, `.ssh_config` | Linked to `~/.gnupg/` and `~/.ssh/config`. |
| `personal-mac/` | Base mac brewfile and the opt-in `brewfile.personal`. |
| `infrastructure/`, `language-specific/` | Opt-in brewfiles and setup (k8s/terraform, python). Run by hand. |
| `ai-tools/` | Claude Code agents, skills, hooks and project templates, split by audience. |
| `AGENTS.md` | Global agent instructions, symlinked to `~/AGENTS.md` and `~/.claude/CLAUDE.md`. |
| `link-local.sh` | Installs gitignored `.local` files. |

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
- Existing real files at the destination are skipped with a warning.
  `.claude/`, `.git/`, `.generated/`, `.vim/undodir` and `.vim/plugged`
  are skipped.

`.local` files are not in git, so a new machine must recreate them.

## Opt-in tooling

Today the opt-ins are manual:

```bash
brew bundle --file infrastructure/brewfile            # k8s, helm, terraform, docker
brew bundle --file language-specific/python/brewfile  # pyenv, pipx
bash language-specific/python/bootstrap.sh            # see roadmap caveats first
~/.claude/hooks/push-review-install-hook.sh           # per repo: push-review gate
init-claude <template>                                # per project: AGENTS.md from a template
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
- `manager/`: reserved, empty.

To add an agent, skill or hook: put it in the matching tier, then add its
`ln -s` line to `bootstrap-mac.sh`. Nothing is auto-discovered.

Settings: the bootstrap merges only the `PreToolUse` key of
`~/.claude/settings.json` from `ai-tools/developer/hooks/settings-hooks.json`
and backs up the previous file to `settings.json.bak`.

## Known gaps

See [docs/roadmap.md](docs/roadmap.md) for concrete portability bugs and
the proposed profile system.

## GPG setup

```bash
gpg --default-new-key-algo rsa4096 --gen-key
gpg --list-secret-keys --keyid-format=long
gpg --armor --export <replace with value after rsa4096/> | pbcopy
```

## References
* https://docs.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#adding-your-ssh-key-to-the-ssh-agent
