<#
.SYNOPSIS
    ITUP Azure DevOps Responsiveness Tracker
.DESCRIPTION
    Tracks PR review response time, @mention response in work item comments,
    and PR comment response time on own PRs. Writes weekly evidence to
    ITUP_EVIDENCE_LOG.md alongside the Teams responsiveness data.

    Auth: Windows integrated auth (-UseDefaultCredentials) against on-prem TFS.
    Timezone: All AZD timestamps are UTC, converted to PHT (UTC+8) for display
    and core-hours classification.
.PARAMETER DaysBack
    Number of days to look back. Default: 7.
.PARAMETER AppendToLog
    Write results to the ITUP Evidence Log.
.PARAMETER IncludeDetails
    Show per-item breakdown of response times.
.PARAMETER DryRun
    Preview the evidence log entry without writing.
.PARAMETER MaxPRs
    Max PRs to fetch per query. Default: 200.
.EXAMPLE
    .\_itup_azd_responsiveness.ps1
.EXAMPLE
    .\_itup_azd_responsiveness.ps1 -AppendToLog -IncludeDetails
.PARAMETER StartDate
    Start date (yyyy-MM-dd). Overrides DaysBack. Used with EndDate for historical month pulls.
.PARAMETER EndDate
    End date (yyyy-MM-dd). Defaults to today. Used with StartDate for historical month pulls.
.PARAMETER NoCache
    Force fresh API calls, ignoring and replacing any cached responses for this week.
.EXAMPLE
    .\_itup_azd_responsiveness.ps1 -DryRun -IncludeDetails
.EXAMPLE
    .\_itup_azd_responsiveness.ps1 -StartDate 2026-01-01 -EndDate 2026-01-31 -DryRun -IncludeDetails
.EXAMPLE
    .\_itup_azd_responsiveness.ps1 -NoCache -IncludeDetails
#>

[CmdletBinding()]
param(
    [int]$DaysBack = 7,
    [string]$EvidenceLogPath = (Join-Path $PSScriptRoot '..\data\ITUP_EVIDENCE_LOG.md'),
    [switch]$AppendToLog,
    [switch]$IncludeDetails,
    [switch]$DryRun,
    [int]$MaxPRs = 200,
    [switch]$NoCache,
    [string]$StartDate,
    [string]$EndDate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ΓöÇΓöÇ Configuration ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
$MyGuid       = 'a92e701e-0434-412c-9c32-e0e3e89b37a8'
$MyName       = 'Paolo Natanawan'
$TfsBase      = 'https://tfs.realpage.com/tfs/Realpage/PropertyManagement'
$ApiVersion   = 'api-version=5.1'
$CoreTZ       = [System.TimeZoneInfo]::FindSystemTimeZoneById('Singapore Standard Time')  # UTC+8 = PHT
$CoreStart    = 9   # 9 AM PHT
$CoreEnd      = 18  # 6 PM PHT

# Response time targets (minutes)
$PRReviewTargetMin   = 480  # 8 hours (same business day)
$MentionTargetMin    = 480  # 8 hours
$PRCommentTargetMin  = 480  # 8 hours

# Date window
if ($StartDate) {
    $CutoffUtc = [datetime]::Parse($StartDate).ToUniversalTime()
    if ($EndDate) {
        $EndDateUtc = [datetime]::Parse($EndDate).AddDays(1).ToUniversalTime()  # inclusive end
    } else {
        $EndDateUtc = [DateTimeOffset]::UtcNow.UtcDateTime
    }
    $DaysBack = [math]::Ceiling(($EndDateUtc - $CutoffUtc).TotalDays)
    $WeekOf   = $StartDate
    $WindowLabel = "$StartDate to $(if ($EndDate) { $EndDate } else { 'now' })"
} else {
    $Now       = [DateTimeOffset]::UtcNow
    $CutoffUtc = $Now.AddDays(-$DaysBack).UtcDateTime
    $EndDateUtc = $Now.UtcDateTime
    $WeekOf    = $Now.AddDays(-$DaysBack).ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-dd')
    $WindowLabel = "$DaysBack days"
}

# ΓöÇΓöÇ Cache Configuration ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
$CacheDir = Join-Path (Split-Path $EvidenceLogPath) "itup_azd_cache\$WeekOf"
if ($NoCache -and (Test-Path $CacheDir)) {
    Remove-Item $CacheDir -Recurse -Force
}
if (-not (Test-Path $CacheDir)) {
    New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
}
$script:CacheHits = 0
$script:ApiCalls = 0

function Get-CacheFileName([string]$key) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($key)
    $hash = $md5.ComputeHash($bytes)
    return [System.BitConverter]::ToString($hash).Replace('-', '').ToLower() + '.json'
}

function Get-CachedResponse([string]$cacheKey) {
    $file = Join-Path $CacheDir (Get-CacheFileName $cacheKey)
    if (Test-Path $file) {
        $script:CacheHits++
        return Get-Content $file -Raw | ConvertFrom-Json
    }
    return $null
}

function Save-CachedResponse([string]$cacheKey, $response) {
    $file = Join-Path $CacheDir (Get-CacheFileName $cacheKey)
    $response | ConvertTo-Json -Depth 8 -Compress | Set-Content $file -Encoding UTF8
}

# ΓöÇΓöÇ Helper Functions ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

function Write-Header([string]$Text) {
    $bar = '=' * 70
    Write-Host "`n$bar" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "$bar" -ForegroundColor Cyan
}

