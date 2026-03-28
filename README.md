# VBAF-Center — Welcome Center

> The hospital that connects your business problems to the right AI doctor.

## What is VBAF-Center?

VBAF-Center is the gateway between your business systems and VBAF trained agents.
It receives your live data, normalises it, routes it to the right agent,
and returns the action in your own business language.

## The Medical Analogy
```
Your business data  = Patient arriving at hospital
VBAF-Center        = Triage nurse
VBAF Agent         = Specialist doctor
Your system        = Pharmacy filling the prescription
```

## The 8 Phases

| Phase | Name | What it does |
|-------|------|-------------|
| 1 | Customer Profile | WHO are you? |
| 2 | Problem Classification | WHAT is your emergency? |
| 3 | Signal Acquisition | WHERE is your data? |
| 4 | Normalisation | HOW BAD is it? |
| 5 | Agent Router | Sending the right doctor |
| 6 | Action Interpreter | What did the doctor say? |
| 7 | Customer Onboarding UI | Set up once, run forever |
| 8 | Scheduling Engine | How often to check? |

## Relationship to VBAF
```
VBAF         = The doctors (AI engine) — free, open source
VBAF-Center  = The hospital (welcome & routing) — commercial service
```

VBAF does not change.
VBAF-Center is a separate product that uses VBAF.

## Requirements

- Windows 10 or 11
- PowerShell 5.1
- VBAF v4.0.0 or higher (`Install-Module VBAF`)

## Installation
```powershell
Install-Module VBAF
Install-Module VBAF-Center
. .\VBAF-Center\VBAF.Center.LoadAll.ps1
```

## Author

Henning · Roskilde, Denmark 🇩🇰
Built with Claude (Anthropic) · PowerShell ISE · PS 5.1

*"Tell us your problem. We know the right doctor."*
