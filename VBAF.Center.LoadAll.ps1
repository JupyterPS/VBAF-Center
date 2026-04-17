#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center — Load All Modules
.DESCRIPTION
    Loads all 13 VBAF-Center phases in the correct order.
    Run this before using any VBAF-Center functions.
#>
$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Phase 1 — Customer Profile
. (Join-Path $basePath "VBAF.Center.CustomerProfile.ps1")
# Phase 2 — Problem Classification
. (Join-Path $basePath "VBAF.Center.Classification.ps1")
# Phase 3 — Signal Acquisition
. (Join-Path $basePath "VBAF.Center.SignalAcquisition.ps1")
# Phase 4 — Normalisation
. (Join-Path $basePath "VBAF.Center.Normalisation.ps1")
# Phase 5 — Agent Router
. (Join-Path $basePath "VBAF.Center.Router.ps1")
# Phase 6 — Action Interpreter
. (Join-Path $basePath "VBAF.Center.Interpreter.ps1")
# Phase 7 — Customer Onboarding UI
. (Join-Path $basePath "VBAF.Center.OnboardingUI.ps1")
# Phase 8 — Scheduling Engine
. (Join-Path $basePath "VBAF.Center.Scheduler.ps1")
# Phase 9 — Web Portal
. (Join-Path $basePath "VBAF.Center.WebPortal.ps1")
# Phase 10 — Auto-Connector
. (Join-Path $basePath "VBAF.Center.AutoConnector.ps1")
# Phase 11 — Multi-Customer Dashboard
. (Join-Path $basePath "VBAF.Center.Dashboard.ps1")
# Phase 12 — Billing Engine
. (Join-Path $basePath "VBAF.Center.Billing.ps1")
# Phase 13 — Crisis Response Tree
. (Join-Path $basePath "VBAF.Center.CrisisTree.ps1")

Write-Host ""
Write-Host "╔═════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         VBAF-Center v1.0.9 — Ready                 ║" -ForegroundColor Cyan
Write-Host "║         Welcome Center for VBAF Agents             ║" -ForegroundColor Cyan
Write-Host "╠═════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║  Phase 1  Customer Profile       — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 2  Problem Classification — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 3  Signal Acquisition     — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 4  Normalisation          — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 5  Agent Router           — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 6  Action Interpreter     — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 7  Customer Onboarding UI — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 8  Scheduling Engine      — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 9  Web Portal             — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 10 Auto-Connector         — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 11 Multi-Customer Dashboard — loaded        ║" -ForegroundColor White
Write-Host "║  Phase 12 Billing Engine         — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 13 Crisis Response Tree   — loaded          ║" -ForegroundColor Red
Write-Host "╠═════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║  Quick start:                                       ║" -ForegroundColor White
Write-Host "║  Start-VBAFCenterOnboarding                        ║" -ForegroundColor Yellow
Write-Host "║  Invoke-VBAFCenterRun -CustomerID 'TruckCompanyDK' ║" -ForegroundColor Yellow
Write-Host "║  Start-VBAFCenterPortal                            ║" -ForegroundColor Yellow
Write-Host "║  Start-VBAFCenterDashboard                         ║" -ForegroundColor Yellow
Write-Host "║  Start-VBAFCenterCrisis -CustomerID 'Company'     ║" -ForegroundColor Red
Write-Host "╚═════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""






