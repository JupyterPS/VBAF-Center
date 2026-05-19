#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 19 — Claude Brain
.DESCRIPTION
    Replaces the if-statement decision engine with real AI.
    Claude analyses signals, history, customer profile and action map
    and returns a full situational assessment in Danish.

    Option C — Full intelligence:
      Action number (0-3)
      Reason in plain Danish
      Specific dispatcher instruction
      Pattern recognition from history

    Functions:
      Invoke-VBAFCenterClaudeBrain     — run full AI analysis
      Get-VBAFCenterClaudeBrainHistory — show AI decision history
      Set-VBAFCenterClaudeAPIKey       — save API key
      Get-VBAFCenterClaudeAPIKey       — verify API key is set
#>

$script:ClaudeConfigPath = Join-Path $env:USERPROFILE "VBAFCenter\claude"
$script:ClaudeAPIURL     = "https://api.anthropic.com/v1/messages"
$script:ClaudeModel      = "claude-sonnet-4-20250514"

function Initialize-VBAFCenterClaudeStore {
    if (-not (Test-Path $script:ClaudeConfigPath)) {
        New-Item -ItemType Directory -Path $script:ClaudeConfigPath -Force | Out-Null
    }
}

# ============================================================
# SET-VBAFCENTERCLAUDEAPIKEY
# ============================================================
function Set-VBAFCenterClaudeAPIKey {
    <#
    .SYNOPSIS
        Save your Anthropic API key securely to disk.
        Get your key from: https://console.anthropic.com
    .EXAMPLE
        Set-VBAFCenterClaudeAPIKey -APIKey "sk-ant-xxxx"
    #>
    param(
        [Parameter(Mandatory)] [string] $APIKey
    )

    Initialize-VBAFCenterClaudeStore

    $configFile = Join-Path $script:ClaudeConfigPath "claude-config.json"
    @{ APIKey = $APIKey; SavedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") } |
        ConvertTo-Json | Set-Content $configFile -Encoding UTF8

    Write-Host ""
    Write-Host "Claude API key saved!" -ForegroundColor Green
    Write-Host "Test with: Invoke-VBAFCenterClaudeBrain -CustomerID 'TruckCompanyDK'" -ForegroundColor DarkGray
    Write-Host ""
}

# ============================================================
# GET-VBAFCENTERCLAUDEAPIKEY  (internal)
# ============================================================
function Get-VBAFCenterClaudeAPIKey {
    Initialize-VBAFCenterClaudeStore
    $configFile = Join-Path $script:ClaudeConfigPath "claude-config.json"
    if (-not (Test-Path $configFile)) {
        Write-Host "No API key found." -ForegroundColor Red
        Write-Host "Run: Set-VBAFCenterClaudeAPIKey -APIKey 'sk-ant-xxxx'" -ForegroundColor Yellow
        return $null
    }
    $config = Get-Content $configFile -Raw | ConvertFrom-Json
    return $config.APIKey
}

# ============================================================
# BUILD CLAUDE PROMPT  (internal)
# ============================================================
function Build-VBAFCenterClaudePrompt {
    param(
        [string]   $CustomerID,
        [object]   $Profile,
        [object[]] $Signals,
        [object[]] $History,
        [object]   $ActionMap,
        [double]   $WeightedAvg,
        [object[]] $RedSignals,
        [object[]] $YellowSignals
    )

    # Build signal description
    $signalText = ""
    foreach ($s in $Signals) {
        $status = $s.SignalColour
        if (-not $status) { $status = if ($s.Normalised -gt 0.75) { "RED" } elseif ($s.Normalised -gt 0.40) { "YELLOW" } else { "GREEN" } }
        $threshText = ""
        if ($s.GoodBelow -ge 0 -or $s.BadAbove -ge 0) {
            $threshText = " (god: under $($s.GoodBelow), kritisk: over $($s.BadAbove))"
        }
        $signalText += "  - $($s.SignalName): $($s.RawValue) $threshText — $status`n"
    }

    # Build history description (last 5 runs)
    $historyText = ""
    if ($History -and $History.Count -gt 0) {
        $recent = $History | Select-Object -Last 5
        foreach ($h in $recent) {
            $historyText += "  - $($h.Timestamp): $($h.ActionName) (avg $($h.AvgSignal))"
            if ($h.OverrideApplied) { $historyText += " [OVERRIDE]" }
            $historyText += "`n"
        }
    } else {
        $historyText = "  Ingen historik endnu.`n"
    }

    # Build action map description
    $actionText = ""
    if ($ActionMap) {
        $actionText = @"
  Action 0 (Monitor)  : $($ActionMap.Action0Command)
  Action 1 (Reassign) : $($ActionMap.Action1Command)
  Action 2 (Reroute)  : $($ActionMap.Action2Command)
  Action 3 (Escalate) : $($ActionMap.Action3Command)
"@
    } else {
        $actionText = "  Standard: Monitor / Reassign / Reroute / Escalate`n"
    }

    $redCount    = if ($RedSignals)    { @($RedSignals).Count    } else { 0 }
    $yellowCount = if ($YellowSignals) { @($YellowSignals).Count } else { 0 }

    return @"
Du er en driftsassistent for $($Profile.CompanyName) — en $($Profile.BusinessType) virksomhed i Danmark.

Dit job er at analysere de aktuelle driftssignaler og anbefale den rigtige handling til dispatcheren.
Svar ALTID på dansk. Vær konkret og direkte. Ingen lange forklaringer.

KUNDEPROFIL:
  Virksomhed  : $($Profile.CompanyName)
  Branche     : $($Profile.BusinessType)
  Problem     : $($Profile.Problem)
  Agent       : $($Profile.Agent)

AKTUELLE SIGNALER (nu):
$signalText
SIGNAL OVERSIGT:
  Vægtet gennemsnit : $([Math]::Round($WeightedAvg, 4))
  Røde signaler     : $redCount
  Gule signaler     : $yellowCount

SENESTE HISTORIK (de 5 nyeste kørsler):
$historyText
KUNDENS HANDLINGSMULIGHEDER:
$actionText
DIN OPGAVE:
Analyser situationen og returner KUN dette JSON-objekt — intet andet:

{
  "Action": <0, 1, 2 eller 3>,
  "ActionName": "<Monitor, Reassign, Reroute eller Escalate>",
  "Reason": "<2-3 sætninger på dansk — hvad ser du i signalerne og hvorfor er det bekymrende eller OK>",
  "Instruction": "<1-2 konkrete sætninger til dispatcheren — præcis hvad skal de gøre NU>",
  "Pattern": "<1 sætning om mønster på tværs af historik — eller tom streng hvis ingen mønster>",
  "Confidence": "<Høj, Medium eller Lav>"
}

REGLER:
- Action 0 (Monitor)  : alt er OK — ingen handling nødvendig
- Action 1 (Reassign) : noget kræver opmærksomhed — flyt en ressource
- Action 2 (Reroute)  : alvorlig situation — skift tilgang nu
- Action 3 (Escalate) : krise — ring til et menneske med det samme
- Hvis et rødt signal er til stede — minimum Action 2
- Hvis 2+ røde signaler — minimum Action 3
- Brug kundens egne handlingsord fra HANDLINGSMULIGHEDER ovenfor
"@
}

# ============================================================
# INVOKE-VBAFCENTERCLAUDEBRAIN
# ============================================================
function Invoke-VBAFCenterClaudeBrain {
    <#
    .SYNOPSIS
        Full AI analysis of current signals using Claude.
        Replaces the if-statement with real intelligence.
        Returns action, reason, dispatcher instruction and pattern analysis.
    .EXAMPLE
        Invoke-VBAFCenterClaudeBrain -CustomerID "TruckCompanyDK"
        Invoke-VBAFCenterClaudeBrain -CustomerID "TruckCompanyDK" -Verbose
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [switch] $Verbose
    )

    # Get API key
    $apiKey = Get-VBAFCenterClaudeAPIKey
    if (-not $apiKey) { return $null }

    Write-Host ""
    Write-Host ("Claude Brain: {0} — {1}" -f $CustomerID, (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) -ForegroundColor Cyan
    Write-Host "  Gathering context..." -ForegroundColor DarkGray

    # --------------------------------------------------------
    # Step 1 — Load customer profile
    # --------------------------------------------------------
    $profilePath = Join-Path $env:USERPROFILE "VBAFCenter\customers\$CustomerID.json"
    if (-not (Test-Path $profilePath)) {
        Write-Host "Customer not found: $CustomerID" -ForegroundColor Red
        return $null
    }
    $profile = Get-Content $profilePath -Raw | ConvertFrom-Json

    # --------------------------------------------------------
    # Step 2 — Get live signals via Phase 3
    # --------------------------------------------------------
    $signalResult = $null
    $signals      = @()
    $weightedAvg  = 0.0
    $redSignals   = @()
    $yellowSignals = @()

    if (Get-Command Get-VBAFCenterAllSignals -ErrorAction SilentlyContinue) {
        $signalResult  = Get-VBAFCenterAllSignals -CustomerID $CustomerID
        $signals       = @($signalResult.Signals)
        $weightedAvg   = if ($signalResult.WeightedAvg) { $signalResult.WeightedAvg } else { $signalResult.SimpleAvg }
        $redSignals    = @($signalResult.RedSignals)
        $yellowSignals = @($signalResult.YellowSignals)
    } else {
        Write-Host "  Phase 3 not loaded — load VBAF.Center.SignalAcquisition.ps1 first." -ForegroundColor Yellow
        return $null
    }

    if ($signals.Count -eq 0) {
        Write-Host "  No signals configured for: $CustomerID" -ForegroundColor Yellow
        return $null
    }

    # --------------------------------------------------------
    # Step 3 — Load run history
    # --------------------------------------------------------
    $historyPath = Join-Path $env:USERPROFILE "VBAFCenter\history"
    $history     = @()
    if (Test-Path $historyPath) {
        $historyFiles = Get-ChildItem $historyPath -Filter "$CustomerID-*.json" |
                        Sort-Object LastWriteTime -Descending |
                        Select-Object -First 10
        foreach ($f in $historyFiles) {
            try { $history += Get-Content $f.FullName -Raw | ConvertFrom-Json } catch {}
        }
        $history = @($history | Sort-Object Timestamp)
    }

    # --------------------------------------------------------
    # Step 4 — Load action map
    # --------------------------------------------------------
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

    # --------------------------------------------------------
    # Step 5 — Build prompt and call Claude
    # --------------------------------------------------------
    $prompt = Build-VBAFCenterClaudePrompt `
        -CustomerID    $CustomerID `
        -Profile       $profile `
        -Signals       $signals `
        -History       $history `
        -ActionMap     $actionMap `
        -WeightedAvg   $weightedAvg `
        -RedSignals    $redSignals `
        -YellowSignals $yellowSignals

    if ($Verbose) {
        Write-Host ""
        Write-Host "  Prompt sent to Claude:" -ForegroundColor DarkGray
        Write-Host $prompt -ForegroundColor DarkGray
        Write-Host ""
    }

    Write-Host "  Calling Claude..." -ForegroundColor DarkGray

    $body = @{
        model      = $script:ClaudeModel
        max_tokens = 1000
        messages   = @(
            @{ role = "user"; content = $prompt }
        )
    } | ConvertTo-Json -Depth 5

    $headers = @{
        "x-api-key"         = $apiKey
        "anthropic-version" = "2023-06-01"
        "content-type"      = "application/json"
    }

    $claudeResponse = $null
    try {
        $response      = Invoke-RestMethod -Uri $script:ClaudeAPIURL -Method POST -Headers $headers -Body $body -ErrorAction Stop
        $rawText       = $response.content[0].text
        $claudeResponse = $rawText | ConvertFrom-Json
    } catch {
        Write-Host ("  Claude API call failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        Write-Host "  Check your API key with: Get-VBAFCenterClaudeAPIKey" -ForegroundColor Yellow
        return $null
    }

    # --------------------------------------------------------
    # Step 6 — Display result
    # --------------------------------------------------------
    $action      = [int]$claudeResponse.Action
    $actionName  = $claudeResponse.ActionName
    $reason      = $claudeResponse.Reason
    $instruction = $claudeResponse.Instruction
    $pattern     = $claudeResponse.Pattern
    $confidence  = $claudeResponse.Confidence

    $actionColors = @("Green","Yellow","DarkYellow","Red")
    $color        = $actionColors[$action]

    Write-Host ""
    Write-Host ("  Action     : {0} — {1}" -f $action, $actionName) -ForegroundColor $color
    Write-Host ("  Confidence : {0}" -f $confidence) -ForegroundColor White
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

    # --------------------------------------------------------
    # Step 7 — Save result to history
    # --------------------------------------------------------
    $result = [PSCustomObject]@{
        CustomerID       = $CustomerID
        Timestamp        = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
        Signals          = @($signals | ForEach-Object { $_.Normalised })
        AvgSignal        = [Math]::Round($weightedAvg, 4)
        WeightedAvg      = [Math]::Round($weightedAvg, 4)
        Action           = $action
        ActionName       = $actionName
        ActionCommand    = $instruction
        ActionReason     = $reason
        Pattern          = $pattern
        Confidence       = $confidence
        OverrideApplied  = ($redSignals.Count -gt 0)
        RedSignalCount   = $redSignals.Count
        YellowSignalCount = $yellowSignals.Count
        Source           = "Claude"
    }

    $histFile = Join-Path $historyPath "$CustomerID-$(Get-Date -Format 'yyyyMMdd_HHmmss_fff').json"
    if (-not (Test-Path $historyPath)) { New-Item -ItemType Directory -Path $historyPath -Force | Out-Null }
    $result | ConvertTo-Json -Depth 5 | Set-Content $histFile -Encoding UTF8

    # --------------------------------------------------------
    # Step 8 — Crisis response if Action 3
    # --------------------------------------------------------
    if ($action -ge 3) {
        Write-Host ""
        Write-Host "  [CRISIS] Claude recommends Escalate — activating crisis response!" -ForegroundColor Red
        Write-Host ""

        try {
            [Console]::Beep(800,  400)
            Start-Sleep -Milliseconds 100
            [Console]::Beep(1000, 400)
            Start-Sleep -Milliseconds 100
            [Console]::Beep(1500, 800)
        } catch {}

        try {
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing
            $form               = New-Object System.Windows.Forms.Form
            $form.Text          = "VBAF CRISIS — Claude Brain"
            $form.Size          = New-Object System.Drawing.Size(480, 280)
            $form.StartPosition = "CenterScreen"
            $form.TopMost       = $true
            $form.BackColor     = [System.Drawing.Color]::Red
            $label              = New-Object System.Windows.Forms.Label
            $label.Text         = ("KRISE DETEKTERET!`n`nKunde   : {0}`nHandling: {1}`n`nKlauds vurdering:`n{2}`n`nInstruktion:`n{3}`n`nKlik OK for at bekræfte." -f `
                                    $CustomerID, $actionName, $reason, $instruction)
            $label.ForeColor    = [System.Drawing.Color]::White
            $label.Font         = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Regular)
            $label.Size         = New-Object System.Drawing.Size(450, 200)
            $label.Location     = New-Object System.Drawing.Point(10, 10)
            $button             = New-Object System.Windows.Forms.Button
            $button.Text        = "OK — Jeg håndterer det"
            $button.Size        = New-Object System.Drawing.Size(200, 35)
            $button.Location    = New-Object System.Drawing.Point(130, 220)
            $button.BackColor   = [System.Drawing.Color]::White
            $button.ForeColor   = [System.Drawing.Color]::Red
            $button.Font        = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
            $button.Add_Click({ $form.Close() })
            $form.Controls.Add($label)
            $form.Controls.Add($button)
            $form.Add_Shown({ $form.Activate() })
            $form.ShowDialog() | Out-Null
        } catch {}

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
        Show recent Claude Brain decisions for a customer.
    .EXAMPLE
        Get-VBAFCenterClaudeBrainHistory -CustomerID "TruckCompanyDK"
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [int] $Last = 10
    )

    $historyPath = Join-Path $env:USERPROFILE "VBAFCenter\history"
    if (-not (Test-Path $historyPath)) {
        Write-Host "No history found." -ForegroundColor Yellow
        return
    }

    $files = Get-ChildItem $historyPath -Filter "$CustomerID-*.json" |
             Sort-Object LastWriteTime -Descending |
             Select-Object -First $Last

    $claudeOnly = @()
    foreach ($f in $files) {
        try {
            $h = Get-Content $f.FullName -Raw | ConvertFrom-Json
            if ($h.Source -eq "Claude") { $claudeOnly += $h }
        } catch {}
    }

    if ($claudeOnly.Count -eq 0) {
        Write-Host "No Claude Brain decisions found yet." -ForegroundColor Yellow
        Write-Host "Run: Invoke-VBAFCenterClaudeBrain -CustomerID '$CustomerID'" -ForegroundColor DarkGray
        return
    }

    Write-Host ""
    Write-Host ("Claude Brain History: {0} (last {1})" -f $CustomerID, $claudeOnly.Count) -ForegroundColor Cyan
    Write-Host ("  {0,-23} {1,-4} {2,-10} {3,-8} {4}" -f "Timestamp","Act","Name","Conf","Reason") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 85)) -ForegroundColor DarkGray

    foreach ($h in $claudeOnly) {
        $color = @("Green","Yellow","DarkYellow","Red")[[int]$h.Action]
        Write-Host ("  {0,-23} {1,-4} {2,-10} {3,-8} {4}" -f `
            $h.Timestamp, $h.Action, $h.ActionName, $h.Confidence,
            ($h.ActionReason -replace "`n"," " | ForEach-Object { if ($_.Length -gt 50) { $_.Substring(0,50) + "..." } else { $_ } })) -ForegroundColor $color
    }
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   VBAF-Center Phase 19 — Claude Brain           |" -ForegroundColor Cyan
Write-Host "  |   Real AI replaces the if-statement             |" -ForegroundColor Cyan
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Set-VBAFCenterClaudeAPIKey      — save your Anthropic API key"     -ForegroundColor White
Write-Host "  Invoke-VBAFCenterClaudeBrain    — full AI analysis per customer"   -ForegroundColor White
Write-Host "  Get-VBAFCenterClaudeBrainHistory — show recent AI decisions"       -ForegroundColor White
Write-Host ""

$apiKey = Get-VBAFCenterClaudeAPIKey
if ($apiKey) {
    Write-Host "  API key: configured" -ForegroundColor Green
} else {
    Write-Host "  API key: NOT configured" -ForegroundColor Yellow
    Write-Host "  Run: Set-VBAFCenterClaudeAPIKey -APIKey 'sk-ant-xxxx'" -ForegroundColor DarkGray
}
Write-Host ""

<#

SETUP — once only:

Step 1 — Get your Anthropic API key:
Go to https://console.anthropic.com — create an account if needed — copy your API key (starts with sk-ant-)

Step 2 — Save the file from ISE:
Save as C:\Users\henni\OneDrive\WindowsPowerShell\VBAF-Center\VBAF.Center.ClaudeBrain.ps1

Step 3 — Save your API key:
powershellcd "C:\Users\henni\OneDrive\WindowsPowerShell"
. .\VBAF-Center\VBAF.Center.ClaudeBrain.ps1
Set-VBAFCenterClaudeAPIKey -APIKey "sk-ant-xxxx"

DAILY USE — the two options:

Option A — Manual run (testing and demos):
powershellcd "C:\Users\henni\OneDrive\WindowsPowerShell"
. .\VBAF-Center\VBAF.Center.LoadAll.ps1
. .\VBAF-Center\VBAF.Center.ClaudeBrain.ps1
Invoke-VBAFCenterClaudeBrain -CustomerID "TruckCompanyDK"

Option B — Automatic 24/7 via Scheduler:
The Scheduler already calls Invoke-VBAFCenterRun every 10 minutes. You have two choices:

Choice 1 — Replace the brain entirely:
Edit VBAF.Center.Scheduler.ps1 — replace the Invoke-VBAFCenterRoute call with Invoke-VBAFCenterClaudeBrain. Claude makes every decision.

Choice 2 — Run both in parallel (recommended to start):
Keep the existing scheduler running as before. Add a second scheduler that calls Claude every 30 minutes. Compare the two decisions. Trust builds.

PRODUCTION SETUP — 4 consoles:

Console 1 — Scheduler (rule-based, every 10 min)
  Start-VBAFCenterSchedule -CustomerID "TruckCompanyDK"

Console 2 — Portal
  Start-VBAFCenterPortal

Console 3 — Dashboard
  Start-VBAFCenterDashboard

Console 4 — Claude Brain (every 30 min manually or via loop)
  while ($true) {
    Invoke-VBAFCenterClaudeBrain -CustomerID "TruckCompanyDK"
    Start-Sleep -Seconds 1800
  }

REVIEWING DECISIONS:

See what Claude decided recently:
powershellGet-VBAFCenterClaudeBrainHistory -CustomerID "TruckCompanyDK"
Compare Claude vs rule-based in run history:
powershellGet-VBAFCenterRunHistory -CustomerID "TruckCompanyDK"
History rows with Source: Claude are AI decisions. Rows without are rule-based.

COST ESTIMATE:

Each Invoke-VBAFCenterClaudeBrain call uses roughly 800-1200 tokens.
Every 30 min = 48 calls per day per customer
48 calls × 1000 tokens = 48.000 tokens per day
At Claude Sonnet pricing ≈ DKK 1-2 per day per customer
At 10 customers ≈ DKK 10-20 per day = DKK 300-600 per month
Well within what you charge for monthly subscription. 🙂

IF SOMETHING GOES WRONG:

Claude API unreachable:
powershellInvoke-VBAFCenterClaudeBrain -CustomerID "TruckCompanyDK" -Verbose
Shows the full prompt and exact error message.
API key expired or invalid:
powershellSet-VBAFCenterClaudeAPIKey -APIKey "sk-ant-new-key"
Claude returns garbage JSON:
The -Verbose flag shows exactly what Claude returned so you can debug the prompt.

THE MIGRATION PATH:

Today      : Rule-based every 10 min  (what you have now)
Week 1-2   : Claude every 30 min      (parallel — compare decisions)
Month 2    : Claude every 10 min      (Claude is the brain)
Month 3+   : Rule-based as fallback only (Claude primary)
Never remove the rule-based engine entirely — it is your safety net if the API is down.  

#>