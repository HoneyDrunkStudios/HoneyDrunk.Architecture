---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "adr-0066", "wave-4"]
dependencies: ["packet:03"]
adrs: ["ADR-0066"]
wave: 4
initiative: adr-0066-health-endpoints
node: honeydrunk-pulse
---

# Amend Pulse.Collector to call MapHoneyDrunkHealthEndpoints from Kernel

## Summary
Amend `HoneyDrunk.Pulse.Collector`'s existing static `HealthEndpoints.cs` to call `MapHoneyDrunkHealthEndpoints` from `HoneyDrunk.Kernel` (per ADR-0066 D9). The current hand-rolled static endpoints return `200 OK { "Status": "..." }` for `/health`, `/health/live`, `/health/ready` regardless of any contributor state. After this packet, the endpoints follow the Grid-wide contract: `/health/live` and `/health/ready` are empty-body 200/503 (consulting the aggregator); `/health` returns the IETF `application/health+json` body (auth-required).

## Context
ADR-0066 Context audited the current state: `HoneyDrunk.Pulse.Collector/Endpoints/HealthEndpoints.cs` ships three endpoints (`/health`, `/health/ready`, `/health/live`) — each returning a static `200 OK` with a one-field `Status` body. None consult `IHealthContributor` aggregation; they are placeholders. ADR-0066 D9 and the Consequences "Affected Nodes" entry name Pulse.Collector as one of the amendments: "Pulse.Collector amends its existing `HealthEndpoints.cs` to call `MapHoneyDrunkHealthEndpoints` from Kernel. The hand-rolled static responders are removed."

The current file is small (one static `MapHealthEndpoints` method, no contributors), so the amendment is a strict simplification: replace the hand-rolled `MapGet` calls with a single delegation to `MapHoneyDrunkHealthEndpoints`. The host composition for Pulse.Collector must:
- Register Pulse.Collector's contributors (if any exist today — at minimum the `NodeLifecycleHealthContributor` from Kernel) with their `ReadinessPolicy` values (default `Required`).
- Wire the host's default auth scheme so `/health` is auth-gated (per invariant `{N2}`). Pulse.Collector's existing auth posture must be confirmed and the `/health` auth gate honoured.
- Confirm Pulse.Collector's Container App probe configuration matches the ADR-0066 D5 defaults (or document the deliberate per-Node override). The Container App YAML is **not** in this repo — it's deployed via `HoneyDrunk.Actions`. This packet does NOT touch Container App YAML; that lands in packet 08 (per-Node infrastructure walkthroughs).

