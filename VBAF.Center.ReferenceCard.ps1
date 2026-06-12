#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center — Reference Card Generator
.DESCRIPTION
    Generates a printable A4 landscape PDF reference card
    for a customer showing all signal thresholds in Green/Yellow/Red.

    Reads directly from the customer's signal JSON files —
    always matches what VBAF is actually configured to use.

    Functions:
      Export-VBAFCenterReferenceCard  — generate PDF wall card for a customer
#>

function Export-VBAFCenterReferenceCard {
    <#
    .SYNOPSIS
        Generate a printable signal reference card for a customer.
    .EXAMPLE
        Export-VBAFCenterReferenceCard -CustomerID "NordLogistik"
        Export-VBAFCenterReferenceCard -CustomerID "NordLogistik" -OpenBrowser
    #>
    param(
        [Parameter(Mandatory)] [string] $CustomerID,
        [switch] $OpenBrowser
    )

    # ── Check Python available ────────────────────────────────
    $python = $null
    foreach ($cmd in @('python','python3')) {
        if (Get-Command $cmd -ErrorAction SilentlyContinue) {
            $python = $cmd; break
        }
    }
    if (-not $python) {
        Write-Host "Python not found — cannot generate PDF." -ForegroundColor Red
        Write-Host "Install Python from https://python.org" -ForegroundColor Yellow
        return
    }

    # ── Check reportlab ───────────────────────────────────────
    $rlCheck = & $python -c "import reportlab" 2>&1
    if ($rlCheck -like "*No module*" -or $rlCheck -like "*ModuleNotFoundError*") {
        Write-Host "Installing reportlab..." -ForegroundColor Yellow
        & $python -m pip install reportlab --quiet 2>$null
    }

    # ── Load customer data ────────────────────────────────────
    $base         = Join-Path $env:USERPROFILE "VBAFCenter"
    $profilePath  = Join-Path $base "customers\$CustomerID.json"
    $signalPath   = Join-Path $base "signals"
    $schedPath    = Join-Path $base "schedules\$CustomerID-schedule.json"

    if (-not (Test-Path $profilePath)) {
        Write-Host "Customer not found: $CustomerID" -ForegroundColor Red
        return
    }

    $profile     = Get-Content $profilePath -Raw | ConvertFrom-Json
    $companyName = $profile.CompanyName
    $signals     = @()

    Get-ChildItem $signalPath -Filter "$CustomerID-*.json" |
        Sort-Object Name | ForEach-Object {
            $s = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $signals += $s
        }

    if ($signals.Count -eq 0) {
        Write-Host "No signals found for: $CustomerID" -ForegroundColor Red
        return
    }

    # Load thresholds
    $t1 = 0.25; $t2 = 0.50; $t3 = 0.72
    if (Test-Path $schedPath) {
        $sched = Get-Content $schedPath -Raw | ConvertFrom-Json
        if ($sched.Action1Threshold) { $t1 = [double]$sched.Action1Threshold }
        if ($sched.Action2Threshold) { $t2 = [double]$sched.Action2Threshold }
        if ($sched.Action3Threshold) { $t3 = [double]$sched.Action3Threshold }
    }

    # ── Output path ───────────────────────────────────────────
    $outPath = Join-Path $env:USERPROFILE "VBAFCenter\briefings\$CustomerID-referencekort.pdf"
    $outDir  = Split-Path $outPath
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

    Write-Host ""
    Write-Host ("  Generating reference card: {0}" -f $companyName) -ForegroundColor Cyan
    Write-Host ("  Signals : {0}"                  -f $signals.Count) -ForegroundColor White

    # ── Build Python signal data ──────────────────────────────
    $sigLines = @()
    foreach ($s in $signals) {
        $name      = $s.SignalName -replace "'","\\'"
        $rawMin    = if ($null -ne $s.RawMin)    { $s.RawMin }    else { 0 }
        $rawMax    = if ($null -ne $s.RawMax)    { $s.RawMax }    else { 100 }
        $goodBelow = if ($null -ne $s.GoodBelow -and $s.GoodBelow -ge 0) { $s.GoodBelow } else { -1 }
        $badAbove  = if ($null -ne $s.BadAbove  -and $s.BadAbove  -ge 0) { $s.BadAbove  } else { -1 }
        $weight    = if ($null -ne $s.Weight    -and $s.Weight    -gt 0) { $s.Weight    } else { 3  }

        # Determine unit from signal name
        $unit = if ($name -like "*%*")   { "%" }
                elseif ($name -like "*DKK*") { "DKK" }
                elseif ($name -like "*kg*")  { "kg" }
                elseif ($name -like "*km*")  { "km" }
                else { "" }

        # Determine if inverted signal (high raw = bad)
        $inverted = ($goodBelow -ge 0 -and $badAbove -ge 0 -and $goodBelow -lt $badAbove) -eq $false
        if ($goodBelow -ge 0 -and $badAbove -ge 0) {
            $inverted = $goodBelow -gt $badAbove
        }

        # Build threshold labels
        if ($goodBelow -ge 0 -and $badAbove -ge 0) {
            if ($inverted) {
                # High is bad (Route Efficiency, ETA Accuracy etc)
                $greenVal  = "Under $goodBelow $unit".Trim()
                $yellowVal = "$goodBelow – $badAbove $unit".Trim()
                $redVal    = "Over $badAbove $unit".Trim()
                $note      = "Lav $unit = god præstation · Høj $unit = problem *"
            } else {
                # Low is bad (On-Time, Driver Performance etc)
                $greenVal  = "Over $goodBelow $unit".Trim()
                $yellowVal = "$badAbove – $goodBelow $unit".Trim()
                $redVal    = "Under $badAbove $unit".Trim()
                $note      = "Høj $unit = god præstation"
            }
        } else {
            # No thresholds — use normalised
            $greenVal  = "Under 0.40"
            $yellowVal = "0.40 – 0.75"
            $redVal    = "Over 0.75"
            $note      = "Baseret på normaliseret værdi (0-1)"
        }

        $greenVal  = $greenVal  -replace "'","\\'"
        $yellowVal = $yellowVal -replace "'","\\'"
        $redVal    = $redVal    -replace "'","\\'"
        $note      = $note      -replace "'","\\'"

        $sigLines += "    ('$name', '$unit', '$greenVal', '$yellowVal', '$redVal', '$note', $weight),"
    }
    $sigData = $sigLines -join "`n"

    $actionT1 = $t1.ToString("F2")
    $actionT2 = $t2.ToString("F2")
    $actionT3 = $t3.ToString("F2")
    $outEsc   = $outPath -replace '\\','\\\\'
    $company  = $companyName -replace "'","\\'"
    $custID   = $CustomerID  -replace "'","\\'"

    # ── Python script ─────────────────────────────────────────
    $py = @"
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
import datetime

W, H = landscape(A4)

DARK   = colors.HexColor('#2C2C2A')
CYAN   = colors.HexColor('#0B7EA3')
GREEN  = colors.HexColor('#1D9E75')
YELLOW = colors.HexColor('#EF9F27')
RED    = colors.HexColor('#E24B4A')
LIGHT  = colors.HexColor('#F4F4F0')
MID    = colors.HexColor('#D3D1C7')
WHITE  = colors.white
GL     = colors.HexColor('#E1F5EE')
YL     = colors.HexColor('#FEF3E2')
RL     = colors.HexColor('#FDECEA')

signals = [
$sigData
]

company  = '$company'
custID   = '$custID'
t1       = $actionT1
t2       = $actionT2
t3       = $actionT3
out_path = '$outEsc'
today    = datetime.date.today().strftime('%d. %B %Y')

c = canvas.Canvas(out_path, pagesize=landscape(A4))

# Background
c.setFillColor(LIGHT)
c.rect(0, 0, W, H, fill=1, stroke=0)

# Top bar
c.setFillColor(DARK)
c.rect(0, H-12*mm, W, 12*mm, fill=1, stroke=0)
c.setFillColor(WHITE)
c.setFont('Helvetica-Bold', 12)
c.drawString(10*mm, H-8.5*mm, 'VBAF-Center — Signal Referencekort')
c.setFont('Helvetica-Bold', 11)
c.drawCentredString(W/2, H-8.5*mm, company)
c.setFont('Helvetica', 8)
c.drawRightString(W-10*mm, H-8.5*mm, today)

# Column setup
col_x = [10*mm, 58*mm, 102*mm, 153*mm, 204*mm]
col_w = [46*mm, 42*mm, 49*mm,  49*mm,  85*mm]

# Column headers
header_y = H - 21*mm
hdrs     = ['Signal + forklaring', 'Enhed', 'GROEN  OK', 'GUL  Hold oeje', 'ROED  Handle nu']
hcols    = [DARK, DARK, GREEN, YELLOW, RED]
hfg      = [WHITE, WHITE, WHITE, DARK, WHITE]

for i,(hdr,hc,fg) in enumerate(zip(hdrs,hcols,hfg)):
    c.setFillColor(hc)
    c.rect(col_x[i], header_y, col_w[i]-1*mm, 8*mm, fill=1, stroke=0)
    c.setFillColor(fg)
    c.setFont('Helvetica-Bold', 9)
    c.drawCentredString(col_x[i]+col_w[i]/2-0.5*mm, header_y+2.5*mm, hdr)

# Rows
n        = len(signals)
avail_h  = header_y - 20*mm
row_h    = avail_h / n

for idx,(name,unit,gv,yv,rv,note,wt) in enumerate(signals):
    y  = header_y - (idx+1)*row_h
    bg = WHITE if idx%2==0 else colors.HexColor('#EDEDEB')

    c.setFillColor(bg)
    c.rect(10*mm, y, W-20*mm, row_h, fill=1, stroke=0)
    c.setStrokeColor(MID)
    c.setLineWidth(0.3)
    c.line(10*mm, y, W-10*mm, y)

    # Signal name
    c.setFillColor(DARK)
    c.setFont('Helvetica-Bold', 8)
    c.drawString(col_x[0]+2*mm, y+row_h-4.5*mm, name)
    # Weight badge
    c.setFillColor(CYAN)
    c.roundRect(col_x[0]+38*mm, y+row_h-5.5*mm, 7*mm, 4.5*mm, 1.5, fill=1, stroke=0)
    c.setFillColor(WHITE)
    c.setFont('Helvetica-Bold', 6)
    c.drawCentredString(col_x[0]+41.5*mm, y+row_h-3*mm, f'W{wt}')
    # Note
    c.setFillColor(colors.HexColor('#666664'))
    c.setFont('Helvetica', 6.5)
    words = note.split()
    line1,line2='',''
    for w in words:
        test = (line1+' '+w).strip()
        if len(test) < 30: line1=test
        else: line2=(line2+' '+w).strip()
    c.drawString(col_x[0]+2*mm, y+row_h-9*mm, line1)
    if line2:
        c.drawString(col_x[0]+2*mm, y+row_h-13*mm, line2)

    # Unit
    c.setFillColor(DARK)
    c.setFont('Helvetica-Bold', 9)
    c.drawCentredString(col_x[1]+col_w[1]/2-0.5*mm, y+row_h/2-2*mm, unit)

    # Green
    pad=2*mm
    c.setFillColor(GL)
    c.roundRect(col_x[2]+pad, y+pad, col_w[2]-2*pad-1*mm, row_h-2*pad, 3, fill=1, stroke=0)
    c.setFillColor(colors.HexColor('#0A5C3A'))
    c.setFont('Helvetica-Bold', 9)
    c.drawCentredString(col_x[2]+col_w[2]/2-0.5*mm, y+row_h/2-2*mm, gv)

    # Yellow
    c.setFillColor(YL)
    c.roundRect(col_x[3]+pad, y+pad, col_w[3]-2*pad-1*mm, row_h-2*pad, 3, fill=1, stroke=0)
    c.setFillColor(colors.HexColor('#7A4F00'))
    c.setFont('Helvetica-Bold', 9)
    c.drawCentredString(col_x[3]+col_w[3]/2-0.5*mm, y+row_h/2-2*mm, yv)

    # Red
    c.setFillColor(RL)
    c.roundRect(col_x[4]+pad, y+pad, col_w[4]-2*pad-1*mm, row_h-2*pad, 3, fill=1, stroke=0)
    c.setFillColor(colors.HexColor('#7A0A0A'))
    c.setFont('Helvetica-Bold', 9)
    c.drawCentredString(col_x[4]+col_w[4]/2-0.5*mm, y+row_h/2-2*mm, rv)

# Action thresholds bar
act_y  = 9*mm
act_labels = [
    (GREEN,  WHITE, f'0 — Monitor  (avg under {t1})'),
    (YELLOW, DARK,  f'1 — Omfordel  ({t1} – {t2})'),
    (colors.HexColor('#EF6B27'), WHITE, f'2 — Omdiriger  ({t2} – {t3})'),
    (RED,    WHITE, f'3 — Eskalee r  (avg over {t3})'),
]
aw = (W-20*mm)/4
for i,(ac,fg,lbl) in enumerate(act_labels):
    ax = 10*mm + i*aw
    c.setFillColor(ac)
    c.rect(ax, act_y, aw-1*mm, 8*mm, fill=1, stroke=0)
    c.setFillColor(fg)
    c.setFont('Helvetica-Bold', 8)
    c.drawCentredString(ax+aw/2-0.5*mm, act_y+2.5*mm, lbl)

# Bottom bar
c.setFillColor(DARK)
c.rect(0, 0, W, 8.5*mm, fill=1, stroke=0)
c.setFillColor(colors.HexColor('#AAAAAA'))
c.setFont('Helvetica', 6.5)
c.drawString(10*mm, 2*mm, 'VBAF-Center  v1.0.38  Roskilde, Danmark  vbaf.dk')
c.drawCentredString(W/2, 2*mm, '* Omvendt signal: lav vaerdi = god praestaTion')
c.drawRightString(W-10*mm, 2*mm, 'Print  Laminer  Haeng paa vaeggen')

c.save()
print('OK')
"@

    # ── Run Python ────────────────────────────────────────────
    $tmpScript = [System.IO.Path]::GetTempFileName() + ".py"
    $py | Set-Content $tmpScript -Encoding UTF8
    $result = & $python $tmpScript 2>&1
    Remove-Item $tmpScript -Force -ErrorAction SilentlyContinue

    if ($result -eq 'OK') {
        Write-Host ("  Saved   : {0}" -f $outPath) -ForegroundColor Green
        Write-Host ""
        Write-Host "  Print · Laminér · Hæng på væggen" -ForegroundColor Cyan
        Write-Host ""
        if ($OpenBrowser) { Start-Process $outPath }
    } else {
        Write-Host "  Error generating PDF:" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
    }
}

# ── Load message ──────────────────────────────────────────────
Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   VBAF-Center — Reference Card Generator         |" -ForegroundColor Cyan
Write-Host "  |   Reads live signal config — always accurate     |" -ForegroundColor Cyan
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Export-VBAFCenterReferenceCard -CustomerID 'X'" -ForegroundColor White
Write-Host "  Export-VBAFCenterReferenceCard -CustomerID 'X' -OpenBrowser" -ForegroundColor White
Write-Host ""

