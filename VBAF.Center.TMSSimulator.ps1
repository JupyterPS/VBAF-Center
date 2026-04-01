#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center TMS Simulator � Real World Test Engine
.DESCRIPTION
    Simulates a Transport Management System feeding live data into VBAF-Center.
    2 signals. 3 events. 4 modes. Fully connected to VBAF-Center pipeline.

    Signals:
      Signal1 � Empty Driving %
      Signal2 � On-Time Delivery %

    Events:
      WeatherEvent     � On-Time drops, Cost rises
      TrafficJam       � ETA drops, Cost rises
      VehicleBreakdown � Fleet drops, Cost spikes

    Modes:
      Shadow    � every 30 minutes  (48 episodes/day)
      GoLive    � every 10 minutes  (144 episodes/day)
      Autonomy  � every 5 minutes   (288 episodes/day)
      RealTime  � continuous demo/stress test

    Functions:
      Get-VBAFTMSSignal        � get one signal value (time-aware)
      Get-VBAFTMSAllSignals    � get both signals as snapshot
      Invoke-VBAFTMSEvent      � fire a named or random event
      Show-VBAFTMSStatus       � dashboard view of current state
      Invoke-VBAFTMSDayReplay  � run full day compressed
      Start-VBAFTMSSchedule    � run in chosen mode continuously
#>

# ============================================================
# STATE
# ============================================================
$script:TMSState = @{
    ActiveEvent       = $null
    EventRoundsLeft   = 0
    EmptyDrivingBase  = 32.0
    OnTimeBase        = 74.0
    LastSnapshot      = $null
}

# ============================================================
# TIME OF DAY CURVE
# Returns a multiplier 0.0 - 1.0 based on hour of day
# ============================================================
function Get-TMSTimeCurve {
    param([int]$Hour)
    switch ($Hour) {
        {$_ -lt 5}            { return 0.3 }   # Night � low activity
        {$_ -in 5..7}         { return 0.6 }   # Morning start
        {$_ -in 8..11}        { return 1.0 }   # Morning peak � best performance
        {$_ -in 12..14}       { return 0.9 }   # Midday plateau
        {$_ -in 15..17}       { return 0.8 }   # Afternoon pressure
        {$_ -in 18..20}       { return 0.6 }   # Evening wind-down
        {$_ -in 21..23}       { return 0.4 }   # Night shift
        default                { return 0.5 }
    }
}

# ============================================================
# DAY OF WEEK MODIFIER
# ============================================================
function Get-TMSDayModifier {
    $day = (Get-Date).DayOfWeek
    switch ($day) {
        "Monday"    { return @{ Empty=-5;  OnTime=-3  } }
        "Tuesday"   { return @{ Empty=-8;  OnTime=+5  } }
        "Wednesday" { return @{ Empty=0;   OnTime=0   } }
        "Thursday"  { return @{ Empty=+2;  OnTime=-2  } }
        "Friday"    { return @{ Empty=+8;  OnTime=-5  } }
        "Saturday"  { return @{ Empty=+15; OnTime=-8  } }
        "Sunday"    { return @{ Empty=+20; OnTime=-12 } }
        default     { return @{ Empty=0;   OnTime=0   } }
    }
}

