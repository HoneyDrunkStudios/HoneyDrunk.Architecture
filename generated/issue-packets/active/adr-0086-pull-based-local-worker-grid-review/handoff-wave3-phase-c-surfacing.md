# Handoff: Wave 2 → Wave 3 (Phase B → Phase C)

**Read once at the Wave 2 → Wave 3 transition.** This is an ephemeral baton pass, not a live tracker. Immutable per invariant 24.

## Precondition — the Phase B go/no-go decision

Wave 3 does **not** start until packet 09's Phase B exit criterion is met and documented:

> All 10 Phase-B fan-out Nodes carry `runner: local-worker` in their `.honeydrunk-review.yaml`; each Node's enablement PR was itself reviewed by the runner end-to-end (queue comment appeared -> runner claimed -> verdict posted -> labels transitioned); the OpenClaw review-runner role is offline; non-review OpenClaw/Honeyclaw jobs are still running or already have explicit ADR-0086 runner cutover records; the ADR-0044 webhook-signing secret rotation is logged in Log Analytics per invariant 22; the Cloudflare Tunnel hostname for review traffic is removed.

The per-repo smoke-test outcomes are recorded in each of packet 09's 10 child PR bodies. If any Node's smoke test failed and the per-repo PR was halted, that Node's `.honeydrunk-review.yaml` is `enabled: false` (or the file absent) — note the exclusion in the wave's exit-criteria record. The remaining-N Phase-B success can still gate Phase C; the excluded Node is re-evaluated separately.

If multiple Nodes failed and the runner substrate looks structurally suspect, **stop** — diagnose against packet 03 (runner), packet 05 (workflow), or packet 02 (App). Phase C is scheduled-job migration; it should not start while the substrate has known structural gaps.

## What Wave 2 delivered (upstream changes Wave 3 builds on)

- **OpenClaw is decommissioned on the review path** (packet 08). The legacy `infrastructure/openclaw/grid-review-runner.md` carries the supersession banner pointing at `infrastructure/workers/grid-agent-runner/README.md`. The Cloudflare Tunnel hostname `grid-review.honeydrunkstudios.com` is removed. The ADR-0044 webhook-signing secret is rotated out of HoneyDrunk.Vault per ADR-0006, with the rotation logged in Log Analytics. Non-review OpenClaw/Honeyclaw jobs remain running until packet 11 records their runner smoke tests and cutovers.
- **Phase B fan-out shipped on the 10 .NET Nodes** (packet 09). Each Node carries `.honeydrunk-review.yaml` with `enabled: true, runner: local-worker` and a `pr-review.yml` caller declaring the widened `permissions:` block. The worker labels and managed PR labels are present on every repo (packet 06's Grid-wide fan-out covered this). Each per-repo enablement PR was itself reviewed by the worker; per-repo go decisions are in those PR bodies.
- **ADR-0044 Architecture#182 is closed as superseded** by packet 09's tracking issue. `initiatives/active-initiatives.md` reflects the supersession.

## Contracts Wave 3 consumes

- **The `needs-agent-review` label** (and the timestamp at which it was applied) is the review-queue data source. The `gh api search/issues` query — `is:pr is:open label:needs-agent-review org:HoneyDrunkStudios updated:<{since}` where `{since}` is 24 h ago — is the canonical review input source for packet 10's surfacing.
- **The runner's tick/heartbeat log** (per packet 03's Logging module) records review queue depth and per-job freshness to the rotating log/state files.
- **`hive-sync`'s canonical output surface** — wherever ADR-0014 defines the drift report and Grid-health metrics land. Packet 10 adds the `grid_agent_runner` block after packet 11 has job cutover records to report.
- **The ADR-0043 weekly briefing agent** — the canonical filename is the implementing agent's discovery (likely `.claude/agents/brief.md` or `.claude/agents/strategic.md`). Packet 10 adds the "Grid Agent Runner health" subsection under the Reactive pillar.

## Wave 3 objectives (Phase C — scheduled agent job migration)

1. **Migrate scheduled agent jobs to the ADR-0086 runner** (packet 11). Smoke-test and cut over `hive-sync`, `lore-source`, `lore-ingest`, and `lore-signal-review`; disable old OpenClaw/Honeyclaw schedules only after each runner job has a success record and rollback note.
2. **Prepare Wave 4 health surfacing.** Packet 11 records the job ids, output paths, and schedule status that packet 10 will surface.
3. **Coupling with ADR-0044 packets 13/14 and 15/16 remains preserved.** D8 multi-perspective and D9 post-merge audit activate downstream on the local-runner substrate without additional work here.

## Constraints carried into Wave 3

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled. Packet 10 does not edit `.claude/agents/review.md`; it edits `.claude/agents/hive-sync.md` and `.claude/agents/brief.md` (or their canonical filenames). The review-agent context-loading contract is unaffected.

- **No pager, no alarm, no inbound channel.** ADR-0086 D7 is explicit. The briefing and hive-sync output are narrative surfaces, not alerting infrastructure.
- **Default expectation is empty.** "Worker queue: clean" is the steady-state line.
- **Do not edit `.claude/agents/review.md`.** ADR-0086 D1 explicit.
- **Do not edit `constitution/invariants.md`.** ADR-0086 Invariants section explicit; reconciliation is `hive-sync`'s job per ADR-0014.
- **Do not edit ADR-0081.** ADR-0086 Follow-up Work explicit; the one-line D1 edit belongs to ADR-0081's own acceptance cycle.
- **Do not disable old schedules before smoke tests pass.** This is the load-bearing safety rule for Phase C.
- **Do not modify the runner framework unless a smoke test proves packet 03 has a defect.** Packet 11 is primarily cutover/verification.

## Open coupling at the wave boundary

- **D8 multi-perspective on high-risk Nodes** — preserved as discipline; activates downstream when ADR-0044 packet 13 (catalog field) and packet 14 (workflow activation) land. No work in this initiative.
- **D9 post-merge sampling audit** — preserved as discipline; activates downstream when ADR-0044 packets 15/16 land. No work in this initiative.
- **Reviewer 4 via Claude Code CLI under Max** — already live as of Phase A. The June 15 2026 dependency from ADR-0079 D2 is removed; no transition event remains.
- **Polish-phase items mentioned in ADR-0086 D2 (optional richer payload via workflow artifact) and D4 (optional off-hours cadence tuning)** — both are explicitly not v1 requirements. Each is its own follow-up initiative if/when observed gaps justify the complication.

## Acceptance signal — initiative complete

Packet 11 ships: `hive-sync`, `lore-source`, `lore-ingest`, and `lore-signal-review` have runner smoke tests, output records, rollback notes, and old-schedule status recorded. Then file Wave 4 packet 10 for narrative health surfacing. The initiative archives only after packet 10 also lands.

Downstream coupling — D8 activation on the local-worker substrate when ADR-0044 packets 13/14 land; D9 activation when ADR-0044 packets 15/16 land — is **not** part of this initiative's archive condition. Those are ADR-0044 initiative items; their landing is the trigger, not a packet here.