`HoneyDrunk.Pulse` is a live Node currently at v0.3.0 (per `CHANGELOG.md`). This packet is the only packet on the `HoneyDrunk.Pulse` solution in this initiative — per invariant 27 it bumps the whole solution to the next minor version (`0.3.0` → `0.4.0`; new feature, the Kernel-helper adoption changes the on-the-wire body shape of `/health` from `{ Status: "Healthy" }` to the IETF body, and the probe endpoints' body becomes empty — these are visible behaviour changes that warrant a minor bump). Confirm exact current version at execution time.

Pulse.Collector is the **first non-Kernel adopter** of `MapHoneyDrunkHealthEndpoints`. The Pulse.Collector amendment validates the Kernel helper end-to-end before Notify's larger amendment in packet 06 runs.

## Scope
- `Pulse.Collector/Endpoints/HealthEndpoints.cs` — replace hand-rolled `MapGet` calls with `MapHoneyDrunkHealthEndpoints`.
- Pulse.Collector host composition — register Pulse.Collector's contributors with their `ReadinessPolicy` values; confirm the host's auth scheme is wired so `/health` is auth-gated.
- Pulse.Collector unit/integration tests — assert the three endpoints respond per the ADR-0066 contract (probe endpoints empty body 200/503; `/health` IETF body, auth-required).
- Version bump across the `HoneyDrunk.Pulse` solution (invariant 27).
- Repo-level `CHANGELOG.md` new-version entry; per-package CHANGELOGs only for changed packages (Pulse.Collector is a deployable host, not a published NuGet package — confirm the per-package CHANGELOG policy for the deployable's project).

## Proposed Implementation
1. **Replace `HealthEndpoints.MapHealthEndpoints`.** Open `Pulse.Collector/Endpoints/HealthEndpoints.cs`. The current code maps three endpoints with hand-rolled `MapGet` calls. Replace the method body with `return endpoints.MapHoneyDrunkHealthEndpoints();` and remove the three hand-rolled mappings. The method name stays (downstream callers keep their call site). XML doc updated to reflect the Kernel delegation and the new behaviour.
2. **Host composition.** Pulse.Collector's `Program.cs` (or equivalent host file) wires DI. Confirm:
   - `NodeLifecycleHealthContributor` (Kernel) is registered — if not already, add it. Its `ReadinessPolicy` is `Required` (the default; the lifecycle stage is the canonical readiness signal).
   - Any Pulse-specific contributor (e.g. a `PulseExportContributor` if one exists today) is registered with `ReadinessPolicy.OptionalReported` per ADR-0066 D7 — Pulse export readiness is a credible "should I be in rotation" signal but Pulse.Collector itself should not fail readiness if its own export is degraded. State the chosen policy for each contributor in the PR.
   - The host's auth scheme is wired so `/health` is auth-gated. Pulse.Collector is **Studios-internal fleet infrastructure**, not tenant-bounded — per the invariant `{N2}` two-token model the scheme accepts a **Studios-internal token** (no tenant-admin path; tenants do not probe Pulse). Azure Monitor scrape credentials are accepted as a parallel scheme for fleet-wide observability scrapes. If Pulse.Collector currently has no auth scheme, this packet must add one — do not leave `/health` anonymous to ship faster.
3. **Tests.** Pulse.Collector has unit/integration tests (the existing `Pulse.Tests` project). Add or amend tests to:
   - `/health/live` returns `200` with empty body when the process is alive.
   - `/health/ready` returns `200` with empty body when all `Required` contributors are healthy; `503` with empty body when one is unhealthy.
   - `/health` returns the IETF `application/health+json` body (`status`, `version`, `releaseId`, `checks` shape) on an authenticated request.
   - `/health` returns `401` (or the host's configured denial response) on an unauthenticated request.
   - No `Thread.Sleep` (invariant 51).
4. **Versioning.** Bump every non-test `.csproj` in the `HoneyDrunk.Pulse` solution to the next minor version (`0.3.0` → `0.4.0`) in one commit (invariant 27). Repo-level `CHANGELOG.md` new `[0.4.0]` entry. Per-package CHANGELOGs: Pulse.Collector's deployable project gets an entry; library projects (Telemetry.*) that have no functional change in this packet get NO entry (invariant 12, 27).
5. **README.** Update Pulse.Collector's `README.md` if its health-endpoint section documents the wire shape — the shape has changed (probes are empty body; `/health` is IETF). If the README does not document the wire shape, no update required.

## Affected Files
- `Pulse.Collector/Endpoints/HealthEndpoints.cs`
- `Pulse.Collector/Program.cs` (or wherever host composition lives) — contributor registration with `ReadinessPolicy`; auth scheme wiring (if needed).
- `Pulse.Tests/` — endpoint tests.
- Every non-test `.csproj` in the solution — version bump.
- Repo-level `CHANGELOG.md`; per-package CHANGELOG for Pulse.Collector deployable.
- `Pulse.Collector/README.md` (only if it documents the wire shape).

## NuGet Dependencies
- **Pulse.Collector** — gains `HoneyDrunk.Kernel` `0.8.0` (provides `MapHoneyDrunkHealthEndpoints`). If Pulse.Collector already references `HoneyDrunk.Kernel`, update the version to `0.8.0`; otherwise add the reference.
- **Pulse.Collector** — gains `HoneyDrunk.Kernel.Abstractions` `0.8.0` (transitively, or explicit) for the `ReadinessPolicy` enum used in contributor registration.
- If a separate optional Functions-host package was introduced in packet 03 (per packet 03's package-split decision), Pulse.Collector does NOT need it — Pulse.Collector is an ASP.NET Core host, not a Functions host.
- `HoneyDrunk.Standards` is already on every project; no change.
- Pulse.Tests gains no new packages — uses the existing ADR-0047 test stack.
- Confirm exact current versions at execution time — packets 02 and 03 set them on the Kernel side.

## Boundary Check
- [x] All code change is in `HoneyDrunk.Pulse` — its own host endpoint file, host composition, and tests. Routing rule "telemetry, ... collector → HoneyDrunk.Pulse" maps here.
- [x] No contract change — Pulse.Collector consumes the ADR-0066 contracts as shipped by packets 02–03.
- [x] No Container App YAML change in this repo — the YAML lives in `HoneyDrunk.Actions` and is amended in packet 08.

## Acceptance Criteria
- [ ] `Pulse.Collector/Endpoints/HealthEndpoints.cs`'s `MapHealthEndpoints` delegates to `MapHoneyDrunkHealthEndpoints` from `HoneyDrunk.Kernel`; the three hand-rolled `MapGet` calls are removed
- [ ] Pulse.Collector's host composition registers `NodeLifecycleHealthContributor` with `ReadinessPolicy.Required`; any Pulse-specific contributor is registered with the policy stated in the PR (Pulse-export-style contributors should be `OptionalReported` per the ADR-0066 D7 rationale)
- [ ] Pulse.Collector's host has an auth scheme wired so `/health` is auth-gated; the wired scheme accepts the Studios-internal token (and optionally a parallel Azure Monitor scrape credential), pinned per the two-token posture for Studios-internal fleet infrastructure
- [ ] If wiring auth is non-trivial, a follow-up packet is filed and `/health` is NOT left anonymous on the assumption "we'll add auth later" — invariant `{N2}` is a hard rule
- [ ] `/health/live` returns `200` with empty body when alive; `503` with empty body only when the lifecycle stage is `Stopping`/`Stopped`
- [ ] `/health/ready` returns `200` with empty body when `Required` contributors are healthy; `503` with empty body when any `Required` contributor is unhealthy
- [ ] `/health` returns IETF `application/health+json` body matching the ADR-0066 D2 sample shape on an authenticated request
- [ ] `/health` returns `401` (or the host's configured denial) on an unauthenticated request
- [ ] Tests cover the four endpoint outcomes above and contain no `Thread.Sleep` (invariant 51)
- [ ] Every non-test `.csproj` in the `HoneyDrunk.Pulse` solution is at the same new minor version in one commit (`0.3.0` → `0.4.0`); confirm current version at execution time (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new `[0.4.0]` entry; Pulse.Collector deployable CHANGELOG entry; no noise entries for unchanged library packages
- [ ] `Pulse.Collector/README.md` updated if it documents the wire shape; otherwise no change
- [ ] `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Host auth scheme wired before adopting `MapHoneyDrunkHealthEndpoints`.** The Kernel helper calls `RequireAuthorization()` on `/health` without specifying a policy name — the host's default auth scheme is consulted. Pulse.Collector's host must already have an auth scheme registered (Studios-internal token, Azure Monitor scrape credential, or other) before this packet adopts the helper. **The Kernel helper ships no no-throw fallback**; absence of a scheme is a host configuration error, not a runtime fallback to anonymous. If Pulse.Collector has no auth scheme today, this packet's first step is to wire one — and that wiring is what's documented in the PR. Do NOT ship this packet with `/health` anonymous on the assumption "we'll add auth later." Invariant `{N2}` is a hard rule.
- [ ] **Publish the upstream Kernel NuGet packages before this packet can compile.** This packet references `HoneyDrunk.Kernel` / `HoneyDrunk.Kernel.Abstractions` `0.8.0` (packets 02 + 03). Those artifacts exist on the package feed only after a human pushes a git release tag on `HoneyDrunk.Kernel` — agents never tag or publish. Before this Wave-4 packet starts: at the Wave 2→3 boundary tag/release `HoneyDrunk.Kernel.Abstractions` `0.8.0` from packet 02; at the Wave 3→4 boundary tag/release `HoneyDrunk.Kernel` `0.8.0` carrying the runtime types from packet 03. (Practically: a single `0.8.0` Kernel release after both packets 02 and 03 have merged satisfies both.)
- [ ] **Confirm the deploy-workflow readiness gate.** The Pulse.Collector deploy workflow currently probes `/health` (per ADR-0066 Context). Once this packet lands and `/health` becomes auth-required, an unauthenticated probe will return `401`, breaking the deploy gate. Packet 10 amends the deploy workflow to probe `/health/ready` (unauthenticated) instead. Until packet 10 lands, Pulse.Collector's deploy gate may need a temporary credential, a temporary fallback to `/health/live`, or a temporary skip of the gate. Coordinate the sequencing of packets 05 and 10 in deploy windows — both can be merged independently, but Pulse.Collector deploys should not roll until packet 10's workflow change is also live in the deploy environment.

## Referenced ADR Decisions
**ADR-0066 D1 — Three endpoints.** `/health/live`, `/health/ready`, `/health` — uniformly mapped via `MapHoneyDrunkHealthEndpoints`.

**ADR-0066 D2 — Response shape.** Probes return empty body with `200`/`503`. `/health` returns IETF `application/health+json`. Pulse.Collector's current `{ Status: "Healthy" }` body is replaced by these contract shapes.

**ADR-0066 D6 — Auth posture.** Probe endpoints anonymous; `/health` auth-required. Pulse.Collector's host configures the auth scheme.

**ADR-0066 D7 — `ReadinessPolicy`.** Pulse.Collector's contributors are registered with explicit `ReadinessPolicy` values. Pulse-export-style contributors are good candidates for `OptionalReported` — degraded export should not pull Pulse.Collector out of traffic rotation.

**ADR-0066 D9 — Implementation home.** "Pulse.Collector's existing static endpoints are amended to call into the Kernel helpers in a follow-up amendment." This is that amendment.

**ADR-0066 Operational Consequences — "The Pulse.Collector amendment is a strict simplification."** The hand-rolled static responders disappear; the Kernel helper takes over. Net code reduction.

## Constraints
- **Invariant 4 — DAG.** Pulse depends on Kernel; no inversion.
- **Invariant 9 — Vault is the only source of secrets.** Any auth credential `/health` requires (e.g. the Studios-internal token) resolves via `ISecretStore`.
- **Invariant 13 — XML documentation on public types.**
- **Invariant 27 — one version across the solution.** Bump every non-test `.csproj` together; per-package CHANGELOGs only for changed packages.
- **Invariant 51 — no `Thread.Sleep` in test code.**
- **Invariant `{N2}` — `/health/live` and `/health/ready` anonymous; `/health` auth-required.** Hard rule; do not ship Pulse.Collector with `/health` anonymous on the assumption of a follow-up.
- **Invariant `{N3}` — contributor messages free of secrets/connection strings/tenant identifiers/provider opaque IDs.** Audit any new Pulse contributor `output` strings before they ship.
- **Do NOT touch Container App YAML.** That lives in `HoneyDrunk.Actions` and is amended in packet 08; this packet stays within the Pulse repo.

## Labels
`feature`, `tier-2`, `ops`, `adr-0066`, `wave-4`

## Agent Handoff

**Objective:** Amend `HoneyDrunk.Pulse.Collector` to use `MapHoneyDrunkHealthEndpoints` from Kernel, register its contributors with explicit `ReadinessPolicy` values, and wire host auth so `/health` is auth-gated.

**Target:** `HoneyDrunk.Pulse`, branch from `main`.

**Context:**
- Goal: End Pulse.Collector's static placeholder endpoints — bring it onto the Grid-wide contract with a strict simplification.
- Feature: ADR-0066 Health, Readiness, and Liveness Endpoint Contract rollout, Wave 4 (parallel with packet 06 Notify amendment).
- ADRs: ADR-0066 D1/D2/D6/D7/D9 (primary), ADR-0008 (packet conventions), ADR-0015 (Container Apps context — but no YAML change in this packet).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` — `MapHoneyDrunkHealthEndpoints` ships in `HoneyDrunk.Kernel` `0.8.0`.

**Constraints:**
- The hand-rolled `MapGet` calls are removed; delegation to the Kernel helper is the entire endpoint mapping.
- `/health` must be auth-gated before this packet ships (invariant `{N2}`).
- Container App YAML is NOT touched here — packet 08 owns probe configuration; packet 10 owns the deploy-workflow readiness-gate switch.
- Bump the whole `HoneyDrunk.Pulse` solution one minor version (invariant 27).

**Key Files:**
- `Pulse.Collector/Endpoints/HealthEndpoints.cs`
- `Pulse.Collector/Program.cs` (or equivalent host composition file)
- `Pulse.Tests/` (endpoint tests)
- Every non-test `.csproj`; repo-level `CHANGELOG.md`.

**Contracts:** None changed — Pulse.Collector consumes `MapHoneyDrunkHealthEndpoints`, `ReadinessPolicy`, `IHealthContributor` as shipped by packets 02–03.
