alias localip="ipconfig getifaddr en0"
alias flush="dscacheutil -flushcache && killall -HUP mDNSResponder"
alias unquarantine="xattr -r -d com.apple.quarantine"
alias lscleanup="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder"
alias show="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
alias hide="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"
alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"
alias emptytrash="sudo rm -rfv /Volumes/*/.Trashes; sudo rm -rfv ~/.Trash; sudo rm -rfv /private/var/log/asl/*.asl; sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* 'delete from LSQuarantineEvent'"
# Recursively delete `.DS_Store` files
alias cleanup="find . -type f -name '*.DS_Store' -ls -delete"
alias cpwd='pwd | pbcopy'
alias chromekill="ps ux | grep '[C]hrome Helper --type=renderer' | grep -v extension-process | tr -s ' ' | cut -d ' ' -f2 | xargs kill"
alias mplaylist='mdfind -onlyin . "kMDItemContentTypeTree == \"public.audio\"" | while read -r file; do echo "$(mdls -name kMDItemDateAdded -raw "$file") $file"; done | sort | cut -d" " -f4- | xargs -I {} mpg123 "{}"'
alias vplaylist='mdfind -onlyin . "kMDItemContentTypeTree == \"public.movie\"" | while read -r file; do echo "$(mdls -name kMDItemDateAdded -raw "$file") $file"; done | sort | cut -d" " -f4- > playlist.m3u && open -a VLC playlist.m3u'

# IP addresses
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias localips="ifconfig -a | grep -o 'inet6\? \(addr:\)\?\s\?\(\(\([0-9]\+\.\)\{3\}[0-9]\+\)\|[a-fA-F0-9:]\+\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'"

# Show active network interfaces
alias ifactive="ifconfig | pcregrep -M -o '^[^\t:]+:([^\n]|\n\t)*status: active'"

# Defines: GET, HEAD, POST, PUT, DELETE, TRACE, OPTIONS:
for method in GET HEAD POST PUT DELETE TRACE OPTIONS; do
  alias "${method}"="lwp-request -m '${method}'"
done

#NGET, NHEAD, etc. for uncertified requests and most likely headers.
for method in GET HEAD POST PUT DELETE TRACE OPTIONS; do
  alias "N${method}"="PERL_LWP_SSL_VERIFY_HOSTNAME=0 lwp-request -m '${method}' -H 'Content-type: application/json' -H 'Accept: application/json'"
done

jscbin="/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Resources/jsc"
[ -e "${jscbin}" ] && alias jsc="${jscbin}"
unset jscbin

rgspotlight() {
  local query="kMDItemTextContent = \"$1\""
  echo "$query"
  mdfind "$query"
}
export -f rgspotlight > /dev/null

# javascript CLI
alias jsc='/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'

instruments() {
  [[ $# -gt 0 ]] || {
    echo "Usage: instruments <cmd> [args…]"
    return 1
  }
  local cmd_path
  cmd_path=$(command -v -- "$1") || {
    echo "Not found: $1"
    return 1
  }
  shift
  local output="/var/tmp/instruments-$(date '+%Y%m%d-%H%M%S').trace"
  xcrun xctrace record --no-prompt --output "$output" --launch -- "$cmd_path" "$@"
  echo "✅ Trace saved to $output"
  open "$output" -a Instruments.app
}

hopen() {
  local dir="${1:-.}"
  if [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
    open "$dir" -a Terminal.app
  elif [[ -d "/Applications/iTerm.app" ]]; then
    open "$dir" -a iTerm.app
  else
    open "$dir" -a Terminal.app
  fi
}
