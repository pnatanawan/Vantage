<#
.SYNOPSIS
    ITUP Dashboard API Server
.DESCRIPTION
    Local HTTP server that powers the ITUP Command Center dashboard.
    Provides:
    - ITUP evidence log metrics parsing (markdown -> JSON)
    - TFS API proxy for pending actions (Windows integrated auth)
    - Response endpoints for inline PR/WI replies
    - Static file serving for the dashboard HTML

    Run this script and open http://localhost:8099 in your browser.
.PARAMETER Port
    HTTP port. Default: 8099
.PARAMETER EvidenceLogPath
    Path to ITUP evidence log markdown file.
.PARAMETER HtmlPath
    Path to dashboard HTML file.
.EXAMPLE
    .\_itup_dashboard_api.ps1
.EXAMPLE
    .\_itup_dashboard_api.ps1 -Port 9000
#>

[CmdletBinding()]
param(
    [int]$Port = 8099,
    [string]$EvidenceLogPath = (Join-Path $PSScriptRoot '..\data\ITUP_EVIDENCE_LOG.md'),
    [string]$PlaybookPath = (Join-Path $PSScriptRoot '..\data\ITUP_90_DAY_PLAYBOOK.md'),
    [string]$HtmlPath = (Join-Path $PSScriptRoot '..\legacy-ui\index.html')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Configuration ─────────────────────────────────────────────
$MyGuid       = 'a92e701e-0434-412c-9c32-e0e3e89b37a8'
$MyName       = 'Paolo Natanawan'
$TfsBase      = 'https://tfs.realpage.com/tfs/Realpage/PropertyManagement'
$ApiVersion   = 'api-version=5.1'

$PlanStart    = [datetime]::Parse('2026-04-24')
$PlanEnd      = [datetime]::Parse('2026-07-23')

# Cache for TFS API calls (5 min TTL)
$script:ApiCache = @{}
$script:CacheTTL = [TimeSpan]::FromMinutes(5)

# ── TFS API Helper ────────────────────────────────────────────
function Invoke-TfsGet([string]$RelativeUrl) {
    $cacheKey = $RelativeUrl
    $cached = $script:ApiCache[$cacheKey]
    if ($cached -and ((Get-Date) - $cached.Time) -lt $script:CacheTTL) {
        return $cached.Data
    }

    $uri = "$TfsBase/$RelativeUrl"
    if ($RelativeUrl -match '\?') { $uri += "&$ApiVersion" }
    else { $uri += "?$ApiVersion" }

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -UseDefaultCredentials -ContentType 'application/json'
        $script:ApiCache[$cacheKey] = @{ Data = $response; Time = Get-Date }
        return $response
    }
    catch {
        Write-Warning "TFS API failed: $uri - $($_.Exception.Message)"
        return $null
    }
}

function Invoke-TfsPost([string]$RelativeUrl, [hashtable]$Body) {
    $uri = "$TfsBase/$RelativeUrl"
    if ($RelativeUrl -match '\?') { $uri += "&$ApiVersion" }
    else { $uri += "?$ApiVersion" }

    $json = $Body | ConvertTo-Json -Depth 5
    return Invoke-RestMethod -Uri $uri -Method Post -UseDefaultCredentials `
        -ContentType 'application/json' -Body $json
}

function Invoke-TfsPut([string]$RelativeUrl, [hashtable]$Body) {
    $uri = "$TfsBase/$RelativeUrl"
    if ($RelativeUrl -match '\?') { $uri += "&$ApiVersion" }
    else { $uri += "?$ApiVersion" }

    $json = $Body | ConvertTo-Json -Depth 5
    return Invoke-RestMethod -Uri $uri -Method Put -UseDefaultCredentials `
        -ContentType 'application/json' -Body $json
}

