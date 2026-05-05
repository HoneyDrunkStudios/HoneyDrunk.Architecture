# ADR-0028: Event-Driven Architecture and Messaging — Use-Case-First Backing Selection

**Status:** Proposed
**Date:** 2026-05-04
**Deciders:** HoneyDrunk Studios
**Sector:** Core (Transport) · Ops (Communications, Notify, Pulse, Actions) · cross-cutting

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Add the use-case → backing matrix (D2 below) to `repos/HoneyDrunk.Transport/integration-points.md` so the Transport repo is the authoritative reference for "which backing for which use case"
- [ ] Update `repos/HoneyDrunk.Transport/boundaries.md` to clarify that Transport is the abstraction layer for **async commands and durable pub/sub** only — telemetry signals (Pulse), CI cron (Actions), and reactive resource events (Event Grid system topics) are out of Transport's scope
- [ ] Update `repos/HoneyDrunk.Pulse/boundaries.md` to add the "Pulse signals are not domain events" disambiguation introduced in D3
- [ ] Add a follow-up packet against Communications to specify the concrete `INotificationSender` → `INotifyQueueWriter` boundary and confirm that Communications dispatches to Notify in-process (not via Transport) — D4 settles the principle; the implementation packet wires it
- [ ] Update `catalogs/contracts.json` if `IEventPublisher` (custom-topic shape, deferred per D6) gains a concrete contract in a future implementation packet — not at this ADR's acceptance
- [ ] Scope agent flips Status → Accepted after the Transport repo's integration-points and boundaries reflect this ADR

## Context

The Grid has accumulated several messaging-shaped surfaces over the last fourteen ADRs without a single decision document explaining **which backing serves which use case**. The shapes that exist today, audited at the time of this ADR:

1. **`HoneyDrunk.Transport`** — a transport-agnostic abstraction (`ITransportPublisher`, `ITransportConsumer`, `IMessageHandler<T>`) with three working providers (Azure Service Bus, Azure Storage Queue, InMemory), a middleware pipeline, GridContext propagation, transactional outbox contracts, and blob fallback. **Transport is not a backing — it is the abstraction over backings.** It already enumerates Service Bus vs. Storage Queue trade-offs in its README. v0.1.0 ships.
2. **`HoneyDrunk.Notify.Queue.*`** — Notify's *own* queue abstraction, separate from Transport, with `Queue.Abstractions`, `Queue.AzureStorage`, and `Queue.InMemory` packages. The Transport boundaries doc explicitly disclaims this surface: "Queue-based notifications — Queue management for notifications belongs in Notify." Notify intake → Notify worker is an internal queue, not a Transport hop.
3. **`HoneyDrunk.Pulse` + `PulseIngested` Transport event** — Pulse already publishes a `PulseIngested` Transport event after each ingestion batch, treating Transport as the downstream signal fanout channel. This is the one production event in the Grid that cleanly fits Transport's pub/sub shape today, and it predates this ADR.
4. **`HoneyDrunk.Data.Outbox`** — a transactional outbox that bridges database commits to Transport publishes. Already implemented; the seam where domain commits become outgoing messages.
5. **`HoneyDrunk.Communications` (Proposed, ADR-0019)** — sits above Notify and orchestrates outbound messaging. The Communications → Notify hop is the single most-trafficked cross-Node messaging seam the Grid is about to ship. Where it lives — in-process call, Transport hop, Service Bus topic — has not been decided.
6. **`HoneyDrunk.Actions`** — CI/CD control plane (ADR-0012). Schedules nightly-deps, nightly-security, grid-health aggregator, and the hive-sync loop via `cron:`. None of those use Transport, Service Bus, or Event Grid; the schedule lives in GitHub Actions itself.
7. **Lore ingestion two-stage workflow** — daily OpenClaw sourcing into `raw/`, weekly Claude skill ingests `raw/` → `wiki/`. Cron-driven; no broker today.
8. **Vault rotation cache invalidation (ADR-0006)** — relies on Event Grid for secret-version-changed reactive events. Event Grid is mentioned in Invariant 21 ("pinning breaks Event Grid cache invalidation") but the system-topic plumbing is referenced, not formally decided as a Grid pattern.
9. **Notify Cloud (ADR-0027)** — emits `BillingEvent` per delivery; the Stripe billing adapter writes to "an Azure Storage queue that a Stripe webhook bridge consumes" per ADR-0026 D6. That decision is implicit in the consumer-Node ADRs but never elevated to a Grid pattern.

