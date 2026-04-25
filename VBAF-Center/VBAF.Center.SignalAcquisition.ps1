#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 3 — Signal Acquisition
.DESCRIPTION
    Connects to customer data sources and retrieves live signals.
    Supports REST API, WMI, CSV, Manual and Simulated input.

    Phase 14 — Signal Thresholds (GoodBelow / BadAbove per signal)
    Phase 15 — Signal Weights (1-5 importance per signal)

    Functions:
      New-VBAFCenterSignalConfig      — define a signal source
      Get-VBAFCenterSignal            — retrieve one live signal
      Get-VBAFCenterAllSignals        — retrieve all signals for a customer
      Test-VBAFCenterSignalConfig     — test a signal connection
      Get-VBAFCenterSignalStatus      — show signal colours and threshold status
      Invoke-VBAFCenterThresholdCheck — show only Red and Yellow signals
      Set-VBAFCenterSignalThreshold   — update thresholds without full reconfiguration
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
        [Parameter(Mandatory)] [string] $SignalIndex,   # "Signal1"|"Signal2"|"Signal3" etc
        [Parameter(Mandatory)] [string] $SourceType,    # "REST"|"WMI"|"CSV"|"Manual"|"Simulated"
        [string] $SourceURL      = "",       # REST endpoint
        [string] $JSONPath       = "",       # dot-notation path e.g. "current.wind_speed_10m"
        [string] $WMIClass       = "",       # WMI class name
        [string] $WMIProperty    = "",       # WMI property
        [string] $CSVPath        = "",       # CSV file path
        [string] $CSVColumn      = "",       # CSV column name
        [double] $RawMin         = 0.0,      # raw value minimum
        [double] $RawMax         = 100.0,    # raw value maximum
        [string] $Description    = "",

        # Phase 14 — Signal Thresholds
        [double] $GoodBelow      = -1,       # raw value below this = Green  (-1 = not set)
        [double] $BadAbove       = -1,       # raw value above this = Red    (-1 = not set)

        # Phase 15 — Signal Weight
        [ValidateRange(1,5)]
        [int]    $Weight         = 3         # 1=low importance, 3=normal, 5=critical
    )

    Initialize-VBAFCenterSignalStore

    $config = @{
        CustomerID   = $CustomerID
        SignalName   = $SignalName
        SignalIndex  = $SignalIndex
        SourceType   = $SourceType
        SourceURL    = $SourceURL
        JSONPath     = $JSONPath
        WMIClass     = $WMIClass
        WMIProperty  = $WMIProperty
        CSVPath      = $CSVPath
        CSVColumn    = $CSVColumn
        RawMin       = $RawMin
        RawMax       = $RawMax
        Description  = $Description
        GoodBelow    = $GoodBelow
        BadAbove     = $BadAbove
        Weight       = $Weight
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
    Write-Host ("  Weight     : {0}/5" -f $Weight) -ForegroundColor White

    if ($GoodBelow -ge 0 -or $BadAbove -ge 0) {
        $goodStr = if ($GoodBelow -ge 0) { "below $GoodBelow = Green" } else { "not set" }
        $badStr  = if ($BadAbove  -ge 0) { "above $BadAbove = Red"   } else { "not set" }
        Write-Host ("  Thresholds : Good {0}  |  Bad {1}" -f $goodStr, $badStr) -ForegroundColor Cyan
    } else {
        Write-Host "  Thresholds : not configured (using normalised fallback)" -ForegroundColor DarkGray
    }
    Write-Host ""

    return $config
}

