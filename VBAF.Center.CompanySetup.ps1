#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center — Company Setup
.DESCRIPTION
    Sets up a new logistics customer from scratch in one command.
    Creates profile, signals, action map, thresholds, crisis tree,
    write-back config and 30 history runs ready for AI Brain.

    Works for ANY logistics company — fully parameterised.

    Functions:
      New-VBAFCenterCompanySetup  — full setup in one go
      Get-VBAFCenterSetupStatus   — check what is configured for a customer
#>

# ============================================================
# NEW-VBAFCENTERCOMPANYSETUP
# ============================================================
function New-VBAFCenterCompanySetup {
    <#
    .SYNOPSIS
        Full company setup in one command.
        Creates everything needed to start monitoring immediately.
    .EXAMPLE
        New-VBAFCenterCompanySetup `
          -CustomerID   "TruckCompanyDK" `
          -CompanyName  "Truck Company DK" `
          -Contact      "ceo@truckcompanydk.dk" `
          -Problem      "Too many idle trucks and late deliveries" `
          -Signals      10 `
          -BuildHistory $true
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [Parameter(Mandatory)] [string] $CompanyName,
        [Parameter(Mandatory)] [string] $Contact,
        [string] $Problem      = "Too many idle trucks and late deliveries",
        [string] $BusinessType = "Logistics",
        [string] $Agent        = "FleetDispatch",
        [string] $Country      = "Denmark",
        [ValidateSet(2,4,6,10)]
        [int]    $Signals      = 10,
        [double] $Threshold1   = 0.25,
        [double] $Threshold2   = 0.50,
        [double] $Threshold3   = 0.72,
        [string] $TMSBaseURL   = "http://localhost:8082",
        [string] $AlertPhone   = "",
        [bool]   $BuildHistory = $true,
        [int]    $HistoryRuns  = 30
    )

    Write-Host ""
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   VBAF-Center — Company Setup                    |" -ForegroundColor Cyan
    Write-Host ("  |   {0,-47}|" -f $CompanyName)                       -ForegroundColor Cyan
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    # ── Step 1 — Customer Profile ─────────────────────────────
    Write-Host "  Step 1/7 — Customer profile..." -ForegroundColor Yellow
    if (Get-Command New-VBAFCenterCustomer -ErrorAction SilentlyContinue) {
        New-VBAFCenterCustomer `
            -CustomerID   $CustomerID `
            -CompanyName  $CompanyName `
            -Country      $Country `
            -BusinessType $BusinessType `
            -Problem      $Problem `
            -Agent        $Agent `
            -Contact      $Contact `
            -Notes        "Created via New-VBAFCenterCompanySetup" | Out-Null
        Write-Host "  Customer profile created." -ForegroundColor Green
    } else {
        Write-Host "  Phase 1 not loaded — run LoadAll first." -ForegroundColor Red
        return
    }

    # ── Step 2 — Signals ─────────────────────────────────────
    Write-Host ""
    Write-Host ("  Step 2/7 — Signal configuration ({0} signals)..." -f $Signals) -ForegroundColor Yellow

    # Full signal definitions — top 10 logistics KPIs
    $allSignals = @(
        @{ Name="Empty Driving %";      Min=0;   Max=100;  Base=30;  GoodBelow=25;  BadAbove=40;  Weight=5; Invert=$true  }
        @{ Name="On-Time Delivery %";   Min=0;   Max=100;  Base=78;  GoodBelow=85;  BadAbove=70;  Weight=5; Invert=$false }
        @{ Name="Cost Per Trip DKK";    Min=500; Max=4000; Base=1800;GoodBelow=2000;BadAbove=2500;Weight=4; Invert=$true  }
        @{ Name="Route Efficiency %";   Min=0;   Max=100;  Base=76;  GoodBelow=80;  BadAbove=65;  Weight=4; Invert=$false }
        @{ Name="ETA Accuracy %";       Min=0;   Max=100;  Base=80;  GoodBelow=80;  BadAbove=65;  Weight=4; Invert=$false }
        @{ Name="CO2 Per Trip kg";      Min=10;  Max=120;  Base=48;  GoodBelow=50;  BadAbove=70;  Weight=2; Invert=$true  }
        @{ Name="POD Completion %";     Min=0;   Max=100;  Base=88;  GoodBelow=92;  BadAbove=85;  Weight=3; Invert=$false }
        @{ Name="Driver Performance %"; Min=0;   Max=100;  Base=80;  GoodBelow=78;  BadAbove=65;  Weight=3; Invert=$false }
        @{ Name="Fleet Availability %"; Min=0;   Max=100;  Base=90;  GoodBelow=85;  BadAbove=75;  Weight=4; Invert=$false }
        @{ Name="Capacity Util %";      Min=0;   Max=100;  Base=72;  GoodBelow=70;  BadAbove=55;  Weight=3; Invert=$false }
    )

    # Use only the first N signals based on -Signals parameter
    $selectedSignals = $allSignals[0..($Signals-1)]
    $i = 1

    foreach ($s in $selectedSignals) {
        if (Get-Command New-VBAFCenterSignalConfig -ErrorAction SilentlyContinue) {
            New-VBAFCenterSignalConfig `
                -CustomerID  $CustomerID `
                -SignalName  $s.Name `
                -SignalIndex "Signal$i" `
                -SourceType  "Simulated" `
                -RawMin      $s.Min `
                -RawMax      $s.Max `
                -GoodBelow   $s.GoodBelow `
                -BadAbove    $s.BadAbove `
                -Weight      $s.Weight | Out-Null
        }
        $i++
    }
    Write-Host ("  {0} signals configured." -f $Signals) -ForegroundColor Green

    # ── Step 3 — Action Map ───────────────────────────────────
    Write-Host ""
    Write-Host "  Step 3/7 — Action map..." -ForegroundColor Yellow
    if (Get-Command New-VBAFCenterActionMap -ErrorAction SilentlyContinue) {
        New-VBAFCenterActionMap `
            -CustomerID      $CustomerID `
            -Action0Name     "Monitor" `
            -Action0Command  "Alt OK — flåden kører godt. Fortsæt overvågning." `
            -Action1Name     "Reassign" `
            -Action1Command  "Flyt ledig lastbil til næste ventende levering." `
            -Action2Name     "Reroute" `
            -Action2Command  "Skift til hurtigere rute — kontakt dispatcher nu." `
            -Action3Name     "Escalate" `
            -Action3Command  "Ring til driftsleder øjeblikkeligt — kritisk situation." | Out-Null
        Write-Host "  Action map created." -ForegroundColor Green
    }

    # Create schedule file — required by Set-VBAFCenterActionThresholds
    $schedPath2 = Join-Path $env:USERPROFILE "VBAFCenter\schedules"
    if (-not (Test-Path $schedPath2)) { New-Item -ItemType Directory -Path $schedPath2 -Force | Out-Null }
    $schedFile2 = Join-Path $schedPath2 "$CustomerID-schedule.json"
    if (-not (Test-Path $schedFile2)) {
        $token2 = -join ((65..90)+(97..122) | Get-Random -Count 6 | ForEach-Object {[char]$_})
        @{ CustomerID=$CustomerID; IntervalMinutes=10; NormMethod="MinMax"; Active=$true; PortalToken=$token2 } | ConvertTo-Json | Set-Content $schedFile2 -Encoding UTF8
        Write-Host "  Schedule file created." -ForegroundColor Green
    }
    # ── Step 4 — Thresholds ───────────────────────────────────
    Write-Host ""
    Write-Host "  Step 4/7 — Action thresholds (Phase 17)..." -ForegroundColor Yellow
    if (Get-Command Set-VBAFCenterActionThresholds -ErrorAction SilentlyContinue) {
        Set-VBAFCenterActionThresholds `
            -CustomerID $CustomerID `
            -Action1    $Threshold1 `
            -Action2    $Threshold2 `
            -Action3    $Threshold3 | Out-Null
        Write-Host ("  Thresholds set: Reassign={0} Reroute={1} Escalate={2}" -f $Threshold1, $Threshold2, $Threshold3) -ForegroundColor Green
    }

    # Add AlertPhone to schedule file if provided
    if ($AlertPhone -ne "") {
        $schedFile2 = Join-Path $env:USERPROFILE "VBAFCenter\schedules\$CustomerID-schedule.json"
        if (Test-Path $schedFile2) {
            $s2 = Get-Content $schedFile2 -Raw | ConvertFrom-Json
            $s2 | Add-Member -NotePropertyName AlertPhone -NotePropertyValue $AlertPhone -Force
            $s2 | ConvertTo-Json | Set-Content $schedFile2 -Encoding UTF8
            Write-Host ("  SMS alert   : {0}" -f $AlertPhone) -ForegroundColor Green
        }
    }

    # ── Step 5 — Write-back Config ────────────────────────────
    Write-Host ""
    Write-Host "  Step 5/7 — Write-back config..." -ForegroundColor Yellow
    if (Get-Command New-VBAFCenterWriteConfig -ErrorAction SilentlyContinue) {
        New-VBAFCenterWriteConfig `
            -CustomerID  $CustomerID `
            -TMSBaseURL  $TMSBaseURL | Out-Null
        Write-Host ("  Write-back configured: {0}" -f $TMSBaseURL) -ForegroundColor Green
    }

    # ── Step 6 — Crisis Tree ──────────────────────────────────
    Write-Host ""
    Write-Host "  Step 6/7 — Crisis tree (5 logistics scenarios)..." -ForegroundColor Yellow
    if (Get-Command New-VBAFCenterCrisisTree -ErrorAction SilentlyContinue) {
        New-VBAFCenterCrisisTree -CustomerID $CustomerID `
            -CrisisName "Tom kørsel kritisk" `
            -Trigger    "Empty Driving above 40%" `
            -Step1 "Stop alle ikke-planlagte ture øjeblikkeligt" `
            -Step2 "Ring til alle chauffører og bed dem rapportere position" `
            -Step3 "Tildel ledig lastbil til næste ventende levering" `
            -Step4 "Opdater dispatcher om ny ruteplanlægning" `
            -Step5 "Log hændelsen i TMS" | Out-Null

        New-VBAFCenterCrisisTree -CustomerID $CustomerID `
            -CrisisName "Forsinkede leveringer kritisk" `
            -Trigger    "On-Time Delivery below 65%" `
            -Step1 "Identificer hvilke leveringer der er forsinket" `
            -Step2 "Ring til berørte kunder og giv opdateret ETA" `
            -Step3 "Tildel hurtigste tilgængelige lastbil" `
            -Step4 "Vurder om ekstern vognmand skal tilkaldes" `
            -Step5 "Rapporter til ledelse hvis 3+ leveringer er forsinket" | Out-Null

        New-VBAFCenterCrisisTree -CustomerID $CustomerID `
            -CrisisName "Vogn går i stykker" `
            -Trigger    "Fleet Availability below 75%" `
            -Step1 "Bekræft hvilken vogn der er ude af drift" `
            -Step2 "Kontakt værksted og bestil assistance" `
            -Step3 "Flyt aktive leveringer til nærmeste ledige vogn" `
            -Step4 "Informer berørte kunder om forsinkelse" `
            -Step5 "Opdater forsikring hvis nødvendigt" | Out-Null

        New-VBAFCenterCrisisTree -CustomerID $CustomerID `
            -CrisisName "Omkostninger eskalerer" `
            -Trigger    "Cost Per Trip above 2500 DKK" `
            -Step1 "Identificer hvilke ture driver omkostningerne op" `
            -Step2 "Tjek om der er unødvendige omveje eller tomkørsel" `
            -Step3 "Optimer ruter for resten af dagen" `
            -Step4 "Vurder om overarbejde skal stoppes" `
            -Step5 "Rapporter til økonomiansvarlig" | Out-Null

        New-VBAFCenterCrisisTree -CustomerID $CustomerID `
            -CrisisName "Chauffør mangler" `
            -Trigger    "Fleet Availability below 80% due to driver absence" `
            -Step1 "Bekræft hvilke chauffører er fraværende" `
            -Step2 "Kontakt vikarbureau for erstatningschauffør" `
            -Step3 "Prioriter dagens vigtigste leveringer" `
            -Step4 "Udskyd lavprioritets leveringer til næste dag" `
            -Step5 "Informer berørte kunder" | Out-Null

        Write-Host "  5 crisis scenarios configured." -ForegroundColor Green
    }

    # ── Step 7 — Build History ────────────────────────────────
    if ($BuildHistory) {
        Write-Host ""
        Write-Host ("  Step 7/7 — Building {0} history runs..." -f $HistoryRuns) -ForegroundColor Yellow

        $historyPath  = Join-Path $env:USERPROFILE "VBAFCenter\history"
        if (-not (Test-Path $historyPath)) { New-Item -ItemType Directory -Path $historyPath -Force | Out-Null }

        $actionNames  = @("Monitor","Reassign","Reroute","Escalate")
        $baseDate     = (Get-Date).AddDays(-14)

        for ($run = 0; $run -lt $HistoryRuns; $run++) {
            $dayOffset  = [int]($run / 4)
            $hourOffset = ($run % 4) * 6
            $runTime    = $baseDate.AddDays($dayOffset).AddHours($hourOffset)
            $dayOfWeek  = [int]$runTime.DayOfWeek

            $dayMult = switch ($dayOfWeek) {
                0 { 0.80 } 1 { 0.85 } 2 { 0.95 }
                3 { 1.10 } 4 { 1.20 } 5 { 1.05 } 6 { 0.75 }
            }
            $timeMult  = if ($hourOffset -ge 12) { 1.10 } else { 0.92 }
            $driftMult = if ($run -ge 15 -and $run -le 22) { 1.0 + (($run-15) * 0.012) } else { 1.0 }

            $norms    = @()
            $weights  = @()
            $redCount = 0

            foreach ($s in $selectedSignals) {
                $noise  = (Get-Random -Minimum -80 -Maximum 80) / 1000.0
                $raw    = $s.Base * $dayMult * $timeMult * $driftMult + $noise * ($s.Max - $s.Min)
                $raw    = [Math]::Max($s.Min, [Math]::Min($s.Max, $raw))
                $norm   = [Math]::Round(($raw - $s.Min) / ($s.Max - $s.Min), 4)

                # Count reds
                $isRed = if ($s.Invert) { $raw -gt $s.BadAbove } else { $raw -lt $s.BadAbove }
                if ($isRed) { $redCount++ }

                $norms   += $norm
                $weights += $s.Weight
            }

            # Weighted average
            $wsum = 0.0; $nsum = 0.0
            for ($j = 0; $j -lt $norms.Count; $j++) { $wsum += $norms[$j] * $weights[$j]; $nsum += $weights[$j] }
            $wavg = [Math]::Round($wsum / $nsum, 4)

            # Action
            $action = if ($wavg -gt $Threshold3) { 3 } elseif ($wavg -gt $Threshold2) { 2 } elseif ($wavg -gt $Threshold1) { 1 } else { 0 }
            if ($redCount -ge 2) { $action = [Math]::Max($action, 3) }
            elseif ($redCount -ge 1) { $action = [Math]::Max($action, 2) }

            $entry = [PSCustomObject]@{
                CustomerID        = $CustomerID
                Timestamp         = $runTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
                Signals           = $norms
                AvgSignal         = $wavg
                WeightedAvg       = $wavg
                Action            = $action
                ActionName        = $actionNames[$action]
                ActionCommand     = "History build run $run"
                ActionReason      = "Weighted avg $wavg — $redCount red signals"
                OverrideApplied   = ($redCount -gt 0)
                RedSignalCount    = $redCount
                YellowSignalCount = 0
                Source            = "RuleBased"
            }

            $histFile = Join-Path $historyPath ("$CustomerID-{0:yyyyMMdd_HHmmss_fff}.json" -f $runTime.AddMilliseconds($run))
            $entry | ConvertTo-Json -Depth 5 | Set-Content $histFile -Encoding UTF8

            Write-Host ("  Run {0}/{1}" -f ($run+1), $HistoryRuns) -ForegroundColor DarkGray
        }

        Write-Host ("  {0} history runs built." -f $HistoryRuns) -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "  Step 7/7 — History skipped (-BuildHistory `$false)." -ForegroundColor DarkGray
    }

    # ── Summary ───────────────────────────────────────────────
    Write-Host ""
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
    Write-Host "  |   Setup Complete!                                 |" -ForegroundColor Green
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
    Write-Host ""
    Write-Host ("  Customer    : {0}" -f $CompanyName)   -ForegroundColor White
    Write-Host ("  CustomerID  : {0}" -f $CustomerID)    -ForegroundColor White
    Write-Host ("  Signals     : {0} configured"  -f $Signals) -ForegroundColor White
    Write-Host ("  Thresholds  : {0} / {1} / {2}" -f $Threshold1, $Threshold2, $Threshold3) -ForegroundColor White
    $phoneDisplay = if ($AlertPhone -ne "") { $AlertPhone } else { "Not configured" }
    Write-Host ("  SMS alert   : {0}" -f $phoneDisplay) -ForegroundColor White
    Write-Host ("  Crisis tree : 5 scenarios")            -ForegroundColor White
    Write-Host ("  History     : {0} runs built" -f $(if ($BuildHistory) { $HistoryRuns } else { "skipped" })) -ForegroundColor White
    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. Run rule-based pipeline:" -ForegroundColor White
    Write-Host ("     Invoke-VBAFCenterRun -CustomerID '{0}' | Out-Null" -f $CustomerID) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  2. Run AI Brain:" -ForegroundColor White
    Write-Host ("     Invoke-VBAFCenterClaudeBrain -CustomerID '{0}' -Provider 'Mistral' -SuppressCrisis" -f $CustomerID) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  3. Open daily briefing:" -ForegroundColor White
    Write-Host ("     Export-VBAFCenterDailyBriefing -CustomerID '{0}' -RunAIFirst -OpenBrowser" -f $CustomerID) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  4. Start portal:" -ForegroundColor White
    Write-Host "     Start-VBAFCenterPortal" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  5. Get portal URL:" -ForegroundColor White
    Write-Host "     Get-VBAFCenterPortalURLs" -ForegroundColor DarkGray
    Write-Host ""
}

