@{
    JobId = "backlog-strategic-scope"
    Description = "Generate ADR-0043 Strategic proposed backlog packets for Accepted ADR/PDR decisions."
    Enabled = $true
    TriggerKind = "schedule"
    Schedule = @{
        Type = "weekly"
        DaysOfWeek = @("Monday", "Wednesday", "Friday")
        TimeLocal = "09:45"
        AtStartup = $false
        AtLogon = $false
    }
    ConcurrencyKey = "backlog-generation"
    TimeoutMinutes = 60
    MaxMissedRuns = 2
    Repo = "HoneyDrunk.Architecture"
    WorkingDirectory = "."
    PromptPath = "infrastructure/workers/grid-agent-runner/prompts/backlog-strategic-scope.md"
    AgentCommands = @(
        @{
            Name = "codex"
            Executable = "codex"
            Arguments = @("exec", "--sandbox", "danger-full-access", "--ignore-rules", "--ephemeral", "-")
            PromptStdin = $true
        }
    )
    WriteMode = "pr"
    OutputContract = @{
        LatestOutput = "generated/briefings/{YYYY-MM-DD}-strategic-source.md"
        Summary = "Creates Strategic source reports and proposed issue packets for unimplemented Accepted decisions."
    }
    Notifications = @{
        Discord = @{
            Enabled = $true
            Channel = "hive-activity"
            SecretName = "Discord--HiveActivity--RunnerWebhookUrl"
        }
    }
    RequiredSecrets = @(
        "Discord--HiveActivity--RunnerWebhookUrl"
    )
    AllowedTools = @("read", "grep", "glob", "edit", "write", "git", "gh", "codex")
    RetainArtifactsDays = 30
    PortabilityNotes = "Host must have the Architecture checkout and GitHub CLI. Job opens or updates a reviewable PR and never promotes proposed packets to active."
}
