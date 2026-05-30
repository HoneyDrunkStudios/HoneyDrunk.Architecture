---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "infrastructure", "adr-0086", "wave-1"]
dependencies: ["packet:01", "packet:02"]
adrs: ["ADR-0086", "ADR-0081", "ADR-0079"]
accepts: []
wave: 1
initiative: adr-0086-pull-based-local-worker-grid-review
node: honeydrunk-architecture
---

# Author the portable scheduled agent runner framework (PowerShell + Task Scheduler)

## Summary
Author the portable local scheduled agent runner that can run review, hive-sync, and Lore jobs from declarative job specs. The first production job is the pull-based Grid Review Runner: it polls GitHub for PRs labelled `needs-agent-review`, claims them via a label swap, runs the canonical `.claude/agents/review.md` agent locally under Codex CLI / Claude Code CLI subscription auth, synthesizes independent findings into a single PR verdict when both reviewers run, and posts the verdict back. The same framework also seeds first-class specs for `hive-sync`, Lore sourcing, Lore ingest/compile, and Lore signal review so those OpenClaw/Honeyclaw scheduled jobs can migrate under ADR-0086 after smoke tests.

## Source location decision
**Pinned by this packet:** the runner source lives at `infrastructure/workers/grid-agent-runner/` in `HoneyDrunk.Architecture`. ADR-0086 D4 / Follow-up Work names this directory as the recommended placement and lets the implementing packet pin the choice. Rationale: keeps the runner source next to its governing ADR and the existing `infrastructure/openclaw/` runtime contract docs; avoids creating a new Node repo for what is, structurally, operator-machine automation; matches the home of other operator playbooks under `infrastructure/`.

The runner is operator-machine automation, not a deployable Node — it is intentionally not a `csproj`, not a service, and does not run on Azure Container Apps. The repo's CI gates are docs/markdown-flavored and do not touch PowerShell files.

## Context
ADR-0086 D1–D4 define the local scheduled agent runner as the canonical Grid Review Runner transport and the shared substrate for scheduled agent work that is moving off OpenClaw/Honeyclaw. The review job polls GitHub on a 1–5-minute cadence (60–120 s recommended during operator working hours per D4), claims one PR at a time via a label swap (D3 step 3), runs the canonical `.claude/agents/review.md` agent locally under Codex CLI / Claude Code CLI subscription auth, and posts the verdict back to the PR. The substrate change is invisible to the agent prompt — the same `.claude/agents/review.md` runs on either path per ADR-0007's source-of-truth rule.

The non-review jobs are equivalent scheduled-agent jobs, not GitHub webhook jobs: `hive-sync` reconciles Architecture state and opens/updates a PR; Lore sourcing writes qualifying sources into `raw/`; Lore ingest compiles `raw/` into `wiki/` and indexes; Lore signal review writes a sparse report. Their existing prompt files remain canonical. This packet builds the framework and committed job specs so the jobs can be registered on the home server or moved to another host/cloud VM with only host-config changes.

Authentication uses the existing ADR-0044 review-agent GitHub App and the shared automation Vault secrets audited by packet 02: `GitHub--AgentRunner--AppId`, `GitHub--AgentRunner--PrivateKey`, and `GitHub--AgentRunner--InstallationId` in `kv-hd-automation-dev`. The operator's `gh` CLI auth is **not** used by the runner. The operator's existing Codex CLI / Claude Code CLI subscription sessions are used for agent execution.

**This is the load-bearing build of the entire initiative.** Phase-A cutover (packet 07) consumes it.

## Proposed Implementation

### Directory layout
```
infrastructure/workers/grid-agent-runner/
├── README.md
├── Invoke-GridAgentRunner.ps1           # entry-point script Task Scheduler runs
├── lib/
│   ├── GitHub.psm1                      # App-token exchange, label/comment APIs
│   ├── Queue.psm1                       # review queue list/claim/release/complete protocol
│   ├── JobSpec.psm1                     # read/validate job specs and host config
│   ├── Scheduler.psm1                   # schedule/lock/missed-run helpers
│   ├── Agent.psm1                       # CLI invocation (Codex + Claude Code)
│   ├── Synthesis.psm1                   # combine Codex/Claude findings into one verdict
│   ├── State.psm1                       # pending-verdict on-disk cache
│   └── Logging.psm1                     # structured logs to a rotating file
├── config/
│   ├── host.psd1.example                # machine-specific paths/secrets/scheduler defaults
│   └── jobs/
│       ├── grid-review.psd1
│       ├── post-merge-audit.psd1
│       ├── hive-sync.psd1
│       ├── lore-source.psd1
│       ├── lore-ingest.psd1
│       └── lore-signal-review.psd1
└── scripts/
    ├── Register-Task.ps1                # one-shot installer for Windows Task Scheduler
    ├── Unregister-Task.ps1              # rollback helper
    └── Test-JobLocally.ps1              # smoke test (one job invocation, no Task Scheduler)
```

