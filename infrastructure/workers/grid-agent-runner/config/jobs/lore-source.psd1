@{
    JobId = "lore-source"
    Description = "Run the HoneyDrunk.Lore sourcing pass and save qualifying public written sources to raw/."
    Enabled = $true
    TriggerKind = "schedule"
    Schedule = @{
        Type = "daily"
        TimeLocal = "08:00"
        AtStartup = $false
        AtLogon = $false
    }
    ConcurrencyKey = "lore-source"
    TimeoutMinutes = 60
    MaxMissedRuns = 2
    Repo = "HoneyDrunk.Lore"
    WorkingDirectory = "."
    PromptPath = "tools/openclaw-lore-sourcing-prompt.md"
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
        LatestOutput = "output/openclaw-sourcing-last-run.md"
        Summary = "Writes qualifying sources to raw/ and records the sourcing run summary."
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
    AllowedTools = @("read", "write", "edit", "web", "git", "codex")
    RetainArtifactsDays = 30
    PortabilityNotes = "Uses existing Lore sourcing prompt. Browser/audio/video sourcing remains disabled unless the prompt explicitly requires it."
}
