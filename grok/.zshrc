export GROK_TELEMETRY_TRACE_UPLOAD=0
export GROK_TELEMETRY_ENABLED=0

# Refuse an interactive grok whose workspace is $HOME or any parent of it,
# Documents or Downloads themselves, or any path that enters private_keys
# or private_docs. Subdirectories of Documents and Downloads are allowed.
# Every launch uses --sandbox strict. --cwd is the physical directory the
# command was started in, unless a --cwd was already given. A session started
# without that profile cannot be resumed, because grok will not change a
# session's sandbox.
_grok_path_has_private() {
  local part
  local -a parts
  parts=("${(@s:/:)1}")
  for part in "${parts[@]}"; do
    part=${(L)part}
    if [[ $part == private_keys || $part == private_docs ]]; then
      return 0
    fi
  done
  return 1
}

_grok_dir_blocked() {
  local dir=$1 physical home docs downloads
  if _grok_path_has_private "$dir"; then
    print -ru2 -- "grok: refusing to start in ${dir} (private_keys and private_docs are blocked)"
    return 0
  fi
  physical=${dir:P}
  if _grok_path_has_private "$physical"; then
    print -ru2 -- "grok: refusing to start in ${physical} (private_keys and private_docs are blocked)"
    return 0
  fi
  home=${HOME:P}
  if [[ $physical == / || $physical == $home || ${home#$physical/} != $home ]]; then
    print -ru2 -- "grok: refusing to start in ${physical} (home directory or above)"
    return 0
  fi
  docs=${home}/Documents
  downloads=${home}/Downloads
  if [[ -d $docs ]]; then
    docs=${docs:P}
    if [[ $physical == $docs ]]; then
      print -ru2 -- "grok: refusing to start in ${physical} (Documents; use a subdirectory)"
      return 0
    fi
  fi
  if [[ -d $downloads ]]; then
    downloads=${downloads:P}
    if [[ $physical == $downloads ]]; then
      print -ru2 -- "grok: refusing to start in ${physical} (Downloads; use a subdirectory)"
      return 0
    fi
  fi
  return 1
}

_grok_launch_blocked() {
  local arg expect_cwd=
  _grok_dir_blocked "$PWD" && return 0
  for arg in "$@"; do
    if [[ -n $expect_cwd ]]; then
      _grok_dir_blocked "$arg" && return 0
      expect_cwd=
      continue
    fi
    case $arg in
      --cwd=*) _grok_dir_blocked "${arg#--cwd=}" && return 0 ;;
      --cwd) expect_cwd=1 ;;
      --) break ;;
    esac
  done
  return 1
}

_grok_guard() {
  local arg expect_sandbox= ended= has_cwd=
  local -a args
  _grok_launch_blocked "$@" && return 1
  for arg in "$@"; do
    if [[ -n $ended ]]; then
      args+=("$arg")
      continue
    fi
    if [[ -n $expect_sandbox ]]; then
      expect_sandbox=
      continue
    fi
    case $arg in
      --) ended=1; args+=("$arg") ;;
      --sandbox=*) ;;
      --sandbox) expect_sandbox=1 ;;
      --cwd=*) has_cwd=1; args+=("$arg") ;;
      --cwd) has_cwd=1; args+=("$arg") ;;
      *) args+=("$arg") ;;
    esac
  done
  if [[ -n $has_cwd ]]; then
    command grok --sandbox strict "${args[@]}"
  else
    command grok --sandbox strict --cwd "${PWD:P}" "${args[@]}"
  fi
}

alias grok='_grok_guard'
