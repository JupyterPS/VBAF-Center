#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 11 — Multi-Customer Dashboard
.DESCRIPTION
    Your overview screen — ALL customers on one page.
    Green/yellow/red status at a glance.
    Shows last 10 runs per customer.
    Auto-refreshes every 10 minutes.

    Phase 14 — RED/YELLOW signal counts and OVERRIDE indicator per card
    Phase 15 — Weighted average shown in history rows

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

        $actionNames  = @("Monitor","Reassign","Reroute","Escalate")
        $actionColors = @("#1D9E75","#EF9F27","#EF6B27","#E24B4A")
        $bgColors     = @("#1D9E7512","#EF9F2712","#EF6B2712","#E24B4A12")
        $borderColors = @("#1D9E75","#EF9F27","#EF6B27","#E24B4A")

        # Signal count — read from config files (no random values)
        $signalPath  = Join-Path $env:USERPROFILE "VBAFCenter\signals"
        $signalCount = 0
        if (Test-Path $signalPath) {
            $signalCount = @(Get-ChildItem $signalPath -Filter "$($p.CustomerID)-*.json").Count
        }

        # --------------------------------------------------------
        # Read latest run from history — Phase 14/15 data
        # --------------------------------------------------------
        $historyPath     = Join-Path $env:USERPROFILE "VBAFCenter\history"
        $lastRun         = "Never"
        $trend           = "&#8594;"
        $trendColor      = "#888780"
        $action          = 0
        $avgSignal       = 0.0
        $weightedAvg     = $null
        $overrideApplied = $false
        $redCount        = 0
        $yellowCount     = 0
        $runHistory      = @()

        if (Test-Path $historyPath) {
            $runs = Get-ChildItem $historyPath -Filter "$($p.CustomerID)-*.json" |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 10

            if ($runs -and @($runs).Count -ge 1) {
                $latest      = Get-Content $runs[0].FullName -Raw | ConvertFrom-Json
                $lastRun     = $latest.Timestamp
                $action      = if ($null -ne $latest.Action) { [int]$latest.Action } else { 0 }
                $avgSignal   = if ($null -ne $latest.AvgSignal) { [double]$latest.AvgSignal } else { 0.0 }
                $weightedAvg = if ($null -ne $latest.WeightedAvg) { $latest.WeightedAvg } else { $null }
                $overrideApplied = if ($null -ne $latest.OverrideApplied) { [bool]$latest.OverrideApplied } else { $false }
                $redCount    = if ($null -ne $latest.RedSignalCount)    { [int]$latest.RedSignalCount    } else { 0 }
                $yellowCount = if ($null -ne $latest.YellowSignalCount) { [int]$latest.YellowSignalCount } else { 0 }
            }

            if ($runs -and @($runs).Count -ge 2) {
                $latestAction   = [int](Get-Content $runs[0].FullName -Raw | ConvertFrom-Json).Action
                $previousAction = [int](Get-Content $runs[1].FullName -Raw | ConvertFrom-Json).Action
                if ($latestAction -gt $previousAction)      { $trend = "&#8679;"; $trendColor = "#E24B4A" }
                elseif ($latestAction -lt $previousAction)  { $trend = "&#8681;"; $trendColor = "#1D9E75" }
            }

            foreach ($run in $runs) {
                $h = Get-Content $run.FullName -Raw | ConvertFrom-Json
                $runHistory += @{
                    Timestamp        = $h.Timestamp
                    Action           = if ($null -ne $h.Action) { [int]$h.Action } else { 0 }
                    ActionName       = $h.ActionName
                    AvgSignal        = $h.AvgSignal
                    WeightedAvg      = $h.WeightedAvg
                    OverrideApplied  = if ($null -ne $h.OverrideApplied) { [bool]$h.OverrideApplied } else { $false }
                    RedSignalCount   = if ($null -ne $h.RedSignalCount)  { [int]$h.RedSignalCount   } else { 0 }
                    YellowSignalCount= if ($null -ne $h.YellowSignalCount){ [int]$h.YellowSignalCount} else { 0 }
                }
            }
        }

        $customers += [PSCustomObject] @{
            CustomerID       = $p.CustomerID
            CompanyName      = if ($p.CompanyName) { $p.CompanyName } else { $p.CustomerID }
            BusinessType     = $p.BusinessType
            Agent            = $p.Agent
            Status           = $p.Status
            SignalCount      = $signalCount
            AvgSignal        = $avgSignal
            WeightedAvg      = $weightedAvg
            Action           = $action
            ActionName       = $actionNames[$action]
            ActionColor      = $actionColors[$action]
            BgColor          = $bgColors[$action]
            BorderColor      = $borderColors[$action]
            LastRun          = $lastRun
            Trend            = $trend
            TrendColor       = $trendColor
            OverrideApplied  = $overrideApplied
            RedSignalCount   = $redCount
            YellowSignalCount = $yellowCount
            RunHistory       = $runHistory
        }
    }

    return $customers
}

