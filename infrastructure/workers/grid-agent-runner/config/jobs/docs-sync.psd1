@{
    JobId = "docs-sync"
    Description = "Sweep Grid repositories for code-to-docs drift and open conservative documentation reconciliation PRs."
    Enabled = $true
    TriggerKind = "schedule"
    Schedule = @{
        Type = "weekly"
        DaysOfWeek = @("Friday")
        TimeLocal = "10:30"
        AtStartup = $false
        AtLogon = $false
    }
    ConcurrencyKey = "docs-sync"
    TimeoutMinutes = 60
    MaxMissedRuns = 2
    Repo = "HoneyDrunk.Architecture"
    WorkingDirectory = "."
    PromptPath = ".claude/agents/docs-sync.md"
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
        LatestOutput = "generated/docs-sync-reports/{YYYY-MM-DD}.md"
        Summary = "Writes a docs-sync report and opens or updates docs-only reconciliation PRs for clear mechanical drift."
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
    AllowedTools = @("read", "write", "edit", "git", "gh", "codex")
    RetainArtifactsDays = 30
    PortabilityNotes = "Host must have Architecture and target repo checkouts plus GitHub CLI. The agent scans all available Grid repos, skips seed/scaffold repos without actionable docs drift, and posts run completion/report summaries through the runner's hive-activity Discord webhook."
}