function Write-SubHeader([string]$Text) {
    Write-Host "`n--- $Text ---" -ForegroundColor Yellow
}

function Write-Metric([string]$Label, $Value, [string]$Unit = '') {
    $display = if ($Unit) { "$Value $Unit" } else { "$Value" }
    Write-Host "  $($Label.PadRight(40)) $display"
}

function ConvertTo-PHT([datetime]$utcDate) {
    return [System.TimeZoneInfo]::ConvertTimeFromUtc($utcDate, $CoreTZ)
}

function Test-CoreHours([datetime]$phtDate) {
    if ($phtDate.DayOfWeek -eq 'Saturday' -or $phtDate.DayOfWeek -eq 'Sunday') { return $false }
    return ($phtDate.Hour -ge $CoreStart -and $phtDate.Hour -lt $CoreEnd)
}

function Test-Weekend([datetime]$phtDate) {
    return ($phtDate.DayOfWeek -eq 'Saturday' -or $phtDate.DayOfWeek -eq 'Sunday')
}

function Get-BusinessMinutes([datetime]$startUtc, [datetime]$endUtc) {
    # Calculate elapsed business minutes (core hours only: 9-18 PHT, Mon-Fri)
    # If response was outside core hours, count from next core start
    $startPht = ConvertTo-PHT $startUtc
    $endPht   = ConvertTo-PHT $endUtc

    if ($endPht -le $startPht) { return 0 }

    $totalBizMin = 0
    $cursor = $startPht

    # Snap cursor to core hours if before/after
    $cursor = Snap-ToCoreStart $cursor

    while ($cursor -lt $endPht) {
        if ((Test-Weekend $cursor)) {
            # Skip to Monday 9AM
            $daysToMon = if ($cursor.DayOfWeek -eq 'Saturday') { 2 } else { 1 }
            $cursor = $cursor.Date.AddDays($daysToMon).AddHours($CoreStart)
            continue
        }
        if ($cursor.Hour -ge $CoreEnd) {
            # Skip to next day 9AM
            $cursor = $cursor.Date.AddDays(1).AddHours($CoreStart)
            continue
        }

        # We're in core hours. Count minutes until end of core day or end time
        $coreEndToday = $cursor.Date.AddHours($CoreEnd)
        $effectiveEnd = @($coreEndToday, $endPht) | Sort-Object | Select-Object -First 1
        $chunk = ($effectiveEnd - $cursor).TotalMinutes
        if ($chunk -gt 0) { $totalBizMin += $chunk }
        $cursor = $coreEndToday.AddSeconds(1)  # move past core end to trigger next-day logic
    }

    return [math]::Round($totalBizMin, 1)
}

function Snap-ToCoreStart([datetime]$pht) {
    if ((Test-Weekend $pht)) {
        $daysToMon = if ($pht.DayOfWeek -eq 'Saturday') { 2 } else { 1 }
        return $pht.Date.AddDays($daysToMon).AddHours($CoreStart)
    }
    if ($pht.Hour -lt $CoreStart) {
        return $pht.Date.AddHours($CoreStart)
    }
    if ($pht.Hour -ge $CoreEnd) {
        $nextDay = $pht.Date.AddDays(1)
        if ($nextDay.DayOfWeek -eq 'Saturday') { $nextDay = $nextDay.AddDays(2) }
        elseif ($nextDay.DayOfWeek -eq 'Sunday') { $nextDay = $nextDay.AddDays(1) }
        return $nextDay.AddHours($CoreStart)
    }
    return $pht
}

function Format-Duration([double]$minutes) {
    if ($minutes -lt 60) { return "$([math]::Round($minutes,0))m" }
    $h = [math]::Floor($minutes / 60)
    $m = [math]::Round($minutes % 60, 0)
    if ($h -lt 24) { return "${h}h${m}m" }
    $d = [math]::Floor($h / 24)
    $rh = $h % 24
    return "${d}d${rh}h"
}

function Invoke-TfsApi([string]$RelativeUrl) {
    $cached = Get-CachedResponse $RelativeUrl
    if ($cached) { return $cached }

    $uri = "$TfsBase/$RelativeUrl"
    if ($RelativeUrl -match '\?') { $uri += "&$ApiVersion" }
    else { $uri += "?$ApiVersion" }

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -UseDefaultCredentials -ContentType 'application/json'
        $script:ApiCalls++
        Save-CachedResponse $RelativeUrl $response
        return $response
    }
    catch {
        Write-Warning "TFS API call failed: $uri"
        Write-Warning $_.Exception.Message
        return $null
    }
}

# ΓöÇΓöÇ DIMENSION 1: PR Review Response Time ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
# When I'm added as reviewer, how fast do I vote or comment?

