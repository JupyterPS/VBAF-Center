#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center TMS Simulator Standard — 4 Signals
.DESCRIPTION
    Standard 4-signal simulator for customers scoring 16-25
    on the VBAF-Center Assessment (Standard complexity).

    Signals:
      Signal1 — Empty Driving %
      Signal2 — On-Time Delivery %
      Signal3 — Cost Per Trip (DKK)
      Signal4 — Route Efficiency %

    Events:
      WeatherEvent      — On-Time drops, Route drops
      TrafficJam        — Cost rises, ETA drops
      VehicleBreakdown  — Cost spikes, Empty rises
      FuelPriceSpike    — Cost spikes

    Modes:
      Shadow    — every 30 minutes
      GoLive    — every 15 minutes
      Autonomy  — every 10 minutes
      RealTime  — continuous demo

    Functions:
      Get-VBAFTMSStdAllSignals    — get all 4 signals
      Invoke-VBAFTMSStdEvent      — fire a named or random event
      Show-VBAFTMSStdStatus       — dashboard view
      Invoke-VBAFTMSStdDayReplay  — full day 48 episodes
      Start-VBAFTMSStdSchedule    — run in chosen mode
#>

# ============================================================
# STATE
# ============================================================
$script:TMSStdState = @{
    ActiveEvent     = $null
    EventRoundsLeft = 0
    Bases = @{
        EmptyDriving    = 32.0
        OnTimeDelivery  = 74.0
        CostPerTrip     = 1800.0
        RouteEfficiency = 78.0
    }
}

# ============================================================
# TIME OF DAY CURVE
# ============================================================
function Get-TMSStdTimeCurve {
    param([int]$Hour)
    switch ($Hour) {
        {$_ -lt 5}      { return 0.3 }
        {$_ -in 5..7}   { return 0.6 }
        {$_ -in 8..11}  { return 1.0 }
        {$_ -in 12..14} { return 0.9 }
        {$_ -in 15..17} { return 0.8 }
        {$_ -in 18..20} { return 0.6 }
        {$_ -in 21..23} { return 0.4 }
        default          { return 0.5 }
    }
}

# ============================================================
# GET-VBAFTMSSTDALLSIGNALS
# ============================================================
function Get-VBAFTMSStdAllSignals {

    $hour  = (Get-Date).Hour
    $curve = Get-TMSStdTimeCurve -Hour $hour
    $noise = (Get-Random -Minimum -50 -Maximum 50) / 10.0
    $event = $script:TMSStdState.ActiveEvent

    $empty = $script:TMSStdState.Bases.EmptyDriving + ((1.0 - $curve) * 20) + $noise
    if ($event -eq "VehicleBreakdown") { $empty += 15 }
    if ($event -eq "TrafficJam")       { $empty += 8  }

    $ontime = $script:TMSStdState.Bases.OnTimeDelivery + (($curve - 0.5) * 10) + $noise
    if ($event -eq "WeatherEvent")     { $ontime -= 20 }
    if ($event -eq "TrafficJam")       { $ontime -= 15 }
    if ($event -eq "VehicleBreakdown") { $ontime -= 10 }

    $cost = $script:TMSStdState.Bases.CostPerTrip + ((1.0 - $curve) * 200) + ($noise * 10)
    if ($event -eq "VehicleBreakdown") { $cost += 600 }
    if ($event -eq "TrafficJam")       { $cost += 300 }
    if ($event -eq "FuelPriceSpike")   { $cost += 500 }

    $route = $script:TMSStdState.Bases.RouteEfficiency + (($curve - 0.5) * 8) + $noise
    if ($event -eq "WeatherEvent") { $route -= 15 }
    if ($event -eq "TrafficJam")   { $route -= 20 }

    $signals = @{
        EmptyDriving    = [Math]::Round([Math]::Max(0,   [Math]::Min(100,  $empty)),  1)
        OnTimeDelivery  = [Math]::Round([Math]::Max(0,   [Math]::Min(100,  $ontime)), 1)
        CostPerTrip     = [Math]::Round([Math]::Max(800, [Math]::Min(4000, $cost)),   0)
        RouteEfficiency = [Math]::Round([Math]::Max(0,   [Math]::Min(100,  $route)),  1)
        Timestamp       = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        ActiveEvent     = if ($event) { $event } else { "None" }
    }

    if ($script:TMSStdState.EventRoundsLeft -gt 0) {
        $script:TMSStdState.EventRoundsLeft--
        if ($script:TMSStdState.EventRoundsLeft -eq 0) {
            Write-Host ("  [TMS] Event '{0}' cleared." -f $script:TMSStdState.ActiveEvent) -ForegroundColor DarkGray
            $script:TMSStdState.ActiveEvent = $null
        }
    }

    return $signals
}

