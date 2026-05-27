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

# Author the pull-based Grid Review Runner local worker (PowerShell + Task Scheduler)

## Summary
Author the local pull worker that polls GitHub for PRs labelled `needs-agent-review`, claims them via a label swap, runs the canonical `.claude/agents/review.md` agent locally under Codex CLI / Claude Code CLI subscription auth, and posts the verdict back. Implement the D3 claim protocol (list/pick/swap-claim, stale-claim sweep, head-SHA invalidation pre- and post-flight, complete) and the D4 worker shape (PowerShell + Windows Task Scheduler, App-installation-token auth via Vault, env hygiene). Land the worker source under `infrastructure/workers/grid-review-runner/`.

## Source location decision
**Pinned by this packet:** the worker source lives at `infrastructure/workers/grid-review-runner/` in `HoneyDrunk.Architecture`. ADR-0086 D4 / Follow-up Work names this directory as the recommended placement and lets the implementing packet pin the choice. Rationale: keeps the worker source next to its governing ADR and the existing `infrastructure/openclaw/grid-review-runner.md` contract doc (which packet 08 supersedes); avoids creating a new Node repo for what is, structurally, a small operator-machine automation; matches the home of other operator playbooks under `infrastructure/`.

The worker is operator-machine automation, not a deployable Node — it is intentionally not a `csproj`, not a service, and does not run on Azure Container Apps. The repo's CI gates are docs/markdown-flavored and do not touch PowerShell files.

## Context
ADR-0086 D1–D4 define the pull-based local worker as the canonical Grid Review Runner transport. The worker polls GitHub on a 1–5-minute cadence (60–120 s recommended during operator working hours per D4), claims one PR at a time via a label swap (D3 step 3), runs the canonical `.claude/agents/review.md` agent locally under Codex CLI / Claude Code CLI subscription auth, and posts the verdict back to the PR. The substrate change is invisible to the agent prompt — the same `.claude/agents/review.md` runs on either path per ADR-0007's source-of-truth rule.

Authentication uses the `honeydrunk-review-worker` GitHub App (packet 02). The operator's `gh` CLI auth is **not** used by the worker. The operator's existing Codex CLI / Claude Code CLI subscription sessions are used for agent execution.

**This is the load-bearing build of the entire initiative.** Phase-A cutover (packet 07) consumes it.

## Proposed Implementation

### Directory layout
```
infrastructure/workers/grid-review-runner/
├── README.md
├── Invoke-GridReviewWorker.ps1          # entry-point script Task Scheduler runs
├── lib/
│   ├── GitHub.psm1                      # App-token exchange, label/comment APIs
│   ├── Queue.psm1                       # list/claim/release/complete protocol
│   ├── Agent.psm1                       # CLI invocation (Codex + Claude Code)
│   ├── State.psm1                       # pending-verdict on-disk cache
│   └── Logging.psm1                     # structured logs to a rotating file
├── config/
│   └── worker.psd1.example              # operator-customizable config
└── scripts/
    ├── Register-Task.ps1                # one-shot installer for Windows Task Scheduler
    └── Test-WorkerLocally.ps1           # smoke test (single-tick run, no Task Scheduler)
```

`config/worker.psd1` (the operator's actual config; not committed) carries: the polling cadence in seconds, the per-tick PR list cap (recommend 25 per ADR-0086 D3), the stale-claim sweep threshold (recommend 15 min per D3), the path to the Vault-cli or Azure-CLI binary the worker uses to read App-credentials, the path to the local `.claude/agents/review.md` (resolved relative to a checkout of `HoneyDrunk.Architecture` the worker maintains), and the host identifier shape (recommend `<hostname>:<pid>:<workerVersion>` per D3).

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
- **GitHub auth.** Read `review-worker-github-app-id`, `review-worker-github-app-private-key`, `review-worker-github-app-installation-id` from the CI-surface Key Vault at the start of each tick (one `az keyvault secret show` call per secret, or equivalent). Mint an installation token via `POST /app/installations/{installation_id}/access_tokens`. Use the resulting short-lived token for all GitHub API calls in the tick.
- **Codex CLI auth.** Inherited from the operator's existing ChatGPT Pro CLI session on the worker host. The worker shells out to `codex` (or the canonical CLI binary name per the operator's install).
- **Claude Code CLI auth.** Inherited from the operator's existing Claude Max session on the worker host. The worker shells out to `claude` (or `claude-code`).
- **Env hygiene (D4 / D8 / ADR-0079 D8).** The worker process spawns child processes with a deliberately minimal environment block: `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` must NOT be set. If either is present in the operator's shell, the worker explicitly unsets them in the child process environment before invoking the CLI. Document this in the README and the operator setup notes.

