@{
    JobId = "grid-review"
    Description = "Poll GitHub for PRs carrying needs-agent-review and run the Grid-aware review agent."
    Enabled = $true
    TriggerKind = "label-queue"
    Schedule = @{
        Type = "interval"
        IntervalSeconds = 60
        AtStartup = $true
        AtLogon = $true
    }
    ConcurrencyKey = "grid-review"
    TimeoutMinutes = 30
    MaxMissedRuns = 5
    Repo = "HoneyDrunk.Architecture"
    WorkingDirectory = "."
    PromptPath = ".claude/agents/review.md"
    MinimumReviewOutputs = 2
    AgentCommands = @(
        @{
            Name = "codex"
            Executable = "codex"
            Arguments = @("exec", "--sandbox", "read-only", "--ignore-rules", "--ephemeral", "-")
            PromptStdin = $true
        },
        @{
            Name = "claude"
            Executable = "claude"
            Arguments = @("--print", "--permission-mode", "plan", "--no-session-persistence")
            PromptStdin = $true
            Optional = $true
            FallbackCommand = @{
                Name = "codex-contrarian"
                Executable = "codex"
                Arguments = @("exec", "--sandbox", "read-only", "--ignore-rules", "--ephemeral", "-")
                PromptStdin = $true
            }
        }
    )
    SynthesisCommand = @{
        Name = "codex-synthesis"
        Executable = "codex"
        Arguments = @("exec", "--sandbox", "read-only", "--ignore-rules", "--ephemeral", "-")
        PromptStdin = $true
    }
    WriteMode = "comment-only"
    OutputContract = @{
        LatestOutput = "github-pr-comment"
        Summary = "Posts one synthesized advisory review verdict to the PR."
    }
    Notifications = @{
        Discord = @{
            Enabled = $true
            Channel = "agent-activity"
            SecretName = "Discord--AgentActivity--RunnerWebhookUrl"
        }
    }
    RequiredSecrets = @(
        "GitHub--AgentRunner--AppId",
        "GitHub--AgentRunner--PrivateKey",
        "GitHub--AgentRunner--InstallationId",
        "Discord--AgentActivity--RunnerWebhookUrl"
    )
    AllowedTools = @("read", "github-api", "codex", "claude")
    RetainArtifactsDays = 14
    PortabilityNotes = "Requires host config for Architecture checkout, Vault access, Codex CLI, and optional Claude Code CLI."
    Queue = @{
        SearchQuery = "is:pr is:open label:needs-agent-review org:HoneyDrunkStudios"
        StaleClaimMinutes = 15
        QueueCommentMarker = "honeydrunk-grid-review-queue:v1"
        PendingLabel = "needs-agent-review"
        InProgressLabel = "agent-review-in-progress"
        SuccessLabel = "agent-reviewed"
        FailureLabel = "changes-requested-by-agent"
        RemoveOnCompletionLabels = @("needs-agent-review")
    }
}
