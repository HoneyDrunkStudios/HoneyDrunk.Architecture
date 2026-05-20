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

# Chore: Clarify Transport scope in boundaries doc — async commands and durable pub/sub only

## Summary
Update `repos/HoneyDrunk.Transport/boundaries.md` to clarify that Transport is the abstraction layer for **async commands and durable pub/sub only**. Add three explicit out-of-scope items per ADR-0028's "below-the-line" use cases: telemetry signals (Pulse / OTel), CI cron (Actions / GitHub schedules), and reactive resource events (Event Grid system topics). Architecture-repo doc edit only; no code or other catalog touches.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0028's "If Accepted — Required Follow-Up Work" checklist line 2 says:

> Update `repos/HoneyDrunk.Transport/boundaries.md` to clarify that Transport is the abstraction layer for **async commands and durable pub/sub** only — telemetry signals (Pulse), CI cron (Actions), and reactive resource events (Event Grid system topics) are out of Transport's scope

The Transport boundary doc today lists six "What Transport Owns" items and six "What Transport Does NOT Own" items. The "Does NOT Own" list correctly disclaims serialization, business logic, the database outbox store, GridContext, REST/HTTP, and Notify's queue. But it does not yet disclaim three larger surfaces the ADR's matrix walks off the Transport abstraction entirely:

1. **Telemetry signals** — OTel-shaped traces/metrics/logs go through Pulse's OTLP pipeline, not Transport. The conflation "make Pulse a Transport consumer for free observability" is the most-tempting wrong shape in the Grid's messaging surfaces, and the boundary doc should head it off explicitly.
2. **CI cron / scheduled work** — GitHub Actions `schedule:` cron and Container Apps cron-scaler jobs are the right shape for time-triggered work. Adding a queue layer between the schedule and the workflow is rebuilding what the scheduler already provides.
3. **Reactive resource events** — Azure-emitted system events (blob written, secret rotated, image pushed) ride Event Grid system topics, not Transport. There is no Event Grid Transport provider and there will not be one for system topics — the system-topic-to-consumer wiring is portal/Bicep.

The positive form ("async commands and durable pub/sub") and the negative form (three explicit out-of-scope items) together pin what Transport is for, so future Nodes and agents reach for the right tool the first time.

## Scope

Single-file edit. No other repo context files touched. No `catalogs/*.json` edits. No constitution edits. No code.

## Proposed Implementation

### Edits to `repos/HoneyDrunk.Transport/boundaries.md`

The current file is:

```markdown
# HoneyDrunk.Transport — Boundaries

## What Transport Owns

- Message publishing and consumption abstractions
- Middleware pipeline (GridContext propagation → Telemetry → Logging → Handler)
- Immutable transport envelope with correlation/causation tracking
- Transactional outbox abstractions (`IOutboxStore`, `IOutboxDispatcher`)
- Transport-specific health contributors
- Provider implementations (Azure Service Bus, Storage Queue, InMemory)

## What Transport Does NOT Own

- **Message serialization format** — Applications choose serializers
- **Business logic** — Handlers contain business logic, not Transport
- **Database outbox storage** — `IOutboxStore` implementation belongs in HoneyDrunk.Data.Outbox
- **Context model** — GridContext definition belongs in Kernel
- **REST/HTTP** — HTTP-specific concerns belong in Web.Rest
- **Queue-based notifications** — Queue management for notifications belongs in Notify
```

Replace it with:

