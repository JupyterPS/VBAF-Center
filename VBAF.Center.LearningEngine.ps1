

#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 16 — Learning Engine
.DESCRIPTION
    Reads run history and dispatcher overrides to identify patterns,
    calculate agreement rates and suggest threshold improvements.

    VBAF gets smarter the longer you use it.
    After 30 days it knows your operation better than any new dispatcher.

    Functions:
      Start-VBAFCenterOverride         — log a dispatcher override
      Get-VBAFCenterOverrideHistory    — show all overrides for a customer
      Invoke-VBAFCenterLearnFromHistory — analyse history and produce report
      Get-VBAFCenterLearningReport     — show latest learning report
      Clear-VBAFCenterLearningData     — reset learning data for a customer
#>

$script:LearningPath  = Join-Path $env:USERPROFILE "VBAFCenter\learning"
$script:OverridePath  = Join-Path $env:USERPROFILE "VBAFCenter\overrides"
$script:HistoryPath   = Join-Path $env:USERPROFILE "VBAFCenter\history"

function Initialize-VBAFCenterLearningStore {
    if (-not (Test-Path $script:LearningPath))  { New-Item -ItemType Directory -Path $script:LearningPath  -Force | Out-Null }
    if (-not (Test-Path $script:OverridePath))  { New-Item -ItemType Directory -Path $script:OverridePath  -Force | Out-Null }
}

# ============================================================
# START-VBAFCENTEROVERRIDE — log dispatcher override
# ============================================================
function Start-VBAFCenterOverride {
    <#
    .SYNOPSIS
        Log a dispatcher override — when dispatcher disagrees with VBAF.
        Call this immediately after a run where the dispatcher chose differently.
    .EXAMPLE
        Start-VBAFCenterOverride -CustomerID "TruckCompanyDK" -VBAFAction 3 -DispatcherAction 2 -Reason "Situation not as bad as VBAF thinks"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [Parameter(Mandatory)] [ValidateRange(0,3)] [int] $VBAFAction,
        [Parameter(Mandatory)] [ValidateRange(0,3)] [int] $DispatcherAction,
        [string] $Reason = ""
    )

    Initialize-VBAFCenterLearningStore

    # Get the latest run from history to capture signal snapshot
    $latestFile = Get-ChildItem $script:HistoryPath -Filter "$CustomerID-*.json" |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1

    $signals     = @()
    $weightedAvg = $null
    $avgSignal   = 0.0
    $timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    if ($latestFile) {
        $h           = Get-Content $latestFile.FullName -Raw | ConvertFrom-Json
        $signals     = $h.Signals
        $weightedAvg = $h.WeightedAvg
        $avgSignal   = $h.AvgSignal
        $timestamp   = $h.Timestamp
    }

    $actionNames = @("Monitor","Reassign","Reroute","Escalate")

    $override = [PSCustomObject] @{
        CustomerID       = $CustomerID
        Timestamp        = $timestamp
        LoggedAt         = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Signals          = $signals
        AvgSignal        = $avgSignal
        WeightedAvg      = $weightedAvg
        VBAFAction       = $VBAFAction
        VBAFActionName   = $actionNames[$VBAFAction]
        DispatcherAction = $DispatcherAction
        DispatcherActionName = $actionNames[$DispatcherAction]
        Reason           = $Reason
        Outcome          = "Pending"   # updated by next run analysis
    }

    $overrideFile = Join-Path $script:OverridePath "$CustomerID-overrides.json"

    # Load existing overrides or start fresh
    $overrides = @()
    if (Test-Path $overrideFile) {
        try {
            $existing = Get-Content $overrideFile -Raw | ConvertFrom-Json
            $overrides = @($existing)
        } catch { $overrides = @() }
    }

    $overrides += $override
    $overrides | ConvertTo-Json -Depth 5 | Set-Content $overrideFile -Encoding UTF8

    Write-Host ""
    Write-Host "Override logged!" -ForegroundColor Green
    Write-Host ("  Customer         : {0}" -f $CustomerID)                   -ForegroundColor White
    Write-Host ("  VBAF recommended : {0} — {1}" -f $VBAFAction, $actionNames[$VBAFAction])           -ForegroundColor Yellow
    Write-Host ("  Dispatcher chose : {0} — {1}" -f $DispatcherAction, $actionNames[$DispatcherAction]) -ForegroundColor Cyan
    if ($Reason -ne "") {
        Write-Host ("  Reason           : {0}" -f $Reason) -ForegroundColor White
    }
    Write-Host ("  Total overrides  : {0}" -f $overrides.Count) -ForegroundColor DarkGray
    Write-Host ""
}