# ============================================================
# GET-VBAFCENTERSETUPSTATUS
# ============================================================
function Get-VBAFCenterSetupStatus {
    <#
    .SYNOPSIS
        Check what is configured for a customer.
    .EXAMPLE
        Get-VBAFCenterSetupStatus -CustomerID "TruckCompanyDK"
    #>
    param([Parameter(Mandatory)] [string] $CustomerID)

    $base = Join-Path $env:USERPROFILE "VBAFCenter"

    Write-Host ""
    Write-Host ("  Setup Status: {0}" -f $CustomerID) -ForegroundColor Cyan
    Write-Host ("  {0}" -f ("-" * 45)) -ForegroundColor DarkGray

    $checks = @(
        @{ Label="Customer profile";  Path="$base\customers\$CustomerID.json" }
        @{ Label="Signal configs";    Path="$base\signals\$CustomerID-Signal1.json" }
        @{ Label="Action map";        Path="$base\actions\$CustomerID-actions.txt" }
        @{ Label="Schedule file";     Path="$base\schedules\$CustomerID-schedule.json" }
        @{ Label="Write-back config"; Path="$base\writeconfig\$CustomerID-writeconfig.json" }
        @{ Label="Crisis tree";       Path="$base\crisisconfig\$CustomerID-crisis.json" }
    )

    foreach ($c in $checks) {
        $exists = Test-Path $c.Path
        $color  = if ($exists) { "Green" } else { "Red" }
        $mark   = if ($exists) { "OK" }    else { "MISSING" }
        Write-Host ("  {0,-22} {1}" -f $c.Label, $mark) -ForegroundColor $color
    }

    # History count
    $histPath = "$base\history"
    $histCount = if (Test-Path $histPath) {
        (Get-ChildItem $histPath -Filter "$CustomerID-*.json").Count
    } else { 0 }
    $histColor = if ($histCount -gt 0) { "Green" } else { "Yellow" }
    Write-Host ("  {0,-22} {1} runs" -f "History", $histCount) -ForegroundColor $histColor

    # Portal token
    $schedFile = "$base\schedules\$CustomerID-schedule.json"
    if (Test-Path $schedFile) {
        $sched = Get-Content $schedFile -Raw | ConvertFrom-Json
        if ($sched.PortalToken) {
            Write-Host ("  {0,-22} {1}" -f "Portal token", $sched.PortalToken) -ForegroundColor Green
            Write-Host ("  {0,-22} http://localhost:8080/?customer={1}&token={2}" -f "Portal URL", $CustomerID, $sched.PortalToken) -ForegroundColor DarkGray
        }
    }

    Write-Host ""
}

