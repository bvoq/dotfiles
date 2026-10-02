phase_1_admin_installs() {
  install_brewfile texmacs/Brewfile
}

phase_3_dotfiles() {
  link_dotfile "texmacs/TeXmacs/packages/bvoqs-package.ts" "$HOME/.TeXmacs/packages/bvoqs-package.ts"
  link_dotfile "texmacs/TeXmacs/progs/my-init-buffer.scm" "$HOME/.TeXmacs/progs/my-init-buffer.scm"
  link_dotfile "texmacs/TeXmacs/progs/my-init-texmacs.scm" "$HOME/.TeXmacs/progs/my-init-texmacs.scm"
  link_dotfile "texmacs/TeXmacs/styles/bvoqs-beamer.ts" "$HOME/.TeXmacs/styles/bvoqs-beamer.ts"
  link_dotfile "texmacs/TeXmacs/styles/bvoqs-exam.ts" "$HOME/.TeXmacs/styles/bvoqs-exam.ts"
  link_dotfile "texmacs/TeXmacs/system/settings.scm" "$HOME/.TeXmacs/system/settings.scm"
  link_dotfile "texmacs/TeXmacs/system/preferences.scm" "$HOME/.TeXmacs/system/preferences.scm"
}
