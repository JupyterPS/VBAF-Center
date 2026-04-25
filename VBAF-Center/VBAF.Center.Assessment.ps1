#Requires -Version 5.1
<#
.SYNOPSIS
    VBAF-Center Customer Assessment Questionnaire
.DESCRIPTION
    Scores a potential customer 1-40 and recommends
    exactly how many signals and actions to configure.
    Run this BEFORE Start-VBAFCenterOnboarding.

    Functions:
      Start-VBAFCenterAssessment  — run the questionnaire
      Get-VBAFCenterAssessmentMap — show the scoring table
#>

# ============================================================
# START-VBAFCENTERASSESSMENT
# ============================================================
function Start-VBAFCenterAssessment {
    param(
        [string] $CustomerID = ""
    )

    Write-Host ""
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   VBAF-Center Customer Assessment                |" -ForegroundColor Cyan
    Write-Host "  |   Score 1-40 -- find the right setup             |" -ForegroundColor Cyan
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    if ($CustomerID -eq "") {
        $CustomerID = Read-Host "  Customer name or ID"
    }

    Write-Host ""
    Write-Host "  Answer each question honestly." -ForegroundColor White
    Write-Host "  Press ENTER to start..."        -ForegroundColor DarkGray
    Read-Host | Out-Null

    $totalScore = 0
    $answers    = @{}

    # ── SECTION 1: Operation Complexity ──────────────────────
    Write-Host ""
    Write-Host "  ─── Section 1/4: Operation complexity ───" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  How many vehicles / assets / servers do you operate?" -ForegroundColor White
    Write-Host "  1. Fewer than 5"   -ForegroundColor White
    Write-Host "  2. 6 to 20"        -ForegroundColor White
    Write-Host "  3. 21 to 50"       -ForegroundColor White
    Write-Host "  4. More than 50"   -ForegroundColor White
    Write-Host ""
    $q1 = Read-Host "  Enter 1-4"
    $s1 = switch ($q1) { "1"{2} "2"{5} "3"{7} "4"{10} default{2} }
    $totalScore += $s1
    $answers["OperationSize"] = $s1

    Write-Host ""
    Write-Host "  How many people monitor operations daily?" -ForegroundColor White
    Write-Host "  1. Just one person"           -ForegroundColor White
    Write-Host "  2. A small team (2-5)"        -ForegroundColor White
    Write-Host "  3. A dedicated team (5-10)"   -ForegroundColor White
    Write-Host "  4. Full operations centre"    -ForegroundColor White
    Write-Host ""
    $q2 = Read-Host "  Enter 1-4"
    $s2 = switch ($q2) { "1"{2} "2"{5} "3"{7} "4"{10} default{2} }
    $totalScore += $s2
    $answers["TeamSize"] = $s2

    # ── SECTION 2: Data Availability ─────────────────────────
    Write-Host ""
    Write-Host "  ─── Section 2/4: Data availability ───" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  What systems do you use to track operations?" -ForegroundColor White
    Write-Host "  1. No system -- we use paper or memory"    -ForegroundColor White
    Write-Host "  2. Excel or CSV file exports"              -ForegroundColor White
    Write-Host "  3. A basic TMS or ERP system"              -ForegroundColor White
    Write-Host "  4. A modern TMS with REST API"             -ForegroundColor White
    Write-Host ""
    $q3 = Read-Host "  Enter 1-4"
    $s3 = switch ($q3) { "1"{2} "2"{4} "3"{7} "4"{10} default{2} }
    $totalScore += $s3
    $answers["DataSystem"] = $s3

    Write-Host ""
    Write-Host "  How often is your data updated?" -ForegroundColor White
    Write-Host "  1. Once a day or less"     -ForegroundColor White
    Write-Host "  2. Every few hours"        -ForegroundColor White
    Write-Host "  3. Every 30 minutes"       -ForegroundColor White
    Write-Host "  4. Real-time or near live" -ForegroundColor White
    Write-Host ""
    $q4 = Read-Host "  Enter 1-4"
    $s4 = switch ($q4) { "1"{2} "2"{4} "3"{7} "4"{10} default{2} }
    $totalScore += $s4
    $answers["DataFrequency"] = $s4

    # ── SECTION 3: Problem Clarity ───────────────────────────
    Write-Host ""
    Write-Host "  ─── Section 3/4: Problem clarity ───" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  How well can you describe your main operational problem?" -ForegroundColor White
    Write-Host "  1. We have problems but cannot describe them clearly" -ForegroundColor White
    Write-Host "  2. We know the problem but not the numbers"           -ForegroundColor White
    Write-Host "  3. We know the problem and have some numbers"         -ForegroundColor White
    Write-Host "  4. We know exactly what is wrong with precise figures"-ForegroundColor White
    Write-Host ""
    $q5 = Read-Host "  Enter 1-4"
    $s5 = switch ($q5) { "1"{2} "2"{5} "3"{7} "4"{10} default{2} }
    $totalScore += $s5
    $answers["ProblemClarity"] = $s5

    Write-Host ""
    Write-Host "  How many key numbers do you check every morning?" -ForegroundColor White
    Write-Host "  1. None -- we react when problems occur" -ForegroundColor White
    Write-Host "  2. One or two numbers"                   -ForegroundColor White
    Write-Host "  3. Three to five numbers"                -ForegroundColor White
    Write-Host "  4. Six or more numbers"                  -ForegroundColor White
    Write-Host ""
    $q6 = Read-Host "  Enter 1-4"
    $s6 = switch ($q6) { "1"{2} "2"{4} "3"{7} "4"{10} default{2} }
    $totalScore += $s6
    $answers["KPICount"] = $s6

    # ── SECTION 4: Response Capability ───────────────────────
    Write-Host ""
    Write-Host "  ─── Section 4/4: Response capability ───" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  When something goes wrong, how many response options do you have?" -ForegroundColor White
    Write-Host "  1. One -- we call someone and wait"            -ForegroundColor White
    Write-Host "  2. Two or three -- limited options"            -ForegroundColor White
    Write-Host "  3. Four to six -- reasonable flexibility"      -ForegroundColor White
    Write-Host "  4. Seven or more -- full operational toolkit"  -ForegroundColor White
    Write-Host ""
    $q7 = Read-Host "  Enter 1-4"
    $s7 = switch ($q7) { "1"{2} "2"{5} "3"{7} "4"{10} default{2} }
    $totalScore += $s7
    $answers["ResponseOptions"] = $s7

    Write-Host ""
    Write-Host "  How quickly can your team ACT on a recommendation?" -ForegroundColor White
    Write-Host "  1. Hours -- we need to escalate first"         -ForegroundColor White
    Write-Host "  2. 30-60 minutes"                              -ForegroundColor White
    Write-Host "  3. Within 10 minutes"                          -ForegroundColor White
    Write-Host "  4. Immediately -- dispatcher acts in real-time"-ForegroundColor White
    Write-Host ""
    $q8 = Read-Host "  Enter 1-4"
    $s8 = switch ($q8) { "1"{2} "2"{5} "3"{7} "4"{10} default{2} }
    $totalScore += $s8
    $answers["ResponseSpeed"] = $s8

    # ── CALCULATE RECOMMENDATION ─────────────────────────────
    $signals = if     ($totalScore -le 15) { 2 }
               elseif ($totalScore -le 25) { 4 }
               elseif ($totalScore -le 32) { 6 }
               else                        { 10 }

    $actions = if     ($totalScore -le 15) { 4 }
               elseif ($totalScore -le 25) { 4 }
               elseif ($totalScore -le 32) { 6 }
               else                        { 8 }

    $schedule = if    ($totalScore -le 15) { "30 minutes" }
                elseif($totalScore -le 25) { "15 minutes" }
                elseif($totalScore -le 32) { "10 minutes" }
                else                       { "5 minutes"  }

    $complexity = if  ($totalScore -le 15) { "Simple"   }
                  elseif($totalScore -le 25){ "Standard" }
                  elseif($totalScore -le 32){ "Advanced" }
                  else                      { "Full"     }

    $onboarding = if  ($totalScore -le 15) { "DKK 15.000" }
                  elseif($totalScore -le 25){ "DKK 18.000" }
                  elseif($totalScore -le 32){ "DKK 22.000" }
                  else                      { "DKK 25.000" }

    $monthly = if     ($totalScore -le 15) { "DKK 3.000" }
               elseif ($totalScore -le 25) { "DKK 4.500" }
               elseif ($totalScore -le 32) { "DKK 6.000" }
               else                        { "DKK 8.000" }

    # ── DISPLAY RESULTS ──────────────────────────────────────
    Write-Host ""
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
    Write-Host "  |   Assessment Complete!                           |" -ForegroundColor Green
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
    Write-Host ("  |  Customer   : {0,-35}|" -f $CustomerID)            -ForegroundColor White
    Write-Host ("  |  Score      : {0} / 80 -- {1,-26}|" -f $totalScore, $complexity) -ForegroundColor White
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
    Write-Host ("  |  Signals    : {0,-35}|" -f "$signals signals recommended")  -ForegroundColor Cyan
    Write-Host ("  |  Actions    : {0,-35}|" -f "$actions actions recommended")  -ForegroundColor Cyan
    Write-Host ("  |  Schedule   : {0,-35}|" -f "Check every $schedule")         -ForegroundColor Cyan
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
    Write-Host ("  |  Onboarding : {0,-35}|" -f $onboarding)                     -ForegroundColor Yellow
    Write-Host ("  |  Monthly    : {0,-35}|" -f $monthly)                        -ForegroundColor Yellow
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
    Write-Host ""
    $simulator = if ($totalScore -le 15) { "VBAF.Center.TMSSimulator.ps1" } elseif ($totalScore -le 25) { "VBAF.Center.TMSSimulator.Standard.ps1" } elseif ($totalScore -le 32) { "VBAF.Center.TMSSimulator.Advanced.ps1" } else { "VBAF.Center.TMSSimulator.Full.ps1" }
    Write-Host ("  |  Simulator  : {0,-35}|" -f $simulator) -ForegroundColor Cyan
    Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor White
    Write-Host ("  . .\VBAF-Center\{0}" -f $simulator) -ForegroundColor Green
    Write-Host "  Start-VBAFCenterOnboarding" -ForegroundColor Green
    Write-Host ""

    return @{
        CustomerID  = $CustomerID
        Score       = $totalScore
        Complexity  = $complexity
        Signals     = $signals
        Actions     = $actions
        Schedule    = $schedule
        Onboarding  = $onboarding
        Monthly     = $monthly
    }
}

