if [ ! -d "$HOME/.oh-my-zsh" ] 
then  
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

cp .aliases .functions .gitconfig .gitignore .zshconfig .zshrc ~/.
cp .ssh_config ~/.ssh/config
