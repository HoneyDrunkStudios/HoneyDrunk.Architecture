---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "adr-0068", "wave-3"]
dependencies: ["work-item:00", "work-item:01"]
adrs: ["ADR-0068", "ADR-0063", "ADR-0042", "ADR-0030", "ADR-0045"]
wave: 3
initiative: adr-0068-background-jobs
node: honeydrunk-notify
---

# Implement the Notify retry pump as an in-Node `BackgroundService` per ADR-0068 D2

## Summary
Stand up the Notify retry pump as a `BackgroundService` inside the `HoneyDrunk.Notify` Worker host per ADR-0068 D2 — the first in-Node consumer under the ADR's D11 first-shipping list. The pump reads Notify's failed-delivery records, applies backoff windows configured in ISO 8601 duration strings (ADR-0063 D6), reads wall-clock via `TimeProvider` (ADR-0063 D1), enforces idempotency on every re-send attempt via `IIdempotencyStore` (ADR-0042 + ADR-0068 D6), and emits the four ADR-0068 D8 observability signals (Pulse `jobs.outcome` counter, `jobs.duration` histogram, lifecycle traces with `correlationId` propagation per invariant 6, and on final failure both an `IErrorReporter` raise per ADR-0045 and a `JobFailure` audit entry per ADR-0030).

## Context
ADR-0068 D11 names "Notify retries (in flight) — Pin to D2 — in-Node `BackgroundService`" as one of the workloads this ADR pins. ADR-0027 (Notify Cloud stand-up) explicitly cites retry scheduling as needing a committed substrate; D2's in-Node `BackgroundService` is the substrate. This packet is the first concrete in-Node `BackgroundService` under ADR-0068.

The retry pump's responsibilities — pinned by ADR-0068 D2 + D6 + D8:

