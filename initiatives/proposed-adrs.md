# Proposed ADRs and PDRs Awaiting Acceptance

Tracked automatically by the hive-sync agent. ADRs/PDRs with all implementing
issues closed are auto-flipped to Accepted on each run; the rest are listed
here with progress.

Last synced: 2026-05-21

> **Manual addition (2026-05-23):** ADRs 0048–0057 added below by hand on the `claude/adr-review-dFtgC` branch. Hive-sync will reconcile on its next scheduled run; the entries below should be a no-op match.
>
> **Manual addition (2026-05-23):** ADR-0060 (HoneyDrunk.Identity stand-up) added below by the adr-composer agent. Hive-sync will reconcile on its next scheduled run.

## Awaiting (no `accepts:`-declaring packets yet)

These have no packets declaring them in `accepts:` frontmatter. Auto-flip
will not happen until the scope agent files at least one packet that
declares the decision in `accepts:`. Legacy Proposed ADRs whose
implementing packets pre-date the `accepts:` convention also appear here
and remain manually-flippable until rescoped.

| ID | Title | Sector | Dated | Days in Proposed |
|----|-------|--------|-------|------------------|
| [ADR-0011](../adrs/ADR-0011-code-review-and-merge-flow.md) | ADR-0011: Code Review and Merge Flow | Meta | 2026-04-12 | 39 |
| [ADR-0012](../adrs/ADR-0012-grid-cicd-control-plane.md) | ADR-0012: HoneyDrunk.Actions as the Grid CI/CD Control Plane | Meta | 2026-04-13 | 38 |
| [ADR-0017](../adrs/ADR-0017-stand-up-honeydrunk-capabilities-node.md) | ADR-0017: Stand Up the HoneyDrunk.Capabilities Node — Tool Registry and Dispatch Substrate for the AI Sector | AI | 2026-04-19 | 32 |
| [ADR-0029](../adrs/ADR-0029-cloudflare-dns-and-edge-platform.md) | ADR-0029: Cloudflare as Registrar, Authoritative DNS, and Edge Platform | Infrastructure | 2026-05-08 | 13 |
| [ADR-0032](../adrs/ADR-0032-pr-validation-policy-coverage-gate-and-nuget-flagging.md) | ADR-0032: Grid-Wide PR Validation Policy — Coverage Gate and NuGet Update Flagging | Meta | 2026-05-17 | 4 |
| [ADR-0033](../adrs/ADR-0033-environment-gated-deploy-trigger-model.md) | ADR-0033: Environment-Gated Deploy-Trigger Model for Deployable Nodes | Ops | 2026-05-18 | 3 |
| [ADR-0034](../adrs/ADR-0034-public-package-distribution-and-nuget-policy.md) | ADR-0034: Public Package Distribution and NuGet Policy | Meta / cross-cutting | 2026-05-21 | 0 |
| [ADR-0035](../adrs/ADR-0035-abstractions-versioning-and-deprecation-policy.md) | ADR-0035: Abstractions Versioning and Deprecation Policy | Meta / cross-cutting | 2026-05-21 | 0 |
| [ADR-0036](../adrs/ADR-0036-disaster-recovery-and-backup-policy.md) | ADR-0036: Disaster Recovery and Backup Policy | Infrastructure / cross-cutting | 2026-05-21 | 0 |
| [ADR-0037](../adrs/ADR-0037-payment-and-billing-integration.md) | ADR-0037: Payment and Billing Integration | Ops / cross-cutting | 2026-05-21 | 0 |
| [ADR-0038](../adrs/ADR-0038-outbound-sender-identity-and-deliverability.md) | ADR-0038: Outbound Sender Identity and Deliverability | Ops | 2026-05-21 | 0 |
| [ADR-0039](../adrs/ADR-0039-grid-open-source-license-policy.md) | ADR-0039: Grid Open Source License Policy | Meta / cross-cutting | 2026-05-21 | 0 |
| [ADR-0040](../adrs/ADR-0040-telemetry-backend-and-retention.md) | ADR-0040: Telemetry Backend and Retention | Ops / cross-cutting | 2026-05-21 | 0 |
| [ADR-0041](../adrs/ADR-0041-ai-model-registry-and-approval-workflow.md) | ADR-0041: AI Model Registry and Approval Workflow | AI | 2026-05-21 | 0 |
| [ADR-0042](../adrs/ADR-0042-idempotency-contract-for-async-boundaries.md) | ADR-0042: Idempotency Contract for Async Boundaries | Core / cross-cutting | 2026-05-21 | 0 |
| [ADR-0043](../adrs/ADR-0043-continuous-backlog-generation-strategy.md) | ADR-0043: Continuous Backlog Generation Strategy | Meta | 2026-05-21 | 0 |
| [ADR-0044](../adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) | ADR-0044: Grid-Aware Cloud Code Review and AI-Authored PR Discipline | Meta | 2026-05-21 | 0 |
| [ADR-0045](../adrs/ADR-0045-grid-wide-error-tracking.md) | ADR-0045: Grid-Wide Error Tracking | Ops / cross-cutting | 2026-05-21 | 0 |
| [ADR-0046](../adrs/ADR-0046-specialist-review-agents.md) | ADR-0046: Specialist Review Agents | Meta | 2026-05-21 | 0 |
| [ADR-0047](../adrs/ADR-0047-testing-patterns-and-tooling.md) | ADR-0047: Testing Patterns and Tooling | Meta / cross-cutting | 2026-05-21 | 0 |
| [ADR-0048](../adrs/ADR-0048-data-schema-evolution-and-migration-policy.md) | ADR-0048: Data Schema Evolution and Migration Policy | Core / cross-cutting | 2026-05-22 | 1 |
| [ADR-0049](../adrs/ADR-0049-data-classification-pii-handling-and-retention-schedule.md) | ADR-0049: Data Classification, PII Handling, and Retention Schedule | Core / cross-cutting | 2026-05-22 | 1 |
| [ADR-0050](../adrs/ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md) | ADR-0050: Tenant Lifecycle — Provisioning, Suspension, Offboarding, and Data Export | Core / cross-cutting | 2026-05-22 | 1 |
| [ADR-0051](../adrs/ADR-0051-ai-agent-authorization-and-tool-scoping-model.md) | ADR-0051: AI Agent Authorization and Tool Scoping Model | AI / cross-cutting | 2026-05-22 | 1 |
| [ADR-0052](../adrs/ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) | ADR-0052: Cost Governance, Budget Alerts, and Kill-Switches | Ops / cross-cutting | 2026-05-22 | 1 |
| [ADR-0053](../adrs/ADR-0053-environments-branching-and-release-cadence.md) | ADR-0053: Environments, Branching, and Release Cadence | Meta / cross-cutting | 2026-05-22 | 1 |
| [ADR-0054](../adrs/ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) | ADR-0054: Incident Response and On-Call Model for a One-Person Studio | Ops / cross-cutting | 2026-05-22 | 1 |
| [ADR-0055](../adrs/ADR-0055-feature-flag-and-progressive-rollout-strategy.md) | ADR-0055: Feature Flag and Progressive Rollout Strategy | Core / cross-cutting | 2026-05-22 | 1 |
| [ADR-0056](../adrs/ADR-0056-threat-model-and-security-review-cadence.md) | ADR-0056: Threat Model and Security Review Cadence | Meta / Security / cross-cutting | 2026-05-22 | 1 |
| [ADR-0057](../adrs/ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) | ADR-0057: Public HTTP API Versioning and Client SDK Strategy | Core / cross-cutting | 2026-05-22 | 1 |
| [ADR-0060](../adrs/ADR-0060-stand-up-honeydrunk-identity-node.md) | ADR-0060: Stand Up the HoneyDrunk.Identity Node — User Record, Credential Seam, and Erasure Fan-Out | Core | 2026-05-23 | 0 |
| [ADR-0061](../adrs/ADR-0061-stand-up-honeydrunk-files-node.md) | ADR-0061: Stand Up the HoneyDrunk.Files Node — Blob Storage, Media Processing, and Signed-URL Delivery | Core | 2026-05-23 | 0 |
| [PDR-0002](../pdrs/PDR-0002-notify-as-a-service-first-commercial-product.md) | PDR-0002: HoneyDrunk Notify — First Commercial Product on the Grid | Ops (primary) · Meta (positioning) | 2026-05-02 | 19 |
| [PDR-0003](../pdrs/PDR-0003-lately-currents-based-connection-app.md) | PDR-0003: Lately — A Currents-Based Connection App for Regular Humans | Market / Core / Ops | 2026-05-05 | 16 |
| [PDR-0005](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md) | PDR-0005: Hearth — Personal Growth as a Living Town | Market / AI / Ops | 2026-05-05 | 16 |
| [PDR-0006](../pdrs/PDR-0006-currents-social-suggestions-and-quests.md) | PDR-0006: Currents — Social Suggestions and Lightweight Quests | Market / AI / Social | 2026-05-06 | 15 |
| [PDR-0008](../pdrs/PDR-0008-curiosities-discovery-first-city-app.md) | PDR-0008: Curiosities — Discovery-First City App | Market / Location / AI / Play | 2026-05-16 | 5 |

