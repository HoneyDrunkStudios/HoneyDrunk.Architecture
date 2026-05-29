@{
    JobId = "lore-source"
    Description = "Run the HoneyDrunk.Lore sourcing pass and save qualifying public written sources to raw/."
    Enabled = $true
    TriggerKind = "schedule"
    Schedule = @{
        Type = "daily"
        TimeLocal = "09:00"
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
            Name = "claude"
            Executable = "claude"
            Arguments = @("--file", "{PromptPath}")
        }
    )
    WriteMode = "commit"
    OutputContract = @{
        LatestOutput = "output/openclaw-sourcing-last-run.md"
        Summary = "Writes qualifying sources to raw/ and records the sourcing run summary."
    }
    RequiredSecrets = @()
    AllowedTools = @("read", "write", "edit", "web", "git")
    RetainArtifactsDays = 30
    PortabilityNotes = "Uses existing Lore sourcing prompt. Browser/audio/video sourcing remains disabled unless the prompt explicitly requires it."
}
