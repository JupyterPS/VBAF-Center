#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 5 — Agent Router
.DESCRIPTION
    Takes normalised signals and routes them to the correct
    trained VBAF agent. Returns the recommended action (0-3).

    Functions:
      Invoke-VBAFCenterRoute    — send signals to correct agent
      Get-VBAFCenterRouteStatus — show all loaded agents
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
# INVOKE-VBAFCENTERROUTE
# ============================================================
function Invoke-VBAFCenterRoute {
    param(
        [Parameter(Mandatory)] [string]   $CustomerID,
        [Parameter(Mandatory)] [double[]] $NormalisedSignals,
        [string] $AgentOverride = ""
    )

    # Load customer profile to find agent
    $profilePath = Join-Path $env:USERPROFILE "VBAFCenter\customers\$CustomerID.json"
    if (-not (Test-Path $profilePath)) {
        Write-Host "Customer not found: $CustomerID" -ForegroundColor Red
        return $null
    }

    $profile   = Get-Content $profilePath -Raw | ConvertFrom-Json
    $agentName = if ($AgentOverride -ne "") { $AgentOverride } else { $profile.Agent }

    Write-Host ""
    Write-Host "Routing to agent: $agentName" -ForegroundColor Cyan
    Write-Host ("  Customer : {0}" -f $CustomerID)                                          -ForegroundColor White
    Write-Host ("  Signals  : [{0}]" -f ($NormalisedSignals -join ", "))                   -ForegroundColor White

    # Check if agent is loaded
    if ($script:LoadedAgents.ContainsKey($agentName)) {

        # Use real trained agent
        $agent  = $script:LoadedAgents[$agentName].Agent
        $action = $agent.Act($NormalisedSignals)

        Write-Host ("  Agent    : {0} (trained)" -f $agentName) -ForegroundColor Green
        Write-Host ("  Action   : {0}" -f $action)              -ForegroundColor Yellow

    } else {

        # Agent not loaded — use rule-based fallback
        Write-Host ("  Agent    : {0} (rule-based fallback)" -f $agentName) -ForegroundColor Yellow

        # Simple rule: average signal level determines action
        [double] $avg = 0.0
        foreach ($s in $NormalisedSignals) { $avg += $s }
        $avg /= $NormalisedSignals.Length

        $action = if      ($avg -lt 0.25) { 0 }
                  elseif  ($avg -lt 0.50) { 1 }
                  elseif  ($avg -lt 0.75) { 2 }
                  else                    { 3 }

        Write-Host ("  Action   : {0} (from avg signal {1:F2})" -f $action, $avg) -ForegroundColor Yellow
    }

    $actionNames = @("Monitor", "Reassign", "Reroute", "Escalate")
    Write-Host ("  Decision : {0} — {1}" -f $action, $actionNames[$action]) -ForegroundColor Green
    Write-Host ""

    return @{
        CustomerID = $CustomerID
        AgentName  = $agentName
        Signals    = $NormalisedSignals
        Action     = $action
        ActionName = $actionNames[$action]
        Timestamp  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# ============================================================
# GET-VBAFCENTERROUTESTATUS
# ============================================================
function Get-VBAFCenterRouteStatus {

    Write-Host ""
    Write-Host "Agent Router Status:" -ForegroundColor Cyan

    if ($script:LoadedAgents.Count -eq 0) {
        Write-Host "  No agents loaded yet." -ForegroundColor Yellow
        Write-Host "  Using rule-based fallback for all routes." -ForegroundColor Yellow
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
Write-Host "VBAF-Center Phase 5 loaded  [Agent Router]"              -ForegroundColor Cyan
Write-Host "  Invoke-VBAFCenterRoute      — route signals to agent"   -ForegroundColor White
Write-Host "  Register-VBAFCenterAgent    — register a trained agent" -ForegroundColor White
Write-Host "  Get-VBAFCenterRouteStatus   — show loaded agents"       -ForegroundColor White
Write-Host ""

