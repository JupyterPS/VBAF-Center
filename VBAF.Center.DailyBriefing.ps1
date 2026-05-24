#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center — Daily Briefing
.DESCRIPTION
    Generates a clean HTML daily briefing from ClaudeBrain
    and rule-based history. Opens automatically in browser.

    Designed for the dispatcher — not the developer.
    No PowerShell. No console. Just open the browser.

    Functions:
      Export-VBAFCenterDailyBriefing  — generate and open HTML briefing
      Get-VBAFCenterBriefingPath      — show where briefings are saved
#>

$script:BriefingPath = Join-Path $env:USERPROFILE "VBAFCenter\briefings"

function Initialize-VBAFCenterBriefingStore {
    if (-not (Test-Path $script:BriefingPath)) {
        New-Item -ItemType Directory -Path $script:BriefingPath -Force | Out-Null
    }
}

# ============================================================
# FIX DANISH CHARACTERS FOR HTML OUTPUT
# ============================================================
function Repair-VBAFCenterDanishHTML {
    param([string] $Text)
    if (-not $Text) { return "" }
    # Fix garbled UTF-8 read as Windows-1252
    try {
        $bytes = [System.Text.Encoding]::GetEncoding(1252).GetBytes($Text)
        $fixed = [System.Text.Encoding]::UTF8.GetString($bytes)
        if ($fixed -notmatch "\?\?") { $Text = $fixed }
    } catch {}
    # Fix common Mistral ascii substitutions
    $Text = $Text -replace "\baa\b", "aa"
    $Text = $Text -replace "tomkoersel",      "tomkørsel"
    $Text = $Text -replace "omgaaende",        "omgående"
    $Text = $Text -replace "oejeblikkeligt",   "øjeblikkeligt"
    $Text = $Text -replace "oejeblikkelig",    "øjeblikkelig"
    $Text = $Text -replace "omgaaende",        "omgående"
    $Text = $Text -replace "gennemgaa",        "gennemgå"
    $Text = $Text -replace "gennemgaar",       "gennemgår"
    $Text = $Text -replace "ruteplanlaegning", "ruteplanlægning"
    $Text = $Text -replace "planlaegning",     "planlægning"
    $Text = $Text -replace "flaadekapacitet",  "flådekapacitet"
    $Text = $Text -replace "flaaden",          "flåden"
    $Text = $Text -replace "flaade",           "flåde"
    $Text = $Text -replace "leveringspraecision", "leveringspræcision"
    $Text = $Text -replace "praecision",       "præcision"
    $Text = $Text -replace "ressourceallokering", "ressourceallokering"
    $Text = $Text -replace "oekonomi",         "økonomi"
    $Text = $Text -replace "kritiske",         "kritiske"
    $Text = $Text -replace "vaerste",          "værste"
    $Text = $Text -replace "vaer ",            "vær "
    $Text = $Text -replace "hoejeste",         "højeste"
    $Text = $Text -replace "hoej",             "høj"
    $Text = $Text -replace "Hoej",             "Høj"
    $Text = $Text -replace "hojeste",          "højeste"
    $Text = $Text -replace "daarligste",       "dårligste"
    $Text = $Text -replace "daarlig",          "dårlig"
    $Text = $Text -replace "naermer",          "nærmer"
    $Text = $Text -replace "naeste",           "næste"
    $Text = $Text -replace "saerlig",          "særlig"
    $Text = $Text -replace "beordr",           "beordr"
    $Text = $Text -replace "tilpasninger",     "tilpasninger"
    $Text = $Text -replace "kapacitetsjusteringer", "kapacitetsjusteringer"
    $Text = $Text -replace "midlertidige",     "midlertidige"
    $Text = $Text -replace "gentagne",         "gentagne"
    $Text = $Text -replace "koersler",         "kørsler"
    $Text = $Text -replace "koersel",          "kørsel"
    $Text = $Text -replace "braendef",         "brændstof"
    $Text = $Text -replace "braendstof",       "brændstof"
    $Text = $Text -replace "udledning",        "udledning"
    $Text = $Text -replace "effektivitet",     "effektivitet"
    $Text = $Text -replace "prioriter",        "prioritér"
    $Text = $Text -replace "anmod",            "anmod"
    $Text = $Text -replace "reducere",         "reducere"
    $Text = $Text -replace "lastbiler",        "lastbiler"
    $Text = $Text -replace "leveringer",       "leveringer"
    $Text = $Text -replace "faldende",         "faldende"
    $Text = $Text -replace "H\?j","Høj" -replace "H.j","Høj"
    return $Text
}

