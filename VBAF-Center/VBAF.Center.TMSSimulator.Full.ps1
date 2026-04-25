#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center TMS Simulator Full — Real World Test Engine
.DESCRIPTION
    Full 10-signal simulator with 6 events, time of day curves,
    day of week patterns and signal correlations.

    Signals:
      Signal1  — Empty Driving %
      Signal2  — On-Time Delivery %
      Signal3  — Cost Per Trip (DKK)
      Signal4  — Route Efficiency %
      Signal5  — ETA Accuracy %
      Signal6  — CO2 Per Trip (kg)
      Signal7  — POD Completion %
      Signal8  — Driver Performance %
      Signal9  — Fleet Availability %
      Signal10 — Capacity Utilisation %

    Events:
      WeatherEvent      — On-Time drops, CO2 rises
      TrafficJam        — ETA drops, Cost rises
      VehicleBreakdown  — Fleet drops, Cost spikes
      DriverSickDay     — Performance drops, Capacity drops
      HighDemandSurge   — Capacity spikes, Cost rises
      FuelPriceSpike    — Cost spikes, CO2 rises

    Modes:
      Shadow    — every 30 minutes (48 episodes/day)
      GoLive    — every 10 minutes (144 episodes/day)
      Autonomy  — every 5 minutes  (288 episodes/day)
      RealTime  — continuous demo/stress test

    Functions:
      Get-VBAFTMSFullSignal       — get one signal value
      Get-VBAFTMSFullAllSignals   — get all 10 signals
      Invoke-VBAFTMSFullEvent     — fire a named or random event
      Show-VBAFTMSFullStatus      — dashboard view
      Invoke-VBAFTMSFullDayReplay — full day 48 episodes
      Start-VBAFTMSFullSchedule   — run in chosen mode
#>

# ============================================================
# STATE
# ============================================================
$script:TMSFullState = @{
    ActiveEvent      = $null
    EventRoundsLeft  = 0
    Bases = @{
        EmptyDriving       = 32.0
        OnTimeDelivery     = 74.0
        CostPerTrip        = 1800.0
        RouteEfficiency    = 78.0
        ETAAccuracy        = 76.0
        CO2PerTrip         = 45.0
        PODCompletion      = 92.0
        DriverPerformance  = 80.0
        FleetAvailability  = 88.0
        CapacityUtil       = 72.0
    }
}

