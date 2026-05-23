# ADR-0066: Health, Readiness, and Liveness Endpoint Contract

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Core / cross-cutting

## Context

The Grid has a working health primitive surface and no Grid-wide endpoint contract on top of it.

What exists today, audited at the time of this ADR:

- **`HoneyDrunk.Kernel.Abstractions/Lifecycle/IHealthContributor.cs`** ships an `IHealthContributor` interface with `Name`, `Priority`, `IsCritical`, and `CheckHealthAsync` returning `(HealthStatus, string?)`. `HoneyDrunk.Kernel/Diagnostics/NodeLifecycleHealthContributor.cs` is the first concrete implementation, contributing the lifecycle stage as a critical signal.
- **`HoneyDrunk.Kernel.Abstractions/Health/`** ships an `IHealthCheck` interface and `HealthStatus` enum (`Healthy`, `Degraded`, `Unhealthy`) — Kernel's minimal internal-component primitive. `HoneyDrunk.Kernel/Health/CompositeHealthCheck.cs` aggregates them with worst-status-wins semantics. The per-Kernel documentation (`HoneyDrunk.Kernel/docs/Health.md`) explicitly distinguishes the two interfaces: `IHealthCheck` for internal component checks, `IHealthContributor` for Node-level aggregation exposed to external orchestrators.
- **`HoneyDrunk.Pulse.Collector/Endpoints/HealthEndpoints.cs`** ships three endpoints (`/health`, `/health/ready`, `/health/live`) — each returning a static `200 OK` with a one-field `Status` body. None of them consult `IHealthContributor` aggregation; they are placeholders.
- **`HoneyDrunk.Notify.Hosting.AspNetCore/Health/NotifyHealthEndpointsExtensions.cs`** also ships three endpoints (`/health`, `/health/live`, `/health/ready`) — `/health` and `/health/live` are dependency-free liveness signals, `/health/ready` aggregates a per-Node `INotifyHealthContributor` and returns `503` on unhealthy. The Notify shape is reused inside `HoneyDrunk.Notify.Functions` as `/api/health` and inside `HoneyDrunk.Notify.Worker`. The Worker's release workflow (`release-worker.yml`) gates traffic on `/health`; the readiness endpoint exists for monitoring rather than for the deploy gate.
- **`HoneyDrunk.Notify`'s `INotifyHealthContributor`** is a per-Node abstraction that parallels (but does not unify with) `IHealthContributor`. Two contributor interfaces means the two Nodes' health-endpoint code does not compose.

The drift is real: Pulse.Collector returns a static `Healthy` regardless of state; Notify aggregates contributors but through a Notify-private interface; the Kernel-shipped `IHealthContributor` is implemented (lifecycle contributor) but not consumed by any endpoint code outside Notify's local fork.

What no ADR has pinned:

- The endpoint **paths**. Three-endpoint convention (`/health/live`, `/health/ready`, `/health`) is the de-facto shape but unwritten.
- The response **shape** per endpoint. Empty body? JSON? Per-contributor breakdown?
- The **status semantics**. ASP.NET Core's `HealthStatus` enum has three values; the Grid uses the same three; how they map to HTTP status codes per endpoint is not committed.
- **Container Apps probe configuration.** [ADR-0015](./ADR-0015-container-hosting-platform.md) references probes without saying what they hit, what period, what failure threshold.
- **Auth posture.** Anonymous? IP-restricted? mTLS? Three different defenses get casually conflated in code review.
- **Dependency policy in readiness.** What counts as "ready"? Database reachable? Service Bus reachable? Pulse export ready? Optional connectors?
- **PII / secrets exposure in the body.** The Notify shape returns aggregated per-contributor details; nothing prevents a contributor from leaking a connection-string-shaped error.

The forcing functions for deciding this now:

- **[ADR-0015](./ADR-0015-container-hosting-platform.md) committed Container Apps for every containerized deployable Node.** Container Apps probes consume these endpoints. Without a Grid-wide contract, every new containerized Node's probe configuration drifts. The Container Apps revision-mode-Multiple rollback seam (Invariant 36) gates on a health probe outcome — that probe needs a defined contract.
- **Operator (ADR-0018), Agents (ADR-0020), and HoneyHub (ADR-0002 / ADR-0003) are about to land.** Each is a containerized deployable Node. They will pick whatever shape exists; settling the shape before they pick prevents three more divergences from the Pulse-and-Notify drift.
- **Notify Cloud GA carries a tenant-facing health expectation.** Per [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md), tenants integrating against Notify Cloud will treat unanticipated `5xx` responses as outages; the readiness gate is what protects them from being routed to a starting-up revision before its dependencies are reachable.
- **The AI-sector standup wave (ADR-0016 through ADR-0025)** introduces nine Nodes that emit substantial telemetry to Pulse. Pulse export readiness is a credible "should I be in rotation" signal that needs a defined policy slot.
- **Telemetry contribution.** [ADR-0010](./ADR-0010-observation-layer.md) and [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md) both treat probe outcomes as a candidate signal source; nothing today lets Pulse observe them in a structured way.