The Grid's hosting platform (ADR-0015) is **Azure Container Apps**, which has native KEDA scalers for Service Bus, Event Grid, and Storage Queues. Container App revisions can scale-to-zero on Service Bus queue depth, Event Grid event arrival, or Storage Queue length. That changes the operational calculus: a Service Bus topic is no longer "another running thing" — it is a scaler input that lets a Container App stay at zero replicas until a message arrives.

The user's prompt scopes this ADR carefully: **use cases first, mechanism second.** Different patterns warrant different backings. A blanket "the Grid uses Service Bus" decision would over-spend on a workload that fits a Storage Queue (cents/month) and under-spend on a workload that needs Event Grid's pub/sub fanout. The specific question this ADR answers is: **for each event-driven use case the Grid has today or is about to have, which backing is the right default, and why.**

This ADR does **not** replace Transport. Transport stays the abstraction for the use cases where async messaging crosses a Node boundary. This ADR pairs use cases with backings *underneath* the Transport abstraction (Service Bus, Storage Queue) or *outside* it (Event Grid, in-process MediatR-style, GitHub Actions cron, direct HTTP) where Transport is the wrong shape.

## Decision

The Grid does not have one event-driven backing — it has **six**, each chosen for the use case it serves best. The decisions below are the use-case → backing matrix and the rules for picking among them.

### D1. Transport remains the abstraction for cross-Node async messaging — not a backing decision

`HoneyDrunk.Transport` is not in scope for re-decision. It stays the broker-agnostic abstraction for any message that crosses a Node boundary asynchronously. Below the abstraction, two backings are first-class today (Service Bus, Storage Queue) and one (InMemory) for tests. This ADR does not add or remove providers; it pins **which backing Transport uses for which Grid use case**, and which use cases bypass Transport entirely.

The principle: every use case picks a backing on its own merits. Transport is the abstraction *for the use cases that fit it*, not a forced front for every messaging concern.

### D2. Use-case → backing matrix

This is the load-bearing table. Each row is a Grid use case enumerated from the Context audit, with a primary backing, ordering/durability properties, cost posture, and a one-sentence justification.

