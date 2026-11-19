#!/usr/bin/env zsh

export DOTFILES_DIR="${${(%):-%x}:A:h}"
export PATH=$HOME/go/bin/:$PATH

export ZSH="$HOME/.oh-my-zsh"
plugins=(
  git
)

# Profiles contribute shell snippets; the active list is written by bootstrap.sh.
if [ -r "$HOME/.config/dotfiles/profiles" ]; then
  for p in ${(f)"$(<$HOME/.config/dotfiles/profiles)"}; do
    for f in "$DOTFILES_DIR"/profiles/$p/zsh.d/*.zsh(N); do source "$f"; done
  done
  unset p f
fi

source $ZSH/oh-my-zsh.sh

for file in ~/.{functions,aliases,zshconfig,machine_specific_config}; do
	[ -r "$file" ] && [ -f "$file" ] && source "$file";
done;
unset file;

if [ -z $SSH_AGENT_PID ] 
then
	eval "$(ssh-agent -s)" >> /dev/null
fi
export GPG_TTY=$(tty)

# https://zsh.sourceforge.io/doc/release/prompt-expansion.html
export PS1=$BASIC_TERMINAL

# Rancher config
export PATH="$HOME/.rd/bin:$PATH"

[ -r "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
