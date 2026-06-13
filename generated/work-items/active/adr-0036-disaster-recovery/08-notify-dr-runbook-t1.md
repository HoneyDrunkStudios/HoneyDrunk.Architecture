---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0036", "wave-2"]
dependencies: ["work-item:01", "work-item:02"]
adrs: ["ADR-0036", "ADR-0028"]
accepts: ["ADR-0036"]
wave: 2
initiative: adr-0036-disaster-recovery
node: honeydrunk-notify
---

# Author the Notify T1 dr-runbook for delivery state and Service Bus DR posture (ADR-0036 D1/D2)

## Summary
Author `repos/HoneyDrunk.Notify/dr-runbook.md` from the packet-02 template — Notify as a T1 Node — covering delivery state (in-flight messages, retry queues), the Service Bus DR posture per ADR-0036 D2, and the semiannual T1 restore-drill cadence.

## Context
ADR-0036 D1 places **Notify delivery state** (in-flight messages, retry queues) at T1: RPO ≤ 1 hr, RTO ≤ 8 hr, geo-redundant storage with a passive secondary region, semiannual restore drill. ADR-0036's Affected Nodes section: "HoneyDrunk.Notify and HoneyDrunk.Notify.Cloud — T1 and T0 respectively; gain runbooks and drill cadence as a Notify Cloud GA prerequisite."

`HoneyDrunk.Notify.Cloud` is the T0 commercial Node (ADR-0027) and is **not yet scaffolded** — its T0 runbook, tenant identity/billing backup, and tenant-scoped restore (ADR-0036 D5) are deferred to the Notify Cloud standup and out of this initiative's scope (see the dispatch plan's out-of-scope section). **This packet covers `HoneyDrunk.Notify` itself** — the live Ops Node at v0.3.0 — at T1.

ADR-0036 D2 specifies the Service Bus DR posture: T0/T1 namespaces use the standard geo-disaster-recovery alias pairing (cross-region passive pairing); in-flight messages are **not** guaranteed to survive a forced failover, so consumers must be idempotent (ADR-0042) and message-replay-tolerant.

This packet authors **documentation**. It is tracked against the Notify Node but the file lives in `repos/HoneyDrunk.Notify/` inside `HoneyDrunk.Architecture`, so the target repo is `HoneyDrunk.Architecture`. No code, no .NET project.

## Scope
- `repos/HoneyDrunk.Notify/dr-runbook.md` (new) — the Notify T1 runbook, from the packet-02 template.
- `repos/HoneyDrunk.Notify/integration-points.md` — add the Service Bus DR-posture line and the idempotency dependency (ADR-0042).

## Proposed Implementation
1. **Author `dr-runbook.md`** from the packet-02 template at `generated/dr-runbook.template.md`, filled for Notify:
   - Tier: T1. RPO ≤ 1 hr, RTO ≤ 8 hr, geo-redundant storage with a **passive** secondary region (no read traffic), semiannual restore drill.
   - Tier rationale: Notify delivery state is customer-impacting (in-flight messages, retry queues) but not regulated/T0 — ADR-0036 D1.
   - Backing inventory:
     - **Notify's durable delivery state.** Identify the live backing — likely a Storage Queue / Service Bus for in-flight + retry queues, and any durable delivery-state store. Record the D2 mechanics:
       - **Service Bus (T1 namespace):** DR via the standard geo-disaster-recovery **alias pairing** — cross-region passive pairing. In-flight messages are NOT guaranteed across a forced failover.
       - **Storage Queue / Storage Blob (if used):** GRS for T1; soft-delete on, 30-day retention; versioning on.
   - Restore procedure: restore the most recent backing-state backup into an ephemeral environment; validate that pending/retry delivery state is recoverable and that `INotificationSender` operates against the restored state.
   - Failover procedure: for the Service Bus namespace, the geo-DR alias failover steps — note this is a manual operator action (ADR-0036 D4) and that in-flight messages may be lost on a forced failover.
   - Tenant-scoped restore: Notify itself is not the multi-tenant commercial surface (that is Notify Cloud); state "Notify is internal/Grid-facing — tenant-scoped restore is a Notify Cloud T0 concern, deferred to the Notify Cloud standup."
   - Cross-Node ordering: note any ordering (Notify depends on Kernel; Service Bus is the ADR-0028 default broker).
   - Drill cadence + last-drill record: semiannual T1 drill; a line linking to `generated/restore-drills/`.
2. **Update `integration-points.md`:**
   - The Service Bus DR posture: T1 namespace uses geo-DR alias pairing; in-flight messages are not failover-durable.
   - The idempotency dependency: ADR-0036 D2 + Operational Consequences make the Service Bus message-loss posture "load-bearing" on the ADR-0042 idempotency contract — Notify's consumers must be idempotent and message-replay-tolerant.

## Affected Files
- `repos/HoneyDrunk.Notify/dr-runbook.md` (new)
- `repos/HoneyDrunk.Notify/integration-points.md`

## NuGet Dependencies
None. This packet touches only Markdown docs; no .NET project is created or modified.

