@echo off
title VirusTotal Context Menu - Installer
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Installation failed. See the message above for details.
    pause
    exit /b %ERRORLEVEL%
)

echo.
pause
