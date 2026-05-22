---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "infrastructure", "docs", "adr-0036", "wave-2"]
dependencies: ["packet:01", "packet:02"]
adrs: ["ADR-0036", "ADR-0005", "ADR-0006"]
accepts: ["ADR-0036"]
wave: 2
initiative: adr-0036-disaster-recovery
node: honeydrunk-vault
---

# Author the Vault T0 dr-runbook and the bootstrap-recovery procedure (ADR-0036 D2/D4/D6)

## Summary
Author `repos/HoneyDrunk.Vault/dr-runbook.md` from the packet-02 template — Vault as a T0 Node — and author the Vault bootstrap-recovery procedure (ADR-0036 D6): the special-case recovery path that every other Node's DR depends on. The bootstrap-recovery *procedure document* lives in the repo; the *offline encrypted copy of the recovery material* is a separate physical-world artifact provisioned by the human packet 04.

## Context
ADR-0036 D6 makes Vault recovery the special case: "every other Node's DR depends on Vault being readable. The recovery procedure (separate runbook, encrypted offline copy) must exist before any other Tier 0 Node's first drill, because no other Tier 0 drill can succeed without it." Vault is T0 (D1) — RPO ≤ 5 min, RTO ≤ 1 hr, geo-redundant with read-access secondary, annual drill plus semiannual partial spot-check.

ADR-0036 D2 specifies the Vault backup mechanics: Azure Key Vault soft-delete and purge protection both **on**, 90-day retention window; Vault contents exportable via the Vault Node's restore tooling (per ADR-0006); cross-region replication is the Key Vault feature itself.

This packet authors the **documentation** — the runbook and the bootstrap-recovery procedure. It is tracked against the Vault Node but the files live in `HoneyDrunk.Vault/`'s context directory inside `HoneyDrunk.Architecture` (the `repos/{name}/` model directory), so the target repo is `HoneyDrunk.Architecture`. No code, no .NET project. The Azure portal configuration that the runbook *describes* (soft-delete, purge protection, geo posture) is verified/applied by the human packet 04; the offline encrypted recovery copy is also packet 04.

## Scope
- `repos/HoneyDrunk.Vault/dr-runbook.md` (new) — the Vault T0 runbook, from the packet-02 template.
- `repos/HoneyDrunk.Vault/vault-bootstrap-recovery.md` (new) — the D6 bootstrap-recovery procedure.
- `repos/HoneyDrunk.Vault/integration-points.md` — add the cross-Node recovery-ordering line (Vault recovers first; every other T0 Node's drill depends on it).

## Proposed Implementation
1. **Author `dr-runbook.md`** from the packet-02 template at `generated/dr-runbook.template.md`, filled for Vault:
   - Tier: T0. RPO ≤ 5 min, RTO ≤ 1 hr, geo-redundant storage with read-access secondary region, annual restore drill + semiannual partial-restore spot-check.
   - Tier rationale: loss of secrets cascades to every Node (ADR-0036 D1).
   - Backing inventory: the per-environment Azure Key Vaults (`kv-hd-{service}-{env}` per ADR-0005 invariant 17). Backup config per ADR-0036 D2: soft-delete **on**, purge protection **on**, 90-day retention.
   - Restore procedure: restore the most recent Key Vault backup / recover soft-deleted secrets into an ephemeral environment; validate `ISecretStore` resolves a known secret. Reference the Vault Node's own restore tooling (ADR-0006).
   - Failover procedure: manual cross-region failover steps — Key Vault's own cross-region replication is the mechanism (D2); operator triggers per D4.
   - Tenant-scoped restore: Vault uses the `tenant-{tenantId}-{secretName}` convention (invariant 9a); document restoring a single tenant's secrets without touching others.
   - Cross-Node ordering: Vault recovers **first** — point to `integration-points.md`.
   - Drill cadence + last-drill record: annual + semiannual spot-check; a line linking to `generated/restore-drills/`.
2. **Author `vault-bootstrap-recovery.md`** — the D6 procedure:
   - The recovery scenario: the GitHub-hosted Architecture repo is itself a recovery dependency, so this procedure must be runnable from an offline copy.
   - What the offline encrypted artifact contains (the minimum material to re-bootstrap a Key Vault and re-establish RBAC/OIDC access) — described generically; the artifact itself is provisioned by packet 04.
   - The step-by-step recovery: from the offline copy, re-create the Key Vault, restore secrets, re-establish access, and validate.
   - A pointer to `business/context/` for the offline copy's physical location and rotation procedure (recorded there per ADR-0036's BDR record, **not** in the repo — the repo is a recovery dependency).
3. **Update `integration-points.md`** with the recovery-ordering line: Vault recovers first; Audit and other T0 Nodes' drills cannot succeed until Vault is readable.

## Affected Files
- `repos/HoneyDrunk.Vault/dr-runbook.md` (new)
- `repos/HoneyDrunk.Vault/vault-bootstrap-recovery.md` (new)
- `repos/HoneyDrunk.Vault/integration-points.md`

## NuGet Dependencies
None. This packet touches only Markdown docs; no .NET project is created or modified.