# ── ITUP Evidence Log Parser ─────────────────────────────────
function Get-ItupMetrics {
    if (-not (Test-Path $EvidenceLogPath)) {
        return @{ metrics = @(@{ id = 'error'; name = 'Evidence Log'; status = 'red';
            displayValue = 'NOT FOUND'; target = 'File missing'; detail = $EvidenceLogPath }) }
    }

    $content = Get-Content $EvidenceLogPath -Raw -Encoding UTF8
    $metrics = [System.Collections.ArrayList]::new()

    $parsers = @(
        @{ Name = 'Teams Chat';       Fn = { Parse-TeamsMetric $content } }
        @{ Name = 'Ceremonies';        Fn = { Parse-CeremonyMetric $content } }
        @{ Name = 'PR Rework';         Fn = { Parse-PrReworkMetric $content } }
        @{ Name = 'Story Delivery';    Fn = { Parse-StoryMetric $content } }
        @{ Name = 'Defects';           Fn = { Parse-DefectMetric $content } }
        @{ Name = 'QA Handoff';        Fn = { Parse-QaMetric $content } }
        @{ Name = 'AI Usage';          Fn = { Parse-AiUsageMetric $content } }
        @{ Name = 'Blockers';          Fn = { Parse-BlockerMetric $content } }
        @{ Name = 'AZD Response';      Fn = { Parse-AzdMetric $content } }
    )

    foreach ($p in $parsers) {
        try {
            $result = & $p.Fn
            if ($result) { [void]$metrics.Add($result) }
        }
        catch {
            Write-Warning "Parser '$($p.Name)' failed: $($_.Exception.Message)"
            [void]$metrics.Add(@{
                id = "error_$($p.Name)"; name = $p.Name; status = 'red'
                displayValue = 'ERR'; target = 'Parser failed'
                detail = $_.Exception.Message
            })
        }
    }

    return @{ metrics = @($metrics) }
}

function Parse-TeamsMetric([string]$content) {
    # Extract weekly log table rows (non-example, non-header)
    $pattern = '\|\s*(\d{4}-\d{2}-\d{2})\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*([\d.]+)%\s*\|'
    $matches = [regex]::Matches($content, $pattern)

    # Filter to ITUP period only (>= 2026-04-24)
    $itupMatches = @($matches | Where-Object {
        try { [datetime]::Parse($_.Groups[1].Value) -ge $PlanStart } catch { $false }
    })

    if ($itupMatches.Count -eq 0) {
        # Check pre-ITUP data
        $allMatches = @($matches | Where-Object {
            try { [datetime]::Parse($_.Groups[1].Value) -ge [datetime]'2026-01-01' } catch { $false }
        })
        $detail = if ($allMatches.Count -gt 0) {
            $last = $allMatches[-1]
            "Pre-ITUP: $($last.Groups[5].Value)% (week of $($last.Groups[1].Value))"
        } else { 'No data collected yet. Run responsiveness script.' }

        return @{
            id = 'teams_responsiveness'; name = 'Teams Chat'; target = '>=95% < 1hr'
            status = 'gray'; displayValue = '--'; detail = $detail
        }
    }

    $last = $itupMatches[-1]
    $pct = [double]$last.Groups[5].Value
    $weekOf = $last.Groups[1].Value
    $total = [int]$last.Groups[2].Value
    $onTime = [int]$last.Groups[3].Value
    $late = [int]$last.Groups[4].Value

    $status = if ($pct -ge 95) { 'green' } elseif ($pct -ge 85) { 'yellow' } else { 'red' }

    return @{
        id = 'teams_responsiveness'; name = 'Teams Chat'; target = '>=95% < 1hr'
        status = $status; displayValue = "$pct%"
        detail = "Week of ${weekOf}: ${onTime}/${total} on-time, ${late} late"
    }
}

