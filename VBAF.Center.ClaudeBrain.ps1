#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 19 — AI Brain (Multi-Provider)
.DESCRIPTION
    Real AI decision engine supporting multiple providers.
    Replaces the if-statement with genuine intelligence.

    Supported providers:
      Claude     — Anthropic (paid, best quality)
      Gemini     — Google (FREE — 1500 req/day — excellent)
      Groq       — Groq (FREE — extremely fast)
      OpenRouter — OpenRouter (FREE — 200 req/day)
      Mistral    — Mistral AI (FREE)

    Returns full intelligence:
      Action number (0-3)
      Reason in plain Danish
      Specific dispatcher instruction
      Pattern recognition from history
      Confidence level

    Functions:
      Set-VBAFCenterAIKey              — save API key for a provider
      Get-VBAFCenterAIProviders        — show all providers and status
      Test-VBAFCenterAIProvider        — test a provider connection
      Invoke-VBAFCenterClaudeBrain     — run full AI analysis
      Get-VBAFCenterClaudeBrainHistory — show AI decision history
#>

$script:AIConfigPath = Join-Path $env:USERPROFILE "VBAFCenter\ai"

# ============================================================
# PROVIDER DEFINITIONS
# ============================================================
$script:AIProviders = @{

    "Claude" = @{
        Name        = "Claude Sonnet (Anthropic)"
        URL         = "https://api.anthropic.com/v1/messages"
        Model       = "claude-sonnet-4-20250514"
        Format      = "Anthropic"
        Free        = $false
        Description = "Best quality — paid API"
        GetKey      = "https://console.anthropic.com"
    }

    "Gemini" = @{
        Name        = "Gemini 2.0 Flash (Google)"
        URL         = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
        Model       = "gemini-2.0-flash"
        Format      = "OpenAI"
        Free        = $true
        Description = "FREE — 1500 req/day — excellent quality"
        GetKey      = "https://aistudio.google.com/app/apikey"
    }

    "Groq" = @{
        Name        = "Llama 3.3 70B (Groq)"
        URL         = "https://api.groq.com/openai/v1/chat/completions"
        Model       = "llama-3.3-70b-versatile"
        Format      = "OpenAI"
        Free        = $true
        Description = "FREE — extremely fast inference"
        GetKey      = "https://console.groq.com/keys"
    }

    "OpenRouter" = @{
        Name        = "DeepSeek R1 (OpenRouter)"
        URL         = "https://openrouter.ai/api/v1/chat/completions"
        Model       = "deepseek/deepseek-r1:free"
        Format      = "OpenAI"
        Free        = $true
        Description = "FREE — 200 req/day — many models"
        GetKey      = "https://openrouter.ai/keys"
    }

    "Mistral" = @{
        Name        = "Mistral Small (Mistral AI)"
        URL         = "https://api.mistral.ai/v1/chat/completions"
        Model       = "mistral-small-latest"
        Format      = "OpenAI"
        Free        = $true
        Description = "FREE tier — good quality"
        GetKey      = "https://console.mistral.ai/api-keys"
    }
}

# ============================================================
# INITIALIZE
# ============================================================
function Initialize-VBAFCenterAIStore {
    if (-not (Test-Path $script:AIConfigPath)) {
        New-Item -ItemType Directory -Path $script:AIConfigPath -Force | Out-Null
    }
}

# ============================================================
# SET-VBAFCENTERAIKEY
# ============================================================
function Set-VBAFCenterAIKey {
    <#
    .SYNOPSIS
        Save an API key for a provider.
    .EXAMPLE
        Set-VBAFCenterAIKey -Provider "Gemini"     -APIKey "AIzaXXXXXX"
        Set-VBAFCenterAIKey -Provider "Groq"       -APIKey "gsk_XXXXXXXX"
        Set-VBAFCenterAIKey -Provider "OpenRouter" -APIKey "sk-or-XXXXXXX"
        Set-VBAFCenterAIKey -Provider "Mistral"    -APIKey "XXXXXXXXXX"
        Set-VBAFCenterAIKey -Provider "Claude"     -APIKey "sk-ant-XXXXXX"
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Claude","Gemini","Groq","OpenRouter","Mistral")]
        [string] $Provider,
        [Parameter(Mandatory)] [string] $APIKey
    )

    Initialize-VBAFCenterAIStore

    $configFile = Join-Path $script:AIConfigPath "$Provider-key.json"
    @{
        Provider = $Provider
        APIKey   = $APIKey
        SavedAt  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    } | ConvertTo-Json | Set-Content $configFile -Encoding UTF8

    $p = $script:AIProviders[$Provider]
    Write-Host ""
    Write-Host ("  API key saved: {0}" -f $p.Name) -ForegroundColor Green
    Write-Host ("  Free  : {0}" -f (if ($p.Free) { "Yes — " + $p.Description } else { "No (paid)" })) -ForegroundColor White
    Write-Host ("  Model : {0}" -f $p.Model) -ForegroundColor White
    Write-Host ("  Test  : Test-VBAFCenterAIProvider -Provider ""{0}""" -f $Provider) -ForegroundColor DarkGray
    Write-Host ""
}

