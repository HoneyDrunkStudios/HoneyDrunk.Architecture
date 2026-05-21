# ADR-DRAFT: Disaster Recovery and Backup Policy

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Infrastructure / cross-cutting

## Context

The Grid has no Grid-wide RPO/RTO policy. Several Nodes carry durable state today, and the population grows monotonically:

- **HoneyDrunk.Vault** (0.5.0, Core) — Azure Key Vault per Node + bootstrap secrets. ADR-0005/0006 govern lifecycle but not DR.
- **HoneyDrunk.Data** (0.6.0, Core) — backing slot for SQL/Postgres/Cosmos; consumed by Audit, Memory (designed), Knowledge (designed), eventually Notify Cloud tenants.
- **HoneyDrunk.Audit** (Seed, ADR-0030/0031) — durable, attributable security/action log. The decision to home Audit in its own Node is **predicated** on append-only durability, but ADR-0030 explicitly scopes Phase 1 to "append-only-by-interface" and **defers** the durability/integrity story.
- **HoneyDrunk.Notify.Cloud** (Seed, ADR-0027) — first commercial Node. Paying tenants have an implicit DR expectation; ADR-0027 D-section does not address it.
- **HoneyDrunk.Knowledge / Memory / Flow** (designed) — each will hold durable state per its stand-up ADR.

Backup posture today is "whatever Azure does by default." Geo-redundant storage flags, point-in-time restore windows, and cross-region failover are unset/defaulted per Node, set in different places, and not catalogued anywhere a tenant-onboarding checklist can read.

The forcing function is PDR-0002 / ADR-0027 Notify Cloud GA: the first paying tenant onboarding question will be "what's your RPO?" and there must be a defensible answer before that conversation happens. Audit (ADR-0030) is the secondary forcing function: a security audit log with undefined durability characteristics is worse than no audit log because it carries an unjustified trust premium.

This ADR sets the Grid-wide policy. Per-Node implementation lives in each `repos/{name}/`; the policy here defines the **tiers**, the **RPO/RTO targets per tier**, the **assignment of each Node to a tier**, and the **restore-drill cadence** that proves the policy is real.

## Decision

### D1 — Three durability tiers

Every Node holding state is assigned to one of three tiers. Tier defines RPO, RTO, geo posture, and restore-drill cadence. Stateless Nodes (Kernel, Transport, Web.Rest, Communications, Notify orchestrator, Actions, Architecture, Studios) are not tiered; their DR posture is "redeploy from source" via ADR-0033.

- **Tier 0 — Critical, regulated**
  RPO ≤ 5 minutes. RTO ≤ 1 hour. Geo-redundant storage with read-access from secondary region. Annual restore drill, semiannual partial-restore spot-check.
  Members: **Vault** (loss of secrets cascades to every Node), **Audit** (regulatory/forensic value scales with completeness), **Notify Cloud tenant identity & billing data** (when materialized).

- **Tier 1 — Important, customer-impacting**
  RPO ≤ 1 hour. RTO ≤ 8 hours. Geo-redundant storage; secondary region passive (no read traffic). Semiannual restore drill.
  Members: **Notify** delivery state (in-flight messages, retry queues), **Notify Cloud tenant operational data**, **Memory** (durable agent memory once standup lands), **Knowledge** (ingested documents and embeddings).

