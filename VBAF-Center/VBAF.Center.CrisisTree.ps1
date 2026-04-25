#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 13 — Crisis Response Tree
.DESCRIPTION
    When signals hit critical levels VBAF-Center activates
    a structured crisis response — walking the dispatcher
    through every possible recovery step.

    Like a defibrillator — it takes over when the human freezes.
    Human gut feeling stays in the background — the tree just
    makes sure nothing is forgotten in the heat of the moment.

    Domains:
      Logistics     — vehicle breakdown, late delivery, driver missing
      IT            — server down, disk full, CPU critical
      Healthcare    — bed shortage, staff missing, equipment failure
      Manufacturing — machine breakdown, quality alert, supply delay

    Functions:
      Start-VBAFCenterCrisis       — activate crisis response wizard
      Get-VBAFCenterCrisisTree     — show all crisis trees
      New-VBAFCenterCrisisTree     — add custom crisis tree
      Get-VBAFCenterCrisisHistory  — show past crisis responses
#>

# ============================================================
# CRISIS TREES
# ============================================================
$script:CrisisTrees = @{

    # ── LOGISTICS ────────────────────────────────────────────
    "LOGISTICS-VEHICLE-BREAKDOWN" = @{
        Domain      = "Logistics"
        Trigger     = "Empty Driving above 45% or Fleet Availability below 75%"
        Title       = "Vehicle Breakdown Response"
        Steps       = @(
            @{
                Step    = 1
                Question = "Is a backup vehicle available in the depot?"
                Yes     = "Deploy backup vehicle immediately — assign to affected route"
                No      = "Proceed to Step 2"
            }
            @{
                Step    = 2
                Question = "Can the load be split between remaining trucks?"
                Yes     = "Redistribute load — prioritise time-sensitive deliveries first"
                No      = "Proceed to Step 3"
            }
            @{
                Step    = 3
                Question = "Can delivery time be renegotiated with the customer?"
                Yes     = "Call customer now — explain situation, agree new ETA"
                No      = "Proceed to Step 4"
            }
            @{
                Step    = 4
                Question = "Is an external subcontractor available?"
                Yes     = "Contact subcontractor — confirm availability and cost"
                No      = "ESCALATE — Call operations manager immediately"
            }
        )
    }

    "LOGISTICS-LATE-DELIVERY" = @{
        Domain      = "Logistics"
        Trigger     = "On-Time Delivery below 65% or ETA Accuracy below 60%"
        Title       = "Late Delivery Response"
        Steps       = @(
            @{
                Step    = 1
                Question = "Is the delay due to traffic or weather?"
                Yes     = "Reroute to fastest available alternative — check Google Maps"
                No      = "Proceed to Step 2"
            }
            @{
                Step    = 2
                Question = "Is the delay more than 60 minutes?"
                Yes     = "Call customer proactively — do not wait for them to call you"
                No      = "Monitor — update ETA every 15 minutes"
            }
            @{
                Step    = 3
                Question = "Is this a high-priority customer?"
                Yes     = "Reassign nearest available truck to take over delivery"
                No      = "Log delay — update delivery status in TMS"
            }
        )
    }

    "LOGISTICS-HIGH-COST" = @{
        Domain      = "Logistics"
        Trigger     = "Cost Per Trip above 2500 DKK"
        Title       = "Cost Spike Response"
        Steps       = @(
            @{
                Step    = 1
                Question = "Is the cost spike due to fuel price?"
                Yes     = "Check if routes can be shortened — combine deliveries where possible"
                No      = "Proceed to Step 2"
            }
            @{
                Step    = 2
                Question = "Are multiple trucks running near-empty?"
                Yes     = "Consolidate loads — cancel unnecessary runs"
                No      = "Proceed to Step 3"
            }
            @{
                Step    = 3
                Question = "Is overtime driving the cost up?"
                Yes     = "Review driver schedules — reassign to avoid overtime rates"
                No      = "Log for weekly cost review — no immediate action needed"
            }
        )
    }

    # ── IT INFRASTRUCTURE ────────────────────────────────────
    "IT-SERVER-DOWN" = @{
        Domain      = "IT"
        Trigger     = "Fleet Availability below 70% or CPU Load above 90%"
        Title       = "Server Down Response"
        Steps       = @(
            @{
                Step    = 1
                Question = "Is the server responding to ping?"
                Yes     = "Service likely crashed — attempt service restart"
                No      = "Proceed to Step 2"
            }
            @{
                Step    = 2
                Question = "Is a backup server available?"
                Yes     = "Failover to backup server — notify users of temporary switch"
                No      = "Proceed to Step 3"
            }
            @{
                Step    = 3
                Question = "Can users work offline temporarily?"
                Yes     = "Notify all users — estimated recovery time?"
                No      = "ESCALATE — Call IT vendor immediately"
            }
            @{
                Step    = 4
                Question = "Is this affecting business-critical systems?"
                Yes     = "Declare incident — notify management and all affected departments"
                No      = "Continue recovery — update status every 15 minutes"
            }
        )
    }

    "IT-DISK-FULL" = @{
        Domain      = "IT"
        Trigger     = "Disk Space Free below 20%"
        Title       = "Disk Space Critical Response"
        Steps       = @(
            @{
                Step    = 1
                Question = "Are there old log files or temp files that can be deleted?"
                Yes     = "Run disk cleanup — delete logs older than 30 days"
                No      = "Proceed to Step 2"
            }
            @{
                Step    = 2
                Question = "Are there old backups taking up space?"
                Yes     = "Move old backups to archive storage or external drive"
                No      = "Proceed to Step 3"
            }
            @{
                Step    = 3
                Question = "Can additional storage be added quickly?"
                Yes     = "Expand disk — contact IT vendor for emergency storage"
                No      = "ESCALATE — Risk of system crash within hours"
            }
        )
    }

    # ── MANUFACTURING ────────────────────────────────────────
    "MFG-MACHINE-BREAKDOWN" = @{
        Domain      = "Manufacturing"
        Trigger     = "Fleet Availability below 70% or Cost above threshold"
        Title       = "Machine Breakdown Response"
        Steps       = @(
            @{
                Step    = 1
                Question = "Is a backup machine or line available?"
                Yes     = "Switch production to backup line immediately"
                No      = "Proceed to Step 2"
            }
            @{
                Step    = 2
                Question = "Can production be rescheduled to another shift?"
                Yes     = "Reschedule — notify shift manager and production planner"
                No      = "Proceed to Step 3"
            }
            @{
                Step    = 3
                Question = "Is the repair estimated under 2 hours?"
                Yes     = "Hold production — begin repair immediately"
                No      = "ESCALATE — Notify customers of potential delivery delays"
            }
        )
    }

    # ── HEALTHCARE ───────────────────────────────────────────
    "HEALTH-BED-SHORTAGE" = @{
        Domain      = "Healthcare"
        Trigger     = "Capacity Utilisation above 95%"
        Title       = "Bed Shortage Response"
        Steps       = @(
            @{
                Step    = 1
                Question = "Are any patients ready for discharge today?"
                Yes     = "Expedite discharge process — free beds immediately"
                No      = "Proceed to Step 2"
            }
            @{
                Step    = 2
                Question = "Can any patients be transferred to another ward?"
                Yes     = "Coordinate transfer with receiving ward"
                No      = "Proceed to Step 3"
            }
            @{
                Step    = 3
                Question = "Can elective procedures be postponed?"
                Yes     = "Postpone non-urgent admissions — notify patients"
                No      = "ESCALATE — Activate hospital overflow protocol"
            }
        )
    }
}