```markdown
# HoneyDrunk.Transport — Boundaries

## Scope

**Transport is the abstraction layer for async commands and durable pub/sub only.** It is the broker-agnostic surface for messages that cross a Node boundary asynchronously and need delivery, ordering, durability, or per-subscriber fan-out guarantees from the underlying broker.

Below the abstraction: two backings are first-class today — Azure Service Bus (for use cases needing sessions, DLQ, duplicate detection, transactions, or pub/sub topics) and Azure Storage Queue (for high-volume commodity work where ordering doesn't matter and a manual poison-queue pattern is acceptable). InMemory is provided for tests. New backings are added by ADR.

The two messaging shapes Transport serves are:

- **Async commands across Nodes** — one sender, one logical recipient. Backed by a Service Bus queue (sessions when grouped, DLQ on failure) or a Storage Queue (for the cost-sensitive commodity case).
- **Durable pub/sub fanout** — one event, many in-Grid consumers, each wanting per-subscription durability and replay. Backed by a Service Bus topic.

The full use-case → backing matrix lives in `repos/HoneyDrunk.Transport/integration-points.md` (mirrored from ADR-0028 D2).

## What Transport Owns

- Message publishing and consumption abstractions (`ITransportPublisher`, `ITransportConsumer`, `IMessageHandler<T>`)
- Middleware pipeline (GridContext propagation → Telemetry → Logging → Handler)
- Immutable transport envelope with correlation/causation tracking
- Transactional outbox abstractions (`IOutboxStore`, `IOutboxDispatcher`)
- Transport-specific health contributors
- Provider implementations (Azure Service Bus, Storage Queue, InMemory)
- The seam at which a host swaps backings as a host-time composition change, never as a code rewrite

## What Transport Does NOT Own

- **Message serialization format** — Applications choose serializers.
- **Business logic** — Handlers contain business logic, not Transport.
- **Database outbox storage** — `IOutboxStore` implementation belongs in `HoneyDrunk.Data.Outbox`.
- **Context model** — GridContext definition belongs in Kernel.
- **REST/HTTP** — HTTP-specific concerns belong in `HoneyDrunk.Web.Rest`.
- **Queue-based notifications** — Queue management for notifications belongs in `HoneyDrunk.Notify`. Notify intake → Notify worker is an in-Node hop on Notify's own queue abstraction (`HoneyDrunk.Notify.Queue.*`), not a Transport hop. The two queue abstractions coexist by design: Transport for cross-Node, Notify.Queue for in-Node.
- **Telemetry signals (Pulse / OpenTelemetry)** — traces, logs, metrics, errors, and analytics ride OpenTelemetry over OTLP HTTP/gRPC to the Pulse Collector. They do not ride Transport. Pulse is **not** subscribed to Transport topics; Nodes do **not** emit telemetry through Transport. The single Transport hop Pulse uses today (`PulseIngested`, published after a batch lands) is a domain pub/sub event that says "telemetry was ingested" — it is not the telemetry itself. Do not put metrics on Service Bus topics; do not put domain events through OTLP.
- **CI cron / scheduled work** — Time-triggered work (nightly-deps, nightly-security, grid-health aggregator, hive-sync, Vault rotation policy schedule, Lore ingestion) runs on GitHub Actions `schedule:` cron for CI-shaped schedules, or on Container Apps cron-scaler jobs for Node-internal schedules that are too heavy for Actions runners. The scheduler is the broker. Adding a Transport queue between the cron trigger and the workflow runner is rebuilding what the scheduler already provides.
- **Reactive resource events (Azure-emitted system events)** — "this Azure resource changed" events (blob written, Key Vault secret rotated, Container Registry image pushed) ride Event Grid system topics directly to the consumer (Container App webhook, Logic App, or Function). They do not ride Transport, and there is no Event Grid Transport provider for system topics. The Vault rotation cache-invalidation pathway already implicitly relies on this. Event Grid **custom** topics are deferred Grid-wide pending a use case that needs them; Transport does not bridge to custom topics either.

## Decision Test

Before reaching for Transport, ask:

1. Is this a message that crosses a Node boundary asynchronously and needs the broker to guarantee delivery, ordering, or durability? → Transport.
2. Is this an in-Node hop where producer and consumer share a process? → Not Transport. In-process domain events (mediator-style fan-out) or Notify's in-Node queue (for Notify intake → Notify worker) fit.
3. Is this a metric, trace, log, error, or analytics signal? → Not Transport. Pulse OTLP pipeline.
4. Is this a scheduled or time-triggered job? → Not Transport. GitHub Actions cron or Container Apps cron scaler.
5. Is this a reaction to an Azure-emitted resource event? → Not Transport. Event Grid system topic to the consumer directly.

If the answer to #1 is yes, the next question is: does the use case need sessions, DLQ, duplicate detection, or pub/sub topics? If yes → Service Bus. If no → Storage Queue. The backing is a host-time composition choice; the application code consumes `ITransportPublisher` / `ITransportConsumer` regardless.

## No Raw Broker SDK Calls

Even when the chosen backing is Service Bus or Storage Queue, application code calls `ITransportPublisher` / `ITransportConsumer` — never `Azure.Messaging.ServiceBus.ServiceBusClient.SendAsync` or `Azure.Storage.Queues.QueueClient.SendMessageAsync` directly. The abstraction exists so that backing swaps are host-time composition changes, not code rewrites. Direct SDK use from application code is forbidden; the broker SDKs are wrapped only inside the `HoneyDrunk.Transport.*` provider packages.
```

### `CHANGELOG.md` (Architecture repo)

Append to the existing in-progress `## [Unreleased]` section under `### Changed`:

- "Transport boundaries: clarified Transport is the abstraction layer for async commands and durable pub/sub only, with three explicit out-of-scope items per ADR-0028 — telemetry signals (Pulse / OTel), CI cron (Actions / Container Apps scheduled jobs), and reactive resource events (Event Grid system topics). Added a decision-test section and a no-raw-broker-SDK-calls rule."