1. **Polling loop** — `while(!ct.IsCancellationRequested) { ... await Task.Delay(interval, ct) }` shape, exactly as D2 describes; interval is `TimeProvider.GetUtcNow()` aware so `FakeTimeProvider` (ADR-0063 D7) can drive tests.
2. **Backoff windows** — ISO 8601 duration strings in configuration (e.g. `PT1M`, `PT5M`, `PT25M` for the canonical 1m/5m/25m progression D7 cites for Container Apps Jobs; the BackgroundService author decides the exact retry semantics per D7's last paragraph, but the 1m/5m/25m progression is the recommended starting point and the precedent for future authors).
3. **Idempotency** — every re-send goes through an `IIdempotencyStore` check using a deterministic key (`notify-retry:<original-message-id>:<retry-attempt-n>` or, where the original message already carries an `IdempotencyKey` per ADR-0042 D5, a derived key per ADR-0042 D3's `SHA256(inbound:relationship)` shape with `relationship="retry"`). Idempotency on retries is mandatory per ADR-0068 D6 — re-execution is a normal failure mode.
4. **Observability** — Pulse `jobs.outcome` counter, Pulse `jobs.duration` histogram, lifecycle traces with `correlationId` propagation. Long-running pump iterations (>60s — unlikely but possible for batch retries) emit `JobProgress` to Audit per ADR-0030. On final failure (max retries exhausted on a given message), raise via `IErrorReporter` per ADR-0045 + emit `JobFailure` to Audit per ADR-0030.

The pump's name as registered for observability tagging is `notify-retry-pump`.

**Boundary clarification (invariant 41).** The pump is **Notify's delivery-mechanics retry** — it re-attempts a delivery that previously failed at the provider boundary (an SMTP timeout, a Twilio 5xx). Communications' cadence/preference logic is **not** re-evaluated on retry. Per invariant 41: "Preference enforcement, cadence rules, and suppression logic for outbound messages live in HoneyDrunk.Communications, not in HoneyDrunk.Notify. Notify owns delivery mechanics; Communications owns decision logic." The retry pump is in scope (delivery mechanics) — the `BackgroundService` lives in Notify.

**HoneyDrunk.Notify is a live Node** (v0.3.0 most recent per the launch tracker). This packet is the only ADR-0068 packet on the `HoneyDrunk.Notify` solution; per invariant 27 it bumps the whole solution one minor version (a new feature — the retry pump). Confirm the current solution version at execution time.

## Scope
- A new `RetryPump` class deriving from `BackgroundService`, registered via `services.AddHostedService<RetryPump>()` in the Notify Worker host.
- Configuration shape for the pump (poll interval, max retries, backoff schedule), bound via `IOptions<RetryPumpOptions>`.
- The deterministic idempotency-key strategy on every re-send attempt.
- The Pulse + Audit + ErrorReporter observability emissions per ADR-0068 D8.
- Tests using `FakeTimeProvider` (ADR-0063 D7) and the InMemory `IIdempotencyStore` (ADR-0042 D2 default test seam) to verify: a duplicate retry attempt produces exactly one send; final failure emits both audit + error; the pump respects cancellation.
- Solution version bump; CHANGELOG/README updates.

## Proposed Implementation
1. **`RetryPump : BackgroundService`** in the Notify Worker host project (likely `HoneyDrunk.Notify` or `HoneyDrunk.Notify.Worker`, depending on the existing project structure — verify at execution time).
   - Constructor takes `TimeProvider` (ADR-0063 D1), `IOptions<RetryPumpOptions>`, `IIdempotencyStore` (ADR-0042), `ITelemetryActivityFactory` (Kernel — for the Pulse signals + traces), `IAuditLog` (ADR-0030/0031), `IErrorReporter` (ADR-0045), an `IRetryQueueReader` or equivalent Notify-internal abstraction for reading failed-delivery records, and an `INotificationSender` or the Notify-internal delivery callback.
   - Override `ExecuteAsync(CancellationToken ct)`:
     ```
     while (!ct.IsCancellationRequested) {
         var iterationStart = TimeProvider.GetUtcNow();
         var iterationCorrelationId = $"notify-retry-pump:{iterationStart:yyyyMMddTHHmmssZ}";
         // pull due-for-retry records
         // for each: claim idempotency key, send, complete, update record
         // emit jobs.outcome + jobs.duration for the iteration
         // long-running progress -> JobProgress audit (if applicable)
         await Task.Delay(options.Value.PollInterval, TimeProvider, ct);
     }
     ```
   - Per-message retry semantics (the `try/catch` around the actual provider send) use **Polly** with the configured backoff schedule. Polly is already a transitive dependency in many Notify projects; if it isn't on the Worker host, add it (it's MIT-licensed and BCL-aligned).
2. **`RetryPumpOptions`** record/class — `PollInterval` (`TimeSpan`, parsed from `"PT30S"` style configuration via ISO 8601 duration string per ADR-0063 D6), `MaxRetries` (default 3 — matches D7 Container Apps Jobs default for cross-Node parity), `BackoffSchedule` (`string[]` of ISO 8601 durations — default `["PT1M", "PT5M", "PT25M"]`).
3. **Idempotency on every send attempt.**
   - If the failed-delivery record's original message carries an `IdempotencyKey` per ADR-0042 D5: derive the retry key via `originalKey.Derive("retry")` (ADR-0042 D3 shape — `SHA256(inbound:retry)`).
   - Otherwise (legacy records without keys): construct `notify-retry:<external-id>:<retry-attempt-n>`. Persist the key with the retry record so subsequent attempts in the same window observe the same key.
   - Call `IIdempotencyStore.TryClaim` before each provider call; if already claimed (a prior attempt succeeded in a concurrent pump iteration or a replay), skip the send and complete the record with `IdempotencyOutcome.AlreadyClaimed`.
   - Standard 7-day TTL (ADR-0042 D4 — Notify is not billing/audit).
4. **Observability — D8 emissions.**
   - `jobs.outcome` counter — tag `{job_name=notify-retry-pump, outcome=success|retry|fail}` — emitted on each per-message attempt outcome (not the per-iteration outcome — D8 reads more naturally at the message granularity for a retry pump).
   - `jobs.duration` histogram — tag `{job_name=notify-retry-pump}` — emitted per iteration with the iteration's total wall-clock time.
   - Lifecycle traces — start/end span per iteration; per-message child spans; `correlationId` propagated through the provider-send call so downstream observability links back (invariant 6).
   - `JobProgress` audit (ADR-0030) — only if an iteration runs >60s. The retry pump's iterations are usually short; surface this only if it triggers.
   - Final-failure handling — when a message exhausts `MaxRetries`, raise via `IErrorReporter` with the full exception + retry count + correlation ID **and** emit a `JobFailure` `AuditEntry` (ADR-0030 category) carrying job name (`notify-retry-pump`), the failed message's external ID, retry count, and last exception summary. Audit category strings are new (per ADR-0068 dispatch plan's cross-cutting note — forward-compatible if Audit later normalizes its category list).