function Get-PRReviewResponses {
    Write-Header 'Dimension 1: PR Review Response Time'

    # Fetch PRs where I was a reviewer (completed + active)
    $results = @()
    foreach ($status in @('completed', 'active')) {
        $data = Invoke-TfsApi "_apis/git/pullrequests?searchCriteria.reviewerId=$MyGuid&searchCriteria.status=$status&`$top=$MaxPRs"
        if ($data -and $data.value) {
            $results += $data.value
        }
    }

    Write-Metric 'Total PRs as reviewer (all time)' $results.Count

    # Filter to window
    $windowPRs = @($results | Where-Object {
        $created = [datetime]::Parse($_.creationDate).ToUniversalTime()
        $created -ge $CutoffUtc -and $created -lt $EndDateUtc
    })

    Write-Metric "PRs in window ($WindowLabel)" $windowPRs.Count

    if ($windowPRs.Count -eq 0) {
        Write-Host '  No PRs to review in this window.' -ForegroundColor DarkGray
        return @{ Items = @(); OnTime = 0; Total = 0; Pending = 0; AvgBizMin = 0 }
    }

    [array]$reviewItems = @()
    foreach ($pr in $windowPRs) {
        $prId = $pr.pullRequestId
        $repoId = $pr.repository.id
        $createdUtc = [datetime]::Parse($pr.creationDate).ToUniversalTime()
        $author = $pr.createdBy.displayName

        # Skip self-reviews
        if ($pr.createdBy.id -eq $MyGuid) { continue }

        # Get my reviewer entry to check vote timestamp
        $myReview = $pr.reviewers | Where-Object { $_.id -eq $MyGuid }
        $isRequired = $false
        if ($myReview) {
            # TFS may use isRequired or isFlagged depending on version
            if (($myReview.PSObject.Properties.Name -contains 'isRequired') -and $myReview.isRequired) {
                $isRequired = $true
            }
            elseif (($myReview.PSObject.Properties.Name -contains 'isFlagged') -and $myReview.isFlagged) {
                $isRequired = $true
            }
        }

        # Get threads to find my first comment
        $threads = Invoke-TfsApi "_apis/git/repositories/$repoId/pullRequests/$prId/threads"
        $myFirstComment = $null
        $myVoteTime = $null

        if ($threads -and $threads.value) {
            foreach ($thread in $threads.value) {
                if (-not $thread.comments) { continue }
                foreach ($comment in $thread.comments) {
                    if ($comment.author -and $comment.author.id -eq $MyGuid) {
                        $commentDate = [datetime]::Parse($comment.publishedDate).ToUniversalTime()
                        if ($commentDate -ge $CutoffUtc) {
                            if (-not $myFirstComment -or $commentDate -lt $myFirstComment) {
                                $myFirstComment = $commentDate
                            }
                        }
                    }
                }
                # Check for vote system comments
                $threadProps = $thread.PSObject.Properties
                $hasDiscussionId = $false
                if (($threadProps.Name -contains 'properties') -and $thread.properties) {
                    $propNames = $thread.properties.PSObject.Properties.Name
                    $hasDiscussionId = $propNames -contains 'Microsoft.TeamFoundation.Discussion.UniqueID'
                }
                if ($hasDiscussionId) {
                    foreach ($comment in $thread.comments) {
                        if ($comment.author -and $comment.author.id -eq $MyGuid -and $comment.commentType -eq 'system') {
                            $voteDate = [datetime]::Parse($comment.publishedDate).ToUniversalTime()
                            if (-not $myVoteTime -or $voteDate -lt $myVoteTime) {
                                $myVoteTime = $voteDate
                            }
                        }
                    }
                }
            }
        }

        # Use earliest of vote or comment as response time
        $responseUtc = $null
        $responseType = 'none'
        if ($myFirstComment -and $myVoteTime) {
            if ($myFirstComment -le $myVoteTime) { $responseUtc = $myFirstComment; $responseType = 'comment' }
            else { $responseUtc = $myVoteTime; $responseType = 'vote' }
        }
        elseif ($myFirstComment) { $responseUtc = $myFirstComment; $responseType = 'comment' }
        elseif ($myVoteTime) { $responseUtc = $myVoteTime; $responseType = 'vote' }

        # Also check if I voted via the reviewer record (vote != 0 means responded)
        if (-not $responseUtc -and $myReview -and $myReview.vote -ne 0) {
            # We don't have exact vote timestamp from reviewer record, skip
            $responseType = 'vote-no-timestamp'
        }

        $bizMin = $null
        $onTime = $false
        if ($responseUtc) {
            $bizMin = Get-BusinessMinutes $createdUtc $responseUtc
            $onTime = $bizMin -le $PRReviewTargetMin
        }

        $item = [PSCustomObject]@{
            PRId          = $prId
            Author        = $author
            CreatedUtc    = $createdUtc
            CreatedPHT    = ConvertTo-PHT $createdUtc
            ResponseUtc   = $responseUtc
            ResponsePHT   = if ($responseUtc) { ConvertTo-PHT $responseUtc } else { $null }
            ResponseType  = $responseType
            BizMinutes    = $bizMin
            OnTime        = $onTime
            IsRequired    = $isRequired
            Status        = $pr.status
        }
        $reviewItems += $item
    }

    # Stats
    $responded = @($reviewItems | Where-Object { $_.ResponseUtc })
    $onTimeCount = @($responded | Where-Object { $_.OnTime }).Count
    $avgBiz = if ($responded.Count -gt 0) {
        [math]::Round(($responded | Measure-Object -Property BizMinutes -Average).Average, 1)
    } else { 0 }

    Write-Metric 'PRs reviewed (excl self)' $reviewItems.Count
    Write-Metric 'Responded' $responded.Count
    Write-Metric 'No response yet' ($reviewItems.Count - $responded.Count)
    Write-Metric "On-time (<= $(Format-Duration $PRReviewTargetMin))" "$onTimeCount / $($responded.Count)"
    if ($responded.Count -gt 0) {
        Write-Metric 'Avg business-hours response' (Format-Duration $avgBiz)
        $medianBiz = ($responded | Sort-Object BizMinutes | Select-Object -Skip ([math]::Floor($responded.Count / 2)) -First 1).BizMinutes
        Write-Metric 'Median business-hours response' (Format-Duration $medianBiz)
    }

    if ($IncludeDetails -and $reviewItems.Count -gt 0) {
        Write-SubHeader 'Per-PR Detail'
        foreach ($item in ($reviewItems | Sort-Object CreatedUtc)) {
            $respStr = if ($item.ResponseUtc) {
                "$(Format-Duration $item.BizMinutes) biz ($($item.ResponseType))"
            } else { 'no response' }
            $flag = if ($item.OnTime) { '[OK]' } elseif ($item.ResponseUtc) { '[LATE]' } else { '[PENDING]' }
            $req = if ($item.IsRequired) { ' [required]' } else { '' }
            Write-Host "  PR $($item.PRId) by $($item.Author)$req -- $($item.CreatedPHT.ToString('ddd HH:mm')) -- $respStr $flag"
        }
    }

    return @{
        Items    = $reviewItems
        OnTime   = $onTimeCount
        Total    = $responded.Count
        Pending  = $reviewItems.Count - $responded.Count
        AvgBizMin = $avgBiz
    }
}

