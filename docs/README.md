# VBAF-Center Documentation

## Overview
VBAF-Center is the customer gateway for the VBAF Framework.
It connects real business problems to the right AI agent automatically.

## The 8 Phases

| Phase | Name                  | Function                              |
|-------|-----------------------|---------------------------------------|
| 1     | Customer Profile      | Create and manage customer profiles   |
| 2     | Problem Classification| Map problems to the right AI agent    |
| 3     | Signal Acquisition    | Connect to data sources               |
| 4     | Normalisation         | Prepare signals for AI processing     |
| 5     | Agent Router          | Route signals to the correct agent    |
| 6     | Action Interpreter    | Translate AI decisions to plain text  |
| 7     | Customer Onboarding   | Interactive setup wizard              |
| 8     | Scheduling Engine     | Run automatically on a schedule       |

## Quick Start
`powershell
Install-Module VBAF-Center
. .\VBAF.Center.LoadAll.ps1
Start-VBAFCenterOnboarding
`

## Documentation Files
- [Getting Started](GettingStarted.md)
- [Architecture](Architecture.md)