# ============================================================
# GET-VBAFCENTEROVERRIDEHISTORY
# ============================================================
function Get-VBAFCenterOverrideHistory {
    <#
    .SYNOPSIS
        Show all logged dispatcher overrides for a customer.
    .EXAMPLE
        Get-VBAFCenterOverrideHistory -CustomerID "TruckCompanyDK"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [int] $Last = 20
    )

    Initialize-VBAFCenterLearningStore

    $overrideFile = Join-Path $script:OverridePath "$CustomerID-overrides.json"
    if (-not (Test-Path $overrideFile)) {
        Write-Host "No overrides logged yet for: $CustomerID" -ForegroundColor Yellow
        Write-Host "Use Start-VBAFCenterOverride to log dispatcher disagreements." -ForegroundColor DarkGray
        return
    }

    $overrides = @(Get-Content $overrideFile -Raw | ConvertFrom-Json)
    $recent    = $overrides | Select-Object -Last $Last

    Write-Host ""
    Write-Host ("Override History: {0} (last {1})" -f $CustomerID, $recent.Count) -ForegroundColor Cyan
    Write-Host ("  {0,-22} {1,-12} {2,-12} {3}" -f "Timestamp","VBAF","Dispatcher","Reason") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 75)) -ForegroundColor DarkGray

    foreach ($o in $recent) {
        $color = if ($o.DispatcherAction -lt $o.VBAFAction) { "Green" } `
                 elseif ($o.DispatcherAction -gt $o.VBAFAction) { "Red" } `
                 else { "White" }
        Write-Host ("  {0,-22} {1,-12} {2,-12} {3}" -f `
            $o.Timestamp,
            $o.VBAFActionName,
            $o.DispatcherActionName,
            $o.Reason) -ForegroundColor $color
    }
    Write-Host ""
    return $overrides
}

# ============================================================
# INVOKE-VBAFCENTERLEARNFROMHISTORY
# ============================================================
function Invoke-VBAFCenterLearnFromHistory {
    <#
    .SYNOPSIS
        Analyse run history and overrides to produce a learning report.
        Identifies patterns and suggests threshold adjustments.
    .EXAMPLE
        Invoke-VBAFCenterLearnFromHistory -CustomerID "TruckCompanyDK" -Days 30
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [int] $Days = 30
    )

    Initialize-VBAFCenterLearningStore

    $cutoff = (Get-Date).AddDays(-$Days)

    # Load history
    $historyFiles = Get-ChildItem $script:HistoryPath -Filter "$CustomerID-*.json" |
                    Where-Object { $_.LastWriteTime -ge $cutoff } |
                    Sort-Object LastWriteTime

    if ($historyFiles.Count -eq 0) {
        Write-Host "No history found for: $CustomerID in the last $Days days." -ForegroundColor Yellow
        return
    }

    $runs = @($historyFiles | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json })

    # Load overrides
    $overrideFile = Join-Path $script:OverridePath "$CustomerID-overrides.json"
    $overrides    = @()
    if (Test-Path $overrideFile) {
        try { $overrides = @(Get-Content $overrideFile -Raw | ConvertFrom-Json) } catch {}
    }

    # --------------------------------------------------------
    # ANALYSIS
    # --------------------------------------------------------
    $totalRuns     = $runs.Count
    $totalOverrides = $overrides.Count

    # Action distribution
    $actionCounts = @{0=0; 1=0; 2=0; 3=0}
    foreach ($r in $runs) { $actionCounts[[int]$r.Action]++ }

    # Override analysis
    $dispatcherLower  = @($overrides | Where-Object { [int]$_.DispatcherAction -lt [int]$_.VBAFAction }).Count
    $dispatcherHigher = @($overrides | Where-Object { [int]$_.DispatcherAction -gt [int]$_.VBAFAction }).Count
    $dispatcherSame   = @($overrides | Where-Object { [int]$_.DispatcherAction -eq [int]$_.VBAFAction }).Count

    # Average signal per action bucket
    $actionAvgs = @{}
    for ($a = 0; $a -le 3; $a++) {
        $bucket = @($runs | Where-Object { [int]$_.Action -eq $a })
        if ($bucket.Count -gt 0) {
            $sum = 0.0
            foreach ($r in $bucket) { $sum += [double]$r.AvgSignal }
            $actionAvgs[$a] = [Math]::Round($sum / $bucket.Count, 4)
        }
    }

    # Red signal override rate
    $redOverrideRuns = @($runs | Where-Object { $_.OverrideApplied -eq $true }).Count
    $redOverridePct  = if ($totalRuns -gt 0) { [Math]::Round($redOverrideRuns / $totalRuns * 100, 1) } else { 0 }

    # Suggest threshold adjustments based on override patterns
    $suggestions = @()

    if ($dispatcherLower -gt ($totalOverrides * 0.6) -and $totalOverrides -ge 5) {
        $suggestions += "Dispatcher chose LOWER action than VBAF in $dispatcherLower of $totalOverrides overrides. Consider RAISING Action3 threshold — VBAF may be escalating too quickly."
    }

    if ($dispatcherHigher -gt ($totalOverrides * 0.6) -and $totalOverrides -ge 5) {
        $suggestions += "Dispatcher chose HIGHER action than VBAF in $dispatcherHigher of $totalOverrides overrides. Consider LOWERING thresholds — VBAF may be too relaxed."
    }

    if ($actionCounts[3] -gt ($totalRuns * 0.3)) {
        $suggestions += "Escalate fired in $($actionCounts[3]) of $totalRuns runs ($([Math]::Round($actionCounts[3]/$totalRuns*100,1))%). This seems high — consider raising Action3 threshold."
    }

    if ($actionCounts[0] -gt ($totalRuns * 0.8)) {
        $suggestions += "Monitor fired in $($actionCounts[0]) of $totalRuns runs ($([Math]::Round($actionCounts[0]/$totalRuns*100,1))%). System may be too relaxed for this customer."
    }

    if ($suggestions.Count -eq 0) {
        $suggestions += "No threshold adjustments suggested — system appears well calibrated."
    }

    # --------------------------------------------------------
    # BUILD REPORT
    # --------------------------------------------------------
    $report = [PSCustomObject] @{
        CustomerID       = $CustomerID
        GeneratedAt      = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        PeriodDays       = $Days
        TotalRuns        = $totalRuns
        TotalOverrides   = $totalOverrides
        ActionCounts     = [PSCustomObject]@{ Monitor=$actionCounts[0]; Reassign=$actionCounts[1]; Reroute=$actionCounts[2]; Escalate=$actionCounts[3] }
        ActionAvgSignals = [PSCustomObject]@{ Monitor=$actionAvgs[0]; Reassign=$actionAvgs[1]; Reroute=$actionAvgs[2]; Escalate=$actionAvgs[3] }
        DispatcherLower  = $dispatcherLower
        DispatcherHigher = $dispatcherHigher
        DispatcherSame   = $dispatcherSame
        RedOverrideRuns  = $redOverrideRuns
        RedOverridePct   = $redOverridePct
        Suggestions      = $suggestions
    }

    # Save report
    $reportFile = Join-Path $script:LearningPath "$CustomerID-learning.json"
    $report | ConvertTo-Json -Depth 5 | Set-Content $reportFile -Encoding UTF8

    # --------------------------------------------------------
    # DISPLAY REPORT
    # --------------------------------------------------------
    $actionNames = @("Monitor","Reassign","Reroute","Escalate")

    Write-Host ""
    Write-Host ("Learning Report: {0}" -f $CustomerID) -ForegroundColor Cyan
    Write-Host ("  Period    : last {0} days" -f $Days) -ForegroundColor White
    Write-Host ("  Generated : {0}" -f $report.GeneratedAt) -ForegroundColor White
    Write-Host ""
    Write-Host "  Run Summary:" -ForegroundColor Yellow
    Write-Host ("    Total runs     : {0}" -f $totalRuns) -ForegroundColor White

    for ($a = 0; $a -le 3; $a++) {
        $pct = if ($totalRuns -gt 0) { [Math]::Round($actionCounts[$a] / $totalRuns * 100, 1) } else { 0 }
        $avg = if ($actionAvgs.ContainsKey($a)) { "avg signal {0}" -f $actionAvgs[$a] } else { "no runs" }
        $color = @("Green","Yellow","DarkYellow","Red")[$a]
        Write-Host ("    {0,-10} : {1,3} runs ({2,5}%)  {3}" -f $actionNames[$a], $actionCounts[$a], $pct, $avg) -ForegroundColor $color
    }

    Write-Host ""
    Write-Host "  Override Summary:" -ForegroundColor Yellow

    if ($totalOverrides -eq 0) {
        Write-Host "    No overrides logged yet." -ForegroundColor DarkGray
        Write-Host "    Use Start-VBAFCenterOverride to log dispatcher disagreements." -ForegroundColor DarkGray
    } else {
        Write-Host ("    Total overrides    : {0}" -f $totalOverrides) -ForegroundColor White
        Write-Host ("    Dispatcher lower   : {0} (dispatcher less alarmed than VBAF)" -f $dispatcherLower) -ForegroundColor Green
        Write-Host ("    Dispatcher higher  : {0} (dispatcher more alarmed than VBAF)" -f $dispatcherHigher) -ForegroundColor Red
        Write-Host ("    Same action        : {0} (agreed on level but logged reason)" -f $dispatcherSame) -ForegroundColor White
    }

    Write-Host ""
    Write-Host ("    RED signal overrides : {0} runs ({1}%)" -f $redOverrideRuns, $redOverridePct) -ForegroundColor White
    Write-Host ""
    Write-Host "  Suggestions:" -ForegroundColor Yellow

    foreach ($s in $suggestions) {
        Write-Host ("    -> {0}" -f $s) -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "  Apply suggested thresholds with:" -ForegroundColor DarkGray
    Write-Host ("    Set-VBAFCenterActionThresholds -CustomerID ""{0}"" -Action1 X -Action2 Y -Action3 Z" -f $CustomerID) -ForegroundColor DarkGray
    Write-Host ""

    return $report
}

# ============================================================
# GET-VBAFCENTERLEARNINGREPORT — show saved report
# ============================================================
function Get-VBAFCenterLearningReport {
    <#
    .SYNOPSIS
        Show the latest saved learning report for a customer.
        Run Invoke-VBAFCenterLearnFromHistory first to generate it.
    .EXAMPLE
        Get-VBAFCenterLearningReport -CustomerID "TruckCompanyDK"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID
    )

    Initialize-VBAFCenterLearningStore

    $reportFile = Join-Path $script:LearningPath "$CustomerID-learning.json"
    if (-not (Test-Path $reportFile)) {
        Write-Host "No learning report found for: $CustomerID" -ForegroundColor Yellow
        Write-Host "Run Invoke-VBAFCenterLearnFromHistory first." -ForegroundColor DarkGray
        return
    }

    $report = Get-Content $reportFile -Raw | ConvertFrom-Json

    Write-Host ""
    Write-Host ("Learning Report: {0} (saved {1})" -f $CustomerID, $report.GeneratedAt) -ForegroundColor Cyan
    Write-Host ("  Period : last {0} days   Runs : {1}   Overrides : {2}" -f `
        $report.PeriodDays, $report.TotalRuns, $report.TotalOverrides) -ForegroundColor White
    Write-Host ""
    Write-Host "  Suggestions:" -ForegroundColor Yellow
    foreach ($s in $report.Suggestions) {
        Write-Host ("    -> {0}" -f $s) -ForegroundColor Cyan
    }
    Write-Host ""

    return $report
}