function Parse-CeremonyMetric([string]$content) {
    $pattern = '\|\s*(\d{4}-\d{2}-\d{2})\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|'
    $section = Extract-Section $content '## CEREMONY ATTENDANCE' '## '
    if (-not $section) {
        return @{ id = 'ceremony'; name = 'Ceremonies'; target = '100%'; status = 'gray'
            displayValue = '--'; detail = 'No data. Add entries manually each Friday.' }
    }

    $matches = [regex]::Matches($section, $pattern)
    $itupMatches = @($matches | Where-Object {
        try { [datetime]::Parse($_.Groups[1].Value) -ge $PlanStart } catch { $false }
    })

    if ($itupMatches.Count -eq 0) {
        return @{ id = 'ceremony'; name = 'Ceremonies'; target = '100%'; status = 'gray'
            displayValue = '--'; detail = 'No ITUP-period entries yet.' }
    }

    $totalScheduled = 0; $totalAttended = 0
    foreach ($m in $itupMatches) {
        $totalScheduled += [int]$m.Groups[2].Value
        $totalAttended += [int]$m.Groups[3].Value
    }

    $pct = if ($totalScheduled -gt 0) { [math]::Round(($totalAttended / $totalScheduled) * 100, 1) } else { 100 }
    $missed = $totalScheduled - $totalAttended
    $status = if ($missed -eq 0) { 'green' } elseif ($missed -eq 1) { 'yellow' } else { 'red' }

    return @{
        id = 'ceremony'; name = 'Ceremonies'; target = '100%'
        status = $status; displayValue = "$pct%"
        detail = "$totalAttended/$totalScheduled attended across $($itupMatches.Count) weeks"
    }
}

function Parse-PrReworkMetric([string]$content) {
    # Look for ITUP period PR table
    $section = Extract-Section $content '### Active Tracking \(ITUP Period' '---'
    $pattern = '\|\s*(\d+)\s*\|\s*\d{4}-\d{2}-\d{2}\s*\|[^|]+\|\s*(\d+)\s*\|'
    $rxMatches = @(if ($section) { [regex]::Matches($section, $pattern) } else { @() })

    if ($rxMatches.Count -eq 0) {
        # Show baseline
        return @{
            id = 'pr_rework'; name = 'PR Rework'; target = 'Avg <=1.5'
            status = 'gray'; displayValue = '0.50'
            detail = 'Baseline (9mo). No ITUP-period PRs yet.'
        }
    }

    $totalRework = 0
    foreach ($m in $rxMatches) { $totalRework += [int]$m.Groups[2].Value }
    $avg = [math]::Round($totalRework / $rxMatches.Count, 2)

    $status = if ($avg -le 1.0) { 'green' } elseif ($avg -le 1.5) { 'yellow' } else { 'red' }

    return @{
        id = 'pr_rework'; name = 'PR Rework'; target = 'Avg <=1.5'
        status = $status; displayValue = "$avg"
        detail = "$($rxMatches.Count) PRs, $totalRework total rework cycles"
    }
}

function Parse-StoryMetric([string]$content) {
    $section = Extract-Section $content '### Monthly Rollup' '---'
    if (-not $section) {
        return @{ id = 'story_delivery'; name = 'Story Delivery'; target = '>=2 med/mo'
            status = 'gray'; displayValue = '--'; detail = 'No monthly rollup data.' }
    }

    # Get current month name
    $monthName = (Get-Date).ToString('MMM yyyy')
    $pattern = "\|\s*$monthName\s*\|\s*(\d*)\s*\|\s*(\d*)\s*\|"
    $match = [regex]::Match($section, $pattern)

    if (-not $match.Success -or [string]::IsNullOrWhiteSpace($match.Groups[1].Value)) {
        # Check how far into month we are
        $dayOfMonth = (Get-Date).Day
        $detail = if ($dayOfMonth -le 10) { 'Early in month. On track to start.' }
            elseif ($dayOfMonth -le 20) { 'Mid-month. Need stories completing.' }
            else { 'Late in month. Need at least 2 medium stories.' }

        return @{
            id = 'story_delivery'; name = 'Story Delivery'; target = '>=2 med/mo'
            status = $(if ($dayOfMonth -le 15) { 'gray' } else { 'yellow' })
            displayValue = '0'; detail = $detail
        }
    }

    $completed = [int]$match.Groups[1].Value
    $medium = if ($match.Groups[2].Value) { [int]$match.Groups[2].Value } else { 0 }
    $status = if ($medium -ge 2) { 'green' } elseif ($medium -ge 1) { 'yellow' } else { 'red' }

    return @{
        id = 'story_delivery'; name = 'Story Delivery'; target = '>=2 med/mo'
        status = $status; displayValue = "$completed"
        detail = "$medium medium+ this month"
    }
}

