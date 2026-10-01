# Windows counterpart to razordot.zsh.
# Keep orchestration here; each folder owns an install.ps1 that defines phase
# functions. The selected installer is sourced once per phase, then that phase
# function is called, matching the macOS installer model.

######################
# MODIFIABLE SECTION #
######################
# Enable or disable feature folders here, analogous to install_folders in
# razordot.zsh. Each enabled folder must contain an install.ps1. An entry
# containing a slash (for example "owner/repository" or a git URL) is fetched
# as a repo. razordot/winget is listed first so its shared install_wingetfile
# command is defined before later folders call it.
$installFolders = @(
    "razordot/winget"
    #"core"
    "creative"
    #"generic"
    #"windows"
    "git"
    "messaging"
    "texmacs"
    #"starship"
    #"ffmpeg_ytdlp"
    #"rclone"
    #"ripgrep"
    #"vim"
    #"vscode"
)
# OPTIONS:

# Disable updates by removing this line.
$RAZORDOT_UPDATE_LOCATION = "https://raw.githubusercontent.com/razordot/razordot/refs/heads/main/razordot.ps1"

# install_folders entries containing a "/" are acquired into gitignored folders.
# Public GitHub repos are downloaded with web requests first; git is used only as a fallback.

# Preset every waitconfirm prompt (0 = exit on waitconfirm, 1 = keep going). Leave commented to be asked.
# $WAITCONFIRM_DECISION = 1

########################
# UNMODIFIABLE SECTION #
########################
# This section is managed by the RAZORDOT_UPDATE_LOCATION and is under the Apache License, Version 2.0.
# Do not modify below here, unless you fork it with a different name, as "RAZORDOT" is reserved for this project.

$repoRoot = $PSScriptRoot
Set-Location -LiteralPath $repoRoot
$RAZORDOT_SCRIPT_NAME = Split-Path -Leaf $PSCommandPath
if ([string]::IsNullOrWhiteSpace($RAZORDOT_SCRIPT_NAME)) {
    $RAZORDOT_SCRIPT_NAME = $MyInvocation.MyCommand.Name
}
$profileFragmentsDir = Join-Path (Split-Path -Parent $PROFILE.CurrentUserAllHosts) "profiles.d"
New-Item -Path $profileFragmentsDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
$global:RAZORDOT_RUN_ID = [guid]::NewGuid().ToString()

