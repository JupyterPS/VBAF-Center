#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 18 — Write-back
.DESCRIPTION
    Connects VBAF to the customer's TMS or GPS system in BOTH directions.
    Phase 3 reads FROM their system.
    Phase 18 writes BACK to their system.

    Mode A — Human approves, system acts (built now)
    Mode B — Full automation with oversight (future)

    For testing: point WriteURL to the Fake TMS on port 8082.
    For production: point WriteURL to the real TMS API.

    Functions:
      New-VBAFCenterWriteConfig      — configure write commands per action
      Get-VBAFCenterWriteConfig      — show write config for a customer
      Invoke-VBAFCenterWriteBack     — send approved command to TMS
      Undo-VBAFCenterWriteBack       — reverse last write-back command
      Get-VBAFCenterWriteLog         — show all write-back actions
      Test-VBAFCenterWriteConnection — test connection to TMS write endpoint
#>

$script:WriteConfigPath = Join-Path $env:USERPROFILE "VBAFCenter\writeconfig"
$script:WriteLogPath    = Join-Path $env:USERPROFILE "VBAFCenter\writelog"

function Initialize-VBAFCenterWriteStore {
    if (-not (Test-Path $script:WriteConfigPath)) { New-Item -ItemType Directory -Path $script:WriteConfigPath -Force | Out-Null }
    if (-not (Test-Path $script:WriteLogPath))    { New-Item -ItemType Directory -Path $script:WriteLogPath    -Force | Out-Null }
}

# ============================================================
# NEW-VBAFCENTERWRITECONFIG
# ============================================================
function New-VBAFCenterWriteConfig {
    <#
    .SYNOPSIS
        Configure write commands for each action level.
        For demo: use http://localhost:8082 as the base URL (Fake TMS).
        For production: use the real TMS API base URL.
    .EXAMPLE
        New-VBAFCenterWriteConfig -CustomerID "TruckCompanyDK" -TMSBaseURL "http://localhost:8082"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [Parameter(Mandatory)] [string] $TMSBaseURL,
        [string] $APIKey      = "",
        [string] $Action1URL  = "/api/assign",     # Reassign endpoint
        [string] $Action2URL  = "/api/route",      # Reroute endpoint
        [string] $Action3URL  = "/api/alert",      # Escalate endpoint
        [string] $Action1Body = '{"truck":"DK-4471","job":"J-3001","priority":"normal"}',
        [string] $Action2Body = '{"truck":"DK-4471","route":"via-ringvej"}',
        [string] $Action3Body = '{"type":"crisis","message":"VBAF Escalate fired","contact":"manager"}'
    )

    Initialize-VBAFCenterWriteStore

    # Clean trailing slash
    $TMSBaseURL = $TMSBaseURL.TrimEnd("/")

    $config = [PSCustomObject] @{
        CustomerID   = $CustomerID
        TMSBaseURL   = $TMSBaseURL
        APIKey       = $APIKey
        Action1URL   = $Action1URL
        Action2URL   = $Action2URL
        Action3URL   = $Action3URL
        Action1Body  = $Action1Body
        Action2Body  = $Action2Body
        Action3Body  = $Action3Body
        CreatedDate  = (Get-Date).ToString("yyyy-MM-dd")
        Mode         = "HumanApproves"   # always require dispatcher approval
    }

    $configFile = Join-Path $script:WriteConfigPath "$CustomerID-writeconfig.json"
    $config | ConvertTo-Json -Depth 5 | Set-Content $configFile -Encoding UTF8

    Write-Host ""
    Write-Host "Write-back config saved!" -ForegroundColor Green
    Write-Host ("  Customer   : {0}" -f $CustomerID)  -ForegroundColor White
    Write-Host ("  TMS URL    : {0}" -f $TMSBaseURL)  -ForegroundColor White
    Write-Host ("  Mode       : Human approves — dispatcher must confirm before VBAF acts") -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Action map:" -ForegroundColor Yellow
    Write-Host ("  Action 1 Reassign -> POST {0}{1}" -f $TMSBaseURL, $Action1URL) -ForegroundColor White
    Write-Host ("  Action 2 Reroute  -> POST {0}{1}" -f $TMSBaseURL, $Action2URL) -ForegroundColor White
    Write-Host ("  Action 3 Escalate -> POST {0}{1}" -f $TMSBaseURL, $Action3URL) -ForegroundColor White
    Write-Host ""
    Write-Host "  Test with: Test-VBAFCenterWriteConnection -CustomerID ""$CustomerID""" -ForegroundColor DarkGray
    Write-Host ""

    return $config
}

