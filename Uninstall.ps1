[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    $classesKey   = $null
    $starShellKey = $null
    try {
        $classesKey   = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes', $true)
        $starShellKey = $classesKey.OpenSubKey('*\shell', $true)
        if ($starShellKey -and ($starShellKey.GetSubKeyNames() -contains 'VirusTotal')) {
            $starShellKey.DeleteSubKeyTree('VirusTotal')
            Write-Host "Right-click menu entry removed."
        }
        else {
            Write-Host "Right-click menu entry was not found; nothing to remove."
        }
    }
    finally {
        if ($starShellKey) { $starShellKey.Close() }
        if ($classesKey)   { $classesKey.Close() }
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
    Write-Error "Uninstall failed: $($_.Exception.Message)"
    exit 1
}
