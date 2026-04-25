#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center — Fake TMS Server
.DESCRIPTION
    Simulates a real Transport Management System that accepts
    write commands from VBAF-Center Phase 18 Write-back.

    Runs as a local HTTP server on port 8082.
    Accepts POST commands and returns realistic responses.
    Logs every command received with timestamp.

    When a real customer gives API write access — replace the
    fake URL with their real URL. Everything else stays the same.

    Functions:
      Start-VBAFFakeTMS     — start the fake TMS server
      Stop-VBAFFakeTMS      — stop the fake TMS server
      Get-VBAFFakeTMSLog    — show all commands received
      Clear-VBAFFakeTMSLog  — reset the log
#>

$script:FakeTMSListener = $null
$script:FakeTMSRunning  = $false
$script:FakeTMSPort     = 8082
$script:FakeTMSLogPath  = Join-Path $env:USERPROFILE "VBAFCenter\faketms"
$script:FakeTMSLog      = @()

# Fake fleet state — trucks and jobs
$script:FakeTMSFleet = @(
    [PSCustomObject]@{ TruckID="DK-4471"; Driver="Lars Nielsen";    Status="Idle";   Location="Roskilde";   Job="" }
    [PSCustomObject]@{ TruckID="DK-3892"; Driver="Mette Andersen";  Status="Active"; Location="Copenhagen"; Job="J-2847" }
    [PSCustomObject]@{ TruckID="DK-5511"; Driver="Søren Pedersen";  Status="Active"; Location="Odense";     Job="J-2901" }
    [PSCustomObject]@{ TruckID="DK-2244"; Driver="Hanne Christensen";Status="Idle";  Location="Aarhus";     Job="" }
    [PSCustomObject]@{ TruckID="DK-7731"; Driver="Peter Jensen";    Status="Active"; Location="Aalborg";    Job="J-2955" }
)

$script:FakeTMSJobs = @(
    [PSCustomObject]@{ JobID="J-2847"; Customer="Netto Lager";    From="Copenhagen"; To="Roskilde";  Status="InProgress"; ETA="14:23" }
    [PSCustomObject]@{ JobID="J-2901"; Customer="Coop DC";        From="Odense";     To="Svendborg"; Status="InProgress"; ETA="15:10" }
    [PSCustomObject]@{ JobID="J-2955"; Customer="Arla Foods";     From="Aalborg";    To="Viborg";    Status="InProgress"; ETA="13:45" }
    [PSCustomObject]@{ JobID="J-3001"; Customer="PostNord";       From="Roskilde";   To="Køge";      Status="Pending";    ETA="16:00" }
    [PSCustomObject]@{ JobID="J-3002"; Customer="Lidl DC";        From="Aarhus";     To="Silkeborg"; Status="Pending";    ETA="17:30" }
)

function Initialize-VBAFFakeTMSStore {
    if (-not (Test-Path $script:FakeTMSLogPath)) {
        New-Item -ItemType Directory -Path $script:FakeTMSLogPath -Force | Out-Null
    }
}

