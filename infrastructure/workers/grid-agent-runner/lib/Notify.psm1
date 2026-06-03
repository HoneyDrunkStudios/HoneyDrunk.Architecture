Import-Module (Join-Path $PSScriptRoot "Secrets.psm1") -Force

function Invoke-RunnerCompletionNotification {
    param(
        [hashtable]$HostConfig,
        [hashtable]$JobSpec,
        [hashtable]$Result,
        [datetime]$StartedAt,
        [datetime]$FinishedAt,
        [hashtable]$Logger,
        [switch]$DryRun
    )

    try {
        if ($DryRun) {
            Write-RunnerLog -Logger $Logger -Level "DEBUG" -Message "Skipping Discord notification for dry-run."
            return
        }

        $discordConfig = Get-RunnerDiscordConfig -JobSpec $JobSpec
        if ($null -eq $discordConfig -or $discordConfig.Enabled -ne $true) {
            return
        }

        $status = if ([string]::IsNullOrWhiteSpace([string]$Result.status)) { "unknown" } else { [string]$Result.status }
        if ($status -in @("empty", "dry-run", "skipped")) {
            Write-RunnerLog -Logger $Logger -Level "DEBUG" -Message "Skipping Discord notification for non-actionable runner result." -Data @{
                status = $status
            }
            return
        }

        $duration = New-TimeSpan -Start $StartedAt -End $FinishedAt
        $repoPath = Resolve-RunnerNotificationRepoPath -HostConfig $HostConfig -JobSpec $JobSpec
        $summary = Get-RunnerJobSummary -JobSpec $JobSpec -RepoPath $repoPath
        $description = Format-RunnerDiscordDescription -JobSpec $JobSpec -Result $Result -Summary $summary

        if (-not (Test-RunnerDiscordPayloadSafe -Value $description)) {
            $description = "Summary suppressed by runner redaction guard. See local job log for details."
        }

        $description = Limit-RunnerDiscordText -Value $description -MaxLength 3900
        $webhookUrl = Get-RunnerSecret -HostConfig $HostConfig -SecretName $discordConfig.SecretName
        $timeoutSec = if ($discordConfig.ContainsKey("TimeoutSeconds") -and [int]$discordConfig.TimeoutSeconds -gt 0) {
            [int]$discordConfig.TimeoutSeconds
        }
        else {
            10
        }

        $payload = @{
            username = "HoneyDrunk Grid Runner"
            allowed_mentions = @{
                parse = @()
            }
            embeds = @(
                @{
                    title = "$($JobSpec.JobId): $status"
                    description = $description
                    color = Get-RunnerDiscordColor -Status $status
                    fields = Get-RunnerDiscordFields -JobSpec $JobSpec -Result $Result -DiscordConfig $discordConfig -Duration $duration
                    timestamp = $FinishedAt.ToString("o")
                }
            )
        }

        Invoke-RestMethod -Method Post -Uri $webhookUrl -Body ($payload | ConvertTo-Json -Depth 10) -ContentType "application/json" -TimeoutSec $timeoutSec | Out-Null
        Write-RunnerLog -Logger $Logger -Level "INFO" -Message "Posted Discord runner completion notification." -Data @{
            channel = $discordConfig.Channel
            status = $status
        }
    }
    catch {
        Write-RunnerLog -Logger $Logger -Level "WARN" -Message "Discord runner notification failed; job result is unchanged." -Data @{
            error = $_.Exception.Message
        }
    }
}

