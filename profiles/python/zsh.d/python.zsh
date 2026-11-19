export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
command -v pyenv >/dev/null && eval "$(pyenv init -)"
# pipx installs tools here; `pipx ensurepath` would append this to .zshrc, which is tracked
[[ -d $HOME/.local/bin ]] && export PATH="$PATH:$HOME/.local/bin"
fpath+=~/.zfunc
