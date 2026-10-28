[CmdletBinding()]
param(
    [string]$ApiKey
)

$ErrorActionPreference = 'Stop'

try {
    $InstallDir = (New-Item -Path (Join-Path $env:LOCALAPPDATA 'VirusTotalMenu') -ItemType Directory -Force).FullName

    $vtCheckPath = Join-Path $InstallDir 'VTCheck.ps1'
    Copy-Item -Path (Join-Path $PSScriptRoot 'VTCheck.ps1') -Destination $vtCheckPath -Force
    Unblock-File -LiteralPath $vtCheckPath

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

    $cmdValue = '"{0}" --headless "{1}" -NoProfile -ExecutionPolicy Bypass -File "{2}" "%1"' -f `
        (Join-Path $env:SystemRoot 'System32\conhost.exe'), (Get-Process -Id $PID).Path, $vtCheckPath

    $verbPath   = 'Software\Classes\*\shell\VirusTotal'
    $commandKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("$verbPath\command")
    $commandKey.SetValue('', $cmdValue)
    $commandKey.Dispose()

    $verbKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($verbPath)
    $verbKey.SetValue('', 'Scan with VirusTotal')
    $verbKey.SetValue('Icon', 'shell32.dll,23')
    $verbKey.Dispose()

    Write-Host "Installation completed successfully!"
}
catch {
    Write-Error "Installation failed: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}
