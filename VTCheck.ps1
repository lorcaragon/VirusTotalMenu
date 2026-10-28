param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath
)
$ErrorActionPreference = 'Stop'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::Expect100Continue = $false
$ApiKeyFile = Join-Path $PSScriptRoot 'apikey.dat'

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
}
catch {
    try {
        [void][Native.DpiHelper]::SetProcessDpiAwareness(2)
    }
    catch {
        try {
            [void][Native.DpiHelper]::SetProcessDPIAware()
        }
        catch {}
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http
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
        [string]$ClickUrl,
        [string]$ButtonText = 'OK'
    )

    $palette = @{
        'Ok'      = @{ Accent = '#27AE60'; Glyph = [char]0x2713 }
        'Info'    = @{ Accent = '#2E86DE'; Glyph = [char]0x2139 }
        'Warning' = @{ Accent = '#F39C12'; Glyph = [char]0x0021 }
        'Error'   = @{ Accent = '#E74C3C'; Glyph = [char]0x2715 }
    }
    $accentColor = [System.Drawing.ColorTranslator]::FromHtml($palette[$Level].Accent)
    $glyph       = $palette[$Level].Glyph
    $sound = switch ($Level) {
        'Warning' { [System.Media.SystemSounds]::Exclamation }
        'Error'   { [System.Media.SystemSounds]::Hand }
        default   { [System.Media.SystemSounds]::Asterisk }
    }
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

    $buttonTop    = $msgLabel.Bottom + (Scale 24)
    $buttonHeight = Scale 34
    $form.ClientSize = New-Object System.Drawing.Size((Scale 440), ($buttonTop + $buttonHeight + (Scale 24)))

    $newButton = {
        param([string]$Text, [int]$X, [int]$Width, [bool]$Primary, [scriptblock]$OnClick)
        $button              = New-Object System.Windows.Forms.Button
        $button.Text         = $Text
        $button.Size         = New-Object System.Drawing.Size($Width, $buttonHeight)
        $button.Location     = New-Object System.Drawing.Point($X, $buttonTop)
        $button.FlatStyle    = 'Flat'
        $button.Cursor       = [System.Windows.Forms.Cursors]::Hand
        if ($Primary) {
            $button.FlatAppearance.BorderSize = 0
            $button.BackColor                 = $accentColor
            $button.ForeColor                 = [System.Drawing.Color]::White
            $button.Font                      = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
        }
        else {
            $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(210, 210, 210)
            $button.BackColor                  = [System.Drawing.Color]::White
            $button.ForeColor                  = [System.Drawing.Color]::FromArgb(90, 90, 90)
        }
        $button.Add_Click($OnClick)
        $form.Controls.Add($button)
        $button
    }

    $script:dialogResult = $false
    if ($ClickUrl) {
        $viewBtn = & $newButton -Text 'View Report' -X (Scale 196) -Width (Scale 120) -Primary $true -OnClick { $script:dialogResult = $true; $form.Close() }
        $null    = & $newButton -Text 'Dismiss' -X (Scale 322) -Width (Scale 90) -Primary $false -OnClick { $form.Close() }
        $form.Add_Shown({ $viewBtn.Focus(); $sound.Play() })
    }
    else {
        $okBtn = & $newButton -Text $ButtonText -X (Scale 322) -Width (Scale 90) -Primary $true -OnClick { $form.Close() }
        $form.Add_Shown({ $okBtn.Focus(); $sound.Play() })
    }
    $form.ShowDialog() | Out-Null
    if ($ClickUrl -and $script:dialogResult) {
        Start-Process $ClickUrl
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
function Close-BalloonTip {
    param($Icon)
    if ($Icon) {
        $Icon.Visible = $false
        $Icon.Dispose()
    }
}
function Get-JsonParseErrorMessage {
    param(
        [string]$Body,
        [int]$StatusCode,
        [string]$ContentType
    )
    $snippet = $Body
    if ($snippet) { $snippet = $snippet.Trim() }
    if ([string]::IsNullOrWhiteSpace($snippet)) {
        $snippet = '(empty response body)'
    } elseif ($snippet.Length -gt 300) {
        $snippet = $snippet.Substring(0, 300) + '...'
    }
    $statusPart = if ($StatusCode -gt 0) { "HTTP $StatusCode" } else { 'unknown status' }
    $typePart   = if ($ContentType) { $ContentType } else { 'unknown content type' }
    return "VirusTotal returned a non-JSON response ($statusPart, $typePart). This usually means a proxy, firewall, or security product intercepted the request. Response: $snippet"
}
function ConvertFrom-JsonSafe {
    param(
        [string]$Body,
        [int]$StatusCode,
        [string]$ContentType
    )
    if ([string]::IsNullOrWhiteSpace($Body)) {
        throw (Get-JsonParseErrorMessage -Body $Body -StatusCode $StatusCode -ContentType $ContentType)
    }
    try {
        return $Body | ConvertFrom-Json
    }
    catch {
        throw (Get-JsonParseErrorMessage -Body $Body -StatusCode $StatusCode -ContentType $ContentType)
    }
}
function Get-VTErrorDetail {
    param(
        [string]$Body
    )
    if ([string]::IsNullOrWhiteSpace($Body)) {
        return $null
    }
    try {
        $errorJson = $Body | ConvertFrom-Json
    }
    catch {
        return $null
    }
    if ($errorJson.error -and $errorJson.error.message) {
        return [string]$errorJson.error.message
    }
    return $null
}
function Invoke-VTRequest {
    param(
        [string]$Uri,
        [hashtable]$Headers,
        [string]$Method = 'Get',
        [int]$MaxRetries = 6
    )
    $attempt = 0
    while ($true) {
        try {
            $webResponse = Invoke-WebRequest -Uri $Uri -Headers $Headers -Method $Method -UseBasicParsing -TimeoutSec 120
            $statusCode  = [int]$webResponse.StatusCode
            $contentType = $webResponse.Headers['Content-Type']
            if ($contentType -is [array]) { $contentType = $contentType -join ';' }
            if ($contentType -notmatch 'json') {
                if ($attempt -lt $MaxRetries) {
                    $attempt++
                    Start-Sleep -Seconds ([Math]::Min(15, 3 * $attempt))
                    continue
                }
                throw (Get-JsonParseErrorMessage -Body $webResponse.Content -StatusCode $statusCode -ContentType $contentType)
            }
            return ConvertFrom-JsonSafe -Body $webResponse.Content -StatusCode $statusCode -ContentType $contentType
        }
        catch {
            $statusCode  = $null
            $rawBody     = $null
            $contentType = $null
            $errorResponse = $_.Exception.Response
            if ($errorResponse) {
                try { $statusCode = [int]$errorResponse.StatusCode } catch {}
                if ($errorResponse.PSObject.Methods['GetResponseStream']) {
                    try { $contentType = $errorResponse.Headers['Content-Type'] } catch {}
                    try {
                        $errStream = $errorResponse.GetResponseStream()
                        $reader    = New-Object System.IO.StreamReader($errStream)
                        $rawBody   = $reader.ReadToEnd()
                        $reader.Dispose()
                    } catch {}
                }
                else {
                    try { $contentType = $errorResponse.Content.Headers.ContentType.ToString() } catch {}
                    try { $rawBody = $_.ErrorDetails.Message } catch {}
                    if (-not $rawBody) {
                        try { $rawBody = $errorResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult() } catch {}
                    }
                }
            }

            if ($statusCode -eq 429 -and $attempt -lt $MaxRetries) {
                $attempt++
                $waitSeconds = 20
                try {
                    $retryAfterValue = $errorResponse.Headers['Retry-After']
                    if ($retryAfterValue) { $waitSeconds = [Math]::Max(5, [int]$retryAfterValue) }
                } catch {}

                $balloon = Show-BalloonTip -Title 'VirusTotal' `
                    -Text "Hit VirusTotal's API rate limit. Retrying automatically in $waitSeconds seconds..." `
                    -DurationMs 6000
                Start-Sleep -Seconds $waitSeconds
                Close-BalloonTip -Icon $balloon
                continue
            }

            if ($statusCode -eq 429) {
                throw "VirusTotal API rate limit exceeded (too many requests). Please wait a few minutes and try again."
            }

            if ($statusCode -ge 500 -and $attempt -lt $MaxRetries) {
                $attempt++
                Start-Sleep -Seconds ([Math]::Min(30, 5 * $attempt))
                continue
            }

            if ($statusCode -eq 404) {
                throw
            }

            if ($statusCode) {
                $errorDetail = Get-VTErrorDetail -Body $rawBody
                if ($errorDetail) {
                    throw "VirusTotal request failed (HTTP $statusCode): $errorDetail"
                }
                throw (Get-JsonParseErrorMessage -Body $rawBody -StatusCode $statusCode -ContentType $contentType)
            }
            throw
        }
    }
}
function Send-VTFileUpload {
    param(
        [string]$Uri,
        [string]$ApiKey,
        [string]$FilePath,
        [int]$MaxRetries = 3
    )
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $attempt  = 0
    while ($true) {
        $client = [System.Net.Http.HttpClient]::new()
        $client.Timeout = [TimeSpan]::FromMinutes(10)
        $client.DefaultRequestHeaders.ExpectContinue = $false
        $client.DefaultRequestHeaders.Add('x-apikey', $ApiKey)

        $multipart   = [System.Net.Http.MultipartFormDataContent]::new()
        $stream      = [System.IO.File]::OpenRead($FilePath)
        $fileContent = [System.Net.Http.StreamContent]::new($stream)
        $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/octet-stream')
        $multipart.Add($fileContent, 'file', $fileName)
        try {
            $response    = $client.PostAsync($Uri, $multipart).GetAwaiter().GetResult()
            $body        = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $statusCode  = [int]$response.StatusCode
            $contentType = $null
            if ($response.Content.Headers.ContentType) { $contentType = $response.Content.Headers.ContentType.ToString() }

            $looksLikeJson = $body -and ($body.TrimStart().StartsWith('{') -or $body.TrimStart().StartsWith('['))
            $isTransient   = ($statusCode -ge 500) -or [string]::IsNullOrWhiteSpace($body)
            if (-not $response.IsSuccessStatusCode -or -not $looksLikeJson) {
                if ($isTransient -and $attempt -lt $MaxRetries) {
                    $attempt++
                    Start-Sleep -Seconds ([Math]::Min(20, 5 * $attempt))
                    continue
                }
                if (-not $looksLikeJson) {
                    throw (Get-JsonParseErrorMessage -Body $body -StatusCode $statusCode -ContentType $contentType)
                }
                $errorDetail = Get-VTErrorDetail -Body $body
                if ($errorDetail) {
                    throw "Upload failed (HTTP $statusCode): $errorDetail"
                }
                throw "Upload failed with status $statusCode."
            }

            $json = ConvertFrom-JsonSafe -Body $body -StatusCode $statusCode -ContentType $contentType
            if ($json.error) {
                throw "Upload failed: $($json.error.message)"
            }
            return $json
        }
        finally {
            $multipart.Dispose()
            $client.Dispose()
        }
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
        $urlResp = Invoke-VTRequest -Uri 'https://www.virustotal.com/api/v3/files/upload_url' -Headers $headers
        $uploadUri = $urlResp.data
    }
    $resp = Send-VTFileUpload -Uri $uploadUri -ApiKey $ApiKey -FilePath $FilePath
    return $resp.data.id
}
function Wait-VTAnalysis {
    param(
        [string]$AnalysisId,
        [string]$ApiKey,
        [int]$TimeoutSeconds = 300,
        [int]$PollIntervalSeconds = 20
    )
    $headers   = @{ 'x-apikey' = $ApiKey }
    $uri       = "https://www.virustotal.com/api/v3/analyses/$AnalysisId"
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $balloon   = $null
    while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $resp = Invoke-VTRequest -Uri $uri -Headers $headers
        if ($resp.data.attributes.status -eq 'completed') {
            Close-BalloonTip -Icon $balloon
            return $resp
        }

        $elapsedSeconds = [int]$stopwatch.Elapsed.TotalSeconds
        Close-BalloonTip -Icon $balloon
        $balloon = Show-BalloonTip -Title 'VirusTotal' `
            -Text "Still scanning on VirusTotal's servers... ($elapsedSeconds sec elapsed)`nThis depends on VT's engines, not your connection." `
            -DurationMs 6000

        Start-Sleep -Seconds $PollIntervalSeconds
    }
    Close-BalloonTip -Icon $balloon
    throw "The scan timed out after $([int]$stopwatch.Elapsed.TotalSeconds) seconds. VirusTotal is still analyzing the file; please check the report page again in a few minutes."
}
function Get-VTScanCounts {
    param(
        $Stats
    )
    $total = ($Stats.PSObject.Properties | Measure-Object -Property Value -Sum).Sum
    return @{
        Detections = [int]$Stats.malicious + [int]$Stats.suspicious
        Total      = [int]$total
    }
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
}
catch {
    Show-Notification -Title "VirusTotal Check" -Text $_.Exception.Message -Level Error
    exit 1
}
try {
    $hash = (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash
}
catch {
    Show-Notification -Title "VirusTotal Check" -Text "Could not compute hash:`n$($_.Exception.Message)" -Level Error
    exit 1
}

$headers = @{ 'x-apikey' = $apiKey }
try {
    $response = Invoke-VTRequest -Uri "https://www.virustotal.com/api/v3/files/$hash" -Headers $headers
    $counts   = Get-VTScanCounts -Stats $response.data.attributes.last_analysis_stats
    Show-VTVerdict -Detections $counts.Detections -Total $counts.Total -Hash $hash
}
catch {
    if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
        $balloon = $null
        try {
            $balloon = Show-BalloonTip -Title 'VirusTotal' `
                -Text "File not found in the VirusTotal database.`nUploading now, please wait..."
            $analysisId = Submit-FileToVT -FilePath $FilePath -ApiKey $apiKey
            Close-BalloonTip -Icon $balloon
            $balloon = $null

            $analysisResult = Wait-VTAnalysis -AnalysisId $analysisId -ApiKey $apiKey
            $counts = Get-VTScanCounts -Stats $analysisResult.data.attributes.stats
            Show-VTVerdict -Detections $counts.Detections -Total $counts.Total -Hash $hash
        }
        catch {
            Close-BalloonTip -Icon $balloon
            Show-Notification -Title "Upload/Scan Failed" `
                -Text "The file could not be uploaded or scanned automatically:`n$($_.Exception.Message)`n`nYou can try uploading it manually instead." `
                -Level Error -ButtonText 'Close'
        }
    }
    else {
        Show-Notification -Title "Error" -Text "Connection error:`n$($_.Exception.Message)" -Level Error
    }
}
