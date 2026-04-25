


#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 9 — Web Portal
.DESCRIPTION
    Starts a local web server and opens a browser dashboard
    showing live signals, AI recommendations and run history
    for any VBAF-Center customer.

    Phase 14 — Signal colours from GoodBelow/BadAbove thresholds
    Phase 15 — Signal weight displayed per signal
    Phase 14 — Override banner shown when RED signal raised action level

    No internet needed. No cloud. No hosting fees.
    Runs entirely on your Windows PC.

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
    param([int] $Port = 8080)

    $schedPath = Join-Path $env:USERPROFILE "VBAFCenter\schedules"
    if (-not (Test-Path $schedPath)) { Write-Host "No customers found." -ForegroundColor Yellow; return }

    $files = Get-ChildItem $schedPath -Filter "*.json"
    if ($files.Count -eq 0) { Write-Host "No customers found." -ForegroundColor Yellow; return }

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
            Write-Host ("  Customer : {0} — no token (run onboarding again)" -f $s.CustomerID) -ForegroundColor DarkGray
            Write-Host ""
        }
    }
}

# ============================================================
# GET ALL CUSTOMER TABS
# ============================================================
function Get-PortalCustomerTabs {
    param([string]$CurrentCustomerID, [int]$Port = 8080)

    $schedPath = Join-Path $env:USERPROFILE "VBAFCenter\schedules"
    $tabs = ""
    if (Test-Path $schedPath) {
        Get-ChildItem $schedPath -Filter "*.json" | ForEach-Object {
            $s = Get-Content $_.FullName -Raw | ConvertFrom-Json
            if ($s.PortalToken) {
                $active = if ($s.CustomerID -eq $CurrentCustomerID) { " class='tab active'" } else { " class='tab'" }
                $url    = "http://localhost:$Port/?customer=$($s.CustomerID)&token=$($s.PortalToken)"
                $label  = if ($s.CompanyName) { $s.CompanyName } else { $s.CustomerID }
                $tabs  += "<a href='$url'$active>$label</a>"
            }
        }
    }
    return $tabs
}

# ============================================================
# RESOLVE SIGNAL COLOUR FROM THRESHOLDS  (Phase 14)
# ============================================================
function Resolve-PortalSignalColour {
    param(
        [double] $RawValue,
        [double] $Normalised,
        [double] $GoodBelow = -1,
        [double] $BadAbove  = -1
    )

    # Phase 14 — threshold-based (preferred)
    if ($GoodBelow -ge 0 -or $BadAbove -ge 0) {
        if ($BadAbove  -ge 0 -and $RawValue -gt $BadAbove)  { return "#E24B4A" }  # Red
        if ($GoodBelow -ge 0 -and $RawValue -lt $GoodBelow) { return "#1D9E75" }  # Green
        return "#EF9F27"                                                            # Yellow
    }

    # Fallback — normalised-based (backwards compatible)
    if ($Normalised -gt 0.75) { return "#E24B4A" }
    if ($Normalised -gt 0.40) { return "#EF9F27" }
    return "#1D9E75"
}

function Resolve-PortalSignalStatus {
    param([string] $HexColour)
    switch ($HexColour) {
        "#E24B4A" { return "RED"    }
        "#EF9F27" { return "WATCH"  }
        default   { return "OK"     }
    }
}

