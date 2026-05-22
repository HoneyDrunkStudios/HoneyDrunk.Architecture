---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "infrastructure", "human-only", "adr-0040", "wave-3"]
dependencies: ["packet:02"]
adrs: ["ADR-0040", "ADR-0030"]
accepts: ["ADR-0040"]
wave: 3
initiative: adr-0040-telemetry-backend-and-retention
node: honeydrunk-architecture
---

# Configure Log Analytics per-table retention — 730 days for the Audit table

## Summary
Author the per-table retention configuration steps into the App Insights provisioning walkthrough and execute them on the `dev` Log Analytics workspace per ADR-0040 D3: set standard retention to 90 days, create the Audit-sourced custom table, set its retention to 730 days, and create the `evals.sensitive` dedicated table with 90-day retention and tighter access control. This is `Actor=Human` — Log Analytics table and retention configuration is portal work.

## Context
ADR-0040 D3 specifies three retention windows in **one** Log Analytics workspace: traces 90 days, metrics 93 days, logs 90 days standard / **730 days for Audit-sourced logs**. The Audit 2-year retention is the load-bearing exception — it satisfies ADR-0030 Phase 1's forensic-completeness floor ("what happened to this tenant last year") without a separate-workspace complexity. The mechanism: "one Log Analytics workspace with a custom table for Audit-sourced logs and a long retention policy on that table." The boundary is enforced by Audit emitter labeling (`source=hd-audit` custom dimension).

ADR-0040 D9 adds a second custom table: the `evals.sensitive=true`-labeled telemetry is filtered to a dedicated Log Analytics table with 90-day retention and tighter (Azure-AD-role-scoped) access control. ADR-0040's Follow-up Work names this packet's work explicitly: "Configure per-table Log Analytics retention for the Audit table (730 days)."

Log Analytics supports **per-table retention** — each table can have its own retention period independent of the workspace default. The portal surface is the workspace's Tables blade. This packet appends the table/retention steps to the `application-insights-provisioning.md` walkthrough (created by packet 02) rather than spawning a separate walkthrough — the two are the same operator session in practice.

**Coordination with packet 05.** Packet 05 implements the `evals.sensitive` routing in code (the exporter targeting the dedicated table). This packet creates the table that routing targets and configures its retention/access. The two must agree on the table name — packet 05 records the name it routes to; this packet creates that exact table. If packet 05's exporter auto-creates the table on first write, this packet's job for the Evals table narrows to setting retention and access control on the auto-created table.

This packet authors walkthrough steps **and** executes them on `dev`. No code, no .NET project.

## Scope
- `infrastructure/walkthroughs/application-insights-provisioning.md` — append a per-table retention / custom-table section (the walkthrough created by packet 02).
- `catalogs/grid-health.json` — update the `dev` telemetry entry's retention summary to reflect the Audit table at 730 days as configured (entry shape from packet 01).
- The `dev` Log Analytics workspace — the actual table and retention configuration (not a repo artifact).

## Proposed Work (human-executed, Azure Portal)
Append to the walkthrough, and then execute on the `dev` workspace:

1. **Workspace default retention** — confirm the workspace / App Insights resource standard retention is 90 days (the D3 trace/log standard; set in packet 02). Metrics retention (93 days) is an App Insights metrics property, separate from the workspace table retention — confirm it.
2. **Audit custom table** — create (or confirm) the custom Log Analytics table that receives Audit-sourced logs. The Audit emitter labels its telemetry `source=hd-audit` (D3); the table receives those rows. Document whether the table is created explicitly here or auto-created by the exporter's custom-table behavior on first Audit write.
3. **Audit table retention — 730 days** — in the workspace **Tables** blade, set the Audit table's retention to 730 days (overriding the 90-day workspace default for that table). This is the per-table retention policy D3 mandates. Note that retention beyond the included quota incurs per-GB-month storage cost (D3, D10) — document the cost note; the volume is bounded by Audit volume.
4. **`evals.sensitive` dedicated table** — create (or confirm — coordinate with packet 05) the dedicated table for `evals.sensitive=true`-labeled telemetry. Retention 90 days (same as standard, per D9). Apply **tighter access control**: Azure-AD-role-scoped access so eval prompt/completion content is not visible to every workspace reader. Document the role-scoping approach (table-level RBAC / a dedicated workspace role assignment).
5. **Verify** — confirm in the Tables blade that the Audit table shows 730-day retention, the `evals.sensitive` table shows 90 days with restricted access, and the workspace default is 90 days.
6. **Update `grid-health.json`** — update the `dev` telemetry entry's retention summary to record the Audit table as configured at 730 days.

The walkthrough documents the staging/prod repeat — same steps on those workspaces when ADR-0033's environments stand up.

## Affected Files
- `infrastructure/walkthroughs/application-insights-provisioning.md` — appended per-table retention section.
- `catalogs/grid-health.json` — `dev` telemetry retention summary updated.

## NuGet Dependencies
None. This packet has no .NET project — it is an Azure-Portal walkthrough extension plus a catalog update.