# ============================================================
# RESOLVE-VBAFCENTERSIGNALCOLOUR  (internal helper)
# ============================================================
function Resolve-VBAFCenterSignalColour {
    param(
        [double] $RawValue,
        [double] $Normalised,
        [double] $GoodBelow,
        [double] $BadAbove
    )

    # Phase 14 — threshold-based colouring (preferred)
    if ($GoodBelow -ge 0 -or $BadAbove -ge 0) {
        if ($BadAbove  -ge 0 -and $RawValue -gt $BadAbove)  { return "Red"    }
        if ($GoodBelow -ge 0 -and $RawValue -lt $GoodBelow) { return "Green"  }
        return "Yellow"
    }

    # Fallback — normalised-based colouring (backwards compatible)
    if ($Normalised -gt 0.7) { return "Red"    }
    if ($Normalised -gt 0.4) { return "Yellow" }
    return "Green"
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
                $response = Invoke-RestMethod -Uri $config.SourceURL -Method GET -ErrorAction Stop
                if ($config.JSONPath -and $config.JSONPath -ne "") {
                    $parts = $config.JSONPath -split "\."
                    $value = $response
                    foreach ($part in $parts) { $value = $value.$part }
                    $rawValue = [double] $value
                } else {
                    $rawValue = [double] $response
                }
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
            [double] $range = $config.RawMax - $config.RawMin
            $rawValue = $config.RawMin + (Get-Random -Minimum 0 -Maximum 100) / 100.0 * $range
        }
    }

    # Normalise to 0.0-1.0
    [double] $range      = $config.RawMax - $config.RawMin
    [double] $normalised = if ($range -gt 0) { ($rawValue - $config.RawMin) / $range } else { 0.0 }
    $normalised          = [Math]::Max(0.0, [Math]::Min(1.0, $normalised))

    # Phase 14 — resolve signal colour from thresholds
    $goodBelow = if ($null -ne $config.GoodBelow) { [double] $config.GoodBelow } else { -1 }
    $badAbove  = if ($null -ne $config.BadAbove)  { [double] $config.BadAbove  } else { -1 }
    $colour    = Resolve-VBAFCenterSignalColour -RawValue $rawValue -Normalised $normalised `
                                                -GoodBelow $goodBelow -BadAbove $badAbove

    # Phase 15 — read weight (default 3 if not stored)
    $weight = if ($null -ne $config.Weight -and $config.Weight -gt 0) { [int] $config.Weight } else { 3 }

    $result = [PSCustomObject] @{
        CustomerID       = $CustomerID
        SignalIndex      = $SignalIndex
        SignalName       = $config.SignalName
        RawValue         = [Math]::Round($rawValue, 2)
        Normalised       = [Math]::Round($normalised, 4)
        SignalColour     = $colour
        Weight           = $weight
        ThresholdActive  = ($goodBelow -ge 0 -or $badAbove -ge 0)
        GoodBelow        = $goodBelow
        BadAbove         = $badAbove
        SourceType       = $config.SourceType
        Timestamp        = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
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

    $indices = @("Signal1","Signal2","Signal3","Signal4","Signal5","Signal6",
                 "Signal7","Signal8","Signal9","Signal10")
    $results = @()

    Write-Host ""
    Write-Host "Live Signal Acquisition: $CustomerID" -ForegroundColor Cyan
    Write-Host ("  {0,-10} {1,-25} {2,10} {3,10} {4,6} {5,8} {6}" -f `
        "Index","Signal","Raw","Norm","Weight","Colour","Source") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 80)) -ForegroundColor DarkGray

    foreach ($idx in $indices) {
        $path = Join-Path $script:SignalStorePath "$CustomerID-$idx.json"
        if (-not (Test-Path $path)) { continue }

        if ($Simulate) {
            $config = Get-Content $path -Raw | ConvertFrom-Json
            $config.SourceType = "Simulated"
            $config | ConvertTo-Json -Depth 5 | Set-Content $path -Encoding UTF8
        }

        $signal = Get-VBAFCenterSignal -CustomerID $CustomerID -SignalIndex $idx
        if ($null -eq $signal) { continue }

        $consoleColour = switch ($signal.SignalColour) {
            "Red"    { "Red"    }
            "Yellow" { "Yellow" }
            default  { "Green"  }
        }

        $thresholdMark = if ($signal.ThresholdActive) { "*" } else { "" }

        Write-Host ("  {0,-10} {1,-25} {2,10:F2} {3,10:F4} {4,6} {5,8} {6}" -f `
            $signal.SignalIndex,
            $signal.SignalName,
            $signal.RawValue,
            $signal.Normalised,
            ("W{0}" -f $signal.Weight),
            ($signal.SignalColour + $thresholdMark),
            $signal.SourceType) -ForegroundColor $consoleColour

        $results += $signal
    }

    Write-Host ""
    Write-Host "  * = threshold-based colour active" -ForegroundColor DarkGray

    # Phase 14 — flag any RED signals
    $redSignals = $results | Where-Object { $_.SignalColour -eq "Red" }
    if ($redSignals) {
        Write-Host ""
        Write-Host "  ALERT — RED signals detected:" -ForegroundColor Red
        foreach ($r in $redSignals) {
            Write-Host ("    {0} ({1}) — raw value {2}" -f `
                $r.SignalName, $r.SignalIndex, $r.RawValue) -ForegroundColor Red
        }
    }

    Write-Host ""

    # Phase 15 — weighted average
    $weightedSum   = 0.0
    $weightTotal   = 0
    $simpleSum     = 0.0

    foreach ($r in $results) {
        $weightedSum += $r.Normalised * $r.Weight
        $weightTotal += $r.Weight
        $simpleSum   += $r.Normalised
    }

    $simpleAvg   = if ($results.Count -gt 0) { [Math]::Round($simpleSum / $results.Count, 4) } else { 0.0 }
    $weightedAvg = if ($weightTotal  -gt 0)  { [Math]::Round($weightedSum / $weightTotal,  4) } else { 0.0 }

    Write-Host ("  Simple average  (Phase 3 legacy) : {0:F4}" -f $simpleAvg)   -ForegroundColor DarkGray
    Write-Host ("  Weighted average (Phase 15 active): {0:F4}" -f $weightedAvg) -ForegroundColor Cyan
    Write-Host ""

    # Build VBAF input using weighted average logic
    $vbafInput = @()
    foreach ($r in $results) { $vbafInput += $r.Normalised }

    Write-Host ("  VBAF input ready: [{0}]" -f ($vbafInput -join ", ")) -ForegroundColor Green
    Write-Host ""

    return @{
        Signals       = $results
        VBAFInput     = [double[]] $vbafInput
        SimpleAvg     = $simpleAvg
        WeightedAvg   = $weightedAvg
        RedSignals    = @($redSignals)
        YellowSignals = @($results | Where-Object { $_.SignalColour -eq "Yellow" })
    }
}