function Get-RunnerDiscordFields {
    param(
        [hashtable]$JobSpec,
        [hashtable]$Result,
        [hashtable]$DiscordConfig,
        [timespan]$Duration
    )

    $fields = New-Object System.Collections.Generic.List[hashtable]
    $fields.Add(@{ name = "Repo"; value = Get-RunnerDiscordRepoFieldValue -JobSpec $JobSpec -Result $Result; inline = $true })
    $fields.Add(@{ name = "Duration"; value = Format-RunnerDuration -Duration $Duration; inline = $true })
    $fields.Add(@{ name = "Channel"; value = [string]$DiscordConfig.Channel; inline = $true })

    $prUrl = Get-RunnerReviewPullRequestUrl -Result $Result
    if (-not [string]::IsNullOrWhiteSpace($prUrl)) {
        $fields.Add(@{ name = "PR"; value = $prUrl; inline = $false })
    }

    $verdict = Get-RunnerReviewVerdict -Result $Result
    if (-not [string]::IsNullOrWhiteSpace($verdict)) {
        $fields.Add(@{ name = "Review Verdict"; value = $verdict; inline = $true })
    }

    return $fields.ToArray()
}

function Get-RunnerDiscordRepoFieldValue {
    param(
        [hashtable]$JobSpec,
        [hashtable]$Result
    )

    $candidate = [string]$Result.review_repo
    if ($candidate -match "^HoneyDrunkStudios/[A-Za-z0-9_.-]+$") {
        return $candidate
    }

    return [string]$JobSpec.Repo
}

function Get-RunnerReviewPullRequestUrl {
    param([hashtable]$Result)

    $candidate = [string]$Result.pr_url
    if ([string]::IsNullOrWhiteSpace($candidate) -and $Result.ContainsKey("artifacts")) {
        $candidate = @($Result.artifacts | Where-Object { $_ -match "^https://github\.com/HoneyDrunkStudios/[A-Za-z0-9_.-]+/pull/[1-9][0-9]*$" } | Select-Object -First 1)
    }

    if ($candidate -match "^https://github\.com/HoneyDrunkStudios/[A-Za-z0-9_.-]+/pull/[1-9][0-9]*$") {
        return $candidate
    }

    return $null
}

function Get-RunnerReviewVerdict {
    param([hashtable]$Result)

    $candidate = [string]$Result.review_verdict
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        return $null
    }

    $normalized = ($candidate -replace "[^\p{L}\p{N}\s/-]", "").Trim()
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return $null
    }

    if (-not (Test-RunnerDiscordPayloadSafe -Value $normalized)) {
        return $null
    }

    return (Limit-RunnerDiscordText -Value $normalized -MaxLength 120)
}

function Get-RunnerDiscordConfig {
    param([hashtable]$JobSpec)

    if ($null -eq $JobSpec) {
        return $null
    }

    if (-not $JobSpec.ContainsKey("Notifications") -or $null -eq $JobSpec.Notifications) {
        return $null
    }

    if (-not $JobSpec.Notifications.ContainsKey("Discord") -or $null -eq $JobSpec.Notifications.Discord) {
        return $null
    }

    $sourceConfig = $JobSpec.Notifications.Discord
    $config = @{}
    foreach ($key in $sourceConfig.Keys) {
        $config[$key] = $sourceConfig[$key]
    }

    if (-not $config.ContainsKey("Enabled")) {
        $config["Enabled"] = $true
    }

    if ($config.Enabled -eq $false) {
        return $config
    }

    foreach ($key in @("Channel", "SecretName")) {
        if (-not $config.ContainsKey($key) -or [string]::IsNullOrWhiteSpace([string]$config[$key])) {
            throw "Job '$($JobSpec.JobId)' Discord notification config is missing '$key'."
        }
    }

    return $config
}

function Resolve-RunnerNotificationRepoPath {
    param(
        [hashtable]$HostConfig,
        [hashtable]$JobSpec
    )

    if ($null -eq $HostConfig -or -not $HostConfig.ContainsKey("Repositories") -or $null -eq $HostConfig.Repositories -or -not $HostConfig.Repositories.ContainsKey($JobSpec.Repo)) {
        return $null
    }

    return [string]$HostConfig.Repositories[$JobSpec.Repo]
}

