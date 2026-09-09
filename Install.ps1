$ErrorActionPreference = 'Stop'
$SourceDir  = $PSScriptRoot
$InstallDir = Join-Path $env:LOCALAPPDATA 'VirusTotalMenu'
if (-not (Test-Path -LiteralPath $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
}
Copy-Item -Path (Join-Path $SourceDir 'VTCheck.ps1') -Destination $InstallDir -Force
Copy-Item -Path (Join-Path $SourceDir 'VTCheck.vbs') -Destination $InstallDir -Force
$apiKeyFile = Join-Path $InstallDir 'apikey.dat'
if (-not (Test-Path -LiteralPath $apiKeyFile)) {
    $secureKey = Read-Host -Prompt 'Enter your VirusTotal API key' -AsSecureString
    $secureKey | ConvertFrom-SecureString | Set-Content -LiteralPath $apiKeyFile
    Write-Host "API key saved: $apiKeyFile"
} else {
    Write-Host "Using existing API key."
}

$wscriptExe = Join-Path $env:SystemRoot 'System32\wscript.exe'
$vbsPath    = Join-Path $InstallDir 'VTCheck.vbs'
$cmdValue   = "`"$wscriptExe`" `"$vbsPath`" `"%1`""

& reg.exe add "HKCU\Software\Classes\*\shell\VirusTotal" /ve /t REG_SZ /d "Scan with VirusTotal" /f | Out-Null
& reg.exe add "HKCU\Software\Classes\*\shell\VirusTotal" /v "Icon" /t REG_SZ /d "shell32.dll,23" /f | Out-Null
& reg.exe add "HKCU\Software\Classes\*\shell\VirusTotal\command" /ve /t REG_SZ /d $cmdValue /f | Out-Null
Write-Host "Installation completed successfully!"