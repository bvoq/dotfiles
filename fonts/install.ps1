# Windows counterpart to fonts/install.zsh.
# Per-user fonts go in %LOCALAPPDATA%\Microsoft\Windows\Fonts and
# HKCU\...\Fonts. That does not need an elevated process. C:\Windows\Fonts
# would, and would use Verify-Elevated like the other machine installers.
# Requires Windows 10 1809 or newer, which is when per-user fonts were added.

function fonts_u16be([byte[]]$Bytes, [int]$Offset) {
    $hi = $Bytes[$Offset]
    $lo = $Bytes[$Offset + 1]
    return ([int]$hi * 256) + [int]$lo
}

function fonts_u32be([byte[]]$Bytes, [int]$Offset) {
    $b0 = $Bytes[$Offset]
    $b1 = $Bytes[$Offset + 1]
    $b2 = $Bytes[$Offset + 2]
    $b3 = $Bytes[$Offset + 3]
    return ([uint64]$b0 * 16777216) + ([uint64]$b1 * 65536) + ([uint64]$b2 * 256) + [uint64]$b3
}

function fonts_name_text([byte[]]$Bytes, [int]$Offset, [int]$Length, [int]$PlatformId) {
    if ($Length -le 0) { return $null }
    $raw = New-Object byte[] $Length
    [Array]::Copy($Bytes, $Offset, $raw, 0, $Length)
    if ($PlatformId -eq 3 -or $PlatformId -eq 0) {
        $text = [System.Text.Encoding]::BigEndianUnicode.GetString($raw)
    } else {
        $text = [System.Text.Encoding]::GetEncoding(28591).GetString($raw)
    }
    return $text.Trim([char]0).Trim()
}

# Full name (name ID 4) plus TrueType/OpenType, which is the registry value
# Windows writes for an installed face. Collections are not unpacked.
function fonts_face_record([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 12) { throw "Font file is too small: $Path" }

    $magic = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4)
    if ($magic -eq "ttcf") {
        throw "TrueType collections are not registered individually: $Path"
    }

    $numTables = fonts_u16be $bytes 4
    $tableOffset = 12
    $nameOffset = $null
    $outline = "TrueType"
    for ($i = 0; $i -lt $numTables; $i++) {
        $entry = $tableOffset + ($i * 16)
        $tag = [System.Text.Encoding]::ASCII.GetString($bytes, $entry, 4)
        $offset = fonts_u32be $bytes ($entry + 8)
        if ($tag -eq "name") { $nameOffset = [int64]$offset }
        if ($tag -eq "CFF " -or $tag -eq "CFF2") { $outline = "OpenType" }
    }
    if ($null -eq $nameOffset) { throw "No name table in $Path" }

    $count = fonts_u16be $bytes ([int]$nameOffset + 2)
    $stringOffset = fonts_u16be $bytes ([int]$nameOffset + 4)
    $storage = $nameOffset + $stringOffset
    $names = @{}
    for ($i = 0; $i -lt $count; $i++) {
        $rec = [int]$nameOffset + 6 + ($i * 12)
        $platformId = fonts_u16be $bytes $rec
        $languageId = fonts_u16be $bytes ($rec + 4)
        $nameId = fonts_u16be $bytes ($rec + 6)
        $length = fonts_u16be $bytes ($rec + 8)
        $offset = fonts_u16be $bytes ($rec + 10)
        if ($platformId -ne 3 -and $platformId -ne 1 -and $platformId -ne 0) { continue }

        $text = fonts_name_text $bytes ([int]($storage + $offset)) $length $platformId
        if ([string]::IsNullOrWhiteSpace($text)) { continue }

        $score = 0
        if ($platformId -eq 3) { $score += 2 }
        if ($languageId -eq 1033) { $score += 1 }
        $previous = $names[$nameId]
        if ($null -eq $previous -or $score -gt $previous.Score) {
            $names[$nameId] = @{ Text = $text; Score = $score }
        }
    }

    $full = $names[4].Text
    if ([string]::IsNullOrWhiteSpace($full)) {
        $family = $names[16].Text
        if ([string]::IsNullOrWhiteSpace($family)) { $family = $names[1].Text }
        $style = $names[17].Text
        if ([string]::IsNullOrWhiteSpace($style)) { $style = $names[2].Text }
        if ([string]::IsNullOrWhiteSpace($family)) { throw "No font name in $Path" }
        if ($style -and $style -ne "Regular") {
            $full = "$family $style"
        } else {
            $full = $family
        }
    }

    return [pscustomobject]@{
        FullName = $full
        Outline  = $outline
    }
}

function fonts_notify_session([string[]]$Paths) {
    if (-not ('Razordot.FontInstall' -as [type])) {
        Add-Type -Namespace Razordot -Name FontInstall -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
public static extern int AddFontResource(string lpFileName);

[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
'@
    }

    foreach ($path in $Paths) {
        $added = [Razordot.FontInstall]::AddFontResource($path)
        if ($added -le 0) {
            Write-Warning "Windows did not load '$path' into this session. It will be available after you sign in again."
        }
    }

    # WM_FONTCHANGE. PostMessage returns immediately; SendMessage can hang on a stuck window.
    $posted = [Razordot.FontInstall]::PostMessage([IntPtr]0xffff, [uint32]0x001D, [IntPtr]::Zero, [IntPtr]::Zero)
    if (-not $posted) {
        Write-Warning "Fonts were registered, but Windows was not told to reload them. They will be available after you sign in again."
    }
}

function phase_2_user_installs {
    $destDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    $registryPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    if (-not (Test-Path -LiteralPath $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }

    $fontFiles = @(Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File | Where-Object {
        $_.Extension -match '^\.(ttf|otf|ttc)$'
    })
    if ($fontFiles.Count -eq 0) {
        Write-Host "No font files found under fonts/."
        return
    }

    $unchanged = 0
    $activated = @()
    foreach ($file in $fontFiles) {
        try {
            $face = fonts_face_record $file.FullName
        } catch {
            Write-Warning "Skipping $($file.Name): $($_.Exception.Message)"
            continue
        }

        $targetPath = Join-Path $destDir $file.Name
        $needsCopy = $true
        if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
            $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            $targetHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
            if ($sourceHash -eq $targetHash) { $needsCopy = $false }
        }
        if ($needsCopy) {
            try {
                Copy-Item -LiteralPath $file.FullName -Destination $targetPath -Force -ErrorAction Stop
            } catch {
                Write-Warning "Could not install $($file.Name): $($_.Exception.Message)"
                continue
            }
            Write-Host "Installed font $($file.Name)"
        }

        $valueName = "$($face.FullName) ($($face.Outline))"
        $existing = (Get-ItemProperty -LiteralPath $registryPath -Name $valueName -ErrorAction SilentlyContinue).$valueName
        $wasRegistered = $existing -eq $targetPath
        if (-not $wasRegistered) {
            New-ItemProperty -LiteralPath $registryPath -Name $valueName -Value $targetPath -PropertyType String -Force | Out-Null
        }
        # AddFontResource keeps a refcount, so only load faces that were not
        # already both copied and registered. Login loads the registry list.
        if ($needsCopy -or -not $wasRegistered) {
            $activated += $targetPath
        } else {
            $unchanged++
        }
    }

    if ($activated.Count -gt 0) {
        try {
            fonts_notify_session $activated
        } catch {
            Write-Warning "Fonts were registered, but Windows was not told to reload them. They will be available after you sign in again. $($_.Exception.Message)"
        }
    }

    if ($unchanged -eq $fontFiles.Count) {
        Write-Host "Fonts already installed."
    }
}