# ============================================================
# TIME OF DAY CURVE
# ============================================================
function Get-TMSFullTimeCurve {
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
# DAY OF WEEK MODIFIER
# ============================================================
function Get-TMSFullDayModifier {
    $day = (Get-Date).DayOfWeek
    switch ($day) {
        "Monday"    { return @{ Performance=+3;  Cost=-100; Capacity=+8  } }
        "Tuesday"   { return @{ Performance=+5;  Cost=-200; Capacity=+5  } }
        "Wednesday" { return @{ Performance=0;   Cost=0;    Capacity=0   } }
        "Thursday"  { return @{ Performance=-2;  Cost=+100; Capacity=-3  } }
        "Friday"    { return @{ Performance=-5;  Cost=+200; Capacity=-10 } }
        "Saturday"  { return @{ Performance=-10; Cost=+400; Capacity=-20 } }
        "Sunday"    { return @{ Performance=-15; Cost=+600; Capacity=-30 } }
        default     { return @{ Performance=0;   Cost=0;    Capacity=0   } }
    }
}

# ============================================================
# GET-VBAFTMSFULLSIGNAL
# ============================================================
function Get-VBAFTMSFullSignal {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("EmptyDriving","OnTimeDelivery","CostPerTrip","RouteEfficiency",
                     "ETAAccuracy","CO2PerTrip","PODCompletion","DriverPerformance",
                     "FleetAvailability","CapacityUtil")]
        [string] $SignalName
    )

    $hour   = (Get-Date).Hour
    $curve  = Get-TMSFullTimeCurve -Hour $hour
    $dayMod = Get-TMSFullDayModifier
    $noise  = (Get-Random -Minimum -50 -Maximum 50) / 10.0
    $event  = $script:TMSFullState.ActiveEvent
    $base   = $script:TMSFullState.Bases[$SignalName]

    $value = switch ($SignalName) {

        "EmptyDriving" {
            $v = $base + ((1.0 - $curve) * 20) + $noise
            if ($event -eq "VehicleBreakdown") { $v += 15 }
            if ($event -eq "TrafficJam")        { $v += 8  }
            if ($event -eq "HighDemandSurge")   { $v -= 5  }
            $v
        }

        "OnTimeDelivery" {
            $v = $base + (($curve - 0.5) * 10) + $noise
            if ($event -eq "WeatherEvent")     { $v -= 20 }
            if ($event -eq "TrafficJam")       { $v -= 15 }
            if ($event -eq "VehicleBreakdown") { $v -= 10 }
            if ($event -eq "DriverSickDay")    { $v -= 8  }
            $v
        }

        "CostPerTrip" {
            $v = $base + $dayMod.Cost + ((1.0 - $curve) * 200) + ($noise * 10)
            if ($event -eq "VehicleBreakdown") { $v += 600 }
            if ($event -eq "TrafficJam")       { $v += 300 }
            if ($event -eq "FuelPriceSpike")   { $v += 500 }
            if ($event -eq "HighDemandSurge")  { $v += 400 }
            $v
        }

        "RouteEfficiency" {
            $v = $base + (($curve - 0.5) * 8) + $noise
            if ($event -eq "WeatherEvent")  { $v -= 15 }
            if ($event -eq "TrafficJam")    { $v -= 20 }
            $v
        }

        "ETAAccuracy" {
            $v = $base + (($curve - 0.5) * 8) + $noise
            if ($event -eq "TrafficJam")       { $v -= 25 }
            if ($event -eq "WeatherEvent")     { $v -= 15 }
            if ($event -eq "VehicleBreakdown") { $v -= 10 }
            $v
        }

        "CO2PerTrip" {
            $v = $base + ((1.0 - $curve) * 10) + ($noise * 0.5)
            if ($event -eq "WeatherEvent")   { $v += 20 }
            if ($event -eq "FuelPriceSpike") { $v += 15 }
            if ($event -eq "TrafficJam")     { $v += 10 }
            $v
        }

        "PODCompletion" {
            $v = $base + (($curve - 0.5) * 5) + $noise
            if ($event -eq "DriverSickDay")    { $v -= 10 }
            if ($event -eq "VehicleBreakdown") { $v -= 8  }
            $v
        }

        "DriverPerformance" {
            $v = $base + $dayMod.Performance + (($curve - 0.5) * 6) + $noise
            if ($event -eq "DriverSickDay") { $v -= 20 }
            $v
        }

        "FleetAvailability" {
            $v = $base + (($curve - 0.5) * 4) + $noise
            if ($event -eq "VehicleBreakdown") { $v -= 15 }
            if ($event -eq "HighDemandSurge")  { $v -= 8  }
            $v
        }

        "CapacityUtil" {
            $v = $base + $dayMod.Capacity + (($curve - 0.5) * 12) + $noise
            if ($event -eq "HighDemandSurge")  { $v += 20 }
            if ($event -eq "VehicleBreakdown") { $v -= 10 }
            if ($event -eq "DriverSickDay")    { $v -= 8  }
            $v
        }
    }

    # Clamp 0-100 for percentages, 800-4000 for cost, 10-120 for CO2
    switch ($SignalName) {
        "CostPerTrip" { $value = [Math]::Round([Math]::Max(800,  [Math]::Min(4000, $value)), 0) }
        "CO2PerTrip"  { $value = [Math]::Round([Math]::Max(10,   [Math]::Min(120,  $value)), 1) }
        default        { $value = [Math]::Round([Math]::Max(0,    [Math]::Min(100,  $value)), 1) }
    }

    return $value
}

# ============================================================
# GET-VBAFTMSFULLALLSIGNALS
# ============================================================
function Get-VBAFTMSFullAllSignals {

    $signals = [ordered]@{
        EmptyDriving      = Get-VBAFTMSFullSignal -SignalName "EmptyDriving"
        OnTimeDelivery    = Get-VBAFTMSFullSignal -SignalName "OnTimeDelivery"
        CostPerTrip       = Get-VBAFTMSFullSignal -SignalName "CostPerTrip"
        RouteEfficiency   = Get-VBAFTMSFullSignal -SignalName "RouteEfficiency"
        ETAAccuracy       = Get-VBAFTMSFullSignal -SignalName "ETAAccuracy"
        CO2PerTrip        = Get-VBAFTMSFullSignal -SignalName "CO2PerTrip"
        PODCompletion     = Get-VBAFTMSFullSignal -SignalName "PODCompletion"
        DriverPerformance = Get-VBAFTMSFullSignal -SignalName "DriverPerformance"
        FleetAvailability = Get-VBAFTMSFullSignal -SignalName "FleetAvailability"
        CapacityUtil      = Get-VBAFTMSFullSignal -SignalName "CapacityUtil"
        Timestamp         = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        ActiveEvent       = if ($script:TMSFullState.ActiveEvent) { $script:TMSFullState.ActiveEvent } else { "None" }
    }

    # Tick down event
    if ($script:TMSFullState.EventRoundsLeft -gt 0) {
        $script:TMSFullState.EventRoundsLeft--
        if ($script:TMSFullState.EventRoundsLeft -eq 0) {
            Write-Host ("  [TMS] Event '{0}' cleared." -f $script:TMSFullState.ActiveEvent) -ForegroundColor DarkGray
            $script:TMSFullState.ActiveEvent = $null
        }
    }

    return $signals
}

