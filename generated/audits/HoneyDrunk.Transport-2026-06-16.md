# Node Audit: HoneyDrunk.Transport

**Auditor:** node-audit agent
**Date:** 2026-06-16
**Verdict:** Drifting

## Recommendation Breakdown

- **Architecture metadata still advertises Transport 0.6.0 while the repo is 0.7.1**
  - Recommendation: promote
  - Why: `repos/HoneyDrunk.Transport/overview.md` and `catalogs/compatibility.json` still declare Transport `0.6.0`, while the audited repo sets all shipped Transport packages to `<Version>0.7.1</Version>` and consumes `HoneyDrunk.Kernel.Abstractions` `0.8.0`. `catalogs/contracts.json` also exposes only a small subset of the public Transport contract surface. This misleads downstream compatibility and contract planning.
  - Proposed packet path: `generated/work-items/proposed/2026-06-16-architecture-reconcile-transport-071-catalog-drift.md`
  - Human action: Review and promote the Architecture reconciliation packet if Transport `0.7.1` is the intended current source of truth.
  - Urgency: high
  - Dedupe/Skipped reason: _None._
- **Transport consumer docs still show stale v0.1.0/v0.4.0 guidance**
  - Recommendation: promote
  - Why: The root README still frames current feature status as `v0.1.0`, and package README installation snippets pin `Version="0.4.0"` while the packages are `0.7.1`. Transport is consumed by Web.Rest, Data, NovOutbox, and planned Flow work, so stale consumer docs increase incorrect setup and version selection risk.
  - Proposed packet path: `generated/work-items/proposed/2026-06-16-transport-refresh-consumer-readmes-for-071.md`
  - Human action: Review and promote the Transport documentation refresh packet.
  - Urgency: normal
  - Dedupe/Skipped reason: _None._

## Identity and Intent

HoneyDrunk.Transport is a Core-sector Live Node. Per `repos/HoneyDrunk.Transport/overview.md`, it owns transport-agnostic messaging, middleware execution, immutable envelopes, Grid context propagation, transport providers for Azure Service Bus, Storage Queue, and InMemory, plus outbox dispatch contracts. Per `repos/HoneyDrunk.Transport/boundaries.md`, it does not own business logic, the Kernel context model, database outbox storage, REST/HTTP concerns, or notification queue management. `catalogs/relationships.json` lists Transport as consuming Kernel and being consumed by Web.Rest, Data, NovOutbox, with Flow as a planned consumer.

## Drift from Definition

- **Changes Requested - Architecture version drift:** `repos/HoneyDrunk.Transport/overview.md` declares `Version: 0.6.0`, and `catalogs/compatibility.json` declares `honeydrunk-transport.currentVersion` as `0.6.0`. The audited repo's package projects all set `<Version>0.7.1</Version>` and the repo log shows `v0.7.1` as the latest release tag. Transport's package references also consume `HoneyDrunk.Kernel.Abstractions` `0.8.0`, while Architecture compatibility still says Transport is compatible with Kernel `>=0.7.0`.
- Source layout matches the broad definition: core package, Azure Service Bus provider, Storage Queue provider, InMemory provider, SandboxNode demo app, documentation, workflows, and unit tests are present.
- The Architecture overview remains thin compared with the repo's current public surface. It omits newer runtime/telemetry types such as `ITransportRuntime`, `ITransportMetrics`, error-handling strategy contracts, and topology/transaction contracts that are present in the repo.

## Boundary Overlap

- No concrete Transport-owned code was found implementing Kernel, Web.Rest, Data, Notify, or business-domain responsibilities.
- Transport correctly keeps database-specific outbox storage out of the repo. `IOutboxStore` remains a contract and `DefaultOutboxDispatcher` publishes pending messages; no database provider implementation was found in Transport.
- The package projects for shipped libraries depend on `HoneyDrunk.Kernel.Abstractions` rather than full `HoneyDrunk.Kernel`, satisfying the Transport repo invariant for library packages. The `SandboxNode` demo app references full Kernel, but it is marked non-packable and is a host/demo surface rather than a shipped Transport library.

## Producer Quality

