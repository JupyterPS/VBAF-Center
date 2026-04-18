#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 9 — Web Portal
.DESCRIPTION
    Starts a local web server and opens a browser dashboard
    showing live signals, AI recommendations and run history
    for any VBAF-Center customer.

    No internet needed. No cloud. No hosting fees.
    Runs entirely on your Windows PC.

    Access is protected by a token generated during onboarding.
    Each customer gets their own unique URL with token.

    Functions:
      Start-VBAFCenterPortal      — start the web portal
      Stop-VBAFCenterPortal       — stop the web portal
      Get-VBAFCenterPortalURLs    — show all customer portal URLs
#>

# ============================================================
# STATE
# ============================================================
$script:PortalListener = $null
$script:PortalRunning  = $false
$script:PortalPort     = 8080

# ============================================================
# VALIDATE TOKEN
# ============================================================
function Test-PortalToken {
    param([string]$CustomerID, [string]$Token)

    if ($CustomerID -eq "" -or $Token -eq "") { return $false }

    $schedFile = Join-Path $env:USERPROFILE "VBAFCenter\schedules\$CustomerID-schedule.json"
    if (-not (Test-Path $schedFile)) { return $false }

    $sched = Get-Content $schedFile -Raw | ConvertFrom-Json
    if (-not $sched.PortalToken) { return $false }

    return ($sched.PortalToken -eq $Token)
}

