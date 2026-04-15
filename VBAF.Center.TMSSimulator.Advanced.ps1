#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center TMS Simulator Advanced — 6 Signals
.DESCRIPTION
    Advanced 6-signal simulator for customers scoring 26-32
    on the VBAF-Center Assessment (Advanced complexity).

    Signals:
      Signal1 — Empty Driving %
      Signal2 — On-Time Delivery %
      Signal3 — Cost Per Trip (DKK)
      Signal4 — Route Efficiency %
      Signal5 — Driver Performance %
      Signal6 — Fleet Availability %

    Events:
      WeatherEvent      — On-Time drops, Route drops
      TrafficJam        — Cost rises, Route drops
      VehicleBreakdown  — Fleet drops, Cost spikes
      DriverSickDay     — Driver Performance drops
      FuelPriceSpike    — Cost spikes

    Modes:
      Shadow    — every 30 minutes
      GoLive    — every 10 minutes
      Autonomy  — every 5 minutes
      RealTime  — continuous demo

    Functions:
      Get-VBAFTMSAdvAllSignals    — get all 6 signals
      Invoke-VBAFTMSAdvEvent      — fire a named or random event
      Show-VBAFTMSAdvStatus       — dashboard view
      Invoke-VBAFTMSAdvDayReplay  — full day 48 episodes
      Start-VBAFTMSAdvSchedule    — run in chosen mode
#>

# ============================================================
# STATE
# ============================================================
$script:TMSAdvState = @{
    ActiveEvent     = $null
    EventRoundsLeft = 0
    Bases = @{
        EmptyDriving      = 32.0
        OnTimeDelivery    = 74.0
        CostPerTrip       = 1800.0
        RouteEfficiency   = 78.0
        DriverPerformance = 80.0
        FleetAvailability = 88.0
    }
}

