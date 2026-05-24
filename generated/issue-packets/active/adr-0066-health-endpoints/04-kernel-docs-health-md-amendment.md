---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["chore", "tier-1", "core", "docs", "adr-0066", "wave-3"]
dependencies: ["packet:03"]
adrs: ["ADR-0066"]
wave: 3
initiative: adr-0066-health-endpoints
node: honeydrunk-kernel
---

# Amend HoneyDrunk.Kernel/docs/Health.md with the ADR-0066 endpoint contract

## Summary
Amend `HoneyDrunk.Kernel/docs/Health.md` to document the ADR-0066 health endpoint contract (`/health/live`, `/health/ready`, `/health`), the `ReadinessPolicy` model (D7), the auth posture (D6), the aggregation rules (D4), the IETF response shape (D2), the Pulse telemetry contribution (D10), and the per-contributor timeout. The current docs describe the distinction between `IHealthCheck` (internal primitive) and `IHealthContributor` (Node-level aggregation) but predate the endpoint contract — extend the file with the new sections without removing the existing primitive-vs-contributor narrative.

## Context
ADR-0066 follow-up list explicitly calls for: "Update `HoneyDrunk.Kernel/docs/Health.md` to document the endpoint contract and the contributor readiness policies." This packet does that.

The current `docs/Health.md` (state as of ADR-0066 acceptance):
- Documents `IHealthCheck` (the simpler internal-component primitive).
- Documents `HealthStatus` (the three-state enum).
- Documents `CompositeHealthCheck` (the simple aggregator for `IHealthCheck`).
- Documents the relationship between `IHealthCheck` (Health) and `IHealthContributor` (Lifecycle).
- Names "Kubernetes-style" liveness probes — needs an addendum that the Grid is on Container Apps with the D5 probe defaults.

What ADR-0066 adds that this packet must document:
- The three endpoints `/health/live`, `/health/ready`, `/health` and their paths (D1).
- The IETF `application/health+json` response shape on `/health` (D2).
- The `ReadinessPolicy` enum and its three values (D7).
- The aggregation rules: worst-status-wins, critical-degraded escalation, throwing-contributor handling, contributor timeout (D4 + Operational Consequences).
- The auth posture: probes anonymous, `/health` auth-required (D6).
- The Container Apps probe defaults (D5).
- The Pulse telemetry contribution (D10).
- The PII rule for contributor `output` strings (D8).
- The `MapHoneyDrunkHealthEndpoints` extension and the Functions-host helper (D9) — pointing to the runtime package, not Abstractions.

This packet runs in Wave 3 alongside packet 03 (the runtime endpoints) because the docs reference types and APIs that packet 03 introduces — the docs are accurate only once packet 03's code is on the same branch / merged. Hard-block this packet on packet 03's merge to avoid stale doc references.

This is a Kernel-repo docs packet. No code, no `.csproj` change, no version bump (per invariant 27 — packets 02 + 03 own the `0.8.0` bump and the per-package CHANGELOG entries; this packet appends to the existing `[0.8.0]` repo-level `CHANGELOG.md` entry as a docs note).

## Scope
- `HoneyDrunk.Kernel/docs/Health.md` — extend with new sections covering the ADR-0066 endpoint contract.
- Repo-level `CHANGELOG.md` — append a docs note to the in-progress `[0.8.0]` entry.