### Multi-perspective preparation (D8)
The worker reads the `review_risk_class` field from `catalogs/grid-health.json` (per ADR-0044 D8, populated by ADR-0044 packet 13 — that packet is preserved and not superseded by ADR-0086). When `review_risk_class` is `high` for a touched Node and the PR's authorship class is non-human:
- Run Codex CLI as Reviewer 3 — post the verdict as one PR comment.
- Run Claude Code CLI as Reviewer 4 — post the verdict as a second, separate PR comment.

Both passes are independent worker invocations, consume the same `.claude/agents/review.md`, and the two model families satisfy [Invariant 53](../../../constitution/invariants.md). The contrarian-prompt fallback (ADR-0044 D8) applies when only one model family is locally available — same model, two passes, the second pass deliberately contrarian (the worker logs which fallback it took).

**D8 activation in this packet is conditional on `review_risk_class` being present in `catalogs/grid-health.json`.** If the field is absent (ADR-0044 packet 13 has not landed yet), the worker logs a one-line "D8 deferred — `review_risk_class` not present" notice and runs Codex CLI only. This matches ADR-0044 D8's enforceability gate.

### Post-merge sampling audit (D9)
Per ADR-0086 D9 the audit is "just another job type the worker dequeues." The worker recognizes a second label, `audit-sample` (already seeded Grid-wide by ADR-0044 packet 08), and when a PR carries it the worker runs `.claude/agents/review.md` in audit mode (the audit-mode instruction block lives in the agent file per ADR-0044 D9; the worker reads it from the same file the canonical review reads). The merged-PR diff and original review artifacts are passed in. The verdict is posted to the PR and committed to `generated/post-merge-audits/` per ADR-0044's Follow-up Work — ADR-0086 D9 is explicit that the audit is end-to-end the same; only the execution host moves from OpenClaw to the local worker.

**This packet wires the audit-mode dispatch path** but does not exercise it end-to-end — ADR-0044 packets 15 and 16 own the `generated/post-merge-audits/` directory and the `audit-sample` labelling. When those land, the worker already supports the dispatch.

### Worker availability (D7)
- No paging, no inbound alerts, no Telegram, no Discord-via-tunnel. The queue itself is durable in GitHub and survives every worker outage.
- The worker logs each tick's depth (number of `needs-agent-review` PRs Grid-wide) to its rotating log file. Surfacing that to the weekly ADR-0043 briefing and the `hive-sync` / `netrunner` queue-depth reporter is packet 10's concern.

### Task Scheduler installer
`scripts/Register-Task.ps1` is a one-shot operator-run script that:
- Creates a Windows Scheduled Task named `HoneyDrunkGridReviewWorker`.
- Triggers it on a 60-second repeating interval (configurable in `worker.psd1`).
- Runs the task under the operator's interactive user (the same account that holds the Codex CLI / Claude Code CLI sessions).
- Sets the task action to `pwsh.exe -File <path>\Invoke-GridReviewWorker.ps1`.
- Sets task settings: do not start a new instance if the previous is still running (`MultipleInstances = IgnoreNew`), allow start on demand, stop if the task runs longer than 30 minutes (defensive — a single PR review should never approach that).

### README and operator setup notes
`infrastructure/workers/grid-review-runner/README.md` documents:
- What the worker does (one-paragraph summary referencing ADR-0086).
- Prerequisites (packet 02 GitHub App provisioned, Codex CLI installed and authenticated, Claude Code CLI installed and authenticated, local `HoneyDrunk.Architecture` checkout the worker pulls fresh per tick).
- Env hygiene rules (no `ANTHROPIC_API_KEY`, no `OPENAI_API_KEY`).
- Installation steps (clone the repo, copy `config/worker.psd1.example` → `worker.psd1`, customize, run `scripts/Register-Task.ps1`).
- Smoke test (`scripts/Test-WorkerLocally.ps1`).
- Troubleshooting (where logs land, how to read pending-verdict cache, how to manually unstick a stale claim).

Cross-link from `infrastructure/openclaw/grid-review-runner.md` (the legacy contract doc) — that cross-link is added by packet 08 when the legacy doc is marked superseded.