`config/host.psd1` (the operator's actual config; not committed) carries only machine-specific state: checkout roots, runtime/log/cache directories, scheduler defaults, the path to the Vault-cli or Azure-CLI binary, per-host repo locations, and the host identifier shape (recommend `<hostname>:<pid>:<runnerVersion>` per D3). Committed job specs use logical repo names and repo-relative prompt paths so the same specs can run on the home server, workstation, a cloud VM, or a container host.

### Job spec contract
Each `config/jobs/*.psd1` file declares:
- `JobId`, `Description`, `Enabled`, `TriggerKind` (`label-queue`, `schedule`, or `manual`), `Schedule`, `ConcurrencyKey`, `TimeoutMinutes`, and `MaxMissedRuns`.
- `Repo`, `WorkingDirectory`, `PromptPath`, `AgentCommands` (`codex`, `claude`, or both), `WriteMode` (`comment-only`, `commit`, `pr`, or `none`), and `OutputContract`.
- `RequiredSecrets` by Vault secret name only, `AllowedTools`, `RetainArtifactsDays`, and `PortabilityNotes`.

Initial specs:
- `grid-review`: GitHub PR label/comment queue, claim protocol per ADR-0086 D3, Codex/Claude synthesis, PR verdict comment.
- `post-merge-audit`: `audit-sample` queue, review agent audit mode, PR comment plus `generated/post-merge-audits/` artifact when ADR-0044 packets 15/16 land.
- `hive-sync`: scheduled/manual Architecture reconciliation using `.claude/agents/hive-sync.md`, branch/PR output, no direct Hive board mutations.
- `lore-source`: scheduled Lore sourcing using `HoneyDrunk.Lore/tools/openclaw-lore-sourcing-prompt.md`, `raw/` writes, `output/openclaw-sourcing-last-run.md` summary.
- `lore-ingest`: scheduled Lore ingest using `HoneyDrunk.Lore/tools/openclaw-lore-ingest-prompt.md`, `raw/` -> `wiki/` compile, index rebuild, `output/openclaw-ingest-last-run.md` summary.
- `lore-signal-review`: scheduled/manual Lore signal review using `HoneyDrunk.Lore/tools/openclaw-lore-signal-review-prompt.md`, output report only, no strategy artifact or GitHub mutation.

### Claim protocol (D3, implement verbatim)
The worker implements the six-step protocol from ADR-0086 D3:

1. **List.** Single `gh api search/issues` call per tick, filtered to PRs across `enabled` repos carrying the `needs-agent-review` label. The App-installation token authenticates the call (one extra `POST /app/installations/{installation_id}/access_tokens` per tick to mint the token).
2. **Pick.** Oldest unclaimed PR — creation time of the queue comment is the order key.
3. **Swap-claim.** Atomic via GitHub's edit-comment API: remove `needs-agent-review`, add `agent-review-in-progress`, and edit the queue comment in place to record `claimed_by` (host identifier), `claimed_at` (ISO-8601 UTC), and `head_sha` (the SHA being reviewed). If another worker raced and the label is already gone, read the next PR in the list.
4. **Stale-claim sweep.** At the top of each tick *before* listing, examine all PRs labelled `agent-review-in-progress` and swap any claim older than the configured threshold (15 min recommended) with no progress comment update back to `needs-agent-review`. Recovers from worker crashes mid-review.
5. **Head-SHA invalidation during claim.** Two detection points:
   - **Pre-flight (cheap):** before invoking the CLI, re-read the queue comment's `head_sha` and confirm it matches the SHA recorded in the claim. Mismatch → abort the run, swap `agent-review-in-progress` back to `needs-agent-review`, leave a one-line "claim invalidated; head advanced to `<Y>`" entry in the queue comment, pick up the next PR on the next tick. No CLI invocation is wasted.
   - **Post-flight (after CLI completes):** re-read the queue comment's `head_sha`. If it has advanced, the completed verdict is **discarded** (not posted), the claim is released the same way, and the next tick re-reviews against the new SHA.

   The idempotency key from ADR-0044 D1, preserved by ADR-0086 D3 — `owner/repo#pr@headSha` — makes "review at X" and "review at Y" distinct work items by construction. A pending-verdict cache keyed on `head_sha` survives crashes; a verdict for an abandoned SHA is garbage-collected on the next claim of that PR. **The worker never posts a verdict whose `head_sha` differs from the PR's current `head` at post time.**
6. **Complete.** On verdict post, remove `agent-review-in-progress` and add either `agent-reviewed` (no `Block` / `Request Changes` findings) or `changes-requested-by-agent` (one or more findings at those severities). The verdict body posts as a PR comment using the format already defined in `.claude/agents/review.md` (preserved from ADR-0044 D1).

### Auth (D4)
- **GitHub auth.** Read `GitHub--AgentRunner--AppId`, `GitHub--AgentRunner--PrivateKey`, and `GitHub--AgentRunner--InstallationId` from `kv-hd-automation-dev` at the start of each tick (one `az keyvault secret show` call per secret, or equivalent). Mint an installation token via `POST /app/installations/{installation_id}/access_tokens`. Use the resulting short-lived token for all GitHub API calls in the tick.
- **Codex CLI auth.** Inherited from the operator's existing ChatGPT Pro CLI session on the runner host. The runner shells out to `codex` (or the canonical CLI binary name per the operator's install).
- **Claude Code CLI auth.** Inherited from the operator's existing Claude Max session on the runner host. The runner shells out to `claude` (or `claude-code`).
- **Env hygiene (D4 / D8 / ADR-0079 D8).** The runner process spawns child processes with a deliberately minimal environment block: `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` must NOT be set. If either is present in the operator's shell, the runner explicitly unsets them in the child process environment before invoking the CLI. Document this in the README and the operator setup notes.

