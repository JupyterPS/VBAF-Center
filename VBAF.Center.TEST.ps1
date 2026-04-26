. (Join-Path $basePath "VBAF-Center\VBAF.Center.Publish.ps1")                 # GIT
Publish-VBAFCenter

. (Join-Path $basePath "VBAF-Center\VBAF.Center.LoadAll.ps1")

Phase 1 — Customer profile
New-VBAFCenterCustomer	            First time you onboard a new customer	    Once per customer         Purple Once per customer — setup only
Get-VBAFCenterCustomer	            Look up one customer's details	            When needed               Amber When needed — you decide             
Get-VBAFCenterAllCustomers	        See all customers at a glance	            When needed               Amber When needed — you decide
Update-VBAFCenterCustomer	        Customer changes contact, agent or problem	Rarely                    Amber When needed — you decide
Remove-VBAFCenterCustomer	        Customer leaves or test cleanup	            Rarely                    Amber When needed — you decide 
 
Phase 2 — Problem classification
Get-VBAFCenterClassification	    Check which agent was auto-selected	        After onboarding          Purple Once per customer — setup only
Get-VBAFCenterAgentMap	            See all available agents and domains	    When needed               Amber When needed — you decide 
Set-VBAFCenterAgentMap  	        Add a new domain not in the default list	Rarely                    Amber When needed — you decide 
                                    
Phase 3 — Signal acquisition        
New-VBAFCenterSignalConfig	        Define a signal source for a customer	    Once per signal           Purple Once per customer — setup only 
Get-VBAFCenterSignal	            Check one live signal value	                When needed               Amber When needed — you decide 
Get-VBAFCenterAllSignals	        See all signals for a customer	            When needed               Amber When needed — you decide 
Test-VBAFCenterSignalConfig	        Verify signals are reading correctly	    After setup               Purple Once per customer — setup only
                                    
Phase 4 — Normalisation             
Invoke-VBAFCenterNormalise	        Scale raw values to 0-1 for the AI	        Automatic in pipeline     Green Daily / automatic — runs itself
Get-VBAFCenterNormalisationReport	See detailed normalisation results	        When debugging            Amber When needed — you decide 
                                                                                Methods:                  MinMax | Standard | Robust | PassThrough
Phase 5 — Agent router                                                          
Invoke-VBAFCenterRoute	            Route signals to the correct agent	        Automatic in pipeline     Green Daily / automatic — runs itself
Register-VBAFCenterAgent	        Register a trained agent manually	        Once per customer         Purple Once per customer — setup only
Get-VBAFCenterRouteStatus	        Check which agents are loaded	            When debugging            Amber When needed — you decide 
                                    
Phase 6 — Action interpreter        
New-VBAFCenterActionMap	            Define business language for each action	Once per customer         Purple Once per customer — setup only
Invoke-VBAFCenterInterpret	        Translate action number to plain text	    Automatic in pipeline     Green Daily / automatic — runs itself
Get-VBAFCenterActionMap 	        Review customer's action definitions	    When needed               Amber When needed — you decide 
                                    
Phase 7 — Onboarding wizard         
Start-VBAFCenterOnboarding	        Full setup of a new customer in one go	    Once per customer         Purple Once per customer — setup only
Show-VBAFCenterSummary  	        Review what is configured for a customer	When needed               Amber When needed — you decide 
                                    
Phase 8 — Scheduling engine         
Invoke-VBAFCenterRun    	        Run the full pipeline once manually	        Testing / demo            Amber When needed — you decide 
Start-VBAFCenterSchedule	        Start automatic checking on a schedule	    Shadow / go-live          Green Daily / automatic — runs itself  
Get-VBAFCenterRunHistory	        Review recent AI recommendations	        Weekly review             Green Daily / automatic — runs itself
                                    
