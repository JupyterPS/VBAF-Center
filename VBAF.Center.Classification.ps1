#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 2 — Problem Classification
.DESCRIPTION
    Automatically classifies customer problems into categories
    and maps them to the correct VBAF agent family.

    Functions:
      Get-VBAFCenterClassification  — classify a customer problem
      Get-VBAFCenterAgentMap        — show all available agent mappings
      Set-VBAFCenterAgentMap        — add a custom agent mapping
#>

# ============================================================
# AGENT MAP — maps problem categories to VBAF agents
# ============================================================
$script:VBAFCenterAgentMap = @{

    # IT Infrastructure
    "IT-INFRASTRUCTURE-HEALING"    = @{ Agent="SelfHealing";           Phase=14; Description="Self-healing Windows infrastructure" }
    "IT-INFRASTRUCTURE-DASHBOARD"  = @{ Agent="Dashboard";             Phase=15; Description="Intelligent dashboard management" }
    "IT-INFRASTRUCTURE-CAPACITY"   = @{ Agent="CapacityPlanner";       Phase=19; Description="Resource capacity planning" }
    "IT-INFRASTRUCTURE-BACKUP"     = @{ Agent="BackupOptimizer";       Phase=24; Description="Backup optimisation" }
    "IT-INFRASTRUCTURE-ENERGY"     = @{ Agent="EnergyOptimizer";       Phase=25; Description="Energy consumption optimisation" }
    "IT-INFRASTRUCTURE-MULTISITE"  = @{ Agent="MultiSiteCoordinator";  Phase=26; Description="Multi-site coordination" }

    # IT Security
    "IT-SECURITY-ANOMALY"          = @{ Agent="AnomalyDetector";       Phase=18; Description="Anomaly detection" }
    "IT-SECURITY-BEHAVIOR"         = @{ Agent="UserBehaviorAnalytics"; Phase=22; Description="User behavior analytics" }
    "IT-SECURITY-COMPLIANCE"       = @{ Agent="ComplianceReporter";    Phase=21; Description="Compliance reporting" }

    # IT Operations
    "IT-OPERATIONS-INCIDENT"       = @{ Agent="IncidentResponder";     Phase=20; Description="Incident response" }
    "IT-OPERATIONS-PATCH"          = @{ Agent="PatchIntelligence";     Phase=23; Description="Patch intelligence" }
    "IT-OPERATIONS-FEDERATED"      = @{ Agent="FederatedLearning";     Phase=16; Description="Federated learning across sites" }
    "IT-OPERATIONS-CLOUD"          = @{ Agent="CloudBridge";           Phase=17; Description="Cloud bridge management" }
    "IT-OPERATIONS-AUTOPILOT"      = @{ Agent="AutoPilot";             Phase=27; Description="Full enterprise autopilot" }

    # Business Operations
    "BUSINESS-LOGISTICS-FLEET"     = @{ Agent="FleetDispatch";         Phase=28; Description="Fleet dispatch optimisation" }

    # Future
    "BUSINESS-HEALTH"              = @{ Agent="HealthcareMonitor";     Phase=29; Description="Healthcare patient flow and resource management" }
    "BUSINESS-FINANCE"             = @{ Agent="SecurityMonitor";       Phase=30; Description="Financial security and fraud detection" }
    "BUSINESS-MANUFACTURING"       = @{ Agent="PredictiveMaintenance"; Phase=31; Description="Manufacturing predictive maintenance" }
    "BUSINESS-RETAIL"              = @{ Agent="SupplyChain";           Phase=32; Description="Retail supply chain optimisation" }
}

