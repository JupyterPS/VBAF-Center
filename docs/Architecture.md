# VBAF-Center Architecture

## The 8-Phase Pipeline
`
Customer Problem
       |
       v
Phase 1: Customer Profile
  - Store company info, contact, business type
       |
       v
Phase 2: Problem Classification
  - Keyword matching maps problem to correct AI agent
       |
       v
Phase 3: Signal Acquisition
  - Connect to data source (Simulated / REST / CSV / Manual)
       |
       v
Phase 4: Normalisation
  - Scale raw values to 0-100 for AI processing
       |
       v
Phase 5: Agent Router
  - Load the correct VBAF agent for this customer
       |
       v
Phase 6: Action Interpreter
  - Translate AI decision number to plain business language
       |
       v
Phase 7: Customer Onboarding UI
  - Interactive wizard - no code needed
       |
       v
Phase 8: Scheduling Engine
  - Run automatically every 5 / 10 / 30 minutes
`

## Agent Map

| Domain               | Agent                 | Phase |
|----------------------|-----------------------|-------|
| IT Infrastructure    | SelfHealing           | 14    |
| IT Security          | AnomalyDetector       | 18    |
| IT Operations        | IncidentResponder     | 20    |
| Business Logistics   | FleetDispatch         | 28    |
| Business Health      | HealthcareMonitor     | 29    |
| Business Finance     | SecurityMonitor       | 30    |
| Business Mfg         | PredictiveMaintenance | 31    |
| Business Retail      | SupplyChain           | 32    |

## Data Flow
`
Raw Signal --> Normalise --> Agent --> Action Number --> Business Instruction
`

## Repositories

| Repo                    | Purpose                        |
|-------------------------|--------------------------------|
| VBAF                    | The AI engine - 27 pillars     |
| VBAF-Center             | The customer gateway - 8 phases|
| VBAF-Center-Customers   | Private customer configs       |


