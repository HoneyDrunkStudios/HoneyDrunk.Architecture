---
title: Grid Agent Runner
description: Portable ADR-0086 scheduled local-worker framework for review, audit, hive, and lore jobs.
applies_to:
  - ADR-0086
  - ADR-0044
  - ADR-0043
scope: Operator-internal automation infrastructure
type: documentation/runbook
slug: grid-agent-runner
---

# Grid Agent Runner

Portable scheduled agent runner for ADR-0086. The runner is operator-machine automation: PowerShell scripts, declarative job specs, host-local config, and Windows Task Scheduler as the v1 scheduler adapter.

## Jobs

- `grid-review` polls the GitHub label/comment queue for `needs-agent-review` PRs, runs Codex and Claude for every queued PR, and posts one synthesized Grid Review verdict in the established sectioned emoji format.
- `post-merge-audit` wires the future ADR-0044 audit job.
- `hive-sync` runs the Architecture reconciliation agent.
- `docs-sync` runs the grid-wide code-to-docs currency sweep, writes a per-run report, posts a Discord summary, and opens conservative docs-only reconciliation PRs.
- `backlog-strategic-scope` runs the ADR-0043 Strategic source after hive-sync and writes proposed packets for unimplemented Accepted decisions.
- `backlog-tactical-audit` runs the ADR-0043 Tactical Node audit rotation and writes audit reports plus proposed packets for actionable findings.
- `backlog-opportunistic-scout` runs the ADR-0043 Opportunistic Scout source through a weekly schedule with a monthly guard.
- `backlog-weekly-briefing` writes the weekly ADR-0043 human triage briefing and optional netrunner-owned focus refresh.
- `lore-source` runs the Lore sourcing prompt.
- `lore-ingest` runs the Lore ingest/compile prompt.
- `lore-signal-review` runs the sparse Lore signal review prompt.

Committed job specs live in `config/jobs/*.psd1`. Machine-specific paths and Vault settings live in `config/host.psd1`, which is intentionally not committed.

## Loop Jobs (ADR-0093 convention)

Some runner jobs are **loops** in the ADR-0093 sense — they close: they evaluate their
output against a gate and write the result back so the next iteration improves. A runner
job that has a trigger and a synthesizer but **no gate and no feedback sink is a cron
job, not a loop**, and is not registered as a Loop Definition Record (LDR).

For a job that *is* a loop, the convention is:

- **A loop is linked to its runner job by the LDR's `runner_job` field — not by the slug
  string.** The LDR lives at `loops/{loop-id}.md` and records the job-spec path in
  `runner_job`; the job spec is its execution half. The mapping is **usually** 1:1 (JobId
  `hive-sync` ↔ `loop-0001-hive-sync`), and the slug normally echoes the job, but neither
  is a hard rule:
  - **Many-to-one is allowed.** Several LDRs may ride one job — `loop-0005-backlog-reactive`
    rides the `hive-sync` run (reactive conversion is a sink of that pass), so both
    `loop-0001` and `loop-0005` point `runner_job` at `hive-sync.psd1`.
  - **Slugs may abbreviate the JobId.** `loop-0002-backlog-strategic` ↔ JobId
    `backlog-strategic-scope`; the slug names the loop's purpose, the `runner_job` field is
    the authoritative link.
  - **A loop need not have a scheduled job at all.** `loop-0006-pr-activity-autofix` is
    driven by the PR-activity subscription (`runner_job: n/a`), not an ADR-0086 cron job.

  See `constitution/naming-conventions.md` for the id format.
- **`WriteMode = "pr"`** is the floor — artifacts are the write boundary; no loop mutates
  authoritative state outside a reviewable branch/PR.
- **The gate and feedback sink are named in the LDR**, not invented in the job spec. The
  job spec's `OutputContract` should point at the same feedback sink the LDR declares.
- **The kill switch is `Enabled = $false`** on the spec (or unregistering the task), and
  is the control the LDR's `kill_switch` field names.
- **Budget maps to `TimeoutMinutes`** (the per-run cap) and the ADR-0052 cost caps the
  LDR declares.

Loop runner jobs in `config/jobs/` today: `hive-sync` (loop-0001), `backlog-strategic-scope`
(loop-0002), `backlog-tactical-audit` (loop-0003), `backlog-opportunistic-scout` (loop-0004),
and the reactive drift-conversion that rides `hive-sync` (loop-0005). The PR-activity autofix
loop (loop-0006) is **not** a runner job — it is driven by the PR-activity subscription, not a
schedule. Pure cron-style jobs (no gate/feedback sink) are not loops and carry no LDR.

## Safety Model

The runner is clone-safe by default. A fresh checkout has no `config/host.psd1`, and the example config keeps `Safety.Enabled = $false`; non-dry-run jobs refuse to start until the operator explicitly enables the local safety gate.

For PR review, treat every PR field as hostile input. The runner does not check out PR heads or run PR code. It reviews GitHub diff/context only, rejects repositories outside `Safety.AllowedReviewRepositories`, rejects fork PRs unless `Safety.AllowForkPullRequests` is explicitly enabled, rejects private head repositories unless `Safety.AllowPrivateHeadRepositories` is explicitly enabled, requires the queue comment marker for claim recovery, launches child agents with common cloud/source-control/API-token environment variables removed, runs Codex review passes with an ephemeral read-only sandbox that ignores repo-local rules, and runs eligible Claude passes in non-interactive plan mode.

