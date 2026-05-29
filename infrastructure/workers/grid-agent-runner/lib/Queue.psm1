function Invoke-GridReviewQueueTick {
    param(
        [hashtable]$HostConfig,
        [hashtable]$JobSpec,
        [hashtable]$Logger,
        [switch]$DryRun
    )

    $labels = Get-ReviewQueueLabels -JobSpec $JobSpec

    if ($DryRun) {
        Write-RunnerLog -Logger $Logger -Level "INFO" -Message "Dry-run review queue tick validated job spec."
        return @{
            status = "dry-run"
            message = "Validated review queue tick without GitHub calls."
            latest_output = $JobSpec.OutputContract.LatestOutput
            artifacts = @()
        }
    }

    $token = Get-GitHubInstallationToken -HostConfig $HostConfig -RequiredSecretNames $JobSpec.RequiredSecrets -Logger $Logger
    Invoke-StaleClaimSweep -HostConfig $HostConfig -JobSpec $JobSpec -Logger $Logger -Token $token -Labels $labels
    $items = Get-ReviewQueueItems -JobSpec $JobSpec -Token $token -Labels $labels

    if ($items.Count -eq 0) {
        Write-RunnerLog -Logger $Logger -Level "INFO" -Message "Review queue is empty."
        return @{
            status = "empty"
            message = "No PRs carried $($labels.PendingLabel)."
            latest_output = $JobSpec.OutputContract.LatestOutput
            artifacts = @()
        }
    }

    $item = $items | Select-Object -First 1
    Write-RunnerLog -Logger $Logger -Level "INFO" -Message "Review queue item selected." -Data @{
        url = $item.html_url
    }

    $context = Get-ReviewQueueContext -IssueItem $item -Token $token -QueueCommentMarker $JobSpec.Queue.QueueCommentMarker
    $claim = Claim-ReviewQueueItem -Context $context -HostConfig $HostConfig -Token $token -Labels $labels
    $preflight = Get-ReviewQueueContext -IssueItem $item -Token $token -QueueCommentMarker $JobSpec.Queue.QueueCommentMarker

    if (($preflight.QueueHeadSha -ne $claim.HeadSha) -or ($preflight.CurrentHeadSha -ne $claim.HeadSha)) {
        Release-ReviewQueueItem -Context $preflight -Token $token -Labels $labels -Reason "claim invalidated; current head is $($preflight.CurrentHeadSha) and queue head is $($preflight.QueueHeadSha)"
        return @{
            status = "empty"
            message = "Claim invalidated before agent invocation because the PR head changed."
            latest_output = $JobSpec.OutputContract.LatestOutput
            artifacts = @($item.html_url)
        }
    }

    $verdict = Invoke-ReviewAgentPasses -HostConfig $HostConfig -JobSpec $JobSpec -Logger $Logger -Context $context
    $postflight = Get-ReviewQueueContext -IssueItem $item -Token $token -QueueCommentMarker $JobSpec.Queue.QueueCommentMarker
    if (($postflight.QueueHeadSha -ne $claim.HeadSha) -or ($postflight.CurrentHeadSha -ne $claim.HeadSha)) {
        Release-ReviewQueueItem -Context $postflight -Token $token -Labels $labels -Reason "claim invalidated after agent invocation; current head is $($postflight.CurrentHeadSha) and queue head is $($postflight.QueueHeadSha)"
        return @{
            status = "empty"
            message = "Verdict discarded because PR head advanced during review."
            latest_output = $JobSpec.OutputContract.LatestOutput
            artifacts = @($item.html_url)
        }
    }

    Complete-ReviewQueueItem -Context $postflight -Token $token -Labels $labels -VerdictBody $verdict

    return @{
        status = "completed"
        message = "Posted review verdict for '$($item.html_url)'."
        latest_output = $JobSpec.OutputContract.LatestOutput
        artifacts = @($item.html_url)
    }
}

function Get-ReviewQueueItems {
    param(
        [hashtable]$JobSpec,
        [string]$Token,
        [hashtable]$Labels
    )

    $query = if ($JobSpec.ContainsKey("Queue") -and $JobSpec.Queue.ContainsKey("SearchQuery")) {
        $JobSpec.Queue.SearchQuery
    }
    else {
        "is:pr is:open label:$($Labels.PendingLabel) org:HoneyDrunkStudios"
    }

    return Get-ReviewQueueItemsByQuery -Query $query -Token $Token
}

