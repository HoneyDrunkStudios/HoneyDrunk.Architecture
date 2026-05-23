# ADR-0068: Background Job and Recurring Work Substrate

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Core / Ops · cross-cutting

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Update [`infrastructure/reference/tech-stack.md`](../infrastructure/reference/tech-stack.md) — remove `HoneyDrunk.Jobs` from "Planned Nodes" (or move to "Deferred — substrate covered by Container Apps Jobs" per D4)
- [ ] Update [`initiatives/roadmap.md`](../initiatives/roadmap.md) line 67 — remove `HoneyDrunk.Jobs — Background job scheduling with Grid integration` from the Future section, or move to a "Deferred — substrate decided" subsection per D4
- [ ] Update [`repos/HoneyDrunk.Vault.Rotation/boundaries.md`](../repos/HoneyDrunk.Vault.Rotation/boundaries.md) — record the Functions-timer-trigger pattern as grandfathered per D1 / D7 ("Vault.Rotation stays on its existing substrate; new cross-Node recurring work uses Container Apps Jobs")
- [ ] Update [`repos/HoneyDrunk.Communications/`](../repos/HoneyDrunk.Communications/) context — record that cadence/drip-campaign scheduling uses Container Apps Jobs per D3, cron format per [ADR-0063](./ADR-0063-date-time-and-clock-policy.md) D6
- [ ] Update [`repos/HoneyDrunk.Notify/`](../repos/HoneyDrunk.Notify/) and Notify.Cloud context — record the in-Node `BackgroundService` pattern for retries per D2
- [ ] Add a `job-deploy-container-apps-job.yml` reusable workflow to [`HoneyDrunk.Actions`](../../HoneyDrunk.Actions/) — Container Apps Jobs need a deploy workflow analogous to `job-deploy-container.yml` (which deploys Container Apps, not Jobs); the new workflow handles Jobs-specific shape (schedule-or-event trigger, replica policy, retry policy)
- [ ] Promote D6 (idempotency on every job), D7 (retry policy defaults), and D8 (observability) into numbered invariants once Accepted — scope agent assigns invariant numbers in the same PR that flips Status
- [ ] Scope agent flips Status → Accepted after the deploy workflow lands and the first job migrated (or stood-up) under the new substrate

## Context

`HoneyDrunk.Jobs` has lived as a planned Node in [`initiatives/roadmap.md`](../initiatives/roadmap.md) line 67 ("HoneyDrunk.Jobs — Background job scheduling with Grid integration") and as an informal future-Node concept in tech-stack discussions for several months. It does not exist on disk; it is not cataloged in `catalogs/nodes.json`; no contract surface, no implementation, no scaffold.

Meanwhile, recurring and background work is **already happening across the Grid** with at least three different substrates and no stated policy:

1. **Vault.Rotation** ([ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md)) uses Azure Functions timer triggers (Function App, Event Grid schedule).
2. **hive-sync** runs on OpenClaw cron (external scheduled task on the user's box per the OpenClaw runtime memory).
3. **nightly-security** workflows run on GitHub Actions cron (per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md)).
4. **nightly-deps** grouping runs on GitHub Actions cron (per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md)).
5. **Notify retries** ([ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)) will need scheduling — currently in flight, no committed substrate.
6. **Communications cadence and drip campaigns** ([ADR-0013](./ADR-0013-communications-orchestration-layer.md), [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md)) need scheduling — imminent, no committed substrate.
7. **AI cost-ledger periodic drain** ([ADR-0016](./ADR-0016-stand-up-honeydrunk-ai-node.md), implied by `ICostLedger`) will need scheduling when the rate-table refresh cadence is committed.

Without an ADR, the next consumer to ship (Communications cadence is the imminent one) will pick a fourth substrate unilaterally and the Grid drifts further. The user's prompt for this ADR is the right move: settle the policy now, while three of the seven workloads are still pre-implementation and the policy can shape them rather than retrofit them.

The forcing functions:

