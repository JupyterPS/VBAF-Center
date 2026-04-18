#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 8 — Scheduling Engine
.DESCRIPTION
    Controls how often VBAF-Center checks customer signals
    and runs the full pipeline automatically.

    Functions:
      Start-VBAFCenterSchedule  — start automatic checking
      Stop-VBAFCenterSchedule   — stop automatic checking
      Invoke-VBAFCenterRun      — run pipeline once manually
      Get-VBAFCenterRunHistory  — show recent results
#>

$script:SchedulePath  = Join-Path $env:USERPROFILE "VBAFCenter\schedules"
$script:HistoryPath   = Join-Path $env:USERPROFILE "VBAFCenter\history"

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

    # Step 1 — Load schedule config
    $schedFile = Join-Path $script:SchedulePath "$CustomerID-schedule.json"
    if (-not (Test-Path $schedFile)) {
        Write-Host "No schedule found for: $CustomerID" -ForegroundColor Red
        Write-Host "Run Start-VBAFCenterOnboarding first." -ForegroundColor Yellow
        return $null
    }
    $sched = Get-Content $schedFile -Raw | ConvertFrom-Json

    # Step 2 — Acquire signals
    $sigPath = Join-Path $env:USERPROFILE "VBAFCenter\signals"
    $sigFiles = Get-ChildItem $sigPath -Filter "$CustomerID-*.json" -ErrorAction SilentlyContinue
    $rawSignals  = @()
    $signalNames = @()

    foreach ($sf in $sigFiles) {
        $sc = Get-Content $sf.FullName -Raw | ConvertFrom-Json
        [double] $range = $sc.RawMax - $sc.RawMin
        [double] $raw   = $sc.RawMin + (Get-Random -Minimum 0 -Maximum 100) / 100.0 * $range
        [double] $norm  = if ($range -gt 0) { ($raw - $sc.RawMin) / $range } else { 0.0 }
        $norm           = [Math]::Max(0.0, [Math]::Min(1.0, $norm))
        $rawSignals     += $norm
        $signalNames    += $sc.SignalName
    }

    # If no signals configured use simulated pair
    if ($rawSignals.Count -eq 0) {
        $rawSignals  = @([double](Get-Random -Minimum 0 -Maximum 100)/100.0, [double](Get-Random -Minimum 0 -Maximum 100)/100.0)
        $signalNames = @("Signal1","Signal2")
    }

    # Step 3 — Route to agent (rule-based)
    [double] $avg = 0.0
    foreach ($s in $rawSignals) { $avg += $s }
    $avg /= $rawSignals.Count

    $action = if      ($avg -lt 0.25) { 0 }
              elseif  ($avg -lt 0.50) { 1 }
              elseif  ($avg -lt 0.75) { 2 }
              else                    { 3 }

    # Step 4 — Interpret action
    $actFile = Join-Path $env:USERPROFILE "VBAFCenter\actions\$CustomerID-actions.txt"
    $actionName    = @("Monitor","Reassign","Reroute","Escalate")[$action]
    $actionCommand = @("No action needed","Reassign resource","Switch approach","Emergency response")[$action]

    if (Test-Path $actFile) {
        $lines = Get-Content $actFile
        foreach ($line in $lines) {
            $parts = $line -split "\|"
            if ([int]$parts[0] -eq $action) {
                $actionName    = $parts[1]
                $actionCommand = $parts[2]
                break
            }
        }
    }

    # Step 5 — Log result
    $result = @{
        CustomerID    = $CustomerID
        Timestamp     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Signals       = $rawSignals
        AvgSignal     = [Math]::Round($avg, 4)
        Action        = $action
        ActionName    = $actionName
        ActionCommand = $actionCommand
    }

    $histFile = Join-Path $script:HistoryPath "$CustomerID-$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $result | ConvertTo-Json | Set-Content $histFile -Encoding UTF8

    # Step 6 — Display
    if (-not $Silent) {
        $sigStr = ($rawSignals | ForEach-Object { $_.ToString("F2") }) -join ", "
        $color  = if ($action -ge 3) { "Red" } elseif ($action -ge 2) { "Yellow" } else { "Green" }

        Write-Host ("  Signals   : [{0}]" -f $sigStr)       -ForegroundColor White
        Write-Host ("  Avg level : {0:F2}" -f $avg)          -ForegroundColor White
        Write-Host ("  Action    : {0} — {1}" -f $action, $actionName) -ForegroundColor $color
        Write-Host ("  Command   : {0}" -f $actionCommand)   -ForegroundColor $color
        Write-Host ""
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
    [int] $intervalSec = $sched.IntervalMinutes * 10 
    [int] $runCount    = 0

    Write-Host ""
    Write-Host "VBAF-Center Schedule Started" -ForegroundColor Cyan
    Write-Host ("  Customer  : {0}" -f $CustomerID)             -ForegroundColor White
    Write-Host ("  Interval  : every {0} minutes" -f $sched.IntervalMinutes) -ForegroundColor White
    Write-Host "  Press Ctrl+C to stop." -ForegroundColor DarkGray
    Write-Host ""

    while ($true) {
        $runCount++
        Write-Host ("  [{0}] Run #{1}" -f (Get-Date).ToString("HH:mm:ss"), $runCount) -ForegroundColor DarkGray

        $result = Invoke-VBAFCenterRun -CustomerID $CustomerID -Silent:$false

        # Auto-trigger crisis tree on Action 3
        if ($result.Action -ge 3) {
            Write-Host ""
            Write-Host "  [CRISIS] Action 3 detected — activating Crisis Response Tree!" -ForegroundColor Red
            Write-Host ""

            # Sound alarm — 3 escalating beeps
            try {
                [Console]::Beep(800,  400)
                Start-Sleep -Milliseconds 100
                [Console]::Beep(1000, 400)
                Start-Sleep -Milliseconds 100
                [Console]::Beep(1500, 800)
                Write-Host "  [NOTIFY] Sound alarm fired." -ForegroundColor Yellow
            } catch {
                Write-Host "  [NOTIFY] Sound alarm failed." -ForegroundColor DarkGray
            }

            # Persistent red popup — stays until dispatcher clicks OK
            try {
                Add-Type -AssemblyName System.Windows.Forms
                Add-Type -AssemblyName System.Drawing
                $form               = New-Object System.Windows.Forms.Form
                $form.Text          = "VBAF CRISIS ALERT"
                $form.Size          = New-Object System.Drawing.Size(420,220)
                $form.StartPosition = "CenterScreen"
                $form.TopMost       = $true
                $form.BackColor     = [System.Drawing.Color]::Red
                $label              = New-Object System.Windows.Forms.Label
                $label.Text         = "CRISIS DETECTED!`n`nCustomer : $CustomerID`nAction   : Escalate`nCommand  : $($result.ActionCommand)`n`nClick OK to continue."
                $label.ForeColor    = [System.Drawing.Color]::White
                $label.Font         = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
                $label.Size         = New-Object System.Drawing.Size(400,130)
                $label.Location     = New-Object System.Drawing.Point(10,10)
                $button             = New-Object System.Windows.Forms.Button
                $button.Text        = "OK — I am handling it"
                $button.Size        = New-Object System.Drawing.Size(200,35)
                $button.Location    = New-Object System.Drawing.Point(100,145)
                $button.BackColor   = [System.Drawing.Color]::White
                $button.ForeColor   = [System.Drawing.Color]::Red
                $button.Font        = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
                $button.Add_Click({ $form.Close() })
                $form.Controls.Add($label)
                $form.Controls.Add($button)
                $form.Add_Shown({ $form.Activate() })
                $form.ShowDialog() | Out-Null
                Write-Host "  [NOTIFY] Crisis popup dismissed by dispatcher." -ForegroundColor Green
            } catch {
                Write-Host "  [NOTIFY] Popup failed — $($_.Exception.Message)" -ForegroundColor DarkGray
            }

            # Email alert — configure SMTP in customer schedule file
            $schedFile  = Join-Path $env:USERPROFILE "VBAFCenter\schedules\$CustomerID-schedule.json"
            if (Test-Path $schedFile) {
                $sched = Get-Content $schedFile -Raw | ConvertFrom-Json
                if ($sched.AlertEmail -and $sched.AlertEmail -ne "") {
                    try {
                        Send-MailMessage `
                            -To      $sched.AlertEmail `
                            -From    "vbaf@yourdomain.dk" `
                            -Subject "VBAF CRISIS — Action 3 fired for $CustomerID" `
                            -Body    "VBAF-Center detected a critical situation for $CustomerID at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss').`n`nAction: Escalate`nCommand: $($result.ActionCommand)`n`nLog in to VBAF-Center and activate the Crisis Response Tree immediately." `
                            -SmtpServer "smtp.yourdomain.dk"
                        Write-Host "  [NOTIFY] Email alert sent to $($sched.AlertEmail)." -ForegroundColor Yellow
                    } catch {
                        Write-Host "  [NOTIFY] Email alert failed — check SMTP settings." -ForegroundColor DarkGray
                    }
                }
            }

            if (Get-Command Start-VBAFCenterCrisis -ErrorAction SilentlyContinue) {
                Start-VBAFCenterCrisis -CustomerID $CustomerID
            } else {
                Write-Host "  Load VBAF.Center.CrisisTree.ps1 to activate crisis response." -ForegroundColor Yellow
            }
        }

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
    Write-Host ("  {0,-20} {1,-8} {2,-12} {3}" -f "Timestamp","Action","Name","Command") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 75)) -ForegroundColor DarkGray

    foreach ($f in $files) {
        $r     = Get-Content $f.FullName -Raw | ConvertFrom-Json
        $color = if ($r.Action -ge 3) { "Red" } elseif ($r.Action -ge 2) { "Yellow" } else { "Green" }
        Write-Host ("  {0,-20} {1,-8} {2,-12} {3}" -f $r.Timestamp, $r.Action, $r.ActionName, $r.ActionCommand) -ForegroundColor $color
    }
    Write-Host ""
}

Write-Host "VBAF-Center Phase 8 loaded  [Scheduling Engine]"       -ForegroundColor Cyan
Write-Host "  Invoke-VBAFCenterRun         — run pipeline once"     -ForegroundColor White
Write-Host "  Start-VBAFCenterSchedule     — start auto-checking"   -ForegroundColor White
Write-Host "  Get-VBAFCenterRunHistory     — show recent results"   -ForegroundColor White
Write-Host ""