function Parse-DefectMetric([string]$content) {
    $section = Extract-Section $content '### Tracking \(ITUP Period' '### Trend'
    $pattern = '\|\s*(\d+)\s*\|\s*\d{4}-\d{2}-\d{2}\s*\|'
    $rxMatches = @(if ($section) { [regex]::Matches($section, $pattern) } else { @() })
    $defectRows = @($rxMatches | Where-Object { $_.Groups[1].Value -match '^\d+$' -and [int]$_.Groups[1].Value -gt 0 })

    $count = $defectRows.Count
    $status = if ($count -eq 0) { 'green' } elseif ($count -le 1) { 'yellow' } else { 'red' }

    return @{
        id = 'defects'; name = 'Defects'; target = '0 from own code'
        status = $status; displayValue = "$count"
        detail = if ($count -eq 0) { 'Baseline: 0 in 6 months. Maintaining.' } else { "$count defects in ITUP period" }
    }
}

function Parse-QaMetric([string]$content) {
    $section = Extract-Section $content '### ITUP Period.*\n\n\|.*QA Pass' '---'
    if (-not $section) {
        # Try broader pattern
        $section = Extract-Section $content '## QA HANDOFF QUALITY' '## PR REVIEW'
    }

    # Count bounces in ITUP period table
    $bouncePattern = '\|\s*\d+\s*\|[^|]*\|\s*Yes\s*\|'
    $bounceMatches = @(if ($section) { [regex]::Matches($section, $bouncePattern) } else { @() })
    $bounces = $bounceMatches.Count

    # Check if there are any ITUP entries at all
    $entryPattern = '\|\s*(\d{7,})\s*\|'
    $itupSection = Extract-Section $content '### ITUP Period.*QA' '---'
    $entries = @(if ($itupSection) { [regex]::Matches($itupSection, $entryPattern) } else { @() })

    if ($entries.Count -eq 0) {
        return @{
            id = 'qa_handoff'; name = 'QA Handoff'; target = '0 bounces'
            status = 'green'; displayValue = '12/12'
            detail = 'Baseline: 12/12 clean passes. No ITUP entries yet.'
        }
    }

    $status = if ($bounces -eq 0) { 'green' } elseif ($bounces -eq 1) { 'yellow' } else { 'red' }
    return @{
        id = 'qa_handoff'; name = 'QA Handoff'; target = '0 bounces'
        status = $status; displayValue = "$($entries.Count - $bounces)/$($entries.Count)"
        detail = "$bounces bounce(s) in ITUP period"
    }
}

function Parse-AiUsageMetric([string]$content) {
    $section = Extract-Section $content '## AI USAGE EVIDENCE' '## BLOCKER'
    $pattern = '\|\s*\d{4}-\d{2}-\d{2}\s*\|[^|]+\|[^|]+\|[^|]+\|[^|]+\|'
    $rxMatches = @(if ($section) { [regex]::Matches($section, $pattern) } else { @() })
    # Exclude the example row
    $entries = @($rxMatches | Where-Object { $_ -notmatch '_example_' -and $_ -notmatch 'Date \|' })

    $elapsed = ((Get-Date) - $PlanStart).TotalDays
    $dayTarget = 60  # 50% by Day 60
    $progressPct = if ($elapsed -gt 0) { [math]::Round(($elapsed / $dayTarget) * 100, 0) } else { 0 }

    if ($entries.Count -eq 0) {
        return @{
            id = 'ai_usage'; name = 'AI Usage'; target = '>=50% by Day 60'
            status = 'gray'; displayValue = '0'
            detail = 'No AI usage entries yet. Log usages as you work.'
        }
    }

    return @{
        id = 'ai_usage'; name = 'AI Usage'; target = '>=50% by Day 60'
        status = 'gray'; displayValue = "$($entries.Count)"
        detail = "$($entries.Count) entries logged. Track against assigned stories."
    }
}

