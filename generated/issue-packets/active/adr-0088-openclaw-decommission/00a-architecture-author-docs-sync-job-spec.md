---
name: Infrastructure
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "ops", "infrastructure", "adr-0088", "wave-0"]
dependencies: []
adrs: ["ADR-0088", "ADR-0086", "ADR-0085"]
accepts: []
wave: 0
initiative: adr-0088-openclaw-decommission
node: honeydrunk-architecture
---

# Author + smoke-test a `docs-sync` runner job spec so docs-sync keeps automated Friday scheduling post-OpenClaw

## Summary
Author a `docs-sync` job spec at `infrastructure/workers/grid-agent-runner/config/jobs/docs-sync.psd1`, matching the shape of the six existing job specs in that directory (`grid-review`, `hive-sync`, `lore-ingest`, `lore-signal-review`, `lore-source`, `post-merge-audit`). The spec validates against the runner's job-spec schema (`Assert-GridAgentJobSpec` in `lib/JobSpec.psm1`) and carries a dry-run/smoke record from `scripts/Test-JobLocally.ps1 -JobId docs-sync`, so docs-sync's ADR-0085 **weekly Friday cadence runs on the ADR-0086 local worker** rather than dropping to its ADR-0085 manual-dispatch floor.

This is the **committed prerequisite** the operator chose (option (a) — author the spec) over option (b) — accept the manual floor. With this packet done, docs-sync has a scheduler on the surviving runtime before its OpenClaw schedule is stopped. It gates the teardown: it is the earliest packet (Wave 0), it is a hard precondition of packet 00's Part-B Group-1 gate, and packet 02 (which stops the OpenClaw docs-sync schedule) is blocked-by this packet so docs-sync is never stranded with no scheduler.

## Context
ADR-0086 built a portable pull-based local worker (`infrastructure/workers/grid-agent-runner/`) with declarative `.psd1` job specs. As of 2026-05-30 the `config/jobs/` directory holds six specs — `grid-review`, `hive-sync`, `lore-ingest`, `lore-signal-review`, `lore-source`, `post-merge-audit` — but **no `docs-sync` spec**. ADR-0085 (Grid-Wide Documentation Currency Agent) bound docs-sync's execution surface to "OpenClaw scheduled trigger (consistent with `hive-sync`), with manual dispatch supported," and its D6 set the v1 cadence at **weekly, Friday** (deliberately avoiding the Monday/Thursday `hive-sync` slot, landing fixes before the weekend, surfacing the report for `netrunner`'s Monday briefing).

The ADR-0088 OpenClaw decommission removes the OpenClaw scheduled trigger. Without a `docs-sync` runner job spec, stopping OpenClaw's docs-sync schedule would drop docs-sync to its manual-dispatch floor. The operator resolved this open question in favor of **keeping docs-sync automated**: author the `docs-sync` job spec now, on the ADR-0086 worker, before the OpenClaw schedule is torn down. This packet does that. It converts what was an open Part-B precondition (and a packet-05 manual-floor caveat) into a committed, completed prerequisite.

This is operator-machine infrastructure work that an agent can author end-to-end: the `.psd1` spec is a declarative hashtable, validated by a deterministic schema, smoke-tested by an existing dry-run harness. `Actor=Agent`. (The operator's only residual step is registering the new scheduled task on the runner host — captured under Human Prerequisites — but the spec authoring + validation + dry-run smoke is the agent's critical path.)

## The job-spec schema (inlined — the agent has no Architecture-repo context at execution time)
`lib/JobSpec.psm1`'s `Assert-GridAgentJobSpec` requires **every** spec to be a PowerShell data hashtable (`@{ ... }`) with exactly these keys present:

```
JobId, Description, Enabled, TriggerKind, Schedule, ConcurrencyKey,
TimeoutMinutes, MaxMissedRuns, Repo, WorkingDirectory, PromptPath,
AgentCommands, WriteMode, OutputContract, RequiredSecrets,
AllowedTools, RetainArtifactsDays, PortabilityNotes
```

