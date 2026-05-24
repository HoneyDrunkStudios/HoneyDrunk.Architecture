---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "adr-0066", "wave-4"]
dependencies: ["packet:03"]
adrs: ["ADR-0066"]
wave: 4
initiative: adr-0066-health-endpoints
node: honeydrunk-notify
---

# Bridge INotifyHealthContributor via adapter and adopt MapHoneyDrunkHealthEndpoints

## Summary
Amend `HoneyDrunk.Notify` to adopt the Grid-wide health-endpoint contract per ADR-0066 D9: replace `NotifyHealthEndpointsExtensions`'s hand-rolled endpoint mapping with a delegation to `MapHoneyDrunkHealthEndpoints` from Kernel; amend `HealthFunction` (Notify.Functions) to use the Functions-host helper from Kernel; introduce a transitional `NotifyHealthContributorAdapter : IHealthContributor` so existing `INotifyHealthContributor` implementations land in the Kernel-shaped aggregate **without rewrite**. Existing Notify contributors (e.g. `DefaultNotifyHealthContributor`) keep their `INotifyHealthContributor` shape during this packet — they are amended to implement `IHealthContributor` directly in packet 07 (which then removes `INotifyHealthContributor`).

## Context
ADR-0066 Context audited Notify's current state: `HoneyDrunk.Notify.Hosting.AspNetCore/Health/NotifyHealthEndpointsExtensions.cs` ships three endpoints (`/health`, `/health/live`, `/health/ready`) — `/health` and `/health/live` are dependency-free liveness signals (`200 OK { "status": "Healthy" }` / `{ "status": "Live" }`); `/health/ready` aggregates `INotifyHealthContributor` instances via `NotifyHealthEvaluator` and returns `503` on unhealthy. `HoneyDrunk.Notify.Functions/HealthFunction.cs` is bound to `/api/health` and consumes the same `NotifyHealthEvaluator`. `INotifyHealthContributor` is a Notify-private interface that parallels (but does not unify with) `IHealthContributor`.

ADR-0066 D9: "`INotifyHealthContributor` in `HoneyDrunk.Notify` is reconciled with `IHealthContributor` in Kernel. The Notify-private interface is removed in a follow-up amendment packet; existing Notify contributors are amended to implement `IHealthContributor` directly. The transitional period uses an adapter (`NotifyHealthContributorAdapter : IHealthContributor`) so existing contributor implementations land in the Kernel-shaped aggregate without rewrite."

The two-packet sequencing:
- **Packet 06 (this one)** — introduces the bridge adapter, amends the endpoint extensions to use the Kernel helper, amends `HealthFunction` to use the Functions-host helper, registers existing `INotifyHealthContributor` implementations through the adapter. Notify ships in a **transitional** state: the Notify-private interface still exists, but every endpoint goes through the Kernel-aggregator-on-`IHealthContributor` path.
- **Packet 07 (next)** — amends Notify contributors to implement `IHealthContributor` directly; removes the adapter; removes `INotifyHealthContributor`; removes `NotifyHealthEvaluator` and `NotifyHealthReport` and `NotifyHealthStatus`. After packet 07 there is no Notify-private health interface.

The bridge keeps Notify's CHANGELOG entry from being a breaking event — existing Notify contributor implementations compile against an unchanged `INotifyHealthContributor` for one minor release; packet 07 is the breaking event (the interface is gone) and bumps accordingly.

Notify is a live deployable Node currently at v0.3.0 (per `CHANGELOG.md`). This packet is the **first packet on the `HoneyDrunk.Notify` solution in this initiative** — per invariant 27 it bumps the whole solution to the next minor version. Confirm exact current version at execution time. The Functions host (`HoneyDrunk.Notify.Functions`) and the ASP.NET Core host (`HoneyDrunk.Notify.Worker`) both go through the version bump together (invariant 27).

Notify's deploy workflow (`release-worker.yml` per ADR-0066 Context) gates traffic on `/health`. Once this packet lands, `/health` becomes auth-required (invariant `{N2}`). Coordinate sequencing with packet 10 (the Actions-side deploy-workflow change that switches the readiness gate from `/health` to `/health/ready`) — same caveat as packet 05.