function Parse-BlockerMetric([string]$content) {
    $section = Extract-Section $content '## BLOCKER SURFACING' '## REFINEMENT'
    $pattern = '\|\s*\d{4}-\d{2}-\d{2}\s*\|[^|]+\|[^|]+\|[^|]+\|\s*(Yes|No)\s*\|'
    $rxMatches = @(if ($section) { [regex]::Matches($section, $pattern) } else { @() })

    if ($rxMatches.Count -eq 0) {
        return @{
            id = 'blockers'; name = 'Blockers'; target = '<24hr surfacing'
            status = 'green'; displayValue = 'OK'
            detail = 'No blockers recorded (no blockers = good).'
        }
    }

    $late = @($rxMatches | Where-Object { $_.Groups[1].Value -eq 'No' }).Count
    $status = if ($late -eq 0) { 'green' } elseif ($late -eq 1) { 'yellow' } else { 'red' }

    return @{
        id = 'blockers'; name = 'Blockers'; target = '<24hr surfacing'
        status = $status; displayValue = "$($rxMatches.Count - $late)/$($rxMatches.Count)"
        detail = "$late late surfacing(s)"
    }
}

function Parse-AzdMetric([string]$content) {
    $section = Extract-Section $content '## AZD RESPONSIVENESS' '## STORY DELIVERY'
    $pattern = '\|\s*(\d{4}-\d{2}-\d{2})\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|[^|]+\|\s*([\d.]+)%'
    $rxMatches = @(if ($section) { [regex]::Matches($section, $pattern) } else { @() })

    $itupMatches = @($rxMatches | Where-Object {
        try { [datetime]::Parse($_.Groups[1].Value) -ge $PlanStart } catch { $false }
    })

    if ($itupMatches.Count -eq 0) {
        return @{
            id = 'azd_responsiveness'; name = 'AZD Response'; target = '<8 biz hrs'
            status = 'gray'; displayValue = '--'
            detail = 'Run _itup_azd_responsiveness.ps1 -AppendToLog to populate.'
        }
    }

    $last = $itupMatches[-1]
    $pct = [double]$last.Groups[4].Value
    $status = if ($pct -ge 95) { 'green' } elseif ($pct -ge 85) { 'yellow' } else { 'red' }

    return @{
        id = 'azd_responsiveness'; name = 'AZD Response'; target = '<8 biz hrs'
        status = $status; displayValue = "$pct%"
        detail = "Week of $($last.Groups[1].Value): $($last.Groups[3].Value)/$($last.Groups[2].Value) on-time"
    }
}

function Extract-Section([string]$content, [string]$startPattern, [string]$endMarker) {
    $startMatch = [regex]::Match($content, $startPattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $startMatch.Success) { return $null }

    $startIdx = $startMatch.Index + $startMatch.Length
    $remaining = $content.Substring($startIdx)

    # Find the next section break
    $endMatch = [regex]::Match($remaining, "(?m)^$endMarker")
    if ($endMatch.Success) {
        return $remaining.Substring(0, $endMatch.Index)
    }
    return $remaining
}

# ── Pending Actions (TFS API) ────────────────────────────────
function Get-PendingActions {
    $reviews = Get-PendingReviews
    $myPrs = Get-MyPrsPendingComments
    $workItems = Get-ActiveWorkItems

    return @{
        reviews = $reviews
        myPrs = $myPrs
        workItems = $workItems
    }
}

function Get-PendingReviews {
    $data = Invoke-TfsGet "_apis/git/pullrequests?searchCriteria.reviewerId=$MyGuid&searchCriteria.status=active&`$top=50"
    if (-not $data -or -not $data.value) { return @() }

    $results = @()
    foreach ($pr in $data.value) {
        # Skip my own PRs
        if ($pr.createdBy.id -eq $MyGuid) { continue }

        # Check if I've voted
        $myReview = $pr.reviewers | Where-Object { $_.id -eq $MyGuid }
        if ($myReview -and $myReview.vote -ne 0) { continue }

        $createdUtc = [datetime]::Parse($pr.creationDate).ToUniversalTime()
        $ageMin = [math]::Round(([datetime]::UtcNow - $createdUtc).TotalMinutes, 1)

        $results += @{
            prId = $pr.pullRequestId
            repoId = $pr.repository.id
            title = "PR $($pr.pullRequestId) - $($pr.title)"
            author = $pr.createdBy.displayName
            createdUtc = $createdUtc.ToString('o')
            ageMinutes = $ageMin
            contextLabel = "PR Review"
            url = "$TfsBase/_git/$($pr.repository.name)/pullrequest/$($pr.pullRequestId)"
            preview = if ($pr.PSObject.Properties['description']) { $pr.description } else { '' }
            threadId = $null
        }
    }

    return $results
}