# ============================================================
# KEYWORD MAP — maps keywords to classification codes
# ============================================================
$script:KeywordMap = @{
    # IT Infrastructure keywords
    "crash"       = "IT-INFRASTRUCTURE-HEALING"
    "healing"     = "IT-INFRASTRUCTURE-HEALING"
    "restart"     = "IT-INFRASTRUCTURE-HEALING"
    "dashboard"   = "IT-INFRASTRUCTURE-DASHBOARD"
    "capacity"    = "IT-INFRASTRUCTURE-CAPACITY"
    "resource"    = "IT-INFRASTRUCTURE-CAPACITY"
    "memory"      = "IT-INFRASTRUCTURE-CAPACITY"
    "backup"      = "IT-INFRASTRUCTURE-BACKUP"
    "energy"      = "IT-INFRASTRUCTURE-ENERGY"
    "power"       = "IT-INFRASTRUCTURE-ENERGY"
    "multisite"   = "IT-INFRASTRUCTURE-MULTISITE"
    "sites"       = "IT-INFRASTRUCTURE-MULTISITE"

    # IT Security keywords
    "anomaly"     = "IT-SECURITY-ANOMALY"
    "unusual"     = "IT-SECURITY-ANOMALY"
    "threat"      = "IT-SECURITY-ANOMALY"
    "behavior"    = "IT-SECURITY-BEHAVIOR"
    "behaviour"   = "IT-SECURITY-BEHAVIOR"
    "user"        = "IT-SECURITY-BEHAVIOR"
    "compliance"  = "IT-SECURITY-COMPLIANCE"
    "gdpr"        = "IT-SECURITY-COMPLIANCE"
    "audit"       = "IT-SECURITY-COMPLIANCE"

    # IT Operations keywords
    "incident"    = "IT-OPERATIONS-INCIDENT"
    "outage"      = "IT-OPERATIONS-INCIDENT"
    "patch"       = "IT-OPERATIONS-PATCH"
    "update"      = "IT-OPERATIONS-PATCH"
    "cloud"       = "IT-OPERATIONS-CLOUD"
    "azure"       = "IT-OPERATIONS-CLOUD"
    "aws"         = "IT-OPERATIONS-CLOUD"
    "federated"   = "IT-OPERATIONS-FEDERATED"
    "autopilot"   = "IT-OPERATIONS-AUTOPILOT"

    # Business keywords
    "fleet"       = "BUSINESS-LOGISTICS-FLEET"
    "truck"       = "BUSINESS-LOGISTICS-FLEET"
    "dispatch"    = "BUSINESS-LOGISTICS-FLEET"
    "delivery"    = "BUSINESS-LOGISTICS-FLEET"
    "logistics"   = "BUSINESS-LOGISTICS-FLEET"
    "hospital"    = "BUSINESS-HEALTH"
    "patient"     = "BUSINESS-HEALTH"
    "healthcare"  = "BUSINESS-HEALTH"
    "finance"     = "BUSINESS-FINANCE"
    "fraud"       = "BUSINESS-FINANCE"
    "trading"     = "BUSINESS-FINANCE"
    "factory"     = "BUSINESS-MANUFACTURING"
    "machinery"   = "BUSINESS-MANUFACTURING"
    "production"  = "BUSINESS-MANUFACTURING"
    "maintenance" = "BUSINESS-MANUFACTURING"
    "retail"      = "BUSINESS-RETAIL"
    "inventory"   = "BUSINESS-RETAIL"
    "supply"      = "BUSINESS-RETAIL"
}

