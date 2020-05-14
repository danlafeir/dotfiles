#!/usr/bin/env zsh

export ZSH="$HOME/.oh-my-zsh"
plugins=(
  git
)

source $ZSH/oh-my-zsh.sh
export EDITOR=vim
export LESS=-RX

for file in ~/.{functions,aliases}; do
	[ -r "$file" ] && [ -f "$file" ] && source "$file";
done;
unset file;

PS1="%F{blue}%B%n%b%f:%F{yellow}%1/%f$ "