function Format-RunnerDiscordDescription {
    param(
        [hashtable]$JobSpec,
        [hashtable]$Result,
        [string[]]$Summary
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $status = if ([string]::IsNullOrWhiteSpace([string]$Result.status)) { "unknown" } else { [string]$Result.status }
    $lines.Add("Runner status: $status")

    foreach ($line in $Summary) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $lines.Add($line)
        }
    }

    if ($lines.Count -eq 0 -and $JobSpec.ContainsKey("OutputContract")) {
        $lines.Add([string]$JobSpec.OutputContract.Summary)
    }

    return ($lines -join "`n")
}

function Get-RunnerJobSummary {
    param(
        [hashtable]$JobSpec,
        [string]$RepoPath
    )

    $outputPath = Resolve-RunnerLatestOutputPath -JobSpec $JobSpec -RepoPath $RepoPath
    if ([string]::IsNullOrWhiteSpace($outputPath) -or -not (Test-Path -LiteralPath $outputPath)) {
        return @([string]$JobSpec.OutputContract.Summary)
    }

    $outputItem = Get-Item -LiteralPath $outputPath
    if ($outputItem.PSIsContainer) {
        $outputFile = Get-ChildItem -LiteralPath $outputItem.FullName -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($null -eq $outputFile) {
            return @([string]$JobSpec.OutputContract.Summary)
        }

        $outputPath = $outputFile.FullName
    }

    $content = Get-Content -LiteralPath $outputPath -Raw
    switch ($JobSpec.JobId) {
        "hive-sync" { return Get-HiveSyncSummary -Content $content }
        "docs-sync" { return Get-DocsSyncSummary -Content $content }
        "backlog-strategic-scope" { return Get-BacklogGenerationSummary -Content $content -Fallback "Strategic backlog source report generated." }
        "backlog-tactical-audit" { return Get-BacklogGenerationSummary -Content $content -Fallback "Tactical audit report generated." }
        "backlog-opportunistic-scout" { return Get-BacklogGenerationSummary -Content $content -Fallback "Opportunistic Scout report generated." }
        "backlog-weekly-briefing" { return Get-BacklogGenerationSummary -Content $content -Fallback "Weekly backlog briefing generated." }
        "lore-source" { return Get-LoreSourceSummary -Content $content }
        "lore-ingest" { return Get-LoreIngestSummary -Content $content }
        "lore-signal-review" { return Get-LoreSignalReviewSummary -Content $content }
        default { return @("Generated output captured locally; Discord summary suppressed for this job type.") }
    }
}

function Resolve-RunnerLatestOutputPath {
    param(
        [hashtable]$JobSpec,
        [string]$RepoPath
    )

    if ([string]::IsNullOrWhiteSpace($RepoPath) -or -not $JobSpec.ContainsKey("OutputContract")) {
        return $null
    }

    $latestOutput = [string]$JobSpec.OutputContract.LatestOutput
    if ([string]::IsNullOrWhiteSpace($latestOutput) -or $latestOutput -eq "github-pr-comment") {
        return $null
    }

    if ($latestOutput.Contains("YYYY-MM-DD")) {
        $globOutput = $latestOutput.Replace("{YYYY-MM-DD}", "*").Replace("YYYY-MM-DD", "*")
        $pattern = [System.IO.Path]::GetFileName($globOutput)
        $directory = Join-Path $RepoPath ([System.IO.Path]::GetDirectoryName($latestOutput))
        $latest = Get-ChildItem -LiteralPath $directory -Filter $pattern -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($null -ne $latest) {
            return $latest.FullName
        }

        return $null
    }

    return Join-Path $RepoPath $latestOutput
}

