---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "infrastructure", "docs", "adr-0036", "wave-2"]
dependencies: ["packet:01", "packet:02"]
adrs: ["ADR-0036", "ADR-0030", "ADR-0031"]
accepts: ["ADR-0036"]
wave: 2
initiative: adr-0036-disaster-recovery
node: honeydrunk-audit
---

# Author the Audit T0 dr-runbook with the Data tier-inheritance and recovery-ordering rules (ADR-0036 D1/D2)

## Summary
Author `repos/HoneyDrunk.Audit/dr-runbook.md` from the packet-02 template — Audit as a T0 Node — and record the Data-Node tier-inheritance rule (`Audit.Data → T0`) and the cross-Node recovery ordering (Audit recovers after Data, Data after Vault) in `repos/HoneyDrunk.Audit/integration-points.md`.

## Context
ADR-0036 D1 places Audit at T0: "regulatory/forensic value scales with completeness." ADR-0036 Consequences is explicit that Audit "gains restore drill at standup" and that "the 'ADR-0030 Phase 2 hash-chain/WORM' deferral is decoupled from this ADR; durability comes from this ADR even before tamper-evidence lands." Audit's durability story — undefined in ADR-0030 Phase 1, which scoped only "append-only-by-interface" — is the secondary forcing function for ADR-0036.

Audit's backing is `HoneyDrunk.Audit.Data` (ADR-0031), which `HoneyDrunk.Audit`'s overview states is **Data-backed** — it persists "over `HoneyDrunk.Data`'s `IRepository`/`IUnitOfWork`" and is published at v0.1.0. `HoneyDrunk.Data` provides EF Core and SQL Server implementations (`HoneyDrunk.Data.EntityFramework`, `HoneyDrunk.Data.SqlServer`). The concrete durable backing for `Audit.Data` is therefore **Azure SQL** — there is no Cosmos branch to resolve. ADR-0036's Data tier-inheritance rule means `Audit.Data` inherits Audit's T0 tier, so the Audit SQL backing runs T0 Azure SQL backup mechanics (D2). Recovery has cross-Node ordering: Audit must come up after Data, Data after Vault (ADR-0036 D9 names exactly this example).

This packet authors the **documentation**. It is tracked against the Audit Node but the files live in `repos/HoneyDrunk.Audit/` inside `HoneyDrunk.Architecture`, so the target repo is `HoneyDrunk.Architecture`. No code, no .NET project. The Azure portal backup configuration the runbook describes is applied by packet 07a.

## Scope
- `repos/HoneyDrunk.Audit/dr-runbook.md` (new) — the Audit T0 runbook, from the packet-02 template.
- `repos/HoneyDrunk.Audit/integration-points.md` — add the Data tier-inheritance line and the cross-Node recovery-ordering line.

## Proposed Implementation
1. **Author `dr-runbook.md`** from the packet-02 template at `generated/dr-runbook.template.md`, filled for Audit:
   - Tier: T0. RPO ≤ 5 min, RTO ≤ 1 hr, geo-redundant storage with read-access secondary region, annual restore drill + semiannual partial-restore spot-check.
   - Tier rationale: a security/forensic audit log's regulatory value scales with completeness; an audit log with undefined durability carries an unjustified trust premium (ADR-0036 Context).
   - Backing inventory: the `HoneyDrunk.Audit.Data` backing store. `Audit.Data` is Data-backed over `HoneyDrunk.Data`'s `IRepository`/`IUnitOfWork`; `HoneyDrunk.Data` ships EF Core + SQL Server providers, so the live durable backing is **Azure SQL**. Record the T0 Azure SQL D2 mechanics: geo-redundant backup storage on; Long-Term Retention T0 = weekly for 1 year; point-in-time-restore window 35 days. There is no Cosmos branch — Audit.Data is SQL-backed.
   - Restore procedure: restore the most recent Audit.Data Azure SQL backup into an ephemeral environment; validate `IAuditQuery` returns known entries and that `IAuditLog` append still works on the restored store.
   - Failover procedure: manual cross-region failover steps for the T0 backing (D4).
   - Tenant-scoped restore: if Audit holds per-tenant audit records, document the tenant-scoped restore path (D5); if Audit is internal-only at this stage, state "not currently multi-tenant — revisit when tenant-scoped audit records materialize."
   - Cross-Node ordering: Audit recovers **after Data, after Vault** — point to `integration-points.md`.
   - Drill cadence + last-drill record: annual + semiannual spot-check; a line linking to `generated/restore-drills/`.
2. **Update `integration-points.md`:**
   - The Data tier-inheritance rule: `HoneyDrunk.Audit.Data` inherits Audit's T0 tier — the Audit backing runs T0 backup mechanics.
   - The recovery-ordering line: Audit recovers after Data, Data after Vault. An Audit restore drill cannot succeed until Vault and Data are recoverable.

## Affected Files
- `repos/HoneyDrunk.Audit/dr-runbook.md` (new)
- `repos/HoneyDrunk.Audit/integration-points.md`

## NuGet Dependencies
None. This packet touches only Markdown docs; no .NET project is created or modified.

## Boundary Check
- [x] `repos/HoneyDrunk.Audit/` is the Audit Node's context directory inside `HoneyDrunk.Architecture` — correct location for architecture-side runbook docs per ADR-0036 D9.
- [x] No code change in any repo.
- [x] No new cross-Node runtime dependency — Audit→Data and Audit→Kernel edges already exist per ADR-0031.