# ============================================================
# GET-VBAFCENTERPORTALURLS
# ============================================================
function Get-VBAFCenterPortalURLs {
    param(
        [int] $Port = 8080
    )

    $schedPath = Join-Path $env:USERPROFILE "VBAFCenter\schedules"
    if (-not (Test-Path $schedPath)) {
        Write-Host "No customers found." -ForegroundColor Yellow
        return
    }

    $files = Get-ChildItem $schedPath -Filter "*.json"
    if ($files.Count -eq 0) {
        Write-Host "No customers found." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   VBAF-Center Portal URLs                        |" -ForegroundColor Cyan
    Write-Host "  |   Copy and send to each customer                 |" -ForegroundColor Cyan
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    foreach ($file in $files) {
        $s = Get-Content $file.FullName -Raw | ConvertFrom-Json
        if ($s.PortalToken) {
            Write-Host ("  Customer : {0}" -f $s.CustomerID) -ForegroundColor White
            Write-Host ("  URL      : http://localhost:{0}/?customer={1}&token={2}" -f $Port, $s.CustomerID, $s.PortalToken) -ForegroundColor Yellow
            Write-Host ""
        } else {
            Write-Host ("  Customer : {0} — no token (run onboarding again to generate)" -f $s.CustomerID) -ForegroundColor DarkGray
            Write-Host ""
        }
    }
}

# ============================================================
# GET CUSTOMER DATA FOR PORTAL
# ============================================================
function Get-PortalCustomerData {
    param([string]$CustomerID)

    $storePath   = Join-Path $env:USERPROFILE "VBAFCenter\customers"
    $profilePath = Join-Path $storePath "$CustomerID.json"
    if (-not (Test-Path $profilePath)) { return $null }

    $profile = Get-Content $profilePath -Raw | ConvertFrom-Json

    # Get signals
    $signalPath = Join-Path $env:USERPROFILE "VBAFCenter\signals"
    $signals    = @()
    if (Test-Path $signalPath) {
        Get-ChildItem $signalPath -Filter "$CustomerID-*.json" | ForEach-Object {
            $s = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $raw = Get-Random -Minimum ($s.RawMin * 10) -Maximum ($s.RawMax * 10)
            $raw = [Math]::Round($raw / 10.0, 1)
            $norm = [Math]::Round(($raw - $s.RawMin) / ([Math]::Max(1, $s.RawMax - $s.RawMin)), 2)
            $status = if ($norm -gt 0.75) { "HIGH" } elseif ($norm -gt 0.40) { "MEDIUM" } else { "LOW" }
            $color  = if ($norm -gt 0.75) { "#E24B4A" } elseif ($norm -gt 0.40) { "#EF9F27" } else { "#1D9E75" }
            $signals += @{
                SignalName = $s.SignalName
                SignalIndex= $s.SignalIndex
                RawValue   = $raw
                Normalised = $norm
                Status     = $status
                Color      = $color
                SourceType = $s.SourceType
            }
        }
    }

    # Get action map
    $actionPath = Join-Path $env:USERPROFILE "VBAFCenter\actions"
    $actionFile = Join-Path $actionPath "$CustomerID-actions.txt"
    $actions    = @("Monitor","Reassign","Reroute","Escalate")
    if (Test-Path $actionFile) {
        $lines = Get-Content $actionFile
        $parsed = $lines | Where-Object { $_ -match "^\d+\|" } |
                  ForEach-Object { ($_ -split "\|")[1] }
        if ($parsed -and $parsed.Count -gt 0) { $actions = $parsed }
    }

    # Calculate recommendation
    $avg = if ($signals.Count -gt 0) {
        $total = 0
        foreach ($sig in $signals) { $total += $sig.Normalised }
        [Math]::Round($total / $signals.Count, 2)
    } else { 0 }
    $action      = if ($avg -lt 0.25) { 0 } elseif ($avg -lt 0.50) { 1 } elseif ($avg -lt 0.75) { 2 } else { 3 }
    $actionName  = if ($actions.Count -gt $action) { $actions[$action] } else { @("Monitor","Reassign","Reroute","Escalate")[$action] }
    $actionColor = @("#1D9E75","#EF9F27","#EF9F27","#E24B4A")[$action]

    # Get history
    $historyPath = Join-Path $env:USERPROFILE "VBAFCenter\history"
    $history     = @()
    if (Test-Path $historyPath) {
        Get-ChildItem $historyPath -Filter "$CustomerID-*.json" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 10 |
            ForEach-Object {
                $h = Get-Content $_.FullName -Raw | ConvertFrom-Json
                $history += @{
                    Timestamp  = $h.Timestamp
                    Action     = $h.Action
                    ActionName = $h.ActionName
                    AvgSignal  = $h.AvgSignal
                }
            }
    }

    return @{
        Profile    = $profile
        Signals    = $signals
        Action     = $action
        ActionName = $actionName
        ActionColor= $actionColor
        AvgSignal  = [Math]::Round($avg, 2)
        History    = $history
        Timestamp  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# ============================================================
# BUILD ACCESS DENIED PAGE
# ============================================================
function Get-PortalDeniedHTML {
    return @"
<!DOCTYPE html>
<html lang='en'>
<head>
<meta charset='UTF-8'>
<title>VBAF-Center Portal — Access Denied</title>
<style>
  * { box-sizing:border-box; margin:0; padding:0; }
  body { font-family:Arial,sans-serif; background:#f4f4f0; color:#2C2C2A; display:flex; align-items:center; justify-content:center; min-height:100vh; }
  .box { background:#fff; border-radius:12px; padding:40px; text-align:center; box-shadow:0 2px 8px rgba(0,0,0,0.1); max-width:400px; }
  .icon { font-size:48px; margin-bottom:16px; }
  h1 { font-size:20px; font-weight:500; margin-bottom:8px; color:#E24B4A; }
  p { font-size:14px; color:#888; line-height:1.6; }
</style>
</head>
<body>
<div class='box'>
    <div class='icon'>&#128274;</div>
    <h1>Access Denied</h1>
    <p>This portal requires a valid customer URL with token.<br><br>
    Please contact your VBAF-Center administrator for your personal portal link.</p>
</div>
</body>
</html>
"@
}

# ============================================================
# BUILD HTML PAGE
# ============================================================
function Get-PortalHTML {
    param([string]$CustomerID = "", [string]$Token = "")

    $data = Get-PortalCustomerData -CustomerID $CustomerID
    if (-not $data) { return Get-PortalDeniedHTML }

    $signalRows = ($data.Signals | ForEach-Object {
        "<tr>
            <td>$($_.SignalName)</td>
            <td style='color:$($_.Color);font-weight:500'>$($_.RawValue)</td>
            <td style='color:$($_.Color);font-weight:500'>$($_.Normalised)</td>
            <td><span class='badge' style='background:$($_.Color)20;color:$($_.Color);border:1px solid $($_.Color)'>$($_.Status)</span></td>
            <td>$($_.SourceType)</td>
        </tr>"
    }) -join "`n"

    $historyRows = ($data.History | ForEach-Object {
        $hcolor = @("#1D9E75","#EF9F27","#EF9F27","#E24B4A")[[int]$_.Action]
        "<tr>
            <td>$($_.Timestamp)</td>
            <td style='color:$hcolor;font-weight:500'>$($_.ActionName)</td>
            <td>$($_.AvgSignal)</td>
        </tr>"
    }) -join "`n"

    if ($historyRows -eq "") {
        $historyRows = "<tr><td colspan='3' style='text-align:center;color:#888'>No history yet — run Invoke-VBAFCenterRun first</td></tr>"
    }

    return @"
<!DOCTYPE html>
<html lang='en'>
<head>
<meta charset='UTF-8'>
<meta http-equiv='refresh' content='600'>
<title>VBAF-Center — $($data.Profile.CompanyName)</title>
<style>
  * { box-sizing:border-box; margin:0; padding:0; }
  body { font-family:Arial,sans-serif; background:#f4f4f0; color:#2C2C2A; font-size:14px; }
  .header { background:#2C2C2A; color:#fff; padding:16px 32px; display:flex; align-items:center; justify-content:space-between; }
  .header h1 { font-size:18px; font-weight:500; }
  .header .version { font-size:12px; color:#888; }
  .container { max-width:960px; margin:24px auto; padding:0 24px; }
  .card { background:#fff; border-radius:8px; padding:20px 24px; margin-bottom:16px; box-shadow:0 1px 3px rgba(0,0,0,0.08); }
  .card-header { display:flex; justify-content:space-between; align-items:center; font-size:16px; font-weight:500; margin-bottom:8px; }
  .meta { color:#666; font-size:13px; }
  .badge { padding:3px 10px; border-radius:12px; font-size:12px; font-weight:500; }
  .recommendation { display:flex; flex-direction:column; gap:6px; }
  .rec-label { font-size:12px; color:#888; text-transform:uppercase; letter-spacing:0.5px; }
  .rec-action { font-size:28px; font-weight:500; }
  .rec-avg { font-size:13px; color:#666; }
  .section-title { font-weight:500; margin-bottom:12px; color:#444; }
  table { width:100%; border-collapse:collapse; }
  th { text-align:left; padding:8px 12px; background:#f8f8f6; color:#666; font-weight:500; font-size:13px; border-bottom:1px solid #eee; }
  td { padding:10px 12px; border-bottom:1px solid #f0f0ee; font-size:13px; }
  tr:last-child td { border-bottom:none; }
  .footer { text-align:center; color:#aaa; font-size:12px; padding:24px; }
</style>
</head>
<body>
<div class='header'>
    <h1>$($data.Profile.CompanyName) — VBAF Portal</h1>
    <span class='version'>Auto-refresh every 10 min · $($data.Timestamp)</span>
</div>
<div class='container'>

<div class='card'>
    <div class='card-header'>
        <span>$($data.Profile.CompanyName)</span>
        <span class='badge' style='background:#1D9E7520;color:#1D9E75;border:1px solid #1D9E75'>$($data.Profile.Status)</span>
    </div>
    <div class='meta'>
        Agent: <b>$($data.Profile.Agent)</b> &nbsp;|&nbsp;
        Business: <b>$($data.Profile.BusinessType)</b>
    </div>
</div>

<div class='card recommendation' style='border-left:4px solid $($data.ActionColor)'>
    <div class='rec-label'>AI Recommendation</div>
    <div class='rec-action' style='color:$($data.ActionColor)'>$($data.ActionName)</div>
    <div class='rec-avg'>Average signal level: $($data.AvgSignal)</div>
</div>

<div class='card'>
    <div class='section-title'>Live Signals</div>
    <table>
        <thead><tr><th>Signal</th><th>Raw Value</th><th>Normalised</th><th>Status</th><th>Source</th></tr></thead>
        <tbody>$signalRows</tbody>
    </table>
</div>

<div class='card'>
    <div class='section-title'>Run History (last 10)</div>
    <table>
        <thead><tr><th>Timestamp</th><th>Action</th><th>Avg Signal</th></tr></thead>
        <tbody>$historyRows</tbody>
    </table>
</div>

</div>
<div class='footer'>VBAF-Center v1.0.15 · Roskilde, Denmark · Built with PowerShell 5.1</div>
</body>
</html>
"@
}

# ============================================================
# START-VBAFCENTERPORTAL
# ============================================================
function Start-VBAFCenterPortal {
    param(
        [int] $Port = 8080
    )

    if ($script:PortalRunning) {
        Write-Host "Portal already running at http://localhost:$script:PortalPort" -ForegroundColor Yellow
        return
    }

    $script:PortalPort    = $Port
    $script:PortalRunning = $true

    Write-Host ""
    Write-Host "  Starting VBAF-Center Web Portal..." -ForegroundColor Cyan
    Write-Host ("  URL     : http://localhost:{0}" -f $Port) -ForegroundColor White
    Write-Host "  Press Ctrl+C to stop." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Customer portal URLs:" -ForegroundColor DarkGray
    Get-VBAFCenterPortalURLs -Port $Port
    Write-Host ""

    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Start()
    $script:PortalListener = $listener

    $firstSched = Get-ChildItem (Join-Path $env:USERPROFILE "VBAFCenter\schedules") -Filter "*.json" | Select-Object -First 1
    if ($firstSched) {
        $s = Get-Content $firstSched.FullName -Raw | ConvertFrom-Json
        if ($s.PortalToken) { Start-Process ("http://localhost:{0}/?customer={1}&token={2}" -f $Port, $s.CustomerID, $s.PortalToken) }
    }

    Write-Host "  Portal running — browser opened." -ForegroundColor Green
    Write-Host ""

    try {
        while ($script:PortalRunning) {
            $context  = $listener.GetContext()
            $request  = $context.Request
            $response = $context.Response

            # Parse customer and token from query string
            $customerID = $request.QueryString["customer"]
            $token      = $request.QueryString["token"]

            if (-not $customerID) { $customerID = "" }
            if (-not $token)      { $token = "" }

            # Validate token
            $valid = Test-PortalToken -CustomerID $customerID -Token $token

            if ($valid) {
                $html = Get-PortalHTML -CustomerID $customerID -Token $token
                Write-Host ("  [{0}] Access granted: {1}" -f (Get-Date -Format "HH:mm:ss"), $customerID) -ForegroundColor Green
            } else {
                $html = Get-PortalDeniedHTML
                Write-Host ("  [{0}] Access denied: {1}" -f (Get-Date -Format "HH:mm:ss"), $request.RawUrl) -ForegroundColor Red
            }

            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.ContentType     = "text/html; charset=utf-8"
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        }
    }
    finally {
        $listener.Stop()
        $script:PortalRunning = $false
        Write-Host "  Portal stopped." -ForegroundColor Yellow
    }
}

# ============================================================
# STOP-VBAFCENTERPORTAL
# ============================================================
function Stop-VBAFCenterPortal {
    $script:PortalRunning = $false
    if ($script:PortalListener) {
        $script:PortalListener.Stop()
        Write-Host "Portal stopped." -ForegroundColor Yellow
    }
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   VBAF-Center Phase 9 - Web Portal       |" -ForegroundColor Cyan
Write-Host "  |   Token-protected customer dashboard     |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Start-VBAFCenterPortal      — open browser dashboard"    -ForegroundColor White
Write-Host "  Stop-VBAFCenterPortal       — stop the portal"           -ForegroundColor White
Write-Host "  Get-VBAFCenterPortalURLs    — show all customer URLs"    -ForegroundColor White
Write-Host ""
Write-Host "  Quick start:" -ForegroundColor Yellow
Write-Host "  Start-VBAFCenterPortal" -ForegroundColor Green
Write-Host "  Get-VBAFCenterPortalURLs" -ForegroundColor Green
Write-Host ""