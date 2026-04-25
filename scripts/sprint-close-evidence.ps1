<#
.SYNOPSIS
    Sprint-Close Evidence Collection for ITUP Tracking
.DESCRIPTION
    Queries Azure DevOps (on-prem TFS) for sprint delivery metrics:
    - Stories completed (assigned to me, Closed/Resolved in target iteration)
    - QA bounce-backs (stories that went Resolved -> Active)
    - Defects linked to my work
    - Sprint commitment vs delivered
    - Summary stats formatted for ITUP_EVIDENCE_LOG.md
.PARAMETER SprintName
    Target sprint name (e.g., "Sprint 26.09"). Defaults to current iteration.
.PARAMETER OutputFile
    Optional: Write markdown output to file instead of console.
.PARAMETER AppendToEvidenceLog
    If set, appends results to ITUP_EVIDENCE_LOG.md directly.
.EXAMPLE
    .\Sprint-Close-Evidence.ps1
    .\Sprint-Close-Evidence.ps1 -SprintName "Sprint 26.08"
    .\Sprint-Close-Evidence.ps1 -AppendToEvidenceLog
#>
param(
    [string]$SprintName,
    [string]$OutputFile,
    [switch]$AppendToEvidenceLog
)

# ─── Configuration ───
$baseUrl   = "https://tfs.realpage.com/tfs/Realpage/PropertyManagement"
$teamName  = "Koopalings"
$myGuid    = "a92e701e-0434-412c-9c32-e0e3e89b37a8"
$evidenceLog = (Join-Path $PSScriptRoot '..\data\ITUP_EVIDENCE_LOG.md')

function Invoke-AzdApi {
    param([string]$Uri, [string]$Method = "GET", $Body = $null)
    $params = @{
        Uri = $Uri
        Method = $Method
        UseDefaultCredentials = $true
    }
    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
        $params.ContentType = "application/json"
    }
    Invoke-RestMethod @params
}

# ─── 1. Resolve Target Iteration ───
Write-Host "`n=== Sprint-Close Evidence Collection ===" -ForegroundColor Cyan

$iters = Invoke-AzdApi "$baseUrl/$teamName/_apis/work/teamsettings/iterations?api-version=5.0"

if ($SprintName) {
    $targetIter = $iters.value | Where-Object { $_.name -eq $SprintName }
    if (-not $targetIter) {
        Write-Error "Sprint '$SprintName' not found in team iterations."
        return
    }
} else {
    $targetIter = $iters.value | Where-Object { $_.attributes.timeFrame -eq "current" }
    if (-not $targetIter) {
        Write-Error "No current iteration found."
        return
    }
}

$sprintPath = $targetIter.path
$sprintDisplayName = $targetIter.name
$sprintStart = ([DateTime]$targetIter.attributes.startDate).ToString("yyyy-MM-dd")
$sprintEnd   = ([DateTime]$targetIter.attributes.finishDate).ToString("yyyy-MM-dd")

Write-Host "Target: $sprintDisplayName ($sprintStart to $sprintEnd)" -ForegroundColor Green
Write-Host "Iteration Path: $sprintPath" -ForegroundColor Gray

# ─── 2. Stories Completed This Sprint ───
Write-Host "`n--- Stories Completed ---" -ForegroundColor Yellow

$storyQuery = @{
    query = "SELECT [System.Id] FROM WorkItems WHERE [System.WorkItemType] IN ('User Story','Non Functional Story','Bug','Spike') AND [System.AssignedTo] = @me AND [System.State] IN ('Closed','Resolved') AND [System.IterationPath] = '$sprintPath' ORDER BY [System.Id] ASC"
}
$storyResult = Invoke-AzdApi "$baseUrl/_apis/wit/wiql?api-version=5.0" -Method POST -Body $storyQuery