function Invoke-RunnerNotifySelfTest {
    $disabledSpec = @{
        JobId = "disabled-test"
        Repo = "HoneyDrunk.Test"
        Notifications = @{
            Discord = @{
                Enabled = $false
            }
        }
        OutputContract = @{
            LatestOutput = "github-pr-comment"
            Summary = "disabled"
        }
    }

    $disabled = Get-RunnerDiscordConfig -JobSpec $disabledSpec
    if ($null -eq $disabled -or $disabled.Enabled -ne $false) {
        throw "Disabled Discord config should return without requiring Channel or SecretName."
    }

    $defaultSpec = @{
        JobId = "default-test"
        Repo = "HoneyDrunk.Test"
        Notifications = @{
            Discord = @{
                Channel = "agent-activity"
                SecretName = "Discord--AgentActivity--RunnerWebhookUrl"
            }
        }
        OutputContract = @{
            LatestOutput = "github-pr-comment"
            Summary = "default"
        }
    }

    $default = Get-RunnerDiscordConfig -JobSpec $defaultSpec
    if ($default.Enabled -ne $true) {
        throw "Discord config should default Enabled on the effective config."
    }

    if ($defaultSpec.Notifications.Discord.ContainsKey("Enabled")) {
        throw "Discord config should not mutate the job spec when defaulting Enabled."
    }

    $reviewFields = @(Get-RunnerDiscordFields -JobSpec $defaultSpec -Result @{
        status = "completed"
        pr_url = "https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/pull/549"
        review_repo = "HoneyDrunkStudios/HoneyDrunk.Architecture"
        review_verdict = "Approved"
        artifacts = @("https://evil.example.invalid/HoneyDrunkStudios/HoneyDrunk.Architecture/pull/549")
    } -DiscordConfig @{ Channel = "agent-activity" } -Duration ([timespan]::FromSeconds(5)))
    if (-not (@($reviewFields | Where-Object { $_.name -eq "Repo" -and $_.value -eq "HoneyDrunkStudios/HoneyDrunk.Architecture" }).Count -eq 1)) {
        throw "Review Discord fields should prefer the reviewed repository over the runner working repository."
    }
    if (-not (@($reviewFields | Where-Object { $_.name -eq "PR" -and $_.value -eq "https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/pull/549" }).Count -eq 1)) {
        throw "Review Discord fields should include a validated HoneyDrunk PR URL."
    }
    if (-not (@($reviewFields | Where-Object { $_.name -eq "Review Verdict" -and $_.value -eq "Approved" }).Count -eq 1)) {
        throw "Review Discord fields should include a sanitized review verdict."
    }

    $fallbackReviewRepoCases = @(
        @{
            Name = "missing review_repo"
            Result = @{ status = "completed" }
        },
        @{
            Name = "cross-org review_repo"
            Result = @{
                status = "completed"
                review_repo = "OtherOrg/HoneyDrunk.Architecture"
            }
        },
        @{
            Name = "URL-shaped review_repo"
            Result = @{
                status = "completed"
                review_repo = "https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture"
            }
        },
        @{
            Name = "malformed review_repo"
            Result = @{
                status = "completed"
                review_repo = "HoneyDrunkStudios/HoneyDrunk.Architecture/pull/549"
            }
        }
    )
    foreach ($case in $fallbackReviewRepoCases) {
        $fallbackFields = @(Get-RunnerDiscordFields -JobSpec $defaultSpec -Result $case.Result -DiscordConfig @{ Channel = "agent-activity" } -Duration ([timespan]::FromSeconds(5)))
        if (-not (@($fallbackFields | Where-Object { $_.name -eq "Repo" -and $_.value -eq "HoneyDrunk.Test" }).Count -eq 1)) {
            throw "Review Discord fields should fall back to the job repo for $($case.Name)."
        }
    }

    $unsafeValues = @(
        "token = honeydrunk_local_fixture_value_1234567890",
        "Authorization: Bearer local.fixture.value.with.enough.length",
        "DefaultEndpointsProtocol=https;AccountName=acct;AccountKey=localfixturekey12345678901234567890;EndpointSuffix=core.windows.net",
        "AKIAIOSFODNN7EXAMPLE",
        "xoxb-local-fixture-value-123456789012345678",
        "https://example.invalid/webhook/localfixturesecret12345678901234567890",
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.localfixturepayload.localfixturesignature"
    )
    foreach ($unsafe in $unsafeValues) {
        if (Test-RunnerDiscordPayloadSafe -Value $unsafe) {
            throw "Secret-like payload should be rejected before truncation."
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("runner-notify-test-" + [guid]::NewGuid().ToString("n"))
    try {
        $genericSpec = @{
            JobId = "generic-test"
            Repo = "HoneyDrunk.Test"
            OutputContract = @{
                LatestOutput = "reports/generic.md"
                Summary = "generic"
            }
        }

        $genericDir = Join-Path $tempRoot "reports"
        New-Item -ItemType Directory -Path $genericDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $genericDir "generic.md") -Value "secret-looking generated output should stay local" -Encoding UTF8
        $genericSummary = @(Get-RunnerJobSummary -JobSpec $genericSpec -RepoPath $tempRoot)
        if ($genericSummary[0] -ne "Generated output captured locally; Discord summary suppressed for this job type.") {
            throw "Generic job summaries must not forward generated markdown output to Discord."
        }

        $reportDir = Join-Path $tempRoot "directory-reports"
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
        $old = Join-Path $reportDir "old.md"
        $new = Join-Path $reportDir "new.md"
        Set-Content -LiteralPath $old -Value "- **Category one**" -Encoding UTF8
        Set-Content -LiteralPath $new -Value "- **Category one**`n- **Category two**" -Encoding UTF8
        (Get-Item -LiteralPath $old).LastWriteTimeUtc = [datetime]::UtcNow.AddMinutes(-5)
        (Get-Item -LiteralPath $new).LastWriteTimeUtc = [datetime]::UtcNow

        $directorySpec = @{
            JobId = "hive-sync"
            Repo = "HoneyDrunk.Test"
            OutputContract = @{
                LatestOutput = "directory-reports/"
                Summary = "directory"
            }
        }
        $resolved = Resolve-RunnerLatestOutputPath -JobSpec $directorySpec -RepoPath $tempRoot
        if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
            throw "Directory LatestOutput should resolve to the configured directory path."
        }

        $summary = @(Get-RunnerJobSummary -JobSpec $directorySpec -RepoPath $tempRoot)
        if ($summary[0] -ne "Drift findings: 2") {
            throw "Directory LatestOutput should summarize the newest file."
        }

        $docsReportDir = Join-Path $tempRoot "docs-sync-reports"
        New-Item -ItemType Directory -Path $docsReportDir -Force | Out-Null
        $docsReport = Join-Path $docsReportDir "2026-06-01.md"
        Set-Content -LiteralPath $docsReport -Value @"
# Docs Sync Report - 2026-06-01

## Summary

- Repos scanned: 25
- Clean: 20
- Skipped: 3
- Report-only findings: 1
- PRs opened or updated: 1

## Repositories

### HoneyDrunk.Architecture

- Status: actionable
- PR: https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/pull/600
"@ -Encoding UTF8

        $docsSpec = @{
            JobId = "docs-sync"
            Repo = "HoneyDrunk.Test"
            OutputContract = @{
                LatestOutput = "docs-sync-reports/{YYYY-MM-DD}.md"
                Summary = "docs"
            }
        }
        $docsSummary = @(Get-RunnerJobSummary -JobSpec $docsSpec -RepoPath $tempRoot)
        if (-not ($docsSummary -contains "- Repos scanned: 25")) {
            throw "docs-sync summaries should include report counts."
        }
        if (-not ($docsSummary -contains "- PR: https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/pull/600")) {
            throw "docs-sync summaries should include validated HoneyDrunk PR links."
        }

        $backlogReportDir = Join-Path $tempRoot "briefings"
        New-Item -ItemType Directory -Path $backlogReportDir -Force | Out-Null
        $backlogReport = Join-Path $backlogReportDir "2026-06-03-strategic-source.md"
        Set-Content -LiteralPath $backlogReport -Value @"
# Strategic Backlog Source - 2026-06-03

## Summary
- Decisions scanned: 31
- Proposed packets created: 1

## Recommendation Breakdown
- **ADR-0084 routing drift**
  - Recommendation: promote the proposed packet after review.
  - Why: hive-sync is repeatedly surfacing the same routing drift.
  - Human action: move the packet to active when ready.

## Notes For Weekly Briefing
- Weekly briefing should call out the routing-drift packet.
"@ -Encoding UTF8

        $backlogSpec = @{
            JobId = "backlog-strategic-scope"
            Repo = "HoneyDrunk.Test"
            OutputContract = @{
                LatestOutput = "briefings/{YYYY-MM-DD}-strategic-source.md"
                Summary = "backlog"
            }
        }
        $backlogSummary = @(Get-RunnerJobSummary -JobSpec $backlogSpec -RepoPath $tempRoot)
        if (-not ($backlogSummary -contains "Recommendations:")) {
            throw "backlog summaries should include the recommendation section marker."
        }
        if (-not ($backlogSummary -contains "- Recommendation: promote the proposed packet after review.")) {
            throw "backlog summaries should include actionable recommendation detail."
        }
        if (-not ($backlogSummary -contains "- Weekly briefing should call out the routing-drift packet.")) {
            throw "backlog summaries should collect recommendation detail across multiple sections."
        }
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-HiveSyncSummary {
    param([string]$Content)

    $findings = @($Content -split "`r?`n" | Where-Object { $_ -match "^- \*\*Category " })
    $items = @($Content -split "`r?`n" | Where-Object { $_ -match "^\s+- \*\*Item:\*\*" } | Select-Object -First 5)
    $lines = @("Drift findings: $($findings.Count)")
    foreach ($item in $items) {
        $lines += ($item -replace "^\s+- \*\*Item:\*\*\s*", "- ")
    }

    return $lines
}

function Get-DocsSyncSummary {
    param([string]$Content)

    $lines = New-Object System.Collections.Generic.List[string]
    $summary = [regex]::Match($Content, "(?s)## Summary\s+(.+?)(?:\r?\n## |\z)")
    if ($summary.Success) {
        foreach ($line in @($summary.Groups[1].Value -split "`r?`n" | Where-Object { $_ -match "^- " } | Select-Object -First 6)) {
            $clean = $line.Trim()
            if (Test-RunnerDiscordPayloadSafe -Value $clean) {
                $lines.Add($clean)
            }
        }
    }

    $prs = @(
        $Content -split "`r?`n" |
            ForEach-Object {
                $match = [regex]::Match($_, "^\s*- PR:\s+(https://github\.com/HoneyDrunkStudios/[A-Za-z0-9_.-]+/pull/[1-9][0-9]*)\s*$")
                if ($match.Success) {
                    "- PR: $($match.Groups[1].Value)"
                }
            } |
            Select-Object -First 5
    )
    if ($prs.Count -gt 0) {
        $lines.Add("PRs:")
        foreach ($pr in $prs) {
            $cleanPr = $pr.Trim()
            if (Test-RunnerDiscordPayloadSafe -Value $cleanPr) {
                $lines.Add($cleanPr)
            }
        }
    }

    if ($lines.Count -eq 0) {
        $lines.Add("Docs sync report generated; no summary rows found.")
    }

    return $lines.ToArray()
}

function Get-BacklogGenerationSummary {
    param(
        [string]$Content,
        [string]$Fallback
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $summary = [regex]::Match($Content, "(?s)## Summary\s+(.+?)(?:\n## |\z)")
    if ($summary.Success) {
        foreach ($line in @($summary.Groups[1].Value -split "`r?`n" | Where-Object { $_ -match "^- " } | Select-Object -First 6)) {
            $clean = $line.Trim()
            if (Test-RunnerDiscordPayloadSafe -Value $clean) {
                $lines.Add($clean)
            }
        }
    }

    $recommendations = @(Get-BacklogRecommendationLines -Content $Content -MaxLines 8)
    if ($recommendations.Count -gt 0) {
        if ($lines.Count -gt 0) {
            $lines.Add("")
        }

        $lines.Add("Recommendations:")
        foreach ($recommendation in $recommendations) {
            if (Test-RunnerDiscordPayloadSafe -Value $recommendation) {
                $lines.Add($recommendation)
            }
        }
    }

    if ($lines.Count -eq 0) {
        $verdict = [regex]::Match($Content, "(?m)^\*\*Verdict:\*\*\s*(.+)$")
        if ($verdict.Success) {
            $cleanVerdict = "Verdict: $($verdict.Groups[1].Value.Trim())"
            if (Test-RunnerDiscordPayloadSafe -Value $cleanVerdict) {
                $lines.Add($cleanVerdict)
            }
        }
    }

    if ($lines.Count -eq 0) {
        foreach ($heading in @($Content -split "`r?`n" | Where-Object { $_ -match "^## (Recommended Top 3|Recommendation|Findings Summary|Notes For Weekly Briefing)" } | Select-Object -First 2)) {
            $cleanHeading = ($heading -replace "^##\s*", "")
            if (Test-RunnerDiscordPayloadSafe -Value $cleanHeading) {
                $lines.Add($cleanHeading)
            }
        }
    }

    if ($lines.Count -eq 0) {
        $lines.Add($Fallback)
    }

    return $lines.ToArray()
}

function Get-BacklogRecommendationLines {
    param(
        [string]$Content,
        [int]$MaxLines = 8
    )

    $sectionNames = @(
        "Recommendation Breakdown",
        "Recommended Top 3",
        "Notes For Weekly Briefing",
        "Decisions Scoped",
        "New Proposed Packets"
    )

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($sectionName in $sectionNames) {
        $escaped = [regex]::Escape($sectionName)
        $section = [regex]::Match($Content, "(?ms)^##\s+$escaped\s*\r?\n(.+?)(?=^##\s+|\z)")
        if (-not $section.Success) {
            continue
        }

        foreach ($line in @($section.Groups[1].Value -split "`r?`n")) {
            $clean = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($clean)) {
                continue
            }

            if ($clean -match '^```' -or $clean -match '^#+\s+') {
                continue
            }

            if ($clean -match '^[-*]\s+' -or $clean -match '^\d+\.\s+' -or $clean -match '^(Recommendation|Why|Why now / Why not now|Human action|Suggested human action|Urgency|Source|Tradeoff|Opportunity cost|Kill criteria|Packet|Proposed packet path|Dedupe/Skipped reason):\s+') {
                $clean = ($clean -replace "\s+", " ").Trim()
                if (Test-RunnerDiscordPayloadSafe -Value $clean) {
                    $lines.Add((Limit-RunnerDiscordText -Value $clean -MaxLength 280))
                }
            }

            if ($lines.Count -ge $MaxLines) {
                return $lines.ToArray()
            }
        }

    }

    return $lines.ToArray()
}

function Get-LoreSourceSummary {
    param([string]$Content)

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($label in @("Candidates scanned", "Saved count", "Skipped duplicate count")) {
        $match = [regex]::Match($Content, "(?m)^$([regex]::Escape($label)):\s*(.+)$")
        if ($match.Success) {
            $lines.Add("$label`: $($match.Groups[1].Value)")
        }
    }

    $written = @($Content -split "`r?`n" | Where-Object { $_ -match "^- raw/" } | Select-Object -First 5)
    if ($written.Count -gt 0) {
        $lines.Add("Saved sources:")
        foreach ($item in $written) {
            $lines.Add($item)
        }
    }

    return $lines.ToArray()
}

function Get-LoreIngestSummary {
    param([string]$Content)

    $lines = New-Object System.Collections.Generic.List[string]
    $ingested = [regex]::Match($Content, "(?m)^## Raw sources ingested:\s*(\d+)")
    if ($ingested.Success) {
        $lines.Add("Raw sources ingested: $($ingested.Groups[1].Value)")
    }

    $wikiSection = [regex]::Match($Content, "(?s)## Wiki pages created/updated\s+(.+?)(?:\n## |\z)")
    if ($wikiSection.Success) {
        $wikiLines = @($wikiSection.Groups[1].Value -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 4)
        foreach ($line in $wikiLines) {
            $lines.Add($line.Trim())
        }
    }

    $gaps = [regex]::Match($Content, "(?s)## Gaps logged\s+(.+?)(?:\n## |\z)")
    if ($gaps.Success) {
        $gapLines = @($gaps.Groups[1].Value -split "`r?`n" | Where-Object { $_ -match "^- " } | Select-Object -First 3)
        if ($gapLines.Count -gt 0) {
            $lines.Add("Gaps:")
            foreach ($line in $gapLines) {
                $lines.Add($line.Trim())
            }
        }
    }

    return $lines.ToArray()
}

function Get-LoreSignalReviewSummary {
    param([string]$Content)

    $lines = New-Object System.Collections.Generic.List[string]
    $executive = [regex]::Match($Content, "(?s)## Executive verdict\s+(.+?)(?:\n## |\z)")
    if ($executive.Success) {
        foreach ($line in @($executive.Groups[1].Value -split "`r?`n" | Where-Object { $_ -match "^- " } | Select-Object -First 3)) {
            $lines.Add($line.Trim())
        }
    }

    $consider = [regex]::Match($Content, "(?s)## Consider now\s+(.+?)(?:\n## |\z)")
    if ($consider.Success) {
        $first = @($consider.Groups[1].Value -split "`r?`n" | Where-Object { $_ -match "^- " } | Select-Object -First 1)
        if ($first.Count -gt 0) {
            $lines.Add("Consider now:")
            $lines.Add($first[0].Trim())
        }
    }

    return $lines.ToArray()
}

function Test-RunnerDiscordPayloadSafe {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $true
    }

    $patterns = @(
        "discord(app)?\.com/api/webhooks/[0-9]+/[A-Za-z0-9._-]+",
        "https?://[^\s]+/(webhook|hooks|token|secret|callback)/[^\s]{16,}",
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{20,}",
        "\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b",
        "\bAKIA[0-9A-Z]{16}\b",
        "\bASIA[0-9A-Z]{16}\b",
        "\bxox[baprs]-[A-Za-z0-9-]{20,}\b",
        "(?i)(DefaultEndpointsProtocol|AccountKey|SharedAccessKey|SharedAccessSignature)\s*=",
        "(?i)(api[_-]?key|secret|token|password)\s*[:=]\s*['""]?[A-Za-z0-9_./+=-]{16,}",
        "gh[pousr]_[A-Za-z0-9_]{20,}",
        "sk-[A-Za-z0-9]{20,}",
        "\b[A-Za-z0-9_+/=-]{48,}\b"
    )

    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) {
            return $false
        }
    }

    return $true
}

function Get-RunnerDiscordColor {
    param([string]$Status)

    switch -Regex ($Status) {
        "^(completed|dry-run|skipped)$" { return 5763719 }
        "^failed$" { return 15548997 }
        default { return 16776960 }
    }
}

function Format-RunnerDuration {
    param([timespan]$Duration)

    if ($Duration.TotalMinutes -ge 1) {
        return "{0:n1} min" -f $Duration.TotalMinutes
    }

    return "{0:n0} sec" -f $Duration.TotalSeconds
}

function Limit-RunnerDiscordText {
    param(
        [string]$Value,
        [int]$MaxLength
    )

    if ([string]::IsNullOrEmpty($Value) -or $Value.Length -le $MaxLength) {
        return $Value
    }

    return $Value.Substring(0, $MaxLength - 15) + "`n...[truncated]"
}

Export-ModuleMember -Function Invoke-RunnerCompletionNotification, Invoke-RunnerNotifySelfTest