# ============================================================
# GET-VBAFTMSSIGNAL
# ============================================================
function Get-VBAFTMSSignal {
    param(
        [Parameter(Mandatory)] [ValidateSet("EmptyDriving","OnTimeDelivery")]
        [string] $SignalName
    )

    $hour    = (Get-Date).Hour
    $curve   = Get-TMSTimeCurve -Hour $hour
    $dayMod  = Get-TMSDayModifier
    $noise   = (Get-Random -Minimum -50 -Maximum 50) / 10.0  # -5.0 to +5.0

    switch ($SignalName) {
        "EmptyDriving" {
            $base  = $script:TMSState.EmptyDrivingBase
            $value = $base + ($dayMod.Empty) + ((1.0 - $curve) * 20) + $noise

            # Event modifier
            if ($script:TMSState.ActiveEvent -eq "VehicleBreakdown") { $value += 15 }
            if ($script:TMSState.ActiveEvent -eq "TrafficJam")        { $value += 8  }
        }
        "OnTimeDelivery" {
            $base  = $script:TMSState.OnTimeBase
            $value = $base + ($dayMod.OnTime) + (($curve - 0.5) * 10) + $noise

            # Event modifier
            if ($script:TMSState.ActiveEvent -eq "WeatherEvent")      { $value -= 20 }
            if ($script:TMSState.ActiveEvent -eq "TrafficJam")        { $value -= 15 }
            if ($script:TMSState.ActiveEvent -eq "VehicleBreakdown")  { $value -= 10 }
        }
    }

    # Clamp to 0-100
    $value = [Math]::Round([Math]::Max(0, [Math]::Min(100, $value)), 1)
    return $value
}

# ============================================================
# GET-VBAFTMSALLSIGNALS
# ============================================================
function Get-VBAFTMSAllSignals {

    $empty  = Get-VBAFTMSSignal -SignalName "EmptyDriving"
    $ontime = Get-VBAFTMSSignal -SignalName "OnTimeDelivery"

    $snapshot = @{
        Timestamp       = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        EmptyDriving    = $empty
        OnTimeDelivery  = $ontime
        ActiveEvent     = if ($script:TMSState.ActiveEvent) { $script:TMSState.ActiveEvent } else { "None" }
    }

    $script:TMSState.LastSnapshot = $snapshot

    # Tick down event rounds
    if ($script:TMSState.EventRoundsLeft -gt 0) {
        $script:TMSState.EventRoundsLeft--
        if ($script:TMSState.EventRoundsLeft -eq 0) {
            Write-Host "  [TMS] Event '$($script:TMSState.ActiveEvent)' has cleared." -ForegroundColor DarkGray
            $script:TMSState.ActiveEvent = $null
        }
    }

    return $snapshot
}

# ============================================================
# INVOKE-VBAFTMSEVENT
# ============================================================
function Invoke-VBAFTMSEvent {
    param(
        [ValidateSet("WeatherEvent","TrafficJam","VehicleBreakdown","Random")]
        [string] $Event = "Random",
        [int]    $Rounds = 3
    )

    if ($Event -eq "Random") {
        $events = @("WeatherEvent","TrafficJam","VehicleBreakdown")
        $Event  = $events[(Get-Random -Maximum 3)]
    }

    $script:TMSState.ActiveEvent     = $Event
    $script:TMSState.EventRoundsLeft = $Rounds

    $description = switch ($Event) {
        "WeatherEvent"     { "On-Time drops, route efficiency down" }
        "TrafficJam"       { "ETA accuracy drops, cost rises"       }
        "VehicleBreakdown" { "Fleet availability drops, cost spikes" }
    }

    Write-Host ""
    Write-Host "  [TMS EVENT FIRED]" -ForegroundColor Red
    Write-Host ("  Event  : {0}" -f $Event)       -ForegroundColor Yellow
    Write-Host ("  Effect : {0}" -f $description) -ForegroundColor Yellow
    Write-Host ("  Rounds : {0}" -f $Rounds)      -ForegroundColor Yellow
    Write-Host ""
}

