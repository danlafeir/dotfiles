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

ln -sfn "$DOTFILES_DIR/.vim" "$HOME/.vim"
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
CURRENT_KEY=$(git config --file ~/.gitconfig.local user.signingkey 2>/dev/null)
if [ -z "$CURRENT_KEY" ]; then
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
  [ -n "$GPG_KEY" ] && git config --file ~/.gitconfig.local user.signingkey "$GPG_KEY"
fi

mkdir -p ~/.claude && ln -sf "$DOTFILES_DIR/ai-tools/global-claude.md" "$HOME/.claude/CLAUDE.md"
ln -sf "$DOTFILES_DIR/AGENTS.md" "$HOME/AGENTS.md"

mkdir -p ~/.claude/agents
ln -sf "$DOTFILES_DIR/ai-tools/agents/documentation-agent.md" "$HOME/.claude/agents/documentation-agent.md"
ln -sf "$DOTFILES_DIR/ai-tools/agents/pre-push-audit-agent.md" "$HOME/.claude/agents/pre-push-audit-agent.md"
ln -sf "$DOTFILES_DIR/ai-tools/agents/security-review-agent.md" "$HOME/.claude/agents/security-review-agent.md"
ln -sf "$DOTFILES_DIR/ai-tools/agents/performance-review-agent.md" "$HOME/.claude/agents/performance-review-agent.md"
ln -sf "$DOTFILES_DIR/ai-tools/agents/db-integrity-agent.md" "$HOME/.claude/agents/db-integrity-agent.md"
ln -sf "$DOTFILES_DIR/ai-tools/agents/design-review-agent.md" "$HOME/.claude/agents/design-review-agent.md"

mkdir -p ~/.claude/skills
ln -sfn "$DOTFILES_DIR/ai-tools/skills/document-changes" "$HOME/.claude/skills/document-changes"
ln -sfn "$DOTFILES_DIR/ai-tools/skills/pre-push-audit" "$HOME/.claude/skills/pre-push-audit"
ln -sfn "$DOTFILES_DIR/ai-tools/skills/pre-push-review" "$HOME/.claude/skills/pre-push-review"

mkdir -p ~/.claude/hooks
ln -sf "$DOTFILES_DIR/ai-tools/hooks/secret-store-guard.sh" "$HOME/.claude/hooks/secret-store-guard.sh"
ln -sf "$DOTFILES_DIR/ai-tools/hooks/push-review-gate.sh" "$HOME/.claude/hooks/push-review-gate.sh"
ln -sf "$DOTFILES_DIR/ai-tools/hooks/push-review-pretooluse.sh" "$HOME/.claude/hooks/push-review-pretooluse.sh"
ln -sf "$DOTFILES_DIR/ai-tools/git-hooks/pre-push" "$HOME/.claude/hooks/push-review-git-pre-push.sh"
ln -sf "$DOTFILES_DIR/ai-tools/git-hooks/install.sh" "$HOME/.claude/hooks/push-review-install-hook.sh"

CLAUDE_SETTINGS="$HOME/.claude/settings.json"
NEW_HOOKS=$(sed \
  -e "s#__SECRET_STORE_GUARD__#$HOME/.claude/hooks/secret-store-guard.sh#g" \
  -e "s#__PUSH_REVIEW_GATE__#$HOME/.claude/hooks/push-review-pretooluse.sh#g" \
  "$DOTFILES_DIR/ai-tools/hooks/settings-hooks.json")

if [ -f "$CLAUDE_SETTINGS" ]; then
  cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.bak"
  # Merge only the PreToolUse key this template owns — overwriting the whole
  # .hooks object would silently drop any other hook type already
  # configured there (e.g. a SessionStart hook set up some other way).
  jq --argjson hooks "$NEW_HOOKS" '.hooks.PreToolUse = $hooks.PreToolUse' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp" \
    && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
else
  jq -n --argjson hooks "$NEW_HOOKS" '{hooks: $hooks}' > "$CLAUDE_SETTINGS"
fi

# Push-review git-level gate is per-repo opt-in, not global: a global
# `core.hooksPath` override would redirect hook lookup for every hook type,
# not just pre-push, silently breaking any repo-local hook (e.g. the
# `pre-commit` framework's directly-installed .git/hooks/pre-commit) that
# doesn't set its own core.hooksPath. Run
# `~/.claude/hooks/push-review-install-hook.sh` once in a repo to opt it in.

mkdir -p ~/.gnupg && ln -sf "$DOTFILES_DIR/.gpg-agent.conf" "$HOME/.gnupg/gpg-agent.conf"
mkdir -p ~/.ssh && ln -sf "$DOTFILES_DIR/.ssh_config" "$HOME/.ssh/config"