- **[ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) Communications cadence rules** are the next workload to land and need a scheduling substrate.
- **[ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) Notify Cloud retries** need a retry substrate; in-Node `BackgroundService` is the strong candidate but uncommitted.
- **[ADR-0015](./ADR-0015-container-hosting-platform.md)** pinned Azure Container Apps as the deployable platform. Container Apps **Jobs** is the Jobs-shaped sibling of Container Apps (scheduled and event-triggered, single-invocation rather than long-running). The ADR-0015 substrate already covers the Jobs case — this ADR pins it.
- **[ADR-0063](./ADR-0063-date-time-and-clock-policy.md)** (Proposed, paired with this ADR) pins the cron-string format (5-field, UTC) and the clock substrate (`TimeProvider`). This ADR depends on those decisions for "what cron format do jobs use" and "what clock does the in-process scheduler read."

This ADR settles **workload categorization** (which kind of background work belongs where), **the cross-Node scheduling substrate** (Container Apps Jobs), **the in-Node substrate** (`BackgroundService`), **idempotency expectations**, **retry and failure handling defaults**, and **the `HoneyDrunk.Jobs` Node deferral**.

## Decision

### D1 — Distinguish three workload categories; each has a different substrate

Not all "background work" is the same. The Grid carries three categorically different shapes:

| Category | Examples | Substrate | This ADR's scope |
|----------|----------|-----------|------------------|
| **CI/CD and ops cron** | nightly-deps, nightly-security, hive-sync, grid-health aggregator | GitHub Actions cron | **Out of scope** — pinned to GitHub Actions per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md). Stays there. |
| **In-Node background processing** | Notify retry pump, AI cost-ledger drain, audit batch flush, in-process queue consumers | `IHostedService` / `BackgroundService` inside the Node | **In scope** — D2 pins the substrate. |
| **Cross-Node recurring orchestration** | Communications drip campaigns, Vault rotation, future tenant-lifecycle scheduled tasks, future billing reconciliation | **Azure Container Apps Jobs** | **In scope** — D3 pins the substrate. |

The distinguishing question for "in-Node vs. cross-Node" is: does the job run *because* a specific Node owns it, with that Node's domain state and DI graph, or does it run *across* Nodes (orchestrating Communications → Notify, or rotating a secret then notifying consumers)?

- **In-Node:** runs inside the Node's host process, scoped to the Node's DI container, sees the Node's domain types. A Notify retry pump reads from Notify's queue, calls Notify's delivery adapters, updates Notify's records. It is a Notify-internal concern.
- **Cross-Node:** runs as an independent process, may compose against multiple Nodes' SDKs, has its own DI container, its own lifecycle. A Communications drip-campaign scheduler reads from Communications data, calls Notify's SDK, records to Audit. The work spans Nodes.

The categorization is the substrate decision. Once a workload's category is known, the substrate is pinned.

### D2 — In-Node background processing uses `IHostedService` / `BackgroundService`

Every Node that needs in-process recurring or background work uses ASP.NET Core's built-in `IHostedService` interface (typically via the `BackgroundService` base class). No Quartz, no Hangfire, no third-party scheduler dependency.

The reasoning:

- **Already in the SDK.** `Microsoft.Extensions.Hosting` is a transitive dependency of every deployable Node. No new package to add, no new license to vet, no new stewardship risk.
- **Simplicity matches the workload.** In-Node background work — a retry pump, a batch flush, a cache warmer — is a `while(!ct.IsCancellationRequested) { await DoWork(); await Task.Delay(interval, ct); }` shape. `BackgroundService` is exactly that shape.
- **Time substrate is consistent.** The `BackgroundService` reads `TimeProvider` per [ADR-0063](./ADR-0063-date-time-and-clock-policy.md) D1; tests advance `FakeTimeProvider` per [ADR-0063](./ADR-0063-date-time-and-clock-policy.md) D7. No Quartz-specific test seam; no Hangfire-specific test seam.
- **Composition is the Node's concern.** The Node owns its own DI container; the `BackgroundService` is registered with the same `services.AddHostedService<T>()` call every other ASP.NET Core service uses.

