@{
    JobId = "post-merge-audit"
    Description = "Run the review agent in audit mode for merged PRs selected by the audit-sample label."
    Enabled = $true
    TriggerKind = "label-queue"
    Schedule = @{
        Type = "interval"
        IntervalSeconds = 300
        AtStartup = $true
        AtLogon = $true
    }
    ConcurrencyKey = "post-merge-audit"
    TimeoutMinutes = 30
    MaxMissedRuns = 5
    Repo = "HoneyDrunk.Architecture"
    WorkingDirectory = "."
    PromptPath = ".claude/agents/review.md"
    AgentCommands = @(
        @{
            Name = "codex"
            Executable = "codex"
            Arguments = @("exec", "--file", "{PromptPath}")
        }
    )
    WriteMode = "pr"
    OutputContract = @{
        LatestOutput = "generated/post-merge-audits/"
        Summary = "Posts an audit comment and writes an audit artifact when ADR-0044 audit packets land."
    }
    RequiredSecrets = @(
        "review-agent-github-app-id",
        "review-agent-github-app-private-key",
        "review-agent-github-app-installation-id"
    )
    AllowedTools = @("read", "git", "github-api", "codex")
    RetainArtifactsDays = 30
    PortabilityNotes = "Uses the same review agent prompt in audit mode; artifact directory is governed by ADR-0044 packets 15/16."
    Queue = @{
        SearchQuery = "is:pr is:merged label:audit-sample org:HoneyDrunkStudios"
        StaleClaimMinutes = 30
        QueueCommentMarker = "honeydrunk-grid-audit-queue:v1"
    }
}
