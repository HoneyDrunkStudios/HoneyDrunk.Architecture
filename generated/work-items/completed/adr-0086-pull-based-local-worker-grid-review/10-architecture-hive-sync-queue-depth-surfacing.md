---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0086", "wave-4"]
dependencies: ["work-item:03", "work-item:07", "work-item:11"]
adrs: ["ADR-0086", "ADR-0014", "ADR-0043"]
accepts: []
wave: 4
initiative: adr-0086-pull-based-local-worker-grid-review
node: honeydrunk-architecture
---

# Wire runner-health surfacing into hive-sync and the weekly ADR-0043 briefing

## Summary
Wire two narrative surfaces to make ADR-0086 runner availability observable without adding a pager or inbound alert. The weekly ADR-0043 briefing surfaces stale PR review queue items and scheduled runner jobs with missed or stale runs. `hive-sync` reports the same information as a Grid-health metric under a `grid_agent_runner` block.

## Context
ADR-0086 started with PR review reliability, but it now owns the portable scheduled agent runner framework. Review jobs have a GitHub-native durable queue (`needs-agent-review` labels + queue comments). Scheduled jobs (`hive-sync`, `lore-source`, `lore-ingest`, `lore-signal-review`) have runner heartbeat/state metadata, latest output artifacts, and schedules. Both need lightweight visibility through existing operator surfaces.

No pager, Telegram, Discord bot, dashboard, or inbound tunnel is added. The runner writes local heartbeat/job metadata; this packet teaches `hive-sync` and the weekly briefing how to read and report it.

## Scope
- Add a "Grid Agent Runner health" section to the ADR-0043 weekly briefing agent prompt. It lists PRs in `needs-agent-review` older than 24 h and runner scheduled jobs with missed runs or stale `last_success`.
- Add a `grid_agent_runner` block to the hive-sync/Grid-health output with review queue counts and scheduled-job freshness.
- Document the new field in `.claude/agents/hive-sync.md` and the briefing agent definition.

## Proposed Implementation

### Briefing input
The briefing agent reads:
- GitHub PR queue: `is:pr is:open label:needs-agent-review org:HoneyDrunkStudios`, with stale threshold `updated < now() - 24h`.
- Runner state: the host-configured runner state/heartbeat files written by packet 03, using job ids `grid-review`, `post-merge-audit`, `hive-sync`, `lore-source`, `lore-ingest`, and `lore-signal-review`.

When clean, the briefing notes: `Grid Agent Runner: clean.` When not clean, it names each stale PR or job with link/output path, age, `last_success`, `missed_runs`, and runner host id when available.

### hive-sync metric
`hive-sync` adds:

```json
{
  "grid_agent_runner": {
    "review_queue": {
      "total": 3,
      "stale_over_24h": 0,
      "stale_over_72h": 0
    },
    "scheduled_jobs": [
      {
        "job_id": "hive-sync",
        "last_success": "2026-05-28T06:07:12Z",
        "missed_runs": 0,
        "latest_output": "initiatives/drift-report.md"
      },
      {
        "job_id": "lore-ingest",
        "last_success": "2026-05-28T14:01:04Z",
        "missed_runs": 0,
        "latest_output": "output/openclaw-ingest-last-run.md"
      }
    ],
    "as_of": "2026-05-28T14:32:00Z",
    "runner_recent_tick": "2026-05-28T14:31:42Z"
  }
}
```

`runner_recent_tick` is optional. Minimum viable fields are `review_queue.total`, `review_queue.stale_over_24h`, `scheduled_jobs[].job_id`, `scheduled_jobs[].last_success`, `scheduled_jobs[].missed_runs`, and `as_of`.

### What this packet does NOT do
- Does **not** edit the runner source. Packet 03 owns the heartbeat/state files; this packet only teaches narrative surfaces to read them.
- Does **not** add an alarm, pager, dashboard, or new notification channel.
- Does **not** edit `.claude/agents/review.md`.

## Affected Files
- `.claude/agents/hive-sync.md` (or the canonical hive-sync agent definition file)
- `.claude/agents/brief.md` (or the ADR-0043 weekly-briefing agent definition file)
- `CHANGELOG.md`

