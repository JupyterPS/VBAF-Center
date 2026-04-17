#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 11 — Multi-Customer Dashboard
.DESCRIPTION
    Your overview screen — ALL customers on one page.
    Green/yellow/red status at a glance.
    Auto-refreshes every 10 minutes.

    Functions:
      Start-VBAFCenterDashboard  — open multi-customer overview
      Stop-VBAFCenterDashboard   — stop the dashboard
#>

# ============================================================
# STATE
# ============================================================
$script:DashboardListener = $null
$script:DashboardRunning  = $false
$script:DashboardPort     = 8081

# ============================================================
# GET ALL CUSTOMERS WITH STATUS
# ============================================================
function Get-DashboardData {

    $storePath = Join-Path $env:USERPROFILE "VBAFCenter\customers"
    $customers = @()

    if (-not (Test-Path $storePath)) { return $customers }

    Get-ChildItem $storePath -Filter "*.json" | ForEach-Object {
        $p = Get-Content $_.FullName -Raw | ConvertFrom-Json
        if (-not $p.CustomerID) { return }

        # Get signals
        $signalPath = Join-Path $env:USERPROFILE "VBAFCenter\signals"
        $signals    = @()
        if (Test-Path $signalPath) {
            Get-ChildItem $signalPath -Filter "$($p.CustomerID)-*.json" | ForEach-Object {
                $s   = Get-Content $_.FullName -Raw | ConvertFrom-Json
                $raw = Get-Random -Minimum ($s.RawMin * 10) -Maximum ($s.RawMax * 10)
                $raw = [Math]::Round($raw / 10.0, 1)
                $norm = [Math]::Round(($raw - $s.RawMin) / ([Math]::Max(1, $s.RawMax - $s.RawMin)), 2)
                $signals += $norm
            }
        }

        $avg    = if ($signals.Count -gt 0) { [Math]::Round(($signals | Measure-Object -Average).Average, 2) } else { 0 }
        $action = if ($avg -lt 0.25) { 0 } elseif ($avg -lt 0.50) { 1 } elseif ($avg -lt 0.75) { 2 } else { 3 }
        $actionNames  = @("Monitor","Reassign","Reroute","Escalate")
        $actionColors = @("#1D9E75","#EF9F27","#BA7517","#E24B4A")
        $bgColors     = @("#1D9E7512","#EF9F2712","#BA751712","#E24B4A12")
        $borderColors = @("#1D9E75","#EF9F27","#BA7517","#E24B4A")

        # Last run
        $historyPath = Join-Path $env:USERPROFILE "VBAFCenter\history"
        $lastRun     = "Never"
        if (Test-Path $historyPath) {
            $last = Get-ChildItem $historyPath -Filter "$($p.CustomerID)-*.json" |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1
            if ($last) {
                $h = Get-Content $last.FullName -Raw | ConvertFrom-Json
                $lastRun = $h.Timestamp
            }
        }

        $customers += [PSCustomObject]@{
            CustomerID   = $p.CustomerID
            CompanyName  = $p.CompanyName
            BusinessType = $p.BusinessType
            Agent        = $p.Agent
            Status       = $p.Status
            Signals      = $signals.Count
            AvgSignal    = $avg
            Action       = $action
            ActionName   = $actionNames[$action]
            ActionColor  = $actionColors[$action]
            BgColor      = $bgColors[$action]
            BorderColor  = $borderColors[$action]
            LastRun      = $lastRun
        }
    }

    return $customers
}