# ΓöÇΓöÇ DIMENSION 2: @Mention Response in Work Item Comments ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
# When someone mentions me in a WI comment, how fast do I reply?

function Get-MentionResponses {
    Write-Header 'Dimension 2: @Mention Response in Work Items'

    # Use WIQL to find recently updated WIs where I'm involved
    $myWiql = @{
        query = @"
SELECT [System.Id]
FROM WorkItems
WHERE [System.ChangedDate] >= '$($CutoffUtc.ToString('yyyy-MM-dd'))'
  AND [System.ChangedDate] <= '$($EndDateUtc.ToString('yyyy-MM-dd'))'
  AND [System.TeamProject] = 'PropertyManagement'
  AND (
    [System.AssignedTo] = '$MyName'
    OR [System.CreatedBy] = '$MyName'
    OR [System.ChangedBy] = '$MyName'
  )
ORDER BY [System.ChangedDate] DESC
"@
    } | ConvertTo-Json

    $wiqlCacheKey = '_wiql_mention_query'
    $wiResult = Get-CachedResponse $wiqlCacheKey
    if (-not $wiResult) {
        try {
            $uri = "$TfsBase/_apis/wit/wiql?$ApiVersion"
            $wiResult = Invoke-RestMethod -Uri $uri -Method Post -Body $myWiql -UseDefaultCredentials -ContentType 'application/json'
            $script:ApiCalls++
            if ($wiResult) { Save-CachedResponse $wiqlCacheKey $wiResult }
        }
        catch {
            Write-Warning "WIQL query failed: $($_.Exception.Message)"
            return @{ Items = @(); OnTime = 0; Total = 0; Pending = 0; AvgBizMin = 0 }
        }
    }

    [array]$wiIds = @()
    if ($wiResult -and ($wiResult.PSObject.Properties.Name -contains 'workItems') -and $wiResult.workItems) {
        $wiIds = @($wiResult.workItems | Select-Object -ExpandProperty id -First 100)
    }

    Write-Metric 'Work items with recent activity' $wiIds.Count

    if ($wiIds.Count -eq 0) {
        Write-Host '  No recent work items found.' -ForegroundColor DarkGray
        return @{ Items = @(); OnTime = 0; Total = 0; Pending = 0; AvgBizMin = 0 }
    }

    [array]$mentionItems = @()

    foreach ($wiId in $wiIds) {
        # Use updates API (works on TFS on-prem, unlike /comments)
        $updates = Invoke-TfsApi "_apis/wit/workItems/$wiId/updates"
        if (-not $updates -or -not ($updates.PSObject.Properties.Name -contains 'value') -or -not $updates.value) { continue }

        # Extract history comments from updates (System.History field changes)
        [array]$historyUpdates = @()
        foreach ($upd in $updates.value) {
            if (-not $upd -or -not ($upd.PSObject.Properties.Name -contains 'fields')) { continue }
            $fields = $upd.fields
            if (-not $fields) { continue }
            $fieldNames = $fields.PSObject.Properties.Name
            if ($fieldNames -notcontains 'System.History') { continue }

            $historyVal = $fields.'System.History'.newValue
            if (-not $historyVal) { continue }

            $changedDate = $null
            if ($fieldNames -contains 'System.ChangedDate') {
                $changedDate = [datetime]::Parse($fields.'System.ChangedDate'.newValue).ToUniversalTime()
            }
            elseif ($upd.PSObject.Properties.Name -contains 'revisedDate') {
                $changedDate = [datetime]::Parse($upd.revisedDate).ToUniversalTime()
            }
            else { continue }

            $changedBy = $null
            $changedById = $null
            if ($fieldNames -contains 'System.ChangedBy') {
                $cbVal = $fields.'System.ChangedBy'.newValue
                if ($cbVal -is [string]) {
                    $changedBy = $cbVal
                }
                elseif ($cbVal -and ($cbVal.PSObject.Properties.Name -contains 'displayName')) {
                    $changedBy = $cbVal.displayName
                    if ($cbVal.PSObject.Properties.Name -contains 'id') { $changedById = $cbVal.id }
                }
                elseif ($cbVal) {
                    # Fallback: extract displayName from stringified identity object
                    $cbStr = "$cbVal"
                    if ($cbStr -match 'displayName=([^;]+)') { $changedBy = $Matches[1].Trim() }
                }
            }
            if ($upd.PSObject.Properties.Name -contains 'revisedBy') {
                if (-not $changedById -and $upd.revisedBy.PSObject.Properties.Name -contains 'id') {
                    $changedById = $upd.revisedBy.id
                }
                if (-not $changedBy -and $upd.revisedBy.PSObject.Properties.Name -contains 'displayName') {
                    $changedBy = $upd.revisedBy.displayName
                }
            }

            $historyUpdates += [PSCustomObject]@{
                Date     = $changedDate
                Author   = $changedBy
                AuthorId = $changedById
                Text     = $historyVal
            }
        }

        if ($historyUpdates.Count -eq 0) { continue }

        [array]$sorted = $historyUpdates | Sort-Object Date

        for ($i = 0; $i -lt $sorted.Count; $i++) {
            $c = $sorted[$i]
            $cDate = $c.Date

            # Skip if outside window
            if ($cDate -lt $CutoffUtc -or $cDate -ge $EndDateUtc) { continue }

            # Skip my own comments
            if ($c.AuthorId -eq $MyGuid) { continue }

            # Check if comment mentions me (by name, GUID, or email)
            $mentionsMe = $false
            $cText = $c.Text
            if ($cText -match 'Paolo' -or $cText -match $MyGuid -or $cText -match 'pnatanawan') {
                $mentionsMe = $true
            }
            if ($cText -match "uniqueName[=:]\s*[""']?paolo\.natanawan" -or $cText -match "id[=:]\s*[""']?$MyGuid") {
                $mentionsMe = $true
            }

            if (-not $mentionsMe) { continue }

            # Classify mention: actionable vs CC/FYI
            # Strip HTML tags for plain-text analysis
            $plainText = $cText -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&#\d+;', '' -replace '&[a-z]+;', ''
            $plainText = $plainText.Trim()
            $mentionType = 'actionable'

            # Check if mention is after a CC: marker (FYI-only mention)
            $ccMatch = [regex]::Match($plainText, '\bcc\s*:', 'IgnoreCase')
            if ($ccMatch.Success) {
                # Find where my name appears in the plain text
                $myNameMatch = [regex]::Match($plainText, 'Paolo|pnatanawan', 'IgnoreCase')
                if ($myNameMatch.Success -and $myNameMatch.Index -gt $ccMatch.Index) {
                    # My name appears only after CC: marker
                    $mentionType = 'CC'
                }
            }

            # Check if comment starts with FYI
            if ($plainText -match '^\s*FYI\b') {
                $mentionType = 'FYI'
            }

            # Direct address at start = always actionable (overrides CC/FYI)
            # e.g. "@Paolo can you..." or "Hi @Paolo, is this..."
            if ($plainText -match '^\s*(Hi|Hey|Hello)?\s*@?\s*Paolo' -or $plainText -match '^\s*@pnatanawan') {
                $mentionType = 'actionable'
            }

            # Find my next comment in this work item after the mention
            $myReply = $null
            for ($j = $i + 1; $j -lt $sorted.Count; $j++) {
                if ($sorted[$j].AuthorId -eq $MyGuid) {
                    $myReply = $sorted[$j]
                    break
                }
            }

            $replyUtc = $null
            $bizMin = $null
            $onTime = $false
            if ($myReply) {
                $replyUtc = $myReply.Date
                $bizMin = Get-BusinessMinutes $cDate $replyUtc
                $onTime = $bizMin -le $MentionTargetMin
            }

            $mentionItems += [PSCustomObject]@{
                WorkItemId   = $wiId
                MentionBy    = $c.Author
                MentionUtc   = $cDate
                MentionPHT   = ConvertTo-PHT $cDate
                ReplyUtc     = $replyUtc
                ReplyPHT     = if ($replyUtc) { ConvertTo-PHT $replyUtc } else { $null }
                BizMinutes   = $bizMin
                OnTime       = $onTime
                MentionType  = $mentionType
                Actionable   = ($mentionType -eq 'actionable')
            }
        }
    }

    # Stats (only count actionable mentions)
    $actionable = @($mentionItems | Where-Object { $_.Actionable })
    $skipped = @($mentionItems | Where-Object { -not $_.Actionable })
    $responded = @($actionable | Where-Object { $_.ReplyUtc })
    $onTimeCount = @($responded | Where-Object { $_.OnTime }).Count
    $avgBiz = if ($responded.Count -gt 0) {
        [math]::Round(($responded | Measure-Object -Property BizMinutes -Average).Average, 1)
    } else { 0 }

    Write-Metric 'Mentions found' $mentionItems.Count
    if ($skipped.Count -gt 0) {
        Write-Metric 'Skipped (CC/FYI)' $skipped.Count
    }
    Write-Metric 'Actionable' $actionable.Count
    Write-Metric 'Replied' $responded.Count
    Write-Metric 'No reply yet' ($actionable.Count - $responded.Count)
    if ($responded.Count -gt 0) {
        Write-Metric "On-time (<= $(Format-Duration $MentionTargetMin))" "$onTimeCount / $($responded.Count)"
        Write-Metric 'Avg business-hours response' (Format-Duration $avgBiz)
    }

    if ($IncludeDetails -and $mentionItems.Count -gt 0) {
        Write-SubHeader 'Per-Mention Detail'
        foreach ($item in ($mentionItems | Sort-Object MentionUtc)) {
            $respStr = if ($item.ReplyUtc) {
                "replied $(Format-Duration $item.BizMinutes) biz"
            } else { 'no reply' }
            $typeTag = if (-not $item.Actionable) { "[$($item.MentionType)] " } else { '' }
            $flag = if (-not $item.Actionable) { '[SKIPPED]' }
                    elseif ($item.OnTime) { '[OK]' }
                    elseif ($item.ReplyUtc) { '[LATE]' }
                    else { '[PENDING]' }
            Write-Host "  WI $($item.WorkItemId) by $($item.MentionBy) -- $($item.MentionPHT.ToString('ddd HH:mm')) -- ${typeTag}${respStr} $flag"
        }
    }

    return @{
        Items    = $mentionItems
        OnTime   = $onTimeCount
        Total    = $responded.Count
        Pending  = $actionable.Count - $responded.Count
        AvgBizMin = $avgBiz
    }
}