### Open-source safety gate
The review runner must be safe both when a malicious public PR lands and when someone clones `HoneyDrunk.Architecture` and reads or copies the worker source.

- A fresh clone is inert: `config/host.psd1` is uncommitted, `host.psd1.example` leaves `Safety.Enabled = $false`, and every non-dry-run job refuses to start until the operator explicitly enables the safety gate in local host config.
- `Safety.OperatorAcknowledgedUntrustedInputs = $true` is required before non-dry-run execution. That opt-in means the operator has reviewed the hostile-input model and repository allowlist on that machine.
- `Safety.RequireNonRepositoryRunnerRoot = $true` is required by default. Non-dry-run jobs and Task Scheduler registration must refuse to run the worker directly from a Git worktree or configured repository path; the scheduled task runs only from an operator-installed `Safety.TrustedRunnerRoot` copy with `host.psd1` kept outside cloned source.
- Label-queue jobs require `Safety.AllowedReviewRepositories`; the runner rejects queued PRs outside that exact `owner/repo` allowlist.
- Fork PRs are rejected by default (`Safety.AllowForkPullRequests = $false`). Enabling fork review is a host-local policy choice and must not be inherited from committed defaults.
- Private-head PRs are rejected by default (`Safety.AllowPrivateHeadRepositories = $false`), and the queue comment marker remains mandatory for recoverable runner claims.
- The runner treats PR title/body/comments, branch names, filenames, diffs, generated files, and linked docs as hostile prompt input. It must not check out the PR head, run PR code, install dependencies, execute repository scripts from the PR branch, or load arbitrary packet/context links supplied in the PR body.
- The runner reviews GitHub diff/context only, posts an advisory comment only, and keeps the GitHub App permissions bounded to `contents: read`, `pull_requests: write`, and `issues: write`.
- Child agent processes run with common cloud/source-control/API-token environment variables removed, including `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GITHUB_TOKEN`, `GH_TOKEN`, Azure/ARM variables, AWS variables, Google variables, package-publish tokens, and service tokens.
- Codex review passes run ephemeral, ignore repo-local rules, and use read-only sandboxing. Claude passes must use the equivalent non-mutating permission mode and disallow shell/edit tools when enabled.

### Multi-perspective synthesis (D8)
The worker reads the `review_risk_class` field from `catalogs/grid-health.json` (per ADR-0044 D8, populated by ADR-0044 packet 13 — that packet is preserved and not superseded by ADR-0086). When `review_risk_class` is `high` for a touched Node and the PR's authorship class is non-human:
- Run Codex CLI as Reviewer 3 and capture a structured raw verdict.
- Run Claude Code CLI as Reviewer 4 and capture a structured raw verdict.
- Run `Synthesis.psm1` to combine the two raw verdicts into one PR-facing comment.

