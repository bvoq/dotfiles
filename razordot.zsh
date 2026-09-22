#!/bin/zsh

######################
# MODIFIABLE SECTION #
######################
# Add/Source any of your own custom functions here, that should be available to the install scripts.

# Add your install folders here.
install_folders=(
  razordot/brew
  zsh
  # claude
  # copilot
  core
  creative
  # crypto
  # csharp
  # devops
  emacs
  ffmpeg_ytdlp
  formal
  generic
  generic-cask
  grok
  microsoft-office
  git
  iterm
  librewolf
  localai
  lowlevel
  macos
  messaging
  #mobile
  nvim
  quarto
  rclone
  readline
  ripgrep
  ruby
  ssdeep
  ssh
  starship
  # tex
  tmux
  tor
  kitty
  vim
  vscode
  xcode
)
# OPTIONS:

# Disable updates by commenting/removing the below line.
RAZORDOT_UPDATE_LOCATION="https://raw.githubusercontent.com/razordot/razordot/refs/heads/main/razordot.zsh"

# install_folders entries containing a "/" are acquired into gitignored folders.
# Public GitHub repos are downloaded with curl first; git is used only as a fallback.

# Preset every waitconfirm prompt (0 = stop, 1 = keep going). Leave commented to be asked.
# WAITCONFIRM_DECISION=1

########################
# UNMODIFIABLE SECTION #
########################
# This file was checked with: shfmt -ln zsh -i 2 -ci -sr -d razordot.zsh
# This section is managed by the RAZORDOT_UPDATE_LOCATION and is under the Apache License, Version 2.0.
# Do not modify below here, unless you fork it with a different name, as "RAZORDOT" is reserved for this project.

cd "${0:a:h}"
RAZORDOT_SCRIPT_NAME="${0:A:t}"

razordot_self_update() {
  local script_location="$1" invoke_location="$2"
  shift 2

  [[ -n "${RAZORDOT_UPDATE_LOCATION:-}" ]] || return 0 # disabled when unset
  [[ -t 0 ]] || return 0                               # only when stdin is a tty (we prompt below)
  command -v curl > /dev/null 2>&1 || {
    echo "razordot: curl is required for self-update."
    return 1
  }
  command -v awk > /dev/null 2>&1 || {
    echo "razordot: awk is required for self-update."
    return 1
  }

  local marker='# UNMODIFIABLE SECTION #'
  grep -qxF "$marker" "$script_location" 2> /dev/null || return 0 # only if the marker exists

  local remote
  remote="$(curl -fsSL "$RAZORDOT_UPDATE_LOCATION" 2> /dev/null)" || return 0

  # The managed section is the marker line (first exact match) through EOF.
  local local_section="$(awk -v m="$marker" '$0==m{f=1} f' "$script_location")"
  local remote_section="$(printf '%s\n' "$remote" | awk -v m="$marker" '$0==m{f=1} f')"

  [[ -n "$remote_section" ]] || return 0
  if [[ "$local_section" == "$remote_section" ]]; then
    echo "razordot is up to date."
    return 0
  fi

  echo "razordot: the managed section differs from the canonical copy (< current, > update):"
  diff <(printf '%s\n' "$local_section") <(printf '%s\n' "$remote_section") || true

  echo "razordot: update the unmodifiable section and re-run? (remove RAZORDOT_UPDATE_LOCATION to disable update downloads)"
  waitconfirm
  echo "razordot: updating the unmodifiable section and re-running."

  local top="$(awk -v m="$marker" '$0==m{exit} {print}' "$script_location")"
  local tmp
  tmp="$(mktemp -t razordot)" || return 1
  cp -p "$script_location" "$tmp" || {
    rm -f "$tmp"
    return 1
  }
  {
    printf '%s\n' "$top"
    printf '%s\n' "$remote_section"
  } > "$tmp"

  if ! mv "$tmp" "$script_location"; then
    echo "razordot: could not write $script_location; continuing without updating."
    rm -f "$tmp"
    return 1
  fi

  exec /bin/zsh "$invoke_location" "$@"
}

# If your machine has a different admin check, please create a PR.
isadminuser() { [[ $EUID -eq 0 ]] || id -Gn $1 | grep -qwE 'admin|sudo|wheel'; }

