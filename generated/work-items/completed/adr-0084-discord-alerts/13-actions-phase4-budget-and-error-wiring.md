---
name: Phase 4 Emitter Wiring — Azure Budget Alerts + App Insights Error Spikes
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "adr-0084", "wave-4"]
dependencies: ["work-item:05"]
adrs: ["ADR-0084", "ADR-0052", "ADR-0040", "ADR-0045"]
wave: 4
initiative: adr-0084-discord-alerts
node: honeydrunk-actions
source: strategic
generator: scope
---

# Wire Phase 4 emitters — Azure budget alerts + App Insights internal-Grid error spikes

## Summary
Retrofit the Phase 4 emitter families to call `job-discord-notify.yml` (packet 05) or `discord-notify.ps1` (packet 06) per ADR-0084 D6's routing table: Azure budget alerts at the 50/75/90/100% thresholds from ADR-0052 → `#ops-alerts` (Info/Medium) or `#ops-alerts` + `#security-alerts` (Critical at 90/100%); App Insights internal-Grid error spike / failure-rate alerts from ADR-0040 + ADR-0045 → `#ops-alerts` (High).

## Target Workflow
**File:** Azure budget alert action group → webhook receiver (home server or Functions); App Insights alert rule → action group → webhook receiver
**Family:** azure-budget, app-insights-alerts

## Motivation
ADR-0084 D6 specifies the routing for Phase 4:

- **Azure budget 50% threshold (ADR-0052)** → `#ops-alerts`, Info, `💰 budget at 50% ({category}, ${spend}/${cap})`
- **Azure budget 75% threshold (ADR-0052)** → `#ops-alerts`, Medium, `💰 budget at 75% ({category})`
- **Azure budget 90% / 100% threshold (ADR-0052)** → `#ops-alerts` + `#security-alerts`, Critical (multi-channel), `💰🔥 budget at {pct}% ({category}) — kill-switch posture: {posture}`
- **App Insights internal-Grid error spike (ADR-0045)** → `#ops-alerts`, High, `🐞 {node}: {error-fingerprint} firing {rate}/h — {link}`

ADR-0084 Follow-up Work names this work-item: *"Phase 4 rollout — wire Azure budget alerts (ADR-0052) and App Insights internal-Grid error spikes (ADR-0045)."*

These are the lowest-frequency Phase 4 wirings — budget thresholds fire at quarterly cadence at worst, error spikes are exceptional events not routine. The wiring is lower-volume than Phases 1–3 but no less important: budget-90% is a kill-switch posture trigger per ADR-0052, and an internal-Grid error spike is the failure mode App Insights exists to surface.

## Proposed Change

### 1. Azure budget alert wiring
Azure budget alerts emit via Action Groups (configurable in the Azure portal or via Bicep / Terraform per ADR-0077). Configure each existing budget alert (per ADR-0052 D-?? — 50/75/90/100% thresholds per cost category) to invoke a webhook target. The webhook target options:
- **Home-server webhook receiver per ADR-0081**: a small PowerShell HTTP listener that receives Azure-shaped budget-alert payloads, formats them per ADR-0084 D6, and emits via `discord-notify.ps1` (packet 06). This is the cleaner v1 choice.
- **Azure Function as a webhook receiver**: a Function App that receives the Azure-shaped payload and posts to Discord via `job-discord-notify.yml` (workflow_dispatch with payload). This avoids the home-server dependency but adds an Azure-Function-deployment surface to maintain.

Choose the home-server-relay path unless the home server is not operational at packet execution time; document the choice in the PR body. The wiring is per-budget-alert (one webhook configuration per budget threshold per category).

For the 90% and 100% thresholds, multi-channel routing means the webhook receiver emits two notify calls (`channel: ops-alerts` AND `channel: security-alerts`). The `{kill-switch posture}` field in the title interpolates from ADR-0052 D-?? (likely "kill-switch armed" / "kill-switch fired" / "manual review required" depending on the category and severity).