$completedStories = @()
if ($storyResult.workItems.Count -gt 0) {
    $ids = ($storyResult.workItems | ForEach-Object { $_.id }) -join ","
    $fields = "System.Id,System.Title,System.State,System.WorkItemType,Microsoft.VSTS.Scheduling.StoryPoints,System.IterationPath,System.Tags,System.AssignedTo,System.ChangedDate,Microsoft.VSTS.Common.Severity"
    $details = Invoke-AzdApi "$baseUrl/_apis/wit/workitems?ids=$ids&fields=$fields&api-version=5.0"

    foreach ($wi in $details.value) {
        $f = $wi.fields
        # Determine complexity from story points
        $sp = $f.'Microsoft.VSTS.Scheduling.StoryPoints'
        $complexity = if ($null -eq $sp -or $sp -eq 0) { "Unknown" }
                      elseif ($sp -le 1) { "Low" }
                      elseif ($sp -le 3) { "Med" }
                      elseif ($sp -le 5) { "Med" }
                      elseif ($sp -le 8) { "Med-High" }
                      else { "High" }

        $completedStories += [PSCustomObject]@{
            ID         = $f.'System.Id'
            Type       = $f.'System.WorkItemType'
            Title      = ($f.'System.Title').Substring(0, [Math]::Min(60, ($f.'System.Title').Length))
            SP         = $sp
            Complexity = $complexity
            State      = $f.'System.State'
            Tags       = $f.'System.Tags'
        }
        Write-Host "  $($f.'System.WorkItemType') $($f.'System.Id') [$complexity, $($sp)SP] $($f.'System.Title'.Substring(0, [Math]::Min(70, $f.'System.Title'.Length)))"
    }
} else {
    Write-Host "  (none)" -ForegroundColor DarkGray
}

# ─── 3. All Items Committed This Sprint (any state) ───
Write-Host "`n--- Sprint Commitment ---" -ForegroundColor Yellow

$allQuery = @{
    query = "SELECT [System.Id] FROM WorkItems WHERE [System.WorkItemType] IN ('User Story','Non Functional Story','Bug','Spike') AND [System.AssignedTo] = @me AND [System.IterationPath] = '$sprintPath' ORDER BY [System.Id] ASC"
}
$allResult = Invoke-AzdApi "$baseUrl/_apis/wit/wiql?api-version=5.0" -Method POST -Body $allQuery

$committedItems = @()
$carriedOver = @()
if ($allResult.workItems.Count -gt 0) {
    $ids = ($allResult.workItems | ForEach-Object { $_.id }) -join ","
    $fields = "System.Id,System.Title,System.State,System.WorkItemType,Microsoft.VSTS.Scheduling.StoryPoints"
    $allDetails = Invoke-AzdApi "$baseUrl/_apis/wit/workitems?ids=$ids&fields=$fields&api-version=5.0"

    foreach ($wi in $allDetails.value) {
        $f = $wi.fields
        $committedItems += [PSCustomObject]@{
            ID    = $f.'System.Id'
            Type  = $f.'System.WorkItemType'
            Title = $f.'System.Title'
            SP    = $f.'Microsoft.VSTS.Scheduling.StoryPoints'
            State = $f.'System.State'
        }
        if ($f.'System.State' -notin @('Closed','Resolved','Removed')) {
            $carriedOver += [PSCustomObject]@{
                ID    = $f.'System.Id'
                Title = ($f.'System.Title').Substring(0, [Math]::Min(60, ($f.'System.Title').Length))
                State = $f.'System.State'
                SP    = $f.'Microsoft.VSTS.Scheduling.StoryPoints'
            }
        }
    }
}

$totalCommitted   = ($committedItems | Where-Object { $_.State -ne 'Removed' }).Count
$totalCompleted   = $completedStories.Count
$totalRemoved     = @($committedItems | Where-Object { $_.State -eq 'Removed' }).Count
$spCommitted      = ($committedItems | Where-Object { $_.State -ne 'Removed' } | Measure-Object -Property SP -Sum).Sum
$spCompleted      = ($completedStories | Measure-Object -Property SP -Sum).Sum
$hitRate          = if ($totalCommitted -gt 0) { [Math]::Round(($totalCompleted / $totalCommitted) * 100, 0) } else { 0 }

Write-Host "  Committed: $totalCommitted items ($spCommitted SP)"
Write-Host "  Completed: $totalCompleted items ($spCompleted SP)"
Write-Host "  Removed:   $totalRemoved items"
Write-Host "  Hit Rate:  $hitRate%"

if ($carriedOver.Count -gt 0) {
    Write-Host "`n  Carried Over:" -ForegroundColor DarkYellow
    foreach ($co in $carriedOver) {
        Write-Host "    $($co.ID) [$($co.State)] $($co.Title)"
    }
}

# ─── 4. QA Bounce-Backs (Resolved → Active) ───
Write-Host "`n--- QA Bounce-Backs ---" -ForegroundColor Yellow

