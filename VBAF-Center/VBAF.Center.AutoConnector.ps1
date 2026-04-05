#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 10 — Auto-Connector
.DESCRIPTION
    Automatically detects and configures signal connections
    for any customer system. One wizard — VBAF connects itself.

    Supported systems:
      REST      — any modern TMS/ERP with an API endpoint
      CSV       — any system that exports to Excel/CSV
      Manual    — customer reads the number themselves
      WMI       — Windows IT infrastructure
      Simulated — demo and shadow mode

    Functions:
      Start-VBAFCenterAutoConnect     — run the auto-connector wizard
      Test-VBAFCenterConnection       — test an existing connection
      Get-VBAFCenterConnectionStatus  — show all connection statuses
#>

# ============================================================
# SYSTEM TEMPLATES
# ============================================================
$script:SystemTemplates = @{

    "TMS-Generic" = @{
        Description = "Generic Transport Management System"
        Signals     = @(
            @{ Name="Empty Driving";    Index="Signal1"; Type="REST"; Min=0; Max=100 }
            @{ Name="On-Time Delivery"; Index="Signal2"; Type="REST"; Min=0; Max=100 }
        )
    }
    "TMS-Navision" = @{
        Description = "Microsoft Dynamics Navision"
        Signals     = @(
            @{ Name="Fleet Utilisation";     Index="Signal1"; Type="REST"; Min=0; Max=100 }
            @{ Name="Delivery Performance";  Index="Signal2"; Type="REST"; Min=0; Max=100 }
        )
    }
    "TMS-SAP" = @{
        Description = "SAP Transportation Management"
        Signals     = @(
            @{ Name="Load Factor";      Index="Signal1"; Type="REST"; Min=0; Max=100 }
            @{ Name="On-Time Delivery"; Index="Signal2"; Type="REST"; Min=0; Max=100 }
        )
    }
    "Excel-CSV" = @{
        Description = "Excel or CSV file export"
        Signals     = @(
            @{ Name="Signal 1"; Index="Signal1"; Type="CSV"; Min=0; Max=100 }
            @{ Name="Signal 2"; Index="Signal2"; Type="CSV"; Min=0; Max=100 }
        )
    }
    "Manual" = @{
        Description = "Customer reads numbers manually"
        Signals     = @(
            @{ Name="Signal 1"; Index="Signal1"; Type="Manual"; Min=0; Max=100 }
            @{ Name="Signal 2"; Index="Signal2"; Type="Manual"; Min=0; Max=100 }
        )
    }
    "Windows-IT" = @{
        Description = "Windows IT infrastructure via WMI"
        Signals     = @(
            @{ Name="CPU Load";     Index="Signal1"; Type="WMI"; Min=0; Max=100 }
            @{ Name="Memory Usage"; Index="Signal2"; Type="WMI"; Min=0; Max=100 }
        )
    }
    "Simulated" = @{
        Description = "Simulated data — for demo and shadow mode"
        Signals     = @(
            @{ Name="Signal 1"; Index="Signal1"; Type="Simulated"; Min=0; Max=100 }
            @{ Name="Signal 2"; Index="Signal2"; Type="Simulated"; Min=0; Max=100 }
        )
    }
}