# ============================================================
# INVOKE-VBAFTMSFULLEVENT
# ============================================================
function Invoke-VBAFTMSFullEvent {
    param(
        [ValidateSet("WeatherEvent","TrafficJam","VehicleBreakdown","DriverSickDay","HighDemandSurge","FuelPriceSpike","Random")]
        [string] $Event = "Random",
        [int] $Rounds = 4
    )

    if ($Event -eq "Random") {
        $events = @("WeatherEvent","TrafficJam","VehicleBreakdown","DriverSickDay","HighDemandSurge","FuelPriceSpike")
        $Event  = $events[(Get-Random -Maximum 6)]
    }

    $script:TMSFullState.ActiveEvent     = $Event
    $script:TMSFullState.EventRoundsLeft = $Rounds

    $description = switch ($Event) {
        "WeatherEvent"     { "On-Time drops, Route Efficiency drops, CO2 rises" }
        "TrafficJam"       { "ETA drops, Cost rises, Route Efficiency drops"    }
        "VehicleBreakdown" { "Fleet Availability drops, Cost spikes, Empty rises"}
        "DriverSickDay"    { "Driver Performance drops, Capacity drops"         }
        "HighDemandSurge"  { "Capacity spikes, Cost rises, Fleet under pressure" }
        "FuelPriceSpike"   { "Cost spikes, CO2 rises"                           }
    }

    Write-Host ""
    Write-Host "  [TMS EVENT FIRED]"              -ForegroundColor Red
    Write-Host ("  Event  : {0}" -f $Event)       -ForegroundColor Yellow
    Write-Host ("  Effect : {0}" -f $description) -ForegroundColor Yellow
    Write-Host ("  Rounds : {0}" -f $Rounds)      -ForegroundColor Yellow
    Write-Host ""
}

# ============================================================
# SHOW-VBAFTMSFULLSTATUS
# ============================================================
function Show-VBAFTMSFullStatus {

    $s = Get-VBAFTMSFullAllSignals

    $ec = if ($s.EmptyDriving -gt 40)      { "Red"   } elseif ($s.EmptyDriving -gt 25)      { "Yellow" } else { "Green" }
    $oc = if ($s.OnTimeDelivery -lt 70)    { "Red"   } elseif ($s.OnTimeDelivery -lt 85)    { "Yellow" } else { "Green" }
    $cc = if ($s.CostPerTrip -gt 2500)     { "Red"   } elseif ($s.CostPerTrip -gt 2000)     { "Yellow" } else { "Green" }
    $rc = if ($s.RouteEfficiency -lt 65)   { "Red"   } elseif ($s.RouteEfficiency -lt 80)   { "Yellow" } else { "Green" }
    $ac = if ($s.ETAAccuracy -lt 65)       { "Red"   } elseif ($s.ETAAccuracy -lt 80)       { "Yellow" } else { "Green" }
    $co = if ($s.CO2PerTrip -gt 70)        { "Red"   } elseif ($s.CO2PerTrip -gt 55)        { "Yellow" } else { "Green" }
    $pc = if ($s.PODCompletion -lt 85)     { "Red"   } elseif ($s.PODCompletion -lt 92)     { "Yellow" } else { "Green" }
    $dc = if ($s.DriverPerformance -lt 65) { "Red"   } elseif ($s.DriverPerformance -lt 78) { "Yellow" } else { "Green" }
    $fc = if ($s.FleetAvailability -lt 75) { "Red"   } elseif ($s.FleetAvailability -lt 85) { "Yellow" } else { "Green" }
    $kc = if ($s.CapacityUtil -lt 55)      { "Red"   } elseif ($s.CapacityUtil -lt 70)      { "Yellow" } else { "Green" }

    Write-Host ""
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   VBAF TMS Simulator Full — Status               |" -ForegroundColor Cyan
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ("  |  Time    : {0,-39}|" -f $s.Timestamp)              -ForegroundColor White
    Write-Host ("  |  Event   : {0,-39}|" -f $s.ActiveEvent)            -ForegroundColor Yellow
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ("  |  Empty Driving       : {0,6} %                  |" -f $s.EmptyDriving)      -ForegroundColor $ec
    Write-Host ("  |  On-Time Delivery    : {0,6} %                  |" -f $s.OnTimeDelivery)    -ForegroundColor $oc
    Write-Host ("  |  Cost Per Trip       : {0,6} DKK                |" -f $s.CostPerTrip)       -ForegroundColor $cc
    Write-Host ("  |  Route Efficiency    : {0,6} %                  |" -f $s.RouteEfficiency)   -ForegroundColor $rc
    Write-Host ("  |  ETA Accuracy        : {0,6} %                  |" -f $s.ETAAccuracy)       -ForegroundColor $ac
    Write-Host ("  |  CO2 Per Trip        : {0,6} kg                 |" -f $s.CO2PerTrip)        -ForegroundColor $co
    Write-Host ("  |  POD Completion      : {0,6} %                  |" -f $s.PODCompletion)     -ForegroundColor $pc
    Write-Host ("  |  Driver Performance  : {0,6} %                  |" -f $s.DriverPerformance) -ForegroundColor $dc
    Write-Host ("  |  Fleet Availability  : {0,6} %                  |" -f $s.FleetAvailability) -ForegroundColor $fc
    Write-Host ("  |  Capacity Util       : {0,6} %                  |" -f $s.CapacityUtil)      -ForegroundColor $kc
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    return $s
}

