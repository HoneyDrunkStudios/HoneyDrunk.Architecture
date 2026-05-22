---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "infrastructure", "human-only", "adr-0040", "wave-3"]
dependencies: ["packet:02"]
adrs: ["ADR-0040", "ADR-0015"]
accepts: ["ADR-0040"]
wave: 3
initiative: adr-0040-telemetry-backend
node: honeydrunk-architecture
---

# Wire Azure Monitor Alerts and the Studio operator alert channel per ADR-0040 D8

## Summary
Author the Azure Monitor Alerts setup into the App Insights provisioning walkthrough and execute it per ADR-0040 D8: create the Studio-operator action group, configure a starter set of KQL log alerts and metric alerts on the `dev` telemetry resource, and record the operator alert channel id in `business/context/`. This is `Actor=Human` — alert rules and action groups are portal work.

## Context
ADR-0040 D8 names Azure Monitor Alerts as the alert evaluation surface, with action groups routing notifications. Alert rules are KQL queries (log alerts) or metric alerts. Routing terminates at:

- **A Studio-operator channel** for Grid-internal alerts — a single Slack-or-equivalent destination, configured in `business/context/`.
- **Notify Cloud (eventually)** for tenant-facing alerts — deferred to a future Notify Cloud feature.
- **PagerDuty / on-call is NOT adopted** at solo-developer scale — the operator channel is the queue.

ADR-0040's Follow-up Work: "Wire the Studio operator alert channel; record the channel id in `business/context/`."

There is a precedent: `infrastructure/walkthroughs/log-analytics-workspace-and-alerts.md` already covers Azure Monitor alert-rule creation for ADR-0006 (rotation-SLA / security alerts). This packet's alerts are application-telemetry alerts on the App Insights resource — a different rule set, same Azure Monitor Alerts surface. Append the steps to `application-insights-provisioning.md` (the packet-02 walkthrough) and cross-reference the existing log-analytics-alerts walkthrough rather than duplicating the generic alert-creation mechanics.

This packet authors walkthrough steps **and** executes them on `dev`, plus a `business/context/` doc edit. No code, no .NET project.

## Scope
- `infrastructure/walkthroughs/application-insights-provisioning.md` — append an Azure Monitor Alerts section.
- `business/context/` — record the Studio operator alert channel id / destination (the doc the ADR names; check the existing `business/context/` layout and place it consistently — likely alongside the D10 cost-ceiling note packet 01 placed).
- The `dev` Azure Monitor / App Insights resource — the actual action group and alert rules (not repo artifacts).

## Proposed Work (human-executed, Azure Portal)
Append to the walkthrough, and then execute on `dev`:

1. **Studio-operator action group** — create an Azure Monitor action group routing to a single Studio-operator destination (Slack via webhook, email, or equivalent — the operator picks). This is the Grid-internal alert queue. Document the destination type chosen.
2. **Starter log alerts (KQL)** — create a small starter set of log alert rules on the App Insights resource. Suggested starters (the operator tunes thresholds):
   - Error-rate spike — a KQL query over the `exceptions` table, alerting when exception count crosses a threshold in a window.
   - Failed-dependency spike — `dependencies` table where `success == false` over a window.
   - Trace-volume anomaly — a sanity alert if ingest volume spikes toward the daily cap (cost guard tie-in with D10).