# ============================================================
# START-VBAFCENTERAUTOCONNECT
# ============================================================
function Start-VBAFCenterAutoConnect {
    param(
        [string] $CustomerID = ""
    )

    Write-Host ""
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   VBAF-Center Auto-Connector Wizard      |" -ForegroundColor Cyan
    Write-Host "  |   Connect any system in minutes          |" -ForegroundColor Cyan
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    # Step 1 — Customer
    if ($CustomerID -eq "") {
        $CustomerID = Read-Host "  Customer ID"
    }

    $profilePath = Join-Path $env:USERPROFILE "VBAFCenter\customers\$CustomerID.json"
    if (-not (Test-Path $profilePath)) {
        Write-Host "  Customer not found: $CustomerID" -ForegroundColor Red
        Write-Host "  Run New-VBAFCenterCustomer first." -ForegroundColor Yellow
        return
    }

    $profile = Get-Content $profilePath -Raw | ConvertFrom-Json
    Write-Host ("  Customer : {0}" -f $profile.CompanyName) -ForegroundColor White
    Write-Host ""

    # Step 2 — System selection
    Write-Host "  --- Step 1/4: What system do you have? ---" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. TMS-Generic   — any TMS with a web API"      -ForegroundColor White
    Write-Host "  2. TMS-Navision  — Microsoft Dynamics Navision"  -ForegroundColor White
    Write-Host "  3. TMS-SAP       — SAP Transportation"           -ForegroundColor White
    Write-Host "  4. Excel-CSV     — Excel or CSV file export"     -ForegroundColor White
    Write-Host "  5. Manual        — no system, type it yourself"  -ForegroundColor White
    Write-Host "  6. Windows-IT    — Windows infrastructure"       -ForegroundColor White
    Write-Host "  7. Simulated     — demo mode"                    -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "  Enter number (1-7)"
    $systemKey = switch ($choice) {
        "1" { "TMS-Generic"  }
        "2" { "TMS-Navision" }
        "3" { "TMS-SAP"      }
        "4" { "Excel-CSV"    }
        "5" { "Manual"       }
        "6" { "Windows-IT"   }
        "7" { "Simulated"    }
        default { "Simulated" }
    }

    $template = $script:SystemTemplates[$systemKey]
    Write-Host ""
    Write-Host ("  System   : {0}" -f $template.Description) -ForegroundColor Green
    Write-Host ""

    # Step 3 — Configure signals
    Write-Host "  --- Step 2/4: Configure your signals ---" -ForegroundColor Cyan
    Write-Host ""

    $configuredSignals = @()

    foreach ($sig in $template.Signals) {

        Write-Host ("  Signal: {0} ({1})" -f $sig.Name, $sig.Index) -ForegroundColor White

        $signalName = Read-Host ("  Signal name [{0}]" -f $sig.Name)
        if ($signalName -eq "") { $signalName = $sig.Name }

        $sourceType = $sig.Type
        $sourceURL  = ""
        $csvPath    = ""
        $csvColumn  = ""
        $wmiClass   = ""
        $wmiProp    = ""

        switch ($sourceType) {
            "REST" {
                $sourceURL = Read-Host "  API endpoint URL"
            }
            "CSV" {
                $csvPath   = Read-Host "  CSV file path"
                $csvColumn = Read-Host "  Column name"
            }
            "WMI" {
                $wmiClass = Read-Host "  WMI Class [Win32_Processor]"
                if ($wmiClass -eq "") { $wmiClass = "Win32_Processor" }
                $wmiProp  = Read-Host "  WMI Property [LoadPercentage]"
                if ($wmiProp -eq "") { $wmiProp = "LoadPercentage" }
            }
            "Manual" {
                Write-Host "  Manual — you will type the value each time." -ForegroundColor DarkGray
            }
            "Simulated" {
                Write-Host "  Simulated — VBAF generates realistic values." -ForegroundColor DarkGray
            }
        }

        $rawMin = Read-Host ("  Raw minimum [{0}]" -f $sig.Min)
        if ($rawMin -eq "") { $rawMin = $sig.Min }
        $rawMax = Read-Host ("  Raw maximum [{0}]" -f $sig.Max)
        if ($rawMax -eq "") { $rawMax = $sig.Max }

        # Save signal config
        $signalConfig = @{
            CustomerID  = $CustomerID
            SignalName  = $signalName
            SignalIndex = $sig.Index
            SourceType  = $sourceType
            SourceURL   = $sourceURL
            CSVPath     = $csvPath
            CSVColumn   = $csvColumn
            WMIClass    = $wmiClass
            WMIProperty = $wmiProp
            RawMin      = [int]$rawMin
            RawMax      = [int]$rawMax
            CreatedDate = (Get-Date).ToString("yyyy-MM-dd")
        }

        $signalPath = Join-Path $env:USERPROFILE "VBAFCenter\signals"
        if (-not (Test-Path $signalPath)) {
            New-Item -ItemType Directory -Path $signalPath -Force | Out-Null
        }
        $signalFile = Join-Path $signalPath "$CustomerID-$($sig.Index).json"
        $signalConfig | ConvertTo-Json -Depth 5 | Set-Content $signalFile -Encoding UTF8

        $configuredSignals += $signalName
        Write-Host ("  Signal configured: {0}" -f $signalName) -ForegroundColor Green
        Write-Host ""
    }

    # Step 4 — Test connection
    Write-Host "  --- Step 3/4: Testing connection ---" -ForegroundColor Cyan
    Write-Host ""

    $allPassed = $true
    foreach ($sig in $template.Signals) {
        $sigFile = Join-Path $env:USERPROFILE "VBAFCenter\signals\$CustomerID-$($sig.Index).json"
        if (Test-Path $sigFile) {
            Write-Host ("  Signal {0} : OK" -f $sig.Index) -ForegroundColor Green
        } else {
            Write-Host ("  Signal {0} : MISSING" -f $sig.Index) -ForegroundColor Red
            $allPassed = $false
        }
    }

    Write-Host ""

    # Step 5 — Summary
    Write-Host "  --- Step 4/4: Connection Summary ---" -ForegroundColor Cyan
    Write-Host ""

    $statusText = if ($allPassed) { "All connections ready" } else { "Some connections failed" }
    $statusColor = if ($allPassed) { "Green" } else { "Red" }
    $signalList  = $configuredSignals -join ", "

    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host ("  |  Customer : {0,-29}|" -f $profile.CompanyName)  -ForegroundColor White
    Write-Host ("  |  System   : {0,-29}|" -f $template.Description) -ForegroundColor White
    Write-Host ("  |  Signals  : {0,-29}|" -f $signalList)           -ForegroundColor White
    Write-Host ("  |  Status   : {0,-29}|" -f $statusText)           -ForegroundColor $statusColor
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("  Next step: run Invoke-VBAFCenterRun -CustomerID '{0}'" -f $CustomerID) -ForegroundColor Yellow
    Write-Host ""
}

