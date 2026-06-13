---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0066", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0066"]
wave: 1
initiative: adr-0066-health-endpoints
node: honeydrunk-architecture
---

# Register ADR-0066 health-endpoint contract surface in the Grid catalogs

## Summary
Record ADR-0066's new contract surface as catalog data: register the `ReadinessPolicy` enum, the `IHealthContributor` registration extension (the contributor + readiness-policy registration helper), the `MapHoneyDrunkHealthEndpoints` extension (and its Functions-host equivalents `ExecuteHealthLiveAsync` / `ExecuteHealthReadyAsync` / `ExecuteHealthAggregateAsync`), and the IETF response-shape DTOs by appending to the `interfaces` array of the `honeydrunk-kernel` block inside the top-level `contracts` array in `catalogs/contracts.json` (schema verified at packet-authoring time: top-level key is `contracts`; each block's per-node entries live under the `interfaces` array). Append the new type names to the `honeydrunk-kernel` entry's `exposes.contracts` array in `catalogs/relationships.json`. Update `repos/HoneyDrunk.Kernel/integration-points.md` with the health-endpoint contract entry and `repos/HoneyDrunk.Notify/integration-points.md` with the contributor-interface reconciliation note.

## Context
ADR-0066 D9 places the endpoint mapping helpers in `HoneyDrunk.Kernel.Hosting.AspNetCore.HealthEndpoints` (the runtime package). The contract-surface additions split as follows:
- **`HoneyDrunk.Kernel.Abstractions`** gains `ReadinessPolicy` (enum) and the contributor-registration extension members the host calls at composition time to declare a contributor's policy. ADR-0066 D7 names the three values (`Required`, `OptionalReported`, `NotReadinessRelevant`) and pins `Required` as the default. The IETF response DTOs (`HealthCheckResponse`, `HealthCheckEntry`, etc.) likely live in `Kernel.Abstractions` too because they shape the wire format Notify/Pulse code references in their amendment packets.
- **`HoneyDrunk.Kernel`** (runtime) gains `HoneyDrunk.Kernel.Hosting.AspNetCore.HealthEndpoints` with `MapHoneyDrunkHealthEndpoints` and the Functions-host static helper class. These compose with ASP.NET Core and are not contract-surface for downstream consumption — they are runtime extensions a host wires. Catalog them as `extension`/`type` rather than `interface`.

The Grid catalogs are the discoverability surface — `catalogs/contracts.json` has a top-level `contracts` array; each entry is a per-Node block carrying `node`, `node_name`, `package`, `status`, and an `interfaces` array of contract entries. `catalogs/relationships.json` lists each Node's contract names under `exposes.contracts`. This packet keeps both catalogs accurate so packets 02–07 and any downstream Node have an accurate contract/dependency graph. The naming asymmetry is the schema's: top-level `contracts` array vs per-node `interfaces` array — both names are load-bearing.

The integration-points docs for `HoneyDrunk.Kernel` and `HoneyDrunk.Notify` need to reflect (a) the Kernel health-endpoint contract Kernel exposes and (b) the Notify-private `INotifyHealthContributor` interface's reconciliation onto `IHealthContributor` (ADR-0066 D9).

This is a catalog/docs packet. No code, no .NET project.