function Get-ReviewQueueItemsByQuery {
    param(
        [string]$Query,
        [string]$Token
    )

    $uri = "https://api.github.com/search/issues?q=$([System.Uri]::EscapeDataString($Query))&sort=updated&order=asc"
    $response = Invoke-GitHubApi -Method "GET" -Uri $uri -Token $Token
    return @($response.items)
}

function Invoke-StaleClaimSweep {
    param(
        [hashtable]$HostConfig,
        [hashtable]$JobSpec,
        [hashtable]$Logger,
        [string]$Token,
        [hashtable]$Labels
    )

    $minutes = if ($JobSpec.Queue.ContainsKey("StaleClaimMinutes")) { $JobSpec.Queue.StaleClaimMinutes } else { 15 }
    $staleQuery = Get-StaleClaimSearchQuery -JobSpec $JobSpec -Labels $Labels
    Write-RunnerLog -Logger $Logger -Level "INFO" -Message "Stale-claim sweep starting." -Data @{
        stale_claim_minutes = $minutes
        query = $staleQuery
    }

    $items = Get-ReviewQueueItemsByQuery -Query $staleQuery -Token $Token
    $threshold = [DateTimeOffset]::UtcNow.AddMinutes(-1 * [int]$minutes)

    foreach ($item in $items) {
        $context = Get-ReviewQueueContext -IssueItem $item -Token $Token -QueueCommentMarker $JobSpec.Queue.QueueCommentMarker
        $claimedAt = Get-ClaimedAtFromQueueComment -Body $context.QueueComment.body
        if ($null -eq $claimedAt) {
            Write-RunnerLog -Logger $Logger -Level "WARN" -Message "Skipping stale claim without parseable claim timestamp." -Data @{
                url = $item.html_url
            }
            continue
        }

        if ($claimedAt -gt $threshold) {
            continue
        }

        Release-ReviewQueueItem -Context $context -Token $Token -Labels $Labels -Reason "stale claim recovered after $minutes minutes"
        Write-RunnerLog -Logger $Logger -Level "WARN" -Message "Recovered stale queue claim." -Data @{
            url = $item.html_url
            claimed_at = $claimedAt.ToString("o")
        }
    }
}

function Get-StaleClaimSearchQuery {
    param(
        [hashtable]$JobSpec,
        [hashtable]$Labels
    )

    if ($JobSpec.Queue.ContainsKey("StaleSearchQuery")) {
        return $JobSpec.Queue.StaleSearchQuery
    }

    if ($JobSpec.Queue.ContainsKey("SearchQuery")) {
        $pendingPattern = "label:$([regex]::Escape($Labels.PendingLabel))"
        $query = $JobSpec.Queue.SearchQuery -replace $pendingPattern, "label:$($Labels.InProgressLabel)"
        if ($query -ne $JobSpec.Queue.SearchQuery) {
            return $query
        }
    }

    return "is:pr label:$($Labels.InProgressLabel) org:HoneyDrunkStudios"
}

function Get-ReviewQueueContext {
    param(
        [object]$IssueItem,
        [string]$Token,
        [string]$QueueCommentMarker
    )

    $repoPath = ($IssueItem.repository_url -replace "^https://api.github.com/repos/", "")
    $owner, $repo = $repoPath -split "/", 2
    $number = [int]$IssueItem.number
    $pull = Invoke-GitHubApi -Method "GET" -Uri "https://api.github.com/repos/$owner/$repo/pulls/$number" -Token $Token
    $comments = Invoke-GitHubApi -Method "GET" -Uri "https://api.github.com/repos/$owner/$repo/issues/$number/comments?per_page=100" -Token $Token
    $queueComment = @($comments) | Where-Object { $_.body -match [regex]::Escape($QueueCommentMarker) } | Select-Object -Last 1

    $queueHeadSha = $pull.head.sha
    if ($null -ne $queueComment) {
        $parsed = Get-HeadShaFromQueueComment -Body $queueComment.body
        if (-not [string]::IsNullOrWhiteSpace($parsed)) {
            $queueHeadSha = $parsed
        }
    }

    return @{
        Owner = $owner
        Repo = $repo
        Number = $number
        HtmlUrl = $IssueItem.html_url
        Pull = $pull
        CurrentHeadSha = $pull.head.sha
        QueueHeadSha = $queueHeadSha
        QueueComment = $queueComment
    }
}