# ============================================================
# INVOKE-VBAFTMSSTDEVENT
# ============================================================
function Invoke-VBAFTMSStdEvent {
    param(
        [ValidateSet("WeatherEvent","TrafficJam","VehicleBreakdown","FuelPriceSpike","Random")]
        [string] $Event = "Random",
        [int] $Rounds = 4
    )

    if ($Event -eq "Random") {
        $events = @("WeatherEvent","TrafficJam","VehicleBreakdown","FuelPriceSpike")
        $Event  = $events[(Get-Random -Maximum 4)]
    }

    $script:TMSStdState.ActiveEvent     = $Event
    $script:TMSStdState.EventRoundsLeft = $Rounds

    $description = switch ($Event) {
        "WeatherEvent"     { "On-Time drops, Route Efficiency drops"  }
        "TrafficJam"       { "Cost rises, On-Time drops"              }
        "VehicleBreakdown" { "Cost spikes, Empty Driving rises"       }
        "FuelPriceSpike"   { "Cost spikes across all trips"           }
    }

    Write-Host ""
    Write-Host "  [TMS EVENT FIRED]"              -ForegroundColor Red
    Write-Host ("  Event  : {0}" -f $Event)       -ForegroundColor Yellow
    Write-Host ("  Effect : {0}" -f $description) -ForegroundColor Yellow
    Write-Host ("  Rounds : {0}" -f $Rounds)      -ForegroundColor Yellow
    Write-Host ""
}

# ============================================================
# SHOW-VBAFTMSSTDSTATUS
# ============================================================
function Show-VBAFTMSStdStatus {

    $s = Get-VBAFTMSStdAllSignals

    $ec = if ($s.EmptyDriving -gt 40)    { "Red"   } elseif ($s.EmptyDriving -gt 25)    { "Yellow" } else { "Green" }
    $oc = if ($s.OnTimeDelivery -lt 70)  { "Red"   } elseif ($s.OnTimeDelivery -lt 85)  { "Yellow" } else { "Green" }
    $cc = if ($s.CostPerTrip -gt 2500)   { "Red"   } elseif ($s.CostPerTrip -gt 2000)   { "Yellow" } else { "Green" }
    $rc = if ($s.RouteEfficiency -lt 65) { "Red"   } elseif ($s.RouteEfficiency -lt 80) { "Yellow" } else { "Green" }

    Write-Host ""
    Write-Host "  +--------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   VBAF TMS Simulator Standard        |" -ForegroundColor Cyan
    Write-Host "  +--------------------------------------+" -ForegroundColor Cyan
    Write-Host ("  |  Time   : {0,-27}|" -f $s.Timestamp)  -ForegroundColor White
    Write-Host ("  |  Event  : {0,-27}|" -f $s.ActiveEvent) -ForegroundColor Yellow
    Write-Host "  +--------------------------------------+" -ForegroundColor Cyan
    Write-Host ("  |  Empty Driving    : {0,6} %           |" -f $s.EmptyDriving)    -ForegroundColor $ec
    Write-Host ("  |  On-Time Delivery : {0,6} %           |" -f $s.OnTimeDelivery)  -ForegroundColor $oc
    Write-Host ("  |  Cost Per Trip    : {0,6} DKK         |" -f $s.CostPerTrip)     -ForegroundColor $cc
    Write-Host ("  |  Route Efficiency : {0,6} %           |" -f $s.RouteEfficiency) -ForegroundColor $rc
    Write-Host "  +--------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    return $s
}

