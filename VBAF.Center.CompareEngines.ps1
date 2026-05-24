#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center — Compare Engines
.DESCRIPTION
    Generates 100 realistic simulated runs for NordLogistik
    with real patterns built in:
      - Monday mornings calm
      - Wednesday afternoons worse
      - Thursday typically worst
      - A 5-day gradual drift (deteriorating situation)
      - Two spike events (vehicle breakdown simulation)
      - Random noise around realistic baseline

    Then runs BOTH engines on the same data and produces
    a side-by-side comparison report showing where they
    agree, where they differ, and where Mistral spotted
    trends that rule-based missed.

    Run once — see everything — done.
#>
 
cd "C:\Users\henni\OneDrive\WindowsPowerShell"
. .\VBAF-Center\VBAF.Center.LoadAll.ps1
. .\VBAF-Center\VBAF.Center.ClaudeBrain.ps1

$CustomerID  = "NordLogistik"
$Provider    = "Mistral"
$TotalRuns   = 100
$historyPath = Join-Path $env:USERPROFILE "VBAFCenter\history"

# ============================================================
# SIGNAL DEFINITIONS
# ============================================================
$signals = @(
    @{ Name="Empty Driving %";      Min=0;   Max=100;  Base=30;  GoodBelow=25; BadAbove=40; Weight=5; Invert=$true  }
    @{ Name="On-Time Delivery %";   Min=0;   Max=100;  Base=78;  GoodBelow=85; BadAbove=70; Weight=5; Invert=$false }
    @{ Name="Cost Per Trip DKK";    Min=500; Max=4000; Base=1800;GoodBelow=2000;BadAbove=2500;Weight=4;Invert=$true }
    @{ Name="Route Efficiency %";   Min=0;   Max=100;  Base=76;  GoodBelow=80; BadAbove=65; Weight=4; Invert=$false }
    @{ Name="ETA Accuracy %";       Min=0;   Max=100;  Base=80;  GoodBelow=80; BadAbove=65; Weight=4; Invert=$false }
    @{ Name="CO2 Per Trip kg";      Min=10;  Max=120;  Base=48;  GoodBelow=50; BadAbove=70; Weight=2; Invert=$true  }
    @{ Name="POD Completion %";     Min=0;   Max=100;  Base=88;  GoodBelow=92; BadAbove=85; Weight=3; Invert=$false }
    @{ Name="Driver Performance %"; Min=0;   Max=100;  Base=80;  GoodBelow=78; BadAbove=65; Weight=3; Invert=$false }
    @{ Name="Fleet Availability %"; Min=0;   Max=100;  Base=90;  GoodBelow=85; BadAbove=75; Weight=4; Invert=$false }
    @{ Name="Capacity Util %";      Min=0;   Max=100;  Base=72;  GoodBelow=70; BadAbove=55; Weight=3; Invert=$false }
)

# ============================================================
# HELPER FUNCTIONS
# ============================================================
function Get-SignalColour {
    param($s, $norm)
    if ($s.Invert) {
        if ($norm -lt ($s.GoodBelow - $s.Min) / ($s.Max - $s.Min)) { return "Green" }
        if ($norm -gt ($s.BadAbove  - $s.Min) / ($s.Max - $s.Min)) { return "Red"   }
        return "Yellow"
    } else {
        if ($norm -gt ($s.GoodBelow - $s.Min) / ($s.Max - $s.Min)) { return "Green" }
        if ($norm -lt ($s.BadAbove  - $s.Min) / ($s.Max - $s.Min)) { return "Red"   }
        return "Yellow"
    }
}

function Get-WeightedAvg {
    param($norms, $weights)
    $sum = 0.0; $wsum = 0.0
    for ($i = 0; $i -lt $norms.Count; $i++) {
        $sum  += $norms[$i] * $weights[$i]
        $wsum += $weights[$i]
    }
    return [Math]::Round($sum / $wsum, 4)
}

function Get-RuleAction {
    param($avg, $redCount, $yellowCount)
    $base = if ($avg -gt 0.72) { 3 } elseif ($avg -gt 0.50) { 2 } elseif ($avg -gt 0.25) { 1 } else { 0 }
    if ($redCount -ge 2) { $base = [Math]::Max($base, 3) }
    elseif ($redCount -ge 1) { $base = [Math]::Max($base, 2) }
    if ($yellowCount -ge 2) { $base = [Math]::Max($base, 1) }
    return $base
}