## Scope
- `HoneyDrunk.Notify.Hosting.AspNetCore/Health/NotifyHealthContributorAdapter.cs` — **new** transitional adapter: `class NotifyHealthContributorAdapter(INotifyHealthContributor inner, string name, int priority, bool isCritical, ReadinessPolicy policy) : IHealthContributor`. Maps `NotifyHealthReport` → `(HealthStatus, string?)` per the existing `NotifyHealthStatus` → `HealthStatus` mapping.
- `HoneyDrunk.Notify.Hosting.AspNetCore/Health/NotifyHealthEndpointsExtensions.cs` — replace the hand-rolled `MapGet`s with `MapHoneyDrunkHealthEndpoints` from Kernel. Keep `MapNotifyHealthEndpoints` as the exposed method name (downstream callers keep their call site).
- `HoneyDrunk.Notify.Functions/HealthFunction.cs` — amend to use `HealthFunctionExtensions.ExecuteHealthAggregateAsync` from Kernel (per ADR-0066 D9). The route stays `health` (the Functions binding adds `/api/` prefix automatically).
- Notify host composition (`HoneyDrunkNotifyServiceCollectionExtensions` or equivalent) — wrap each registered `INotifyHealthContributor` in a `NotifyHealthContributorAdapter`, register the adapter as `IHealthContributor` with a `ReadinessPolicy` value (see Implementation step 4 for the per-contributor policy choices).
- Notify tests — assert the three endpoints behave per the ADR-0066 contract through the adapter path.
- `INotifyHealthContributor`, `NotifyHealthEvaluator`, `NotifyHealthReport`, `NotifyHealthStatus`, `DefaultNotifyHealthContributor` — **kept as-is** in this packet; removed/amended in packet 07.
- Version bump across the `HoneyDrunk.Notify` solution (invariant 27).

## Proposed Implementation
1. **Adapter (`NotifyHealthContributorAdapter`).** New file in `HoneyDrunk.Notify.Hosting.AspNetCore/Health/`. Implements `IHealthContributor` from `HoneyDrunk.Kernel.Abstractions.Lifecycle`. Constructor takes:
   - `INotifyHealthContributor inner` — the wrapped Notify-private contributor.
   - `string name` — passed through as `IHealthContributor.Name`.
   - `int priority` — passed through as `IHealthContributor.Priority`.
   - `bool isCritical` — passed through as `IHealthContributor.IsCritical`.
   - `ReadinessPolicy policy` — recorded for the host's registration step (the policy is read from the registration-shape packet 02 ships; the adapter itself doesn't gate, but it exposes the policy alongside it).
   Method `CheckHealthAsync`: calls `inner.CheckAsync(cancellationToken)`; maps `NotifyHealthReport` to `(HealthStatus, string?)`:
   - `NotifyHealthStatus.Healthy` → `HealthStatus.Healthy`.
   - `NotifyHealthStatus.Degraded` → `HealthStatus.Degraded`.
   - `NotifyHealthStatus.Unhealthy` → `HealthStatus.Unhealthy`.
   `string?` is `report.Message`, subject to invariant `{N3}` — audit existing Notify contributors' `Message` strings before this packet ships (they should already be safe per the original code, but verify).
2. **`NotifyHealthEndpointsExtensions`.** Replace the `MapGet` calls with `endpoints.MapHoneyDrunkHealthEndpoints()`. The method name `MapNotifyHealthEndpoints` stays. XML doc updated:
   - Old (paraphrased): "`/health` and `/health/live` are dependency-free liveness; `/health/ready` aggregates `INotifyHealthContributor` via `NotifyHealthEvaluator`."
   - New: "`/health/live` and `/health/ready` are anonymous probes (empty body 200/503 per the IETF model); `/health` is the auth-required IETF `application/health+json` aggregate. Notify's existing `INotifyHealthContributor` implementations are wrapped in `NotifyHealthContributorAdapter` during this transition; see ADR-0066 D9."
