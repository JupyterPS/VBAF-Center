#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center API Inspector
.DESCRIPTION
    Inspects any REST API URL and suggests signal configuration.
    Automatically finds all numeric fields, suggests JSONPath,
    RawMin and RawMax — and writes the ready-to-run command.
    Unknown/technical fields are hidden by default.

    Functions:
      Invoke-VBAFCenterAPIInspector — inspect any REST API URL
#>

# ============================================================
# HELPER — FLATTEN JSON OBJECT
# ============================================================
function Get-FlattenedJSON {
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

        if ($type -in @("PSCustomObject","Object[]")) {
            if ($type -eq "Object[]") {
                if ($value.Count -gt 0) {
                    $results += Get-FlattenedJSON -obj $value[0] -prefix "$path[0]"
                }
            } else {
                $results += Get-FlattenedJSON -obj $value -prefix $path
            }
        } elseif ($type -in @("Double","Single","Int32","Int64","Decimal")) {
            $results += @{ Path=$path; Value=$value; Type="Number" }
        } elseif ($type -eq "String") {
            $num = 0.0
            if ([double]::TryParse($value, [ref]$num)) {
                $results += @{ Path=$path; Value=$num; Type="Number" }
            }
        }
    }

    return $results
}

# ============================================================
# HELPER — SUGGEST RANGE
# ============================================================
function Get-SuggestedRange {
    param([string]$Path, [double]$Value)

    $pathLower = $Path.ToLower()

    if ($pathLower -like "*wind*speed*" -or $pathLower -like "*windspeed*") {
        return @{ Min=0; Max=20; Unit="m/s"; Description="Vindstyrke"; Known=$true }
    }
    if ($pathLower -like "*gust*") {
        return @{ Min=0; Max=40; Unit="m/s"; Description="Vindstød"; Known=$true }
    }
    if ($pathLower -like "*wind*dir*") {
        return @{ Min=0; Max=360; Unit="grader"; Description="Vindretning"; Known=$true }
    }
    if ($pathLower -like "*temp*") {
        return @{ Min=-20; Max=40; Unit="C"; Description="Temperatur"; Known=$true }
    }
    if ($pathLower -like "*precip*" -or $pathLower -like "*rain*") {
        return @{ Min=0; Max=50; Unit="mm"; Description="Nedbør"; Known=$true }
    }
    if ($pathLower -like "*humid*") {
        return @{ Min=0; Max=100; Unit="%"; Description="Luftfugtighed"; Known=$true }
    }
    if ($pathLower -like "*pressure*") {
        return @{ Min=950; Max=1050; Unit="hPa"; Description="Lufttryk"; Known=$true }
    }
    if ($pathLower -like "*cloud*") {
        return @{ Min=0; Max=100; Unit="%"; Description="Skydække"; Known=$true }
    }
    if ($pathLower -like "*visibility*" -or $pathLower -like "*visib*") {
        return @{ Min=0; Max=10000; Unit="m"; Description="Sigtbarhed"; Known=$true }
    }
    if ($pathLower -like "*pct*" -or $pathLower -like "*percent*" -or $pathLower -like "*ratio*") {
        return @{ Min=0; Max=100; Unit="%"; Description="Procent"; Known=$true }
    }
    if ($pathLower -like "*speed*" -or $pathLower -like "*velocity*") {
        return @{ Min=0; Max=200; Unit="km/h"; Description="Hastighed"; Known=$true }
    }
    if ($pathLower -like "*km*" -or $pathLower -like "*distance*") {
        return @{ Min=0; Max=1000; Unit="km"; Description="Distance"; Known=$true }
    }
    if ($pathLower -like "*cost*" -or $pathLower -like "*price*" -or $pathLower -like "*amount*") {
        return @{ Min=0; Max=5000; Unit="DKK"; Description="Beløb"; Known=$true }
    }
    if ($pathLower -like "*cpu*" -or $pathLower -like "*load*") {
        return @{ Min=0; Max=100; Unit="%"; Description="CPU belastning"; Known=$true }
    }
    if ($pathLower -like "*memory*" -or $pathLower -like "*disk*" -or $pathLower -like "*storage*") {
        return @{ Min=0; Max=100; Unit="%"; Description="Lager"; Known=$true }
    }
    if ($pathLower -like "*count*" -or $pathLower -like "*antal*") {
        return @{ Min=0; Max=100; Unit="stk"; Description="Antal"; Known=$true }
    }
    if ($pathLower -like "*empty*") {
        return @{ Min=0; Max=100; Unit="%"; Description="Tom kørsel"; Known=$true }
    }
    if ($pathLower -like "*ontime*" -or $pathLower -like "*on_time*" -or $pathLower -like "*delivery*") {
        return @{ Min=0; Max=100; Unit="%"; Description="Til tiden"; Known=$true }
    }
    if ($pathLower -like "*fuel*") {
        return @{ Min=0; Max=5000; Unit="DKK"; Description="Brændstof"; Known=$true }
    }
    if ($pathLower -like "*score*") {
        return @{ Min=0; Max=100; Unit="%"; Description="Score"; Known=$true }
    }

    # Unknown — technical field
    $suggested_max = [Math]::Max(100, [Math]::Round($Value * 3))
    return @{ Min=0; Max=$suggested_max; Unit=""; Description="Ukendt enhed"; Known=$false }
}