# ============================================================
# PROCESS INCOMING COMMAND
# ============================================================
function Invoke-VBAFFakeTMSCommand {
    param(
        [string] $Endpoint,
        [string] $Body
    )

    $timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $actionNames = @{
        "/api/assign" = "Assign truck to job"
        "/api/route"  = "Reroute truck"
        "/api/alert"  = "Send alert"
        "/api/status" = "Get fleet status"
        "/api/fleet"  = "Get fleet list"
        "/api/jobs"   = "Get job list"
    }

    $actionName = if ($actionNames.ContainsKey($Endpoint)) { $actionNames[$Endpoint] } else { "Unknown command" }

    # Parse body if JSON
    $params = @{}
    try {
        if ($Body -and $Body -ne "") {
            $parsed = $Body | ConvertFrom-Json
            $parsed.PSObject.Properties | ForEach-Object { $params[$_.Name] = $_.Value }
        }
    } catch {}

    # Build response based on endpoint
    $response = switch ($Endpoint) {

        "/api/assign" {
            $truckID = if ($params.truck) { $params.truck } else { "DK-4471" }
            $jobID   = if ($params.job)   { $params.job   } else { "J-3001"  }

            # Update fake fleet state
            $truck = $script:FakeTMSFleet | Where-Object { $_.TruckID -eq $truckID }
            $job   = $script:FakeTMSJobs  | Where-Object { $_.JobID   -eq $jobID   }

            if ($truck) { $truck.Status = "Active"; $truck.Job = $jobID }
            if ($job)   { $job.Status = "Assigned" }

            $eta = (Get-Date).AddMinutes((Get-Random -Minimum 15 -Maximum 60)).ToString("HH:mm")

            [PSCustomObject]@{
                success  = $true
                command  = "assign"
                truck    = $truckID
                job      = $jobID
                eta      = $eta
                message  = "Truck $truckID assigned to job $jobID. ETA $eta."
                timestamp = $timestamp
            }
        }

        "/api/route" {
            $truckID = if ($params.truck) { $params.truck } else { "DK-4471" }
            $route   = if ($params.route) { $params.route } else { "via-ringvej" }

            $eta = (Get-Date).AddMinutes((Get-Random -Minimum 10 -Maximum 45)).ToString("HH:mm")

            [PSCustomObject]@{
                success   = $true
                command   = "route"
                truck     = $truckID
                route     = $route
                eta       = $eta
                distance  = (Get-Random -Minimum 15 -Maximum 80)
                message   = "Truck $truckID rerouted via $route. New ETA $eta."
                timestamp = $timestamp
            }
        }

        "/api/alert" {
            $alertType = if ($params.type)    { $params.type    } else { "warning" }
            $message   = if ($params.message) { $params.message } else { "VBAF alert" }
            $contact   = if ($params.contact) { $params.contact } else { "dispatcher" }

            [PSCustomObject]@{
                success   = $true
                command   = "alert"
                type      = $alertType
                message   = $message
                contact   = $contact
                notified  = $true
                result    = ("Alert sent to {0} - {1}" -f $contact, $message)
                timestamp = $timestamp
            }
        }

        "/api/status" {
            [PSCustomObject]@{
                success      = $true
                command      = "status"
                fleet        = $script:FakeTMSFleet
                activeTrucks = @($script:FakeTMSFleet | Where-Object { $_.Status -eq "Active" }).Count
                idleTrucks   = @($script:FakeTMSFleet | Where-Object { $_.Status -eq "Idle"   }).Count
                pendingJobs  = @($script:FakeTMSJobs  | Where-Object { $_.Status -eq "Pending" }).Count
                timestamp    = $timestamp
            }
        }

        "/api/fleet" {
            [PSCustomObject]@{
                success = $true
                command = "fleet"
                trucks  = $script:FakeTMSFleet
                count   = $script:FakeTMSFleet.Count
                timestamp = $timestamp
            }
        }

        "/api/jobs" {
            [PSCustomObject]@{
                success = $true
                command = "jobs"
                jobs    = $script:FakeTMSJobs
                count   = $script:FakeTMSJobs.Count
                timestamp = $timestamp
            }
        }

        default {
            [PSCustomObject]@{
                success   = $false
                command   = "unknown"
                endpoint  = $Endpoint
                message   = "Unknown endpoint. Available: /api/assign /api/route /api/alert /api/status /api/fleet /api/jobs"
                timestamp = $timestamp
            }
        }
    }

    # Log the command
    $logEntry = [PSCustomObject]@{
        Timestamp  = $timestamp
        Endpoint   = $Endpoint
        Action     = $actionName
        Parameters = ($params.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " | "
        Success    = $response.success
        Response   = $response.message
    }

    $script:FakeTMSLog += $logEntry

    # Save log to file
    Initialize-VBAFFakeTMSStore
    $logFile = Join-Path $script:FakeTMSLogPath "faketms-log.json"
    $script:FakeTMSLog | ConvertTo-Json -Depth 5 | Set-Content $logFile -Encoding UTF8

    # Console output
    $color = if ($response.success) { "Green" } else { "Red" }
    Write-Host ("")
    Write-Host ("  [{0}] {1}" -f $timestamp, $actionName) -ForegroundColor $color
    if ($params.Count -gt 0) {
        Write-Host ("  Params : {0}" -f $logEntry.Parameters) -ForegroundColor White
    }
    Write-Host ("  Result : {0}" -f $response.message) -ForegroundColor $color
    Write-Host ("")

    return $response
}

# ============================================================
# START-VBAFFAKETMS
# ============================================================
function Start-VBAFFakeTMS {
    param([int] $Port = 8082)

    if ($script:FakeTMSRunning) {
        Write-Host "Fake TMS already running at http://localhost:$script:FakeTMSPort" -ForegroundColor Yellow
        return
    }

    $script:FakeTMSPort    = $Port
    $script:FakeTMSRunning = $true
    $script:FakeTMSLog     = @()

    Write-Host ""
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   VBAF Fake TMS Server                           |" -ForegroundColor Cyan
    Write-Host "  |   Simulates a real Transport Management System   |" -ForegroundColor Cyan
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ("  URL  : http://localhost:{0}" -f $Port) -ForegroundColor White
    Write-Host ""
    Write-Host "  Available endpoints:" -ForegroundColor Yellow
    Write-Host "  POST http://localhost:$Port/api/assign   — assign truck to job" -ForegroundColor White
    Write-Host "  POST http://localhost:$Port/api/route    — reroute truck"       -ForegroundColor White
    Write-Host "  POST http://localhost:$Port/api/alert    — send alert"          -ForegroundColor White
    Write-Host "  GET  http://localhost:$Port/api/status   — fleet status"        -ForegroundColor White
    Write-Host "  GET  http://localhost:$Port/api/fleet    — list all trucks"     -ForegroundColor White
    Write-Host "  GET  http://localhost:$Port/api/jobs     — list all jobs"       -ForegroundColor White
    Write-Host ""
    Write-Host "  Fleet loaded: $($script:FakeTMSFleet.Count) trucks, $($script:FakeTMSJobs.Count) jobs" -ForegroundColor Green
    Write-Host "  Waiting for commands from VBAF Write-back..." -ForegroundColor DarkGray
    Write-Host "  Press Ctrl+C to stop." -ForegroundColor DarkGray
    Write-Host ""

    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Start()
    $script:FakeTMSListener = $listener

    try {
        while ($script:FakeTMSRunning) {
            $context  = $listener.GetContext()
            $request  = $context.Request
            $response = $context.Response

            $endpoint = $request.Url.AbsolutePath
            $method   = $request.HttpMethod

            # Read body
            $body = ""
            if ($request.HasEntityBody) {
                $reader = [System.IO.StreamReader]::new($request.InputStream)
                $body   = $reader.ReadToEnd()
                $reader.Close()
            }

            # Process command
            $result     = Invoke-VBAFFakeTMSCommand -Endpoint $endpoint -Body $body
            $jsonResult = $result | ConvertTo-Json -Depth 5

            # Send response
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($jsonResult)
            $response.ContentType     = "application/json; charset=utf-8"
            $response.ContentLength64 = $buffer.Length
            $response.StatusCode      = if ($result.success) { 200 } else { 400 }
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        }
    }
    finally {
        $listener.Stop()
        $script:FakeTMSRunning = $false
        Write-Host "  Fake TMS stopped." -ForegroundColor Yellow
    }
}

# ============================================================
# STOP-VBAFFAKETMS
# ============================================================
function Stop-VBAFFakeTMS {
    $script:FakeTMSRunning = $false
    if ($script:FakeTMSListener) {
        $script:FakeTMSListener.Stop()
        Write-Host "Fake TMS stopped." -ForegroundColor Yellow
    }
}

# ============================================================
# GET-VBAFFAKETMSLOG
# ============================================================
function Get-VBAFFakeTMSLog {
    param([int] $Last = 20)

    Initialize-VBAFFakeTMSStore
    $logFile = Join-Path $script:FakeTMSLogPath "faketms-log.json"

    $log = @()
    if (Test-Path $logFile) {
        try { $log = @(Get-Content $logFile -Raw | ConvertFrom-Json) } catch {}
    }

    if ($log.Count -eq 0 -and $script:FakeTMSLog.Count -gt 0) {
        $log = $script:FakeTMSLog
    }

    if ($log.Count -eq 0) {
        Write-Host "No commands received yet." -ForegroundColor Yellow
        return
    }

    $recent = $log | Select-Object -Last $Last

    Write-Host ""
    Write-Host "Fake TMS Command Log (last $($recent.Count)):" -ForegroundColor Cyan
    Write-Host ("  {0,-22} {1,-15} {2,-30} {3}" -f "Timestamp","Action","Parameters","Result") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 90)) -ForegroundColor DarkGray

    foreach ($entry in $recent) {
        $color = if ($entry.Success) { "Green" } else { "Red" }
        Write-Host ("  {0,-22} {1,-15} {2,-30} {3}" -f `
            $entry.Timestamp,
            $entry.Action,
            $entry.Parameters,
            $entry.Response) -ForegroundColor $color
    }
    Write-Host ""
    return $log
}

# ============================================================
# CLEAR-VBAFFAKETMSLOG
# ============================================================
function Clear-VBAFFakeTMSLog {
    $script:FakeTMSLog = @()
    $logFile = Join-Path $script:FakeTMSLogPath "faketms-log.json"
    if (Test-Path $logFile) { Remove-Item $logFile -Force }
    Write-Host "Fake TMS log cleared." -ForegroundColor Green
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   VBAF Fake TMS Server loaded                    |" -ForegroundColor Cyan
Write-Host "  |   Simulates a real TMS for Write-back testing    |" -ForegroundColor Cyan
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Start-VBAFFakeTMS      — start fake TMS on port 8082" -ForegroundColor White
Write-Host "  Stop-VBAFFakeTMS       — stop fake TMS"               -ForegroundColor White
Write-Host "  Get-VBAFFakeTMSLog     — show received commands"      -ForegroundColor White
Write-Host "  Clear-VBAFFakeTMSLog   — reset the log"               -ForegroundColor White
Write-Host ""
Write-Host "  Fleet: $($script:FakeTMSFleet.Count) trucks ready" -ForegroundColor Green
Write-Host "  Jobs : $($script:FakeTMSJobs.Count) jobs ready"    -ForegroundColor Green
Write-Host ""