function Get-MyPrsPendingComments {
    $data = Invoke-TfsGet "_apis/git/pullrequests?searchCriteria.creatorId=$MyGuid&searchCriteria.status=active&`$top=20"
    if (-not $data -or -not $data.value) { return @() }

    $results = @()
    foreach ($pr in $data.value) {
        $prId = $pr.pullRequestId
        $repoId = $pr.repository.id

        # Get threads to find unreplied comments
        $threads = Invoke-TfsGet "_apis/git/repositories/$repoId/pullRequests/$prId/threads"
        if (-not $threads -or -not $threads.value) { continue }

        foreach ($thread in $threads.value) {
            $tStatus = if ($thread.PSObject.Properties['status']) { $thread.status } else { $null }
            if ($tStatus -eq 'closed' -or $tStatus -eq 'fixed') { continue }
            if (-not $thread.PSObject.Properties['comments'] -or -not $thread.comments -or $thread.comments.Count -eq 0) { continue }

            # Check if last comment is from someone else (needs my reply)
            $comments = @($thread.comments | Where-Object { (-not $_.PSObject.Properties['commentType']) -or $_.commentType -ne 'system' })
            if ($comments.Count -eq 0) { continue }

            $lastComment = $comments[-1]
            if ($lastComment.author.id -eq $MyGuid) { continue }

            $pubDate = if ($lastComment.PSObject.Properties['publishedDate']) { $lastComment.publishedDate } else { $null }
            if (-not $pubDate) { continue }
            $commentDate = [datetime]::Parse($pubDate).ToUniversalTime()
            $ageMin = [math]::Round(([datetime]::UtcNow - $commentDate).TotalMinutes, 1)
            $commentContent = if ($lastComment.PSObject.Properties['content']) { $lastComment.content -replace '<[^>]+>', '' } else { '' }

            $results += @{
                prId = $prId
                repoId = $repoId
                title = "PR ${prId} - $($pr.title)"
                author = $lastComment.author.displayName
                createdUtc = $commentDate.ToString('o')
                ageMinutes = $ageMin
                contextLabel = "Comment on my PR"
                url = "$TfsBase/_git/$($pr.repository.name)/pullrequest/$prId"
                preview = $commentContent
                threadId = if ($thread.PSObject.Properties['id']) { $thread.id } else { $null }
            }
        }
    }

    return $results
}

