export GROK_TELEMETRY_TRACE_UPLOAD=0
export GROK_TELEMETRY_ENABLED=0

# Every launch uses --sandbox strict. --cwd is the physical directory the
# command was started in, unless a --cwd was already given. A session started
# without that profile cannot be resumed, because grok will not change a
# session's sandbox. sensitive_guard refuses the workspace before launch.
_grok_guard() {
  local arg expect_sandbox= ended= has_cwd= expect_cwd=
  local -a args
  sensitive_guard "$PWD" || return 1
  for arg in "$@"; do
    if [[ -n $ended ]]; then
      args+=("$arg")
      continue
    fi
    if [[ -n $expect_cwd ]]; then
      sensitive_guard "$arg" || return 1
      expect_cwd=
      has_cwd=1
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
      --cwd=*)
        sensitive_guard "${arg#--cwd=}" || return 1
        has_cwd=1
        args+=("$arg")
        ;;
      --cwd)
        expect_cwd=1
        has_cwd=1
        args+=("$arg")
        ;;
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
