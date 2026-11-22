# Installed for the current user into ~/Library/Fonts, which does not need
# admin rights. A system-wide copy into /Library/Fonts would, and would belong
# in phase 1 behind isadminuser.

phase_2_user_installs() {
  [[ $OSTYPE == 'darwin'* ]] || return 0
  setopt local_options extended_glob

  local dest="$HOME/Library/Fonts" file target
  local -a font_files
  local copied=0
  mkdir -p "$dest"

  font_files=(fonts/**/*.(ttf|otf|ttc)(.N))
  if (( ${#font_files} == 0 )); then
    echo "No font files found under fonts/."
    return 0
  fi

  for file in "${font_files[@]}"; do
    target="$dest/${file:t}"
    if [[ -f $target ]] && cmp -s -- "$file" "$target"; then
      continue
    fi
    if ! cp -f -- "$file" "$target"; then
      echo "Could not install ${file:t} into $dest" >&2
      return 1
    fi
    echo "Installed font ${file:t}"
    copied=$((copied + 1))
  done

  if (( copied == 0 )); then
    echo "Fonts already installed."
  fi
}
