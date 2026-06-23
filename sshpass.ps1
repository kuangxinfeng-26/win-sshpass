$ErrorActionPreference = "Stop"
$Version = "win-sshpass 0.1.0"
$OriginalArgs = [string[]]$args

function Show-Usage {
    @"
$Version

Usage:
  sshpass -p <password> ssh [ssh-options] user@host [command]
  sshpass -e ssh [ssh-options] user@host [command]
  sshpass -f <password-file> ssh [ssh-options] user@host [command]

Supported sshpass options:
  -p <password>       Use password from argument
  -e                  Use password from SSHPASS environment variable
  -f <file>           Use first line of file as password
  -V                  Print version
  -h, --help          Show this help

Backends:
  auto                Prefer WSL sshpass, fallback to plink
  wsl                 Force WSL sshpass
  plink               Force PuTTY plink.exe

Set backend with:
  `$env:WIN_SSHPASS_BACKEND = "wsl"
  `$env:WIN_SSHPASS_BACKEND = "plink"
"@
}

function Test-WslSshpass {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        return $false
    }
    & wsl.exe sh -lc "command -v sshpass >/dev/null 2>&1"
    return $LASTEXITCODE -eq 0
}

function Get-PlinkPath {
    $local = Join-Path $PSScriptRoot "plink.exe"
    if (Test-Path -LiteralPath $local) {
        return $local
    }

    $cmd = Get-Command plink.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    return $null
}

function Invoke-WslBackend {
    param([string[]]$OriginalArgs)

    & wsl.exe -- sshpass @OriginalArgs
    exit $LASTEXITCODE
}

function Parse-SshpassArgs {
    param([string[]]$InputArgs)

    $password = $null
    $remaining = New-Object System.Collections.Generic.List[string]
    $i = 0

    while ($i -lt $InputArgs.Count) {
        $arg = $InputArgs[$i]

        switch ($arg) {
            "-V" {
                Write-Output $Version
                exit 0
            }
            "-h" {
                Show-Usage
                exit 0
            }
            "--help" {
                Show-Usage
                exit 0
            }
            "-e" {
                $password = $env:SSHPASS
                if ([string]::IsNullOrEmpty($password)) {
                    throw "SSHPASS environment variable is empty"
                }
                $i++
                continue
            }
            "-p" {
                if ($i + 1 -ge $InputArgs.Count) {
                    throw "Missing password after -p"
                }
                $password = $InputArgs[$i + 1]
                $i += 2
                continue
            }
            "-f" {
                if ($i + 1 -ge $InputArgs.Count) {
                    throw "Missing password file after -f"
                }
                $file = $InputArgs[$i + 1]
                if (-not (Test-Path -LiteralPath $file)) {
                    throw "Password file not found: $file"
                }
                $password = (Get-Content -LiteralPath $file -TotalCount 1 -Raw).TrimEnd("`r", "`n")
                $i += 2
                continue
            }
            default {
                for ($j = $i; $j -lt $InputArgs.Count; $j++) {
                    $remaining.Add($InputArgs[$j])
                }
                break
            }
        }

        break
    }

    if ([string]::IsNullOrEmpty($password)) {
        throw "Password not provided. Use -p, -e, or -f."
    }
    if ($remaining.Count -eq 0) {
        throw "Missing command. Expected: ssh ..."
    }

    [pscustomobject]@{
        Password = $password
        Command = [string[]]$remaining
    }
}

function Convert-OpenSshToPlinkArgs {
    param([string[]]$CommandArgs, [string]$Password)

    if ($CommandArgs[0] -ne "ssh") {
        throw "Plink backend only supports ssh command. Use WSL backend for full sshpass compatibility."
    }

    $plinkArgs = New-Object System.Collections.Generic.List[string]
    $plinkArgs.Add("-ssh")
    $plinkArgs.Add("-batch")
    $plinkArgs.Add("-pw")
    $plinkArgs.Add($Password)

    $i = 1
    while ($i -lt $CommandArgs.Count) {
        $arg = $CommandArgs[$i]

        if ($arg -eq "-p") {
            if ($i + 1 -ge $CommandArgs.Count) {
                throw "Missing port after ssh -p"
            }
            $plinkArgs.Add("-P")
            $plinkArgs.Add($CommandArgs[$i + 1])
            $i += 2
            continue
        }

        if ($arg -eq "-l") {
            if ($i + 1 -ge $CommandArgs.Count) {
                throw "Missing user after ssh -l"
            }
            $plinkArgs.Add("-l")
            $plinkArgs.Add($CommandArgs[$i + 1])
            $i += 2
            continue
        }

        if ($arg -eq "-o") {
            if ($i + 1 -ge $CommandArgs.Count) {
                throw "Missing value after ssh -o"
            }
            $opt = $CommandArgs[$i + 1]
            if ($opt -match "^(StrictHostKeyChecking|UserKnownHostsFile|LogLevel)=") {
                $i += 2
                continue
            }
            throw "Plink backend does not support ssh option: -o $opt"
        }

        if ($arg -eq "-i") {
            throw "Plink backend does not support OpenSSH -i keys. Use WSL backend or PuTTY .ppk configuration."
        }

        $plinkArgs.Add($arg)
        $i++
    }

    [string[]]$plinkArgs
}

function Invoke-PlinkBackend {
    param([string[]]$CommandArgs, [string]$Password)

    $plink = Get-PlinkPath
    if (-not $plink) {
        throw "plink.exe not found. Run install.ps1 -Backend plink -DownloadPlink, install PuTTY, or use WSL backend."
    }

    $plinkArgs = Convert-OpenSshToPlinkArgs -CommandArgs $CommandArgs -Password $Password
    & $plink @plinkArgs
    exit $LASTEXITCODE
}

if (-not $OriginalArgs -or $OriginalArgs.Count -eq 0) {
    Show-Usage
    exit 1
}

$backend = $env:WIN_SSHPASS_BACKEND
if ([string]::IsNullOrWhiteSpace($backend)) {
    $backend = "auto"
}
$backend = $backend.ToLowerInvariant()

if ($OriginalArgs -contains "-V" -or $OriginalArgs -contains "--help" -or $OriginalArgs -contains "-h") {
    $parsed = Parse-SshpassArgs -InputArgs $OriginalArgs
}

if ($backend -eq "wsl") {
    Invoke-WslBackend -OriginalArgs $OriginalArgs
}

if ($backend -eq "auto" -and (Test-WslSshpass)) {
    Invoke-WslBackend -OriginalArgs $OriginalArgs
}

$parsed = Parse-SshpassArgs -InputArgs $OriginalArgs

if ($backend -eq "auto" -or $backend -eq "plink") {
    Invoke-PlinkBackend -CommandArgs $parsed.Command -Password $parsed.Password
}

throw "Unknown WIN_SSHPASS_BACKEND: $backend"
