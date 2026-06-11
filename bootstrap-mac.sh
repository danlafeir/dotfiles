DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PERSONAL=false
[[ "$1" == "personal" ]] && PERSONAL=true

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

which -s brew
if [[ $? != 0 ]] ; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
brew upgrade
brew bundle --file "$DOTFILES_DIR/personal-mac/brewfile"
$PERSONAL && brew bundle --file "$DOTFILES_DIR/personal-mac/brewfile.personal"

ln -sf "$DOTFILES_DIR/.vim" "$HOME/.vim"
mkdir -p "$DOTFILES_DIR/.vim/undodir"
for file in .aliases .functions .gitconfig .gitignore .zshconfig .zshrc .vimrc .tmux.conf; do
  ln -sf "$DOTFILES_DIR/$file" "$HOME/$file"
done

mkdir -p ~/.config/nvim && ln -sf "$DOTFILES_DIR/.vimrc" "$HOME/.config/nvim/init.vim"

# Install vim-plug for neovim, reusing the bundled plug.vim from .vim/autoload
NVIM_PLUG="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim"
mkdir -p "$(dirname "$NVIM_PLUG")"
ln -sf "$HOME/.vim/autoload/plug.vim" "$NVIM_PLUG"

# Install all vim/neovim plugins
vim +PlugInstall +qall
nvim +PlugInstall +qall
GPG_KEYS=($(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep '^sec' | awk '{print $2}' | cut -d'/' -f2))
if [ ${#GPG_KEYS[@]} -eq 1 ]; then
  GPG_KEY="${GPG_KEYS[0]}"
elif [ ${#GPG_KEYS[@]} -gt 1 ]; then
  echo "Multiple GPG keys found. Select one to use for git signing:"
  for i in "${!GPG_KEYS[@]}"; do
    UID_LINE=$(gpg --list-secret-keys --keyid-format LONG "${GPG_KEYS[$i]}" 2>/dev/null | grep '^uid' | head -1 | sed 's/^uid *\[[^]]*\] *//')
    printf "  %d) %s  %s\n" "$((i+1))" "${GPG_KEYS[$i]}" "$UID_LINE"
  done
  read -rp "Enter number (or press Enter to skip): " CHOICE
  [[ "$CHOICE" =~ ^[0-9]+$ ]] && GPG_KEY="${GPG_KEYS[$((CHOICE-1))]}"
fi
if [ -n "$GPG_KEY" ]; then
  printf '[user]\n\tsigningkey = %s\n' "$GPG_KEY" > ~/.gitconfig.local
fi

mkdir -p ~/.claude && ln -sf "$DOTFILES_DIR/ai-tools/global-claude.md" "$HOME/.claude/CLAUDE.md"
ln -sf "$DOTFILES_DIR/AGENTS.md" "$HOME/AGENTS.md"
mkdir -p ~/.gnupg && ln -sf "$DOTFILES_DIR/.gpg-agent.conf" "$HOME/.gnupg/gpg-agent.conf"
mkdir -p ~/.ssh && ln -sf "$DOTFILES_DIR/.ssh_config" "$HOME/.ssh/config"