## In Progress (implementing packets filed; some issues still open)

| ID | Title | Progress | Open / Missing packets |
|----|-------|----------|------------------------|
| [ADR-0018](../adrs/ADR-0018-stand-up-honeydrunk-operator-node.md) | ADR-0018: Stand Up the HoneyDrunk.Operator Node — Human-Policy Enforcement and Audit Substrate for the AI Sector | 0/4 closed | [HoneyDrunk.Architecture#121](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/121) open<br>[HoneyDrunk.Architecture#122](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/122) open<br>[HoneyDrunk.Architecture#123](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/123) open<br>[HoneyDrunk.Operator#3](https://github.com/HoneyDrunkStudios/HoneyDrunk.Operator/issues/3) open |
| [ADR-0020](../adrs/ADR-0020-stand-up-honeydrunk-agents-node.md) | ADR-0020: Stand Up the HoneyDrunk.Agents Node — Agent Runtime Substrate for the AI Sector | 0/4 closed | [HoneyDrunk.Architecture#125](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/125) open<br>[HoneyDrunk.Architecture#126](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/126) open<br>[HoneyDrunk.Architecture#127](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/127) open<br>[HoneyDrunk.Agents#2](https://github.com/HoneyDrunkStudios/HoneyDrunk.Agents/issues/2) open |
| [ADR-0021](../adrs/ADR-0021-stand-up-honeydrunk-knowledge-node.md) | ADR-0021: Stand Up the HoneyDrunk.Knowledge Node — External Knowledge Ingestion and Retrieval Substrate for the AI Sector | 0/4 closed | [HoneyDrunk.Architecture#129](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/129) open<br>[HoneyDrunk.Architecture#130](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/130) open<br>[HoneyDrunk.Architecture#131](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/131) open<br>[HoneyDrunk.Knowledge#2](https://github.com/HoneyDrunkStudios/HoneyDrunk.Knowledge/issues/2) open |
| [ADR-0022](../adrs/ADR-0022-stand-up-honeydrunk-memory-node.md) | ADR-0022: Stand Up the HoneyDrunk.Memory Node — Agent-Memory Substrate for the AI Sector | 0/4 closed | [HoneyDrunk.Architecture#134](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/134) open<br>[HoneyDrunk.Architecture#135](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/135) open<br>[HoneyDrunk.Architecture#136](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/136) open<br>[HoneyDrunk.Memory#2](https://github.com/HoneyDrunkStudios/HoneyDrunk.Memory/issues/2) open |
| [ADR-0023](../adrs/ADR-0023-stand-up-honeydrunk-evals-node.md) | ADR-0023: Stand Up the HoneyDrunk.Evals Node — Evaluation and Quality Substrate for the AI Sector | 0/4 closed | [HoneyDrunk.Architecture#137](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/137) open<br>[HoneyDrunk.Architecture#138](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/138) open<br>[HoneyDrunk.Architecture#139](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/139) open<br>missing `generated/issue-packets/active/adr-0023-evals-standup/04-evals-node-scaffold.md` |
| [ADR-0024](../adrs/ADR-0024-stand-up-honeydrunk-flow-node.md) | ADR-0024: Stand Up the HoneyDrunk.Flow Node — Workflow-Orchestration Substrate for the AI Sector | 0/4 closed | [HoneyDrunk.Architecture#141](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/141) open<br>[HoneyDrunk.Architecture#142](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/142) open<br>[HoneyDrunk.Architecture#143](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/143) open<br>[HoneyDrunk.Flow#2](https://github.com/HoneyDrunkStudios/HoneyDrunk.Flow/issues/2) open |
| [ADR-0025](../adrs/ADR-0025-stand-up-honeydrunk-sim-node.md) | ADR-0025: Stand Up the HoneyDrunk.Sim Node — Simulation and Plan-Evaluation Substrate for the AI Sector | 0/4 closed | [HoneyDrunk.Architecture#145](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/145) open<br>[HoneyDrunk.Architecture#146](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/146) open<br>[HoneyDrunk.Architecture#147](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/147) open<br>missing `generated/issue-packets/active/adr-0025-sim-standup/04-sim-node-scaffold.md` |
| [ADR-0027](../adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) | ADR-0027: Stand Up the HoneyDrunk.Notify.Cloud Node — Multi-Tenant Commercial Wrapper Above Notify | 0/6 closed | [HoneyDrunk.Architecture#149](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/149) open<br>[HoneyDrunk.Architecture#150](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/150) open<br>[HoneyDrunk.Notify#21](https://github.com/HoneyDrunkStudios/HoneyDrunk.Notify/issues/21) open<br>[HoneyDrunk.Communications#18](https://github.com/HoneyDrunkStudios/HoneyDrunk.Communications/issues/18) open<br>[HoneyDrunk.Architecture#151](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/151) open<br>missing `generated/issue-packets/active/adr-0027-notify-cloud-standup/06-notify-cloud-node-scaffold.md` |
| [ADR-0028](../adrs/ADR-0028-event-driven-architecture-and-messaging.md) | ADR-0028: Event-Driven Architecture and Messaging — Use-Case-First Backing Selection | 0/4 closed | [HoneyDrunk.Architecture#117](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/117) open<br>[HoneyDrunk.Architecture#118](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/118) open<br>[HoneyDrunk.Architecture#119](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/119) open<br>[HoneyDrunk.Communications#17](https://github.com/HoneyDrunkStudios/HoneyDrunk.Communications/issues/17) open |

## Pending Flip (qualified for auto-flip but exceeds MAX_FLIPS_PER_RUN this run)

> Flip queue exceeds the per-run limit (3); the entries below will flip on subsequent runs.

| ID | Title | Sector | Date |
|----|-------|--------|------|
| _None._ |  |  |  |

## Anomalies

Surface-only items. The agent does not act on these - the human/scope agent does.

| Item | Detail |
|------|--------|
| ADR-0023 | accepts packet(s) missing from filed-packets.json: generated/issue-packets/active/adr-0023-evals-standup/04-evals-node-scaffold.md |
| ADR-0025 | accepts packet(s) missing from filed-packets.json: generated/issue-packets/active/adr-0025-sim-standup/04-sim-node-scaffold.md |
| ADR-0027 | accepts packet(s) missing from filed-packets.json: generated/issue-packets/active/adr-0027-notify-cloud-standup/06-notify-cloud-node-scaffold.md |

## Flipped This Run

ADRs/PDRs whose Status was changed by **this** sync run from `Proposed` to `Accepted`. Regenerated each run from the current run's flips only.

| ID | Title | Sector | Date |
|----|-------|--------|------|
| [ADR-0031](../adrs/ADR-0031-stand-up-honeydrunk-audit-node.md) | ADR-0031: Stand Up the HoneyDrunk.Audit Node — Grid-Wide Durable Security and Action Record | Core | 2026-05-16 |