5. **DI registration.** In the Worker host composition: `services.AddOptions<RetryPumpOptions>().Bind(config.GetSection("Notify:RetryPump"));`; `services.AddHostedService<RetryPump>();`. `TimeProvider` is registered as a singleton (`services.TryAddSingleton(TimeProvider.System);`) — if it isn't already; ADR-0063 may already pin its DI registration as a Grid invariant.
6. **Tests.** Unit tests in the Notify test project:
   - Pump iteration with one due record → one send → `jobs.outcome=success` emitted, `jobs.duration` emitted, the message marked complete in the queue.
   - Two concurrent pump iterations claim the same key → only one send is performed (`IIdempotencyStore` rejects the second claim).
   - Provider throws → retry attempts increment; final failure emits `IErrorReporter` raise + `JobFailure` audit.
   - `FakeTimeProvider.Advance(...)` to drive the polling loop without wall-clock waits — **no `Thread.Sleep`** (invariant 51).
   - The pump respects cancellation: `cts.Cancel()` exits the loop within one poll interval.
7. **Versioning.** Bump every non-test `.csproj` in the `HoneyDrunk.Notify` solution to the next minor version in one commit (invariant 27). Repo-level `CHANGELOG.md` new version entry naming the retry-pump feature; per-package CHANGELOG for the Notify Worker host project (the only package with a functional change). README updated if the public composition story changed.

## Affected Files
- A new `RetryPump.cs` (and `RetryPumpOptions.cs`) in the Notify Worker host project.
- Notify host composition / DI registration source.
- Every non-test `.csproj` in the `HoneyDrunk.Notify` solution — version bump.
- Repo-level `CHANGELOG.md`; per-package CHANGELOG for the Worker host package.
- `README.md` if the public composition story changes.
- Notify test project — new retry-pump tests.