waitconfirm() {
  if [[ -n "${WAITCONFIRM_DECISION:-}" ]]; then
    if [[ "$WAITCONFIRM_DECISION" == 1 ]]; then
      return 0
    else
      [[ -n "${WAITCONFIRM_ABORT_MESSAGE:-}" ]] && echo "$WAITCONFIRM_ABORT_MESSAGE"
      exit "${WAITCONFIRM_ABORT_EXIT_CODE:-0}"
    fi
  fi
  if read -q "choice?Continue [press y/n]? "; then
    echo "Continuing..."
  else
    [[ -n "${WAITCONFIRM_ABORT_MESSAGE:-}" ]] && echo "$WAITCONFIRM_ABORT_MESSAGE"
    exit "${WAITCONFIRM_ABORT_EXIT_CODE:-0}"
  fi
}

# A function that returns nonzero without tripping errexit in-context.
_zsh_error_handler_command_location() {
  ZSH_ERROR_HANDLER_LAST_LOCATION="${funcfiletrace[1]}"
}

_zsh_error_handler_source_line() {
  local file="$1" lineno="$2"
  local content_on_line trimmed_line limited_line padded_line
  content_on_line="$(awk "NR == $lineno" "$file" 2> /dev/null)"
  trimmed_line=$(echo "$content_on_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [[ ${#trimmed_line} -gt 50 ]]; then
    limited_line="${trimmed_line:0:47}..."
  else
    limited_line="$trimmed_line"
  fi
  padded_line=$(printf "%-50s" "$limited_line")
  echo "\t$padded_line  on line $lineno\t in file $file."
}

_zsh_error_handler_trap() {
  # Iterate over the stack trace to find the original error location
  echo "Encountered an error. Stacktrace:"
  for ((i = ${#funcfiletrace[@]}; i >= 1; i--)); do
    fileandlineno=${funcfiletrace[i]}
    file=${fileandlineno%%:*}   # Get the first part before the first ':'
    lineno=${fileandlineno##*:} # Get the last part after the last ':'
    _zsh_error_handler_source_line "$file" "$lineno"
  done
  if [[ -n "$ZSH_ERROR_HANDLER_LAST_LOCATION" && "$ZSH_ERROR_HANDLER_LAST_LOCATION" != "${funcfiletrace[1]}" ]]; then
    _zsh_error_handler_source_line "${ZSH_ERROR_HANDLER_LAST_LOCATION%%:*}" "${ZSH_ERROR_HANDLER_LAST_LOCATION##*:}"
  fi
}

set_error_handler() {
  set -e
  trap '_zsh_error_handler_command_location' DEBUG
  trap '_zsh_error_handler_trap' ERR
}

link_dotfile() {
  local source_path="${1:a}"
  local target_path="${2:a}"
  local backup_root="$PWD/backups"
  local backup_path

  [[ -e "$source_path" || -L "$source_path" ]] || {
    echo "Dotfile source missing: $source_path"
    return 1
  }

  if [[ "$target_path" == "$HOME/"* ]]; then
    backup_path="$backup_root/home/${target_path#$HOME/}"
  else
    backup_path="$backup_root/absolute/${target_path#/}"
  fi

  if [[ -e "$target_path" || -L "$target_path" ]]; then
    if [[ -L "$target_path" && "$(readlink "$target_path")" == "$source_path" ]]; then
      return 0
    fi

    local backup_base="$backup_path"
    local backup_suffix=1
    while [[ -e "$backup_path" || -L "$backup_path" ]]; do
      backup_path="$backup_base.$backup_suffix"
      ((backup_suffix++))
    done

    mkdir -p "${backup_path:h}"
    mv "$target_path" "$backup_path"
  fi

  mkdir -p "${target_path:h}"
  ln -sfn "$source_path" "$target_path"
}

prune_broken_dotfile_links() {
  local dir link target
  for dir in "$@"; do
    [[ -d "$dir" ]] || continue
    for link in "$dir"/*(N@) "$dir"/.*(N@); do
      [[ -e "$link" ]] && continue
      target="$(readlink "$link")"
      echo "Removing broken dotfile link: $link -> $target"
      rm -f "$link"
    done
  done
}

# Materialize install_folders entries that name a repo (detected by a "/") into
# local gitignored folders, so the phase loops treat them like any other plugin
# folder. Public GitHub repos are downloaded by curl from a pinned commit archive.
# If curl cannot access the repo (for example a private repo), git is used as a
# fallback. First use is gated behind waitconfirm and pinned to an exact commit
# (trust on first use); a pinned repo re-resolves to the same commit later.
_razordot_repo_url() {
  local spec="$1"
  if [[ "$spec" == *"://"* || "$spec" == *@*:* ]]; then
    printf '%s\n' "$spec" # full https/ssh URL, used as-is
  else
    printf '%s\n' "https://github.com/${spec%.git}.git" # "owner/repo" shorthand
  fi
}

_razordot_repo_folder() {
  local base="${1%.git}"
  base="${base%/}"
  printf '%s\n' "${base##*/}"
}

_razordot_github_slug() {
  local spec="${1%.git}"
  spec="${spec%/}"
  case "$spec" in
    git@github.com:*) spec="${spec#git@github.com:}" ;;
    ssh://git@github.com/*) spec="${spec#ssh://git@github.com/}" ;;
    https://github.com/*) spec="${spec#https://github.com/}" ;;
    http://github.com/*) spec="${spec#http://github.com/}" ;;
    git://github.com/*) spec="${spec#git://github.com/}" ;;
    github.com/*) spec="${spec#github.com/}" ;;
  esac

  [[ "$spec" == */* ]] || return 1
  [[ "$spec" == *"://"* || "$spec" == *@*:* ]] && return 1

  local owner="${spec%%/*}"
  local rest="${spec#*/}"
  local repo="${rest%%/*}"
  [[ -n "$owner" && -n "$repo" ]] || return 1
  printf '%s/%s\n' "$owner" "$repo"
}

_razordot_curl_resolve_head() {
  local url="$1" slug sha
  command -v curl > /dev/null 2>&1 || return 1
  slug="$(_razordot_github_slug "$url")" || return 1
  sha="$(curl -fsSL "https://api.github.com/repos/$slug/commits/HEAD" 2> /dev/null |
    awk -F'"' '$2 == "sha" { print $4; exit }')" || return 1
  [[ -n "$sha" ]] || return 1
  printf '%s\n' "$sha"
}

