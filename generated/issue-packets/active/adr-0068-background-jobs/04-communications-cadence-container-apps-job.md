---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Communications
labels: ["feature", "tier-2", "ops", "adr-0068", "wave-3"]
dependencies: ["packet:01", "packet:02"]
adrs: ["ADR-0068", "ADR-0063", "ADR-0042", "ADR-0030", "ADR-0045", "ADR-0019", "ADR-0015"]
wave: 3
initiative: adr-0068-background-jobs
node: honeydrunk-communications
---

# Stand up the Communications cadence/drip-campaign scheduler as the first cross-Node Container Apps Job per ADR-0068 D3

## Summary
Add a new schedule-triggered Azure Container Apps Job to the `HoneyDrunk.Communications` solution — the cadence/drip-campaign scheduler — as the first cross-Node Container Apps Job under ADR-0068 D3 (D11's named first consumer for the cross-Node substrate). The Job is a small console-app binary (`Program.cs` + `Main`) that wakes on schedule, walks Communications' cadence + drip-campaign data for due intents, dispatches each through `ICommunicationOrchestrator` (the existing decision-and-delivery surface from ADR-0019), and exits. Schedule is 5-field UTC cron per ADR-0063 D6 (initial cadence `*/30 * * * *` — every 30 minutes — confirmed in-PR; per-environment configurable). Idempotency per ADR-0068 D6 uses key `comms-cadence:{scheduledInstant:yyyyMMddTHHmmssZ}` against `IIdempotencyStore` (ADR-0042). Deploys via the new reusable workflow from packet 02 to `caj-hd-comms-cadence-{env}`. D7 retry defaults (3 retries, 1m/5m/25m exponential) wired in the Container Apps Jobs manifest. D8 observability emissions (Pulse `jobs.outcome` / `jobs.duration`, lifecycle traces, long-running progress to Audit, final-failure to `IErrorReporter` + `JobFailure` audit) wired into the Job body.

## Context
ADR-0068 D11 names "Communications cadence (imminent) — Pin to D3 — Container Apps Jobs" as one of the workloads this ADR pins. ADR-0019 (Communications stand-up) commits cadence/drip-campaign scheduling as a capability of Communications. Before ADR-0068, no substrate was decided; the cadence work was deferred. This packet ships the substrate and the first concrete cross-Node Job on it.

The cadence scheduler's responsibilities:

1. **Wake on schedule** — Container Apps Jobs cron trigger fires on the configured cadence (initial `*/30 * * * *`, 5-field UTC per ADR-0063 D6).
2. **Read due intents** — query Communications' data for `IMessageIntent`s whose cadence/drip-campaign schedule names this `scheduledInstant` (or one within tolerance).
3. **Dispatch via `ICommunicationOrchestrator`** — for each due intent, call `ICommunicationOrchestrator.Send(intent, ...)`. The orchestrator (ADR-0019) is the existing decision-and-delivery surface — preferences, cadence rules, suppression, decision-log emission all run inside it. The Job is **not** a delivery path bypass.
4. **Per-intent idempotency** — every dispatch goes through `IIdempotencyStore` with key `comms-cadence:{intentId}:{scheduledInstant:yyyyMMddTHHmmssZ}` (intent-scoped so two distinct intents at the same instant don't collide). The job-level key (`comms-cadence:{scheduledInstant:yyyyMMddTHHmmssZ}`, per ADR-0068 D6's deterministic-schedule formula) guards against double-trigger of the *job itself*; the intent-scoped key guards each dispatch within the job.
5. **Exit when done** — Container Apps Jobs replicas terminate when the entry point returns (or when `replicaTimeout` elapses). The Job is single-invocation, not long-running.

**Boundary clarification.** The Job is `HoneyDrunk.Communications` because Communications owns cadence decision logic per invariant 41. It composes the orchestrator (in-process within the Job — the Job binary references `HoneyDrunk.Communications` directly), which then delegates delivery to Notify per ADR-0019. So the Job is a *Communications* job; the in-process Communications→Notify hop inside the orchestrator stays unchanged.

**Local-dev story (ADR-0068 D9).** The Job binary's `Main` is invocable as `dotnet run` from the Communications solution. A timer-driven host harness (a small `HostBuilder` + a `BackgroundService` that fires the Job entry on a developer-controlled cadence) lives in the Communications test project for local cadence-shape testing without Azure.

**Communications is a live Node** (v0.2.0 most recent per the overview). This packet is the only ADR-0068 packet on the `HoneyDrunk.Communications` solution; per invariant 27 it bumps the solution one minor version (new runtime artifact — the Job binary). Confirm the current solution version at execution time.

**First Container Apps Job in production.** This is the studio's first Container Apps Job deploy. The deploy workflow (packet 02) is also new; expect a small amount of iteration on both — see the dispatch plan's Cross-Cutting Concerns.

## Scope
- A new project in the Communications solution (e.g. `HoneyDrunk.Communications.Jobs.Cadence` or `HoneyDrunk.Communications.Cadence`, name per the Communications repo's existing project-naming convention — verify at execution time) that produces the Job binary.
- `Program.cs` with `Main` that:
  - Builds a minimal `HostBuilder` (or runs without one, depending on the in-Node convention) wiring the orchestrator and dependencies.
  - Composes `IIdempotencyStore`, `IAuditLog`, `IErrorReporter`, `TimeProvider`, `ICommunicationOrchestrator`.
  - Calls a `Run(scheduledInstant, ct)` method that does the iteration body.
  - Returns / `Environment.Exit(...)` cleanly on success or failure.
- A `Dockerfile` for the Job container image (the new container image; packet 02's workflow builds + pushes it to `acrhdshared{env}`).
- The Container Apps Jobs manifest (a Bicep file or the input parameters for packet 02's `az containerapp job create` invocation) declaring `triggerType: Schedule`, the cron expression, replica policy (`replicaCompletionCount: 1`, `parallelism: 1`, `replicaTimeout: 1800`), retry policy (`replicaRetryLimit: 3` per ADR-0068 D7).
- The Communications consuming release workflow change that calls packet 02's `job-deploy-container-apps-job.yml` reusable workflow on tag → environment per ADR-0033.
- A local-dev harness (test project) for `dotnet run` invocation of the Job entry with `FakeTimeProvider`.
- Pulse + Audit + ErrorReporter observability emissions per ADR-0068 D8.
- Tests: `FakeTimeProvider`-driven idempotency check (job-level and intent-level), happy path (two due intents → two dispatches → two `jobs.outcome=success` emits), provider failure → final-failure handling, replay (same `scheduledInstant` → no double-dispatch via job-level idempotency).
- Solution version bump; CHANGELOG/README updates.

## Proposed Implementation
1. **New project — the Job binary.** Add `HoneyDrunk.Communications.Cadence` (or the existing-conventions-aligned name) to the Communications solution. `<OutputType>Exe</OutputType>`, `TargetFramework=net10.0`, references `HoneyDrunk.Communications` (the runtime package) for the orchestrator, `HoneyDrunk.Kernel.Abstractions` for `IIdempotencyStore`, `HoneyDrunk.Data.Idempotency.Cosmos` for the deployed backing, `HoneyDrunk.Audit.Abstractions` for `IAuditLog`, `HoneyDrunk.Telemetry.Abstractions` (or wherever `IErrorReporter` lands per ADR-0045) for the error reporter. **Verify NuGet versions at execution time** — see Human Prerequisites for the cross-init dependency on ADR-0042 / ADR-0045 release tags.
2. **`Program.cs`.** Pseudocode:
   ```csharp
   public static async Task<int> Main(string[] args) {
       using var host = Host.CreateApplicationBuilder(args)
           .ConfigureServices(s => { /* register everything */ })
           .Build();
       await host.StartAsync();
       try {
           var runner = host.Services.GetRequiredService<CadenceJobRunner>();
           var scheduledInstant = TimeProvider.System.GetUtcNow(); // approximate; the platform doesn't pass schedule time directly — use the current minute boundary
           await runner.RunAsync(scheduledInstant, host.Services.GetRequiredService<IHostApplicationLifetime>().ApplicationStopping);
           return 0;
       } catch (Exception ex) {
           // ErrorReporter raise + JobFailure audit; rethrow if needed for non-zero exit
           host.Services.GetRequiredService<IErrorReporter>().Capture(ex, /* context */);
           return 1;
       } finally {
           await host.StopAsync();
       }
   }
   ```
3. **`CadenceJobRunner.RunAsync(scheduledInstant, ct)`.**
   - **Job-level idempotency.** `var jobKey = $"comms-cadence:{scheduledInstant:yyyyMMddTHHmmssZ}"; var claim = await idempotencyStore.TryClaim(jobKey, TimeSpan.FromDays(7), ct);` — if not claimed (already-ran indicator), log and return early. Per ADR-0042 D4 standard 7-day TTL (Communications is neither billing nor audit).
   - **Read due intents.** Query the Communications data layer for intents due at or before `scheduledInstant` with cadence tolerance.
   - **Per-intent dispatch.** Partial-batch posture: **continue-on-error** (decided in this packet — see Constraints). A per-intent orchestrator failure is captured (`IErrorReporter.Capture` + `JobFailure` audit emit) and the loop proceeds to the next intent; the batch is not aborted on the first failure. The Job's exit code is non-zero only if `RunAsync` itself throws (an infrastructural failure — idempotency-store outage, data-layer outage); per-intent failures do not bubble out of the loop.
     ```
     foreach (var intent in dueIntents) {
         var intentKey = $"comms-cadence:{intent.IntentId}:{scheduledInstant:yyyyMMddTHHmmssZ}";
         var intentClaim = await idempotencyStore.TryClaim(intentKey, TimeSpan.FromDays(7), ct);
         if (intentClaim.Outcome == AlreadyClaimed) continue;
         try {
             await orchestrator.SendAsync(intent, ct);
             jobsOutcomeCounter.Add(1, new(...) { ["outcome"] = "success" });
             await idempotencyStore.Complete(intentClaim, IdempotencyOutcome.Succeeded);
         } catch (Exception ex) {
             jobsOutcomeCounter.Add(1, new(...) { ["outcome"] = "fail" });
             await idempotencyStore.Complete(intentClaim, IdempotencyOutcome.Failed);
             // continue-on-error: surface per-intent failure via IErrorReporter + JobFailure audit; do NOT throw — loop proceeds to next intent.
             errorReporter.Capture(ex, new { job_name = "comms-cadence", intent_id = intent.IntentId, scheduled_instant = scheduledInstant });
             auditLog.Append(new AuditEntry(category: "JobFailure", /* job_name, intent_id, retry_count (from env var), last_exception_summary */));
             continue;
         }
     }
     await idempotencyStore.Complete(claim, IdempotencyOutcome.Succeeded);
     jobsDurationHistogram.Record(stopwatch.ElapsedSeconds, new(...) { ["job_name"] = "comms-cadence" });
     ```
   - **Long-running progress.** If `stopwatch.Elapsed > TimeSpan.FromSeconds(60)`, emit a `JobProgress` `AuditEntry` per ADR-0030 D8 with the intent index, total intent count, and elapsed time.
4. **`Dockerfile`.** Minimal — `mcr.microsoft.com/dotnet/runtime:10.0` base, copy the published binary, `ENTRYPOINT ["dotnet", "HoneyDrunk.Communications.Cadence.dll"]`.
5. **Container Apps Jobs manifest.** Either a Bicep file in `infrastructure/`, or as input parameters supplied to packet 02's reusable workflow from the Communications release workflow — decide at execution time based on the Communications repo's existing infrastructure conventions. The shape:
   - `containerapps-job: caj-hd-comms-cadence-{env}` (note `comms-cadence` is 12 chars — within the 13-char invariant 19 limit).
   - `containerapps-environment: cae-hd-{env}`.
   - `trigger-type: Schedule`.
   - `cron-expression: "*/30 * * * *"` (initial; per-environment overridable). 5-field UTC per ADR-0063 D6.
   - `replica-completion-count: 1`, `parallelism: 1`, `replica-timeout-seconds: 1800`.
   - `replica-retry-limit: 3` per ADR-0068 D7.
   - Secrets via Key Vault references (orchestrator's data store connection, idempotency store connection, etc.) — same Key Vault-backed pattern as Container Apps proper.
6. **Communications release workflow change.** Amend Communications' release workflow (or add a new one if none exists for the Job) so a SemVer tag triggers packet 02's `job-deploy-container-apps-job.yml` per ADR-0033's tag→environment mapping. Path-filtered to the new Job project for dev continuous deploy.
7. **Observability emissions.**
   - `jobs.outcome` counter — per-intent dispatch outcome. Tags `{job_name=comms-cadence, outcome=success|fail}`.
   - `jobs.duration` histogram — recorded once at job end. Tag `{job_name=comms-cadence}`.
   - Lifecycle traces — span over `RunAsync` with `correlationId = $"comms-cadence:{scheduledInstant:yyyyMMddTHHmmssZ}"`; child span per intent dispatch with the intent ID; `correlationId` propagated into the orchestrator call (invariant 6).
   - `JobProgress` audit emit on long-running iterations (>60s).
   - **Final-failure handling.** On exhausted retries (the platform exhausts `replicaRetryLimit: 3`; the Job's final replica's exit code is non-zero), the platform records the failure. The Job's own `Program.cs` `catch` raises via `IErrorReporter` (ADR-0045 D3) and emits a `JobFailure` `AuditEntry` (ADR-0030) with job name, scheduled instant, retry attempt (read from the env var the platform sets), and last exception summary — *every* exception path emits both, regardless of whether this is the final retry, because the Job binary can't directly observe "this was the last retry" — the platform decides. ADR-0045 deduplicates by `problem_id` so multiple retries don't multiply error reports.
8. **Local-dev harness.** In the Communications test project, add a small `HostBuilder` + `BackgroundService`-driven harness that fires `CadenceJobRunner.RunAsync` on a developer-controlled cadence using `FakeTimeProvider`. `dotnet run --project HoneyDrunk.Communications.Cadence` invokes the same entry locally without the harness; the harness is for cadence-shape testing.
9. **Tests.**
   - Two due intents → two `jobs.outcome=success` emits → one `jobs.duration` emit → two `IIdempotencyStore` completes.
   - Replay at the same `scheduledInstant` → job-level idempotency claim rejects → no work done → log emitted.
   - One intent fails inside the orchestrator → `jobs.outcome=fail` emitted for that intent, `JobFailure` audit + `IErrorReporter` raise emitted, **other intents still dispatched** (continue-on-error posture per this packet — verified by asserting the second intent's `jobs.outcome=success` emit lands after the first intent's failure).
   - Long-running scenario (the test harness drives the duration > 60s) → `JobProgress` audit emit observed.
   - All time-driven tests use `FakeTimeProvider` (ADR-0063 D7); no `Thread.Sleep` (invariant 51).
10. **Versioning.** Bump every non-test `.csproj` in the `HoneyDrunk.Communications` solution to the next minor version in one commit (invariant 27). Repo-level `CHANGELOG.md` new version entry naming the cadence Job; per-package CHANGELOG for the new Cadence Job project. `README.md` updated to mention the new Job deployable.

## Affected Files
- A new project under the Communications solution — `HoneyDrunk.Communications.Cadence` (or convention-aligned name): `.csproj`, `Program.cs`, `CadenceJobRunner.cs`, `CadenceJobOptions.cs`, `Dockerfile`.
- Communications local-dev harness in the test project — a `HostBuilder` shim and tests.
- A Container Apps Jobs manifest — either `infrastructure/comms-cadence-job.bicep` or the input parameters supplied to packet 02's reusable workflow from the Communications release workflow.
- Communications' release workflow (`.github/workflows/release.yml` or whatever the repo uses) — add a step that calls packet 02's `job-deploy-container-apps-job.yml`.
- Every non-test `.csproj` in the `HoneyDrunk.Communications` solution — version bump.
- Repo-level `CHANGELOG.md`; per-package CHANGELOG for the new Cadence Job project.
- `README.md` updated to mention the new Job deployable.

## NuGet Dependencies
- The new `HoneyDrunk.Communications.Cadence` project gains:
  - `HoneyDrunk.Communications` (runtime — the orchestrator).
  - `HoneyDrunk.Kernel.Abstractions` (for `IIdempotencyStore`, `IGridContext`, etc.) — version per ADR-0042's packet 02 (0.8.0).
  - `HoneyDrunk.Data.Idempotency.Cosmos` (deployed-environment backing) — version per ADR-0042's packet 03.
  - `HoneyDrunk.Audit.Abstractions` (for `IAuditLog`, `AuditEntry`) — current shipped version.
  - `HoneyDrunk.Telemetry.Abstractions` (for `IErrorReporter`) — version per ADR-0045's packet 02. If ADR-0045 has not yet shipped, see Human Prerequisites.
  - `Microsoft.Extensions.Hosting` for `Host.CreateApplicationBuilder`.
- Communications test project gains:
  - `HoneyDrunk.Data.Idempotency.InMemory` — version per ADR-0042's packet 03.
  - `Microsoft.Extensions.TimeProvider.Testing` (for `FakeTimeProvider`).
- `HoneyDrunk.Standards` already on every Communications project; no change.
- Confirm exact current versions at execution time.

## Boundary Check
- [x] All code change in `HoneyDrunk.Communications`. Routing rule "communications, cadence, drip, preferences, suppression, decision-log → HoneyDrunk.Communications" maps here.
- [x] The cadence Job is Communications' work (invariant 41 — Communications owns cadence decisions; Notify owns delivery mechanics). The Job composes `ICommunicationOrchestrator` from Communications and lets *it* delegate to Notify per ADR-0019.
- [x] The Job consumes (does not redefine) `IIdempotencyStore`, `IAuditLog`, `IErrorReporter`, `TimeProvider`. No new contract surface.
- [x] Container Apps Jobs is the substrate per ADR-0068 D3 (cross-Node recurring orchestration). Not in-Node `BackgroundService` (D2) — the cadence work spans Nodes (Communications → Notify via the orchestrator) and runs on a schedule, not inside a Node's host process.
- [x] No Functions timer trigger (ADR-0068 D7 grandfathers Vault.Rotation only; new cross-Node work uses Container Apps Jobs per D3 + invariant `{N2}` Proposed).
- [x] Naming `caj-hd-comms-cadence-{env}` — service name `comms-cadence` is 12 chars, within the 13-char invariant 19 limit; matches the `caj-hd-{service}-{env}` convention from invariant `{N2}` Proposed (ADR-0068 D3).

## Acceptance Criteria
- [ ] A new `HoneyDrunk.Communications.Cadence` (or convention-aligned name) project exists in the Communications solution, producing a console-app binary with `Program.cs` + `Main`
- [ ] The Job runs as a Container Apps Job named `caj-hd-comms-cadence-{env}` (service name within the 13-char invariant 19 limit) in the shared `cae-hd-{env}` Environment, deployed via packet 02's reusable workflow
- [ ] Trigger is `Schedule` with cron `*/30 * * * *` (initial — per-environment configurable in the manifest); 5-field UTC per ADR-0063 D6
- [ ] Replica policy: `replicaCompletionCount: 1`, `parallelism: 1`, `replicaTimeout: 1800`; retry policy `replicaRetryLimit: 3` per ADR-0068 D7
- [ ] Job-level idempotency uses key `comms-cadence:{scheduledInstant:yyyyMMddTHHmmssZ}` against `IIdempotencyStore` with 7-day TTL (ADR-0042 D4 standard)
- [ ] Per-intent idempotency uses key `comms-cadence:{intentId}:{scheduledInstant:yyyyMMddTHHmmssZ}` against `IIdempotencyStore`
- [ ] Each due intent is dispatched through `ICommunicationOrchestrator` (Communications owns the decision, per invariant 41 and ADR-0019) — the Job does not bypass the orchestrator
- [ ] Pulse `jobs.outcome` counter emitted per-intent with tags `{job_name=comms-cadence, outcome=success|fail}`
- [ ] Pulse `jobs.duration` histogram emitted at job end with tag `{job_name=comms-cadence}`
- [ ] Lifecycle traces emitted with `correlationId = comms-cadence:{scheduledInstant:yyyyMMddTHHmmssZ}` propagated into the orchestrator call per invariant 6
- [ ] Long-running (>60s) iterations emit `JobProgress` audit entries (ADR-0030)
- [ ] Exceptions from the orchestrator emit `JobFailure` audit (ADR-0030) and raise via `IErrorReporter` (ADR-0045)
- [ ] Partial-batch posture is **continue-on-error** (decided in this packet) — per-intent failures are captured via `IErrorReporter` + `JobFailure` audit and the loop proceeds to the next intent; `RunAsync` only propagates infrastructural failures (idempotency-store / data-layer outage). The PR description records the chosen posture.
- [ ] Local-dev harness in the test project drives `CadenceJobRunner.RunAsync` with `FakeTimeProvider`; `dotnet run --project HoneyDrunk.Communications.Cadence` invokes the binary locally
- [ ] Tests cover: happy path (two intents → two dispatches), replay rejection by job-level idempotency, per-intent failure handling, long-running > 60s `JobProgress`
- [ ] No `Thread.Sleep` in tests (invariant 51); `FakeTimeProvider` drives all time-dependent assertions (ADR-0063 D7)
- [ ] Communications release workflow calls packet 02's `job-deploy-container-apps-job.yml` for the Cadence Job per ADR-0033's tag→environment mapping
- [ ] Dockerfile uses `mcr.microsoft.com/dotnet/runtime:10.0` (or current equivalent) and runs the `dotnet HoneyDrunk.Communications.Cadence.dll` entry
- [ ] Every non-test `.csproj` in the solution is at the same new minor version in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new version entry naming the cadence Job; per-package CHANGELOG entry on the new Cadence Job project
- [ ] `README.md` updated to mention the new Job deployable
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Packet 02's `job-deploy-container-apps-job.yml` must be merged and on `main` before this packet's deploy step can call it.** Hard same-initiative dependency, encoded in `dependencies: ["packet:01", "packet:02"]`.
- [ ] **HARD GATE — Do not push this packet until ADR-0042 packets 02 and 03 ship NuGet packages on the feed.** This packet's compile depends on `HoneyDrunk.Kernel.Abstractions` (with `IIdempotencyStore` — ADR-0042 packet 02 ships 0.8.0) and `HoneyDrunk.Data.Idempotency.Cosmos` / `HoneyDrunk.Data.Idempotency.InMemory` (ADR-0042 packet 03). ADR-0042 is **Proposed** at the time this packet was authored; its packets have not yet been executed or merged. Until those packages are published, the executor cannot resolve the references and the PR will not build. Cross-initiative — not encoded in `dependencies:` (which only resolves within the initiative folder). The operator confirms package availability on the feed (search `HoneyDrunk.Kernel.Abstractions` version >= 0.8.0 and the `HoneyDrunk.Data.Idempotency.*` family in the package registry) **before** branching for this packet. **Agents never tag or publish — the operator runs that ceremony.**
- [ ] **Verify the `IErrorReporter` package home against ADR-0045's current state.** The reference text above lists `HoneyDrunk.Telemetry.Abstractions` as the package home; ADR-0045 may have settled the surface differently (e.g. `HoneyDrunk.Pulse.Abstractions`, a dedicated `HoneyDrunk.ErrorReporting.Abstractions`, or kept it under another Node's contracts package). At packet execution time, check ADR-0045's current Status and the latest packet set in `adr-0045-grid-wide-error-tracking/`:
  - If ADR-0045's packet 02 has shipped: use the actual published package name and version; update `## NuGet Dependencies` in this packet body to match.
  - If ADR-0045's packet 02 has NOT shipped: wire a local TODO-comment `IErrorReporter`-shaped seam in the Cadence Job binary (a private `interface IErrorReporterSeam { void Capture(Exception, object?); }` with a no-op default registration), document the seam in the Cadence Job's README and in this packet's PR description, and file a follow-up task to lift the seam to the real `IErrorReporter` once ADR-0045 lands. The seam falls back is acceptable explicitly — do NOT block this packet on ADR-0045 if the operator decides to ship the Cadence Job with a seam.
- [ ] **Upstream NuGet packages must be published before this packet compiles.**
  - `HoneyDrunk.Kernel.Abstractions` with `IIdempotencyStore` — ships from ADR-0042 packet 02 (0.8.0). If ADR-0042's packets have not yet shipped on the NuGet feed, hold this packet until they have.
  - `HoneyDrunk.Data.Idempotency.Cosmos` (deployed) and `HoneyDrunk.Data.Idempotency.InMemory` (tests) — ship from ADR-0042 packet 03.
  - `HoneyDrunk.Telemetry.Abstractions` with `IErrorReporter` — ships from ADR-0045 packet 02 (package home verified per the prerequisite above). If ADR-0045 has not yet shipped, hold this packet OR wire a TODO-comment `IErrorReporter`-shaped seam and lift it once ADR-0045 lands (per the verification prerequisite above).
  Cross-initiative — not encoded in `dependencies:` (which only resolves within the initiative folder). The operator confirms upstream package availability before starting this packet.
- [ ] **Container Apps Environment** — the shared `cae-hd-{env}` already exists per ADR-0015's rollout; no new Environment provisioning. Confirm at first deploy.
- [ ] **Cosmos dedup account** — provisioned by ADR-0042 packet 03's Human Prerequisites; the Communications Job's Managed Identity needs the Cosmos data-plane RBAC role on the dedup account in each env.
- [ ] **Cosmos connection secret** — must be seeded into `kv-hd-comms-{env}` (or whatever Communications' Key Vault naming is per invariant 17) so the Job's `ISecretStore` can resolve it (invariant 9).
- [ ] **Container Apps Contributor (or Contributor) role** — the deploy identity needs this on the resource group to create `Microsoft.App/jobs/*` resources. Per packet 02's Human Prerequisites, **verify in the Azure portal at first deploy** that the existing OIDC deploy identity has the role; if not, a one-time RBAC grant via the portal is needed.
- [ ] **First Container Apps Job deploy** — the operator performs the first deploy with eyes on the Azure portal to verify the Job resource is created with the expected `triggerType`, cron, replica, and retry settings. Subsequent deploys are mechanical via the workflow.

## Referenced ADR Decisions
**ADR-0068 D3 — Cross-Node Container Apps Jobs.** Every cross-Node recurring or event-driven job runs on Azure Container Apps Jobs. Communications cadence is named in D11 as the first consumer.

**ADR-0068 D6 — Idempotency on every job.** Schedule-triggered jobs use the deterministic key `${jobName}:${scheduledInstant:yyyyMMddTHHmmssZ}`. Job-level and per-intent keys both use this shape, with the intent ID inserted in the per-intent variant.

**ADR-0068 D7 — Retry policy defaults.** 3 retries, exponential 1m/5m/25m. Wired in the Container Apps Jobs manifest as `replicaRetryLimit: 3`; the exponential backoff is the platform's default behaviour for that limit.

**ADR-0068 D8 — Observability.** Pulse `jobs.outcome` counter, Pulse `jobs.duration` histogram, lifecycle traces with `correlationId` propagation per invariant 6, long-running >60s progress to Audit as `JobProgress` (ADR-0030), final-failure errors via `IErrorReporter` (ADR-0045) and `JobFailure` audit (ADR-0030).

**ADR-0068 D9 — Local-dev story.** Container Apps Jobs don't run locally. The binary runs as a console app (`dotnet run`); optionally under a timer-driven host harness for cadence-shape testing.

**ADR-0068 D10 — Job code organization.** Each Node owns its own jobs. The cadence Job lives in `HoneyDrunk.Communications`.

**ADR-0068 D11 — Migration path.** Communications cadence (imminent at the time of ADR drafting) is pinned to D3.

**ADR-0019 — Communications stand-up.** `ICommunicationOrchestrator` is the decision-and-delivery surface; cadence is one of Communications' owned capabilities. The Job composes the orchestrator; it does not bypass the decision logic.

**ADR-0042 D2/D3/D4 — Idempotency.** `IIdempotencyStore` is consumer-side dedup state, per consumer-group, durable at Tier 1, default Cosmos backing. 7-day standard TTL (Communications is not billing/audit).

**ADR-0063 D1/D6/D7 — Clock, cron, test seam.** `TimeProvider` for wall-clock; 5-field UTC cron; ISO 8601 duration strings for intervals; `FakeTimeProvider` in tests.

**ADR-0045 D3 — `IErrorReporter`.** Final-failure errors flow through the Pulse `IErrorReporter` facade.

**ADR-0030 — Audit substrate.** `JobProgress` and `JobFailure` are new audit-category strings; ride the existing `AuditEntry` shape; forward-compatible.

**ADR-0015 — Container Apps shared platform.** Shared `cae-hd-{env}` Environment and shared `acrhdshared{env}` ACR serve both Container Apps and Container Apps Jobs.

**ADR-0033 — Tag→environment mapping.** SemVer tags gate staging/prod. The cadence Job follows the same model.

## Constraints
> **Invariant 41 — Preference enforcement, cadence rules, and suppression logic for outbound messages live in HoneyDrunk.Communications, not in HoneyDrunk.Notify.** The Job is Communications' work and composes `ICommunicationOrchestrator`; it does not bypass the orchestrator or duplicate its decision logic.

> **Invariant `{N2}` (Proposed, tied to ADR-0068) — Cross-Node recurring orchestration uses Azure Container Apps Jobs.** Naming `caj-hd-{service}-{env}`; 13-character service-name limit (invariant 19) applies — `comms-cadence` is 12 chars and complies. (`{N2}` is the second of the four ADR-0068 invariant numbers claimed in packet 01 from `constitution/invariant-reservations.md`; resolve at execution time and substitute consistently with packets 01 and 03.)

> **Invariant `{N3}` (Proposed, tied to ADR-0068) — Every state-mutating job is idempotent.** Job-level and per-intent keys are both deterministic; `IIdempotencyStore.TryClaim` is called before every state-mutating action.

> **Invariant `{N4}` (Proposed, tied to ADR-0068) — Job failure emits Audit and Pulse signals on the documented schedule.** Pulse `jobs.outcome` + `jobs.duration`; lifecycle traces with `correlationId` propagation per invariant 6; long-running `JobProgress`; final-failure `IErrorReporter` + `JobFailure` audit pair.

> **Invariant 19 — Service-name 13-character limit.** `comms-cadence` is 12 chars — compliant.

> **Invariant 35 — Shared Container Apps Environment and ACR.** The Cadence Job reuses `cae-hd-{env}` and `acrhdshared{env}`.

> **Invariant 51 — No `Thread.Sleep` in tests.** Tests use `FakeTimeProvider.Advance(...)`.

> **Invariant 6 — `correlationId` propagation.** The Job's iteration `correlationId` is propagated through the orchestrator call.

> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** Audit and Pulse signals carry job-name/intent-id/scheduled-instant metadata — never message bodies, recipient PII, or provider credentials.

> **Invariant 27 — Solution version bumps are atomic.** Every non-test `.csproj` in the Communications solution moves to the same new minor version in one commit.

> **Invariant 11 — One repo per Node.** The Cadence Job project lives **in `HoneyDrunk.Communications`**; it is not a separate Node or repo.

- **`IGridContext.AgentId` / `AgentRunId` are not plumbed in this packet.** The Cadence Job runs as a Container Apps Job replica — there is no Agent identity in scope at job invocation, and `IGridContext` does not currently expose a "Job"-shaped equivalent. Where the Job's composition needs `IGridContext` for downstream calls (audit emits, orchestrator), **pass null where Agent context is null** (the Job sets `AgentId = null, AgentRunId = null` on the `IGridContext` it constructs for the run; the audit substrate accepts null per its append contract). File a follow-up task in `initiatives/backlog.md` to plumb `IGridContext` extensions for Job-shaped runs (a `JobRunId` field or a "system" actor token) once a second cross-Node Job lands and the shape clarifies. Do NOT invent a `JobId`/`JobRunId` field on `IGridContext` in this packet — it is out of scope.
- **Idempotency is mandatory at both levels** — job-level (one execution per scheduled-instant) and per-intent (one dispatch per intent per scheduled-instant). Both keys are 7-day TTL (ADR-0042 D4 standard).
- **Partial-batch posture — DECIDED in this packet: continue-on-error.** A per-intent orchestrator exception is captured via `IErrorReporter` + `JobFailure` audit and the loop proceeds to the next intent. Rationale: per-intent failures are routine (one bad recipient, one provider hiccup) and systemic failures appear as a clustering pattern in error tracking (`IErrorReporter` dedupes by `problem_id` per ADR-0045) — fail-fast would lose the rest of the batch on the first transient hiccup. The Job's exit code is non-zero only on infrastructural failure (idempotency-store outage, data-layer outage) inside `RunAsync` itself; the platform's `replicaRetryLimit: 3` re-runs the Job in that case, and job-level idempotency keeps the re-run safe.
- **First Container Apps Jobs production deploy.** Expect a small amount of iteration on the manifest shape — the ADR's Negative Consequences flag this: "The deploy workflow … is the studio's first authored Jobs workflow; expect iteration." Operator pairs with the agent for the first prod deploy.
- **Local-dev harness is test-time only.** The cadence schedule in dev/stg/prod is the Container Apps Jobs cron; the harness exists to drive `RunAsync` in `FakeTimeProvider`-aware tests without Azure.

## Labels
`feature`, `tier-2`, `ops`, `adr-0068`, `wave-3`

## Agent Handoff

**Objective:** Ship the Communications cadence/drip-campaign scheduler as the first cross-Node Container Apps Job under ADR-0068 D3.

**Target:** `HoneyDrunk.Communications`, branch from `main`.

**Context:**
- Goal: First concrete cross-Node consumer under ADR-0068 D3. Becomes the pattern future cross-Node Jobs follow (future tenant-lifecycle scheduled work per ADR-0050, future billing reconciliation per ADR-0037, etc.).
- Feature: ADR-0068 Background Job and Recurring Work Substrate rollout, Wave 3.
- ADRs: ADR-0068 D3/D6/D7/D8/D9/D10/D11 (primary), ADR-0063 D1/D6/D7 (clock/cron/test seam), ADR-0042 D2/D3/D4 (idempotency), ADR-0030 (`JobProgress`/`JobFailure`), ADR-0045 D3 (`IErrorReporter`), ADR-0019 (orchestrator surface), ADR-0015 (shared Environment + ACR), ADR-0033 (tag→environment mapping).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — hard. The reusable workflow this packet's release wires up must exist on `main`.

**Constraints:**
- Job composes `ICommunicationOrchestrator`; does not bypass cadence/preference decision logic (invariant 41).
- Naming `caj-hd-comms-cadence-{env}` (invariants 19, `{N2}` Proposed).
- Both job-level and per-intent idempotency are mandatory (invariant `{N3}` Proposed; ADR-0068 D6; ADR-0042).
- Pulse + Audit + ErrorReporter D8 emissions all four (invariant `{N4}` Proposed; ADR-0068 D8).
- Cron is 5-field UTC (ADR-0063 D6); `TimeProvider`+`FakeTimeProvider` (ADR-0063 D1/D7); no `Thread.Sleep` (invariant 51).
- First Container Apps Jobs production deploy — operator pairs for the first prod deploy.
- Solution version bump is atomic across all non-test `.csproj` (invariant 27).

**Key Files:**
- `src/HoneyDrunk.Communications.Cadence/Program.cs` (new).
- `src/HoneyDrunk.Communications.Cadence/CadenceJobRunner.cs` (new).
- `src/HoneyDrunk.Communications.Cadence/CadenceJobOptions.cs` (new).
- `src/HoneyDrunk.Communications.Cadence/Dockerfile` (new).
- `infrastructure/comms-cadence-job.bicep` OR equivalent inputs to packet 02's workflow (new).
- Communications release workflow (`.github/workflows/release.yml` or equivalent) — new step calling `job-deploy-container-apps-job.yml`.
- `tests/HoneyDrunk.Communications.Tests/.../CadenceJobRunnerTests.cs` + the local-dev harness (new).

**Contracts:** None changed — consumes `IIdempotencyStore`, `IAuditLog`, `IErrorReporter`, `TimeProvider`, `ICommunicationOrchestrator`.
