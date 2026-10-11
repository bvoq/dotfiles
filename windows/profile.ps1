function hopen() { Start-Process powershell } # start powershell in same directory, with the same user and elevation

function caffeinate() {
    # Usage: caffeinate (indefinitely), caffeinate --time-limit 3600 (1 hour), caffeinate --display-on true
    $awakeExe = "C:\Program Files\PowerToys\PowerToys.Awake.exe"
    if (Test-Path $awakeExe) {
        & $awakeExe $args
    } else {
        Write-Host "PowerToys Awake not found. Install PowerToys first." -ForegroundColor Red
    }
}

function Update-System() {
    Install-WindowsUpdate -IgnoreUserInput -IgnoreReboot -AcceptAll
    Update-Module
    Update-Help -Force
    gem update --system
    gem update
    npm install npm -g
    npm update -g
}

# PowerShell privacy and update settings
$env:POWERSHELL_TELEMETRY_OPTOUT = "1"
$env:POWERSHELL_UPDATECHECK = "Off"

# Windows dotfiles
# Set-Location C:\
new-alias -Name clip -Value "C:\Windows\System32\clip.exe"
new-alias -Name pbcopy -Value "C:\Windows\System32\clip.exe"
new-alias -Name dup -Value windows_czkawka_cli
new-alias -Name pass -Value gopass

# Use analyzer using: Invoke-ScriptAnalyzer .\your-script.ps1
# Auto-install PSScriptAnalyzer if not present
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -ErrorAction SilentlyContinue
}
Import-Module PSScriptAnalyzer -ErrorAction SilentlyContinue

# Set autocomplete similar to bash with a menu showing the options.
# Also check out -Function MenuComplete.
Set-PSReadlineKeyHandler -Key Tab -Function Complete

# When pushing arrow up and you've already typed something, it will only show prefixed strings.
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward


# TODO set your own host
# Write-Host "`e]0;$PWD`a" -NoNewLine
# razordot.ps1 dot-sources this profile after phase 3. Leave the installer log on screen.
if (-not $global:RAZORDOT_RUN_ID) {
    Clear-Host
}

# Enable this if you use Flutter in China.
# $env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
# $env:PUB_HOSTED_URL='https://pub.flutter-io.cn'


# zoxide
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# Per-folder setup scripts can install persistent profile fragments here.
$profileFragmentsDir = Join-Path $PSScriptRoot "profiles.d"
if (Test-Path -LiteralPath $profileFragmentsDir -PathType Container) {
    Get-ChildItem -LiteralPath $profileFragmentsDir -Filter "*.ps1" -File |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }
}

# fnm (Fast Node Manager)
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}

