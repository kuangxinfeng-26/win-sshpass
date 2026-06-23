@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sshpass.ps1" %*
