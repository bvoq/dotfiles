phase_1_admin_installs() {
  curl -fsSL https://x.ai/cli/install.sh | bash
}

phase_3_dotfiles() {
  link_dotfile "grok/.zshenv" "$HOME/.zshenv.d/zshenv_grok"
  link_dotfile "grok/.zshrc.d/20_pre_compinit.zsh" "$HOME/.zshrc.d/20_pre_compinit_grok.zsh"
}