# ============================================================
# INVOKE-VBAFTMSFULLDAYREPLAY
# ============================================================
function Invoke-VBAFTMSFullDayReplay {
    param(
        [string] $CustomerID = "TruckCompanyDK",
        [switch] $FireEvents
    )

    Write-Host ""
    Write-Host "  [TMS Full] Starting Day Replay — 48 episodes, 10 signals" -ForegroundColor Cyan
    Write-Host ("  [TMS Full] CustomerID: {0}" -f $CustomerID) -ForegroundColor White
    Write-Host ""

    $results = @()

    for ($episode = 1; $episode -le 48; $episode++) {

        $simulatedHour   = [Math]::Floor(($episode - 1) / 2)
        $simulatedMinute = if (($episode % 2) -eq 0) { 30 } else { 0 }
        $timeLabel       = "{0:00}:{1:00}" -f $simulatedHour, $simulatedMinute

        if ($FireEvents -and ($episode -in @(8, 18, 30, 42))) {
            Invoke-VBAFTMSFullEvent -Event "Random" -Rounds 3
        }

        $s = Get-VBAFTMSFullAllSignals

        $result = [PSCustomObject]@{
            Episode           = $episode
            Time              = $timeLabel
            EmptyDriving      = $s.EmptyDriving
            OnTimeDelivery    = $s.OnTimeDelivery
            CostPerTrip       = $s.CostPerTrip
            RouteEfficiency   = $s.RouteEfficiency
            ETAAccuracy       = $s.ETAAccuracy
            CO2PerTrip        = $s.CO2PerTrip
            PODCompletion     = $s.PODCompletion
            DriverPerformance = $s.DriverPerformance
            FleetAvailability = $s.FleetAvailability
            CapacityUtil      = $s.CapacityUtil
            Event             = $s.ActiveEvent
        }

        $results += $result

        $ec = if ($s.EmptyDriving -gt 40)   { "Red" } elseif ($s.EmptyDriving -gt 25)   { "Yellow" } else { "Green" }
        $oc = if ($s.OnTimeDelivery -lt 70) { "Red" } elseif ($s.OnTimeDelivery -lt 85) { "Yellow" } else { "Green" }

        Write-Host ("  Ep {0,2}  {1}  Empty: " -f $episode, $timeLabel) -NoNewline -ForegroundColor White
        Write-Host ("{0,5} %" -f $s.EmptyDriving) -NoNewline -ForegroundColor $ec
        Write-Host "  OnTime: " -NoNewline -ForegroundColor White
        Write-Host ("{0,5} %" -f $s.OnTimeDelivery) -NoNewline -ForegroundColor $oc
        Write-Host ("  Cost: {0,5} DKK  CO2: {1,5} kg" -f $s.CostPerTrip, $s.CO2PerTrip) -NoNewline -ForegroundColor White
        if ($s.ActiveEvent -ne "None") {
            Write-Host ("  [{0}]" -f $s.ActiveEvent) -ForegroundColor Red
        } else {
            Write-Host ""
        }

        Start-Sleep -Milliseconds 150
    }

    Write-Host ""
    Write-Host "  [TMS Full] Day Replay complete — 48 episodes done." -ForegroundColor Cyan

    $avgEmpty  = [Math]::Round(($results | Measure-Object -Property EmptyDriving      -Average).Average, 1)
    $avgOnTime = [Math]::Round(($results | Measure-Object -Property OnTimeDelivery    -Average).Average, 1)
    $avgCost   = [Math]::Round(($results | Measure-Object -Property CostPerTrip       -Average).Average, 0)
    $avgCO2    = [Math]::Round(($results | Measure-Object -Property CO2PerTrip        -Average).Average, 1)
    $avgDriver = [Math]::Round(($results | Measure-Object -Property DriverPerformance -Average).Average, 1)
    $alerts    = ($results | Where-Object { $_.EmptyDriving -gt 40 -or $_.OnTimeDelivery -lt 70 -or $_.CostPerTrip -gt 2500 }).Count

    Write-Host ""
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |           Day Replay Summary                     |" -ForegroundColor Cyan
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ("  |  Avg Empty Driving    : {0,5} %                 |" -f $avgEmpty)  -ForegroundColor White
    Write-Host ("  |  Avg On-Time Delivery : {0,5} %                 |" -f $avgOnTime) -ForegroundColor White
    Write-Host ("  |  Avg Cost Per Trip    : {0,5} DKK               |" -f $avgCost)   -ForegroundColor White
    Write-Host ("  |  Avg CO2 Per Trip     : {0,5} kg                |" -f $avgCO2)    -ForegroundColor White
    Write-Host ("  |  Avg Driver Score     : {0,5} %                 |" -f $avgDriver) -ForegroundColor White
    Write-Host ("  |  Alert Episodes       : {0,5}                   |" -f $alerts)    -ForegroundColor Yellow
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    return $results
}

