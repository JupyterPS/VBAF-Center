#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Phase 12 — Billing Engine
.DESCRIPTION
    Automatic monthly invoice generation per customer.
    Calculates usage, generates invoice as text file,
    ready to print or send.

    Functions:
      New-VBAFCenterInvoice        — generate invoice for one customer
      Get-VBAFCenterInvoiceHistory — show all invoices
      Get-VBAFCenterBillingSummary — show all customers billing status
#>

# ============================================================
# BILLING CONFIG
# ============================================================
$script:BillingConfig = @{
    CompanyName    = "VBAF Solutions"
    CompanyAddress = "Roskilde, Denmark"
    CompanyEmail   = "henning@vbaf.dk"
    CompanyPhone   = "+45 XXXX XXXX"
    CVR            = "XX XX XX XX"
    Currency       = "DKK"
    OnboardingFee  = 20000
    MonthlyFee     = 5000
    InvoicePath    = (Join-Path $env:USERPROFILE "VBAFCenter\invoices")
}

# ============================================================
# NEW-VBAFCENTERINVOICE
# ============================================================
function New-VBAFCenterInvoice {
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [string] $InvoiceType    = "Monthly",
        [int]    $MonthlyFee     = 0,
        [int]    $OnboardingFee  = 0,
        [string] $Notes          = ""
    )

    # Load customer profile
    $profilePath = Join-Path $env:USERPROFILE "VBAFCenter\customers\$CustomerID.json"
    if (-not (Test-Path $profilePath)) {
        Write-Host "Customer not found: $CustomerID" -ForegroundColor Red
        return
    }
    $profile = Get-Content $profilePath -Raw | ConvertFrom-Json

    # Set fees
    if ($MonthlyFee  -eq 0) { $MonthlyFee    = $script:BillingConfig.MonthlyFee  }
    if ($OnboardingFee -eq 0 -and $InvoiceType -eq "Onboarding") {
        $OnboardingFee = $script:BillingConfig.OnboardingFee
    }

    # Calculate totals
    $subtotal = $MonthlyFee + $OnboardingFee
    $vat      = [Math]::Round($subtotal * 0.25)
    $total    = $subtotal + $vat

    # Invoice number
    $invoiceNumber = "VBAF-{0}-{1}" -f (Get-Date -Format "yyyyMM"), ($CustomerID.Substring(0, [Math]::Min(4, $CustomerID.Length)).ToUpper())
    $invoiceDate   = (Get-Date).ToString("yyyy-MM-dd")
    $dueDate       = (Get-Date).AddDays(30).ToString("yyyy-MM-dd")
    $period        = (Get-Date).ToString("MMMM yyyy")

    # Build invoice text
    $invoice = @"
================================================================================
                           FAKTURA / INVOICE
================================================================================

Fra / From:
  $($script:BillingConfig.CompanyName)
  $($script:BillingConfig.CompanyAddress)
  Email : $($script:BillingConfig.CompanyEmail)
  Tlf   : $($script:BillingConfig.CompanyPhone)
  CVR   : $($script:BillingConfig.CVR)

Til / To:
  $($profile.CompanyName)
  Kontakt : $($profile.Contact)

--------------------------------------------------------------------------------
  Fakturanr.  / Invoice No. : $invoiceNumber
  Dato        / Date        : $invoiceDate
  Forfaldsdato/ Due Date    : $dueDate
  Periode     / Period      : $period
--------------------------------------------------------------------------------

YDELSER / SERVICES:

"@

    if ($OnboardingFee -gt 0) {
        $invoice += "  Onboarding — VBAF-Center opsaetning          DKK {0,10}`n" -f $OnboardingFee
        $invoice += "  Inkluderer: moder, signalkonfiguration,`n"
        $invoice += "  action map, shadow mode og go-live`n`n"
    }

    if ($MonthlyFee -gt 0) {
        $invoice += "  Maanedlig abonnement — $period               DKK {0,10}`n" -f $MonthlyFee
        $invoice += "  Inkluderer: AI-monitoring, anbefalinger,`n"
        $invoice += "  historik, support og opdateringer`n`n"
    }

    if ($Notes -ne "") {
        $invoice += "  Note: $Notes`n`n"
    }

    $invoice += @"
--------------------------------------------------------------------------------
  Subtotal ekskl. moms / Subtotal excl. VAT  : DKK $subtotal
  Moms 25% / VAT 25%                         : DKK $vat
  -----------------------------------------------------------------------
  TOTAL inkl. moms / TOTAL incl. VAT         : DKK $total
--------------------------------------------------------------------------------

Betalingsbetingelser / Payment Terms:
  Betales inden / Pay before : $dueDate
  Bank          : XXXX — Reg. XXXX Konto XXXXXXXXXX
  Reference     : $invoiceNumber

Tak for samarbejdet! / Thank you for your business!

================================================================================
  $($script:BillingConfig.CompanyName) · $($script:BillingConfig.CompanyAddress)
  VBAF-Center v1.0.2 · AI-drevet operations monitoring