Phases 9-12 — Advanced              
Start-VBAFCenterPortal  	        Show one customer their live dashboard	    Meetings / demos          Green Daily / automatic — runs itself
Start-VBAFCenterDashboard	        Your overview of all customers at once	    Daily monitoring          Green Daily / automatic — runs itself
Start-VBAFCenterAutoConnect	        Connect a real data source for a customer	Once per customer         Purple Once per customer — setup only
New-VBAFCenterInvoice	            Generate monthly invoice for a customer  	Monthly                   Light greenMonthly — billing cycle

. "VBAF-Center\VBAF.Center.Assessment.ps1" Run ALL 4 BEFORE every onboarding FOR NEED  Once per customer  Purple Once per customer — setup only
. "VBAF-Center\VBAF.Center.TMSSimulator.ps1"
. "VBAF-Center\VBAF.Center.TMSSimulator.Standard.ps1"
. "VBAF-Center\VBAF.Center.TMSSimulator.Advanced.ps1"
. "VBAF-Center\VBAF.Center.TMSSimulator.Full.ps1"    
. "VBAF-Center\VBAF.Center.APIInspector.ps1"                                                              
. "VBAF-Center\VBAF.Center.GPSInspector.ps1"  
. "VBAF-Center\VBAF-Center\VBAF.Center.FakeTMS.ps1"                                                            
Start-VBAFCenterOnboarding covers all Purple setup functions in one go


#___________________________________ RESET FILES IN BETWEEN TEST'S ________________________________________________

# Clean reset — removes all test customers and their data
$base = "$env:USERPROFILE\VBAFCenter"

# Remove all customer profiles
Remove-Item "$base\customers\*.json"    -Force -ErrorAction SilentlyContinue
# Remove all signal configs
Remove-Item "$base\signals\*.json"      -Force -ErrorAction SilentlyContinue
# Remove all action maps
Remove-Item "$base\actions\*.txt"       -Force -ErrorAction SilentlyContinue
Remove-Item "$base\actions\*.json"      -Force -ErrorAction SilentlyContinue
# Remove all schedules
Remove-Item "$base\schedules\*.json"    -Force -ErrorAction SilentlyContinue
# Remove all history
Remove-Item "$base\history\*.json"      -Force -ErrorAction SilentlyContinue
# Remove all invoices
Remove-Item "$base\invoices\*.txt"      -Force -ErrorAction SilentlyContinue

Write-Host "Clean slate — all test data removed!" -ForegroundColor Green

. "VBAF-Center\VBAF.Center.LoadAll.ps1"
Get-VBAFCenterAllCustomers              # CHECK    


<#___________________ ALLE NEDENSTÅENDE DATA ER AT FINDE PÅ GITHUB VBAF-CENTER (PAGES)__________________

CustomerID   : TruckCompanyDK
CompanyName  : Truck Company DK
Country      : Denmark
BusinessType : Logistics
Problem      : Too many idle trucks and late deliveries
Agent        : FleetDispatch
Contact      : ceo@truckcompanydk.dk
Notes        : First test customer

        CustomerID   = $CustomerID
        CompanyName  = $CompanyName
        Country      = $Country
        BusinessType = $BusinessType
        Problem      = $Problem
        Agent        = $Agent
        Contact      = $Contact
        Notes        = $Notes
        CreatedDate  = (Get-Date).ToString("yyyy-MM-dd")
        Status       = "Active"
        Version      = "1.0" 


TESTING PHASE 1-8 (PROMPT ARGUMENTS)

>>>>>>>>>>>>>>>>>>>>>>@ Get-VBAFCenterCustomer
cmdlet Get-VBAFCenterCustomer at command pipeline position 1
Supply values for the following parameters:
CustomerID: TruckCompanyDK

Customer Profile:
  CustomerID   : TruckCompanyDK
  Company      : Truck Company DK
  Country      : Denmark
  Business     : Logistics
  Problem      : Too many idle trucks and late deliveries
  Agent        : FleetDispatch
  Contact      : ceo@truckcompanydk.dk
  Created      : 2026-04-03
  Status       : Active

Contact      : ceo@truckcompanydk.dk
Agent        : FleetDispatch
Version      : 1.0
CustomerID   : TruckCompanyDK
Notes        : Third test customer
Problem      : Too many idle trucks and late deliveries
CreatedDate  : 2026-04-03
Status       : Active
BusinessType : Logistics
CompanyName  : Truck Company DK
Country      : Denmark