# ============================================================
# START-VBAFTMSFULLSCHEDULE
# ============================================================
function Start-VBAFTMSFullSchedule {
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
    Write-Host "  [TMS Full] Starting Schedule"                                -ForegroundColor Cyan
    Write-Host ("  Mode     : {0}" -f $Mode)                                  -ForegroundColor White
    Write-Host ("  Interval : {0} seconds" -f $intervalSeconds)               -ForegroundColor White
    Write-Host ("  MaxRuns  : {0}" -f $MaxRuns)                               -ForegroundColor White
    Write-Host "  Press Ctrl+C to stop."                                       -ForegroundColor Yellow
    Write-Host ""

    for ($run = 1; $run -le $MaxRuns; $run++) {
        Write-Host ("  [Run {0}/{1}]" -f $run, $MaxRuns) -ForegroundColor DarkCyan
        $snapshot = Show-VBAFTMSFullStatus
        if (($run % 6) -eq 0) {
            Invoke-VBAFTMSFullEvent -Event "Random" -Rounds 3
        }
        if ($run -lt $MaxRuns) {
            Write-Host ("  Next run in {0} seconds..." -f $intervalSeconds) -ForegroundColor DarkGray
            Start-Sleep -Seconds $intervalSeconds
        }
    }

    Write-Host ""
    Write-Host "  [TMS Full] Schedule complete." -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   VBAF-Center TMS Simulator Full  v1.0.0        |" -ForegroundColor Cyan
Write-Host "  |   10 Signals · 6 Events · 4 Modes               |" -ForegroundColor Cyan
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Signals : EmptyDriving · OnTimeDelivery · CostPerTrip"     -ForegroundColor White
Write-Host "            RouteEfficiency · ETAAccuracy · CO2PerTrip"       -ForegroundColor White
Write-Host "            PODCompletion · DriverPerformance"                 -ForegroundColor White
Write-Host "            FleetAvailability · CapacityUtil"                 -ForegroundColor White
Write-Host "  Events  : WeatherEvent · TrafficJam · VehicleBreakdown"     -ForegroundColor White
Write-Host "            DriverSickDay · HighDemandSurge · FuelPriceSpike" -ForegroundColor White
Write-Host "  Modes   : Shadow(30m) · GoLive(10m) · Autonomy(5m) · RealTime" -ForegroundColor White
Write-Host ""
Write-Host "  Quick start:"                                                                             -ForegroundColor Yellow
Write-Host "  Show-VBAFTMSFullStatus"                                                                   -ForegroundColor Green
Write-Host "  Invoke-VBAFTMSFullDayReplay -CustomerID 'TruckCompanyDK' -FireEvents"                      -ForegroundColor Green
Write-Host " Start-VBAFTMSFullSchedule   -CustomerID 'TruckCompanyDK' -Mode Shadow -MaxRuns 10" -ForegroundColor Green
Write-Host ""