Quartz or Hangfire may be revisited later if a genuine workload demands one of their capabilities (Quartz's clustering, Hangfire's dashboard). Until then, the in-process need is `BackgroundService`-sized and the simpler substrate wins.

**Concrete first consumers under D2:**

- **Notify retry pump** ([ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)). Retries inside Notify's Worker process; reads Notify's failed-delivery queue; uses `TimeProvider` for backoff windows; ISO 8601 duration strings for backoff configuration per [ADR-0063](./ADR-0063-date-time-and-clock-policy.md) D6.
- **AI cost-ledger drain** ([ADR-0016](./ADR-0016-stand-up-honeydrunk-ai-node.md)). When the cost-ledger flush cadence is committed, the flusher is a `BackgroundService` inside the AI Node.
- **Audit batch flush** ([ADR-0030](./ADR-0030-audit-substrate-grid-wide.md)). If audit emission introduces an in-process batch buffer (a future ADR may add one for high-throughput sources), the flusher is a `BackgroundService` inside the Audit Node.

### D3 — Cross-Node recurring orchestration uses Azure Container Apps Jobs

Every cross-Node recurring or event-driven job runs on **Azure Container Apps Jobs**. This is the Jobs-shaped sibling of the Container Apps decision in [ADR-0015](./ADR-0015-container-hosting-platform.md) — same Azure platform, same Container Apps Environment, same managed-identity story, same registry, same telemetry pipeline. New deploy workflow, but reusing the existing build-and-push pipeline up to the deploy step.

Container Apps Jobs support two trigger shapes:

- **Schedule-triggered (cron).** A cron expression (5-field, UTC per [ADR-0063](./ADR-0063-date-time-and-clock-policy.md) D6) drives the job. Azure starts a replica on schedule, the job runs, the replica terminates.
- **Event-triggered (KEDA scaler).** A Service Bus queue depth, an Event Grid event arrival, a Storage Queue length, or a custom scaler triggers the job. Same Container Apps KEDA story as the long-running `ca-hd-{service}-{env}` Container Apps in [ADR-0015](./ADR-0015-container-hosting-platform.md).

**Why Container Apps Jobs over the alternatives:**

| Dimension | Functions timer trigger (current Vault.Rotation) | New `HoneyDrunk.Jobs` Node with Quartz cluster | Per-Node hosted service | Container Apps Jobs |
|-----------|--------------------------------------------------|------------------------------------------------|-------------------------|---------------------|
| Stays in [ADR-0015](./ADR-0015-container-hosting-platform.md) substrate | No (Functions) | Adds new Azure surface (compute for Quartz cluster) | Yes | **Yes** |
| Cron support | Yes (NCRONTAB) | Yes | Self-built | **Yes (standard cron)** |
| Event-trigger support | Yes (Functions bindings) | Self-built | Self-built | **Yes (KEDA)** |
| Durability of execution | Functions retry policy | Quartz misfire policy | Self-built | **Container Apps retry policy** |
| Observability | App Insights | Self-built dashboards | Per-Node | **Same as ADR-0015 telemetry** |
| Net Grid surface added | Adds a new Functions app per job | Adds a Node, a Quartz cluster, a database | Zero | **New deploy workflow only** |
| Cost at Grid scale | Function App per Job is overhead | Cluster cost is real | Free | **Consumption-priced, scale-to-zero between runs** |

The decision is straightforward: Container Apps Jobs are the natural fit for the platform already in production. Functions timer triggers grandfather in (D7), but new cross-Node recurring work goes here.

**Naming convention.** Container Apps Jobs follow the same convention as Container Apps per [Invariant 34](../constitution/invariants.md), with a `-job` suffix to disambiguate: `caj-hd-{service}-{env}` (e.g., `caj-hd-comms-cadence-prod`). The 13-character service-name limit ([Invariant 19](../constitution/invariants.md)) applies the same way.

### D4 — `HoneyDrunk.Jobs` Node — defer the standup; substrate is sufficient

`HoneyDrunk.Jobs` was planned as a Node that would own Grid-wide background-job scheduling. With Container Apps Jobs as the substrate per D3 and `BackgroundService` as the in-Node substrate per D2, **a dedicated Jobs Node is not required**.