3. **`HealthFunction` (Notify.Functions).** Amend the function's `Run` method to call `HealthFunctionExtensions.ExecuteHealthAggregateAsync(request, ...)` from Kernel. Match the Functions host's binding patterns (the existing `HealthFunction` resolves `NotifyHealthEvaluator` via DI; the new code resolves whatever DI surface the Kernel helper consumes — likely the aggregator plus `INodeContext`). State the chosen wiring in the PR. The `[Function]` binding name and the `health` route stay the same; only the body of `Run` changes. Per ADR-0066 D11 the Functions-host `/api/` prefix is the host's, not the Grid's — no route literal changes.
4. **Contributor registration with `ReadinessPolicy`.** Notify's existing `INotifyHealthContributor` implementations (e.g. `DefaultNotifyHealthContributor`) are registered in DI through the Hosting.AspNetCore composition. Amend the registration so each is wrapped in `NotifyHealthContributorAdapter` and registered as `IHealthContributor` with an explicit `ReadinessPolicy`:
   - `DefaultNotifyHealthContributor` (and any contributor that signals Notify's core readiness — provider connectivity, template loading, secrets resolution) — `ReadinessPolicy.Required`.
   - Any contributor that reports a non-critical optional signal (e.g. a future Pulse-export-status contributor, an optional connector) — `ReadinessPolicy.OptionalReported`.
   - Document the policy choice for each existing contributor in the PR.
   The host also keeps the **existing** registration of `INotifyHealthContributor` if any other code path resolves it directly (e.g. `NotifyHealthEvaluator` if it still exists in this packet's tree). The dual registration is acceptable transitionally; packet 07 removes the Notify-private surface and consolidates.
5. **`NotifyHealthEvaluator` and friends.** Kept in this packet as **dead-from-the-endpoint-path code** — no endpoint calls them anymore, but they remain compileable so existing tests / consumers don't break. Mark them `[Obsolete("Removed in packet 07 — INotifyHealthContributor reconciled to IHealthContributor")]` if the project supports Obsolete attributes without failing the build (it should — `pr-core.yml` does not treat `[Obsolete]` warnings as errors). Document the deprecation in `HoneyDrunk.Notify.Hosting.AspNetCore`'s per-package `CHANGELOG.md`.
6. **Auth scheme — pinned two-token posture.** Notify is **tenant-bounded** per the invariant `{N2}` two-token model: Notify's `/health` accepts a **tenant-administrator token** for tenant-scoped probes, plus an Azure Monitor scrape credential as a parallel scheme for fleet-wide scrapes. Studios-internal tokens are NOT in scope for Notify (those are reserved for cross-tenant operator probes in Operator/Agents/HoneyHub). Notify already uses `HoneyDrunk.Auth` for inbound API authentication on its REST surface — check `HoneyDrunk.Notify.HostBootstrap` for the existing wiring; confirm the tenant-admin scheme reaches the `/health` route, and either extend the wiring or add a parallel Azure Monitor scrape scheme. Document the chosen approach in the PR. **Do not** ship Notify with `/health` anonymous on the assumption of a follow-up — invariant `{N2}`.
7. **Tests.** Amend or add tests in the existing Notify test projects (`HoneyDrunk.Notify.Tests`, `HoneyDrunk.Notify.IntegrationTests`):
   - The adapter maps `NotifyHealthStatus` → `HealthStatus` correctly and surfaces the message.
   - `/health/live` returns `200` with empty body when alive; `503` only when lifecycle stage is `Stopping`/`Stopped`.
   - `/health/ready` returns `200` with empty body when `Required` contributors (through the adapter) are healthy; `503` with empty body when any `Required` contributor is unhealthy.
   - `/health` returns IETF `application/health+json` body matching ADR-0066 D2 shape on an authenticated request.
   - `/health` returns `401` on an unauthenticated request.
   - Both the ASP.NET Core (`Worker`) and Functions (`Functions`) hosts pass the endpoint contract tests.
   - No `Thread.Sleep` (invariant 51).
8. **Versioning.** Bump every non-test `.csproj` in the `HoneyDrunk.Notify` solution to the next minor version in one commit (invariant 27). Repo-level `CHANGELOG.md` new entry. Per-package CHANGELOGs:
   - `HoneyDrunk.Notify.Hosting.AspNetCore` — entry: adapter introduced; endpoint extension amended; `INotifyHealthContributor` marked obsolete.
   - `HoneyDrunk.Notify.Functions` — entry: `HealthFunction` amended to use Kernel Functions-host helper.
   - `HoneyDrunk.Notify` (core) — entry only if it carries any functional change in this packet (unlikely — most changes live in Hosting.AspNetCore); no noise entry if no change.
9. **README.** Update `HoneyDrunk.Notify.Hosting.AspNetCore/README.md` (if it exists) and the repo-level Notify `README.md` if either documents the wire shape — the shape has changed (probes empty body; `/health` IETF; auth required).

## Affected Files
- `HoneyDrunk.Notify.Hosting.AspNetCore/Health/NotifyHealthContributorAdapter.cs` — **new**.
- `HoneyDrunk.Notify.Hosting.AspNetCore/Health/NotifyHealthEndpointsExtensions.cs` — body replaced.
- `HoneyDrunk.Notify.Hosting.AspNetCore/Health/INotifyHealthContributor.cs` — marked `[Obsolete]` (if supported).
- `HoneyDrunk.Notify.Hosting.AspNetCore/Health/NotifyHealthEvaluator.cs`, `NotifyHealthReport.cs`, `NotifyHealthStatus.cs`, `DefaultNotifyHealthContributor.cs` — marked `[Obsolete]` where applicable; otherwise unchanged this packet.
- `HoneyDrunk.Notify.Hosting.AspNetCore/ServiceCollectionExtensions/HoneyDrunkNotifyServiceCollectionExtensions.cs` (or wherever contributor registration lives) — wrap registered `INotifyHealthContributor` instances in the adapter and register as `IHealthContributor` with `ReadinessPolicy`.
- `HoneyDrunk.Notify.Functions/HealthFunction.cs` — body replaced to call `ExecuteHealthAggregateAsync`.
- `HoneyDrunk.Notify.HostBootstrap/` and/or `HoneyDrunk.Notify.Worker/` — confirm auth scheme covers `/health`; extend if needed.
- `HoneyDrunk.Notify.Tests/`, `HoneyDrunk.Notify.IntegrationTests/` — endpoint and adapter tests.
- Every non-test `.csproj` in the solution — version bump.
- Repo-level `CHANGELOG.md`; per-package CHANGELOGs as noted.
- `HoneyDrunk.Notify.Hosting.AspNetCore/README.md` and repo-level Notify `README.md` if either documents the wire shape.

## NuGet Dependencies
- **`HoneyDrunk.Notify.Hosting.AspNetCore`** — gains (or updates):
  - `HoneyDrunk.Kernel` — `0.8.0` (provides `MapHoneyDrunkHealthEndpoints`, the aggregator, `ReadinessPolicy` consumption).
  - `HoneyDrunk.Kernel.Abstractions` — `0.8.0` (provides `IHealthContributor`, `ReadinessPolicy`, `HealthCheckResponse`, `HealthCheckEntry`).
- **`HoneyDrunk.Notify.Functions`** — gains (or updates):
  - `HoneyDrunk.Kernel` — `0.8.0` (for `HealthFunctionExtensions`) OR a separate optional Functions-host package if packet 03 split it out. State the choice in the PR; the package name is whichever packet 03 shipped.
- **Notify test projects** — no new packages (existing ADR-0047 test stack).
- `HoneyDrunk.Standards` is already on every project; no change.
- Confirm exact current versions at execution time; packets 02 + 03 set the Kernel side.

## Boundary Check
- [x] All code change is in `HoneyDrunk.Notify` — its own host endpoint extension, Functions function, host composition, and adapter. Routing rule "notification, ... notify, channel → HoneyDrunk.Notify" maps here.
- [x] No contract change in Notify's hot path — `INotificationSender` / `INotificationGateway` shapes are not touched; the Communications-hot-path canary (invariant 43) stays green.
- [x] The Notify-private `INotifyHealthContributor` stays in this packet (transitional); it is removed in packet 07.
- [x] No Container App YAML change in this repo — packet 08 handles probe configuration; packet 10 handles the deploy-workflow readiness-gate switch.

## Acceptance Criteria
- [ ] `NotifyHealthContributorAdapter` is a new class in `HoneyDrunk.Notify.Hosting.AspNetCore.Health` implementing `IHealthContributor`; wraps an `INotifyHealthContributor`; maps `NotifyHealthStatus` to `HealthStatus` correctly
- [ ] `NotifyHealthEndpointsExtensions.MapNotifyHealthEndpoints` delegates to `MapHoneyDrunkHealthEndpoints` from Kernel; the hand-rolled `MapGet` calls are removed
- [ ] `HealthFunction.Run` calls `HealthFunctionExtensions.ExecuteHealthAggregateAsync` from Kernel (or whichever method matches the Functions-host helper's name in packet 03); the function binding name and `health` route are unchanged
- [ ] Notify's host composition registers existing `INotifyHealthContributor` instances through the adapter as `IHealthContributor`, with explicit `ReadinessPolicy` values; the policy choice for each is documented in the PR
- [ ] `INotifyHealthContributor`, `NotifyHealthEvaluator`, `NotifyHealthReport`, `NotifyHealthStatus` are marked `[Obsolete]` (if the project supports it) with a message naming packet 07 as the removal point
- [ ] Notify's host auth scheme covers `/health` so it is auth-gated; auth wiring is documented in the PR
- [ ] `/health/live` returns `200` with empty body when alive
- [ ] `/health/ready` returns `200`/`503` with empty body based on `Required` contributors
- [ ] `/health` returns IETF `application/health+json` body on authenticated request, `401` on unauthenticated
- [ ] Both Worker and Functions hosts pass endpoint contract tests
- [ ] Tests have no `Thread.Sleep` (invariant 51)
- [ ] Every non-test `.csproj` in the `HoneyDrunk.Notify` solution is at the same new minor version in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` new-version entry; per-package CHANGELOGs only for packages with functional changes (Hosting.AspNetCore + Functions get entries; core Notify gets none if untouched)
- [ ] READMEs updated if they documented the wire shape
- [ ] No change to Notify hot-path contracts (`INotificationSender`, `INotificationGateway`) — invariants 41–43 unaffected
- [ ] `pr-core.yml` tier-1 gate passes; the Worker and Functions deploy gates may need temporary accommodation until packet 10 lands (see Human Prerequisites)

## Human Prerequisites
- [ ] **Host auth scheme wired before adopting `MapHoneyDrunkHealthEndpoints`.** Both Notify Worker (ASP.NET Core) and Notify Functions hosts must have an auth scheme registered before this packet adopts the Kernel helpers. The Kernel helper calls `RequireAuthorization()` without a policy name — the host's default scheme is consulted; **the Kernel helper ships no no-throw fallback**, absence of a scheme is a host configuration error. The two-token posture (invariant `{N2}`): Notify is tenant-bounded, so the wired scheme accepts a **tenant-administrator token** for tenant-scoped probes (a tenant admin can hit `/health` for the Notify Worker/Functions in their tenant context); Azure Monitor scrape credentials are accepted as a parallel scheme for fleet-wide observability scrapes. Studios-internal tokens are NOT in scope for Notify (those are reserved for Operator/Agents/HoneyHub cross-tenant operator probes). Notify already uses `HoneyDrunk.Auth` for its public REST API today; confirm the same scheme works for `/health`, or wire a separate scheme. If the wiring is non-trivial it may need an explicit secret seeded into `kv-hd-notify-{env}`. **Do NOT ship this packet with `/health` anonymous on the assumption of a follow-up — invariant `{N2}` is a hard rule.**
- [ ] **Publish the upstream Kernel NuGet packages.** This packet references `HoneyDrunk.Kernel` / `HoneyDrunk.Kernel.Abstractions` `0.8.0` (packets 02 + 03) and `HoneyDrunk.Kernel.Hosting.Functions` `0.8.0` (the new optional package from packet 03, pinned). A human tags/releases `HoneyDrunk.Kernel` `0.8.0` AND `HoneyDrunk.Kernel.Hosting.Functions` `0.8.0` after packets 02 and 03 merge. Wave 4 cannot build against unpublished packages. Agents never tag or publish.
- [ ] **Coordinate the deploy-workflow readiness gate.** Notify Worker's `release-worker.yml` currently probes `/health` per ADR-0066 Context. After this packet, `/health` is auth-required and an unauthenticated probe returns `401`. Packet 10 amends the deploy workflow to probe `/health/ready` (unauthenticated). Until packet 10 lands in the deploy environment, the Notify deploy may need: (a) a temporary credential supplied to the deploy probe, (b) a temporary fallback to `/health/live`, or (c) deferral of the deploy until packet 10 lands. The same applies to the Functions-host's deploy gate if it has one. Coordinate sequencing with packet 10's deploy-workflow change.

## Referenced ADR Decisions
**ADR-0066 D1/D2/D6 — Endpoint contract.** Three endpoints, IETF body on `/health`, empty body on probes, probe endpoints anonymous, `/health` auth-required.

**ADR-0066 D7 — `ReadinessPolicy`.** Notify contributors are registered with explicit policies. Critical readiness signals are `Required`; optional reported signals are `OptionalReported`.

**ADR-0066 D9 — Implementation home + Notify reconciliation.** Notify's `INotifyHealthContributor` is reconciled with `IHealthContributor`. The transitional period uses `NotifyHealthContributorAdapter`; existing contributors are amended to implement `IHealthContributor` directly in the follow-up (packet 07). The Functions-host helper from Kernel replaces Notify's hand-rolled `HealthFunction` body.

**ADR-0066 Operational Consequences — "The Notify amendment requires care."** "The amendment packet stages: (1) bridge adapter lands, (2) Notify contributors amend to `IHealthContributor` directly, (3) `INotifyHealthContributor` is removed. The bridge keeps Notify's CHANGELOG entry from being a breaking event." This packet is stage (1); packet 07 is stages (2) and (3).

## Constraints
- **Invariant 4 — DAG.** Notify depends on Kernel; no inversion.
- **Invariant 9 — Vault is the only source of secrets.** Any auth credential `/health` requires resolves via `ISecretStore`.
- **Invariants 41–43 — Notify hot-path contracts.** Do NOT change `INotificationSender`, `INotificationGateway`, decision-log or cadence shapes. This packet only touches the health-endpoint surface.
- **Invariant 13 — XML documentation on new public types.** The adapter is public; the existing `INotifyHealthContributor` stays as-is (now marked Obsolete).
- **Invariant 27 — one version across the solution.** Bump every non-test `.csproj` together; per-package CHANGELOGs only for changed packages.
- **Invariant 51 — no `Thread.Sleep` in test code.**
- **Invariant `{N2}` — `/health` auth-required.** Hard rule.
- **Invariant `{N3}` — contributor messages free of secrets/connection strings/tenant identifiers/provider opaque IDs.** Audit existing Notify contributor `Message` strings before they ship through the adapter.
- **Keep `INotifyHealthContributor` compileable in this packet.** Packet 07 removes it; this packet only marks it `[Obsolete]`. Removal is a breaking event; the bridge in this packet prevents that.

## Labels
`feature`, `tier-2`, `ops`, `adr-0066`, `wave-4`

## Agent Handoff

**Objective:** Adopt the Kernel health-endpoint helper in Notify's AspNetCore and Functions hosts, introduce a transitional bridge adapter for `INotifyHealthContributor`, mark the Notify-private interface obsolete.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Bring Notify onto the Grid-wide contract without breaking existing contributor implementations.
- Feature: ADR-0066 Health, Readiness, and Liveness Endpoint Contract rollout, Wave 4 (parallel with packet 05 Pulse).
- ADRs: ADR-0066 D1/D2/D6/D7/D9 (primary), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` — `MapHoneyDrunkHealthEndpoints`, `HealthFunctionExtensions`, the aggregator ship in `HoneyDrunk.Kernel` `0.8.0`.

**Constraints:**
- Existing `INotifyHealthContributor` implementations stay unchanged in this packet — they are wrapped in the adapter. Packet 07 amends them to implement `IHealthContributor` directly and removes the Notify-private interface.
- `/health` must be auth-gated before this packet ships (invariant `{N2}`).
- No change to Notify hot-path contracts (`INotificationSender`, `INotificationGateway`) — invariants 41–43 hold.
- Container App YAML / deploy workflows are NOT touched here — packet 08 / packet 10 own those.
- Bump the whole Notify solution one minor version (invariant 27); both Worker and Functions hosts go to the same version together.

**Key Files:**
- `HoneyDrunk.Notify.Hosting.AspNetCore/Health/NotifyHealthContributorAdapter.cs` (new), `NotifyHealthEndpointsExtensions.cs` (body replaced), `INotifyHealthContributor.cs` / `NotifyHealthEvaluator.cs` / `NotifyHealthReport.cs` / `NotifyHealthStatus.cs` (mark `[Obsolete]`).
- `HoneyDrunk.Notify.Hosting.AspNetCore/ServiceCollectionExtensions/HoneyDrunkNotifyServiceCollectionExtensions.cs` (contributor registration through adapter).
- `HoneyDrunk.Notify.Functions/HealthFunction.cs` (body replaced).
- `HoneyDrunk.Notify.HostBootstrap/` / `HoneyDrunk.Notify.Worker/` — auth-scheme wiring for `/health`.
- Notify test projects.
- Every non-test `.csproj`; repo-level `CHANGELOG.md`.

**Contracts:**
- Consumes `IHealthContributor`, `ReadinessPolicy`, `HealthCheckResponse` from `HoneyDrunk.Kernel.Abstractions` `0.8.0`.
- Consumes `MapHoneyDrunkHealthEndpoints`, `HealthFunctionExtensions` from `HoneyDrunk.Kernel` `0.8.0`.
- `INotifyHealthContributor` stays public (now `[Obsolete]`); removed in packet 07.
- `NotifyHealthContributorAdapter` is a new public type in `HoneyDrunk.Notify.Hosting.AspNetCore` (transitional — also removed in packet 07).
