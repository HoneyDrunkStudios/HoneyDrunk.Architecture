---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Audit
labels: ["chore", "tier-2", "infrastructure", "human-only", "adr-0036", "wave-4"]
dependencies: ["work-item:05", "work-item:07a"]
adrs: ["ADR-0036", "ADR-0031"]
accepts: ["ADR-0036"]
wave: 4
initiative: adr-0036-disaster-recovery
node: honeydrunk-audit
---

# Execute the first Audit T0 restore drill and log the outcome (ADR-0036 D3)

## Summary
Execute the first Audit restore drill following `repos/HoneyDrunk.Audit/dr-runbook.md`: restore the most recent `HoneyDrunk.Audit.Data` Azure SQL backup into an ephemeral environment, validate basic operations, tear the environment down, and log the outcome to `generated/restore-drills/` per the packet-02 schema. Any drill-surfaced procedure correction is fed back into the runbook.

## Context
ADR-0036 Consequences: Audit "gains restore drill at standup." ADR-0036 Follow-up Work mandates the first Vault and Audit drills within 90 days of acceptance. The Audit drill depends on the Vault drill (packet 05) having proven the Vault recovery path — ADR-0036 D6 and the recovery ordering (Vault → Data → Audit) mean Audit cannot be meaningfully restored until Vault is known-recoverable. It also depends on packet 07a having applied the T0 Azure SQL backup configuration — a drill against an unconfigured backing is not a meaningful proof.

This is **`Actor=Human`**: an operator-executed restore drill. Not delegable — provisioning an ephemeral environment, running the restore, validating, and judging the outcome are operator work. The `human-only` label is set. The user prefers Azure Portal walkthroughs; the drill steps are in the packet-06 runbook and should be portal-oriented.

## Scope
- An ephemeral environment — provisioned for the drill, torn down after.
- `generated/restore-drills/` — one new Audit drill-log entry per the packet-02 schema.
- `repos/HoneyDrunk.Audit/dr-runbook.md` — updated with any drill-surfaced procedure deltas.

## Proposed Work (human-executed)
1. Confirm packet 05 (Vault first drill) is complete with a `pass` outcome — the Vault recovery path must be proven before the Audit drill, per the Vault → Data → Audit ordering.
2. Confirm packet 07a is complete — the Audit.Data T0 Azure SQL backup configuration is applied.
3. Follow `repos/HoneyDrunk.Audit/dr-runbook.md` restore procedure: provision an ephemeral environment and restore the most recent `HoneyDrunk.Audit.Data` Azure SQL backup into it.
4. Validate basic operations: confirm `IAuditQuery` returns known entries and `IAuditLog` append still works on the restored store. Confirm the recovery ordering held (Vault and Data recoverable first).
5. Tear down the ephemeral environment.
6. Log the drill outcome to `generated/restore-drills/` per the packet-02 schema: `date`, `tier: T0`, `node: honeydrunk-audit`, `outcome` (pass/fail/partial), `runbook-deltas`, `operator`.
7. Apply any procedure deltas back into `repos/HoneyDrunk.Audit/dr-runbook.md`.

## Affected Files
- `generated/restore-drills/` — one new Audit drill-log entry (Markdown).
- `repos/HoneyDrunk.Audit/dr-runbook.md` — delta corrections, if any.

## NuGet Dependencies
None. This packet has no .NET project — it is an operator-executed drill plus a Markdown log entry.