The argument that earned `HoneyDrunk.Jobs` its planned slot was "the Grid needs a place for cross-Node background scheduling logic." That place was going to be a Node with a Quartz cluster (or equivalent). Container Apps Jobs subsumes the Node — Azure provides the scheduling, observability, retry, and durability; the per-job business logic lives in the Node that owns the job (Communications owns its drip-campaign Job; Vault.Rotation owns its rotation Jobs).

`HoneyDrunk.Jobs` is **deferred indefinitely**. The roadmap entry moves to "Deferred — substrate covered by Container Apps Jobs" or is removed entirely. If a future workload reveals a genuine need for a Jobs-Node-shaped capability (a shared retry policy library, a job-history query surface, a centralized job-failure forensic view), the Node can be stood up then; the deferral does not foreclose it.

The principle: do not stand up a Node whose role is "wrap the Azure capability we are already using directly." That is the same principle that keeps `HoneyDrunk.Cache` honest in [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) (the Node is for *backing implementations*, not for "wrap Redis the consumer would otherwise use directly").

### D5 — Cron format and clock substrate

Cross-references [ADR-0063](./ADR-0063-date-time-and-clock-policy.md):

- Cron strings are **5-field, UTC** per [ADR-0063](./ADR-0063-date-time-and-clock-policy.md) D6. No 6-field cron (no seconds). No local-timezone cron.
- Jobs read time via `TimeProvider.GetUtcNow()` per [ADR-0063](./ADR-0063-date-time-and-clock-policy.md) D1. The Container Apps Jobs runtime fires the job on schedule; inside the job, every wall-clock read goes through `TimeProvider`.
- Tests for jobs that depend on time advance `FakeTimeProvider` per [ADR-0063](./ADR-0063-date-time-and-clock-policy.md) D7. The Container Apps Jobs trigger itself is platform-driven (no in-process scheduler to fake); the *body* of the job is what gets tested with `FakeTimeProvider`.
- Delays and intervals (retry backoff, in-job pacing) use ISO 8601 duration strings per [ADR-0063](./ADR-0063-date-time-and-clock-policy.md) D6.

### D6 — Idempotency is required on every job

Every job (in-Node `BackgroundService` or cross-Node Container Apps Job) **must be idempotent**. Re-execution is a normal failure mode: a job's replica may crash mid-run, Container Apps may retry per D7, the platform may double-trigger near a schedule boundary in rare edge cases.

Jobs that mutate state use `IIdempotencyStore` per [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md). The idempotency key is deterministic per (job-name, scheduled-run-time):

```
idempotencyKey = $"{jobName}:{scheduledInstant:yyyyMMddTHHmmssZ}"
```

For event-triggered jobs (KEDA scalers), the key is derived from the trigger event (typically the Service Bus `MessageId` or the Event Grid event ID, salted with the job name).

Read-only jobs (a status probe, a health check) need no idempotency record — they make no state changes; re-execution is harmless.

The canary surface for idempotency-on-jobs is part of [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md)'s canary obligations; no separate canary in this ADR.

### D7 — Retry and failure handling defaults

Container Apps Jobs supports configurable retry policy and replica count. The Grid defaults:

- **Max retries:** 3
- **Backoff:** exponential — 1 minute, 5 minutes, 25 minutes (configurable per-job; default if unspecified)
- **Dead-letter on final failure:** the job emits an audit record per [ADR-0030](./ADR-0030-audit-substrate-grid-wide.md) (`AuditEntry` with category `JobFailure`, including job name, scheduled instant, retry count, and last exception summary), and raises an error per [ADR-0045](./ADR-0045-grid-wide-error-tracking.md).
- **Per-job override:** any job may override the default in its Container Apps Jobs manifest if its workload demands it (e.g., a long-running data export with a single deterministic retry). The override is configuration, not code.