function Get-ActiveWorkItems {
    $wiql = @{
        query = @"
SELECT [System.Id], [System.Title], [System.State], [System.ChangedDate]
FROM WorkItems
WHERE [System.AssignedTo] = '$MyName'
  AND [System.State] IN ('Active', 'Ready to Work')
  AND [System.TeamProject] = 'PropertyManagement'
  AND [System.WorkItemType] IN ('User Story', 'Bug', 'Task')
ORDER BY [System.ChangedDate] DESC
"@
    }

    try {
        $uri = "$TfsBase/_apis/wit/wiql?$ApiVersion"
        $json = $wiql | ConvertTo-Json -Depth 3
        $result = Invoke-RestMethod -Uri $uri -Method Post -UseDefaultCredentials `
            -ContentType 'application/json' -Body $json
    }
    catch {
        Write-Warning "WIQL failed: $($_.Exception.Message)"
        return @()
    }

    if (-not $result.workItems -or $result.workItems.Count -eq 0) { return @() }

    # Get work item details (batch, max 200)
    $ids = ($result.workItems | Select-Object -First 25).id
    $idList = $ids -join ','
    $fields = 'System.Id,System.Title,System.State,System.WorkItemType,System.ChangedDate,System.AssignedTo'
    $wiDetails = Invoke-TfsGet "_apis/wit/workitems?ids=$idList&fields=$fields"

    if (-not $wiDetails -or -not $wiDetails.value) { return @() }

    $results = @()
    foreach ($wi in $wiDetails.value) {
        $f = $wi.fields
        $changedUtc = [datetime]::Parse($f.'System.ChangedDate').ToUniversalTime()
        $ageMin = [math]::Round(([datetime]::UtcNow - $changedUtc).TotalMinutes, 1)

        $results += @{
            wiId = $wi.id
            title = "$($f.'System.WorkItemType') $($wi.id) - $($f.'System.Title')"
            author = ''
            createdUtc = $changedUtc.ToString('o')
            ageMinutes = $ageMin
            contextLabel = "$($f.'System.State')"
            url = "$TfsBase/_workitems/edit/$($wi.id)"
            preview = $null
            threadId = $null
        }
    }

    return $results
}

# ── HTTP Response Helpers ─────────────────────────────────────
function Send-JsonResponse($response, $data, [int]$statusCode = 200) {
    $json = $data | ConvertTo-Json -Depth 10 -Compress
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
    $response.StatusCode = $statusCode
    $response.ContentType = 'application/json; charset=utf-8'
    $response.ContentLength64 = $buffer.Length
    Add-CorsHeaders $response
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.OutputStream.Close()
}

function Send-HtmlResponse($response, [string]$html) {
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
    $response.StatusCode = 200
    $response.ContentType = 'text/html; charset=utf-8'
    $response.ContentLength64 = $buffer.Length
    Add-CorsHeaders $response
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.OutputStream.Close()
}

function Send-TextResponse($response, [string]$text, [int]$statusCode = 200) {
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($text)
    $response.StatusCode = $statusCode
    $response.ContentType = 'text/plain; charset=utf-8'
    $response.ContentLength64 = $buffer.Length
    Add-CorsHeaders $response
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.OutputStream.Close()
}

function Add-CorsHeaders($response) {
    $response.Headers.Add('Access-Control-Allow-Origin', '*')
    $response.Headers.Add('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS')
    $response.Headers.Add('Access-Control-Allow-Headers', 'Content-Type')
}

function Read-RequestBody($request) {
    $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
    $body = $reader.ReadToEnd()
    $reader.Close()
    return $body | ConvertFrom-Json
}

# ── Request Handlers ──────────────────────────────────────────
function Handle-ItupStatus($response) {
    try {
        $data = Get-ItupMetrics
        Send-JsonResponse $response $data
    }
    catch {
        Write-Warning "ITUP parse error: $($_.Exception.Message)"
        Send-JsonResponse $response @{ error = $_.Exception.Message; metrics = @() } 500
    }
}

function Handle-Pending($response) {
    try {
        $data = Get-PendingActions
        Send-JsonResponse $response $data
    }
    catch {
        Write-Warning "Pending fetch error: $($_.Exception.Message)"
        Send-JsonResponse $response @{ error = $_.Exception.Message; reviews = @(); myPrs = @(); workItems = @() } 500
    }
}

function Handle-VotePr($request, $response, [string]$prId) {
    try {
        $body = Read-RequestBody $request
        $repoId = $body.repoId
        $vote = $body.vote  # 10 = approve, 5 = approve w/ suggestions, -5 = wait

        $result = Invoke-TfsPut "_apis/git/repositories/$repoId/pullRequests/$prId/reviewers/$MyGuid" @{
            vote = $vote
        }

        # Clear cache so next refresh shows updated state
        $script:ApiCache.Clear()
        Send-JsonResponse $response @{ success = $true; prId = $prId }
    }
    catch {
        Send-TextResponse $response "Vote failed: $($_.Exception.Message)" 500
    }
}

function Handle-RespondPr($request, $response, [string]$prId) {
    try {
        $body = Read-RequestBody $request
        $repoId = $body.repoId
        $threadId = $body.threadId
        $content = $body.content

        if ($threadId) {
            # Reply to existing thread
            $result = Invoke-TfsPost "_apis/git/repositories/$repoId/pullRequests/$prId/threads/$threadId/comments" @{
                content = $content
                parentCommentId = 0
            }
        } else {
            # Create new thread with comment
            $result = Invoke-TfsPost "_apis/git/repositories/$repoId/pullRequests/$prId/threads" @{
                comments = @(@{
                    content = $content
                    commentType = 'text'
                })
                status = 'active'
            }
        }

        $script:ApiCache.Clear()
        Send-JsonResponse $response @{ success = $true }
    }
    catch {
        Send-TextResponse $response "Reply failed: $($_.Exception.Message)" 500
    }
}

function Handle-RespondWi($request, $response, [string]$wiId) {
    try {
        $body = Read-RequestBody $request
        $content = $body.content

        $uri = "$TfsBase/_apis/wit/workItems/$wiId/comments?api-version=5.1-preview.3"
        $json = @{ text = $content } | ConvertTo-Json
        $result = Invoke-RestMethod -Uri $uri -Method Post -UseDefaultCredentials `
            -ContentType 'application/json' -Body $json

        $script:ApiCache.Clear()
        Send-JsonResponse $response @{ success = $true }
    }
    catch {
        Send-TextResponse $response "Comment failed: $($_.Exception.Message)" 500
    }
}