# ============================================================
# START-VBAFCENTERCROSS
# ============================================================
function Start-VBAFCenterCrisis {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [string] $CrisisType = ""
    )

    $profilePath = Join-Path $env:USERPROFILE "VBAFCenter\customers\$CustomerID.json"
    if (-not (Test-Path $profilePath)) {
        Write-Host "Customer not found: $CustomerID" -ForegroundColor Red
        return
    }
    $profile = Get-Content $profilePath -Raw | ConvertFrom-Json

    Write-Host ""
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Red
    Write-Host "  |   VBAF-Center CRISIS RESPONSE ACTIVATED          |" -ForegroundColor Red
    Write-Host "  |   Follow the steps. Do not skip any.             |" -ForegroundColor Red
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Red
    Write-Host ("  |  Customer : {0,-39}|" -f $profile.CompanyName) -ForegroundColor White
    Write-Host ("  |  Time     : {0,-39}|" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) -ForegroundColor White
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Red
    Write-Host ""

    # Select crisis type
    if ($CrisisType -eq "") {
        Write-Host "  Select crisis type:" -ForegroundColor Yellow
        Write-Host ""

        $domain = $profile.BusinessType.ToLower()
        $relevant = $script:CrisisTrees.Keys | Where-Object {
            $script:CrisisTrees[$_].Domain.ToLower() -eq $domain -or
            $domain -eq "logistics" -and $_ -like "LOGISTICS-*" -or
            $domain -eq "it" -and $_ -like "IT-*" -or
            $domain -eq "manufacturing" -and $_ -like "MFG-*" -or
            $domain -eq "healthcare" -and $_ -like "HEALTH-*"
        }

        if ($relevant.Count -eq 0) { $relevant = $script:CrisisTrees.Keys }

        $i = 1
        $menu = @{}
        foreach ($key in ($relevant | Sort-Object)) {
            $tree = $script:CrisisTrees[$key]
            Write-Host ("  {0}. {1}" -f $i, $tree.Title) -ForegroundColor White
            Write-Host ("     Trigger: {0}" -f $tree.Trigger) -ForegroundColor DarkGray
            $menu[$i.ToString()] = $key
            $i++
        }

        Write-Host ""
        $choice = Read-Host "  Enter number"
        $CrisisType = $menu[$choice]
        if (-not $CrisisType) {
            Write-Host "  Invalid selection." -ForegroundColor Red
            return
        }
    }

    $tree = $script:CrisisTrees[$CrisisType]
    if (-not $tree) {
        Write-Host "Crisis type not found: $CrisisType" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host ("  CRISIS: {0}" -f $tree.Title) -ForegroundColor Red
    Write-Host ("  Trigger: {0}" -f $tree.Trigger) -ForegroundColor Yellow
    Write-Host ""

    $responses   = @()
    $startTime   = Get-Date
    $allResolved = $true

    foreach ($step in $tree.Steps) {
        Write-Host ("  ─── Step {0} ───" -f $step.Step) -ForegroundColor Cyan
        Write-Host ("  {0}" -f $step.Question) -ForegroundColor White
        Write-Host ""
        Write-Host "  Y = Yes    N = No" -ForegroundColor DarkGray
        Write-Host ""

        $answer = Read-Host "  Your answer (Y/N)"

        if ($answer.ToUpper() -eq "Y") {
            Write-Host ""
            Write-Host ("  ACTION: {0}" -f $step.Yes) -ForegroundColor Green
            $responses += @{ Step=$step.Step; Question=$step.Question; Answer="Yes"; Action=$step.Yes }

            Write-Host ""
            $confirm = Read-Host "  Action taken? Mark as done (Y/N)"
            if ($confirm.ToUpper() -eq "Y") {
                Write-Host "  Step $($step.Step) complete." -ForegroundColor Green
                break
            }
        } else {
            Write-Host ""
            Write-Host ("  CONTINUE: {0}" -f $step.No) -ForegroundColor Yellow
            $responses += @{ Step=$step.Step; Question=$step.Question; Answer="No"; Action=$step.No }
            Write-Host ""

            if ($step.No -like "ESCALATE*") {
                $allResolved = $false
            }
        }
        Write-Host ""
    }

    $endTime     = Get-Date
    $duration    = [Math]::Round(($endTime - $startTime).TotalMinutes, 1)
    $resolution  = if ($allResolved) { "Resolved" } else { "Escalated" }
    $resColor    = if ($allResolved) { "Green" } else { "Red" }

    # Save crisis log
    $historyPath = Join-Path $env:USERPROFILE "VBAFCenter\crisis"
    if (-not (Test-Path $historyPath)) { New-Item -ItemType Directory -Path $historyPath -Force | Out-Null }
    $logFile = Join-Path $historyPath "$CustomerID-crisis-$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    @{
        CustomerID  = $CustomerID
        CrisisType  = $CrisisType
        Title       = $tree.Title
        StartTime   = $startTime.ToString("yyyy-MM-dd HH:mm:ss")
        EndTime     = $endTime.ToString("yyyy-MM-dd HH:mm:ss")
        Duration    = $duration
        Resolution  = $resolution
        Responses   = $responses
    } | ConvertTo-Json -Depth 5 | Set-Content $logFile -Encoding UTF8

    Write-Host ""
    Write-Host "  +--------------------------------------------------+" -ForegroundColor $resColor
    Write-Host ("  |  Crisis Resolution: {0,-31}|" -f $resolution) -ForegroundColor $resColor
    Write-Host ("  |  Duration  : {0} minutes{1,-30}|" -f $duration, "") -ForegroundColor White
    Write-Host ("  |  Logged to : {0,-35}|" -f (Split-Path $logFile -Leaf)) -ForegroundColor White
    Write-Host "  +--------------------------------------------------+" -ForegroundColor $resColor
    Write-Host ""
}

