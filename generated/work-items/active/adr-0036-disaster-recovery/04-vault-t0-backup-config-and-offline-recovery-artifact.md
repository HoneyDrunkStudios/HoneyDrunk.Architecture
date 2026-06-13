---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Vault
labels: ["chore", "tier-2", "infrastructure", "human-only", "adr-0036", "wave-3"]
dependencies: ["work-item:03"]
adrs: ["ADR-0036", "ADR-0005", "ADR-0006"]
accepts: ["ADR-0036"]
wave: 3
initiative: adr-0036-disaster-recovery
node: honeydrunk-vault
---

# Apply Vault T0 backup configuration and create the offline bootstrap-recovery artifact (ADR-0036 D2/D6)

## Summary
Verify and apply the ADR-0036 D2 backup configuration on every Vault Key Vault via the Azure Portal — soft-delete on, purge protection on, geo-redundant posture — and create the D6 offline encrypted bootstrap-recovery artifact (encrypted USB or printed shares), recording its physical location and rotation procedure in `business/context/`. This is the human/portal work that makes the packet-03 Vault runbook executable.

## Context
ADR-0036 D6 requires the Vault bootstrap-recovery artifact — the encrypted offline copy — to exist **before any other T0 Node's first drill**, because no other T0 drill can succeed without Vault being recoverable. ADR-0036 D2 requires Azure Key Vault soft-delete and purge protection both on with a 90-day retention window, and cross-region replication (the Key Vault feature itself) for T0.

This is **`Actor=Human`**. The work is: Azure Portal configuration of Key Vault backup flags, and the creation of a physical-world encrypted artifact (USB or printed Shamir shares). Neither is delegable to an agent — there is no code artifact. The procedure document already exists (packet 03 authored `vault-bootstrap-recovery.md`); this packet executes it for the first time and provisions the artifact the procedure depends on. The `human-only` label is set.

The user prefers Azure Portal UI walkthroughs over CLI — the steps below are written as portal clicks.

## Scope
- Each environment's Vault Key Vault (`kv-hd-{service}-{env}` per ADR-0005) — backup configuration verified/applied via the Azure Portal.
- The offline encrypted bootstrap-recovery artifact — created (encrypted USB or printed Shamir shares).
- `business/context/` — a BDR-style record of the offline artifact's physical location and rotation procedure (in `HoneyDrunk.Architecture`, **not** in `repos/`).
- `repos/HoneyDrunk.Vault/integration-points.md` — confirm the backup posture is recorded (the runbook line landed in packet 03; this packet confirms the live config matches).

## Proposed Work (human-executed, Azure Portal)
1. **For each Vault Key Vault** (`kv-hd-vault-dev`, `-stg`, `-prod` or whatever the live names are):
   - Portal → Key Vault → **Properties** (or the vault's overview blade). Confirm **Soft-delete** is enabled. Soft-delete is on by default for new vaults and cannot be disabled; verify it is present.
   - Portal → Key Vault → **Properties** → enable **Purge protection** if not already on. Purge protection is irreversible once enabled — this is intended for a T0 vault.
   - Confirm the soft-delete **retention period** is set to **90 days** (ADR-0036 D2). The retention window is set at vault creation; if an existing vault is on a shorter window, note it — the window cannot be changed after creation, which may mean recreating the vault on the next maintenance window. Record any deviation.
2. **Geo-redundancy / cross-region:** Azure Key Vault contents are automatically replicated within the region and to the paired region by the service — no portal toggle. **First confirm the vault's region actually has an Azure-defined paired region** — not every Azure region has one (some newer single-region geographies do not). Check Portal → the region's metadata, or the Azure "Cross-region replication / region pairs" documentation, before relying on geo-replication. If the region **has** a pair: document the paired region in the packet-03 runbook's failover section; the read-access-from-secondary expectation (D1) is satisfied by Key Vault's built-in regional failover and no additional resource is provisioned. If the region **has no pair**: record this as a deviation — geo-replication cannot be relied on, and the runbook's failover section must note that recovery falls back to the offline bootstrap-recovery artifact + soft-deleted-secret recovery. Surface the no-pair case to the operator before treating Vault's T0 geo posture as satisfied.
3. **Diagnostic settings:** confirm each Key Vault routes diagnostic settings to the shared Log Analytics workspace (invariant 22) — Portal → Key Vault → **Diagnostic settings**. If absent, add it (this also supports the rotation-SLA monitoring from ADR-0006).
4. **Create the offline bootstrap-recovery artifact** per the packet-03 `vault-bootstrap-recovery.md` procedure: capture the minimum material to re-bootstrap a Key Vault and re-establish RBAC/OIDC access onto an encrypted USB drive, or as printed Shamir secret shares. Encrypt it. This is the artifact ADR-0036 D6 requires to exist before any other T0 drill.
5. **Record the artifact's location in `business/context/`** — a short BDR-style record: what the artifact is, where it physically lives, who can access it, and the rotation procedure (re-create the artifact whenever the underlying recovery material changes). Do **not** record this in `repos/` — the repo is itself a recovery dependency (ADR-0036 D6).
6. **Confirm** `repos/HoneyDrunk.Vault/integration-points.md` and the packet-03 runbook accurately reflect the live backup posture; note any deltas.

## Affected Files
- `business/context/` — one new BDR-style record (Markdown) for the offline recovery artifact.
- `repos/HoneyDrunk.Vault/integration-points.md` — confirmation/delta note only (the substantive content landed in packet 03).

## NuGet Dependencies
None. This packet has no .NET project — it is Azure Portal configuration plus a physical-world artifact plus one Markdown record.

## Boundary Check
- [x] The Key Vault backup configuration belongs to the Vault Node's Azure resources — Vault is the only source of secrets (invariant 9). Correct ownership.
- [x] No code change in any repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] Every Vault Key Vault has soft-delete confirmed enabled and purge protection enabled
- [ ] Each vault's soft-delete retention is 90 days, or any deviation is recorded with a remediation note
- [ ] Each vault's region was checked for an Azure-defined paired region; if a pair exists it is recorded in the packet-03 runbook's failover section; if no pair exists the deviation is recorded and the offline-artifact fallback is noted in the runbook
- [ ] Every Vault Key Vault routes diagnostic settings to the shared Log Analytics workspace (invariant 22)
- [ ] The offline encrypted bootstrap-recovery artifact is created (encrypted USB or printed Shamir shares) per the packet-03 procedure
- [ ] A BDR-style record in `business/context/` documents the artifact's physical location, access, and rotation procedure
- [ ] The offline artifact and its location record are NOT committed to any `repos/` directory or any code repo
- [ ] `repos/HoneyDrunk.Vault/integration-points.md` confirms the live backup posture matches the runbook; deltas (if any) noted
- [ ] No secret values appear in the `business/context/` record (invariant 8) — it records location and procedure, not material

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] Azure Portal access to every Vault Key Vault.
- [ ] A physical medium for the offline artifact (encrypted USB drive) or a means to print Shamir shares, and a secure physical storage location for it.
- [ ] Purge protection enablement is irreversible — confirm intent before clicking.

