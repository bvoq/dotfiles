function phase_1_machine_installs {
    if (-not (Verify-Elevated)) {
        Write-Host "Skipping TeXmacs machine install: this PowerShell process is not elevated." -ForegroundColor Yellow
        return
    }

    install_wingetfile -Path (Join-Path $PSScriptRoot "winget_package.json") `
        -OnlyScope machine -IgnoreVersions | Out-Null
}

function phase_3_dotfiles {
    $texmacsHome = Join-Path $env:APPDATA "TeXmacs"
    link_file (Join-Path $PSScriptRoot "TeXmacs\packages\dotfiles.ts") `
        (Join-Path $texmacsHome "packages\dotfiles.ts")
    link_file (Join-Path $PSScriptRoot "TeXmacs\progs\my-init-buffer.scm") `
        (Join-Path $texmacsHome "progs\my-init-buffer.scm")
    link_file (Join-Path $PSScriptRoot "TeXmacs\system\settings.scm") `
        (Join-Path $texmacsHome "system\settings.scm")
    link_file (Join-Path $PSScriptRoot "TeXmacs\system\preferences.scm") `
        (Join-Path $texmacsHome "system\preferences.scm")
}
