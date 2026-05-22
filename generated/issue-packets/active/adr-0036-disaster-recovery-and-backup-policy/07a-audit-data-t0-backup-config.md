---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Audit
labels: ["chore", "tier-2", "infrastructure", "human-only", "adr-0036", "wave-3"]
dependencies: ["packet:06"]
adrs: ["ADR-0036", "ADR-0031"]
accepts: ["ADR-0036"]
wave: 3
initiative: adr-0036-disaster-recovery-and-backup-policy
node: honeydrunk-audit
---

# Apply Audit.Data T0 Azure SQL backup configuration (ADR-0036 D2)

## Summary
Apply the ADR-0036 D2 T0 Azure SQL backup configuration to the `HoneyDrunk.Audit.Data` backing via the Azure Portal — geo-redundant backup storage, weekly Long-Term Retention for 1 year, 35-day point-in-time-restore window. This is the human/portal work that puts Audit's T0 backup posture in place. It has no ordering dependency on the Vault drill — only the Audit runbook (packet 06) must exist so the configuration matches the documented procedure. The first Audit restore drill is the separate packet 07b.

## Context
ADR-0036 D2 sets the T0 backup mechanics for the Audit.Data backing. `HoneyDrunk.Audit.Data` is Data-backed — it persists over `HoneyDrunk.Data`'s `IRepository`/`IUnitOfWork`, and `HoneyDrunk.Data` ships EF Core + SQL Server providers — so the durable backing is **Azure SQL**. There is no Cosmos branch.

Applying the backup configuration is pure portal work against the Audit SQL backing; it does not require the Vault recovery path to be proven first. Only the *drill* (packet 07b) is hard-sequenced after the Vault drill per the Vault → Data → Audit recovery ordering. This packet is therefore Wave 3, blocked only on packet 06 (the Audit runbook must exist so the live config can be checked against it).

This is **`Actor=Human`**: Azure Portal configuration of database backup flags. Not delegable — there is no code artifact. The `human-only` label is set. The user prefers Azure Portal walkthroughs — the steps below are portal clicks.

## Scope
- The `HoneyDrunk.Audit.Data` Azure SQL backing resource — T0 backup configuration applied via the Azure Portal.
- `repos/HoneyDrunk.Audit/dr-runbook.md` — confirmation/delta note only if the live config surfaces a correction to the packet-06 runbook's backing-inventory section.

## Proposed Work (human-executed, Azure Portal)
1. **Apply T0 Azure SQL backup configuration to the Audit.Data backing.**
   - Portal → SQL database (the Audit.Data backing) → **Backups** / **Compute + storage** → set backup storage redundancy to **Geo-redundant**.
   - Portal → **Backups** → **Retention policies** → set Long-Term Retention to **weekly for 1 year** (T0).
   - Confirm the point-in-time-restore window is **35 days** (T0).
2. **Confirm diagnostic settings** route to the shared Log Analytics workspace if applicable (Portal → SQL database → **Diagnostic settings**).
3. **Confirm** the live configuration matches the packet-06 `repos/HoneyDrunk.Audit/dr-runbook.md` backing-inventory section; note any delta.

## Affected Files
- `repos/HoneyDrunk.Audit/dr-runbook.md` — confirmation/delta note only, if the live config surfaces a correction.

## NuGet Dependencies
None. This packet has no .NET project — it is Azure Portal configuration plus, at most, a one-line confirmation note in an existing Markdown file.

## Boundary Check
- [x] The Audit.Data backing's backup configuration belongs to the Audit Node's Azure resources. Correct ownership.
- [x] No code change in any repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] The Audit.Data Azure SQL backing has geo-redundant backup storage enabled
- [ ] Long-Term Retention is set to weekly for 1 year (T0); the point-in-time-restore window is confirmed at 35 days
- [ ] Diagnostic settings route to the shared Log Analytics workspace, if applicable
- [ ] The live configuration is confirmed to match the packet-06 Audit runbook's backing-inventory section; any delta is noted in `repos/HoneyDrunk.Audit/dr-runbook.md`

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] Azure Portal access to the `HoneyDrunk.Audit.Data` Azure SQL backing resource.

## Referenced ADR Decisions
**ADR-0036 D2 — Backup mechanics, Azure SQL.** Geo-redundant backup storage on; T0 LTR weekly for 1 year; PITR window 35 days. (Audit.Data is Azure SQL-backed; the Cosmos profile does not apply.)

**ADR-0031 — Audit standup.** `HoneyDrunk.Audit.Data` is the Data-backed implementation, persisting over `HoneyDrunk.Data`'s `IRepository`/`IUnitOfWork` — Azure SQL via the SQL Server provider.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** Any confirmation note records configuration state — never any secret or sensitive audit-record content.

- **The backing is Azure SQL** — apply the Azure SQL D2 mechanics only; there is no Cosmos branch.
- **No ordering dependency on the Vault drill** — this is the backup-configuration step; the drill (07b) carries the Vault → Data → Audit sequencing.

## Labels
`chore`, `tier-2`, `infrastructure`, `human-only`, `adr-0036`, `wave-3`

## Agent Handoff

**Objective:** Apply ADR-0036 D2 T0 Azure SQL backup configuration to the `HoneyDrunk.Audit.Data` backing via the Azure Portal.

**Target:** Tracked against `HoneyDrunk.Audit`; the work is human-executed (Azure Portal). `Actor=Human` — `human-only` label set.

**Context:**
- Goal: Put Audit's T0 backup posture in place — geo-redundant storage, weekly LTR, 35-day PITR.
- Feature: ADR-0036 Disaster Recovery rollout, Wave 3.
- ADRs: ADR-0036 (D2), ADR-0031 (Audit.Data backing — Azure SQL).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:06` — hard. The Audit runbook must exist so the live config can be checked against its backing-inventory section. No dependency on the Vault drill — this is the config step, not the drill.

**Constraints:**
- The backing is Azure SQL — apply the Azure SQL D2 mechanics only.
- No ordering dependency on the Vault drill.
- No secret values in any confirmation note (invariant 8).

**Key Files:**
- `repos/HoneyDrunk.Audit/dr-runbook.md` — confirmation/delta note only.

**Contracts:** None changed — Azure Portal configuration, no code.