# ============================================================
# BUILD DASHBOARD HTML
# ============================================================
function Get-DashboardHTML {

    $customers = Get-DashboardData
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    $customerList  = @($customers)
    $total         = $customerList.Count
    $vbafAlerts    = @($customerList | Where-Object { [int]$_.Action -ge 2 }).Count
    $vbafHealthy   = @($customerList | Where-Object { [int]$_.Action -eq 0 }).Count
    $vbafAttention = @($customerList | Where-Object { [int]$_.Action -eq 1 }).Count
    $vbafOverrides = @($customerList | Where-Object { $_.OverrideApplied -eq $true }).Count

    $cards = ($customerList | ForEach-Object {
        $c = $_

        # --------------------------------------------------------
        # History rows — Phase 14/15 fields
        # --------------------------------------------------------
        $historyRows = ""
        if ($c.RunHistory -and $c.RunHistory.Count -gt 0) {
            foreach ($r in $c.RunHistory) {
                $rAction  = [int]$r.Action
                $rColor   = @("#1D9E75","#EF9F27","#EF6B27","#E24B4A")[$rAction]
                $rName    = @("Monitor","Reassign","Reroute","Escalate")[$rAction]
                $rOverride = if ($r.OverrideApplied) {
                    "<span style='color:#E24B4A;font-size:10px;margin-left:3px;'>&#9888;</span>"
                } else { "" }
                $rWAvg    = if ($null -ne $r.WeightedAvg) { $r.WeightedAvg.ToString("F2") } else { "—" }
                $rRed     = if ($r.RedSignalCount -gt 0) {
                    "<span style='color:#E24B4A;font-size:10px;'>&#9679;$($r.RedSignalCount)</span>"
                } else { "" }

                $historyRows += "<tr>
                    <td style='color:#888;font-size:11px'>$($r.Timestamp)</td>
                    <td style='color:$rColor;font-weight:500;font-size:11px'>$rName$rOverride</td>
                    <td style='color:#888;font-size:11px;text-align:right'>$($r.AvgSignal)</td>
                    <td style='color:#666;font-size:11px;text-align:right'>$rWAvg</td>
                    <td style='text-align:center'>$rRed</td>
                </tr>"
            }
        } else {
            $historyRows = "<tr><td colspan='5' style='color:#aaa;font-size:11px;text-align:center;padding:8px'>No history yet</td></tr>"
        }

        # --------------------------------------------------------
        # Signal badges — Red / Yellow counts
        # --------------------------------------------------------
        $signalBadges = ""
        if ($c.RedSignalCount -gt 0) {
            $signalBadges += "<span style='background:#E24B4A20;color:#E24B4A;border:1px solid #E24B4A40;border-radius:4px;padding:2px 6px;font-size:11px;margin-left:4px;'>&#9679; $($c.RedSignalCount) Red</span>"
        }
        if ($c.YellowSignalCount -gt 0) {
            $signalBadges += "<span style='background:#EF9F2720;color:#EF9F27;border:1px solid #EF9F2740;border-radius:4px;padding:2px 6px;font-size:11px;margin-left:4px;'>&#9679; $($c.YellowSignalCount) Watch</span>"
        }

        # --------------------------------------------------------
        # Override indicator on card
        # --------------------------------------------------------
        $overrideBadge = ""
        if ($c.OverrideApplied) {
            $overrideBadge = "<span style='background:#E24B4A20;color:#E24B4A;border:1px solid #E24B4A40;border-radius:4px;padding:2px 8px;font-size:11px;font-weight:500;'>&#9888; OVERRIDE</span>"
        }

        # --------------------------------------------------------
        # Weighted avg display
        # --------------------------------------------------------
        $avgDisplay = if ($null -ne $c.WeightedAvg) {
            "W:$($c.WeightedAvg) / S:$($c.AvgSignal)"
        } else {
            $c.AvgSignal.ToString()
        }

        # Signal bar uses weighted avg if available, else simple avg
        $barValue = if ($null -ne $c.WeightedAvg) { [double]$c.WeightedAvg } else { [double]$c.AvgSignal }
        $barPct   = [Math]::Min(100, [Math]::Round($barValue * 100))

        "<div class='customer-card' style='border-left:4px solid $($c.BorderColor)'>
            <div class='card-top'>
                <div class='company-name'>$($c.CompanyName)</div>
                <div style='display:flex;align-items:center;gap:6px'>
                    <span style='font-size:20px;color:$($c.TrendColor)'>$($c.Trend)</span>
                    <div class='action-badge' style='background:$($c.BgColor);color:$($c.ActionColor);border:1px solid $($c.BorderColor)40'>$($c.ActionName)</div>
                </div>
            </div>
            <div class='card-meta'>
                <span>$($c.BusinessType)</span>
                <span>$($c.Agent)</span>
                <span>$($c.SignalCount) signals</span>
                $overrideBadge
                $signalBadges
            </div>
            <div class='card-bottom'>
                <div class='signal-bar-wrap'>
                    <div class='signal-bar' style='width:$barPct%;background:$($c.ActionColor)'></div>
                </div>
                <div class='signal-value' style='color:$($c.ActionColor)'>$avgDisplay</div>
            </div>
            <div style='font-size:11px;color:#aaa;margin-bottom:8px;'>Last run: $($c.LastRun)</div>
            <div class='history-section'>
                <table class='history-table'>
                    <thead><tr>
                        <th>Time</th>
                        <th>Action</th>
                        <th style='text-align:right'>Avg</th>
                        <th style='text-align:right'>W.Avg</th>
                        <th style='text-align:center'>!</th>
                    </tr></thead>
                    <tbody>$historyRows</tbody>
                </table>
            </div>
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
  .summary { display:flex; gap:16px; padding:20px 32px; background:#fff; border-bottom:1px solid #eee; flex-wrap:wrap; }
  .summary-box { flex:1; min-width:120px; text-align:center; padding:12px; border-radius:8px; }
  .summary-box .num { font-size:32px; font-weight:500; }
  .summary-box .lbl { font-size:12px; color:#888; margin-top:4px; }
  .container { max-width:1200px; margin:24px auto; padding:0 24px; }
  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(360px,1fr)); gap:16px; }
  .customer-card { background:#fff; border-radius:8px; padding:20px; box-shadow:0 1px 3px rgba(0,0,0,0.08); }
  .card-top { display:flex; justify-content:space-between; align-items:center; margin-bottom:8px; }
  .company-name { font-size:16px; font-weight:500; }
  .action-badge { padding:4px 12px; border-radius:12px; font-size:12px; font-weight:500; }
  .card-meta { display:flex; flex-wrap:wrap; gap:8px; font-size:12px; color:#888; margin-bottom:10px; align-items:center; }
  .card-bottom { display:flex; align-items:center; gap:12px; margin-bottom:6px; }
  .signal-bar-wrap { flex:1; height:6px; background:#f0f0ee; border-radius:3px; overflow:hidden; }
  .signal-bar { height:100%; border-radius:3px; }
  .signal-value { font-size:12px; font-weight:500; min-width:80px; text-align:right; }
  .history-section { border-top:1px solid #f0f0ee; padding-top:8px; margin-top:6px; }
  .history-table { width:100%; border-collapse:collapse; }
  .history-table th { text-align:left; font-size:10px; color:#aaa; font-weight:500; padding:2px 4px; border-bottom:1px solid #f0f0ee; }
  .history-table td { padding:3px 4px; border-bottom:1px solid #f8f8f6; vertical-align:middle; }
  .history-table tr:last-child td { border-bottom:none; }
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
        <div class='num' style='color:#1D9E75'>$vbafHealthy</div>
        <div class='lbl'>Healthy</div>
    </div>
    <div class='summary-box' style='background:#EF9F2712'>
        <div class='num' style='color:#EF9F27'>$vbafAttention</div>
        <div class='lbl'>Attention</div>
    </div>
    <div class='summary-box' style='background:#E24B4A12'>
        <div class='num' style='color:#E24B4A'>$vbafAlerts</div>
        <div class='lbl'>Alerts</div>
    </div>
    <div class='summary-box' style='background:#E24B4A08'>
        <div class='num' style='color:#c03030'>$vbafOverrides</div>
        <div class='lbl'>Overrides</div>
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
<div class='footer'>VBAF-Center v1.1.0 · Phase 14/15 active · Roskilde, Denmark · Built with PowerShell 5.1</div>
</body>
</html>
"@
}

# ============================================================
# START-VBAFCENTERDASHBOARD
# ============================================================
function Start-VBAFCenterDashboard {
    param([int] $Port = 8081)

    if ($script:DashboardRunning) {
        Write-Host "Dashboard already running at http://localhost:$script:DashboardPort" -ForegroundColor Yellow
        return
    }

    $script:DashboardPort    = $Port
    $script:DashboardRunning = $true

    Write-Host ""
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   VBAF-Center Multi-Customer Dashboard   |" -ForegroundColor Cyan
    Write-Host "  |   Phase 14/15 — overrides + weights      |" -ForegroundColor Cyan
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host ("  URL : http://localhost:{0}" -f $Port) -ForegroundColor White
    Write-Host "  Press Ctrl+C to stop." -ForegroundColor Yellow
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
            $response.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
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
Write-Host "  |  VBAF-Center Phase 11 — Dashboard        |" -ForegroundColor Cyan
Write-Host "  |  All customers — one screen              |" -ForegroundColor Cyan
Write-Host "  |  Phase 14/15: overrides + weights active |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Start-VBAFCenterDashboard  — open all-customer overview" -ForegroundColor White
Write-Host "  Stop-VBAFCenterDashboard   — stop the dashboard"         -ForegroundColor White
Write-Host ""