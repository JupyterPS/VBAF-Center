#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 7 — Customer Onboarding UI
.DESCRIPTION
    Interactive console UI that walks a new customer through
    the complete VBAF-Center setup in one session.
    Runs all Phase 1-6 setup steps in the correct order.

    Phase 14 — Signal thresholds (GoodBelow / BadAbove) per signal
    Phase 15 — Signal weights (1-5) per signal
    Phase 17 — Customer-specific action thresholds

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
    Write-Host ("  --- Step {0}/{1}: {2} ---" -f $Step, $Total, $Title) -ForegroundColor Cyan
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
    Write-Host "  This wizard will guide you through 7 setup steps."   -ForegroundColor White
    Write-Host "  Estimated time: 10-15 minutes."                       -ForegroundColor White
    Write-Host ""
    Write-Host "  Press ENTER to start..." -ForegroundColor DarkGray
    Read-Host | Out-Null

    # ── STEP 1: Customer Profile ──────────────────────────────
    Write-VBAFStep -Step 1 -Total 7 -Title "Customer Profile"

    $customerID   = Read-VBAFInput "Customer ID (no spaces, no special characters)"
    $companyName  = Read-VBAFInput "Company name"
    $country      = Read-VBAFInput "Country" "Denmark"
    $businessType = Read-VBAFInput "Business type (e.g. Logistics, Healthcare, IT)"
    $problem      = Read-VBAFInput "Describe the problem in one sentence"
    $contact      = Read-VBAFInput "Contact email"

    # ── STEP 2: Problem Classification ───────────────────────
    Write-VBAFStep -Step 2 -Total 7 -Title "Problem Classification"

    $words = $problem.ToLower() -split "\s+"
    $keywordMap = @{
        "fleet"="FleetDispatch"; "truck"="FleetDispatch"; "dispatch"="FleetDispatch"
        "logistics"="FleetDispatch"; "delivery"="FleetDispatch"; "transport"="FleetDispatch"
        "server"="SelfHealing"; "crash"="SelfHealing"; "healing"="SelfHealing"
        "capacity"="CapacityPlanner"; "resource"="CapacityPlanner"
        "energy"="EnergyOptimizer"; "power"="EnergyOptimizer"
        "anomaly"="AnomalyDetector"; "unusual"="AnomalyDetector"
        "incident"="IncidentResponder"; "outage"="IncidentResponder"
        "patch"="PatchIntelligence"; "update"="PatchIntelligence"
        "compliance"="ComplianceReporter"; "gdpr"="ComplianceReporter"
        "backup"="BackupOptimizer"
        "health"="HealthcareMonitor"; "patient"="HealthcareMonitor"
        "manufacturing"="PredictiveMaintenance"; "machine"="PredictiveMaintenance"
        "retail"="SupplyChain"; "supply"="SupplyChain"; "stock"="SupplyChain"
        "fraud"="SecurityMonitor"; "finance"="SecurityMonitor"
    }

    $agentName = "AutoPilot"
    foreach ($word in $words) {
        if ($keywordMap.ContainsKey($word)) {
            $agentName = $keywordMap[$word]
            break
        }
    }

    Write-Host ("  Auto-classified: {0}" -f $agentName) -ForegroundColor Green
    $confirm = Read-VBAFInput "Accept this agent? (Y/N)" "Y"
    if ($confirm.ToUpper() -eq "N") {
        Write-Host ""
        Write-Host "  Available agents:" -ForegroundColor Yellow
        Write-Host "  FleetDispatch, SelfHealing, HealthcareMonitor"          -ForegroundColor White
        Write-Host "  PredictiveMaintenance, SupplyChain, SecurityMonitor"    -ForegroundColor White
        Write-Host "  AnomalyDetector, IncidentResponder, ComplianceReporter" -ForegroundColor White
        Write-Host "  BackupOptimizer, EnergyOptimizer, AutoPilot"            -ForegroundColor White
        Write-Host ""
        $agentName = Read-VBAFInput "Enter agent name"
    }

    # ── STEP 3: Signal Configuration (Phase 14/15) ───────────
    Write-VBAFStep -Step 3 -Total 7 -Title "Signal Configuration (with Thresholds and Weights)"

    Write-Host "  Configure up to 10 signals. Press ENTER on signal name to stop." -ForegroundColor White
    Write-Host ""
    Write-Host "  For each signal you will be asked:" -ForegroundColor DarkGray
    Write-Host "  - Name, Source, Min, Max (required)"                            -ForegroundColor DarkGray
    Write-Host "  - GoodBelow / BadAbove — thresholds for Green/Yellow/Red colour" -ForegroundColor DarkGray
    Write-Host "  - Weight 1-5 — how important is this signal"                    -ForegroundColor DarkGray
    Write-Host ""

    $signals = @()
    for ($i = 1; $i -le 10; $i++) {
        Write-Host ("  Signal {0}:" -f $i) -ForegroundColor Yellow
        $sigName = Read-VBAFInput "  Signal name (or ENTER to finish)"
        if ($sigName -eq "") { break }

        $sigSource = Read-VBAFInput "  Source type (REST/WMI/CSV/Manual/Simulated)" "Simulated"
        $sigMin    = Read-VBAFInput "  Raw minimum value" "0"
        $sigMax    = Read-VBAFInput "  Raw maximum value" "100"

        $sigURL = ""
        if ($sigSource.ToUpper() -eq "REST") {
            $sigURL = Read-VBAFInput "  REST endpoint URL"
        }

        # Phase 14 — Thresholds
        Write-Host ""
        Write-Host ("  Thresholds for {0} (Phase 14 — optional, press ENTER to skip):" -f $sigName) -ForegroundColor Cyan
        Write-Host "  Ask customer: 'Hvornaar er I tilfredse?' and 'Hvornaar begynder I at blive bekymrede?'" -ForegroundColor DarkGray
        $goodBelowStr = Read-VBAFInput "  Good below (e.g. 25 means below 25 = Green)" ""
        $badAboveStr  = Read-VBAFInput "  Bad above  (e.g. 40 means above 40 = Red)"   ""

        $goodBelow = if ($goodBelowStr -ne "") { [double]$goodBelowStr } else { -1 }
        $badAbove  = if ($badAboveStr  -ne "") { [double]$badAboveStr  } else { -1 }

        # Phase 15 — Weight
        Write-Host ""
        Write-Host "  Weight (Phase 15 — how important is this signal?):" -ForegroundColor Cyan
        Write-Host "  1=minor context   3=normal   5=critical (drives decisions)" -ForegroundColor DarkGray
        $weightStr = Read-VBAFInput "  Weight (1-5)" "3"
        $weight    = [int]$weightStr
        if ($weight -lt 1) { $weight = 1 }
        if ($weight -gt 5) { $weight = 5 }

        $signals += @{
            Index     = "Signal$i"
            Name      = $sigName
            Source    = $sigSource
            Min       = [double]$sigMin
            Max       = [double]$sigMax
            URL       = $sigURL
            GoodBelow = $goodBelow
            BadAbove  = $badAbove
            Weight    = $weight
        }

        $threshNote = ""
        if ($goodBelow -ge 0 -or $badAbove -ge 0) {
            $threshNote = " | thresholds set"
        }
        Write-Host ("  Signal {0} configured: {1} ({2}) W{3}{4}" -f $i, $sigName, $sigSource, $weight, $threshNote) -ForegroundColor Green
        Write-Host ""
    }

    # ── STEP 4: Normalisation Method ─────────────────────────
    Write-VBAFStep -Step 4 -Total 7 -Title "Normalisation Method"

    Write-Host "  MinMax    — simple 0-100% scale (recommended for logistics)" -ForegroundColor White
    Write-Host "  Standard  — zero mean, unit variance" -ForegroundColor White
    Write-Host "  Robust    — median/IQR, handles outliers" -ForegroundColor White
    Write-Host ""
    $normMethod = Read-VBAFInput "Normalisation method" "MinMax"

    # ── STEP 5: Action Map ────────────────────────────────────
    Write-VBAFStep -Step 5 -Total 7 -Title "Action Map — Customer Language"

    Write-Host "  Define what each action means in YOUR customer's language." -ForegroundColor White
    Write-Host "  Use their words — not English jargon."                      -ForegroundColor White
    Write-Host ""

    $actions = @()
    $defaultNames    = @("Monitor","Reassign","Reroute","Escalate")
    $defaultCommands = @(
        "Alt OK — fortsaet overvaagning",
        "Flyt ledig ressource til naeste opgave",
        "Skift til hurtigere tilgang",
        "Ring til mig nu — det er alvorligt"
    )

    for ($i = 0; $i -le 3; $i++) {
        Write-Host ("  Action {0}:" -f $i) -ForegroundColor Yellow
        $aName    = Read-VBAFInput "  Name" $defaultNames[$i]
        $aCommand = Read-VBAFInput "  Command (their exact words)" $defaultCommands[$i]
        $actions += @{ Number=$i; Name=$aName; Command=$aCommand }
        Write-Host ""
    }

    # ── STEP 6: Action Thresholds (Phase 17) ─────────────────
    Write-VBAFStep -Step 6 -Total 7 -Title "Action Thresholds (Phase 17 — Customer Sensitivity)"

    Write-Host "  Default thresholds: Reassign=0.25  Reroute=0.50  Escalate=0.75" -ForegroundColor White
    Write-Host "  Adjust these to match how sensitive this customer wants to be."   -ForegroundColor White
    Write-Host ""
    Write-Host "  Ask customer:"                                                    -ForegroundColor DarkGray
    Write-Host "  'Hvornaar vil du have en advarsel?'           -> Action1"        -ForegroundColor DarkGray
    Write-Host "  'Hvornaar er det alvorligt nok til handling?' -> Action2"        -ForegroundColor DarkGray
    Write-Host "  'Hvornaar ringer du til nogen uanset tidspunkt?' -> Action3"    -ForegroundColor DarkGray
    Write-Host ""

    $useCustomThresholds = Read-VBAFInput "Set custom thresholds? (Y/N)" "N"
    $action1Threshold = 0.25
    $action2Threshold = 0.50
    $action3Threshold = 0.75

    if ($useCustomThresholds.ToUpper() -eq "Y") {
        $a1 = Read-VBAFInput "  Reassign threshold (0.00-1.00)" "0.25"
        $a2 = Read-VBAFInput "  Reroute threshold  (0.00-1.00)" "0.50"
        $a3 = Read-VBAFInput "  Escalate threshold (0.00-1.00)" "0.75"
        $action1Threshold = [double]$a1
        $action2Threshold = [double]$a2
        $action3Threshold = [double]$a3
        Write-Host ""
        Write-Host ("  Thresholds set: Reassign={0}  Reroute={1}  Escalate={2}" -f $action1Threshold, $action2Threshold, $action3Threshold) -ForegroundColor Green
    } else {
        Write-Host "  Using defaults: 0.25 / 0.50 / 0.75" -ForegroundColor DarkGray
    }

    # ── STEP 7: Schedule ──────────────────────────────────────
    Write-VBAFStep -Step 7 -Total 7 -Title "Check Schedule"

    Write-Host "  How often should VBAF-Center check your signals?" -ForegroundColor White
    Write-Host "  Recommended: 10 minutes for production, 1-3 for testing." -ForegroundColor DarkGray
    Write-Host ""
    $intervalMinutes = Read-VBAFInput "Check interval in minutes" "10"

    # ── SAVE EVERYTHING ───────────────────────────────────────
    Write-Host ""
    Write-Host "  Saving configuration..." -ForegroundColor Yellow

    $storePath = Join-Path $env:USERPROFILE "VBAFCenter"

    # Save customer profile
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
    $profile | ConvertTo-Json -Depth 5 | Set-Content "$custPath\$customerID.json" -Encoding UTF8
    Write-Host "  Customer profile saved." -ForegroundColor Green

    # Save signals — Phase 14/15 included
    $sigPath = Join-Path $storePath "signals"
    if (-not (Test-Path $sigPath)) { New-Item -ItemType Directory -Path $sigPath -Force | Out-Null }
    foreach ($s in $signals) {
        $sigConfig = @{
            CustomerID  = $customerID
            SignalName  = $s.Name
            SignalIndex = $s.Index
            SourceType  = $s.Source
            SourceURL   = $s.URL
            JSONPath    = ""
            CSVPath     = ""
            CSVColumn   = ""
            WMIClass    = ""
            WMIProperty = ""
            RawMin      = $s.Min
            RawMax      = $s.Max
            GoodBelow   = $s.GoodBelow
            BadAbove    = $s.BadAbove
            Weight      = $s.Weight
            Description = ""
            CreatedDate = (Get-Date).ToString("yyyy-MM-dd")
        }
        $sigConfig | ConvertTo-Json -Depth 5 | Set-Content "$sigPath\$customerID-$($s.Index).json" -Encoding UTF8
    }
    Write-Host ("  {0} signal(s) saved." -f $signals.Count) -ForegroundColor Green

    # Save action map
    $actPath = Join-Path $storePath "actions"
    if (-not (Test-Path $actPath)) { New-Item -ItemType Directory -Path $actPath -Force | Out-Null }
    $lines = @()
    foreach ($a in $actions) { $lines += "$($a.Number)|$($a.Name)|$($a.Command)" }
    Set-Content "$actPath\$customerID-actions.txt" -Value $lines -Encoding UTF8
    Write-Host "  Action map saved." -ForegroundColor Green

    # Generate portal token
    $token = -join ((65..90) + (48..57) | Get-Random -Count 6 | ForEach-Object { [char]$_ })

    # Save schedule — Phase 17 thresholds included
    $schedPath = Join-Path $storePath "schedules"
    if (-not (Test-Path $schedPath)) { New-Item -ItemType Directory -Path $schedPath -Force | Out-Null }
    $schedule = @{
        CustomerID        = $customerID
        IntervalMinutes   = [int]$intervalMinutes
        NormMethod        = $normMethod
        Active            = $true
        PortalToken       = $token
        Action1Threshold  = $action1Threshold
        Action2Threshold  = $action2Threshold
        Action3Threshold  = $action3Threshold
    }
    $schedule | ConvertTo-Json -Depth 5 | Set-Content "$schedPath\$customerID-schedule.json" -Encoding UTF8
    Write-Host "  Schedule and thresholds saved." -ForegroundColor Green

    # ── SUMMARY ───────────────────────────────────────────────
    Write-Host ""
    Write-Host "╔═════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║       Onboarding Complete!                          ║" -ForegroundColor Green
    Write-Host "╠═════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host ("║  Customer   : {0,-38}║" -f $companyName)              -ForegroundColor White
    Write-Host ("║  Agent      : {0,-38}║" -f $agentName)                -ForegroundColor White
    Write-Host ("║  Signals    : {0,-38}║" -f ("{0} configured" -f $signals.Count)) -ForegroundColor White
    Write-Host ("║  Schedule   : every {0} minutes{1,-28}║" -f $intervalMinutes, "") -ForegroundColor White
    Write-Host ("║  Thresholds : {0} / {1} / {2}{3,-26}║" -f $action1Threshold, $action2Threshold, $action3Threshold, "") -ForegroundColor White
    Write-Host "╠═════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║  Next steps:                                        ║" -ForegroundColor Cyan
    Write-Host ("║  Invoke-VBAFCenterRun -CustomerID ""{0}""" -f $customerID).PadRight(54) + "║" -ForegroundColor Cyan
    Write-Host "║  Start-VBAFCenterSchedule -CustomerID ""..."" (console)  ║" -ForegroundColor Cyan
    Write-Host "║  Start-VBAFCenterPortal              (console)       ║" -ForegroundColor Cyan
    Write-Host "╠═════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║  Portal URL:                                        ║" -ForegroundColor Yellow
    Write-Host ("║  http://localhost:8080/?customer={0}&token={1}" -f $customerID, $token).PadRight(54) + "║" -ForegroundColor Yellow
    Write-Host "╚═════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

    return @{
        CustomerID       = $customerID
        Agent            = $agentName
        Signals          = $signals.Count
        Action1Threshold = $action1Threshold
        Action2Threshold = $action2Threshold
        Action3Threshold = $action3Threshold
        PortalToken      = $token
    }
}