This ADR commits the three-endpoint convention, the response shape per endpoint, the status-code mapping, the `IHealthContributor` aggregation rule, the Container Apps probe defaults, the auth posture, the dependency-policy-in-readiness rule, the PII / secrets exposure rule, the implementation substrate, and the telemetry contribution.

It does **not** commit per-Node contributor catalogs (which `IHealthContributor` does each Node register?) — that is per-Node packet work. It does not commit a tenant-visible health page or status page (a Studios marketing surface, not a Node-level probe).

## Decision

### D1. Three endpoints: `/health/live`, `/health/ready`, `/health`

Every HTTP-fronted deployable Node exposes exactly three endpoints, named uniformly across Nodes:

- **`/health/live`** — liveness. The process is alive, the runtime is responsive, no dependency checks. Semantically: "is this container still worth keeping?" Kubernetes-style liveness probes consume this; Container Apps' `livenessProbe` per [ADR-0015](./ADR-0015-container-hosting-platform.md) configures against it. A failing liveness signal causes the orchestrator to restart the container.
- **`/health/ready`** — readiness. The Node is ready to serve traffic — required dependencies are reachable, warm-up is complete, the Node has reached the `Ready` lifecycle stage. Semantically: "should I route a request here right now?" Kubernetes-style readiness probes consume this; Container Apps' `readinessProbe` configures against it. A failing readiness signal causes the orchestrator to withhold traffic without restarting.
- **`/health`** — full health aggregate. Returns every registered `IHealthContributor`'s name, status, and (optional) message — the human-readable and dashboard-readable view. Auth-required (D6). Not consumed by probes.

