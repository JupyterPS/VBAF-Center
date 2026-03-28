#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center — Load All Modules
.DESCRIPTION
    Loads all VBAF-Center modules in the correct order.
    Run this before using any VBAF-Center functions.
#>

$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Phase 1 — Customer Profile
# . (Join-Path $basePath "VBAF.Center.CustomerProfile.ps1")

# Phase 2 — Problem Classification
# . (Join-Path $basePath "VBAF.Center.Classification.ps1")

# Phase 3 — Signal Acquisition
# . (Join-Path $basePath "VBAF.Center.SignalAcquisition.ps1")

# Phase 4 — Normalisation
# . (Join-Path $basePath "VBAF.Center.Normalisation.ps1")

# Phase 5 — Agent Router
# . (Join-Path $basePath "VBAF.Center.Router.ps1")

# Phase 6 — Action Interpreter
# . (Join-Path $basePath "VBAF.Center.Interpreter.ps1")

# Phase 7 — Customer Onboarding UI
# . (Join-Path $basePath "VBAF.Center.OnboardingUI.ps1")

# Phase 8 — Scheduling Engine
# . (Join-Path $basePath "VBAF.Center.Scheduler.ps1")

Write-Host ""
Write-Host "VBAF-Center ready!" -ForegroundColor Cyan
Write-Host "  Version : v1.0.0" -ForegroundColor White
Write-Host "  Phases  : 8 planned, 0 built" -ForegroundColor White
Write-Host "  Docs    : github.com/JupyterPS/VBAF-Center" -ForegroundColor White
Write-Host ""
