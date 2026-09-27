# e opens an Emacs window.
# The macOS daemon is the emacs-daemon LaunchAgent. Connect when it answers,
# start it when it is not running, and when it is stuck offer to quit it and
# start a new one. The server socket appears only after Emacs finishes loading.

_emacs_daemon_socket() {
  local uid_dir="emacs$(id -u)" candidate alt
  if [[ -n ${XDG_RUNTIME_DIR:-} ]]; then
    candidate="${XDG_RUNTIME_DIR%/}/emacs/server"
  else
    candidate="${${TMPDIR:-/tmp}%/}/${uid_dir}/server"
  fi
  if [[ -S $candidate ]]; then
    print -r -- "$candidate"
    return 0
  fi
  for alt in "/tmp/${uid_dir}/server" "/private/tmp/${uid_dir}/server"; do
    if [[ -S $alt ]]; then
      print -r -- "$alt"
      return 0
    fi
  done
  print -r -- "$candidate"
}

_emacs_daemon_live_socket() {
  local pid="$1" live
  [[ -n $pid ]] || return 1
  live="$(lsof -nP -a -p "$pid" -U -Fn 2> /dev/null \
    | awk 'substr($0,1,1)=="n" && $0 ~ /\/server$/ { print substr($0,2); exit }')"
  [[ -n $live && -S $live ]] || return 1
  print -r -- "$live"
}