function razordot_self_update {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptLocation,
        [Parameter(Mandatory = $true)]
        [string]$InvokeLocation,
        [string[]]$ScriptArgs = @()
    )

    if ([string]::IsNullOrWhiteSpace($RAZORDOT_UPDATE_LOCATION)) { return }  # disabled when unset
    if ([Console]::IsInputRedirected) { return }                            # only when interactive (we prompt below)

    $marker = '# UNMODIFIABLE SECTION #'
    $localLines = @(Get-Content -LiteralPath $ScriptLocation)
    $localMarkerIndex = -1
    for ($i = 0; $i -lt $localLines.Count; $i++) {
        if ($localLines[$i] -ceq $marker) { $localMarkerIndex = $i; break }
    }
    if ($localMarkerIndex -lt 0) { return }  # only if the marker exists

    try {
        $remote = (Invoke-WebRequest -Uri $RAZORDOT_UPDATE_LOCATION -UseBasicParsing -ErrorAction Stop).Content
    } catch {
        return  # network or tooling failure: continue without updating
    }

    $remoteLines = $remote -split "\r?\n"
    $remoteMarkerIndex = -1
    for ($i = 0; $i -lt $remoteLines.Count; $i++) {
        if ($remoteLines[$i] -ceq $marker) { $remoteMarkerIndex = $i; break }
    }
    if ($remoteMarkerIndex -lt 0) { return }

    # The managed section is the marker line (first exact match) through EOF.
    $localSection = ($localLines[$localMarkerIndex..($localLines.Count - 1)]) -join "`n"
    $remoteSection = (($remoteLines[$remoteMarkerIndex..($remoteLines.Count - 1)]) -join "`n").TrimEnd("`r", "`n")

    if ([string]::IsNullOrWhiteSpace($remoteSection)) { return }
    if ($localSection -ceq $remoteSection) {
        Write-Host "razordot is up to date."
        return
    }

    Write-Host "razordot: the managed section differs from the canonical copy (< current, > update):"
    $comparison = Compare-Object -ReferenceObject ($localSection -split "`n") -DifferenceObject ($remoteSection -split "`n")
    foreach ($change in $comparison) {
        $sign = if ($change.SideIndicator -eq "<=") { "<" } else { ">" }
        Write-Host "$sign $($change.InputObject)"
    }

    Write-Host "razordot: update the unmodifiable section and re-run? (remove RAZORDOT_UPDATE_LOCATION to disable update downloads)"
    if (-not (Wait-RazordotConfirm)) {
        exit 0
    }
    Write-Host "razordot: updating the unmodifiable section and re-running."

    $topLines = @()
    if ($localMarkerIndex -gt 0) {
        $topLines = @($localLines[0..($localMarkerIndex - 1)])
    }
    $updated = ((@($topLines) + ($remoteSection -split "`n")) -join "`n") + "`n"

    $tempFile = [IO.Path]::GetTempFileName()
    try {
        Set-Content -LiteralPath $tempFile -Value $updated -Encoding UTF8 -NoNewline
        Copy-Item -LiteralPath $tempFile -Destination $ScriptLocation -Force
    } catch {
        Write-Host "razordot: could not write $ScriptLocation; continuing without updating."
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        return
    }
    Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue

    $executable = (Get-Process -Id $PID).Path
    & $executable -File $InvokeLocation @ScriptArgs
    exit $LASTEXITCODE
}