# ============================================================
# GET-VBAFCENTERBRIEFINGPATH
# ============================================================
function Get-VBAFCenterBriefingPath {
    Write-Host ("Briefings saved to: {0}" -f $script:BriefingPath) -ForegroundColor Cyan
    Get-ChildItem $script:BriefingPath -Filter "*.html" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 10 |
        ForEach-Object { Write-Host ("  {0}" -f $_.Name) -ForegroundColor White }
}

# ============================================================
# EXPORT-VBAFCENTERDAILYBRIEFING
# ============================================================
function Export-VBAFCenterDailyBriefing {
    <#
    .SYNOPSIS
        Generate HTML daily briefing and open in browser.
        Reads last 24h of history + latest AI Brain result.
    .EXAMPLE
        Export-VBAFCenterDailyBriefing -CustomerID "NordLogistik"
        Export-VBAFCenterDailyBriefing -CustomerID "NordLogistik" -Provider "Mistral" -OpenBrowser
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [string] $Provider    = "Mistral",
        [switch] $OpenBrowser,
        [switch] $RunAIFirst
    )

    Initialize-VBAFCenterBriefingStore

    Write-Host ""
    Write-Host ("  Generating daily briefing: {0}" -f $CustomerID) -ForegroundColor Cyan

    # Load customer profile
    $profilePath = Join-Path $env:USERPROFILE "VBAFCenter\customers\$CustomerID.json"
    if (-not (Test-Path $profilePath)) {
        Write-Host ("  Customer not found: {0}" -f $CustomerID) -ForegroundColor Red
        return
    }
    $profile = Get-Content $profilePath -Raw | ConvertFrom-Json

    # Run AI Brain first if requested
    $latestAI = $null
    if ($RunAIFirst) {
        Write-Host "  Running AI Brain first..." -ForegroundColor DarkGray
        if (Get-Command Invoke-VBAFCenterClaudeBrain -ErrorAction SilentlyContinue) {
            $latestAI = Invoke-VBAFCenterClaudeBrain -CustomerID $CustomerID -Provider $Provider -SuppressCrisis
        }
    }

    # Load history — last 24 hours
    $historyPath = Join-Path $env:USERPROFILE "VBAFCenter\history"
    $cutoff      = (Get-Date).AddHours(-24)
    $allHistory  = @()
    $aiHistory   = @()

    if (Test-Path $historyPath) {
        $files = Get-ChildItem $historyPath -Filter "$CustomerID-*.json" |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 200

        foreach ($f in $files) {
            try {
                $h = Get-Content $f.FullName -Raw | ConvertFrom-Json
                $allHistory += $h
                if ($h.Source -like "AI-*") { $aiHistory += $h }
            } catch {}
        }
    }

    $last24h   = @($allHistory | Where-Object {
        try { [DateTime]::Parse($_.Timestamp) -ge $cutoff } catch { $false }
    })
    $aiLast24h = @($aiHistory  | Where-Object {
        try { [DateTime]::Parse($_.Timestamp) -ge $cutoff } catch { $false }
    })

    # Get latest AI result
    if (-not $latestAI -and $aiHistory.Count -gt 0) {
        $latestAI = $aiHistory | Sort-Object Timestamp | Select-Object -Last 1
    }

    # Statistics
    $actionNames  = @("Monitor","Reassign","Reroute","Escalate")
    $actionColors = @("#1D9E75","#EF9F27","#EF6B27","#E24B4A")

    $totalRuns    = $last24h.Count
    $actionCounts = @{0=0;1=0;2=0;3=0}
    foreach ($h in $last24h) { try { $actionCounts[[int]$h.Action]++ } catch {} }

    $avgSignal = if ($last24h.Count -gt 0) {
        [Math]::Round(($last24h | ForEach-Object { try { [double]$_.WeightedAvg } catch { 0 } } | Measure-Object -Average).Average, 3)
    } else { 0 }

    $maxRed = if ($last24h.Count -gt 0) {
        ($last24h | ForEach-Object { try { [int]$_.RedSignalCount } catch { 0 } } | Measure-Object -Maximum).Maximum
    } else { 0 }

    # Load daily log
    $logPath    = Join-Path $env:USERPROFILE "VBAFCenter\dailylog"
    $logEntries = @()
    $logFile    = Join-Path $logPath "$CustomerID-$(Get-Date -Format 'yyyyMMdd').log"
    if (Test-Path $logFile) {
        $logEntries = Get-Content $logFile -Encoding UTF8 -ErrorAction SilentlyContinue
    }

    # Dominant action
    $dominantAction = 0
    $dominantCount  = 0
    foreach ($a in 0..3) {
        if ($actionCounts[$a] -gt $dominantCount) {
            $dominantCount  = $actionCounts[$a]
            $dominantAction = $a
        }
    }

    # Latest rule-based run
    $latestRule = $allHistory | Where-Object { $_.Source -notlike "AI-*" } |
                  Sort-Object Timestamp | Select-Object -Last 1

    # Build signal cards HTML
    $signalCardsHTML = ""
    if ($latestRule -and $latestRule.Signals) {
        $signalNames = @(
            "Empty Driving %","On-Time Delivery %","Cost Per Trip DKK",
            "Route Efficiency %","ETA Accuracy %","CO2 Per Trip kg",
            "POD Completion %","Driver Performance %","Fleet Availability %","Capacity Util %"
        )
        $signals = @($latestRule.Signals)
        for ($i = 0; $i -lt [Math]::Min($signals.Count, $signalNames.Count); $i++) {
            $norm  = try { [double]$signals[$i] } catch { 0 }
            $pct   = [int]($norm * 100)
            $color = if ($norm -gt 0.75) { "#E24B4A" } elseif ($norm -gt 0.40) { "#EF9F27" } else { "#1D9E75" }
            $bg    = if ($norm -gt 0.75) { "#fde8e8" } elseif ($norm -gt 0.40) { "#fef3e2" } else { "#e8f8f2" }
            $signalCardsHTML += @"
        <div class="signal-card" style="border-left:4px solid $color;background:$bg">
          <div class="signal-name">$($signalNames[$i])</div>
          <div class="signal-value" style="color:$color">$pct%</div>
          <div class="signal-bar"><div class="signal-fill" style="width:$pct%;background:$color"></div></div>
        </div>
"@
        }
    }

    # Build AI section HTML
    $aiSectionHTML = ""
    if ($latestAI) {
        $aiAction    = try { [int]$latestAI.Action } catch { 0 }
        $aiColor     = $actionColors[$aiAction]
        $aiName      = $actionNames[$aiAction]
        $aiReason    = Repair-VBAFCenterDanishHTML -Text ([string]$latestAI.ActionReason)
        $aiInstruct  = Repair-VBAFCenterDanishHTML -Text ([string]$latestAI.ActionCommand)
        $aiPattern   = Repair-VBAFCenterDanishHTML -Text ([string]$latestAI.Pattern)
        $aiConf      = Repair-VBAFCenterDanishHTML -Text ([string]$latestAI.Confidence)
        $aiTime      = [string]$latestAI.Timestamp
        $aiProvider  = [string]$latestAI.Source -replace "^AI-",""

        $patternHTML = ""
        if ($aiPattern -and $aiPattern -ne "") {
            $patternHTML = "<div class='pattern-box'>🔍 Pattern: $aiPattern</div>"
        }

        $aiSectionHTML = @"
      <div class="ai-card">
        <div class="ai-header">
          <span class="ai-badge">AI Brain — $aiProvider</span>
          <span class="ai-time">$aiTime</span>
        </div>
        <div class="ai-action" style="color:$aiColor;border-left:4px solid $aiColor">
          Action $aiAction — $aiName
          <span class="conf-badge">Confidence: $aiConf</span>
        </div>
        <div class="ai-reason"><strong>Reason:</strong> $aiReason</div>
        <div class="ai-instruction" style="border-left:4px solid $aiColor">
          <strong>Instruction:</strong> $aiInstruct
        </div>
        $patternHTML
      </div>
"@
    } else {
        $aiSectionHTML = "<div class='ai-card'><p style='color:#888'>No AI Brain result available. Run Invoke-VBAFCenterClaudeBrain first.</p></div>"
    }

    # Build action distribution bars
    $distHTML = ""
    foreach ($a in 0..3) {
        $pct   = if ($totalRuns -gt 0) { [int]($actionCounts[$a] / $totalRuns * 100) } else { 0 }
        $color = $actionColors[$a]
        $name  = $actionNames[$a]
        $distHTML += @"
        <div class="dist-row">
          <span class="dist-label">$name</span>
          <div class="dist-bar"><div class="dist-fill" style="width:$pct%;background:$color"></div></div>
          <span class="dist-pct">$($actionCounts[$a]) runs ($pct%)</span>
        </div>
"@
    }

    # Build log HTML
    $logHTML = ""
    if ($logEntries.Count -gt 0) {
        foreach ($line in ($logEntries | Select-Object -Last 10)) {
            $logColor   = if ($line -like "*Escalate*") { "#E24B4A" } elseif ($line -like "*Reroute*") { "#EF6B27" } elseif ($line -like "*Reassign*") { "#EF9F27" } else { "#1D9E75" }
            $fixedLine  = Repair-VBAFCenterDanishHTML -Text $line
            $logHTML   += "<div class='log-line' style='color:$logColor'>$fixedLine</div>"
        }
    } else {
        $logHTML = "<div class='log-line' style='color:#888'>No AI decisions logged today yet.</div>"
    }

    # Date and day
    $dayNames   = @("Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday")
    $todayName  = $dayNames[[int](Get-Date).DayOfWeek]
    $dateStr    = (Get-Date).ToString("d MMMM yyyy")
    $domColor   = $actionColors[$dominantAction]
    $domName    = $actionNames[$dominantAction]
    $domPct     = if ($totalRuns -gt 0) { [int]($actionCounts[$dominantAction] / $totalRuns * 100) } else { 0 }

    # ============================================================
    # BUILD HTML
    # ============================================================
    $html = @"