# ============================================================
# INVOKE-VBAFTMSSTDDAYREPLAY
# ============================================================
function Invoke-VBAFTMSStdDayReplay {
    param(
        [string] $CustomerID = "TruckCompanyDK",
        [switch] $FireEvents
    )

    Write-Host ""
    Write-Host "  [TMS Std] Starting Day Replay — 48 episodes, 4 signals" -ForegroundColor Cyan
    Write-Host ("  [TMS Std] CustomerID: {0}" -f $CustomerID) -ForegroundColor White
    Write-Host ""

    $results = @()

    for ($episode = 1; $episode -le 48; $episode++) {

        $simulatedHour   = [Math]::Floor(($episode - 1) / 2)
        $simulatedMinute = if (($episode % 2) -eq 0) { 30 } else { 0 }
        $timeLabel       = "{0:00}:{1:00}" -f $simulatedHour, $simulatedMinute

        if ($FireEvents -and ($episode -in @(10, 24, 38))) {
            Invoke-VBAFTMSStdEvent -Event "Random" -Rounds 4
        }

        $s = Get-VBAFTMSStdAllSignals

        $result = [PSCustomObject]@{
            Episode         = $episode
            Time            = $timeLabel
            EmptyDriving    = $s.EmptyDriving
            OnTimeDelivery  = $s.OnTimeDelivery
            CostPerTrip     = $s.CostPerTrip
            RouteEfficiency = $s.RouteEfficiency
            Event           = $s.ActiveEvent
        }

        $results += $result

        $ec = if ($s.EmptyDriving -gt 40)   { "Red" } elseif ($s.EmptyDriving -gt 25)   { "Yellow" } else { "Green" }
        $oc = if ($s.OnTimeDelivery -lt 70) { "Red" } elseif ($s.OnTimeDelivery -lt 85) { "Yellow" } else { "Green" }

        Write-Host ("  Ep {0,2}  {1}  Empty: " -f $episode, $timeLabel) -NoNewline -ForegroundColor White
        Write-Host ("{0,5} %" -f $s.EmptyDriving) -NoNewline -ForegroundColor $ec
        Write-Host "  OnTime: " -NoNewline -ForegroundColor White
        Write-Host ("{0,5} %" -f $s.OnTimeDelivery) -NoNewline -ForegroundColor $oc
        Write-Host ("  Cost: {0,5} DKK  Route: {1,5} %" -f $s.CostPerTrip, $s.RouteEfficiency) -NoNewline -ForegroundColor White
        if ($s.ActiveEvent -ne "None") {
            Write-Host ("  [{0}]" -f $s.ActiveEvent) -ForegroundColor Red
        } else {
            Write-Host ""
        }

        Start-Sleep -Milliseconds 150
    }

    $avgEmpty  = [Math]::Round(($results | Measure-Object -Property EmptyDriving    -Average).Average, 1)
    $avgOnTime = [Math]::Round(($results | Measure-Object -Property OnTimeDelivery  -Average).Average, 1)
    $avgCost   = [Math]::Round(($results | Measure-Object -Property CostPerTrip     -Average).Average, 0)
    $avgRoute  = [Math]::Round(($results | Measure-Object -Property RouteEfficiency -Average).Average, 1)
    $alerts    = ($results | Where-Object { $_.EmptyDriving -gt 40 -or $_.OnTimeDelivery -lt 70 -or $_.CostPerTrip -gt 2500 }).Count

    Write-Host ""
    Write-Host "  +--------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |       Day Replay Summary             |" -ForegroundColor Cyan
    Write-Host "  +--------------------------------------+" -ForegroundColor Cyan
    Write-Host ("  |  Avg Empty Driving    : {0,5} %       |" -f $avgEmpty)  -ForegroundColor White
    Write-Host ("  |  Avg On-Time Delivery : {0,5} %       |" -f $avgOnTime) -ForegroundColor White
    Write-Host ("  |  Avg Cost Per Trip    : {0,5} DKK     |" -f $avgCost)   -ForegroundColor White
    Write-Host ("  |  Avg Route Efficiency : {0,5} %       |" -f $avgRoute)  -ForegroundColor White
    Write-Host ("  |  Alert Episodes       : {0,5}         |" -f $alerts)    -ForegroundColor Yellow
    Write-Host "  +--------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    return $results
}