function link_file {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$TargetPath
    )

    $sourcePath = [IO.Path]::GetFullPath($SourcePath)
    $targetPath = [IO.Path]::GetFullPath($TargetPath)
    if (-not (Get-Item -LiteralPath $sourcePath -Force -ErrorAction SilentlyContinue)) {
        throw "Link source not found: $sourcePath"
    }

    $homePath = [IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
    $backupRoot = Join-Path $repoRoot "backups"
    if ($targetPath.StartsWith($homePath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        $relativeTargetPath = $targetPath.Substring($homePath.Length).TrimStart('\', '/')
        $backupPath = Join-Path (Join-Path $backupRoot "home") $relativeTargetPath
    } else {
        $relativeTargetPath = $targetPath.TrimStart('\', '/')
        $backupPath = Join-Path (Join-Path $backupRoot "absolute") $relativeTargetPath
    }

    $targetItem = Get-Item -LiteralPath $targetPath -Force -ErrorAction SilentlyContinue
    if ($targetItem) {
        # If the target is already an identical copy of the source, there is
        # nothing to do. (Symlinks require elevation or Developer Mode on
        # Windows, so for now we copy the file instead of linking it.)
        if (-not $targetItem.PSIsContainer) {
            $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
            $targetHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
            if ($sourceHash -eq $targetHash) {
                return
            }
        }

        $backupBase = $backupPath
        $backupSuffix = 1
        while (Get-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue) {
            $backupPath = "$backupBase.$backupSuffix"
            $backupSuffix++
        }

        New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
        Move-Item -LiteralPath $targetPath -Destination $backupPath
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $targetPath) -Force | Out-Null
    try {
        # NOTE: This copies rather than symlinks for now, because creating a
        # symbolic link on Windows requires an elevated process or Developer
        # Mode. The name stays link_file so the call sites and mental model
        # match the macOS side; revisit once Developer Mode is guaranteed.
        Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force -ErrorAction Stop
    } catch {
        throw "Could not copy '$sourcePath' -> '$targetPath'. $($_.Exception.Message)"
    }
}

Function Set-PathVariable {
    param (
        [string]$AddPath,
        [string]$RemovePath,
        [ValidateSet('Process', 'User', 'Machine')]
        [string]$Scope = 'Process'
    )
    $regexPaths = @()
    if ($PSBoundParameters.Keys -contains 'AddPath') {
        $regexPaths += [regex]::Escape($AddPath)
    }

    if ($PSBoundParameters.Keys -contains 'RemovePath') {
        $regexPaths += [regex]::Escape($RemovePath)
    }
    $arrPath = [System.Environment]::GetEnvironmentVariable('PATH', $Scope) -split ';'
    foreach ($path in $regexPaths) {
        $arrPath = $arrPath | Where-Object { $_ -notMatch "^$path\\?" }
    }
    $value = ($arrPath + $addPath) -join ';'
    [System.Environment]::SetEnvironmentVariable('PATH', $value, $Scope)
}

function Verify-Elevated {
    $myIdentity=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myPrincipal=new-object System.Security.Principal.WindowsPrincipal($myIdentity)
    return $myPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Wait-RazordotConfirm {
    $decision = $null
    $decisionVariable = Get-Variable -Name WAITCONFIRM_DECISION -Scope Script -ErrorAction SilentlyContinue
    if ($decisionVariable) {
        $decision = [string]$decisionVariable.Value
    }
    if ([string]::IsNullOrWhiteSpace($decision)) {
        $decision = $env:WAITCONFIRM_DECISION
    }

    if (-not [string]::IsNullOrWhiteSpace($decision)) {
        return $decision -match "^(1|y|yes)$"
    }

    if (-not ($Host.UI -and $Host.UI.RawUI)) {
        Write-Warning "Cannot ask for confirmation in a non-interactive session."
        return $false
    }

    do {
        $decision = Read-Host "Continue [y/n]?"
    }
    while ($decision -notmatch "^(y|n)$")

    return $decision -eq "y"
}

function Get-RazordotRepositoryUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Specification
    )

    if ($Specification -match "://|@[^/\\:]+:") {
        return $Specification
    }

    $repository = $Specification -replace "\.git$", ""
    return "https://github.com/$repository.git"
}

function Get-RazordotRepositoryFolder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Specification
    )

    $folder = $Specification -replace "\.git$", ""
    while ($folder.EndsWith('/') -or $folder.EndsWith('\')) {
        $folder = $folder.Substring(0, $folder.Length - 1)
    }
    return ($folder -split '[/\\]')[-1]
}

function Get-RazordotGitHubSlug {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Specification
    )

    $specification = $Specification -replace "\.git$", ""
    while ($specification.EndsWith('/') -or $specification.EndsWith('\')) {
        $specification = $specification.Substring(0, $specification.Length - 1)
    }

    if ($specification.StartsWith("git@github.com:", [StringComparison]::OrdinalIgnoreCase)) {
        $specification = $specification.Substring("git@github.com:".Length)
    } elseif ($specification.StartsWith("ssh://git@github.com/", [StringComparison]::OrdinalIgnoreCase)) {
        $specification = $specification.Substring("ssh://git@github.com/".Length)
    } elseif ($specification.StartsWith("https://github.com/", [StringComparison]::OrdinalIgnoreCase)) {
        $specification = $specification.Substring("https://github.com/".Length)
    } elseif ($specification.StartsWith("http://github.com/", [StringComparison]::OrdinalIgnoreCase)) {
        $specification = $specification.Substring("http://github.com/".Length)
    } elseif ($specification.StartsWith("git://github.com/", [StringComparison]::OrdinalIgnoreCase)) {
        $specification = $specification.Substring("git://github.com/".Length)
    } elseif ($specification.StartsWith("github.com/", [StringComparison]::OrdinalIgnoreCase)) {
        $specification = $specification.Substring("github.com/".Length)
    }

    if ($specification -match "://|@[^/\\:]+:") { return }
    $parts = @($specification -split '[/\\]')
    if ($parts.Count -lt 2 -or
        [string]::IsNullOrWhiteSpace($parts[0]) -or
        [string]::IsNullOrWhiteSpace($parts[1])) {
        return
    }
    return "$($parts[0])/$($parts[1])"
}

function Resolve-RazordotRemoteHead {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    $slug = Get-RazordotGitHubSlug -Specification $Url
    if (-not [string]::IsNullOrWhiteSpace($slug)) {
        try {
            $commit = Invoke-RestMethod -Uri "https://api.github.com/repos/$slug/commits/HEAD" -ErrorAction Stop
            if (-not [string]::IsNullOrWhiteSpace([string]$commit.sha)) {
                return [string]$commit.sha
            }
        } catch {
            # Fall through to git for private repositories or non-GitHub URLs.
        }
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return }
    $remoteHead = @(& git ls-remote $Url HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or $remoteHead.Count -eq 0) { return }
    return (($remoteHead | Select-Object -First 1) -split '\s+')[0]
}

function Get-RazordotDownloadPin {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Folder
    )

    if (-not (Test-Path -LiteralPath ".gitignore" -PathType Leaf)) {
        return
    }

    $prefix = "# $RAZORDOT_SCRIPT_NAME $Folder/ "
    foreach ($line in @(Get-Content -LiteralPath ".gitignore")) {
        if ($line.StartsWith($prefix, [StringComparison]::Ordinal)) {
            $parts = $line.Substring($prefix.Length) -split '\s+'
            if ($parts.Count -gt 0) {
                return $parts[-1]
            }
        }
    }
}