Both passes are independent worker invocations, consume the same `.claude/agents/review.md`, and the two model families satisfy [Invariant 53](../../../constitution/invariants.md). The synthesis step deduplicates matching findings, preserves source attribution (`Codex`, `Claude`, or `Both`), calls out material disagreement, chooses the strongest blocking verdict when severities differ, and posts one combined PR comment. The raw per-model verdicts are saved only as transient local artifacts or cache entries for debugging and are not posted as competing PR comments.

The contrarian-prompt fallback (ADR-0044 D8) applies when only one model family is locally available — same model, two passes, the second pass deliberately contrarian. The synthesized verdict explicitly says which fallback was used or which pass was skipped.

**D8 activation in this packet is conditional on `review_risk_class` being present in `catalogs/grid-health.json`.** If the field is absent (ADR-0044 packet 13 has not landed yet), the worker logs a one-line "D8 deferred — `review_risk_class` not present" notice and runs Codex CLI only. This matches ADR-0044 D8's enforceability gate.

### Post-merge sampling audit (D9)
Per ADR-0086 D9 the audit is another runner job spec. The runner recognizes a second label, `audit-sample` (already seeded Grid-wide by ADR-0044 packet 08), and when a PR carries it the runner runs `.claude/agents/review.md` in audit mode (the audit-mode instruction block lives in the agent file per ADR-0044 D9; the runner reads it from the same file the canonical review reads). The merged-PR diff and original review artifacts are passed in. The verdict is posted to the PR and committed to `generated/post-merge-audits/` per ADR-0044's Follow-up Work — ADR-0086 D9 is explicit that the audit is end-to-end the same; only the execution host moves from OpenClaw to the local scheduled agent runner.

### Scheduled agent job specs (D4 / D10 / D11)
This packet seeds the job specs but does not disable the current OpenClaw/Honeyclaw schedules. Each scheduled job can be smoke-tested with `scripts/Test-JobLocally.ps1 -JobId <id>` and only cuts over when the relevant migration packet records output comparison and rollback.

- `hive-sync` runs in `HoneyDrunk.Architecture`, consumes `.claude/agents/hive-sync.md`, may create or update a reconciliation PR, and must not directly mutate The Hive board via GraphQL.
- `lore-source` runs in `HoneyDrunk.Lore`, consumes `tools/openclaw-lore-sourcing-prompt.md`, writes qualifying sources to `raw/`, and writes `output/openclaw-sourcing-last-run.md`.
- `lore-ingest` runs in `HoneyDrunk.Lore`, consumes `tools/openclaw-lore-ingest-prompt.md`, compiles `raw/` into `wiki/`, rebuilds indexes, writes `output/openclaw-ingest-last-run.md`, and commits safe changes.
- `lore-signal-review` runs in `HoneyDrunk.Lore`, consumes `tools/openclaw-lore-signal-review-prompt.md`, writes `output/signal-review-YYYY-MM-DD.md`, and does not mutate strategy artifacts or GitHub.

**This packet wires the audit-mode dispatch path** but does not exercise it end-to-end — ADR-0044 packets 15 and 16 own the `generated/post-merge-audits/` directory and the `audit-sample` labelling. When those land, the runner already supports the dispatch.

### Worker availability (D7)
- No paging, no inbound alerts, no Telegram, no Discord-via-tunnel. The queue itself is durable in GitHub and survives every worker outage.
- The runner logs each review tick's depth (number of `needs-agent-review` PRs Grid-wide) and each scheduled job's heartbeat/freshness to its rotating log/state files. Surfacing that to the weekly ADR-0043 briefing and the `hive-sync` / `netrunner` runner-health reporter is packet 10's concern.

### Task Scheduler installer
`scripts/Register-Task.ps1` is a one-shot operator-run script that:
- Creates Windows Scheduled Tasks named `HoneyDrunkGridReview`, `HoneyDrunkHiveSync`, `HoneyDrunkLoreSource`, `HoneyDrunkLoreIngest`, and `HoneyDrunkLoreSignalReview` from the committed job specs and the local host config.
- Triggers it at operator logon/startup and on the schedule declared by each job spec and `host.psd1`.
- Runs the task under the operator's interactive user (the same account that holds the Codex CLI / Claude Code CLI sessions).
- Sets each task action to `pwsh.exe -File <path>\Invoke-GridAgentRunner.ps1 -JobId <job-id>`.
- Sets task settings: restart on failure, do not start a new instance if the previous is still running (`MultipleInstances = IgnoreNew`), allow start on demand, run as soon as possible after a missed start, stop if the task runs longer than 30 minutes (defensive — a single PR review should never approach that), and write a heartbeat/tick log so reboot recovery is visible.

