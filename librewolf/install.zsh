librewolf_version_from_dmg_url() {
  local name="${1:t}"
  name="${name#librewolf-}"
  name="${name%-macos-arm64-package.dmg}"
  print -r -- "$name"
}

# Numeric compare of versions like 156.0.1-1. Returns 0 when $1 is strictly newer.
librewolf_version_gt() {
  local -a left right
  local i count left_n right_n left_part right_part
  left=("${(@s/./)${1//-/.}}")
  right=("${(@s/./)${2//-/.}}")
  left_n=${#left}
  right_n=${#right}
  count=$left_n
  (( right_n > count )) && count=$right_n
  for (( i=1; i<=count; i++ )); do
    left_part=${left[i]:-0}
    right_part=${right[i]:-0}
    left_part=${left_part//[^0-9]/}
    right_part=${right_part//[^0-9]/}
    [[ -n $left_part ]] || left_part=0
    [[ -n $right_part ]] || right_part=0
    if (( left_part > right_part )); then
      return 0
    fi
    if (( left_part < right_part )); then
      return 1
    fi
  done
  return 1
}

librewolf_select_newest_url() {
  local line best best_version candidate_version
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    if [[ -z $best ]]; then
      best=$line
      best_version="$(librewolf_version_from_dmg_url "$line")"
      continue
    fi
    candidate_version="$(librewolf_version_from_dmg_url "$line")"
    if librewolf_version_gt "$candidate_version" "$best_version"; then
      best=$line
      best_version=$candidate_version
    fi
  done
  print -r -- "$best"
}

librewolf_install_dmg() {
  local url="$1" tmp_dir dmg_path mount_point app_path expected_sha256 actual_sha256
  tmp_dir="$(mktemp -d)"
  dmg_path="$tmp_dir/LibreWolf.dmg"
  mount_point="$tmp_dir/mount"
  app_path="$tmp_dir/LibreWolf.app"
  mkdir -p "$mount_point"

  curl -fL "$url" -o "$dmg_path"
  expected_sha256="$(curl -fsSL "$url.sha256sum" | awk '{print $1}')"
  actual_sha256="$(shasum -a 256 "$dmg_path" | awk '{print $1}')"
  if [[ "$expected_sha256" != "$actual_sha256" ]]; then
    echo "WARNING: LibreWolf checksum mismatch (expected: $expected_sha256, actual: $actual_sha256)" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  hdiutil attach -nobrowse -readonly -mountpoint "$mount_point" "$dmg_path"
  ditto "$mount_point/LibreWolf.app" "$app_path"
  mkdir -p "$app_path/Contents/Resources/distribution"
  cp -p librewolf/policies.json \
    "$app_path/Contents/Resources/distribution/policies.json"
  # The policy file changes the vendor-sealed bundle, so give the local copy
  # a valid ad-hoc signature before installing it.
  codesign --force --deep --sign - "$app_path"
  codesign --verify --deep --strict "$app_path"
  rm -rf /Applications/LibreWolf.app
  ditto "$app_path" /Applications/LibreWolf.app
  hdiutil detach "$mount_point"
  xattr -dr com.apple.quarantine /Applications/LibreWolf.app
  rm -rf "$tmp_dir"
}

# Copy dotfiles policies into the installed app when they differ, then re-sign.
# LibreWolf installs ExtensionSettings into the profile from this file.
librewolf_sync_policies() {
  local app="/Applications/LibreWolf.app"
  local src="librewolf/policies.json"
  local dest="$app/Contents/Resources/distribution/policies.json"
  [[ -d $app ]] || return 0
  [[ -f $src ]] || {
    echo "Missing $src" >&2
    return 1
  }
  if [[ -f $dest ]] && cmp -s "$src" "$dest"; then
    return 0
  fi
  mkdir -p "${dest:h}"
  cp -p "$src" "$dest"
  codesign --force --deep --sign - "$app"
  codesign --verify --deep --strict "$app"
  xattr -dr com.apple.quarantine "$app"
}

phase_1_admin_installs() {
  local url latest_version installed_version app="/Applications/LibreWolf.app"

  url="$(curl -fsSL --compressed https://librewolf.net/installation/macos/ \
    | grep -Eo 'https://dl\.librewolf\.net/librewolf/[^"]*macos-arm64-package\.dmg' \
    | librewolf_select_newest_url)"
  if [[ -z $url ]]; then
    echo "Could not find latest LibreWolf arm64 DMG."
    [[ -d $app ]] || return 1
  else
    latest_version="$(librewolf_version_from_dmg_url "$url")"
    installed_version=""
    if [[ -x $app/Contents/MacOS/librewolf ]]; then
      installed_version="$("$app/Contents/MacOS/librewolf" --version | awk '{print $NF}')"
    fi

    if [[ -z $installed_version ]] || librewolf_version_gt "$latest_version" "$installed_version"; then
      librewolf_install_dmg "$url" || return 1
    fi
  fi

  librewolf_sync_policies
}