In-Node `BackgroundService` work is not subject to D7's retry policy directly — the `BackgroundService` author decides the retry semantics in code. The convention: `BackgroundService` retries should be visible in the code (a `Polly` policy or explicit `try/catch` with logging), not implicit in the runtime.

**Grandfathering Vault.Rotation.** Vault.Rotation per [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) Tier 2 uses Azure Functions timer triggers today. The grandfather posture: **stays on its existing substrate** until a natural migration moment (a major rewrite of Vault.Rotation, or a Functions plan retirement). New cross-Node recurring work goes on Container Apps Jobs per D3; Vault.Rotation is not retroactively migrated.

### D8 — Observability

Every job emits the following:

- **Pulse metrics.** A counter `jobs.outcome` with tags `{job_name, outcome=success|retry|fail}`. A histogram `jobs.duration` with tags `{job_name}`. Both via Kernel's `ITelemetryActivityFactory` per the existing Pulse plumbing.
- **Job lifecycle traces.** Start, end, and (on retry/fail) the retry attempt are spans on the Pulse trace pipeline. The job's `correlationId` is generated at job start and propagated to every downstream call per [Invariant 6](../constitution/invariants.md).
- **Long-running job progress.** Jobs running > 60 seconds emit progress to Audit per [ADR-0030](./ADR-0030-audit-substrate-grid-wide.md) (a `JobProgress` audit category) so the forensic surface can answer "where is the long-running job right now."
- **Failed jobs raise errors per [ADR-0045](./ADR-0045-grid-wide-error-tracking.md).** The error tracking surface (Sentry, Application Insights, whichever ADR-0045 lands on) captures the final-failure stack trace, the retry count, and the job's correlation ID.

The line between Pulse and Audit per [Invariant 47](../constitution/invariants.md) is preserved: Pulse answers "are jobs healthy in aggregate" (metrics, traces, sampled); Audit answers "did this specific job run, did it succeed, what did it do" (durable, attributable, complete). A job-failure event lives in both — Pulse for the SRE-style health view, Audit for the forensic view.

### D9 — Local dev story

Container Apps Jobs do not run locally — the platform is Azure-specific. For local development of a cross-Node Job:

- The same job binary runs as a **console app** (a `Program.cs` with a `Main` that calls the job's entry point).
- Optionally, the binary runs under a **timer-driven host** (`HostBuilder` + a `BackgroundService` that fires the job entry on a developer-controlled cadence) for testing the schedule behavior without Azure in the loop.
- Test code drives `FakeTimeProvider` to simulate cron-firing without waiting for wall-clock minutes/hours/days.

Cross-references the future Aspire-stance ADR (provisional [ADR-0065](./ADR-0065-aspire-stance.md), not yet filed). If Aspire becomes the local-dev orchestrator, the job-binary-as-console-app pattern composes into the Aspire AppHost; if Aspire is rejected, the pattern stands alone via `dotnet run`. Either way the binary is the unit of code; the platform is the choice.

### D10 — Job code organization

**Each Node owns its own jobs.** There is no central jobs repository. There is no shared `HoneyDrunk.Jobs.Library` package.

- Notify retry pump lives in Notify (per D2; in-process `BackgroundService`).
- Communications cadence drain lives in Communications (per D3; Container Apps Job deployed from the Communications repo).
- Vault.Rotation Jobs live in Vault.Rotation (grandfathered per D7; current Functions substrate).
- AI cost-ledger drain lives in HoneyDrunk.AI (per D2; in-process `BackgroundService`).

The locality matches the data and the domain. The job is part of the Node's deployable surface; its tests live alongside the Node's tests; its CHANGELOG is the Node's CHANGELOG.

For cross-Node Jobs deployed as Container Apps Jobs, the deploy artifact is part of the owning Node's CI pipeline (a new `job-deploy-container-apps-job.yml` reusable workflow in [HoneyDrunk.Actions](../../HoneyDrunk.Actions/) per the follow-up checklist).

### D11 — Migration path for existing recurring work

The Grid's current recurring-work surface, with the migration disposition:

| Workload | Current substrate | Disposition per this ADR |
|----------|-------------------|--------------------------|
| nightly-deps grouping | GitHub Actions cron | **Stays.** CI/CD ops cron per D1. |
| nightly-security | GitHub Actions cron | **Stays.** CI/CD ops cron per D1. |
| hive-sync | OpenClaw cron | **Stays.** External substrate; not Grid-internal. |
| grid-health aggregator | GitHub Actions cron per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md) | **Stays.** CI/CD ops cron per D1. |
| Vault.Rotation | Azure Functions timer triggers per [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) | **Grandfathered per D7.** Stays on Functions until a natural migration moment. |
| Notify retries (in flight) | Uncommitted | **Pin to D2** — in-Node `BackgroundService`. |
| Communications cadence (imminent) | Uncommitted | **Pin to D3** — Container Apps Jobs. |
| AI cost-ledger drain (future) | Uncommitted | **Pin to D2** — in-Node `BackgroundService`. |
| Future tenant-lifecycle scheduled work | Uncommitted | **Pin to D3** — Container Apps Jobs. |