# ============================================================
# START-VBAFTMSSTDSCHEDULE
# ============================================================
function Start-VBAFTMSStdSchedule {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [ValidateSet("Shadow","GoLive","Autonomy","RealTime")]
        [string] $Mode = "Shadow",
        [int] $MaxRuns = 10
    )

    $intervalSeconds = switch ($Mode) {
        "Shadow"   { 1800 }
        "GoLive"   { 900  }
        "Autonomy" { 600  }
        "RealTime" { 5    }
    }

    Write-Host ""
    Write-Host "  [TMS Std] Starting Schedule"                              -ForegroundColor Cyan
    Write-Host ("  Mode     : {0}" -f $Mode)                               -ForegroundColor White
    Write-Host ("  Interval : {0} seconds" -f $intervalSeconds)            -ForegroundColor White
    Write-Host ("  MaxRuns  : {0}" -f $MaxRuns)                            -ForegroundColor White
    Write-Host "  Press Ctrl+C to stop."                                    -ForegroundColor Yellow
    Write-Host ""

    for ($run = 1; $run -le $MaxRuns; $run++) {
        Write-Host ("  [Run {0}/{1}]" -f $run, $MaxRuns) -ForegroundColor DarkCyan
        Show-VBAFTMSStdStatus | Out-Null
        if (($run % 7) -eq 0) { Invoke-VBAFTMSStdEvent -Event "Random" -Rounds 3 }
        if ($run -lt $MaxRuns) {
            Write-Host ("  Next run in {0} seconds..." -f $intervalSeconds) -ForegroundColor DarkGray
            Start-Sleep -Seconds $intervalSeconds
        }
    }

    Write-Host ""
    Write-Host "  [TMS Std] Schedule complete." -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |  VBAF-Center TMS Simulator Standard      |" -ForegroundColor Cyan
Write-Host "  |  4 Signals · 4 Events · 4 Modes          |" -ForegroundColor Cyan
Write-Host "  |  For Assessment score 16-25              |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Signals : EmptyDriving · OnTimeDelivery · CostPerTrip · RouteEfficiency" -ForegroundColor White
Write-Host "  Events  : WeatherEvent · TrafficJam · VehicleBreakdown · FuelPriceSpike" -ForegroundColor White
Write-Host "  Modes   : Shadow(30m) · GoLive(15m) · Autonomy(10m) · RealTime"          -ForegroundColor White
Write-Host ""
Write-Host "  Quick start:"                                                                          -ForegroundColor Yellow
Write-Host "  Show-VBAFTMSStdStatus"                                                                 -ForegroundColor Green
Write-Host "  Invoke-VBAFTMSStdDayReplay -CustomerID 'TruckCompanyDK' -FireEvents"                    -ForegroundColor Green
Write-Host "  Start-VBAFTMSStdSchedule   -CustomerID 'TruckCompanyDK' -Mode Shadow -MaxRuns 10"       -ForegroundColor Green
Write-Host ""