# ============================================================
# TIME OF DAY CURVE
# ============================================================
function Get-TMSAdvTimeCurve {
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
# GET-VBAFTMSADVALLSIGNALS
# ============================================================
function Get-VBAFTMSAdvAllSignals {

    $hour  = (Get-Date).Hour
    $curve = Get-TMSAdvTimeCurve -Hour $hour
    $noise = (Get-Random -Minimum -50 -Maximum 50) / 10.0
    $event = $script:TMSAdvState.ActiveEvent

    $empty = $script:TMSAdvState.Bases.EmptyDriving + ((1.0 - $curve) * 20) + $noise
    if ($event -eq "VehicleBreakdown") { $empty += 15 }
    if ($event -eq "TrafficJam")       { $empty += 8  }

    $ontime = $script:TMSAdvState.Bases.OnTimeDelivery + (($curve - 0.5) * 10) + $noise
    if ($event -eq "WeatherEvent")     { $ontime -= 20 }
    if ($event -eq "TrafficJam")       { $ontime -= 15 }
    if ($event -eq "VehicleBreakdown") { $ontime -= 10 }
    if ($event -eq "DriverSickDay")    { $ontime -= 8  }

    $cost = $script:TMSAdvState.Bases.CostPerTrip + ((1.0 - $curve) * 200) + ($noise * 10)
    if ($event -eq "VehicleBreakdown") { $cost += 600 }
    if ($event -eq "TrafficJam")       { $cost += 300 }
    if ($event -eq "FuelPriceSpike")   { $cost += 500 }

    $route = $script:TMSAdvState.Bases.RouteEfficiency + (($curve - 0.5) * 8) + $noise
    if ($event -eq "WeatherEvent") { $route -= 15 }
    if ($event -eq "TrafficJam")   { $route -= 20 }

    $driver = $script:TMSAdvState.Bases.DriverPerformance + (($curve - 0.5) * 6) + $noise
    if ($event -eq "DriverSickDay") { $driver -= 20 }

    $fleet = $script:TMSAdvState.Bases.FleetAvailability + (($curve - 0.5) * 4) + $noise
    if ($event -eq "VehicleBreakdown") { $fleet -= 15 }

    $signals = @{
        EmptyDriving      = [Math]::Round([Math]::Max(0,   [Math]::Min(100,  $empty)),  1)
        OnTimeDelivery    = [Math]::Round([Math]::Max(0,   [Math]::Min(100,  $ontime)), 1)
        CostPerTrip       = [Math]::Round([Math]::Max(800, [Math]::Min(4000, $cost)),   0)
        RouteEfficiency   = [Math]::Round([Math]::Max(0,   [Math]::Min(100,  $route)),  1)
        DriverPerformance = [Math]::Round([Math]::Max(0,   [Math]::Min(100,  $driver)), 1)
        FleetAvailability = [Math]::Round([Math]::Max(0,   [Math]::Min(100,  $fleet)),  1)
        Timestamp         = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        ActiveEvent       = if ($event) { $event } else { "None" }
    }

    if ($script:TMSAdvState.EventRoundsLeft -gt 0) {
        $script:TMSAdvState.EventRoundsLeft--
        if ($script:TMSAdvState.EventRoundsLeft -eq 0) {
            Write-Host ("  [TMS] Event '{0}' cleared." -f $script:TMSAdvState.ActiveEvent) -ForegroundColor DarkGray
            $script:TMSAdvState.ActiveEvent = $null
        }
    }

    return $signals
}

# ============================================================
# INVOKE-VBAFTMSADVEVENT
# ============================================================
function Invoke-VBAFTMSAdvEvent {
    param(
        [ValidateSet("WeatherEvent","TrafficJam","VehicleBreakdown","DriverSickDay","FuelPriceSpike","Random")]
        [string] $Event = "Random",
        [int] $Rounds = 4
    )

    if ($Event -eq "Random") {
        $events = @("WeatherEvent","TrafficJam","VehicleBreakdown","DriverSickDay","FuelPriceSpike")
        $Event  = $events[(Get-Random -Maximum 5)]
    }

    $script:TMSAdvState.ActiveEvent     = $Event
    $script:TMSAdvState.EventRoundsLeft = $Rounds

    $description = switch ($Event) {
        "WeatherEvent"     { "On-Time drops, Route Efficiency drops"       }
        "TrafficJam"       { "Cost rises, Route Efficiency drops"          }
        "VehicleBreakdown" { "Fleet drops, Cost spikes, Empty rises"       }
        "DriverSickDay"    { "Driver Performance drops, On-Time drops"     }
        "FuelPriceSpike"   { "Cost spikes across all trips"                }
    }

    Write-Host ""
    Write-Host "  [TMS EVENT FIRED]"              -ForegroundColor Red
    Write-Host ("  Event  : {0}" -f $Event)       -ForegroundColor Yellow
    Write-Host ("  Effect : {0}" -f $description) -ForegroundColor Yellow
    Write-Host ("  Rounds : {0}" -f $Rounds)      -ForegroundColor Yellow
    Write-Host ""
}

# ============================================================
# SHOW-VBAFTMSADVSTATUS
# ============================================================
function Show-VBAFTMSAdvStatus {

    $s = Get-VBAFTMSAdvAllSignals

    $ec = if ($s.EmptyDriving -gt 40)      { "Red"   } elseif ($s.EmptyDriving -gt 25)      { "Yellow" } else { "Green" }
    $oc = if ($s.OnTimeDelivery -lt 70)    { "Red"   } elseif ($s.OnTimeDelivery -lt 85)    { "Yellow" } else { "Green" }
    $cc = if ($s.CostPerTrip -gt 2500)     { "Red"   } elseif ($s.CostPerTrip -gt 2000)     { "Yellow" } else { "Green" }
    $rc = if ($s.RouteEfficiency -lt 65)   { "Red"   } elseif ($s.RouteEfficiency -lt 80)   { "Yellow" } else { "Green" }
    $dc = if ($s.DriverPerformance -lt 65) { "Red"   } elseif ($s.DriverPerformance -lt 78) { "Yellow" } else { "Green" }
    $fc = if ($s.FleetAvailability -lt 75) { "Red"   } elseif ($s.FleetAvailability -lt 85) { "Yellow" } else { "Green" }

    Write-Host ""
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   VBAF TMS Simulator Advanced            |" -ForegroundColor Cyan
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host ("  |  Time    : {0,-31}|" -f $s.Timestamp)      -ForegroundColor White
    Write-Host ("  |  Event   : {0,-31}|" -f $s.ActiveEvent)    -ForegroundColor Yellow
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host ("  |  Empty Driving      : {0,6} %             |" -f $s.EmptyDriving)      -ForegroundColor $ec
    Write-Host ("  |  On-Time Delivery   : {0,6} %             |" -f $s.OnTimeDelivery)    -ForegroundColor $oc
    Write-Host ("  |  Cost Per Trip      : {0,6} DKK           |" -f $s.CostPerTrip)       -ForegroundColor $cc
    Write-Host ("  |  Route Efficiency   : {0,6} %             |" -f $s.RouteEfficiency)   -ForegroundColor $rc
    Write-Host ("  |  Driver Performance : {0,6} %             |" -f $s.DriverPerformance) -ForegroundColor $dc
    Write-Host ("  |  Fleet Availability : {0,6} %             |" -f $s.FleetAvailability) -ForegroundColor $fc
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    return $s
}

# ============================================================
# INVOKE-VBAFTMSADVDAYREPLAY
# ============================================================
function Invoke-VBAFTMSAdvDayReplay {
    param(
        [string] $CustomerID = "TruckCompanyDK",
        [switch] $FireEvents
    )

    Write-Host ""
    Write-Host "  [TMS Adv] Starting Day Replay — 48 episodes, 6 signals" -ForegroundColor Cyan
    Write-Host ("  [TMS Adv] CustomerID: {0}" -f $CustomerID) -ForegroundColor White
    Write-Host ""

    $results = @()

    for ($episode = 1; $episode -le 48; $episode++) {

        $simulatedHour   = [Math]::Floor(($episode - 1) / 2)
        $simulatedMinute = if (($episode % 2) -eq 0) { 30 } else { 0 }
        $timeLabel       = "{0:00}:{1:00}" -f $simulatedHour, $simulatedMinute

        if ($FireEvents -and ($episode -in @(10, 24, 38))) {
            Invoke-VBAFTMSAdvEvent -Event "Random" -Rounds 4
        }

        $s = Get-VBAFTMSAdvAllSignals

        $result = [PSCustomObject]@{
            Episode           = $episode
            Time              = $timeLabel
            EmptyDriving      = $s.EmptyDriving
            OnTimeDelivery    = $s.OnTimeDelivery
            CostPerTrip       = $s.CostPerTrip
            RouteEfficiency   = $s.RouteEfficiency
            DriverPerformance = $s.DriverPerformance
            FleetAvailability = $s.FleetAvailability
            Event             = $s.ActiveEvent
        }

        $results += $result

        $ec = if ($s.EmptyDriving -gt 40)   { "Red" } elseif ($s.EmptyDriving -gt 25)   { "Yellow" } else { "Green" }
        $oc = if ($s.OnTimeDelivery -lt 70) { "Red" } elseif ($s.OnTimeDelivery -lt 85) { "Yellow" } else { "Green" }

        Write-Host ("  Ep {0,2}  {1}  Empty: " -f $episode, $timeLabel) -NoNewline -ForegroundColor White
        Write-Host ("{0,5} %" -f $s.EmptyDriving) -NoNewline -ForegroundColor $ec
        Write-Host "  OnTime: " -NoNewline -ForegroundColor White
        Write-Host ("{0,5} %" -f $s.OnTimeDelivery) -NoNewline -ForegroundColor $oc
        Write-Host ("  Cost: {0,5} DKK  Driver: {1,5} %  Fleet: {2,5} %" -f $s.CostPerTrip, $s.DriverPerformance, $s.FleetAvailability) -NoNewline -ForegroundColor White
        if ($s.ActiveEvent -ne "None") {
            Write-Host ("  [{0}]" -f $s.ActiveEvent) -ForegroundColor Red
        } else {
            Write-Host ""
        }

        Start-Sleep -Milliseconds 150
    }

    $avgEmpty  = [Math]::Round(($results | Measure-Object -Property EmptyDriving      -Average).Average, 1)
    $avgOnTime = [Math]::Round(($results | Measure-Object -Property OnTimeDelivery    -Average).Average, 1)
    $avgCost   = [Math]::Round(($results | Measure-Object -Property CostPerTrip       -Average).Average, 0)
    $avgDriver = [Math]::Round(($results | Measure-Object -Property DriverPerformance -Average).Average, 1)
    $avgFleet  = [Math]::Round(($results | Measure-Object -Property FleetAvailability -Average).Average, 1)
    $alerts    = ($results | Where-Object { $_.EmptyDriving -gt 40 -or $_.OnTimeDelivery -lt 70 -or $_.CostPerTrip -gt 2500 }).Count

    Write-Host ""
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |         Day Replay Summary               |" -ForegroundColor Cyan
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host ("  |  Avg Empty Driving    : {0,5} %           |" -f $avgEmpty)  -ForegroundColor White
    Write-Host ("  |  Avg On-Time Delivery : {0,5} %           |" -f $avgOnTime) -ForegroundColor White
    Write-Host ("  |  Avg Cost Per Trip    : {0,5} DKK         |" -f $avgCost)   -ForegroundColor White
    Write-Host ("  |  Avg Driver Score     : {0,5} %           |" -f $avgDriver) -ForegroundColor White
    Write-Host ("  |  Avg Fleet Available  : {0,5} %           |" -f $avgFleet)  -ForegroundColor White
    Write-Host ("  |  Alert Episodes       : {0,5}             |" -f $alerts)    -ForegroundColor Yellow
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    return $results
}

# ============================================================
# START-VBAFTMSADVSCHEDULE
# ============================================================
function Start-VBAFTMSAdvSchedule {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [ValidateSet("Shadow","GoLive","Autonomy","RealTime")]
        [string] $Mode = "Shadow",
        [int] $MaxRuns = 10
    )

    $intervalSeconds = switch ($Mode) {
        "Shadow"   { 1800 }
        "GoLive"   { 600  }
        "Autonomy" { 300  }
        "RealTime" { 5    }
    }

    Write-Host ""
    Write-Host "  [TMS Adv] Starting Schedule"                              -ForegroundColor Cyan
    Write-Host ("  Mode     : {0}" -f $Mode)                               -ForegroundColor White
    Write-Host ("  Interval : {0} seconds" -f $intervalSeconds)            -ForegroundColor White
    Write-Host ("  MaxRuns  : {0}" -f $MaxRuns)                            -ForegroundColor White
    Write-Host "  Press Ctrl+C to stop."                                    -ForegroundColor Yellow
    Write-Host ""

    for ($run = 1; $run -le $MaxRuns; $run++) {
        Write-Host ("  [Run {0}/{1}]" -f $run, $MaxRuns) -ForegroundColor DarkCyan
        Show-VBAFTMSAdvStatus | Out-Null
        if (($run % 6) -eq 0) { Invoke-VBAFTMSAdvEvent -Event "Random" -Rounds 3 }
        if ($run -lt $MaxRuns) {
            Write-Host ("  Next run in {0} seconds..." -f $intervalSeconds) -ForegroundColor DarkGray
            Start-Sleep -Seconds $intervalSeconds
        }
    }

    Write-Host ""
    Write-Host "  [TMS Adv] Schedule complete." -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |  VBAF-Center TMS Simulator Advanced      |" -ForegroundColor Cyan
Write-Host "  |  6 Signals · 5 Events · 4 Modes          |" -ForegroundColor Cyan
Write-Host "  |  For Assessment score 26-32              |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Signals : EmptyDriving · OnTimeDelivery · CostPerTrip"           -ForegroundColor White
Write-Host "            RouteEfficiency · DriverPerformance · FleetAvailability" -ForegroundColor White
Write-Host "  Events  : WeatherEvent · TrafficJam · VehicleBreakdown"           -ForegroundColor White
Write-Host "            DriverSickDay · FuelPriceSpike"                          -ForegroundColor White
Write-Host "  Modes   : Shadow(30m) · GoLive(10m) · Autonomy(5m) · RealTime"    -ForegroundColor White
Write-Host ""
Write-Host "  Quick start:"                                                                          -ForegroundColor Yellow
Write-Host "  Show-VBAFTMSAdvStatus"                                                                 -ForegroundColor Green
Write-Host "  Invoke-VBAFTMSAdvDayReplay -CustomerID 'TruckCompanyDK' -FireEvents"                    -ForegroundColor Green
Write-Host "  Start-VBAFTMSAdvSchedule   -CustomerID 'TruckCompanyDK' -Mode Shadow -MaxRuns 10"       -ForegroundColor Green
Write-Host ""