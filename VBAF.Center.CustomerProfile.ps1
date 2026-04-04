#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 1 — Customer Profile
.DESCRIPTION
    Manages customer profiles for the VBAF Welcome Center.
    Each customer has a profile that identifies who they are,
    what problem they are solving and which VBAF agent handles it.

    Functions:
      New-VBAFCenterCustomer     — create a new customer profile
      Get-VBAFCenterCustomer     — retrieve a customer profile
      Get-VBAFCenterAllCustomers — list all customer profiles
      Update-VBAFCenterCustomer  — update an existing profile
      Remove-VBAFCenterCustomer  — remove a customer profile
#>

# ============================================================
# INITIALISE CUSTOMER STORE
# ============================================================
$script:CustomerStorePath = Join-Path $env:USERPROFILE "VBAFCenter\customers"

function Initialize-VBAFCenterCustomerStore {
    if (-not (Test-Path $script:CustomerStorePath)) {
        New-Item -ItemType Directory -Path $script:CustomerStorePath -Force | Out-Null
        Write-Host "Customer store created: $($script:CustomerStorePath)" -ForegroundColor Green
    }
}

# ============================================================
# NEW-VBAFCENTERCUSTOMER
# ============================================================
function New-VBAFCenterCustomer {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [Parameter(Mandatory)] [string] $CompanyName,
        [Parameter(Mandatory)] [string] $BusinessType,
        [Parameter(Mandatory)] [string] $Problem,
        [Parameter(Mandatory)] [string] $Agent,
        [string] $Country   = "Denmark",
        [Parameter(Mandatory)] [string] $Contact,
        [Parameter(Mandatory)] [string] $Notes
    )

    Initialize-VBAFCenterCustomerStore

    $profile = @{
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
    }

    $path = Join-Path $script:CustomerStorePath "$CustomerID.json"

    if (Test-Path $path) {
        Write-Host "Customer already exists: $CustomerID" -ForegroundColor Yellow
        Write-Host "Use Update-VBAFCenterCustomer to modify." -ForegroundColor Yellow
        return $null
    }

    $profile | ConvertTo-Json -Depth 5 | Set-Content $path -Encoding UTF8

    Write-Host ""
    Write-Host "Customer profile created!" -ForegroundColor Green
    Write-Host ("  CustomerID   : {0}" -f $profile.CustomerID)   -ForegroundColor White
    Write-Host ("  Company      : {0}" -f $profile.CompanyName)   -ForegroundColor White
    Write-Host ("  Business     : {0}" -f $profile.BusinessType)  -ForegroundColor White
    Write-Host ("  Problem      : {0}" -f $profile.Problem)       -ForegroundColor White
    Write-Host ("  Agent        : {0}" -f $profile.Agent)         -ForegroundColor White
    Write-Host ("  Status       : {0}" -f $profile.Status)        -ForegroundColor White
    Write-Host ""

    return $profile
}

# ============================================================
# GET-VBAFCENTERCUSTOMER
# ============================================================
function Get-VBAFCenterCustomer {
    param(
        [Parameter(Mandatory)] [string] $CustomerID
    )

    Initialize-VBAFCenterCustomerStore

    $path = Join-Path $script:CustomerStorePath "$CustomerID.json"

    if (-not (Test-Path $path)) {
        Write-Host "Customer not found: $CustomerID" -ForegroundColor Red
        return $null
    }

    $profile = Get-Content $path -Raw | ConvertFrom-Json

    Write-Host ""
    Write-Host "Customer Profile:" -ForegroundColor Cyan
    Write-Host ("  CustomerID   : {0}" -f $profile.CustomerID)   -ForegroundColor White
    Write-Host ("  Company      : {0}" -f $profile.CompanyName)   -ForegroundColor White
    Write-Host ("  Country      : {0}" -f $profile.Country)       -ForegroundColor White
    Write-Host ("  Business     : {0}" -f $profile.BusinessType)  -ForegroundColor White
    Write-Host ("  Problem      : {0}" -f $profile.Problem)       -ForegroundColor White
    Write-Host ("  Agent        : {0}" -f $profile.Agent)         -ForegroundColor White
    Write-Host ("  Contact      : {0}" -f $profile.Contact)       -ForegroundColor White
    Write-Host ("  Created      : {0}" -f $profile.CreatedDate)   -ForegroundColor White
    Write-Host ("  Status       : {0}" -f $profile.Status)        -ForegroundColor White
    Write-Host ""

    return $profile
}