The path scheme is fixed: `/health/live`, `/health/ready`, `/health`. Per-Node prefixes (Notify's `/api/health` for the Functions host) are accommodated as an environment-dependent prefix added by the host; the **endpoint suffix** is uniform. A Functions-hosted Node mounts `/api/health/live` and `/api/health/ready`; the `/api/` prefix is the Functions host's, not the Grid's.

Rejected alternatives:

- **Two endpoints (`/health` and `/health/ready`).** Conflates "is the process alive" with "do I want a restart on transient dependency failures." Container Apps and Kubernetes both expose distinct liveness and readiness probes for a reason; collapsing them into one endpoint means every dependency hiccup triggers a restart. The three-endpoint shape is the orchestrator's expected shape.
- **One endpoint (`/health`) with a query parameter (`?check=live`).** Operationally legible only at first glance; in practice Container Apps probe configuration would need to encode the query parameter, the body would still need to be parsed, and the URL-as-debug-aid property the orchestrators rely on is lost.
- **Kubernetes-style `/healthz` paths.** Plausible — `/healthz`, `/readyz`, `/livez` is the k8s ecosystem convention. Rejected because `/health/{aspect}` is the more conventional shape outside the k8s lineage, and the Grid is not on Kubernetes. Container Apps documentation samples lean toward `/health/...`. The convention here is the more legible one for the platform we actually run on.

### D2. Response shape per endpoint

**`/health/live` and `/health/ready`** return:

- `200 OK` with empty body on healthy/degraded (probes do not consume bodies; an empty body is the cheapest and least-leak-prone shape).
- `503 Service Unavailable` with empty body on unhealthy.

Probes consume status codes, not bodies. The body is empty by design — for these endpoints, there is no consumer that needs structured information, and an empty body removes the chance of leaking implementation detail or PII through a contributor's status message.

**`/health`** returns:

- JSON body conforming to the IETF draft [Health Check Response Format for HTTP APIs](https://datatracker.ietf.org/doc/html/draft-inadarei-api-health-check) (`application/health+json`) shape. The minimum payload:

```json
{
  "status": "pass" | "warn" | "fail",
  "version": "1.4.2",
  "releaseId": "1.4.2-abcd1234",
  "checks": {
    "node-lifecycle": [{ "status": "pass", "time": "2026-05-23T14:00:00Z" }],
    "service-bus:notify-cloud": [{ "status": "warn", "output": "elevated send latency", "time": "2026-05-23T14:00:00Z" }],
    "key-vault:secrets-cache": [{ "status": "pass", "time": "2026-05-23T14:00:00Z" }]
  }
}
```

- `200 OK` on `pass` or `warn` (Healthy or Degraded — the aggregate is reachable, but operators should look).
- `503 Service Unavailable` on `fail` (Unhealthy — at least one critical contributor is failing).

The IETF `health+json` shape is the right wire format because it has tooling support across multiple ecosystems, it composes with the OpenAPI spec [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) commits, and it gives a Studios dashboard (future) a documented shape to parse.

Per-contributor entries carry `status` (mapped from `HealthStatus`), `time` (ISO-8601 timestamp), and optional `output` (the contributor's message string, subject to D8's PII rule). The `version` and `releaseId` come from the Node's assembly metadata.

The Notify shape today returns a one-field `{ "status": "Healthy" }` JSON envelope on `/health/ready`. That is not the committed shape; Notify's amendment packet brings it onto the IETF shape with backward-compatibility consideration (the `/health/ready` body becomes the empty-body shape; the IETF body moves to `/health`).

### D3. Status semantics: `HealthStatus` is the wire enum

The Grid uses Kernel's existing three-state enum verbatim — `Healthy`, `Degraded`, `Unhealthy` (per `HoneyDrunk.Kernel.Abstractions.Health.HealthStatus`). No ASP.NET-Core `Microsoft.Extensions.Diagnostics.HealthChecks.HealthStatus` is introduced; the Kernel enum is the source of truth, and the bridge to the ASP.NET surface (when used) maps Kernel → ASP.NET Core values 1:1.

Wire encoding in the `/health` body:

- `Healthy` → `"pass"`
- `Degraded` → `"warn"`
- `Unhealthy` → `"fail"`

(per the IETF draft's enum values.) The wire format is stable; the Kernel enum stays the implementation surface.

### D4. `IHealthContributor` aggregation: worst-status-wins, criticality respected

Aggregation rules for the `/health` endpoint (and for the readiness gate the orchestrator consumes via `/health/ready`):

- Every registered `IHealthContributor` is invoked in `Priority` order (lower first).
- Each contributor reports `(HealthStatus, string?)`.
- The aggregate status is the **worst** of all contributor statuses with one criticality refinement: a `Degraded` from a contributor whose `IsCritical == true` is escalated to `Unhealthy` for the aggregate (its `IsCritical` is the contract that says "Node cannot serve traffic if this is degraded"). A `Degraded` from a non-critical contributor stays `Degraded`.
- A contributor that throws is treated as `Unhealthy`, the exception's `Message` is recorded as the contributor's `output` (subject to D8's PII rule), and aggregation continues — one contributor's failure does not short-circuit the others. The aggregate is the joint truth.

The implementation lives in `HoneyDrunk.Kernel`'s `NodeLifecycleManager` (the existing host of `IHealthContributor` orchestration per the Kernel `Lifecycle.md` docs). The endpoint code asks `NodeLifecycleManager` for the aggregate; it does not iterate contributors itself.

`IHealthCheck` (the simpler Kernel primitive) is **not** consulted by the endpoint. It is the internal-component shape — a `RedisHealthCheck` reports to whoever depends on it inside the Node. If a component wants its health surfaced at the endpoint, the Node wraps it in an `IHealthContributor` (the docs in `HoneyDrunk.Kernel/docs/Health.md` show the pattern).

### D5. Container Apps probe defaults

The probe configuration each containerized Node declares in its Container App definition is committed as the **default**; per-Node overrides are permitted with reason recorded in the Node's `infrastructure/` walkthrough.

| Probe | Path | Period | Initial delay | Timeout | Failure threshold | Success threshold |
|---|---|---|---|---|---|---|
| `livenessProbe` | `/health/live` | 30s | 10s | 3s | 3 | 1 |
| `readinessProbe` | `/health/ready` | 10s | 5s | 3s | 3 | 1 |
| `startupProbe` | `/health/live` | 5s | 0s | 3s | 30 | 1 |

The startup probe uses `/health/live` with a generous failure threshold (30 × 5s = 150 seconds of warm-up runway). The startup probe protects slow-starting Nodes (containers building dependency graphs, JIT warming, secrets resolving from Vault) from premature liveness-probe restart. Once the startup probe succeeds once, the orchestrator switches to the liveness and readiness probes.

These values are starting defaults — not invariants — because per-Node load characteristics may require tuning. The container-hosting walkthrough for each new Node carries the probe declaration; the [ADR-0015](./ADR-0015-container-hosting-platform.md) deploy gate (Invariant 36's traffic-shift on revision health) consumes the readiness signal.

Container-App revision health gating: a new revision is shifted to `100%` traffic only after `/health/ready` has returned `200` for at least three consecutive periods on the revision's direct FQDN. The probe configuration above provides the timing; the deploy workflow (`job-deploy-container-app.yml` per [ADR-0015](./ADR-0015-container-hosting-platform.md)) holds the gate.

### D6. Auth posture: probes anonymous, `/health` auth-required

- **`/health/live`** — anonymous. Probe sources cannot send authentication headers; the endpoint must succeed without auth. The endpoint is trivial — it never returns a body, never reflects a request parameter, never exposes more than a `200`/`503` signal.
- **`/health/ready`** — anonymous, same reasoning. The endpoint returns no body; an attacker probing it learns only "this Node currently believes itself ready/not-ready," which is identical to information they could infer from whether the Node accepts traffic.
- **`/health`** — **auth-required**. The full aggregate carries per-contributor diagnostic detail, version metadata, and (subject to D8) potentially sensitive contributor messages. The endpoint requires a valid Auth token per [ADR-0010](./ADR-0010-observation-layer.md)'s Invariant 10. Acceptable token shapes: an internal Studios-staff token, a tenant-administrator token (for tenant-visible Nodes — Notify Cloud, future Billing), or an Azure Monitor scrape credential when the dashboarding surface consumes it.

Container Apps ingress respects this: anonymous probes hit `/health/live` and `/health/ready` on the platform's probe path; tenant traffic hits authenticated routes; an internal operator hitting `/health` from a browser or Azure Monitor scrape supplies a token.

Rejected: IP-allowlisting the `/health` endpoint to known Studios egress IPs. Operationally fragile (developer machines, GitHub Actions runner pools, future tenant-administrator browser sessions all have variable egress IPs); auth-on-the-token is the right discipline.

Rejected: anonymizing `/health` and trusting that its body is harmless. The body contains contributor names that hint at internal dependency topology (`service-bus:notify-cloud`, `key-vault:secrets-cache`) — that is reconnaissance value for an attacker. Auth gates it.

### D7. Dependency policy in readiness

`/health/ready` reflects the **readiness aggregate**, which is computed from the subset of `IHealthContributor` instances marked as **required for traffic**. Each contributor declares its readiness policy at registration time:

- `ReadinessPolicy.Required` — a `Degraded` or `Unhealthy` status from this contributor causes `/health/ready` to return `503`. The Node will not receive traffic until the contributor reports `Healthy`. Examples: the primary database connection, the Service Bus connection for Nodes that consume queues, the Vault secrets cache after first warm-up.
- `ReadinessPolicy.OptionalReported` — the contributor's status appears in the `/health` aggregate but **does not affect** `/health/ready`. Examples: Pulse export (telemetry sinks can be unavailable without preventing tenant traffic); third-party observability backends (App Insights ingest, Sentry); optional connector health.
- `ReadinessPolicy.NotReadinessRelevant` — the contributor only appears in `/health`, not in `/health/ready` aggregation. Reserved for diagnostic-only contributors a Node operator wants to expose without it ever being a readiness signal.

The default at registration is `ReadinessPolicy.Required` — a contributor that is registered without an explicit policy is presumed to gate traffic. This is conservative; a non-blocking contributor must declare itself non-blocking explicitly.

`/health/live` does not consult contributors at all. It returns `200` if the process is responding to HTTP requests; the only way it returns `503` is if the host process is in the `Stopping` or `Stopped` lifecycle stage (per the existing `NodeLifecycleHealthContributor` mapping). This protects against a "Node thinks it's unhealthy and asks the orchestrator to kill it" feedback loop on dependency hiccups.

### D8. PII / secrets exposure in `/health`

Contributor `output` strings appear in the `/health` body. They must not carry:

- Connection strings, vault URIs, or credential fragments. The contributor's job is to report status, not to surface the configuration value.
- Tenant-attributable data. A contributor reporting "tenant `tnt_abc123` has expired credentials" is leaking a tenant identifier into an endpoint that — even auth-gated — may be exposed to a different tenant's administrator in a multi-tenant Node. Contributors aggregate to Node-level signals, not per-tenant signals.
- Internal Stripe IDs, Azure resource IDs, or any provider-issued opaque identifier the operator did not deliberately put there.

The contributor implementation is responsible for redaction at the report site. The Kernel-supplied `IHealthContributor` base helper (if one ships — see D9) does **not** auto-redact; the contributor knows what its message contains and the operator's data-classification rubric ([ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md)) governs what is safe to expose.

The `security` specialist review per [ADR-0046](./ADR-0046-specialist-review-agents.md) gains a checklist item for contributor message review.

### D9. Implementation home: Kernel-owned

The endpoint mapping helpers live in **`HoneyDrunk.Kernel`** (the runtime package, not Abstractions — the helpers compose with ASP.NET Core which Kernel.Abstractions explicitly does not depend on). The shape:

```csharp
// HoneyDrunk.Kernel.Hosting.AspNetCore.HealthEndpoints
public static IEndpointRouteBuilder MapHoneyDrunkHealthEndpoints(this IEndpointRouteBuilder endpoints);

// Convenience for Functions-host
public static class HealthFunctionExtensions
{
    public static Task<HttpResponseData> ExecuteHealthLiveAsync(HttpRequestData req, ...);
    public static Task<HttpResponseData> ExecuteHealthReadyAsync(HttpRequestData req, ...);
    public static Task<HttpResponseData> ExecuteHealthAggregateAsync(HttpRequestData req, ...);
}
```

The ASP.NET Core helper wires `MapGet` for the three paths; the Functions helper is a per-function-binding shape consumers compose into their own `HttpTrigger` function.

The underlying substrate is **ASP.NET Core's `Microsoft.Extensions.Diagnostics.HealthChecks`** where it composes — the contributor-to-`IHealthCheck` bridge gives Kernel access to the ecosystem's middleware. Where the substrate diverges from the IETF draft response shape (which it does — the default ASP.NET response is a plain status string), Kernel ships its own response writer that emits the D2 shape. The substrate provides plumbing; the shape is Kernel's.

`INotifyHealthContributor` in `HoneyDrunk.Notify` is reconciled with `IHealthContributor` in Kernel. The Notify-private interface is removed in a follow-up amendment packet; existing Notify contributors are amended to implement `IHealthContributor` directly. The transitional period uses an adapter (`NotifyHealthContributorAdapter : IHealthContributor`) so existing contributor implementations land in the Kernel-shaped aggregate without rewrite.

Pulse.Collector's existing static endpoints are amended to call into the Kernel helpers in a follow-up amendment.

### D10. Telemetry contribution: probe outcomes flow to Pulse

Every health-endpoint invocation contributes to Pulse signals per [ADR-0010](./ADR-0010-observation-layer.md) and [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md):

- A counter `honeydrunk.health.probes` with dimensions `(node, endpoint, status_code, outcome)` increments per probe response. `outcome` is one of `healthy`, `degraded`, `unhealthy`.
- A failed probe (status `503` or contributor exception) raises a structured log entry at **Warning** minimum. `Error` if the failing contributor is `IsCritical`.
- A first-time-after-success `503` raises a log entry at **Error** unconditionally. The first-time-after-success transition is the operationally interesting signal; sustained failures are aggregated into the rate counter.
- Per-contributor execution time contributes a histogram `honeydrunk.health.contributor.duration` with dimension `(node, contributor)`. Detects slow contributors before they become probe-timeout sources.

Telemetry is emitted via Kernel's existing `ITelemetryActivityFactory` (the same surface used by every other Kernel-instrumented operation). The telemetry contribution is **not** a separate sink; it flows through Pulse's existing export per [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md).

Probe outcomes are **not** audit events. Probe traffic is high-volume and the orchestrator's confidence is not a forensic event. The probe-as-attack-signal case (an attacker repeatedly probing `/health/ready` to detect rotation events) is in scope for future rate-limiting work, not for audit.

### D11. Out of scope

- **Public status page.** A tenant-facing `status.honeydrunkstudios.com` is a marketing/Studios surface, not a Node-level health concern. It composes against this ADR's `/health` shape when it lands, but it is a separate decision.
- **Cross-Node aggregate health dashboard.** A "Grid health" dashboard is a Pulse surface that consumes the telemetry signals D10 emits. It is a future work item that composes against this ADR.
- **Per-tenant readiness.** A Node's readiness signal is Node-level — the orchestrator's question is "send any traffic to this revision." Per-tenant gating (this tenant's quota is exhausted; route only their requests away) is a tenant-rate-limit concern at the application layer, not a readiness concern.
- **Synthetic monitoring.** External probes (Azure Monitor synthetic, Pingdom, etc.) hit the same endpoints with no additional plumbing.
- **The `/health` endpoint as a tenant-visible SLA signal.** Tenants do not see `/health`; the auth-required boundary in D6 makes that explicit. A future tenant-facing endpoint (`/api/v1/status`) is a separate decision.

## Consequences

### Affected Nodes

- **`HoneyDrunk.Kernel`** — gains `HoneyDrunk.Kernel.Hosting.AspNetCore.HealthEndpoints` with `MapHoneyDrunkHealthEndpoints`, the IETF-shape response writer, the `ReadinessPolicy` enum, and the contributor-policy registration extension. Lifecycle docs (`HoneyDrunk.Kernel/docs/Health.md`) are amended to reflect the endpoint contract. Spec-level additions, not breaking.
- **`HoneyDrunk.Pulse`** — `Pulse.Collector` amends its existing `HealthEndpoints.cs` to call `MapHoneyDrunkHealthEndpoints` from Kernel. The hand-rolled static responders are removed.
- **`HoneyDrunk.Notify`** — `NotifyHealthEndpointsExtensions` is amended to call into Kernel's helper. `INotifyHealthContributor` is bridged through `NotifyHealthContributorAdapter` in a transitional packet, then deprecated in favor of `IHealthContributor`. `HoneyDrunk.Notify.Functions.HealthFunction` is amended to use the Functions-host helper.
- **`HoneyDrunk.Web.Rest`** — adopts the Kernel helper for its endpoints. The existing `/health` shape is amended onto the IETF body; this is a non-breaking change because the existing shape had no documented consumers per [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) D2 (Web.Rest's v1 freeze).
- **`HoneyDrunk.Notify.Cloud`** (planned per [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)) — composes the Kernel helper at standup. The tenant-facing readiness behavior (`503` while warming) is part of the GA shape from day one.
- **`HoneyDrunk.Operator`, `HoneyDrunk.Agents`, `HoneyHub`** (each per their standup ADR) — compose the Kernel helper at standup. The contributor catalog per Node is per-Node packet work.
- **`HoneyDrunk.Audit`** — composes the helper. Health endpoints are not audit events (D10).
- **`HoneyDrunk.Communications`** — composes the helper.
- **All future containerized deployable Nodes** — compose the helper at standup. Per Invariant 50 the test tiers are scoped to deployable Nodes; this ADR adds no new test invariants.

### Cascade impact

Cross-checked against `catalogs/relationships.json`:

- Kernel changes propagate to every Node that consumes `HoneyDrunk.Kernel` (or `Kernel.Abstractions` for downstream contributors). The contract-shape canary on Kernel.Abstractions remains the gate; new types (`ReadinessPolicy`, additions to the contributor-registration surface) are additive.
- Pulse, Notify, Web.Rest, and Notify.Cloud are the immediate amendment targets. Each gets one packet to bring its health-endpoint code onto the Kernel shape.
- Operator, Agents, HoneyHub adopt at standup; their standup ADRs cite this ADR as a prerequisite for their health-endpoint canaries.
- No new dependency edges; the implementation home is Kernel, which every Node already consumes.

### Invariants

This ADR proposes the following new invariants (final numbers assigned at acceptance by the scope agent):

- **Every HTTP-fronted deployable Node exposes `/health/live`, `/health/ready`, and `/health` via Kernel's `MapHoneyDrunkHealthEndpoints` extension (or the Functions-host equivalent), aggregating `IHealthContributor` instances per the readiness-policy model.** Enforced at standup; the canary surface gains a "health endpoints reachable" check.
- **`/health/live` and `/health/ready` are anonymous; `/health` is auth-required.** Enforced by the `security` specialist review per [ADR-0046](./ADR-0046-specialist-review-agents.md).
- **`IHealthContributor` `output` strings must not carry secrets, connection strings, tenant identifiers, or other restricted-tier data per [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md).** Enforced by review; redaction at the contributor implementation site.

Strengthening of an existing operational rule:

- The Container Apps revision-health gate per Invariant 36 reads `/health/ready` exclusively after this ADR. Existing deploy workflows that probe `/health` are amended to probe `/health/ready` (a behavior change captured in the per-Node amendment packets).

### Operational consequences

- **Probe traffic is non-trivial.** Container Apps' defaults run `/health/live` every 30s and `/health/ready` every 10s, per Node, per replica. At Grid scale (≤20 Nodes × ~2 replicas average × 4 probes/min combined liveness+readiness) the probe load is bounded and well below the cost of any backing dependency. Pulse's counter dimension cardinality is similarly bounded.
- **Telemetry cardinality on `honeydrunk.health.contributor.duration` is `node × contributor`.** A Node with ~10 contributors × 20 Nodes = ~200 series in the histogram. Well within [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md)'s cardinality discipline.
- **Contributor execution time becomes a load-bearing operational signal.** A 1-second slow Vault contributor pulls `/health/ready` latency past the probe's 3-second timeout, which fails the probe, which removes the Node from rotation. Contributors must be aggressively bounded (sub-100ms target, hard timeout enforced by the aggregator). The Kernel aggregator wraps each contributor in a 1-second timeout by default; configurable per registration.
- **The Notify amendment requires care.** `INotifyHealthContributor` is a real (small) surface; the bridge-then-deprecate path means two contributor interfaces coexist briefly. The amendment packet stages: (1) bridge adapter lands, (2) Notify contributors amend to `IHealthContributor` directly, (3) `INotifyHealthContributor` is removed. The bridge keeps Notify's CHANGELOG entry from being a breaking event.
- **The Pulse.Collector amendment is a strict simplification.** The hand-rolled static responders disappear; the Kernel helper takes over. Net code reduction.
- **The `/health` auth-required posture means tenant administrators of Notify Cloud do not see the aggregated body.** They see only `/health/live` and `/health/ready` outcomes via integration with the orchestrator. If a tenant-visible status page becomes a Notify Cloud GA requirement, it composes against this ADR's `/health` shape through a separate tenant-scoped surface.
- **Container Apps probe failure thresholds are conservative.** Three consecutive failures at 10s readiness intervals (D5) means ~30 seconds before traffic-withhold; three consecutive at 30s liveness intervals means ~90 seconds before restart. These are the right defaults for the Grid's load profile but should be revisited per-Node if a Node's contributor surface settles slower or faster.

### Follow-up work

Not edited by this ADR — listed for the scope agent's packet wave at acceptance time. The user runs the scope agent separately per the standard workflow.

- File the Kernel implementation packet — `HoneyDrunk.Kernel.Hosting.AspNetCore.HealthEndpoints`, `MapHoneyDrunkHealthEndpoints`, the IETF response writer, the `ReadinessPolicy` enum, the contributor-execution timeout wrapper, the Functions-host helper.
- Update `HoneyDrunk.Kernel/docs/Health.md` to document the endpoint contract and the contributor readiness policies.
- Add the proposed invariants to `constitution/invariants.md` with scope-agent-assigned numbers at acceptance time.
- File a Notify amendment packet — bridge `INotifyHealthContributor` through `NotifyHealthContributorAdapter`, amend `NotifyHealthEndpointsExtensions` to call the Kernel helper, amend `HealthFunction` to use the Functions-host helper.
- File a Notify follow-up packet — amend Notify contributors to implement `IHealthContributor` directly; remove `INotifyHealthContributor`.
- File a Pulse.Collector amendment packet — replace static `HealthEndpoints.cs` with the Kernel helper.
- File a Web.Rest amendment packet — adopt the Kernel helper; amend the response shape onto the IETF body within the v1 surface freeze.
- Update `catalogs/contracts.json` with the `ReadinessPolicy` enum and the contributor-registration extension under `honeydrunk-kernel`.
- Update `repos/HoneyDrunk.Kernel/integration-points.md` with the health-endpoint contract.
- Update `repos/HoneyDrunk.Notify/integration-points.md` with the contributor-interface reconciliation.
- Add per-Node Container Apps probe declarations to each containerized Node's infrastructure walkthrough — Pulse, Notify (Worker), future Notify.Cloud, Operator, Agents, HoneyHub.
- Update `.claude/agents/review.md` and the `security` specialist prompt with a health-endpoint checklist: three endpoints mapped, auth posture correct, contributor messages reviewed for PII, contributor execution time bounded.
- Coordinate with the deploy-workflow owner ([ADR-0015](./ADR-0015-container-hosting-platform.md)'s `job-deploy-container-app.yml` in `HoneyDrunk.Actions`) to confirm the readiness-gate probe target switches from `/health` to `/health/ready` for new revisions.

## Alternatives Considered

### Two-endpoint convention (`/health` and `/health/ready`)

Considered: collapse liveness into the full-health aggregate; the orchestrator probes the aggregate. Rejected because conflating "is the process alive" with "is every dependency reachable" means transient dependency failures trigger container restarts. Container Apps and Kubernetes both expose distinct liveness and readiness probes because the operational semantics differ. The three-endpoint shape (D1) matches what the orchestrator expects.

### One-endpoint convention with query parameter (`/health?check=live`)

Considered: a single `/health` endpoint with a `?check=` query parameter selecting the mode. Rejected because Container Apps probe configuration would need to encode the query parameter (the platform supports it, but the URL-as-debug-aid property the operator relies on weakens), and the body shape would have to switch by query parameter, which complicates the IETF response writer. Three distinct paths is the more legible shape.

### Kubernetes-style `/healthz`, `/readyz`, `/livez`

Considered: the k8s ecosystem convention. Rejected because `/health/{aspect}` is the more conventional shape outside the k8s lineage, and the Grid runs on Container Apps. The Container Apps documentation samples lean toward `/health/...` paths. The chosen convention is the more legible one for the platform actually in use.

### IETF `health+json` body for every endpoint, including `/health/live` and `/health/ready`

Considered: return the structured body on all three endpoints; let the orchestrator parse only the status code. Rejected because the probe body is consumed-nowhere — Container Apps and Kubernetes probes do not parse JSON. Emitting the body on probes is wasted bytes and increases the surface for leaking detail through contributor messages. Empty body on probes (D2) is the cheapest and least-leak-prone shape.

### Per-Node-private health-endpoint code (the current Notify pattern, generalized)

Considered: let each Node continue to ship its own endpoint code and contributor interface. Rejected because the drift between Pulse.Collector's static endpoints and Notify's contributor-aggregating endpoints is exactly the failure mode this ADR is designed to prevent. Kernel-owned helpers (D9) are the right substrate for a uniform Grid-wide shape.

### Make `/health` anonymous, redact contributor messages

Considered: drop the auth requirement on `/health`; rely on D8's redaction discipline to keep the body safe. Rejected because the contributor names themselves (`service-bus:notify-cloud`, `key-vault:secrets-cache`) expose internal dependency topology to an attacker. Reconnaissance value is real. Auth-gating (D6) is the right discipline; an anonymous status page is a separate Studios surface (D11).

### Anonymous `/health` for the Studios-internal dev/staging environments; auth-required only in prod

Considered: relax the auth posture per environment. Rejected because per-environment posture invites the "I forgot to flip the toggle in prod" failure mode. Uniform auth-required is the safe default; an authenticated probe credential is cheap.

### Use ASP.NET Core's default `MapHealthChecks` and its default response writer

Considered: skip the Kernel helper and use the framework's default. Rejected because the default response is a plain text status string ("Healthy", "Degraded", "Unhealthy") which does not match the IETF `health+json` shape D2 commits. The Kernel helper builds on the framework's substrate but emits the Grid-committed shape. Sticking with the default would mean every consumer of `/health` writes a per-Node body parser.

### IP-allowlist `/health` to Studios egress

Considered: replace the auth requirement on `/health` with an IP allowlist of Studios egress and Azure Monitor scrape IPs. Rejected as operationally fragile (developer machines, GitHub Actions runner pools, future tenant-administrator browser sessions all have variable egress). Token-based auth is the more sustainable discipline.

### Make probe outcomes audit events per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md)

Considered: every probe response is an `IAuditLog` emit. Rejected because probe volume is high (one Node × 2 replicas × 4 probes/min × 60min = 480 probes/hour just from the orchestrator), the events are not attributable to a principal, and they are not forensically interesting. Telemetry per D10 is the right substrate. Audit's volume budget per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) D4's distinct-from-observability retention is not the right place for probe traffic.

### Defer until a second containerized Node beyond Notify/Pulse exists, to validate cross-Node patterns

Considered: wait for Operator standup to make this decision. Rejected because Operator's standup is days-to-weeks out and its health-endpoint code will be committed at standup. Settling the shape now means Operator inherits the substrate; deferring means Operator invents its own shape and the reconciliation cost lands later. Pulse's drift and Notify's contributor-interface fork are the empirical evidence — two Nodes is already enough to demonstrate the drift problem.

### Per-Node probe configuration without Grid-wide defaults

Considered: each Node declares its own probe periods, failure thresholds, and initial delays. Rejected because per-Node variation invites "Notify's probes are 10s, Pulse's are 30s, and Operator's are 5s — which is the right one when we add a new Node?" The defaults in D5 are starting points the deploy workflow consumes; per-Node overrides are permitted but the default is published.

### Use `Microsoft.Extensions.Diagnostics.HealthChecks` `HealthStatus` enum directly

Considered: drop the Kernel-owned `HealthStatus` enum; standardize on the framework's. Rejected because the Kernel enum is already canonical in `HoneyDrunk.Kernel.Abstractions.Health.HealthStatus`, every contributor implementation uses it, and the framework enum is a 1:1 mapping (`Healthy` ↔ `Healthy`, `Degraded` ↔ `Degraded`, `Unhealthy` ↔ `Unhealthy`). The Kernel enum stays the contract surface; the framework type appears at the host-side bridge only.

### Combine this ADR with the future tenant-facing status-page ADR

Considered: govern Node-level probes and tenant-facing status pages in a single ADR. Rejected on scope — the tenant-facing surface is a marketing/Studios product surface with its own concerns (incident communication, history, subscriber notifications). This ADR governs the Node-internal contract; the status-page ADR composes against it when it lands.