### What this packet does NOT do
- Does **not** edit `.claude/agents/review.md`. ADR-0086 D1 is explicit: the substrate change is invisible to the prompt.
- Does **not** rewrite `job-review-request.yml`. That's packet 05 in HoneyDrunk.Actions.
- Does **not** flip Architecture's `.honeydrunk-review.yaml` to `runner: local-worker`. That's packet 07 (Phase-A cutover).
- Does **not** remove the OpenClaw webhook bridge or the Cloudflare Tunnel hostname. That's packet 08 at Phase A → Phase B cutover.
- Does **not** decommission `infrastructure/openclaw/grid-review-runner.md`. That's packet 08.

## Affected Files
- `infrastructure/workers/grid-review-runner/Invoke-GridReviewWorker.ps1` (new)
- `infrastructure/workers/grid-review-runner/lib/*.psm1` (new — five modules)
- `infrastructure/workers/grid-review-runner/config/worker.psd1.example` (new)
- `infrastructure/workers/grid-review-runner/scripts/Register-Task.ps1` (new)
- `infrastructure/workers/grid-review-runner/scripts/Test-WorkerLocally.ps1` (new)
- `infrastructure/workers/grid-review-runner/README.md` (new)
- `CHANGELOG.md`

## NuGet Dependencies
None. This packet creates PowerShell scripts and Markdown docs; no .NET project or `csproj` exists or is modified.

## Boundary Check
- [x] Worker source lives in `HoneyDrunk.Architecture/infrastructure/workers/grid-review-runner/` — pinned in this packet per ADR-0086 D4 Follow-up Work recommendation.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.
- [x] The worker is operator-machine automation, not a deployable Node — no Azure Container App, no Function App, no Vault of its own.
- [x] `.claude/agents/review.md` is NOT edited (ADR-0086 D1).
- [x] `job-review-request.yml` is NOT edited (packet 05 owns that).

## Acceptance Criteria
- [ ] `infrastructure/workers/grid-review-runner/` directory exists with the layout described above
- [ ] `Invoke-GridReviewWorker.ps1` is a runnable PowerShell entry point that on each tick: (1) runs the stale-claim sweep first; (2) mints a fresh installation token from Vault-stored App credentials; (3) lists `needs-agent-review` PRs Grid-wide via the App-installation token; (4) picks oldest unclaimed; (5) swap-claims via label edit + queue-comment edit (claim records `claimed_by` / `claimed_at` / `head_sha`); (6) pre-flight checks the queue comment's `head_sha`; (7) invokes Codex CLI (and Claude Code CLI if D8 high-risk applies); (8) post-flight re-checks `head_sha`; (9) posts verdict and completes via label swap to `agent-reviewed` or `changes-requested-by-agent`
- [ ] The worker reads `review-worker-github-app-id`, `review-worker-github-app-private-key`, `review-worker-github-app-installation-id` from the CI-surface Key Vault; does NOT read them from environment variables or config files (invariant 9)
- [ ] The worker does NOT use `gh` CLI auth for its GitHub API calls — only the App-installation token
- [ ] The worker spawns child CLI processes with `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` explicitly unset, even if the parent environment has them set (ADR-0086 D4 / D8; ADR-0079 D8)
- [ ] The pending-verdict cache survives a worker crash mid-review; verdict for an abandoned SHA is garbage-collected on next claim
- [ ] The worker never posts a verdict whose `head_sha` differs from the PR's current `head` at post time
- [ ] D8 multi-perspective dispatch is wired: when `catalogs/grid-health.json` has `review_risk_class: high` for a touched Node, both Codex CLI and Claude Code CLI run as independent passes and post separate comments; when `review_risk_class` is absent, the worker logs "D8 deferred" and runs Codex only
- [ ] D9 audit-mode dispatch is wired: when a PR carries the `audit-sample` label, the worker runs `.claude/agents/review.md` in audit mode (the wiring is in place; ADR-0044 packets 15/16 exercise it)
- [ ] `scripts/Register-Task.ps1` registers a Windows Scheduled Task `HoneyDrunkGridReviewWorker` with a 60-second repeating trigger (configurable) under the operator's interactive user
- [ ] `scripts/Test-WorkerLocally.ps1` runs a single tick without registering the Task Scheduler entry — for smoke testing
- [ ] `README.md` documents prerequisites, env hygiene rules, installation steps, smoke test, and troubleshooting
- [ ] `.claude/agents/review.md` is unchanged (ADR-0086 D1)
- [ ] `infrastructure/openclaw/grid-review-runner.md` is unchanged in this packet (packet 08 handles the supersession marking)
- [ ] No secret value appears in any committed file (invariant 8)
- [ ] CHANGELOG.md updated noting the worker source landing

