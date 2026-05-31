@{
    JobId = "lore-signal-review"
    Description = "Review Lore outputs and Architecture focus for sparse signals without mutating strategy artifacts."
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
        Summary = "Writes a sparse signal-review report only; no strategy or GitHub mutations."
    }
    Notifications = @{
        Discord = @{
            Enabled = $true
            Channel = "agent-activity"
            SecretName = "Discord--AgentActivity--RunnerWebhookUrl"
        }
    }
    RequiredSecrets = @(
        "Discord--AgentActivity--RunnerWebhookUrl"
    )
    AllowedTools = @("read", "write", "codex")
    RetainArtifactsDays = 60
    PortabilityNotes = "Can run manually or on schedule. It is intentionally report-only."
}