### README and operator setup notes
`infrastructure/workers/grid-agent-runner/README.md` documents:
- What the runner does (one-paragraph summary referencing ADR-0086).
- Prerequisites (packet 02 existing review-agent App audited and Vault credentials verified, Codex CLI installed and authenticated, Claude Code CLI installed and authenticated, local repo checkouts the runner pulls fresh per job).
- Env hygiene rules (no `ANTHROPIC_API_KEY`, no `OPENAI_API_KEY`).
- Installation steps (clone the repo, copy the runner to `Safety.TrustedRunnerRoot`, copy `config/host.psd1.example` to an operator-local host config outside cloned source, customize, run `scripts/Register-Task.ps1` from the installed runner copy).
- Smoke test (`scripts/Test-JobLocally.ps1 -JobId grid-review`, plus one dry run for each scheduled job).
- Troubleshooting (where logs land, how to read pending-verdict cache, how to manually unstick a stale claim).

Cross-link from `infrastructure/openclaw/grid-review-runner.md` (the legacy contract doc) — that cross-link is added by packet 08 when the legacy doc is marked superseded.

### What this packet does NOT do
- Does **not** edit `.claude/agents/review.md`. ADR-0086 D1 is explicit: the substrate change is invisible to the prompt.
- Does **not** rewrite `job-review-request.yml`. That's packet 05 in HoneyDrunk.Actions.
- Does **not** flip Architecture's `.honeydrunk-review.yaml` to `runner: local-worker`. That's packet 07 (Phase-A cutover).
- Does **not** remove the OpenClaw webhook bridge or the Cloudflare Tunnel hostname. That's packet 08 at Phase A → Phase B cutover.
- Does **not** decommission `infrastructure/openclaw/grid-review-runner.md`. That's packet 08.

## Affected Files
- `infrastructure/workers/grid-agent-runner/Invoke-GridAgentRunner.ps1` (new)
- `infrastructure/workers/grid-agent-runner/lib/*.psm1` (new)
- `infrastructure/workers/grid-agent-runner/config/host.psd1.example` (new)
- `infrastructure/workers/grid-agent-runner/config/jobs/*.psd1` (new)
- `infrastructure/workers/grid-agent-runner/scripts/Register-Task.ps1` (new)
- `infrastructure/workers/grid-agent-runner/scripts/Unregister-Task.ps1` (new)
- `infrastructure/workers/grid-agent-runner/scripts/Test-JobLocally.ps1` (new)
- `infrastructure/workers/grid-agent-runner/README.md` (new)
- `CHANGELOG.md`

## NuGet Dependencies
None. This packet creates PowerShell scripts and Markdown docs; no .NET project or `csproj` exists or is modified.

## Boundary Check
- [x] Runner source lives in `HoneyDrunk.Architecture/infrastructure/workers/grid-agent-runner/` — pinned in this packet per ADR-0086 D4 Follow-up Work recommendation.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.
- [x] The runner is operator-machine automation, not a deployable Node — no Azure Container App, no Function App, no Vault of its own.
- [x] `.claude/agents/review.md` is NOT edited (ADR-0086 D1).
- [x] `job-review-request.yml` is NOT edited (packet 05 owns that).