# ============================================================
# GET-VBAFCENTERAIPROVIDERS
# ============================================================
function Get-VBAFCenterAIProviders {
    <#
    .SYNOPSIS
        Show all providers and which ones have API keys configured.
    #>
    Initialize-VBAFCenterAIStore

    Write-Host ""
    Write-Host "  VBAF-Center AI Providers" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("  {0,-12} {1,-32} {2,-6} {3,-10} {4}" -f "Provider","Name","Free","Status","Description") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 85)) -ForegroundColor DarkGray

    foreach ($key in ($script:AIProviders.Keys | Sort-Object)) {
        $p       = $script:AIProviders[$key]
        $keyFile = Join-Path $script:AIConfigPath "$key-key.json"
        $status  = if (Test-Path $keyFile) { "Key OK" } else { "No key" }
        $color   = if (Test-Path $keyFile) { "Green" } else { "DarkGray" }
        $free    = if ($p.Free) { "FREE" } else { "Paid" }
        Write-Host ("  {0,-12} {1,-32} {2,-6} {3,-10} {4}" -f $key, $p.Name, $free, $status, $p.Description) -ForegroundColor $color
    }

    Write-Host ""
    Write-Host "  Get free API keys:" -ForegroundColor Yellow
    foreach ($key in ($script:AIProviders.Keys | Where-Object { $script:AIProviders[$_].Free } | Sort-Object)) {
        Write-Host ("  {0,-12} {1}" -f $key, $script:AIProviders[$key].GetKey) -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ============================================================
# GET API KEY (internal)
# ============================================================
function Get-VBAFCenterAIKey {
    param([string] $Provider)
    Initialize-VBAFCenterAIStore
    $configFile = Join-Path $script:AIConfigPath "$Provider-key.json"
    if (-not (Test-Path $configFile)) { return $null }
    $config = Get-Content $configFile -Raw | ConvertFrom-Json
    return $config.APIKey
}

# ============================================================
# REPAIR-VBAFCENTERDANISH — fix encoding of Danish characters
# ============================================================
function Repair-VBAFCenterDanish {
    param([string] $Text)
    $Text = $Text -replace 'Ã¦', 'ae' -replace 'Ã…', 'AA' -replace 'Ã¥', 'aa'
    $Text = $Text -replace 'Ã¸', 'oe' -replace 'Ã˜', 'OE'
    $Text = $Text -replace 'Ã¦', 'ae' -replace 'Ã†', 'AE'
    $Text = $Text -replace 'Ã©', 'e'  -replace 'Ã¨', 'e'
    $Text = $Text -replace 'Ã ', 'a'  -replace 'Ã¢', 'a'
    $Text = $Text -replace 'Ã«', 'e'  -replace 'Ã¯', 'i'
    $Text = $Text -replace 'Ã®', 'i'  -replace 'Ã´', 'o'
    $Text = $Text -replace 'Ã»', 'u'  -replace 'Ã¹', 'u'
    $Text = $Text -replace 'Ã§', 'c'  -replace 'Ã±', 'n'
    # Common Danish words - direct fixes
    $Text = $Text -replace 'rA¸de',    'roede'
    $Text = $Text -replace 'hA¸j',     'hoej'
    $Text = $Text -replace 'kA¦r',     'kaer'
    $Text = $Text -replace 'brA¦nd',   'braend'
    $Text = $Text -replace 'stofA',    'stofa'
    $Text = $Text -replace 'A¸je',     'oje'
    $Text = $Text -replace 'A¸kono',   'okono'
    $Text = $Text -replace 'lA¦nge',   'laenge'
    $Text = $Text -replace 'tilgA¦ng', 'tilgaeng'
    $Text = $Text -replace 'forA¦ld',  'foraeld'
    $Text = $Text -replace 'omrA¥d',   'omraad'
    return $Text
}

# ============================================================
# INVOKE AI CALL (internal)
# ============================================================
function Invoke-VBAFCenterAICall {
    param([string]$Provider, [string]$Prompt, [string]$APIKey)

    $p = $script:AIProviders[$Provider]

    if ($p.Format -eq "Anthropic") {
        $body = @{
            model      = $p.Model
            max_tokens = 1000
            messages   = @(@{ role="user"; content=$Prompt })
        } | ConvertTo-Json -Depth 5

        $headers = @{
            "x-api-key"         = $APIKey
            "anthropic-version" = "2023-06-01"
            "content-type"      = "application/json"
        }

        $response = Invoke-RestMethod -Uri $p.URL -Method POST -Headers $headers -Body $body -ErrorAction Stop
        return $response.content[0].text

    } else {
        $promptString = [string]$Prompt
        $bodyObj = [ordered]@{
            model    = [string]$p.Model
            messages = @([ordered]@{ role="user"; content=$promptString })
        }
        $body      = $bodyObj | ConvertTo-Json -Depth 5
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

        $headers = @{
            "Authorization" = "Bearer $APIKey"
            "Content-Type"  = "application/json; charset=utf-8"
        }

        if ($Provider -eq "OpenRouter") {
            $headers["HTTP-Referer"] = "https://github.com/JupyterPS/VBAF-Center"
            $headers["X-Title"]      = "VBAF-Center"
        }

        $response = Invoke-RestMethod -Uri $p.URL -Method POST -Headers $headers -Body $bodyBytes -ErrorAction Stop
        return $response.choices[0].message.content
    }
}

# ============================================================
# TEST-VBAFCENTERAIPROVIDER
# ============================================================
function Test-VBAFCenterAIProvider {
    <#
    .SYNOPSIS
        Test a provider with a simple ping.
    .EXAMPLE
        Test-VBAFCenterAIProvider -Provider "Gemini"
        Test-VBAFCenterAIProvider -Provider "Groq"
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Claude","Gemini","Groq","OpenRouter","Mistral")]
        [string] $Provider
    )

    $apiKey = Get-VBAFCenterAIKey -Provider $Provider
    if (-not $apiKey) {
        Write-Host ("No API key for {0}." -f $Provider) -ForegroundColor Red
        Write-Host ("  Run: Set-VBAFCenterAIKey -Provider ""{0}"" -APIKey ""your-key""" -f $Provider) -ForegroundColor Yellow
        return
    }

    $p = $script:AIProviders[$Provider]
    Write-Host ""
    Write-Host ("Testing: {0}" -f $p.Name) -ForegroundColor Yellow
    Write-Host ("  URL   : {0}" -f $p.URL)   -ForegroundColor White
    Write-Host ("  Model : {0}" -f $p.Model) -ForegroundColor White

    try {
        $result = Invoke-VBAFCenterAICall -Provider $Provider -APIKey $apiKey `
            -Prompt 'Reply with exactly: {"status":"ok","message":"VBAF connection test successful"}'
        Write-Host ("  Result: Connection OK") -ForegroundColor Green
        Write-Host ("  Response: {0}" -f ($result -replace "`n"," ")) -ForegroundColor DarkGray
    } catch {
        Write-Host ("  FAILED: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }
    Write-Host ""
}

# ============================================================
# GET-VBAFCENTERHISTORYSUMMARY — 30-day aggregated analysis
# ============================================================
function Get-VBAFCenterHistorySummary {
    param(
        [string] $CustomerID,
        [int]    $Days = 30
    )

    $historyPath = Join-Path $env:USERPROFILE "VBAFCenter\history"
    if (-not (Test-Path $historyPath)) { return "  Ingen historik tilgaengelig.`n" }

    $cutoff = (Get-Date).AddDays(-$Days)
    $files  = Get-ChildItem $historyPath -Filter "$CustomerID-*.json" |
              Where-Object { $_.LastWriteTime -ge $cutoff } |
              Sort-Object LastWriteTime

    if ($files.Count -eq 0) { return "  Ingen historik i de seneste $Days dage.`n" }

    $runs = @()
    foreach ($f in $files) {
        try { $runs += Get-Content $f.FullName -Raw | ConvertFrom-Json } catch {}
    }

    if ($runs.Count -eq 0) { return "  Ingen gyldige historik-poster fundet.`n" }

    # Action distribution
    $actionCounts = @{0=0;1=0;2=0;3=0}
    foreach ($r in $runs) { $actionCounts[[int]$r.Action]++ }

    # Average per day of week
    $dayAvgs = @{}
    $dayNames = @("Sondag","Mandag","Tirsdag","Onsdag","Torsdag","Fredag","Lordag")
    foreach ($r in $runs) {
        try {
            $dt  = [DateTime]::Parse($r.Timestamp)
            $day = [int]$dt.DayOfWeek
            if (-not $dayAvgs.ContainsKey($day)) { $dayAvgs[$day] = @() }
            $dayAvgs[$day] += [double]$r.AvgSignal
        } catch {}
    }

    # Trend — last 5 vs previous 5
    $trend = "stabil"
    if ($runs.Count -ge 10) {
        $recent5 = ($runs | Select-Object -Last 5  | ForEach-Object { [double]$_.AvgSignal } | Measure-Object -Average).Average
        $prev5   = ($runs | Select-Object -First 5 | ForEach-Object { [double]$_.AvgSignal } | Measure-Object -Average).Average
        $diff    = [Math]::Round($recent5 - $prev5, 3)
        if ($diff -gt 0.05)       { $trend = "stigende (+$diff)" }
        elseif ($diff -lt -0.05)  { $trend = "faldende ($diff)" }
    }

    # Override rate
    $overrideCount = @($runs | Where-Object { $_.OverrideApplied -eq $true }).Count
    $overridePct   = if ($runs.Count -gt 0) { [Math]::Round($overrideCount / $runs.Count * 100, 0) } else { 0 }

    # Worst signal combination
    $escalateRuns = @($runs | Where-Object { [int]$_.Action -eq 3 })
    $worstAvg     = if ($escalateRuns.Count -gt 0) {
        [Math]::Round(($escalateRuns | ForEach-Object { [double]$_.AvgSignal } | Measure-Object -Average).Average, 3)
    } else { "N/A" }

    # Overall average
    $overallAvg = [Math]::Round(($runs | ForEach-Object { [double]$_.AvgSignal } | Measure-Object -Average).Average, 3)

    # Build summary text
    $summary = "HISTORIK SAMMENDRAG ($Days dage — $($runs.Count) koersler):`n"
    $summary += "  Samlet gennemsnit   : $overallAvg`n"
    $summary += "  Trend (nu vs start) : $trend`n"
    $summary += "  Override rate       : $overridePct% (dispatcher korrigerede $overrideCount gange)`n"
    $summary += "  Action fordeling    : Monitor=$($actionCounts[0]) Reassign=$($actionCounts[1]) Reroute=$($actionCounts[2]) Escalate=$($actionCounts[3])`n"

    if ($escalateRuns.Count -gt 0) {
        $summary += "  Kritiske situationer: $($escalateRuns.Count) Escalate-haendelser (gns signal ved krise: $worstAvg)`n"
    }

    # Day of week pattern
    $dayPattern = ""
    foreach ($day in ($dayAvgs.Keys | Sort-Object)) {
        $avg = [Math]::Round(($dayAvgs[$day] | Measure-Object -Average).Average, 3)
        $dayPattern += "$($dayNames[$day])=$avg  "
    }
    if ($dayPattern -ne "") {
        $summary += "  Ugedags-moenster    : $dayPattern`n"
        # Find worst day
        $worstDay = $dayAvgs.Keys | Sort-Object { ($dayAvgs[$_] | Measure-Object -Average).Average } -Descending | Select-Object -First 1
        $summary += "  Typisk vaerste dag  : $($dayNames[$worstDay])`n"
    }

    # Time of day pattern
    $morningRuns   = @($runs | Where-Object { try { [DateTime]::Parse($_.Timestamp).Hour -lt 12   } catch { $false } })
    $afternoonRuns = @($runs | Where-Object { try { $h=[DateTime]::Parse($_.Timestamp).Hour; $h -ge 12 -and $h -lt 17 } catch { $false } })
    $eveningRuns   = @($runs | Where-Object { try { [DateTime]::Parse($_.Timestamp).Hour -ge 17  } catch { $false } })

    if ($morningRuns.Count -gt 0 -and $afternoonRuns.Count -gt 0) {
        $morningAvg   = [Math]::Round(($morningRuns   | ForEach-Object { [double]$_.AvgSignal } | Measure-Object -Average).Average, 3)
        $afternoonAvg = [Math]::Round(($afternoonRuns | ForEach-Object { [double]$_.AvgSignal } | Measure-Object -Average).Average, 3)
        $summary += "  Tidspunkt moenster  : Formiddag=$morningAvg  Eftermiddag=$afternoonAvg`n"
        if ($afternoonAvg -gt $morningAvg + 0.10) {
            $summary += "  OBS: Situationen forvaerres typisk om eftermiddagen`n"
        }
    }

    return $summary
}

# ============================================================
# BUILD PROMPT (internal)
# ============================================================
function Build-VBAFCenterAIPrompt {
    param(
        [string]   $CustomerID,
        [object]   $Profile,
        [object[]] $Signals,
        [object[]] $History,
        [object]   $ActionMap,
        [double]   $WeightedAvg,
        [object[]] $RedSignals,
        [object[]] $YellowSignals,
        [string]   $HistorySummary = ""
    )

    $signalText = ""
    foreach ($s in $Signals) {
        $status = if ($s.SignalColour) { $s.SignalColour } else {
            if ($s.Normalised -gt 0.75) { "RED" } elseif ($s.Normalised -gt 0.40) { "YELLOW" } else { "GREEN" }
        }
        $thr = ""
        if ($s.GoodBelow -ge 0 -or $s.BadAbove -ge 0) { $thr = " (god under $($s.GoodBelow), kritisk over $($s.BadAbove))" }
        $signalText += "  - $($s.SignalName): $($s.RawValue)$thr -- $status`n"
    }

    $historyText = ""
    if ($History -and $History.Count -gt 0) {
        foreach ($h in ($History | Select-Object -Last 5)) {
            $historyText += "  - $($h.Timestamp): $($h.ActionName) (avg $($h.AvgSignal))"
            if ($h.OverrideApplied) { $historyText += " [OVERRIDE]" }
            $historyText += "`n"
        }
    } else { $historyText = "  Ingen historik endnu.`n" }

    $actionText = ""
    if ($ActionMap) {
        $actionText = "  Action 0: $($ActionMap.Action0Command)`n  Action 1: $($ActionMap.Action1Command)`n  Action 2: $($ActionMap.Action2Command)`n  Action 3: $($ActionMap.Action3Command)`n"
    } else {
        $actionText = "  Standard: Monitor / Reassign / Reroute / Escalate`n"
    }

    $redCount    = if ($RedSignals)    { @($RedSignals).Count    } else { 0 }
    $yellowCount = if ($YellowSignals) { @($YellowSignals).Count } else { 0 }

    return @"
Du er driftsassistent for $($Profile.CompanyName) - en $($Profile.BusinessType) virksomhed i Danmark.
Svar ALTID paa dansk. Vaer konkret. Ingen lange forklaringer.

KUNDEPROFIL:
  Virksomhed: $($Profile.CompanyName) | Branche: $($Profile.BusinessType) | Agent: $($Profile.Agent)
  Problem: $($Profile.Problem)

AKTUELLE SIGNALER:
$signalText
OVERSIGT: Vaegtet gns=$([Math]::Round($WeightedAvg,4)) | Roede=$redCount | Gule=$yellowCount

$HistorySummary
SENESTE 5 KOERSLER:
$historyText
HANDLINGER:
$actionText
OPGAVE - returner KUN dette JSON uden markdown eller forklaring:
{"Action":<0-3>,"ActionName":"<Monitor/Reassign/Reroute/Escalate>","Reason":"<2-3 saetninger>","Instruction":"<1-2 konkrete saetninger til dispatcher>","Pattern":"<1 saetning eller tom>","Confidence":"<Hoej/Medium/Lav>"}

REGLER: 1 roed=min Action 2 | 2+ roede=min Action 3 | avg>0.75=Action 3 | avg>0.50=Action 2 | avg>0.25=Action 1
"@
}

# ============================================================
# INVOKE-VBAFCENTERCLAUDEBRAIN
# ============================================================
function Invoke-VBAFCenterClaudeBrain {
    <#
    .SYNOPSIS
        Full AI analysis using your chosen provider.
    .EXAMPLE
        Invoke-VBAFCenterClaudeBrain -CustomerID "TruckCompanyDK"
        Invoke-VBAFCenterClaudeBrain -CustomerID "TruckCompanyDK" -Provider "Gemini"
        Invoke-VBAFCenterClaudeBrain -CustomerID "TruckCompanyDK" -Provider "Groq"
        Invoke-VBAFCenterClaudeBrain -CustomerID "TruckCompanyDK" -Provider "Claude"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [ValidateSet("Claude","Gemini","Groq","OpenRouter","Mistral")]
        [string] $Provider = "Gemini"
    )

    $apiKey = Get-VBAFCenterAIKey -Provider $Provider
    if (-not $apiKey) {
        Write-Host ""
        Write-Host ("No API key for {0}." -f $Provider) -ForegroundColor Red
        $p = $script:AIProviders[$Provider]
        Write-Host ("  Get free key : {0}" -f $p.GetKey) -ForegroundColor Yellow
        Write-Host ("  Then run     : Set-VBAFCenterAIKey -Provider ""{0}"" -APIKey ""your-key""" -f $Provider) -ForegroundColor Yellow
        Write-Host ""
        return $null
    }

    $p = $script:AIProviders[$Provider]

    Write-Host ""
    Write-Host ("AI Brain [{0}]: {1} — {2}" -f $Provider, $CustomerID, (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) -ForegroundColor Cyan
    Write-Host ("  Provider : {0}" -f $p.Name)  -ForegroundColor White
    Write-Host ("  Model    : {0}" -f $p.Model) -ForegroundColor White
    Write-Host "  Gathering context..." -ForegroundColor DarkGray

    # Load profile
    $profilePath = Join-Path $env:USERPROFILE "VBAFCenter\customers\$CustomerID.json"
    if (-not (Test-Path $profilePath)) {
        Write-Host ("Customer not found: {0}" -f $CustomerID) -ForegroundColor Red
        return $null
    }
    $profile = Get-Content $profilePath -Raw | ConvertFrom-Json

    # Get signals
    if (-not (Get-Command Get-VBAFCenterAllSignals -ErrorAction SilentlyContinue)) {
        Write-Host "Phase 3 not loaded. Run: . .\VBAF-Center\VBAF.Center.LoadAll.ps1" -ForegroundColor Yellow
        return $null
    }

    $signalResult  = Get-VBAFCenterAllSignals -CustomerID $CustomerID
    $signals       = @($signalResult.Signals)
    $weightedAvg   = if ($signalResult.WeightedAvg) { $signalResult.WeightedAvg } else { $signalResult.SimpleAvg }
    $redSignals    = @($signalResult.RedSignals)
    $yellowSignals = @($signalResult.YellowSignals)

    if ($signals.Count -eq 0) {
        Write-Host ("No signals configured for: {0}" -f $CustomerID) -ForegroundColor Yellow
        return $null
    }

    # Load history
    $historyPath = Join-Path $env:USERPROFILE "VBAFCenter\history"
    $history     = @()
    if (Test-Path $historyPath) {
        $files = Get-ChildItem $historyPath -Filter "$CustomerID-*.json" |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 10
        foreach ($f in $files) {
            try { $history += Get-Content $f.FullName -Raw | ConvertFrom-Json } catch {}
        }
        $history = @($history | Sort-Object Timestamp)
    }

    # Load action map
    $actionMap  = $null
    $actionFile = Join-Path $env:USERPROFILE "VBAFCenter\actions\$CustomerID-actions.txt"
    if (Test-Path $actionFile) {
        $lines = Get-Content $actionFile
        $actionMap = [PSCustomObject]@{
            Action0Command = ($lines | Where-Object { $_ -match "^0\|" } | ForEach-Object { ($_ -split "\|")[2] }) -join ""
            Action1Command = ($lines | Where-Object { $_ -match "^1\|" } | ForEach-Object { ($_ -split "\|")[2] }) -join ""
            Action2Command = ($lines | Where-Object { $_ -match "^2\|" } | ForEach-Object { ($_ -split "\|")[2] }) -join ""
            Action3Command = ($lines | Where-Object { $_ -match "^3\|" } | ForEach-Object { ($_ -split "\|")[2] }) -join ""
        }
    }

    # Build 30-day history summary
    Write-Host "  Building 30-day history summary..." -ForegroundColor DarkGray
    $historySummary = Get-VBAFCenterHistorySummary -CustomerID $CustomerID -Days 30

    # Build and send prompt
    $prompt = Build-VBAFCenterAIPrompt `
        -CustomerID $CustomerID -Profile $profile -Signals $signals `
        -History $history -ActionMap $actionMap -WeightedAvg $weightedAvg `
        -RedSignals $redSignals -YellowSignals $yellowSignals `
        -HistorySummary $historySummary

    Write-Host ("  Calling {0}..." -f $p.Name) -ForegroundColor DarkGray

    $aiResponse = $null
    try {
        $rawText    = Invoke-VBAFCenterAICall -Provider $Provider -Prompt $prompt -APIKey $apiKey
        $rawText    = Repair-VBAFCenterDanish -Text $rawText
        $clean      = $rawText.Trim() -replace '```json', '' -replace '```', '' -replace "`n", " "
        # Extract JSON if surrounded by other text
        if ($clean -match '\{.*\}') { $clean = $Matches[0] }
        $aiResponse = $clean | ConvertFrom-Json
    } catch {
        Write-Host ("  AI call failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        Write-Host "  Raw response was:" -ForegroundColor DarkGray
        if ($rawText) { Write-Host ("  {0}" -f $rawText.Substring(0, [Math]::Min(200, $rawText.Length))) -ForegroundColor DarkGray }
        return $null
    }

    # Display
    $action      = [int]$aiResponse.Action
    $actionName  = [string]$aiResponse.ActionName
    $reason      = [string]$aiResponse.Reason
    $instruction = [string]$aiResponse.Instruction
    $pattern     = [string]$aiResponse.Pattern
    $confidence  = [string]$aiResponse.Confidence

    $actionColors = @("Green","Yellow","DarkYellow","Red")
    $color        = $actionColors[$action]

    Write-Host ""
    Write-Host ("  Action     : {0} — {1}" -f $action, $actionName) -ForegroundColor $color
    Write-Host ("  Confidence : {0}" -f $confidence)                 -ForegroundColor White
    Write-Host ""
    Write-Host "  Reason:" -ForegroundColor Yellow
    Write-Host ("  {0}" -f $reason) -ForegroundColor White
    Write-Host ""
    Write-Host "  Instruction to dispatcher:" -ForegroundColor Yellow
    Write-Host ("  {0}" -f $instruction) -ForegroundColor $color
    if ($pattern -and $pattern -ne "") {
        Write-Host ""
        Write-Host "  Pattern:" -ForegroundColor Cyan
        Write-Host ("  {0}" -f $pattern) -ForegroundColor Cyan
    }
    Write-Host ""

    # Save to history
    $result = [PSCustomObject]@{
        CustomerID        = $CustomerID
        Timestamp         = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
        Provider          = $Provider
        Model             = $p.Model
        Signals           = @($signals | ForEach-Object { $_.Normalised })
        AvgSignal         = [Math]::Round($weightedAvg, 4)
        WeightedAvg       = [Math]::Round($weightedAvg, 4)
        Action            = $action
        ActionName        = $actionName
        ActionCommand     = $instruction
        ActionReason      = $reason
        Pattern           = $pattern
        Confidence        = $confidence
        OverrideApplied   = ($redSignals.Count -gt 0)
        RedSignalCount    = $redSignals.Count
        YellowSignalCount = $yellowSignals.Count
        Source            = "AI-$Provider"
    }

    if (-not (Test-Path $historyPath)) { New-Item -ItemType Directory -Path $historyPath -Force | Out-Null }
    $histFile = Join-Path $historyPath "$CustomerID-$(Get-Date -Format 'yyyyMMdd_HHmmss_fff').json"
    $result | ConvertTo-Json -Depth 5 | Set-Content $histFile -Encoding UTF8

    # Crisis if Action 3
    if ($action -ge 3) {
        Write-Host "  [CRISIS] AI recommends Escalate — activating crisis response!" -ForegroundColor Red
        try { [Console]::Beep(800,400); Start-Sleep -Milliseconds 100; [Console]::Beep(1200,800) } catch {}
        if (Get-Command Start-VBAFCenterCrisis -ErrorAction SilentlyContinue) {
            Start-VBAFCenterCrisis -CustomerID $CustomerID
        }
    }

    return $result
}

# ============================================================
# GET-VBAFCENTERCLAUDEBRAINHISTORY
# ============================================================
function Get-VBAFCenterClaudeBrainHistory {
    <#
    .SYNOPSIS
        Show recent AI Brain decisions for a customer.
    .EXAMPLE
        Get-VBAFCenterClaudeBrainHistory -CustomerID "TruckCompanyDK"
        Get-VBAFCenterClaudeBrainHistory -CustomerID "TruckCompanyDK" -Provider "Gemini"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [string] $Provider = "",
        [int]    $Last     = 10
    )

    $historyPath = Join-Path $env:USERPROFILE "VBAFCenter\history"
    if (-not (Test-Path $historyPath)) {
        Write-Host "No history found." -ForegroundColor Yellow
        return
    }

    $files  = Get-ChildItem $historyPath -Filter "$CustomerID-*.json" |
              Sort-Object LastWriteTime -Descending | Select-Object -First ($Last * 3)
    $aiOnly = @()

    foreach ($f in $files) {
        try {
            $h = Get-Content $f.FullName -Raw | ConvertFrom-Json
            if ($h.Source -like "AI-*") {
                if ($Provider -eq "" -or $h.Source -eq "AI-$Provider") { $aiOnly += $h }
            }
        } catch {}
    }

    $aiOnly = $aiOnly | Select-Object -First $Last

    if ($aiOnly.Count -eq 0) {
        Write-Host ("No AI Brain decisions found for: {0}" -f $CustomerID) -ForegroundColor Yellow
        Write-Host ("  Run: Invoke-VBAFCenterClaudeBrain -CustomerID '{0}'" -f $CustomerID) -ForegroundColor DarkGray
        return
    }

    Write-Host ""
    Write-Host ("AI Brain History: {0} (last {1})" -f $CustomerID, $aiOnly.Count) -ForegroundColor Cyan
    Write-Host ("  {0,-23} {1,-12} {2,-4} {3,-10} {4,-8} {5}" -f "Timestamp","Provider","Act","Name","Conf","Reason") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 90)) -ForegroundColor DarkGray

    foreach ($h in $aiOnly) {
        $color    = @("Green","Yellow","DarkYellow","Red")[[int]$h.Action]
        $prov     = [string]$h.Source -replace "^AI-", ""
        $reason   = [string]$h.ActionReason
        $short    = if ($reason.Length -gt 40) { $reason.Substring(0,40) + "..." } else { $reason }
        Write-Host ("  {0,-23} {1,-12} {2,-4} {3,-10} {4,-8} {5}" -f `
            $h.Timestamp, $prov, $h.Action, $h.ActionName, $h.Confidence, $short) -ForegroundColor $color
    }
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Initialize-VBAFCenterAIStore

Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   VBAF-Center Phase 19 — AI Brain               |" -ForegroundColor Cyan
Write-Host "  |   Multi-provider — Claude, Gemini, Groq + more  |" -ForegroundColor Cyan
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Set-VBAFCenterAIKey              — save API key for a provider"   -ForegroundColor White
Write-Host "  Get-VBAFCenterAIProviders        — show all providers and status" -ForegroundColor White
Write-Host "  Test-VBAFCenterAIProvider        — test a provider connection"    -ForegroundColor White
Write-Host "  Invoke-VBAFCenterClaudeBrain     — run full AI analysis"          -ForegroundColor White
Write-Host "  Get-VBAFCenterClaudeBrainHistory — show AI decision history"      -ForegroundColor White
Write-Host ""

# Show configured providers
$configured = @()
foreach ($key in $script:AIProviders.Keys) {
    $keyFile = Join-Path $script:AIConfigPath "$key-key.json"
    if (Test-Path $keyFile) { $configured += $key }
}

if ($configured.Count -gt 0) {
    Write-Host ("  Configured: {0}" -f ($configured -join ", ")) -ForegroundColor Green
    Write-Host ("  Default   : Gemini (free) — use -Provider to switch") -ForegroundColor DarkGray
} else {
    Write-Host "  No providers configured yet — start with free Gemini:" -ForegroundColor Yellow
    Write-Host "  1. Go to  : https://aistudio.google.com/app/apikey" -ForegroundColor DarkGray
    Write-Host "  2. Run    : Set-VBAFCenterAIKey -Provider ""Gemini"" -APIKey ""AIzaXXXX""" -ForegroundColor DarkGray
    Write-Host "  3. Test   : Test-VBAFCenterAIProvider -Provider ""Gemini""" -ForegroundColor DarkGray
    Write-Host "  4. Analyse: Invoke-VBAFCenterClaudeBrain -CustomerID ""TruckCompanyDK"" -Provider ""Gemini""" -ForegroundColor DarkGray
}
Write-Host ""

<#

Set-VBAFCenterAIKey -Provider "Mistral" -APIKey "PvPxsvxKVk1SoefDnGbsW9gnjWTiMHOJ"
Test-VBAFCenterAIProvider -Provider "Mistral"

Invoke-VBAFCenterClaudeBrain -CustomerID "TruckCompanyDK" -Provider "Mistral"



#>