# ============================================================
# GET-VBAFCENTERALLCUSTOMERS
# ============================================================
function Get-VBAFCenterAllCustomers {

    Initialize-VBAFCenterCustomerStore

    $files = Get-ChildItem $script:CustomerStorePath -Filter "*.json"

    if ($files.Count -eq 0) {
        Write-Host "No customers registered yet." -ForegroundColor Yellow
        return @()
    }

    Write-Host ""
    Write-Host "Registered Customers:" -ForegroundColor Cyan
    Write-Host ("  {0,-20} {1,-25} {2,-20} {3,-15} {4}" -f "CustomerID","Company","Business","Agent","Status") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 90)) -ForegroundColor DarkGray

    $customers = @()
    foreach ($file in $files) {
        $p = Get-Content $file.FullName -Raw | ConvertFrom-Json
        Write-Host ("  {0,-20} {1,-25} {2,-20} {3,-15} {4}" -f $p.CustomerID, $p.CompanyName, $p.BusinessType, $p.Agent, $p.Status) -ForegroundColor White
        $customers += $p
    }

    Write-Host ""
    Write-Host "  Total: $($customers.Count) customer(s)" -ForegroundColor White
    Write-Host ""

    return $customers
}

# ============================================================
# UPDATE-VBAFCENTERCUSTOMER
# ============================================================
function Update-VBAFCenterCustomer {
    param(
        [Parameter(Mandatory)] [string] $CustomerID
    )

    Initialize-VBAFCenterCustomerStore

    $path = Join-Path $script:CustomerStorePath "$CustomerID.json"

    if (-not (Test-Path $path)) {
        Write-Host "Customer not found: $CustomerID" -ForegroundColor Red
        return $null
    }

    $profile = Get-Content $path -Raw | ConvertFrom-Json

    Write-Host ""
    Write-Host "Current values for: $CustomerID" -ForegroundColor Cyan
    Write-Host "  Press Enter to keep current value." -ForegroundColor DarkGray
    Write-Host ""

    $fields = @("CompanyName","Country","BusinessType","Problem","Agent","Contact","Notes","Status")

    foreach ($field in $fields) {
        $current = $profile.$field
        $input = Read-Host "  $field [$current]"
        if ($input -ne "") { $profile.$field = $input }
    }

    $profile | ConvertTo-Json -Depth 5 | Set-Content $path -Encoding UTF8

    Write-Host ""
    Write-Host "Customer updated: $CustomerID" -ForegroundColor Green
    Write-Host ""
    return $profile
}

# ============================================================
# REMOVE-VBAFCENTERCUSTOMER
# ============================================================
function Remove-VBAFCenterCustomer {
    param(
        [Parameter(Mandatory)] [string] $CustomerID
    )

    Initialize-VBAFCenterCustomerStore

    $path = Join-Path $script:CustomerStorePath "$CustomerID.json"

    if (-not (Test-Path $path)) {
        Write-Host "Customer not found: $CustomerID" -ForegroundColor Red
        return
    }

    Remove-Item $path -Force
    Write-Host "Customer removed: $CustomerID" -ForegroundColor Yellow
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host "VBAF-Center Phase 1 loaded  [Customer Profile]" -ForegroundColor Cyan
Write-Host "  New-VBAFCenterCustomer      — create profile"  -ForegroundColor White
Write-Host "  Get-VBAFCenterCustomer      — retrieve profile" -ForegroundColor White
Write-Host "  Get-VBAFCenterAllCustomers  — list all"        -ForegroundColor White
Write-Host "  Update-VBAFCenterCustomer   — update profile"  -ForegroundColor White
Write-Host "  Remove-VBAFCenterCustomer   — remove profile"  -ForegroundColor White
Write-Host ""