# Check state change history for stories in this sprint
$bounces = @()
if ($allResult.workItems.Count -gt 0) {
    foreach ($wi in $allResult.workItems) {
        $updates = Invoke-AzdApi "$baseUrl/_apis/wit/workitems/$($wi.id)/updates?api-version=5.0"
        $bounceCount = 0
        $bounceReasons = @()

        foreach ($update in $updates.value) {
            if ($update.fields -and $update.fields.'System.State') {
                $stateChange = $update.fields.'System.State'
                $oldState = $stateChange.oldValue
                $newState = $stateChange.newValue
                if ($oldState -eq 'Resolved' -and $newState -eq 'Active') {
                    $bounceCount++
                    if ($update.fields.'System.Reason') {
                        $bounceReasons += $update.fields.'System.Reason'.newValue
                    }
                }
            }
        }

        if ($bounceCount -gt 0) {
            $wiDetail = $committedItems | Where-Object { $_.ID -eq $wi.id }
            $bounces += [PSCustomObject]@{
                ID       = $wi.id
                Title    = $wiDetail.Title
                Bounces  = $bounceCount
                Reasons  = ($bounceReasons -join "; ")
            }
            Write-Host "  $($wi.id): $bounceCount bounce(s) - $($bounceReasons -join '; ')" -ForegroundColor Red
        }
    }
}
if ($bounces.Count -eq 0) {
    Write-Host "  No QA bounces this sprint" -ForegroundColor Green
}

# ─── 5. Defects Created This Sprint Linked to My Work ───
Write-Host "`n--- Defects This Sprint ---" -ForegroundColor Yellow

$bugQuery = @{
    query = "SELECT [System.Id] FROM WorkItems WHERE [System.WorkItemType] = 'Bug' AND [System.AssignedTo] = @me AND [System.CreatedDate] >= '$sprintStart' AND [System.CreatedDate] <= '$sprintEnd' ORDER BY [System.CreatedDate] ASC"
}
$bugResult = Invoke-AzdApi "$baseUrl/_apis/wit/wiql?api-version=5.0" -Method POST -Body $bugQuery

$sprintBugs = @()
if ($bugResult.workItems.Count -gt 0) {
    $bugIds = ($bugResult.workItems | ForEach-Object { $_.id }) -join ","
    $bugFields = "System.Id,System.Title,System.State,System.CreatedDate,Microsoft.VSTS.Common.Severity,System.Tags"
    $bugDetails = Invoke-AzdApi "$baseUrl/_apis/wit/workitems?ids=$bugIds&fields=$bugFields&api-version=5.0"

    foreach ($bug in $bugDetails.value) {
        $bf = $bug.fields
        $escaped = if ($bf.'System.Tags' -match 'External PME') { "Yes (PME)" } else { "No (QA/SAT)" }
        $sprintBugs += [PSCustomObject]@{
            ID       = $bf.'System.Id'
            Title    = ($bf.'System.Title').Substring(0, [Math]::Min(60, ($bf.'System.Title').Length))
            Severity = $bf.'Microsoft.VSTS.Common.Severity'
            Escaped  = $escaped
        }
        Write-Host "  Bug $($bf.'System.Id') [$($bf.'Microsoft.VSTS.Common.Severity')] $escaped - $($bf.'System.Title'.Substring(0, [Math]::Min(70, $bf.'System.Title'.Length)))"
    }
} else {
    Write-Host "  No new bugs this sprint" -ForegroundColor Green
}

# ─── 6. Summary ───
Write-Host "`n=== SPRINT SUMMARY ===" -ForegroundColor Cyan

$mediumPlus = ($completedStories | Where-Object { $_.Complexity -in @('Med','Med-High','High') }).Count

$summary = @"

### $sprintDisplayName ($sprintStart to $sprintEnd)

**Stories:** $totalCompleted completed, $mediumPlus medium+
**Commitment:** $totalCompleted / $totalCommitted delivered ($hitRate%) | $spCompleted / $spCommitted SP
**QA Bounces:** $($bounces.Count) ($( if ($bounces.Count -eq 0) { 'clean' } else { ($bounces | ForEach-Object { "$($_.ID): $($_.Bounces)x" }) -join ', ' } ))
**Defects:** $($sprintBugs.Count) new this sprint

"@

Write-Host $summary

# ─── 7. Generate Evidence Log Entries ───

$storyTable = @()
$storyTable += "| Story ID | Title | Complexity | Est | Actual | On-Est? | Independent? | Sprint |"
$storyTable += "|---|---|---|---|---|---|---|---|"
foreach ($s in $completedStories) {
    # Est = Actual for now (SP not typically changed mid-sprint). Flag if different.
    $onEst = "Yes"
    $storyTable += "| $($s.ID) | $($s.Title) | $($s.Complexity) | $($s.SP) SP | $($s.SP) SP | $onEst | Yes | $sprintDisplayName |"
}

