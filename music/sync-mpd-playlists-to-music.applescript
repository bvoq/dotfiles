-- ============================================================
-- Requirements for this AppleScript
-- ============================================================
-- 1. Music.app must be running (or it will be launched).
-- 2. “Copy files to Music Media folder when adding to library”
--    must be unchecked in Music → Settings → Files.
-- 3. MPD playlists must live in ~/.config/mpd/playlists as .m3u files.
--    Paths may be absolute, relative to ~/.config/mpd/media, ~/, or file://.
-- 4. Membership is idempotent: missing playlists are created, and tracks
--    are added/removed so each Music playlist matches its M3U. Order is
--    not rewritten. Run this file yourself; razordot does not invoke it.
-- 5. Paths outside ~/.config/mpd/media raise a warning with Abort/Continue
--    before Music.app is touched.
-- ============================================================

on nonemptyParagraphs(txt)
	if txt is "" then return {}
	set out to {}
	repeat with p in paragraphs of txt
		set p to p as text
		if p is not "" then set end of out to p
	end repeat
	return out
end nonemptyParagraphs

on joinPath(dir, child)
	if dir ends with "/" then
		return dir & child
	else
		return dir & "/" & child
	end if
end joinPath

on realPathIfExists(p)
	try
		return do shell script "if [ -e " & quoted form of p & " ] && command -v realpath >/dev/null 2>&1; then realpath " & quoted form of p & "; else printf %s " & quoted form of p & "; fi"
	on error
		return p
	end try
end realPathIfExists

on resolveTrackPath(rawPath, musicDir, homeDir)
	set p to rawPath as text
	if p starts with "file://" then set p to text 8 thru -1 of p
	if p starts with "~/" then
		set p to my joinPath(homeDir, text 3 thru -1 of p)
	else if p does not start with "/" then
		set p to my joinPath(musicDir, p)
	end if
	return my realPathIfExists(p)
end resolveTrackPath

on readM3UPaths(m3uPath, musicDir, homeDir)
	-- tr is last so an empty or comment-only playlist does not fail do shell script
	set raw to do shell script "grep -v '^#' " & quoted form of m3uPath & " | grep -v '^[[:space:]]*$' | tr -d '\\015' || true"
	set out to {}
	repeat with lineText in my nonemptyParagraphs(raw)
		set end of out to my resolveTrackPath(lineText as text, musicDir, homeDir)
	end repeat
	return out
end readM3UPaths

on isUnderDir(p, dir)
	set p to my realPathIfExists(p)
	set dir to my realPathIfExists(dir)
	if dir ends with "/" then set dir to text 1 thru -2 of dir
	if p is dir then return true
	return p starts with (dir & "/")
end isUnderDir

on warnOutsideMedia(outsidePaths)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to linefeed
	set shown to outsidePaths
	set extraCount to 0
	if (count of outsidePaths) > 20 then
		set shown to items 1 thru 20 of outsidePaths
		set extraCount to (count of outsidePaths) - 20
	end if
	set warnMsg to "These files are outside ~/.config/mpd/media:" & linefeed & (shown as text)
	if extraCount > 0 then set warnMsg to warnMsg & linefeed & "… and " & extraCount & " more"
	set AppleScript's text item delimiters to oldDelims
	try
		set dlg to display dialog warnMsg buttons {"Abort", "Continue"} default button "Abort"
		return button returned of dlg is "Continue"
	on error number -128
		return false
	end try
end warnOutsideMedia

set homeDir to do shell script "printf %s \"$HOME\""
set mpdPlaylistsDir to homeDir & "/.config/mpd/playlists"
set musicDir to homeDir & "/.config/mpd/media"
set failures to {}
set playlistJobs to {}
set outsidePaths to {}

set m3uFiles to do shell script "find " & quoted form of mpdPlaylistsDir & " -maxdepth 1 -type f -name '*.m3u' -print 2>/dev/null || true"
set m3uList to nonemptyParagraphs(m3uFiles)

if (count of m3uList) is 0 then
	display dialog "No .m3u playlists found in ~/.config/mpd/playlists"
	return
end if

repeat with m3uPath in m3uList
	set m3uPath to m3uPath as text
	set plName to do shell script "basename " & quoted form of m3uPath & " .m3u"
	set trackPaths to readM3UPaths(m3uPath, musicDir, homeDir)
	copy {plName, trackPaths} to end of playlistJobs
	repeat with p in trackPaths
		set p to p as text
		if not isUnderDir(p, musicDir) then
			set end of outsidePaths to plName & ": " & p
		end if
	end repeat
end repeat

if (count of outsidePaths) > 0 then
	if not warnOutsideMedia(outsidePaths) then return
end if

tell application "Music"
	repeat with job in playlistJobs
		set job to contents of job
		set plName to item 1 of job
		set trackPaths to item 2 of job
		
		if not (exists user playlist plName) then
			make new user playlist with properties {name:plName}
		end if
		
		set targetPlaylist to user playlist plName
		
		set currentPaths to {}
		repeat with t in tracks of targetPlaylist
			set t to contents of t
			try
				set end of currentPaths to my realPathIfExists(POSIX path of (location of t))
			end try
		end repeat
		
		set tracksToDelete to {}
		repeat with t in tracks of targetPlaylist
			set t to contents of t
			set tPath to ""
			try
				set tPath to my realPathIfExists(POSIX path of (location of t))
			end try
			if tPath is "" or trackPaths does not contain tPath then
				set end of tracksToDelete to t
			end if
		end repeat
		repeat with t in tracksToDelete
			delete (contents of t)
		end repeat
		
		repeat with p in trackPaths
			set p to p as text
			if currentPaths does not contain p then
				try
					add (POSIX file p as alias) to targetPlaylist
				on error errMsg
					set end of failures to plName & ": " & p & " (" & errMsg & ")"
				end try
			end if
		end repeat
	end repeat
end tell

if (count of failures) is 0 then
	display notification "Music.app playlists synced from ~/.config/mpd/playlists" with title "MPD → Music"
else
	set AppleScript's text item delimiters to linefeed
	display dialog "Synced with errors:" & linefeed & (failures as text)
end if