## Proposed Implementation
1. Read the existing `docs/Health.md`. Keep the **Overview**, **`IHealthCheck.cs`**, **`HealthStatus.cs`**, and **`CompositeHealthCheck`** sections — they remain accurate.
2. Amend the **Relationship to Lifecycle** section: the comparison table is correct ("`IHealthCheck` for internal checks; `IHealthContributor` for Node-level aggregation exposed to orchestrators") but the "Kubernetes liveness/readiness" framing predates the Container Apps decision (ADR-0015). Update the framing to "Container Apps liveness/readiness probes (per ADR-0015 / ADR-0066)" while keeping the conceptual table intact.
3. Add a new top-level section **Endpoint Contract (ADR-0066)** with subsections:
   - **The three endpoints** — `/health/live`, `/health/ready`, `/health`. Semantics per ADR-0066 D1.
   - **Response shapes** — probes return empty body with `200`/`503`; `/health` returns IETF `application/health+json` (D2). Include the sample JSON body from ADR-0066 D2.
   - **Status mapping** — `HealthStatus.Healthy` → `"pass"`, `Degraded` → `"warn"`, `Unhealthy` → `"fail"` (D3). The Kernel enum stays the implementation surface; the wire string appears only on the IETF body.
   - **`ReadinessPolicy`** — the three values (`Required`, `OptionalReported`, `NotReadinessRelevant`), what each means for `/health/ready` aggregation, and the registration default (`Required`).
   - **Aggregation rules** — worst-status-wins; `Degraded` + `IsCritical == true` → `Unhealthy`; throwing contributor → `Unhealthy` with exception message in `output`; one contributor's failure does not short-circuit others (D4). Note that `IHealthCheck` is **not** consulted by the endpoint — it remains the internal-component primitive (the existing section in this file is still the right reference for that primitive).
   - **`/health/live` does not consult contributors** — it returns based on lifecycle stage only (D7), protecting against feedback-loop restarts on dependency hiccups.
   - **Contributor timeout** — the Kernel aggregator wraps each contributor in a 1-second timeout by default; configurable per registration. Targets sub-100ms contributor execution.
   - **Auth posture** — probe endpoints anonymous; `/health` auth-required (host configures scheme). Cross-reference Invariant `{N2}`.
   - **Contributor message PII rule** — contributor `output` strings must not carry secrets, connection strings, tenant identifiers, or provider opaque IDs (D8). Cross-reference invariants 8 and 56 and ADR-0049.
4. Add a new top-level section **Wiring the endpoints** with subsections:
   - **ASP.NET Core host** — call `endpoints.MapHoneyDrunkHealthEndpoints()` in the host's endpoint route configuration. Show a minimal sample.
   - **Functions host** — use `HealthFunctionExtensions.ExecuteHealthLiveAsync` / `ExecuteHealthReadyAsync` / `ExecuteHealthAggregateAsync` from inside a `[Function]` `[HttpTrigger]`-bound function. Show a minimal sample matching the pattern Notify.Functions adopts in packet 06.
   - **Registering contributors with a `ReadinessPolicy`** — the registration extension shape from packet 02; show the three policy values in use (required DB, optional Pulse export, diagnostic-only NotReadinessRelevant contributor).
5. Add a new top-level section **Container Apps probe configuration (ADR-0066 D5)** with the probe-defaults table from the ADR:

   | Probe | Path | Period | Initial delay | Timeout | Failure threshold | Success threshold |
   |---|---|---|---|---|---|---|
   | `livenessProbe` | `/health/live` | 30s | 10s | 3s | 3 | 1 |
   | `readinessProbe` | `/health/ready` | 10s | 5s | 3s | 3 | 1 |
   | `startupProbe` | `/health/live` | 5s | 0s | 3s | 30 | 1 |

   And the revision health-gate rule: a new revision is shifted to 100% traffic only after `/health/ready` returns `200` for at least three consecutive periods on the revision's direct FQDN. Reference invariant 36 (Container App revision-mode-Multiple with traffic splitting).
6. Add a new top-level section **Telemetry (ADR-0066 D10)** with:
   - Counter `honeydrunk.health.probes` with `(node, endpoint, status_code, outcome)`.
   - Histogram `honeydrunk.health.contributor.duration` with `(node, contributor)`.
   - Log severity: Warning on failed probe; Error on failed critical contributor; first-time-after-success `503` logs at Error.
   - Note: probe outcomes are **not** audit events (D10 prose).
7. Add a short **Migration note for existing Nodes** subsection (or at the bottom):
   - `HoneyDrunk.Pulse.Collector` — its existing static `MapHealthEndpoints` is amended in this initiative (packet 05) to call `MapHoneyDrunkHealthEndpoints` from Kernel. Link to packet 05's planned change.
   - `HoneyDrunk.Notify` — `NotifyHealthEndpointsExtensions` is amended in packet 06; `INotifyHealthContributor` is bridged via `NotifyHealthContributorAdapter` in packet 06 and removed in packet 07. The Functions-host `HealthFunction` is amended in packet 06 to use the Functions-host helper.
8. Append a docs note to the repo-level `CHANGELOG.md`'s in-progress `[0.8.0]` entry: "docs: document the ADR-0066 health-endpoint contract and Container Apps probe defaults in `docs/Health.md`." No version bump (invariant 27).

## Affected Files
- `HoneyDrunk.Kernel/docs/Health.md`
- Repo-level `CHANGELOG.md` (`[0.8.0]` docs append).

## NuGet Dependencies
None. This packet touches only Markdown docs; no .NET project is created or modified.

## Boundary Check
- [x] Kernel-repo docs change describing Kernel's contract surface and the Container Apps integration. Routing rule "context, ... health contributor → HoneyDrunk.Kernel" maps here.
- [x] No code change.
- [x] No new dependency.

