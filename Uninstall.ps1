& reg.exe delete "HKCU\Software\Classes\*\shell\VirusTotal" /f 2>$null | Out-Null
Write-Host "Right-click menu entry removed."
$InstallDir = Join-Path $env:LOCALAPPDATA 'VirusTotalMenu'
if (Test-Path -LiteralPath $InstallDir) {
    $answer = Read-Host "Delete the install folder ($InstallDir)? (Y/N)"
    if ($answer -match '^[Yy]') {
        Remove-Item -LiteralPath $InstallDir -Recurse -Force
        Write-Host "Install folder deleted."
    }
}
Write-Host "Done."