## Human Prerequisites
- [ ] Packet 02 (GitHub App + Vault credentials) must be complete before the worker can mint installation tokens
- [ ] Codex CLI must be installed on the worker host and authenticated against the operator's ChatGPT Pro subscription
- [ ] Claude Code CLI must be installed on the worker host and authenticated against the operator's Claude Max subscription
- [ ] The operator's shell environment on the worker host must NOT have `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` set persistently (per ADR-0086 D4 env hygiene). If either is set, remove it from the persistent profile. The worker also unsets them in the child process environment as a defense-in-depth.
- [ ] The operator's Azure CLI session on the worker host must be able to read the three new Vault secrets (or the chosen Vault-CLI binding works equivalently)
- [ ] After packet 03 lands, run `scripts/Test-WorkerLocally.ps1` once on the home server to smoke-test before registering the Task Scheduler entry
- [ ] After smoke-test passes, run `scripts/Register-Task.ps1` on the home server (per ADR-0081 D1) to install the Scheduled Task

## Dependencies
- `packet:01` — ADR-0086 acceptance (soft; references ADR-0086 decisions as live rules).
- `packet:02` — GitHub App + Vault credentials (**hard** — the worker cannot mint installation tokens without these).

## Referenced ADR Decisions

**ADR-0086 D1** — Pull-based local worker is the canonical Grid Review Runner transport. Inbound webhook removed; Cloudflare Tunnel for review traffic removed; OpenClaw removed from the review path entirely. Execution moves to the local worker under Codex CLI / Claude Code CLI subscription auth. `.claude/agents/review.md` is unchanged — substrate change is invisible to the prompt per ADR-0007.

**ADR-0086 D3** — Claim protocol: List → Pick → Swap-claim → Stale-claim sweep → Head-SHA invalidation (pre- and post-flight) → Complete. The labels carry the protocol state; the queue comment carries the audit trail. The idempotency key `owner/repo#pr@headSha` is preserved from ADR-0044 D1.