# ============================================================
# SHOW-VBAFCENTERSUMMARY
# ============================================================
function Show-VBAFCenterSummary {
    param([Parameter(Mandatory)] [string] $CustomerID)

    $storePath = Join-Path $env:USERPROFILE "VBAFCenter"

    Write-Host ""
    Write-Host ("VBAF-Center Setup Summary: {0}" -f $CustomerID) -ForegroundColor Cyan
    Write-Host ("  {0}" -f ("-" * 55)) -ForegroundColor DarkGray

    $profPath = "$storePath\customers\$CustomerID.json"
    if (Test-Path $profPath) {
        $p = Get-Content $profPath -Raw | ConvertFrom-Json
        Write-Host ("  Company      : {0}" -f $p.CompanyName)   -ForegroundColor White
        Write-Host ("  Agent        : {0}" -f $p.Agent)         -ForegroundColor White
        Write-Host ("  Business     : {0}" -f $p.BusinessType)  -ForegroundColor White
        Write-Host ("  Problem      : {0}" -f $p.Problem)       -ForegroundColor White
        Write-Host ("  Status       : {0}" -f $p.Status)        -ForegroundColor Green
    }

    Write-Host ""

    $signals = Get-ChildItem "$storePath\signals" -Filter "$CustomerID-*.json" -ErrorAction SilentlyContinue
    Write-Host ("  Signals      : {0} configured" -f @($signals).Count) -ForegroundColor White

    if ($signals) {
        foreach ($sf in $signals) {
            $s = Get-Content $sf.FullName -Raw | ConvertFrom-Json
            $threshInfo = ""
            if ($null -ne $s.GoodBelow -and $s.GoodBelow -ge 0) {
                $threshInfo += " GoodBelow=$($s.GoodBelow)"
            }
            if ($null -ne $s.BadAbove -and $s.BadAbove -ge 0) {
                $threshInfo += " BadAbove=$($s.BadAbove)"
            }
            $weightInfo = if ($null -ne $s.Weight -and $s.Weight -gt 0) { " W$($s.Weight)/5" } else { " W3/5" }
            Write-Host ("    {0,-10} {1,-25} {2}{3}{4}" -f `
                $s.SignalIndex, $s.SignalName, $s.SourceType, $weightInfo, $threshInfo) -ForegroundColor DarkGray
        }
    }

    Write-Host ""

    $schedPath = "$storePath\schedules\$CustomerID-schedule.json"
    if (Test-Path $schedPath) {
        $s = Get-Content $schedPath -Raw | ConvertFrom-Json
        Write-Host ("  Schedule     : every {0} minutes" -f $s.IntervalMinutes) -ForegroundColor White
        Write-Host ("  Thresholds   : Reassign={0}  Reroute={1}  Escalate={2}" -f `
            $s.Action1Threshold, $s.Action2Threshold, $s.Action3Threshold) -ForegroundColor White
        if ($s.PortalToken) {
            Write-Host ("  Portal URL   : http://localhost:8080/?customer={0}&token={1}" -f $CustomerID, $s.PortalToken) -ForegroundColor Yellow
        }
    }

    $actPath = "$storePath\actions\$CustomerID-actions.txt"
    if (Test-Path $actPath) {
        Write-Host ""
        Write-Host "  Action map:" -ForegroundColor White
        Get-Content $actPath | ForEach-Object {
            $parts = $_ -split "\|"
            if ($parts.Length -ge 3) {
                Write-Host ("    Action {0}: {1,-12} — {2}" -f $parts[0], $parts[1], $parts[2]) -ForegroundColor DarkGray
            }
        }
    }

    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host "VBAF-Center Phase 7 loaded  [Customer Onboarding UI + Phase 14/15/17]" -ForegroundColor Cyan
Write-Host "  Start-VBAFCenterOnboarding  — full setup wizard (7 steps)"           -ForegroundColor White
Write-Host "  Show-VBAFCenterSummary      — show complete customer setup"           -ForegroundColor White
Write-Host ""