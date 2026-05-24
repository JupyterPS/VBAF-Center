#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center — NordLogistik Test Company Setup
.DESCRIPTION
    Creates a fully configured test company with 10 realistic
    logistics signals for testing the AI Brain with rich context.

    Run this once — then run 20-30 cycles to build history.

    Company  : NordLogistik A/S
    Signals  : 10 real logistics KPIs
    Source   : Simulated (realistic random values)
    Purpose  : Test AI Brain with full signal suite
#>

cd "C:\Users\henni\OneDrive\WindowsPowerShell"
. .\VBAF-Center\VBAF.Center.LoadAll.ps1

$CustomerID = "NordLogistik"

Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   NordLogistik — Test Company Setup              |" -ForegroundColor Cyan
Write-Host "  |   10 signals · Full AI Brain test               |" -ForegroundColor Cyan
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# STEP 1 — Customer Profile
# ============================================================
Write-Host "  Step 1/7 — Customer profile..." -ForegroundColor Yellow

New-VBAFCenterCustomer `
    -CustomerID   $CustomerID `
    -CompanyName  "NordLogistik A/S" `
    -Country      "Denmark" `
    -BusinessType "Logistics" `
    -Problem      "Too many idle trucks, late deliveries and rising fuel costs" `
    -Agent        "FleetDispatch" `
    -Contact      "ops@nordlogistik.dk" `
    -Notes        "AI Brain test company — 10 signals"

Write-Host "  Customer profile created." -ForegroundColor Green

# ============================================================
# STEP 2 — Signal Configuration (10 signals)
# ============================================================
Write-Host ""
Write-Host "  Step 2/7 — Signal configuration (10 signals)..." -ForegroundColor Yellow

# Signal 1 — Empty Driving (inverted — lower is better)
New-VBAFCenterSignalConfig `
    -CustomerID  $CustomerID `
    -SignalName  "Empty Driving %" `
    -SignalIndex "Signal1" `
    -SourceType  "Simulated" `
    -RawMin      0 `
    -RawMax      100 `
    -GoodBelow   25 `
    -BadAbove    40 `
    -Weight      5

# Signal 2 — On-Time Delivery (higher is better)
New-VBAFCenterSignalConfig `
    -CustomerID  $CustomerID `
    -SignalName  "On-Time Delivery %" `
    -SignalIndex "Signal2" `
    -SourceType  "Simulated" `
    -RawMin      0 `
    -RawMax      100 `
    -GoodBelow   85 `
    -BadAbove    70 `
    -Weight      5

# Signal 3 — Cost Per Trip (inverted — lower is better)
New-VBAFCenterSignalConfig `
    -CustomerID  $CustomerID `
    -SignalName  "Cost Per Trip DKK" `
    -SignalIndex "Signal3" `
    -SourceType  "Simulated" `
    -RawMin      500 `
    -RawMax      4000 `
    -GoodBelow   2000 `
    -BadAbove    2500 `
    -Weight      4

# Signal 4 — Route Efficiency (higher is better)
New-VBAFCenterSignalConfig `
    -CustomerID  $CustomerID `
    -SignalName  "Route Efficiency %" `
    -SignalIndex "Signal4" `
    -SourceType  "Simulated" `
    -RawMin      0 `
    -RawMax      100 `
    -GoodBelow   80 `
    -BadAbove    65 `
    -Weight      4

# Signal 5 — ETA Accuracy (higher is better)
New-VBAFCenterSignalConfig `
    -CustomerID  $CustomerID `
    -SignalName  "ETA Accuracy %" `
    -SignalIndex "Signal5" `
    -SourceType  "Simulated" `
    -RawMin      0 `
    -RawMax      100 `
    -GoodBelow   80 `
    -BadAbove    65 `
    -Weight      4

# Signal 6 — CO2 Per Trip (inverted — lower is better)
New-VBAFCenterSignalConfig `
    -CustomerID  $CustomerID `
    -SignalName  "CO2 Per Trip kg" `
    -SignalIndex "Signal6" `
    -SourceType  "Simulated" `
    -RawMin      10 `
    -RawMax      120 `
    -GoodBelow   50 `
    -BadAbove    70 `
    -Weight      2