## Referenced ADR Decisions
**ADR-0036 D2 — Backup mechanics, Azure Key Vault.** Soft-delete and purge protection both on. Retention window 90 days. Cross-region replication is the Key Vault feature itself.

**ADR-0036 D6 — Vault has a bootstrap-recovery procedure.** The recovery procedure (separate runbook, encrypted offline copy) must exist before any other T0 Node's first drill. The Vault bootstrap-recovery offline copy is the only DR artifact that lives outside the GitHub-hosted Architecture repo — its location and rotation procedure are recorded in `business/context/` per the BDR record, not in the repo, because the repo is itself a recovery dependency.

**ADR-0036 Follow-up Work.** "Author Vault bootstrap-recovery procedure (D6) before any other Tier 0 drill." "Schedule the first Vault and Audit drills within 90 days of this ADR's acceptance" — packet 05 runs the Vault drill; this packet provisions the artifact those drills depend on.

**ADR-0006 / Invariant 22 — Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace.**

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The `business/context/` record names the artifact's location and rotation procedure — never its contents.

> **Invariant 22 — Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace.** Confirm this for every Vault Key Vault as part of the backup-posture verification.

> **Invariant 9 — Vault is the only source of secrets.** The recovery material stays in Vault / the offline encrypted artifact — never on a developer laptop unencrypted, never in the repo.

- **The offline artifact and its location record never enter a code repo or `repos/`** — ADR-0036 D6: the repo is itself a recovery dependency. `business/context/` (Architecture repo, but the operator's BDR area) is the recorded home for the *location pointer*; the artifact itself is physical.
- **This packet must complete before any other T0 drill** — ADR-0036 D6. Packet 05 (Vault drill) and packet 07b (Audit drill) are downstream of this one.
- **Purge protection is irreversible** — once enabled it cannot be turned off for the life of the vault; this is intended for T0.

## Labels
`chore`, `tier-2`, `infrastructure`, `human-only`, `adr-0036`, `wave-3`

## Agent Handoff

**Objective:** Apply ADR-0036 D2 backup configuration to every Vault Key Vault and create the D6 offline encrypted bootstrap-recovery artifact, recording its location in `business/context/`.

**Target:** Tracked against `HoneyDrunk.Vault`; the work is human-executed (Azure Portal + a physical artifact). `Actor=Human` — `human-only` label set.

**Context:**
- Goal: Make the packet-03 Vault runbook and bootstrap-recovery procedure executable; satisfy the ADR-0036 D6 precondition that gates every other T0 drill.
- Feature: ADR-0036 Disaster Recovery rollout, Wave 3.
- ADRs: ADR-0036 (D2/D6 primary), ADR-0005 (per-Node Key Vault), ADR-0006 (diagnostics + rotation).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:03` — hard. The `vault-bootstrap-recovery.md` procedure must exist; this packet executes it and provisions the artifact it depends on.

**Constraints:**
- The offline artifact and its location record never enter a code repo or `repos/`.
- Purge protection is irreversible — confirm intent.
- This packet gates every other T0 drill (ADR-0036 D6).
- No secret values in the `business/context/` record (invariant 8).

**Key Files:**
- `business/context/` — one new BDR-style record (the only repo artifact).
- `repos/HoneyDrunk.Vault/integration-points.md` — confirmation/delta note.

**Contracts:** None changed — Azure Portal configuration + a physical artifact, no code.