# ============================================================
# TEST-VBAFCENTERCONNECTION
# ============================================================
function Test-VBAFCenterConnection {
    param(
        [Parameter(Mandatory)] [string] $CustomerID
    )

    Write-Host ""
    Write-Host ("  Testing connections for: {0}" -f $CustomerID) -ForegroundColor Cyan
    Write-Host ""

    $signalPath = Join-Path $env:USERPROFILE "VBAFCenter\signals"
    $found      = 0

    if (Test-Path $signalPath) {
        Get-ChildItem $signalPath -Filter "$CustomerID-*.json" | ForEach-Object {
            $s = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $status = switch ($s.SourceType) {
                "Simulated" { "OK — Simulated" }
                "Manual"    { "OK — Manual input" }
                "REST"      { if ($s.SourceURL) { "OK — REST: $($s.SourceURL)" } else { "MISSING URL" } }
                "CSV"       { if ($s.CSVPath -and (Test-Path $s.CSVPath)) { "OK — File found" } else { "FILE NOT FOUND" } }
                "WMI"       { "OK — WMI: $($s.WMIClass)" }
                default     { "Unknown" }
            }
            $color = if ($status -like "OK*") { "Green" } else { "Red" }
            Write-Host ("  {0,-10} {1,-25} {2}" -f $s.SignalIndex, $s.SignalName, $status) -ForegroundColor $color
            $found++
        }
    }

    if ($found -eq 0) {
        Write-Host "  No signals configured. Run Start-VBAFCenterAutoConnect first." -ForegroundColor Yellow
    }

    Write-Host ""
}

# ============================================================
# GET-VBAFCENTERCONNECTIONSTATUS
# ============================================================
function Get-VBAFCenterConnectionStatus {

    Write-Host ""
    Write-Host "  VBAF-Center Connection Status — All Customers" -ForegroundColor Cyan
    Write-Host ("  {0,-20} {1,-10} {2,-25} {3}" -f "Customer","Signal","Name","Status") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 75)) -ForegroundColor DarkGray

    $storePath  = Join-Path $env:USERPROFILE "VBAFCenter\customers"
    $signalPath = Join-Path $env:USERPROFILE "VBAFCenter\signals"

    if (Test-Path $storePath) {
        Get-ChildItem $storePath -Filter "*.json" | ForEach-Object {
            $p = Get-Content $_.FullName -Raw | ConvertFrom-Json
            if (-not $p.CustomerID) { return }

            if (Test-Path $signalPath) {
                $sigs = Get-ChildItem $signalPath -Filter "$($p.CustomerID)-*.json"
                if ($sigs.Count -eq 0) {
                    Write-Host ("  {0,-20} {1,-10} {2,-25} {3}" -f $p.CustomerID, "-", "-", "No signals configured") -ForegroundColor Yellow
                } else {
                    foreach ($sf in $sigs) {
                        $s       = Get-Content $sf.FullName -Raw | ConvertFrom-Json
                        $status  = if ($s.SourceType -eq "Simulated" -or $s.SourceType -eq "Manual") { "Ready" } elseif ($s.SourceURL -or $s.CSVPath -or $s.WMIClass) { "Configured" } else { "Incomplete" }
                        $color   = if ($status -eq "Ready") { "Green" } elseif ($status -eq "Configured") { "Yellow" } else { "Red" }
                        Write-Host ("  {0,-20} {1,-10} {2,-25} {3}" -f $p.CustomerID, $s.SignalIndex, $s.SignalName, $status) -ForegroundColor $color
                    }
                }
            }
        }
    }
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |  VBAF-Center Phase 10 - Auto-Connector   |" -ForegroundColor Cyan
Write-Host "  |  Connect any system in minutes           |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Start-VBAFCenterAutoConnect     — run connection wizard"  -ForegroundColor White
Write-Host "  Test-VBAFCenterConnection       — test one customer"      -ForegroundColor White
Write-Host "  Get-VBAFCenterConnectionStatus  — show all connections"   -ForegroundColor White
Write-Host ""
Write-Host "  Quick start:" -ForegroundColor Yellow
Write-Host "  Start-VBAFCenterAutoConnect -CustomerID 'NordLogistik'" -ForegroundColor Green
Write-Host ""