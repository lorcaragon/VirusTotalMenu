[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    $shellKey  = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes\*\shell', $true)
    $verbFound = $shellKey -and ($shellKey.GetSubKeyNames() -contains 'VirusTotal')
    if ($verbFound) {
        $shellKey.DeleteSubKeyTree('VirusTotal')
    }
    if ($shellKey) {
        $shellKey.Dispose()
    }
    if ($verbFound) {
        Write-Host "Right-click menu entry removed."
    }
    else {
        Write-Host "Right-click menu entry was not found; nothing to remove."
    }

    $InstallDir = Join-Path $env:LOCALAPPDATA 'VirusTotalMenu'
    if (Test-Path -LiteralPath $InstallDir) {
        $answer = Read-Host "Delete the install folder ($InstallDir)? (Y/N)"
        if ($answer -match '^[Yy]') {
            Remove-Item -LiteralPath $InstallDir -Recurse -Force
            Write-Host "Install folder deleted."
        }
    }

    Write-Host "Done."
}
catch {
    Write-Error "Uninstall failed: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}
