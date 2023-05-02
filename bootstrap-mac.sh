if [ ! -d "$HOME/.oh-my-zsh" ] 
then  
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

which -s brew
if [[ $? != 0 ]] ; then
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	brew bundle
else
	brew bundle
  brew upgrade
fi

if [[ ! -d "$HOME/.vim/autoload/plug.vim" ]] ; then 
	curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

cp .aliases .functions .gitconfig .gitignore .zshconfig .zshrc .vimrc ~/.
cp .ssh_config ~/.ssh/config