## NuGet Dependencies
- The Worker host project gains or updates:
  - `Microsoft.Extensions.Hosting` — almost certainly already present (it's the source of `BackgroundService`). No change expected.
  - `HoneyDrunk.Kernel.Abstractions` — version that exports `IIdempotencyStore` (ADR-0042's packet 02 ships this; `HoneyDrunk.Kernel.Abstractions` `0.8.0` per the ADR-0042 dispatch plan's expected version-bump shape). **Verify the version at execution time** — if ADR-0042's packets have not yet shipped on the NuGet feed, see Human Prerequisites for the cross-init dependency.
  - One of the `HoneyDrunk.Data.Idempotency.*` packages — `HoneyDrunk.Data.Idempotency.Cosmos` for the deployed-environment composition, `HoneyDrunk.Data.Idempotency.InMemory` for the test project. Both ship from ADR-0042's packet 03.
  - `Polly` — if not already a transitive dependency. MIT-licensed; safe to add.
- `HoneyDrunk.Standards` already on every Notify project; no change.
- Confirm exact current versions at execution time.

## Boundary Check
- [x] All code change in `HoneyDrunk.Notify` — the retry pump is delivery mechanics (invariant 41). Routing rule "notification, email, SMS, ... notify, channel → HoneyDrunk.Notify" maps here.
- [x] No contract change in Notify — the pump consumes `IIdempotencyStore` / `IAuditLog` / `IErrorReporter` / `TimeProvider` as shipped by other Nodes / the BCL.
- [x] Communications' preference/cadence/suppression logic is not touched (invariant 41). The retry pump re-attempts an already-decided send; it does not re-decide whether to send.
- [x] No third-party in-process scheduler — only `BackgroundService` + Polly (Polly is a retry library, not a scheduler; it does not violate the ADR-0068 D2 invariant `{N1}` prohibition on Quartz/Hangfire).
- [x] The pump is in-Node (D2) — not a Container Apps Job (D3). The packet 02 deploy workflow is not used here.

## Acceptance Criteria
- [ ] `RetryPump : BackgroundService` exists in the Notify Worker host, registered via `services.AddHostedService<RetryPump>()`
- [ ] The pump reads wall-clock time via `TimeProvider` (ADR-0063 D1); polling interval is parsed from configuration as an ISO 8601 duration string (ADR-0063 D6)
- [ ] Per-message backoff uses Polly with a configured schedule of ISO 8601 duration strings (default `["PT1M", "PT5M", "PT25M"]`); `MaxRetries` defaults to 3 (parity with ADR-0068 D7 Container Apps Jobs default)
- [ ] Every send attempt goes through `IIdempotencyStore.TryClaim` with a deterministic retry-derived key; standard 7-day TTL (ADR-0042 D4)
- [ ] On a duplicate claim, the send is skipped and the record is completed with `IdempotencyOutcome.AlreadyClaimed`
- [ ] Pulse `jobs.outcome` counter is emitted per per-message attempt with tags `{job_name=notify-retry-pump, outcome=success|retry|fail}`
- [ ] Pulse `jobs.duration` histogram is emitted per pump iteration with tag `{job_name=notify-retry-pump}`
- [ ] Lifecycle traces are emitted (iteration start/end span + per-message child spans) with `correlationId` propagation per invariant 6
- [ ] Final failure (exhausted retries on a message) raises via `IErrorReporter` with full exception + retry count + correlation ID, and emits a `JobFailure` `AuditEntry` (job name, external ID, retry count, last exception summary)
- [ ] Tests use `FakeTimeProvider` (ADR-0063 D7) and the InMemory `IIdempotencyStore`; no `Thread.Sleep` (invariant 51)
- [ ] Tests cover: single-record happy path; concurrent claim → exactly one send; provider failure → retries → final failure with audit + error; cancellation exits within one poll interval
- [ ] Every non-test `.csproj` in the solution is at the same new minor version in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new version entry naming the retry-pump feature; per-package CHANGELOG entry on the Worker host package
- [ ] `README.md` updated if the public composition story changed
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **HARD GATE — Do not push this packet until ADR-0042 packets 02 and 03 ship NuGet packages on the feed.** This packet's compile depends on `HoneyDrunk.Kernel.Abstractions` (with `IIdempotencyStore` — ADR-0042 packet 02 ships 0.8.0) and `HoneyDrunk.Data.Idempotency.Cosmos` / `HoneyDrunk.Data.Idempotency.InMemory` (ADR-0042 packet 03). ADR-0042 is **Proposed** at the time this packet was authored; its packets have not yet been executed or merged. Until those packages are published, the executor cannot resolve the references and the PR will not build. Cross-initiative — not encoded in `dependencies:` (which only resolves within the initiative folder). The operator confirms package availability on the feed (search `HoneyDrunk.Kernel.Abstractions` version >= 0.8.0 and the `HoneyDrunk.Data.Idempotency.*` family in the package registry) **before** branching for this packet. **Agents never tag or publish — the operator runs that ceremony.**
- [ ] **Upstream NuGet packages must be published before this packet compiles.** This packet's projects reference `HoneyDrunk.Kernel.Abstractions` (for `IIdempotencyStore`), `HoneyDrunk.Data.Idempotency.Cosmos` (for deployed composition), and `HoneyDrunk.Data.Idempotency.InMemory` (for tests). Those artifacts exist on the package feed only after a human pushes a git release tag in `HoneyDrunk.Kernel` and `HoneyDrunk.Data` respectively — **agents never tag or publish.** If ADR-0042's packets (`adr-0042-idempotency` packets 02 + 03) have not yet shipped at this packet's execution time, hold this packet until they have. ADR-0042 packet 02 ships `HoneyDrunk.Kernel.Abstractions` 0.8.0 (the contracts) and packet 03 ships the `HoneyDrunk.Data.Idempotency.*` family. Cross-initiative — not encoded in `dependencies:` (which only resolves within the initiative folder).
- [ ] The Cosmos dedup account (provisioned by ADR-0042 packet 03's Human Prerequisites) must exist in each environment Notify deploys to before Notify's deployed composition can resolve the Cosmos `IIdempotencyStore` at runtime. Notify's consumer-group gets the 7-day-TTL container/configuration.
- [ ] The Cosmos connection secret must be seeded into `kv-hd-notify-{env}` so Notify's `ISecretStore` can resolve it (invariant 9).
- [ ] Notify's Worker / Function Managed Identity needs the Cosmos data-plane RBAC role on the dedup account.
- [ ] **The code work in this packet does not require the live Cosmos account** — tests run against the InMemory store. It does, however, require the upstream packages above to be published.

## Referenced ADR Decisions
**ADR-0068 D2 — In-Node `BackgroundService`.** "Every Node that needs in-process recurring or background work uses ASP.NET Core's built-in `IHostedService` interface (typically via the `BackgroundService` base class). No Quartz, no Hangfire, no third-party scheduler dependency." `TimeProvider` (ADR-0063 D1) for wall-clock reads; `FakeTimeProvider` (ADR-0063 D7) for tests. ADR-0068's named first consumer under D2 (D11 row): "Notify retry pump."

**ADR-0068 D6 — Idempotency on every job.** Every state-mutating job is idempotent. Notify's retry pump mutates state (sends a notification) — fully bound. Uses `IIdempotencyStore` from ADR-0042.

**ADR-0068 D7 — Retry policy defaults (Container Apps Jobs context).** 3 retries, exponential 1m/5m/25m. Per D7's last paragraph, in-Node `BackgroundService` retry semantics are author-decided; the pump adopts these defaults for cross-substrate parity, with `RetryPumpOptions` allowing per-deployment override.

**ADR-0068 D8 — Observability.** Pulse `jobs.outcome` counter, Pulse `jobs.duration` histogram, lifecycle traces with `correlationId` propagation per invariant 6, long-running >60s progress to Audit as `JobProgress` (ADR-0030), final-failure errors via `IErrorReporter` (ADR-0045) and `JobFailure` audit (ADR-0030).

**ADR-0042 D2 — `IIdempotencyStore`.** Consumer-side dedup state, per consumer-group, durable at Tier 1, default Cosmos backing. 7-day standard TTL (D4 — Notify is not billing/audit).

**ADR-0042 D3 — Downstream-key derivation.** A downstream message's key is `SHA256(inbound:relationship)` of the inbound key. The retry pump's derived-key form `originalKey.Derive("retry")` follows this shape exactly.

**ADR-0063 D1 — `TimeProvider` substrate.** Every wall-clock read goes through `TimeProvider`.

**ADR-0063 D6 — Cron and duration format.** 5-field UTC cron; ISO 8601 duration strings for intervals.

**ADR-0063 D7 — Test seam.** `FakeTimeProvider` advances time in tests.

**ADR-0045 D3 — `IErrorReporter`.** Final-failure errors flow through the Pulse `IErrorReporter` facade.

**ADR-0030 — Audit substrate.** `JobProgress` and `JobFailure` are new audit-category strings; ride the existing `AuditEntry` shape. Forward-compatible if Audit later normalizes its category list.

## Constraints
> **Invariant 41 — Preference enforcement, cadence rules, and suppression logic for outbound messages live in HoneyDrunk.Communications, not in HoneyDrunk.Notify.** The retry pump is delivery mechanics; it re-attempts an already-decided send. It MUST NOT re-evaluate Communications-owned decisions (no `IPreferenceStore` read, no `ICadencePolicy` check, no decision-log emit) inside the pump.

> **Invariant `{N1}` (Proposed, tied to ADR-0068) — In-Node `BackgroundService`.** No Quartz, no Hangfire, no third-party in-process scheduler. Polly is a retry library, not a scheduler — its use is permitted and expected. (`{N1}` is the first of the four ADR-0068 invariant numbers claimed in packet 01 from `constitution/invariant-reservations.md`; resolve at execution time and substitute consistently with packet 01.)

> **Invariant 51 — No `Thread.Sleep` in tests.** Tests use `FakeTimeProvider.Advance(...)`; the pump uses `Task.Delay(..., TimeProvider, ct)`.

> **Invariant 6 — `correlationId` propagation.** The pump's iteration `correlationId` is propagated through every per-message span and through the provider-send call.

> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** Audit entries and Pulse signals carry job-name, retry-count, exception-summary metadata — never message bodies, recipient addresses (PII), or provider credentials.

> **Invariant 27 — Solution version bumps are atomic.** Every non-test `.csproj` in the Notify solution moves to the same new minor version in one commit.

- **Idempotency on retries is mandatory** — every send goes through `IIdempotencyStore.TryClaim`; a duplicate claim short-circuits the send.
- **The pump does NOT use packet 02's `job-deploy-container-apps-job.yml` workflow.** It is in-Node — it ships as part of the Notify Worker host's container image, deployed by the existing `job-deploy-container-app.yml` workflow (no change to that workflow needed).
- **Audit category strings (`JobProgress`, `JobFailure`) are new.** Ride the existing `AuditEntry` shape; if Audit later normalizes its category list, this packet's emits are forward-compatible.

## Labels
`feature`, `tier-2`, `ops`, `adr-0068`, `wave-3`

## Agent Handoff

**Objective:** Ship the Notify retry pump as the first in-Node `BackgroundService` under ADR-0068 D2.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: First concrete consumer under ADR-0068 D2. The pump becomes the pattern future in-Node background work (AI cost-ledger drain, audit batch flush) follows.
- Feature: ADR-0068 Background Job and Recurring Work Substrate rollout, Wave 3.
- ADRs: ADR-0068 D2/D6/D7/D8 (primary), ADR-0063 D1/D6/D7 (clock/cron/test seam), ADR-0042 D2/D3/D4 (idempotency), ADR-0030 (`JobProgress`/`JobFailure` audit categories), ADR-0045 D3 (`IErrorReporter`).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft; the substrate-choice note in `boundaries.md` lands first so the executor reads the boundary doc and sees the substrate decision.

**Constraints:**
- Polly is the per-message retry library; no third-party scheduler (invariant `{N1}` Proposed; tied to ADR-0068 D2).
- `TimeProvider` everywhere, `FakeTimeProvider` in tests, no `Thread.Sleep` (invariants 51 + ADR-0063 D1/D7).
- Idempotency on every send attempt (invariant `{N3}` Proposed; ADR-0068 D6 + ADR-0042 D2/D3).
- Invariant 41 — Notify does delivery mechanics; no preference/cadence/suppression logic in the pump.
- Solution version bump is atomic across all non-test `.csproj` (invariant 27).

**Key Files:**
- `src/HoneyDrunk.Notify/.../RetryPump.cs` (new) — exact project path TBD at execution time based on the Notify solution's current structure.
- `src/HoneyDrunk.Notify/.../RetryPumpOptions.cs` (new).
- Notify Worker host composition / DI registration source.
- `tests/HoneyDrunk.Notify.Tests/.../RetryPumpTests.cs` (new).

**Contracts:** None changed — consumes `IIdempotencyStore` / `IAuditLog` / `IErrorReporter` / `TimeProvider` from other Nodes / the BCL.