The migration disposition is "no retroactive rewrites; pin the new work." This matches the [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) caching-grandfather pattern: existing patterns stay, new patterns follow the ADR.

## Consequences

### Implementation — Done When

This ADR is "Done" when all of the following are true:

- [ ] [ADR-0063](./ADR-0063-date-time-and-clock-policy.md) is Accepted (paired prerequisite — cron format and clock substrate are pinned there).
- [ ] `job-deploy-container-apps-job.yml` reusable workflow lands in [HoneyDrunk.Actions](../../HoneyDrunk.Actions/).
- [ ] The first cross-Node Container Apps Job ships (likely Communications cadence per D11).
- [ ] The first in-Node `BackgroundService` under this ADR ships (likely Notify retry pump per D11).
- [ ] `infrastructure/reference/tech-stack.md` reflects the `HoneyDrunk.Jobs` deferral.
- [ ] `initiatives/roadmap.md` reflects the `HoneyDrunk.Jobs` deferral.
- [ ] `repos/HoneyDrunk.Vault.Rotation/boundaries.md` records the grandfather posture per D7.
- [ ] `repos/HoneyDrunk.Communications/` and `repos/HoneyDrunk.Notify/` context reflect their substrate choices per D2 / D3.
- [ ] Scope agent flips Status → Accepted.

### Unblocks

Accepting this ADR unblocks the following:

- **Communications cadence and drip-campaign scheduling.** The substrate (Container Apps Jobs) is pinned; the cron format is pinned (via [ADR-0063](./ADR-0063-date-time-and-clock-policy.md) D6); the deploy workflow lands as a follow-up; Communications can file its cadence-job packets.
- **Notify Cloud retry scheduling.** The substrate (`BackgroundService`) is pinned; the backoff format (ISO 8601 durations) is pinned; Notify Cloud can file the retry-pump packet.
- **Future AI cost-ledger drain.** When the cost-ledger flush cadence is committed, the substrate is known.
- **Future tenant-lifecycle scheduled jobs** ([ADR-0050](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md)). Any scheduled lifecycle task (provisioning timeout reaper, suspension cooldown reaper) has a substrate.
- **`HoneyDrunk.Jobs` Node deferral.** The Node's planned slot can be removed from the roadmap; no future packet wave will assume the Node exists.

### New invariants (proposed; scope agent assigns numbers at acceptance)

- **In-Node background processing uses `IHostedService` / `BackgroundService`.** Third-party in-process schedulers (Quartz, Hangfire) are forbidden without a follow-up ADR.
- **Cross-Node recurring orchestration uses Azure Container Apps Jobs.** Functions timer triggers for new cross-Node recurring work are forbidden; existing Functions-based jobs (Vault.Rotation) are grandfathered.
- **Every state-mutating job is idempotent.** State-mutating jobs without an `IIdempotencyStore` interaction (or an equivalent deterministic-key check) fail the canary in [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md).
- **Container Apps Jobs follow the naming convention `caj-hd-{service}-{env}`.** The 13-character service-name limit ([Invariant 19](../constitution/invariants.md)) applies.