# ============================================================
# SHOW-VBAFTMSSTATUS
# ============================================================
function Show-VBAFTMSStatus {

    $s = Get-VBAFTMSAllSignals

    $emptyColor  = if ($s.EmptyDriving -gt 40)  { "Red"   } elseif ($s.EmptyDriving -gt 25)  { "Yellow" } else { "Green" }
    $ontimeColor = if ($s.OnTimeDelivery -lt 70) { "Red"   } elseif ($s.OnTimeDelivery -lt 85) { "Yellow" } else { "Green" }

    Write-Host ""
    Write-Host "  +--------------------------------------+" -ForegroundColor Cyan
    Write-Host "  �     VBAF TMS Simulator � Status      �" -ForegroundColor Cyan
    Write-Host "  �--------------------------------------�" -ForegroundColor Cyan
    Write-Host ("  �  Time   : {0,-27}�" -f $s.Timestamp)   -ForegroundColor White
    Write-Host ("  �  Event  : {0,-27}�" -f $s.ActiveEvent) -ForegroundColor Yellow
    Write-Host "  �--------------------------------------�" -ForegroundColor Cyan
    Write-Host ("  �  Empty Driving    : {0,6} %           �" -f $s.EmptyDriving)   -ForegroundColor $emptyColor
    Write-Host ("  �  On-Time Delivery : {0,6} %           �" -f $s.OnTimeDelivery) -ForegroundColor $ontimeColor
    Write-Host "  +--------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    return $s
}

# ============================================================
# INVOKE-VBAFTMSDAYREPLAY
# Full day compressed � 48 episodes at 30-min intervals
# ============================================================
function Invoke-VBAFTMSDayReplay {
    param(
        [string] $CustomerID = "NordLogistik",
        [switch] $FireEvents
    )

    Write-Host ""
    Write-Host "  [TMS] Starting Day Replay � 48 episodes" -ForegroundColor Cyan
    Write-Host "  [TMS] CustomerID: $CustomerID"           -ForegroundColor White
    Write-Host ""

    $results = @()

    for ($episode = 1; $episode -le 48; $episode++) {

        # Simulate time of day (30 min intervals from 00:00)
        $simulatedHour   = [Math]::Floor(($episode - 1) / 2)
        $simulatedMinute = if (($episode % 2) -eq 0) { 30 } else { 0 }
        $timeLabel       = "{0:00}:{1:00}" -f $simulatedHour, $simulatedMinute

        # Fire a random event occasionally
        if ($FireEvents -and ($episode -in @(10, 24, 38))) {
            Invoke-VBAFTMSEvent -Event "Random" -Rounds 4
        }

        $snapshot = Get-VBAFTMSAllSignals

        $result = [PSCustomObject]@{
            Episode        = $episode
            Time           = $timeLabel
            EmptyDriving   = $snapshot.EmptyDriving
            OnTimeDelivery = $snapshot.OnTimeDelivery
            Event          = $snapshot.ActiveEvent
        }

        $results += $result

        # Color coding
        $emptyColor  = if ($snapshot.EmptyDriving -gt 40)  { "Red"   } elseif ($snapshot.EmptyDriving -gt 25)  { "Yellow" } else { "Green" }
        $ontimeColor = if ($snapshot.OnTimeDelivery -lt 70) { "Red"   } elseif ($snapshot.OnTimeDelivery -lt 85) { "Yellow" } else { "Green" }

        Write-Host ("  Ep {0,2}  {1}  Empty: " -f $episode, $timeLabel) -NoNewline -ForegroundColor White
        Write-Host ("{0,5} %" -f $snapshot.EmptyDriving) -NoNewline -ForegroundColor $emptyColor
        Write-Host ("  OnTime: ") -NoNewline -ForegroundColor White
        Write-Host ("{0,5} %" -f $snapshot.OnTimeDelivery) -NoNewline -ForegroundColor $ontimeColor
        if ($snapshot.ActiveEvent -ne "None") {
            Write-Host ("  [{0}]" -f $snapshot.ActiveEvent) -ForegroundColor Red
        } else {
            Write-Host ""
        }

        Start-Sleep -Milliseconds 200
    }

    Write-Host ""
    Write-Host "  [TMS] Day Replay complete � 48 episodes done." -ForegroundColor Cyan

    # Summary
    $avgEmpty  = [Math]::Round(($results | Measure-Object -Property EmptyDriving  -Average).Average, 1)
    $avgOnTime = [Math]::Round(($results | Measure-Object -Property OnTimeDelivery -Average).Average, 1)
    $redEpisodes = ($results | Where-Object { $_.EmptyDriving -gt 40 -or $_.OnTimeDelivery -lt 70 }).Count

    Write-Host ""
    Write-Host "  +--------------------------------------+" -ForegroundColor Cyan
    Write-Host "  �         Day Replay Summary           �" -ForegroundColor Cyan
    Write-Host "  �--------------------------------------�" -ForegroundColor Cyan
    Write-Host ("  �  Avg Empty Driving    : {0,5} %       �" -f $avgEmpty)   -ForegroundColor White
    Write-Host ("  �  Avg On-Time Delivery : {0,5} %       �" -f $avgOnTime)  -ForegroundColor White
    Write-Host ("  �  Alert Episodes       : {0,5}         �" -f $redEpisodes) -ForegroundColor Yellow
    Write-Host "  +--------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    return $results
}

