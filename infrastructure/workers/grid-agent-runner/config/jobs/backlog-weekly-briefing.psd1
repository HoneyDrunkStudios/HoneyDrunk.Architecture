@{
    JobId = "backlog-weekly-briefing"
    Description = "Generate the ADR-0043 weekly backlog briefing and optional netrunner focus refresh."
    Enabled = $true
    TriggerKind = "schedule"
    Schedule = @{
        Type = "weekly"
        DaysOfWeek = @("Monday")
        TimeLocal = "10:30"
        AtStartup = $false
        AtLogon = $false
    }
    ConcurrencyKey = "backlog-generation"
    TimeoutMinutes = 60
    MaxMissedRuns = 1
    Repo = "HoneyDrunk.Architecture"
    WorkingDirectory = "."
    PromptPath = "infrastructure/workers/grid-agent-runner/prompts/backlog-weekly-briefing.md"
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
        LatestOutput = "generated/briefings/{YYYY-MM-DD}.md"
        Summary = "Writes the weekly ADR-0043 backlog briefing for human triage."
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
    PortabilityNotes = "Runs after Monday hive-sync and strategic source jobs. It never moves packets between proposed, active, and completed."
}
