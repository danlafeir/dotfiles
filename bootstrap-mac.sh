DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

which -s brew
if [[ $? != 0 ]] ; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
brew upgrade

# Install vim-plug for neovim
NVIM_PLUG="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim"
if [ ! -f "$NVIM_PLUG" ]; then
  curl -fLo "$NVIM_PLUG" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

ln -sf "$DOTFILES_DIR/.vim" "$HOME/.vim"
mkdir -p "$DOTFILES_DIR/.vim/undodir"
for file in .aliases .functions .gitconfig .gitignore .zshconfig .zshrc .vimrc .tmux.conf; do
  ln -sf "$DOTFILES_DIR/$file" "$HOME/$file"
done

mkdir -p ~/.config/nvim && ln -sf "$DOTFILES_DIR/.vimrc" "$HOME/.config/nvim/init.vim"
mkdir -p ~/.claude && ln -sf "$DOTFILES_DIR/ai-tools/global-claude.md" "$HOME/.claude/CLAUDE.md"
mkdir -p ~/.gnupg && ln -sf "$DOTFILES_DIR/.gpg-agent.conf" "$HOME/.gnupg/gpg-agent.conf"
mkdir -p ~/.ssh && ln -sf "$DOTFILES_DIR/.ssh_config" "$HOME/.ssh/config"
