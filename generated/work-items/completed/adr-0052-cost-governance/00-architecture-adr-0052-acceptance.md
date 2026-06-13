---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0052", "wave-1"]
dependencies: []
adrs: ["ADR-0052"]
accepts: ["ADR-0052"]
wave: 1
initiative: adr-0052-cost-governance
node: honeydrunk-architecture
---

# Accept ADR-0052 — flip status, add the three cost-governance invariants, register the initiative

## Summary
Flip ADR-0052 (Cost Governance, Budget Alerts, and Kill-Switches) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, claim a three-invariant block in `constitution/invariant-reservations.md`, add the three new cost-governance invariants ADR-0052 commits in its Consequences/Invariants section to `constitution/invariants.md` at the claimed numbers `{N1}`/`{N2}`/`{N3}`, and register the `adr-0052-cost-governance` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0052 commits the Grid's cost-governance substrate: five named cost categories with per-category soft/hard caps, alert thresholds, kill-switch mechanics, per-tenant and per-agent attribution, a Cosmos-backed ledger, monthly auto-generated reports, anomaly detection, time-bounded operator overrides, and a dev/prod cap split. The forcing function is asymmetric risk: a runaway agent loop, a misconfigured retry, or a malicious tenant could surface a five-figure Azure or OpenAI bill that is a material event for the LLC, and the studio has no FinOps team to catch it. The first runaway loop is too late to introduce the policy — this ADR is positioned **inside** the AI-sector standup wave specifically so the AI Nodes consume the cost-ledger from day one of their standup.

ADR-0052 decides:
- **D1** — five named cost categories (Azure infra, AI inference, third-party SaaS, domain/cert/registrar, GitHub Actions minutes) with one human owner per category. Categories do not cross-subsidize.
- **D2** — per-category monthly soft and hard caps (AI inference $500/$1500, Azure infra $300/$800, SaaS $200 soft-only, domain/cert $25 soft-only, GitHub Actions $50/$150). Defaults live in `business/context/cost-budgets.json` and are tuned via the slow PR path; the fast path is the D11 override CLI.
- **D3** — alerts flow through `HoneyDrunk.Communications` into `HoneyDrunk.Notify`. Daily roll-up at 08:00 operator-local, threshold pings at 50/75/90/100%, hard-cap breach fires both `IErrorReporter` and maximum-priority push, anomaly alerts on detection.
- **D4** — per-category kill-switches. AI inference is in-process (`ILlmDispatcher` calls `IsHardCapBreachedAsync` before each call, throws `BudgetExceededException` — sealed, no-retry). Azure infra is out-of-process via a Container Apps auto-suspend job (non-prod only). GitHub Actions uses the GitHub-native org-level limit. SaaS and domain/cert have no kill-switch.
- **D5** — every cost event carries an optional `TenantId` dimension. Tenant-scoped costs feed the future Billing Node (ADR-0037) and abuse detection (D10).
- **D6** — AI inference events additionally carry `AgentId` and `AgentRunId` for forensics and per-run rollback. `AgentId` reuses the identifier ADR-0051 commits.
- **D7** — `ICostLedger` interface lives in `HoneyDrunk.Kernel` (Kernel-thin-shell); v1 implementation lives in `HoneyDrunk.AI`. Co-locating with the dispatcher avoids cross-Node calls on the kill-switch hot path. Promotion path to a dedicated `HoneyDrunk.CostLedger` Node when non-AI categories grow material.
- **D8** — Cosmos persistence (`(category, year-month)` partition key); rolling 13-month retention; in-memory cache refreshed every 30 seconds for hot-path reads.
- **D9** — two reporting surfaces: an Operator Node "Cost" dashboard view (real-time control surface) and `generated/cost-reports/YYYY-MM.md` auto-generated monthly reports in the Architecture repo (review surface).
- **D10** — anomaly detection as Application Insights alert rules (hour-over-hour 5x, day-over-day 3x); per-tenant and per-agent variants. Defined as Bicep IaC; alerts fire but do not trigger kill-switches.
- **D11** — operator overrides via `hd cost unlock <category> --reason --duration`; audited via `IAuditLog` per ADR-0030; time-bounded with no permanent-override option.
- **D12** — dev caps on separate subscription (or tagged resource group); production caps do not include dev burn.
- **D13** — relationship to ADR-0016 (operator-configurable rates), ADR-0037 (per-tenant attribution feeds future Billing), ADR-0041 (model approval gates *what runs*; this ADR gates *how much runs*), ADR-0045 (`IErrorReporter` surface for breach events), ADR-0030 (override audit), ADR-0018 (Operator hosts the CLI/aggregator/dashboard), ADR-0036 (tier-2 backup), ADR-0026 (`TenantId` primitive), BDR-0001 (vendor records extend the SaaS category).
- **D14** — phased rollout. Phase 1 ledger substrate with intentionally loose caps. Phase 2 aggregator + external API ingestion. Phase 3 threshold tuning + ping activation. Phase 4 kill-switch enablement (the dangerous phase). Phase 5 anomaly detection. Phase 6 per-tenant/per-agent surfaces. Phase 7 dev/prod separation.