_razordot_resolve_head() {
  local url="$1" sha
  if sha="$(_razordot_curl_resolve_head "$url")"; then
    printf '%s\n' "$sha"
    return 0
  fi

  command -v git > /dev/null 2>&1 || return 1
  git ls-remote "$url" HEAD | awk 'NR == 1 { print $1 }'
}

# Pins are recorded in .gitignore, keeping the ignore entry and the pinned commit
# together and version-controlled. Format is two lines, the pin on a comment line
# directly above the ignore entry (git does not support trailing comments):
#   # <script-name> <folder>/ <url> <sha>
#   <folder>/
_razordot_download_pin() {
  [[ -f .gitignore ]] || return 0
  awk -v f="# $RAZORDOT_SCRIPT_NAME $1/ " 'index($0, f) == 1 { print $NF }' .gitignore
}

_razordot_pin_download() {
  local folder="$1" url="$2" sha="$3"
  touch .gitignore
  # keep entries line-separated even if .gitignore has no trailing newline
  [[ -s .gitignore && -n "$(tail -c1 .gitignore)" ]] && echo >> .gitignore
  local comment_prefix="# $RAZORDOT_SCRIPT_NAME $folder/ "
  local ignore_line="$folder/"
  local tmp
  tmp="$(mktemp -t razordot)" || return 1
  awk -v c="$comment_prefix" -v i="$ignore_line" '
        skip_ignore && $0 == i { skip_ignore = 0; next }
        { skip_ignore = 0 }
        index($0, c) == 1 { skip_ignore = 1; next }
        { print }
    ' .gitignore > "$tmp" && mv "$tmp" .gitignore || {
    rm -f "$tmp"
    return 1
  }
  [[ -s .gitignore && -n "$(tail -c1 .gitignore)" ]] && echo >> .gitignore
  echo "# $RAZORDOT_SCRIPT_NAME $folder/ $url $sha" >> .gitignore
  echo "$folder/" >> .gitignore
}