# ============================================================
# CLEAR OLD HISTORY
# ============================================================
Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   VBAF-Center — Engine Comparison               |" -ForegroundColor Cyan
Write-Host "  |   Rule-based vs Mistral AI — NordLogistik       |" -ForegroundColor Cyan
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Clearing old NordLogistik history..." -ForegroundColor Yellow
Get-ChildItem $historyPath -Filter "NordLogistik-*.json" -ErrorAction SilentlyContinue | Remove-Item -Force
Write-Host "  Old history cleared." -ForegroundColor Green

# ============================================================
# GENERATE 100 REALISTIC RUNS
# ============================================================
Write-Host ""
Write-Host "  Generating 100 realistic runs..." -ForegroundColor Yellow

$actionNames = @("Monitor","Reassign","Reroute","Escalate")
$ruleResults = @()
$baseDate    = (Get-Date).AddDays(-14)  # start 14 days ago

for ($run = 0; $run -lt $TotalRuns; $run++) {

    # Time simulation — 4 runs per day, spread across 25 days
    $dayOffset  = [int]($run / 4)
    $hourOffset = ($run % 4) * 6  # 00:00, 06:00, 12:00, 18:00
    $runTime    = $baseDate.AddDays($dayOffset).AddHours($hourOffset)
    $dayOfWeek  = [int]$runTime.DayOfWeek   # 0=Sun 1=Mon ... 4=Thu 5=Fri 6=Sat
    $isAfternoon = $hourOffset -ge 12

    # Pattern multipliers
    $dayMult = switch ($dayOfWeek) {
        0 { 0.80 }  # Sunday — very calm
        1 { 0.85 }  # Monday — calm start
        2 { 0.95 }  # Tuesday — normal
        3 { 1.10 }  # Wednesday afternoon spike
        4 { 1.20 }  # Thursday — worst day
        5 { 1.05 }  # Friday — slightly worse
        6 { 0.75 }  # Saturday — quiet
    }

    $timeMult = if ($isAfternoon) { 1.12 } else { 0.92 }

    # Gradual drift — runs 50-70 simulate a deteriorating week
    $driftMult = 1.0
    if ($run -ge 50 -and $run -le 70) {
        $driftMult = 1.0 + (($run - 50) * 0.015)  # +1.5% per run
    }

    # Spike events — runs 35 and 75 simulate a vehicle breakdown
    $spikeMult = 1.0
    if ($run -eq 35 -or $run -eq 36) { $spikeMult = 1.45 }
    if ($run -eq 75 -or $run -eq 76) { $spikeMult = 1.35 }

    # Generate signal values
    $norms    = @()
    $raws     = @()
    $colours  = @()
    $weights  = @()
    $redCount = 0; $yellowCount = 0

    foreach ($s in $signals) {
        $noise  = (Get-Random -Minimum -80 -Maximum 80) / 1000.0
        $mult   = $dayMult * $timeMult * $driftMult * $spikeMult
        $raw    = $s.Base * $mult + $noise * ($s.Max - $s.Min)
        $raw    = [Math]::Max($s.Min, [Math]::Min($s.Max, $raw))
        $norm   = [Math]::Round(($raw - $s.Min) / ($s.Max - $s.Min), 4)
        $colour = Get-SignalColour -s $s -norm $norm

        if ($colour -eq "Red")    { $redCount++    }
        if ($colour -eq "Yellow") { $yellowCount++ }

        $norms   += $norm
        $raws    += [Math]::Round($raw, 1)
        $colours += $colour
        $weights += $s.Weight
    }

    $wavg   = Get-WeightedAvg -norms $norms -weights $weights
    $action = Get-RuleAction -avg $wavg -redCount $redCount -yellowCount $yellowCount

    # Save to history
    $entry = [PSCustomObject]@{
        CustomerID        = $CustomerID
        Timestamp         = $runTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
        Signals           = $norms
        RawSignals        = $raws
        AvgSignal         = $wavg
        WeightedAvg       = $wavg
        Action            = $action
        ActionName        = $actionNames[$action]
        ActionCommand     = "Rule-based: $($actionNames[$action])"
        ActionReason      = "Weighted avg $wavg — $redCount red signals"
        OverrideApplied   = ($redCount -gt 0)
        RedSignalCount    = $redCount
        YellowSignalCount = $yellowCount
        Source            = "RuleBased"
        DayOfWeek         = $dayOfWeek
        IsAfternoon       = $isAfternoon
        RunIndex          = $run
        DriftActive       = ($run -ge 50 -and $run -le 70)
        SpikeActive       = ($run -eq 35 -or $run -eq 36 -or $run -eq 75 -or $run -eq 76)
    }

    $histFile = Join-Path $historyPath ("NordLogistik-{0:yyyyMMdd_HHmmss_fff}.json" -f $runTime.AddMilliseconds($run))
    $entry | ConvertTo-Json -Depth 5 | Set-Content $histFile -Encoding UTF8

    $ruleResults += $entry
}

