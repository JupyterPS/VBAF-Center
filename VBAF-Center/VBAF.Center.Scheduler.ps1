#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 8 — Scheduling Engine
.DESCRIPTION
    Controls how often VBAF-Center checks customer signals
    and runs the full pipeline automatically.

    Phase 14 — RED signal override raises minimum action level
    Phase 15 — Weighted average passed through full pipeline
    Phase 17 — Customer-specific thresholds honoured end-to-end

    Functions:
      Invoke-VBAFCenterRun      — run full pipeline once
      Start-VBAFCenterSchedule  — start automatic checking
      Get-VBAFCenterRunHistory  — show recent results
#>

$script:SchedulePath = Join-Path $env:USERPROFILE "VBAFCenter\schedules"
$script:HistoryPath  = Join-Path $env:USERPROFILE "VBAFCenter\history"

function Initialize-VBAFCenterScheduleStore {
    if (-not (Test-Path $script:SchedulePath)) { New-Item -ItemType Directory -Path $script:SchedulePath -Force | Out-Null }
    if (-not (Test-Path $script:HistoryPath))  { New-Item -ItemType Directory -Path $script:HistoryPath  -Force | Out-Null }
}

# ============================================================
# INVOKE-VBAFCENTERRUN — run full pipeline once
# ============================================================
function Invoke-VBAFCenterRun {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [switch] $Silent
    )

    Initialize-VBAFCenterScheduleStore

    if (-not $Silent) {
        Write-Host ""
        Write-Host ("VBAF-Center Run: {0} — {1}" -f $CustomerID, (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) -ForegroundColor Cyan
        Write-Host ""
    }

    # --------------------------------------------------------
    # Step 1 — Load schedule config
    # --------------------------------------------------------
    $schedFile = Join-Path $script:SchedulePath "$CustomerID-schedule.json"
    if (-not (Test-Path $schedFile)) {
        Write-Host "No schedule found for: $CustomerID" -ForegroundColor Red
        Write-Host "Run Start-VBAFCenterOnboarding first." -ForegroundColor Yellow
        return $null
    }
    $sched = Get-Content $schedFile -Raw | ConvertFrom-Json

    # --------------------------------------------------------
    # Step 2 — Acquire signals via Phase 3
    # Phase 14/15: returns RedSignals, YellowSignals, WeightedAvg
    # --------------------------------------------------------
    $signalResult = $null

    if (Get-Command Get-VBAFCenterAllSignals -ErrorAction SilentlyContinue) {

        $signalResult = Get-VBAFCenterAllSignals -CustomerID $CustomerID

        if ($null -eq $signalResult -or $signalResult.VBAFInput.Length -eq 0) {
            Write-Host "No signals returned — check signal configuration." -ForegroundColor Red
            return $null
        }

        $normalisedSignals = [double[]] $signalResult.VBAFInput
        $weightedAvg       = $signalResult.WeightedAvg
        $redSignals        = $signalResult.RedSignals
        $yellowSignals     = $signalResult.YellowSignals

    } else {

        # Phase 3 not loaded — use legacy inline signal reading
        Write-Host "  [WARN] Get-VBAFCenterAllSignals not available — using legacy signal read." -ForegroundColor Yellow

        $sigPath   = Join-Path $env:USERPROFILE "VBAFCenter\signals"
        $sigFiles  = Get-ChildItem $sigPath -Filter "$CustomerID-*.json" -ErrorAction SilentlyContinue
        $normalisedSignals = @()

        foreach ($sf in $sigFiles) {
            $sc     = Get-Content $sf.FullName -Raw | ConvertFrom-Json
            [double] $range = $sc.RawMax - $sc.RawMin
            [double] $raw   = $sc.RawMin + (Get-Random -Minimum 0 -Maximum 100) / 100.0 * $range
            [double] $norm  = if ($range -gt 0) { ($raw - $sc.RawMin) / $range } else { 0.0 }
            $normalisedSignals += [Math]::Max(0.0, [Math]::Min(1.0, $norm))
        }

        if ($normalisedSignals.Count -eq 0) {
            $normalisedSignals = @(
                [double](Get-Random -Minimum 0 -Maximum 100) / 100.0,
                [double](Get-Random -Minimum 0 -Maximum 100) / 100.0
            )
        }

        $weightedAvg   = -1
        $redSignals    = @()
        $yellowSignals = @()
    }

    # --------------------------------------------------------
    # Step 3 — Route to agent via Phase 5
    # Phase 14: passes RedSignals and YellowSignals
    # Phase 15: passes WeightedAvg
    # Phase 17: Phase 5 reads customer thresholds from schedule.json
    # --------------------------------------------------------
    $routeResult  = $null
    [int] $action = 0
    [string] $actionReason   = ""
    [bool]   $overrideApplied = $false
    [int]    $redCount        = 0
    [int]    $yellowCount     = 0
    [double] $avgUsed         = 0.0

    if (Get-Command Invoke-VBAFCenterRoute -ErrorAction SilentlyContinue) {

        $routeResult = Invoke-VBAFCenterRoute `
            -CustomerID        $CustomerID `
            -NormalisedSignals $normalisedSignals `
            -WeightedAvg       $weightedAvg `
            -RedSignals        $redSignals `
            -YellowSignals     $yellowSignals

        if ($null -eq $routeResult) {
            Write-Host "Routing failed — check agent configuration." -ForegroundColor Red
            return $null
        }

        $action          = $routeResult.FinalAction
        $actionReason    = $routeResult.ActionReason
        $overrideApplied = $routeResult.OverrideApplied
        $redCount        = $routeResult.RedSignalCount
        $yellowCount     = $routeResult.YellowSignalCount
        $avgUsed         = $routeResult.AvgUsed

    } else {

        # Phase 5 not loaded — use legacy inline rule-based routing
        Write-Host "  [WARN] Invoke-VBAFCenterRoute not available — using legacy routing." -ForegroundColor Yellow

        [double] $avg = 0.0
        foreach ($s in $normalisedSignals) { $avg += $s }
        if ($normalisedSignals.Length -gt 0) { $avg /= $normalisedSignals.Length }

        $action       = if      ($avg -lt 0.25) { 0 }
                        elseif  ($avg -lt 0.50) { 1 }
                        elseif  ($avg -lt 0.75) { 2 }
                        else                    { 3 }
        $actionReason = ("Legacy average {0:F4}" -f $avg)
        $avgUsed      = $avg
    }

    # --------------------------------------------------------
    # Step 4 — Interpret action — read customer action map
    # --------------------------------------------------------
    $actionNames   = @("Monitor","Reassign","Reroute","Escalate")
    $actionDefaults = @("No action needed","Reassign resource","Switch approach","Emergency response")
    $actionName    = $actionNames[$action]
    $actionCommand = $actionDefaults[$action]

    $actFile = Join-Path $env:USERPROFILE "VBAFCenter\actions\$CustomerID-actions.txt"
    if (Test-Path $actFile) {
        $lines = Get-Content $actFile
        foreach ($line in $lines) {
            $parts = $line -split "\|"
            if ($parts.Length -ge 3 -and [int]$parts[0] -eq $action) {
                $actionName    = $parts[1]
                $actionCommand = $parts[2]
                break
            }
        }
    }

    # --------------------------------------------------------
    # Step 5 — Log result to history
    # Now includes Phase 14/15 fields for trend analysis
    # --------------------------------------------------------
    $result = [PSCustomObject] @{
        CustomerID       = $CustomerID
        Timestamp        = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
        Signals          = $normalisedSignals
        AvgSignal        = [Math]::Round($avgUsed, 4)
        WeightedAvg      = if ($weightedAvg -ge 0) { [Math]::Round($weightedAvg, 4) } else { $null }
        Action           = $action
        ActionName       = $actionName
        ActionCommand    = $actionCommand
        ActionReason     = $actionReason
        OverrideApplied  = $overrideApplied
        RedSignalCount   = $redCount
        YellowSignalCount = $yellowCount
    }

    $histFile = Join-Path $script:HistoryPath "$CustomerID-$(Get-Date -Format 'yyyyMMdd_HHmmss_fff').json"
    $result | ConvertTo-Json -Depth 5 | Set-Content $histFile -Encoding UTF8

    # --------------------------------------------------------
    # Step 6 — Display
    # --------------------------------------------------------
    if (-not $Silent) {
        $sigStr = ($normalisedSignals | ForEach-Object { $_.ToString("F2") }) -join ", "
        $color  = if ($action -ge 3) { "Red" } elseif ($action -ge 2) { "DarkYellow" } else { "Green" }

        Write-Host ("  Signals   : [{0}]"              -f $sigStr)       -ForegroundColor White
        Write-Host ("  Avg used  : {0:F4}"             -f $avgUsed)      -ForegroundColor White

        if ($null -ne $result.WeightedAvg) {
            Write-Host ("  Weighted  : {0:F4}"         -f $result.WeightedAvg) -ForegroundColor Cyan
        }

        if ($redCount -gt 0) {
            Write-Host ("  Red signals    : {0}"       -f $redCount)     -ForegroundColor Red
        }
        if ($yellowCount -gt 0) {
            Write-Host ("  Yellow signals : {0}"       -f $yellowCount)  -ForegroundColor Yellow
        }
        if ($overrideApplied) {
            Write-Host ("  OVERRIDE  : {0}"            -f $actionReason) -ForegroundColor Red
        }

        Write-Host ("  Action    : {0} — {1}"          -f $action, $actionName)    -ForegroundColor $color
        Write-Host ("  Command   : {0}"                 -f $actionCommand)          -ForegroundColor $color

        if (-not $overrideApplied -and $actionReason -ne "") {
            Write-Host ("  Reason    : {0}"            -f $actionReason) -ForegroundColor DarkGray
        }

        Write-Host ""
    }

    # --------------------------------------------------------
    # Step 7 — Crisis response on Action 3
    # Fires on actual Action 3 OR when RED override raised to 3
    # --------------------------------------------------------
    if ($action -ge 3) {

        if (-not $Silent) {
            Write-Host ""
            Write-Host "  [CRISIS] Action 3 detected — activating Crisis Response Tree!" -ForegroundColor Red
            if ($overrideApplied) {
                Write-Host "  [CRISIS] Triggered by RED signal threshold override." -ForegroundColor Red
            }
            Write-Host ""
        }

        # Sound alarm — 3 escalating beeps
        try {
            [Console]::Beep(800,  400)
            Start-Sleep -Milliseconds 100
            [Console]::Beep(1000, 400)
            Start-Sleep -Milliseconds 100
            [Console]::Beep(1500, 800)
            if (-not $Silent) { Write-Host "  [NOTIFY] Sound alarm fired." -ForegroundColor Yellow }
        } catch {
            if (-not $Silent) { Write-Host "  [NOTIFY] Sound alarm failed." -ForegroundColor DarkGray }
        }

        # Persistent red popup — stays until dispatcher clicks OK
        try {
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing

            $overrideNote = if ($overrideApplied) { "`nCause    : RED signal threshold override" } else { "" }

            $form               = New-Object System.Windows.Forms.Form
            $form.Text          = "VBAF CRISIS ALERT"
            $form.Size          = New-Object System.Drawing.Size(440, 240)
            $form.StartPosition = "CenterScreen"
            $form.TopMost       = $true
            $form.BackColor     = [System.Drawing.Color]::Red

            $label              = New-Object System.Windows.Forms.Label
            $label.Text         = ("CRISIS DETECTED!`n`nCustomer : {0}`nAction   : Escalate`nCommand  : {1}{2}`n`nClick OK to continue." -f `
                                    $CustomerID, $actionCommand, $overrideNote)
            $label.ForeColor    = [System.Drawing.Color]::White
            $label.Font         = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
            $label.Size         = New-Object System.Drawing.Size(410, 150)
            $label.Location     = New-Object System.Drawing.Point(10, 10)

            $button             = New-Object System.Windows.Forms.Button
            $button.Text        = "OK — I am handling it"
            $button.Size        = New-Object System.Drawing.Size(200, 35)
            $button.Location    = New-Object System.Drawing.Point(110, 170)
            $button.BackColor   = [System.Drawing.Color]::White
            $button.ForeColor   = [System.Drawing.Color]::Red
            $button.Font        = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
            $button.Add_Click({ $form.Close() })

            $form.Controls.Add($label)
            $form.Controls.Add($button)
            $form.Add_Shown({ $form.Activate() })
            $form.ShowDialog() | Out-Null

            if (-not $Silent) { Write-Host "  [NOTIFY] Crisis popup dismissed by dispatcher." -ForegroundColor Green }
        } catch {
            if (-not $Silent) { Write-Host "  [NOTIFY] Popup failed — $($_.Exception.Message)" -ForegroundColor DarkGray }
        }

        # Email alert — configure AlertEmail in customer schedule file
        if (Test-Path $schedFile) {
            $schedData = Get-Content $schedFile -Raw | ConvertFrom-Json
            if ($schedData.AlertEmail -and $schedData.AlertEmail -ne "") {
                try {
                    Send-MailMessage `
                        -To         $schedData.AlertEmail `
                        -From       "vbaf@yourdomain.dk" `
                        -Subject    ("VBAF CRISIS — Action 3 fired for {0}" -f $CustomerID) `
                        -Body       ("VBAF-Center detected a critical situation for {0} at {1}.`n`nAction  : Escalate`nCommand : {2}`nReason  : {3}`n`nLog in to VBAF-Center immediately." -f `
                                     $CustomerID, (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $actionCommand, $actionReason) `
                        -SmtpServer "smtp.yourdomain.dk"
                    if (-not $Silent) { Write-Host "  [NOTIFY] Email sent to $($schedData.AlertEmail)." -ForegroundColor Yellow }
                } catch {
                    if (-not $Silent) { Write-Host "  [NOTIFY] Email failed — check SMTP settings." -ForegroundColor DarkGray }
                }
            }
        }

        # Activate crisis tree if loaded
        if (Get-Command Start-VBAFCenterCrisis -ErrorAction SilentlyContinue) {
            Start-VBAFCenterCrisis -CustomerID $CustomerID
        } else {
            if (-not $Silent) {
                Write-Host "  Load VBAF.Center.CrisisTree.ps1 to activate crisis response." -ForegroundColor Yellow
            }
        }
    }

    return $result
}

# ============================================================
# START-VBAFCENTERSCHEDULE — loop until stopped
# ============================================================
function Start-VBAFCenterSchedule {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [int] $MaxRuns = 0   # 0 = run forever until Ctrl+C
    )

    $schedFile = Join-Path $script:SchedulePath "$CustomerID-schedule.json"
    if (-not (Test-Path $schedFile)) {
        Write-Host "No schedule found for: $CustomerID" -ForegroundColor Red
        return
    }

    $sched = Get-Content $schedFile -Raw | ConvertFrom-Json
    [int] $intervalSec = $sched.IntervalMinutes * 60
    [int] $runCount    = 0

    Write-Host ""
    Write-Host "VBAF-Center Schedule Started" -ForegroundColor Cyan
    Write-Host ("  Customer  : {0}"            -f $CustomerID)              -ForegroundColor White
    Write-Host ("  Interval  : every {0} minutes" -f $sched.IntervalMinutes) -ForegroundColor White
    Write-Host "  Press Ctrl+C to stop."                                     -ForegroundColor DarkGray
    Write-Host ""

    while ($true) {
        $runCount++
        Write-Host ("  [{0}] Run #{1}" -f (Get-Date).ToString("HH:mm:ss"), $runCount) -ForegroundColor DarkGray

        Invoke-VBAFCenterRun -CustomerID $CustomerID -Silent:$false | Out-Null

        if ($MaxRuns -gt 0 -and $runCount -ge $MaxRuns) {
            Write-Host "Max runs reached. Stopping." -ForegroundColor Yellow
            break
        }

        Write-Host ("  Next run in {0} minutes..." -f $sched.IntervalMinutes) -ForegroundColor DarkGray
        Start-Sleep -Seconds $intervalSec
    }
}

# ============================================================
# GET-VBAFCENTERRUNHISTORY
# ============================================================
function Get-VBAFCenterRunHistory {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [int] $Last = 10
    )

    Initialize-VBAFCenterScheduleStore

    $files = Get-ChildItem $script:HistoryPath -Filter "$CustomerID-*.json" |
             Sort-Object LastWriteTime -Descending |
             Select-Object -First $Last

    if ($files.Count -eq 0) {
        Write-Host "No run history for: $CustomerID" -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Run History: $CustomerID (last $($files.Count) runs)" -ForegroundColor Cyan
    Write-Host ("  {0,-23} {1,-4} {2,-12} {3,-6} {4,-6} {5}" -f `
        "Timestamp","Act","Name","Red","Yellow","Reason / Command") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 90)) -ForegroundColor DarkGray

    foreach ($f in $files) {
        $r     = Get-Content $f.FullName -Raw | ConvertFrom-Json
        $color = if ($r.Action -ge 3) { "Red" } elseif ($r.Action -ge 2) { "Yellow" } else { "Green" }

        $redCol    = if ($null -ne $r.RedSignalCount    -and $r.RedSignalCount    -gt 0) { $r.RedSignalCount.ToString()    } else { "-" }
        $yellowCol = if ($null -ne $r.YellowSignalCount -and $r.YellowSignalCount -gt 0) { $r.YellowSignalCount.ToString() } else { "-" }
        $reasonCol = if ($r.OverrideApplied) { "[OVERRIDE] $($r.ActionReason)" } else { $r.ActionCommand }

        Write-Host ("  {0,-23} {1,-4} {2,-12} {3,-6} {4,-6} {5}" -f `
            $r.Timestamp, $r.Action, $r.ActionName,
            $redCol, $yellowCol, $reasonCol) -ForegroundColor $color
    }
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host "VBAF-Center Phase 8 loaded  [Scheduling Engine + Phase 14/15/17 pipeline]" -ForegroundColor Cyan
Write-Host "  Invoke-VBAFCenterRun         — run full pipeline once"    -ForegroundColor White
Write-Host "  Start-VBAFCenterSchedule     — start auto-checking"       -ForegroundColor White
Write-Host "  Get-VBAFCenterRunHistory     — show recent results"       -ForegroundColor White
Write-Host ""