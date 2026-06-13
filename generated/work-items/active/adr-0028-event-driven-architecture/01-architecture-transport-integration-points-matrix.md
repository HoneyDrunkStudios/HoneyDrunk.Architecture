---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "docs", "core", "adr-0028"]
dependencies: []
adrs: ["ADR-0028"]
accepts: ADR-0028
wave: 1
initiative: adr-0028-event-driven-architecture
node: honeydrunk-architecture
---

# Chore: Add D2 use-case to backing matrix to Transport integration-points

## Summary
Add ADR-0028 D2's use-case → backing matrix verbatim to `repos/HoneyDrunk.Transport/integration-points.md` so the Transport repo's context folder is the authoritative developer-facing reference for "which backing serves which use case" across the Grid. Architecture-repo doc edit only; no code or other catalog touches.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0028's "If Accepted — Required Follow-Up Work" checklist line 1 says:

> Add the use-case → backing matrix (D2 below) to `repos/HoneyDrunk.Transport/integration-points.md` so the Transport repo is the authoritative reference for "which backing for which use case"

The Transport repo's `integration-points.md` currently lists only the upstream Kernel dependency and three downstream consumers (Web.Rest, Data, Notify) — it has no surface for the higher-order question "for which Grid use case is Transport the right tool, and which backing does it use?" That question is answered exhaustively in ADR-0028 D2's seven-row matrix, but the ADR lives in the Architecture repo and is not where a Transport-consuming agent looks first.

This packet copies the D2 matrix into the Transport-repo-side context file the Grid uses for cross-Node integration discovery. The ADR remains the source of truth (the matrix is opinionated and any revision is an ADR-amendment event); the Transport context file becomes the developer-facing reference. This is exactly the pattern the ADR §Consequences names: "the matrix lives in this ADR (the source of truth) and is mirrored into `repos/HoneyDrunk.Transport/integration-points.md` (the developer-facing reference)."

## Scope

Single-file edit. No other repo context files touched. No `catalogs/*.json` edits. No constitution edits. No code.

## Proposed Implementation

### Edits to `repos/HoneyDrunk.Transport/integration-points.md`

Append a new top-level section after the existing "Downstream Consumers" table. The section is the D2 matrix verbatim, with a brief framing paragraph and a closing note about source-of-truth.