For PR review, raw Codex and Claude outputs are retained as runner artifacts. The PR receives one comment with an `Independent Review Findings` section for the per-agent summaries followed by the synthesized canonical Grid Review verdict owned by `.claude/agents/review.md` (`Risk Level`, `Review Confidence`, `✅ Verdict`, and the full emoji section checklist). The runner normalizes transport-only agent wrappers before posting. Every queued PR now receives the dual-review path. Trusted base-branch `catalogs/grid-health.json` metadata remains useful context, but it no longer gates whether Claude runs. If Claude cannot launch, the runner uses a Codex contrarian fallback pass before synthesis. If the review still produces fewer than two independent review outputs, the runner posts a Grid Review `Block` guardrail verdict instead of allowing the item to pass.

The scheduled runner code must also be isolated from repository updates. With `Safety.RequireNonRepositoryRunnerRoot = $true`, non-dry-run jobs and Task Scheduler registration refuse to run from a Git worktree or from a configured repository path. Install or copy the runner into the operator-controlled `Safety.TrustedRunnerRoot`, keep `host.psd1` outside cloned source, then register scheduled tasks from that installed copy. If a malicious Architecture PR ever lands, the scheduled task continues running the previously installed runner copy until an operator intentionally updates it.

## Setup

1. Copy `config/host.psd1.example` to an operator-local config path outside cloned source and outside the installed runner code, for example `C:\HoneyDrunk\Runtime\grid-agent-runner\host.psd1`.
2. Set `RuntimeRoot` and repository paths for `HoneyDrunk.Architecture` and `HoneyDrunk.Lore`.
3. Confirm Codex CLI is installed and authenticated. The runner resolves `codex` from PATH or the Codex desktop `%LOCALAPPDATA%\OpenAI\Codex\bin\*\codex.exe` install path for hidden Task Scheduler runs. Install and authenticate Claude Code on hosts that handle Grid Review PRs.
4. Confirm `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` are not set persistently on the runner host.
5. Confirm the host can read the shared automation Vault, `kv-hd-automation-dev`, and its `GitHub--AgentRunner--*` secrets before running `grid-review` without `-DryRun`.
6. Copy the runner directory into `Safety.TrustedRunnerRoot`, keep host config outside cloned source, and register scheduled tasks from that installed copy.
7. Set `Safety.Enabled = $true` and `Safety.OperatorAcknowledgedUntrustedInputs = $true` only on the operator-controlled runner host after verifying the repository allowlist, fork policy, private-head policy, queue marker requirement, and trusted runner root.

## Smoke Tests

Dry-run a job without touching GitHub or invoking agents:

```powershell
pwsh ./scripts/Test-JobLocally.ps1 -JobId grid-review
pwsh ./scripts/Test-JobLocally.ps1 -JobId hive-sync
pwsh ./scripts/Test-JobLocally.ps1 -JobId docs-sync
pwsh ./scripts/Test-JobLocally.ps1 -JobId backlog-strategic-scope
pwsh ./scripts/Test-JobLocally.ps1 -JobId backlog-tactical-audit
pwsh ./scripts/Test-JobLocally.ps1 -JobId backlog-opportunistic-scout
pwsh ./scripts/Test-JobLocally.ps1 -JobId backlog-weekly-briefing
```

Run against a real host config:

```powershell
pwsh ./scripts/Test-JobLocally.ps1 -JobId grid-review -ConfigPath C:\HoneyDrunk\Runtime\grid-agent-runner\host.psd1
```

Invoke agents intentionally:

```powershell
pwsh ./scripts/Test-JobLocally.ps1 -JobId hive-sync -ConfigPath C:\HoneyDrunk\Runtime\grid-agent-runner\host.psd1 -InvokeAgents
```

## Task Scheduler

Preview registration:

```powershell
pwsh ./scripts/Register-Task.ps1 -ConfigPath C:\HoneyDrunk\Runtime\grid-agent-runner\host.psd1 -WhatIf
```

Register default jobs. Windows registrations use a hidden launcher by default so recurring jobs do not open terminal windows in the interactive session. Each task's execution limit budgets the primary agent commands, any configured fallback commands, and the synthesis command so a slow secondary review cannot be killed by a limit sized only for the first pass:

```powershell
pwsh ./scripts/Register-Task.ps1 -ConfigPath C:\HoneyDrunk\Runtime\grid-agent-runner\host.psd1
```

Use `-VisibleWindow` only when debugging a task interactively.

Rollback:

```powershell
pwsh ./scripts/Unregister-Task.ps1
```

## State And Logs

The runner writes JSON logs under `LogRoot` and per-job heartbeat state under `StateRoot`. Review queue state remains durable in GitHub labels/comments; scheduled jobs resume from repo state and their latest output artifacts.

## Historical Predecessors

- The OpenClaw review-runner and hive-sync runtime contracts were removed when OpenClaw was decommissioned per ADR-0088; this runner and its job specs are their successors.