# ============================================================
# GET-VBAFCENTERCRISISTREEE
# ============================================================
function Get-VBAFCenterCrisisTree {

    Write-Host ""
    Write-Host "  VBAF-Center Crisis Trees" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("  {0,-35} {1,-15} {2}" -f "Crisis Type", "Domain", "Steps") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 70)) -ForegroundColor DarkGray

    foreach ($key in ($script:CrisisTrees.Keys | Sort-Object)) {
        $tree = $script:CrisisTrees[$key]
        Write-Host ("  {0,-35} {1,-15} {2}" -f $tree.Title, $tree.Domain, $tree.Steps.Count) -ForegroundColor White
    }
    Write-Host ""
}

# ============================================================
# NEW-VBAFCENTERCRISISTREEE
# ============================================================
function New-VBAFCenterCrisisTree {
    param(
        [Parameter(Mandatory)] [string] $TreeKey,
        [Parameter(Mandatory)] [string] $Domain,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [string] $Trigger
    )

    $script:CrisisTrees[$TreeKey] = @{
        Domain  = $Domain
        Trigger = $Trigger
        Title   = $Title
        Steps   = @()
    }

    Write-Host ("Crisis tree added: {0}" -f $Title) -ForegroundColor Green
}

# ============================================================
# GET-VBAFCENTERCRISISHISTORY
# ============================================================
function Get-VBAFCenterCrisisHistory {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [int] $Last = 10
    )

    $historyPath = Join-Path $env:USERPROFILE "VBAFCenter\crisis"
    if (-not (Test-Path $historyPath)) {
        Write-Host "No crisis history found." -ForegroundColor Yellow
        return
    }

    $logs = Get-ChildItem $historyPath -Filter "$CustomerID-crisis-*.json" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First $Last

    if ($logs.Count -eq 0) {
        Write-Host "No crisis history for $CustomerID." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host ("  Crisis History: {0} (last {1})" -f $CustomerID, $Last) -ForegroundColor Cyan
    Write-Host ("  {0,-22} {1,-30} {2,-12} {3}" -f "Time", "Crisis", "Duration", "Resolution") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 80)) -ForegroundColor DarkGray

    foreach ($log in $logs) {
        $h = Get-Content $log.FullName -Raw | ConvertFrom-Json
        $color = if ($h.Resolution -eq "Resolved") { "Green" } else { "Red" }
        Write-Host ("  {0,-22} {1,-30} {2,-12} {3}" -f $h.StartTime, $h.Title, "$($h.Duration) min", $h.Resolution) -ForegroundColor $color
    }
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Red
Write-Host "  |  VBAF-Center Phase 13 - Crisis Response Tree    |" -ForegroundColor Red
Write-Host "  |  Step-by-step recovery when signals go critical |" -ForegroundColor Red
Write-Host "  +--------------------------------------------------+" -ForegroundColor Red
Write-Host ""
Write-Host "  Start-VBAFCenterCrisis      — activate crisis wizard"    -ForegroundColor White
Write-Host "  Get-VBAFCenterCrisisTree    — show all crisis trees"     -ForegroundColor White
Write-Host "  New-VBAFCenterCrisisTree    — add custom crisis tree"    -ForegroundColor White
Write-Host "  Get-VBAFCenterCrisisHistory — show past crisis responses"-ForegroundColor White
Write-Host ""
Write-Host "  Quick start:" -ForegroundColor Yellow
Write-Host "  Start-VBAFCenterCrisis -CustomerID 'TruckCompanyDK'" -ForegroundColor Green
Write-Host "  Get-VBAFCenterCrisisTree" -ForegroundColor Green
Write-Host ""