### Catalog obligations

- `catalogs/nodes.json` — **no `honeydrunk-jobs` entry to add.** This ADR explicitly defers the Node.
- `catalogs/contracts.json` — no entry. The contract surface (cron strings, `BackgroundService` shape, Container Apps Jobs deploy manifest) is platform/BCL types; nothing HoneyDrunk-owned to register.
- `constitution/invariants.md` — append the new invariants listed above with sequential numbers at acceptance.
- `infrastructure/reference/tech-stack.md` — update the `HoneyDrunk.Jobs` row per the follow-up checklist.
- `initiatives/roadmap.md` — update line 67 per the follow-up checklist.

### Negative

- **Container Apps Jobs is a newer Azure surface than Container Apps proper.** The platform has been GA since 2023 but its tooling (especially for IaC and CI/CD) lags Container Apps slightly. The deploy workflow (per follow-up checklist) is the studio's first authored Jobs workflow; expect iteration. Mitigation: the cost of authoring the workflow is one-time; the cost of *not* having a committed substrate compounds with every new recurring workload.
- **The deferral of `HoneyDrunk.Jobs` Node closes a future architectural door.** If a future Grid scale or workload reveals a need for a shared Jobs library, the Node has to be stood up at that point with retrofit cost. Mitigation: the deferral does not foreclose the standup; it just doesn't pre-emptively pay for it. The scout's discipline applies — front-load Nodes whose role is real, defer Nodes whose role is "wrap the platform."
- **Vault.Rotation grandfathered on Functions creates a two-substrate world.** New jobs go on Container Apps Jobs; one existing job stays on Functions. Mitigation: explicit, documented, and time-bounded by a natural migration moment. The two-substrate posture is the standard transition shape; the Grid has lived with similar transitions (Notify on App Service before the [ADR-0015](./ADR-0015-container-hosting-platform.md) migration to Container Apps).
- **The 3-retry / 1m-5m-25m exponential backoff default is somewhat arbitrary.** It is not derived from a workload study; it is a starting point. Mitigation: per-job override per D7; revisit the default if real failure data shows it is wrong. Acceptable cost.
- **No central job-history view.** Each Node's jobs emit telemetry to Pulse and audit records to Audit; there is no single "show me every job that ran in the last 24 hours" surface. Mitigation: Pulse's job-outcome metric tagged by job name *is* that view, in aggregate; Audit's `JobFailure` and `JobProgress` categories *are* the forensic view. If a future operator workload demands a dashboard, that dashboard is built on top of the existing telemetry, not via a new central jobs service.

## Alternatives Considered

### Stand up `HoneyDrunk.Jobs` as a dedicated Node with a Quartz.NET cluster

Considered. The argument: front-load the Node per the same charter principle that justifies the Cache, Audit, AI-sector standups; ship a real scheduling substrate with full feature support (clustering, misfire policies, JobStores) and let every Node compose against it.

Rejected per D4. Container Apps Jobs subsumes the Node's role. Quartz's clustering capability would solve a problem the Grid does not have (Quartz clustering exists because Quartz needs to coordinate a multi-instance scheduler against a shared JobStore; Container Apps Jobs delegates the coordination to Azure). The cluster cost, the JobStore database, the operational learning curve for Quartz's misfire/recovery model — all real costs for capability the Grid does not need.

The standup-Node-first principle that justified Cache, Audit, and AI applies when *there is a contract role for the Node to own*. Cache owns backing implementations of `ICacheStore<T>`. Audit owns the durable, attributable record substrate. AI owns model/provider abstraction. `HoneyDrunk.Jobs` would own... wrapping a cron scheduler. The wrapping is the platform's job; the Node would be a thin proxy. Rejected.

### Use Azure Functions timer triggers for everything (extend the Vault.Rotation pattern)

Considered. The argument: Vault.Rotation already works; the pattern is proven; extend it to Communications, Notify retries, and future scheduled work. One substrate.

