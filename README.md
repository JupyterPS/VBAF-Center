# VBAF-Center — Welcome Center

**v1.0.24 · PowerShell 5.1 · Enterprise AI Gateway · Built on VBAF v4.0.0**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1-blue.svg)](https://microsoft.com/powershell)
[![VBAF](https://img.shields.io/badge/VBAF-v4.0.0-green.svg)](https://www.powershellgallery.com/packages/VBAF)

---

## What is VBAF-Center?

VBAF-Center is the commercial gateway between your business systems and the VBAF AI agent engine. It receives your live data, normalises it, routes it to the right trained agent, and returns the action in your own business language.

> **VBAF trains the doctors. VBAF-Center runs the hospital.**

---

## The Medical Analogy

```
Your business data  = Patient arriving at hospital
VBAF-Center        = Triage nurse
VBAF Agent         = Specialist doctor
Your system        = Pharmacy filling the prescription
```

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
                              + red popup stays until dismissed
```

---

## How It Works

```
Your systems (GPS, TMS, ERP, SAP...)
         |
         | live signals every 10 minutes
         v
+--------------------------------------------------+
|              VBAF-Center v1.0.24                 |
|                                                  |
|  Phase 1:  WHO are you                           |
|  Phase 2:  WHAT is the problem                  |
|  Phase 3:  WHERE is your data                   |
|  Phase 4:  Normalise to 0.0-1.0                 |
|  Phase 5:  Route to right agent                 |
|  Phase 6:  Interpret action                     |
|  Phase 7:  Onboarding UI                        |
|  Phase 8:  Schedule checks                      |
|  Phase 9:  Web portal — browser dashboard       |
|  Phase 10: Auto-connector — any system          |
|  Phase 11: Multi-customer dashboard             |
|  Phase 12: Billing — automatic invoices         |
|  Phase 13: Crisis response tree                 |
|  Phase 14: Signal thresholds — per signal       |
|  Phase 15: Weighted signals — importance 1-5    |
|  Phase 16: Learning engine — gets smarter       |
|  Phase 17: Smart action map — per customer      |
|  Phase 18: Write-back — VBAF now acts           |
+--------------------------------------------------+
         |
         | action in YOUR language
         v
Dispatcher reads portal — acts on recommendation
"Flyt ledig lastbil til næste levering i Køge"

Phase 18: VBAF sends command directly to TMS
"Truck DK-4471 assigned to job J-3001. ETA 16:23."
```

---

## Quick Start

```powershell
# Install VBAF engine first
Install-Module VBAF -Scope CurrentUser

# Install VBAF-Center
Install-Module VBAF-Center -Scope CurrentUser

# Load everything
cd "C:\Users\henni\OneDrive\WindowsPowerShell"
. .\VBAF-Center\VBAF.Center.LoadAll.ps1

# Onboard your first customer (interactive wizard)
Start-VBAFCenterOnboarding

# Run the pipeline
Invoke-VBAFCenterRun -CustomerID "YourCustomerID"

# Start portal (separate console)
Start-VBAFCenterPortal

# Start dashboard (separate console)
Start-VBAFCenterDashboard
```

---

## All 18 Phases

| Phase | Name | Key Function | What it does |
|---|---|---|---|
| 1 | Customer Profile | New-VBAFCenterCustomer | WHO are you |
| 2 | Problem Classification | Get-VBAFCenterClassification | WHAT is your emergency |
| 3 | Signal Acquisition | New-VBAFCenterSignalConfig | WHERE is your data — REST/WMI/CSV/Simulated |
| 4 | Normalisation | Invoke-VBAFCenterNormalise | Convert raw figures to 0.0-1.0 |
| 5 | Agent Router | Invoke-VBAFCenterRoute | Send to the right VBAF doctor |
| 6 | Action Interpreter | New-VBAFCenterActionMap | Translate action to business command |
| 7 | Customer Onboarding UI | Start-VBAFCenterOnboarding | Interactive setup wizard |
| 8 | Scheduling Engine | Start-VBAFCenterSchedule | Check every 10 minutes automatically |
| 9 | Web Portal | Start-VBAFCenterPortal | Browser dashboard — token protected |
| 10 | Auto-Connector | Start-VBAFCenterAutoConnect | Connect any system in minutes |
| 11 | Multi-Customer Dashboard | Start-VBAFCenterDashboard | All customers on one screen |
| 12 | Billing Engine | New-VBAFCenterInvoice | Automatic monthly invoices |
| 13 | Crisis Response Tree | Start-VBAFCenterCrisis | Step-by-step recovery wizard |
| 14 | Signal Thresholds | Get-VBAFCenterSignalStatus | Green/Yellow/Red per signal |
| 15 | Weighted Signals | (built into Phase 3/5/8) | Signal importance 1-5 |
| 16 | Learning Engine | Invoke-VBAFCenterLearnFromHistory | Gets smarter from dispatcher overrides |
| 17 | Smart Action Map | Set-VBAFCenterActionThresholds | Customer-specific sensitivity |
| 18 | Write-back | Invoke-VBAFCenterWriteBack | VBAF now acts — not just advises |

---

## What is New in v1.0.24

**Phase 14 — Signal Thresholds**
Every signal now has a colour — Green, Yellow or Red — based on customer-defined thresholds.
A single RED signal overrides the average and raises the action level automatically.

**Phase 15 — Weighted Signals**
Each signal gets a weight from 1 to 5. Critical signals count more.
Weighted average used for all decisions instead of simple average.

**Phase 16 — Learning Engine**
Dispatcher overrides are logged and analysed.
After 30 days of real data — VBAF suggests threshold improvements.
Agreement rate tracked over time — VBAF gets smarter the longer you use it.

**Phase 17 — Smart Action Map**
Each customer gets their own action sensitivity thresholds.
A relaxed small operation and a high-pressure logistics hub no longer get the same settings.
Calibrated from real override data via Phase 16.

**Phase 18 — Write-back**
VBAF now acts — not just advises.
Mode A: dispatcher approves, TMS executes automatically.
Full audit log with 5-minute rollback window.
Fake TMS included for testing and demos without a real customer system.

---

## NordLogistik — Proof of Concept

```
Problem  : Trucks idle 30%, late deliveries, lost biggest client
Signals  : Fleet idle rate + Delivery urgency
Agent    : VBAF FleetDispatch (Phase 28)
Result   : +97% improvement over random dispatcher

Action 0 : Monitor   — Fleet healthy, watch and wait
Action 1 : Reassign  — Move idle truck to pending delivery
Action 2 : Reroute   — Switch to faster routes
Action 3 : Escalate  — Emergency, deploy all trucks
```

**Key message:**
> "VBAF caught it at 13:34. Your dispatcher would have noticed at 14:30.
> That is 56 minutes earlier. What can go wrong in 56 minutes?"

---

## Available VBAF Agents

| Domain | Agent | Phase |
|---|---|---|
| IT Infrastructure | SelfHealing | 14 |
| Anomaly Detection | AnomalyDetector | 18 |
| Incident Response | IncidentResponder | 20 |
| Full Automation | AutoPilot | 27 |
| Fleet Dispatch | FleetDispatch | 28 |
| Healthcare | HealthcareMonitor | 29 |
| Finance | SecurityMonitor | 30 |
| Manufacturing | PredictiveMaintenance | 31 |
| Retail | SupplyChain | 32 |

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
- IT companies (already have Datadog, Prometheus etc)

---

## Commercial Model

| Complexity | Score | Signals | Onboarding | Monthly |
|---|---|---|---|---|
| Simple | 8-15 | 2 | DKK 15.000 | DKK 3.000 |
| Standard | 16-25 | 4 | DKK 18.000 | DKK 4.500 |
| Advanced | 26-32 | 6 | DKK 22.000 | DKK 6.000 |
| Full | 33-40 | 10 | DKK 25.000 | DKK 8.000 |

```
VBAF         — free, open source, PSGallery
VBAF-Center  — commercial service

Onboarding   : one-time setup fee
Running      : monthly subscription per customer
Custom pillars: project rate DKK 20.000-40.000
```

---

## Relationship to VBAF

VBAF-Center uses VBAF as its AI engine. VBAF does not change — it is the stable foundation. VBAF-Center is the commercial layer on top.

```powershell
Install-Module VBAF          # the doctors
Install-Module VBAF-Center   # the hospital
```

---

## Requirements

- Windows 10 or 11
- PowerShell 5.1
- VBAF v4.0.0 (`Install-Module VBAF`)

---

## Production Workflow

```
Console 1 -> Start-VBAFCenterSchedule -CustomerID "X"   (runs 24/7)
Console 2 -> Start-VBAFCenterPortal                      (customer access)
Console 3 -> Start-VBAFCenterDashboard                   (your overview)
Console 4 -> Start-VBAFFakeTMS                           (write-back demo)

Never run in ISE — always PowerShell console windows.
```

---

## License

MIT License — see LICENSE for details.

---

## Author

**Henning — Roskilde, Denmark** 🇩🇰

Built with Claude (Anthropic) · PowerShell ISE · PS 5.1

> *"Tell us your problem. We know the right doctor."*