---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Vault
labels: ["chore", "tier-2", "infrastructure", "human-only", "adr-0036", "wave-4"]
dependencies: ["work-item:04"]
adrs: ["ADR-0036"]
accepts: ["ADR-0036"]
wave: 4
initiative: adr-0036-disaster-recovery
node: honeydrunk-vault
---

# Execute the first Vault T0 restore drill and log the outcome (ADR-0036 D3)

## Summary
Execute the first Vault restore drill following `repos/HoneyDrunk.Vault/dr-runbook.md`: restore the most recent Key Vault backup into an ephemeral environment, validate basic operations, and log the outcome to `generated/restore-drills/` per the packet-02 schema. Any procedure correction discovered during the drill is fed back into the runbook.

## Context
ADR-0036 D3: "A backup not test-restored is a backup not known to work." ADR-0036 Follow-up Work mandates "Schedule the first Vault and Audit drills within 90 days of this ADR's acceptance." The Vault drill must run first — ADR-0036 D6 says no other T0 drill can succeed until the Vault bootstrap-recovery procedure exists and is proven. Packet 04 created the offline recovery artifact; this packet runs the drill that proves the Vault runbook works end-to-end.

This is **`Actor=Human`**. Executing a restore drill is operator work — provisioning an ephemeral environment, running the restore, validating, and judging the outcome. ADR-0036's Operational Consequences budget an annual T0 drill at roughly half a working day. The `human-only` label is set. The user prefers Azure Portal walkthroughs; the drill steps are in the packet-03 runbook and should be portal-oriented.

## Scope
- An ephemeral environment — provisioned for the drill, torn down after.
- `generated/restore-drills/` — one new drill-log entry per the packet-02 schema.
- `repos/HoneyDrunk.Vault/dr-runbook.md` — updated with any procedure deltas the drill surfaced.

## Proposed Work (human-executed)
1. Confirm packet 04 is complete — the offline bootstrap-recovery artifact exists and the backup configuration is applied.
2. Follow `repos/HoneyDrunk.Vault/dr-runbook.md` restore procedure: provision an ephemeral environment and restore the most recent Vault Key Vault backup (recover soft-deleted secrets / restore from the geo-replicated copy) into it.
3. Validate basic operations: confirm `ISecretStore` resolves a known secret from the restored vault; confirm a tenant-scoped secret (`tenant-{tenantId}-{secretName}`) restores correctly per the runbook's tenant-scoped restore path.
4. Optionally exercise the `vault-bootstrap-recovery.md` procedure as a partial-restore spot-check (the semiannual T0 spot-check from D1) — at minimum confirm the offline artifact is readable and the procedure's first steps are accurate.
5. Tear down the ephemeral environment.
6. Log the drill outcome to `generated/restore-drills/` per the packet-02 schema: `date`, `tier: T0`, `node: honeydrunk-vault`, `outcome` (pass/fail/partial), `runbook-deltas`, `operator`.
7. Apply any procedure corrections discovered during the drill back into `repos/HoneyDrunk.Vault/dr-runbook.md` (and `vault-bootstrap-recovery.md` if the spot-check surfaced a delta).

## Affected Files
- `generated/restore-drills/` — one new drill-log entry (Markdown).
- `repos/HoneyDrunk.Vault/dr-runbook.md` — delta corrections, if any.
- `repos/HoneyDrunk.Vault/vault-bootstrap-recovery.md` — delta corrections, if the spot-check surfaced any.

## NuGet Dependencies
None. This packet has no .NET project — it is an operator-executed drill plus a Markdown log entry.

## Boundary Check
- [x] The drill log lives in `generated/restore-drills/` per ADR-0036 D9; the runbook lives in `repos/HoneyDrunk.Vault/`. Correct locations.
- [x] No code change in any repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] The Vault restore drill was executed against an ephemeral environment following the packet-03 runbook
- [ ] Basic operations were validated — `ISecretStore` resolved a known secret; a tenant-scoped secret restored correctly
- [ ] A drill-log entry exists in `generated/restore-drills/` with all schema fields (`date`, `tier: T0`, `node: honeydrunk-vault`, `outcome`, `runbook-deltas`, `operator`)
- [ ] Any procedure delta discovered during the drill is applied back into the Vault runbook (and bootstrap-recovery doc if relevant)
- [ ] The ephemeral environment was torn down — no orphaned drill resources left running (cost discipline)
- [ ] If the drill outcome is `fail` or `partial`, a remediation note is recorded — a missed/failed drill is an incident per ADR-0036 D3 and freezes tier-affecting tenant onboarding until resolved

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] Azure Portal access to provision and tear down an ephemeral environment for the drill.
- [ ] Packet 04 confirmed complete (the offline recovery artifact exists; backup config applied).
- [ ] Roughly half a working day budgeted (ADR-0036 Operational Consequences).

## Referenced ADR Decisions
**ADR-0036 D3 — Restore drills are the proof.** Restore the most recent backup into an ephemeral environment and validate basic operations. Results logged to `generated/restore-drills/` with date, tier, Node, outcome, runbook deltas. A missed drill is an incident — Tier-promotion freeze on the affected Node.

**ADR-0036 D1 — Tier 0 drill cadence.** Annual restore drill, semiannual partial-restore spot-check.

**ADR-0036 D6.** No other T0 drill can succeed until the Vault bootstrap-recovery procedure exists and is proven — the Vault drill goes first.

**ADR-0036 Follow-up Work.** "Schedule the first Vault and Audit drills within 90 days of this ADR's acceptance." "Add `generated/restore-drills/` and an initial drill log for Vault" — this packet produces that initial Vault log entry.

**ADR-0036 Operational Consequences.** Annual T0 drill ≈ half a working day per Node; explicitly budgeted.

## Constraints
> **Invariant 61 (added by packet 00) — a missed restore drill freezes tier-affecting tenant onboarding for the affected Node.** A `fail`/`partial` outcome without remediation is treated as a missed drill — record the remediation note and the freeze status.

> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The drill-log entry records outcome and procedure deltas — never any secret value resolved during validation.

- **Tear down the ephemeral environment** — leaving drill infrastructure running is unbudgeted cost; ADR-0036 D8's cost discipline applies.
- **The Vault drill goes first** — ADR-0036 D6. Packet 07b's Audit drill depends on this drill having proven the Vault recovery path.

## Labels
`chore`, `tier-2`, `infrastructure`, `human-only`, `adr-0036`, `wave-4`

## Agent Handoff

**Objective:** Execute the first Vault T0 restore drill per the packet-03 runbook and log the outcome to `generated/restore-drills/`.

**Target:** Tracked against `HoneyDrunk.Vault`; the work is human-executed (operator runs the drill). `Actor=Human` — `human-only` label set.

**Context:**
- Goal: Prove the Vault restore runbook works end-to-end; produce the initial Vault drill log; satisfy the 90-day first-drill mandate.
- Feature: ADR-0036 Disaster Recovery rollout, Wave 4.
- ADRs: ADR-0036 (D3/D1/D6, Follow-up Work).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:04` — hard. The offline recovery artifact must exist and the backup config must be applied before a meaningful drill can run.

**Constraints:**
- Tear down the ephemeral environment after the drill (cost discipline).
- The Vault drill goes first — it gates packet 07b's Audit drill.
- A `fail`/`partial` outcome is an incident — record remediation and the onboarding-freeze status.

**Key Files:**
- `generated/restore-drills/` — one new drill-log entry.
- `repos/HoneyDrunk.Vault/dr-runbook.md` — delta corrections, if any.

**Contracts:** None changed — operator drill + a Markdown log entry.