ADR-0052 is a **policy + contract + governance** ADR. The concrete code lands across multiple Nodes; this initiative ships the abstraction surface, the budget config file, the Kernel-level contract relocation, the AI-side v1 implementation, the monthly report format, and a deferred-rollout playbook. Operator-side surfaces (CLI, aggregator, dashboard, auto-suspend, anomaly Bicep) wait on ADR-0018's Operator Node scaffold — they are named as follow-ups, not built here.

Every other packet in this initiative references ADR-0052's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Invariant Numbering
The verified current maximum invariant number in `constitution/invariants.md` is **53**. ADR-0052 adds exactly **three** invariants. Reservations are coordinated via `constitution/invariant-reservations.md` (the cross-ADR reservation ledger). **The executor claims a contiguous block of size 3** by:

1. Read `constitution/invariant-reservations.md` and inspect the **Active Reservations** table.
2. Pick the next free block of size 3 above the highest existing reservation (today's "next free" is **54**, so the expected block is **54, 55, 56**, but verify at edit time — another ADR may have claimed first).
3. Add a row to `constitution/invariant-reservations.md` recording the claim: `Range | ADR-0052 | Proposed | packet 00 at generated/work-items/active/adr-0052-cost-governance/00-architecture-adr-0052-acceptance.md`.
4. Substitute the three claimed numbers wherever this packet (and downstream packets in this initiative) uses the placeholders `{N1}` / `{N2}` / `{N3}` — meaning the three invariants in numerical order.
5. Append the three new invariants under a new `## Cost Governance Invariants` section in `constitution/invariants.md`, numbered `{N1}` / `{N2}` / `{N3}` (the invariants form a coherent group).

**First merge wins.** If another ADR's packet 00 claims the same block first and merges before this PR, this packet shifts upward by re-reading `invariant-reservations.md`, picking the new next-free block, and updating every `{N*}` placeholder reference in this initiative's packets in a follow-up commit before pushing. The reservation file is the source of truth — `invariants.md` is the canonical accepted state and lags reservations by one merge.

## Scope
- `adrs/ADR-0052-cost-governance-budget-alerts-and-kill-switches.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0052 row Status column to Accepted.
- `constitution/invariant-reservations.md` — add a row to the **Active Reservations** table claiming a three-invariant block (see Invariant Numbering above).
- `constitution/invariants.md` — add the three new cost-governance invariants (see Proposed Implementation for exact text) at the three numbers claimed in `invariant-reservations.md` (referenced here as `{N1}`/`{N2}`/`{N3}`).
- `initiatives/active-initiatives.md` — register the `adr-0052-cost-governance` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0052 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0052 index row in `adrs/README.md` to Accepted.
3. **Claim the invariant block in `constitution/invariant-reservations.md`.** Open the file, read the **Active Reservations** table, pick the next free contiguous block of size 3 above the highest current reservation, and add a row recording the claim against ADR-0052 with the path to this packet. Today's expected starting number is **54** (next free per the file); verify at edit time — if another ADR claimed first, shift upward. The three numbers claimed are referenced below as `{N1}` / `{N2}` / `{N3}` in numerical order.
4. Add three new invariants to `constitution/invariants.md`, numbered `{N1}` / `{N2}` / `{N3}` per the reservation claimed in step 3. Create a new `## Cost Governance Invariants` section (the invariants form a coherent group). The text, taken verbatim-in-substance from ADR-0052's Consequences "Invariants" section:
   - **`{N1}` — Every cost-producing operation in the Grid is recorded as a `CostEvent` in the cost ledger.** Operations that bypass the ledger have undefined kill-switch and attribution behavior and are forbidden. The dispatcher and aggregator code paths must produce a `CostEvent` for every dollar of external spend (Azure, AI provider, SaaS subscription, GitHub Actions minutes, domain/cert renewal). CI check enforces dispatcher and aggregator coverage. See ADR-0052 D1, D4, D5, D6, D7.
   - **`{N2}` — The LLM-dispatch chokepoint checks the cost ledger against the hard cap before each LLM call.** "Chokepoint" is the single seam in the AI Node that every LLM call passes through (the routing decorator or interceptor — the concrete role is named at edit time in `HoneyDrunk.AI`, not in this invariant). The check is on the hot path; failure to short-circuit when the cap is breached is a budgeting failure and a defect. `BudgetExceededException` is sealed and non-transient — code that catches it and retries within the same billing window is a defect detected by the `review` agent. Integration test required per ADR-0047 D4. See ADR-0052 D4.
   - **`{N3}` — Operator overrides of cost caps are audited.** Overrides without a corresponding audit event are an audit-substrate violation per ADR-0030 (invariant 47) and a cost-governance violation per ADR-0052. The override CLI surface is the only sanctioned override path; direct database writes to `BudgetOverride` are forbidden. Override audit records carry `sensitive=audit` tagging and follow Audit-tier retention from ADR-0030, not the cost-ledger's 13-month retention. See ADR-0052 D11.
   - Use the three claimed numbers from step 3 (in numerical order, lowest to `{N1}`). Append them under the new `## Cost Governance Invariants` section. Do not renumber any existing invariant.
5. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0052-cost-governance-budget-alerts-and-kill-switches.md`
- `adrs/README.md`
- `constitution/invariant-reservations.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0052 header reads `**Status:** Accepted`
- [ ] The ADR-0052 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariant-reservations.md` carries a new row in **Active Reservations** claiming a three-invariant contiguous block for ADR-0052 (status `Proposed` until merge), with this packet's path recorded
- [ ] `constitution/invariants.md` carries the three new cost-governance invariants (every cost-producing operation recorded as `CostEvent`; the LLM-dispatch chokepoint checks the cap on the hot path; operator overrides audited) at the three numbers claimed in `invariant-reservations.md`, under a new `## Cost Governance Invariants` section, citing ADR-0052
- [ ] The override-audit invariant references invariant 47 (Audit substrate) rather than restating its retention/tagging contract
- [ ] The chokepoint invariant references the role abstractly (the single seam in the AI Node every LLM call passes through), not a specific type name
- [ ] `initiatives/active-initiatives.md` registers the `adr-0052-cost-governance` initiative with a packet checklist
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)
- [ ] No `business/context/cost-budgets.json` in this packet (the budget config lands in packet 02)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0052 Consequences — Invariants.** ADR-0052 adds exactly three invariants: every cost-producing operation is recorded as a `CostEvent` (D1, D4, D5, D6, D7); the LLM-dispatch chokepoint checks the ledger against the hard cap before each call (D4); operator overrides are audited (D11). The three numbers are claimed at execution time via `constitution/invariant-reservations.md`.