## Acceptance Criteria
- [ ] `docs/Health.md` retains the existing `IHealthCheck` / `HealthStatus` / `CompositeHealthCheck` / Relationship-to-Lifecycle sections (the internal-primitive narrative stays accurate)
- [ ] The "Relationship to Lifecycle" section is amended from generic "Kubernetes" framing to Container-Apps-specific framing (referencing ADR-0015 / ADR-0066)
- [ ] A new **Endpoint Contract (ADR-0066)** section documents the three endpoints, response shapes (with the IETF body sample), status mapping, `ReadinessPolicy`, aggregation rules, `/health/live` not consulting contributors, contributor timeout, auth posture, and the contributor-message PII rule
- [ ] A new **Wiring the endpoints** section shows minimal samples for both ASP.NET Core and Functions host, plus a sample of registering contributors with each `ReadinessPolicy` value
- [ ] A new **Container Apps probe configuration (ADR-0066 D5)** section carries the probe-defaults table and the revision-health-gate rule
- [ ] A new **Telemetry (ADR-0066 D10)** section lists the counter, histogram, log severities, and the "not audit events" note
- [ ] A migration note names the packet-05 (Pulse) and packet-06/07 (Notify) amendments
- [ ] Cross-references to invariants 8, 36, 55, 56 and ADR-0049 are present where appropriate
- [ ] No code change; no `.csproj` change; no version bump
- [ ] Repo-level `CHANGELOG.md` `[0.8.0]` entry has a docs-note append
- [ ] `pr-core.yml` tier-1 gate passes

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0066 D1/D2/D3/D4/D5/D6/D7/D8/D9/D10** — the full ADR is referenced; this packet documents the contract end-to-end in the Kernel docs.

**ADR-0015 — Container Apps as hosting platform.** The Container Apps probe defaults (D5) compose against ADR-0015's hosting choice; the docs reference both ADRs together for context.

**ADR-0049 — Data classification.** Invariant `{N3}` cites ADR-0049; the docs reference it for the contributor-message PII rule.

## Constraints
- **Invariant 27 — no version bump in this packet.** Packet 02 owns the version bump; this packet appends a docs note to the in-progress `[0.8.0]` repo-level `CHANGELOG.md` entry.
- **Keep the existing `IHealthCheck`/`HealthStatus`/`CompositeHealthCheck` narrative.** It remains accurate; the new sections extend the file rather than replacing existing content.
- **`IHealthCheck` is not consulted by the endpoint.** The docs must state this clearly to avoid the readers' natural assumption that the simpler primitive is the endpoint's source.
- **Cross-reference invariant 8.** The contributor-message PII rule (Invariant `{N3}`) is broader than "secrets in telemetry" (invariant 8) but does not replace it; the docs reference both.

## Labels
`chore`, `tier-1`, `core`, `docs`, `adr-0066`, `wave-3`

## Agent Handoff

**Objective:** Document the ADR-0066 endpoint contract, `ReadinessPolicy` model, aggregation rules, Container Apps probe defaults, and Pulse telemetry contribution in `HoneyDrunk.Kernel/docs/Health.md`.

**Target:** `HoneyDrunk.Kernel`, branch from `main` (after packet 03 has merged so the docs reference live code).

**Context:**
- Goal: Make `docs/Health.md` the authoritative implementation guide for the contract every Node calls.
- Feature: ADR-0066 Health, Readiness, and Liveness Endpoint Contract rollout, Wave 3 (alongside packet 03's runtime code).
- ADRs: ADR-0066 (full), ADR-0015 (Container Apps), ADR-0049 (data classification, referenced via Invariant `{N3}`), ADR-0008.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` — the runtime code (`MapHoneyDrunkHealthEndpoints`, the Functions-host helper, the aggregator) must be on the branch before the docs reference it.

**Constraints:**
- Keep the existing `IHealthCheck` / `HealthStatus` / `CompositeHealthCheck` narrative (the internal-primitive story stays accurate).
- State clearly that `IHealthCheck` is NOT consulted by the endpoint — only `IHealthContributor` participates in endpoint aggregation.
- No version bump (invariant 27); docs append to the in-progress `[0.8.0]` `CHANGELOG.md` entry.
- Cross-reference invariants 8, 36, 55, 56 where appropriate.

**Key Files:**
- `HoneyDrunk.Kernel/docs/Health.md`
- Repo-level `CHANGELOG.md`.

**Contracts:** None changed — docs-only packet.
