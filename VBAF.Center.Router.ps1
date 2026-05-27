#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 5 — Agent Router
.DESCRIPTION
    Takes normalised signals and routes them to the correct
    trained VBAF agent. Returns the recommended action (0-3).

    Phase 14 — RED signal override raises minimum action level
    Phase 15 — Weighted average used instead of simple average
    Phase 17 — Customer-specific action thresholds from schedule.json

    Functions:
      Invoke-VBAFCenterRoute          — send signals to correct agent
      Register-VBAFCenterAgent        — register a trained agent
      Get-VBAFCenterRouteStatus       — show all loaded agents
      Get-VBAFCenterActionExplanation — explain why an action was chosen
#>

# ============================================================
# AGENT REGISTRY
# ============================================================
$script:LoadedAgents = @{}

# ============================================================
# REGISTER-VBAFCENTERAGENT
# ============================================================
function Register-VBAFCenterAgent {
    param(
        [Parameter(Mandatory)] [string] $AgentName,
        [Parameter(Mandatory)] [object] $Agent,
        [string] $Description = ""
    )

    $script:LoadedAgents[$AgentName] = @{
        Agent       = $Agent
        Description = $Description
        LoadedAt    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    Write-Host "Agent registered: $AgentName" -ForegroundColor Green
}

# ============================================================
# GET-ROUTERTHRESHOLDS  (internal — private to Router)
# ============================================================
function Get-RouterThresholds {
    param([string] $CustomerID)

    $thresholds = @{ Action1 = 0.25; Action2 = 0.50; Action3 = 0.75 }

    $schedPath = Join-Path $env:USERPROFILE "VBAFCenter\schedules\$CustomerID-schedule.json"
    if (Test-Path $schedPath) {
        try {
            $sched = Get-Content $schedPath -Raw | ConvertFrom-Json
            if ($null -ne $sched.Action1Threshold) { $thresholds.Action1 = [double]$sched.Action1Threshold }
            if ($null -ne $sched.Action2Threshold) { $thresholds.Action2 = [double]$sched.Action2Threshold }
            if ($null -ne $sched.Action3Threshold) { $thresholds.Action3 = [double]$sched.Action3Threshold }
        } catch {}
    }

    return $thresholds
}

# ============================================================
# INVOKE-VBAFCENTERROUTE
# ============================================================
function Invoke-VBAFCenterRoute {
    param(
        [Parameter(Mandatory)] [string]   $CustomerID,
        [Parameter(Mandatory)] [double[]] $NormalisedSignals,
        [string]   $AgentOverride = "",
        [double]   $WeightedAvg   = -1,
        [object[]] $RedSignals    = @(),
        [object[]] $YellowSignals = @()
    )

    $profilePath = Join-Path $env:USERPROFILE "VBAFCenter\customers\$CustomerID.json"
    if (-not (Test-Path $profilePath)) {
        Write-Host "Customer not found: $CustomerID" -ForegroundColor Red
        return $null
    }

    $profile    = Get-Content $profilePath -Raw | ConvertFrom-Json
    $agentName  = if ($AgentOverride -ne "") { $AgentOverride } else { $profile.Agent }
    $thresholds = Get-RouterThresholds -CustomerID $CustomerID

    $customThresholds = $thresholds.Action1 -ne 0.25 -or
                        $thresholds.Action2 -ne 0.50 -or
                        $thresholds.Action3 -ne 0.75

    # ── Average ───────────────────────────────────────────────
    [double]$simpleAvg = 0.0
    foreach ($s in $NormalisedSignals) { $simpleAvg += $s }
    if ($NormalisedSignals.Length -gt 0) { $simpleAvg /= $NormalisedSignals.Length }
    [double]$avgUsed = if ($WeightedAvg -ge 0) { $WeightedAvg } else { $simpleAvg }
    $avgLabel = if ($WeightedAvg -ge 0) { "weighted" } else { "simple" }

    # ── Base action ───────────────────────────────────────────
    [int]$baseAction = 0
    [string]$agentMode = ""

    if ($script:LoadedAgents.ContainsKey($agentName)) {
        $baseAction = [int]$script:LoadedAgents[$agentName].Agent.Act($NormalisedSignals)
        $agentMode  = "trained agent"
    } else {
        $baseAction = if      ($avgUsed -lt $thresholds.Action1) { 0 }
                      elseif  ($avgUsed -lt $thresholds.Action2) { 1 }
                      elseif  ($avgUsed -lt $thresholds.Action3) { 2 }
                      else                                        { 3 }
        $agentMode  = "rule-based fallback"
    }

    # ── Phase 14 overrides ────────────────────────────────────
    [int]$finalAction      = $baseAction
    [string]$actionReason  = ("Average signal {0:F4} => baseline action {1}" -f $avgUsed, $baseAction)
    [bool]$overrideApplied = $false

    $redCount    = if ($RedSignals)    { @($RedSignals).Count    } else { 0 }
    $yellowCount = if ($YellowSignals) { @($YellowSignals).Count } else { 0 }

    if ($redCount -gt 0 -and $finalAction -lt 2) {
        $redNames      = ($RedSignals | ForEach-Object { $_.SignalName }) -join ", "
        $finalAction   = 2
        $actionReason  = ("RED signal override: {0} — raised to Reroute" -f $redNames)
        $overrideApplied = $true
    }

    if ($redCount -ge 2 -and $finalAction -lt 3) {
        $redNames      = ($RedSignals | ForEach-Object { $_.SignalName }) -join ", "
        $finalAction   = 3
        $actionReason  = ("MULTIPLE RED signals: {0} — raised to Escalate" -f $redNames)
        $overrideApplied = $true
    }

    if ($yellowCount -ge 2 -and $finalAction -lt 1) {
        $yellowNames   = ($YellowSignals | ForEach-Object { $_.SignalName }) -join ", "
        $finalAction   = 1
        $actionReason  = ("YELLOW signals: {0} — raised to Reassign" -f $yellowNames)
        $overrideApplied = $true
    }

    # ── Output — clean, no duplicates ────────────────────────
    $actionNames  = @("Monitor","Reassign","Reroute","Escalate")
    $actionColors = @("Green","Yellow","DarkYellow","Red")
    $color        = $actionColors[$finalAction]

    Write-Host ("Routing to agent: {0}" -f $agentName) -ForegroundColor Cyan
    $threshLabel = if ($customThresholds) { "customer-specific" } else { "default" }
    Write-Host ("  Thresholds: Action1={0}  Action2={1}  Action3={2}  [{3}]" -f $thresholds.Action1, $thresholds.Action2, $thresholds.Action3, $threshLabel) -ForegroundColor White

    Write-Host ("  Avg used  : {0:F4} ({1})" -f $avgUsed, $avgLabel) -ForegroundColor White
    Write-Host ("  Agent     : {0} ({1})" -f $agentName, $agentMode) -ForegroundColor White

    if ($overrideApplied) {
        Write-Host ("  Base      : {0} — {1}" -f $baseAction, $actionNames[$baseAction]) -ForegroundColor DarkGray
        Write-Host ("  OVERRIDE  : {0}" -f $actionReason) -ForegroundColor Red
    }

    Write-Host ("  Decision  : {0} — {1}" -f $finalAction, $actionNames[$finalAction]) -ForegroundColor $color

    if ($redCount -gt 0)    { Write-Host ("  Red       : {0} signals" -f $redCount)    -ForegroundColor Red    }
    if ($yellowCount -gt 0) { Write-Host ("  Yellow    : {0} signals" -f $yellowCount) -ForegroundColor Yellow }

    Write-Host ""

    return [PSCustomObject]@{
        CustomerID        = $CustomerID
        AgentName         = $agentName
        AgentMode         = $agentMode
        Signals           = $NormalisedSignals
        SimpleAvg         = [Math]::Round($simpleAvg, 4)
        WeightedAvg       = if ($WeightedAvg -ge 0) { [Math]::Round($WeightedAvg, 4) } else { $null }
        AvgUsed           = [Math]::Round($avgUsed, 4)
        BaseAction        = $baseAction
        FinalAction       = $finalAction
        ActionName        = $actionNames[$finalAction]
        ActionReason      = $actionReason
        OverrideApplied   = $overrideApplied
        RedSignalCount    = $redCount
        YellowSignalCount = $yellowCount
        Thresholds        = $thresholds
        CustomThresholds  = $customThresholds
        Timestamp         = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# ============================================================
# GET-VBAFCENTERACTIONEXPLANATION
# ============================================================
function Get-VBAFCenterActionExplanation {
    param([Parameter(Mandatory)] [object] $RouteResult)

    $actionNames  = @("Monitor","Reassign","Reroute","Escalate")
    $actionColors = @("Green","Yellow","DarkYellow","Red")
    $action       = $RouteResult.FinalAction
    $color        = $actionColors[$action]

    Write-Host ""
    Write-Host ("Action Explanation: {0}" -f $RouteResult.CustomerID) -ForegroundColor Cyan
    Write-Host ("  Decision   : {0} — {1}" -f $action, $actionNames[$action]) -ForegroundColor $color
    Write-Host ("  Reason     : {0}"        -f $RouteResult.ActionReason)      -ForegroundColor White
    Write-Host ""
    Write-Host "  Signal average:" -ForegroundColor DarkGray

    if ($null -ne $RouteResult.WeightedAvg) {
        Write-Host ("    Simple avg   : {0:F4}" -f $RouteResult.SimpleAvg)   -ForegroundColor DarkGray
        Write-Host ("    Weighted avg : {0:F4}  (used for decision)" -f $RouteResult.WeightedAvg) -ForegroundColor White
    } else {
        Write-Host ("    Simple avg   : {0:F4}  (used for decision)" -f $RouteResult.SimpleAvg) -ForegroundColor White
    }

    Write-Host ""
    Write-Host ("  Thresholds ({0}):" -f (if ($RouteResult.CustomThresholds) { "customer-specific" } else { "default" })) -ForegroundColor DarkGray
    Write-Host ("    Reassign above : {0}" -f $RouteResult.Thresholds.Action1) -ForegroundColor DarkGray
    Write-Host ("    Reroute above  : {0}" -f $RouteResult.Thresholds.Action2) -ForegroundColor DarkGray
    Write-Host ("    Escalate above : {0}" -f $RouteResult.Thresholds.Action3) -ForegroundColor DarkGray

    if ($RouteResult.OverrideApplied) {
        Write-Host ""
        Write-Host "  Override applied:" -ForegroundColor Red
        Write-Host ("    Base action : {0} — {1}" -f $RouteResult.BaseAction, $actionNames[$RouteResult.BaseAction]) -ForegroundColor DarkGray
        Write-Host ("    Raised to   : {0} — {1}" -f $RouteResult.FinalAction, $actionNames[$RouteResult.FinalAction]) -ForegroundColor Red
        Write-Host ("    Red signals : {0}" -f $RouteResult.RedSignalCount)    -ForegroundColor Red
        Write-Host ("    Yellow      : {0}" -f $RouteResult.YellowSignalCount) -ForegroundColor Yellow
    }
    Write-Host ""
}

# ============================================================
# GET-VBAFCENTERROUTESTATUS
# ============================================================
function Get-VBAFCenterRouteStatus {
    Write-Host ""
    Write-Host "Agent Router Status:" -ForegroundColor Cyan
    if ($script:LoadedAgents.Count -eq 0) {
        Write-Host "  No agents loaded — using rule-based fallback." -ForegroundColor Yellow
    } else {
        Write-Host ("  {0,-25} {1,-20} {2}" -f "Agent","Loaded At","Description") -ForegroundColor Yellow
        Write-Host ("  {0}" -f ("-" * 65)) -ForegroundColor DarkGray
        foreach ($key in $script:LoadedAgents.Keys) {
            $a = $script:LoadedAgents[$key]
            Write-Host ("  {0,-25} {1,-20} {2}" -f $key, $a.LoadedAt, $a.Description) -ForegroundColor White
        }
    }
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host "VBAF-Center Phase 5 loaded  [Agent Router + Phase 14/15/17]" -ForegroundColor Cyan
Write-Host "  Invoke-VBAFCenterRoute          — route signals to agent"       -ForegroundColor White
Write-Host "  Register-VBAFCenterAgent        — register a trained agent"     -ForegroundColor White
Write-Host "  Get-VBAFCenterRouteStatus       — show loaded agents"           -ForegroundColor White
Write-Host "  Get-VBAFCenterActionExplanation — explain why action was chosen" -ForegroundColor White
Write-Host ""

