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
    Phase 18 — Accept/Override buttons for write-back
    Phase 16 — Threshold suggestion Yes/No buttons
    Option C  — Daglig Briefing button opens in new tab

    Functions:
      Start-VBAFCenterPortal      — start the web portal
      Stop-VBAFCenterPortal       — stop the web portal
      Get-VBAFCenterPortalURLs    — show all customer portal URLs
#>

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
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    foreach ($file in $files) {
        $s = Get-Content $file.FullName -Raw | ConvertFrom-Json
        if ($s.PortalToken) {
            Write-Host ("  Customer : {0}" -f $s.CustomerID) -ForegroundColor White
            Write-Host ("  Portal   : http://localhost:{0}/?customer={1}&token={2}" -f $Port, $s.CustomerID, $s.PortalToken) -ForegroundColor Yellow
            Write-Host ("  Briefing : http://localhost:{0}/briefing?customer={1}&token={2}" -f $Port, $s.CustomerID, $s.PortalToken) -ForegroundColor Cyan
            Write-Host ""
        }
    }
}

# ============================================================
# CUSTOMER TABS
# ============================================================
function Get-PortalCustomerTabs {
    param([string]$CurrentCustomerID, [string]$CurrentToken, [int]$Port = 8080)
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
    # Daglig Briefing button — always in tabs bar, opens in new tab
    $briefingURL = "http://localhost:$Port/briefing?customer=$CurrentCustomerID&token=$CurrentToken"
    $tabs += "<a href='$briefingURL' target='_blank' class='tab-briefing'>&#128197; Daglig Briefing</a>"
    return $tabs
}

# ============================================================
# SIGNAL COLOUR
# ============================================================
function Resolve-PortalSignalColour {
    param([double]$RawValue, [double]$Normalised, [double]$GoodBelow = -1, [double]$BadAbove = -1)
    if ($GoodBelow -ge 0 -or $BadAbove -ge 0) {
        if ($BadAbove  -ge 0 -and $RawValue -gt $BadAbove)  { return "#E24B4A" }
        if ($GoodBelow -ge 0 -and $RawValue -lt $GoodBelow) { return "#1D9E75" }
        return "#EF9F27"
    }
    if ($Normalised -gt 0.75) { return "#E24B4A" }
    if ($Normalised -gt 0.40) { return "#EF9F27" }
    return "#1D9E75"
}

function Resolve-PortalSignalStatus {
    param([string]$HexColour)
    switch ($HexColour) { "#E24B4A" { return "RED" } "#EF9F27" { return "WATCH" } default { return "OK" } }
}

# ============================================================
# GET THRESHOLD SUGGESTION
# ============================================================
function Get-PortalThresholdSuggestion {
    param([string]$CustomerID)
    $suggPath    = Join-Path $env:USERPROFILE "VBAFCenter\suggestions\$CustomerID-suggestion.json"
    $dismissPath = Join-Path $env:USERPROFILE "VBAFCenter\suggestions\$CustomerID-dismissed.txt"
    if (-not (Test-Path $suggPath)) { return $null }
    if (Test-Path $dismissPath) {
        $dismissedDate = Get-Content $dismissPath -Raw
        if ($dismissedDate -and [DateTime]::Parse($dismissedDate.Trim()) -gt (Get-Date).AddDays(-7)) {
            return $null
        }
    }
    try { return Get-Content $suggPath -Raw | ConvertFrom-Json } catch { return $null }
}

# ============================================================
# SAVE THRESHOLD SUGGESTION
# ============================================================
function Save-VBAFCenterThresholdSuggestion {
    param(
        [string] $CustomerID,
        [double] $SuggestedAction1,
        [double] $SuggestedAction2,
        [double] $SuggestedAction3,
        [string] $Reason
    )
    $suggPath = Join-Path $env:USERPROFILE "VBAFCenter\suggestions"
    if (-not (Test-Path $suggPath)) { New-Item -ItemType Directory -Path $suggPath -Force | Out-Null }
    @{
        CustomerID       = $CustomerID
        SuggestedAction1 = $SuggestedAction1
        SuggestedAction2 = $SuggestedAction2
        SuggestedAction3 = $SuggestedAction3
        Reason           = $Reason
        CreatedAt        = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    } | ConvertTo-Json | Set-Content "$suggPath\$CustomerID-suggestion.json" -Encoding UTF8
    Write-Host ("Threshold suggestion saved for: {0}" -f $CustomerID) -ForegroundColor Green
}