### 2. App Insights error spike / failure-rate alert wiring
App Insights alert rules per ADR-0040 + ADR-0045 fire when configured error-spike or failure-rate thresholds are crossed for **internal-Grid** error categories (tenant-facing errors remain on PagerDuty per ADR-0054 per ADR-0084 D6's clarification). Configure each App Insights alert rule's action group to invoke the same webhook target as the Azure budget alerts — same execution surface (home-server-relay or Azure Function).

The notify payload includes the Node name, error fingerprint (per ADR-0045's error-tracking taxonomy), firing rate (events/hour), and the App Insights query link for drill-down. Title `🐞 {node}: {error-fingerprint} firing {rate}/h — {link}`. `channel: ops-alerts`, `severity: high`.

### Webhook payload normalization
Both Azure budget alerts and App Insights alerts emit Azure-shaped JSON payloads (different schemas per source). The webhook receiver (home-server or Azure Function) normalizes each shape into the `job-discord-notify.yml` / `discord-notify.ps1` input contract (`channel`, `severity`, `title`, `body`, `link`, `metadata`). This normalization layer is the load-bearing implementation surface of this packet — it converts vendor-shaped events into the Grid's canonical alert contract.

## Consumer Impact
None at the Grid consumer level. The webhook receivers are infrastructure pieces, not consumed by any application Node.

## Breaking Change?
- [ ] Yes — consumers need to update their caller workflows
- [x] No — backward compatible (additive: new webhook receivers + new Azure action-group configurations; no existing behavior changed)

## Acceptance Criteria
- [ ] Azure budget alerts at 50% / 75% / 90% / 100% thresholds (per ADR-0052) are configured to invoke a webhook receiver (home-server per ADR-0081 or Azure Function — document the chosen path in PR body)
- [ ] The webhook receiver normalizes Azure-shaped budget-alert payloads into the `job-discord-notify.yml` / `discord-notify.ps1` input contract and emits notify calls per ADR-0084 D6 routing (50% → `#ops-alerts` Info; 75% → `#ops-alerts` Medium; 90%/100% → multi-channel `#ops-alerts` + `#security-alerts` Critical)
- [ ] The 90%/100% Critical notify title carries the `kill-switch posture: {posture}` field interpolated from ADR-0052 D-?? (e.g., "kill-switch armed" / "kill-switch fired" / "manual review required")
- [ ] App Insights alert rules per ADR-0040 + ADR-0045 are configured to invoke the same webhook receiver, scoped to **internal-Grid** error categories only (tenant-facing alerts remain on PagerDuty per ADR-0054)
- [ ] The webhook receiver normalizes App Insights alert payloads into the canonical alert contract and emits notify to `#ops-alerts` with `severity: high` and title `🐞 {node}: {error-fingerprint} firing {rate}/h — {link}`
- [ ] The notify metadata for App Insights alerts includes `node`, `error_fingerprint`, `rate_per_hour`, `query_link` as structured JSON fields per ADR-0084 D9's `metadata` input shape
- [ ] All notify wirings use the canonical seam (`job-discord-notify.yml` for Azure-Function-side; `discord-notify.ps1` for home-server-side) — never ad-hoc `curl` per ADR-0084 D11
- [ ] The webhook-receiver code (home-server or Azure Function) is committed to its appropriate location (home server: `infrastructure/scripts/` or the home-server bridge repo per ADR-0081; Azure Function: an existing Functions repo per ADR-0083 D1 categorization or a new one if ADR-0081 home-server-relay is the chosen path and no Azure Function is created)
- [ ] Per invariant 27, `HoneyDrunk.Actions/CHANGELOG.md` appends to the in-progress version entry documenting Phase 4 emitter wiring (if any Actions-side change lands in this packet — likely just documentation if the home-server path is chosen and no workflow change is needed)
- [ ] All affected workflows pass `actionlint` and the repo's existing CI gate post-edit (if any workflow change was needed)

## NuGet Dependencies
None. Webhook receiver is shell / PowerShell or .NET Functions; no .NET project changes inside this packet's scope unless a new Functions project is created.

## Boundary Check
- [x] Architecture-side edits target the home-server bridge code or `infrastructure/scripts/` (depending on chosen path).
- [x] Actions-side edits (if any) target `HoneyDrunk.Actions`.
- [x] Azure portal / Bicep changes configure existing Azure budget alerts and App Insights alert rules to point at the webhook receiver; no application-Node code change.
- [x] No catalog change.

## Human Prerequisites
- [ ] Operator configures the Azure budget alert action-group webhook target in the Azure portal (or via Bicep per ADR-0077 if Bicep templates exist for the budget configuration) for each of the four thresholds (50/75/90/100%) per cost category. Document the configuration in the PR.
- [ ] Operator configures the App Insights alert rule action-group webhook target similarly for each internal-Grid alert rule.
- [ ] After webhook receiver and Azure-side configuration land, the operator manually triggers a test by **temporarily** adjusting a budget threshold downward to fire an alert (then restores), and triggers a synthetic App Insights query to fire an alert rule. Verify Discord posts land in the expected channels with the expected payload normalization.

## Referenced ADR Decisions
**ADR-0084 D5 — Alert sources roster.** Azure budget alerts and App Insights internal-Grid error spikes are on the v1 roster.

**ADR-0084 D6 — Alert-routing table.** Pins the exact channel + severity + format-hint for each Phase 4 emitter. 90%/100% budget thresholds are Critical multi-channel; App Insights internal-Grid error spikes are High to `#ops-alerts`.

**ADR-0084 D9 — Implementation seam.** Cloud emitters use `job-discord-notify.yml`; home-server emitters use `discord-notify.ps1`. The webhook receiver normalizes vendor-shaped payloads into the canonical input contract.

**ADR-0084 D11 — New invariant.** Ad-hoc `curl` is forbidden in the webhook receiver — it MUST call `job-discord-notify.yml` or `discord-notify.ps1`.

**ADR-0084 Follow-up Work Phase 4.** Names this packet's scope verbatim.

**ADR-0052 — Cost governance, budget alerts, and kill-switches.** Defines the 50/75/90/100% threshold model and the per-threshold kill-switch posture. This packet routes those thresholds to Discord; the kill-switch behavior itself is not changed (kill-switches fire per ADR-0052; Discord notifies of the firing).

**ADR-0040 — Telemetry backend and retention.** App Insights is the telemetry backend; alert rules fire from it.

**ADR-0045 — Grid-wide error tracking.** Error-fingerprint taxonomy used in the notify title. Internal-Grid error categories are scoped to `#ops-alerts` per ADR-0084 D6; tenant-facing categories remain on PagerDuty per ADR-0054.

**ADR-0054 — Incident response.** Tenant-facing incident pages stay on PagerDuty per ADR-0054 D4; Discord routes only internal-Grid alerts. The boundary is the load-bearing distinction in the App Insights alert-rule configuration.

**ADR-0081 — Home server.** Hosts the webhook receiver in the home-server-relay path. PowerShell HTTP listener per D5 / D7.

**Invariant 47 — Audit and telemetry are distinct channels.** App Insights is the telemetry channel; Discord receives the alert (an operational signal), not the underlying telemetry stream. This packet does not violate invariant 47 because the alert is the rule-fired event, not the telemetry it observed.

## Constraints
- **Internal-Grid error categories only.** App Insights alert wiring routes only internal-Grid error categories per ADR-0084 D6. Tenant-facing alerts remain on PagerDuty per ADR-0054. Verify the alert-rule configuration filters correctly at packet execution time.
- **Use the canonical seam for the chosen execution surface.** Home-server-relay = `discord-notify.ps1`; Azure Function = `job-discord-notify.yml` via `workflow_dispatch` payload. Document the choice in the PR body.
- **Webhook receiver normalizes vendor-shaped payloads.** Azure budget alerts and App Insights alerts have different JSON schemas; the receiver converts both into the canonical `(channel, severity, title, body, link, metadata)` input contract.
- **Multi-channel routing for 90%/100% budget thresholds.** Two notify calls (`#ops-alerts` AND `#security-alerts`).
- **Kill-switch posture interpolation.** The 90%/100% Critical title includes the `{posture}` field from ADR-0052 D-??. Match the live ADR-0052 vocabulary.
- **Title/body templates verbatim from ADR-0084 D6.** Match emojis and placeholder names exactly.
- **Strict PR body discipline.** `Authorship: agent`, `Work Item: <path>`.

## Labels
`ci`, `tier-2`, `ops`, `adr-0084`, `wave-4`

## Agent Handoff

**Objective:** Wire Phase 4 emitters (Azure budget alerts at 50/75/90/100% + App Insights internal-Grid error spikes) to `#ops-alerts` / `#security-alerts` via the canonical seam.

**Target:** `HoneyDrunk.Actions` (for any Actions-side change) and home-server bridge code (for the home-server-relay path per ADR-0081), plus Azure portal / Bicep configuration of budget-alert and App-Insights-alert action groups.

**Context:**
- Goal: Close the v1 emitter roster — budget thresholds and error spikes are the last two families before the seven channels carry the full operator-actionable signal set.
- Feature: ADR-0084 Discord operator-alerts rollout, Wave 4.
- ADRs: ADR-0084 (D5 roster, D6 routing, D9 seam, D11 invariant), ADR-0052 (budget thresholds + kill-switches), ADR-0040 (App Insights backend), ADR-0045 (error fingerprints), ADR-0054 (tenant vs internal boundary — Discord is internal only), ADR-0081 (home-server relay), Invariant 47 (audit/telemetry vs alerts).

**Acceptance Criteria:** As listed above.

**Dependencies:** work-item:05 (`job-discord-notify.yml` must exist). Work Item:06 (`discord-notify.ps1`) is required for the home-server-relay path; same-wave so structurally satisfied.

**Constraints:**
- Internal-Grid error categories only — tenant-facing alerts stay on PagerDuty per ADR-0054.
- Use the canonical seam for the chosen execution surface.
- Webhook receiver normalizes vendor-shaped payloads into the canonical input contract.
- Multi-channel routing for 90%/100% budget thresholds.
- Title/body templates verbatim from ADR-0084 D6.
- Kill-switch posture interpolation matches ADR-0052 vocabulary.
- PR body: `Authorship: agent`, `Work Item: <path>`.

**Key Files:**
- Home-server webhook receiver code (per ADR-0081 — locate at authoring time) OR Azure Function project (NEW or existing)
- Azure portal / Bicep configuration for budget-alert action groups (per ADR-0052 + ADR-0077)
- Azure portal / Bicep configuration for App Insights alert-rule action groups (per ADR-0040 + ADR-0045 + ADR-0077)
- `CHANGELOG.md` (append if any Actions-side change lands)
- `README.md` (if applicable)

**Contracts:** None changed at the consumer-API level. Webhook-receiver-internal: Azure budget alerts and App Insights internal-Grid error alerts now produce Discord posts.
