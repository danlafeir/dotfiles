if [ ! -d "$HOME/.oh-my-zsh" ] 
then  
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

which -s brew
if [[ $? != 0 ]] ; then
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
else
  brew upgrade
fi

cp .aliases .functions .gitconfig .gitignore .zshconfig .zshrc ~/.
cp .ssh_config ~/.ssh/config
