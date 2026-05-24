# Handoff — Wave 4: Node Rollouts

**Initiative:** `adr-0066-health-endpoints`
**Wave transition:** Wave 3 (Kernel runtime + docs) → Wave 4 (Pulse + Notify amendments)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 3 landed

- **Packet 03** — `HoneyDrunk.Kernel` runtime now ships:
  - `HoneyDrunk.Kernel.Hosting.AspNetCore.HealthEndpoints` with `MapHoneyDrunkHealthEndpoints(this IEndpointRouteBuilder endpoints)`.
  - `HoneyDrunk.Kernel.Hosting.AspNetCore.HealthFunctionExtensions` with `ExecuteHealthLiveAsync` / `ExecuteHealthReadyAsync` / `ExecuteHealthAggregateAsync` — pinned to ship in the new `HoneyDrunk.Kernel.Hosting.Functions` package (per packet 03's pinned split), not in `HoneyDrunk.Kernel`.
  - The aggregator with worst-status-wins + critical-degraded escalation + per-contributor 1-second timeout (configurable per registration) + throwing-contributor handling.
  - The IETF response writer that serializes the aggregator output to `application/health+json`.
  - The Pulse telemetry contribution per D10: counter `honeydrunk.health.probes`, histogram `honeydrunk.health.contributor.duration`, Warning/Error structured logs on failures.
  - `HoneyDrunk.Kernel` is at `0.8.0` (along with `HoneyDrunk.Kernel.Abstractions` `0.8.0` from packet 02).
- **Packet 04** — `HoneyDrunk.Kernel/docs/Health.md` documents the contract end-to-end: three endpoints, IETF response shape, `ReadinessPolicy`, aggregation rules, Container Apps probe defaults (D5), Pulse telemetry, the PII rule.

Packets 02 + 03 + 04 share the `[0.8.0]` line. The Kernel `[0.8.0]` CHANGELOG entry covers (a) the contract additions (packet 02), (b) the runtime endpoints + aggregator + helpers (packet 03), and (c) the docs amendment note (packet 04).

**Human package release at this boundary.** Before Wave 4 packets can compile, a human tags/releases `HoneyDrunk.Kernel` `0.8.0` AND `HoneyDrunk.Kernel.Hosting.Functions` `0.8.0` (the new package pinned in packet 03) so the artifacts reach the package feed. Agents never tag.

## What Wave 4 must deliver

### Packet 05 — Pulse.Collector adoption

Amend `HoneyDrunk.Pulse.Collector/Endpoints/HealthEndpoints.cs`:
- Replace the three hand-rolled `MapGet` calls with `return endpoints.MapHoneyDrunkHealthEndpoints();`.
- The method name `MapHealthEndpoints` stays (downstream callers keep their call site).

Amend Pulse.Collector's host composition (`Program.cs` or equivalent):
- Register `NodeLifecycleHealthContributor` with `ReadinessPolicy.Required` (the default).
- Register any Pulse-specific contributor with the appropriate policy — Pulse-export-style contributors should be `ReadinessPolicy.OptionalReported` per ADR-0066 D7 (Pulse should not pull itself out of rotation on its own export's degradation).
- Confirm the host has an auth scheme wired so `/health` is auth-gated (Invariant `{N2}`). If Pulse.Collector currently has no auth scheme, this packet must add one (a Studios-internal token, Azure Monitor scrape credential, or config flag — document the choice in the PR).

Bump every non-test `.csproj` in the `HoneyDrunk.Pulse` solution one minor version (`0.3.0` → `0.4.0` or whatever the current is). Repo-level `CHANGELOG.md` new-version entry.

### Packet 06 — Notify bridge adapter + adoption

Amend `HoneyDrunk.Notify.Hosting.AspNetCore/Health/NotifyHealthEndpointsExtensions.cs`:
- Replace the hand-rolled `MapGet` calls with `return endpoints.MapHoneyDrunkHealthEndpoints();`.

Amend `HoneyDrunk.Notify.Functions/HealthFunction.cs`:
- Replace the body of `Run` with a call to `HealthFunctionExtensions.ExecuteHealthAggregateAsync(request, ...)` from Kernel.

Introduce `HoneyDrunk.Notify.Hosting.AspNetCore/Health/NotifyHealthContributorAdapter.cs`:
- New class `NotifyHealthContributorAdapter(INotifyHealthContributor inner, string name, int priority, bool isCritical, ReadinessPolicy policy) : IHealthContributor` that maps `NotifyHealthReport` → `(HealthStatus, string?)`.

Amend Notify's host composition:
- Wrap each registered `INotifyHealthContributor` in the adapter and register as `IHealthContributor` with an explicit `ReadinessPolicy`.
- Confirm the host's auth scheme covers `/health` (Invariant `{N2}`). Notify already uses `HoneyDrunk.Auth` for inbound REST — confirm the same scheme is reachable on `/health`, or wire a separate scheme.

Mark `INotifyHealthContributor`, `NotifyHealthEvaluator`, `NotifyHealthReport`, `NotifyHealthStatus` `[Obsolete]` with a message naming packet 07 as the removal point.

Bump every non-test `.csproj` in the `HoneyDrunk.Notify` solution one minor version. The Worker and Functions hosts go to the same version together.

## Wave-4 sequencing — Pulse and Notify are independent

Packets 05 and 06 target different repos with no shared state — they can run in parallel.

Both packets depend on packet 03 (the Kernel runtime). Both build against `HoneyDrunk.Kernel` `0.8.0` published at the Wave 3→4 boundary.

## Deploy-workflow coordination — Notify is more sensitive

Both Pulse.Collector and Notify.Worker have Container Apps deploy gates that currently probe `/health`. After this wave:
- `/health` becomes auth-required (Invariant `{N2}`).
- An unauthenticated probe from the deploy workflow returns `401`, breaking the gate.

**Packet 10 (Wave 6)** switches the deploy-workflow's readiness gate from `/health` to `/health/ready` — anonymous, empty-body 200/503. Coordinate deploy windows:
- **Best case:** packet 10's workflow change lands in the deploy environment **before** packets 05/06 deploy their `/health`-auth-required revisions. The gate continues to work.
- **Acceptable case:** packets 05/06 deploy with a temporary credential supplied to the deploy probe, OR with a temporary fallback to `/health/live`. Packet 10 lands shortly after and the temporary accommodation is removed.
- **Unacceptable case:** packets 05/06 deploy with no accommodation and the deploy gate gets `401`. The deploy is blocked.

State the chosen deploy sequencing in the PR. The same applies to the Notify Functions deploy gate which probes `/api/health` today.

## Interface signatures and constraints

```csharp
// From HoneyDrunk.Kernel.Abstractions (packet 02):
public enum ReadinessPolicy { Required = 0, OptionalReported, NotReadinessRelevant }

public interface IHealthContributor
{
    string Name { get; }
    int Priority { get; }
    bool IsCritical { get; }
    Task<(HealthStatus status, string? message)> CheckHealthAsync(CancellationToken cancellationToken = default);
}

// From HoneyDrunk.Notify (current, marked [Obsolete] in packet 06):
public interface INotifyHealthContributor
{
    Task<NotifyHealthReport> CheckAsync(CancellationToken cancellationToken = default);
}

// Bridge (introduced in packet 06):
public sealed class NotifyHealthContributorAdapter(
    INotifyHealthContributor inner,
    string name,
    int priority,
    bool isCritical,
    ReadinessPolicy policy) : IHealthContributor
{
    public string Name => name;
    public int Priority => priority;
    public bool IsCritical => isCritical;
    public ReadinessPolicy Policy => policy; // recorded for the host's registration step
    public async Task<(HealthStatus status, string? message)> CheckHealthAsync(CancellationToken ct = default)
    {
        var report = await inner.CheckAsync(ct);
        var status = report.Status switch
        {
            NotifyHealthStatus.Healthy => HealthStatus.Healthy,
            NotifyHealthStatus.Degraded => HealthStatus.Degraded,
            NotifyHealthStatus.Unhealthy => HealthStatus.Unhealthy,
            _ => HealthStatus.Unhealthy
        };
        return (status, report.Message);
    }
}
```

## Frozen / do-not-touch

- **Notify hot-path contracts.** `INotificationSender`, `INotificationGateway`, the decision-log and cadence contracts (invariants 41–43). Wave 4 only touches the health-endpoint surface.
- **`NotifyHealthEvaluator` body and `NotifyHealthReport` / `NotifyHealthStatus` shape.** Packet 06 marks them `[Obsolete]` but keeps them compileable. Packet 07 (Wave 5) does the removal.
- **`DefaultNotifyHealthContributor` body.** Packet 06 keeps it implementing `INotifyHealthContributor` (now wrapped in the adapter at registration). Packet 07 (Wave 5) amends it to implement `IHealthContributor` directly.
- **Container App YAML in `HoneyDrunk.Actions`.** Packet 10 owns workflow changes; packet 08 owns infrastructure walkthroughs. Wave 4 packets do not touch these.

## Invariants binding Wave 4

- **Invariant 4** — DAG. Pulse and Notify depend on Kernel; no inversion.
- **Invariant 9** — Vault is the only source of secrets. Any auth credential `/health` requires resolves via `ISecretStore`.
- **Invariants 41–43** — Notify hot-path contracts unchanged.
- **Invariant 13** — XML documentation on new public types (the adapter is public).
- **Invariant 27** — one version across each solution. Bump every non-test `.csproj` together; per-package CHANGELOGs only for changed packages.
- **Invariant 51** — no `Thread.Sleep` in test code.
- **Invariant `{N2}`** — `/health` is auth-required. Hard rule; do not ship Pulse or Notify with `/health` anonymous on the assumption "we'll add auth later."
- **Invariant `{N3}`** — contributor `output` strings carry no secrets / connection strings / tenant identifiers / provider opaque IDs. Re-audit Notify's existing contributors' `Message` strings during the adapter wrap; audit any new Pulse contributors at registration time.

## Acceptance gate for the wave

Both packets 05 and 06 pass `pr-core.yml`. Endpoint contract tests prove:
- `/health/live` returns `200` (empty body) when alive, `503` when stopping.
- `/health/ready` returns `200`/`503` (empty body) based on `Required` contributors.
- `/health` returns IETF body on authenticated request, `401` on unauthenticated.

Both repos at their new minor versions. CHANGELOGs accurate.

**Human package release at the Wave 4→5 boundary.** Packet 07 builds against `HoneyDrunk.Notify`'s post-packet-06 minor version. A human tags/releases that version after packet 06 merges so packet 07 can compile against an unchanged-as-released Notify line.

After this wave, both deployable Nodes consume the Grid-wide health-endpoint contract. The Notify-private surface is `[Obsolete]` but compileable. Wave 5 closes the reconciliation.
