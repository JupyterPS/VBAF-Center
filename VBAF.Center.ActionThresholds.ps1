#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 17 — Smart Action Map
.DESCRIPTION
    Customer-specific action thresholds.
    Each customer gets their own sensitivity settings
    instead of the fixed default 0.25 / 0.50 / 0.75.

    The reading side is already built into Router.ps1.
    This file provides the user-facing functions to
    set, view and test thresholds per customer.

    Functions:
      Set-VBAFCenterActionThresholds  — save thresholds to schedule.json
      Get-VBAFCenterActionThresholds  — show current thresholds
      Test-VBAFCenterActionThresholds — simulate action at a given average
      Reset-VBAFCenterActionThresholds — reset to default values
#>

$script:Phase17SchedulePath = Join-Path $env:USERPROFILE "VBAFCenter\schedules"

# ============================================================
# SET-VBAFCENTERACTIONTHRESHOLDS
# ============================================================
function Set-VBAFCenterActionThresholds {
    <#
    .SYNOPSIS
        Save customer-specific action thresholds to schedule.json.
        Router.ps1 reads these automatically on every run.
    .EXAMPLE
        Set-VBAFCenterActionThresholds -CustomerID "TruckCompanyDK" -Action1 0.20 -Action2 0.40 -Action3 0.65
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [double] $Action1 = 0.25,   # Reassign threshold
        [double] $Action2 = 0.50,   # Reroute threshold
        [double] $Action3 = 0.75    # Escalate threshold
    )

    # Validate thresholds are in ascending order
    if ($Action1 -ge $Action2) {
        Write-Host "Action1 must be less than Action2." -ForegroundColor Red
        return
    }
    if ($Action2 -ge $Action3) {
        Write-Host "Action2 must be less than Action3." -ForegroundColor Red
        return
    }
    if ($Action3 -gt 1.0) {
        Write-Host "Action3 cannot exceed 1.0." -ForegroundColor Red
        return
    }

    $schedFile = Join-Path $script:Phase17SchedulePath "$CustomerID-schedule.json"
    if (-not (Test-Path $schedFile)) {
        Write-Host "No schedule found for: $CustomerID" -ForegroundColor Red
        Write-Host "Run Start-VBAFCenterOnboarding first." -ForegroundColor Yellow
        return
    }

    $sched = Get-Content $schedFile -Raw | ConvertFrom-Json

    # Add or update threshold properties
    $sched | Add-Member -MemberType NoteProperty -Name Action1Threshold -Value $Action1 -Force
    $sched | Add-Member -MemberType NoteProperty -Name Action2Threshold -Value $Action2 -Force
    $sched | Add-Member -MemberType NoteProperty -Name Action3Threshold -Value $Action3 -Force

    $sched | ConvertTo-Json -Depth 5 | Set-Content $schedFile -Encoding UTF8

    Write-Host ""
    Write-Host "Action thresholds saved!" -ForegroundColor Green
    Write-Host ("  Customer  : {0}" -f $CustomerID) -ForegroundColor White
    Write-Host ""
    Write-Host ("  Avg below {0:F2} -> Monitor   (0)" -f $Action1) -ForegroundColor Green
    Write-Host ("  Avg below {0:F2} -> Reassign  (1)" -f $Action2) -ForegroundColor Yellow
    Write-Host ("  Avg below {0:F2} -> Reroute   (2)" -f $Action3) -ForegroundColor DarkYellow
    Write-Host ("  Avg above {0:F2} -> Escalate  (3)" -f $Action3) -ForegroundColor Red
    Write-Host ""
    Write-Host "  Router.ps1 will use these thresholds on next Invoke-VBAFCenterRun." -ForegroundColor DarkGray
    Write-Host ""
}

