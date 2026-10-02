# List all files colorized in long format
alias l="eza"

alias grabsite='wget -r -np --wait=1 -k --execute="robots = off" --mirror --random-wait --user-agent="Mozilla/5.0 (X11; Fedora; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0"'

# Find and interactively delete duplicate files
alias dup='fdupes -d'

# Merge PDF files, preserving hyperlinks
# Usage: `mergepdf input{1,2,3}.pdf`
alias mergepdf='gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=_merged.pdf'
alias mergepdf2='pdfjoin --rotateoversize false'

# Usage: pdfjoings merged.pdf file1.pdf file2.pdf ... fileN.pdf
pdfjoings() {
  gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile="$1" "${@:2}"
}

semver() { printf "%09d%09d%09d%09d" $(echo "$1" | tr '.' ' '); }

# First argument = dir, Second argument = location and name (.tar.xz)
compressdir() {
  if [ $# -eq 1 ]; then tar --xz -cf "$1.tar.xz" "$1"; fi
  if [ $# -eq 2 ]; then tar --xz -cf "$2.tar.xz" "$1"; fi
}

decompressdir() {
  bname=$(basename $1)
  fname=${bname%.tar.xz}
  tar --xz -xvf "$1"
  if [ $# -eq 2 ]; then mv "$fname" "$2"; fi
}

foldertopdf() {
  for d in "$@"; do
    if [ -d "$d" ]; then
      dname="${d%/}"
      echo "converting $d"
      (
        cd "$d" || exit 1
        files=(*.webp(N) *.png(N) *.jpg(N) *.jpeg(N) *.tif(N) *.tiff(N) *.pdf(N))
        echo "found $files"
        ((${#files[@]} == 0)) && exit 0
        files=("${(@on)files}")
        magick "${files[@]}" "../${dname}.pdf"
      )
    fi
  done
}

# Create a data URL from a file
dataurl() {
  local mimeType=$(file -b --mime-type "$1")
  if [[ $mimeType == text/* ]]; then
    mimeType="${mimeType};charset=utf-8"
  fi
  echo "data:${mimeType};base64,$(openssl base64 -in "$1" | tr -d '\n')"
}

# eg. utf8_encode Zoë
utf8_encode() {
  printf "\\\x%s" $(printf "$@" | xxd -p -c1 -u)
  if [ -t 1 ]; then
    echo ""
  fi
}

# eg. utf8_decode \\x5A\\x6F\\xC3\\xAB
utf8_decode() {
  perl -e "binmode(STDOUT, ':utf8'); print \"$@\""
  if [ -t 1 ]; then
    echo "" # newline
  fi
}

errors() {
  local regex='\b(?:abort(?:ed|ing|s)?|anomal(?:y|ies)|block(?:ed|ing|s)?|breach(?:ed|ing|es)?|break(?:s|ing|age)?|brok(?:e|en)|bugs?|cannot|code 1|compromis(?:e|ed|ing|es)?|conflict(?:ed|ing|s)?|corrupt(?:ed|ing|s|ion|ions)?|crash(?:ed|ing|es)?|critical|defect(?:ed|ing|s|ive)?|den(?:y|ied|ies|ial|ials)?|deprecat(?:e|ed|ing|es|ion|ions)?|detect(?:ed|ing|s)?|discrepanc(?:y|ies)|err(?:or|ors)?|exceed(?:ed|ing|s)?|except(?:ion|ions)?|expir(?:e|ed|es|ing)|fail(?:ed|ing|s|ure|ures)?|fatal|fault(?:ed|ing|s|y)?|forbidden|hang(?:ed|ing|s)?|illegal|incorrect|inconsistent|invalid|issue(?:s)?|kill(?:ed|ing|s)?|leak(?:ed|ing|s)?|limit(?:ed|ing|s)?|loss(?:es)?|mismatch(?:ed|ing|es)?|miss(?:ed|ing|es)?|mistake(?:n|s)?|no\s+route|not\s+found|not\s+known|not\s+permitted|overflow(?:ed|ing|s)?|overheat(?:ed|ing|s)?|panic(?:s|ked|king)?|problem(?:s|atic)?|race\s+condition|refus(?:e|ed|ing|es|al)?|reject(?:ed|ing|s|ion|ions)?|segfault(?:ed|ing|s)?|shutdown(?:s)?|terminat(?:e|ed|ing|es|ion|ions)?|threat(?:en|ened|ening|s)?|timedout(?:s)?|timed out|unavailable|unauthori[sz]ed|undefined|unexpected|unhandled|unknown|unreachable|unrecoverable|unresponsive|violat(?:e|ed|ing|es|ion|ions)?|(?:server|system|connection|service|network|database|application|link|interface|cluster)\s+down|(?:disk|memory|buffer|queue|log|cache|storage|heap|stack|table)\s+full|(?:connection|read|write|request|operation|session|login|execution|gateway|handshake)\s+timeout)\b'

  # Case: Input is an argument.
  if [ -t 0 ]; then
    # One argument: filename
    if [ "${#}" -eq 1 ]; then
      local surroundno=1
    elif [ "${#}" -eq 2 ]; then
      # Two arguments: filename and context lines
      local surroundno="$2"
    else
      echo "Usage: errors <file> [context_lines]" >&2
      echo "Alternative: cat <file> | errors [context_lines]" >&2
      return 1
    fi
    if command -v rg > /dev/null 2>&1; then
      rg -n --colors 'column:fg:blue' \
        --colors 'column:bg:yellow' \
        --colors 'column:style:bold' \
        --colors 'match:none' \
        --colors 'match:bg:0x33,0x66,0xFF' \
        --colors 'match:fg:white' \
        --colors 'match:style:bold' \
        --column \
        -C "$surroundno" "$regex" "$1"
    else
      grep -Ei -C "$surroundno" -n "$regex" "$1"
    fi
  # Case: Input is piped in.
  else
    if [ "${#}" -eq 0 ]; then
      local surroundno=1
    elif [ "${#}" -eq 1 ]; then
      local surroundno="$1"
    else
      echo "Usage: cat <file> | errors [context_lines]" >&2
      return 1
    fi
    if command -v rg > /dev/null 2>&1; then
      rg -n --colors 'column:fg:blue' \
        --colors 'column:bg:yellow' \
        --colors 'column:style:bold' \
        --colors 'match:none' \
        --colors 'match:bg:0x33,0x66,0xFF' \
        --colors 'match:fg:white' \
        --colors 'match:style:bold' \
        --column \
        -C "$surroundno" "$regex"
    else
      grep -n -Ei -C "$surroundno" "$regex"
    fi
  fi
}

__removesensitive() {
  echo "seding $1"
  sed -E -i.bak 's/K.{13}\$/EXAMPLE/g' "$1" && rm "$1.bak"
  sed -E -i.bak 's/K.{12}4/EXAMPLE/g' "$1" && rm "$1.bak"
  sed -E -i.bak 's/I.{7}\$/EXAMPLE/g' "$1" && rm "$1.bak"
  sed -E -i.bak 's/I.{6}4/EXAMPLE/g' "$1" && rm "$1.bak"
  sed -E -i.bak 's/AKIA[0-9A-Z]{16}/EXAMPLE_AWS_ACCESS_KEY/g' "$1" && rm "$1.bak"

  perl -0777 -pi -e 's/-----BEGIN.*?-----END.*?-----/-----BEGIN EXAMPLE KEY BLOCK-----\n-----END EXAMPLE KEY BLOCK-----/sg' "$1"
}
__removesensitiveandurls() {
  __removesensitive "$1"
  # remove all urls
  perl -pi -e 's{https?://[^<('"'"')"\s]+}{https://example.com}g' "$1"
  perl -pi -e 's{ftp?://[^<('"'"')"\s]+}{ftp://example}g' "$1"
  perl -pi -e 's{mysql?://[^<('"'"')"\s]+}{mysql://example}g' "$1"
  sed -E -i.bak 's/([a-zA-Z0-9._]+@[a-zA-Z0-9._]+\.[a-zA-Z0-9._]+)/example@example.com/g' "$1" && rm "$1.bak"
}

cattree() {
  local max_lines

  if (( $# == 0 )); then
    max_lines=
  elif (( $# == 1 )) && [[ $1 == <-> ]]; then
    max_lines=$1
  else
    print -u2 'usage: cattree [max_lines]'
    return 2
  fi

  find . -type f ! -name '.DS_Store' -exec zsh -c '
    max_lines=$1
    shift

    for f in "$@"; do
      printf "\n--- %s ---\n" "$f"
      if grep -Iq . -- "$f"; then
        if [[ -n $max_lines ]]; then
          sed -n "1,${max_lines}p" -- "$f"
        else
          cat -- "$f"
        fi
      else
        printf "[binary file]\n"
      fi
    done
  ' zsh "$max_lines" {} +
}

removesensitive() {
  local files=()
  if [ -t 0 ]; then
    files=("$@")
  else
    while IFS= read -r line; do
      files+=("$line")
    done
  fi
  for file in "${files[@]}"; do
    if [ ! -f "$file" ]; then
      echo "File '$file' not found, skipping." >&2
      continue
    fi
    __removesensitive "$file"
  done
}

flatten_folder() {
  # Default values:
  local comment="#"
  local dir="."
  # Process arguments:
  while [[ "$1" == --* ]]; do
    case "$1" in
      --comment)
        shift
        comment="$1"
        shift
        ;;
      --help)
        echo "Usage: flatten_folder [--comment <comment_marker>] [directory]"
        return 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        return 1
        ;;
    esac
  done
  if [ -n "$1" ]; then
    if [ -d "$1" ]; then
      dir="$1"
    else
      dir=$(dirname "$1")
    fi
  fi

  # Store all file paths in an array
  local files=()
  while IFS= read -r -d '' file; do
    # Use iconv to verify the file only contains valid UTF-8.
    if file "$file" | grep -qi text && iconv -f utf-8 -t utf-8 "$file" > /dev/null 2>&1; then
      files+=("$file")
    fi
  done < <(find "$dir" -type f -print0)

  # Calculate the total size (in bytes) of text files
  local total_size=0
  for file in "${files[@]}"; do
    # Using GNU stat; adjust if on another platform
    local size=$(wc -c < "$file" | awk '{print $1}')
    total_size=$((total_size + size))
  done

  echo "$comment Total size of text files: $total_size bytes"

  # Flatten the text files with a header for each file
  for file in "${files[@]}"; do
    if file "$file" | grep -qi text; then
      echo '```'
      echo "$comment File: $file"
      cat "$file"
      echo '```'
    fi
  done
}
