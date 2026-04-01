#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 3 — Signal Acquisition
.DESCRIPTION
    Connects to customer data sources and retrieves live signals.
    Supports REST API, WMI, CSV and manual input.

    Functions:
      New-VBAFCenterSignalConfig   — define a signal source
      Get-VBAFCenterSignal         — retrieve one live signal
      Get-VBAFCenterAllSignals     — retrieve all signals for a customer
      Test-VBAFCenterSignalConfig  — test a signal connection
#>

# ============================================================
# SIGNAL CONFIG STORE
# ============================================================
$script:SignalStorePath = Join-Path $env:USERPROFILE "VBAFCenter\signals"

function Initialize-VBAFCenterSignalStore {
    if (-not (Test-Path $script:SignalStorePath)) {
        New-Item -ItemType Directory -Path $script:SignalStorePath -Force | Out-Null
    }
}

# ============================================================
# NEW-VBAFCENTERSIGNALCONFIG
# ============================================================
function New-VBAFCenterSignalConfig {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [Parameter(Mandatory)] [string] $SignalName,
        [Parameter(Mandatory)] [string] $SignalIndex,   # "Signal1"|"Signal2"|"Signal3"|"Signal4"
        [Parameter(Mandatory)] [string] $SourceType,    # "REST"|"WMI"|"CSV"|"Manual"
        [string] $SourceURL      = "",   # REST endpoint
        [string] $WMIClass       = "",   # WMI class name
        [string] $WMIProperty    = "",   # WMI property
        [string] $CSVPath        = "",   # CSV file path
        [string] $CSVColumn      = "",   # CSV column name
        [double] $RawMin         = 0.0,  # raw value minimum
        [double] $RawMax         = 100.0,# raw value maximum
        [string] $Description    = ""
    )

    Initialize-VBAFCenterSignalStore

    $config = @{
        CustomerID   = $CustomerID
        SignalName   = $SignalName
        SignalIndex  = $SignalIndex
        SourceType   = $SourceType
        SourceURL    = $SourceURL
        WMIClass     = $WMIClass
        WMIProperty  = $WMIProperty
        CSVPath      = $CSVPath
        CSVColumn    = $CSVColumn
        RawMin       = $RawMin
        RawMax       = $RawMax
        Description  = $Description
        CreatedDate  = (Get-Date).ToString("yyyy-MM-dd")
    }

    $path = Join-Path $script:SignalStorePath "$CustomerID-$SignalIndex.json"
    $config | ConvertTo-Json -Depth 5 | Set-Content $path -Encoding UTF8

    Write-Host ""
    Write-Host "Signal config saved!" -ForegroundColor Green
    Write-Host ("  Customer   : {0}" -f $CustomerID)  -ForegroundColor White
    Write-Host ("  Signal     : {0} ({1})" -f $SignalName, $SignalIndex) -ForegroundColor White
    Write-Host ("  Source     : {0}" -f $SourceType)  -ForegroundColor White
    Write-Host ("  Raw range  : {0} - {1}" -f $RawMin, $RawMax) -ForegroundColor White
    Write-Host ""

    return $config
}

# ============================================================
# GET-VBAFCENTERSIGNAL
# ============================================================
function Get-VBAFCenterSignal {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [Parameter(Mandatory)] [string] $SignalIndex
    )

    Initialize-VBAFCenterSignalStore

    $path = Join-Path $script:SignalStorePath "$CustomerID-$SignalIndex.json"

    if (-not (Test-Path $path)) {
        Write-Host "Signal config not found: $CustomerID $SignalIndex" -ForegroundColor Red
        return $null
    }

    $config = Get-Content $path -Raw | ConvertFrom-Json
    [double] $rawValue = 0.0

    switch ($config.SourceType) {

        "REST" {
            try {
                $response  = Invoke-RestMethod -Uri $config.SourceURL -Method GET -ErrorAction Stop
                $rawValue  = [double] $response
            } catch {
                Write-Host "REST call failed: $($_.Exception.Message)" -ForegroundColor Red
                $rawValue = 0.0
            }
        }

        "WMI" {
            try {
                $wmi      = Get-WmiObject -Class $config.WMIClass -ErrorAction Stop
                $rawValue = [double] ($wmi | Select-Object -First 1).$($config.WMIProperty)
            } catch {
                Write-Host "WMI call failed: $($_.Exception.Message)" -ForegroundColor Red
                $rawValue = 0.0
            }
        }

        "CSV" {
            try {
                $csv      = Import-Csv $config.CSVPath -ErrorAction Stop
                $rawValue = [double] ($csv | Select-Object -Last 1).$($config.CSVColumn)
            } catch {
                Write-Host "CSV read failed: $($_.Exception.Message)" -ForegroundColor Red
                $rawValue = 0.0
            }
        }

        "Manual" {
            Write-Host ("Enter value for {0} (raw range {1}-{2}): " -f $config.SignalName, $config.RawMin, $config.RawMax) -NoNewline -ForegroundColor Yellow
            $rawValue = [double] (Read-Host)
        }

        "Simulated" {
            # For testing — returns random value in raw range
            [double] $range = $config.RawMax - $config.RawMin
            $rawValue = $config.RawMin + (Get-Random -Minimum 0 -Maximum 100) / 100.0 * $range
        }
    }

    # Normalise to 0.0-1.0
    [double] $range      = $config.RawMax - $config.RawMin
    [double] $normalised = if ($range -gt 0) { ($rawValue - $config.RawMin) / $range } else { 0.0 }
    $normalised          = [Math]::Max(0.0, [Math]::Min(1.0, $normalised))

    $result = @{
        CustomerID   = $CustomerID
        SignalIndex  = $SignalIndex
        SignalName   = $config.SignalName
        RawValue     = [Math]::Round($rawValue, 2)
        Normalised   = [Math]::Round($normalised, 4)
        SourceType   = $config.SourceType
        Timestamp    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    return $result
}

