---
name: Infrastructure
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "infrastructure", "adr-0086", "wave-3"]
dependencies: ["packet:03", "packet:07"]
adrs: ["ADR-0086", "ADR-0014", "ADR-0043"]
accepts: []
wave: 3
initiative: adr-0086-pull-based-local-worker-grid-review
node: honeydrunk-architecture
---

# Migrate scheduled agent jobs to the ADR-0086 runner

## Summary
Cut over the non-review scheduled agent jobs from OpenClaw/Honeyclaw to the ADR-0086 scheduled agent runner after packet 03 lands the framework and job specs. The jobs are `hive-sync`, `lore-source`, `lore-ingest`, and `lore-signal-review`. Each job gets a smoke-test record, latest output artifact, rollback note, and old-schedule status before the old schedule is disabled.

## Context
ADR-0086 now owns the common runner framework, not just PR review. The current jobs are agent workloads with schedules, repo checkouts, prompts, safe write modes, and output reports:

- `hive-sync` reconciles HoneyDrunk.Architecture with The Hive and creates or updates a reconciliation PR. It must not directly mutate the Hive board.
- `lore-source` sources public written material into HoneyDrunk.Lore `raw/` and writes `output/openclaw-sourcing-last-run.md`.
- `lore-ingest` compiles Lore `raw/` into `wiki/`, rebuilds indexes, writes `output/openclaw-ingest-last-run.md`, and commits safe changes.
- `lore-signal-review` writes a sparse signal report under `output/signal-review-YYYY-MM-DD.md` and does not mutate strategy artifacts or GitHub.

Packet 03 seeds the portable job specs. This packet performs the cutover record and operator-side schedule switch.

## Scope
- Verify packet 03 job specs point at canonical prompt files and repo-relative paths.
- Run smoke/dry runs through `scripts/Test-JobLocally.ps1` for each job.
- Record output comparison against the current OpenClaw/Honeyclaw behavior.
- Register Task Scheduler entries for the jobs on the chosen host.
- Disable the matching OpenClaw/Honeyclaw schedules only after smoke tests pass.
- Update docs/changelog with cutover status and rollback commands.

## Acceptance Criteria
- [ ] `hive-sync` runner smoke test completed and recorded with latest output/PR link.
- [ ] `lore-source` runner smoke test completed and recorded with latest output path.
- [ ] `lore-ingest` runner smoke test completed and recorded with latest output path.
- [ ] `lore-signal-review` runner smoke test completed and recorded with latest output path.
- [ ] Task Scheduler entries exist for each migrated job, or the PR records why a job remains manual-only.
- [ ] Old OpenClaw/Honeyclaw schedules are disabled only for jobs whose runner smoke tests passed.
- [ ] Rollback note exists for each job: re-enable old schedule, unregister runner task, and point to last known good output.
- [ ] No job spec contains host-specific absolute paths.
- [ ] CHANGELOG.md updated noting scheduled-agent job migration.

## Human Prerequisites
- [ ] Packet 03 runner framework has landed.
- [ ] Packet 07 Phase-A review cutover is green.
- [ ] Operator confirms the target host (home server by default) has Codex CLI / Claude Code CLI sessions, repo checkouts, and Vault access needed by the jobs.
- [ ] Operator has access to disable the existing OpenClaw/Honeyclaw schedules.

## Dependencies
- `packet:03` — runner framework and job specs.
- `packet:07` — proves the runner on the Architecture review pilot.

## Referenced ADR Decisions

**ADR-0086 D4** — Local scheduled agent runner is a portable job framework. Task Scheduler is the v1 adapter; job specs are portable; host-specific paths live only in host config.

**ADR-0086 D10** — Non-review OpenClaw/Honeyclaw jobs continue until replacement runner jobs are installed and smoke-tested, then old schedules are disabled per job.

**ADR-0014** — `hive-sync` remains the canonical Architecture reconciliation agent; only its scheduler/runtime moves.

**ADR-0043** — Lore and briefing-related scheduled agent work remains narrative/advisory; this packet moves execution substrate, not strategic authority.

## Constraints
- Do not mutate The Hive board directly from the runner.
- Do not copy prompt text into runner code; reference canonical prompt files.
- Do not disable an old schedule until the replacement runner job has a smoke-test record.
- Do not put host-specific absolute paths in committed job specs.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `infrastructure`, `adr-0086`, `wave-3`

## Agent Handoff

**Objective:** Migrate `hive-sync`, `lore-source`, `lore-ingest`, and `lore-signal-review` to the ADR-0086 scheduled agent runner. Smoke-test each job, record outputs/rollback, register Task Scheduler entries, and disable old OpenClaw/Honeyclaw schedules only after success.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Acceptance Criteria:** As listed above.

**Dependencies:** `packet:03`, `packet:07`.

**Key Files:**
- `infrastructure/workers/grid-agent-runner/config/jobs/hive-sync.psd1`
- `infrastructure/workers/grid-agent-runner/config/jobs/lore-source.psd1`
- `infrastructure/workers/grid-agent-runner/config/jobs/lore-ingest.psd1`
- `infrastructure/workers/grid-agent-runner/config/jobs/lore-signal-review.psd1`
- `infrastructure/workers/grid-agent-runner/README.md`
- `CHANGELOG.md`