# ΓöÇΓöÇ DIMENSION 3: PR Comment Response Time (My Own PRs) ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
# When a reviewer leaves feedback on my PR, how fast do I respond?

function Get-MyPRCommentResponses {
    Write-Header 'Dimension 3: PR Comment Response Time (Own PRs)'

    # Fetch my PRs
    $results = @()
    foreach ($status in @('completed', 'active')) {
        $data = Invoke-TfsApi "_apis/git/pullrequests?searchCriteria.creatorId=$MyGuid&searchCriteria.status=$status&`$top=$MaxPRs"
        if ($data -and $data.value) {
            $results += $data.value
        }
    }

    # Filter to window
    $windowPRs = @($results | Where-Object {
        $created = [datetime]::Parse($_.creationDate).ToUniversalTime()
        $created -ge $CutoffUtc -and $created -lt $EndDateUtc
    })

    Write-Metric "My PRs in window ($WindowLabel)" $windowPRs.Count

    if ($windowPRs.Count -eq 0) {
        Write-Host '  No PRs authored in this window.' -ForegroundColor DarkGray
        return @{ Items = @(); OnTime = 0; Total = 0; Pending = 0; AvgBizMin = 0 }
    }

    [array]$commentItems = @()

    foreach ($pr in $windowPRs) {
        $prId = $pr.pullRequestId
        $repoId = $pr.repository.id

        # Get threads
        $threads = Invoke-TfsApi "_apis/git/repositories/$repoId/pullRequests/$prId/threads"
        if (-not $threads -or -not $threads.value) { continue }

        # Get iterations for push-response tracking
        $iterations = Invoke-TfsApi "_apis/git/repositories/$repoId/pullRequests/$prId/iterations"
        $iterDates = @()
        if ($iterations -and $iterations.value) {
            $iterDates = $iterations.value | ForEach-Object {
                [datetime]::Parse($_.createdDate).ToUniversalTime()
            } | Sort-Object
        }

        foreach ($thread in $threads.value) {
            # Skip system threads, non-code-review threads
            if (-not $thread.comments -or $thread.comments.Count -eq 0) { continue }

            $firstComment = $thread.comments[0]

            # Skip my own threads (I started the thread)
            if ($firstComment.author -and $firstComment.author.id -eq $MyGuid) { continue }

            # Skip system-generated threads
            if ($firstComment.commentType -eq 'system') { continue }

            $reviewerCommentUtc = [datetime]::Parse($firstComment.publishedDate).ToUniversalTime()
            if ($reviewerCommentUtc -lt $CutoffUtc -or $reviewerCommentUtc -ge $EndDateUtc) { continue }

            $reviewerName = $firstComment.author.displayName

            # Find my first reply in this thread
            $myReply = $null
            foreach ($comment in $thread.comments) {
                if ($comment.author -and $comment.author.id -eq $MyGuid -and $comment.commentType -ne 'system') {
                    $replyDate = [datetime]::Parse($comment.publishedDate).ToUniversalTime()
                    if ($replyDate -gt $reviewerCommentUtc) {
                        if (-not $myReply -or $replyDate -lt $myReply) {
                            $myReply = $replyDate
                        }
                    }
                }
            }

            # Also check if I pushed a new iteration (code fix) after the comment
            $myNextPush = $null
            foreach ($iterDate in $iterDates) {
                if ($iterDate -gt $reviewerCommentUtc) {
                    $myNextPush = $iterDate
                    break
                }
            }

            # Use earliest of reply or push as response
            $responseUtc = $null
            $responseType = 'none'
            if ($myReply -and $myNextPush) {
                if ($myReply -le $myNextPush) { $responseUtc = $myReply; $responseType = 'reply' }
                else { $responseUtc = $myNextPush; $responseType = 'push' }
            }
            elseif ($myReply) { $responseUtc = $myReply; $responseType = 'reply' }
            elseif ($myNextPush) { $responseUtc = $myNextPush; $responseType = 'push' }

            $bizMin = $null
            $onTime = $false
            if ($responseUtc) {
                $bizMin = Get-BusinessMinutes $reviewerCommentUtc $responseUtc
                $onTime = $bizMin -le $PRCommentTargetMin
            }

            $commentItems += [PSCustomObject]@{
                PRId           = $prId
                Reviewer       = $reviewerName
                CommentUtc     = $reviewerCommentUtc
                CommentPHT     = ConvertTo-PHT $reviewerCommentUtc
                ResponseUtc    = $responseUtc
                ResponsePHT    = if ($responseUtc) { ConvertTo-PHT $responseUtc } else { $null }
                ResponseType   = $responseType
                BizMinutes     = $bizMin
                OnTime         = $onTime
                ThreadId       = $thread.id
            }
        }
    }

    # Stats
    $responded = @($commentItems | Where-Object { $_.ResponseUtc })
    $onTimeCount = @($responded | Where-Object { $_.OnTime }).Count
    $avgBiz = if ($responded.Count -gt 0) {
        [math]::Round(($responded | Measure-Object -Property BizMinutes -Average).Average, 1)
    } else { 0 }

    Write-Metric 'Review comments received' $commentItems.Count
    Write-Metric 'Responded (reply or push)' $responded.Count
    Write-Metric 'No response yet' ($commentItems.Count - $responded.Count)
    if ($responded.Count -gt 0) {
        Write-Metric "On-time (<= $(Format-Duration $PRCommentTargetMin))" "$onTimeCount / $($responded.Count)"
        Write-Metric 'Avg business-hours response' (Format-Duration $avgBiz)
        Write-Metric 'Response by reply' @($responded | Where-Object { $_.ResponseType -eq 'reply' }).Count
        Write-Metric 'Response by push' @($responded | Where-Object { $_.ResponseType -eq 'push' }).Count
    }

    if ($IncludeDetails -and $commentItems.Count -gt 0) {
        Write-SubHeader 'Per-Comment Detail'
        foreach ($item in ($commentItems | Sort-Object CommentUtc)) {
            $respStr = if ($item.ResponseUtc) {
                "$(Format-Duration $item.BizMinutes) biz ($($item.ResponseType))"
            } else { 'no response' }
            $flag = if ($item.OnTime) { '[OK]' } elseif ($item.ResponseUtc) { '[LATE]' } else { '[PENDING]' }
            Write-Host "  PR $($item.PRId) thread $($item.ThreadId) by $($item.Reviewer) -- $($item.CommentPHT.ToString('ddd HH:mm')) -- $respStr $flag"
        }
    }

    return @{
        Items     = $commentItems
        OnTime    = $onTimeCount
        Total     = $responded.Count
        Pending   = $commentItems.Count - $responded.Count
        AvgBizMin = $avgBiz
    }
}