# ============================================================
# INVOKE-VBAFCENTERAPIINSPECTOR
# ============================================================
function Invoke-VBAFCenterAPIInspector {
    param(
        [Parameter(Mandatory)] [string] $URL,
        [string] $CustomerID  = "",
        [string] $SignalIndex = "Signal1"
    )

    Write-Host ""
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   VBAF-Center API Inspector                      |" -ForegroundColor Cyan
    Write-Host "  |   Analysing REST API response...                 |" -ForegroundColor Cyan
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("  URL: {0}" -f $URL) -ForegroundColor DarkGray
    Write-Host ""

    # Call the API
    try {
        Write-Host "  Calling API..." -ForegroundColor Yellow
        $response = Invoke-RestMethod -Uri $URL -Method GET -ErrorAction Stop
        Write-Host "  Response received!" -ForegroundColor Green
        Write-Host ""
    } catch {
        Write-Host ("  API call failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        Write-Host "  Check the URL and try again." -ForegroundColor Yellow
        return
    }

    # Flatten all numeric fields
    $allFields = Get-FlattenedJSON -obj $response

    if ($allFields.Count -eq 0) {
        Write-Host "  No numeric fields found in response." -ForegroundColor Red
        return
    }

    # Build field list with ranges
    $fieldList = @()
    $i = 1
    foreach ($field in $allFields) {
        $range = Get-SuggestedRange -Path $field.Path -Value $field.Value
        $fieldList += @{
            Index       = $i
            Path        = $field.Path
            Value       = $field.Value
            Min         = $range.Min
            Max         = $range.Max
            Unit        = $range.Unit
            Description = $range.Description
            Known       = $range.Known
        }
        $i++
    }

    # Show only KNOWN fields by default
    $showAll = $false

    :menuloop while ($true) {

        $displayList = if ($showAll) { $fieldList } else { $fieldList | Where-Object { $_.Known -eq $true } }

        if ($displayList.Count -eq 0) {
            Write-Host "  No known fields found — showing all fields." -ForegroundColor Yellow
            $showAll = $true
            $displayList = $fieldList
        }

        Write-Host "  Fields found in API response:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host ("  {0,-4} {1,-40} {2,10} {3,-15} {4}" -f "#", "Field (JSONPath)", "Value", "Range", "Description") -ForegroundColor Yellow
        Write-Host ("  {0}" -f ("-" * 80)) -ForegroundColor DarkGray

        # Renumber display list
        $displayIndex = 1
        $displayMap = @{}
        foreach ($f in $displayList) {
            Write-Host ("  {0,-4} {1,-40} {2,10} {3,-15} {4}" -f `
                $displayIndex, $f.Path, $f.Value, "$($f.Min)-$($f.Max) $($f.Unit)", $f.Description) -ForegroundColor White
            $displayMap[$displayIndex] = $f
            $displayIndex++
        }

        Write-Host ""
        if (-not $showAll) {
            $hiddenCount = ($fieldList | Where-Object { $_.Known -eq $false }).Count
            if ($hiddenCount -gt 0) {
                Write-Host ("  [S] Show all fields ($hiddenCount technical fields hidden)") -ForegroundColor DarkGray
            }
        }
        Write-Host ""
        Write-Host "  Which field do you want? Enter number (or S to show all): " -NoNewline -ForegroundColor Yellow
        $choice = Read-Host

        if ($choice.ToUpper() -eq "S") {
            $showAll = $true
            Write-Host ""
            continue menuloop
        }

        $selected = $displayMap[[int]$choice]

        if (-not $selected) {
            Write-Host "  Invalid selection — try again." -ForegroundColor Red
            Write-Host ""
            continue menuloop
        }

        break menuloop
    }

    # Ask for signal name
    Write-Host ""
    $defaultName = $selected.Description
    Write-Host ("  Signal name [{0}]: " -f $defaultName) -NoNewline -ForegroundColor Yellow
    $signalName = Read-Host
    if ($signalName -eq "") { $signalName = $defaultName }

    # Ask for CustomerID if not provided
    if ($CustomerID -eq "") {
        Write-Host "  CustomerID: " -NoNewline -ForegroundColor Yellow
        $CustomerID = Read-Host
    }

    # Ask for SignalIndex
    Write-Host ("  SignalIndex [{0}]: " -f $SignalIndex) -NoNewline -ForegroundColor Yellow
    $idx = Read-Host
    if ($idx -ne "") { $SignalIndex = $idx }

    # Show ready command
    Write-Host ""
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
    Write-Host "  |   Ready! Copy and run this command:              |" -ForegroundColor Green
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
    Write-Host ""
    Write-Host "  New-VBAFCenterSignalConfig ``" -ForegroundColor White
    Write-Host ("    -CustomerID  ""{0}"" ``" -f $CustomerID) -ForegroundColor White
    Write-Host ("    -SignalName  ""{0}"" ``" -f $signalName) -ForegroundColor White
    Write-Host ("    -SignalIndex ""{0}"" ``" -f $SignalIndex) -ForegroundColor White
    Write-Host "    -SourceType  ""REST"" ``" -ForegroundColor White
    Write-Host ("    -SourceURL   ""{0}"" ``" -f $URL) -ForegroundColor White
    Write-Host ("    -JSONPath    ""{0}"" ``" -f $selected.Path) -ForegroundColor White
    Write-Host ("    -RawMin      {0} ``" -f $selected.Min) -ForegroundColor White
    Write-Host ("    -RawMax      {0}" -f $selected.Max) -ForegroundColor White
    Write-Host ""

    # Optionally run it directly
    Write-Host "  Run this command now? (Y/N): " -NoNewline -ForegroundColor Yellow
    $run = Read-Host
    if ($run.ToUpper() -eq "Y") {
        New-VBAFCenterSignalConfig `
            -CustomerID  $CustomerID `
            -SignalName  $signalName `
            -SignalIndex $SignalIndex `
            -SourceType  "REST" `
            -SourceURL   $URL `
            -JSONPath    $selected.Path `
            -RawMin      $selected.Min `
            -RawMax      $selected.Max
        Write-Host ""
        Write-Host "  Signal configured! Test it with:" -ForegroundColor Green
        Write-Host ("  Get-VBAFCenterSignal -CustomerID ""{0}"" -SignalIndex ""{1}""" -f $CustomerID, $SignalIndex) -ForegroundColor Yellow
    }

    Write-Host ""
    return $selected
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   VBAF-Center API Inspector              |" -ForegroundColor Cyan
Write-Host "  |   Inspect any REST API in seconds        |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Invoke-VBAFCenterAPIInspector — inspect any REST API" -ForegroundColor White
Write-Host ""
Write-Host "  Quick start:" -ForegroundColor Yellow
Write-Host "  Invoke-VBAFCenterAPIInspector -URL 'https://api.open-meteo.com/v1/forecast?latitude=55.6415&longitude=12.0803&current=wind_speed_10m,precipitation,temperature_2m' -CustomerID 'TruckCompanyDK' -SignalIndex 'Signal1'" -ForegroundColor Green
Write-Host ""