_razordot_curl_checkout() {
  local url="$1" folder="$2" sha="$3"
  local slug tmp archive
  local -a extracted

  command -v curl > /dev/null 2>&1 || return 1
  command -v tar > /dev/null 2>&1 || return 1
  slug="$(_razordot_github_slug "$url")" || return 1

  if [[ -f "$folder/.razordot-commit" && "$(cat "$folder/.razordot-commit" 2> /dev/null)" == "$sha" ]]; then
    return 0
  fi

  tmp="$(mktemp -d -t razordot)" || return 1
  archive="$tmp/archive.tar.gz"
  if ! curl -fsSL "https://api.github.com/repos/$slug/tarball/$sha" -o "$archive"; then
    rm -rf "$tmp"
    return 1
  fi
  if ! tar -xzf "$archive" -C "$tmp"; then
    rm -rf "$tmp"
    return 1
  fi

  extracted=("$tmp"/*(N/))
  if ((${#extracted[@]} == 0)); then
    rm -rf "$tmp"
    return 1
  fi

  rm -rf "$folder"
  mkdir -p "${folder:h}"
  if ! mv "${extracted[1]}" "$folder"; then
    rm -rf "$tmp"
    return 1
  fi
  printf '%s\n' "$sha" > "$folder/.razordot-commit"
  rm -rf "$tmp"
}

_razordot_git_checkout() {
  local url="$1" folder="$2" sha="$3"
  command -v git > /dev/null 2>&1 || return 1

  if [[ -d "$folder/.git" ]]; then
    [[ "$(git -C "$folder" rev-parse HEAD 2> /dev/null)" == "$sha" ]] && return 0
  else
    rm -rf "$folder"
    mkdir -p "$folder"
    git -C "$folder" init -q
    git -C "$folder" remote add origin "$url" 2> /dev/null ||
      git -C "$folder" remote set-url origin "$url"
  fi
  if git -C "$folder" fetch --depth 1 origin "$sha" 2> /dev/null; then
    git -C "$folder" checkout -q FETCH_HEAD
  else
    git -C "$folder" fetch -q origin && git -C "$folder" checkout -q "$sha"
  fi
}

_razordot_download_checkout() {
  local url="$1" folder="$2" sha="$3"
  if _razordot_curl_checkout "$url" "$folder" "$sha"; then
    return 0
  fi

  echo "razordot: curl download failed for $url; trying git fallback."
  _razordot_git_checkout "$url" "$folder" "$sha"
}

_razordot_ensure_download() {
  local url="$1" folder="$2" sha
  sha="$(_razordot_download_pin "$folder")"
  if [[ -z "$sha" ]]; then
    sha="$(_razordot_resolve_head "$url")"
    [[ -n "$sha" ]] || {
      echo "razordot: could not resolve a commit for $url"
      return 1
    }
    echo "razordot: first use of remote folder '$folder' ($url)"
    echo "razordot: pinning to commit $sha"
    waitconfirm
    _razordot_download_checkout "$url" "$folder" "$sha"
    _razordot_pin_download "$folder" "$url" "$sha"
  else
    _razordot_download_checkout "$url" "$folder" "$sha"
  fi
}

# Repos previously materialized by this script as gitignored downloads,
# identified by .gitignore pin lines ("# <script-name> <folder>/ <url> <sha>").
_razordot_managed_download_folders() {
  [[ -f .gitignore ]] || return 0
  awk -v owner="$RAZORDOT_SCRIPT_NAME" '$1 == "#" && $2 == owner && $3 ~ /\/$/ { s = $3; sub(/\/$/, "", s); print s }' .gitignore
}

_razordot_other_download_owners_exist() {
  [[ -f .gitignore ]] || return 1
  awk -v owner="$RAZORDOT_SCRIPT_NAME" -v folder="$1/" '
        $1 == "#" && $2 != owner && $3 == folder { found = 1 }
        END { exit found ? 0 : 1 }
    ' .gitignore
}

# Remove a gitignored download folder and its .gitignore pin lines (both the
# comment pin line and the bare ignore entry directly below it).
_razordot_remove_download() {
  local folder="$1" tmp
  if _razordot_other_download_owners_exist "$folder"; then
    echo "razordot: removing stale download pin for '$folder' (folder kept; another script still owns it)"
  else
    echo "razordot: removing stale download folder '$folder'"
    rm -rf "$folder"
  fi
  [[ -f .gitignore ]] || return 0
  tmp="$(mktemp -t razordot)" || return 1
  awk -v c="# $RAZORDOT_SCRIPT_NAME $folder/ " -v i="$folder/" '
        skip_ignore && $0 == i { skip_ignore = 0; next }
        { skip_ignore = 0 }
        index($0, c) == 1 { skip_ignore = 1; next }
        { print }
    ' .gitignore > "$tmp" &&
    mv "$tmp" .gitignore || {
    rm -f "$tmp"
    return 1
  }
}

resolve_install_repos() {
  local i spec url folder f
  local -A desired
  for ((i = 1; i <= $#install_folders; i++)); do
    spec="${install_folders[i]}"
    [[ "$spec" == */* ]] || continue
    folder="$(_razordot_repo_folder "$spec")"
    desired[$folder]=1
  done

  # Reconcile away stale managed downloads before acquiring. Skipped in
  # single-folder mode, which cannot see the full list and would otherwise
  # treat every other repo as removed.
  if ((${RAZORDOT_SINGLE_FOLDER:-0} == 0)); then
    for f in $(_razordot_managed_download_folders); do
      [[ -n "${desired[$f]}" ]] || _razordot_remove_download "$f"
    done
  fi

  for ((i = 1; i <= $#install_folders; i++)); do
    spec="${install_folders[i]}"
    [[ "$spec" == */* ]] || continue
    url="$(_razordot_repo_url "$spec")"
    folder="$(_razordot_repo_folder "$spec")"
    _razordot_ensure_download "$url" "$folder"
    install_folders[i]="$folder"
  done
}

assure_userlevel_zsh() {
  # $SHELL is the login shell (persists across subshells), portable across macOS/Linux/BSD.
  if [[ "$SHELL" != */zsh ]]; then
    local zsh_path="$(command -v zsh)"
    echo "Your current login shell is $SHELL. Let's change this to zsh."
    echo "This script will execute: chsh -s $zsh_path"
    waitconfirm
    chsh -s "$zsh_path"
  fi
}

# Darwin specific
check_not_rosetta() {
  [[ $OSTYPE == 'darwin'* ]] || return 0
  if [[ "$(uname -m)" == "arm64" && "$(sysctl -n sysctl.proc_translated)" != 0 ]]; then
    echo "It seems you are running this script with Rosetta enabled."
    echo "Make sure that this terminal or session has Rosetta turned off."
    echo "For example: Right-Click Terminal > Get Info > Uncheck Open using Rosetta"
    exit 1
  fi
}

_darwin_developer_tools_present() {
  [[ $OSTYPE == 'darwin'* ]] || return 0

  local developer_dir
  developer_dir="$(xcode-select -p 2> /dev/null)" || return 1
  [[ -d "$developer_dir" ]] || return 1
}

_darwin_developer_tools_ready() {
  [[ $OSTYPE == 'darwin'* ]] || return 0
  _darwin_developer_tools_present || return 1

  local developer_dir
  developer_dir="$(xcode-select -p 2> /dev/null)" || return 1

  if [[ "$developer_dir" == *'.app/Contents/Developer' ]] && command -v xcodebuild > /dev/null 2>&1; then
    xcodebuild -license check > /dev/null 2>&1 || return 1
  fi
}

_darwin_accept_xcode_license() {
  [[ $OSTYPE == 'darwin'* ]] || return 0
  command -v xcodebuild > /dev/null 2>&1 || return 1
  isadminuser || return 1
  sudo xcodebuild -license accept
}

ensure_developer_tools_installed() {
  [[ $OSTYPE == 'darwin'* ]] || return 0
  _darwin_developer_tools_ready && return 0

  local WAITCONFIRM_ABORT_MESSAGE="macOS Developer Tools are not available. The user aborted installing them or accepting the license agreements."
  local WAITCONFIRM_ABORT_EXIT_CODE=1

  echo "macOS developer tools aren't installed yet."
  echo "This script will execute: xcode-select --install if the tools are missing."
  if isadminuser; then
    echo "This script will also execute: sudo xcodebuild -license accept after the tools are present."
  else
    echo "You are not an admin user; accept Xcode license agreements manually if prompted."
  fi
  waitconfirm
  _darwin_developer_tools_present || xcode-select --install > /dev/null 2>&1 || true

  while true; do
    if _darwin_developer_tools_present; then
      _darwin_accept_xcode_license || true
    fi
    _darwin_developer_tools_ready && return 0

    echo "macOS developer tools aren't installed yet."
    if _darwin_developer_tools_present; then
      echo "Accept any remaining license agreements, then continue to check again."
    else
      echo "Finish the macOS Developer Tools installation, then continue to check again."
    fi
    waitconfirm
  done
}

################
# Run RAZORDOT #
################

set_error_handler
razordot_self_update "${0:A}" "${0:a}" "$@"
assure_userlevel_zsh
check_not_rosetta
ensure_developer_tools_installed

# Optional: `./razordot.zsh --install <folder>` runs only that single plugin folder (even for disabled folders).
if [[ "$1" == "--install" ]]; then
  folder="${2%/}"
  if [[ ! -f "$folder/install.zsh" ]]; then
    echo "Usage: ${0:t} --install <folder>  (no '$folder/install.zsh' found)"
    exit 1
  fi
  install_folders=("$folder")
  unset folder
  RAZORDOT_SINGLE_FOLDER=1
fi

# Materialize any remote-repo entries (those containing a "/") into local folders.
resolve_install_repos

install_scripts=(${^install_folders}/install.zsh)

######################################################
# Section 0: Bootstrap before admin-capable installs #
######################################################

if isadminuser; then
  for install_script in "${install_scripts[@]}"; do
    phase_0_bootstrap() { :; }
    source "$install_script"
    phase_0_bootstrap
  done
fi

##################################################################
# Section 1: Brew installs and other admin-capable user installs #
##################################################################

if isadminuser; then
  for install_script in "${install_scripts[@]}"; do
    phase_1_admin_installs() { :; }
    source "$install_script"
    phase_1_admin_installs
  done
else
  echo "Skipping admin-capable user installs."
fi

##################################
# Section 2: User-level installs #
##################################

echo "Installing other user-level tools."

for install_script in "${install_scripts[@]}"; do
  phase_2_user_installs() { :; }
  source "$install_script"
  phase_2_user_installs
done

#########################################################
# Section 3: Dotfiles (user-level) install and sourcing #
#########################################################

echo "Linking dotfiles after installation, because some install script like to add stuff to .zshrc (evil right?!?)."

for install_script in "${install_scripts[@]}"; do
  phase_3_dotfiles() { :; }
  source "$install_script"
  phase_3_dotfiles
done

# Drop any dotfile links we used to create but no longer do (e.g. renamed or
# removed plugin folders), so the loaders below don't try to source dead links.
prune_broken_dotfile_links "$HOME/.zshrc.d" "$HOME/.zshenv.d" "$HOME/.zprofile.d"

# ~/.zshenv, ~/.zprofile and ~/.zshrc are tiny loaders that just source the
# ~/.zshenv.d, ~/.zprofile.d and ~/.zshrc.d fragments linked by the plugin folders above.
mkdir -p backups
{ [[ -e "$HOME/.zshenv" || -L "$HOME/.zshenv" ]]; } && mv "$HOME/.zshenv" backups/.zshenv
{ [[ -e "$HOME/.zprofile" || -L "$HOME/.zprofile" ]]; } && mv "$HOME/.zprofile" backups/.zprofile
{ [[ -e "$HOME/.zshrc" || -L "$HOME/.zshrc" ]]; } && mv "$HOME/.zshrc" backups/.zshrc

cat > "$HOME/.zshenv" << 'RAZORDOT_ZSHENV'
#!/bin/zsh

for zshenv_file in "${ZDOTDIR:-$HOME}"/.zshenv.d/zshenv_*(N); do
  source "$zshenv_file"
done
unset zshenv_file
RAZORDOT_ZSHENV

cat > "$HOME/.zprofile" << 'RAZORDOT_ZPROFILE'
#!/bin/zsh

for zprofile_file in "${ZDOTDIR:-$HOME}"/.zprofile.d/zprofile_*(N); do
  source "$zprofile_file"
done
unset zprofile_file
RAZORDOT_ZPROFILE

cat > "$HOME/.zshrc" << 'RAZORDOT_ZSHRC'
#!/bin/zsh

for zshrc_file in "${ZDOTDIR:-$HOME}"/.zshrc.d/*.zsh(N); do
  source "$zshrc_file"
  (( ${RAZORDOT_STOP:-0} )) && break
done
unset zshrc_file RAZORDOT_STOP
RAZORDOT_ZSHRC

source ~/.zshrc

####################################################################################
# Section 4: Installing user-level tools that require the dotfiles to be in place. #
####################################################################################

for install_script in "${install_scripts[@]}"; do
  phase_4_post_dotfiles() { :; }
  source "$install_script"
  phase_4_post_dotfiles
done

##############################################################
# Section 5: Heavy system changes, requires admin and reboot #
##############################################################

if isadminuser; then
  for install_script in "${install_scripts[@]}"; do
    phase_5_system_changes() { :; }
    source "$install_script"
    phase_5_system_changes
  done
fi
