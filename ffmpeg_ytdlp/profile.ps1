# make sure to use " around url when using ymp3, works for playlists and single videos.
function ymp3 { yt-dlp -x --audio-format mp3 --add-metadata --embed-thumbnail --cookies-from-browser chrome $args }
function ymp4 { yt-dlp -fmp4 --write-sub --write-auto-sub --sub-langs "en,en-en,en-orig" --embed-subs --sleep-subtitles 5 --cookies-from-browser chrome $args }