# ============================================================
# GET-VBAFCENTERCLASSIFICATION
# ============================================================
function Get-VBAFCenterClassification {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [string] $ProblemText = ""
    )

    # Load customer profile
    $profilePath = Join-Path $env:USERPROFILE "VBAFCenter\customers\$CustomerID.json"
    if (-not (Test-Path $profilePath)) {
        Write-Host "Customer not found: $CustomerID" -ForegroundColor Red
        Write-Host "Run New-VBAFCenterCustomer first." -ForegroundColor Yellow
        return $null
    }

    $profile = Get-Content $profilePath -Raw | ConvertFrom-Json

    # Use profile problem if no text provided
    if ($ProblemText -eq "") { $ProblemText = $profile.Problem }

    # Classify by keyword matching
    $classificationCode = $null
    $matchedKeyword     = ""
    $words = $ProblemText.ToLower() -split "\s+"

    foreach ($word in $words) {
        if ($script:KeywordMap.ContainsKey($word)) {
            $classificationCode = $script:KeywordMap[$word]
            $matchedKeyword     = $word
            break
        }
    }

    # Also check BusinessType from profile
    if ($null -eq $classificationCode) {
        $bt = $profile.BusinessType.ToLower()
        if ($script:KeywordMap.ContainsKey($bt)) {
            $classificationCode = $script:KeywordMap[$bt]
            $matchedKeyword     = $bt
        }
    }

    # Default if nothing matched
    if ($null -eq $classificationCode) {
        $classificationCode = "IT-OPERATIONS-AUTOPILOT"
        $matchedKeyword     = "default"
    }

    $mapping = $script:VBAFCenterAgentMap[$classificationCode]

    $result = @{
        CustomerID          = $CustomerID
        ProblemText         = $ProblemText
        ClassificationCode  = $classificationCode
        MatchedKeyword      = $matchedKeyword
        RecommendedAgent    = $mapping.Agent
        Phase               = $mapping.Phase
        Description         = $mapping.Description
    }

    Write-Host ""
    Write-Host "Problem Classification:" -ForegroundColor Cyan
    Write-Host ("  Customer     : {0}" -f $CustomerID)                -ForegroundColor White
    Write-Host ("  Problem      : {0}" -f $ProblemText)               -ForegroundColor White
    Write-Host ("  Keyword      : {0}" -f $matchedKeyword)            -ForegroundColor Yellow
    Write-Host ("  Class        : {0}" -f $classificationCode)        -ForegroundColor Yellow
    Write-Host ("  Agent        : {0}" -f $mapping.Agent)             -ForegroundColor Green
    Write-Host ("  Phase        : {0}" -f $mapping.Phase)             -ForegroundColor White
    Write-Host ("  Description  : {0}" -f $mapping.Description)       -ForegroundColor White

    if ($mapping.Phase -eq 0) {
        Write-Host ""
        Write-Host "  NOTE: No standard agent available for this domain." -ForegroundColor Yellow
        Write-Host "  A custom pillar needs to be built (see Tutorial 13)." -ForegroundColor Yellow
    }

    Write-Host ""
    return $result
}

# ============================================================
# GET-VBAFCENTERAGENTMAP
# ============================================================
function Get-VBAFCenterAgentMap {

    Write-Host ""
    Write-Host "VBAF-Center Agent Map:" -ForegroundColor Cyan
    Write-Host ("  {0,-40} {1,-25} {2}" -f "Classification", "Agent", "Phase") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 75)) -ForegroundColor DarkGray

    foreach ($key in ($script:VBAFCenterAgentMap.Keys | Sort-Object)) {
        $m = $script:VBAFCenterAgentMap[$key]
        $color = if ($m.Phase -eq 0) { "Gray" } else { "White" }
        Write-Host ("  {0,-40} {1,-25} {2}" -f $key, $m.Agent, $m.Phase) -ForegroundColor $color
    }
    Write-Host ""
}

# ============================================================
# SET-VBAFCENTERAGENTMAP
# ============================================================
function Set-VBAFCenterAgentMap {
    param(
        [Parameter(Mandatory)] [string] $ClassificationCode,
        [Parameter(Mandatory)] [string] $Agent,
        [Parameter(Mandatory)] [string] $Description,
        [int]                           $Phase = 0
    )

    $script:VBAFCenterAgentMap[$ClassificationCode] = @{
        Agent       = $Agent
        Phase       = $Phase
        Description = $Description
    }

    Write-Host "Agent map updated: $ClassificationCode -> $Agent" -ForegroundColor Green
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host "VBAF-Center Phase 2 loaded  [Problem Classification]" -ForegroundColor Cyan
Write-Host "  Get-VBAFCenterClassification  — classify a problem"  -ForegroundColor White
Write-Host "  Get-VBAFCenterAgentMap        — show agent mappings" -ForegroundColor White
Write-Host "  Set-VBAFCenterAgentMap        — add custom mapping"  -ForegroundColor White
Write-Host ""