# ΓöÇΓöÇ Summary & Evidence Log ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

function Build-EvidenceEntry {
    param($ReviewData, $MentionData, $CommentData)

    $prRevPct = if ($ReviewData.Total -gt 0) {
        [math]::Round(($ReviewData.OnTime / $ReviewData.Total) * 100, 1)
    } else { '-' }
    $mentionPct = if ($MentionData.Total -gt 0) {
        [math]::Round(($MentionData.OnTime / $MentionData.Total) * 100, 1)
    } else { '-' }
    $commentPct = if ($CommentData.Total -gt 0) {
        [math]::Round(($CommentData.OnTime / $CommentData.Total) * 100, 1)
    } else { '-' }

    # Build note string
    $notes = @()
    if ($ReviewData.Total -gt 0) {
        $notes += "PRrev: $($ReviewData.OnTime)/$($ReviewData.Total) on-time, avg $(Format-Duration $ReviewData.AvgBizMin)"
    }
    if ($MentionData.Total -gt 0) {
        $notes += "Mentions: $($MentionData.OnTime)/$($MentionData.Total) on-time, avg $(Format-Duration $MentionData.AvgBizMin)"
    }
    if ($CommentData.Total -gt 0) {
        $notes += "PRcmt: $($CommentData.OnTime)/$($CommentData.Total) on-time, avg $(Format-Duration $CommentData.AvgBizMin)"
    }
    if ($ReviewData.Pending -gt 0) { $notes += "PRrev pending: $($ReviewData.Pending)" }
    if ($MentionData.Pending -gt 0) { $notes += "Mention pending: $($MentionData.Pending)" }
    if ($CommentData.Pending -gt 0) { $notes += "PRcmt pending: $($CommentData.Pending)" }

    $noteStr = if ($notes.Count -gt 0) { $notes -join '; ' } else { 'no AZD activity' }

    # Table row for the evidence log
    $row = "| $WeekOf | $($ReviewData.Total + $MentionData.Total + $CommentData.Total) | $($ReviewData.OnTime + $MentionData.OnTime + $CommentData.OnTime) | $($ReviewData.Total + $MentionData.Total + $CommentData.Total - $ReviewData.OnTime - $MentionData.OnTime - $CommentData.OnTime) | $prRevPct% / $mentionPct% / $commentPct% | $noteStr |"

    return $row
}