function Set-RazordotDownloadPin {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Folder,
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [Parameter(Mandatory = $true)]
        [string]$Commit
    )

    if (-not (Test-Path -LiteralPath ".gitignore" -PathType Leaf)) {
        New-Item -ItemType File -Path ".gitignore" -Force | Out-Null
    }

    $commentPrefix = "# $RAZORDOT_SCRIPT_NAME $Folder/ "
    $ignoreLine = "$Folder/"
    $lines = @()
    $skipIgnoreLine = $false
    foreach ($line in @(Get-Content -LiteralPath ".gitignore")) {
        if ($skipIgnoreLine -and $line -eq $ignoreLine) {
            $skipIgnoreLine = $false
            continue
        }
        $skipIgnoreLine = $false
        if ($line.StartsWith($commentPrefix, [StringComparison]::Ordinal)) {
            $skipIgnoreLine = $true
            continue
        }
        $lines += $line
    }
    $lines += "# $RAZORDOT_SCRIPT_NAME $Folder/ $Url $Commit"
    $lines += "$Folder/"
    Set-Content -LiteralPath ".gitignore" -Value $lines
}

function Invoke-RazordotWebDownloadCheckout {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [Parameter(Mandatory = $true)]
        [string]$Folder,
        [Parameter(Mandatory = $true)]
        [string]$Commit
    )

    $slug = Get-RazordotGitHubSlug -Specification $Url
    if ([string]::IsNullOrWhiteSpace($slug)) { return $false }

    $markerPath = Join-Path $Folder ".razordot-commit"
    $existingCommit = Get-Content -LiteralPath $markerPath -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not [string]::IsNullOrWhiteSpace($existingCommit) -and $existingCommit.Trim() -eq $Commit) {
        return $true
    }

    $tempDirectory = Join-Path ([IO.Path]::GetTempPath()) "razordot-$([guid]::NewGuid())"
    $archivePath = Join-Path $tempDirectory "archive.zip"
    $extractPath = Join-Path $tempDirectory "extract"
    try {
        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
        Invoke-WebRequest -Uri "https://api.github.com/repos/$slug/zipball/$Commit" `
            -OutFile $archivePath -UseBasicParsing -ErrorAction Stop
        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath -Force

        $extractedFolder = Get-ChildItem -LiteralPath $extractPath -Directory | Select-Object -First 1
        if (-not $extractedFolder) { return $false }

        Remove-Item -LiteralPath $Folder -Recurse -Force -ErrorAction SilentlyContinue
        $parent = Split-Path -Parent $Folder
        if (-not [string]::IsNullOrWhiteSpace($parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Move-Item -LiteralPath $extractedFolder.FullName -Destination $Folder
        Set-Content -LiteralPath (Join-Path $Folder ".razordot-commit") -Value $Commit
        return $true
    } catch {
        return $false
    } finally {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-RazordotGitDownloadCheckout {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [Parameter(Mandatory = $true)]
        [string]$Folder,
        [Parameter(Mandatory = $true)]
        [string]$Commit
    )

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $false }

    $gitFolder = Join-Path $Folder ".git"
    if (Test-Path -LiteralPath $gitFolder -PathType Container) {
        $head = (& git -C $Folder rev-parse HEAD 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and ([string]$head).Trim() -eq $Commit) {
            return $true
        }
    } else {
        Remove-Item -LiteralPath $Folder -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
        & git -C $Folder init -q | Out-Null
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
    }

    & git -C $Folder remote add origin $Url 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        & git -C $Folder remote set-url origin $Url 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
    }

    & git -C $Folder fetch --depth 1 origin $Commit 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        & git -C $Folder checkout -q FETCH_HEAD | Out-Null
    } else {
        & git -C $Folder fetch -q origin | Out-Null
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
        & git -C $Folder checkout -q $Commit | Out-Null
    }

    if ($LASTEXITCODE -ne 0) {
        return $false
    }
    return $true
}

function Invoke-RazordotDownloadCheckout {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [Parameter(Mandatory = $true)]
        [string]$Folder,
        [Parameter(Mandatory = $true)]
        [string]$Commit
    )

    if (Invoke-RazordotWebDownloadCheckout -Url $Url -Folder $Folder -Commit $Commit) {
        return $true
    }

    Write-Host "Web download failed for $Url; trying git fallback." -ForegroundColor Yellow
    return (Invoke-RazordotGitDownloadCheckout -Url $Url -Folder $Folder -Commit $Commit)
}

function Initialize-RazordotDownload {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [Parameter(Mandatory = $true)]
        [string]$Folder
    )

    $commit = Get-RazordotDownloadPin -Folder $Folder
    if ([string]::IsNullOrWhiteSpace($commit)) {
        $commit = Resolve-RazordotRemoteHead -Url $Url
        if ([string]::IsNullOrWhiteSpace($commit)) {
            throw "Could not resolve a commit for $Url."
        }

        Write-Host "First use of remote folder '$Folder' ($Url)." -ForegroundColor Cyan
        Write-Host "Pinning to commit $commit." -ForegroundColor Cyan
        if (-not (Wait-RazordotConfirm)) {
            return $false
        }

        if (-not (Invoke-RazordotDownloadCheckout -Url $Url -Folder $Folder -Commit $commit)) {
            throw "Could not acquire '$Url' at commit '$commit'."
        }
        Set-RazordotDownloadPin -Folder $Folder -Url $Url -Commit $commit
    } else {
        if (-not (Invoke-RazordotDownloadCheckout -Url $Url -Folder $Folder -Commit $commit)) {
            throw "Could not acquire '$Url' at commit '$commit'."
        }
    }

    return $true
}

function Get-RazordotManagedDownloadFolders {
    if (-not (Test-Path -LiteralPath ".gitignore" -PathType Leaf)) {
        return
    }

    $prefix = "# $RAZORDOT_SCRIPT_NAME "
    foreach ($line in @(Get-Content -LiteralPath ".gitignore")) {
        if ($line.StartsWith($prefix, [StringComparison]::Ordinal)) {
            $parts = $line.Substring($prefix.Length) -split '\s+'
            if ($parts.Count -gt 0 -and $parts[0].EndsWith('/')) {
                $parts[0].TrimEnd('/')
            }
        }
    }
}

function Test-RazordotOtherDownloadOwner {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Folder
    )

    if (-not (Test-Path -LiteralPath ".gitignore" -PathType Leaf)) {
        return $false
    }

    $folderToken = "$Folder/"
    foreach ($line in @(Get-Content -LiteralPath ".gitignore")) {
        if (-not $line.StartsWith("# ", [StringComparison]::Ordinal)) { continue }
        $parts = $line -split '\s+'
        if ($parts.Count -ge 4 -and $parts[1] -ne $RAZORDOT_SCRIPT_NAME -and $parts[2] -eq $folderToken) {
            return $true
        }
    }
    return $false
}

function Remove-RazordotDownload {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Folder
    )

    if (Test-RazordotOtherDownloadOwner -Folder $Folder) {
        Write-Host "Removing stale download pin for '$Folder' (folder kept; another script still owns it)." -ForegroundColor Yellow
    } else {
        Write-Host "Removing stale downloaded folder '$Folder'." -ForegroundColor Yellow
        Remove-Item -LiteralPath $Folder -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path -LiteralPath ".gitignore" -PathType Leaf)) {
        return
    }

    $commentPrefix = "# $RAZORDOT_SCRIPT_NAME $Folder/ "
    $ignoreLine = "$Folder/"
    $remaining = @()
    $skipIgnoreLine = $false
    foreach ($line in @(Get-Content -LiteralPath ".gitignore")) {
        if ($skipIgnoreLine -and $line -eq $ignoreLine) {
            $skipIgnoreLine = $false
            continue
        }
        $skipIgnoreLine = $false
        if ($line.StartsWith($commentPrefix, [StringComparison]::Ordinal)) {
            $skipIgnoreLine = $true
            continue
        }
        $remaining += $line
    }
    Set-Content -LiteralPath ".gitignore" -Value $remaining
}

function Resolve-RazordotInstallRepositories {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$InstallFolders
    )

    $desired = @{}
    foreach ($specification in $InstallFolders) {
        if ($specification -notmatch '/') { continue }
        $folder = Get-RazordotRepositoryFolder -Specification $specification
        $desired[$folder] = $true
    }

    if (-not $global:RAZORDOT_SINGLE_FOLDER) {
        foreach ($folder in @(Get-RazordotManagedDownloadFolders)) {
            if (-not $desired.ContainsKey($folder)) {
                Remove-RazordotDownload -Folder $folder
            }
        }
    }

    $resolvedFolders = @()
    foreach ($specification in $InstallFolders) {
        if ($specification -notmatch '/') {
            $resolvedFolders += $specification
            continue
        }

        $url = Get-RazordotRepositoryUrl -Specification $specification
        $folder = Get-RazordotRepositoryFolder -Specification $specification
        if (-not (Initialize-RazordotDownload -Url $url -Folder $folder)) {
            return
        }
        $resolvedFolders += $folder
    }

    return $resolvedFolders
}

################
# SELF-UPDATE  #
################
razordot_self_update -ScriptLocation $PSCommandPath -InvokeLocation $PSCommandPath -ScriptArgs $args

########################
# WINDOWS PREFLIGHT    #
########################
Write-Host "PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
Write-Host "PSScriptRoot $PSScriptRoot" -ForegroundColor Cyan

# Detect and fix PSModulePath cross-contamination (pwsh 7 paths leaking into PS 5.1 or vice versa).
# See https://github.com/PowerShell/PowerShell/issues/18530
$pathEntries = $env:PSModulePath -split ';'
$contaminated = @()
if ($PSVersionTable.PSVersion.Major -le 5) {
    # PS 5.1 should NOT have pwsh 7 module paths.
    $contaminated = $pathEntries | Where-Object {
        ($_ -match '\\PowerShell\[7-9]') -or
        ($_ -match '[\\/]PowerShell[\\/]Modules' -and $_ -notmatch 'WindowsPowerShell')
    }
} else {
    # pwsh 7 inheriting WindowsPowerShell paths is normal (by design), so nothing to fix.
}
if ($contaminated.Count -gt 0) {
    Write-Host "`nWARN: PSModulePath cross-contamination detected!" -ForegroundColor Red
    Write-Host "  The following pwsh 7 paths do not belong in PowerShell $($PSVersionTable.PSVersion):" -ForegroundColor Yellow
    $contaminated | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    $clean = ($pathEntries | Where-Object { $_ -notin $contaminated }) -join ';'
    $env:PSModulePath = $clean
    Write-Host "  OK: Removed contaminated paths for this session." -ForegroundColor Green
    Write-Host "  Tip: run razordot.ps1 directly from powershell.exe, not from a pwsh/VS Code terminal.`n" -ForegroundColor Yellow
} else {
    Write-Host "PSModulePath: OK (no cross-contamination)" -ForegroundColor Green
}