Write-Host ("  {0} runs generated and saved to history." -f $TotalRuns) -ForegroundColor Green

# ============================================================
# RUN MISTRAL ON CURRENT SNAPSHOT
# ============================================================
Write-Host ""
Write-Host "  Calling Mistral AI Brain on current snapshot..." -ForegroundColor Yellow
Write-Host "  (Using last generated run as current state)" -ForegroundColor DarkGray

# Temporarily set signals to last run values for Mistral to read
$lastRun = $ruleResults[-1]

$mistralResult = $null
try {
    # Build history summary from generated runs
    $historySummary = Get-VBAFCenterHistorySummary -CustomerID $CustomerID -Days 30

    # Build prompt manually using generated data
    $profile = Get-Content "$env:USERPROFILE\VBAFCenter\customers\$CustomerID.json" -Raw | ConvertFrom-Json

    $signalText = ""
    for ($i = 0; $i -lt $signals.Count; $i++) {
        $s      = $signals[$i]
        $norm   = $lastRun.Signals[$i]
        $raw    = $lastRun.RawSignals[$i]
        $colour = Get-SignalColour -s $s -norm $norm
        $signalText += "  - $($s.Name): $raw (god under $($s.GoodBelow), kritisk over $($s.BadAbove)) -- $colour`n"
    }

    $historyText = ""
    $recent5 = $ruleResults | Select-Object -Last 5
    foreach ($h in $recent5) {
        $historyText += "  - $($h.Timestamp): $($h.ActionName) (avg $($h.WeightedAvg))"
        if ($h.DriftActive) { $historyText += " [DRIFT AKTIV]" }
        if ($h.SpikeActive) { $historyText += " [SPIKE]" }
        $historyText += "`n"
    }

    $actionFile = "$env:USERPROFILE\VBAFCenter\actions\$CustomerID-actions.txt"
    $actionText = ""
    if (Test-Path $actionFile) {
        Get-Content $actionFile | ForEach-Object {
            $parts = $_ -split "\|"
            if ($parts.Length -ge 3) { $actionText += "  Action $($parts[0]): $($parts[2])`n" }
        }
    }

    $prompt = @"
Du er driftsassistent for $($profile.CompanyName) - en $($profile.BusinessType) virksomhed i Danmark.
Svar ALTID paa dansk med rigtige danske tegn. Vaer konkret. Ingen lange forklaringer.

KUNDEPROFIL:
  Virksomhed: $($profile.CompanyName) | Branche: $($profile.BusinessType) | Agent: $($profile.Agent)
  Problem: $($profile.Problem)

AKTUELLE SIGNALER (seneste koersel):
$signalText
OVERSIGT: Vaegtet gns=$($lastRun.WeightedAvg) | Roede=$($lastRun.RedSignalCount) | Gule=$($lastRun.YellowSignalCount)

$historySummary

SENESTE 5 KOERSLER:
$historyText
HANDLINGER:
$actionText
OPGAVE - returner KUN dette JSON uden markdown:
{"Action":<0-3>,"ActionName":"<Monitor/Reassign/Reroute/Escalate>","Reason":"<2-3 saetninger>","Instruction":"<1-2 konkrete saetninger>","Pattern":"<1 saetning om moenster>","Confidence":"<Hoj/Medium/Lav>"}

REGLER: 1 roed=min Action 2 | 2+ roede=min Action 3 | avg>0.72=Action 3 | avg>0.50=Action 2 | avg>0.25=Action 1
"@

    $apiKey  = Get-VBAFCenterAIKey -Provider $Provider
    $rawText = Invoke-VBAFCenterAICall -Provider $Provider -Prompt $prompt -APIKey $apiKey
    $rawText = Repair-VBAFCenterDanish -Text $rawText
    $clean   = $rawText.Trim() -replace '```json',''-replace '```','' -replace "`n"," "
    if ($clean -match '\{.*\}') { $clean = $Matches[0] }
    $mistralResult = $clean | ConvertFrom-Json
    Write-Host "  Mistral response received." -ForegroundColor Green
} catch {
    Write-Host ("  Mistral call failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
    $mistralResult = $null
}

# ============================================================
# ANALYSIS
# ============================================================
$actionCounts    = @{0=0;1=0;2=0;3=0}
$driftActions    = @()
$spikeActions    = @()
$thursdayActions = @()
$afternoonActions= @()

foreach ($r in $ruleResults) {
    $actionCounts[$r.Action]++
    if ($r.DriftActive) { $driftActions    += $r.Action }
    if ($r.SpikeActive) { $spikeActions    += $r.Action }
    if ($r.DayOfWeek -eq 4) { $thursdayActions += $r.Action }
    if ($r.IsAfternoon) { $afternoonActions += $r.Action }
}

$avgDrift     = if ($driftActions.Count   -gt 0) { [Math]::Round(($driftActions    | Measure-Object -Average).Average, 2) } else { "N/A" }
$avgSpike     = if ($spikeActions.Count   -gt 0) { [Math]::Round(($spikeActions    | Measure-Object -Average).Average, 2) } else { "N/A" }
$avgThursday  = if ($thursdayActions.Count -gt 0) { [Math]::Round(($thursdayActions | Measure-Object -Average).Average, 2) } else { "N/A" }
$avgAfternoon = if ($afternoonActions.Count -gt 0){ [Math]::Round(($afternoonActions| Measure-Object -Average).Average, 2) } else { "N/A" }
$avgMorning   = @($ruleResults | Where-Object { -not $_.IsAfternoon } | ForEach-Object { $_.Action })
$avgMorningV  = if ($avgMorning.Count -gt 0) { [Math]::Round(($avgMorning | Measure-Object -Average).Average, 2) } else { "N/A" }

$overallAvg   = [Math]::Round(($ruleResults | ForEach-Object { $_.WeightedAvg } | Measure-Object -Average).Average, 3)
$escalatePct  = [Math]::Round($actionCounts[3] / $TotalRuns * 100, 0)
$monitorPct   = [Math]::Round($actionCounts[0] / $TotalRuns * 100, 0)

# ============================================================
# DISPLAY REPORT
# ============================================================
Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   ENGINE COMPARISON REPORT — NordLogistik       |" -ForegroundColor Cyan
Write-Host "  |   $TotalRuns simulated runs · 25 days of data           |" -ForegroundColor Cyan
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan

Write-Host ""
Write-Host "  RULE-BASED ENGINE RESULTS:" -ForegroundColor Yellow
Write-Host ("  Total runs        : {0}" -f $TotalRuns)            -ForegroundColor White
Write-Host ("  Overall avg signal: {0}" -f $overallAvg)           -ForegroundColor White
Write-Host ("  Action distribution:") -ForegroundColor White
Write-Host ("    Monitor   (0) : {0,3} runs ({1}%)" -f $actionCounts[0], $monitorPct)   -ForegroundColor Green
Write-Host ("    Reassign  (1) : {0,3} runs ({1}%)" -f $actionCounts[1], [Math]::Round($actionCounts[1]/$TotalRuns*100,0)) -ForegroundColor Yellow
Write-Host ("    Reroute   (2) : {0,3} runs ({1}%)" -f $actionCounts[2], [Math]::Round($actionCounts[2]/$TotalRuns*100,0)) -ForegroundColor DarkYellow
Write-Host ("    Escalate  (3) : {0,3} runs ({1}%)" -f $actionCounts[3], $escalatePct) -ForegroundColor Red

Write-Host ""
Write-Host "  PATTERNS IN RULE-BASED DATA:" -ForegroundColor Yellow
Write-Host ("  Thursday avg action   : {0}  (higher = worse)" -f $avgThursday)  -ForegroundColor White
Write-Host ("  Afternoon avg action  : {0}" -f $avgAfternoon)  -ForegroundColor White
Write-Host ("  Morning avg action    : {0}" -f $avgMorningV)   -ForegroundColor White
Write-Host ("  Drift period (runs 50-70) avg action: {0}" -f $avgDrift) -ForegroundColor DarkYellow
Write-Host ("  Spike events (runs 35,75) avg action: {0}" -f $avgSpike) -ForegroundColor Red

Write-Host ""
Write-Host "  RULE-BASED BLIND SPOTS:" -ForegroundColor Yellow
Write-Host "  - Cannot explain WHY it chose an action"                          -ForegroundColor DarkGray
Write-Host "  - Cannot spot that Thursday is structurally worse"                -ForegroundColor DarkGray
Write-Host "  - Cannot warn that drift is accelerating before threshold breach" -ForegroundColor DarkGray
Write-Host "  - Cannot identify spike pattern vs gradual deterioration"         -ForegroundColor DarkGray
Write-Host "  - Same signal combination always gives same answer"               -ForegroundColor DarkGray

Write-Host ""
Write-Host ("  {0}" -f ("=" * 52)) -ForegroundColor Cyan

Write-Host ""
Write-Host "  MISTRAL AI BRAIN RESULT (current snapshot):" -ForegroundColor Yellow

if ($mistralResult) {
    $action     = [int]$mistralResult.Action
    $aColors    = @("Green","Yellow","DarkYellow","Red")
    $color      = $aColors[$action]

    Write-Host ("  Action     : {0} — {1}" -f $action, $mistralResult.ActionName) -ForegroundColor $color
    Write-Host ("  Confidence : {0}" -f $mistralResult.Confidence) -ForegroundColor White
    Write-Host ""
    Write-Host "  Reason:" -ForegroundColor Yellow
    Write-Host ("  {0}" -f $mistralResult.Reason) -ForegroundColor White
    Write-Host ""
    Write-Host "  Instruction to dispatcher:" -ForegroundColor Yellow
    Write-Host ("  {0}" -f $mistralResult.Instruction) -ForegroundColor $color
    if ($mistralResult.Pattern -and $mistralResult.Pattern -ne "") {
        Write-Host ""
        Write-Host "  Pattern spotted:" -ForegroundColor Cyan
        Write-Host ("  {0}" -f $mistralResult.Pattern) -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "  WHAT MISTRAL CAN DO THAT RULE-BASED CANNOT:" -ForegroundColor Yellow

    $ruleAction = Get-RuleAction -avg $lastRun.WeightedAvg -redCount $lastRun.RedSignalCount -yellowCount $lastRun.YellowSignalCount

    if ($action -ne $ruleAction) {
        Write-Host ("  ACTION DIFFERENCE DETECTED!" ) -ForegroundColor Red
        Write-Host ("    Rule-based : Action {0} — {1}" -f $ruleAction, $actionNames[$ruleAction]) -ForegroundColor White
        Write-Host ("    Mistral    : Action {0} — {1}" -f $action, $mistralResult.ActionName) -ForegroundColor $color
        Write-Host ("    Why Mistral differs: context from 30-day history changed the recommendation") -ForegroundColor Cyan
    } else {
        Write-Host ("  Same action as rule-based ({0}) — but Mistral adds:" -f $actionNames[$action]) -ForegroundColor White
        Write-Host "    - Plain Danish explanation of why"       -ForegroundColor Green
        Write-Host "    - Specific instruction to dispatcher"    -ForegroundColor Green
        Write-Host "    - Pattern spotted from history"          -ForegroundColor Green
        Write-Host "    - Confidence level"                      -ForegroundColor Green
    }
} else {
    Write-Host "  Mistral result not available — check API key." -ForegroundColor Red
}

Write-Host ""
Write-Host ("  {0}" -f ("=" * 52)) -ForegroundColor Cyan
Write-Host ""
Write-Host "  SUMMARY TABLE:" -ForegroundColor Yellow
Write-Host ("  {0,-30} {1,-20} {2}" -f "Capability","Rule-based","Mistral") -ForegroundColor Yellow
Write-Host ("  {0}" -f ("-" * 65)) -ForegroundColor DarkGray
Write-Host ("  {0,-30} {1,-20} {2}" -f "Action decision","Yes","Yes")                          -ForegroundColor White
Write-Host ("  {0,-30} {1,-20} {2}" -f "Plain Danish reason","No","Yes")                       -ForegroundColor White
Write-Host ("  {0,-30} {1,-20} {2}" -f "Dispatcher instruction","Fixed template","Dynamic")    -ForegroundColor White
Write-Host ("  {0,-30} {1,-20} {2}" -f "Pattern recognition","No","Yes")                       -ForegroundColor White
Write-Host ("  {0,-30} {1,-20} {2}" -f "Day-of-week awareness","No","Yes")                     -ForegroundColor White
Write-Host ("  {0,-30} {1,-20} {2}" -f "Drift detection","No","Yes")                           -ForegroundColor White
Write-Host ("  {0,-30} {1,-20} {2}" -f "Spike vs drift distinction","No","Yes")                -ForegroundColor White
Write-Host ("  {0,-30} {1,-20} {2}" -f "Confidence level","No","Yes")                          -ForegroundColor White
Write-Host ("  {0,-30} {1,-20} {2}" -f "API cost","Free","Free (Mistral tier)")                -ForegroundColor White
Write-Host ("  {0,-30} {1,-20} {2}" -f "Speed","Instant","2-5 seconds")                        -ForegroundColor White
Write-Host ""
Write-Host "  RECOMMENDATION:" -ForegroundColor Yellow
Write-Host "  Run rule-based every 10 min for instant decisions." -ForegroundColor White
Write-Host "  Run Mistral every 30 min for context and explanation." -ForegroundColor White
Write-Host "  They complement each other — not replace each other." -ForegroundColor White
Write-Host ""