# ============================================================
# GET-VBAFCENTERACTIONTHRESHOLDS
# ============================================================
function Get-VBAFCenterActionThresholds {
    <#
    .SYNOPSIS
        Show current action thresholds for a customer.
        Shows whether default or customer-specific thresholds are active.
    .EXAMPLE
        Get-VBAFCenterActionThresholds -CustomerID "TruckCompanyDK"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID
    )

    $schedFile = Join-Path $script:Phase17SchedulePath "$CustomerID-schedule.json"
    if (-not (Test-Path $schedFile)) {
        Write-Host "No schedule found for: $CustomerID" -ForegroundColor Red
        return
    }

    $sched = Get-Content $schedFile -Raw | ConvertFrom-Json

    $a1 = if ($null -ne $sched.Action1Threshold) { [double]$sched.Action1Threshold } else { 0.25 }
    $a2 = if ($null -ne $sched.Action2Threshold) { [double]$sched.Action2Threshold } else { 0.50 }
    $a3 = if ($null -ne $sched.Action3Threshold) { [double]$sched.Action3Threshold } else { 0.75 }

    $custom = ($null -ne $sched.Action1Threshold -or
               $null -ne $sched.Action2Threshold -or
               $null -ne $sched.Action3Threshold)

    $label = if ($custom) { "customer-specific" } else { "default" }

    Write-Host ""
    Write-Host ("Action Thresholds: {0} [{1}]" -f $CustomerID, $label) -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("  Avg 0.00 - {0:F2}  ->  Monitor   (0)" -f $a1) -ForegroundColor Green
    Write-Host ("  Avg {0:F2} - {1:F2}  ->  Reassign  (1)" -f $a1, $a2) -ForegroundColor Yellow
    Write-Host ("  Avg {0:F2} - {1:F2}  ->  Reroute   (2)" -f $a2, $a3) -ForegroundColor DarkYellow
    Write-Host ("  Avg {0:F2} - 1.00  ->  Escalate  (3)" -f $a3) -ForegroundColor Red
    Write-Host ""

    if (-not $custom) {
        Write-Host "  Using default thresholds." -ForegroundColor DarkGray
        Write-Host "  Run Set-VBAFCenterActionThresholds to customise." -ForegroundColor DarkGray
    } else {
        Write-Host "  Customer-specific thresholds active." -ForegroundColor Cyan
        Write-Host "  Run Reset-VBAFCenterActionThresholds to restore defaults." -ForegroundColor DarkGray
    }

    Write-Host ""

    return [PSCustomObject] @{
        CustomerID = $CustomerID
        Action1    = $a1
        Action2    = $a2
        Action3    = $a3
        Custom     = $custom
    }
}

# ============================================================
# TEST-VBAFCENTERACTIONTHRESHOLDS
# ============================================================
function Test-VBAFCenterActionThresholds {
    <#
    .SYNOPSIS
        Simulate which action fires at a given average signal level.
        Use this to calibrate thresholds before going live.
    .EXAMPLE
        Test-VBAFCenterActionThresholds -CustomerID "TruckCompanyDK" -SimulatedAverage 0.55
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [Parameter(Mandatory)] [double] $SimulatedAverage
    )

    $thresholds = Get-VBAFCenterActionThresholds -CustomerID $CustomerID

    $action = if      ($SimulatedAverage -lt $thresholds.Action1) { 0 }
              elseif  ($SimulatedAverage -lt $thresholds.Action2) { 1 }
              elseif  ($SimulatedAverage -lt $thresholds.Action3) { 2 }
              else                                                  { 3 }

    $actionNames  = @("Monitor","Reassign","Reroute","Escalate")
    $actionColors = @("Green","Yellow","DarkYellow","Red")

    Write-Host ""
    Write-Host ("Threshold Test: {0}" -f $CustomerID) -ForegroundColor Cyan
    Write-Host ("  Simulated avg : {0:F4}" -f $SimulatedAverage) -ForegroundColor White
    Write-Host ("  Result        : {0} — {1}" -f $action, $actionNames[$action]) -ForegroundColor $actionColors[$action]
    Write-Host ""
}

# ============================================================
# RESET-VBAFCENTERACTIONTHRESHOLDS
# ============================================================
function Reset-VBAFCenterActionThresholds {
    <#
    .SYNOPSIS
        Remove customer-specific thresholds and restore defaults (0.25/0.50/0.75).
    .EXAMPLE
        Reset-VBAFCenterActionThresholds -CustomerID "TruckCompanyDK"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID
    )

    $schedFile = Join-Path $script:Phase17SchedulePath "$CustomerID-schedule.json"
    if (-not (Test-Path $schedFile)) {
        Write-Host "No schedule found for: $CustomerID" -ForegroundColor Red
        return
    }

    $sched = Get-Content $schedFile -Raw | ConvertFrom-Json

    # Remove threshold properties if they exist
    $sched.PSObject.Properties.Remove("Action1Threshold")
    $sched.PSObject.Properties.Remove("Action2Threshold")
    $sched.PSObject.Properties.Remove("Action3Threshold")

    $sched | ConvertTo-Json -Depth 5 | Set-Content $schedFile -Encoding UTF8

    Write-Host ""
    Write-Host ("Thresholds reset to defaults for: {0}" -f $CustomerID) -ForegroundColor Green
    Write-Host "  Monitor   below 0.25" -ForegroundColor Green
    Write-Host "  Reassign  below 0.50" -ForegroundColor Yellow
    Write-Host "  Reroute   below 0.75" -ForegroundColor DarkYellow
    Write-Host "  Escalate  above 0.75" -ForegroundColor Red
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host "VBAF-Center Phase 17 loaded  [Smart Action Map]" -ForegroundColor Cyan
Write-Host "  Set-VBAFCenterActionThresholds   — save customer thresholds"   -ForegroundColor White
Write-Host "  Get-VBAFCenterActionThresholds   — show current thresholds"    -ForegroundColor White
Write-Host "  Test-VBAFCenterActionThresholds  — simulate action at avg"     -ForegroundColor White
Write-Host "  Reset-VBAFCenterActionThresholds — restore defaults"           -ForegroundColor White
Write-Host ""