# ΓöÇΓöÇ Main Execution ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

Write-Header "ITUP AZD Responsiveness -- $WeekOf ($WindowLabel)"
Write-Host "  My GUID: $MyGuid"
Write-Host "  TFS Base: $TfsBase"
Write-Host "  Core Hours: ${CoreStart}:00-${CoreEnd}:00 PHT (UTC+8)"
Write-Host "  Target: respond within $(Format-Duration $PRReviewTargetMin) business hours"
$existingCache = @(Get-ChildItem $CacheDir -Filter '*.json' -ErrorAction SilentlyContinue).Count
if ($NoCache) {
    Write-Host "  Cache: DISABLED (fresh API calls)" -ForegroundColor Yellow
} elseif ($existingCache -gt 0) {
    Write-Host "  Cache: LOADED ($existingCache cached responses from $CacheDir)" -ForegroundColor DarkGray
} else {
    Write-Host "  Cache: EMPTY (first run for week of $WeekOf)" -ForegroundColor DarkGray
}

$reviewData  = Get-PRReviewResponses
$mentionData = Get-MentionResponses
$commentData = Get-MyPRCommentResponses

# ΓöÇΓöÇ Combined Summary ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
Write-Header 'Combined AZD Responsiveness Summary'

$totalResponded = $reviewData.Total + $mentionData.Total + $commentData.Total
$totalPending = $reviewData.Pending + $mentionData.Pending + $commentData.Pending
$totalAll = $totalResponded + $totalPending
$totalOnTime = $reviewData.OnTime + $mentionData.OnTime + $commentData.OnTime
$overallPct = if ($totalResponded -gt 0) {
    [math]::Round(($totalOnTime / $totalResponded) * 100, 1)
} else { 0 }

