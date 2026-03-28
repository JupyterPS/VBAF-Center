#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 7 — Customer Onboarding UI
.DESCRIPTION
    Interactive console UI that walks a new customer through
    the complete VBAF-Center setup in one session.
    Runs all Phase 1-6 setup steps in the correct order.

    Functions:
      Start-VBAFCenterOnboarding  — full interactive setup wizard
      Show-VBAFCenterSummary      — show complete customer setup
#>

# ============================================================
# HELPER
# ============================================================
function Read-VBAFInput {
    param([string]$Prompt, [string]$Default = "")
    if ($Default -ne "") {
        Write-Host ("  {0} [{1}]: " -f $Prompt, $Default) -NoNewline -ForegroundColor Yellow
    } else {
        Write-Host ("  {0}: " -f $Prompt) -NoNewline -ForegroundColor Yellow
    }
    $input = Read-Host
    if ($input -eq "" -and $Default -ne "") { return $Default }
    return $input
}

function Write-VBAFStep {
    param([int]$Step, [int]$Total, [string]$Title)
    Write-Host ""
    Write-Host ("  ─── Step {0}/{1}: {2} ───" -f $Step, $Total, $Title) -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================
# START-VBAFCENTERONBOARDING
# ============================================================
function Start-VBAFCenterOnboarding {

    Write-Host ""
    Write-Host "╔═════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║       VBAF-Center — Customer Onboarding Wizard      ║" -ForegroundColor Cyan
    Write-Host "║       Set up once. Run forever.                     ║" -ForegroundColor Cyan
    Write-Host "╚═════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  This wizard will guide you through 6 setup steps."   -ForegroundColor White
    Write-Host "  Estimated time: 5-10 minutes."                        -ForegroundColor White
    Write-Host ""
    Write-Host "  Press ENTER to start..." -ForegroundColor DarkGray
    Read-Host | Out-Null

    # ── STEP 1: Customer Profile ──────────────────────────────
    Write-VBAFStep -Step 1 -Total 6 -Title "Customer Profile"

    $customerID   = Read-VBAFInput "Customer ID (no spaces)"
    $companyName  = Read-VBAFInput "Company name"
    $country      = Read-VBAFInput "Country" "Denmark"
    $businessType = Read-VBAFInput "Business type (e.g. Logistics, Healthcare, IT)"
    $problem      = Read-VBAFInput "Describe the problem in one sentence"
    $contact      = Read-VBAFInput "Contact email"

    # ── STEP 2: Problem Classification ───────────────────────
    Write-VBAFStep -Step 2 -Total 6 -Title "Problem Classification"

    # Auto-classify
    $words = $problem.ToLower() -split "\s+"
    $keywordMap = @{
        "fleet"="FleetDispatch"; "truck"="FleetDispatch"; "dispatch"="FleetDispatch"
        "logistics"="FleetDispatch"; "delivery"="FleetDispatch"
        "server"="SelfHealing"; "crash"="SelfHealing"; "healing"="SelfHealing"
        "capacity"="CapacityPlanner"; "resource"="CapacityPlanner"
        "energy"="EnergyOptimizer"; "power"="EnergyOptimizer"
        "anomaly"="AnomalyDetector"; "unusual"="AnomalyDetector"
        "incident"="IncidentResponder"; "outage"="IncidentResponder"
        "patch"="PatchIntelligence"; "update"="PatchIntelligence"
        "compliance"="ComplianceReporter"; "gdpr"="ComplianceReporter"
        "backup"="BackupOptimizer"
    }

    $agentName = "AutoPilot"
    foreach ($word in $words) {
        if ($keywordMap.ContainsKey($word)) {
            $agentName = $keywordMap[$word]
            break
        }
    }

    Write-Host ("  Auto-classified: {0}" -f $agentName) -ForegroundColor Green
    $confirm  = Read-VBAFInput "Accept this agent? (Y/N)" "Y"
    if ($confirm.ToUpper() -eq "N") {
        Write-Host "  Available agents:" -ForegroundColor Yellow
        Write-Host "  FleetDispatch, SelfHealing, CapacityPlanner, EnergyOptimizer" -ForegroundColor White
        Write-Host "  AnomalyDetector, IncidentResponder, PatchIntelligence" -ForegroundColor White
        Write-Host "  ComplianceReporter, BackupOptimizer, AutoPilot" -ForegroundColor White
        $agentName = Read-VBAFInput "Enter agent name"
    }

    # ── STEP 3: Signal Configuration ─────────────────────────
    Write-VBAFStep -Step 3 -Total 6 -Title "Signal Configuration"

    Write-Host "  Configure up to 4 signals. Press ENTER to skip a signal." -ForegroundColor White
    Write-Host ""

    $signals = @()
    for ($i = 1; $i -le 4; $i++) {
        Write-Host ("  Signal {0}:" -f $i) -ForegroundColor Yellow
        $sigName = Read-VBAFInput "  Signal name (or ENTER to skip)"
        if ($sigName -eq "") { break }
        $sigSource = Read-VBAFInput "  Source type (REST/WMI/CSV/Manual/Simulated)" "Simulated"
        $sigMin    = Read-VBAFInput "  Raw minimum value" "0"
        $sigMax    = Read-VBAFInput "  Raw maximum value" "100"
        $sigURL    = ""
        if ($sigSource.ToUpper() -eq "REST") {
            $sigURL = Read-VBAFInput "  REST endpoint URL"
        }
        $signals += @{
            Index  = "Signal$i"
            Name   = $sigName
            Source = $sigSource
            Min    = [double]$sigMin
            Max    = [double]$sigMax
            URL    = $sigURL
        }
        Write-Host ("  Signal {0} configured: {1} ({2})" -f $i, $sigName, $sigSource) -ForegroundColor Green
        Write-Host ""
    }

    # ── STEP 4: Normalisation Method ─────────────────────────
    Write-VBAFStep -Step 4 -Total 6 -Title "Normalisation Method"

    Write-Host "  MinMax    — simple 0-100% scale (recommended)" -ForegroundColor White
    Write-Host "  Standard  — zero mean, unit variance" -ForegroundColor White
    Write-Host "  Robust    — median/IQR, handles outliers" -ForegroundColor White
    Write-Host ""
    $normMethod = Read-VBAFInput "Normalisation method" "MinMax"

    # ── STEP 5: Action Map ────────────────────────────────────
    Write-VBAFStep -Step 5 -Total 6 -Title "Action Map"

    Write-Host "  Define what each action means in YOUR business language." -ForegroundColor White
    Write-Host ""

    $actions = @()
    $defaultNames    = @("Monitor","Reassign","Reroute","Escalate")
    $defaultCommands = @(
        "No action needed — continue monitoring",
        "Reassign resource to pending task",
        "Switch to alternative approach",
        "Emergency — deploy all resources"
    )

    for ($i = 0; $i -le 3; $i++) {
        Write-Host ("  Action {0}:" -f $i) -ForegroundColor Yellow
        $aName    = Read-VBAFInput "  Name" $defaultNames[$i]
        $aCommand = Read-VBAFInput "  Command (business language)" $defaultCommands[$i]
        $actions += @{ Number=$i; Name=$aName; Command=$aCommand }
        Write-Host ""
    }

    # ── STEP 6: Schedule ──────────────────────────────────────
    Write-VBAFStep -Step 6 -Total 6 -Title "Check Schedule"

    Write-Host "  How often should VBAF-Center check your signals?" -ForegroundColor White
    Write-Host ""
    $intervalMinutes = Read-VBAFInput "Check interval in minutes" "10"

    # ── SAVE EVERYTHING ───────────────────────────────────────
    Write-Host ""
    Write-Host "  Saving configuration..." -ForegroundColor Yellow

    $storePath = Join-Path $env:USERPROFILE "VBAFCenter"

    # Save profile
    $profile = @{
        CustomerID   = $customerID
        CompanyName  = $companyName
        Country      = $country
        BusinessType = $businessType
        Problem      = $problem
        Agent        = $agentName
        Contact      = $contact
        CreatedDate  = (Get-Date).ToString("yyyy-MM-dd")
        Status       = "Active"
        Version      = "1.0"
    }
    $custPath = Join-Path $storePath "customers"
    if (-not (Test-Path $custPath)) { New-Item -ItemType Directory -Path $custPath -Force | Out-Null }
    $profile | ConvertTo-Json | Set-Content "$custPath\$customerID.json" -Encoding UTF8

    # Save signals
    $sigPath = Join-Path $storePath "signals"
    if (-not (Test-Path $sigPath)) { New-Item -ItemType Directory -Path $sigPath -Force | Out-Null }
    foreach ($s in $signals) {
        $sigConfig = @{
            CustomerID  = $customerID
            SignalName  = $s.Name
            SignalIndex = $s.Index
            SourceType  = $s.Source
            SourceURL   = $s.URL
            RawMin      = $s.Min
            RawMax      = $s.Max
        }
        $sigConfig | ConvertTo-Json | Set-Content "$sigPath\$customerID-$($s.Index).json" -Encoding UTF8
    }

    # Save action map
    $actPath = Join-Path $storePath "actions"
    if (-not (Test-Path $actPath)) { New-Item -ItemType Directory -Path $actPath -Force | Out-Null }
    $lines = @()
    foreach ($a in $actions) { $lines += "$($a.Number)|$($a.Name)|$($a.Command)" }
    Set-Content "$actPath\$customerID-actions.txt" -Value $lines -Encoding UTF8

    # Save schedule
    $schedPath = Join-Path $storePath "schedules"
    if (-not (Test-Path $schedPath)) { New-Item -ItemType Directory -Path $schedPath -Force | Out-Null }
    @{ CustomerID=$customerID; IntervalMinutes=[int]$intervalMinutes; NormMethod=$normMethod; Active=$true } |
        ConvertTo-Json | Set-Content "$schedPath\$customerID-schedule.json" -Encoding UTF8

    # ── SUMMARY ───────────────────────────────────────────────
    Write-Host ""
    Write-Host "╔═════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║       Onboarding Complete!                          ║" -ForegroundColor Green
    Write-Host "╠═════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host ("║  Customer   : {0,-38}║" -f $companyName)       -ForegroundColor White
    Write-Host ("║  Agent      : {0,-38}║" -f $agentName)         -ForegroundColor White
    Write-Host ("║  Signals    : {0,-38}║" -f $signals.Count)     -ForegroundColor White
    Write-Host ("║  Schedule   : every {0} minutes{1,-28}║" -f $intervalMinutes, "") -ForegroundColor White
    Write-Host "╠═════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║  Next step: run the Welcome Center                  ║" -ForegroundColor Cyan
    Write-Host ("║  Invoke-VBAFCenterRun -CustomerID ""{0}""" -f $customerID) -ForegroundColor Cyan
    Write-Host "╚═════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

    return @{ CustomerID=$customerID; Agent=$agentName; Signals=$signals.Count }
}

# ============================================================
# SHOW-VBAFCENTERSUMMARY
# ============================================================
function Show-VBAFCenterSummary {
    param([Parameter(Mandatory)] [string] $CustomerID)

    $storePath = Join-Path $env:USERPROFILE "VBAFCenter"

    Write-Host ""
    Write-Host "VBAF-Center Setup Summary: $CustomerID" -ForegroundColor Cyan
    Write-Host ("  {0}" -f ("-" * 50)) -ForegroundColor DarkGray

    $profPath = "$storePath\customers\$CustomerID.json"
    if (Test-Path $profPath) {
        $p = Get-Content $profPath -Raw | ConvertFrom-Json
        Write-Host ("  Company  : {0}" -f $p.CompanyName)   -ForegroundColor White
        Write-Host ("  Agent    : {0}" -f $p.Agent)         -ForegroundColor White
        Write-Host ("  Problem  : {0}" -f $p.Problem)       -ForegroundColor White
        Write-Host ("  Status   : {0}" -f $p.Status)        -ForegroundColor Green
    }

    $signals = Get-ChildItem "$storePath\signals" -Filter "$CustomerID-*.json" -ErrorAction SilentlyContinue
    Write-Host ("  Signals  : {0} configured" -f $signals.Count) -ForegroundColor White

    $actPath = "$storePath\actions\$CustomerID-actions.txt"
    if (Test-Path $actPath) {
        Write-Host "  Actions  : configured" -ForegroundColor White
    }

    $schedPath = "$storePath\schedules\$CustomerID-schedule.json"
    if (Test-Path $schedPath) {
        $s = Get-Content $schedPath -Raw | ConvertFrom-Json
        Write-Host ("  Schedule : every {0} minutes" -f $s.IntervalMinutes) -ForegroundColor White
    }

    Write-Host ""
}

Write-Host "VBAF-Center Phase 7 loaded  [Customer Onboarding UI]"    -ForegroundColor Cyan
Write-Host "  Start-VBAFCenterOnboarding  — full setup wizard"        -ForegroundColor White
Write-Host "  Show-VBAFCenterSummary      — show customer setup"      -ForegroundColor White
Write-Host ""
