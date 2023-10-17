if [ ! -d "$HOME/.oh-my-zsh" ] 
then  
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

which -s brew
if [[ $? != 0 ]] ; then
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	brew bundle
else
  brew upgrade
fi

cp .aliases .functions .gitconfig .gitignore .zshconfig .zshrc .vimrc ~/.
cp .ssh_config ~/.ssh/config
