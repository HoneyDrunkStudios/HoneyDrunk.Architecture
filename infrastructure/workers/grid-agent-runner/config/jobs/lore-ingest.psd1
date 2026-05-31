@{
    JobId = "lore-ingest"
    Description = "Compile HoneyDrunk.Lore raw sources into wiki pages and indexes."
    Enabled = $true
    TriggerKind = "schedule"
    Schedule = @{
        Type = "daily"
        TimeLocal = "10:00"
        AtStartup = $false
        AtLogon = $false
    }
    ConcurrencyKey = "lore-ingest"
    TimeoutMinutes = 60
    MaxMissedRuns = 2
    Repo = "HoneyDrunk.Lore"
    WorkingDirectory = "."
    PromptPath = "tools/openclaw-lore-ingest-prompt.md"
    AgentCommands = @(
        @{
            Name = "codex"
            Executable = "codex"
            Arguments = @("exec", "--sandbox", "danger-full-access", "--ignore-rules", "--ephemeral", "-")
            PromptStdin = $true
        }
    )
    WriteMode = "commit"
    OutputContract = @{
        LatestOutput = "output/openclaw-ingest-last-run.md"
        Summary = "Compiles raw/ into wiki/, updates indexes, and records the ingest run summary."
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
    AllowedTools = @("read", "write", "edit", "git", "codex")
    RetainArtifactsDays = 30
    PortabilityNotes = "Uses existing Lore ingest prompt; redaction and flat-file wiki rules stay in HoneyDrunk.Lore."
}