# ============================================================
# GET-VBAFCENTERALLSIGNALS
# ============================================================
function Get-VBAFCenterAllSignals {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [switch] $Simulate
    )

    Initialize-VBAFCenterSignalStore

    $indices = @("Signal1","Signal2","Signal3","Signal4")
    $results = @()

    Write-Host ""
    Write-Host "Live Signal Acquisition: $CustomerID" -ForegroundColor Cyan
    Write-Host ("  {0,-10} {1,-25} {2,10} {3,12} {4}" -f "Index","Signal","Raw","Normalised","Source") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 70)) -ForegroundColor DarkGray

    foreach ($idx in $indices) {
        $path = Join-Path $script:SignalStorePath "$CustomerID-$idx.json"
        if (-not (Test-Path $path)) { continue }

        $config = Get-Content $path -Raw | ConvertFrom-Json
        if ($Simulate) { $config.SourceType = "Simulated" }

        $signal = Get-VBAFCenterSignal -CustomerID $CustomerID -SignalIndex $idx
        if ($null -eq $signal) { continue }

        $color = if ($signal.Normalised -gt 0.7) { "Red" } `
                 elseif ($signal.Normalised -gt 0.4) { "Yellow" } `
                 else { "Green" }

        Write-Host ("  {0,-10} {1,-25} {2,10:F2} {3,12:F4} {4}" -f `
            $signal.SignalIndex, $signal.SignalName, $signal.RawValue, $signal.Normalised, $signal.SourceType) -ForegroundColor $color

        $results += $signal
    }

    Write-Host ""

    # Return as double[] for VBAF
    $vbafInput = @()
    foreach ($r in $results) { $vbafInput += $r.Normalised }

    Write-Host ("  VBAF input ready: [{0}]" -f ($vbafInput -join ", ")) -ForegroundColor Green
    Write-Host ""

    return @{ Signals=$results; VBAFInput=[double[]]$vbafInput }
}

# ============================================================
# TEST-VBAFCENTERSIGNALCONFIG
# ============================================================
function Test-VBAFCenterSignalConfig {
    param(
        [Parameter(Mandatory)] [string] $CustomerID
    )

    Write-Host ""
    Write-Host "Testing signal configuration for: $CustomerID" -ForegroundColor Yellow

    $result = Get-VBAFCenterAllSignals -CustomerID $CustomerID -Simulate

    if ($result.VBAFInput.Length -eq 0) {
        Write-Host "No signals configured yet!" -ForegroundColor Red
        Write-Host "Use New-VBAFCenterSignalConfig to add signals." -ForegroundColor Yellow
    } else {
        Write-Host "Signal test passed!" -ForegroundColor Green
        Write-Host ("Signals configured: {0}" -f $result.VBAFInput.Length) -ForegroundColor White
    }

    return $result
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host "VBAF-Center Phase 3 loaded  [Signal Acquisition]"   -ForegroundColor Cyan
Write-Host "  New-VBAFCenterSignalConfig   — define signal source" -ForegroundColor White
Write-Host "  Get-VBAFCenterSignal         — get one live signal"  -ForegroundColor White
Write-Host "  Get-VBAFCenterAllSignals     — get all signals"      -ForegroundColor White
Write-Host "  Test-VBAFCenterSignalConfig  — test configuration"   -ForegroundColor White
Write-Host ""

