function Invoke-GridReviewQueueTick {
    param(
        [hashtable]$HostConfig,
        [hashtable]$JobSpec,
        [hashtable]$Logger,
        [switch]$DryRun
    )

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
    Invoke-StaleClaimSweep -HostConfig $HostConfig -JobSpec $JobSpec -Logger $Logger -Token $token
    $items = Get-ReviewQueueItems -JobSpec $JobSpec -Token $token

    if ($items.Count -eq 0) {
        Write-RunnerLog -Logger $Logger -Level "INFO" -Message "Review queue is empty."
        return @{
            status = "empty"
            message = "No PRs carried needs-agent-review."
            latest_output = $JobSpec.OutputContract.LatestOutput
            artifacts = @()
        }
    }

    $item = $items | Select-Object -First 1
    Write-RunnerLog -Logger $Logger -Level "INFO" -Message "Review queue item selected." -Data @{
        url = $item.html_url
    }

    $context = Get-ReviewQueueContext -IssueItem $item -Token $token -QueueCommentMarker $JobSpec.Queue.QueueCommentMarker
    $claim = Claim-ReviewQueueItem -Context $context -HostConfig $HostConfig -Token $token
    $preflight = Get-ReviewQueueContext -IssueItem $item -Token $token -QueueCommentMarker $JobSpec.Queue.QueueCommentMarker

    if ($preflight.QueueHeadSha -ne $claim.HeadSha) {
        Release-ReviewQueueItem -Context $preflight -Token $token -Reason "claim invalidated; head advanced to $($preflight.QueueHeadSha)"
        return @{
            status = "empty"
            message = "Claim invalidated before agent invocation because head advanced."
            latest_output = $JobSpec.OutputContract.LatestOutput
            artifacts = @($item.html_url)
        }
    }

    $verdict = Invoke-ReviewAgentPasses -HostConfig $HostConfig -JobSpec $JobSpec -Logger $Logger -Context $context
    $postflight = Get-ReviewQueueContext -IssueItem $item -Token $token -QueueCommentMarker $JobSpec.Queue.QueueCommentMarker
    if ($postflight.QueueHeadSha -ne $claim.HeadSha) {
        Release-ReviewQueueItem -Context $postflight -Token $token -Reason "claim invalidated after agent invocation; head advanced to $($postflight.QueueHeadSha)"
        return @{
            status = "empty"
            message = "Verdict discarded because PR head advanced during review."
            latest_output = $JobSpec.OutputContract.LatestOutput
            artifacts = @($item.html_url)
        }
    }

    Complete-ReviewQueueItem -Context $postflight -Token $token -VerdictBody $verdict

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
        [string]$Token
    )

    $query = if ($JobSpec.ContainsKey("Queue") -and $JobSpec.Queue.ContainsKey("SearchQuery")) {
        $JobSpec.Queue.SearchQuery
    }
    else {
        "is:pr is:open label:needs-agent-review org:HoneyDrunkStudios"
    }

    $uri = "https://api.github.com/search/issues?q=$([System.Uri]::EscapeDataString($query))&sort=updated&order=asc"
    $response = Invoke-GitHubApi -Method "GET" -Uri $uri -Token $Token
    return @($response.items)
}

function Invoke-StaleClaimSweep {
    param(
        [hashtable]$HostConfig,
        [hashtable]$JobSpec,
        [hashtable]$Logger,
        [string]$Token
    )

    $minutes = if ($JobSpec.Queue.ContainsKey("StaleClaimMinutes")) { $JobSpec.Queue.StaleClaimMinutes } else { 15 }
    Write-RunnerLog -Logger $Logger -Level "INFO" -Message "Stale-claim sweep starting." -Data @{
        stale_claim_minutes = $minutes
    }

    # The v1 sweep intentionally logs the configured threshold here. The claim-comment
    # mutation path is kept with the queue protocol implementation so it can share parsing.
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

    if ($Body -match "(?im)head_sha\s*[:=]\s*`?([a-f0-9]{7,40})`?") {
        return $Matches[1]
    }

    if ($Body -match '"head_sha"\s*:\s*"([a-f0-9]{7,40})"') {
        return $Matches[1]
    }

    return $null
}

function Claim-ReviewQueueItem {
    param(
        [hashtable]$Context,
        [hashtable]$HostConfig,
        [string]$Token
    )

    $owner = $Context.Owner
    $repo = $Context.Repo
    $number = $Context.Number
    $headSha = $Context.QueueHeadSha

    try {
        Invoke-GitHubApi -Method "DELETE" -Uri "https://api.github.com/repos/$owner/$repo/issues/$number/labels/needs-agent-review" -Token $Token | Out-Null
    }
    catch {
        # Missing label means another runner probably raced this one; the follow-up add/comment edit still converges.
    }

    Invoke-GitHubApi -Method "POST" -Uri "https://api.github.com/repos/$owner/$repo/issues/$number/labels" -Token $Token -Body @{ labels = @("agent-review-in-progress") } | Out-Null

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
        [string]$Reason
    )

    $owner = $Context.Owner
    $repo = $Context.Repo
    $number = $Context.Number

    try {
        Invoke-GitHubApi -Method "DELETE" -Uri "https://api.github.com/repos/$owner/$repo/issues/$number/labels/agent-review-in-progress" -Token $Token | Out-Null
    }
    catch {
    }

    Invoke-GitHubApi -Method "POST" -Uri "https://api.github.com/repos/$owner/$repo/issues/$number/labels" -Token $Token -Body @{ labels = @("needs-agent-review") } | Out-Null

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
        [string]$VerdictBody
    )

    $owner = $Context.Owner
    $repo = $Context.Repo
    $number = $Context.Number
    $completionLabel = if ($VerdictBody -match "(?im)\b(Block|Request Changes)\b") { "changes-requested-by-agent" } else { "agent-reviewed" }

    $body = @"
<!-- honeydrunk-grid-review-verdict:v1 -->

$VerdictBody

_Reviewed head SHA: `$($Context.QueueHeadSha)`._
"@

    Invoke-GitHubApi -Method "POST" -Uri "https://api.github.com/repos/$owner/$repo/issues/$number/comments" -Token $Token -Body @{ body = $body } | Out-Null

    try {
        Invoke-GitHubApi -Method "DELETE" -Uri "https://api.github.com/repos/$owner/$repo/issues/$number/labels/agent-review-in-progress" -Token $Token | Out-Null
    }
    catch {
    }

    Invoke-GitHubApi -Method "POST" -Uri "https://api.github.com/repos/$owner/$repo/issues/$number/labels" -Token $Token -Body @{ labels = @($completionLabel) } | Out-Null
}

Export-ModuleMember -Function Invoke-GridReviewQueueTick
