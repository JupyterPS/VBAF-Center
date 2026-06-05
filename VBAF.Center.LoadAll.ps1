#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center — Load All Modules
.DESCRIPTION
    Loads all VBAF-Center phases in the correct order.
    Run this before using any VBAF-Center functions.

    NOTE: FakeTMS must run in its own separate console:
    . .\VBAF-Center\VBAF.Center.FakeTMS.ps1
    Start-VBAFFakeTMS

    NOTE: ClaudeBrain requires an API key:
    Set-VBAFCenterAIKey -Provider "Mistral" -APIKey "XXXX"
#>
$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Phase 1 — Customer Profile
. (Join-Path $basePath "VBAF.Center.CustomerProfile.ps1")
# Phase 2 — Problem Classification
. (Join-Path $basePath "VBAF.Center.Classification.ps1")
# Phase 3 — Signal Acquisition (Phase 14 Thresholds + Phase 15 Weights)
. (Join-Path $basePath "VBAF.Center.SignalAcquisition.ps1")
# Phase 4 — Normalisation (AUTOMATIC — runs inside Invoke-VBAFCenterRun)
. (Join-Path $basePath "VBAF.Center.Normalisation.ps1")
# Phase 5 — Agent Router (Phase 14 Overrides + Phase 15 Weights + Phase 17 Thresholds)
. (Join-Path $basePath "VBAF.Center.Router.ps1")
# Phase 6 — Action Interpreter
. (Join-Path $basePath "VBAF.Center.Interpreter.ps1")
# Phase 7 — Customer Onboarding UI (7 steps)
. (Join-Path $basePath "VBAF.Center.OnboardingUI.ps1")
# Phase 8 — Scheduling Engine (Phase 14/15/17 pipeline)
. (Join-Path $basePath "VBAF.Center.Scheduler.ps1")
# Phase 9 — Web Portal (Accept/Override buttons + threshold suggestion)
. (Join-Path $basePath "VBAF.Center.WebPortal.ps1")
# Phase 10 — Auto-Connector
. (Join-Path $basePath "VBAF.Center.AutoConnector.ps1")
# Phase 11 — Multi-Customer Dashboard
. (Join-Path $basePath "VBAF.Center.Dashboard.ps1")
# Phase 12 — Billing Engine
. (Join-Path $basePath "VBAF.Center.Billing.ps1")
# Phase 13 — Crisis Response Tree (customer-specific trees)
. (Join-Path $basePath "VBAF.Center.CrisisTree.ps1")
# Phase 14/15 — Signal Thresholds and Weights (built into SignalAcquisition.ps1, Phase 3)
# Assessment
. (Join-Path $basePath "VBAF.Center.Assessment.ps1")
# Phase 16 — Learning Engine
. (Join-Path $basePath "VBAF.Center.LearningEngine.ps1")
# Phase 17 — Smart Action Map
. (Join-Path $basePath "VBAF.Center.ActionThresholds.ps1")
# Phase 18 — Write-back (TMS integration)
. (Join-Path $basePath "VBAF.Center.WriteBack.ps1")
# Phase 19 — AI Brain (multi-provider: Claude, Gemini, Groq, OpenRouter, Mistral)
. (Join-Path $basePath "VBAF.Center.ClaudeBrain.ps1")
# Daily Briefing — HTML report for dispatcher
. (Join-Path $basePath "VBAF.Center.DailyBriefing.ps1")

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       VBAF-Center v1.0.36 — Ready                   ║" -ForegroundColor Cyan
Write-Host "║       Smart Monitoring — Powered by AI              ║" -ForegroundColor Cyan
Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║  Phase 1  Customer Profile        — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 2  Problem Classification  — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 3  Signal Acquisition      — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 4  Normalisation           — AUTOMATIC       ║" -ForegroundColor White
Write-Host "║  Phase 5  Agent Router            — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 6  Action Interpreter      — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 7  Customer Onboarding UI  — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 8  Scheduling Engine       — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 9  Web Portal              — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 10 Auto-Connector          — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 11 Multi-Customer Dashboard — loaded         ║" -ForegroundColor White
Write-Host "║  Phase 12 Billing Engine          — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 13 Crisis Response Tree    — loaded          ║" -ForegroundColor White
Write-Host "║  Phase 14 Signal Thresholds       — loaded          ║" -ForegroundColor Cyan
Write-Host "║  Phase 15 Weighted Signals        — loaded          ║" -ForegroundColor Cyan
Write-Host "║  Phase 16 Learning Engine         — loaded          ║" -ForegroundColor Cyan
Write-Host "║  Phase 17 Smart Action Map        — loaded          ║" -ForegroundColor Cyan
Write-Host "║  Phase 18 Write-back              — loaded          ║" -ForegroundColor Cyan
Write-Host "║  Assessment           — loaded                      ║
║  Phase 19 AI Brain (multi-provider) — loaded        ║" -ForegroundColor Green
Write-Host "║  Daily Briefing HTML              — loaded          ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║  Quick start:                                        ║" -ForegroundColor White
Write-Host "║  Start-VBAFCenterOnboarding                         ║" -ForegroundColor Yellow
Write-Host "║  Invoke-VBAFCenterRun -CustomerID 'NordLogistik'    ║" -ForegroundColor Yellow
Write-Host "║  Start-VBAFCenterPortal                             ║" -ForegroundColor Yellow
Write-Host "║  Start-VBAFCenterDashboard                          ║" -ForegroundColor Yellow
Write-Host "║  Export-VBAFCenterDailyBriefing -CustomerID 'X' -OpenBrowser ║" -ForegroundColor Yellow
Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║  AI Brain (needs API key):                           ║" -ForegroundColor White
Write-Host "║  Set-VBAFCenterAIKey -Provider 'Mistral' -APIKey '' ║" -ForegroundColor Green
Write-Host "║  Invoke-VBAFCenterClaudeBrain -CustomerID 'X'       ║" -ForegroundColor Green
Write-Host "║  Invoke-VBAFCenterClaudeBrain -CustomerID 'X' -SuppressCrisis ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║  Separate consoles:                                  ║" -ForegroundColor White
Write-Host "║  . .\VBAF-Center\VBAF.Center.FakeTMS.ps1            ║" -ForegroundColor DarkGray
Write-Host "║  Start-VBAFFakeTMS                                  ║" -ForegroundColor DarkGray
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""