## Acceptance Criteria
- [ ] `infrastructure/workers/grid-agent-runner/` directory exists with the layout described above
- [ ] `Invoke-GridAgentRunner.ps1 -JobId grid-review` is a runnable PowerShell entry point that on each tick: (1) runs the stale-claim sweep first; (2) mints a fresh installation token from Vault-stored App credentials; (3) lists `needs-agent-review` PRs Grid-wide via the App-installation token; (4) picks oldest unclaimed; (5) swap-claims via label edit + queue-comment edit (claim records `claimed_by` / `claimed_at` / `head_sha`); (6) pre-flight checks the queue comment's `head_sha`; (7) invokes Codex CLI and, when D8 requires it, Claude Code CLI as independent passes; (8) synthesizes the two raw verdicts into one combined verdict when both ran; (9) post-flight re-checks `head_sha`; (10) posts verdict and completes via label swap to `agent-reviewed` or `changes-requested-by-agent`
- [ ] `JobSpec.psm1` validates all committed job specs and rejects host-specific absolute paths inside committed specs
- [ ] Initial job specs exist for `grid-review`, `post-merge-audit`, `hive-sync`, `lore-source`, `lore-ingest`, and `lore-signal-review`
- [ ] `hive-sync`, `lore-source`, `lore-ingest`, and `lore-signal-review` specs point at their existing canonical prompt files and declare schedule, concurrency key, timeout, write mode, output contract, required secrets by name, and rollback notes
- [ ] The runner reads `GitHub--AgentRunner--AppId`, `GitHub--AgentRunner--PrivateKey`, and `GitHub--AgentRunner--InstallationId` from `kv-hd-automation-dev`; does NOT read them from environment variables or config files (invariant 9)
- [ ] The runner does NOT use `gh` CLI auth for GitHub API calls — only the App-installation token
- [ ] Non-dry-run jobs refuse to start unless local `host.psd1` explicitly sets `Safety.Enabled = $true` and `Safety.OperatorAcknowledgedUntrustedInputs = $true`
- [ ] Non-dry-run jobs and Task Scheduler registration refuse to run the runner from a Git worktree or configured repository path when `Safety.RequireNonRepositoryRunnerRoot = $true`
- [ ] `grid-review` rejects queued PRs outside `Safety.AllowedReviewRepositories`, rejects fork/private-head PRs by default, requires the queue comment marker, ignores arbitrary PR-body packet links, and does not check out or execute PR-head code
- [ ] The runner spawns child CLI processes with `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, GitHub tokens, Azure/ARM variables, AWS variables, Google variables, package-publish tokens, and service tokens explicitly removed even if the parent environment has them set (ADR-0086 D4 / D8; ADR-0079 D8)
- [ ] Codex review passes run with an ephemeral read-only sandbox that ignores repo-local rules; Claude review passes use an equivalent non-mutating permission/tool profile when enabled
- [ ] The pending-verdict cache survives a worker crash mid-review; verdict for an abandoned SHA is garbage-collected on next claim
- [ ] The runner never posts a verdict whose `head_sha` differs from the PR's current `head` at post time
- [ ] D8 multi-perspective dispatch is wired: when `catalogs/grid-health.json` has `review_risk_class: high` for a touched Node, both Codex CLI and Claude Code CLI run as independent passes, `Synthesis.psm1` combines their findings, and the worker posts one synthesized verdict with source attribution; when `review_risk_class` is absent, the worker logs "D8 deferred" and runs Codex only
- [ ] D9 audit-mode dispatch is wired: when a PR carries the `audit-sample` label, the worker runs `.claude/agents/review.md` in audit mode (the wiring is in place; ADR-0044 packets 15/16 exercise it)
- [ ] `scripts/Register-Task.ps1` registers Windows Scheduled Tasks from the job specs with startup/logon or schedule triggers as appropriate, restart-on-failure behavior, missed-start recovery, and `MultipleInstances = IgnoreNew` under the operator's interactive user
- [ ] `scripts/Test-JobLocally.ps1` runs one named job without registering the Task Scheduler entry — for smoke testing
- [ ] `README.md` documents prerequisites, env hygiene rules, installation steps, smoke test, and troubleshooting
- [ ] `.claude/agents/review.md` is unchanged (ADR-0086 D1)
- [ ] `infrastructure/openclaw/grid-review-runner.md` is unchanged in this packet (packet 08 handles the supersession marking)
- [ ] No secret value appears in any committed file (invariant 8)
- [ ] CHANGELOG.md updated noting the runner framework and initial job specs landing

## Human Prerequisites
- [ ] Packet 02 (existing review-agent GitHub App audit + Vault credential verification) must be complete before the runner can mint installation tokens
- [ ] Codex CLI must be installed on the runner host and authenticated against the operator's ChatGPT Pro subscription
- [ ] Claude Code CLI must be installed on the runner host and authenticated against the operator's Claude Max subscription
- [ ] The operator's shell environment on the runner host must NOT have `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` set persistently (per ADR-0086 D4 env hygiene). If either is set, remove it from the persistent profile. The runner also unsets them in the child process environment as a defense-in-depth.
- [ ] The operator's Azure CLI session on the runner host must be able to read the three new Vault secrets (or the chosen Vault-CLI binding works equivalently)
- [ ] The operator must install the runner into `Safety.TrustedRunnerRoot`, keep `host.psd1` outside cloned source, and set `Safety.Enabled = $true`, `Safety.OperatorAcknowledgedUntrustedInputs = $true`, `Safety.RequireNonRepositoryRunnerRoot = $true`, and the exact `Safety.AllowedReviewRepositories` allowlist before any non-dry-run review job is registered
- [ ] After packet 03 lands, run `scripts/Test-JobLocally.ps1 -JobId grid-review` once on the home server to smoke-test before registering the review Scheduled Task
- [ ] Run dry/smoke tests for `hive-sync`, `lore-source`, `lore-ingest`, and `lore-signal-review` before disabling any current OpenClaw/Honeyclaw schedule
- [ ] After smoke-test passes, run `scripts/Register-Task.ps1` on the home server (per ADR-0081 D1) to install the Scheduled Task

## Dependencies
- `packet:01` — ADR-0086 acceptance (soft; references ADR-0086 decisions as live rules).
- `packet:02` — existing review-agent GitHub App audit + Vault credential verification (**hard** — the worker cannot mint installation tokens without these).

## Referenced ADR Decisions

**ADR-0086 D1** — Pull-based local runner is the canonical Grid Review Runner transport. Inbound webhook removed; Cloudflare Tunnel for review traffic removed; OpenClaw removed from the review path entirely. Execution moves to the local runner under Codex CLI / Claude Code CLI subscription auth. `.claude/agents/review.md` is unchanged — substrate change is invisible to the prompt per ADR-0007.

**ADR-0086 D4** — Local scheduled agent runner is a portable job framework, not one script. Task Scheduler is the v1 scheduler adapter; committed job specs are portable data; host-specific paths live only in host config. Initial job specs include review, post-merge audit, hive-sync, Lore sourcing, Lore ingest/compile, and Lore signal review.

**ADR-0086 D3** — Claim protocol: List → Pick → Swap-claim → Stale-claim sweep → Head-SHA invalidation (pre- and post-flight) → Complete. The labels carry the protocol state; the queue comment carries the audit trail. The idempotency key `owner/repo#pr@headSha` is preserved from ADR-0044 D1.