3. **Starter metric alerts (conditional)** — metric alerts on Azure platform metrics. **These are conditional on the underlying resources existing in `dev`.** ADR-0015's Container Apps environment and the Service Bus namespace may not be provisioned in `dev` yet — a metric alert cannot target a resource that does not exist. Author the walkthrough to instruct: create the Container Apps CPU and Service Bus queue-depth alerts **only if those resources are already provisioned in `dev`**; otherwise document them as a deferred starter set to add when the resources stand up. The App-Insights-resource-scoped alerts (log alerts in step 2) have no such dependency — the App Insights resource exists after packet 02. Keep whatever metric alerts are created minimal.
4. **Route all rules to the operator action group.** Set severity per rule. No PagerDuty, no on-call rotation — D8 is explicit.
5. **Record the channel** — write the operator alert channel id / destination into `business/context/`. Per the memory note on secrets, if the channel is a webhook URL treat it as a secret — record only a non-sensitive channel *identifier* in the repo, and store any webhook secret in Vault. Document this distinction.
6. **Verify** — fire a test alert (or use the portal's test-action-group feature) and confirm it reaches the operator channel.

The walkthrough documents the staging/prod repeat.

## Affected Files
- `infrastructure/walkthroughs/application-insights-provisioning.md` — appended Azure Monitor Alerts section.
- `business/context/` — the operator alert channel record.

## NuGet Dependencies
None. This packet has no .NET project — it is an Azure-Portal walkthrough extension plus a `business/context/` doc edit.

## Boundary Check
- [x] The walkthrough and the `business/context/` record live in `HoneyDrunk.Architecture` — correct home for infrastructure walkthroughs and operator context.
- [x] No code change in any repo.
- [x] Alert rules and action groups land in the Azure subscription (a vendor surface, not a Node).

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/application-insights-provisioning.md` has an appended Azure Monitor Alerts section covering the operator action group, log alerts, and metric alerts, cross-referencing the existing `log-analytics-workspace-and-alerts.md` for generic mechanics
- [ ] A Studio-operator action group exists on the `dev` Azure Monitor surface routing to a single operator destination
- [ ] A starter set of log alert rules (KQL) is configured on the `dev` App Insights resource — error-rate spike, failed-dependency spike, trace-volume anomaly — all routing to the operator action group
- [ ] A minimal starter set of metric alerts is configured **for whichever target resources exist in `dev`**; Container Apps / Service Bus metric alerts are documented as deferred if those resources are not yet provisioned (a metric alert cannot target a non-existent resource)
- [ ] No PagerDuty / on-call rotation is configured — the operator channel is the queue (D8)
- [ ] The operator alert channel id / destination is recorded in `business/context/`; any webhook secret is in Vault, not the repo (invariant 8) — the distinction documented
- [ ] A test alert is confirmed to reach the operator channel
- [ ] No secret value (webhook URL with token, etc.) appears in the walkthrough or anywhere in the repo (invariant 8)

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] The `dev` App Insights resource must exist (packet 02).
- [ ] Azure Portal access to the `dev` Azure Monitor surface with rights to create action groups and alert rules.
- [ ] A decision on the operator-channel destination type — Slack webhook, email, or equivalent.
- [ ] If a Slack (or similar) webhook is used, the webhook must exist and its secret URL must be stored in Vault (not the repo).
- [ ] Acceptance that alert-rule evaluation has a small Azure cost (within the $100/month ceiling; log-alert evaluation is billed per rule — keep the starter set minimal).

## Referenced ADR Decisions
**ADR-0040 D8 — Alerting.** Azure Monitor Alerts is the alert evaluation surface, with action groups routing notifications. Alert rules are KQL queries (log alerts) or metric alerts. Routing terminates at a Studio-operator channel for Grid-internal alerts (single Slack-or-equivalent destination, configured in `business/context/`); at Notify Cloud eventually for tenant-facing alerts (deferred); PagerDuty / on-call is NOT adopted at solo-developer scale — the operator channel is the queue.

**ADR-0040 D1 — Metrics explorer.** Azure platform metrics (Container Apps CPU, Service Bus queue depth, Cosmos RU) are available in the same query surface — metric alerts can target them.

**ADR-0040 D10 — Cost.** Alert-rule evaluation has a per-rule cost; the starter set is kept minimal; within the $100/month ceiling.

**ADR-0040 Follow-up Work.** "Wire the Studio operator alert channel; record the channel id in `business/context/`."

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry — nor in the repo.** A Slack webhook URL with an embedded token is a secret. Record only a non-sensitive channel identifier in `business/context/`; store the webhook secret in Vault.

- **No PagerDuty, no on-call rotation.** D8 is explicit — the operator channel is the queue at solo-developer scale.
- **Reuse the existing alert walkthrough's mechanics.** `log-analytics-workspace-and-alerts.md` already covers generic Azure Monitor alert-rule creation — cross-reference it; do not duplicate the click-by-click generic steps.
- **Portal-only, UI walkthrough.** Append to the packet-02 walkthrough.
- **`dev` only.** Staging/prod deferred per ADR-0033; documented as a repeat.
- **Keep the starter rule set minimal.** Alert-rule evaluation is billed per rule — D10 cost discipline.
- **Metric alerts are conditional on their target resources existing.** Container Apps (ADR-0015) and Service Bus may not be provisioned in `dev` — a metric alert cannot target a non-existent resource. Create those metric alerts only if the resources exist; otherwise document them as a deferred starter set. The App-Insights log alerts have no such dependency.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `human-only`, `adr-0040`, `wave-3`

## Agent Handoff

**Objective:** Wire Azure Monitor Alerts on the `dev` telemetry resource and the Studio operator alert channel per ADR-0040 D8.

**Target:** Tracked against `HoneyDrunk.Architecture`; the Azure Monitor work is human-executed in the Azure Portal. `Actor=Human` — `human-only` label set. Walkthrough steps append to `infrastructure/walkthroughs/application-insights-provisioning.md`; the channel record goes in `business/context/`.

**Context:**
- Goal: Give the Grid an alerting surface — the operator gets paged (to a single channel) when error rates or dependency failures spike.
- Feature: ADR-0040 Telemetry Backend and Retention rollout, Wave 3.
- ADRs: ADR-0040 D8/D1/D10 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — hard. The `dev` App Insights resource must exist before alert rules can target it.

**Constraints:**
- No PagerDuty / on-call — the operator channel is the queue.
- Webhook secrets go in Vault, not the repo (invariant 8).
- Cross-reference the existing `log-analytics-workspace-and-alerts.md`; do not duplicate generic mechanics.
- Portal-only; `dev` only; minimal starter rule set (cost discipline).

**Key Files:**
- `infrastructure/walkthroughs/application-insights-provisioning.md`
- `business/context/`

**Contracts:** None — Azure Monitor configuration, no code.
