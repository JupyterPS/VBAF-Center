#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center GPS Inspector
.DESCRIPTION
    Connects to any GPS fleet management system and automatically
    configures VBAF signals from live fleet data.

    Supported GPS systems:
      1. Webfleet (TomTom WEBFLEET.connect)
      2. Geotab
      3. Trackunit
      4. Keatech
      5. Generic REST API (any other system)

    Functions:
      Start-VBAFCenterGPSInspector — guided GPS connection wizard
#>

# ============================================================
# GPS SYSTEM DEFINITIONS
# ============================================================
$script:GPSSystems = @(
    @{
        ID          = "Webfleet"
        Name        = "Webfleet (TomTom)"
        Danish      = "Webfleet — mest brugte internationalt"
        AuthFields  = @("Account","Username","Password","APIKey")
        BuildURL    = {
            param($auth, $action)
            "https://csv.webfleet.com/extern?account=$($auth.Account)&username=$($auth.Username)&password=$($auth.Password)&apikey=$($auth.APIKey)&lang=en&outputformat=json&action=$action"
        }
        Signals     = @(
            @{ Name="Tom kørsel %";        Action="showVehicleReportExtern"; Field="totalstandbytime_h";    Calc="EmptyPct";  RawMin=0; RawMax=100; Unit="%" }
            @{ Name="Til tiden %";         Action="showOrderReportExtern";   Field="ontime_pct";            Calc="Direct";    RawMin=0; RawMax=100; Unit="%" }
            @{ Name="Afstand i dag (km)";  Action="showVehicleReportExtern"; Field="totaldistance_km";      Calc="Direct";    RawMin=0; RawMax=1000; Unit="km" }
            @{ Name="Chauffør score";      Action="showDriverReportExtern";  Field="drivingscore";          Calc="Direct";    RawMin=0; RawMax=100; Unit="%" }
            @{ Name="Brændstof forbrug";   Action="showVehicleReportExtern"; Field="totalfuelconsumption_l";Calc="Direct";    RawMin=0; RawMax=500; Unit="L" }
        )
    }
    @{
        ID          = "Geotab"
        Name        = "Geotab"
        Danish      = "Geotab — stor international løsning"
        AuthFields  = @("Server","Database","Username","Password")
        BuildURL    = {
            param($auth, $action)
            "https://$($auth.Server)/apiv1"
        }
        Signals     = @(
            @{ Name="Tom kørsel %";       Action="Get/Device";  Field="engineHours";  Calc="EmptyPct";  RawMin=0; RawMax=100; Unit="%" }
            @{ Name="Afstand i dag (km)"; Action="Get/Device";  Field="odometer";     Calc="Direct";    RawMin=0; RawMax=1000; Unit="km" }
            @{ Name="Chauffør score";     Action="Get/Device";  Field="driverScore";  Calc="Direct";    RawMin=0; RawMax=100; Unit="%" }
        )
    }
    @{
        ID          = "Trackunit"
        Name        = "Trackunit"
        Danish      = "Trackunit — populær i Danmark"
        AuthFields  = @("APIKey")
        BuildURL    = {
            param($auth, $action)
            "https://api.trackunit.com/public/$action"
        }
        Signals     = @(
            @{ Name="Aktive enheder";     Action="asset";       Field="count";        Calc="Direct";    RawMin=0; RawMax=100; Unit="stk" }
            @{ Name="Afstand i dag (km)"; Action="asset";       Field="totalKm";      Calc="Direct";    RawMin=0; RawMax=1000; Unit="km" }
        )
    }
    @{
        ID          = "Keatech"
        Name        = "Keatech"
        Danish      = "Keatech — dansk løsning, 1000+ kunder"
        AuthFields  = @("APIKey")
        BuildURL    = {
            param($auth, $action)
            "https://api.keatech.com/v1/$action"
        }
        Signals     = @(
            @{ Name="Flåde position";     Action="vehicles";    Field="count";        Calc="Direct";    RawMin=0; RawMax=100; Unit="stk" }
            @{ Name="Afstand i dag (km)"; Action="trips";       Field="totalDistance"; Calc="Direct";   RawMin=0; RawMax=1000; Unit="km" }
        )
    }
    @{
        ID          = "Generic"
        Name        = "Anden GPS/REST løsning"
        Danish      = "Anden løsning — enhver REST API"
        AuthFields  = @("URL","APIKey")
        BuildURL    = {
            param($auth, $action)
            $url = $auth.URL
            if ($auth.APIKey -ne "") { $url += "?apikey=$($auth.APIKey)" }
            $url
        }
        Signals     = @()
    }
)