# Optional: `./razordot.ps1 --install <folder>` runs only that folder, even if
# it is disabled above.
$singleFolder = $null
$global:RAZORDOT_SINGLE_FOLDER = 0
if ($args.Count -ge 1 -and $args[0] -eq "--install") {
    if ($args.Count -ne 2) {
        throw "Usage: .\razordot.ps1 --install <folder>"
    }

    $singleFolder = $args[1]
    while ($singleFolder.EndsWith('/') -or $singleFolder.EndsWith('\')) {
        $singleFolder = $singleFolder.Substring(0, $singleFolder.Length - 1)
    }
    if ($singleFolder -notmatch '/' -and
        -not (Test-Path -LiteralPath (Join-Path $repoRoot (Join-Path $singleFolder "install.ps1")) -PathType Leaf)) {
        throw "Usage: .\razordot.ps1 --install <folder> (no '$singleFolder/install.ps1' found)"
    }
    $installFolders = @($singleFolder)
    $global:RAZORDOT_SINGLE_FOLDER = 1
}

# Materialize remote-repository entries (those containing a slash) into local
# folders before building the install-script list. The resolved folder names
# are then handled exactly like local feature folders in every phase.
$resolvedInstallFolders = @(Resolve-RazordotInstallRepositories -InstallFolders $installFolders)
if ($resolvedInstallFolders.Count -ne $installFolders.Count) {
    Write-Host "Remote install-folder acquisition was cancelled." -ForegroundColor Yellow
    return
}
$installFolders = $resolvedInstallFolders

$installScripts = foreach ($folder in $installFolders) {
    $installScript = Join-Path $repoRoot (Join-Path $folder "install.ps1")
    if (-not (Test-Path -LiteralPath $installScript -PathType Leaf)) {
        throw "Install script not found for '$folder': $installScript"
    }
    (Resolve-Path -LiteralPath $installScript).Path
}

################
# RUN RAZORDOT #
################

try {
# Phase 1: machine-scoped installs and machine-level changes.
foreach ($installScript in $installScripts) {
    function phase_1_machine_installs {}
    . $installScript
    phase_1_machine_installs
}

# Phase 2: user-level installs.
foreach ($installScript in $installScripts) {
    function phase_2_user_installs {}
    . $installScript
    phase_2_user_installs
}

# Reconcile every WinGet manifest after all feature folders have contributed
# their packages. Running this at the phase boundary prevents the first folder
# from cleaning up packages declared by folders that have not run yet.
if (Get-Command cleanup_wingetfiles -ErrorAction SilentlyContinue) {
    cleanup_wingetfiles
}

# Phase 3: user dotfiles.
foreach ($installScript in $installScripts) {
    function phase_3_dotfiles {}
    . $installScript
    phase_3_dotfiles
}

# Phase 4: user-level setup that requires dotfiles to be in place.
foreach ($installScript in $installScripts) {
    function phase_4_post_dotfiles {}
    . $installScript
    phase_4_post_dotfiles
}

# Phase 5: heavy system changes.
foreach ($installScript in $installScripts) {
    function phase_5_system_changes {}
    . $installScript
    phase_5_system_changes
}

} finally {
    # The WinGet command keeps copies of every imported manifest only for this
    # run, so always remove them even if a later phase fails.
    if (Get-Command Remove-WingetManifestAccumulator -ErrorAction SilentlyContinue) {
        Remove-WingetManifestAccumulator
    }
}
