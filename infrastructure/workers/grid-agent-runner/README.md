# Grid Agent Runner

Portable scheduled agent runner for ADR-0086. The runner is operator-machine automation: PowerShell scripts, declarative job specs, host-local config, and Windows Task Scheduler as the v1 scheduler adapter.

## Jobs

- `grid-review` polls the GitHub label/comment queue for `needs-agent-review` PRs.
- `post-merge-audit` wires the future ADR-0044 audit job.
- `hive-sync` runs the Architecture reconciliation agent.
- `lore-source` runs the Lore sourcing prompt.
- `lore-ingest` runs the Lore ingest/compile prompt.
- `lore-signal-review` runs the sparse Lore signal review prompt.

Committed job specs live in `config/jobs/*.psd1`. Machine-specific paths and Vault settings live in `config/host.psd1`, which is intentionally not committed.

## Setup

1. Copy `config/host.psd1.example` to `config/host.psd1`.
2. Set `RuntimeRoot` and repository paths for `HoneyDrunk.Architecture` and `HoneyDrunk.Lore`.
3. Confirm Codex CLI and Claude Code CLI are installed and authenticated through subscription sessions.
4. Confirm `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` are not set persistently on the runner host.
5. Confirm the host can read the `review-agent-github-app-*` Vault secrets before running `grid-review` without `-DryRun`.

## Smoke Tests

Dry-run a job without touching GitHub or invoking agents:

```powershell
pwsh ./scripts/Test-JobLocally.ps1 -JobId grid-review
pwsh ./scripts/Test-JobLocally.ps1 -JobId hive-sync
```

Run against a real host config:

```powershell
pwsh ./scripts/Test-JobLocally.ps1 -JobId grid-review -ConfigPath ./config/host.psd1
```

Invoke agents intentionally:

```powershell
pwsh ./scripts/Test-JobLocally.ps1 -JobId hive-sync -ConfigPath ./config/host.psd1 -InvokeAgents
```

## Task Scheduler

Preview registration:

```powershell
pwsh ./scripts/Register-Task.ps1 -ConfigPath ./config/host.psd1 -WhatIf
```

Register default jobs:

```powershell
pwsh ./scripts/Register-Task.ps1 -ConfigPath ./config/host.psd1
```

Rollback:

```powershell
pwsh ./scripts/Unregister-Task.ps1
```

## State And Logs

The runner writes JSON logs under `LogRoot` and per-job heartbeat state under `StateRoot`. Review queue state remains durable in GitHub labels/comments; scheduled jobs resume from repo state and their latest output artifacts.

## Historical Predecessors

- `infrastructure/openclaw/grid-review-runner.md` records the superseded OpenClaw review runner contract.
- `infrastructure/openclaw/hive-sync.md` records the predecessor hive-sync runtime contract.
