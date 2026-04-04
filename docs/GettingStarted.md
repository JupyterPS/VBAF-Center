# Getting Started with VBAF-Center

## Installation
`powershell
Install-Module VBAF
Install-Module VBAF-Center
`

## First Run
`powershell
. .\VBAF.Center.LoadAll.ps1
Start-VBAFCenterOnboarding
`

## Onboarding a New Customer
Step 1 - Run the wizard and fill in from your meeting notes:
`powershell
Start-VBAFCenterOnboarding
`

Step 2 - Configure their signals (start simulated):
`powershell
New-VBAFCenterSignalConfig -CustomerID "CompanyName" -SignalName "Empty Driving" -SignalIndex "Signal1" -SourceType "Simulated" -RawMin 0 -RawMax 100
`

Step 3 - Configure their action map:
`powershell
New-VBAFCenterActionMap -CustomerID "CompanyName" -Action0Name "Monitor" -Action0Command "Watch and log" -Action1Name "Reassign" -Action1Command "Move driver to busier route" -Action2Name "Reroute" -Action2Command "Find alternative route" -Action3Name "Escalate" -Action3Command "Call operations manager"
`

Step 4 - Run first demo:
`powershell
Invoke-VBAFCenterRun -CustomerID "CompanyName"
Get-VBAFCenterRunHistory -CustomerID "CompanyName"
`

Step 5 - Start shadow mode:
`powershell
Start-VBAFCenterSchedule -CustomerID "CompanyName" -MaxRuns 48
`

## Timeline
| Week    | Action                        |
|---------|-------------------------------|
| Day 1   | First meeting - listen        |
| Day 2   | Wizard + simulated demo       |
| Week 1-2| Connect real data source      |
| Week 3-6| Shadow mode - daily results   |
| Month 2 | Go live - AI recommends       |
| Month 3+| Full autonomy - measure ROI   |