- Transport is a producer Node. `catalogs/contracts.json` declares `ITransportPublisher`, `ITransportConsumer`, `IMessageHandler<T>`, and `ITransportEnvelope`; the repo additionally exposes public contracts such as `IMessagePublisher`, `IMessageReceiver`, `IMessageSerializer`, `ITransportTopology`, `ITransportTransaction`, `IMessageMiddleware`, `IMessagePipeline`, `IOutboxStore`, `IOutboxDispatcher`, `ITransportHealthContributor`, `ITransportMetrics`, and `ITransportRuntime`. This is Architecture catalog drift rather than a Transport code defect.
- Public API XML documentation generation is enabled in all shipped package projects.
- Repo and package changelogs have released `0.7.0` and `0.7.1` headings. The repo-level changelog still lacks bottom link references for `0.6.0`, `0.7.0`, and `0.7.1`; this is minor documentation polish and is included in the README/doc-refresh packet rather than a separate packet.
- **Changes Requested - Consumer README drift:** The root README has a `v0.1.0 Limitations` section and `What's New in v0.1.0`; package README XML snippets still pin `Version="0.4.0"`. These docs no longer reflect the shipped `0.7.1` package set.

## Consumer Quality

- Transport consumes Kernel through `HoneyDrunk.Kernel.Abstractions` in shipped packages, consistent with `repos/HoneyDrunk.Transport/invariants.md`.
- Package versions are aligned at `0.7.1` across `HoneyDrunk.Transport`, `HoneyDrunk.Transport.AzureServiceBus`, `HoneyDrunk.Transport.StorageQueue`, and `HoneyDrunk.Transport.InMemory`.
- No direct secret reads were found in the shipped Transport source scan. Provider configuration exposes connection-string options where Azure SDKs require them, but the repo does not appear to read secrets directly from environment variables or hardcode secret values.

## Job Performance

- Local verification passed: `dotnet test HoneyDrunk.Transport/HoneyDrunk.Transport.slnx --configuration Release --no-restore` reported 495 passed, 0 failed, 0 skipped. The run emitted NU1900 warnings because the local Azure DevOps package vulnerability feed could not be loaded; tests still completed successfully.
- Recent GitHub run state is healthy: the latest visible Nightly Security run on `main` at `2026-06-16T03:13:15Z` concluded `success`, and the latest Weekly Dependencies run at `2026-06-15T04:38:54Z` concluded `success`.
- PR, Grid Review request, publish, nightly security, weekly dependency, Hive field mirror, SonarQube Cloud, and coverage-baseline ratchet workflows are present.
- `.honeydrunk-review.yaml` has `enabled: true`, so non-draft PRs are eligible for Grid Review.

## Cross-Cutting Health

- No committed secret value was identified during this audit. Secret scanning is enabled through PR and nightly security workflows.
- The tracked-source scan found no `Thread.Sleep` usage.
- Local ignored build output exists on disk (`bin/`, `obj/`, `TestResults/`, and `buildlog.zip`), but `git ls-files` confirmed those artifacts are not tracked.
- The local repo is clean and on `main...origin/main`.

## Findings Summary

### Blocking

- None.

### Changes Requested

- **Phase 2 - Architecture version drift:** Architecture advertises Transport `0.6.0` while the repo packages are `0.7.1` and consume Kernel.Abstractions `0.8.0`. Update Architecture context, compatibility metadata, and contract/catalog surface.
- **Phase 4 - Contract catalog drift:** `catalogs/contracts.json` only declares a subset of Transport's public contracts. Reconcile the catalog to the actual producer surface.
- **Phase 6 - README accuracy:** Transport READMEs still contain `v0.1.0` and `Version="0.4.0"` guidance despite current `0.7.1` packages.

### Suggestions

- **Phase 6 - Changelog polish:** Add bottom link references for `0.6.0`, `0.7.0`, and `0.7.1` in the repo-level changelog if the README refresh touches release docs.
- **Phase 7 - Local hygiene:** The local ignored build artifacts can be cleaned outside this audit if they become noisy for future filesystem walks; no packet created because they are not tracked.

## Recommended Handoffs

1. **Reconcile Transport 0.7.1 Architecture catalog drift** -> `scope` for Architecture packet review and promotion.
2. **Refresh Transport consumer READMEs for current 0.7.1 packages** -> `scope` for Transport docs packet review and promotion.

## Checklist

- [x] Architecture context fully loaded
- [x] Repo walked on disk
- [x] Drift from definition
- [x] Boundary overlap
- [x] Producer quality
- [x] Consumer quality
- [x] Job performance
- [x] Cross-cutting health
