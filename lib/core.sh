#!/usr/bin/env bash
# Platform-neutral steps. Sourced by bootstrap.sh after common.sh, which
# defines the globals used here: DOTFILES_DIR, PROFILES, DRY_RUN,
# SKIP_PACKAGES, UPGRADE.

install_shell_tooling() {
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    run env RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
}

link_shell_config() {
  local file
  for file in .aliases .functions .gitconfig .gitignore .zshconfig .zshrc .vimrc .tmux.conf; do
    link "$DOTFILES_DIR/$file" "$HOME/$file"
  done
  link "$DOTFILES_DIR/.vim" "$HOME/.vim"
  run mkdir -p "$DOTFILES_DIR/.vim/undodir"
  link "$DOTFILES_DIR/.vimrc" "$HOME/.config/nvim/init.vim"
  # neovim reuses the plug.vim bundled in .vim/autoload
  link "$HOME/.vim/autoload/plug.vim" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim"
}

install_editor_plugins() {
  run vim +PlugInstall +qall
  run nvim +PlugInstall +qall
}

choose_gpg_signing_key() {
  local current
  current="$(git config --file "$HOME/.gitconfig.local" user.signingkey 2>/dev/null || true)"
  [ -n "$current" ] && return 0
  [ "$DRY_RUN" = true ] && { log "[dry-run] choose GPG signing key"; return 0; }
  command -v gpg >/dev/null 2>&1 || return 0

  local keys=() key=""
  while IFS= read -r k; do keys+=("$k"); done < <(
    gpg --list-secret-keys --keyid-format LONG 2>/dev/null \
      | awk '/^sec/ {split($2, a, "/"); print a[2]}'
  )

  if [ "${#keys[@]}" -eq 1 ]; then
    key="${keys[0]}"
  elif [ "${#keys[@]}" -gt 1 ] && [ -t 0 ]; then
    echo "Multiple GPG keys found. Select one to use for git signing:"
    local i uid choice=""
    for i in "${!keys[@]}"; do
      uid="$(gpg --list-secret-keys --keyid-format LONG "${keys[$i]}" 2>/dev/null \
        | awk '/^uid/ {sub(/^uid *\[[^]]*\] */, ""); print; exit}')"
      printf "  %d) %s  %s\n" "$((i + 1))" "${keys[$i]}" "$uid"
    done
    read -rp "Enter number (or press Enter to skip): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#keys[@]}" ]; then
      key="${keys[$((choice - 1))]}"
    fi
  fi
  [ -n "$key" ] && git config --file "$HOME/.gitconfig.local" user.signingkey "$key"
  return 0
}

link_gpg_ssh() {
  local conf="$HOME/.gnupg/gpg-agent.conf" pinentry=""
  pinentry="$(command -v pinentry-mac || command -v pinentry || true)"
  if [ "$DRY_RUN" = true ]; then
    log "[dry-run] generate $conf (pinentry: ${pinentry:-none found})"
  else
    mkdir -p "$HOME/.gnupg"
    # Replace a symlink from an older bootstrap rather than writing through it.
    [ -L "$conf" ] && rm "$conf"
    {
      cat "$DOTFILES_DIR/.gpg-agent.conf"
      [ -n "$pinentry" ] && echo "pinentry-program $pinentry"
    } > "$conf.tmp"
    mv "$conf.tmp" "$conf"
  fi
  link "$DOTFILES_DIR/.ssh_config" "$HOME/.ssh/config"
}

active_ai_tiers() {
  local p
  for p in "${PROFILES[@]}"; do
    [ -f "$DOTFILES_DIR/profiles/$p/ai-tiers" ] && cat "$DOTFILES_DIR/profiles/$p/ai-tiers"
  done | sort -u
}

link_ai_tools() {
  local tools="$DOTFILES_DIR/ai-tools" tier f

  # Claude Code loads user-scope instructions only from ~/.claude/CLAUDE.md
  # (no user-level AGENTS.md), so the name stays CLAUDE.md.
  link "$DOTFILES_DIR/AGENTS.md" "$HOME/.claude/CLAUDE.md"
  link "$DOTFILES_DIR/AGENTS.md" "$HOME/AGENTS.md"

  while IFS= read -r tier; do
    [ -z "$tier" ] && continue
    for f in "$tools/$tier"/agents/*.md; do
      [ -e "$f" ] && link "$f" "$HOME/.claude/agents/$(basename "$f")"
    done
    for f in "$tools/$tier"/skills/*/; do
      [ -d "$f" ] && link "${f%/}" "$HOME/.claude/skills/$(basename "$f")"
    done
  done < <(active_ai_tiers)

  # Hook link names are referenced from ~/.claude/settings.json, so they stay explicit.
  link "$tools/all-purpose/hooks/secret-store-guard.sh" "$HOME/.claude/hooks/secret-store-guard.sh"
  link "$tools/developer/hooks/push-review-gate.sh" "$HOME/.claude/hooks/push-review-gate.sh"
  link "$tools/developer/hooks/push-review-pretooluse.sh" "$HOME/.claude/hooks/push-review-pretooluse.sh"
  link "$tools/developer/git-hooks/pre-push" "$HOME/.claude/hooks/push-review-git-pre-push.sh"
  link "$tools/developer/git-hooks/install.sh" "$HOME/.claude/hooks/push-review-install-hook.sh"

  merge_claude_settings
  # The push-review git gate is per-repo opt-in, not global: a global
  # core.hooksPath would redirect every hook type and silently break repo-local
  # hooks (e.g. the pre-commit framework). Opt a repo in with
  # ~/.claude/hooks/push-review-install-hook.sh.
}

merge_claude_settings() {
  local settings="$HOME/.claude/settings.json" hooks
  if [ "$DRY_RUN" = true ]; then
    log "[dry-run] merge PreToolUse hooks into $settings"
    return 0
  fi
  command -v jq >/dev/null 2>&1 || { warn "jq not found; skipping $settings hook merge"; return 0; }
  hooks="$(sed \
    -e "s#__SECRET_STORE_GUARD__#$HOME/.claude/hooks/secret-store-guard.sh#g" \
    -e "s#__PUSH_REVIEW_GATE__#$HOME/.claude/hooks/push-review-pretooluse.sh#g" \
    "$DOTFILES_DIR/ai-tools/developer/hooks/settings-hooks.json")"
  if [ -f "$settings" ]; then
    cp "$settings" "$settings.bak"
    # Merge only the PreToolUse key this template owns; overwriting all of
    # .hooks would drop other hook types configured elsewhere.
    jq --argjson hooks "$hooks" '.hooks.PreToolUse = $hooks.PreToolUse' "$settings" > "$settings.tmp" \
      && mv "$settings.tmp" "$settings"
  else
    jq -n --argjson hooks "$hooks" '{hooks: $hooks}' > "$settings"
  fi
}

run_profile_setup() {
  local p
  for p in "${PROFILES[@]}"; do
    if [ -x "$DOTFILES_DIR/profiles/$p/setup.sh" ]; then
      run "$DOTFILES_DIR/profiles/$p/setup.sh"
    fi
  done
}
