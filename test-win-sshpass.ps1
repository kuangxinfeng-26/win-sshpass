$ErrorActionPreference = "Stop"

$script = Join-Path $PSScriptRoot "sshpass.ps1"

Write-Host "Version:"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -V
if ($LASTEXITCODE -ne 0) {
    throw "Version command failed"
}

Write-Host "Help:"
$helpOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script --help
if ($LASTEXITCODE -ne 0) {
    throw "Help command failed"
}
$helpOutput | Select-Object -First 3

Write-Host "Parse failure check:"
$oldBackend = $env:WIN_SSHPASS_BACKEND
$env:WIN_SSHPASS_BACKEND = "plink"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -p test
$env:WIN_SSHPASS_BACKEND = $oldBackend
if ($LASTEXITCODE -eq 0) {
    throw "Expected missing command failure"
}

Write-Host "Smoke tests completed."