# ============================================================
# CLEAR-VBAFCENTERLEARNINGDATA
# ============================================================
function Clear-VBAFCenterLearningData {
    <#
    .SYNOPSIS
        Reset all learning data for a customer — overrides and reports.
        Use when starting fresh after major operational changes.
    .EXAMPLE
        Clear-VBAFCenterLearningData -CustomerID "TruckCompanyDK"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID
    )

    $overrideFile = Join-Path $script:OverridePath "$CustomerID-overrides.json"
    $reportFile   = Join-Path $script:LearningPath "$CustomerID-learning.json"

    $removed = 0
    if (Test-Path $overrideFile) { Remove-Item $overrideFile -Force; $removed++ }
    if (Test-Path $reportFile)   { Remove-Item $reportFile   -Force; $removed++ }

    Write-Host ""
    if ($removed -gt 0) {
        Write-Host ("Learning data cleared for: {0}" -f $CustomerID) -ForegroundColor Green
    } else {
        Write-Host ("No learning data found for: {0}" -f $CustomerID) -ForegroundColor Yellow
    }
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host "VBAF-Center Phase 16 loaded  [Learning Engine]" -ForegroundColor Cyan
Write-Host "  Start-VBAFCenterOverride          — log dispatcher override"       -ForegroundColor White
Write-Host "  Get-VBAFCenterOverrideHistory     — show all overrides"            -ForegroundColor White
Write-Host "  Invoke-VBAFCenterLearnFromHistory — analyse and produce report"    -ForegroundColor White
Write-Host "  Get-VBAFCenterLearningReport      — show latest report"            -ForegroundColor White
Write-Host "  Clear-VBAFCenterLearningData      — reset learning data"           -ForegroundColor White
Write-Host ""