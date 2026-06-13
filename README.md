# VBAF-Center — Smart Monitoring Platform

**v1.0.33 · PowerShell 5.1 · AI-powered · Built on VBAF v4.0.0**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1-blue.svg)](https://microsoft.com/powershell)
[![VBAF](https://img.shields.io/badge/VBAF-v4.0.0-green.svg)](https://www.powershellgallery.com/packages/VBAF)

---

## What is VBAF-Center?

VBAF-Center is a smart monitoring platform for logistics and fleet operations.
It reads live signals from your GPS and TMS systems every 10 minutes, compares
them against customer-defined thresholds, and tells your dispatcher exactly what
to do — in plain Danish.

On top of the rule-based engine, an AI Brain (Mistral, Gemini, Claude) reads
30 days of history, spots patterns the rules cannot see, and produces a daily
HTML briefing that opens in the browser before the first truck leaves the depot.

> **The rule engine catches the problem. The AI Brain explains why it keeps happening.**

---

## The Honest Description

VBAF-Center has two engines running side by side:

**Engine A — Rule-based (every 10 minutes)**
- Reads signals
- Applies weighted average + thresholds
- Returns action 0-3 instantly
- Free, no API key needed
- Cannot explain why. Cannot spot trends.

**Engine B — AI Brain (every 30 minutes)**
- Reads the same signals PLUS 30 days of history
- Calls Mistral (free tier) or any supported provider
- Returns action + plain Danish reason + dispatcher instruction + pattern
- Spots "Thursday is always your worst day"
- Learns from dispatcher overrides over time

Neither engine replaces the dispatcher. Both make the dispatcher faster.

---

## The Fire Alarm Analogy

VBAF-Center is a smart fire alarm for your business — with 4 sounds instead of one.

```
Monitor  = soft beep        — everything normal
Reassign = warning tone     — something needs attention
Reroute  = loud siren       — act now
Escalate = full alarm       — call a human immediately
                              + crisis tree activates automatically
                              + sound alarm fires
                              + portal shows Accept/Override buttons
```

---

## How It Works

```
Your systems (GPS, TMS, ERP...)
         |
         | live signals every 10 minutes
         v
+------------------------------------------------------------+
|                  VBAF-Center v1.0.33                       |
|                                                            |
|  Phase 1-8:   Signal pipeline (read, normalise, decide)    |
|  Phase 9:     Web portal — Accept/Override buttons         |
|  Phase 13:    Crisis response tree — customer-specific     |
|  Phase 14:    Signal colours — Green/Yellow/Red per signal |
|  Phase 15:    Weighted signals — importance 1-5            |
|  Phase 16:    Learning engine — learns from overrides      |
|  Phase 17:    Smart action map — per customer sensitivity  |
|  Phase 18:    Write-back — sends command to TMS            |
|  Phase 19:    AI Brain — Mistral/Gemini/Claude             |
|  Briefing:    HTML daily briefing — opens in browser       |
+------------------------------------------------------------+
         |
         | Rule-based: action in YOUR language
         | AI Brain:   reason + instruction + pattern
         v
Dispatcher sees portal — clicks Accept — TMS executes
"Flyt ledig lastbil til næste levering i Køge"

Daily briefing opens at 07:00:
"Torsdag er typisk din værste dag.
 Signal3 og Signal7 er altid dårlige sammen.
 Pre-positioner DK-4471 i Køge inden kl. 13:00."
```

---

## Quick Start

```powershell
# Install
Install-Module VBAF -Scope CurrentUser
Install-Module VBAF-Center -Scope CurrentUser

# Load
cd "C:\Users\yourname\OneDrive\WindowsPowerShell"
. .\VBAF-Center\VBAF.Center.LoadAll.ps1

# Onboard first customer
Start-VBAFCenterOnboarding

# Run pipeline
Invoke-VBAFCenterRun -CustomerID "YourCustomerID"

# Start portal
Start-VBAFCenterPortal

# Set up AI Brain (free Mistral key)
# Get key at: https://console.mistral.ai/api-keys
Set-VBAFCenterAIKey -Provider "Mistral" -APIKey "your-key"
Invoke-VBAFCenterClaudeBrain -CustomerID "YourCustomerID" -Provider "Mistral"

# Generate daily briefing
Export-VBAFCenterDailyBriefing -CustomerID "YourCustomerID" -OpenBrowser
```

---

## All 19 Phases + Daily Briefing

| Phase | Name | Key Function | What it does |
|---|---|---|---|
| 1 | Customer Profile | New-VBAFCenterCustomer | WHO are you |
| 2 | Problem Classification | Get-VBAFCenterClassification | WHAT is your problem |
| 3 | Signal Acquisition | New-VBAFCenterSignalConfig | WHERE is your data — REST/CSV/WMI/Simulated |
| 4 | Normalisation | Invoke-VBAFCenterNormalise | **AUTOMATIC** — runs inside Invoke-VBAFCenterRun |
| 5 | Agent Router | Invoke-VBAFCenterRoute | Route to right agent |
| 6 | Action Interpreter | New-VBAFCenterActionMap | Translate action to business command |
| 7 | Onboarding UI | Start-VBAFCenterOnboarding | Interactive 7-step setup wizard |
| 8 | Scheduling Engine | Start-VBAFCenterSchedule | Check every 10 minutes automatically |
| 9 | Web Portal | Start-VBAFCenterPortal | Browser dashboard with Accept/Override buttons |
| 10 | Auto-Connector | Start-VBAFCenterAutoConnect | Connect any system in minutes |
| 11 | Dashboard | Start-VBAFCenterDashboard | All customers on one screen |
| 12 | Billing Engine | New-VBAFCenterInvoice | Automatic monthly invoices |
| 13 | Crisis Response Tree | Start-VBAFCenterCrisis | Customer-specific step-by-step recovery |
| 14 | Signal Thresholds | Get-VBAFCenterSignalStatus | Green/Yellow/Red per signal |
| 15 | Weighted Signals | (built into Phase 3/5/8) | Signal importance 1-5 |
| 16 | Learning Engine | Invoke-VBAFCenterLearnFromHistory | Learns from dispatcher overrides |
| 17 | Smart Action Map | Set-VBAFCenterActionThresholds | Customer-specific sensitivity |
| 18 | Write-back | Invoke-VBAFCenterWriteBack | Sends command directly to TMS |
| 19 | AI Brain | Invoke-VBAFCenterClaudeBrain | Multi-provider AI — reasons in Danish |
| — | Daily Briefing | Export-VBAFCenterDailyBriefing | HTML report — opens in browser at 07:00 |

---

## AI Brain — Supported Providers

| Provider | Free | Model | Get Key |
|---|---|---|---|
| Mistral | FREE | mistral-small-latest | https://console.mistral.ai/api-keys |
| Gemini | FREE | gemini-2.0-flash | https://aistudio.google.com/app/apikey |
| Groq | FREE | llama-3.3-70b | https://console.groq.com/keys |
| OpenRouter | FREE | deepseek-r1:free | https://openrouter.ai/keys |
| Claude | Paid | claude-sonnet-4 | https://console.anthropic.com |

```powershell
# Save key once — persists across sessions
Set-VBAFCenterAIKey -Provider "Mistral" -APIKey "your-key"

# Test connection
Test-VBAFCenterAIProvider -Provider "Mistral"

# Run AI analysis
Invoke-VBAFCenterClaudeBrain -CustomerID "NordLogistik" -Provider "Mistral"

# Run in loop — suppresses crisis wizard
while ($true) {
    Invoke-VBAFCenterClaudeBrain -CustomerID "NordLogistik" -Provider "Mistral" -SuppressCrisis
    Start-Sleep -Seconds 1800
}
```

---

## Portal Buttons — What Is New in v1.0.33

The web portal now has two buttons below every recommendation:

**Accept** — dispatcher clicks Accept → `Invoke-VBAFCenterWriteBack` fires automatically → TMS receives the command. No typing required.

**Override** — dispatcher clicks Override → small form appears → dispatcher picks their action and types a reason → `Start-VBAFCenterOverride` logs it → AI Brain learns from it next run.

**Threshold suggestion** — when the Learning Engine has a suggestion, the portal shows it with Yes/No buttons. Yes applies immediately. No dismisses for 7 days.

---

## Daily Briefing — What Is New in v1.0.33

```powershell
# Generate once
Export-VBAFCenterDailyBriefing -CustomerID "NordLogistik" -OpenBrowser

# Run AI first then generate
Export-VBAFCenterDailyBriefing -CustomerID "NordLogistik" -RunAIFirst -OpenBrowser

# Auto-generate every morning at 07:00
while ($true) {
    if ((Get-Date).Hour -eq 7 -and (Get-Date).Minute -eq 0) {
        Export-VBAFCenterDailyBriefing -CustomerID "NordLogistik" -RunAIFirst -OpenBrowser
        Start-Sleep -Seconds 61
    }
    Start-Sleep -Seconds 30
}
```

The briefing contains:
- Summary cards — total runs, average signal, max red signals, AI runs
- Dominant action badge
- AI Brain latest assessment — action, reason, instruction, pattern
- Signal status grid — all signals with colour bars
- Action distribution — last 24 hours
- AI decision log — today's Mistral decisions in plain Danish

---

## The Right Customer for VBAF Today

**YES:**
- Has GPS trackers on vehicles (Webfleet, Trackunit, Keatech, Geotab)
- Has someone whose job is to watch the numbers
- Frustrated that they find out about problems too late
- 10-50 vehicles

**NOT YET:**
- Small company with no GPS, no TMS, no systems
- Companies where manual daily input is required

---

## Commercial Model

| Complexity | Signals | Onboarding | Monthly |
|---|---|---|---|
| Simple | 2 | DKK 15.000 | DKK 3.000 |
| Standard | 4 | DKK 18.000 | DKK 4.500 |
| Advanced | 6 | DKK 22.000 | DKK 6.000 |
| Full | 10 | DKK 25.000 | DKK 8.000 |

---

## Production Console Setup

```
Console 1 — Scheduler (rule-based every 10 min)
  Start-VBAFCenterSchedule -CustomerID "NordLogistik"

Console 2 — AI Brain (every 30 min)
  while ($true) {
      Invoke-VBAFCenterClaudeBrain -CustomerID "NordLogistik" -Provider "Mistral" -SuppressCrisis
      Start-Sleep -Seconds 1800
  }

Console 3 — Portal
  Start-VBAFCenterPortal

Console 4 — Fake TMS (write-back demo)
  Start-VBAFFakeTMS

Console 5 — Morning briefing at 07:00
  while ($true) {
      if ((Get-Date).Hour -eq 7 -and (Get-Date).Minute -eq 0) {
          Export-VBAFCenterDailyBriefing -CustomerID "NordLogistik" -RunAIFirst -OpenBrowser
          Start-Sleep -Seconds 61
      }
      Start-Sleep -Seconds 30
  }
```

---

## Requirements

- Windows 10 or 11
- PowerShell 5.1
- VBAF v4.0.0 (`Install-Module VBAF`)
- Free Mistral API key for AI Brain (optional but recommended)

---

## License

MIT License — see LICENSE for details.

---

## Author

**Henning — Roskilde, Denmark** 🇩🇰

Built with Claude (Anthropic) · PowerShell ISE · PS 5.1

> *"The rule engine catches it. The AI Brain explains why it keeps happening."*


