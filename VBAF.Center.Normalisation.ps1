#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 4 — Normalisation
.DESCRIPTION
    Takes raw customer signals and normalises them to 0.0-1.0
    using VBAF's proven scalers — borrowed directly from VBAF ML engine.

    Functions:
      Invoke-VBAFCenterNormalise      — normalise a signal array
      Get-VBAFCenterNormalisationReport — show normalisation details
#>

# ============================================================
# INVOKE-VBAFCENTERNORMALISE
# ============================================================
function Invoke-VBAFCenterNormalise {
    param(
        [Parameter(Mandatory)] [string]   $CustomerID,
        [Parameter(Mandatory)] [double[]] $RawSignals,
        [string] $Method = "MinMax"
        # Method: "MinMax" | "Standard" | "Robust" | "PassThrough"
    )

    $normalised = [double[]]::new($RawSignals.Length)

    switch ($Method) {

        "PassThrough" {
            # Signals already 0.0-1.0 — just clip to be safe
            for ($i = 0; $i -lt $RawSignals.Length; $i++) {
                $normalised[$i] = [Math]::Max(0.0, [Math]::Min(1.0, $RawSignals[$i]))
            }
        }

        "MinMax" {
            # Already done in Phase 3 Signal Acquisition
            # PassThrough with safety clip
            for ($i = 0; $i -lt $RawSignals.Length; $i++) {
                $normalised[$i] = [Math]::Max(0.0, [Math]::Min(1.0, $RawSignals[$i]))
            }
        }

        "Standard" {
            # Zero mean, unit variance — then clip to 0-1
            # Borrow concept from VBAF StandardScaler
            [double] $mean = 0.0
            foreach ($v in $RawSignals) { $mean += $v }
            $mean /= $RawSignals.Length

            [double] $std = 0.0
            foreach ($v in $RawSignals) { $std += ($v - $mean) * ($v - $mean) }
            $std = [Math]::Sqrt($std / $RawSignals.Length)
            if ($std -eq 0.0) { $std = 1.0 }

            for ($i = 0; $i -lt $RawSignals.Length; $i++) {
                [double] $scaled = ($RawSignals[$i] - $mean) / $std
                # Map from typical -3..+3 range to 0..1
                $normalised[$i] = [Math]::Max(0.0, [Math]::Min(1.0, ($scaled + 3.0) / 6.0))
            }
        }

        "Robust" {
            # Median/IQR — robust to outliers
            # Borrow concept from VBAF RobustScaler
            $sorted = $RawSignals | Sort-Object
            $n      = $sorted.Length
            [double] $median = $sorted[[int]($n / 2)]
            [double] $q1     = $sorted[[int]($n * 0.25)]
            [double] $q3     = $sorted[[int]($n * 0.75)]
            [double] $iqr    = $q3 - $q1
            if ($iqr -eq 0.0) { $iqr = 1.0 }

            for ($i = 0; $i -lt $RawSignals.Length; $i++) {
                [double] $scaled = ($RawSignals[$i] - $median) / $iqr
                $normalised[$i]  = [Math]::Max(0.0, [Math]::Min(1.0, ($scaled + 2.0) / 4.0))
            }
        }
    }

    return $normalised
}

# ============================================================
# GET-VBAFCENTERNORMALISATIONREPORT
# ============================================================
function Get-VBAFCenterNormalisationReport {
    param(
        [Parameter(Mandatory)] [string]   $CustomerID,
        [Parameter(Mandatory)] [double[]] $RawSignals,
        [string[]] $SignalNames = @(),
        [string]   $Method      = "MinMax"
    )

    $normalised = Invoke-VBAFCenterNormalise `
        -CustomerID  $CustomerID `
        -RawSignals  $RawSignals `
        -Method      $Method

    Write-Host ""
    Write-Host "Normalisation Report: $CustomerID" -ForegroundColor Cyan
    Write-Host ("  Method: {0}" -f $Method) -ForegroundColor White
    Write-Host ""
    Write-Host ("  {0,-5} {1,-25} {2,10} {3,12} {4}" -f "#","Signal","Raw","Normalised","Status") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 65)) -ForegroundColor DarkGray

    for ($i = 0; $i -lt $RawSignals.Length; $i++) {
        $name   = if ($i -lt $SignalNames.Length) { $SignalNames[$i] } else { "Signal$($i+1)" }
        $norm   = $normalised[$i]
        $status = if ($norm -gt 0.75) { "HIGH" } elseif ($norm -gt 0.40) { "MEDIUM" } else { "LOW" }
        $color  = if ($norm -gt 0.75) { "Red" } elseif ($norm -gt 0.40) { "Yellow" } else { "Green" }
        $bar    = "█" * [int]($norm * 20)
        Write-Host ("  {0,-5} {1,-25} {2,10:F2} {3,12:F4} {4,-8} {5}" -f `
            ($i+1), $name, $RawSignals[$i], $norm, $status, $bar) -ForegroundColor $color
    }

    Write-Host ""
    Write-Host ("  VBAF input: [{0}]" -f (($normalised | ForEach-Object { $_.ToString("F4") }) -join ", ")) -ForegroundColor Green
    Write-Host ""

    return @{
        CustomerID  = $CustomerID
        Method      = $Method
        RawSignals  = $RawSignals
        Normalised  = $normalised
        VBAFInput   = $normalised
    }
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host "VBAF-Center Phase 4 loaded  [Normalisation]"               -ForegroundColor Cyan
Write-Host "  Invoke-VBAFCenterNormalise        — normalise signals"    -ForegroundColor White
Write-Host "  Get-VBAFCenterNormalisationReport — detailed report"      -ForegroundColor White
Write-Host "  Methods: MinMax | Standard | Robust | PassThrough"       -ForegroundColor White
Write-Host ""