## Affected Files
- `repos/HoneyDrunk.Transport/boundaries.md` (rewrite — new "Scope" section, expanded "Does NOT Own" list with three new disclaimers, new "Decision Test" section, new "No Raw Broker SDK Calls" section)
- `CHANGELOG.md` (Unreleased entry)

## NuGet Dependencies
None. Architecture is a knowledge repo — no .NET projects.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture` — correct repo per routing rules.
- [x] No code changes anywhere; one markdown doc + CHANGELOG.
- [x] No `catalogs/*.json` edits. No `constitution/*.md` edits. No `adrs/*.md` edits. No other repo context files (Pulse, Communications, Notify, etc.) edited.
- [x] The new "Does NOT Own" items are copies of ADR-0028's decisions in different sections (D3 for telemetry, D2 row 5 for cron, D2 row 6 for Event Grid). The ADR is the source of truth — any deviation is grounds to stop and flag rather than ship.
- [x] The existing six "Does NOT Own" items are preserved; only three new items are added. The six "Owns" items are preserved with one minor expansion (the third sub-bullet referencing the host-time backing-swap seam).

## Acceptance Criteria
- [ ] `repos/HoneyDrunk.Transport/boundaries.md` has a new top-level `## Scope` section at the top of the file (after the H1 title) stating Transport is for async commands and durable pub/sub only, naming the two messaging shapes (async commands, durable pub/sub), and pointing at `integration-points.md` for the full matrix.
- [ ] The "What Transport Owns" section retains all six existing bullets plus one new bullet about the host-time backing-swap seam.
- [ ] The "What Transport Does NOT Own" section retains all six existing bullets and adds three new bullets: telemetry signals (Pulse / OTel), CI cron (Actions / Container Apps cron), and reactive resource events (Event Grid system topics). Each new bullet matches the text in the Proposed Implementation section above.
- [ ] The Notify-queue bullet is expanded to name the in-Node-vs-cross-Node split: Transport for cross-Node, `Notify.Queue.*` for in-Node, and the two coexist by design.
- [ ] A new `## Decision Test` section is added with the five-question checklist matching the Proposed Implementation text.
- [ ] A new `## No Raw Broker SDK Calls` section is added with the rule that application code calls `ITransportPublisher` / `ITransportConsumer`, never `ServiceBusClient.SendAsync` or `QueueClient.SendMessageAsync` directly.
- [ ] `CHANGELOG.md` Unreleased section has the changed-entry described above.
- [ ] No file other than `repos/HoneyDrunk.Transport/boundaries.md` and `CHANGELOG.md` is edited.
- [ ] PR description references this packet (per the PR-to-packet linking invariant inlined below).
- [ ] PR description states explicitly: the three new "Does NOT Own" bullets correspond to ADR-0028's D2 rows 4, 5, and 6 (telemetry, cron, Event Grid) and D3 (signals-vs-events). Any drift from those ADR sections is grounds to stop and flag rather than ship.

## Human Prerequisites
None. This packet is fully delegable; the agent edits one doc file and opens a PR.

## Referenced ADR Decisions

**ADR-0028 D1 (Transport remains the abstraction for cross-Node async messaging):** Transport is not in scope for re-decision. It stays the broker-agnostic abstraction for any message that crosses a Node boundary asynchronously. Below the abstraction, Service Bus and Storage Queue are first-class; InMemory is for tests. The abstraction exists so that backing swaps are host-time composition changes, not code rewrites.

**ADR-0028 D2 (Use-case → backing matrix):** Rows 4 (telemetry), 5 (cron), 6 (reactive resource events), and 7 (in-process domain events) explicitly do **not** ride Transport. Rows 1 (async commands), 2 (pub/sub fanout), and 3 (commodity work queues) do.

**ADR-0028 D3 (Pulse signals are not domain events):** Telemetry signals ride OpenTelemetry over OTLP. Domain events ride Transport. `PulseIngested` is a domain event ("telemetry was ingested for batch X") that happens to be emitted by Pulse — it is not the telemetry. Pulse is not subscribed to Transport topics; Nodes do not emit metrics through Transport.

**ADR-0028 D5 (Service Bus default; one shared namespace per environment):** When use cases #1 and #2 hit production, the backing is Service Bus, with `sbns-hd-shared-{env}` per environment. The reference to "host-time composition" in the new "Owns" bullet is the practical manifestation of D5 — switching from InMemory to Service Bus is a DI change, not a code change.

**ADR-0028 D6 (Event Grid system topics yes; custom topics deferred):** System topics are the only managed channel for Azure-emitted resource events. Custom topics are deferred until a concrete consumer materializes. The new "Reactive resource events" bullet in "Does NOT Own" captures both halves: system topics ride Event Grid (not Transport), and there is no Transport provider for custom topics either.

**ADR-0028 §"New invariants (proposed for `constitution/invariants.md`)":** Two invariants are proposed — "Telemetry signals ride OpenTelemetry; domain events ride Transport" and "Cross-Node async messaging crosses Transport — never raw broker SDK calls." This packet encodes both into the Transport boundary doc (not the constitution — the constitution edit is a separate scope-agent acceptance-time concern out of scope for this initiative). The "No Raw Broker SDK Calls" section in the new boundary doc is the operational form of the second invariant.

## Referenced Invariants

> **Invariant 12:** Semantic versioning with `CHANGELOG.md` and `README.md`. Every shipped change gets an entry in the repo-level changelog. — This packet ships a documentation surface change in the Architecture repo; CHANGELOG entry mandatory.

> **Invariant 23:** Every tracked work item has a GitHub Issue in its target repo. No work tracked exclusively in packet files, chat logs, or external tools.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body. The review agent resolves the packet via this link and uses it as the primary scope anchor. Absent the link, the PR receives a degraded review.

## Dependencies
None. Wave 1 foundational packet; runs in parallel with packets 01 and 03.

## Labels
`chore`, `tier-1`, `docs`, `core`, `adr-0028`

## Agent Handoff

**Objective:** Update `repos/HoneyDrunk.Transport/boundaries.md` to clarify Transport's scope (async commands and durable pub/sub only), expand the "Does NOT Own" list with three new disclaimers (telemetry, cron, Event Grid system topics), add a decision-test checklist, and add a no-raw-broker-SDK-calls rule.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Pin Transport's scope so future Nodes and agents reach for the right tool the first time. The positive form ("async commands and durable pub/sub") and the negative form (three explicit out-of-scope items) together prevent the conflation patterns the ADR explicitly rejects (Pulse-as-Transport-consumer, queue-between-Actions-and-Nodes, custom-topic-everything).
- Feature: ADR-0028 Event-Driven Architecture and Messaging, Wave 1.
- ADR: ADR-0028 (Proposed at edit time; auto-flipped to Accepted by hive-sync after all four packets in this initiative close).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**

- **Invariant 12:** Semantic versioning with `CHANGELOG.md` and `README.md`. Every shipped change gets an entry in the repo-level changelog. This packet ships a documentation surface change; CHANGELOG entry mandatory.

- **Invariant 23:** Every tracked work item has a GitHub Issue in its target repo. No work tracked exclusively in packet files.

- **Invariant 32:** Agent-authored PRs must link to their packet in the PR body. The review agent resolves the packet via this link and uses it as the primary scope anchor.

- **Verbatim ADR alignment.** The three new "Does NOT Own" bullets and the decision-test and no-raw-SDK-calls sections track ADR-0028 D2/D3/D6 directly. The agent does not paraphrase the rules into something looser or stricter; the text in the Proposed Implementation section above is the canonical wording. If the agent reads the live ADR and finds it has been amended after this packet was authored, the agent follows the ADR's live text and notes the divergence in the PR body.

- **Preserve existing bullets.** The six existing "Owns" bullets and six existing "Does NOT Own" bullets are not removed or reworded. Additions only. The one minor expansion permitted is the Notify-queue bullet (existing wording extended to name the in-Node-vs-cross-Node split per D1's "two queue abstractions coexist by design" note).

- **No code.** No `.cs`, `.csproj`, `.json` (other than the existing CHANGELOG which is markdown), or YAML touched.

- **No other context files.** Pulse boundaries, Communications boundaries, Notify boundaries — all out of scope for this packet; they are separate packets in this initiative (Pulse) or future initiatives (Communications, Notify if needed).

- **No initiative or roadmap or constitution edits.** Per the initiative-level direction, `initiatives/active-initiatives.md`, `initiatives/proposed-adrs.md`, `adrs/README.md`, `catalogs/*.json`, and `constitution/invariants.md` are all out of scope for this initiative. The proposed invariants from the ADR's §New Invariants section are noted in the Transport boundary doc's new "No Raw Broker SDK Calls" section but are not added to the constitution by this packet.

**Key Files:**
- `repos/HoneyDrunk.Transport/boundaries.md` — full rewrite per the Proposed Implementation section
- `CHANGELOG.md` — Unreleased section append

**Contracts:** None changed. This is a boundary doc edit; no interface or type surface is touched.