# ============================================================
# REMOVE-VBAFCENTERCOMPANY
# ============================================================
function Remove-VBAFCenterCompany {
    <#
    .SYNOPSIS
        Completely removes a customer and all their data.
        Deletes: profile, signals, actions, schedule, history,
                 overrides, learning, crisis, writeconfig, briefings,
                 dailylog, crisisconfig, suggestions.
    .EXAMPLE
        Remove-VBAFCenterCompany -CustomerID "TestCompanyDK"
        Remove-VBAFCenterCompany -CustomerID "TestCompanyDK" -Confirm
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [switch] $Confirm
    )

    $base = Join-Path $env:USERPROFILE "VBAFCenter"

    Write-Host ""
    Write-Host ("  Removing customer: {0}" -f $CustomerID) -ForegroundColor Red
    Write-Host ""

    if (-not $Confirm) {
        $answer = Read-Host "  Are you sure? This cannot be undone. Type YES to confirm"
        if ($answer -ne "YES") {
            Write-Host "  Cancelled." -ForegroundColor Yellow
            return
        }
    }

    $removed = 0

    # All paths to clean
    $targets = @(
        @{ Label="Customer profile";  Path="$base\customers\$CustomerID.json" }
        @{ Label="Actions";           Path="$base\actions\$CustomerID-actions.txt" }
        @{ Label="Schedule";          Path="$base\schedules\$CustomerID-schedule.json" }
        @{ Label="Write config";      Path="$base\writeconfig\$CustomerID-writeconfig.json" }
        @{ Label="Write log";         Path="$base\writelog\$CustomerID-writelog.json" }
        @{ Label="Learning report";   Path="$base\learning\$CustomerID-learning.json" }
        @{ Label="Overrides";         Path="$base\overrides\$CustomerID-overrides.json" }
        @{ Label="Crisis config";     Path="$base\crisisconfig\$CustomerID-crisis.json" }
        @{ Label="Suggestions";       Path="$base\suggestions\$CustomerID-suggestion.json" }
        @{ Label="Suggestions dimiss";Path="$base\suggestions\$CustomerID-dismissed.txt" }
        @{ Label="Latest briefing";   Path="$base\briefings\$CustomerID-latest.html" }
        @{ Label="AI key context";    Path="$base\ai\$CustomerID-context.json" }
    )

    foreach ($t in $targets) {
        if (Test-Path $t.Path) {
            Remove-Item $t.Path -Force
            Write-Host ("  Removed: {0}" -f $t.Label) -ForegroundColor DarkGray
            $removed++
        }
    }

    # Wildcard deletions — multiple files
    $wildcards = @(
        @{ Label="Signal configs";   Pattern="$base\signals\$CustomerID-*.json" }
        @{ Label="History runs";     Pattern="$base\history\$CustomerID-*.json" }
        @{ Label="Crisis logs";      Pattern="$base\crisis\$CustomerID-crisis-*.json" }
        @{ Label="Briefing files";   Pattern="$base\briefings\$CustomerID-*.html" }
        @{ Label="Daily logs";       Pattern="$base\dailylog\$CustomerID-*.log" }
    )

    foreach ($w in $wildcards) {
        $files = Get-ChildItem $w.Pattern -ErrorAction SilentlyContinue
        if ($files.Count -gt 0) {
            $files | Remove-Item -Force
            Write-Host ("  Removed: {0} ({1} files)" -f $w.Label, $files.Count) -ForegroundColor DarkGray
            $removed += $files.Count
        }
    }

    Write-Host ""
    if ($removed -gt 0) {
        Write-Host ("  Customer {0} fully removed — {1} files deleted." -f $CustomerID, $removed) -ForegroundColor Green
    } else {
        Write-Host ("  Nothing found for: {0}" -f $CustomerID) -ForegroundColor Yellow
    }
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   VBAF-Center — Company Setup                    |" -ForegroundColor Cyan
Write-Host "  |   Full setup in one command for any customer     |" -ForegroundColor Cyan
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  New-VBAFCenterCompanySetup  — full setup in one go"    -ForegroundColor White
Write-Host "  Get-VBAFCenterSetupStatus   — check customer config"   -ForegroundColor White
Write-Host "  Remove-VBAFCenterCompany     — delete customer and all data" -ForegroundColor White
Write-Host ""
Write-Host "  Example:" -ForegroundColor Yellow
Write-Host "  New-VBAFCenterCompanySetup \`" -ForegroundColor DarkGray
Write-Host "    -CustomerID  'TruckCompanyDK' \`" -ForegroundColor DarkGray
Write-Host "    -CompanyName 'Truck Company DK' \`" -ForegroundColor DarkGray
Write-Host "    -Contact     'ceo@truckcompanydk.dk' \`" -ForegroundColor DarkGray
Write-Host "    -Problem     'Too many idle trucks and late deliveries' \`" -ForegroundColor DarkGray
Write-Host "    -Signals     10 \`" -ForegroundColor DarkGray
Write-Host "    -BuildHistory `$true" -ForegroundColor DarkGray
Write-Host ""
