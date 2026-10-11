# macOS only for now: relies on --cookies-from-browser chrome.
if [[ $OSTYPE == 'darwin'* ]]; then
  # make sure to use " around url when using ymp3, works for playlists and single videos.
  alias ymp3='yt-dlp -x --audio-format mp3 --add-metadata --embed-thumbnail --cookies-from-browser "firefox:~/Library/Application Support/librewolf"'
  alias ymp4='yt-dlp -fmp4 --write-sub --write-auto-sub --sub-langs "en,en-en,en-orig" --embed-subs --sleep-subtitles 5 --cookies-from-browser "firefox:~/Library/Application Support/librewolf"'
fi

compressvideo() {
  if [ $# -lt 2 ]; then
    echo "Usage: compress_video <input_file> <size_in_MB> [output_file]"
    return 1
  fi
  INPUT="$1"
  SIZE_MB="$2"
  OUTPUT="${3:-output_compressed.mp4}"
  MAX_ATTEMPTS=5
  REDUCTION_FACTOR=0.9
  DURATION=$(ffprobe -v error -select_streams v:0 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT")
  TARGET_SIZE_BYTES=$((SIZE_MB * 1024 * 1024))
  AUDIO_BITRATE=128
  TOTAL_BITRATE=$(echo "$TARGET_SIZE_BYTES * 8 / $DURATION / 1000" | bc)

  attempt=1
  while [ $attempt -le $MAX_ATTEMPTS ]; do
    VIDEO_BITRATE=$((TOTAL_BITRATE - AUDIO_BITRATE))
    if [ "$VIDEO_BITRATE" -le 0 ]; then
      AUDIO_BITRATE=64
      VIDEO_BITRATE=$((TOTAL_BITRATE - AUDIO_BITRATE))
      if [ "$VIDEO_BITRATE" -le 0 ]; then
        return 1
      fi
    fi
    rm -f ffmpeg2pass-0.log*
    ffmpeg -y -i "$INPUT" -c:v libx264 -preset medium -b:v "${VIDEO_BITRATE}k" -pass 1 -c:a aac -b:a "${AUDIO_BITRATE}k" -f mp4 /dev/null
    ffmpeg -i "$INPUT" -c:v libx264 -preset medium -b:v "${VIDEO_BITRATE}k" -pass 2 -c:a aac -b:a "${AUDIO_BITRATE}k" "$OUTPUT"
    SIZE=$(stat -c%s "$OUTPUT" 2> /dev/null || stat -f%z "$OUTPUT")
    if [ "$SIZE" -le "$TARGET_SIZE_BYTES" ]; then
      return 0
    else
      rm -f "$OUTPUT"
      TOTAL_BITRATE=$(echo "$TOTAL_BITRATE * $REDUCTION_FACTOR" | bc | awk '{printf "%d\n",$0}')
      if [ "$TOTAL_BITRATE" -le 0 ]; then
        return 1
      fi
    fi
    attempt=$((attempt + 1))
  done
  return 1
}

gifgen() {
  # gifgen - Credits: https://github.com/lukechilds/gifgen
  local show_help=false

  show_help_text() {
    echo "gifgen 1.2.0"
    echo
    echo "Usage: gifgen [options] [input]"
    echo
    echo "Options:"
    echo "  -o   Output file [input.gif]"
    echo "  -f   Frames per second [10]"
    echo "  -s   Optimize for static background"
    echo "  -d   Set dither pattern in ffmpeg"
    echo "  -v   Display verbose output from ffmpeg"
    echo "  -w   Scale output with horizontal resolution"
    echo "  -b   Begin the clip at a given timestamp (in seconds)"
    echo "  -t   Duration in seconds of the resulting gif, can be combined with at"
    echo
    echo "Examples:"
    echo "  $ gifgen video.mp4"
    echo "  $ gifgen -o demo.gif SCM_1457.mp4"
    echo "  $ gifgen -sf 15 screencap.mov"
    echo "  $ gifgen -sf 15 -w 320 screencap.mov"
    echo
    echo "Begin at 3.5 seconds into the video, make the gif using the next 5.5 seconds"
    echo "  $ gifgen -b 3.5 -t 5.5 screencap.mov"
  }

  # Setup defaults
  local pid=$$
  local palette="/tmp/gif-palette-$pid.png"
  local fps="24"
  local verbosity="warning"
  local stats_mode="full"
  local dither="sierra2_4a"
  local scale=""
  local scale_num=""
  local begin=""
  local duration=""
  local output=""
  local input=""

  # Parse args
  while getopts "hi:o:f:w:b:t:d:sv" opt; do
    case "$opt" in
      h)
        show_help=true
        ;;
      o)
        output=$OPTARG
        ;;
      f)
        fps=$OPTARG
        ;;
      s)
        stats_mode="diff"
        ;;
      d)
        dither=$OPTARG
        ;;
      w)
        scale_num=$OPTARG
        ;;
      b)
        begin="-ss $OPTARG"
        ;;
      t)
        duration="-t $OPTARG"
        ;;
      v)
        verbosity="info"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"
  # Grab input file from end of command
  input=$1

  [[ -n "$scale_num" ]] && scale=",scale=$scale_num:-1:flags=lanczos"

  # Show help and exit if we have no input
  [[ "$input" = "" ]] || [[ $show_help = true ]] && show_help_text && return

  # Check for ffmpeg before encoding
  type ffmpeg > /dev/null 2>&1 || {
    echo "Error: gifgen requires ffmpeg to be installed"
    return 1
  }

  # Set output if not specified
  if [[ "$output" = "" ]]; then
    local input_filename=${input##*/}
    output=${input_filename%.*}
    if [[ "$scale_num" != "" ]]; then
      output=${output%.*}_$scale_num
    fi
    output=${output%.*}.gif
  fi

  # Encode GIF
  echo "Generating palette..."
  ffmpeg -v "$verbosity" $begin $duration -i "$input" -vf "fps=$fps$scale,palettegen=stats_mode=$stats_mode" -y "$palette"
  [[ "$verbosity" = "info" ]] && echo
  echo "Encoding GIF..."
  ffmpeg -v "$verbosity" $begin $duration -i "$input" -i "$palette" -lavfi "fps=$fps$scale [x]; [x][1:v] paletteuse=dither=$dither" -y "$output"
  echo "Done!"
}