## Acceptance Criteria
- [ ] `repos/HoneyDrunk.Audit/dr-runbook.md` exists, follows the packet-02 template, and records Audit as T0 with the correct RPO/RTO/geo/cadence
- [ ] The runbook's backing inventory names `HoneyDrunk.Audit.Data`, states it is Azure SQL-backed (via `HoneyDrunk.Data`'s SQL Server provider), and records the T0 Azure SQL D2 mechanics (geo-redundant backup storage, weekly LTR for 1 year, 35-day PITR) — single-branch, no Cosmos fork
- [ ] The runbook has a restore procedure validating `IAuditQuery` and `IAuditLog` against the restored store, and a manual failover procedure
- [ ] The runbook addresses tenant-scoped restore — either the D5 path, or an explicit "not currently multi-tenant" note
- [ ] `integration-points.md` records the `Audit.Data → T0` tier-inheritance rule and the `Vault → Data → Audit` recovery ordering
- [ ] The runbook notes that durability comes from ADR-0036 independent of the deferred ADR-0030 Phase 2 hash-chain/WORM work — and does NOT claim tamper-evidence (ADR-0030 Phase 1 is append-only-by-interface only, invariant 47)

## Human Prerequisites
- [ ] None for authoring the documentation. **Note for the operator:** the Azure portal backup configuration this runbook describes is packet 07a, and the first Audit restore drill is packet 07b — both `Actor=Human`. This packet writes the procedure; 07a applies the config and 07b runs the drill.

## Referenced ADR Decisions
**ADR-0036 D1 — Tier 0.** RPO ≤ 5 min, RTO ≤ 1 hr, geo-redundant with read-access secondary, annual drill + semiannual partial-restore spot-check. Audit is a member: "regulatory/forensic value scales with completeness."

**ADR-0036 D2 — Backup mechanics, Azure SQL.** Geo-redundant backup storage on; T0 LTR weekly for 1 year; PITR window 35 days. (Audit.Data is Azure SQL-backed; the Cosmos backup profile in ADR-0036 D2 does not apply to Audit.)

**ADR-0036 Consequences — Affected Nodes.** Audit is T0; gains restore drill at standup. The "ADR-0030 Phase 2 hash-chain/WORM" deferral is decoupled from this ADR; durability comes from this ADR even before tamper-evidence lands. Data has no own tier; `Audit.Data` inherits Audit's T0.

**ADR-0036 D9.** A line in `integration-points.md` if recovery has cross-Node ordering — "e.g., Audit must come up after Data, Data after Vault."

**ADR-0030 / Invariant 47 — Phase-1 audit integrity is append-only-by-interface; it is explicitly not tamper-evident, and Phase 1 must not be documented or marketed as such.** The runbook documents durability, not tamper-evidence.

**ADR-0031 — Audit standup.** `HoneyDrunk.Audit.Data` is the Data-backed implementation, persisting over `HoneyDrunk.Data`'s `IRepository`/`IUnitOfWork`. `HoneyDrunk.Data` ships EF Core + SQL Server providers — the durable backing is Azure SQL.

## Constraints
> **Invariant 47 — Phase-1 audit integrity is append-only-by-interface; it is explicitly not tamper-evident, and Phase 1 must not be documented or marketed as such.** The runbook describes durability and restore — it must not describe or imply tamper-evidence / WORM, which is deferred ADR-0030 Phase 2 work.

> **Invariant 60 (added by packet 00) — every Node holding state has a `dr_tier` assignment in `catalogs/grid-health.json`.** Audit's `dr_tier` is T0 (set in packet 01); the runbook's tier must match the catalog.

- **Audit recovery ordering is Vault → Data → Audit** — an Audit drill cannot succeed until Vault and Data are recoverable. The runbook and `integration-points.md` must state this.
- **The backing is Azure SQL** — `Audit.Data` persists over `HoneyDrunk.Data`'s SQL Server provider. Record the Azure SQL D2 mechanics only; do not write a Cosmos branch or a "flag for operator" hedge.

## Labels
`feature`, `tier-2`, `infrastructure`, `docs`, `adr-0036`, `wave-2`

## Agent Handoff

**Objective:** Author the Audit T0 `dr-runbook.md` and record the `Audit.Data → T0` tier-inheritance and the `Vault → Data → Audit` recovery ordering in `integration-points.md`.

**Target:** `HoneyDrunk.Architecture` (the `repos/HoneyDrunk.Audit/` context directory), branch from `main`. Tracked against the Audit Node.

**Context:**
- Goal: Produce the Audit DR documentation; pin the Data tier-inheritance and the cross-Node recovery ordering.
- Feature: ADR-0036 Disaster Recovery rollout, Wave 2.
- ADRs: ADR-0036 (D1/D2/D9 primary), ADR-0030 (Audit substrate, Phase-1 integrity scope), ADR-0031 (Audit standup, the Data backing).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — soft. The `dr_tier` field should exist so the runbook's tier is consistent with the catalog.
- `packet:02` — hard. The template at `generated/dr-runbook.template.md` must exist; this packet fills it in.

**Constraints:**
- Do not claim tamper-evidence — durability only (invariant 47).
- Audit recovery ordering is Vault → Data → Audit.
- The backing is Azure SQL (via `HoneyDrunk.Data`'s SQL Server provider) — single-branch runbook, no Cosmos fork, no operator hedge.

**Key Files:**
- `repos/HoneyDrunk.Audit/dr-runbook.md` (new)
- `repos/HoneyDrunk.Audit/integration-points.md`

**Contracts:** None changed — documentation only.
