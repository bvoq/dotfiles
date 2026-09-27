phase_1_admin_installs() {
  local grok_bin check channel installed_version marker

  grok_bin="${GROK_BIN_DIR:-$HOME/.grok/bin}/grok"
  if [[ -x "$grok_bin" ]]; then
    check="$("$grok_bin" update --check --json)" || {
      echo "Could not check whether a new Grok version is available."
      return 1
    }
    check="${check//[[:space:]]/}"

    if [[ "$check" == *'"updateAvailable":false'* && "$check" == *'"error":null'* ]]; then
      marker='"currentVersion":"'
      if [[ "$check" == *"$marker"* ]]; then
        installed_version="${check#*$marker}"
        installed_version="${installed_version%%\"*}"
        echo "Grok ${installed_version} is already installed."
      else
        echo "Grok is already installed."
      fi
      return 0
    fi

    if [[ "$check" != *'"updateAvailable":true'* ]]; then
      echo "Could not tell whether a new Grok version is available."
      return 1
    fi

    marker='"channel":"'
    if [[ "$check" == *"$marker"* ]]; then
      channel="${check#*$marker}"
      channel="${channel%%\"*}"
      case "$channel" in
        stable | alpha | enterprise) ;;
        *) channel="" ;;
      esac
    fi
  fi

  if [[ -n "$channel" ]]; then
    curl -fsSL https://x.ai/cli/install.sh | env GROK_CHANNEL="$channel" bash
  else
    curl -fsSL https://x.ai/cli/install.sh | bash
  fi
}

phase_3_dotfiles() {
  link_dotfile "grok/.zshenv" "$HOME/.zshenv.d/zshenv_grok"
  link_dotfile "grok/.zshrc.d/20_pre_compinit.zsh" "$HOME/.zshrc.d/20_pre_compinit_grok.zsh"
}