# ============================================================
# HELPER — READ NESTED VALUE
# ============================================================
function Get-NestedValue {
    param($obj, [string]$path)
    $parts = $path -split "\."
    $value = $obj
    foreach ($part in $parts) {
        if ($null -eq $value) { return $null }
        $value = $value.$part
    }
    return $value
}

# ============================================================
# HELPER — FLATTEN JSON FOR GENERIC MODE
# ============================================================
function Get-GPSFlattenedFields {
    param($obj, [string]$prefix = "")
    $results = @()
    if ($null -eq $obj) { return $results }
    $properties = $obj | Get-Member -MemberType NoteProperty -ErrorAction SilentlyContinue
    foreach ($prop in $properties) {
        $name  = $prop.Name
        $value = $obj.$name
        $path  = if ($prefix -ne "") { "$prefix.$name" } else { $name }
        if ($null -eq $value) { continue }
        $type = $value.GetType().Name
        if ($type -in @("PSCustomObject")) {
            $results += Get-GPSFlattenedFields -obj $value -prefix $path
        } elseif ($type -in @("Double","Single","Int32","Int64","Decimal")) {
            $results += @{ Path=$path; Value=$value }
        }
    }
    return $results
}

# ============================================================
# HELPER — PRINT BANNER
# ============================================================
function Write-GPSBanner {
    Write-Host ""
    Write-Host "  +----------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   VBAF-Center GPS Inspector                              |" -ForegroundColor Cyan
    Write-Host "  |   Tilslut dit GPS-system automatisk                      |" -ForegroundColor Cyan
    Write-Host "  +----------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================
# HELPER — TEST GPS CONNECTION
# ============================================================
function Test-GPSConnection {
    param([string]$URL, [hashtable]$Headers = @{})
    try {
        $response = Invoke-RestMethod -Uri $URL -Method GET -Headers $Headers -ErrorAction Stop
        return @{ Success=$true; Response=$response }
    } catch {
        return @{ Success=$false; Error=$_.Exception.Message }
    }
}

# ============================================================
# START-VBAFCENTERGPSINSPECTOR
# ============================================================
function Start-VBAFCenterGPSInspector {
    param(
        [Parameter(Mandatory)] [string] $CustomerID
    )

    Write-GPSBanner

    # Check customer exists
    $profPath = Join-Path $env:USERPROFILE "VBAFCenter\customers\$CustomerID.json"
    if (-not (Test-Path $profPath)) {
        Write-Host ("  Kunde ikke fundet: {0}" -f $CustomerID) -ForegroundColor Red
        Write-Host "  Kør Start-VBAFCenterOnboarding først!" -ForegroundColor Yellow
        return
    }

    $profile = Get-Content $profPath -Raw | ConvertFrom-Json
    Write-Host ("  Kunde        : {0}" -f $profile.CompanyName) -ForegroundColor White
    Write-Host ("  CustomerID   : {0}" -f $CustomerID) -ForegroundColor White
    Write-Host ""

    # ── STEP 1 — CHOOSE GPS SYSTEM ─────────────────────────
    Write-Host "  TRIN 1/4 — Hvilket GPS-system bruger virksomheden?" -ForegroundColor Yellow
    Write-Host ""

    $i = 1
    foreach ($sys in $script:GPSSystems) {
        Write-Host ("  {0}. {1}" -f $i, $sys.Danish) -ForegroundColor White
        $i++
    }

    Write-Host ""
    Write-Host "  Vælg nummer: " -NoNewline -ForegroundColor Yellow
    $sysChoice = [int](Read-Host)
    $selectedSystem = $script:GPSSystems[$sysChoice - 1]

    if (-not $selectedSystem) {
        Write-Host "  Ugyldigt valg." -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host ("  Valgt: {0}" -f $selectedSystem.Name) -ForegroundColor Green
    Write-Host ""

    # ── STEP 2 — COLLECT CREDENTIALS ───────────────────────
    Write-Host "  TRIN 2/4 — Indtast API-adgang fra jeres GPS-leverandør" -ForegroundColor Yellow
    Write-Host "  (Disse oplysninger får du fra GPS-leverandørens support)" -ForegroundColor DarkGray
    Write-Host ""

    $auth = @{}
    foreach ($field in $selectedSystem.AuthFields) {
        Write-Host ("  {0}: " -f $field) -NoNewline -ForegroundColor White
        $auth[$field] = Read-Host
    }

    Write-Host ""

    # ── STEP 3 — TEST CONNECTION ────────────────────────────
    Write-Host "  TRIN 3/4 — Tester forbindelsen til GPS-systemet..." -ForegroundColor Yellow
    Write-Host ""

    $headers = @{}
    if ($auth.ContainsKey("APIKey") -and $auth.APIKey -ne "") {
        $headers["Authorization"] = "Bearer $($auth.APIKey)"
        $headers["X-API-Key"]     = $auth.APIKey
    }

    # For generic system — use URL directly
    if ($selectedSystem.ID -eq "Generic") {
        $testURL = $auth.URL
        if ($auth.ContainsKey("APIKey") -and $auth.APIKey -ne "") {
            if ($testURL -like "*?*") {
                $testURL += "&apikey=$($auth.APIKey)"
            } else {
                $testURL += "?apikey=$($auth.APIKey)"
            }
        }

        Write-Host ("  URL: {0}" -f $testURL) -ForegroundColor DarkGray
        $test = Test-GPSConnection -URL $testURL -Headers $headers

        if (-not $test.Success) {
            Write-Host ("  Forbindelse fejlede: {0}" -f $test.Error) -ForegroundColor Red
            Write-Host "  Tjek URL og API-nøgle og prøv igen." -ForegroundColor Yellow
            return
        }

        Write-Host "  Forbindelse OK!" -ForegroundColor Green
        Write-Host ""

        # Show all numeric fields
        Write-Host "  TRIN 4/4 — Vælg signaler fra GPS-systemet" -ForegroundColor Yellow
        Write-Host ""

        $fields = Get-GPSFlattenedFields -obj $test.Response
        if ($fields.Count -eq 0) {
            Write-Host "  Ingen numeriske felter fundet i svaret." -ForegroundColor Red
            Write-Host "  Prøv API Inspector i stedet: Invoke-VBAFCenterAPIInspector" -ForegroundColor Yellow
            return
        }

        Write-Host ("  {0,-4} {1,-40} {2,10}" -f "#", "Felt (JSONPath)", "Værdi") -ForegroundColor Yellow
        Write-Host ("  {0}" -f ("-" * 60)) -ForegroundColor DarkGray

        $displayMap = @{}
        $idx = 1
        foreach ($f in $fields) {
            Write-Host ("  {0,-4} {1,-40} {2,10}" -f $idx, $f.Path, $f.Value) -ForegroundColor White
            $displayMap[$idx] = $f
            $idx++
        }

        Write-Host ""
        Write-Host "  Konfigurer VBAF-signaler fra disse felter." -ForegroundColor Cyan
        Write-Host "  Tryk Enter for at afslutte eller vælg felt:" -ForegroundColor DarkGray
        Write-Host ""

        $signalIdx = 1
        while ($signalIdx -le 4) {
            Write-Host ("  Signal{0} — Felt nummer (eller Enter for at springe over): " -f $signalIdx) -NoNewline -ForegroundColor Yellow
            $pick = Read-Host
            if ($pick -eq "") { break }

            $picked = $displayMap[[int]$pick]
            if (-not $picked) { continue }

            Write-Host ("  Navn på signal [{0}]: " -f $picked.Path) -NoNewline -ForegroundColor Yellow
            $sigName = Read-Host
            if ($sigName -eq "") { $sigName = $picked.Path }

            $rawMax = [Math]::Max(100, [Math]::Round($picked.Value * 3))

            New-VBAFCenterSignalConfig `
                -CustomerID  $CustomerID `
                -SignalName  $sigName `
                -SignalIndex "Signal$signalIdx" `
                -SourceType  "REST" `
                -SourceURL   $testURL `
                -JSONPath    $picked.Path `
                -RawMin      0 `
                -RawMax      $rawMax

            $signalIdx++
        }

    } else {
        # Known GPS system — use pre-built connector
        $firstAction = $selectedSystem.Signals[0].Action
        $builtURL = & $selectedSystem.BuildURL $auth $firstAction

        Write-Host ("  URL: {0}" -f $builtURL) -ForegroundColor DarkGray
        $test = Test-GPSConnection -URL $builtURL -Headers $headers

        if (-not $test.Success) {
            Write-Host ("  Forbindelse fejlede: {0}" -f $test.Error) -ForegroundColor Red
            Write-Host ""
            Write-Host "  Mulige årsager:" -ForegroundColor Yellow
            Write-Host "  - Forkert API-nøgle eller password" -ForegroundColor White
            Write-Host "  - API-adgang ikke aktiveret af leverandøren endnu" -ForegroundColor White
            Write-Host "  - Kontakt $($selectedSystem.Name) support" -ForegroundColor White
            return
        }

        Write-Host "  Forbindelse OK!" -ForegroundColor Green
        Write-Host ""

        # ── STEP 4 — CONFIGURE SIGNALS ─────────────────────
        Write-Host "  TRIN 4/4 — Vælg signaler der skal overvåges" -ForegroundColor Yellow
        Write-Host ""

        Write-Host ("  {0,-4} {1,-35} {2,-15} {3}" -f "#", "Signal", "Enhed", "Beskrivelse") -ForegroundColor Yellow
        Write-Host ("  {0}" -f ("-" * 70)) -ForegroundColor DarkGray

        $i = 1
        foreach ($sig in $selectedSystem.Signals) {
            Write-Host ("  {0,-4} {1,-35} {2,-15} {3}" -f $i, $sig.Name, $sig.Unit, $sig.Action) -ForegroundColor White
            $i++
        }

        Write-Host ""
        Write-Host "  Vælg op til 4 signaler (kommasepareret, f.eks. 1,2,3): " -NoNewline -ForegroundColor Yellow
        $picks = (Read-Host) -split "," | ForEach-Object { $_.Trim() }

        $signalIdx = 1
        foreach ($pick in $picks) {
            if ($signalIdx -gt 4) { break }
            $sig = $selectedSystem.Signals[[int]$pick - 1]
            if (-not $sig) { continue }

            $sigURL = & $selectedSystem.BuildURL $auth $sig.Action

            New-VBAFCenterSignalConfig `
                -CustomerID  $CustomerID `
                -SignalName  $sig.Name `
                -SignalIndex "Signal$signalIdx" `
                -SourceType  "REST" `
                -SourceURL   $sigURL `
                -JSONPath    $sig.Field `
                -RawMin      $sig.RawMin `
                -RawMax      $sig.RawMax

            $signalIdx++
        }
    }

    # ── SUMMARY ────────────────────────────────────────────
    Write-Host ""
    Write-Host "  +----------------------------------------------------------+" -ForegroundColor Green
    Write-Host "  |   GPS-forbindelse konfigureret!                          |" -ForegroundColor Green
    Write-Host "  +----------------------------------------------------------+" -ForegroundColor Green
    Write-Host ""
    Write-Host ("  Kunde     : {0}" -f $profile.CompanyName) -ForegroundColor White
    Write-Host ("  GPS-system: {0}" -f $selectedSystem.Name) -ForegroundColor White
    Write-Host ""
    Write-Host "  Test forbindelsen:" -ForegroundColor Yellow
    Write-Host ("  Invoke-VBAFCenterRun -CustomerID ""{0}""" -f $CustomerID) -ForegroundColor Green
    Write-Host ""
    Write-Host "  Start 24/7 overvågning:" -ForegroundColor Yellow
    Write-Host ("  Start-VBAFCenterSchedule -CustomerID ""{0}""" -f $CustomerID) -ForegroundColor Green
    Write-Host ""
    Write-Host "  Se resultater i portalen:" -ForegroundColor Yellow
    Get-VBAFCenterPortalURLs
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   VBAF-Center GPS Inspector              |" -ForegroundColor Cyan
Write-Host "  |   Tilslut GPS-system i 4 trin            |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Start-VBAFCenterGPSInspector — start GPS-forbindelsesguide" -ForegroundColor White
Write-Host ""
Write-Host "  Understøttede GPS-systemer:" -ForegroundColor DarkGray
Write-Host "  Webfleet · Geotab · Trackunit · Keatech · Andre REST APIs" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Forudsætning:" -ForegroundColor Yellow
Write-Host "  Kunden skal have bedt GPS-leverandøren om API-adgang" -ForegroundColor White
Write-Host ""
Write-Host "  Quick start:" -ForegroundColor Yellow
Write-Host "  Start-VBAFCenterGPSInspector -CustomerID 'TruckCompanyDK'" -ForegroundColor Green
Write-Host ""