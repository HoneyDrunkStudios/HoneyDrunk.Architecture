@{
    JobId = "hive-sync"
    Description = "Reconcile HoneyDrunk.Architecture against The Hive and open or update a reconciliation PR."
    Enabled = $true
    TriggerKind = "schedule"
    Schedule = @{
        Type = "weekly"
        DaysOfWeek = @("Monday", "Wednesday", "Friday")
        TimeLocal = "09:00"
        AtStartup = $false
        AtLogon = $false
    }
    ConcurrencyKey = "hive-sync"
    TimeoutMinutes = 45
    MaxMissedRuns = 2
    Repo = "HoneyDrunk.Architecture"
    WorkingDirectory = "."
    PromptPath = ".claude/agents/hive-sync.md"
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
        LatestOutput = "initiatives/drift-report.md"
        Summary = "Creates or updates a reconciliation PR; no direct Hive board mutation."
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
    AllowedTools = @("read", "write", "edit", "git", "gh", "graphql", "codex")
    RetainArtifactsDays = 30
    PortabilityNotes = "Host must have Architecture checkout and GitHub CLI for interactive operator use; runner job must not mutate The Hive board directly."
}