| # | Use Case | Primary Backing | Ordering | Durability | Idle Cost | Why this backing |
|---|---|---|---|---|---|---|
| 1 | Async commands across Nodes (one sender, one logical recipient — e.g. Flow workflow engine async step boundaries per ADR-0024, Communications → Notify post-split (currently in-process per D4; Service Bus when split), long-running Container App hand-offs from Actions per D8 (Action-to-Action coordination stays GitHub-native)) | **Azure Service Bus queue** via `HoneyDrunk.Transport.AzureServiceBus` | FIFO with sessions when grouped; otherwise best-effort | Durable; dead-letter queue native; duplicate detection native | ~$10/mo Standard tier per namespace (one shared namespace per environment, not per use case) | Sessions, DLQ, duplicate detection, transactions — none of which Storage Queue offers — are all relevant to "send this command exactly once, in order if grouped, with a recovery surface when it fails." |
| 2 | Pub/sub fanout (one event, many in-Grid consumers — e.g. Pulse `PulseIngested`, future `UserSignedUp`-style domain events with welcome-email + analytics + provisioning consumers) | **Azure Service Bus topic** via `HoneyDrunk.Transport.AzureServiceBus` (same namespace as #1) | Per-subscription FIFO with sessions | Durable per subscription; per-subscription DLQ | Shared namespace cost from #1 — topics are free incremental | Service Bus topics give per-subscriber durability and DLQ. Event Grid (D6) is the wrong shape here — Event Grid is best for *infrastructure* events (blob written, secret rotated), not for in-Grid domain pub/sub where consumers want guaranteed delivery and replay. |
| 3 | High-volume commodity work queues (notification dispatch, batch background work — e.g. Notify intake → Notify worker, Notify Cloud `BillingEvent` → Stripe webhook bridge) | **Azure Storage Queue** via `HoneyDrunk.Transport.StorageQueue` (Notify Cloud's billing path uses Storage Queue per ADR-0026 D6 implicit decision; this ADR pins the pattern) | Best-effort, no FIFO | Durable; manual poison-queue pattern (no built-in DLQ) | Cents per month at the Grid's volume (10K ops = $0.0004) | When the workload is "many small messages, ordering doesn't matter, transient failures retry up to N times then go to a poison queue I write myself," Storage Queue is two orders of magnitude cheaper than Service Bus and the feature gap doesn't matter. |
| 4 | High-volume telemetry / observability signals (Pulse OTLP ingest path) | **Direct OTLP via HTTP/gRPC, then Pulse Collector → backends (Tempo, Loki, Mimir, Sentry, PostHog, Azure Monitor)** | None — best-effort | Best-effort, sink-by-sink failure isolation | Pay-per-ingestion to backends; no broker between Node and Pulse Collector | Telemetry is **not a domain event**. It rides OpenTelemetry, not Transport. The single Transport hop Pulse uses today (`PulseIngested` after a batch lands) is a domain pub/sub event that says "telemetry ingested," not the telemetry itself. D3 disambiguates. |
| 5 | Scheduled / time-triggered work (cron — nightly-deps, nightly-security, grid-health aggregator, hive-sync, Vault rotation policy schedule, Lore ingestion) | **GitHub Actions `schedule:` cron** for CI-shaped schedules; **Azure Container Apps scheduled jobs** (KEDA cron scaler) for Node-internal schedules where the workload is too heavy for Actions runners | Per-trigger; no message ordering concern | The scheduler retries on the next trigger | Free at the Grid's volume — Actions minutes are free for public repos; Container Apps cron jobs scale to zero between triggers | Cron is not a queue. The scheduler **is** the broker. Adding Service Bus or Event Grid between "the schedule fired" and "the work runs" is rebuilding cron's job. Lore's two-stage flow stays cron-driven (D7). |
| 6 | Reactive resource events (Azure-emitted system events — blob written, Key Vault secret rotated, Container Registry image pushed — and any future Grid-internal "something changed" event a system topic can publish) | **Azure Event Grid system topics** for Azure-resource-emitted events; **Azure Event Grid custom topics deferred** until a concrete consumer materializes | Best-effort, at-least-once | Durable retry up to 24h, then dead-lettered to Storage | Pay-per-event ($0.60/M events at Basic tier); zero idle cost | Event Grid is the only Azure surface that emits secret-rotated, blob-written, image-pushed events as a managed system topic. The Vault rotation cache-invalidation pathway already implicitly relies on it (Invariant 21). Custom topics are deferred (D6) — no Grid-internal use case justifies the operational weight today. |
| 7 | In-process / same-Node domain events (mediator-style command/handler decoupling within a single Node — e.g. `IMessageIntent` resolution → preference check → cadence check → send delegation, all within Communications) | **In-process MediatR-style or simple `IServiceProvider.GetService<IDomainEventHandler>` fan-out** — not Transport, not a broker | N/A — synchronous in-process | N/A — no durability needed; failure is a thrown exception | Zero | If sender and receiver share a process and a transaction, putting a broker between them adds latency, failure modes, and cost for nothing. The "make it async to be safe" instinct is wrong when the work is synchronous by domain. |
| 8 | Dead-letter / poison-message handling | **Service Bus native DLQ** for use cases #1, #2; **manual poison-queue pattern** for use case #3 (Storage Queue); **Event Grid dead-lettering to Storage** for use case #6 | Per-backing | Per-backing | Negligible | Dead-letter strategy is per-backing, not Grid-wide. Service Bus has it native; Storage Queue does not and a poison-queue convention substitutes; Event Grid dead-letters to Storage with a configured destination. |

Use cases #5 (cron) and #7 (in-process) **do not use Transport**. Use case #4 (Pulse telemetry) uses OpenTelemetry, not Transport, except for the single `PulseIngested` domain pub/sub event which rides Transport per #2. Use cases #1, #2, #3, and #6 are the four genuinely-event-driven backings the Grid commits to.

### D3. Pulse signals are not domain events — explicit disambiguation

This is the single most-conflated concept the Grid's existing surfaces blur. Pulse is observability — traces, logs, metrics, errors, analytics. Domain events are facts about the business — `UserSignedUp`, `OrderShipped`, `BillingEventEmitted`. The two are not interchangeable backings, and this ADR pins the rule:

- **Telemetry signals ride OpenTelemetry over the OTLP wire format.** Nodes emit traces/metrics/logs to the Pulse Collector via HTTP or gRPC. The Pulse Collector fans out to backends (Tempo, Loki, Mimir, Sentry, PostHog, Azure Monitor). No Transport hop, no Service Bus topic, no Event Grid involvement. The pipeline already works.
- **Domain events ride Transport.** `PulseIngested` is a domain event ("telemetry was ingested for batch X") that happens to be emitted by Pulse — it is *not* the telemetry. It rides Transport per use case #2 above.
- **Pulse never receives domain events as a consumer.** Pulse observes; it does not subscribe. If a Node wants Pulse to see something, it emits a span / metric / log via the existing OTel pipeline, not a Transport message.

The negative form: do not put metrics on Service Bus topics. Do not put domain events through OTLP. Do not subscribe Pulse to Transport topics to "make it learn what happened." The two channels are intentionally separate and stay separate.

`repos/HoneyDrunk.Pulse/boundaries.md` already lists "Transport — Message publishing for events belongs in Transport" under "What Pulse Does NOT Own." This ADR's follow-up extends that to the explicit signals-vs-events sentence.

### D4. Communications → Notify is in-process at v1, Service Bus when scale demands it

The most-trafficked cross-Node messaging seam the Grid is about to ship is `ICommunicationOrchestrator` → `INotificationSender`. ADR-0019 D5 made Communications take a first-class runtime dependency on `HoneyDrunk.Notify.Abstractions` — meaning the call is in-process by default, not over a broker. This ADR confirms that decision against the use-case matrix:

- **At v1 (single Container App per Node, low/bursty traffic), the call is in-process.** Communications resolves intent, checks preferences and cadence, then synchronously invokes Notify's `INotificationSender`. Notify's *own internal* queue (Notify intake → Notify worker, use case #3) is the first async hop. This matches the existing design and the behavior Notify already ships.
- **The seam to Service Bus opens when Notify Cloud's tier ceiling pressures it.** PDR-0002 names tens of paying tenants at v1 and low hundreds at the Pro ceiling. If Notify Cloud sustains a load where Communications and Notify benefit from being independently scaled — different replica counts, different Container Apps — the path is to introduce a Service Bus queue between them via the existing `ITransportPublisher` / `ITransportConsumer` abstraction. **Communications already composes Transport in its planned dependencies** (Communications → Transport is implied by orchestration over a queue); the abstractions are in place. The change is a host-time composition, not a code rewrite.
- **Notify Cloud's external API → Communications is also in-process at v1.** The whole Notify Cloud Container App composes Notify Cloud + Communications + Notify in the same process. The split-by-Container-App question is deferred to a future ADR if the v1 deployment shows scaling pressure.

This is the "no eventing — direct call" choice for use case #1's Communications-shaped subset. It is not a permanent decision; it is the right choice at the Grid's current scale, with a known migration path through Transport when scale demands it.

### D5. Service Bus is the default broker; one shared namespace per environment

When use cases #1 and #2 hit production, the backing is Service Bus, and the namespace shape is shared per environment (consistent with ADR-0015's shared Container Apps Environment and shared ACR per environment):

- **`sbns-hd-shared-{env}`** — one Service Bus namespace per environment (`dev`, `stg`, `prod`). All Grid-internal queues and topics live in this namespace.
- **Tier:** Standard for all environments at v1 (~$10/mo per namespace per environment). Premium is rejected — its features (dedicated capacity, geo-DR, larger message size) do not apply at the Grid's scale and would multiply cost ~10x.
- **Naming:** queues are `sbq-{purpose}-{env}` (e.g. `sbq-notify-cloud-billing-stg`); topics are `sbt-{purpose}-{env}` with subscriptions named after the consumer Node (e.g. `sbt-pulse-ingested-stg/sub-analytics`).
- **Per-Node namespace rejected.** Same logic as ADR-0015's per-Node-environment rejection: namespace is not a security boundary (Managed Identity scopes per queue/topic), namespaces have a fixed per-namespace cost, and a shared namespace simplifies cross-Node observability. If a single Node ever generates enough traffic to warrant its own namespace, that's a future ADR — not the v1 default.

The cost posture: at the Grid's current scale, the namespace itself costs ~$10/mo per environment (so ~$30/mo across `dev`/`stg`/`prod`); message volume is well within the Standard tier's included throughput. This is the price of having pub/sub topics at all — Storage Queue does not offer them. For use cases where pub/sub is not needed (use case #3), Storage Queue at cents/month remains the right choice.

**Provisioning is just-in-time.** Per memory ("provision Azure resources when first needed"), the namespace is not provisioned until the **first cross-Node async pub/sub consumer ships** — which may or may not coincide with Pulse Collector's deploy. `PulseIngested` is published today but has no subscribers; if Pulse Collector ships with no `PulseIngested` consumers, it can run with the `InMemory` Transport provider in non-prod and the namespace creation defers further. The trigger is "first real consumer," not "first publisher." When that consumer lands, the namespace is shared across all use cases #1 and #2 in that environment, holding the cost figure (~$10/mo per environment, ~$30/mo across `dev`/`stg`/`prod`).

### D6. Event Grid custom topics deferred — system topics only at v1

Event Grid has two surfaces: **system topics** (Azure emits — secret rotated, blob written, image pushed) and **custom topics** (you publish — your own events).

- **System topics are accepted at v1.** They are the only mechanism that delivers Azure-emitted reactive events. The Vault rotation cache-invalidation flow already implicitly depends on Event Grid system topics (Invariant 21). This ADR pins the pattern: when a Grid-internal flow needs to react to an Azure-resource event, the wiring is Event Grid system topic → consumer (Container App via webhook, Logic App, or Function). No Transport, no Service Bus.
- **Custom topics are deferred.** No Grid-internal use case today justifies the cost of "publish your own event to Event Grid" over the Service Bus topic alternative (use case #2). Service Bus topics give durable per-subscription delivery; Event Grid custom topics are at-most-once-with-retry and route by event-type filter, which is the wrong shape for in-Grid domain events. If a future use case emerges where Event Grid's filter/fanout-to-disparate-consumers shape is genuinely needed (e.g. webhook fanout to external customer endpoints), it gets its own follow-up ADR. Until then, custom topics are not provisioned.

### D7. Lore ingestion stays cron, not event-driven

The Lore two-stage workflow — daily OpenClaw sourcing into `raw/`, weekly Claude skill ingests `raw/` → `wiki/` — is a candidate for event-driven (e.g. `raw/` blob write → Event Grid → ingest trigger). This ADR rejects that conversion at v1:

- **The cron model fits.** Daily and weekly cadences are explicit, predictable, and the right granularity for an LLM-compiled wiki. There is no value in compiling sub-daily.
- **OpenClaw is the scheduler.** OpenClaw already runs the daily sourcing pass on its own cron. Replacing that with a blob-write trigger would require running a Container App for the ingest stage and inverting the schedule's source of truth from OpenClaw to Azure.
- **The wiki compilation is single-threaded by design.** Lore explicitly compiles `raw/` → `wiki/` as a deliberate, slower-than-real-time pass. Event-driven would tempt sub-batch compilation, which fights the design.

Lore's flow stays cron. If a future workflow on Lore genuinely needs sub-daily reactivity, that's a per-flow ADR.

### D8. Actions stays GitHub-Actions-native — no queue layer

`HoneyDrunk.Actions` (CI/CD control plane per ADR-0012) schedules the nightly-deps, nightly-security, grid-health aggregator, hive-sync, and the future grid-wide pipeline observability via `schedule:` cron in YAML. This ADR rejects adding a queue or eventing layer between Actions and the Nodes those workflows touch:

- **The use case is "trigger a CI job on a schedule."** GitHub Actions provides this directly. Adding Service Bus, Event Grid, or anything else between the cron trigger and the workflow runner is rebuilding what GitHub already provides.
- **Cross-Node fanout is already idiomatic in Actions.** Where one Action needs to trigger work in another repo, the pattern is `gh workflow run` from the calling workflow, or the existing `repository_dispatch` event. No broker is needed; GitHub is the broker.
- **The grid-health aggregator (ADR-0012 D6) is a periodic pull, not an event-driven push.** It runs on cron, queries each Grid repo's CI state via the GitHub API, and assembles the aggregate. Inverting this to "every CI run pushes its result to a Grid topic" is more moving parts for the same outcome.

If a future Actions-driven workflow needs to durably hand off work to a long-running Container App (e.g. a multi-hour data migration), that workflow uses the use-case #1 pattern (Service Bus queue) at the seam. Actions-to-Action coordination stays GitHub-native.

### D9. Outbox pattern is the bridge from domain commits to Transport publishes

`HoneyDrunk.Data.Outbox` (already implemented, per ADR-0008-era work and Transport's `IOutboxStore` / `IOutboxDispatcher` contracts) is the standard bridge for any use case where a database commit and a Transport publish must be atomic — the classic "I saved the user but failed to send the welcome email" problem.

This ADR confirms outbox as the **only** correct pattern for committing-then-publishing across Transport. Direct publishes from inside a database transaction are forbidden — Transport has no way to roll back a Service Bus send if the transaction commits and the send fails (or vice versa). The outbox writes the message into the same database transaction; `IOutboxDispatcher` polls and publishes asynchronously, with at-least-once delivery semantics.

Use cases #1 and #2 are the consumers of outbox. Use case #3 (Storage Queue commodity work) may also use outbox, but the cost-vs-value calculation is per-flow — for Notify intake → Notify worker, where Notify owns both ends in the same Container App, the queue is durable enough on its own.

### D10. KEDA scaling on Container Apps is the consumer-side runtime model

ADR-0015 settled Container Apps with KEDA. This ADR confirms the consumer-side rule:

- **Service Bus queue/topic consumers** scale on KEDA's `azure-servicebus` scaler (queue length / subscription length).
- **Storage Queue consumers** scale on KEDA's `azure-queue` scaler (queue length).
- **Event Grid consumers** scale on KEDA's `azure-eventgrid-topic` scaler if a Container App is the destination, or run as a webhook endpoint if the workload is bursty.
- **Cron-driven Container Apps** (use case #5's heavy variant) use KEDA's `cron` scaler to scale to one replica during the scheduled window and back to zero.

The corollary: every consumer Container App for an event-driven use case is configured to scale to zero between events. This is the cost-defining decision — at the Grid's traffic, Container Apps Consumption + scale-to-zero is the difference between "messaging is cents per month" and "messaging is the line item that swallows the budget."

### D11. What this ADR explicitly does **not** decide

To keep the scope tight and avoid the trap of bundling every event-shaped concern into one ADR:

- **Per-flow message schema versioning.** Transport's README already names schema-registry as out of scope for v0.1.0. When schema evolution becomes a real concern (a v2 of `PulseIngested`, etc.), the per-Node ADR for that flow handles it.
- **Specific dead-letter consumer wiring.** Service Bus queues and topics get a DLQ by default; what runs against the DLQ (a manual replay tool, a Container App that auto-retries, a Pulse signal that fires) is a per-flow operational concern.
- **Cross-region replication.** All current use cases are single-region (East US per ADR-0027). Multi-region eventing is a future ADR if and when a workload needs it.
- **Webhook delivery to external customers.** Notify Cloud's customer-facing webhook story is in PDR-0002's open-questions list. When it gets specified, it likely uses Event Grid custom topics or a webhook-specific service — the question is opened by D6's deferral, not closed.
- **AI agent inter-message coordination.** Flow's workflow engine (ADR-0024) coordinates multi-step AI work over `ITransportPublisher` for async step boundaries — that's use case #1. The Flow-specific saga semantics are scoped by ADR-0024, not by this ADR.
- **Queue-vs-topic for Notify Cloud's billing path.** ADR-0026 D6 mentions Storage Queue as the implementation; this ADR D2 row 3 confirms the pattern. The exact wiring (queue name, retention, idempotency keys) is the Stripe billing integration ADR, not this one.
- **Outbox dispatcher hosting and scaling.** `HoneyDrunk.Data.Outbox.Dispatcher` runs as a long-lived poller; whether it lives as a sidecar to each producing Node, as a single shared Container App per environment, or with KEDA cron-driven activation is a per-deployment question. The first flow that ships an outbox-fed Transport publish settles the host shape.

## Consequences

### Implementation — Done When

This ADR is "Done" when all of the following are true:

- [ ] `repos/HoneyDrunk.Transport/integration-points.md` carries the use-case → backing matrix from D2 verbatim or by reference.
- [ ] `repos/HoneyDrunk.Transport/boundaries.md` reflects D3's signals-vs-events disambiguation (Transport is for domain events; telemetry rides OTel).
- [ ] `repos/HoneyDrunk.Pulse/boundaries.md` adds the explicit "Pulse signals are not domain events" sentence per D3.
- [ ] No Grid Node has been deployed to production yet that violates the matrix in D2 — the audit is clean. (If a violation is found, it is a follow-up packet, not a blocker for this ADR.)
- [ ] Scope agent flips Status → Accepted.

### New invariants (proposed for `constitution/invariants.md`)

Numbering is tentative — scope agent finalizes at acceptance. Two invariants are proposed; both are deliberately small.

- **Telemetry signals ride OpenTelemetry; domain events ride Transport.** Pulse is not subscribed to Transport topics. Nodes do not emit metrics or traces over Transport. The two channels stay separate. (See D3.)
- **Cross-Node async messaging crosses Transport — never raw broker SDK calls.** Even when the chosen backing is Service Bus or Storage Queue, the call site is `ITransportPublisher` / `ITransportConsumer`. Direct `ServiceBusClient.SendAsync` from application code is forbidden — the abstraction exists so that backing swaps are host-time composition changes, not code rewrites. (See D1.)

### Unblocks

Accepting this ADR unblocks the following:

- **Pulse Collector production deployment.** The `PulseIngested` Transport pub/sub flow has a named backing (Service Bus topic per D2 row 2, in `sbns-hd-shared-{env}` per D5), so the production deploy can provision the namespace alongside the first Container App.
- **Notify Cloud Stripe billing integration ADR.** The Storage Queue → Stripe webhook bridge pattern is pinned (D2 row 3); the integration ADR scopes the wiring, not the choice.
- **Communications → Notify production deployment.** D4 confirms the in-process call at v1 with a known migration path, so the deployment doesn't need to provision a Service Bus queue prematurely.
- **Future event-driven use cases.** Any new Node introducing async messaging consults D2 first, picks a row that fits, and either reuses the existing backing or files a follow-up ADR if no row fits.

### Negative

- **Two queue abstractions remain in the Grid.** `HoneyDrunk.Transport` (cross-Node) and `HoneyDrunk.Notify.Queue.*` (intra-Notify) coexist. Notify's queue is not Transport because the boundary doc explicitly disclaims it, and merging them would force every Notify intake message through Transport's middleware pipeline — which is wasteful for the in-Node case. The cost is one more abstraction to maintain; the benefit is each one fits its scope. Mitigation: this is documented in D1 and in Transport's boundaries doc; new Nodes default to Transport unless they have a strict in-Node queue justification.
- **Service Bus Standard at ~$10/mo per environment is a fixed cost the Grid pays once Pulse Collector deploys.** At three environments, that is ~$30/mo of broker idle cost before any messages flow. Mitigation: the namespace is shared across all use cases #1 and #2 in the Grid for that environment, so the cost is amortized across every consumer. The alternative (per-use-case namespaces) would multiply the cost without commensurate benefit.
- **The use-case → backing matrix in D2 is opinionated and may need revision as new use cases emerge.** Mitigation: the matrix lives in this ADR (the source of truth) and is mirrored into `repos/HoneyDrunk.Transport/integration-points.md` (the developer-facing reference). New rows are added by follow-up ADRs that name a use case the matrix does not currently cover.
- **Deferring Event Grid custom topics may need revisiting sooner than expected.** If Notify Cloud's customer-facing webhook story (PDR-0002 open question) lands within the next two ADR cycles and clearly wants Event Grid custom topics, D6 will need a follow-up ADR. Mitigation: the deferral is named explicitly so the next ADR knows where to look; it is not a permanent rejection.
- **Outbox is not free — it requires a database table, a polling dispatcher, and operational discipline (lease timeouts, dead-letter handling on the dispatcher side).** The pattern is non-trivial. Mitigation: `HoneyDrunk.Data.Outbox` and `HoneyDrunk.Data.Outbox.Dispatcher` already implement the pattern; new consumers compose them rather than reinventing.

### Catalog obligations

`catalogs/contracts.json` — no immediate change. If a future implementation packet introduces an `IEventPublisher`-shaped contract for Event Grid custom topics (D6 deferred), that packet adds the entry. The four Transport contracts (`ITransportPublisher`, `ITransportConsumer`, `IMessageHandler`, `ITransportEnvelope`) are already cataloged.

`catalogs/relationships.json` — no immediate change. The use-case matrix is descriptive of how existing Node-to-Node edges are realized, not new edges.

`catalogs/grid-health.json` — no immediate change. Pulse, Transport, Notify, Communications, and Notify Cloud entries already capture their messaging surfaces.

`constitution/sectors.md` — no change.

`constitution/invariants.md` — adds the two invariants from the section above.

## Alternatives Considered

### One backing for the whole Grid (e.g. "all messaging is Service Bus")

Rejected. This is the framing the user explicitly turned down in the prompt and the Context section evidences why: a blanket Service Bus decision over-spends on commodity-work-queue use cases (use case #3, billing events to Stripe — Storage Queue at cents) and under-spends on reactive resource events (use case #6 — only Event Grid emits Azure-system signals as a managed channel). One-backing decisions are easy to write but produce wrong-tool-for-the-job costs across the matrix.

### Use Event Grid (custom topics) as the Grid's primary pub/sub instead of Service Bus topics

Rejected at v1. Event Grid custom topics are filter-routed, at-most-once-with-retry, and shine when the consumer set is heterogeneous (some HTTP webhooks, some Azure Functions, some Container Apps). The Grid's pub/sub use cases today (use case #2 — `PulseIngested`, future domain events) are homogeneous (Container App consumers that want guaranteed per-subscription delivery and replay). Service Bus topics fit that shape; Event Grid does not. Custom topics may be revisited if/when an external-webhook-fanout use case lands.

### Use Storage Queue for everything (cost-first)

Rejected. Storage Queue lacks topics (no fanout), sessions (no FIFO grouping), DLQ (manual poison-queue convention required), transactions, and duplicate detection. Use cases #1 and #2 need at least three of those features; use case #3 needs none of them. The right answer is to use Storage Queue where its trade-offs fit (use case #3) and Service Bus where they do not (#1, #2).

### Treat Pulse as a Transport consumer and route domain events through it for "free observability"

Rejected. This is the conflation D3 names explicitly. Pulse is observability infrastructure; domain events are business state. Subscribing Pulse to Transport topics would (a) couple observability to event schema, (b) put telemetry processing in the path of domain delivery, (c) blur the architectural seam between OTel-shaped signals and Transport-shaped events. The two channels stay separate; Pulse instruments domain events from inside the Nodes that emit them, via OpenTelemetry.

### Replace Notify's internal queue (`HoneyDrunk.Notify.Queue.*`) with Transport

Rejected at v1. Notify intake → Notify worker is an in-Node hop where the producer and consumer share the same Container App and the same `kv-hd-notify-{env}` Vault. Routing the message through Transport's middleware pipeline adds latency and complexity for no boundary-crossing benefit. The Transport boundaries doc already disclaims this surface for the same reason. If Notify ever splits intake and worker into separate Container Apps, the seam migrates to Transport via the abstraction that already exists; until then, the in-Node queue stays Notify-internal.

### Add a queue layer between GitHub Actions and Grid Nodes (Actions → Service Bus → Node consumer)

Rejected. The use case is "trigger a CI job on a schedule," and GitHub Actions does that natively with `schedule:` cron. Adding a broker between the cron trigger and the workflow runner is rebuilding what GitHub already provides. Cross-Action coordination uses `gh workflow run` or `repository_dispatch`. If a future Actions-driven flow needs durable hand-off to a long-running Container App, that flow uses the use-case-#1 Service Bus pattern at the hand-off seam — but Actions-to-Actions coordination stays GitHub-native.

### Convert Lore's two-stage workflow to event-driven (raw/ blob write → ingest trigger)

Rejected at v1, per D7. Daily and weekly cadences are explicit, predictable, and right-sized for an LLM-compiled wiki. OpenClaw is already the scheduler; converting to event-driven would invert the source of truth and tempt sub-batch compilation that fights Lore's design. If a Lore-specific workflow ever genuinely needs sub-daily reactivity, that's a per-flow ADR.

### Make Service Bus per-Node instead of one shared namespace per environment

Rejected. Same reasoning as ADR-0015's per-Node-environment rejection: namespace is not a security boundary (Managed Identity scopes per queue/topic), per-namespace cost is fixed (~$10/mo Standard), and a shared namespace simplifies cross-Node observability. If a single Node ever generates traffic that warrants its own namespace (Notify Cloud at 10K+ tenants, hypothetically), that is a future ADR — not the v1 default.

### Skip Event Grid system topics and roll cache invalidation into a Transport flow

Rejected. Event Grid system topics are the **only** mechanism Azure provides for emitting "this resource changed" events as a managed channel. Vault rotation cache invalidation already implicitly relies on this (Invariant 21 calls out version pinning as breaking Event Grid invalidation). Replacing it with a polling Transport flow would mean every Vault consumer polls Key Vault for the latest version on every request — which is exactly what the cache exists to avoid. System topics are accepted; custom topics are deferred.

## Open Questions

Items that should become their own ADRs or packets later:

- **Notify Cloud customer-facing webhooks.** PDR-0002 §Open Questions defers this. When it lands, it likely needs Event Grid custom topics (the deferred half of D6) or a webhook-specific service. Specific shape unknown.
- **Cross-region replication for Service Bus / Event Grid.** Notify Cloud v1 is single-region per PDR-0002 §B. Multi-region eventing is a future ADR when a workload needs it.
- **Schema registry for Transport messages.** Transport's README disclaims this for v0.1.0. When schema evolution causes pain (a v2 of `PulseIngested`, an evolving `BillingEvent`), a follow-up packet adds a registry — likely as a thin convention rather than a heavy schema-registry service.
- **Static analyzer enforcing the "no raw broker SDK calls" invariant.** A `HoneyDrunk.Standards` analyzer that flags `Azure.Messaging.ServiceBus.ServiceBusClient` or `Azure.Storage.Queues.QueueClient` references outside `HoneyDrunk.Transport.*` packages. Useful but not gating; future packet.
- **Event Grid → Container App webhook authentication.** When the first Container App consumes Event Grid system topic events (Vault rotation cache invalidation is the most likely first), the auth shape (Event Grid signed delivery, plus Auth's existing JWT validation, plus per-Node Managed Identity) needs settling. Future packet, likely under the Vault rotation flow.
- **Outbox dispatcher operational tuning.** Lease timeouts, batch sizes, polling intervals — all currently default values in `HoneyDrunk.Data.Outbox.Dispatcher`. Will need tuning once the first production outbox-fed flow ships. Not gating for this ADR; surfaces as operational telemetry on Pulse.