Write-Metric 'Total AZD interactions' "$totalAll (responded: $totalResponded, pending: $totalPending)"
Write-Metric 'On-time responses' "$totalOnTime / $totalResponded ($overallPct%)"
Write-Metric 'PR Reviews' "$($reviewData.OnTime)/$($reviewData.Total) on-time$(if($reviewData.Pending){", $($reviewData.Pending) pending"})"
Write-Metric '@Mentions' "$($mentionData.OnTime)/$($mentionData.Total) on-time$(if($mentionData.Pending){", $($mentionData.Pending) pending"})"
Write-Metric 'PR Comments (own)' "$($commentData.OnTime)/$($commentData.Total) on-time$(if($commentData.Pending){", $($commentData.Pending) pending"})"

# ΓöÇΓöÇ Evidence Log Entry ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
$logEntry = Build-EvidenceEntry $reviewData $mentionData $commentData

Write-Header 'Evidence Log Entry'
Write-Host ''
Write-Host '  Table row for AZD RESPONSIVENESS section:' -ForegroundColor Green
Write-Host "  $logEntry"

if ($AppendToLog -or $DryRun) {
    Write-Host ''
    if ($DryRun) {
        Write-Host '  [DRY RUN] Would append to evidence log:' -ForegroundColor Yellow
        Write-Host "  $logEntry"
    }
    elseif ($AppendToLog) {
        # Find the AZD RESPONSIVENESS section and append
        $logContent = Get-Content $EvidenceLogPath -Raw
        $marker = '## AZD RESPONSIVENESS'

        if ($logContent -match [regex]::Escape($marker)) {
            # Find the table and append after the header row separator
            $sectionPattern = '(?s)(## AZD RESPONSIVENESS.*?\|---\|.*?\|.*?\|)'
            if ($logContent -match $sectionPattern) {
                $logContent = $logContent -replace [regex]::Escape($Matches[0]), "$($Matches[0])`n$logEntry"
                Set-Content -Path $EvidenceLogPath -Value $logContent -Encoding UTF8 -NoNewline
                Write-Host '  Appended to evidence log.' -ForegroundColor Green
            }
            else {
                Write-Warning 'Found AZD RESPONSIVENESS section but could not find table. Manual append needed.'
                Write-Host "  Entry: $logEntry"
            }
        }
        else {
            Write-Warning 'AZD RESPONSIVENESS section not found in evidence log. Manual append needed.'
            Write-Host "  Entry: $logEntry"
        }
    }
}

# ΓöÇΓöÇ Raw Export ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
$exportPath = Join-Path (Split-Path $EvidenceLogPath) "itup_azd_responsiveness_$($WeekOf).json"
$export = @{
    weekOf        = $WeekOf
    daysBack      = $DaysBack
    generated     = (Get-Date).ToString('o')
    prReviews     = $reviewData.Items | ForEach-Object { $_ | Select-Object PRId, Author, CreatedPHT, ResponsePHT, ResponseType, BizMinutes, OnTime, IsRequired }
    mentions      = $mentionData.Items | ForEach-Object { $_ | Select-Object WorkItemId, MentionBy, MentionPHT, ReplyPHT, BizMinutes, OnTime }
    prComments    = $commentData.Items | ForEach-Object { $_ | Select-Object PRId, Reviewer, CommentPHT, ResponsePHT, ResponseType, BizMinutes, OnTime }
    summary       = @{
        totalResponded    = $totalResponded
        totalPending      = $totalPending
        totalOnTime       = $totalOnTime
        overallPct        = $overallPct
        prReviewAvgBiz    = $reviewData.AvgBizMin
        mentionAvgBiz     = $mentionData.AvgBizMin
        prCommentAvgBiz   = $commentData.AvgBizMin
    }
}
$export | ConvertTo-Json -Depth 5 | Set-Content $exportPath -Encoding UTF8
Write-Host "`n  Raw data exported: $exportPath" -ForegroundColor DarkGray

# ΓöÇΓöÇ Cache Stats ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
$cacheFiles = @(Get-ChildItem $CacheDir -Filter '*.json').Count
$cacheBytes = (Get-ChildItem $CacheDir -Filter '*.json' | Measure-Object -Property Length -Sum).Sum
$cacheSizeStr = if ($cacheBytes -gt 1MB) { "$([math]::Round($cacheBytes / 1MB, 1))MB" } else { "$([math]::Round($cacheBytes / 1KB, 1))KB" }
Write-Host "`n  Cache: $CacheDir" -ForegroundColor DarkGray
Write-Host "  API calls this run: $($script:ApiCalls), Cache hits: $($script:CacheHits), Cached files: $cacheFiles ($cacheSizeStr)" -ForegroundColor DarkGray

Write-Host "`nDone.`n" -ForegroundColor Green
