@{
    JobId = "backlog-opportunistic-scout"
    Description = "Run ADR-0043 Opportunistic Scout mode monthly through a weekly guarded schedule."
    Enabled = $true
    TriggerKind = "schedule"
    Schedule = @{
        Type = "weekly"
        DaysOfWeek = @("Thursday")
        TimeLocal = "10:00"
        AtStartup = $false
        AtLogon = $false
    }
    ConcurrencyKey = "backlog-generation"
    TimeoutMinutes = 75
    MaxMissedRuns = 1
    Repo = "HoneyDrunk.Architecture"
    WorkingDirectory = "."
    PromptPath = "infrastructure/workers/grid-agent-runner/prompts/backlog-opportunistic-scout.md"
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
        LatestOutput = "generated/scout-reports/{YYYY-MM-DD}.md"
        Summary = "Writes a monthly Scout report and proposed opportunistic packets only when opportunities clear the bar."
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
    AllowedTools = @("read", "grep", "glob", "websearch", "edit", "write", "git", "gh", "codex")
    RetainArtifactsDays = 60
    PortabilityNotes = "The prompt enforces one Scout report per calendar month. Host needs network access for current market signal; if search is unavailable, the report must disclose that limitation."
}