The current file (as of this packet's edit time) is:

```markdown
# HoneyDrunk.Transport — Integration Points

## Upstream Dependencies

| Node | Contract | Usage |
|------|----------|-------|
| **Kernel** | `HoneyDrunk.Kernel.Abstractions` | `IGridContext`, `CorrelationId`, context mappers |

## Downstream Consumers

| Node | What It Uses | How |
|------|-------------|-----|
| **Web.Rest** | `ITransportEnvelope` | Maps envelope to ApiResult |
| **Data** | `ITransportPublisher` | Outbox dispatcher publishes via Transport |
| **Notify** | Transport patterns | Follows envelope and middleware patterns |
```

After the "Downstream Consumers" table, append:

```markdown
## Use-Case → Backing Matrix

This matrix mirrors ADR-0028 D2 — the Grid-wide use-case → backing matrix. The ADR is the source of truth; this section is the developer-facing reference. New rows are added by follow-up ADRs that name a use case the matrix does not currently cover.

Transport is the abstraction layer for use cases that fit it (#1, #2, #3 below). Use cases #4 (telemetry), #5 (cron), #6 (reactive resource events), and #7 (in-process domain events) do **not** ride Transport — they are listed here so the matrix is exhaustive and so the boundary between Transport and the alternative backings is visible from one place.

| # | Use Case | Primary Backing | Ordering | Durability | Idle Cost | Why this backing |
|---|---|---|---|---|---|---|
| 1 | Async commands across Nodes (one sender, one logical recipient — e.g. Flow workflow engine async step boundaries, Communications → Notify post-split **(currently in-process per D4; Service Bus when split)**, long-running Container App hand-offs from Actions; Action-to-Action coordination stays GitHub-native) | **Azure Service Bus queue** via `HoneyDrunk.Transport.AzureServiceBus` | FIFO with sessions when grouped; otherwise best-effort | Durable; dead-letter queue native; duplicate detection native | ~$10/mo Standard tier per namespace (one shared namespace per environment, not per use case) | Sessions, DLQ, duplicate detection, transactions — none of which Storage Queue offers — are all relevant to "send this command exactly once, in order if grouped, with a recovery surface when it fails." |
| 2 | Pub/sub fanout (one event, many in-Grid consumers — e.g. Pulse `PulseIngested`, future `UserSignedUp`-style domain events with welcome-email + analytics + provisioning consumers) | **Azure Service Bus topic** via `HoneyDrunk.Transport.AzureServiceBus` (same namespace as #1) | Per-subscription FIFO with sessions | Durable per subscription; per-subscription DLQ | Shared namespace cost from #1 — topics are free incremental | Service Bus topics give per-subscriber durability and DLQ. Event Grid (row 6) is the wrong shape here — Event Grid is best for *infrastructure* events (blob written, secret rotated), not for in-Grid domain pub/sub where consumers want guaranteed delivery and replay. |
| 3 | High-volume commodity work queues (notification dispatch, batch background work — e.g. Notify intake → Notify worker, Notify Cloud `BillingEvent` → Stripe webhook bridge) | **Azure Storage Queue** via `HoneyDrunk.Transport.StorageQueue` | Best-effort, no FIFO | Durable; manual poison-queue pattern (no built-in DLQ) | Cents per month at the Grid's volume (10K ops = $0.0004) | When the workload is "many small messages, ordering doesn't matter, transient failures retry up to N times then go to a poison queue I write myself," Storage Queue is two orders of magnitude cheaper than Service Bus and the feature gap doesn't matter. |
| 4 | High-volume telemetry / observability signals (Pulse OTLP ingest path) | **Direct OTLP via HTTP/gRPC, then Pulse Collector → backends (Tempo, Loki, Mimir, Sentry, PostHog, Azure Monitor)** | None — best-effort | Best-effort, sink-by-sink failure isolation | Pay-per-ingestion to backends; no broker between Node and Pulse Collector | Telemetry is **not a domain event**. It rides OpenTelemetry, not Transport. The single Transport hop Pulse uses today (`PulseIngested` after a batch lands) is a domain pub/sub event that says "telemetry ingested," not the telemetry itself. |
| 5 | Scheduled / time-triggered work (cron — nightly-deps, nightly-security, grid-health aggregator, hive-sync, Vault rotation policy schedule, Lore ingestion) | **GitHub Actions `schedule:` cron** for CI-shaped schedules; **Azure Container Apps scheduled jobs** (KEDA cron scaler) for Node-internal schedules where the workload is too heavy for Actions runners | Per-trigger; no message ordering concern | The scheduler retries on the next trigger | Free at the Grid's volume — Actions minutes are free for public repos; Container Apps cron jobs scale to zero between triggers | Cron is not a queue. The scheduler **is** the broker. Adding Service Bus or Event Grid between "the schedule fired" and "the work runs" is rebuilding cron's job. |
| 6 | Reactive resource events (Azure-emitted system events — blob written, Key Vault secret rotated, Container Registry image pushed — and any future Grid-internal "something changed" event a system topic can publish) | **Azure Event Grid system topics**; custom topics are deferred until a concrete consumer materializes | Best-effort, at-least-once | Durable retry up to 24h, then dead-lettered to Storage | Pay-per-event ($0.60/M events at Basic tier); zero idle cost | Event Grid is the only Azure surface that emits secret-rotated, blob-written, image-pushed events as a managed system topic. The Vault rotation cache-invalidation pathway already implicitly relies on it. |
| 7 | In-process / same-Node domain events (mediator-style command/handler decoupling within a single Node — e.g. `IMessageIntent` resolution → preference check → cadence check → send delegation, all within Communications) | **In-process MediatR-style or simple `IServiceProvider.GetService<IDomainEventHandler>` fan-out** — not Transport, not a broker | N/A — synchronous in-process | N/A — no durability needed; failure is a thrown exception | Zero | If sender and receiver share a process and a transaction, putting a broker between them adds latency, failure modes, and cost for nothing. |

Use cases #5 (cron) and #7 (in-process) **do not use Transport**. Use case #4 (Pulse telemetry) uses OpenTelemetry, not Transport, except for the single `PulseIngested` domain pub/sub event which rides Transport per row #2. Use cases #1, #2, #3, and #6 are the four genuinely-event-driven backings the Grid commits to; of those, #6 (Event Grid system topics) is reached *outside* the Transport abstraction (Event Grid does not have a Transport provider; the system-topic-to-consumer wiring is portal/Bicep, not `ITransportPublisher`).

### Dead-Letter Strategy

Per ADR-0028 D2 row 8 (dead-letter handling): the strategy is per-backing, not Grid-wide. Service Bus has native DLQ for use cases #1 and #2; Storage Queue uses a manual poison-queue convention for use case #3; Event Grid dead-letters to Storage with a configured destination for use case #6.

### Outbox Bridge

For any use case where a database commit and a Transport publish must be atomic, `HoneyDrunk.Data.Outbox` is the standard bridge. Direct publishes from inside a database transaction are forbidden (no rollback path if the transaction commits and the publish fails or vice versa). The outbox writes the message into the same database transaction; `IOutboxDispatcher` polls and publishes asynchronously with at-least-once delivery semantics.

### Service Bus Namespace

One shared namespace per environment (`sbns-hd-shared-{env}` for `dev`/`stg`/`prod`), Standard tier, ~$10/mo per environment. Per-Node namespaces are rejected for the same reasons per-Node Container Apps Environments are rejected: namespace is not a security boundary (Managed Identity scopes per queue/topic), per-namespace cost is fixed, and a shared namespace simplifies cross-Node observability. Naming: queues are `sbq-{purpose}-{env}` (e.g. `sbq-notify-cloud-billing-stg`); topics are `sbt-{purpose}-{env}` with subscriptions named after the consumer Node.

Provisioning is just-in-time — the namespace is not provisioned until the first cross-Node async pub/sub consumer ships. `PulseIngested` is published today but has no consumers, so the namespace creation defers until the first real consumer lands.

### Source of Truth

If this section ever drifts from ADR-0028 D2, the ADR wins. New rows are added by follow-up ADRs that name a use case the current matrix does not cover.
```

### `CHANGELOG.md` (Architecture repo)

Append to the existing in-progress `## [Unreleased]` section under `### Changed`:

- "Transport context: added the use-case → backing matrix from ADR-0028 D2 to `repos/HoneyDrunk.Transport/integration-points.md` so the Transport repo is the authoritative developer-facing reference for which backing serves which Grid use case."

## Affected Files
- `repos/HoneyDrunk.Transport/integration-points.md` (append the new "Use-Case → Backing Matrix" section after "Downstream Consumers")
- `CHANGELOG.md` (Unreleased entry)

## NuGet Dependencies
None. Architecture is a knowledge repo — no .NET projects.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture` — correct repo per routing rules (architecture/ADR/catalog/repo-context files belong in this repo).
- [x] No code changes anywhere; one markdown doc + CHANGELOG.
- [x] No `catalogs/*.json` edits. No `constitution/*.md` edits. No `adrs/*.md` edits. No other repo context files (Pulse, Communications, Notify, etc.) edited — those are separate packets in this initiative.
- [x] The matrix is copied verbatim from the ADR's D2 section. No edits to the matrix content itself — the ADR is the source of truth.

## Acceptance Criteria
- [ ] `repos/HoneyDrunk.Transport/integration-points.md` carries a new top-level section `## Use-Case → Backing Matrix` after the existing "Downstream Consumers" table.
- [ ] The matrix in that section has all seven rows verbatim from ADR-0028 D2 (use cases #1 through #7; row #8 from the ADR's dead-letter row is captured in the prose "Dead-Letter Strategy" subsection instead of as a matrix row to keep the use-case axis clean).
- [ ] The section includes the "Use cases #5 and #7 do not use Transport" disambiguation paragraph and the "Source of Truth" closing paragraph naming ADR-0028 as the source.
- [ ] The section includes the Outbox-bridge, Service-Bus-namespace, and dead-letter-strategy paragraphs that capture D5, D8, and D9 of the ADR (these are operational notes the matrix alone does not convey).
- [ ] No other section of `repos/HoneyDrunk.Transport/integration-points.md` is edited. The existing "Upstream Dependencies" and "Downstream Consumers" tables are byte-for-byte unchanged.
- [ ] No other file in `repos/HoneyDrunk.Transport/` is edited (this packet touches only `integration-points.md`).
- [ ] `CHANGELOG.md` Unreleased section has the changed-entry described above.
- [ ] PR description references this packet (per the invariant on PR-to-packet linking, inlined below).
- [ ] PR description confirms the matrix matches ADR-0028 D2 verbatim — any deviation is grounds to stop and flag rather than ship.

## Human Prerequisites
None. This packet is fully delegable; the agent edits one doc file and opens a PR.

## Referenced ADR Decisions

**ADR-0028 D1 (Transport remains the abstraction):** `HoneyDrunk.Transport` is the broker-agnostic abstraction for any message that crosses a Node boundary asynchronously. Below the abstraction, two backings are first-class today (Service Bus, Storage Queue) and one (InMemory) for tests. This ADR pins which backing Transport uses for which Grid use case and which use cases bypass Transport entirely.

**ADR-0028 D2 (Use-case → backing matrix):** The load-bearing matrix copied into this packet. Each row is a Grid use case with a primary backing, ordering/durability properties, cost posture, and a one-sentence justification.

**ADR-0028 D5 (Service Bus default broker; one shared namespace per environment):** `sbns-hd-shared-{env}` for `dev`/`stg`/`prod`, Standard tier, queues `sbq-{purpose}-{env}`, topics `sbt-{purpose}-{env}` with consumer-Node-named subscriptions. Provisioning is just-in-time — the namespace is not created until the first cross-Node async pub/sub consumer ships.

**ADR-0028 D8 (Dead-letter strategy is per-backing):** Service Bus native DLQ for #1/#2; Storage Queue manual poison-queue for #3; Event Grid dead-letter-to-Storage for #6.

**ADR-0028 D9 (Outbox is the bridge for committing-then-publishing):** `HoneyDrunk.Data.Outbox` is the only correct pattern for atomic database-commit + Transport-publish. Direct publishes from inside a database transaction are forbidden.

**ADR-0028 §Consequences (mirroring rule):** "the matrix lives in this ADR (the source of truth) and is mirrored into `repos/HoneyDrunk.Transport/integration-points.md` (the developer-facing reference)." This packet is that mirror.

## Dependencies
None. Wave 1 foundational packet; runs in parallel with packets 02 and 03.

## Labels
`chore`, `tier-1`, `docs`, `core`, `adr-0028`

## Agent Handoff

**Objective:** Add the ADR-0028 D2 use-case → backing matrix to `repos/HoneyDrunk.Transport/integration-points.md`, plus the operational notes (Service Bus namespace, dead-letter strategy, Outbox bridge, source-of-truth pointer), so the Transport repo context folder is the developer-facing reference for which backing serves which Grid use case.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Mirror the ADR's matrix into the Transport-repo-side context file so cross-Node messaging questions resolve from the Transport repo, not by hunting in the Architecture repo's ADR folder.
- Feature: ADR-0028 Event-Driven Architecture and Messaging, Wave 1.
- ADR: ADR-0028 (Proposed at edit time; auto-flipped to Accepted by hive-sync after all four packets in this initiative close).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**

- **Invariant 12:** Semantic versioning with `CHANGELOG.md` and `README.md`. Breaking changes bump major; new features bump minor; fixes bump patch. Every repo must have a repo-level `CHANGELOG.md`; every shipped change gets an entry. This packet ships a documentation surface change in the Architecture repo — `CHANGELOG.md` entry mandatory.

- **Invariant 23:** Every tracked work item has a GitHub Issue in its target repo. No work tracked exclusively in packet files, chat logs, or external tools. This packet files as an issue against `HoneyDrunk.Architecture` once the manifest picks it up.

- **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Pre-filing amendments to fill in missing operational context (NuGet deps, key files, constraints) are permitted; post-filing corrections require a new packet.

- **Invariant 32:** Agent-authored PRs must link to their packet in the PR body. The review agent resolves the packet via this link and uses it as the primary scope anchor. Absent the link, the PR receives a degraded review.

- **Verbatim matrix.** The D2 matrix in this packet is the canonical text. The agent does not paraphrase, reorder rows, drop columns, or add new rows — those changes would be drift from the ADR. If the agent reads the live ADR file and finds a difference from the matrix text in this packet (the ADR may have been amended after this packet was authored), the agent follows the **ADR's live text** and notes the divergence in the PR body. The ADR wins.

- **Stay narrow — append-only.** The existing "Upstream Dependencies" and "Downstream Consumers" tables in `integration-points.md` are not edited. No other Transport-context-folder file is touched. No `catalogs/*.json`, no `constitution/*.md`, no `adrs/*.md`, no other repo's context files.

- **No code.** No `.cs`, `.csproj`, `.json` (other than the existing CHANGELOG which is markdown), or YAML touched. This is an Architecture-repo doc edit only.

- **No initiative or roadmap edits.** Per the initiative-level direction, `initiatives/active-initiatives.md`, `initiatives/proposed-adrs.md`, `adrs/README.md`, and `catalogs/*.json` are all out of scope for this initiative.

**Key Files:**
- `repos/HoneyDrunk.Transport/integration-points.md` — append the new "Use-Case → Backing Matrix" section after "Downstream Consumers"
- `CHANGELOG.md` — Unreleased section append

**Contracts:** None changed. This is a doc-mirror edit; no interface or type surface is touched.