function Handle-ClearCache($response) {
    $script:ApiCache.Clear()
    Send-JsonResponse $response @{ success = $true; message = 'Cache cleared' }
}

# ── Main HTTP Listener Loop ──────────────────────────────────
function Start-DashboardServer {
    $prefix = "http://localhost:$Port/"
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($prefix)

    try {
        $listener.Start()
    }
    catch {
        Write-Error "Failed to start listener on port $Port. Is another instance running? Error: $($_.Exception.Message)"
        return
    }

    Write-Host ""
    Write-Host "  =======================================" -ForegroundColor Cyan
    Write-Host "   ITUP Command Center API Server" -ForegroundColor Cyan
    Write-Host "   http://localhost:$Port" -ForegroundColor Yellow
    Write-Host "  =======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Evidence Log: $EvidenceLogPath" -ForegroundColor DarkGray
    Write-Host "  HTML:         $HtmlPath" -ForegroundColor DarkGray
    Write-Host "  TFS:          $TfsBase" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Press Ctrl+C to stop." -ForegroundColor DarkGray
    Write-Host ""

    # Verify HTML file exists
    if (-not (Test-Path $HtmlPath)) {
        Write-Warning "Dashboard HTML not found at: $HtmlPath"
        Write-Warning "The API will still work, but GET / will return 404."
    }

    try {
        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $req = $context.Request
            $res = $context.Response

            $path = $req.Url.LocalPath
            $method = $req.HttpMethod

            # Log request
            $timestamp = (Get-Date).ToString('HH:mm:ss')
            Write-Host "  [$timestamp] $method $path" -ForegroundColor DarkGray

            try {
                # Handle CORS preflight
                if ($method -eq 'OPTIONS') {
                    Add-CorsHeaders $res
                    $res.StatusCode = 204
                    $res.Close()
                    continue
                }

                # Route requests
                switch -Regex ($path) {
                    '^/$' {
                        if (Test-Path $HtmlPath) {
                            $html = Get-Content $HtmlPath -Raw -Encoding UTF8
                            Send-HtmlResponse $res $html
                        } else {
                            Send-TextResponse $res 'Dashboard HTML not found' 404
                        }
                    }
                    '^/favicon\.ico$' {
                        $res.StatusCode = 204
                        $res.Close()
                    }
                    '^/api/itup-status$' {
                        Handle-ItupStatus $res
                    }
                    '^/api/pending$' {
                        Handle-Pending $res
                    }
                    '^/api/vote/pr/(\d+)$' {
                        $prId = $Matches[1]
                        Handle-VotePr $req $res $prId
                    }
                    '^/api/respond/pr/(\d+)$' {
                        $prId = $Matches[1]
                        Handle-RespondPr $req $res $prId
                    }
                    '^/api/respond/wi/(\d+)$' {
                        $wiId = $Matches[1]
                        Handle-RespondWi $req $res $wiId
                    }
                    '^/api/clear-cache$' {
                        Handle-ClearCache $res
                    }
                    default {
                        Send-TextResponse $res 'Not Found' 404
                    }
                }
            }
            catch {
                Write-Warning "Request error on $path : $($_.Exception.Message)"
                try {
                    Send-TextResponse $res "Internal Server Error: $($_.Exception.Message)" 500
                } catch {
                    # Response may already be closed
                }
            }
        }
    }
    finally {
        $listener.Stop()
        $listener.Close()
        Write-Host "`n  Server stopped." -ForegroundColor Yellow
    }
}

# ── Run ───────────────────────────────────────────────────────
Start-DashboardServer
