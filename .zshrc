#!/usr/bin/env zsh

export PATH=$HOME/go/bin/:$PATH

export ZSH="$HOME/.oh-my-zsh"
plugins=(
  git
)

source $ZSH/oh-my-zsh.sh

for file in ~/.{functions,aliases,zshconfig}; do
	[ -r "$file" ] && [ -f "$file" ] && source "$file";
done;
unset file;

if [ -z $SSH_AGENT_PID ] 
then
	eval "$(ssh-agent -s)" >> /dev/null
fi
export GPG_TTY=$(tty)

# https://zsh.sourceforge.io/doc/release/prompt-expansion.html
export PS1=$(custom_ps1)

# Rancher config
export PATH="$HOME/.rd/bin:$PATH"

# python config
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# nvim config 
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