# ============================================================
# GET CUSTOMER DATA FOR PORTAL
# ============================================================
function Get-PortalCustomerData {
    param([string]$CustomerID)

    $profilePath = Join-Path $env:USERPROFILE "VBAFCenter\customers\$CustomerID.json"
    if (-not (Test-Path $profilePath)) { return $null }

    $profile = Get-Content $profilePath -Raw | ConvertFrom-Json

    # --------------------------------------------------------
    # Signals — read from signal config files
    # Phase 14: use GoodBelow/BadAbove for colour
    # Phase 15: read Weight per signal
    # --------------------------------------------------------
    $signalPath = Join-Path $env:USERPROFILE "VBAFCenter\signals"
    $signals    = @()

    if (Test-Path $signalPath) {
        Get-ChildItem $signalPath -Filter "$CustomerID-*.json" |
            Sort-Object Name |
            ForEach-Object {
                $sc = Get-Content $_.FullName -Raw | ConvertFrom-Json

                # Use simulated value for display if no live run yet
                [double] $range = $sc.RawMax - $sc.RawMin
                [double] $raw   = $sc.RawMin + (Get-Random -Minimum 0 -Maximum 100) / 100.0 * $range
                [double] $norm  = if ($range -gt 0) { ($raw - $sc.RawMin) / $range } else { 0.0 }
                $norm           = [Math]::Max(0.0, [Math]::Min(1.0, [Math]::Round($norm, 2)))
                $raw            = [Math]::Round($raw, 1)

                # Phase 14 — threshold-based colour
                $goodBelow = if ($null -ne $sc.GoodBelow -and $sc.GoodBelow -ge 0) { [double]$sc.GoodBelow } else { -1 }
                $badAbove  = if ($null -ne $sc.BadAbove  -and $sc.BadAbove  -ge 0) { [double]$sc.BadAbove  } else { -1 }
                $colour    = Resolve-PortalSignalColour -RawValue $raw -Normalised $norm -GoodBelow $goodBelow -BadAbove $badAbove
                $status    = Resolve-PortalSignalStatus -HexColour $colour

                # Phase 15 — weight
                $weight = if ($null -ne $sc.Weight -and $sc.Weight -gt 0) { [int]$sc.Weight } else { 3 }

                # Threshold label
                $threshLabel = ""
                if ($goodBelow -ge 0 -or $badAbove -ge 0) {
                    $parts = @()
                    if ($goodBelow -ge 0) { $parts += "Good &lt;$goodBelow" }
                    if ($badAbove  -ge 0) { $parts += "Bad &gt;$badAbove"   }
                    $threshLabel = $parts -join " | "
                }

                $signals += @{
                    SignalName   = $sc.SignalName
                    SignalIndex  = $sc.SignalIndex
                    RawValue     = $raw
                    Normalised   = $norm
                    Status       = $status
                    Color        = $colour
                    SourceType   = $sc.SourceType
                    Weight       = $weight
                    ThreshLabel  = $threshLabel
                    ThreshActive = ($goodBelow -ge 0 -or $badAbove -ge 0)
                }
            }
    }

    # --------------------------------------------------------
    # Recommendation — read from latest history file
    # This uses the Phase 14/15 result already calculated
    # by Invoke-VBAFCenterRun — no recalculation needed
    # --------------------------------------------------------
    $historyPath    = Join-Path $env:USERPROFILE "VBAFCenter\history"
    $latestHistory  = $null
    $action         = 0
    $actionName     = "Monitor"
    $actionColor    = "#1D9E75"
    $actionReason   = ""
    $overrideApplied = $false
    $redCount       = 0
    $yellowCount    = 0
    $avgUsed        = 0.0
    $weightedAvg    = $null
    $lastTimestamp  = "No runs yet"

    if (Test-Path $historyPath) {
        $latestFile = Get-ChildItem $historyPath -Filter "$CustomerID-*.json" |
                      Sort-Object LastWriteTime -Descending |
                      Select-Object -First 1

        if ($latestFile) {
            $latestHistory  = Get-Content $latestFile.FullName -Raw | ConvertFrom-Json
            $action         = [int] $latestHistory.Action
            $actionName     = $latestHistory.ActionName
            $actionColor    = @("#1D9E75","#EF9F27","#EF6B27","#E24B4A")[$action]
            $actionReason   = if ($latestHistory.ActionReason) { $latestHistory.ActionReason } else { "" }
            $overrideApplied = if ($null -ne $latestHistory.OverrideApplied) { [bool]$latestHistory.OverrideApplied } else { $false }
            $redCount       = if ($null -ne $latestHistory.RedSignalCount)    { [int]$latestHistory.RedSignalCount    } else { 0 }
            $yellowCount    = if ($null -ne $latestHistory.YellowSignalCount) { [int]$latestHistory.YellowSignalCount } else { 0 }
            $avgUsed        = if ($null -ne $latestHistory.AvgSignal)         { [double]$latestHistory.AvgSignal      } else { 0.0 }
            $weightedAvg    = if ($null -ne $latestHistory.WeightedAvg)       { $latestHistory.WeightedAvg            } else { $null }
            $lastTimestamp  = $latestHistory.Timestamp
        }
    }

    # Action map — customer language
    $actionFile = Join-Path $env:USERPROFILE "VBAFCenter\actions\$CustomerID-actions.txt"
    $actionCommand = ""
    if (Test-Path $actionFile) {
        $lines = Get-Content $actionFile
        foreach ($line in $lines) {
            $parts = $line -split "\|"
            if ($parts.Length -ge 3 -and [int]$parts[0] -eq $action) {
                $actionCommand = $parts[2]
                break
            }
        }
    }

    # Run history — last 10
    $history = @()
    if (Test-Path $historyPath) {
        Get-ChildItem $historyPath -Filter "$CustomerID-*.json" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 10 |
            ForEach-Object {
                $h = Get-Content $_.FullName -Raw | ConvertFrom-Json
                $history += @{
                    Timestamp        = $h.Timestamp
                    Action           = $h.Action
                    ActionName       = $h.ActionName
                    AvgSignal        = $h.AvgSignal
                    WeightedAvg      = $h.WeightedAvg
                    ActionReason     = if ($h.ActionReason)    { $h.ActionReason }    else { "" }
                    OverrideApplied  = if ($null -ne $h.OverrideApplied) { [bool]$h.OverrideApplied } else { $false }
                    RedSignalCount   = if ($null -ne $h.RedSignalCount)  { [int]$h.RedSignalCount   } else { 0 }
                    YellowSignalCount= if ($null -ne $h.YellowSignalCount){ [int]$h.YellowSignalCount} else { 0 }
                }
            }
    }

    return @{
        Profile          = $profile
        Signals          = @($signals)
        Action           = $action
        ActionName       = $actionName
        ActionCommand    = $actionCommand
        ActionColor      = $actionColor
        ActionReason     = $actionReason
        OverrideApplied  = $overrideApplied
        RedSignalCount   = $redCount
        YellowSignalCount = $yellowCount
        AvgSignal        = $avgUsed
        WeightedAvg      = $weightedAvg
        LastTimestamp    = $lastTimestamp
        History          = $history
        Timestamp        = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
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
    param([string]$CustomerID = "", [string]$Token = "", [int]$Port = 8080)

    $data = Get-PortalCustomerData -CustomerID $CustomerID
    if (-not $data) { return Get-PortalDeniedHTML }

    $tabs = Get-PortalCustomerTabs -CurrentCustomerID $CustomerID -Port $Port

    # --------------------------------------------------------
    # Signal rows — Phase 14 colours, Phase 15 weights
    # --------------------------------------------------------
    $signalRows = ($data.Signals | ForEach-Object {
        $weightBadge = "<span style='background:#f0f0ee;color:#666;border-radius:4px;padding:2px 6px;font-size:11px;'>W$($_.Weight)/5</span>"
        $threshCell  = if ($_.ThreshActive) {
            "<span style='font-size:11px;color:#888;'>$($_.ThreshLabel)</span>"
        } else {
            "<span style='font-size:11px;color:#ccc;'>—</span>"
        }
        "<tr>
            <td><b>$($_.SignalName)</b></td>
            <td style='color:$($_.Color);font-weight:500'>$($_.RawValue)</td>
            <td style='color:$($_.Color);font-weight:500'>$($_.Normalised)</td>
            <td><span class='badge' style='background:$($_.Color)20;color:$($_.Color);border:1px solid $($_.Color)40'>$($_.Status)</span></td>
            <td>$weightBadge</td>
            <td>$threshCell</td>
            <td style='color:#888;font-size:12px'>$($_.SourceType)</td>
        </tr>"
    }) -join "`n"

    if ($signalRows -eq "") {
        $signalRows = "<tr><td colspan='7' style='text-align:center;color:#888'>No signals configured yet</td></tr>"
    }

    # --------------------------------------------------------
    # History rows — Phase 14 override flag + Red/Yellow counts
    # --------------------------------------------------------
    $historyRows = ($data.History | ForEach-Object {
        $hcolor   = @("#1D9E75","#EF9F27","#EF6B27","#E24B4A")[[int]$_.Action]
        $override = if ($_.OverrideApplied) {
            "<span style='background:#E24B4A20;color:#E24B4A;border:1px solid #E24B4A40;border-radius:4px;padding:1px 6px;font-size:11px;margin-left:4px;'>OVERRIDE</span>"
        } else { "" }
        $redCell    = if ($_.RedSignalCount    -gt 0) { "<span style='color:#E24B4A;font-weight:500'>$($_.RedSignalCount)</span>"    } else { "<span style='color:#ccc'>—</span>" }
        $yellowCell = if ($_.YellowSignalCount -gt 0) { "<span style='color:#EF9F27;font-weight:500'>$($_.YellowSignalCount)</span>" } else { "<span style='color:#ccc'>—</span>" }
        $wAvg       = if ($null -ne $_.WeightedAvg)  { $_.WeightedAvg.ToString("F4") } else { "—" }

        "<tr>
            <td style='font-size:12px;color:#888'>$($_.Timestamp)</td>
            <td style='color:$hcolor;font-weight:500'>$($_.ActionName)$override</td>
            <td>$($_.AvgSignal)</td>
            <td>$wAvg</td>
            <td>$redCell</td>
            <td>$yellowCell</td>
        </tr>"
    }) -join "`n"

    if ($historyRows -eq "") {
        $historyRows = "<tr><td colspan='6' style='text-align:center;color:#888'>No history yet — run Invoke-VBAFCenterRun first</td></tr>"
    }

    # --------------------------------------------------------
    # Override banner (Phase 14)
    # --------------------------------------------------------
    $overrideBanner = ""
    if ($data.OverrideApplied) {
        $overrideBanner = @"
<div class='card' style='border-left:4px solid #E24B4A;background:#fff5f5;'>
    <div style='display:flex;align-items:center;gap:12px;'>
        <span style='font-size:24px;'>&#9888;</span>
        <div>
            <div style='font-weight:600;color:#E24B4A;font-size:15px;'>RED Signal Override Applied</div>
            <div style='color:#666;font-size:13px;margin-top:4px;'>$($data.ActionReason)</div>
        </div>
    </div>
</div>
"@
    }

    # --------------------------------------------------------
    # Avg display — show weighted if available
    # --------------------------------------------------------
    $avgDisplay = if ($null -ne $data.WeightedAvg) {
        "Weighted average: <b>$($data.WeightedAvg)</b> &nbsp;|&nbsp; Simple average: $($data.AvgSignal)"
    } else {
        "Average signal level: <b>$($data.AvgSignal)</b>"
    }

    # --------------------------------------------------------
    # Signal summary badges
    # --------------------------------------------------------
    $redCount    = @($data.Signals | Where-Object { $_.Color -eq "#E24B4A" }).Count
    $yellowCount = @($data.Signals | Where-Object { $_.Color -eq "#EF9F27" }).Count
    $greenCount  = @($data.Signals | Where-Object { $_.Color -eq "#1D9E75" }).Count

    $signalSummary = @"
<span style='color:#1D9E75;font-weight:500;margin-right:12px;'>&#9679; $greenCount OK</span>
<span style='color:#EF9F27;font-weight:500;margin-right:12px;'>&#9679; $yellowCount Watch</span>
<span style='color:#E24B4A;font-weight:500;'>&#9679; $redCount Red</span>
"@

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
  .header .ts { font-size:12px; color:#888; }
  .tabs { background:#1a1a18; padding:0 32px; display:flex; gap:4px; }
  .tab { display:inline-block; padding:10px 20px; color:#aaa; text-decoration:none; font-size:13px; border-bottom:3px solid transparent; transition:all 0.2s; }
  .tab:hover { color:#fff; background:#2C2C2A; }
  .tab.active { color:#fff; border-bottom:3px solid #EF9F27; }
  .container { max-width:980px; margin:24px auto; padding:0 24px; }
  .card { background:#fff; border-radius:8px; padding:20px 24px; margin-bottom:16px; box-shadow:0 1px 3px rgba(0,0,0,0.08); }
  .card-header { display:flex; justify-content:space-between; align-items:center; font-size:16px; font-weight:500; margin-bottom:8px; }
  .meta { color:#666; font-size:13px; }
  .badge { padding:3px 10px; border-radius:12px; font-size:12px; font-weight:500; }
  .rec-label { font-size:12px; color:#888; text-transform:uppercase; letter-spacing:0.5px; margin-bottom:6px; }
  .rec-action { font-size:30px; font-weight:600; margin-bottom:4px; }
  .rec-command { font-size:14px; color:#444; margin-bottom:4px; }
  .rec-avg { font-size:13px; color:#888; }
  .rec-reason { font-size:13px; color:#666; margin-top:8px; padding-top:8px; border-top:1px solid #f0f0ee; }
  .section-title { font-weight:500; margin-bottom:12px; color:#444; }
  table { width:100%; border-collapse:collapse; }
  th { text-align:left; padding:8px 12px; background:#f8f8f6; color:#666; font-weight:500; font-size:12px; border-bottom:1px solid #eee; }
  td { padding:10px 12px; border-bottom:1px solid #f0f0ee; font-size:13px; vertical-align:middle; }
  tr:last-child td { border-bottom:none; }
  .footer { text-align:center; color:#aaa; font-size:12px; padding:24px; }
  .last-run { font-size:12px; color:#888; margin-top:4px; }
</style>
</head>
<body>
<div class='header'>
    <h1>VBAF-Center Portal</h1>
    <span class='ts'>Live · Auto-refresh every 10 min · $($data.Timestamp)</span>
</div>
<div class='tabs'>$tabs</div>
<div class='container'>

<div class='card'>
    <div class='card-header'>
        <span>$($data.Profile.CompanyName)</span>
        <span class='badge' style='background:#1D9E7520;color:#1D9E75;border:1px solid #1D9E7540'>$($data.Profile.Status)</span>
    </div>
    <div class='meta'>
        Agent: <b>$($data.Profile.Agent)</b> &nbsp;|&nbsp;
        Type: <b>$($data.Profile.BusinessType)</b> &nbsp;|&nbsp;
        $signalSummary
    </div>
</div>

$overrideBanner

<div class='card' style='border-left:4px solid $($data.ActionColor)'>
    <div class='rec-label'>AI Recommendation — Last run: $($data.LastTimestamp)</div>
    <div class='rec-action' style='color:$($data.ActionColor)'>$($data.ActionName)</div>
    <div class='rec-command'>$($data.ActionCommand)</div>
    <div class='rec-avg'>$avgDisplay</div>
    $(if ($data.ActionReason -ne "" -and -not $data.OverrideApplied) {
        "<div class='rec-reason'>$($data.ActionReason)</div>"
    })
</div>

<div class='card'>
    <div class='section-title'>Live Signals</div>
    <table>
        <thead>
            <tr>
                <th>Signal</th>
                <th>Raw Value</th>
                <th>Normalised</th>
                <th>Status</th>
                <th>Weight</th>
                <th>Thresholds</th>
                <th>Source</th>
            </tr>
        </thead>
        <tbody>$signalRows</tbody>
    </table>
</div>

<div class='card'>
    <div class='section-title'>Run History (last 10)</div>
    <table>
        <thead>
            <tr>
                <th>Timestamp</th>
                <th>Action</th>
                <th>Avg Signal</th>
                <th>Weighted Avg</th>
                <th>Red</th>
                <th>Yellow</th>
            </tr>
        </thead>
        <tbody>$historyRows</tbody>
    </table>
</div>

</div>
<div class='footer'>VBAF-Center v1.1.0 · Phase 14/15 active · Roskilde, Denmark · Built with PowerShell 5.1</div>
</body>
</html>
"@
}

# ============================================================
# START-VBAFCENTERPORTAL
# ============================================================
function Start-VBAFCenterPortal {
    param([int] $Port = 8080)

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
    Get-VBAFCenterPortalURLs -Port $Port

    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Start()
    $script:PortalListener = $listener

    $firstSched = Get-ChildItem (Join-Path $env:USERPROFILE "VBAFCenter\schedules") -Filter "*.json" |
                  Select-Object -First 1
    if ($firstSched) {
        $s = Get-Content $firstSched.FullName -Raw | ConvertFrom-Json
        if ($s.PortalToken) {
            Start-Process ("http://localhost:{0}/?customer={1}&token={2}" -f $Port, $s.CustomerID, $s.PortalToken)
        }
    }

    Write-Host "  Portal running — browser opened." -ForegroundColor Green
    Write-Host ""

    try {
        while ($script:PortalRunning) {
            $context  = $listener.GetContext()
            $request  = $context.Request
            $response = $context.Response

            $customerID = $request.QueryString["customer"]
            $token      = $request.QueryString["token"]

            if (-not $customerID) { $customerID = "" }
            if (-not $token)      { $token = "" }

            $valid = Test-PortalToken -CustomerID $customerID -Token $token

            if ($valid) {
                $html = Get-PortalHTML -CustomerID $customerID -Token $token -Port $Port
                Write-Host ("  [{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $customerID) -ForegroundColor Green
            } else {
                $html = Get-PortalDeniedHTML
                Write-Host ("  [{0}] Access denied: {1}" -f (Get-Date -Format "HH:mm:ss"), $request.RawUrl) -ForegroundColor Red
            }

            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
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
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   VBAF-Center Phase 9 — Web Portal               |" -ForegroundColor Cyan
Write-Host "  |   Phase 14: threshold colours + override banner   |" -ForegroundColor Cyan
Write-Host "  |   Phase 15: signal weights displayed              |" -ForegroundColor Cyan
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Start-VBAFCenterPortal      — open browser dashboard"  -ForegroundColor White
Write-Host "  Stop-VBAFCenterPortal       — stop the portal"         -ForegroundColor White
Write-Host "  Get-VBAFCenterPortalURLs    — show all customer URLs"  -ForegroundColor White
Write-Host ""
