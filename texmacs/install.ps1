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
    link_file (Join-Path $PSScriptRoot "TeXmacs\packages\bvoqs-package.ts") `
        (Join-Path $texmacsHome "packages\bvoqs-package.ts")
    link_file (Join-Path $PSScriptRoot "TeXmacs\progs\my-init-buffer.scm") `
        (Join-Path $texmacsHome "progs\my-init-buffer.scm")
    link_file (Join-Path $PSScriptRoot "TeXmacs\progs\my-init-texmacs.scm") `
        (Join-Path $texmacsHome "progs\my-init-texmacs.scm")
    link_file (Join-Path $PSScriptRoot "TeXmacs\styles\bvoqs-beamer.ts") `
        (Join-Path $texmacsHome "styles\bvoqs-beamer.ts")
    link_file (Join-Path $PSScriptRoot "TeXmacs\styles\bvoqs-exam.ts") `
        (Join-Path $texmacsHome "styles\bvoqs-exam.ts")
    link_file (Join-Path $PSScriptRoot "TeXmacs\system\settings.scm") `
        (Join-Path $texmacsHome "system\settings.scm")
    link_file (Join-Path $PSScriptRoot "TeXmacs\system\preferences.scm") `
        (Join-Path $texmacsHome "system\preferences.scm")
}