function Get-HeadShaFromQueueComment {
    param([string]$Body)

    if ([string]::IsNullOrWhiteSpace($Body)) {
        return $null
    }

    if ($Body -match "(?im)head_sha\s*[:=]\s*`?([a-f0-9]{7,40})`?") {
        return $Matches[1]
    }

    if ($Body -match '"head_sha"\s*:\s*"([a-f0-9]{7,40})"') {
        return $Matches[1]
    }

    return $null
}

function Get-ClaimedAtFromQueueComment {
    param([string]$Body)

    if ([string]::IsNullOrWhiteSpace($Body)) {
        return $null
    }

    if ($Body -match "(?im)claimed_at\s*[:=]\s*`?(.+?)`?\s*$") {
        $value = $Matches[1].Trim().Trim([char]0x60)
        $claimedAt = [DateTimeOffset]::MinValue
        if ([DateTimeOffset]::TryParse($value, [ref]$claimedAt)) {
            return $claimedAt.ToUniversalTime()
        }
    }

    return $null
}

function Get-ReviewQueueLabels {
    param([hashtable]$JobSpec)

    $queue = if ($JobSpec.ContainsKey("Queue")) { $JobSpec.Queue } else { @{} }
    $pending = Get-QueueLabelValue -Queue $queue -Key "PendingLabel" -DefaultValue "needs-agent-review"
    $inProgress = Get-QueueLabelValue -Queue $queue -Key "InProgressLabel" -DefaultValue "agent-review-in-progress"
    $success = Get-QueueLabelValue -Queue $queue -Key "SuccessLabel" -DefaultValue "agent-reviewed"
    $failure = Get-QueueLabelValue -Queue $queue -Key "FailureLabel" -DefaultValue "changes-requested-by-agent"
    $removeOnCompletion = if ($queue.ContainsKey("RemoveOnCompletionLabels")) {
        @($queue.RemoveOnCompletionLabels)
    }
    else {
        @($pending)
    }

    return @{
        PendingLabel = $pending
        InProgressLabel = $inProgress
        SuccessLabel = $success
        FailureLabel = $failure
        RemoveOnCompletionLabels = @($removeOnCompletion | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    }
}

function Get-QueueLabelValue {
    param(
        [hashtable]$Queue,
        [string]$Key,
        [string]$DefaultValue
    )

    if ($Queue.ContainsKey($Key) -and -not [string]::IsNullOrWhiteSpace([string]$Queue[$Key])) {
        return [string]$Queue[$Key]
    }

    return $DefaultValue
}

function Claim-ReviewQueueItem {
    param(
        [hashtable]$Context,
        [hashtable]$HostConfig,
        [string]$Token,
        [hashtable]$Labels
    )

    $owner = $Context.Owner
    $repo = $Context.Repo
    $number = $Context.Number
    $headSha = $Context.QueueHeadSha

    Remove-IssueLabel -Owner $owner -Repo $repo -Number $number -Token $Token -Label $Labels.PendingLabel
    Add-IssueLabels -Owner $owner -Repo $repo -Number $number -Token $Token -Labels @($Labels.InProgressLabel)

    if ($null -ne $Context.QueueComment) {
        $body = $Context.QueueComment.body.TrimEnd() + @"

claimed_by: $($HostConfig.HostId)
claimed_at: $((Get-Date).ToUniversalTime().ToString("o"))
claim_head_sha: $headSha
"@
        Invoke-GitHubApi -Method "PATCH" -Uri "https://api.github.com/repos/$owner/$repo/issues/comments/$($Context.QueueComment.id)" -Token $Token -Body @{ body = $body } | Out-Null
    }

    return @{
        HeadSha = $headSha
    }
}

function Release-ReviewQueueItem {
    param(
        [hashtable]$Context,
        [string]$Token,
        [hashtable]$Labels,
        [string]$Reason
    )

    $owner = $Context.Owner
    $repo = $Context.Repo
    $number = $Context.Number

    Remove-IssueLabel -Owner $owner -Repo $repo -Number $number -Token $Token -Label $Labels.InProgressLabel
    Add-IssueLabels -Owner $owner -Repo $repo -Number $number -Token $Token -Labels @($Labels.PendingLabel)

    if ($null -ne $Context.QueueComment) {
        $body = $Context.QueueComment.body.TrimEnd() + "`n`nrelease_reason: $Reason"
        Invoke-GitHubApi -Method "PATCH" -Uri "https://api.github.com/repos/$owner/$repo/issues/comments/$($Context.QueueComment.id)" -Token $Token -Body @{ body = $body } | Out-Null
    }
}

function Invoke-ReviewAgentPasses {
    param(
        [hashtable]$HostConfig,
        [hashtable]$JobSpec,
        [hashtable]$Logger,
        [hashtable]$Context
    )

    $repoPath = Resolve-RunnerRepoPath -HostConfig $HostConfig -JobSpec $JobSpec
    $promptPath = Join-Path $repoPath $JobSpec.PromptPath
    $artifactPath = Join-Path $HostConfig.ArtifactRoot "$($JobSpec.JobId)-$($Context.Owner)-$($Context.Repo)-$($Context.Number)-$($Context.QueueHeadSha).md"

    $prompt = @"
You are running the HoneyDrunk Grid review agent.

Canonical agent file: $promptPath
Pull request: $($Context.HtmlUrl)
Repository: $($Context.Owner)/$($Context.Repo)
PR number: $($Context.Number)
Head SHA: $($Context.QueueHeadSha)

Load the canonical review prompt, ADR-0086 context, the PR diff, and the linked packet from the PR body. Return only the advisory review verdict body. Do not post comments yourself; the runner posts the final synthesized verdict.
"@

    $prompt | Set-Content -LiteralPath $artifactPath -Encoding UTF8

    $outputs = @()
    foreach ($command in $JobSpec.AgentCommands) {
        $stdout = Invoke-AgentCommand -CommandSpec $command -PromptPath $artifactPath -WorkingDirectory $repoPath -Logger $Logger -TimeoutMinutes $JobSpec.TimeoutMinutes
        $outputs += "## $($command.Name)`n`n$stdout"
    }

    return $outputs -join "`n`n"
}

function Complete-ReviewQueueItem {
    param(
        [hashtable]$Context,
        [string]$Token,
        [hashtable]$Labels,
        [string]$VerdictBody
    )

    $owner = $Context.Owner
    $repo = $Context.Repo
    $number = $Context.Number
    $completionLabel = if ($VerdictBody -match "(?im)\b(Block|Request Changes)\b") { $Labels.FailureLabel } else { $Labels.SuccessLabel }

    $body = @"
<!-- honeydrunk-grid-review-verdict:v1 -->

$VerdictBody

_Reviewed head SHA: `$($Context.QueueHeadSha)`._
"@

    Invoke-GitHubApi -Method "POST" -Uri "https://api.github.com/repos/$owner/$repo/issues/$number/comments" -Token $Token -Body @{ body = $body } | Out-Null

    Remove-IssueLabel -Owner $owner -Repo $repo -Number $number -Token $Token -Label $Labels.InProgressLabel
    foreach ($label in $Labels.RemoveOnCompletionLabels) {
        Remove-IssueLabel -Owner $owner -Repo $repo -Number $number -Token $Token -Label $label
    }

    Add-IssueLabels -Owner $owner -Repo $repo -Number $number -Token $Token -Labels @($completionLabel)
}

function Add-IssueLabels {
    param(
        [string]$Owner,
        [string]$Repo,
        [int]$Number,
        [string]$Token,
        [string[]]$Labels
    )

    $labelsToAdd = @($Labels | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($labelsToAdd.Count -eq 0) {
        return
    }

    Invoke-GitHubApi -Method "POST" -Uri "https://api.github.com/repos/$Owner/$Repo/issues/$Number/labels" -Token $Token -Body @{ labels = $labelsToAdd } | Out-Null
}

function Remove-IssueLabel {
    param(
        [string]$Owner,
        [string]$Repo,
        [int]$Number,
        [string]$Token,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Label)) {
        return
    }

    $encodedLabel = [System.Uri]::EscapeDataString($Label)
    try {
        Invoke-GitHubApi -Method "DELETE" -Uri "https://api.github.com/repos/$Owner/$Repo/issues/$Number/labels/$encodedLabel" -Token $Token | Out-Null
    }
    catch {
        # Missing labels are expected when another runner or maintainer touched the queue first.
    }
}

Export-ModuleMember -Function Invoke-GridReviewQueueTick