## Boundary Check
- [x] The walkthrough and the catalog update live in `HoneyDrunk.Architecture` — correct home for infrastructure walkthroughs and catalog metadata.
- [x] No code change in any repo.
- [x] Log Analytics table configuration lands in the Azure subscription (a vendor surface, not a Node).

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/application-insights-provisioning.md` has an appended section covering per-table retention, the Audit custom table, and the `evals.sensitive` dedicated table
- [ ] The `dev` Log Analytics workspace default retention is 90 days (D3 standard)
- [ ] The Audit-sourced custom table exists on the `dev` workspace and its retention is set to 730 days, overriding the workspace default
- [ ] The `evals.sensitive` dedicated table exists with 90-day retention and Azure-AD-role-scoped access control restricting eval-content visibility
- [ ] The table names agree with what packet 05's exporter routing targets — coordination recorded
- [ ] `catalogs/grid-health.json` `dev` telemetry retention summary records the Audit table at 730 days as configured
- [ ] The cost note (730-day retention incurs per-GB-month storage above the included quota, bounded by Audit volume) is documented in the walkthrough
- [ ] No secret value appears in the walkthrough or anywhere in the repo (invariant 8)

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] The `dev` App Insights resource and its backing Log Analytics workspace must exist (packet 02).
- [ ] Azure Portal access to the `dev` Log Analytics workspace with rights to create custom tables and set per-table retention.
- [ ] Azure AD rights to configure table-level / workspace role-scoped access control for the `evals.sensitive` table.
- [ ] Acceptance of the incremental storage cost for 730-day Audit retention (per-GB-month above the included quota; bounded by Audit volume — small at v1 scale).
- [ ] Confirmation of the Audit table name and the `evals.sensitive` table name — fed back to / from packet 05 so the exporter routing and the table creation agree.

## Referenced ADR Decisions
**ADR-0040 D3 — Three signal types, three retention windows.** Traces 90 days, metrics 93 days, logs 90 days standard / 730 days for Audit-sourced logs. One Log Analytics workspace with a custom table for Audit-sourced logs and a long retention policy on that table. The boundary is enforced by Audit emitter labeling (`source=hd-audit` custom dimension). Audit retention satisfies ADR-0030 Phase 1's forensic-completeness floor without separate-workspace complexity.

**ADR-0040 D9 — Evals dedicated table.** `evals.sensitive=true`-labeled telemetry is filtered to a dedicated Log Analytics table with 90-day retention and tighter access control (Azure-AD-role-scoped).

**ADR-0040 D10 — Cost.** The Audit 730-day retention incurs per-GB-month storage cost beyond the included quota; bounded by Audit volume, not unbounded. Within the $100/month ceiling at v1 volume.

**ADR-0030 — Audit forensic floor.** The Audit substrate's Phase 1 forensic-completeness requirement is what the 730-day retention serves — "what happened to this tenant last year."

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** No secret in the walkthrough or the repo.

- **One workspace, per-table retention.** D3 is explicit — do NOT create a separate workspace for Audit logs. One Log Analytics workspace; the Audit table gets a per-table 730-day retention policy overriding the 90-day default.
- **Coordinate the table names with packet 05.** Packet 05's exporter routes `evals.sensitive` telemetry to a named table; this packet creates that exact table. The Audit table likewise. Names must agree.
- **Portal-only, UI walkthrough.** No CLI, no ARM — the operator's portal-over-CLI preference. Append to the existing `application-insights-provisioning.md` walkthrough.
- **`dev` only.** Staging/prod are deferred per ADR-0033; the walkthrough documents them as a repeat.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `human-only`, `adr-0040`, `wave-3`

## Agent Handoff

**Objective:** Configure Log Analytics per-table retention on the `dev` workspace — 730 days for the Audit table, 90 days standard, and the access-controlled `evals.sensitive` dedicated table.

**Target:** Tracked against `HoneyDrunk.Architecture`; the Log Analytics work is human-executed in the Azure Portal. `Actor=Human` — `human-only` label set. The walkthrough steps append to `infrastructure/walkthroughs/application-insights-provisioning.md`.

**Context:**
- Goal: Land ADR-0040 D3's retention policy — the 730-day Audit table is the load-bearing piece serving ADR-0030's forensic floor.
- Feature: ADR-0040 Telemetry Backend and Retention rollout, Wave 3.
- ADRs: ADR-0040 D3/D9/D10 (primary), ADR-0030 (the Audit forensic-completeness floor the 730-day retention serves).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — hard. The `dev` App Insights resource and its Log Analytics workspace must exist before per-table retention can be configured.
- **packet:05** — soft coordination (not a hard `dependencies:` edge — different repo, both can proceed). The Audit and `evals.sensitive` table names must agree between packet 05's exporter routing and this packet's table creation.

**Constraints:**
- One workspace, per-table retention — do not create a separate Audit workspace.
- Coordinate table names with packet 05.
- Portal-only — append to the packet-02 walkthrough.
- `dev` only — staging/prod deferred per ADR-0033.

**Key Files:**
- `infrastructure/walkthroughs/application-insights-provisioning.md`
- `catalogs/grid-health.json`

**Contracts:** None — Azure Log Analytics configuration, no code.