__________________


>>>>>>>>>>>>>>>>>>>>>>>>>>@ Get-VBAFCenterAllCustomers

Contact      : ceo@TruckCompanyDK.dk
Agent        : FleetDispatch
Version      : 1.0
CustomerID   : TruckCompanyDK
Notes        : 
Problem      : Fleet dispatch optimisation
CreatedDate  : 2026-03-28
Status       : Active
BusinessType : Logistics
CompanyName  : TruckCompanyDK A/S
Country      : Denmark

Contact      : ceo@truckcompanydk.dk
Agent        : FleetDispatch
Version      : 1.0
CustomerID   : TruckCompanyDK
Notes        : Third test customer
Problem      : Too many idle trucks and late deliveries
CreatedDate  : 2026-04-03
Status       : Active
BusinessType : Logistics
CompanyName  : Truck Company DK
Country      : Denmark

________Phase 2 ____________________________

>>>>>>>>>>>>>>>>>>>>>>>>>>@ Get-VBAFCenterClassification
cmdlet Get-VBAFCenterClassification at command pipeline position 1
Supply values for the following parameters:
CustomerID: TruckCompanyDK

Problem Classification:
  Customer     : TruckCompanyDK
  Problem      : Too many idle trucks and late deliveries
  Keyword      : logistics
  Class        : BUSINESS-LOGISTICS-FLEET
  Agent        : FleetDispatch
  Phase        : 28
  Description  : Fleet dispatch optimisation

Name                           Value                                           
----                           -----                                           
ClassificationCode             BUSINESS-LOGISTICS-FLEET                        
CustomerID                     TruckCompanyDK                                  
Description                    Fleet dispatch optimisation                     
Phase                          28                                              
MatchedKeyword                 logistics                                       
ProblemText                    Too many idle trucks and late deliveries        
RecommendedAgent               FleetDispatch 

______________Phase 3 ____________________

>>>>>>>>>>>>>>>> New-VBAFCenterSignalConfig

CustomerID  : TruckCompanyDK
SignalName  : On-Time Delivery
SignalIndex : Signal2
SourceType  : Simulated
RawMin      : 0
RawMax      : 100


______________Phase 4 ____________________


>>>>>> Invoke-VBAFCenterNormalise        — normalise signals

CustomerID  : TruckCompanyDK
RawSignals[0]: 27.0
RawSignals[1]: 64.0
RawSignals[2]: [just press Enter]


______________Phase 5 ____________________

>>>>>>>>>>>>>  Invoke-VBAFCenterRoute      — route signals to agent

CustomerID         : TruckCompanyDK
NormalisedSignals[0]: 0.27
NormalisedSignals[1]: 0.64
NormalisedSignals[2]: [just press Enter]

>>>>>>>>>>>>>>>>  Register-VBAFCenterAgent

CustomerID  : TruckCompanyDK
AgentName : FleetDispatch
Agent     : [just press Enter]

______________Phase 6 ____________________

>>>>>>>>>>>>>>>>  New-VBAFCenterActionMap    — define action meanings

CustomerID     : TruckCompanyDK
Action0Name    : Monitor
Action0Command : Watch and log — fleet healthy
Action1Name    : Reassign
Action1Command : Move idle truck to pending delivery
Action2Name    : Reroute
Action2Command : Switch to faster route
Action3Name    : Escalate
Action3Command : Call operations manager immediately

>>>>>>>>>>>>   Invoke-VBAFCenterInterpret — translate action number 

CustomerID   : TruckCompanyDK
ActionNumber : 1

>>>>>>>>>>>  Get-VBAFCenterActionMap

CustomerID : TruckCompanyDK

______________Phase 7____________________

>>>>>>>>>  Start-VBAFCenterOnboarding  — full setup wizard