# Signal 7 — POD Completion (higher is better)
New-VBAFCenterSignalConfig `
    -CustomerID  $CustomerID `
    -SignalName  "POD Completion %" `
    -SignalIndex "Signal7" `
    -SourceType  "Simulated" `
    -RawMin      0 `
    -RawMax      100 `
    -GoodBelow   92 `
    -BadAbove    85 `
    -Weight      3

# Signal 8 — Driver Performance (higher is better)
New-VBAFCenterSignalConfig `
    -CustomerID  $CustomerID `
    -SignalName  "Driver Performance %" `
    -SignalIndex "Signal8" `
    -SourceType  "Simulated" `
    -RawMin      0 `
    -RawMax      100 `
    -GoodBelow   78 `
    -BadAbove    65 `
    -Weight      3

# Signal 9 — Fleet Availability (higher is better)
New-VBAFCenterSignalConfig `
    -CustomerID  $CustomerID `
    -SignalName  "Fleet Availability %" `
    -SignalIndex "Signal9" `
    -SourceType  "Simulated" `
    -RawMin      0 `
    -RawMax      100 `
    -GoodBelow   85 `
    -BadAbove    75 `
    -Weight      4

# Signal 10 — Capacity Utilisation (higher is better)
New-VBAFCenterSignalConfig `
    -CustomerID  $CustomerID `
    -SignalName  "Capacity Utilisation %" `
    -SignalIndex "Signal10" `
    -SourceType  "Simulated" `
    -RawMin      0 `
    -RawMax      100 `
    -GoodBelow   70 `
    -BadAbove    55 `
    -Weight      3

Write-Host "  10 signals configured." -ForegroundColor Green

# ============================================================
# STEP 3 — Action Map
# ============================================================
Write-Host ""
Write-Host "  Step 3/7 — Action map..." -ForegroundColor Yellow