_emacs_daemon_elapsed() {
  local etime days=0 rest h=0 m=0 s=0
  etime="$(ps -p "$1" -o etime= 2> /dev/null)" || return 1
  etime="${etime//[[:space:]]/}"
  [[ -n $etime ]] || return 1
  if [[ $etime == *-* ]]; then
    days="${etime%%-*}"
    etime="${etime#*-}"
  fi
  case "$etime" in
    *:*:*)
      h="${etime%%:*}"
      rest="${etime#*:}"
      m="${rest%%:*}"
      s="${rest#*:}"
      ;;
    *:*)
      m="${etime%%:*}"
      s="${etime#*:}"
      ;;
    *)
      s="$etime"
      ;;
  esac
  print -r -- $((10#$days * 86400 + 10#$h * 3600 + 10#$m * 60 + 10#$s))
}

# Wait until Emacs answers. $4 is a limit in seconds, or 0 to wait until Ctrl-C.
# Lines the daemon writes while we wait are printed as they appear.
_emacs_daemon_wait() {
  local client="$1" domain="$2" label="$3" max_seconds="$4"
  shift 4
  local -a logs=("$@")
  local -A seen
  local log_file line_count previous socket pid live
  local started=$SECONDS last_note=$SECONDS grew=0 probe_status=1

  for log_file in "${logs[@]}"; do
    seen[$log_file]="$(wc -l < "$log_file" 2> /dev/null || echo 0)"
  done

  while true; do
    if ((max_seconds > 0 && SECONDS - started >= max_seconds)); then
      return 1
    fi

    pid="$(launchctl print "$domain/$label" 2> /dev/null \
      | awk '/^[[:space:]]*pid =/{print $3; exit}' || true)"
    socket="$(_emacs_daemon_socket)"
    if [[ ! -S $socket && -n $pid ]]; then
      if live="$(_emacs_daemon_live_socket "$pid")"; then
        socket="$live"
      fi
    fi

    probe_status=1
    if [[ -S $socket ]]; then
      if gtimeout 1 "$client" --socket-name="$socket" --eval t > /dev/null 2>&1; then
        return 0
      fi
      probe_status=$?
    fi
    if ((probe_status == 130)); then
      echo
      echo "Stopped waiting for Emacs."
      return 130
    fi

    grew=0
    for log_file in "${logs[@]}"; do
      line_count="$(wc -l < "$log_file")"
      line_count=$((line_count))
      previous="${seen[$log_file]:-0}"
      previous=$((previous))
      if ((line_count < previous)); then
        previous=0
      fi
      if ((line_count > previous)); then
        echo "==> $log_file <=="
        sed -n "$((previous + 1)),${line_count}p" "$log_file"
        seen[$log_file]="$line_count"
        grew=1
      fi
    done

    if ((grew)); then
      last_note=$SECONDS
    elif ((SECONDS - last_note >= 5)); then
      echo "Still waiting for Emacs."
      last_note=$SECONDS
    fi

    sleep 0.2 || {
      echo
      echo "Stopped waiting for Emacs."
      return 130
    }
  done
}

_emacs_daemon_blocked_on_prompt() {
  local sample_text="$1"
  [[ -n $sample_text ]] || return 1
  print -r -- "$sample_text" \
    | grep -E -q 'read-multiple-choice|read_multiple_choice|read-from-minibuffer|Fread_from_minibuffer|read_minibuf|yes-or-no-p|y-or-n-p'
}

e() {
  # No LaunchAgent on this system. emacsclient starts a daemon if needed.
  if [[ "$OSTYPE" != darwin* ]]; then
    emacsclient --alternate-editor='' --create-frame --no-wait "$@"
    return
  fi

  local client=/Applications/Emacs.app/Contents/MacOS/bin/emacsclient
  [[ -x $client ]] || client="$(command -v emacsclient)" || {
    echo "emacsclient was not found." >&2
    return 1
  }
  command -v gtimeout > /dev/null || {
    echo "gtimeout was not found. Install coreutils." >&2
    return 1
  }

  local domain="gui/$(id -u)"
  local label=emacs-daemon
  local plist="$HOME/Library/LaunchAgents/$label.plist"
  [[ -f $plist ]] || {
    echo "The Emacs daemon is not installed ($plist)." >&2
    return 1
  }

  local -a daemon_logs=(
    "$HOME/Library/Logs/$label.out.log"
    "$HOME/Library/Logs/$label.err.log"
  )
  mkdir -p "$HOME/Library/Logs"
  touch "${daemon_logs[@]}"

  local restart_count=0
  local print_out state pid socket live probe probe_status
  local failure_reason elapsed sample_text log_file

  while true; do
    failure_reason=""
    print_out="$(launchctl print "$domain/$label" 2> /dev/null || true)"
    state="$(print -r -- "$print_out" | awk '/^[[:space:]]*state =/{print $3; exit}')"
    pid="$(print -r -- "$print_out" | awk '/^[[:space:]]*pid =/{print $3; exit}')"

    socket="$(_emacs_daemon_socket)"
    if [[ ! -S $socket && -n $pid ]]; then
      if live="$(_emacs_daemon_live_socket "$pid")"; then
        socket="$live"
      fi
    fi

    probe=""
    probe_status=1
    if [[ -S $socket ]]; then
      if probe="$(gtimeout 2 "$client" --socket-name="$socket" --eval t 2>&1)"; then
        probe_status=0
      else
        probe_status=$?
      fi
    fi
    if ((probe_status == 130)); then
      return 130
    fi

    if ((probe_status == 0)); then
      sample_text=""
      if [[ -n $pid ]]; then
        sample_text="$(sample "$pid" 0.05 1 2> /dev/null || true)"
      fi

      # Emacs is asking a question, and there is no window in which to answer it.
      if _emacs_daemon_blocked_on_prompt "$sample_text"; then
        failure_reason="Emacs is waiting for an answer, but no window is open."
      # Emacs is ready. Open a window and bring it forward.
      elif gtimeout 5 "$client" --socket-name="$socket" --create-frame --no-wait "$@"; then
        open -a Emacs
        return 0
      else
        probe_status=$?
        if ((probe_status == 130)); then
          return 130
        fi
        failure_reason="Emacs did not open a window within 5 seconds."
      fi
    elif [[ $state != running || -z $pid ]]; then
      # Nothing is running. Start it.
      echo "Emacs is not running. Starting it."
      if ! launchctl kickstart "$domain/$label" > /dev/null 2>&1; then
        launchctl bootstrap "$domain" "$plist" > /dev/null 2>&1 || return 1
        launchctl kickstart "$domain/$label" > /dev/null 2>&1 || return 1
      fi
      echo "Waiting for Emacs. Press Ctrl-C to stop."
      _emacs_daemon_wait "$client" "$domain" "$label" 0 "${daemon_logs[@]}" || return $?
      continue
    else
      elapsed=""
      if ! elapsed="$(_emacs_daemon_elapsed "$pid")"; then
        elapsed=""
      fi

      # Emacs has just started and is still loading.
      if [[ ! -S $socket && -n $elapsed ]] && ((elapsed < 60)); then
        echo "Emacs is still starting. Press Ctrl-C to stop."
        if _emacs_daemon_wait "$client" "$domain" "$label" $((60 - elapsed)) "${daemon_logs[@]}"; then
          continue
        fi
        failure_reason="Emacs has been starting for over a minute and is still not ready."
      elif [[ ! -S $socket ]]; then
        failure_reason="Emacs is running but is not ready for a window."
      elif ((probe_status == 124)); then
        failure_reason="Emacs did not respond within 2 seconds."
      else
        failure_reason="Emacs did not respond."
      fi
    fi

    # A restart already failed. Stop instead of quitting Emacs again.
    if ((restart_count >= 1)); then
      echo "$failure_reason" >&2
      return 1
    fi

    echo "$failure_reason"
    if [[ -n $pid ]]; then
      echo "Emacs is running (pid $pid)."
    fi
    for log_file in "${daemon_logs[@]}"; do
      echo "==> $log_file <=="
      tail -n 10 "$log_file"
    done

    # Leave the current Emacs alone.
    if ! read -q "reply?Quit Emacs and start it again? [y/N] "; then
      echo
      echo "Left Emacs running."
      return 1
    fi
    echo

    # Quit the stuck Emacs. launchd starts a new one.
    if ! launchctl kickstart -k "$domain/$label" > /dev/null 2>&1; then
      launchctl bootstrap "$domain" "$plist" > /dev/null 2>&1 || return 1
      launchctl kickstart -k "$domain/$label" > /dev/null 2>&1 || return 1
    fi
    restart_count=$((restart_count + 1))

    echo "Waiting for Emacs. Press Ctrl-C to stop."
    _emacs_daemon_wait "$client" "$domain" "$label" 0 "${daemon_logs[@]}" || return $?
  done
}
