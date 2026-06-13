@{
    JobId = "lore-signal-review"
    Description = "Review Lore outputs against HoneyDrunk focus and surface sparse usefulness signals without mutating strategy artifacts."
    Enabled = $true
    TriggerKind = "schedule"
    Schedule = @{
        Type = "weekly"
        DaysOfWeek = @("Friday")
        TimeLocal = "11:00"
        AtStartup = $false
        AtLogon = $false
    }
    ConcurrencyKey = "lore-signal-review"
    TimeoutMinutes = 45
    MaxMissedRuns = 2
    Repo = "HoneyDrunk.Lore"
    WorkingDirectory = "."
    PromptPath = "tools/openclaw-lore-signal-review-prompt.md"
    AgentCommands = @(
        @{
            Name = "codex"
            Executable = "codex"
            Arguments = @("exec", "--sandbox", "danger-full-access", "--ignore-rules", "--ephemeral", "-")
            PromptStdin = $true
        }
    )
    WriteMode = "none"
    OutputContract = @{
        LatestOutput = "output/signal-review-YYYY-MM-DD.md"
        Summary = "Writes a sparse HoneyDrunk-usefulness report only; no strategy or GitHub mutations."
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
    AllowedTools = @("read", "write", "codex")
    RetainArtifactsDays = 60
    PortabilityNotes = "Runs weekly after the Friday Lore ingest window, can also run manually, and is intentionally report-only."
}
