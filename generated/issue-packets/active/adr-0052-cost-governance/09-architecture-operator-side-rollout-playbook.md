---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-3", "ops", "docs", "adr-0052", "wave-5"]
dependencies: ["packet:00", "packet:01", "packet:02", "packet:07"]
adrs: ["ADR-0052", "ADR-0018"]
accepts: ["ADR-0052"]
wave: 5
initiative: adr-0052-cost-governance
node: honeydrunk-architecture
---

# Author the ADR-0052 Operator-side rollout playbook and catalog the deferred follow-up surfaces

## Summary
Author the rollout playbook for the Operator-side cost-governance surfaces that this initiative does NOT build because ADR-0018 (Operator standup) is still Proposed and the Operator Node is not scaffolded: the aggregator job (Azure Cost Management / GitHub Actions / vendor API polling), the Container Apps auto-suspend job for the Azure-infra hard cap, the `hd cost` CLI surface (status / unlock / report), the "Cost" dashboard view in the Operator UI, the App Insights alert rules (D10 anomaly detection) defined as Bicep, the Communications + Notify alert wiring (daily roll-up, threshold pings, hard-cap breach push), the Phase-1 multiplier flip (D14 Phase 3), and the catalog cleanup that removes the relocating `ICostLedger` entry under `honeydrunk-ai` (left in place by packet 04 to avoid splitting the AI-code change across two repos).

## Context
ADR-0052 commits a substrate with components in multiple Nodes:
- `HoneyDrunk.Kernel` (contracts — packet 03)
- `HoneyDrunk.AI` (v1 implementation, dispatcher kill-switch — packets 04/05/06)
- `HoneyDrunk.Operator` (aggregator, CLI, dashboard, auto-suspend — **not built in this initiative**)
- `HoneyDrunk.Communications` + `HoneyDrunk.Notify` (alert delivery — **not built in this initiative**)
- `HoneyDrunk.Observe` (App Insights alert Bicep — **not built in this initiative**)

The Operator-side surfaces are the bulk of ADR-0052's deferred surface and they are deferred for a single hard reason: **ADR-0018 (Operator standup) is Proposed; the Operator Node is at seed status with no scaffolded code**. ADR-0052 Phase 1 (the substrate) builds against a not-yet-existing Operator Node would be a wasted exercise — every surface the Operator hosts must wait for the standup, not lead it.

ADR-0018 acceptance + scaffold is the **gate** for these follow-ups. This packet does not advance ADR-0018; it produces the playbook so the moment ADR-0018 lands, the follow-up packets are pre-shaped and the operator (or a future initiative) can file them without re-doing the scoping work.

**Why a playbook and not a packet-per-deferred-item.** Each deferred item is a packet against a Node that does not yet exist. Filing them now would produce GitHub issues against a repo that has no code, which is operationally noisy and misleading (the issues sit forever, gating nothing). The playbook is the right level: a structured document that lists every follow-up, gates it on the right upstream event, names the target Node, and provides enough detail that a future scope agent can re-decompose it into packets without re-reading ADR-0052 end-to-end.

**Why this packet lives in Wave 5.** It depends on the catalog (packet 01) and the budget config (packet 02) and the report format (packet 07) being in place — those are the artifacts the playbook references and links into. It also depends on packet 00 (acceptance) so the cited invariants exist. It does NOT depend on packets 03–06 (the code packets) because the playbook is purely documentation; it can land in parallel with or after the code packets without coupling.

**Phase-1 multiplier flip narrative.** ADR-0052 D14 Phase 3 says "with one month of baseline actuals from Phase 1/2, tune the per-category caps to the D2 defaults (or to the operator's adjusted values based on observed behavior). Enable threshold pings." The Phase-1 multiplier (packet 05) is the mechanism — flipping it from 10x (dev) / 1x (prod) to 1x / 1x effectively activates the D2 caps. This playbook documents the flip narrative: when to flip, how to observe, how to revert.

**Catalog cleanup.** Packet 01 marked the `honeydrunk-ai` `ICostLedger` entry as relocating. Packet 04 deleted the AI-side `ICostLedger` code. The catalog entry under `honeydrunk-ai` can now be removed cleanly — this packet does that cleanup as a small adjacent edit, since it is the last packet on the Architecture repo in this initiative.

## Scope
- `initiatives/adr-0052-rollout-playbook.md` (new — under `initiatives/` per the repo's playbook convention, or wherever the `adr-0044-cloud-code-review` playbook lives at edit time; match the existing convention) — the playbook document.
- `catalogs/contracts.json` — remove the relocating `ICostLedger` entry under `honeydrunk-ai` (packet 04 completed the code-level relocation; the catalog can now match).
- Repo-level `CHANGELOG.md`.

## Proposed Implementation
1. **`initiatives/adr-0052-rollout-playbook.md`** — the playbook document. Sections:
   - **Status.** Phase 1 (ledger substrate) shipped via packets 00–08 of `adr-0052-cost-governance`. Phase 2–7 deferred — gated on ADR-0018 Operator standup and ADR-0040 telemetry backend.
   - **Gating events.** A short list of upstream events that unblock the follow-ups:
     - **Gate 1: ADR-0018 Accepted + Operator scaffold packet executed.** Unblocks every Operator-side surface (aggregator, CLI, dashboard, auto-suspend).
     - **Gate 2: ADR-0040 Accepted + App Insights provisioned.** Unblocks the App Insights alert Bicep (D10).
     - **Gate 3: One month of Phase-1 baseline data in the ledger.** Unblocks the Phase-3 multiplier flip and cap tuning.
     - **Gate 4: ADR-0037 Accepted + Billing Node scaffolded.** Unblocks the per-tenant query API the Billing Node consumes (D9).
   - **Deferred follow-up table.** Every deferred surface with target Node, gating event, and a one-sentence sketch of the work. Columns: `#`, `Surface`, `Target Node`, `Gating Event`, `ADR-0052 Decision`. Entries:
     1. **Aggregator job** — `HoneyDrunk.Operator`. Gate 1. Polls Azure Cost Management API daily, GitHub Actions API, known vendor APIs; writes `CostEvent`s with `Source = AzureInfraSource(...)` / `CiSource(...)` / `SaasSource(...)` / `DomainSource(...)`. Backfills the prior 90 days where each API supports historical query. Validates totals against actual bills (drift > 5% is a defect). [ADR-0052 D7, D14 Phase 2]
     2. **Container Apps auto-suspend job** — `HoneyDrunk.Operator`. Gate 1. When `IsHardCapBreachedAsync(CostCategory.AzureInfrastructure)` returns `true` from the aggregator's update, the job suspends non-production Container Apps revisions. Production revisions are NOT auto-suspended (D4). [ADR-0052 D4]
     3. **`hd cost status` CLI** — `HoneyDrunk.Operator`. Gate 1. Reads `GetMonthToDateAsync` + `BudgetConfigProvider` for every category and prints the table. [ADR-0052 D11]
     4. **`hd cost unlock` CLI** — `HoneyDrunk.Operator`. Gate 1. Writes an audit event via `IAuditLog` (ADR-0030; invariant 47) and a `BudgetOverride` row via the ledger. Required flags: `<category> --reason "<text>" --duration <hours>`. Default duration 24h. No permanent option. [ADR-0052 D11; invariant 92]
     5. **`hd cost report` CLI** — `HoneyDrunk.Operator`. Gate 1. Reads the ledger and writes a manual `generated/cost-reports/YYYY-MM.md` for the requested month. Useful before the monthly aggregator is live. [ADR-0052 D9]
     6. **Monthly report aggregator** — `HoneyDrunk.Operator`. Gate 1. Cron job running on the 1st of each month; writes `generated/cost-reports/YYYY-MM.md` per the format in `generated/cost-reports/_format.md` (packet 07). Commits via the Architecture-repo automation. [ADR-0052 D9]
     7. **Operator "Cost" dashboard view** — `HoneyDrunk.Operator`. Gate 1. Real-time per-category month-to-date, threshold consumption percentages, top-N agents by spend, top-N tenants by spend, anomaly indicators. [ADR-0052 D9]
     8. **App Insights anomaly alert rules (Bicep)** — `HoneyDrunk.Observe` or `HoneyDrunk.Operator` (depending on which Node owns observability IaC at edit time — per ADR-0040's amendment the alert rules typically live with the Observe-adjacent IaC). Gate 2. Hour-over-hour 5x and day-over-day 3x rules per category; per-tenant and per-agent variants. [ADR-0052 D10]
     9. **Communications + Notify alert wiring** — `HoneyDrunk.Communications` (decision) + `HoneyDrunk.Notify` (delivery). Gate 1. Daily roll-up email at 08:00 operator-local-time; threshold pings on 50/75/90/100% soft cap; hard-cap breach push (max priority) and the structured `IErrorReporter` event (problem group `Honeydrunk.Cost.HardCapBreach`); anomaly alerts. [ADR-0052 D3]
     10. **Phase-1 multiplier flip** — `HoneyDrunk.Operator` + App Configuration. Gate 3. Flip `CostLedger:PhaseOneMultiplier:Dev` from 10 to 1 in App Configuration. No code change. Observe for one week before deploying to prod. [ADR-0052 D14 Phase 3]
     11. **Per-provider API key spending limits** — Manual portal step (OpenAI dashboard, Anthropic dashboard). Gate 0 (do at any time after this initiative ships). Set each provider's per-key limit to ~$1700/month (slightly above the $1500 AI inference hard cap), as the defense-in-depth net per ADR-0052's Alternatives Considered. [ADR-0052 Alternatives Considered]
     12. **Dev/prod Azure resource separation** — Manual portal + IaC. Gate 1 ideally; lighter version possible earlier. Reorganize Azure resources so dev and prod live in separate subscriptions or distinctly-tagged resource groups; the aggregator depends on the split to compute per-environment costs cleanly. [ADR-0052 D12]
     13. **Operator override pattern docs** — `HoneyDrunk.Architecture` (`business/context/`). Gate 0 (can happen at any time). Document the three patterns from D11 (emergency / investigative / planned) with concrete CLI examples, so the first real override is not the operator's first attempt. [ADR-0052 D11; Follow-up Work]
     14. **Per-tenant query API for the Billing Node** — `HoneyDrunk.AI` (or `HoneyDrunk.CostLedger` after promotion). Gate 4. A read API the Billing Node consumes to produce per-tenant invoices. The ledger already supports `QueryAsync` with a `TenantId` filter; this work wraps it in a Billing-friendly surface. [ADR-0037, ADR-0052 D5]
     15. **Structured JSON sidecar for monthly reports** — `HoneyDrunk.Operator` aggregator. Gate 1. After the aggregator is live, add a `YYYY-MM.json` sidecar carrying the structured data, for machine consumers. The Markdown surface is canonical for humans; the JSON is canonical for tools. [ADR-0052 D9; Follow-up Work]
   - **Recommended sequencing.** Once Gate 1 fires, file the follow-ups in roughly this order to land the most-load-bearing surfaces first:
     - First wave: aggregator + status CLI + manual report CLI (so the operator has read-side visibility).
     - Second wave: unlock CLI + override pattern docs (so the operator has the emergency response path before the kill-switches start firing).
     - Third wave: Communications + Notify alert wiring (so the operator gets the daily roll-up + threshold pings).
     - Fourth wave: Container Apps auto-suspend + App Insights anomaly Bicep + dashboard view (so the kill-switch posture is complete in all categories).
     - Fifth wave: Phase-1 multiplier flip (after a month of baseline).
     - Sixth wave: per-tenant query API (when Billing Node arrives).
   - **Re-scope guidance for a future agent.** A future scope agent re-decomposing this playbook should:
     - Treat each numbered surface as a candidate single packet, but **check for cross-Node coupling** (e.g., the Communications + Notify wiring spans two Nodes — that may decompose into two packets).
     - Use the existing ADR-0052 follow-up packet 09 as the cross-reference; do not re-discover the deferred items by reading ADR-0052 end-to-end.
     - Carry forward the gating-event language from this playbook to keep upstream dependencies explicit.
   - **Pointers to the existing artifacts.** Link `business/context/cost-budgets.json` (packet 02), `generated/cost-reports/_format.md` (packet 07), `catalogs/contracts.json` (packet 01), and `constitution/invariants.md` (packet 00, invariants 90/91/92). These are the canonical artifacts the follow-ups consume.
2. **`catalogs/contracts.json` — catalog cleanup.** Remove the `ICostLedger` entry under `honeydrunk-ai` (the seed-era entry from ADR-0016, removed in code by packet 04). Confirm at edit time that the AI repo has merged packet 04 before doing this cleanup — if packet 04 is still unmerged when this packet runs, defer the cleanup and note it as a follow-up tick. The Kernel-side `ICostLedger` entry under `honeydrunk-kernel` (added by packet 01) stays.
3. **Repo-level `CHANGELOG.md`** entry naming the playbook + the catalog cleanup.

## Affected Files
- `initiatives/adr-0052-rollout-playbook.md` (new — under `initiatives/`, or wherever the existing playbook convention places it)
- `catalogs/contracts.json` — remove the AI-side `ICostLedger` entry
- Repo-level `CHANGELOG.md`

## NuGet Dependencies
None. Documentation + catalog cleanup only.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. The playbook + catalog cleanup are Architecture-repo concerns.
- [x] No code change in any other repo.
- [x] No new runtime dependency. The deferred surfaces named in the playbook live in `HoneyDrunk.Operator` / `HoneyDrunk.Communications` / `HoneyDrunk.Notify` / `HoneyDrunk.Observe`, and this packet does not build any of them.

## Acceptance Criteria
- [ ] `initiatives/adr-0052-rollout-playbook.md` (or the equivalent per existing playbook convention) exists with the four gating events, the deferred follow-up table (15 entries), the recommended sequencing, the re-scope guidance, and the pointers to existing artifacts
- [ ] The catalog entry `{ "name": "ICostLedger", ... }` under `honeydrunk-ai` in `catalogs/contracts.json` is removed (the Kernel entry from packet 01 stays); the cleanup is performed only if packet 04 has merged
- [ ] If packet 04 has not yet merged at edit time, the cleanup is deferred and noted as a follow-up tick in this packet's PR description; the playbook still ships
- [ ] Repo-level `CHANGELOG.md` carries an entry naming the playbook and the catalog cleanup
- [ ] No code change; no .NET project; no edit to `business/context/cost-budgets.json` or `constitution/invariants.md`

## Human Prerequisites
- [ ] **Per-provider API key spending limits (deferred follow-up #11).** Set the OpenAI per-key spending limit (and Anthropic, and any other provider in use) to ~$1700/month (slightly above the $1500 Grid hard cap). This is the defense-in-depth net per ADR-0052's Alternatives Considered. Portal click: OpenAI dashboard → Billing → Usage limits; Anthropic dashboard → equivalent. The limit catches the case where the in-process ledger is somehow bypassed; the provider's limit halts spend before it spirals. Not a code change; not gated on the Operator standup. The playbook lists it as Gate-0 — do it as soon as the operator is ready.

## Referenced ADR Decisions
**ADR-0052 D3 — Alert channels and cadence.** Alerts flow through `HoneyDrunk.Communications` into `HoneyDrunk.Notify`. Daily roll-up at 08:00 operator-local. Threshold pings on 50/75/90/100%. Hard-cap breach fires both `IErrorReporter` and a Notify push. Anomaly alerts on detection. — Gated on Gate 1.

**ADR-0052 D4 — Per-category kill-switches.** AI inference is in-process (shipped in this initiative, packets 05/06). Azure infrastructure is out-of-process via the Operator-side Container Apps auto-suspend job (Gate 1). GitHub Actions uses GitHub's native org-level spending limit ($150/month per D2). SaaS / domain-cert have no kill-switch.

**ADR-0052 D9 — Reporting surfaces.** Operator "Cost" dashboard (real-time, Gate 1). Architecture repo monthly reports (format shipped in packet 07; aggregator gated on Gate 1).

**ADR-0052 D10 — Anomaly detection.** App Insights alert rules; defined as Bicep IaC. Gated on Gate 2 (App Insights provisioned per ADR-0040).

**ADR-0052 D11 — Operator unlock policy.** `hd cost unlock` CLI on `HoneyDrunk.Operator`; audited via `IAuditLog` (ADR-0030; invariant 47). Gate 1.

**ADR-0052 D12 — Dev/prod separation.** Azure resource organization step; gated on Gate 1 ideally but doable lighter earlier.

**ADR-0052 D14 — Phased rollout.** Phase 1 (ledger substrate) is closed by this initiative. Phase 2–7 are the playbook's responsibility.

**ADR-0052 Alternatives Considered — Per-key provider limits as defense-in-depth.** Set each provider's per-key limit slightly above the Grid hard cap. Adopted as a safety-net layer; named as Human Prerequisite in this packet.

**ADR-0052 Follow-up Work — JSON sidecar; override pattern docs.** Both named in the playbook's deferred table.

**ADR-0018 (Operator standup) — Proposed.** The gate for every Operator-side surface. ADR-0018 is sequenced as a separate initiative; this initiative does not advance it. The playbook records the dependency for future re-scoping.

## Constraints
- **No new code.** The playbook is documentation; no .NET project, no runtime change.
- **Catalog cleanup gated on packet 04 merge.** If packet 04 is unmerged when this packet runs, defer the cleanup and note it in the PR. The playbook ships regardless.
- **The playbook is not an issue tracker.** Do not file the deferred items as GitHub issues — that creates noise against Nodes that don't exist. Filing happens when the gating event fires (a future scope agent re-decomposes the playbook into packets).
- **Cross-reference, do not duplicate.** Where the playbook references ADR-0052 decisions or existing artifacts (`cost-budgets.json`, `_format.md`), link them rather than copying content. The ADR is the source-of-truth; the playbook is the rollout-stagger map.

## Labels
`feature`, `tier-3`, `ops`, `docs`, `adr-0052`, `wave-5`

## Agent Handoff

**Objective:** Author the ADR-0052 rollout playbook for the Operator-side surfaces this initiative does not build (because ADR-0018 standup is still Proposed), and remove the `honeydrunk-ai` `ICostLedger` catalog entry now that packet 04 has migrated the AI-side code.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Close out the initiative by recording the deferred Phase 2–7 work in a playbook a future scope agent can re-decompose into packets when the gating events (chiefly the ADR-0018 standup) fire.
- Feature: ADR-0052 Cost Governance rollout, Wave 5 (the wrap).
- ADRs: ADR-0052 D3/D4/D9/D10/D11/D12/D14 (the deferred decisions), ADR-0018 (the main gating ADR, still Proposed).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — invariant 91 / 92 cited.
- `packet:01` — catalog entry for `ICostLedger` under `honeydrunk-kernel` already exists; this packet only removes the AI-side entry.
- `packet:02` — `cost-budgets.json` cross-referenced by the playbook.
- `packet:07` — `_format.md` cross-referenced by the aggregator playbook entry.

**Constraints:**
- No code change; documentation + catalog cleanup only.
- Catalog cleanup is gated on packet 04's merge; defer the cleanup if packet 04 is unmerged.
- Do not file the deferred items as GitHub issues — a future scope agent decomposes them when the gate fires.
- Link to ADR-0052 and existing artifacts; do not duplicate content.

**Key Files:**
- `initiatives/adr-0052-rollout-playbook.md` (or the equivalent under existing convention)
- `catalogs/contracts.json` — remove AI-side `ICostLedger` entry
- Repo-level `CHANGELOG.md`

**Contracts:** None. Documentation + catalog cleanup.