# ============================================================
# GET-VBAFCENTERSIGNALSTATUS  (Phase 14 — new)
# ============================================================
function Get-VBAFCenterSignalStatus {
    <#
    .SYNOPSIS
        Shows full threshold status for all signals — Green / Yellow / Red.
    .EXAMPLE
        Get-VBAFCenterSignalStatus -CustomerID "TruckCompanyDK"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID
    )

    Write-Host ""
    Write-Host "Signal Status: $CustomerID" -ForegroundColor Cyan
    Write-Host ("  {0,-10} {1,-25} {2,10} {3,8} {4,10} {5,10} {6,8}" -f `
        "Index","Signal","Raw","Colour","GoodBelow","BadAbove","Weight") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 85)) -ForegroundColor DarkGray

    $result = Get-VBAFCenterAllSignals -CustomerID $CustomerID
    $greenCount  = 0
    $yellowCount = 0
    $redCount    = 0

    foreach ($s in $result.Signals) {
        $consoleColour = switch ($s.SignalColour) {
            "Red"    { "Red"    }
            "Yellow" { "Yellow" }
            default  { "Green"  }
        }

        $goodStr = if ($s.GoodBelow -ge 0) { $s.GoodBelow.ToString() } else { "---" }
        $badStr  = if ($s.BadAbove  -ge 0) { $s.BadAbove.ToString()  } else { "---" }

        Write-Host ("  {0,-10} {1,-25} {2,10:F2} {3,8} {4,10} {5,10} {6,8}" -f `
            $s.SignalIndex, $s.SignalName, $s.RawValue,
            $s.SignalColour, $goodStr, $badStr, ("W{0}" -f $s.Weight)) -ForegroundColor $consoleColour

        switch ($s.SignalColour) {
            "Green"  { $greenCount++  }
            "Yellow" { $yellowCount++ }
            "Red"    { $redCount++    }
        }
    }

    Write-Host ""
    Write-Host ("  Summary: {0} Green   {1} Yellow   {2} Red" -f `
        $greenCount, $yellowCount, $redCount) -ForegroundColor White

    if ($redCount -gt 0) {
        Write-Host "  One or more signals are RED — consider raising action level." -ForegroundColor Red
    } elseif ($yellowCount -gt 0) {
        Write-Host "  One or more signals are YELLOW — monitor closely." -ForegroundColor Yellow
    } else {
        Write-Host "  All signals GREEN — situation normal." -ForegroundColor Green
    }

    Write-Host ""
    return $result
}

# ============================================================
# INVOKE-VBAFCENTERTHRESHOLDCHECK  (Phase 14 — new)
# ============================================================
function Invoke-VBAFCenterThresholdCheck {
    <#
    .SYNOPSIS
        Shows only signals currently in Red or Yellow state.
        Returns nothing if all signals are Green.
    .EXAMPLE
        Invoke-VBAFCenterThresholdCheck -CustomerID "TruckCompanyDK"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID
    )

    $result = Get-VBAFCenterAllSignals -CustomerID $CustomerID
    $alerts = $result.Signals | Where-Object { $_.SignalColour -ne "Green" }

    Write-Host ""
    Write-Host "Threshold Check: $CustomerID" -ForegroundColor Cyan

    if (-not $alerts -or @($alerts).Count -eq 0) {
        Write-Host "  All signals GREEN — no threshold alerts." -ForegroundColor Green
        Write-Host ""
        return
    }

    Write-Host ("  {0} signal(s) require attention:" -f @($alerts).Count) -ForegroundColor Yellow
    Write-Host ""

    foreach ($s in $alerts) {
        $consoleColour = if ($s.SignalColour -eq "Red") { "Red" } else { "Yellow" }
        $badStr  = if ($s.BadAbove  -ge 0) { "BadAbove $($s.BadAbove)"   } else { "" }
        $goodStr = if ($s.GoodBelow -ge 0) { "GoodBelow $($s.GoodBelow)" } else { "" }

        Write-Host ("  [{0}] {1} ({2})" -f $s.SignalColour, $s.SignalName, $s.SignalIndex) -ForegroundColor $consoleColour
        Write-Host ("        Raw value : {0}   Threshold : {1} {2}" -f `
            $s.RawValue, $goodStr, $badStr) -ForegroundColor $consoleColour
        Write-Host ("        Weight    : {0}/5   Normalised : {1:F4}" -f `
            $s.Weight, $s.Normalised) -ForegroundColor DarkGray
        Write-Host ""
    }

    return $alerts
}

# ============================================================
# SET-VBAFCENTERSIGNALTHRESHOLD  (Phase 14 — new)
# ============================================================
function Set-VBAFCenterSignalThreshold {
    <#
    .SYNOPSIS
        Update GoodBelow, BadAbove and/or Weight for an existing signal
        without reconfiguring the full signal from scratch.
    .EXAMPLE
        Set-VBAFCenterSignalThreshold -CustomerID "TruckCompanyDK" -SignalIndex "Signal1" -GoodBelow 25 -BadAbove 40
        Set-VBAFCenterSignalThreshold -CustomerID "TruckCompanyDK" -SignalIndex "Signal2" -Weight 5
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [Parameter(Mandatory)] [string] $SignalIndex,
        [double] $GoodBelow = -999,   # -999 = not changing
        [double] $BadAbove  = -999,   # -999 = not changing
        [ValidateRange(1,5)]
        [int]    $Weight    = 0       # 0 = not changing
    )

    Initialize-VBAFCenterSignalStore

    $path = Join-Path $script:SignalStorePath "$CustomerID-$SignalIndex.json"

    if (-not (Test-Path $path)) {
        Write-Host "Signal config not found: $CustomerID $SignalIndex" -ForegroundColor Red
        return
    }

    $config = Get-Content $path -Raw | ConvertFrom-Json

    if ($GoodBelow -ne -999) { $config.GoodBelow = $GoodBelow }
    if ($BadAbove  -ne -999) { $config.BadAbove  = $BadAbove  }
    if ($Weight    -gt 0)    { $config.Weight     = $Weight    }

    $config | ConvertTo-Json -Depth 5 | Set-Content $path -Encoding UTF8

    Write-Host ""
    Write-Host "Signal threshold updated!" -ForegroundColor Green
    Write-Host ("  Customer   : {0}" -f $CustomerID)    -ForegroundColor White
    Write-Host ("  Signal     : {0} ({1})" -f $config.SignalName, $SignalIndex) -ForegroundColor White
    Write-Host ("  GoodBelow  : {0}" -f $config.GoodBelow) -ForegroundColor White
    Write-Host ("  BadAbove   : {0}" -f $config.BadAbove)  -ForegroundColor White
    Write-Host ("  Weight     : {0}/5" -f $config.Weight)   -ForegroundColor White
    Write-Host ""
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
        Write-Host ("  Signals configured : {0}"    -f $result.VBAFInput.Length) -ForegroundColor White
        Write-Host ("  Simple average     : {0:F4}" -f $result.SimpleAvg)        -ForegroundColor White
        Write-Host ("  Weighted average   : {0:F4}" -f $result.WeightedAvg)      -ForegroundColor White

        if ($result.RedSignals -and @($result.RedSignals).Count -gt 0) {
            Write-Host ("  RED signals        : {0}" -f @($result.RedSignals).Count) -ForegroundColor Red
        }
    }

    return $result
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host "VBAF-Center Phase 3 loaded  [Signal Acquisition + Phase 14 Thresholds + Phase 15 Weights]" -ForegroundColor Cyan
Write-Host "  New-VBAFCenterSignalConfig        — define signal source"           -ForegroundColor White
Write-Host "  Get-VBAFCenterSignal              — get one live signal"             -ForegroundColor White
Write-Host "  Get-VBAFCenterAllSignals          — get all signals"                 -ForegroundColor White
Write-Host "  Test-VBAFCenterSignalConfig       — test configuration"              -ForegroundColor White
Write-Host "  Get-VBAFCenterSignalStatus        — show Green/Yellow/Red status"    -ForegroundColor Cyan
Write-Host "  Invoke-VBAFCenterThresholdCheck   — show only Red and Yellow alerts" -ForegroundColor Cyan
Write-Host "  Set-VBAFCenterSignalThreshold     — tune thresholds and weights"     -ForegroundColor Cyan
Write-Host ""