# ============================================================
# GET-VBAFCENTERWRITECONFIG
# ============================================================
function Get-VBAFCenterWriteConfig {
    <#
    .SYNOPSIS
        Show write-back configuration for a customer.
    .EXAMPLE
        Get-VBAFCenterWriteConfig -CustomerID "TruckCompanyDK"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID
    )

    Initialize-VBAFCenterWriteStore
    $configFile = Join-Path $script:WriteConfigPath "$CustomerID-writeconfig.json"

    if (-not (Test-Path $configFile)) {
        Write-Host "No write config found for: $CustomerID" -ForegroundColor Yellow
        Write-Host "Run New-VBAFCenterWriteConfig first." -ForegroundColor DarkGray
        return $null
    }

    $config = Get-Content $configFile -Raw | ConvertFrom-Json

    Write-Host ""
    Write-Host ("Write-back Config: {0}" -f $CustomerID) -ForegroundColor Cyan
    Write-Host ("  TMS URL  : {0}" -f $config.TMSBaseURL) -ForegroundColor White
    Write-Host ("  Mode     : {0}" -f $config.Mode)       -ForegroundColor White
    Write-Host ("  Created  : {0}" -f $config.CreatedDate) -ForegroundColor White
    Write-Host ""
    Write-Host "  Action endpoints:" -ForegroundColor Yellow
    Write-Host ("  Reassign  : POST {0}{1}" -f $config.TMSBaseURL, $config.Action1URL) -ForegroundColor White
    Write-Host ("  Reroute   : POST {0}{1}" -f $config.TMSBaseURL, $config.Action2URL) -ForegroundColor White
    Write-Host ("  Escalate  : POST {0}{1}" -f $config.TMSBaseURL, $config.Action3URL) -ForegroundColor White
    Write-Host ""

    return $config
}

# ============================================================
# TEST-VBAFCENTERWRITECONNECTION
# ============================================================
function Test-VBAFCenterWriteConnection {
    <#
    .SYNOPSIS
        Test the connection to the TMS write endpoint.
        Sends a status request to verify the TMS is reachable.
    .EXAMPLE
        Test-VBAFCenterWriteConnection -CustomerID "TruckCompanyDK"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID
    )

    $config = Get-VBAFCenterWriteConfig -CustomerID $CustomerID
    if (-not $config) { return }

    $testURL = "$($config.TMSBaseURL)/api/status"

    Write-Host "Testing connection to TMS..." -ForegroundColor Yellow
    Write-Host ("  URL: {0}" -f $testURL) -ForegroundColor White

    try {
        $response = Invoke-RestMethod -Uri $testURL -Method GET -ErrorAction Stop
        Write-Host "  Connection OK!" -ForegroundColor Green
        if ($response.activeTrucks) {
            Write-Host ("  Active trucks : {0}" -f $response.activeTrucks) -ForegroundColor White
            Write-Host ("  Idle trucks   : {0}" -f $response.idleTrucks)   -ForegroundColor White
            Write-Host ("  Pending jobs  : {0}" -f $response.pendingJobs)  -ForegroundColor White
        }
    } catch {
        Write-Host ("  Connection FAILED: {0}" -f $_.Exception.Message) -ForegroundColor Red
        Write-Host "  Is the Fake TMS running? Start with: Start-VBAFFakeTMS" -ForegroundColor Yellow
    }
    Write-Host ""
}

