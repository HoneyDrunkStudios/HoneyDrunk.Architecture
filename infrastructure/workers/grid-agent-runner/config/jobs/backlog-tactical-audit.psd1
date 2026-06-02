@{
    JobId = "backlog-tactical-audit"
    Description = "Run ADR-0043 Tactical Node audit rotation and create proposed packets for actionable findings."
    Enabled = $true
    TriggerKind = "schedule"
    Schedule = @{
        Type = "weekly"
        DaysOfWeek = @("Tuesday")
        TimeLocal = "09:00"
        AtStartup = $false
        AtLogon = $false
    }
    ConcurrencyKey = "backlog-generation"
    TimeoutMinutes = 90
    MaxMissedRuns = 1
    Repo = "HoneyDrunk.Architecture"
    WorkingDirectory = "."
    PromptPath = "infrastructure/workers/grid-agent-runner/prompts/backlog-tactical-audit.md"
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
        LatestOutput = "generated/audits/"
        Summary = "Writes the weekly Node audit report and proposed tactical packets when findings warrant action."
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
    AllowedTools = @("read", "grep", "glob", "edit", "write", "git", "gh", "codex")
    RetainArtifactsDays = 60
    PortabilityNotes = "Host should have neighboring Grid repo checkouts available for the selected Node. Missing repos produce skipped audit reports rather than guessed findings."
}
