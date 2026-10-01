phase_1_admin_installs() {
  install_brewfile texmacs/Brewfile
}

phase_3_dotfiles() {
  link_dotfile "texmacs/TeXmacs/packages/dotfiles.ts" "$HOME/.TeXmacs/packages/dotfiles.ts"
  link_dotfile "texmacs/TeXmacs/progs/my-init-buffer.scm" "$HOME/.TeXmacs/progs/my-init-buffer.scm"
  link_dotfile "texmacs/TeXmacs/system/settings.scm" "$HOME/.TeXmacs/system/settings.scm"
  link_dotfile "texmacs/TeXmacs/system/preferences.scm" "$HOME/.TeXmacs/system/preferences.scm"
}