## Boundary Check
- [x] `repos/HoneyDrunk.Notify/` is the Notify Node's context directory inside `HoneyDrunk.Architecture` — correct location for architecture-side runbook docs per ADR-0036 D9.
- [x] No code change in any repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `repos/HoneyDrunk.Notify/dr-runbook.md` exists, follows the packet-02 template, and records Notify as T1 with the correct RPO/RTO/geo/cadence (RPO ≤ 1 hr, RTO ≤ 8 hr, passive secondary, semiannual drill)
- [ ] The runbook's backing inventory records the Service Bus geo-DR alias-pairing posture and notes in-flight messages are not failover-durable
- [ ] The runbook has a restore procedure validating `INotificationSender` against restored delivery state, and a manual failover procedure
- [ ] The runbook explicitly states tenant-scoped restore is a Notify Cloud T0 concern, deferred to the Notify Cloud standup — NOT in scope for the Notify T1 runbook
- [ ] `integration-points.md` records the Service Bus DR posture and the ADR-0042 idempotency dependency
- [ ] The runbook scopes itself to `HoneyDrunk.Notify` only and does not author Notify Cloud DR content

## Human Prerequisites
- [ ] None for authoring the documentation.
- [ ] The executing agent must confirm Notify's live durable backing (Service Bus namespace and/or Storage Queue) from `repos/HoneyDrunk.Notify/` docs or `catalogs/`; if undeterminable, document the likely shape and flag for the operator to confirm.

## Referenced ADR Decisions
**ADR-0036 D1 — Tier 1.** RPO ≤ 1 hr, RTO ≤ 8 hr, geo-redundant storage with a passive secondary (no read traffic), semiannual restore drill. Notify delivery state (in-flight messages, retry queues) is a member.

**ADR-0036 D2 — Backup mechanics, Azure Service Bus.** DR via the standard geo-disaster-recovery alias pairing for T0/T1 namespaces (cross-region passive pairing). In-flight messages are not guaranteed to survive a forced failover; consumers must be idempotent (ADR-0042) and message-replay-tolerant. Storage Blob/Queue: GRS for T1; soft-delete on, 30-day retention; versioning on.

**ADR-0036 D4 — Manual failover.** Failover is manually triggered by the operator per the runbook.

**ADR-0036 Affected Nodes.** "HoneyDrunk.Notify and HoneyDrunk.Notify.Cloud — T1 and T0 respectively; gain runbooks and drill cadence as a Notify Cloud GA prerequisite."

**ADR-0036 Operational Consequences.** "T2 message loss on Service Bus forced failover is accepted policy and depends on the idempotency contract (ADR-0042). The two ADRs are mutually load-bearing." (The same dependency applies to T1 in-flight messages per D2.)

**ADR-0028 — Event-Driven Architecture.** Service Bus is the Grid's default broker, one shared namespace per environment.

## Constraints
> **Invariant 60 (added by packet 00) — every Node holding state has a `dr_tier` assignment in `catalogs/grid-health.json`.** Notify's `dr_tier` is T1 (set in packet 01); the runbook's tier must match the catalog.

- **Notify ≠ Notify Cloud.** This runbook is for `HoneyDrunk.Notify` (T1, the live Ops Node). Notify Cloud's T0 runbook, tenant identity/billing backup, and tenant-scoped restore are out of scope — deferred to the Notify Cloud standup. Do not author Notify Cloud DR content here.
- **In-flight Service Bus messages are not failover-durable** — the runbook must state this plainly; recovery relies on consumer idempotency (ADR-0042), not on message preservation.
- **Confirm the live backing** — do not guess the Service Bus / Storage Queue topology; if undeterminable, document the likely shape and flag.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0036`, `wave-2`

## Agent Handoff

**Objective:** Author the Notify T1 `dr-runbook.md` covering delivery state and the Service Bus geo-DR posture; record the Service Bus DR posture and the ADR-0042 idempotency dependency in `integration-points.md`.

**Target:** `HoneyDrunk.Architecture` (the `repos/HoneyDrunk.Notify/` context directory), branch from `main`. Tracked against the Notify Node.

**Context:**
- Goal: Produce the Notify T1 DR documentation; pin the Service Bus failover posture and its idempotency dependency.
- Feature: ADR-0036 Disaster Recovery rollout, Wave 2.
- ADRs: ADR-0036 (D1/D2/D4 primary), ADR-0028 (Service Bus default broker), ADR-0042 (idempotency — load-bearing for the failover message-loss posture).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — soft. The `dr_tier` field should exist so the runbook's tier is consistent with the catalog.
- `work-item:02` — hard. The template at `generated/dr-runbook.template.md` must exist; this packet fills it in.

**Constraints:**
- This runbook is for `HoneyDrunk.Notify` only — Notify Cloud DR is deferred to the Notify Cloud standup.
- In-flight Service Bus messages are not failover-durable — state plainly.
- Confirm the live backing; flag if undeterminable.

**Key Files:**
- `repos/HoneyDrunk.Notify/dr-runbook.md` (new)
- `repos/HoneyDrunk.Notify/integration-points.md`

**Contracts:** None changed — documentation only.