# ============================================================
# GET-VBAFCENTERASSESSMENTMAP
# ============================================================
function Get-VBAFCenterAssessmentMap {

    Write-Host ""
    Write-Host "  VBAF-Center Assessment Scoring Map" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("  {0,-12} {1,-12} {2,-10} {3,-12} {4,-12} {5,-12} {6}" -f "Score","Complexity","Signals","Actions","Schedule","Onboarding","Monthly") -ForegroundColor Yellow
    Write-Host ("  {0}" -f ("-" * 80)) -ForegroundColor DarkGray
    Write-Host ("  {0,-12} {1,-12} {2,-10} {3,-12} {4,-12} {5,-12} {6}" -f "8-15",  "Simple",   "2",  "4", "30 min", "DKK 15.000", "DKK 3.000") -ForegroundColor White
    Write-Host ("  {0,-12} {1,-12} {2,-10} {3,-12} {4,-12} {5,-12} {6}" -f "16-25", "Standard", "4",  "4", "15 min", "DKK 18.000", "DKK 4.500") -ForegroundColor White
    Write-Host ("  {0,-12} {1,-12} {2,-10} {3,-12} {4,-12} {5,-12} {6}" -f "26-32", "Advanced", "6",  "6", "10 min", "DKK 22.000", "DKK 6.000") -ForegroundColor White
    Write-Host ("  {0,-12} {1,-12} {2,-10} {3,-12} {4,-12} {5,-12} {6}" -f "33-40", "Full",     "10", "8", "5 min",  "DKK 25.000", "DKK 8.000") -ForegroundColor White
    Write-Host ""
    Write-Host "  Questions scored 1-4 x 8 questions = max 80 points" -ForegroundColor DarkGray
    Write-Host ""
}

# ============================================================
# LOAD MESSAGE
# ============================================================
Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   VBAF-Center Customer Assessment  v1.0.0       |" -ForegroundColor Cyan
Write-Host "  |   Score any customer before onboarding          |" -ForegroundColor Cyan
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Start-VBAFCenterAssessment   — run the questionnaire" -ForegroundColor White
Write-Host "  Get-VBAFCenterAssessmentMap  — show the scoring table" -ForegroundColor White
Write-Host ""
Write-Host "  Quick start:" -ForegroundColor Yellow
Write-Host "  Start-VBAFCenterAssessment" -ForegroundColor Green
Write-Host ""