================================================================================
"@

    # Save invoice
    $invoicePath = $script:BillingConfig.InvoicePath
    if (-not (Test-Path $invoicePath)) {
        New-Item -ItemType Directory -Path $invoicePath -Force | Out-Null
    }

    $invoiceFile = Join-Path $invoicePath "$invoiceNumber.txt"
    $invoice | Set-Content $invoiceFile -Encoding UTF8

    # Display summary
    Write-Host ""
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   VBAF-Center Invoice Generated          |" -ForegroundColor Cyan
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host ("  |  Invoice No : {0,-27}|" -f $invoiceNumber)           -ForegroundColor White
    Write-Host ("  |  Customer   : {0,-27}|" -f $profile.CompanyName)     -ForegroundColor White
    Write-Host ("  |  Period     : {0,-27}|" -f $period)                  -ForegroundColor White
    Write-Host ("  |  Subtotal   : DKK {0,-24}|" -f $subtotal)            -ForegroundColor White
    Write-Host ("  |  VAT 25%    : DKK {0,-24}|" -f $vat)                 -ForegroundColor White
    Write-Host ("  |  TOTAL      : DKK {0,-24}|" -f $total)               -ForegroundColor Green
    Write-Host ("  |  Due date   : {0,-27}|" -f $dueDate)                 -ForegroundColor White
    Write-Host ("  |  Saved to   : {0,-27}|" -f "$invoiceNumber.txt")     -ForegroundColor Yellow
    Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("  Full invoice: {0}" -f $invoiceFile) -ForegroundColor DarkGray
    Write-Host ""

    return $invoiceFile
}

# ============================================================
# GET-VBAFCENTERINVOICEHISTORY
# ============================================================
function Get-VBAFCenterInvoiceHistory {

    $invoicePath = $script:BillingConfig.InvoicePath

    if (-not (Test-Path $invoicePath)) {
        Write-Host "No invoices found yet." -ForegroundColor Yellow
        return
    }

    $invoices = Get-ChildItem $invoicePath -Filter "*.txt" | Sort-Object LastWriteTime -Descending

    Write-Host ""
    Write-Host "  VBAF-Center Invoice History" -ForegroundColor Cyan
    Write-Host ("  {0,-30} {1,-20} {2}" -f "Invoice", "Date", "File") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 70)) -ForegroundColor DarkGray

    foreach ($inv in $invoices) {
        Write-Host ("  {0,-30} {1,-20} {2}" -f $inv.BaseName, $inv.LastWriteTime.ToString("yyyy-MM-dd"), $inv.Name) -ForegroundColor White
    }

    Write-Host ""
    Write-Host ("  Total invoices: {0}" -f $invoices.Count) -ForegroundColor White
    Write-Host ""
}

# ============================================================
# GET-VBAFCENTERBILLINGSUMMARY
# ============================================================
function Get-VBAFCenterBillingSummary {

    Write-Host ""
    Write-Host "  VBAF-Center Billing Summary" -ForegroundColor Cyan
    Write-Host ("  {0,-20} {1,-25} {2,-15} {3}" -f "CustomerID","Company","Monthly DKK","Status") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 75)) -ForegroundColor DarkGray

    $storePath = Join-Path $env:USERPROFILE "VBAFCenter\customers"
    $totalMonthly = 0

    if (Test-Path $storePath) {
        Get-ChildItem $storePath -Filter "*.json" | ForEach-Object {
            $p = Get-Content $_.FullName -Raw | ConvertFrom-Json
            if (-not $p.CustomerID) { return }
            $monthly = $script:BillingConfig.MonthlyFee
            $totalMonthly += $monthly
            Write-Host ("  {0,-20} {1,-25} {2,-15} {3}" -f $p.CustomerID, $p.CompanyName, $monthly, $p.Status) -ForegroundColor White
        }
    }

    Write-Host ("  {0}" -f ("-" * 75)) -ForegroundColor DarkGray
    Write-Host ("  Total monthly revenue : DKK {0}" -f $totalMonthly) -ForegroundColor Green
    Write-Host ("  Total annual revenue  : DKK {0}" -f ($totalMonthly * 12)) -ForegroundColor Green
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |  VBAF-Center Phase 12 - Billing Engine   |" -ForegroundColor Cyan
Write-Host "  |  Automatic invoice generation            |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  New-VBAFCenterInvoice        — generate invoice"        -ForegroundColor White
Write-Host "  Get-VBAFCenterInvoiceHistory — show all invoices"       -ForegroundColor White
Write-Host "  Get-VBAFCenterBillingSummary — show billing overview"   -ForegroundColor White
Write-Host ""
Write-Host "  Quick start:" -ForegroundColor Yellow
Write-Host "  New-VBAFCenterInvoice -CustomerID 'NordLogistik' -InvoiceType 'Monthly'" -ForegroundColor Green
Write-Host ""