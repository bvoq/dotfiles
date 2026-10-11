# SSH PowerShell profile fragment; equivalent to ssh/.zshrc.d/00_safe_config.zsh.

function setupnewsshkey {
    param(
        [string]$Name,
        [string]$Email,
        [string]$SshHost
    )

    function Test-SshHostHasIdentityFile {
        param(
            [Parameter(Mandatory = $true)]
            [string]$ConfigPath,
            [Parameter(Mandatory = $true)]
            [string]$WantedHost
        )

        $inHost = $false
        foreach ($line in [IO.File]::ReadLines($ConfigPath)) {
            $trimmed = $line.Trim()
            if ($trimmed -match '^(?i)host\s+(.*)$') {
                $inHost = $false
                foreach ($token in ($Matches[1] -split '\s+')) {
                    if ($token -ceq $WantedHost) { $inHost = $true }
                }
                continue
            }
            if ($inHost -and $trimmed -match '^(?i)identityfile\b') {
                return $true
            }
        }
        return $false
    }

    function Start-SetupSshAgent {
        $service = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
        if (-not $service) {
            Write-Error "ssh-agent service was not found."
            return $false
        }
        if ($service.StartType -eq "Disabled") {
            try {
                Set-Service -Name ssh-agent -StartupType Manual -ErrorAction Stop
            } catch {
                Write-Error "Could not enable the ssh-agent service. From an elevated PowerShell: Set-Service ssh-agent -StartupType Manual"
                return $false
            }
        }
        if ((Get-Service -Name ssh-agent).Status -ne "Running") {
            try {
                Start-Service -Name ssh-agent -ErrorAction Stop
            } catch {
                Write-Error "Could not start ssh-agent. $($_.Exception.Message)"
                return $false
            }
        }
        return $true
    }

    function Set-SshUserOnlyAcl {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,
            [switch]$Directory
        )

        $account = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $rights = if ($Directory) { "(OI)(CI)F" } else { "F" }
        & icacls.exe $Path /inheritance:r /grant:r "${account}:${rights}" "NT AUTHORITY\SYSTEM:${rights}" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not restrict permissions on $Path."
        }
    }

    if ($PSBoundParameters.Count -ne 3 -or $args.Count -ne 0) {
        Write-Error "Usage: setupnewsshkey <name> <email> <host>"
        return
    }

    $sshDir = Join-Path $HOME ".ssh"
    $configPath = Join-Path $sshDir "config"
    $keyPath = Join-Path $sshDir "id_$Name"

    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    Set-SshUserOnlyAcl -Path $sshDir -Directory

    if ((Test-Path -LiteralPath $configPath -PathType Leaf) -and (Test-SshHostHasIdentityFile -ConfigPath $configPath -WantedHost $SshHost)) {
        Write-Error "SSH config already has an IdentityFile for host $SshHost. Aborting."
        return
    }

    if ((Test-Path -LiteralPath $keyPath) -or (Test-Path -LiteralPath "$keyPath.pub")) {
        Write-Error "SSH key already exists: $keyPath. Aborting."
        return
    }

    & ssh-keygen -t ed25519 -C $Email -f $keyPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "ssh-keygen failed."
        return
    }

    if (-not (Start-SetupSshAgent)) {
        return
    }
    & ssh-add $keyPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "ssh-add failed."
        return
    }

    $newline = "`n"
    $stanza = New-Object System.Collections.Generic.List[string]
    if ((Test-Path -LiteralPath $configPath -PathType Leaf) -and ((Get-Item -LiteralPath $configPath).Length -gt 0)) {
        $stanza.Add("")
    }
    $stanza.Add("Host $SshHost")
    $stanza.Add("  AddKeysToAgent yes")
    $stanza.Add("  IdentityFile ~/.ssh/id_$Name")
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [IO.File]::AppendAllText($configPath, (($stanza -join $newline) + $newline), $utf8)
    Set-SshUserOnlyAcl -Path $configPath

    $publicKey = ([IO.File]::ReadAllText("$keyPath.pub")).TrimEnd("`r", "`n")
    Set-Clipboard -Value $publicKey
    Write-Host "Public key copied to clipboard."
}