New-VBAFCenterActionMap `
    -CustomerID      $CustomerID `
    -Action0Name     "Monitor" `
    -Action0Command  "Alt OK — flåden kører godt. Fortsæt overvågning." `
    -Action1Name     "Reassign" `
    -Action1Command  "Flyt ledig lastbil til næste ventende levering." `
    -Action2Name     "Reroute" `
    -Action2Command  "Skift til hurtigere rute — kontakt dispatcher nu." `
    -Action3Name     "Escalate" `
    -Action3Command  "Ring til driftsleder øjeblikkeligt — kritisk situation."

Write-Host "  Action map created." -ForegroundColor Green

# ============================================================
# STEP 4 — Customer-specific Action Thresholds (Phase 17)
# ============================================================
Write-Host ""
Write-Host "  Step 4/7 — Action thresholds (Phase 17)..." -ForegroundColor Yellow

Set-VBAFCenterActionThresholds `
    -CustomerID $CustomerID `
    -Action1    0.25 `
    -Action2    0.50 `
    -Action3    0.72

Write-Host "  Thresholds set: Reassign=0.25 Reroute=0.50 Escalate=0.72" -ForegroundColor Green

# ============================================================
# STEP 5 — Write-back Config (Fake TMS)
# ============================================================
Write-Host ""
Write-Host "  Step 5/7 — Write-back config (Fake TMS)..." -ForegroundColor Yellow

New-VBAFCenterWriteConfig `
    -CustomerID  $CustomerID `
    -TMSBaseURL  "http://localhost:8082"

Write-Host "  Write-back configured: http://localhost:8082" -ForegroundColor Green

# ============================================================
# STEP 6 — Crisis Tree
# ============================================================
Write-Host ""
Write-Host "  Step 6/7 — Crisis tree (NordLogistik specific)..." -ForegroundColor Yellow

New-VBAFCenterCrisisTree -CustomerID $CustomerID -CrisisName "Tom kørsel kritisk"         -Trigger "Empty Driving above 40%"              -Step1 "Stop alle ikke-planlagte ture" -Step2 "Ring til alle chauffører" -Step3 "Tildel ledig vogn til næste levering" -Step4 "Opdater TMS" -Step5 "Log hændelsen"
New-VBAFCenterCrisisTree -CustomerID $CustomerID -CrisisName "Forsinkelser kritisk"        -Trigger "On-Time Delivery below 65%"            -Step1 "Identificer forsinkede leveringer" -Step2 "Ring til berørte kunder" -Step3 "Tildel hurtigste vogn" -Step4 "Informer ledelse" -Step5 "Log i TMS"
New-VBAFCenterCrisisTree -CustomerID $CustomerID -CrisisName "Omkostninger eskalerer"      -Trigger "Cost Per Trip above 2500 DKK"          -Step1 "Identificer dyre ture" -Step2 "Optimer ruter" -Step3 "Stop unødvendige ture" -Step4 "Rapporter til økonomi" -Step5 "Log hændelsen"
New-VBAFCenterCrisisTree -CustomerID $CustomerID -CrisisName "Vogn utilgængelig"           -Trigger "Fleet Availability below 75%"          -Step1 "Bekræft hvilke vogne er ude" -Step2 "Kontakt værksted" -Step3 "Omfordel leveringer" -Step4 "Informer kunder" -Step5 "Opdater forsikring"
New-VBAFCenterCrisisTree -CustomerID $CustomerID -CrisisName "Chaufførpræstation kritisk"  -Trigger "Driver Performance below 65%"          -Step1 "Identificer berørte chauffører" -Step2 "Gennemgå ruteplanlægning" -Step3 "Overvej omplacering" -Step4 "Informer HR" -Step5 "Log hændelsen"

Write-Host "  5 crisis scenarios configured." -ForegroundColor Green

# ============================================================
# STEP 7 — Build history (30 quick runs)
# ============================================================
Write-Host ""
Write-Host "  Step 7/7 — Building history (30 test runs)..." -ForegroundColor Yellow
Write-Host "  This takes about 30 seconds..." -ForegroundColor DarkGray

for ($i = 1; $i -le 30; $i++) {
    Invoke-VBAFCenterRun -CustomerID $CustomerID | Out-Null
    Write-Host ("  Run {0}/30 complete" -f $i) -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 500
}

Write-Host "  30 history runs complete." -ForegroundColor Green

# ============================================================
# SUMMARY
# ============================================================
Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
Write-Host "  |   NordLogistik Setup Complete!                   |" -ForegroundColor Green
Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  Customer    : NordLogistik A/S" -ForegroundColor White
Write-Host "  Signals     : 10 configured" -ForegroundColor White
Write-Host "  History     : 30 runs built" -ForegroundColor White
Write-Host "  Crisis tree : 5 scenarios" -ForegroundColor White
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Test rule-based:" -ForegroundColor White
Write-Host "     Invoke-VBAFCenterRun -CustomerID 'NordLogistik'" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  2. Test AI Brain:" -ForegroundColor White
Write-Host "     . .\VBAF-Center\VBAF.Center.ClaudeBrain.ps1" -ForegroundColor DarkGray
Write-Host "     Invoke-VBAFCenterClaudeBrain -CustomerID 'NordLogistik' -Provider 'Mistral'" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  3. Run history report:" -ForegroundColor White
Write-Host "     Get-VBAFCenterRunHistory -CustomerID 'NordLogistik'" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  4. View portal:" -ForegroundColor White
Write-Host "     Start-VBAFCenterPortal" -ForegroundColor DarkGray
Write-Host "     Get-VBAFCenterPortalURLs" -ForegroundColor DarkGray
Write-Host ""