## Scope
- `catalogs/contracts.json` — inside the top-level `contracts` array, locate the block whose `node` value is `honeydrunk-kernel`; append entries to that block's `interfaces` array for the new contract surface (`ReadinessPolicy`, the contributor-registration extension, the endpoint-mapping extension, the Functions-host helper, the IETF response DTOs).
- `catalogs/relationships.json` — append the new type names to the `honeydrunk-kernel` entry's `exposes.contracts` array. No new top-level Node-to-Node edge — every affected Node already consumes `HoneyDrunk.Kernel.Abstractions`.
- `repos/HoneyDrunk.Kernel/integration-points.md` — add the health-endpoint contract entry (the three endpoints, their consumers — Container Apps probes, Azure Monitor scrapes, the deploy workflow's revision-health gate).
- `repos/HoneyDrunk.Notify/integration-points.md` — add the contributor-interface reconciliation note (Notify-private `INotifyHealthContributor` bridged via `NotifyHealthContributorAdapter` in packet 05, removed in packet 07).
- `catalogs/nodes.json` — **not edited.** nodes.json entries have no `exposes` field; the contract surface lives in relationships.json and contracts.json (precedent: ADR-0042 packet 01).

## Proposed Implementation
1. **`catalogs/contracts.json`** — locate the node block whose `node` value is `honeydrunk-kernel` (do not rely on line numbers). Append entries to that block's `interfaces` array, matching the existing `{ "name", "kind", "description" }` shape:
   - `ReadinessPolicy` — `kind: type` — "Enum declaring whether an IHealthContributor gates traffic at /health/ready. Values: Required (default; degraded/unhealthy fails /health/ready); OptionalReported (appears in /health body but does not gate readiness); NotReadinessRelevant (only in /health, never in readiness aggregation)."
   - `HealthContributorRegistration` — `kind: type` — "Extension methods on IServiceCollection (or the equivalent registration surface) that register an IHealthContributor with an explicit ReadinessPolicy. Default policy is Required."
   - `MapHoneyDrunkHealthEndpoints` — `kind: extension` — "IEndpointRouteBuilder extension that maps /health/live, /health/ready, and /health on the host. Anonymous routes for the probe endpoints; auth-required attribute on /health (host wires the auth scheme)."
   - `HealthFunctionExtensions` — `kind: type` — "Functions-host helper exposing ExecuteHealthLiveAsync, ExecuteHealthReadyAsync, ExecuteHealthAggregateAsync that consumers compose into their own HttpTrigger functions when running on the Functions host."
   - `HealthCheckResponse` — `kind: type` — "Record/DTO mapping the IETF Health Check Response Format for HTTP APIs (application/health+json) body emitted by /health. Carries status (pass/warn/fail), version, releaseId, and per-contributor checks dictionary."
   - `HealthCheckEntry` — `kind: type` — "Record/DTO for a single contributor's entry in the /health body. Carries status (pass/warn/fail), time (ISO-8601), and optional output (the contributor's message string, subject to the PII rule from ADR-0066 D8)."
   - Drop the leading `I` from record/DTO names per the Grid naming rule (records drop the `I`); interfaces keep the `I`. The contract-shape names here are records/types/extensions, not interfaces, so no `I` prefix.
2. **`catalogs/relationships.json`** — append `ReadinessPolicy`, `HealthContributorRegistration`, `MapHoneyDrunkHealthEndpoints`, `HealthFunctionExtensions`, `HealthCheckResponse`, `HealthCheckEntry` to the `honeydrunk-kernel` entry's `exposes.contracts` array. Do not touch existing entries. The existing `IHealthContributor` and `IReadinessContributor` entries stay as-is.
3. **`catalogs/nodes.json`** — no edit. nodes.json has no `exposes` field; do not invent one (precedent: ADR-0042 packet 01).
4. **`repos/HoneyDrunk.Kernel/integration-points.md`** — add a "Health endpoints (ADR-0066)" subsection. State: (a) Kernel exposes `MapHoneyDrunkHealthEndpoints` and the Functions-host helper; (b) consumers are Container Apps probes (livenessProbe/readinessProbe/startupProbe per ADR-0066 D5), Azure Monitor scrapes on `/health`, and the `job-deploy-container-app.yml` revision-health gate which probes `/health/ready`; (c) the substrate is `Microsoft.Extensions.Diagnostics.HealthChecks` with a Kernel-shipped IETF response writer.
5. **`repos/HoneyDrunk.Notify/integration-points.md`** — add a "Health contributor reconciliation (ADR-0066)" subsection. State: (a) Notify currently ships `INotifyHealthContributor` in `HoneyDrunk.Notify.Hosting.AspNetCore.Health`; (b) packet 05 introduces `NotifyHealthContributorAdapter : IHealthContributor` to bridge existing Notify contributor implementations onto the Kernel-shaped aggregate; (c) packet 07 amends Notify contributors to implement `IHealthContributor` directly and removes the Notify-private interface; (d) during the transitional period, the bridge keeps Notify's CHANGELOG entry from being a breaking event.

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `repos/HoneyDrunk.Kernel/integration-points.md`
- `repos/HoneyDrunk.Notify/integration-points.md`

## NuGet Dependencies
None. This packet touches only catalog JSON and Markdown integration-points docs; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Catalog data and integration-points narrative only; the Kernel/Pulse/Notify code lands in packets 02–07.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` registers all six new entries in the `honeydrunk-kernel` node block's `interfaces` array, matching the existing entry shape
- [ ] `catalogs/relationships.json` `honeydrunk-kernel` entry lists all six new type names in `exposes.contracts`, with all existing entries (including `IHealthContributor` and `IReadinessContributor`) untouched
- [ ] `catalogs/nodes.json` is NOT modified (it has no `exposes` field)
- [ ] No new top-level Node-to-Node edge is created (every affected Node already consumes `HoneyDrunk.Kernel.Abstractions`)
- [ ] `repos/HoneyDrunk.Kernel/integration-points.md` gains a "Health endpoints (ADR-0066)" subsection naming the endpoints, consumers, and substrate
- [ ] `repos/HoneyDrunk.Notify/integration-points.md` gains a "Health contributor reconciliation (ADR-0066)" subsection naming the bridge-then-deprecate sequencing
- [ ] No invariant change in this packet (invariants land in packet 00)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0066 D7 — `ReadinessPolicy` enum.** Three values: `Required` (default, gates readiness), `OptionalReported` (in `/health` body only), `NotReadinessRelevant` (only in `/health`). Default at registration is `Required` — a contributor without an explicit policy is presumed to gate traffic.

**ADR-0066 D9 — Implementation home.** `HoneyDrunk.Kernel.Hosting.AspNetCore.HealthEndpoints` with `MapHoneyDrunkHealthEndpoints` (ASP.NET Core), plus `HealthFunctionExtensions` for the Functions host. Substrate is `Microsoft.Extensions.Diagnostics.HealthChecks` with a Kernel-shipped IETF response writer. `INotifyHealthContributor` is reconciled with `IHealthContributor`; transitional `NotifyHealthContributorAdapter` bridge.

**ADR-0066 D2 — IETF `application/health+json` response shape.** `status` (`pass`/`warn`/`fail`), `version`, `releaseId`, and a `checks` dictionary keyed by contributor name carrying per-contributor `status`/`time`/optional `output`.

**ADR-0066 Consequences — Affected Nodes.** Kernel gains the helper and the `ReadinessPolicy` enum. Pulse and Notify are amended in this initiative (packets 05/06/07). Notify.Cloud (planned per ADR-0027), Operator (ADR-0018), Agents (ADR-0020), HoneyHub (ADR-0002/0003), Audit (ADR-0031), Communications (ADR-0028 D4 — composes inside Notify.Cloud's host) all compose the helper at their own standup. **Web.Rest has no current `/health` code** (library-only Node at packet-authoring time, audited via `repos/HoneyDrunk.Web.Rest/`); the Web.Rest amendment is anticipatory — no Web.Rest packet exists in this initiative. When a future Web.Rest deployable consumer first ships, that consumer's host PR composes the Kernel helper. See dispatch plan's "Web.Rest is mentioned but has no current `/health` code" section.

## Constraints
- **Records/types drop the `I`; interfaces keep it.** Grid-wide naming rule: `ReadinessPolicy`, `HealthCheckResponse`, `HealthCheckEntry`, `HealthContributorRegistration`, `HealthFunctionExtensions` are types/extensions/records — no `I` prefix. The existing `IHealthContributor` / `IReadinessContributor` stay `I`-prefixed.
- **No new Node-to-Node edge.** Every affected Node already consumes `HoneyDrunk.Kernel.Abstractions`. The contracts are additive; only `exposes.contracts` is enriched.
- **nodes.json is NOT edited.** nodes.json has no `exposes` field; precedent set in ADR-0042 packet 01.
- **Match existing entry shape.** Match the `{ "name", "kind", "description" }` shape already used in `contracts.json` for the `honeydrunk-kernel` block.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0066`, `wave-1`

## Agent Handoff

**Objective:** Register ADR-0066's health-endpoint contract surface in the Grid catalogs and update the Kernel/Notify integration-points docs.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Keep the contract/dependency catalogs accurate so implementation packets 02–07 read a correct graph.
- Feature: ADR-0066 Health, Readiness, and Liveness Endpoint Contract rollout, Wave 1.
- ADRs: ADR-0066 D2/D7/D9 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0066 should be Accepted before its contract surface is recorded as catalog data.

**Constraints:**
- Records/types drop the `I`; interfaces keep it. `IHealthContributor` and `IReadinessContributor` stay as-is.
- No new top-level Node-to-Node edge — only `exposes.contracts` enrichment.
- `catalogs/nodes.json` is NOT edited — it has no `exposes` field.
- Match the existing `{ "name", "kind", "description" }` shape in `contracts.json`.

**Key Files:**
- `catalogs/contracts.json` — new entries in the `honeydrunk-kernel` block's `interfaces` array.
- `catalogs/relationships.json` — `honeydrunk-kernel` `exposes.contracts` enrichment.
- `repos/HoneyDrunk.Kernel/integration-points.md` — new health-endpoint subsection.
- `repos/HoneyDrunk.Notify/integration-points.md` — new contributor-reconciliation subsection.

**Contracts:** None changed — this packet only records catalog metadata for contracts that packet 02 (Abstractions additions) and packet 03 (runtime endpoints) implement.
