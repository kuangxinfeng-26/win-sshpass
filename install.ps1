param(
    [ValidateSet("auto", "wsl", "plink")]
    [string]$Backend = "auto",

    [string]$InstallDir = "$env:USERPROFILE\.win-sshpass\bin",

    [switch]$DownloadPlink,

    [switch]$NoPathUpdate
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[win-sshpass] $Message"
}

function Add-UserPath {
    param([string]$PathToAdd)

    $current = [Environment]::GetEnvironmentVariable("PATH", "User")
    $parts = @()
    if ($current) {
        $parts = $current -split ";" | Where-Object { $_ -ne "" }
    }

    if ($parts -notcontains $PathToAdd) {
        $newPath = (@($parts) + $PathToAdd) -join ";"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Write-Step "Added to user PATH: $PathToAdd"
    } else {
        Write-Step "User PATH already contains: $PathToAdd"
    }
}

function Download-Plink {
    param([string]$Destination)

    $arch = if ([Environment]::Is64BitOperatingSystem) { "w64" } else { "w32" }
    $url = "https://the.earth.li/~sgtatham/putty/latest/$arch/plink.exe"
    Write-Step "Downloading plink.exe from $url"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $Destination
}

$sourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$shimPs1 = Join-Path $sourceDir "sshpass.ps1"
$shimCmd = Join-Path $sourceDir "sshpass.cmd"

if (-not (Test-Path -LiteralPath $shimPs1)) {
    throw "Missing sshpass.ps1 next to install.ps1"
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -LiteralPath $shimPs1 -Destination (Join-Path $InstallDir "sshpass.ps1") -Force
Copy-Item -LiteralPath $shimCmd -Destination (Join-Path $InstallDir "sshpass.cmd") -Force

if ($Backend -eq "plink" -or ($Backend -eq "auto" -and $DownloadPlink)) {
    $plinkPath = Join-Path $InstallDir "plink.exe"
    if (-not (Test-Path -LiteralPath $plinkPath)) {
        if ($DownloadPlink) {
            Download-Plink -Destination $plinkPath
        } else {
            Write-Step "plink.exe not found. Re-run with -DownloadPlink or install PuTTY separately."
        }
    }
}

if (-not $NoPathUpdate) {
    Add-UserPath -PathToAdd $InstallDir
}

Write-Step "Installed to $InstallDir"
Write-Step "Restart PowerShell, then run: sshpass -V"
