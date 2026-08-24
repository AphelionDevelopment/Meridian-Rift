@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\build\rift\invoke.ps1"
exit /b %ERRORLEVEL%
