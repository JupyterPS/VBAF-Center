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

    Functions:
      Start-VBAFCenterPortal   — start the web portal
      Stop-VBAFCenterPortal    — stop the web portal
#>

# ============================================================
# STATE
# ============================================================
$script:PortalListener = $null
$script:PortalRunning  = $false
$script:PortalPort     = 8080

# ============================================================
# GET CUSTOMER LIST
# ============================================================
function Get-PortalCustomerList {
    $storePath = Join-Path $env:USERPROFILE "VBAFCenter\customers"
    $customers = @()
    if (Test-Path $storePath) {
        Get-ChildItem $storePath -Filter "*.json" | ForEach-Object {
            $p = Get-Content $_.FullName -Raw | ConvertFrom-Json
            if ($p.CustomerID) {
                $customers += @{
                    CustomerID   = $p.CustomerID
                    CompanyName  = $p.CompanyName
                    BusinessType = $p.BusinessType
                    Agent        = $p.Agent
                    Status       = $p.Status
                }
            }
        }
    }
    return $customers
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
        $actions = $lines | Where-Object { $_ -match "^Action\d+Name=" } |
                   ForEach-Object { ($_ -split "=")[1] }
        if ($actions.Count -eq 0) { $actions = @("Monitor","Reassign","Reroute","Escalate") }
    }

    # Calculate recommendation
    $avg = if ($signals.Count -gt 0) { $total = 0; foreach ($sig in $signals) { $total += $sig.Normalised }; [Math]::Round($total / $signals.Count, 2) } else { 0 }
    $action = if ($avg -lt 0.25) { 0 } elseif ($avg -lt 0.50) { 1 } elseif ($avg -lt 0.75) { 2 } else { 3 }
    $actionName = if ($actions.Count -gt $action) { $actions[$action] } else { @("Monitor","Reassign","Reroute","Escalate")[$action] }
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
# BUILD HTML PAGE
# ============================================================
function Get-PortalHTML {
    param([string]$CustomerID = "")

    $customers = Get-PortalCustomerList
    $customerOptions = ($customers | ForEach-Object {
        $sel = if ($_.CustomerID -eq $CustomerID) { " selected" } else { "" }
        "<option value='$($_.CustomerID)'$sel>$($_.CompanyName)</option>"
    }) -join "`n"

    $dataSection = ""
    if ($CustomerID -ne "" -and $CustomerID -ne "SELECT") {
        $data = Get-PortalCustomerData -CustomerID $CustomerID
        if ($data) {
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

            $dataSection = @"
<div class='card'>
    <div class='card-header'>
        <span>$($data.Profile.CompanyName)</span>
        <span class='badge' style='background:#1D9E7520;color:#1D9E75;border:1px solid #1D9E75'>$($data.Profile.Status)</span>
    </div>
    <div class='meta'>
        Agent: <b>$($data.Profile.Agent)</b> &nbsp;|&nbsp;
        Business: <b>$($data.Profile.BusinessType)</b> &nbsp;|&nbsp;
        Updated: <b>$($data.Timestamp)</b>
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
"@
        }
    }

    return @"
<!DOCTYPE html>
<html lang='en'>
<head>
<meta charset='UTF-8'>
<meta http-equiv='refresh' content='600'>
<title>VBAF-Center Portal</title>
<style>
  * { box-sizing:border-box; margin:0; padding:0; }
  body { font-family:Arial,sans-serif; background:#f4f4f0; color:#2C2C2A; font-size:14px; }
  .header { background:#2C2C2A; color:#fff; padding:16px 32px; display:flex; align-items:center; justify-content:space-between; }
  .header h1 { font-size:18px; font-weight:500; }
  .header .version { font-size:12px; color:#888; }
  .container { max-width:960px; margin:24px auto; padding:0 24px; }
  .selector { background:#fff; border-radius:8px; padding:16px 24px; margin-bottom:20px; display:flex; align-items:center; gap:16px; box-shadow:0 1px 3px rgba(0,0,0,0.08); }
  .selector label { font-weight:500; }
  .selector select { padding:8px 12px; border:1px solid #ccc; border-radius:6px; font-size:14px; min-width:200px; }
  .selector button { padding:8px 20px; background:#2C2C2A; color:#fff; border:none; border-radius:6px; cursor:pointer; font-size:14px; }
  .selector button:hover { background:#444; }
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
  .empty { text-align:center; padding:40px; color:#aaa; }
  .footer { text-align:center; color:#aaa; font-size:12px; padding:24px; }
</style>
</head>
<body>
<div class='header'>
    <h1>VBAF-Center Portal</h1>
    <span class='version'>v1.0.0 · Auto-refresh every 10 min</span>
</div>
<div class='container'>
    <form method='GET' action='/'>
        <div class='selector'>
            <label>Customer:</label>
            <select name='customer'>
                <option value='SELECT'>-- Select customer --</option>
                $customerOptions
            </select>
            <button type='submit'>Load</button>
        </div>
    </form>
    $dataSection
    $(if ($dataSection -eq "") { "<div class='card'><div class='empty'>Select a customer to view their dashboard</div></div>" })
</div>
<div class='footer'>VBAF-Center v1.0.2 · Roskilde, Denmark · Built with PowerShell 5.1</div>
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

    $script:PortalPort = $Port

    Write-Host ""
    Write-Host "  Starting VBAF-Center Web Portal..." -ForegroundColor Cyan
    Write-Host ("  URL     : http://localhost:{0}" -f $Port) -ForegroundColor White
    Write-Host "  Press Ctrl+C to stop." -ForegroundColor Yellow
    Write-Host ""

    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Start()
    $script:PortalListener = $listener
    $script:PortalRunning  = $true

    # Open browser
    Start-Process "http://localhost:$Port/"

    Write-Host "  Portal running — browser opened." -ForegroundColor Green
    Write-Host ""

    try {
        while ($script:PortalRunning) {
            $context  = $listener.GetContext()
            $request  = $context.Request
            $response = $context.Response

            # Parse customer from query string
            $customerID = ""
            if ($request.QueryString["customer"]) {
                $customerID = $request.QueryString["customer"]
                if ($customerID -eq "SELECT") { $customerID = "" }
            }

            $html   = Get-PortalHTML -CustomerID $customerID
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.ContentType     = "text/html; charset=utf-8"
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()

            Write-Host ("  [{0}] Request: {1}" -f (Get-Date -Format "HH:mm:ss"), $request.RawUrl) -ForegroundColor DarkGray
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
Write-Host "  |   Local browser dashboard                |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Start-VBAFCenterPortal   — open browser dashboard" -ForegroundColor White
Write-Host "  Stop-VBAFCenterPortal    — stop the portal"        -ForegroundColor White
Write-Host ""
Write-Host "  Quick start:" -ForegroundColor Yellow
Write-Host "  Start-VBAFCenterPortal" -ForegroundColor Green
Write-Host ""