**ADR-0086 D4** — Runner shape: PowerShell + Windows Task Scheduler on the always-on home server per ADR-0081 D1; portable job specs; polling cadence 60–120 s for the review job; existing ADR-0044 review-agent GitHub App for auth where possible (not the operator's `gh` CLI); startup/logon and restart-on-failure Task Scheduler posture; Codex CLI + Claude Code CLI under subscription sessions; `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` must not be set in the runner environment.

**ADR-0086 D8** — Multi-perspective for high-risk Nodes: Reviewer 3 (Codex CLI under ChatGPT Pro) + Reviewer 4 (Claude Code CLI under Claude Max). Both passes are independent worker invocations, both consume the same canonical `.claude/agents/review.md`, the dual-model property satisfies invariant 53, and the worker posts one synthesized verdict. Contrarian-prompt fallback when only one model family is locally available.

**ADR-0086 D9** — Post-merge sampling audit (ADR-0044 D9) preserved: just another job type the worker dequeues. Audit-mode instruction block lives in `.claude/agents/review.md`. Worker selects audit mode based on the `audit-sample` label.

**ADR-0079 D8** — Auth-precedence gotcha: if `ANTHROPIC_API_KEY` is set as an environment variable, the Claude SDK uses it preferentially and per-token API billing applies silently. The worker enforces env hygiene by unsetting both `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` in child process environments.

**ADR-0007** — `.claude/agents/` is the single source of truth for agent definitions. The runner reads `.claude/agents/review.md` from a checkout of `HoneyDrunk.Architecture` it maintains; the file is never duplicated into the runner source. Existing hive-sync and Lore prompt files remain canonical for their job specs.

**ADR-0081 D1** — The always-on home server is the steady-state runner host (workstation hosting acceptable for prototyping). OpenClaw/Honeyclaw scheduled jobs continue until equivalent ADR-0086 runner jobs are smoke-tested and cut over.

## Constraints
> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. App-installation tokens and the App's private key must never be echoed into the runner's log file, into stderr, into PR comments, or into any committed file.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore` (or, for operator-machine automation like the worker, through the equivalent Vault-CLI binding documented in packet 02's walkthrough).

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled. The worker invokes the agent — it must not modify the agent's context-loading list. Changes to that list are edits to `.claude/agents/review.md`, which is out of scope for this packet.

> **Invariant 52 (preserved from ADR-0044, "requests" redefined by ADR-0086):** Every non-draft PR on an `enabled` repo lands in the GitHub-native queue (the `needs-agent-review` label + queue comment) and is processed by the local worker. Skip is via `skip-review` or `enabled: false` — both explicit and visible.

> **Invariant 53:** Agent-authored PRs touching a high-risk Node receive two independent LLM-review perspectives before merge. The canonical satisfaction is the dual-model execution of the Grid-aware `review` agent — Codex CLI (GPT-class) + Claude Code CLI (Anthropic). Both under subscription auth, both under this worker.

- **No agent-prompt duplication.** The runner reads `.claude/agents/review.md` from a local checkout of `HoneyDrunk.Architecture`; scheduled jobs reference their existing prompt files by path. Prompts are never copied into the runner source. Copying would create a drift surface and violate ADR-0007.
- **Advisory only.** The worker never makes a PR check required; never blocks a merge. Worker outage means PRs accumulate in `needs-agent-review` and remain mergeable (ADR-0086 D7; ADR-0011 D5 preserved).
- **Runner authenticates exclusively via the App-installation token for review GitHub API calls.** The operator's `gh` CLI may still be present on the host for interactive use but the runner process must not call `gh` for review API operations (it shells out to `curl` or `Invoke-RestMethod` with the minted token).
- **Env hygiene enforced in child process spawns.** Even if the operator's persistent shell has `ANTHROPIC_API_KEY` set, the worker unsets it in the child process environment block before invoking the CLI — defense-in-depth on the human prerequisite.
- **Head-SHA invalidation is non-negotiable.** The worker never posts a verdict whose `head_sha` differs from the PR's current `head` at post time. Wasted CLI runs are acceptable; stale verdicts are not.
- **No blind OpenClaw/Honeyclaw cutover.** This packet adds the runner and initial specs; it does not disable current hive-sync or Lore schedules. Each old schedule is disabled only after its runner job has a smoke-test record and rollback note.

## Labels
`chore`, `tier-2`, `meta`, `infrastructure`, `adr-0086`, `wave-1`

## Agent Handoff

**Objective:** Author the portable scheduled agent runner framework (PowerShell + Task Scheduler) at `infrastructure/workers/grid-agent-runner/`. Implement the D3 review claim protocol, the D4 job-spec framework, the D8 multi-perspective dispatch and synthesis, the D9 audit-mode dispatch, and first-class job specs for hive-sync and Lore scheduled work. Auth exclusively via the existing review-agent App installation token for GitHub PR review operations audited in packet 02.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Ship the Phase-A runner so Architecture's `.honeydrunk-review.yaml` can flip to `runner: local-worker` (packet 07).
- Feature: ADR-0086 Pull-Based Local Worker rollout, Phase A.
- ADRs: ADR-0086 (primary, D1/D3/D4/D8/D9), ADR-0007 (agent-definition source of truth), ADR-0011 D5 (advisory posture), ADR-0044 (preserved disciplines), ADR-0079 D8 (auth-precedence gotcha), ADR-0081 D1 (home-server host).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — ADR-0086 acceptance (soft).
- `packet:02` — existing review-agent GitHub App audit + Vault credential verification (hard).

**Constraints:**
- No agent-prompt duplication; read `.claude/agents/review.md` from a local Architecture checkout.
- Advisory only; never a required check.
- Worker uses ONLY the App-installation token for GitHub — never `gh` CLI.
- Env hygiene: child processes spawn with `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` unset.
- Head-SHA invalidation: never post a verdict whose `head_sha` differs from the PR's current `head` at post time.
- See "Constraints" — inlined for agent consumption.

**Key Files:**
- `infrastructure/workers/grid-agent-runner/Invoke-GridAgentRunner.ps1` (new)
- `infrastructure/workers/grid-agent-runner/lib/GitHub.psm1` (new)
- `infrastructure/workers/grid-agent-runner/lib/Queue.psm1` (new)
- `infrastructure/workers/grid-agent-runner/lib/JobSpec.psm1` (new)
- `infrastructure/workers/grid-agent-runner/lib/Scheduler.psm1` (new)
- `infrastructure/workers/grid-agent-runner/lib/Agent.psm1` (new)
- `infrastructure/workers/grid-agent-runner/lib/Synthesis.psm1` (new)
- `infrastructure/workers/grid-agent-runner/lib/State.psm1` (new)
- `infrastructure/workers/grid-agent-runner/lib/Logging.psm1` (new)
- `infrastructure/workers/grid-agent-runner/config/host.psd1.example` (new)
- `infrastructure/workers/grid-agent-runner/config/jobs/*.psd1` (new)
- `infrastructure/workers/grid-agent-runner/scripts/Register-Task.ps1` (new)
- `infrastructure/workers/grid-agent-runner/scripts/Unregister-Task.ps1` (new)
- `infrastructure/workers/grid-agent-runner/scripts/Test-JobLocally.ps1` (new)
- `infrastructure/workers/grid-agent-runner/README.md` (new)
- `CHANGELOG.md`

**Contracts:** Consumes `.claude/agents/review.md` (read-only) and the App-installation token from Vault. Reads `catalogs/grid-health.json` for `review_risk_class`. Reads each enabled repo's `.honeydrunk-review.yaml` (the schema doc from packet 04 is the reference). Produces PR comments and label-state transitions per ADR-0086 D2/D3/D6.
