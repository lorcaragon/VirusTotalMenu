param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath
)
$ErrorActionPreference = 'Stop'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::Expect100Continue = $false
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
        $viewBtn.Cursor      = [System.Windows.Forms.Cursors]::Hand
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
        $closeBtn.Cursor      = [System.Windows.Forms.Cursors]::Hand
        $closeBtn.BackColor   = [System.Drawing.Color]::White
        $closeBtn.ForeColor   = [System.Drawing.Color]::FromArgb(90, 90, 90)
        $closeBtn.Add_Click({ $form.Close() })
        $form.Controls.Add($closeBtn)
        $form.Add_Shown({ $viewBtn.Focus(); $sound.Play() })
        $form.ShowDialog() | Out-Null
        if ($script:dialogResult) {
            Start-Process $ClickUrl
        }
    }
    else {
        $okBtn               = New-Object System.Windows.Forms.Button
        $okBtn.Text           = $ButtonText
        $okBtn.Size           = New-Object System.Drawing.Size((Scale 90), (Scale 34))
        $okBtn.Location       = New-Object System.Drawing.Point((Scale 322), $buttonTop)
        $okBtn.FlatStyle      = 'Flat'
        $okBtn.FlatAppearance.BorderSize = 0
        $okBtn.Cursor         = [System.Windows.Forms.Cursors]::Hand
        $okBtn.BackColor      = $accentColor
        $okBtn.ForeColor      = [System.Drawing.Color]::White
        $okBtn.Font           = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
        $okBtn.Add_Click({ $form.Close() })
        $form.Controls.Add($okBtn)
        $form.Add_Shown({ $okBtn.Focus(); $sound.Play() })
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
function Get-JsonParseErrorMessage {
    param(
        [string]$Body,
        [Nullable[int]]$StatusCode,
        [string]$ContentType
    )
    $snippet = $Body
    if ($snippet) { $snippet = $snippet.Trim() }
    if ([string]::IsNullOrWhiteSpace($snippet)) {
        $snippet = '(empty response body)'
    } elseif ($snippet.Length -gt 300) {
        $snippet = $snippet.Substring(0, 300) + '...'
    }
    $statusPart = if ($StatusCode) { "HTTP $StatusCode" } else { 'unknown status' }
    $typePart   = if ($ContentType) { $ContentType } else { 'unknown content type' }
    return "VirusTotal returned a non-JSON response ($statusPart, $typePart). This usually means a proxy, firewall, or security product intercepted the request. Response: $snippet"
}
function ConvertFrom-JsonSafe {
    param(
        [string]$Body,
        [Nullable[int]]$StatusCode,
        [string]$ContentType
    )
    if ([string]::IsNullOrWhiteSpace($Body)) {
        throw (Get-JsonParseErrorMessage -Body $Body -StatusCode $StatusCode -ContentType $ContentType)
    }
    try {
        return $Body | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw (Get-JsonParseErrorMessage -Body $Body -StatusCode $StatusCode -ContentType $ContentType)
    }
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
            $webResponse = Invoke-WebRequest -Uri $Uri -Headers $Headers -Method $Method -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
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
            if ($_.Exception.Response) {
                try { $statusCode = [int]$_.Exception.Response.StatusCode } catch {}
                try { $contentType = $_.Exception.Response.Headers['Content-Type'] } catch {}
                try {
                    $errStream = $_.Exception.Response.GetResponseStream()
                    $reader    = New-Object System.IO.StreamReader($errStream)
                    $rawBody   = $reader.ReadToEnd()
                    $reader.Dispose()
                } catch {}
            }

            if ($statusCode -eq 429 -and $attempt -lt $MaxRetries) {
                $attempt++
                $waitSeconds = 20
                try {
                    $retryAfterValue = $_.Exception.Response.Headers['Retry-After']
                    if ($retryAfterValue) { $waitSeconds = [Math]::Max(5, [int]$retryAfterValue) }
                } catch {}

                $balloon = Show-BalloonTip -Title 'VirusTotal' `
                    -Text "Hit VirusTotal's API rate limit. Retrying automatically in $waitSeconds seconds..." `
                    -DurationMs 6000
                Start-Sleep -Seconds $waitSeconds
                if ($balloon) { $balloon.Visible = $false; $balloon.Dispose() }
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
                $errorJson = $null
                if ($rawBody) {
                    try { $errorJson = $rawBody | ConvertFrom-Json -ErrorAction Stop } catch {}
                }
                if ($errorJson -and $errorJson.error -and $errorJson.error.message) {
                    throw "VirusTotal request failed (HTTP $statusCode): $($errorJson.error.message)"
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
    Add-Type -AssemblyName System.Net.Http

    $fileName  = [System.IO.Path]::GetFileName($FilePath)
    $boundary  = [Guid]::NewGuid().ToString('N')
    $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)

    $preambleText = "--$boundary`r`nContent-Disposition: form-data; name=`"file`"; filename=`"$fileName`"`r`nContent-Type: application/octet-stream`r`n`r`n"
    $epilogueText = "`r`n--$boundary--`r`n"
    $preambleBytes = [System.Text.Encoding]::ASCII.GetBytes($preambleText)
    $epilogueBytes = [System.Text.Encoding]::ASCII.GetBytes($epilogueText)

    $bodyBytes = New-Object byte[] ($preambleBytes.Length + $fileBytes.Length + $epilogueBytes.Length)
    [System.Buffer]::BlockCopy($preambleBytes, 0, $bodyBytes, 0, $preambleBytes.Length)
    [System.Buffer]::BlockCopy($fileBytes, 0, $bodyBytes, $preambleBytes.Length, $fileBytes.Length)
    [System.Buffer]::BlockCopy($epilogueBytes, 0, $bodyBytes, ($preambleBytes.Length + $fileBytes.Length), $epilogueBytes.Length)

    $attempt = 0
    while ($true) {
        $client  = [System.Net.Http.HttpClient]::new()
        $client.Timeout = [TimeSpan]::FromMinutes(10)
        $client.DefaultRequestHeaders.ExpectContinue = $false
        $content = [System.Net.Http.ByteArrayContent]::new($bodyBytes)
        $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("multipart/form-data; boundary=`"$boundary`"")
        try {
            $client.DefaultRequestHeaders.Add('x-apikey', $ApiKey)

            $response    = $client.PostAsync($Uri, $content).GetAwaiter().GetResult()
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
                $errorJson = $null
                try { $errorJson = $body | ConvertFrom-Json -ErrorAction Stop } catch {}
                if ($errorJson -and $errorJson.error -and $errorJson.error.message) {
                    throw "Upload failed (HTTP $statusCode): $($errorJson.error.message)"
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
            $content.Dispose()
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
        $resp   = Invoke-VTRequest -Uri $uri -Headers $headers
        $status = $resp.data.attributes.status
        if ($status -eq 'completed') {
            if ($balloon) { $balloon.Visible = $false; $balloon.Dispose() }
            return $resp
        }

        $elapsedSeconds = [int]$stopwatch.Elapsed.TotalSeconds
        if ($balloon) { $balloon.Visible = $false; $balloon.Dispose() }
        $balloon = Show-BalloonTip -Title 'VirusTotal' `
            -Text "Still scanning on VirusTotal's servers... ($elapsedSeconds sec elapsed)`nThis depends on VT's engines, not your connection." `
            -DurationMs 6000

        Start-Sleep -Seconds $PollIntervalSeconds
    }
    if ($balloon) { $balloon.Visible = $false; $balloon.Dispose() }
    throw "The scan timed out after $([int]$stopwatch.Elapsed.TotalSeconds) seconds. VirusTotal is still analyzing the file; please check the report page again in a few minutes."
}
function Show-VTVerdict {
    param(
        [int]$Detections,
        [int]$Total,
        [string]$Hash
    )
    $reportUrl = "https://www.virustotal.com/gui/file/$Hash"
    switch ($true) {
        { $Detections -ge 25 } {
            Show-Notification -Title "High Risk Detected" `
                -Text "$Detections out of $Total engines flagged this file as malicious. Do not open or run it. Review the full report before proceeding." `
                -Level Error -ClickUrl $reportUrl
            break
        }
        { $Detections -ge 12 } {
            Show-Notification -Title "Flagged by Several Engines" `
                -Text "$Detections out of $Total engines flagged this file. Reviewing the report before opening it is recommended." `
                -Level Warning -ClickUrl $reportUrl
            break
        }
        { $Detections -ge 4 } {
            Show-Notification -Title "A Few Engines Flagged This File" `
                -Text "$Detections out of $Total engines flagged this file. This is common with packed or obfuscated software and is often a false positive, but you can check the report if you want details." `
                -Level Info -ClickUrl $reportUrl
            break
        }
        { $Detections -gt 0 } {
            Show-Notification -Title "Likely False Positive" `
                -Text "Only $Detections out of $Total engines flagged this file, which is typically an isolated false positive rather than an actual threat." `
                -Level Ok -ClickUrl $reportUrl
            break
        }
        default {
            Show-Notification -Title "Clean File" `
                -Text "No engines flagged this file. All $Total engines reported it as clean." `
                -Level Ok -ClickUrl $reportUrl
        }
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
    $response = Invoke-VTRequest -Uri "https://www.virustotal.com/api/v3/files/$hash" -Headers $headers
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
                -Level Error -ButtonText 'Close'
        }
    }
    else {
        Show-Notification -Title "Error" -Text "Connection error:`n$($_.Exception.Message)" -Level Error
    }
}