<!DOCTYPE html>
<html lang="da">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>VBAF Daily Briefing — $($profile.CompanyName)</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:Arial,sans-serif;background:#f4f4f0;color:#2C2C2A;padding:0}
.header{background:#2C2C2A;color:#fff;padding:20px 24px;display:flex;justify-content:space-between;align-items:center}
.header-left h1{font-size:18px;font-weight:500}
.header-left p{font-size:13px;color:#aaa;margin-top:4px}
.header-right{text-align:right}
.header-right .day{font-size:22px;font-weight:500}
.header-right .date{font-size:13px;color:#aaa}
.content{padding:20px 24px;max-width:1200px;margin:0 auto}
.section-title{font-size:13px;font-weight:500;color:#5F5E5A;text-transform:uppercase;letter-spacing:0.5px;margin:20px 0 10px}
.summary-cards{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:8px}
.sum-card{background:#fff;border-radius:10px;padding:14px 16px;border:0.5px solid #D3D1C7}
.sum-card .label{font-size:11px;color:#888;margin-bottom:4px}
.sum-card .value{font-size:22px;font-weight:500}
.sum-card .sub{font-size:11px;color:#888;margin-top:2px}
.dominant-card{background:#fff;border-radius:10px;padding:16px;margin-bottom:16px;border:0.5px solid #D3D1C7;display:flex;align-items:center;gap:16px}
.dominant-action{font-size:32px;font-weight:700;padding:8px 20px;border-radius:8px;color:#fff}
.dominant-text h2{font-size:16px;font-weight:500}
.dominant-text p{font-size:13px;color:#666;margin-top:4px}
.two-col{display:grid;grid-template-columns:1fr 1fr;gap:16px}
.card{background:#fff;border-radius:10px;padding:16px;border:0.5px solid #D3D1C7}
.signal-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px}
.signal-card{padding:10px 12px;border-radius:8px;background:#f8f8f6}
.signal-name{font-size:11px;color:#666;margin-bottom:4px}
.signal-value{font-size:16px;font-weight:500;margin-bottom:4px}
.signal-bar{background:#e8e8e4;border-radius:4px;height:4px;overflow:hidden}
.signal-fill{height:4px;border-radius:4px;transition:width 0.3s}
.dist-row{display:flex;align-items:center;gap:10px;margin-bottom:8px}
.dist-label{font-size:12px;color:#444;min-width:80px}
.dist-bar{flex:1;background:#f0f0ec;border-radius:4px;height:8px;overflow:hidden}
.dist-fill{height:8px;border-radius:4px}
.dist-pct{font-size:11px;color:#888;min-width:100px;text-align:right}
.ai-card{background:#fff;border-radius:10px;padding:16px;border:0.5px solid #D3D1C7;margin-bottom:16px}
.ai-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:12px}
.ai-badge{background:#EEEDFE;color:#26215C;font-size:11px;font-weight:500;padding:3px 10px;border-radius:20px}
.ai-time{font-size:11px;color:#888}
.ai-action{font-size:18px;font-weight:500;padding:10px 14px;border-radius:8px;background:#f8f8f6;margin-bottom:12px;display:flex;justify-content:space-between;align-items:center}
.conf-badge{font-size:11px;font-weight:400;color:#666;background:#fff;padding:2px 8px;border-radius:10px;border:0.5px solid #ddd}
.ai-reason{font-size:13px;color:#444;margin-bottom:10px;line-height:1.5}
.ai-instruction{font-size:13px;padding:10px 14px;background:#f8f8f6;border-radius:8px;margin-bottom:10px;line-height:1.5}
.pattern-box{font-size:12px;color:#26215C;background:#EEEDFE;padding:8px 12px;border-radius:8px;border-left:4px solid #AFA9EC}
.log-line{font-size:11px;font-family:monospace;padding:4px 0;border-bottom:0.5px solid #f0f0ec;line-height:1.6}
.footer{text-align:center;color:#888;font-size:12px;padding:20px 0;border-top:0.5px solid #D3D1C7;margin-top:20px}
.refresh-btn{display:inline-block;margin-top:8px;padding:6px 16px;background:#2C2C2A;color:#fff;border-radius:6px;font-size:12px;cursor:pointer;text-decoration:none}
</style>
</head>
<body>

<div class="header">
  <div class="header-left">
    <h1>VBAF Daily Briefing</h1>
    <p>$($profile.CompanyName) · $($profile.BusinessType)</p>
  </div>
  <div class="header-right">
    <div class="day">$todayName</div>
    <div class="date">$dateStr</div>
  </div>
</div>

<div class="content">

  <div class="section-title">Last 24 Hours — Overview</div>

  <div class="summary-cards">
    <div class="sum-card">
      <div class="label">Total runs</div>
      <div class="value">$totalRuns</div>
      <div class="sub">rule-based checks</div>
    </div>
    <div class="sum-card">
      <div class="label">Average signal</div>
      <div class="value">$avgSignal</div>
      <div class="sub">0.0 = perfect · 1.0 = crisis</div>
    </div>
    <div class="sum-card">
      <div class="label">Max red signals</div>
      <div class="value" style="color:#E24B4A">$maxRed</div>
      <div class="sub">in a single run</div>
    </div>
    <div class="sum-card">
      <div class="label">AI Brain runs</div>
      <div class="value" style="color:#26215C">$($aiLast24h.Count)</div>
      <div class="sub">via $Provider</div>
    </div>
  </div>

  <div class="dominant-card">
    <div class="dominant-action" style="background:$domColor">$domName</div>
    <div class="dominant-text">
      <h2>Most common action yesterday</h2>
      <p>$domName fired $dominantCount times ($domPct% of all runs)</p>
    </div>
  </div>

  <div class="section-title">AI Brain — Latest Assessment</div>
  $aiSectionHTML

  <div class="two-col">
    <div>
      <div class="section-title">Current Signal Status</div>
      <div class="card">
        <div class="signal-grid">
          $signalCardsHTML
        </div>
      </div>
    </div>
    <div>
      <div class="section-title">Action Distribution (last 24h)</div>
      <div class="card">
        $distHTML
      </div>
      <div class="section-title" style="margin-top:16px">AI Decision Log (today)</div>
      <div class="card">
        $logHTML
      </div>
    </div>
  </div>

</div>

<div class="footer">
  VBAF-Center v1.0 · $($profile.CompanyName) · Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  <br><a class="refresh-btn" href="javascript:location.reload()">Refresh</a>
</div>

</body>
</html>
"@

    # Save HTML
    $filename = "$CustomerID-briefing-$(Get-Date -Format 'yyyyMMdd_HHmm').html"
    $filepath = Join-Path $script:BriefingPath $filename
    $htmlBytes = [System.Text.Encoding]::UTF8.GetBytes($html); [System.IO.File]::WriteAllBytes($filepath, $htmlBytes)

    Write-Host ("  Briefing saved: {0}" -f $filepath) -ForegroundColor Green

    # Also save as latest
    $latestPath = Join-Path $script:BriefingPath "$CustomerID-latest.html"
    $htmlBytes = [System.Text.Encoding]::UTF8.GetBytes($html); [System.IO.File]::WriteAllBytes($latestPath, $htmlBytes)
    Write-Host ("  Latest:         {0}" -f $latestPath) -ForegroundColor Green

    # Open in browser
    if ($OpenBrowser) {
        Start-Process $latestPath
        Write-Host "  Opening in browser..." -ForegroundColor Cyan
    } else {
        Write-Host "  Open with: Start-Process '$latestPath'" -ForegroundColor DarkGray
    }

    Write-Host ""
    return $latestPath
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   VBAF-Center — Daily Briefing                  |" -ForegroundColor Cyan
Write-Host "  |   HTML report for dispatcher — opens in browser |" -ForegroundColor Cyan
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Export-VBAFCenterDailyBriefing  — generate HTML briefing"        -ForegroundColor White
Write-Host "  Get-VBAFCenterBriefingPath      — show saved briefings"          -ForegroundColor White
Write-Host ""
Write-Host "  Quick start:" -ForegroundColor Yellow
Write-Host "  Export-VBAFCenterDailyBriefing -CustomerID 'NordLogistik' -OpenBrowser" -ForegroundColor DarkGray
Write-Host "  Export-VBAFCenterDailyBriefing -CustomerID 'NordLogistik' -RunAIFirst -OpenBrowser" -ForegroundColor DarkGray
Write-Host ""