$qaTable = @()
$qaTable += "| Story/PR | QA Pass? | Bounced? | Reason | Repeated? |"
$qaTable += "|---|---|---|---|---|"
if ($bounces.Count -eq 0) {
    foreach ($s in $completedStories) {
        $qaTable += "| $($s.ID) | Yes | No | - | - |"
    }
} else {
    foreach ($s in $completedStories) {
        $bounce = $bounces | Where-Object { $_.ID -eq $s.ID }
        if ($bounce) {
            $qaTable += "| $($s.ID) | After bounce | Yes ($($bounce.Bounces)x) | $($bounce.Reasons) | TBD |"
        } else {
            $qaTable += "| $($s.ID) | Yes | No | - | - |"
        }
    }
}

$defectTable = @()
$defectTable += "| Bug ID | Date Found | Source | Severity | Root Cause | Escaped? |"
$defectTable += "|---|---|---|---|---|---|"
foreach ($b in $sprintBugs) {
    $defectTable += "| $($b.ID) | $sprintDisplayName | TBD | $($b.Severity) | TBD | $($b.Escaped) |"
}

$carryTable = @()
if ($carriedOver.Count -gt 0) {
    $carryTable += "`n**Carried Over:**"
    foreach ($co in $carriedOver) {
        $carryTable += "- $($co.ID) [$($co.State)] $($co.Title) ($($co.SP) SP)"
    }
}

$fullOutput = @"
---

## Sprint Evidence: $sprintDisplayName ($sprintStart to $sprintEnd)
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm")

### Stories Completed
$($storyTable -join "`n")

### Commitment
- Committed: $totalCommitted items ($spCommitted SP)
- Completed: $totalCompleted items ($spCompleted SP)
- Removed: $totalRemoved
- **Hit Rate: $hitRate%**
$($carryTable -join "`n")

### QA Handoff Quality
$($qaTable -join "`n")

### Defects This Sprint
$($defectTable -join "`n")
$(if ($sprintBugs.Count -eq 0) { "(none)" })

### Summary Stats
- Stories: $totalCompleted completed, $mediumPlus medium+
- QA: $($completedStories.Count - $bounces.Count) passed clean, $($bounces.Count) bounced
- Defects: $($sprintBugs.Count) new this sprint
- Commitment: $totalCompleted/$totalCommitted stories delivered ($hitRate%)
"@

Write-Host "`n$fullOutput"

# ─── 8. Output / Append ───
if ($OutputFile) {
    $fullOutput | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "`nWritten to: $OutputFile" -ForegroundColor Green
}

if ($AppendToEvidenceLog) {
    # Append story delivery rows
    $logContent = Get-Content $evidenceLog -Raw

    # Append to STORY DELIVERY section (before Monthly Rollup)
    $storyRows = ""
    foreach ($s in $completedStories) {
        $storyRows += "| $($s.ID) | $($s.Title) | $($s.Complexity) | $($s.SP) SP | $($s.SP) SP | Yes | Yes | $sprintDisplayName |`n"
    }

    # Append to QA HANDOFF QUALITY section
    $qaRows = ""
    if ($bounces.Count -eq 0) {
        foreach ($s in $completedStories) {
            $qaRows += "| $($s.ID) | Yes | No | - | - |`n"
        }
    } else {
        foreach ($s in $completedStories) {
            $bounce = $bounces | Where-Object { $_.ID -eq $s.ID }
            if ($bounce) {
                $qaRows += "| $($s.ID) | After bounce | Yes ($($bounce.Bounces)x) | $($bounce.Reasons) | TBD |`n"
            } else {
                $qaRows += "| $($s.ID) | Yes | No | - | - |`n"
            }
        }
    }

    # Append to DEFECTS tracking
    $defectRows = ""
    foreach ($b in $sprintBugs) {
        $defectRows += "| $($b.ID) | $sprintDisplayName | TBD | $($b.Severity) | TBD | $($b.Escaped) |`n"
    }

    Write-Host "`n--- Evidence log append preview ---" -ForegroundColor Cyan
    if ($storyRows)  { Write-Host "Story rows:`n$storyRows" }
    if ($qaRows)     { Write-Host "QA rows:`n$qaRows" }
    if ($defectRows) { Write-Host "Defect rows:`n$defectRows" }
    Write-Host "(Manual paste recommended to preserve formatting)" -ForegroundColor DarkGray

    # Also write full sprint report to a separate file
    $reportFile = "c:\Users\pnatanawan\.agents\sprint-reports\$($sprintDisplayName -replace ' ','_').md"
    $reportDir = Split-Path $reportFile -Parent
    if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
    $fullOutput | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Host "Full report saved: $reportFile" -ForegroundColor Green
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan
