---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "infrastructure", "human-only", "adr-0054", "wave-3"]
dependencies: ["packet:03"]
adrs: ["ADR-0054", "ADR-0040", "ADR-0045", "ADR-0052", "ADR-0012", "ADR-0030", "ADR-0005", "ADR-0037"]
accepts: ["ADR-0054"]
wave: 3
initiative: adr-0054-incident-response
node: honeydrunk-architecture
---

# Wire every D4 alert source to PagerDuty per the routing table

## Summary
Wire every alert source named in ADR-0054 D4's routing table to PagerDuty via webhook — Azure Monitor action groups for App Insights alerts (ADR-0040), `IErrorReporter` captures landing in App Insights Failures (ADR-0045), Azure Monitor budget alerts (ADR-0052), canary failure alerts (ADR-0012), Audit failure paths (ADR-0030), Vault failure paths (ADR-0005), Stripe webhook failures (ADR-0037), and the operator-internal tenant-initiated SEV-1 ticket surface (deferred to Notify Cloud). Each source's default severity comes from the D4 table; SEV-3/4 sources go Notify-only (not PagerDuty). Maintain an operational reference copy of the routing table at `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` per ADR-0054 D4.

## Context
ADR-0054 D4 specifies the alert routing table — every signal source the Grid produces, with its default severity, routing target (Notify + PagerDuty / Notify-only), and routing conditions. The table lives in this ADR for the v1 commitment; the **operational reference copy** lives in `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` (per D10) and stays in sync via a `hive-sync` check that diffs the two.

ADR-0054's Follow-up Work names the per-source wiring:

- "Wire App Insights alerts (ADR-0040) to PagerDuty per the D4 routing table."
- "Wire `IErrorReporter` captures (ADR-0045) to PagerDuty per the D4 routing table."
- "Wire Azure Monitor budget alerts (ADR-0052) to PagerDuty per the D4 routing table."
- "Wire canary failure alerts (ADR-0012) to PagerDuty per the D4 routing table."

Per the operator's standing preference, this is **Azure Portal work**, not CLI / Terraform / ARM. The packet authors a walkthrough doc covering each source's configuration and executes it for `dev` (staging/prod are deferred per ADR-0033 — the walkthrough covers them as a re-execution).

**Mechanism — Azure Monitor → PagerDuty action group.** Most sources fire through Azure Monitor alert rules. Azure Monitor's "action group" abstraction supports a webhook action that posts to PagerDuty's Azure-Monitor integration (per packet 03's PagerDuty walkthrough). One action group per environment, named `ag-hd-pagerduty-{env}`, wired into every alert rule that should page.

**Stripe webhook failures** route differently — Stripe webhook failures surface in the deployable Node that consumes the webhook (per ADR-0037). The Node fires an `IErrorReporter` capture (per ADR-0045) which lands in App Insights and fires the App-Insights Failures-blade alert rule → PagerDuty. So Stripe → App Insights → PagerDuty rather than Stripe → PagerDuty direct.

**Audit / Vault failures** similarly route via App Insights — the Node's failure path emits an `IErrorReporter` capture which fires the App-Insights alert rule. The D4 table's Audit and Vault entries are App Insights alert rules with high severity tags.

**Tenant-initiated SEV-1 (Notify Cloud).** D4 names "Tenant opens a SEV-1 ticket via in-product surface" — but Notify Cloud is a Seed Node per ADR-0027. That source is **deferred** to Notify Cloud GA; this packet wires every other D4 source.

**Per-environment wiring.** Wire `dev` now; staging/prod are deferred per ADR-0033 (those environments do not yet exist). The walkthrough covers all three environments so wiring is a re-execution when staging/prod stand up.

**hive-sync drift check (deferred).** ADR-0054 D4 names a `hive-sync` check that diffs the ADR's table against `repos/HoneyDrunk.Notify/runbooks/alert-routing.md`. The drift check is a follow-on `hive-sync` enhancement, not part of this packet — flag as a deferred item in this packet's PR. This packet creates the operational reference copy; the drift check that keeps it in sync is a future packet.

This is an infrastructure walkthrough + wiring packet. No code, no .NET project. **Actor=Human** — the steps are Azure portal clicks the agent cannot perform.

## Scope
- `infrastructure/walkthroughs/alert-routing-pagerduty.md` (new) — the per-source Azure Monitor → PagerDuty wiring walkthrough.
- `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` (new, in this repo — the Architecture repo holds the master per-Node runbook scaffolds per packet 10; this is the alert-routing reference copy). Created in this repo and then copied / synced to the actual Notify repo by packet 10's per-Node fanout. The drift-check hive-sync (deferred) will keep them in sync going forward.
- Per-source Azure portal configuration: one `ag-hd-pagerduty-dev` action group; alert rules for every D4 source pointing at it for SEV-1/2; alert rules pointing at email/log-only for SEV-3 (Notify-only routing).
- `catalogs/grid-health.json` (or equivalent) — wiring readout per source.
- `business/context/` — deferred items list (Stripe direct integration if needed; tenant-initiated SEV-1 deferred to Notify Cloud; hive-sync drift check).

## Proposed Work (human-executed, Azure Portal + walkthrough authoring)
The walkthrough authors and the operator executes for `dev`:

1. **Action group `ag-hd-pagerduty-dev`.**
   - In Azure Portal → Monitor → Alerts → Action groups → create `ag-hd-pagerduty-dev`.
   - Add a Webhook action: target the PagerDuty Azure Monitor integration URL from packet 03's Vault entry (`pagerduty-azure-monitor-integration-url`).
   - Test the action group with the "Test action group" UI — confirm PagerDuty receives a synthetic alert.
2. **App Insights alert rules per D4.**
   - **Failure rate > 5% over 5 min on tenant-facing endpoint (SEV-1).** Create the alert rule on App Insights, scoped by the `surface=tenant` tag. Action group: `ag-hd-pagerduty-dev`. Severity: Sev1.
   - **Failure rate > 5% over 10 min on internal endpoint (SEV-2 within coverage; Notify-only outside).** Create the alert rule, scope by `surface=internal`. Action group within coverage: `ag-hd-pagerduty-dev`. Outside coverage: a Notify-only action group (or the same `ag-hd-pagerduty-dev` with PagerDuty integration's own time-window scheduling — match the cleanest pattern).
   - **Latency p95 > 2x baseline on tenant-facing endpoint (SEV-2).** Alert rule, action group `ag-hd-pagerduty-dev`.
   - **New unique problem ID with > 10 occurrences in 1h on tenant traffic (SEV-2 within coverage).** Failures-blade rule on App Insights — query on `application_Version` + `problem_id` (per ADR-0045 D2). Action group within coverage: `ag-hd-pagerduty-dev`.
   - **Existing problem ID exceeding 100/h regression threshold (SEV-3, Notify-only).** Failures-blade rule. Action group: a Notify-only action group (no PagerDuty).
3. **Azure Monitor budget alerts per D4.**
   - **Spend forecast > 120% of monthly budget (SEV-2 within coverage).** Existing budget alert from ADR-0052 — add `ag-hd-pagerduty-dev` to its action group list (within coverage).
   - **Spend actual > 80% mid-month (SEV-3).** Notify-only action group.
4. **Canary failure alerts per D4 (cross-ref ADR-0012).**
   - **Published-package canary fails post-publish (SEV-2 within coverage).** Source: `HoneyDrunk.Actions` workflow. The canary failure already emits to App Insights / GitHub status; configure the GitHub status-check failure → repository_dispatch → packet 08's incident-record generator OR an Azure Monitor log alert on the failure event. Match the existing canary-failure surface. Route to `ag-hd-pagerduty-dev`.
   - **Nightly grid-health canary fails on non-published Node (SEV-3, Notify-only).** Notify-only action group.
5. **Audit failure paths per D4 (cross-ref ADR-0030).**
   - **Write-path failure / single event drop (SEV-1).** App Insights alert rule on the Audit Node's `IErrorReporter` captures matching the Audit-write-failure problem ID. Action group: `ag-hd-pagerduty-dev`.
   - **Ingestion latency > 30 min (SEV-2).** App Insights metric alert. Action group: `ag-hd-pagerduty-dev`.
6. **Vault failure paths per D4 (cross-ref ADR-0005/0006).**
   - **Vault unreachable from any Node for > 2 min (SEV-1).** App Insights metric alert on Vault Node's connectivity probe. Action group: `ag-hd-pagerduty-dev`.
   - **Secret-rotation failure (SEV-2).** App Insights alert on rotation-Function failure path. Action group: `ag-hd-pagerduty-dev`.
7. **Stripe webhook failures per D4 (cross-ref ADR-0037).**
   - **Payment webhook failure > 5 min (SEV-2 within coverage).** Source: the Node consuming Stripe webhooks emits `IErrorReporter` captures on webhook-failure; the App Insights Failures-blade rule fires. Action group: `ag-hd-pagerduty-dev`.
8. **Tenant-initiated SEV-1 ticket (DEFERRED).** ADR-0054 D4 names "Tenant opens a SEV-1 ticket via in-product surface" but Notify Cloud is Seed. Record as a deferred item in `business/context/` — wires when Notify Cloud's tenant portal lands.
9. **DR drill SEV declarations (D4 says "as declared").** No wiring needed — drills are operator-declared incidents using packet 08's generator. Document in the walkthrough.
10. **Operational reference copy `repos/HoneyDrunk.Notify/runbooks/alert-routing.md`.**
    - Create the file in the Architecture repo at `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` mirroring the D4 table verbatim.
    - Cross-link the file as the operational reference and ADR-0054 D4 as the v1 commitment source.
    - The file will be **copied to the actual Notify repo** by packet 10's per-Node runbook fanout. For now, it lives here in the Architecture repo where the walkthrough work is happening.
    - Flag the `hive-sync` drift-check as a deferred item — packet 12 or a follow-on hive-sync packet wires it.
11. **Verify end-to-end.**
    - For each configured alert rule, trigger a synthetic condition (e.g., generate a failure spike, exhaust the canary, etc.) — confirm the PagerDuty incident fires through `ag-hd-pagerduty-dev` and a real alert reaches the operator. Document each test.
    - For Notify-only alert rules, confirm Notify intake receives the alert payload (per packet 04's intake), without PagerDuty firing.
12. **Update catalog readout.**
    - `catalogs/grid-health.json` (or equivalent) records the wiring state per source: `wired-dev` (all D4 sources), `deferred-notify-cloud` (tenant in-product ticket).
    - `business/context/` lists deferred items: tenant-initiated SEV-1 (Notify Cloud), `hive-sync` drift-check.

## Affected Files
- `infrastructure/walkthroughs/alert-routing-pagerduty.md` (new)
- `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` (new — operational reference copy, hosted here in Architecture for now; packet 10's per-Node fanout copies it to the actual Notify repo)
- `catalogs/grid-health.json` (or equivalent) — per-source wiring state
- `business/context/` — deferred items list
- Azure Portal: one action group `ag-hd-pagerduty-dev`; alert rules for App Insights / budget / canary / Audit / Vault / Stripe paths (Azure resources, not repo artifacts)

## NuGet Dependencies
None. This packet has no .NET project.

## Boundary Check
- [x] The walkthrough doc lives in `HoneyDrunk.Architecture` — correct home for infrastructure walkthroughs.
- [x] The operational reference copy of the D4 table lives in `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` per ADR-0054 D4 — Architecture is the master copy until packet 10's fanout.
- [x] No code change in any repo.
- [x] Azure resources land in the Azure subscription (a vendor surface, not a Node).
- [x] PagerDuty webhook integration was provisioned in packet 03; this packet consumes that integration.

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/alert-routing-pagerduty.md` exists and documents the per-source Azure Monitor → PagerDuty wiring for every D4 source: App Insights failure-rate / latency / Failures-blade rules; budget alerts; canary failures; Audit / Vault / Stripe failure paths; the Notify-only SEV-3 routing; the deferred Notify Cloud tenant-initiated SEV-1
- [ ] One action group `ag-hd-pagerduty-dev` exists in `dev` with the PagerDuty Azure Monitor integration URL webhook action; test-action-group succeeded
- [ ] Each D4 source has an alert rule (or existing alert rule extended) in `dev` pointing at the correct action group per the D4 severity / coverage-window matrix
- [ ] `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` exists in the Architecture repo (hosted here for now; packet 10 fanouts to the actual Notify repo) mirroring the D4 table verbatim and cross-linking ADR-0054 D4 as the source of truth
- [ ] Each configured alert rule has been triggered with a synthetic condition; PagerDuty receipt confirmed for SEV-1/2; Notify-only receipt confirmed for SEV-3 — each verification documented
- [ ] `catalogs/grid-health.json` (or equivalent) records the per-source wiring state for `dev`; staging/prod marked deferred per ADR-0033
- [ ] `business/context/` lists deferred items: tenant-initiated SEV-1 (Notify Cloud), `hive-sync` drift-check (D4 ↔ operational reference copy)
- [ ] No secret in any walkthrough text or repo file; the PagerDuty integration URL is read from Vault per packet 03 (invariants 8, 9)

## Human Prerequisites
- [ ] **Packet 03 must be complete** — the PagerDuty Starter account, escalation policy, and Azure Monitor integration URL must exist and be stored in Vault.
- [ ] **Packet 04 must be complete or in progress** — Notify intake must exist for the Notify-only SEV-3 routing (the routing layer can be wired without packet 04 if the alert paths are configured to email/log-only, but verifying end-to-end requires Notify intake).
- [ ] **ADR-0040 packet 02 must be complete** — App Insights `dev` resource provisioned (referenced by every App Insights alert rule in this packet).
- [ ] **ADR-0030 / Audit Node alerting surfaces** — Audit must already emit the failure-path captures that ADR-0030 commits; without those, the Audit alert rules have no data.
- [ ] **ADR-0052 budget alerts** — must already exist in `dev`; this packet extends them to add `ag-hd-pagerduty-dev`.
- [ ] **Trigger synthetic conditions for each alert rule** — agent cannot click "trigger test" in the Azure portal; operator executes the verification.
- [ ] **Decide deferred-items handling** — the agent can author the deferred-items list; the operator confirms tenant-initiated SEV-1 stays deferred until Notify Cloud lands and the `hive-sync` drift-check is a follow-on packet.

## Referenced ADR Decisions
**ADR-0054 D4 — Alert sources and routing table.** Every signal source the Grid produces routes through this table. The source declares the SEV at emission; the routing layer (Notify Communications + PagerDuty) honors it. Full table reproduced in the ADR's D4 section; this packet wires every row except the deferred tenant-initiated SEV-1.

**ADR-0054 D4 — Operational reference copy.** "The table lives in this ADR for the v1 commitment; the operational reference copy lives in `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` (per D10) and stays in sync via a `hive-sync` check that diffs the two." The `hive-sync` check is a follow-on; this packet creates the operational reference copy.

**ADR-0040 — Telemetry backend.** App Insights resources per environment; alert rules attached.

**ADR-0045 — Grid-wide error tracking.** `IErrorReporter` captures land in App Insights Failures with `problem_id` + `application_Version`; the Failures-blade alert rules consume them.

**ADR-0052 — Cost discipline.** Azure Monitor budget alerts at the subscription level; this packet adds `ag-hd-pagerduty-dev` to their action group lists per D4's thresholds.

**ADR-0012 — Canary failures.** Canary failure surface; the SEV-2 published-package-canary-failure rule fires through Azure Monitor.

**ADR-0030 — Audit failure paths.** Audit write-path failures and ingestion latency emit captures that App Insights alert rules consume; SEV-1 / SEV-2 per D4.

**ADR-0005 — Vault failure paths.** Vault unreachable and rotation failures emit captures that App Insights alert rules consume; SEV-1 / SEV-2 per D4.

**ADR-0037 — Stripe webhook failures.** Stripe webhook surface in the consuming Node emits captures on webhook failure; App Insights alert rule fires the SEV-2 routing.

**ADR-0027 — Notify Cloud (deferred).** Tenant in-product SEV-1 ticket surface depends on Notify Cloud; deferred.

**ADR-0033 — Tag → environment mapping.** Staging/prod environments are deferred; this packet wires `dev` and documents the staging/prod re-execution path.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry — or in walkthrough docs.** The PagerDuty Azure Monitor integration URL is read from Vault per packet 03; never pasted into the walkthrough text, never committed.

> **Invariant 9 — Vault is the only source of secrets.** The integration URL is read via `ISecretStore` at runtime by any code that consumes it; the portal configuration references the Vault path (Azure Monitor action group webhook config supports secret values).

- **One action group per environment.** `ag-hd-pagerduty-dev` for `dev`. Staging/prod are deferred per ADR-0033.
- **SEV-3 / SEV-4 are Notify-only or unrouted.** Do not add SEV-3 sources to the PagerDuty action group — they would burn PagerDuty's ack tax for non-paging-worthy events (D3).
- **Coverage-window scheduling for SEV-2 outside coverage.** Per D2, SEV-2 outside coverage hours pages via Notify-only (not PagerDuty). Implement via PagerDuty's time-window scheduling or via separate action groups — match the cleanest pattern.
- **Tenant-initiated SEV-1 is deferred** — record but do not wire.
- **`hive-sync` drift check is deferred** — record but do not implement here.
- **Walkthrough covers all environments** so staging/prod is a re-execution.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `human-only`, `adr-0054`, `wave-3`

## Agent Handoff

**Objective:** Wire every D4 alert source to PagerDuty (or Notify-only for SEV-3) in the `dev` environment via Azure Monitor action groups, create the operational reference copy of the D4 table at `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` in the Architecture repo, and verify each wiring with a synthetic trigger.

**Target:** `HoneyDrunk.Architecture` for the walkthrough doc and the operational reference copy. Azure resources land in the Azure subscription.

**Context:**
- Goal: Close the loop on the alert paths the ADR-0034–0047 wave opened. Every alert source defined by ADR-0040/0045/0052/0012/0030/0005/0037 now routes through PagerDuty (for SEV-1/2) or Notify (for SEV-3) per the D4 table.
- Feature: ADR-0054 Incident Response rollout, Wave 3.
- ADRs: ADR-0054 D4 (primary), ADR-0040 (App Insights), ADR-0045 (Failures-blade), ADR-0052 (budgets), ADR-0012 (canaries), ADR-0030 (Audit), ADR-0005 (Vault), ADR-0037 (Stripe), ADR-0027 (deferred Notify Cloud), ADR-0033 (deferred staging/prod).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` — hard. PagerDuty integration URL must exist in Vault before any action group can target it.

**Constraints:**
- One action group per environment.
- SEV-3 / SEV-4 are Notify-only.
- Coverage-window scheduling for SEV-2 outside coverage.
- Tenant-initiated SEV-1 deferred to Notify Cloud.
- `hive-sync` drift check deferred to a follow-on packet.
- Walkthrough covers all environments for staging/prod re-execution.
- No secret in any walkthrough text or repo file (invariants 8, 9).

**Key Files:**
- `infrastructure/walkthroughs/alert-routing-pagerduty.md` (new)
- `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` (new in Architecture repo; packet 10 fanouts to Notify repo)
- `catalogs/grid-health.json` (or equivalent) — wiring state
- `business/context/` — deferred items list

**Contracts:** None changed. The Azure Monitor action groups and alert rules are Azure resources; the operational reference copy is a docs artifact.