# ============================================================
# START-VBAFTMSSCHEDULE
# Run in chosen mode continuously
# ============================================================
function Start-VBAFTMSSchedule {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [ValidateSet("Shadow","GoLive","Autonomy","RealTime")]
        [string] $Mode = "Shadow",
        [int]    $MaxRuns = 10
    )

    $intervalSeconds = switch ($Mode) {
        "Shadow"   { 1800 }   # 30 minutes
        "GoLive"   { 600  }   # 10 minutes
        "Autonomy" { 300  }   # 5 minutes
        "RealTime" { 5    }   # 5 seconds � demo mode
    }

    Write-Host ""
    Write-Host "  [TMS] Starting Schedule" -ForegroundColor Cyan
    Write-Host ("  Mode     : {0}"   -f $Mode)                                          -ForegroundColor White
    Write-Host ("  Interval : {0} seconds" -f $intervalSeconds)                         -ForegroundColor White
    Write-Host ("  MaxRuns  : {0}"   -f $MaxRuns)                                       -ForegroundColor White
    Write-Host "  Press Ctrl+C to stop."                                                 -ForegroundColor Yellow
    Write-Host ""

    for ($run = 1; $run -le $MaxRuns; $run++) {

        Write-Host ("  [Run {0}/{1}]" -f $run, $MaxRuns) -ForegroundColor DarkCyan

        $snapshot = Show-VBAFTMSStatus

        # Fire random event every ~8 runs
        if (($run % 8) -eq 0) {
            Invoke-VBAFTMSEvent -Event "Random" -Rounds 3
        }

        if ($run -lt $MaxRuns) {
            Write-Host ("  Next run in {0} seconds..." -f $intervalSeconds) -ForegroundColor DarkGray
            Start-Sleep -Seconds $intervalSeconds
        }
    }

    Write-Host ""
    Write-Host "  [TMS] Schedule complete." -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host "  �   VBAF-Center TMS Simulator  v1.0.0     �" -ForegroundColor Cyan
Write-Host "  �   2 Signals � 3 Events � 4 Modes        �" -ForegroundColor Cyan
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Signals : EmptyDriving % � OnTimeDelivery %"        -ForegroundColor White
Write-Host "  Events  : WeatherEvent � TrafficJam � VehicleBreakdown" -ForegroundColor White
Write-Host "  Modes   : Shadow(30m) � GoLive(10m) � Autonomy(5m) � RealTime" -ForegroundColor White
Write-Host ""
Write-Host "  Quick start:"                                                    -ForegroundColor Yellow
Write-Host "  Show-VBAFTMSStatus"                                              -ForegroundColor Green
Write-Host "  Invoke-VBAFTMSDayReplay -CustomerID 'NordLogistik' -FireEvents"  -ForegroundColor Green
Write-Host "  Start-VBAFTMSSchedule   -CustomerID 'NordLogistik' -Mode Shadow -MaxRuns 10" -ForegroundColor Green
Write-Host ""

