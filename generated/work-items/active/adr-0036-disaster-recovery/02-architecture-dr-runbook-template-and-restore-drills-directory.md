---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "infrastructure", "docs", "adr-0036", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0036"]
accepts: ["ADR-0036"]
wave: 1
initiative: adr-0036-disaster-recovery
node: honeydrunk-architecture
---

# Create the dr-runbook.md template and the generated/restore-drills/ directory (ADR-0036 D3/D9)

## Summary
Author a reusable `generated/dr-runbook.template.md` template that every Node's `repos/{name}/` directory will adopt, and create the `generated/restore-drills/` directory with its README and drill-log schema. These are the two shared documentation artifacts ADR-0036 D9 mandates; every per-Node DR packet downstream copies the template and logs drill outcomes here.

## Context
ADR-0036 D9 says each Node's `repos/{name}/` directory gains a `dr-runbook.md` (restore procedure, failover procedure, tier rationale) and that `generated/restore-drills/` is the rolling log of drill outcomes, included by `hive-sync` in drift reconciliation. ADR-0036 D3 says each drill result is logged "with the date, tier, Node, outcome, and any deltas to the runbook."

Authoring the template and the drill-log directory once — before any per-Node runbook packet runs — means every downstream runbook (Vault packet 03, Audit packet 06, Notify packet 08) starts from the same structure rather than inventing one. This packet ships the templates only; per-Node runbooks are filled in by their own packets.

This is an Architecture-repo docs change only. No code, no .NET project.

## Scope
- `generated/dr-runbook.template.md` (new) — the reusable runbook skeleton. The repo has no `templates/` directory; per-Node docs live in `repos/{name}/` and drafts/generated artifacts live in `generated/`, so the shared template lands at `generated/dr-runbook.template.md`.
- `generated/restore-drills/` (new directory) — with `README.md` describing the directory's purpose and a drill-log entry schema/example.
- `generated/restore-drills/.gitkeep` if the directory would otherwise be empty after the README.

## Proposed Implementation
1. **Author `generated/dr-runbook.template.md`.** The template has these sections (an executing agent for a per-Node runbook packet fills the bracketed slots):
   - **Node + Tier** — `{Node name}`, `dr_tier: {T0|T1|T2}`, the tier's RPO/RTO/geo posture/drill cadence pulled from ADR-0036 D1.
   - **Tier rationale** — why this Node is at this tier (D1 references).
   - **Backing inventory** — every durable Azure resource the Node owns (Key Vault / Azure SQL / Cosmos / Blob / Service Bus namespace) and its ADR-0036 D2 backup configuration.
   - **Restore procedure** — step-by-step restore of the most recent backup into an **ephemeral** environment and validation of basic operations (D3).
   - **Failover procedure** — for T0 Nodes, the manual cross-region failover steps (D4); for T1/T2, "not applicable — see tier posture."
   - **Tenant-scoped restore** — for multi-tenant Nodes only (D5): the "restore to ephemeral, export one TenantId, replay into prod" path.
   - **Cross-Node recovery ordering** — if recovery has ordering dependencies (e.g. Audit must come up after Data, Data after Vault), a pointer to `integration-points.md` (D9).
   - **Drill cadence + last-drill record** — the tier's mandated cadence and a line for the most recent drill date/outcome (links into `generated/restore-drills/`).
2. **Create `generated/restore-drills/`** with a `README.md` that states: this is the rolling log of restore-drill outcomes per ADR-0036 D3; `hive-sync` includes it in drift reconciliation; a missed drill past its cadence is an incident that freezes tier-affecting tenant onboarding (the packet-00 invariant).
3. **Define the drill-log entry schema** in that README — each drill is one Markdown file (or one entry) recording: `date`, `tier`, `node`, `outcome` (pass/fail/partial), `runbook-deltas` (any procedure corrections found), and `operator`. Include one worked example so the format is unambiguous.

## Affected Files
- `generated/dr-runbook.template.md` (new)
- `generated/restore-drills/README.md` (new)
- `generated/restore-drills/.gitkeep` (new, if needed)

## NuGet Dependencies
None. This packet touches only Markdown docs; no .NET project is created or modified.

## Boundary Check
- [x] The template and the `generated/restore-drills/` directory live in `HoneyDrunk.Architecture` per ADR-0036 D9.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `generated/dr-runbook.template.md` exists with the eight sections above (Node+Tier, rationale, backing inventory, restore procedure, failover procedure, tenant-scoped restore, cross-Node ordering, drill cadence + last-drill record)
- [ ] The template's RPO/RTO/cadence values per tier are quoted accurately from ADR-0036 D1
- [ ] `generated/restore-drills/` exists with a `README.md` stating its purpose, the `hive-sync` reconciliation role, and the missed-drill freeze rule
- [ ] The drill-log entry schema is defined with all five fields (`date`, `tier`, `node`, `outcome`, `runbook-deltas`) plus `operator`, and one worked example
- [ ] The template is generic — no Node-specific content; per-Node runbooks are produced by their own packets

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0036 D3 — Restore drills are the proof.** Each Node's release runbook gains a Restore Drill section with a step-by-step procedure to restore the most recent backup into an ephemeral environment and validate basic operations. Drill cadence per D1 is mandatory; results logged to `generated/restore-drills/` with date, tier, Node, outcome, and runbook deltas. A missed drill is an incident — Tier-promotion freeze on the affected Node.

**ADR-0036 D9 — Documentation surface.** Each Node's `repos/{name}/` gains `dr-runbook.md` (restore procedure, failover procedure, tier rationale); `generated/restore-drills/` is the rolling drill-outcome log; a line in `integration-points.md` if recovery has cross-Node ordering.

**ADR-0036 D4 — Cross-region failover is a documented runbook.** T0 Nodes have read-access secondary regions and the mechanism to fail over, but failover is manually triggered by the Studio operator per the runbook. Automated failover is not adopted at solo-developer scale.

**ADR-0036 D5 — Tenant-data isolation.** Multi-tenant Nodes' restore drills must include a tenant-scoped restore path: restore one TenantId without affecting others, via "restore to ephemeral, export the tenant, replay into prod."

## Constraints
- **Template, not instance.** This packet ships the empty template + the directory + schema. It does not author any Node's actual runbook — those are packets 03, 06, 08 and the standup-amendment follow-ups.
- **Quote ADR-0036 D1 tier values exactly** — the RPO/RTO/cadence numbers in the template must match the ADR so per-Node runbooks inherit correct figures.

## Labels
`feature`, `tier-2`, `infrastructure`, `docs`, `adr-0036`, `wave-1`

## Agent Handoff

**Objective:** Author the shared `dr-runbook.template.md` and create `generated/restore-drills/` with its README and drill-log schema.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Give every downstream per-Node DR runbook packet a common structure to fill in, and stand up the drill-outcome log directory.
- Feature: ADR-0036 Disaster Recovery rollout, Wave 1.
- ADRs: ADR-0036 (D3/D4/D5/D9 primary), ADR-0014 (`hive-sync` reconciles `restore-drills/`).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. Should land after the acceptance flip so the template references Accepted ADR text.

**Constraints:**
- Ship the template + directory + schema only — no Node-specific runbook content.
- Quote ADR-0036 D1 tier RPO/RTO/cadence values exactly.

**Key Files:**
- `generated/dr-runbook.template.md` (new)
- `generated/restore-drills/README.md` (new)

**Contracts:** None changed.
