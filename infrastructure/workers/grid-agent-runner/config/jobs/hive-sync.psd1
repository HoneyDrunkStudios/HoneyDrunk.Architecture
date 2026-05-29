@{
    JobId = "hive-sync"
    Description = "Reconcile HoneyDrunk.Architecture against The Hive and open or update a reconciliation PR."
    Enabled = $true
    TriggerKind = "schedule"
    Schedule = @{
        Type = "weekly"
        DaysOfWeek = @("Monday", "Thursday")
        TimeUtc = "06:00"
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
            Name = "claude"
            Executable = "claude"
            Arguments = @("--file", "{PromptPath}")
        }
    )
    WriteMode = "pr"
    OutputContract = @{
        LatestOutput = "initiatives/drift-report.md"
        Summary = "Creates or updates a reconciliation PR; no direct Hive board mutation."
    }
    RequiredSecrets = @()
    AllowedTools = @("read", "write", "edit", "git", "gh", "graphql")
    RetainArtifactsDays = 30
    PortabilityNotes = "Host must have Architecture checkout and GitHub CLI for interactive operator use; runner job must not mutate The Hive board directly."
}