- **Tier 2 — Best-effort**
  RPO ≤ 24 hours. RTO ≤ 72 hours. Locally redundant storage; cross-region replication not required. Annual restore drill.
  Members: **Pulse** historical signals (current values are not durable by ADR-0028's "Pulse signals are not domain events" rule), **Flow** workflow state for non-customer-facing workflows, **Evals** historical run data, internal dev/staging environments at any Node.

The mapping for each Node is recorded in `catalogs/grid-health.json` under a new `dr_tier` field per Node. `hive-sync` (ADR-0014) treats a Node holding state without a `dr_tier` as drift.

### D2 — Backup mechanics per Azure resource type

The policy maps to concrete Azure features per backing slot. This is the operational floor; Nodes may choose stronger guarantees but never weaker.

- **Azure Key Vault (Vault)** — Soft-delete and purge protection both **on**. Retention window 90 days. Vault contents are exportable via the Vault Node's restore tooling (per ADR-0006); cross-region replication is the Key Vault feature itself.
- **Azure SQL (Data backing for relational consumers)** — Geo-redundant backup storage on. Long-term retention (LTR) per tier: T0 = weekly for 1 year; T1 = weekly for 90 days; T2 = monthly for 90 days. Point-in-time-restore window = 35 days for T0/T1, 7 days for T2.
- **Azure Cosmos DB (Data backing for document/graph consumers)** — Continuous backup tier (7-day or 30-day window): T0 = 30-day; T1 = 30-day; T2 = 7-day. Geo-redundant accounts for T0/T1; single-region for T2.
- **Azure Storage Blob (logs, evals artifacts, package symbols cache)** — RA-GRS for T0; GRS for T1; LRS for T2. Soft-delete on for all tiers, retention windows = 90/30/7 days respectively. Versioning on for T0/T1; off for T2.
- **Azure Service Bus (ADR-0028 default broker)** — DR is via the standard "geo-disaster recovery" alias pairing for T0/T1 namespaces (cross-region passive pairing). In-flight messages are **not** guaranteed to survive a forced failover; consumers must be idempotent (ADR-0042) and message-replay-tolerant. T2 namespaces are single-region.
- **GitHub repos (Architecture, code Nodes)** — Codebase recovery is "re-clone from GitHub." GitHub's own durability is taken as a dependency, not as a Grid-managed concern. Releases and tagged versions on nuget.org (ADR-0034) are the version-of-record; the Grid does not separately archive nupkgs.

### D3 — Restore drills are the proof

A backup not test-restored is a backup not known to work. Each Node's release runbook gains a **Restore Drill** section with a step-by-step procedure to restore the most recent backup into an ephemeral environment and validate basic operations. The drill cadence per D1 is mandatory; results are logged to `generated/restore-drills/` (new directory) with the date, tier, Node, outcome, and any deltas to the runbook.

A missed drill is an incident: it triggers a Tier-promotion freeze on the affected Node (no new tenants onboarded against a Node whose last drill is overdue).

### D4 — Cross-region failover is a documented runbook, not an automated failover

T0 Nodes have read-access secondary regions and the **mechanism** to fail over, but failover is **manually triggered** by the Studio operator per the runbook in `repos/{name}/dr-runbook.md` (new file). Automated cross-region failover at the platform level is not adopted at this stage because:

- The Grid is single-region (per ADR-0029's implicit posture; an explicit multi-region ADR is on the backlog).
- Spurious failover is a worse failure mode than degraded availability for a solo-developer studio.
- The dollar cost of standby region capacity for stateless replicas is non-trivial at current revenue.

This is reconsidered when the Grid has more than one paying tenant whose contract requires automated regional failover.

### D5 — Tenant-data isolation in DR procedures

For multi-tenant Nodes (ADR-0026), restore drills must include a **tenant-scoped restore** path: restore one specific TenantId without affecting others. This is a hard requirement for Notify Cloud T0 data and the reason its `dr_tier` is T0 rather than T1. The mechanism is "restore to ephemeral environment, export the tenant, replay into prod" — point-in-time per-tenant restore in place is **not** required by this ADR but is named as a future amendment if the operational cost of the export/replay flow becomes prohibitive.

### D6 — Vault has a bootstrap-recovery procedure

Vault recovery is the **special case** because every other Node's DR depends on Vault being readable. The recovery procedure (separate runbook, encrypted offline copy) must exist before any other Tier 0 Node's first drill, because no other Tier 0 drill can succeed without it. The Vault bootstrap recovery doc is the only DR artifact that lives **outside** the GitHub-hosted Architecture repo (offline encrypted backup, location recorded in `business/context/` per BDR record).

### D7 — Backup retention vs. data subject deletion

GDPR / data-subject deletion requests must be honored across **active stores and backups**. Backups in retention windows are exempt from immediate deletion (per standard practice and Article 17(3)) but expire on the documented retention cycle. The Studio's DPA template (not yet authored; deferred to a future ADR) must state retention windows explicitly. Audit (ADR-0030) deletion semantics — append-only — are the explicit exception, governed by Audit's own retention rules, not by this ADR.

### D8 — Cost ceiling and tier promotion

Tier 0 storage costs roughly 3× Tier 2 in Azure at current pricing. The Grid budget envelope (no formal ADR yet; tracked in `business/context/`) treats tier assignment as a cost-impacting decision. **Tier promotion (e.g., moving Memory from T1 to T0) requires an ADR amendment**, not a configuration change. This is intentional: tier inflation is the easy mistake.

### D9 — Documentation surface

Each Node's `repos/{name}/` directory gains:

- `dr-runbook.md` — restore procedure, failover procedure, tier rationale.
- A new field `dr_tier` in `catalogs/grid-health.json`.
- A line in `repos/{name}/integration-points.md` if recovery has cross-Node ordering (e.g., Audit must come up after Data, Data after Vault).

`generated/restore-drills/` is the rolling log of drill outcomes; `hive-sync` includes it in drift reconciliation.

## Consequences

### Affected Nodes

- **HoneyDrunk.Vault** — Tier 0; gains the bootstrap-recovery procedure (D6).
- **HoneyDrunk.Audit** — Tier 0; gains restore drill at standup. The "ADR-0030 Phase 2 hash-chain/WORM" deferral is decoupled from this ADR; durability comes from this ADR even before tamper-evidence lands.
- **HoneyDrunk.Data** — Tier inheritance: it doesn't have its own DR tier; its backings inherit from the **consuming Node's** tier. (Audit.Data → T0, Memory.Data → T1, Pulse.Data → T2.) This is a Data-Node-specific clarification.
- **HoneyDrunk.Notify and HoneyDrunk.Notify.Cloud** — T1 and T0 respectively; gain runbooks and drill cadence as a Notify Cloud GA prerequisite.
- **HoneyDrunk.Pulse** — T2; existing posture mostly matches.
- **HoneyDrunk.Memory, Knowledge, Flow** (Seed) — DR tier is decided at standup, recorded in their standup ADR amendments.

### Invariants

Adds two:

- **Invariant: every Node holding state has a `dr_tier` assignment in `catalogs/grid-health.json`.** Missing assignment is drift.
- **Invariant: a missed restore drill freezes Tier-affecting tenant onboarding for the affected Node.** Recovery is "complete the drill," not "wave the requirement."

### Operational Consequences

- Tier 0 geo-redundant storage adds approximately 2× the storage cost of Tier 2 LRS. Vault, Audit, and Notify Cloud's T0 stores all carry this premium; the cost is recorded as the price of "answering RPO defensibly when a tenant asks."
- Restore drills consume Studio-operator time. Annual T0 drill ≈ half a working day per Node. Semi-annual T1 drill ≈ a quarter-day per Node. Cumulative ~3–5 operator-days per year at full Grid maturity; explicitly budgeted.
- T2 message loss on Service Bus forced failover is accepted policy and depends on the idempotency contract (ADR-0042). The two ADRs are mutually load-bearing.
- The Vault bootstrap-recovery offline copy is a new physical-world artifact (encrypted USB or printed shares). Its location and rotation procedure live in `business/context/`, not in the repo, because the repo is itself a recovery dependency.

### Follow-up Work

- Author per-Node `dr-runbook.md` for every Tier 0 Node (Vault, Audit, Notify Cloud).
- Add `dr_tier` field to `catalogs/grid-health.json` schema; backfill for current Nodes.
- Add `generated/restore-drills/` and an initial drill log for Vault.
- Author Vault bootstrap-recovery procedure (D6) before any other Tier 0 drill.
- Schedule the first Vault and Audit drills within 90 days of this ADR's acceptance.
- Backfill Tier 1 runbooks for Notify and Memory at their respective standups.

## Alternatives Considered

### One-size-fits-all "everything is Tier 0"

Rejected. Costs scale linearly with tier inflation and most state in the Grid does not have a T0 recovery requirement (Pulse signals, Evals history, ephemeral Flow state). Treating everything as T0 inflates cost with no defensible benefit.

### Defer DR until first paying tenant

Rejected. The first paying tenant's onboarding question is "what's your RPO?" If the answer is "we'll decide after you sign," they don't sign. DR posture is a precondition to commercialization, not a consequence of it.

### Adopt automated cross-region failover now

Rejected (D4). Spurious failover under solo-developer operations is more likely to be the disaster than the failure it would prevent. Manual-failover-with-tested-runbook is the correct intermediate state. Automated failover comes back on the table when contract or scale demands it.

### Per-Node DR ADRs instead of a Grid-wide policy

Rejected. Tier semantics, RPO/RTO targets, and drill cadence are exactly the kind of thing that should not be relitigated per Node. The per-Node decision is **which tier** — the tier definition is shared.

### Take the Azure default for everything and document it

Rejected as a non-decision. Azure's defaults vary by service, account, and even by ARM-template-vs-portal. "Default" is not a posture; it is the absence of one.
