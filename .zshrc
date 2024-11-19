#!/usr/bin/env zsh

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
export PS1='%F{cyan}%n%f%F{magenta}@%f%F{magenta}%m%f:%F{yellow}%~/%f$ '
# Swan Computer terminal
export PS1='%F{green}:> '

# Rancher config
export PATH="$HOME/.rd/bin:$PATH"

# python config
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