Rejected per D3. Functions per-job means one Function App per workload, each with its own plan, its own ingress, its own deploy pipeline. Container Apps Jobs reuses the existing ADR-0015 platform — same Environment, same registry, same managed-identity wiring. The marginal cost of a new Container Apps Job is much lower than the marginal cost of a new Function App. And event-triggered scheduling (KEDA scalers on Service Bus / Event Grid) is awkward on Functions outside the bindings model; Container Apps Jobs handles it natively.

Vault.Rotation grandfathers (per D7) because the migration cost is real and the existing substrate is not broken. New work goes on the new substrate.

### Use App Service WebJobs

Considered. The argument: a third Azure option for hosted scheduled work; integrates with App Service.

Rejected. The Grid is not on App Service (per [ADR-0015](./ADR-0015-container-hosting-platform.md)) — containerized Nodes run on Container Apps. WebJobs would require either a separate App Service plan (cost, complexity) or a retroactive shift of a Node onto App Service (regression). Not viable.

### Build a centralized HoneyDrunk-owned scheduler that delegates to Container Apps Jobs underneath

Considered. The argument: keep the Container Apps Jobs decision but add a thin HoneyDrunk-owned `IScheduler` abstraction so consumer Nodes compile against the abstraction and the implementation (Container Apps Jobs deploy manifest writer) is swappable.

Rejected. The abstraction does not earn its keep. Container Apps Jobs is a deployment manifest; an `IScheduler` abstraction would have to model "produce a deploy manifest" as a runtime call, which is not a runtime concern — it is a build/deploy concern. The abstraction would be over the wrong axis. Direct use of the Container Apps Jobs platform is the right granularity.

The clock substrate (`TimeProvider`) and the cron format (5-field UTC strings) *are* abstractions — but they live at [ADR-0063](./ADR-0063-date-time-and-clock-policy.md), not here. Inside a job, those abstractions are what the code reads. The job's *trigger* is platform; the job's *body* is code.

### Use Hangfire for in-Node background processing

Considered. The argument: Hangfire is the .NET community's go-to for background work, has a dashboard, has persistent JobStores (SQL Server, Redis), has retry policies built in.

Rejected per D2. Hangfire's value props are (a) the dashboard and (b) the durable JobStore for at-least-once execution across host restarts. The dashboard is solved by Pulse + Audit per D8 (Grid-aware observability). The durable JobStore is solved by Service Bus or Storage Queue as the trigger source for Container Apps Jobs (durable by the platform). What's left is "a `BackgroundService` with a polling loop and `TimeProvider`" — which is what `BackgroundService` already is. The Hangfire dependency, its JobStore database, its dashboard auth, its license consideration — all real costs for capability the Grid covers via existing infrastructure.

Hangfire may be revisited later if a workload reveals a genuine need it uniquely solves. Today, none does.

### Defer this ADR until a workload forces the substrate choice

Considered. The argument: only one workload (Vault.Rotation) is in production; the next two (Notify retries, Communications cadence) are pre-implementation; substrate can be decided per-workload.

Rejected. The substrate choice **is** the policy. Letting each workload pick independently is exactly the drift this ADR exists to prevent. The user's framing — "without an ADR, Communications will pick a fourth substrate unilaterally" — is correct. Pinning the substrate now, while the first two new workloads are still pre-implementation, is much cheaper than pinning it after they have shipped on divergent substrates.

### Use GitHub Actions cron for cross-Node scheduling too

Considered. The argument: GitHub Actions cron already runs nightly-deps, nightly-security, grid-health aggregator; extend it to Communications cadence, Notify retries, etc.

Rejected per D1. GitHub Actions cron is for **CI/CD operations cron** — work whose context is "the Grid's build, security, and reconciliation infrastructure." Communications cadence is product runtime; running it from a GitHub Actions workflow would mean (a) the runtime depends on GitHub Actions availability, (b) the runtime emits product-level audit and telemetry from a workflow runner that is not in the Grid's observability boundary, and (c) the per-tenant cadence work would write to product databases from a CI environment. All three are wrong.

GitHub Actions cron stays where it is per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md). Product runtime work goes on Container Apps Jobs per D3.