Press ENTER to start         : [just press Enter]
Customer ID                  : TruckCompanyDK2
Company name                 : Truck Company DK
Country                      : Denmark
Business type                : Logistics
Problem                      : Too many idle trucks and late deliveries
Contact email                : ceo@truckcompanydk.dk
Accept agent? (Y/N)          : N
Manual agent                 : FleetDispatch
Signal 1 name                : Empty Driving
Source type                  : Simulated
Raw minimum value            : 0
Raw maximum value            : 100
Signal 2 name                : On-Time Delivery
Source type                  : Simulated
Raw minimum value            : 0
Raw maximum value            : 100
Signal 3 name                : [just press Enter]
Signal 4 name                : [just press Enter]
Normalisation method         : MinMax
Action 0 name                : Monitor
Action 0 command             : Watch and log — fleet healthy
Action 1 name                : Reassign
Action 1 command             : Move idle truck to pending delivery
Action 2 name                : Reroute
Action 2 command             : Switch to faster route
Action 3 name                : Escalate
Action 3 command             : Call operations manager immediately

>>>>>>  >>>>   Show-VBAFCenterSummary      — show customer setup

CustomerID : TruckCompanyDK2

______________Phase 8 ____________________

>>>>   Invoke-VBAFCenterRun         — run pipeline once

CustomerID : TruckCompanyDK2


>>>>>  Start-VBAFCenterSchedule

CustomerID : TruckCompanyDK2
MaxRuns    : 3

__________________________________________

CLEAN-UP:  

Remove-VBAFCenterCustomer -CustomerID "TruckCompanyDK"
Remove-VBAFCenterCustomer -CustomerID "TruckCompanyDK2"
Get-VBAFCenterAllCustomers

#>

#_______________________________ CONNECTION SYSTEMS DATA ____________________

<#

# VBAF-Center — Source Types Reference
## The 7 ways VBAF connects to customer data

---

## Decision Tree — Which Source Type?

  Has GPS trackers?
    YES → Use GPS Inspector (preferred)
    NO  ↓
  Has REST API?
    YES → Source type: REST (use API Inspector to find fields)
    NO  ↓
  Exports CSV/Excel daily?
    YES → Source type: CSV
    NO  ↓
  Windows IT infrastructure?
    YES → Source type: WMI
    NO  ↓
  No system at all?
    → Source type: Simulated (demo only)
    → Manual possible but unreliable in practice

---

## 1. TMS-Generic — Any system with a REST API

  Signal name    : Empty Driving
  SourceType     : REST
  SourceURL      : https://tms.company.dk/api/idle
  JSONPath       : (use API Inspector to find — may be needed)
  Raw minimum    : 0
  Raw maximum    : 100

  Notes:
  → Ask IT department for REST API documentation
  → Use Invoke-VBAFCenterAPIInspector to inspect the response
  → JSONPath required if response is nested JSON
  → GPS Inspector covers most fleet GPS systems

---

## 2. TMS-Navision — Microsoft Dynamics

  Signal name    : Fleet Utilisation
  SourceType     : REST
  SourceURL      : https://nav.company.dk/api/fleet
  JSONPath       : (use API Inspector to find)
  Raw minimum    : 0
  Raw maximum    : 100

  Notes:
  → Navision (Microsoft Dynamics 365 Business Central) has OData REST endpoints built in
  → Requires Azure AD authentication + API key
  → Authentication is more complex than simple GPS systems
  → Use GPS Inspector Generic option or API Inspector
  → Ask their IT department for the Business Central API URL and credentials
  → Complexity: ⚠️ Medium

---

## 3. TMS-SAP — SAP Transportation

  Signal name    : Load Factor
  SourceType     : REST
  SourceURL      : https://sap.company.dk/api/load
  JSONPath       : (use API Inspector to find)
  Raw minimum    : 0
  Raw maximum    : 100

  Notes:
  → SAP TM exposes REST via SAP API Management
  → Requires formal API access request — typically takes weeks to approve
  → Usually only found at large enterprise companies
  → Not realistic for small/medium companies
  → Complexity: ⚠️ High — not recommended for first customers

---