## Boundary Check
- [x] The drill log lives in `generated/restore-drills/` per ADR-0036 D9; the runbook lives in `repos/HoneyDrunk.Audit/`. Correct locations.
- [x] No code change in any repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] The first Audit restore drill was executed against an ephemeral environment following the packet-06 runbook
- [ ] Validation confirmed `IAuditQuery` returns known entries and `IAuditLog` append works on the restored store
- [ ] A drill-log entry exists in `generated/restore-drills/` with all schema fields (`date`, `tier: T0`, `node: honeydrunk-audit`, `outcome`, `runbook-deltas`, `operator`)
- [ ] Any drill-surfaced procedure delta is applied back into the Audit runbook
- [ ] The ephemeral environment was torn down — no orphaned drill resources (cost discipline)
- [ ] If the drill outcome is `fail`/`partial`, a remediation note is recorded and the tier-affecting onboarding freeze is noted (ADR-0036 D3)

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] Azure Portal access to provision and tear down an ephemeral environment for the drill.
- [ ] Packet 05 (Vault first drill) confirmed complete with a `pass` outcome — the Vault recovery path must be proven before the Audit drill.
- [ ] Packet 07a confirmed complete — the Audit.Data T0 Azure SQL backup configuration is applied.
- [ ] Roughly half a working day budgeted (ADR-0036 Operational Consequences, annual T0 drill).

## Referenced ADR Decisions
**ADR-0036 D3 — Restore drills are the proof.** Restore the most recent backup into an ephemeral environment, validate, log to `generated/restore-drills/` with date, tier, Node, outcome, runbook deltas. A missed/failed drill is an incident — Tier-promotion freeze on the affected Node.

**ADR-0036 D1 — Tier 0 drill cadence.** Annual restore drill, semiannual partial-restore spot-check.

**ADR-0036 D6 / recovery ordering.** No other T0 drill can succeed until the Vault recovery path is proven; Audit recovers after Data, after Vault.

**ADR-0036 Follow-up Work.** "Schedule the first Vault and Audit drills within 90 days of this ADR's acceptance." This packet produces the initial Audit drill log entry.

**ADR-0036 Operational Consequences.** Annual T0 drill ≈ half a working day per Node; explicitly budgeted.

**ADR-0031 — Audit standup.** `HoneyDrunk.Audit.Data` is the Azure SQL-backed implementation; the drill restores its Azure SQL backup.

## Constraints
> **Invariant 61 (added by packet 00) — a missed restore drill freezes tier-affecting tenant onboarding for the affected Node.** A `fail`/`partial` Audit drill without remediation is treated as a missed drill — record the remediation note and the freeze status.

> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The drill-log entry records outcome and procedure deltas — never any secret or sensitive audit-record content.

- **Tear down the ephemeral environment** — leaving drill infrastructure running is unbudgeted cost; ADR-0036 D8's cost discipline applies.
- **The Audit drill runs after the Vault drill** — ADR-0036 recovery ordering (Vault → Data → Audit). Packet 05 must be complete first.

## Labels
`chore`, `tier-2`, `infrastructure`, `human-only`, `adr-0036`, `wave-4`

## Agent Handoff

**Objective:** Execute the first Audit T0 restore drill per the packet-06 runbook and log the outcome to `generated/restore-drills/`.

**Target:** Tracked against `HoneyDrunk.Audit`; the work is human-executed (operator runs the drill). `Actor=Human` — `human-only` label set.

**Context:**
- Goal: Prove the Audit restore runbook works end-to-end; produce the initial Audit drill log; satisfy the 90-day first-drill mandate.
- Feature: ADR-0036 Disaster Recovery rollout, Wave 4.
- ADRs: ADR-0036 (D3/D1/D6, Follow-up Work), ADR-0031 (Audit.Data backing — Azure SQL).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:05` — hard. The Vault first drill must be complete with a `pass` outcome — the Vault recovery path must be proven before the Audit drill (Vault → Data → Audit ordering).
- `work-item:07a` — hard. The Audit.Data T0 Azure SQL backup configuration must be applied before a meaningful drill can run.

**Constraints:**
- Tear down the ephemeral environment after the drill (cost discipline).
- The Audit drill runs after the Vault drill.
- A `fail`/`partial` outcome is an incident — record remediation and the onboarding-freeze status.

**Key Files:**
- `generated/restore-drills/` — one new Audit drill-log entry.
- `repos/HoneyDrunk.Audit/dr-runbook.md` — delta corrections, if any.

**Contracts:** None changed — operator drill + a Markdown log entry.