## Boundary Check
- [x] `repos/HoneyDrunk.Vault/` is the Vault Node's context directory inside `HoneyDrunk.Architecture` — correct location for architecture-side runbook docs per ADR-0036 D9.
- [x] No code change in any repo — the Vault Node's restore tooling already exists per ADR-0006; this packet documents the recovery procedure that uses it.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `repos/HoneyDrunk.Vault/dr-runbook.md` exists, follows the packet-02 template, and records Vault as T0 with the correct RPO/RTO/geo/cadence
- [ ] The runbook's backing inventory names the per-environment `kv-hd-{service}-{env}` Key Vaults and the D2 backup config (soft-delete on, purge protection on, 90-day retention)
- [ ] The runbook has a restore procedure, a manual failover procedure, and a tenant-scoped restore path (`tenant-{tenantId}-{secretName}`)
- [ ] `repos/HoneyDrunk.Vault/vault-bootstrap-recovery.md` exists with the full D6 bootstrap-recovery procedure and a pointer to `business/context/` for the offline copy's location
- [ ] `integration-points.md` records the recovery-ordering line — Vault recovers first
- [ ] No secret values appear anywhere in the runbook or the bootstrap-recovery doc (invariant 8)
- [ ] The bootstrap-recovery doc explicitly states the offline encrypted copy is NOT stored in the repo, and that its location lives in `business/context/`

## Human Prerequisites
- [ ] None for authoring the documentation. **Note for the operator:** the offline encrypted recovery artifact and the Azure portal backup-configuration verification this runbook *describes* are provisioned by packet 04 (`Actor=Human`). This packet writes the procedure; packet 04 makes the procedure executable. Packet 04 is hard-blocked on this packet.

## Referenced ADR Decisions
**ADR-0036 D2 — Backup mechanics, Azure Key Vault.** Soft-delete and purge protection both on. Retention window 90 days. Vault contents are exportable via the Vault Node's restore tooling (per ADR-0006); cross-region replication is the Key Vault feature itself.

**ADR-0036 D4 — Cross-region failover is a documented runbook, not automated failover.** T0 Nodes have read-access secondary regions and the mechanism to fail over; failover is manually triggered by the Studio operator per `repos/{name}/dr-runbook.md`. Automated failover is not adopted at solo-developer scale — spurious failover is a worse failure mode.

**ADR-0036 D6 — Vault has a bootstrap-recovery procedure.** Vault recovery is the special case because every other Node's DR depends on Vault being readable. The recovery procedure (separate runbook, encrypted offline copy) must exist before any other T0 Node's first drill. The offline encrypted recovery copy is the only DR artifact that lives outside the GitHub-hosted Architecture repo; its location is recorded in `business/context/`.

**ADR-0005 — per-Node Key Vault.** One Key Vault per deployable Node per environment, `kv-hd-{service}-{env}`, Azure RBAC enabled.

**ADR-0006 — secret rotation and lifecycle.** The Vault Node's restore tooling and the secret lifecycle this runbook's restore procedure invokes.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** No secret value is written into the runbook or bootstrap-recovery doc. Only secret names/identifiers and procedure steps.

> **Invariant 17 — One Key Vault per deployable Node per environment, `kv-hd-{service}-{env}`, Azure RBAC enabled.** The runbook's backing inventory names the vaults by this convention.

> **Invariant 9a — Tenant-scoped secrets use `tenant-{tenantId}-{secretName}`.** The tenant-scoped restore path documents restoring one tenant's secrets at this path prefix without touching others.

- **The offline encrypted copy never lands in the repo.** ADR-0036 D6: the repo is itself a recovery dependency. The doc points to `business/context/`; it does not embed the recovery material.
- **This packet is the hard prerequisite for packet 04 and for every other T0 drill** — ADR-0036 D6 says the Vault bootstrap-recovery procedure must exist before any other T0 Node's first drill.

## Labels
`feature`, `tier-2`, `infrastructure`, `docs`, `adr-0036`, `wave-2`

## Agent Handoff

**Objective:** Author the Vault T0 `dr-runbook.md` and the `vault-bootstrap-recovery.md` D6 procedure; add the recovery-ordering line to `integration-points.md`.

**Target:** `HoneyDrunk.Architecture` (the `repos/HoneyDrunk.Vault/` context directory), branch from `main`. Tracked against the Vault Node.

**Context:**
- Goal: Produce the Vault DR documentation — the runbook and the special-case bootstrap-recovery procedure that gates every other T0 drill.
- Feature: ADR-0036 Disaster Recovery rollout, Wave 2.
- ADRs: ADR-0036 (D2/D4/D6 primary), ADR-0005 (per-Node Key Vault), ADR-0006 (Vault restore tooling, secret lifecycle).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — soft. The `dr_tier` field should exist so the runbook's tier reference is consistent with the catalog.
- `packet:02` — hard. The template at `generated/dr-runbook.template.md` must exist; this packet fills it in.

**Constraints:**
- No secret values in any doc (invariant 8).
- The offline encrypted recovery copy is never stored in the repo (ADR-0036 D6) — point to `business/context/`.
- This packet is the hard prerequisite for packet 04 and gates every other T0 drill.

**Key Files:**
- `repos/HoneyDrunk.Vault/dr-runbook.md` (new)
- `repos/HoneyDrunk.Vault/vault-bootstrap-recovery.md` (new)
- `repos/HoneyDrunk.Vault/integration-points.md`

**Contracts:** None changed — documentation only. The Vault restore tooling (ADR-0006) already exists.