## 4. Excel-CSV — File Export

  Signal name    : Empty Driving
  SourceType     : CSV
  CSVPath        : C:\Data\fleet.csv
  CSVColumn      : EmptyDriving
  Raw minimum    : 0
  Raw maximum    : 100

  Notes:
  → Customer exports daily CSV from their system
  → File must be on a path VBAF can access (local or network drive)
  → VBAF reads the LAST row of the CSV each run
  → Customer must save/overwrite the file before each VBAF run
  → Works reliably if customer has a scheduled export
  → Unreliable if customer must do it manually every day

  New-VBAFCenterSignalConfig `
    -CustomerID  "CompanyName" `
    -SignalName  "Empty Driving" `
    -SignalIndex "Signal1" `
    -SourceType  "CSV" `
    -CSVPath     "C:\Data\fleet.csv" `
    -CSVColumn   "EmptyDriving" `
    -RawMin      0 `
    -RawMax      100

---

## 5. Manual — No System

  Signal name    : Empty Driving
  SourceType     : Manual
  Raw minimum    : 0
  Raw maximum    : 100

  Notes:
  → Customer types the number themselves each run
  → No API, no file, no automation needed
  → ⚠️ UNRELIABLE IN PRACTICE
  → Customers rarely do manual input consistently
  → Works in theory — breaks down in practice after 1-2 weeks
  → Only use as last resort or for short-term testing
  → Better to wait until customer gets GPS than rely on manual input

---

## 6. Windows-IT — WMI Infrastructure

  Signal name    : CPU Load
  SourceType     : WMI
  WMIClass       : Win32_Processor
  WMIProperty    : LoadPercentage
  Raw minimum    : 0
  Raw maximum    : 100

  Notes:
  → For IT customers — reads Windows system data directly
  → ⚠️ IMPORTANT: WMI only works on same network or VPN
  → Does NOT work over the internet without VPN
  → Requires Windows Firewall to allow WMI (port 135)
  → Requires admin credentials for their server

  Useful WMI combinations:
  | Signal          | WMIClass                | WMIProperty       | RawMax       |
  |-----------------|-------------------------|-------------------|--------------|
  | CPU Load %      | Win32_Processor         | LoadPercentage    | 100          |
  | Disk Free %     | Win32_LogicalDisk       | PercentFreeSpace  | 100          |
  | Memory Free KB  | Win32_OperatingSystem   | FreePhysicalMemory| Total KB     |

  ⚠️ FreeSpace (bytes) is NOT the same as PercentFreeSpace (%)
  Always use PercentFreeSpace for disk — not FreeSpace

  New-VBAFCenterSignalConfig `
    -CustomerID  "SkoleIT" `
    -SignalName  "CPU Load" `
    -SignalIndex "Signal1" `
    -SourceType  "WMI" `
    -WMIClass    "Win32_Processor" `
    -WMIProperty "LoadPercentage" `
    -RawMin      0 `
    -RawMax      100

---

## 7. Simulated — Demo and Shadow Mode

  Signal name    : Empty Driving
  SourceType     : Simulated
  Raw minimum    : 0
  Raw maximum    : 100

  Notes:
  → No real data source needed
  → VBAF generates realistic random values automatically
  → Values change every run — by design
  → Use during: demo, shadow mode, testing, onboarding
  → Always start with Simulated — replace with REST when GPS API ready
  → The 4 TMS simulators use this source type

---

## Summary Table

| # | Source Type | When to use | Reliability | Complexity |
|---|-------------|-------------|-------------|------------|
| 1 | REST (GPS)  | Has GPS with API | ✅ Excellent | Low with Inspector |
| 2 | REST (Navision) | Microsoft Dynamics | ⚠️ Medium | Medium |
| 3 | REST (SAP) | SAP enterprise | ⚠️ Complex | High |
| 4 | CSV | Daily file export | ✅ Good if automated | Low |
| 5 | Manual | No system at all | ❌ Unreliable | Low |
| 6 | WMI | Windows IT servers | ✅ Good on VPN | Medium |
| 7 | Simulated | Demo and testing | ✅ Always works | Zero |
#>