## NuGet Dependencies
None. Agent-prompt edits only; no .NET project is created or modified.

## Boundary Check
- [x] Agent-prompt/doc edits stay in `HoneyDrunk.Architecture`.
- [x] No code change in any other repo.
- [x] Runner source (packet 03) is not modified.
- [x] `.claude/agents/review.md` is not edited.

## Acceptance Criteria
- [ ] Weekly briefing prompt includes "Grid Agent Runner health" under the Reactive pillar.
- [ ] Briefing lists stale `needs-agent-review` PRs older than 24 h.
- [ ] Briefing lists scheduled runner jobs with missed runs or stale `last_success`.
- [ ] Clean state renders `Grid Agent Runner: clean.`
- [ ] `hive-sync` outputs `grid_agent_runner.review_queue` with at least `total`, `stale_over_24h`, and `stale_over_72h`.
- [ ] `hive-sync` outputs `grid_agent_runner.scheduled_jobs[]` with at least `job_id`, `last_success`, `missed_runs`, and `latest_output`.
- [ ] `.claude/agents/hive-sync.md` documents the new `grid_agent_runner` field and its advisory meaning.
- [ ] No alarm, pager, or inbound notification surface is added.
- [ ] CHANGELOG.md updated noting runner-health surfacing.

## Human Prerequisites
- [ ] Packet 03 runner framework must have landed so heartbeat/state metadata exists.
- [ ] Confirm the canonical filename of the ADR-0043 weekly-briefing agent.
- [ ] Confirm where `hive-sync`'s output lands (likely the drift report or Grid-health JSON).

## Dependencies
- `work-item:03` — runner framework and heartbeat/state metadata.
- `work-item:07` — Phase-A review cutover; the review queue is meaningful after at least one repo uses it.
- `work-item:11` — scheduled agent job migration records the job ids, output paths, and old-schedule status to surface.

## Referenced ADR Decisions

**ADR-0086 D7 / Operational Consequences** — Runner availability is advisory. Review queue depth/backlog and scheduled-job freshness are narrative health signals.

**ADR-0086 D10 / D11** — `hive-sync` and Lore jobs migrate to ADR-0086 runner job specs after smoke tests; health surfacing must cover those scheduled jobs, not just PR review queue depth.

**ADR-0014** — Hive-sync / netrunner is the canonical reconciliation agent. Adding `grid_agent_runner` to its output is a direct restatement of that mandate.

**ADR-0043** — Weekly strategic/tactical/reactive briefing. Stale runner work is a Reactive-pillar concern.

## Constraints
- **No pager, no alarm, no inbound channel.** Narrative surfaces only.
- **Do not edit the runner source.** Packet 03 already exposes the data.
- **Do not edit `.claude/agents/review.md`.**
- **Default expectation is empty/clean.**

## Labels
`chore`, `tier-2`, `meta`, `docs`, `adr-0086`, `wave-4`

## Agent Handoff

**Objective:** Wire runner-health surfacing into the weekly ADR-0043 briefing and hive-sync output. Include stale review queue items and scheduled-job freshness for `hive-sync`, `lore-source`, `lore-ingest`, and `lore-signal-review`. No pager, alarm, dashboard, or inbound channel.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:** ADR-0086 now owns the portable scheduled agent runner framework. Packet 03 emits runner heartbeat/job metadata; this packet makes that metadata visible through existing narrative surfaces.

**Acceptance Criteria:** As listed above.

**Dependencies:** `work-item:03`, `work-item:07`, `work-item:11`.

**Constraints:** Narrative surfaces only; no runner-source changes; no `.claude/agents/review.md` changes.

**Key Files:**
- `.claude/agents/hive-sync.md` (or its canonical filename)
- `.claude/agents/brief.md` (or the ADR-0043 briefing agent's filename)
- `CHANGELOG.md`

**Contracts:** Consumes the existing `needs-agent-review` label on PRs plus runner heartbeat/job-output metadata. Produces the new briefing subsection and the `grid_agent_runner` field in hive-sync output.