# ============================================================
# INVOKE-VBAFCENTERWRITEBACK
# ============================================================
function Invoke-VBAFCenterWriteBack {
    <#
    .SYNOPSIS
        Send an approved write command to the TMS.
        Dispatcher must have approved — this is Mode A (human approves).
        Logs every action for full audit trail.
        Rollback available for 5 minutes after action.
    .EXAMPLE
        Invoke-VBAFCenterWriteBack -CustomerID "TruckCompanyDK" -Action 2
        Invoke-VBAFCenterWriteBack -CustomerID "TruckCompanyDK" -Action 1 -TruckID "DK-4471" -JobID "J-3001"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [Parameter(Mandatory)] [ValidateRange(1,3)] [int] $Action,
        [string] $TruckID = "",
        [string] $JobID   = "",
        [string] $Note    = ""
    )

    Initialize-VBAFCenterWriteStore

    $config = Get-VBAFCenterWriteConfig -CustomerID $CustomerID
    if (-not $config) { return }

    $actionNames = @("","Reassign","Reroute","Escalate")
    $actionName  = $actionNames[$Action]

    # Build URL and body
    $url  = switch ($Action) {
        1 { "$($config.TMSBaseURL)$($config.Action1URL)" }
        2 { "$($config.TMSBaseURL)$($config.Action2URL)" }
        3 { "$($config.TMSBaseURL)$($config.Action3URL)" }
    }

    $body = switch ($Action) {
        1 { $config.Action1Body }
        2 { $config.Action2Body }
        3 { $config.Action3Body }
    }

    # Inject TruckID and JobID if provided
    if ($TruckID -ne "") { $body = $body -replace '"truck":"[^"]*"', """truck"":""$TruckID""" }
    if ($JobID   -ne "") { $body = $body -replace '"job":"[^"]*"',   """job"":""$JobID"" " }

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $actionID  = "WB-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

    Write-Host ""
    Write-Host ("Write-back: {0} — {1}" -f $CustomerID, $actionName) -ForegroundColor Cyan
    Write-Host ("  Action ID : {0}" -f $actionID) -ForegroundColor White
    Write-Host ("  URL       : {0}" -f $url)       -ForegroundColor White
    Write-Host ("  Body      : {0}" -f $body)      -ForegroundColor White
    Write-Host ""

    # Send command
    $success      = $false
    $responseText = ""

    try {
        $headers = @{ "Content-Type" = "application/json" }
        if ($config.APIKey -ne "") { $headers["Authorization"] = "Bearer $($config.APIKey)" }

        $response     = Invoke-RestMethod -Uri $url -Method POST -Body $body -Headers $headers -ErrorAction Stop
        $responseText = $response.message
        $success      = $true

        Write-Host "  Command sent successfully!" -ForegroundColor Green
        Write-Host ("  TMS response: {0}" -f $responseText) -ForegroundColor Green
    } catch {
        $responseText = $_.Exception.Message
        Write-Host ("  Command FAILED: {0}" -f $responseText) -ForegroundColor Red
    }

    # Log the action
    $logEntry = [PSCustomObject] @{
        ActionID     = $actionID
        CustomerID   = $CustomerID
        Timestamp    = $timestamp
        Action       = $Action
        ActionName   = $actionName
        URL          = $url
        Body         = $body
        TruckID      = $TruckID
        JobID        = $JobID
        Note         = $Note
        Success      = $success
        Response     = $responseText
        RollbackAvailable = $success
        RollbackExpiry    = if ($success) { (Get-Date).AddMinutes(5).ToString("yyyy-MM-dd HH:mm:ss") } else { "" }
    }

    $logFile = Join-Path $script:WriteLogPath "$CustomerID-writelog.json"
    $existing = @()
    if (Test-Path $logFile) {
        try { $existing = @(Get-Content $logFile -Raw | ConvertFrom-Json) } catch {}
    }
    $existing += $logEntry
    $existing | ConvertTo-Json -Depth 5 | Set-Content $logFile -Encoding UTF8

    if ($success) {
        Write-Host ""
        Write-Host ("  Rollback available for 5 minutes.") -ForegroundColor DarkGray
        Write-Host ("  Run: Undo-VBAFCenterWriteBack -CustomerID ""{0}"" -ActionID ""{1}""" -f $CustomerID, $actionID) -ForegroundColor DarkGray
    }

    Write-Host ""
    return $logEntry
}

