@echo off
title VirusTotal Context Menu - Uninstaller
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Uninstall failed. See the message above for details.
    pause
    exit /b %ERRORLEVEL%
)

echo.
pause
