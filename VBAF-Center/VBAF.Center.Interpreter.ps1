#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 6 — Action Interpreter
#>

$script:ActionMapPath = Join-Path $env:USERPROFILE "VBAFCenter\actions"

function Initialize-VBAFCenterActionStore {
    if (-not (Test-Path $script:ActionMapPath)) {
        New-Item -ItemType Directory -Path $script:ActionMapPath -Force | Out-Null
    }
}

function New-VBAFCenterActionMap {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [Parameter(Mandatory)] [string] $Action0Name,
        [Parameter(Mandatory)] [string] $Action0Command,
        [Parameter(Mandatory)] [string] $Action1Name,
        [Parameter(Mandatory)] [string] $Action1Command,
        [Parameter(Mandatory)] [string] $Action2Name,
        [Parameter(Mandatory)] [string] $Action2Command,
        [Parameter(Mandatory)] [string] $Action3Name,
        [Parameter(Mandatory)] [string] $Action3Command
    )

    Initialize-VBAFCenterActionStore

    $lines = @(
        "0|$Action0Name|$Action0Command",
        "1|$Action1Name|$Action1Command",
        "2|$Action2Name|$Action2Command",
        "3|$Action3Name|$Action3Command"
    )

    $path = Join-Path $script:ActionMapPath "$CustomerID-actions.txt"
    Set-Content $path -Value $lines -Encoding UTF8

    Write-Host ""
    Write-Host "Action map saved: $CustomerID" -ForegroundColor Green
    Write-Host ("  Action 0 : {0} — {1}" -f $Action0Name, $Action0Command) -ForegroundColor White
    Write-Host ("  Action 1 : {0} — {1}" -f $Action1Name, $Action1Command) -ForegroundColor White
    Write-Host ("  Action 2 : {0} — {1}" -f $Action2Name, $Action2Command) -ForegroundColor White
    Write-Host ("  Action 3 : {0} — {1}" -f $Action3Name, $Action3Command) -ForegroundColor White
    Write-Host ""
}

function Invoke-VBAFCenterInterpret {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [Parameter(Mandatory)] [int]    $Action
    )

    Initialize-VBAFCenterActionStore

    $path = Join-Path $script:ActionMapPath "$CustomerID-actions.txt"

    if (-not (Test-Path $path)) {
        $genericNames    = @("Monitor","Reassign","Reroute","Escalate")
        $genericCommands = @(
            "No action needed — continue monitoring",
            "Reassign available resource to pending task",
            "Switch to alternative route or approach",
            "Emergency — deploy all available resources"
        )
        Write-Host "No action map found — using generic." -ForegroundColor Yellow
        $result = @{ CustomerID=$CustomerID; Action=$Action; ActionName=$genericNames[$Action]; Command=$genericCommands[$Action]; Timestamp=(Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
        Write-Host ""
        Write-Host "Action Interpretation:" -ForegroundColor Cyan
        Write-Host ("  Customer  : {0}" -f $CustomerID)                  -ForegroundColor White
        Write-Host ("  Action    : {0}" -f $Action)                      -ForegroundColor White
        Write-Host ("  Name      : {0}" -f $result.ActionName)           -ForegroundColor Green
        Write-Host ("  Command   : {0}" -f $result.Command)              -ForegroundColor Green
        Write-Host ("  Time      : {0}" -f $result.Timestamp)            -ForegroundColor White
        Write-Host ""
        return $result
    }

    $lines = Get-Content $path
    $actionName    = ""
    $actionCommand = ""

    foreach ($line in $lines) {
        $parts = $line -split "\|"
        if ([int]$parts[0] -eq $Action) {
            $actionName    = $parts[1]
            $actionCommand = $parts[2]
            break
        }
    }

    $result = @{
        CustomerID = $CustomerID
        Action     = $Action
        ActionName = $actionName
        Command    = $actionCommand
        Timestamp  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    Write-Host ""
    Write-Host "Action Interpretation:" -ForegroundColor Cyan
    Write-Host ("  Customer  : {0}" -f $CustomerID)     -ForegroundColor White
    Write-Host ("  Action    : {0}" -f $Action)          -ForegroundColor White
    Write-Host ("  Name      : {0}" -f $actionName)     -ForegroundColor Green
    Write-Host ("  Command   : {0}" -f $actionCommand)  -ForegroundColor Green
    Write-Host ("  Time      : {0}" -f $result.Timestamp) -ForegroundColor White
    Write-Host ""

    return $result
}

function Get-VBAFCenterActionMap {
    param(
        [Parameter(Mandatory)] [string] $CustomerID
    )

    Initialize-VBAFCenterActionStore

    $path = Join-Path $script:ActionMapPath "$CustomerID-actions.txt"

    if (-not (Test-Path $path)) {
        Write-Host "No action map found for: $CustomerID" -ForegroundColor Yellow
        return $null
    }

    $lines = Get-Content $path

    Write-Host ""
    Write-Host "Action Map: $CustomerID" -ForegroundColor Cyan
    Write-Host ("  {0,-8} {1,-15} {2}" -f "Action","Name","Command") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 65)) -ForegroundColor DarkGray

    foreach ($line in $lines) {
        $parts = $line -split "\|"
        Write-Host ("  {0,-8} {1,-15} {2}" -f $parts[0], $parts[1], $parts[2]) -ForegroundColor White
    }
    Write-Host ""
}

Write-Host "VBAF-Center Phase 6 loaded  [Action Interpreter]"       -ForegroundColor Cyan
Write-Host "  New-VBAFCenterActionMap    — define action meanings"   -ForegroundColor White
Write-Host "  Invoke-VBAFCenterInterpret — translate action number"  -ForegroundColor White
Write-Host "  Get-VBAFCenterActionMap    — show customer action map" -ForegroundColor White
Write-Host ""

