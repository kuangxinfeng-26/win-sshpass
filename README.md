# win-sshpass

PowerShell-friendly `sshpass` command for Windows.

This package provides a Windows command named `sshpass` that can be used directly from PowerShell or CMD.

It supports two backends:

- `wsl`: calls real Linux `sshpass` inside WSL. This is the most compatible backend.
- `plink`: calls PuTTY `plink.exe` with password authentication. This works without WSL, but it is not a full OpenSSH replacement.

## Install

Open PowerShell and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer copies files to:

```text
%USERPROFILE%\.win-sshpass\bin
```

and adds that directory to your user `PATH`.

Restart PowerShell after installation.

## Recommended Backend: WSL

Install `sshpass` in WSL:

```powershell
wsl -d Ubuntu -- sudo apt update
wsl -d Ubuntu -- sudo apt install -y sshpass
```

Then use it from Windows:

```powershell
sshpass -p "your-password" ssh user@host
sshpass -p "your-password" ssh -p 2222 user@host "hostname"
```

To avoid putting the password directly on the command line:

```powershell
$env:SSHPASS = "your-password"
sshpass -e ssh user@host "hostname"
Remove-Item Env:\SSHPASS
```

## Plink Backend

If WSL is unavailable, install with PuTTY `plink.exe`:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Backend plink -DownloadPlink
```

Usage:

```powershell
sshpass -p "your-password" ssh user@host
sshpass -p "your-password" ssh -p 2222 user@host "hostname"
```

Plink does not behave exactly like OpenSSH. For first-time host connections, PuTTY may require a cached host key or a configured `-hostkey` option.

## Force Backend

```powershell
$env:WIN_SSHPASS_BACKEND = "wsl"
sshpass -p "your-password" ssh user@host

$env:WIN_SSHPASS_BACKEND = "plink"
sshpass -p "your-password" ssh user@host
```

## Supported sshpass Options

- `-p <password>`
- `-e` with `SSHPASS`
- `-f <password-file>`
- `-V`
- `-h` / `--help`

## Security Notes

Password authentication is less safe than SSH keys. Prefer SSH keys for persistent automation.

Using `-p` may expose the password through process lists. Prefer `-e` with a short-lived `SSHPASS` environment variable when possible.

Do not commit passwords, tokens, cookies, or private keys to any repository.