# ============================================================
# BUILD DASHBOARD HTML
# ============================================================
function Get-DashboardHTML {

    $customers  = Get-DashboardData
    $timestamp  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    $customerList = @($customers)
    $total        = $customerList.Count
    $alerts       = ($customerList | Where-Object { $_.Action -ge 2 }).Count
    $healthy      = ($customerList | Where-Object { $_.Action -eq 0 }).Count
    $attention    = ($customerList | Where-Object { $_.Action -eq 1 }).Count

    $cards = ($customerList | ForEach-Object {
        $c = $_
        "<div class='customer-card' style='border-left:4px solid $($c.BorderColor)'>
            <div class='card-top'>
                <div class='company-name'>$($c.CompanyName)</div>
                <div class='action-badge' style='background:$($c.BgColor);color:$($c.ActionColor);border:1px solid $($c.BorderColor)'>$($c.ActionName)</div>
            </div>
            <div class='card-meta'>
                <span>$($c.BusinessType)</span>
                <span>Agent: $($c.Agent)</span>
                <span>Signals: $($c.Signals)</span>
            </div>
            <div class='card-bottom'>
                <div class='signal-bar-wrap'>
                    <div class='signal-bar' style='width:$([Math]::Min(100, $c.AvgSignal * 100))%;background:$($c.ActionColor)'></div>
                </div>
                <div class='signal-value' style='color:$($c.ActionColor)'>$($c.AvgSignal)</div>
            </div>
            <div class='last-run'>Last run: $($c.LastRun)</div>
        </div>"
    }) -join "`n"

    if ($cards -eq "") {
        $cards = "<div class='empty'>No customers found — run Start-VBAFCenterOnboarding to add one</div>"
    }

    return @"
<!DOCTYPE html>
<html lang='en'>
<head>
<meta charset='UTF-8'>
<meta http-equiv='refresh' content='600'>
<title>VBAF-Center — All Customers</title>
<style>
  * { box-sizing:border-box; margin:0; padding:0; }
  body { font-family:Arial,sans-serif; background:#f4f4f0; color:#2C2C2A; font-size:14px; }
  .header { background:#2C2C2A; color:#fff; padding:16px 32px; display:flex; align-items:center; justify-content:space-between; }
  .header h1 { font-size:18px; font-weight:500; }
  .header .ts { font-size:12px; color:#888; }
  .summary { display:flex; gap:16px; padding:20px 32px; background:#fff; border-bottom:1px solid #eee; }
  .summary-box { flex:1; text-align:center; padding:12px; border-radius:8px; }
  .summary-box .num { font-size:32px; font-weight:500; }
  .summary-box .lbl { font-size:12px; color:#888; margin-top:4px; }
  .container { max-width:1100px; margin:24px auto; padding:0 24px; }
  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(300px,1fr)); gap:16px; }
  .customer-card { background:#fff; border-radius:8px; padding:20px; box-shadow:0 1px 3px rgba(0,0,0,0.08); }
  .card-top { display:flex; justify-content:space-between; align-items:center; margin-bottom:10px; }
  .company-name { font-size:16px; font-weight:500; }
  .action-badge { padding:4px 12px; border-radius:12px; font-size:12px; font-weight:500; }
  .card-meta { display:flex; gap:12px; font-size:12px; color:#888; margin-bottom:12px; }
  .card-bottom { display:flex; align-items:center; gap:12px; margin-bottom:8px; }
  .signal-bar-wrap { flex:1; height:6px; background:#f0f0ee; border-radius:3px; overflow:hidden; }
  .signal-bar { height:100%; border-radius:3px; transition:width 0.3s; }
  .signal-value { font-size:13px; font-weight:500; min-width:32px; text-align:right; }
  .last-run { font-size:11px; color:#aaa; }
  .empty { text-align:center; padding:60px; color:#aaa; grid-column:1/-1; }
  .footer { text-align:center; color:#aaa; font-size:12px; padding:24px; }
  .refresh-btn { background:#444; color:#fff; border:none; padding:6px 14px; border-radius:6px; cursor:pointer; font-size:12px; }
  .refresh-btn:hover { background:#666; }
</style>
</head>
<body>
<div class='header'>
    <h1>VBAF-Center — All Customers</h1>
    <div style='display:flex;align-items:center;gap:16px'>
        <span class='ts'>Updated: $timestamp · Auto-refresh every 10 min</span>
        <button class='refresh-btn' onclick='location.reload()'>Refresh now</button>
    </div>
</div>
<div class='summary'>
    <div class='summary-box' style='background:#1D9E7512'>
        <div class='num' style='color:#1D9E75'>$healthy</div>
        <div class='lbl'>Healthy</div>
    </div>
    <div class='summary-box' style='background:#EF9F2712'>
        <div class='num' style='color:#EF9F27'>$attention</div>
        <div class='lbl'>Attention</div>
    </div>
    <div class='summary-box' style='background:#E24B4A12'>
        <div class='num' style='color:#E24B4A'>$alerts</div>
        <div class='lbl'>Alerts</div>
    </div>
    <div class='summary-box' style='background:#f4f4f0'>
        <div class='num' style='color:#2C2C2A'>$total</div>
        <div class='lbl'>Total Customers</div>
    </div>
</div>
<div class='container'>
    <div class='grid'>
        $cards
    </div>
</div>
<div class='footer'>VBAF-Center v1.0.2 · Roskilde, Denmark · Built with PowerShell 5.1</div>
</body>
</html>
"@
}

# ============================================================
# START-VBAFCENTERDASHBOARD
# ============================================================
function Start-VBAFCenterDashboard {
    param(
        [int] $Port = 8081
    )

    if ($script:DashboardRunning) {
        Write-Host "Dashboard already running at http://localhost:$script:DashboardPort" -ForegroundColor Yellow
        return
    }

    $script:DashboardPort    = $Port
    $script:DashboardRunning = $true

    Write-Host ""
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   VBAF-Center Multi-Customer Dashboard   |" -ForegroundColor Cyan
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host ("  URL : http://localhost:{0}" -f $Port)         -ForegroundColor White
    Write-Host "  Press Ctrl+C to stop."                         -ForegroundColor Yellow
    Write-Host ""

    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Start()
    $script:DashboardListener = $listener

    Start-Process "http://localhost:$Port/"
    Write-Host "  Dashboard running — browser opened." -ForegroundColor Green
    Write-Host ""

    try {
        while ($script:DashboardRunning) {
            $context  = $listener.GetContext()
            $response = $context.Response
            $html     = Get-DashboardHTML
            $buffer   = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.ContentType     = "text/html; charset=utf-8"
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
            Write-Host ("  [{0}] Dashboard served" -f (Get-Date -Format "HH:mm:ss")) -ForegroundColor DarkGray
        }
    }
    finally {
        $listener.Stop()
        $script:DashboardRunning = $false
        Write-Host "  Dashboard stopped." -ForegroundColor Yellow
    }
}

# ============================================================
# STOP-VBAFCENTERDASHBOARD
# ============================================================
function Stop-VBAFCenterDashboard {
    $script:DashboardRunning = $false
    if ($script:DashboardListener) {
        $script:DashboardListener.Stop()
        Write-Host "Dashboard stopped." -ForegroundColor Yellow
    }
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |  VBAF-Center Phase 11 - Dashboard        |" -ForegroundColor Cyan
Write-Host "  |  All customers — one screen              |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Start-VBAFCenterDashboard  — open all-customer overview" -ForegroundColor White
Write-Host "  Stop-VBAFCenterDashboard   — stop the dashboard"         -ForegroundColor White
Write-Host ""
Write-Host "  Quick start:" -ForegroundColor Yellow
Write-Host "  Start-VBAFCenterDashboard" -ForegroundColor Green
Write-Host ""
