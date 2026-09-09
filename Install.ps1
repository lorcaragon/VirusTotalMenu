[CmdletBinding()]
param(
    [string]$ApiKey
)

$ErrorActionPreference = 'Stop'

try {
    $InstallDir = (New-Item -Path (Join-Path $env:LOCALAPPDATA 'VirusTotalMenu') -ItemType Directory -Force).FullName

    Copy-Item -Path (Join-Path $PSScriptRoot 'VTCheck.ps1') -Destination $InstallDir -Force

    $apiKeyFile = Join-Path $InstallDir 'apikey.dat'
    if (-not (Test-Path -LiteralPath $apiKeyFile)) {
        if ($ApiKey) {
            $secureKey = ConvertTo-SecureString -String $ApiKey -AsPlainText -Force
        }
        else {
            $secureKey = Read-Host -Prompt 'Enter your VirusTotal API key' -AsSecureString
        }
        $secureKey | ConvertFrom-SecureString | Set-Content -LiteralPath $apiKeyFile
        Write-Host "API key saved: $apiKeyFile"
    }
    else {
        Write-Host "Using existing API key."
    }

    $conhostExe  = Join-Path $env:SystemRoot 'System32\conhost.exe'
    $psExe       = (Get-Process -Id $PID).Path
    $vtCheckPath = Join-Path $InstallDir 'VTCheck.ps1'
    $cmdValue    = '"{0}" --headless "{1}" -NoProfile -ExecutionPolicy Bypass -File "{2}" "%1"' -f $conhostExe, $psExe, $vtCheckPath

    $classesKey = $null
    $shellKey   = $null
    $commandKey = $null
    try {
        $classesKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes', $true)
        $shellKey   = $classesKey.CreateSubKey('*\shell\VirusTotal')
        $shellKey.SetValue('', 'Scan with VirusTotal')
        $shellKey.SetValue('Icon', 'shell32.dll,23')
        $commandKey = $shellKey.CreateSubKey('command')
        $commandKey.SetValue('', $cmdValue)
    }
    finally {
        if ($commandKey) { $commandKey.Close() }
        if ($shellKey)   { $shellKey.Close() }
        if ($classesKey) { $classesKey.Close() }
    }

    Write-Host "Installation completed successfully!"
}
catch {
    Write-Error "Installation failed: $($_.Exception.Message)"
    exit 1
}