# ============================================================
# SERVE DAILY BRIEFING
# ============================================================
function Get-PortalBriefingHTML {
    param([string]$CustomerID)
    $briefingPath = Join-Path $env:USERPROFILE "VBAFCenter\briefings\$CustomerID-latest.html"
    if (Test-Path $briefingPath) {
        return Get-Content $briefingPath -Raw -Encoding UTF8
    }
    # No briefing yet — return helpful page
    return @"
<!DOCTYPE html><html lang='da'><head><meta charset='UTF-8'>
<title>VBAF-Center — Daglig Briefing</title>
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:Arial,sans-serif;background:#f4f4f0;display:flex;align-items:center;justify-content:center;min-height:100vh}
  .box{background:#fff;border-radius:12px;padding:40px;text-align:center;max-width:480px;box-shadow:0 2px 8px rgba(0,0,0,0.1)}
  .icon{font-size:48px;margin-bottom:16px}
  h1{font-size:20px;color:#2C2C2A;margin-bottom:8px}
  p{font-size:14px;color:#888;line-height:1.7;margin-bottom:12px}
  code{background:#f4f4f0;padding:4px 8px;border-radius:4px;font-size:12px;color:#0B7EA3}
</style>
</head><body>
<div class='box'>
  <div class='icon'>&#128197;</div>
  <h1>Daglig Briefing</h1>
  <p>Ingen briefing er genereret endnu for <b>$CustomerID</b>.</p>
  <p>Kør denne kommando for at generere briefingen:</p>
  <p><code>Export-VBAFCenterDailyBriefing -CustomerID "$CustomerID" -RunAIFirst -OpenBrowser</code></p>
  <p style='color:#1D9E75;font-size:13px'>Briefingen genereres automatisk hver morgen kl. 07:00 når den daglige loop kører.</p>
</div>
</body></html>
"@
}

# ============================================================
# GET CUSTOMER DATA
# ============================================================
function Get-PortalCustomerData {
    param([string]$CustomerID)
    $profilePath = Join-Path $env:USERPROFILE "VBAFCenter\customers\$CustomerID.json"
    if (-not (Test-Path $profilePath)) { return $null }
    $profile = Get-Content $profilePath -Raw | ConvertFrom-Json

    $signalPath = Join-Path $env:USERPROFILE "VBAFCenter\signals"
    $signals    = @()
    if (Test-Path $signalPath) {
        Get-ChildItem $signalPath -Filter "$CustomerID-*.json" | Sort-Object Name | ForEach-Object {
            $sc        = Get-Content $_.FullName -Raw | ConvertFrom-Json
            [double]$range = $sc.RawMax - $sc.RawMin
            [double]$raw   = $sc.RawMin + (Get-Random -Minimum 0 -Maximum 100) / 100.0 * $range
            [double]$norm  = if ($range -gt 0) { ($raw - $sc.RawMin) / $range } else { 0.0 }
            $norm          = [Math]::Max(0.0, [Math]::Min(1.0, [Math]::Round($norm, 2)))
            $raw           = [Math]::Round($raw, 1)
            $goodBelow     = if ($null -ne $sc.GoodBelow -and $sc.GoodBelow -ge 0) { [double]$sc.GoodBelow } else { -1 }
            $badAbove      = if ($null -ne $sc.BadAbove  -and $sc.BadAbove  -ge 0) { [double]$sc.BadAbove  } else { -1 }
            $colour        = Resolve-PortalSignalColour -RawValue $raw -Normalised $norm -GoodBelow $goodBelow -BadAbove $badAbove
            $status        = Resolve-PortalSignalStatus -HexColour $colour
            $weight        = if ($null -ne $sc.Weight -and $sc.Weight -gt 0) { [int]$sc.Weight } else { 3 }
            $threshLabel   = ""
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

    $historyPath     = Join-Path $env:USERPROFILE "VBAFCenter\history"
    $action          = 0
    $actionName      = "Monitor"
    $actionColor     = "#1D9E75"
    $actionReason    = ""
    $overrideApplied = $false
    $redCount        = 0
    $yellowCount     = 0
    $avgUsed         = 0.0
    $weightedAvg     = $null
    $lastTimestamp   = "No runs yet"

    if (Test-Path $historyPath) {
        $latestFile = Get-ChildItem $historyPath -Filter "$CustomerID-*.json" |
                      Sort-Object Name -Descending | Select-Object -First 1
        if ($latestFile) {
            $h               = Get-Content $latestFile.FullName -Raw | ConvertFrom-Json
            $action          = [int]$h.Action
            $actionName      = $h.ActionName
            $actionColor     = @("#1D9E75","#EF9F27","#EF6B27","#E24B4A")[$action]
            $actionReason    = if ($h.ActionReason)    { $h.ActionReason }    else { "" }
            $overrideApplied = if ($null -ne $h.OverrideApplied) { [bool]$h.OverrideApplied } else { $false }
            $redCount        = if ($null -ne $h.RedSignalCount)    { [int]$h.RedSignalCount    } else { 0 }
            $yellowCount     = if ($null -ne $h.YellowSignalCount) { [int]$h.YellowSignalCount } else { 0 }
            $avgUsed         = if ($null -ne $h.AvgSignal)         { [double]$h.AvgSignal      } else { 0.0 }
            $weightedAvg     = if ($null -ne $h.WeightedAvg)       { $h.WeightedAvg            } else { $null }
            $lastTimestamp   = $h.Timestamp
        }
    }

    $actionFile    = Join-Path $env:USERPROFILE "VBAFCenter\actions\$CustomerID-actions.txt"
    $actionCommand = ""
    if (Test-Path $actionFile) {
        Get-Content $actionFile | ForEach-Object {
            $parts = $_ -split "\|"
            if ($parts.Length -ge 3 -and [int]$parts[0] -eq $action) { $actionCommand = $parts[2] }
        }
    }

    $history = @()
    if (Test-Path $historyPath) {
        Get-ChildItem $historyPath -Filter "$CustomerID-*.json" |
            Sort-Object Name -Descending | Select-Object -First 10 | ForEach-Object {
                $h = Get-Content $_.FullName -Raw | ConvertFrom-Json
                $history += @{
                    Timestamp         = $h.Timestamp
                    Action            = $h.Action
                    ActionName        = $h.ActionName
                    AvgSignal         = $h.AvgSignal
                    WeightedAvg       = $h.WeightedAvg
                    ActionReason      = if ($h.ActionReason)              { $h.ActionReason }              else { "" }
                    OverrideApplied   = if ($null -ne $h.OverrideApplied) { [bool]$h.OverrideApplied }     else { $false }
                    RedSignalCount    = if ($null -ne $h.RedSignalCount)   { [int]$h.RedSignalCount }       else { 0 }
                    YellowSignalCount = if ($null -ne $h.YellowSignalCount){ [int]$h.YellowSignalCount }    else { 0 }
                }
            }
    }

    $thresholds = $null
    $schedFile  = Join-Path $env:USERPROFILE "VBAFCenter\schedules\$CustomerID-schedule.json"
    if (Test-Path $schedFile) {
        $sched      = Get-Content $schedFile -Raw | ConvertFrom-Json
        $thresholds = @{
            Action1 = if ($sched.Action1Threshold) { $sched.Action1Threshold } else { 0.25 }
            Action2 = if ($sched.Action2Threshold) { $sched.Action2Threshold } else { 0.50 }
            Action3 = if ($sched.Action3Threshold) { $sched.Action3Threshold } else { 0.75 }
        }
    }

    return @{
        Profile           = $profile
        Signals           = @($signals)
        Action            = $action
        ActionName        = $actionName
        ActionCommand     = $actionCommand
        ActionColor       = $actionColor
        ActionReason      = $actionReason
        OverrideApplied   = $overrideApplied
        RedSignalCount    = $redCount
        YellowSignalCount = $yellowCount
        AvgSignal         = $avgUsed
        WeightedAvg       = $weightedAvg
        LastTimestamp     = $lastTimestamp
        History           = $history
        Thresholds        = $thresholds
        Timestamp         = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# ============================================================
# HANDLE POST
# ============================================================
function Invoke-PortalPostAction {
    param([string]$CustomerID, [string]$PostBody, [int]$Port)

    $params = @{}
    $PostBody -split "&" | ForEach-Object {
        $kv = $_ -split "="
        if ($kv.Length -ge 2) {
            $params[$kv[0]] = [System.Uri]::UnescapeDataString($kv[1])
        }
    }

    $postAction = $params["postaction"]

    switch ($postAction) {
        "accept" {
            Write-Host ("  [PORTAL] Accept clicked — CustomerID: {0}" -f $CustomerID) -ForegroundColor Green
            if (Get-Command Invoke-VBAFCenterWriteBack -ErrorAction SilentlyContinue) {
                $actionNum = [int]$params["action"]
                Invoke-VBAFCenterWriteBack -CustomerID $CustomerID -Action $actionNum -Note "Dispatcher accepted via portal"
                Write-Host ("  [PORTAL] Write-back fired: Action {0}" -f $actionNum) -ForegroundColor Green
            } else {
                Write-Host "  [PORTAL] WriteBack module not loaded." -ForegroundColor Yellow
            }
        }
        "override" {
            Write-Host ("  [PORTAL] Override clicked — CustomerID: {0}" -f $CustomerID) -ForegroundColor Yellow
            $vbafAction = [int]$params["vbafaction"]
            $dispAction = [int]$params["dispaction"]
            $reason     = $params["reason"]
            if (-not $reason) { $reason = "No reason given" }
            if (Get-Command Start-VBAFCenterOverride -ErrorAction SilentlyContinue) {
                Start-VBAFCenterOverride -CustomerID $CustomerID -VBAFAction $vbafAction -DispatcherAction $dispAction -Reason $reason
                Write-Host ("  [PORTAL] Override logged: VBAF={0} Dispatcher={1}" -f $vbafAction, $dispAction) -ForegroundColor Yellow
            }
        }
        "apply-threshold" {
            Write-Host ("  [PORTAL] Threshold apply clicked — CustomerID: {0}" -f $CustomerID) -ForegroundColor Cyan
            $a1 = [double]$params["a1"]
            $a2 = [double]$params["a2"]
            $a3 = [double]$params["a3"]
            if (Get-Command Set-VBAFCenterActionThresholds -ErrorAction SilentlyContinue) {
                Set-VBAFCenterActionThresholds -CustomerID $CustomerID -Action1 $a1 -Action2 $a2 -Action3 $a3
            }
            $suggFile = Join-Path $env:USERPROFILE "VBAFCenter\suggestions\$CustomerID-suggestion.json"
            if (Test-Path $suggFile) { Remove-Item $suggFile -Force }
        }
        "dismiss-threshold" {
            Write-Host ("  [PORTAL] Threshold dismissed — CustomerID: {0}" -f $CustomerID) -ForegroundColor DarkGray
            $dismissPath = Join-Path $env:USERPROFILE "VBAFCenter\suggestions"
            if (-not (Test-Path $dismissPath)) { New-Item -ItemType Directory -Path $dismissPath -Force | Out-Null }
            (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") | Set-Content "$dismissPath\$CustomerID-dismissed.txt" -Encoding UTF8
        }
    }
}

# ============================================================
# ACCESS DENIED PAGE
# ============================================================
function Get-PortalDeniedHTML {
    return @"
<!DOCTYPE html><html lang='da'><head><meta charset='UTF-8'>
<title>VBAF-Center — Access Denied</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:Arial,sans-serif;background:#f4f4f0;display:flex;align-items:center;justify-content:center;min-height:100vh}.box{background:#fff;border-radius:12px;padding:40px;text-align:center;max-width:400px}.icon{font-size:48px;margin-bottom:16px}h1{font-size:20px;color:#E24B4A;margin-bottom:8px}p{font-size:14px;color:#888;line-height:1.6}</style>
</head><body><div class='box'><div class='icon'>&#128274;</div><h1>Access Denied</h1><p>This portal requires a valid customer URL with token.<br><br>Contact your VBAF-Center administrator.</p></div></body></html>
"@
}

# ============================================================
# BUILD PORTAL HTML
# ============================================================
function Get-PortalHTML {
    param([string]$CustomerID = "", [string]$Token = "", [int]$Port = 8080, [string]$Message = "")

    $data = Get-PortalCustomerData -CustomerID $CustomerID
    if (-not $data) { return Get-PortalDeniedHTML }

    $tabs       = Get-PortalCustomerTabs -CurrentCustomerID $CustomerID -CurrentToken $Token -Port $Port
    $suggestion = Get-PortalThresholdSuggestion -CustomerID $CustomerID
    $baseURL    = "http://localhost:$Port/?customer=$CustomerID&token=$Token"

    # Signal rows
    $signalRows = ($data.Signals | ForEach-Object {
        $wb = "<span style='background:#f0f0ee;color:#666;border-radius:4px;padding:2px 6px;font-size:11px;'>W$($_.Weight)/5</span>"
        $tc = if ($_.ThreshActive) { "<span style='font-size:11px;color:#888;'>$($_.ThreshLabel)</span>" } else { "<span style='color:#ccc;'>—</span>" }
        "<tr>
          <td><b>$($_.SignalName)</b></td>
          <td style='color:$($_.Color);font-weight:500'>$($_.RawValue)</td>
          <td style='color:$($_.Color);font-weight:500'>$($_.Normalised)</td>
          <td><span class='badge' style='background:$($_.Color)20;color:$($_.Color);border:1px solid $($_.Color)40'>$($_.Status)</span></td>
          <td>$wb</td><td>$tc</td>
          <td style='color:#888;font-size:12px'>$($_.SourceType)</td>
        </tr>"
    }) -join "`n"
    if (-not $signalRows) { $signalRows = "<tr><td colspan='7' style='text-align:center;color:#888'>No signals configured</td></tr>" }

    # History rows
    $historyRows = ($data.History | ForEach-Object {
        $hc  = @("#1D9E75","#EF9F27","#EF6B27","#E24B4A")[[int]$_.Action]
        $ov  = if ($_.OverrideApplied) { "<span style='background:#E24B4A20;color:#E24B4A;border:1px solid #E24B4A40;border-radius:4px;padding:1px 6px;font-size:11px;margin-left:4px'>OVERRIDE</span>" } else { "" }
        $rc  = if ($_.RedSignalCount    -gt 0) { "<span style='color:#E24B4A;font-weight:500'>$($_.RedSignalCount)</span>"    } else { "<span style='color:#ccc'>—</span>" }
        $yc  = if ($_.YellowSignalCount -gt 0) { "<span style='color:#EF9F27;font-weight:500'>$($_.YellowSignalCount)</span>" } else { "<span style='color:#ccc'>—</span>" }
        $wa  = if ($null -ne $_.WeightedAvg) { $_.WeightedAvg.ToString("F4") } else { "—" }
        "<tr>
          <td style='font-size:12px;color:#888'>$($_.Timestamp)</td>
          <td style='color:$hc;font-weight:500'>$($_.ActionName)$ov</td>
          <td>$($_.AvgSignal)</td><td>$wa</td><td>$rc</td><td>$yc</td>
        </tr>"
    }) -join "`n"
    if (-not $historyRows) { $historyRows = "<tr><td colspan='6' style='text-align:center;color:#888'>No history yet</td></tr>" }

    # Override banner
    $overrideBanner = ""
    if ($data.OverrideApplied) {
        $overrideBanner = "<div class='card' style='border-left:4px solid #E24B4A;background:#fff5f5'><div style='display:flex;align-items:center;gap:12px'><span style='font-size:24px'>&#9888;</span><div><div style='font-weight:600;color:#E24B4A'>RED Signal Override Applied</div><div style='color:#666;font-size:13px;margin-top:4px'>$($data.ActionReason)</div></div></div></div>"
    }

    # Avg display
    $avgDisplay = if ($null -ne $data.WeightedAvg) {
        "Weighted avg: <b>$($data.WeightedAvg)</b> &nbsp;|&nbsp; Simple avg: $($data.AvgSignal)"
    } else { "Average signal: <b>$($data.AvgSignal)</b>" }

    # Signal summary
    $rc = @($data.Signals | Where-Object { $_.Color -eq "#E24B4A" }).Count
    $yc = @($data.Signals | Where-Object { $_.Color -eq "#EF9F27" }).Count
    $gc = @($data.Signals | Where-Object { $_.Color -eq "#1D9E75" }).Count
    $signalSummary = "<span style='color:#1D9E75;font-weight:500;margin-right:12px'>&#9679; $gc OK</span><span style='color:#EF9F27;font-weight:500;margin-right:12px'>&#9679; $yc Watch</span><span style='color:#E24B4A;font-weight:500'>&#9679; $rc Red</span>"

    $actionNum  = $data.Action
    $actionName = $data.ActionName

    $writebackSection = @"
<div class='card' style='border-left:4px solid $($data.ActionColor);margin-top:0'>
  <div class='rec-label'>VBAF Recommendation — $($data.LastTimestamp)</div>
  <div class='rec-action' style='color:$($data.ActionColor)'>$actionName</div>
  <div class='rec-command'>$($data.ActionCommand)</div>
  <div class='rec-avg'>$avgDisplay</div>
  $(if ($data.ActionReason -ne "" -and -not $data.OverrideApplied) { "<div class='rec-reason'>$($data.ActionReason)</div>" })
  <div class='action-buttons'>
    <div style='font-size:12px;color:#888;margin-bottom:10px;margin-top:16px;text-transform:uppercase;letter-spacing:0.5px'>Dispatcher Action</div>
    <form method='POST' action='$baseURL' style='display:inline'>
      <input type='hidden' name='postaction' value='accept'>
      <input type='hidden' name='action' value='$actionNum'>
      <button type='submit' class='btn-accept'>&#10003; Accept &amp; Execute</button>
    </form>
    <button class='btn-override' onclick="document.getElementById('override-form-$actionNum').style.display='block';this.style.display='none'">&#10007; Override</button>
    <div id='override-form-$actionNum' style='display:none;margin-top:12px;background:#fafafa;padding:14px;border-radius:8px;border:0.5px solid #ddd'>
      <form method='POST' action='$baseURL'>
        <input type='hidden' name='postaction' value='override'>
        <input type='hidden' name='vbafaction' value='$actionNum'>
        <div style='margin-bottom:8px;font-size:13px;font-weight:500'>What action did you take instead?</div>
        <div style='display:flex;gap:8px;margin-bottom:10px'>
          <label><input type='radio' name='dispaction' value='0' required> Monitor</label>
          <label><input type='radio' name='dispaction' value='1'> Reassign</label>
          <label><input type='radio' name='dispaction' value='2'> Reroute</label>
          <label><input type='radio' name='dispaction' value='3'> Escalate</label>
        </div>
        <textarea name='reason' placeholder='Why did you override? (helps VBAF learn)' rows='2' style='width:100%;padding:8px;border:0.5px solid #ddd;border-radius:6px;font-size:13px;resize:none;margin-bottom:8px'></textarea>
        <button type='submit' class='btn-override-submit'>Log Override</button>
        <button type='button' onclick="document.getElementById('override-form-$actionNum').style.display='none'" style='background:none;border:none;color:#888;cursor:pointer;margin-left:8px;font-size:13px'>Cancel</button>
      </form>
    </div>
  </div>
</div>
"@

    $thresholdSection = ""
    if ($suggestion) {
        $thresholdSection = @"
<div class='card' style='border-left:4px solid #AFA9EC;background:#EEEDFE20'>
  <div style='display:flex;align-items:center;gap:10px;margin-bottom:12px'>
    <span style='font-size:20px'>&#129504;</span>
    <div>
      <div style='font-weight:600;color:#26215C;font-size:15px'>Learning Engine Suggestion</div>
      <div style='color:#666;font-size:13px;margin-top:2px'>$($suggestion.Reason)</div>
    </div>
  </div>
  <div style='background:#fff;border-radius:8px;padding:12px;margin-bottom:12px;font-size:13px'>
    <div style='display:flex;gap:24px'>
      <div><span style='color:#888'>Current Action1</span><br><b>$($data.Thresholds.Action1)</b></div>
      <div style='color:#AFA9EC;font-size:20px;padding-top:8px'>&#8594;</div>
      <div><span style='color:#26215C'>Suggested Action1</span><br><b style='color:#26215C'>$($suggestion.SuggestedAction1)</b></div>
      &nbsp;&nbsp;
      <div><span style='color:#888'>Current Action2</span><br><b>$($data.Thresholds.Action2)</b></div>
      <div style='color:#AFA9EC;font-size:20px;padding-top:8px'>&#8594;</div>
      <div><span style='color:#26215C'>Suggested Action2</span><br><b style='color:#26215C'>$($suggestion.SuggestedAction2)</b></div>
      &nbsp;&nbsp;
      <div><span style='color:#888'>Current Action3</span><br><b>$($data.Thresholds.Action3)</b></div>
      <div style='color:#AFA9EC;font-size:20px;padding-top:8px'>&#8594;</div>
      <div><span style='color:#26215C'>Suggested Action3</span><br><b style='color:#26215C'>$($suggestion.SuggestedAction3)</b></div>
    </div>
  </div>
  <div style='display:flex;gap:10px'>
    <form method='POST' action='$baseURL' style='display:inline'>
      <input type='hidden' name='postaction' value='apply-threshold'>
      <input type='hidden' name='a1' value='$($suggestion.SuggestedAction1)'>
      <input type='hidden' name='a2' value='$($suggestion.SuggestedAction2)'>
      <input type='hidden' name='a3' value='$($suggestion.SuggestedAction3)'>
      <button type='submit' class='btn-accept'>&#10003; Yes — Apply Thresholds</button>
    </form>
    <form method='POST' action='$baseURL' style='display:inline'>
      <input type='hidden' name='postaction' value='dismiss-threshold'>
      <button type='submit' class='btn-dismiss'>&#10007; No — Dismiss for 7 days</button>
    </form>
  </div>
</div>
"@
    }

    $messageBanner = ""
    if ($Message -ne "") {
        $messageBanner = "<div style='background:#E1F5EE;border-left:4px solid #1D9E75;padding:12px 16px;border-radius:8px;margin-bottom:16px;font-size:13px;color:#04342C'>&#10003; $Message</div>"
    }

    return @"
<!DOCTYPE html>
<html lang='da'>
<head>
<meta charset='UTF-8'>
<meta http-equiv='refresh' content='600'>
<title>VBAF-Center — $($data.Profile.CompanyName)</title>
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:Arial,sans-serif;background:#f4f4f0;color:#2C2C2A;font-size:14px}
  .header{background:#2C2C2A;color:#fff;padding:16px 32px;display:flex;align-items:center;justify-content:space-between}
  .header h1{font-size:18px;font-weight:500}
  .header .ts{font-size:12px;color:#888}
  .tabs{background:#1a1a18;padding:0 32px;display:flex;align-items:center;gap:4px}
  .tab{display:inline-block;padding:10px 20px;color:#aaa;text-decoration:none;font-size:13px;border-bottom:3px solid transparent}
  .tab:hover{color:#fff;background:#2C2C2A}
  .tab.active{color:#fff;border-bottom:3px solid #EF9F27}
  .tab-briefing{display:inline-block;padding:8px 16px;color:#1D9E75;text-decoration:none;font-size:13px;font-weight:500;border:1px solid #1D9E7560;border-radius:6px;margin-left:auto;background:#1D9E7515}
  .tab-briefing:hover{background:#1D9E7530;color:#fff}
  .container{max-width:980px;margin:24px auto;padding:0 24px}
  .card{background:#fff;border-radius:8px;padding:20px 24px;margin-bottom:16px;box-shadow:0 1px 3px rgba(0,0,0,0.08)}
  .card-header{display:flex;justify-content:space-between;align-items:center;font-size:16px;font-weight:500;margin-bottom:8px}
  .meta{color:#666;font-size:13px}
  .badge{padding:3px 10px;border-radius:12px;font-size:12px;font-weight:500}
  .rec-label{font-size:12px;color:#888;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:6px}
  .rec-action{font-size:30px;font-weight:600;margin-bottom:4px}
  .rec-command{font-size:14px;color:#444;margin-bottom:4px}
  .rec-avg{font-size:13px;color:#888}
  .rec-reason{font-size:13px;color:#666;margin-top:8px;padding-top:8px;border-top:1px solid #f0f0ee}
  .section-title{font-weight:500;margin-bottom:12px;color:#444}
  table{width:100%;border-collapse:collapse}
  th{text-align:left;padding:8px 12px;background:#f8f8f6;color:#666;font-weight:500;font-size:12px;border-bottom:1px solid #eee}
  td{padding:10px 12px;border-bottom:1px solid #f0f0ee;font-size:13px;vertical-align:middle}
  tr:last-child td{border-bottom:none}
  .footer{text-align:center;color:#aaa;font-size:12px;padding:24px}
  .btn-accept{background:#1D9E75;color:#fff;border:none;padding:10px 20px;border-radius:6px;font-size:13px;font-weight:500;cursor:pointer;margin-right:8px}
  .btn-accept:hover{background:#178a64}
  .btn-override{background:#fff;color:#E24B4A;border:1px solid #E24B4A;padding:10px 20px;border-radius:6px;font-size:13px;font-weight:500;cursor:pointer}
  .btn-override:hover{background:#fff5f5}
  .btn-override-submit{background:#E24B4A;color:#fff;border:none;padding:8px 16px;border-radius:6px;font-size:13px;cursor:pointer}
  .btn-dismiss{background:#fff;color:#888;border:1px solid #ddd;padding:10px 20px;border-radius:6px;font-size:13px;cursor:pointer}
  .btn-dismiss:hover{background:#f8f8f6}
  .action-buttons{border-top:1px solid #f0f0ee;padding-top:16px;margin-top:12px}
</style>
</head>
<body>
<div class='header'>
  <h1>VBAF-Center Portal</h1>
  <span class='ts'>Live · Auto-refresh 10 min · $($data.Timestamp)</span>
</div>
<div class='tabs'>$tabs</div>
<div class='container'>

$messageBanner

<div class='card'>
  <div class='card-header'>
    <span>$($data.Profile.CompanyName)</span>
    <span class='badge' style='background:#1D9E7520;color:#1D9E75;border:1px solid #1D9E7540'>$($data.Profile.Status)</span>
  </div>
  <div class='meta'>Agent: <b>$($data.Profile.Agent)</b> &nbsp;|&nbsp; Type: <b>$($data.Profile.BusinessType)</b> &nbsp;|&nbsp; $signalSummary</div>
</div>

$overrideBanner
$thresholdSection
$writebackSection

<div class='card'>
  <div class='section-title'>Live Signals</div>
  <table>
    <thead><tr><th>Signal</th><th>Raw</th><th>Norm</th><th>Status</th><th>Weight</th><th>Thresholds</th><th>Source</th></tr></thead>
    <tbody>$signalRows</tbody>
  </table>
</div>

<div class='card'>
  <div class='section-title'>Run History (last 10)</div>
  <table>
    <thead><tr><th>Timestamp</th><th>Action</th><th>Avg</th><th>Weighted</th><th>Red</th><th>Yellow</th></tr></thead>
    <tbody>$historyRows</tbody>
  </table>
</div>

</div>
<div class='footer'>VBAF-Center · Phase 14/15/18 active · Roskilde, Denmark · Built with PowerShell 5.1</div>
</body>
</html>
"@
}

# ============================================================
# START-VBAFCENTERPORTAL
# ============================================================
function Start-VBAFCenterPortal {
    param([int]$Port = 8080)

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

    $firstSched = Get-ChildItem (Join-Path $env:USERPROFILE "VBAFCenter\schedules") -Filter "*.json" -ErrorAction SilentlyContinue |
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
            if (-not $token)      { $token      = "" }

            $valid = Test-PortalToken -CustomerID $customerID -Token $token
            $html  = ""
            $message = ""

            if ($valid) {
                # ── Briefing endpoint ─────────────────────────
                if ($request.Url.AbsolutePath -eq "/briefing") {
                    $html = Get-PortalBriefingHTML -CustomerID $customerID
                    Write-Host ("  [{0}] BRIEFING {1}" -f (Get-Date -Format "HH:mm:ss"), $customerID) -ForegroundColor Cyan
                }
                # ── Main portal ───────────────────────────────
                else {
                    if ($request.HttpMethod -eq "POST") {
                        $reader   = [System.IO.StreamReader]::new($request.InputStream)
                        $postBody = $reader.ReadToEnd()
                        $reader.Close()

                        Write-Host ("  [POST] {0} — {1}" -f $customerID, $postBody) -ForegroundColor Cyan
                        Invoke-PortalPostAction -CustomerID $customerID -PostBody $postBody -Port $Port

                        if ($postBody -like "*postaction=accept*")              { $message = "Action accepted and sent to TMS." }
                        elseif ($postBody -like "*postaction=override*")        { $message = "Override logged. VBAF will learn from this." }
                        elseif ($postBody -like "*postaction=apply-threshold*") { $message = "Thresholds updated successfully." }
                        elseif ($postBody -like "*postaction=dismiss-threshold*") { $message = "Suggestion dismissed for 7 days." }
                    }

                    $html = Get-PortalHTML -CustomerID $customerID -Token $token -Port $Port -Message $message
                    Write-Host ("  [{0}] GET {1}" -f (Get-Date -Format "HH:mm:ss"), $customerID) -ForegroundColor Green
                }
            } else {
                $html = Get-PortalDeniedHTML
                Write-Host ("  [{0}] Denied: {1}" -f (Get-Date -Format "HH:mm:ss"), $request.RawUrl) -ForegroundColor Red
            }

            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.Headers.Add("Cache-Control","no-cache,no-store,must-revalidate")
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
Write-Host "  |   Phase 18: Accept/Override write-back buttons    |" -ForegroundColor Cyan
Write-Host "  |   Phase 16: Threshold suggestion Yes/No           |" -ForegroundColor Cyan
Write-Host "  |   Option C: Daglig Briefing button in portal      |" -ForegroundColor Green
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Start-VBAFCenterPortal             — open browser dashboard"     -ForegroundColor White
Write-Host "  Stop-VBAFCenterPortal              — stop the portal"            -ForegroundColor White
Write-Host "  Get-VBAFCenterPortalURLs           — show all customer URLs"     -ForegroundColor White
Write-Host "  Save-VBAFCenterThresholdSuggestion — push suggestion to portal"  -ForegroundColor White
Write-Host ""