#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Sync + Publish in one command
.DESCRIPTION
    Syncs all VBAF.Center.*.ps1 files from root to subfolder,
    bumps the version automatically and publishes to PSGallery.

    Usage:
    . .\VBAF.Center.Publish.ps1
    Publish-VBAFCenter
#>

function Publish-VBAFCenter {

    $src  = "C:\Users\henni\OneDrive\WindowsPowerShell\VBAF-Center"
    $dest = "C:\Users\henni\OneDrive\WindowsPowerShell\VBAF-Center\VBAF-Center"

    Write-Host ""
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   VBAF-Center Sync + Publish             |" -ForegroundColor Cyan
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    # Step 1 — Sync all ps1 files from root to subfolder
    Write-Host "  Step 1/3 — Syncing files..." -ForegroundColor Yellow
    Get-ChildItem $src -Filter "VBAF.Center.*.ps1" | ForEach-Object {
        Copy-Item $_.FullName $dest -Force
        Write-Host ("    Synced: {0}" -f $_.Name) -ForegroundColor Green
    }
    Write-Host ""

    # Step 2 — Bump version automatically
    Write-Host "  Step 2/3 — Bumping version..." -ForegroundColor Yellow
    $psd1    = Join-Path $dest "VBAF-Center.psd1"
    $content = Get-Content $psd1 -Raw
    $current = [regex]::Match($content, "ModuleVersion = '([\d.]+)'").Groups[1].Value
    $parts   = $current -split '\.'
    $parts[2] = [int]$parts[2] + 1
    $newVersion = $parts -join '.'
    ($content -replace "ModuleVersion = '$current'", "ModuleVersion = '$newVersion'") |
        Set-Content $psd1 -Encoding UTF8
    Write-Host ("    Version: {0} -> {1}" -f $current, $newVersion) -ForegroundColor Cyan
    Write-Host ""

    # Step 3 — Publish to PSGallery
    Write-Host "  Step 3/3 — Publishing to PSGallery..." -ForegroundColor Yellow
    $key = Read-Host "  API Key"
    Publish-Module -Path $dest -NuGetApiKey $key
    Write-Host ""
    Write-Host "  Published! Version $newVersion live on PSGallery." -ForegroundColor Green
    Write-Host ""

    # Reminder to Git
    Write-Host "  Remember to Git:" -ForegroundColor Yellow
    Write-Host "  cd '$src'" -ForegroundColor White
    Write-Host "  git add VBAF.Center.*.ps1 VBAF-Center/VBAF-Center.psd1" -ForegroundColor White
    Write-Host ("  git commit -m 'Release v{0}'" -f $newVersion) -ForegroundColor White
    Write-Host "  git push origin master" -ForegroundColor White
    Write-Host ""
}

Write-Host ""
Write-Host "  VBAF-Center Publish Tool loaded." -ForegroundColor Cyan
Write-Host "  Run: Publish-VBAFCenter" -ForegroundColor Green
Write-Host ""