**ADR-0030 D1 / Invariant 47 (referenced) — Durable, attributable security, action, and data-change events are emitted to `HoneyDrunk.Audit` via `IAuditLog`, on a durable channel separate from observability telemetry.** Invariant 92 (override audit) references this contract rather than restating it.

**ADR-0045 / `IErrorReporter`** — ADR-0052 D3 routes hard-cap breaches through `IErrorReporter`, problem-grouped as `Honeydrunk.Cost.HardCapBreach`. Not in this packet's scope; named here so the invariant text correctly identifies the surface.

## Constraints
- **Acceptance precedes flip.** ADR-0052 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers 90, 91, 92.** Append the three new invariants as numbers 90, 91, 92 (pre-reserved — see Invariant Numbering). Do not renumber existing invariants. Create the new `## Cost Governance Invariants` section. Include the batch note.
- **Reference, do not restate, invariant 47.** Invariant 92's override-audit rule references invariant 47 (durable audit via `IAuditLog`) and ADR-0030; do not duplicate the Audit retention/tagging contract in this invariant.
- **No catalog or config edits in this packet.** Catalog registration is packet 01; the `business/context/cost-budgets.json` config file is packet 02.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0052`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0052 to Accepted, add the three cost-governance invariants to `constitution/invariants.md`, and register the cost-governance initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0052 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0052 Cost Governance rollout, Wave 1.
- ADRs: ADR-0052 (primary), ADR-0030 (Audit — invariant 47 referenced by invariant 92), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- Acceptance precedes flip — ADR-0052 stays Proposed until this PR merges.
- Append the three new invariants as **numbers 90, 91, 92** (pre-reserved) under a new `## Cost Governance Invariants` section; do not renumber existing invariants; include the batch note.
- Invariant 92 references invariant 47 (Audit) — it does not restate it.

**Key Files:**
- `adrs/ADR-0052-cost-governance-budget-alerts-and-kill-switches.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