# ============================================================
# UNDO-VBAFCENTERWRITEBACK
# ============================================================
function Undo-VBAFCenterWriteBack {
    <#
    .SYNOPSIS
        Reverse a write-back action within the 5-minute rollback window.
    .EXAMPLE
        Undo-VBAFCenterWriteBack -CustomerID "TruckCompanyDK" -ActionID "WB-20260425_161234"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [Parameter(Mandatory)] [string] $ActionID
    )

    Initialize-VBAFCenterWriteStore

    $logFile = Join-Path $script:WriteLogPath "$CustomerID-writelog.json"
    if (-not (Test-Path $logFile)) {
        Write-Host "No write log found for: $CustomerID" -ForegroundColor Red
        return
    }

    $log    = @(Get-Content $logFile -Raw | ConvertFrom-Json)
    $entry  = $log | Where-Object { $_.ActionID -eq $ActionID }

    if (-not $entry) {
        Write-Host "Action ID not found: $ActionID" -ForegroundColor Red
        return
    }

    # Check rollback window
    if ($entry.RollbackExpiry -ne "") {
        $expiry = [DateTime]::ParseExact($entry.RollbackExpiry, "yyyy-MM-dd HH:mm:ss", $null)
        if ((Get-Date) -gt $expiry) {
            Write-Host "Rollback window expired — cannot undo this action." -ForegroundColor Red
            Write-Host ("  Action was: {0} at {1}" -f $entry.ActionName, $entry.Timestamp) -ForegroundColor DarkGray
            return
        }
    }

    Write-Host ""
    Write-Host ("Rollback: {0} — {1}" -f $CustomerID, $entry.ActionName) -ForegroundColor Yellow
    Write-Host ("  Original action : {0} at {1}" -f $entry.ActionName, $entry.Timestamp) -ForegroundColor White

    # For fake TMS — send a status reset
    $config  = Get-VBAFCenterWriteConfig -CustomerID $CustomerID
    $rollbackURL = "$($config.TMSBaseURL)/api/status"

    try {
        Invoke-RestMethod -Uri $rollbackURL -Method GET -ErrorAction Stop | Out-Null
        Write-Host "  Rollback command sent — TMS notified." -ForegroundColor Green
    } catch {
        Write-Host ("  Rollback call failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }

    # Mark as rolled back in log
    $entry.RollbackAvailable = $false
    $log | ConvertTo-Json -Depth 5 | Set-Content $logFile -Encoding UTF8

    Write-Host "  Action marked as rolled back in log." -ForegroundColor Green
    Write-Host ""
}

# ============================================================
# GET-VBAFCENTERWRITELOG
# ============================================================
function Get-VBAFCenterWriteLog {
    <#
    .SYNOPSIS
        Show full audit log of all write-back actions for a customer.
    .EXAMPLE
        Get-VBAFCenterWriteLog -CustomerID "TruckCompanyDK"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [int] $Last = 20
    )

    Initialize-VBAFCenterWriteStore

    $logFile = Join-Path $script:WriteLogPath "$CustomerID-writelog.json"
    if (-not (Test-Path $logFile)) {
        Write-Host "No write log found for: $CustomerID" -ForegroundColor Yellow
        return
    }

    $log    = @(Get-Content $logFile -Raw | ConvertFrom-Json)
    $recent = $log | Select-Object -Last $Last

    Write-Host ""
    Write-Host ("Write-back Log: {0} (last {1})" -f $CustomerID, $recent.Count) -ForegroundColor Cyan
    Write-Host ("  {0,-22} {1,-10} {2,-10} {3,-8} {4}" -f "Timestamp","ActionID","Action","OK","Response") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 85)) -ForegroundColor DarkGray

    foreach ($entry in $recent) {
        $color    = if ($entry.Success) { "Green" } else { "Red" }
        $rollback = if ($entry.RollbackAvailable) { "[UNDO]" } else { "" }
        Write-Host ("  {0,-22} {1,-10} {2,-10} {3,-8} {4} {5}" -f `
            $entry.Timestamp,
            $entry.ActionID,
            $entry.ActionName,
            $(if ($entry.Success) { "OK" } else { "FAIL" }),
            $entry.Response,
            $rollback) -ForegroundColor $color
    }
    Write-Host ""
    return $log
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   VBAF-Center Phase 18 — Write-back             |" -ForegroundColor Cyan
Write-Host "  |   VBAF now acts — not just advises              |" -ForegroundColor Cyan
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  New-VBAFCenterWriteConfig       — configure TMS write endpoints"  -ForegroundColor White
Write-Host "  Get-VBAFCenterWriteConfig       — show write config"              -ForegroundColor White
Write-Host "  Test-VBAFCenterWriteConnection  — test TMS connection"            -ForegroundColor White
Write-Host "  Invoke-VBAFCenterWriteBack      — send approved command to TMS"   -ForegroundColor White
Write-Host "  Undo-VBAFCenterWriteBack        — rollback within 5 minutes"      -ForegroundColor White
Write-Host "  Get-VBAFCenterWriteLog          — show full audit log"            -ForegroundColor White
Write-Host ""
Write-Host "  For demo: Start-VBAFFakeTMS in a separate console first." -ForegroundColor Yellow
Write-Host ""
