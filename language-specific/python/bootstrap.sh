brew bundle

if ! grep -q "# python config" ~/.zshrc; then
	echo '\n# python config' >> ~/.zshrc
	echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
	echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
	echo 'eval "$(pyenv init -)"' >> ~/.zshrc

	echo 'ifpath+=~/.zfunc' >> ~/.zshrc
	echo 'autoload -Uz compinit && compinit' >> ~/.zshrc
fi

pipx ensurepath

mkdir -p ~/.zfunc
poetry completions zsh > ~/.zfunc/_poetry

