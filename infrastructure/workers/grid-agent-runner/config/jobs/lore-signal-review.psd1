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
            Name = "claude"
            Executable = "claude"
            Arguments = @("--file", "{PromptPath}")
        }
    )
    WriteMode = "none"
    OutputContract = @{
        LatestOutput = "output/signal-review-YYYY-MM-DD.md"
        Summary = "Writes a sparse signal-review report only; no strategy or GitHub mutations."
    }
    RequiredSecrets = @()
    AllowedTools = @("read", "write")
    RetainArtifactsDays = 60
    PortabilityNotes = "Can run manually or on schedule. It is intentionally report-only."
}