Hard validation rules the spec must satisfy:
- `TriggerKind` must be one of `"label-queue"`, `"schedule"`, `"manual"`. docs-sync is scheduled → `"schedule"`.
- `WriteMode` must be one of `"comment-only"`, `"commit"`, `"pr"`, `"none"`. docs-sync opens per-repo PRs + a report PR → `"pr"` (matches `hive-sync`).
- `WorkingDirectory` and `PromptPath` must be **relative** paths — no rooted/absolute path, no Windows `X:\` drive path (`Assert-PortableRunnerPath` throws otherwise). Use `WorkingDirectory = "."` and a repo-relative `PromptPath`.

Reference shape (the `hive-sync.psd1` spec, the closest analog — same repo, same `WriteMode = "pr"`, same weekly cadence family):

```powershell
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
    AgentCommands = @( @{ Name = "claude"; Executable = "claude"; Arguments = @("--file", "{PromptPath}") } )
    WriteMode = "pr"
    OutputContract = @{ LatestOutput = "initiatives/drift-report.md"; Summary = "..." }
    RequiredSecrets = @()
    AllowedTools = @("read", "write", "edit", "git", "gh", "graphql")
    RetainArtifactsDays = 30
    PortabilityNotes = "..."
}
```

## The docs-sync spec content (per ADR-0085, inlined)
Author `config/jobs/docs-sync.psd1` with these values (derived from ADR-0085 D1/D4/D6):
- `JobId = "docs-sync"`.
- `Description` — a one-line summary, e.g. "Sweep every in-scope Grid repo for documentation drift and open one reconciliation PR per affected repo plus a per-run report PR in Architecture."
- `Enabled = $true`.
- `TriggerKind = "schedule"`.
- `Schedule` — **weekly, Friday** per ADR-0085 D6. Use `Type = "weekly"`, `DaysOfWeek = @("Friday")`, and a `TimeUtc` (or `TimeLocal`) that does not collide with the Monday/Thursday `hive-sync` slot. Match the time-key convention the other weekly spec uses (`hive-sync` uses `TimeUtc`; the Lore daily specs use `TimeLocal`). Set `AtStartup = $false`, `AtLogon = $false`.
- `ConcurrencyKey = "docs-sync"`.
- `TimeoutMinutes` — generous enough for a full 25-repo Markdown sweep (ADR-0085 D6 says "minutes"); 60 is a safe ceiling consistent with the Lore jobs.
- `MaxMissedRuns = 2` (consistent with the other specs).
- `Repo = "HoneyDrunk.Architecture"` — the agent is hosted in Architecture (ADR-0085 D1: `.claude/agents/docs-sync.md`, same hosting model as `hive-sync`/`site-sync`); cross-repo PRs are opened by the agent's `gh` tool from that working directory.
- `WorkingDirectory = "."`.
- `PromptPath = ".claude/agents/docs-sync.md"` (ADR-0085 D1).
- `AgentCommands` — the `claude --file {PromptPath}` shape used by every existing spec.
- `WriteMode = "pr"` (ADR-0085 D4: one PR per affected repo per run + the report PR; same as `hive-sync`).
- `OutputContract` — `LatestOutput` pointing at the per-run report path family `generated/docs-sync-reports/{YYYY-MM-DD}.md` (ADR-0085 D4), with a `Summary` describing the per-repo-PR + report-PR output.
- `RequiredSecrets = @()` — keep consistent with the other committed specs (host-config Vault settings live in `host.psd1`, not the spec). If the runner needs the ADR-0085 `docs-sync` GitHub App token surfaced as a named secret, mirror whatever `grid-review.psd1` does; do **not** invent a new secret-surfacing convention.
- `AllowedTools` — `@("read", "write", "edit", "git", "gh")` (ADR-0085 D1 tool grant: Read/Grep/Glob/Bash/Edit/Write + `gh pr create`; no `graphql` needed since docs-sync does not mutate The Hive board).
- `RetainArtifactsDays = 30`.
- `PortabilityNotes` — note the host must have an Architecture checkout + GitHub CLI, and that cross-repo PR creation is bounded to the ADR-0085 D4 scope.

> **If the agent finds the docs-sync agent prompt (`.claude/agents/docs-sync.md`) does not yet exist** in the Architecture repo, the spec's `PromptPath` still points at the canonical ADR-0085 D1 location — the spec is correct; the dry-run smoke (which does not invoke the agent) still passes. Note the prompt's absence in the PR body if so; authoring the prompt itself is ADR-0085 D1 work, out of scope here. The spec is the scheduler wiring, which is this packet's deliverable.

## Smoke / validation (the dry-run record)
The runner ships a dry-run harness that exercises the spec without touching GitHub or invoking agents: `scripts/Test-JobLocally.ps1 -JobId docs-sync` runs `Invoke-GridAgentRunner.ps1 -JobId docs-sync -Once -DryRun`. The dry run loads the spec via `Get-GridAgentJobSpec`, validates it via `Assert-GridAgentJobSpec`, and exercises the scheduling/portability assertions — all without network or agent invocation. Capture its output (exit code 0) as the smoke record in the PR body.

This satisfies "validates against the runner's job-spec schema, and has a dry-run/smoke record" without requiring the operator's runner host or a live agent run. A full non-dry-run invocation (`-InvokeAgents` against the operator host config) is the operator's optional follow-up, recorded under Human Prerequisites, not the agent's critical path.

## Scope
- `infrastructure/workers/grid-agent-runner/config/jobs/docs-sync.psd1` — **new file.** The job spec above.
- `infrastructure/workers/grid-agent-runner/README.md` — add a `docs-sync` bullet to the `## Jobs` list (after the `lore-signal-review` line), mirroring the one-line style of the existing entries (e.g. "`docs-sync` runs the grid-wide documentation-currency sweep and opens per-repo reconciliation PRs.").
- `CHANGELOG.md` — record the new `docs-sync` job spec landing on the ADR-0086 runner (docs-sync's Friday cadence now runs on the local worker; ADR-0088 prerequisite).

## Proposed Implementation
1. Author `config/jobs/docs-sync.psd1` per the spec content above, copying the structural shape of `hive-sync.psd1` and substituting the docs-sync values (weekly Friday schedule, `Repo = "HoneyDrunk.Architecture"`, `PromptPath = ".claude/agents/docs-sync.md"`, `WriteMode = "pr"`, report-path `OutputContract`).
2. Run `pwsh ./scripts/Test-JobLocally.ps1 -JobId docs-sync` from the runner root. Confirm exit code 0 (the dry run validates the spec against `Assert-GridAgentJobSpec` and the scheduling/portability assertions). Paste the output into the PR body as the smoke record.
3. Add the `docs-sync` bullet to the runner `README.md` `## Jobs` list.
4. Update `CHANGELOG.md`.

## Affected Files
- `infrastructure/workers/grid-agent-runner/config/jobs/docs-sync.psd1` (new)
- `infrastructure/workers/grid-agent-runner/README.md`
- `CHANGELOG.md`

## NuGet Dependencies
None. A PowerShell `.psd1` data file + a Markdown README/CHANGELOG edit; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture` (the runner lives at `infrastructure/workers/grid-agent-runner/`). Routing rule "architecture, infrastructure, runner, ADR → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency. The runner is operator-machine automation, not a Node.
- [x] `constitution/invariants.md` is NOT edited (ADR-0088 D6 — no new invariants).
- [x] No OpenClaw teardown action here. This packet *adds* the replacement scheduler; it does not remove any OpenClaw runtime, secret, or file (those are packets 01–04).
- [x] The new spec uses only relative `WorkingDirectory`/`PromptPath` values (the schema rejects absolute/Windows paths).

## Acceptance Criteria
- [ ] `infrastructure/workers/grid-agent-runner/config/jobs/docs-sync.psd1` exists and is a valid PowerShell data hashtable carrying all 18 required keys (`JobId`, `Description`, `Enabled`, `TriggerKind`, `Schedule`, `ConcurrencyKey`, `TimeoutMinutes`, `MaxMissedRuns`, `Repo`, `WorkingDirectory`, `PromptPath`, `AgentCommands`, `WriteMode`, `OutputContract`, `RequiredSecrets`, `AllowedTools`, `RetainArtifactsDays`, `PortabilityNotes`)
- [ ] `TriggerKind = "schedule"`; `Schedule` encodes a **weekly Friday** cadence (`DaysOfWeek = @("Friday")`) that does not collide with the Monday/Thursday `hive-sync` slot (ADR-0085 D6)
- [ ] `WriteMode = "pr"`; `Repo = "HoneyDrunk.Architecture"`; `PromptPath = ".claude/agents/docs-sync.md"` (ADR-0085 D1); `WorkingDirectory` and `PromptPath` are relative paths (schema rejects absolute/Windows paths)
- [ ] `OutputContract.LatestOutput` points at the `generated/docs-sync-reports/{YYYY-MM-DD}.md` report family (ADR-0085 D4)
- [ ] `pwsh ./scripts/Test-JobLocally.ps1 -JobId docs-sync` exits 0 (the dry run validates the spec against `Assert-GridAgentJobSpec` and the scheduling/portability assertions); its output is captured in the PR body as the smoke record
- [ ] The runner `README.md` `## Jobs` list includes a `docs-sync` entry
- [ ] `constitution/invariants.md` is unchanged
- [ ] No OpenClaw runtime, secret, file, or schedule is removed in this packet (this packet only *adds* the replacement scheduler)
- [ ] `CHANGELOG.md` records the new `docs-sync` job spec landing on the ADR-0086 runner as the ADR-0088 prerequisite (docs-sync's Friday cadence now runs on the local worker)

## Human Prerequisites
- [ ] **Register the `docs-sync` scheduled task on the runner host (optional, post-merge).** Once the spec merges, the operator runs `pwsh ./scripts/Register-Task.ps1 -ConfigPath <host.psd1>` from the installed runner copy to wire the Friday schedule into Windows Task Scheduler. The agent cannot do this (no runner-host access); it is not on the agent's critical path — the spec + dry-run smoke is the deliverable, the live registration is the operator's deploy-time step.
- [ ] **Optional: a live (non-dry-run) smoke against the host config** — `pwsh ./scripts/Test-JobLocally.ps1 -JobId docs-sync -ConfigPath <host.psd1> -InvokeAgents` — to confirm the agent prompt resolves and the worker can open a PR. Optional; the dry-run record satisfies this packet's acceptance.

## Dependencies
None. This is the earliest packet in the initiative (Wave 0) — it has no upstream blockers and gates the teardown.

## Referenced ADR Decisions
**ADR-0085 D1 — `docs-sync` agent, hosting + tools.** The agent is authored at `HoneyDrunk.Architecture/.claude/agents/docs-sync.md` (same hosting model as `hive-sync`/`site-sync`). Tools: Read/Grep/Glob/Bash/Edit/Write, with `Bash` including `gh pr create` against the target repo. This packet's `PromptPath`, `Repo`, `AllowedTools`, and `WriteMode` derive from this decision.

**ADR-0085 D4 — Cross-repo write authority.** docs-sync opens one PR per affected repo per run (branch `chore/docs-sync-{YYYY-MM-DD}`) plus a per-run report PR to Architecture writing `generated/docs-sync-reports/{YYYY-MM-DD}.md`. This packet's `WriteMode = "pr"` and `OutputContract.LatestOutput` derive from this decision.

**ADR-0085 D6 — Cadence + execution surface.** v1 cadence is **weekly, Friday** (avoids the Monday/Thursday `hive-sync` slot). The original execution surface was "OpenClaw scheduled trigger … manual cadence is the floor." This packet re-homes that surface onto the ADR-0086 local worker by authoring the job spec, so the Friday cadence is automated rather than manual-floor.

**ADR-0086 — Pull-based local worker / job-spec runner.** The runner at `infrastructure/workers/grid-agent-runner/` runs declarative `.psd1` job specs validated by `Assert-GridAgentJobSpec`. This packet adds the `docs-sync` spec to that runner.

**ADR-0088 D3 Group 1 / D5 — Prerequisite gate.** No OpenClaw workload's schedule is stopped before its ADR-0086 replacement is proven. This packet *is* docs-sync's replacement scheduler; completing it makes docs-sync's Part-B gate green and unblocks stopping its OpenClaw schedule in packet 02.

**ADR-0088 D6 — No new invariants.** This packet adds no invariants and does not edit `constitution/invariants.md`.

## Constraints
- **Author, do not redesign.** docs-sync's design is fixed by ADR-0085. This packet only authors the runner wiring (the job spec) that re-homes its Friday cadence onto the ADR-0086 worker. Do not change the agent's scope, tools, or PR model beyond what ADR-0085 D1/D4 specify.
- **Match the existing spec shape exactly.** The schema (`Assert-GridAgentJobSpec`) requires all 18 keys; `TriggerKind` ∈ {label-queue, schedule, manual}; `WriteMode` ∈ {comment-only, commit, pr, none}; `WorkingDirectory`/`PromptPath` must be relative. Do not invent new keys or surfacing conventions; mirror `hive-sync.psd1` (the closest analog).
- **Avoid the `hive-sync` slot.** The Friday cadence (ADR-0085 D6) deliberately avoids the Monday/Thursday `hive-sync` schedule. Do not schedule docs-sync on Monday or Thursday.
- **No teardown here.** This packet adds the replacement scheduler only. It removes no OpenClaw runtime, secret, file, or schedule — those are packets 01–04, all downstream.
- **Do not edit `constitution/invariants.md`** (ADR-0088 D6).
- **Do not invent a new secret.** If the spec needs to reference the ADR-0085 docs-sync GitHub App token, mirror `grid-review.psd1`'s `RequiredSecrets` convention; keep `RequiredSecrets = @()` if host-config Vault wiring is the surfacing mechanism (as it is for `hive-sync`). **Invariant 8:** *Secret values never appear in logs, traces, exceptions, or telemetry.* The spec names secrets, never holds their values.

## Labels
`chore`, `tier-2`, `meta`, `ops`, `infrastructure`, `adr-0088`, `wave-0`

## Agent Handoff

**Objective:** Author a `docs-sync` job spec at `infrastructure/workers/grid-agent-runner/config/jobs/docs-sync.psd1` matching the existing spec shape, validate it against the runner's schema, and capture a dry-run smoke record — so docs-sync's ADR-0085 weekly-Friday cadence runs on the ADR-0086 local worker before its OpenClaw schedule is torn down.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Convert docs-sync's "manual-floor caveat" into a committed automated scheduler on the surviving (ADR-0086) runtime, as the operator-chosen prerequisite of the OpenClaw decommission.
- Feature: ADR-0088 OpenClaw decommission, Wave 0 (prerequisite that gates the teardown and satisfies packet 00's Part-B Group-1 gate).
- ADRs: ADR-0085 (docs-sync design — hosting, tools, PR model, Friday cadence), ADR-0086 (the runner this spec runs on), ADR-0088 (the decommission this gates).

**Acceptance Criteria:** As listed above.

**Dependencies:** None — this is the earliest packet (Wave 0).

**Constraints:**
- Match the existing `.psd1` spec shape; all 18 schema keys present; `TriggerKind="schedule"`, `WriteMode="pr"`, relative paths only.
- Weekly Friday cadence; avoid the Monday/Thursday `hive-sync` slot.
- Author the scheduler wiring only — no redesign of docs-sync, no teardown of any OpenClaw surface.
- Do not edit `constitution/invariants.md` (ADR-0088 D6).
- Invariant 8: *Secret values never appear in logs, traces, exceptions, or telemetry.* — the spec names secrets, never their values.

**Key Files:**
- `infrastructure/workers/grid-agent-runner/config/jobs/docs-sync.psd1` (new — the deliverable)
- `infrastructure/workers/grid-agent-runner/config/jobs/hive-sync.psd1` (the reference shape to copy)
- `infrastructure/workers/grid-agent-runner/lib/JobSpec.psm1` (`Assert-GridAgentJobSpec` — the schema)
- `infrastructure/workers/grid-agent-runner/scripts/Test-JobLocally.ps1` (the dry-run smoke harness)
- `infrastructure/workers/grid-agent-runner/README.md` (add the `docs-sync` Jobs bullet)
- `CHANGELOG.md`

**Contracts:**
- The job-spec hashtable schema enforced by `Assert-GridAgentJobSpec` (18 required keys; `TriggerKind` ∈ {label-queue, schedule, manual}; `WriteMode` ∈ {comment-only, commit, pr, none}; relative `WorkingDirectory`/`PromptPath`).
