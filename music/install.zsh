phase_1_admin_installs() {
  install_brewfile music/Brewfile
}

phase_3_dotfiles() {
  link_dotfile "music/mpd.conf" "$HOME/.config/mpd/mpd.conf"
}
