param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath
)
$ErrorActionPreference = 'Stop'
$InstallDir  = $PSScriptRoot
$ApiKeyFile  = Join-Path $InstallDir 'apikey.dat'

Add-Type -Namespace Native -Name DpiHelper -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true)]
public static extern bool SetProcessDpiAwarenessContext(IntPtr dpiContext);

[DllImport("shcore.dll", SetLastError = true)]
public static extern int SetProcessDpiAwareness(int value);

[DllImport("user32.dll", SetLastError = true)]
public static extern bool SetProcessDPIAware();
'@
try {
    [void][Native.DpiHelper]::SetProcessDpiAwarenessContext([IntPtr](-4))
} catch {
    try {
        [void][Native.DpiHelper]::SetProcessDpiAwareness(2)
    } catch {
        try {
            [void][Native.DpiHelper]::SetProcessDPIAware()
        } catch {}
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
function Get-ApiKey {
    if (-not (Test-Path -LiteralPath $ApiKeyFile)) {
        throw "API key not found. Please run Install.ps1 first."
    }
    $encrypted = Get-Content -LiteralPath $ApiKeyFile
    $secure    = ConvertTo-SecureString -String $encrypted
    $bstr      = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Show-Notification {
    param(
        [string]$Title,
        [string]$Text,
        [ValidateSet('Ok', 'Info', 'Warning', 'Error')][string]$Level = 'Info',
        [string]$ClickUrl
    )

    $palette = @{
        'Ok'      = @{ Accent = '#27AE60'; Glyph = [char]0x2713 }
        'Info'    = @{ Accent = '#2E86DE'; Glyph = [char]0x2139 }
        'Warning' = @{ Accent = '#F39C12'; Glyph = [char]0x0021 }
        'Error'   = @{ Accent = '#E74C3C'; Glyph = [char]0x2715 }
    }
    $accentColor = [System.Drawing.ColorTranslator]::FromHtml($palette[$Level].Accent)
    $glyph       = $palette[$Level].Glyph
    $form                 = New-Object System.Windows.Forms.Form
    $form.AutoScaleMode    = [System.Windows.Forms.AutoScaleMode]::None
    $form.Text             = 'VirusTotal'
    $form.FormBorderStyle  = 'FixedDialog'
    $form.ControlBox       = $false
    $form.MaximizeBox      = $false
    $form.MinimizeBox      = $false
    $form.StartPosition    = 'CenterScreen'
    $form.BackColor        = [System.Drawing.Color]::White
    $form.Font             = New-Object System.Drawing.Font('Segoe UI', 9)
    $form.TopMost          = $true

    $gfx      = $form.CreateGraphics()
    $dpiScale = [double]$gfx.DpiX / 96.0
    $gfx.Dispose()
    function Scale([double]$Value) { return [int][Math]::Round($Value * $dpiScale) }

    $form.ClientSize = New-Object System.Drawing.Size((Scale 440), (Scale 232))

    $accentBar            = New-Object System.Windows.Forms.Panel
    $accentBar.Dock        = 'Left'
    $accentBar.Width       = Scale 8
    $accentBar.BackColor   = $accentColor
    $form.Controls.Add($accentBar)

    $iconSize   = Scale 44
    $iconPanel  = New-Object System.Windows.Forms.Panel
    $iconPanel.Size      = New-Object System.Drawing.Size($iconSize, $iconSize)
    $iconPanel.Location  = New-Object System.Drawing.Point((Scale 28), (Scale 24))
    $iconPanel.BackColor = $form.BackColor
    $iconFont = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $iconPanel.Add_Paint({
        param($senderObj, $paintArgs)
        $g = $paintArgs.Graphics
        $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint  = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $rect = New-Object System.Drawing.RectangleF(0, 0, ($iconSize - 1), ($iconSize - 1))
        $brush = New-Object System.Drawing.SolidBrush($accentColor)
        try {
            $g.FillEllipse($brush, $rect)
        } finally {
            $brush.Dispose()
        }
        $emSize = $iconFont.Size * $g.DpiY / 72
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddString($glyph, $iconFont.FontFamily, [int]$iconFont.Style, $emSize, [System.Drawing.PointF]::Empty, [System.Drawing.StringFormat]::GenericTypographic)
        $glyphBounds = $path.GetBounds()
        $offsetX = (($rect.Width - $glyphBounds.Width) / 2) - $glyphBounds.X
        $offsetY = (($rect.Height - $glyphBounds.Height) / 2) - $glyphBounds.Y
        $matrix = New-Object System.Drawing.Drawing2D.Matrix
        $matrix.Translate($offsetX, $offsetY)
        $path.Transform($matrix)
        try {
            $g.FillPath([System.Drawing.Brushes]::White, $path)
        } finally {
            $path.Dispose()
            $matrix.Dispose()
        }
    }.GetNewClosure())
    $form.Controls.Add($iconPanel)

    $titleLabel            = New-Object System.Windows.Forms.Label
    $titleLabel.Text       = $Title
    $titleLabel.Font       = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor  = [System.Drawing.Color]::FromArgb(40, 40, 40)
    $titleLabel.Location   = New-Object System.Drawing.Point((Scale 86), (Scale 24))
    $titleLabel.AutoSize   = $true
    $titleLabel.MaximumSize = New-Object System.Drawing.Size((Scale 320), 0)
    $form.Controls.Add($titleLabel)

    $msgFont    = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $msgLeft    = Scale 86
    $msgTop     = Scale 54
    $msgWidth   = Scale 320

    $measuredSize = [System.Windows.Forms.TextRenderer]::MeasureText(
        $Text, $msgFont, (New-Object System.Drawing.Size($msgWidth, 0)),
        [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::TextBoxControl)
    $msgHeight = [Math]::Max((Scale 40), [Math]::Min($measuredSize.Height + (Scale 6), (Scale 400)))
    $msgLabel              = New-Object System.Windows.Forms.Label
    $msgLabel.Text         = $Text
    $msgLabel.Font         = $msgFont
    $msgLabel.ForeColor    = [System.Drawing.Color]::FromArgb(90, 90, 90)
    $msgLabel.Location     = New-Object System.Drawing.Point($msgLeft, $msgTop)
    $msgLabel.Size         = New-Object System.Drawing.Size($msgWidth, $msgHeight)
    $form.Controls.Add($msgLabel)

    $buttonTop      = $msgLabel.Bottom + (Scale 24)
    $formHeight     = $buttonTop + (Scale 34) + (Scale 24)
    $form.ClientSize = New-Object System.Drawing.Size((Scale 440), $formHeight)
    $script:dialogResult = $false
    if ($ClickUrl) {
        $viewBtn            = New-Object System.Windows.Forms.Button
        $viewBtn.Text        = 'View Report'
        $viewBtn.Size        = New-Object System.Drawing.Size((Scale 120), (Scale 34))
        $viewBtn.Location    = New-Object System.Drawing.Point((Scale 196), $buttonTop)
        $viewBtn.FlatStyle   = 'Flat'
        $viewBtn.FlatAppearance.BorderSize = 0
        $viewBtn.BackColor   = $accentColor
        $viewBtn.ForeColor   = [System.Drawing.Color]::White
        $viewBtn.Font        = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
        $viewBtn.Add_Click({ $script:dialogResult = $true; $form.Close() })
        $form.Controls.Add($viewBtn)
        $closeBtn            = New-Object System.Windows.Forms.Button
        $closeBtn.Text        = 'Dismiss'
        $closeBtn.Size        = New-Object System.Drawing.Size((Scale 90), (Scale 34))
        $closeBtn.Location    = New-Object System.Drawing.Point((Scale 322), $buttonTop)
        $closeBtn.FlatStyle   = 'Flat'
        $closeBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(210, 210, 210)
        $closeBtn.BackColor   = [System.Drawing.Color]::White
        $closeBtn.ForeColor   = [System.Drawing.Color]::FromArgb(90, 90, 90)
        $closeBtn.Add_Click({ $form.Close() })
        $form.Controls.Add($closeBtn)
        $form.Add_Shown({ $viewBtn.Focus() })
        $form.ShowDialog() | Out-Null
        if ($script:dialogResult) {
            Start-Process $ClickUrl
        }
    }
    else {
        $okBtn               = New-Object System.Windows.Forms.Button
        $okBtn.Text           = 'OK'
        $okBtn.Size           = New-Object System.Drawing.Size((Scale 90), (Scale 34))
        $okBtn.Location       = New-Object System.Drawing.Point((Scale 322), $buttonTop)
        $okBtn.FlatStyle      = 'Flat'
        $okBtn.FlatAppearance.BorderSize = 0
        $okBtn.BackColor      = $accentColor
        $okBtn.ForeColor      = [System.Drawing.Color]::White
        $okBtn.Font           = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
        $okBtn.Add_Click({ $form.Close() })
        $form.Controls.Add($okBtn)
        $form.Add_Shown({ $okBtn.Focus() })
        $form.ShowDialog() | Out-Null
    }
}
function Show-BalloonTip {
    param(
        [string]$Title,
        [string]$Text,
        [int]$DurationMs = 8000
    )
    $icon = New-Object System.Windows.Forms.NotifyIcon
    $icon.Icon = [System.Drawing.SystemIcons]::Information
    $icon.Visible = $true
    $icon.BalloonTipTitle = $Title
    $icon.BalloonTipText  = $Text
    $icon.ShowBalloonTip($DurationMs)
    Start-Sleep -Milliseconds 300
    return $icon
}
function Invoke-VTFileUpload {
    param(
        [string]$Uri,
        [string]$ApiKey,
        [string]$FilePath
    )
    $curlExe = "$env:SystemRoot\System32\curl.exe"
    if (Test-Path $curlExe) {
        $rawResponse = & $curlExe -s -X POST -H "x-apikey: $ApiKey" -F "file=@$FilePath" "$Uri"
        if ([string]::IsNullOrWhiteSpace($rawResponse)) {
            throw "Upload failed: Empty response from VirusTotal."
        }
        $json = $rawResponse | ConvertFrom-Json
        if ($json.error) {
            throw "Upload failed: $($json.error.message)"
        }
        return $json
    }
    else {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("x-apikey", $ApiKey)
        $responseBytes = $webClient.UploadFile($Uri, "POST", $FilePath)
        $rawResponse = [System.Text.Encoding]::UTF8.GetString($responseBytes)
        return $rawResponse | ConvertFrom-Json
    }
}
function Submit-FileToVT {
    param(
        [string]$FilePath,
        [string]$ApiKey
    )
    $maxDirectSize = 32MB
    $fileSize      = (Get-Item -LiteralPath $FilePath).Length
    $uploadUri     = 'https://www.virustotal.com/api/v3/files'
    if ($fileSize -gt $maxDirectSize) {
        $headers = @{ 'x-apikey' = $ApiKey }
        $urlResp = Invoke-RestMethod -Uri 'https://www.virustotal.com/api/v3/files/upload_url' -Headers $headers -Method Get -ErrorAction Stop
        $uploadUri = $urlResp.data
    }
    $resp = Invoke-VTFileUpload -Uri $uploadUri -ApiKey $ApiKey -FilePath $FilePath
    return $resp.data.id
}
function Wait-VTAnalysis {
    param(
        [string]$AnalysisId,
        [string]$ApiKey,
        [int]$TimeoutSeconds = 300,
        [int]$PollIntervalSeconds = 5
    )
    $headers = @{ 'x-apikey' = $ApiKey }
    $uri     = "https://www.virustotal.com/api/v3/analyses/$AnalysisId"
    $elapsed = 0
    $balloon = $null
    while ($elapsed -lt $TimeoutSeconds) {
        $resp   = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
        $status = $resp.data.attributes.status
        if ($status -eq 'completed') {
            if ($balloon) { $balloon.Visible = $false; $balloon.Dispose() }
            return $resp
        }

        if ($elapsed % 15 -eq 0) {
            if ($balloon) { $balloon.Visible = $false; $balloon.Dispose() }
            $balloon = Show-BalloonTip -Title 'VirusTotal' `
                -Text "Still scanning on VirusTotal's servers... ($elapsed sec elapsed)`nThis depends on VT's engines, not your connection." `
                -DurationMs 6000
        }
        Start-Sleep -Seconds $PollIntervalSeconds
        $elapsed += $PollIntervalSeconds
    }
    if ($balloon) { $balloon.Visible = $false; $balloon.Dispose() }
    throw "The scan timed out after $TimeoutSeconds seconds. VirusTotal is still analyzing the file; please check the report page again in a few minutes."
}
function Show-VTVerdict {
    param(
        [int]$Detections,
        [int]$Total,
        [string]$Hash
    )
    $reportUrl = "https://www.virustotal.com/gui/file/$Hash"
    if ($Detections -ge 25) {
        Show-Notification -Title "High Risk Detected" `
            -Text "$Detections out of $Total engines flagged this file as malicious. Do not open or run it. Review the full report before proceeding." `
            -Level Error -ClickUrl $reportUrl
    }
    elseif ($Detections -ge 12) {
        Show-Notification -Title "Flagged by Several Engines" `
            -Text "$Detections out of $Total engines flagged this file. Reviewing the report before opening it is recommended." `
            -Level Warning -ClickUrl $reportUrl
    }
    elseif ($Detections -ge 4) {
        Show-Notification -Title "A Few Engines Flagged This File" `
            -Text "$Detections out of $Total engines flagged this file. This is common with packed or obfuscated software and is often a false positive, but you can check the report if you want details." `
            -Level Info -ClickUrl $reportUrl
    }
    elseif ($Detections -gt 0) {
        Show-Notification -Title "Likely False Positive" `
            -Text "Only $Detections out of $Total engines flagged this file, which is typically an isolated false positive rather than an actual threat." `
            -Level Ok -ClickUrl $reportUrl
    }
    else {
        Show-Notification -Title "Clean File" `
            -Text "No engines flagged this file. All $Total engines reported it as clean." `
            -Level Ok -ClickUrl $reportUrl
    }
}
if (-not (Test-Path -LiteralPath $FilePath)) {
    Show-Notification -Title "VirusTotal Check" -Text "File not found:`n$FilePath" -Level Error
    exit 1
}
try {
    $apiKey = Get-ApiKey
} catch {
    Show-Notification -Title "VirusTotal Check" -Text $_.Exception.Message -Level Error
    exit 1
}
try {
    $hash = (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash
} catch {
    Show-Notification -Title "VirusTotal Check" -Text "Could not compute hash:`n$($_.Exception.Message)" -Level Error
    exit 1
}
$reportUrl = "https://www.virustotal.com/gui/file/$hash"

$headers = @{ 'x-apikey' = $apiKey }
try {
    $response = Invoke-RestMethod -Uri "https://www.virustotal.com/api/v3/files/$hash" -Headers $headers -Method Get -ErrorAction Stop
    $stats = $response.data.attributes.last_analysis_stats
    $malicious = $stats.malicious
    $suspicious = $stats.suspicious
    $total = ($stats.PSObject.Properties | Measure-Object -Property Value -Sum).Sum
    $detections = $malicious + $suspicious
    Show-VTVerdict -Detections $detections -Total $total -Hash $hash
}
catch {
    if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
        $balloon = $null
        try {
            $balloon = Show-BalloonTip -Title 'VirusTotal' `
                -Text "File not found in the VirusTotal database.`nUploading now, please wait..."
            $analysisId = Submit-FileToVT -FilePath $FilePath -ApiKey $apiKey
            if ($balloon) { $balloon.Visible = $false; $balloon.Dispose(); $balloon = $null }

            $analysisResult = Wait-VTAnalysis -AnalysisId $analysisId -ApiKey $apiKey
            $stats      = $analysisResult.data.attributes.stats
            $malicious  = $stats.malicious
            $suspicious = $stats.suspicious
            $total      = ($stats.PSObject.Properties | Measure-Object -Property Value -Sum).Sum
            $detections = $malicious + $suspicious
            Show-VTVerdict -Detections $detections -Total $total -Hash $hash
        }
        catch {
            if ($balloon) { $balloon.Visible = $false; $balloon.Dispose(); $balloon = $null }
            Show-Notification -Title "Upload/Scan Failed" `
                -Text "The file could not be uploaded or scanned automatically:`n$($_.Exception.Message)`n`nYou can try uploading it manually instead." `
                -Level Error -ClickUrl "https://www.virustotal.com/gui/home/upload"
        }
    }
    else {
        Show-Notification -Title "Error" -Text "Connection error:`n$($_.Exception.Message)" -Level Error
    }
}