**ADR-0086 D4** — Worker shape: PowerShell + Windows Task Scheduler on the always-on home server per ADR-0081 D1; polling cadence 60–120 s during operator working hours; dedicated `honeydrunk-review-worker` GitHub App for auth (not the operator's `gh` CLI); Codex CLI + Claude Code CLI under subscription sessions; `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` must not be set in the worker environment.

**ADR-0086 D8** — Multi-perspective for high-risk Nodes: Reviewer 3 (Codex CLI under ChatGPT Pro) + Reviewer 4 (Claude Code CLI under Claude Max). Both passes are independent worker invocations, both consume the same canonical `.claude/agents/review.md`, the dual-model property satisfies invariant 53. Contrarian-prompt fallback when only one model family is locally available.

**ADR-0086 D9** — Post-merge sampling audit (ADR-0044 D9) preserved: just another job type the worker dequeues. Audit-mode instruction block lives in `.claude/agents/review.md`. Worker selects audit mode based on the `audit-sample` label.

**ADR-0079 D8** — Auth-precedence gotcha: if `ANTHROPIC_API_KEY` is set as an environment variable, the Claude SDK uses it preferentially and per-token API billing applies silently. The worker enforces env hygiene by unsetting both `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` in child process environments.

**ADR-0007** — `.claude/agents/` is the single source of truth for agent definitions. The worker reads `.claude/agents/review.md` from a checkout of `HoneyDrunk.Architecture` it maintains; the file is never duplicated into the worker source.

**ADR-0081 D1** — The always-on home server is the steady-state worker host (workstation hosting acceptable for prototyping). Other home-server workloads — Honeyclaw, scheduled Lore sourcing per ADR-0043, OpenClaw's non-review roles — are unaffected by this packet.

## Constraints
> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. App-installation tokens and the App's private key must never be echoed into the worker's log file, into stderr, into PR comments, or into any committed file.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore` (or, for operator-machine automation like the worker, through the equivalent Vault-CLI binding documented in packet 02's walkthrough).

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled. The worker invokes the agent — it must not modify the agent's context-loading list. Changes to that list are edits to `.claude/agents/review.md`, which is out of scope for this packet.

> **Invariant 52 (preserved from ADR-0044, "requests" redefined by ADR-0086):** Every non-draft PR on an `enabled` repo lands in the GitHub-native queue (the `needs-agent-review` label + queue comment) and is processed by the local worker. Skip is via `skip-review` or `enabled: false` — both explicit and visible.

> **Invariant 53:** Agent-authored PRs touching a high-risk Node receive two independent LLM-review perspectives before merge. The canonical satisfaction is the dual-model execution of the Grid-aware `review` agent — Codex CLI (GPT-class) + Claude Code CLI (Anthropic). Both under subscription auth, both under this worker.

- **No agent-prompt duplication.** The worker reads `.claude/agents/review.md` from a local checkout of `HoneyDrunk.Architecture`; the prompt is never copied into the worker source. Copying would create a drift surface and violate ADR-0007.
- **Advisory only.** The worker never makes a PR check required; never blocks a merge. Worker outage means PRs accumulate in `needs-agent-review` and remain mergeable (ADR-0086 D7; ADR-0011 D5 preserved).
- **Worker authenticates exclusively via the App-installation token.** The operator's `gh` CLI may still be present on the host for interactive use but the worker process must not call `gh` (it shells out to `curl` or `Invoke-RestMethod` with the minted token).
- **Env hygiene enforced in child process spawns.** Even if the operator's persistent shell has `ANTHROPIC_API_KEY` set, the worker unsets it in the child process environment block before invoking the CLI — defense-in-depth on the human prerequisite.
- **Head-SHA invalidation is non-negotiable.** The worker never posts a verdict whose `head_sha` differs from the PR's current `head` at post time. Wasted CLI runs are acceptable; stale verdicts are not.
- **OpenClaw's other workloads are unaffected.** This packet adds the worker; it does not stop or alter Honeyclaw, ADR-0043 Lore sourcing, or any other home-server workload.

## Labels
`chore`, `tier-2`, `meta`, `infrastructure`, `adr-0086`, `wave-1`

## Agent Handoff

**Objective:** Author the pull-based Grid Review Runner local worker (PowerShell + Task Scheduler) at `infrastructure/workers/grid-review-runner/`. Implement the D3 claim protocol, the D4 worker shape, the D8 multi-perspective dispatch, the D9 audit-mode dispatch. Auth exclusively via the `honeydrunk-review-worker` App installation token.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Ship the Phase-A worker so Architecture's `.honeydrunk-review.yaml` can flip to `runner: local-worker` (packet 07).
- Feature: ADR-0086 Pull-Based Local Worker rollout, Phase A.
- ADRs: ADR-0086 (primary, D1/D3/D4/D8/D9), ADR-0007 (agent-definition source of truth), ADR-0011 D5 (advisory posture), ADR-0044 (preserved disciplines), ADR-0079 D8 (auth-precedence gotcha), ADR-0081 D1 (home-server host).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — ADR-0086 acceptance (soft).
- `packet:02` — GitHub App + Vault credentials (hard).

**Constraints:**
- No agent-prompt duplication; read `.claude/agents/review.md` from a local Architecture checkout.
- Advisory only; never a required check.
- Worker uses ONLY the App-installation token for GitHub — never `gh` CLI.
- Env hygiene: child processes spawn with `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` unset.
- Head-SHA invalidation: never post a verdict whose `head_sha` differs from the PR's current `head` at post time.
- See "Constraints" — inlined for agent consumption.

**Key Files:**
- `infrastructure/workers/grid-review-runner/Invoke-GridReviewWorker.ps1` (new)
- `infrastructure/workers/grid-review-runner/lib/GitHub.psm1` (new)
- `infrastructure/workers/grid-review-runner/lib/Queue.psm1` (new)
- `infrastructure/workers/grid-review-runner/lib/Agent.psm1` (new)
- `infrastructure/workers/grid-review-runner/lib/State.psm1` (new)
- `infrastructure/workers/grid-review-runner/lib/Logging.psm1` (new)
- `infrastructure/workers/grid-review-runner/config/worker.psd1.example` (new)
- `infrastructure/workers/grid-review-runner/scripts/Register-Task.ps1` (new)
- `infrastructure/workers/grid-review-runner/scripts/Test-WorkerLocally.ps1` (new)
- `infrastructure/workers/grid-review-runner/README.md` (new)
- `CHANGELOG.md`

**Contracts:** Consumes `.claude/agents/review.md` (read-only) and the App-installation token from Vault. Reads `catalogs/grid-health.json` for `review_risk_class`. Reads each enabled repo's `.honeydrunk-review.yaml` (the schema doc from packet 04 is the reference). Produces PR comments and label-state transitions per ADR-0086 D2/D3/D6.
