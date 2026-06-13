# Handoff: Wave 3 → Wave 4 (backup configuration in place → execute the restore drills)

**Read once at the Wave 3 → Wave 4 transition.** This is an ephemeral baton pass, not a live tracker. Immutable per invariant 24. This handoff is addressed primarily to the **Studio operator** — Wave 4 is human-executed work.

## What Waves 1–3 delivered (upstream state Wave 4 depends on)

- **The DR policy is live** — ADR-0036 Accepted, the two DR invariants in force, `dr_tier` on every Node in `grid-health.json` (packet 00, 01).
- **The runbooks exist** — `repos/HoneyDrunk.Vault/dr-runbook.md` + `vault-bootstrap-recovery.md` (packet 03), `repos/HoneyDrunk.Audit/dr-runbook.md` (packet 06). These are the step-by-step procedures Wave 4 executes. `generated/restore-drills/` and its drill-log schema exist (packet 02).
- **Vault T0 backup configuration is applied and the offline recovery artifact exists** (packet 04, `Actor=Human`). Every Vault Key Vault has soft-delete + purge protection on, 90-day retention, diagnostics to Log Analytics. The offline encrypted bootstrap-recovery artifact (encrypted USB or printed Shamir shares) exists; its physical location and rotation procedure are recorded in `business/context/`.
- **Audit.Data T0 Azure SQL backup configuration is applied** (packet 07a, `Actor=Human`, Wave 3). The `HoneyDrunk.Audit.Data` Azure SQL backing has geo-redundant backup storage, weekly LTR for 1 year, and a 35-day PITR window. `Audit.Data` is Data-backed over `HoneyDrunk.Data`'s SQL Server provider — the backing is Azure SQL, single-branch, no Cosmos fork.
- **`hive-sync` reconciles DR state** (packet 09). It now flags a stateful Node missing a `dr_tier` and a Node whose most recent `generated/restore-drills/` entry is overdue per its tier cadence — surfacing both as board-item drift findings, and flagging the tenant-onboarding freeze for an overdue drill. The overdue grace window is anchored to ADR-0036's accepted-date read from the ADR header at runtime.

## Wave 4 objectives — the two first restore drills

ADR-0036 Follow-up Work mandates the first Vault and Audit drills **within 90 days of ADR-0036's acceptance**. Wave 4 is those two drills. Both are `Actor=Human`.

1. **Packet 05 — First Vault T0 restore drill.** Follow `repos/HoneyDrunk.Vault/dr-runbook.md`: provision an ephemeral environment, restore the most recent Vault Key Vault backup into it (recover soft-deleted secrets / restore from the geo-replicated copy), validate `ISecretStore` resolves a known secret and a tenant-scoped secret restores correctly, optionally exercise the `vault-bootstrap-recovery.md` procedure as the semiannual partial-restore spot-check, tear down the ephemeral environment, and log the outcome to `generated/restore-drills/`. Budget ~half a working day (ADR-0036 Operational Consequences).
2. **Packet 07b — first Audit T0 restore drill.** The Audit.Data T0 Azure SQL backup configuration was already applied in Wave 3 (packet 07a). Follow `repos/HoneyDrunk.Audit/dr-runbook.md`: provision an ephemeral environment, restore the most recent Audit.Data Azure SQL backup, validate `IAuditQuery` returns known entries and `IAuditLog` append works on the restored store, tear down, and log the outcome.

## Hard sequencing — the Vault drill goes first

**Packet 07b's Audit drill is hard-blocked on packet 05's Vault drill** (and on packet 07a's Audit backup config, completed in Wave 3). ADR-0036 D6 and the recovery ordering `Vault → Data → Audit` mean an Audit restore cannot be meaningfully validated until the Vault recovery path is proven. Run packet 05 to completion — with a `pass` outcome — before starting packet 07b's drill. The old single packet 07 (which bundled the backup config with the drill) was split: the config has no Vault-drill dependency and ran in Wave 3 (07a); the drill carries the ordering and runs in Wave 4 (07b).

## Constraints carried into Wave 4

> **Invariant 61 (packet 00) — a missed restore drill freezes tier-affecting tenant onboarding for the affected Node.** If a drill outcome is `fail` or `partial`, record a remediation note and treat it as a missed drill — the affected Node's tier-affecting tenant onboarding is frozen until the drill passes. `hive-sync` (packet 09) will surface this.

> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The drill-log entries record outcome and procedure deltas — never any secret value or sensitive audit-record content resolved during validation.

- **Tear down every ephemeral environment.** Leaving drill infrastructure running is unbudgeted cost — ADR-0036 D8's cost discipline applies. Each drill packet ends with teardown.
- **Log every drill, pass or fail.** The drill-log entry in `generated/restore-drills/` (schema: `date`, `tier`, `node`, `outcome`, `runbook-deltas`, `operator`) is the proof the drill happened. `hive-sync` reads it; a Node with no log past the 90-day grace window is drift.
- **Feed deltas back into the runbook.** Any procedure correction discovered during a drill is applied back into the relevant `dr-runbook.md` (and `vault-bootstrap-recovery.md` if the Vault spot-check surfaced one). A drill that improves the runbook is a successful drill.
- **The Audit drill follows the Vault drill** — non-negotiable per the recovery ordering.

## Acceptance signal for Wave 4 completion

The first Vault drill is executed with a recorded outcome; a `tier: T0, node: honeydrunk-vault` entry exists in `generated/restore-drills/`. The first Audit drill is executed with a recorded outcome; a `tier: T0, node: honeydrunk-audit` entry exists in `generated/restore-drills/`. (The Audit.Data T0 Azure SQL backup configuration was completed in Wave 3, packet 07a.) Any drill-surfaced procedure deltas are applied back into the runbooks. Both drills landed within ADR-0036's 90-day-from-acceptance mandate, or the slip is recorded. Once both drill packets (05, 07b) are `Done` — and all Wave 1–3 packets including 07a — the initiative meets its archival gate (ADR-0008 D10) and the folder moves to `archive/`.
