---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0055", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0055"]
accepts: ["ADR-0055"]
wave: 1
initiative: adr-0055-feature-flags
node: honeydrunk-architecture
---

# Register the IFeatureGate contracts and the new HoneyDrunk.FeatureFlags Node in the Grid catalogs

## Summary
Record ADR-0055's new contract surface and the new Node `HoneyDrunk.FeatureFlags` as catalog data: register `IFeatureGate`, `ITargetingContext`, and `InMemoryFeatureGate` under the `honeydrunk-kernel` Node in `catalogs/contracts.json`; add the new Node entry `honeydrunk-featureflags` to `catalogs/nodes.json` and `catalogs/grid-health.json`; add the new Node and its dependency on `HoneyDrunk.Kernel.Abstractions` to `catalogs/relationships.json` (`exposes.contracts` for the FeatureFlags Node, `consumes_detail` enrichment for downstream Notes); append the new type names to the `honeydrunk-kernel` entry's `exposes.contracts` array.

## Context
ADR-0055 D4 adds new contracts to `HoneyDrunk.Kernel.Abstractions` — `IFeatureGate`, `ITargetingContext`, and the supporting variant/feature types — and a test fixture (`InMemoryFeatureGate`) in `HoneyDrunk.Kernel.Abstractions.Testing` per invariant 15. ADR-0055 D4 also stands up a **new Node `HoneyDrunk.FeatureFlags`** for the concrete `Microsoft.FeatureManagement.AzureAppConfiguration`-backed implementation and the `TenantTargetingFilter` (D3).

The Grid catalogs are the discoverability surface:
- `catalogs/nodes.json` lists every Node with descriptive metadata; `honeydrunk-featureflags` does not yet exist there.
- `catalogs/grid-health.json` tracks per-Node release state (`signal`, `version`, `canary_status`, `last_release`, `active_blockers`).
- `catalogs/contracts.json` registers each Node's contracts in its node block's `interfaces` array.
- `catalogs/relationships.json` lists each Node's contract names under `exposes.contracts` and per-Node dependency `consumes_detail`.

This packet keeps all four catalogs accurate so packets 04–09 read a correct graph. The Cosmos analogue from ADR-0042 packet 01 (records the Kernel contract surface; backing-package registration lives in the backing packet) is followed here: this packet records the **contract** surface in `honeydrunk-kernel` and the **new Node entry** for `honeydrunk-featureflags`. Packet 05 (the FeatureFlags Node standup) will fill in the concrete package list under `honeydrunk-featureflags` and its `exposes.contracts` once the package names are settled.

This is a catalog/docs packet. No code, no .NET project.

## Scope
- `catalogs/nodes.json` — add the new Node entry `honeydrunk-featureflags`, matching the existing Node-entry shape (id/type/name/public_name/short/description/sector/signal/cluster/energy/priority/flow/tags/links/long_description). nodes.json has **no** `exposes` field; do not invent one.
- `catalogs/grid-health.json` — add the per-Node release-state entry for `honeydrunk-featureflags` (signal `Seed`, version `0.0.0`, canary_status `none`, last_release `null`, active_blockers `["Repo not yet scaffolded — standup in packet 05"]`).
- `catalogs/contracts.json` — locate the node block whose `node` value is `honeydrunk-kernel`; append the new contract entries from ADR-0055 D4 to that block's `interfaces` array.
- `catalogs/relationships.json` — append the new type names to the `honeydrunk-kernel` entry's `exposes.contracts` array; add a new top-level entry for `honeydrunk-featureflags` listing its dependency on `honeydrunk-kernel` (via `HoneyDrunk.Kernel.Abstractions`); for each Node that will consume `IFeatureGate` in this initiative (Notify per packet 07; Operator per packet 08), add `honeydrunk-featureflags` to the Node's `consumes` array and populate `consumes_detail["honeydrunk-featureflags"]`. For Operator specifically (packet 08 also consumes the Audit substrate and the App Configuration management SDK), also add `honeydrunk-audit` to the `consumes` array and populate `consumes_detail["honeydrunk-audit"]`.

- **Stale `IAuditLog` on `honeydrunk-operator` (out-of-scope cleanup, noted here).** `catalogs/relationships.json` still lists `IAuditLog` under `honeydrunk-operator`'s `exposes.contracts` (line ~328 at scoping). ADR-0030 already relocated `IAuditLog` to the `honeydrunk-audit` Node (and `catalogs/contracts.json` reflects that — its `honeydrunk-operator` block carries a "RELOCATED" note). This drift is **out of scope for this packet** — fixing it would mix ADR-0030 cleanup with ADR-0055 work. File a follow-up packet against ADR-0030 (or amend the `adr-0030-audit` initiative if it is still in flight) to remove `IAuditLog` from `honeydrunk-operator`'s `exposes.contracts` array. This packet's Operator edits only add new entries to `consumes` / `consumes_detail`; do not touch `honeydrunk-operator.exposes.contracts`.

## Proposed Implementation
1. **`catalogs/nodes.json`** — append a new Node entry for `honeydrunk-featureflags`. Use the existing pattern (see `honeydrunk-vault-rotation` or `honeydrunk-audit` as the closest precedents for a small Core-sector Node):
   - `id: "honeydrunk-featureflags"`, `type: "node"`, `name: "HoneyDrunk.FeatureFlags"`, `public_name: "HoneyDrunk.FeatureFlags"`.
   - `short`: "Feature-flag and progressive-rollout substrate."
   - `description`: "Grid-wide feature-flag substrate backed by Azure App Configuration's feature-flag surface. Implements `IFeatureGate` from `HoneyDrunk.Kernel.Abstractions` with the `Microsoft.FeatureManagement.AzureAppConfiguration` library and a custom `TenantTargetingFilter` for per-tenant and per-tier targeting. Backend is swappable per ADR-0055 D15 (LaunchDarkly or GrowthBook escalation triggers)."
   - `sector: "Core"`, `signal: "Seed"`, `cluster` (pick a coherent one — likely `platform` or `governance` — match the closest precedent), `energy: 0`, `priority` (match similar-priority Core Nodes), `flow: 0`.
   - `tags`: `["feature-flags", "progressive-rollout", "app-configuration", "release-flags", "permission-flags", "operational-flags", "targeting"]`.
   - `links.repo`: `"https://github.com/HoneyDrunkStudios/HoneyDrunk.FeatureFlags"`.
   - `long_description`: overview, why_it_exists ("Trunk-based dev (ADR-0053) requires application-level flags; per-tenant entitlement requires runtime targeting; operational kill-switches require runtime control — App Configuration's feature-flag surface delivers all three with no new vendor relationship."), primary_audience ("Every Node consuming `IFeatureGate`; the operator via the `operator flags …` CLI."), value_props (D1 categories, D3 targeting, D9 dev-on inversion, D15 backend reversibility).
2. **`catalogs/grid-health.json`** — append a new entry for `honeydrunk-featureflags`:
   ```json
   {
     "id": "honeydrunk-featureflags",
     "name": "HoneyDrunk.FeatureFlags",
     "sector": "Core",
     "signal": "Seed",
     "version": "0.0.0",
     "canary_status": "none",
     "last_release": null,
     "active_blockers": ["Repo not yet scaffolded — standup in packet 05 of adr-0055-feature-flags initiative"],
     "notes": "ADR-0055 Phase 1 Node. App-Configuration-backed `IFeatureGate` + `TenantTargetingFilter`. Standup landing via the adr-0055-feature-flags initiative."
   }
   ```
3. **`catalogs/contracts.json`** — locate the node block whose `node` value is `honeydrunk-kernel` (do not rely on line numbers). Append entries to that block's `interfaces` array, matching the existing `{ "name", "kind", "description" }` shape:
   - `IFeatureGate` — `kind: interface` — "Grid-wide feature-flag evaluation surface. `IsEnabledAsync(name)` for binary flags, `IsEnabledAsync(name, context)` for explicit targeting context (off-request paths), `GetVariantAsync<T>(name, default)` for named-variant evaluation. The only sanctioned surface for flag evaluation — direct SDK consumption is forbidden per ADR-0055 invariant."
   - `ITargetingContext` — `kind: interface` — "Targeting context for `IFeatureGate` evaluation. Carries `TenantId`, `PrincipalId`, `Tier`, plus a `Tags` dictionary for future targeting filters. Populated from `RequestContext` (per ADR-0026) by the default DI registration; constructed explicitly only for off-request paths."
   - `InMemoryFeatureGate` — `kind: type` — "In-memory `IFeatureGate` test fixture in `HoneyDrunk.Kernel.Abstractions.Testing` (per invariant 15). Lets any Node's unit tests flip flags without depending on App Configuration. Ships with `SetFlag(name, enabled: bool)` / `SetVariant(name, value)` setup methods."
   - Drop the leading `I` from record/type names per the Grid naming rule; interfaces keep the `I`. `InMemoryFeatureGate` is a class — no `I`.
4. **`catalogs/relationships.json`** — three edits:
   a. Append `IFeatureGate`, `ITargetingContext`, `InMemoryFeatureGate` to the `honeydrunk-kernel` entry's `exposes.contracts` array. Do not touch existing entries.
   b. Add a new top-level entry for `honeydrunk-featureflags`:
      - `consumes_detail`: `{ "honeydrunk-kernel": ["IFeatureGate", "ITargetingContext"] }` (FeatureFlags implements `IFeatureGate` from Kernel.Abstractions).
      - `exposes.contracts`: placeholder — packet 05 fills in the concrete package contract names (`TenantTargetingFilter` is a type, not a public interface; the `HoneyDrunk.FeatureFlags` package exposes `AddFeatureFlags` DI extension). Record what is known now and leave a `TODO` comment if needed; packet 05 will finalize.
   c. For `honeydrunk-notify` and `honeydrunk-operator`, extend the `consumes_detail["honeydrunk-kernel"]` array with `IFeatureGate` and `ITargetingContext` (the contract surface they consume from Kernel).
   d. For `honeydrunk-notify` (packet 07): add `"honeydrunk-featureflags"` to its `consumes` array; populate `consumes_detail["honeydrunk-featureflags"]` with `["HoneyDrunk.FeatureFlags", "AddFeatureFlags"]` (the composition extension that wires the App-Configuration-backed `IFeatureGate` into Notify's host).
   e. For `honeydrunk-operator` (packet 08): add `"honeydrunk-featureflags"` and `"honeydrunk-audit"` to its `consumes` array; populate `consumes_detail["honeydrunk-featureflags"]` with `["HoneyDrunk.FeatureFlags", "AddFeatureFlags"]`; populate `consumes_detail["honeydrunk-audit"]` with `["IAuditLog", "AuditEntry", "HoneyDrunk.Audit.Abstractions"]` (permission/operational flip events flow through `IAuditLog` per ADR-0055 D10 / ADR-0030). The Operator CLI's App Configuration management SDK consumption (`Azure.Data.AppConfiguration`, `Azure.ResourceManager.AppConfiguration`) is a third-party NuGet — it does not appear in `relationships.json` (which tracks HoneyDrunk-Node-to-Node edges only); the SDK consumption is captured in packet 08's NuGet Dependencies section.
   f. **Out-of-scope drift, do NOT fix here.** Do not edit `honeydrunk-operator.exposes.contracts` — the stale `IAuditLog` entry there is ADR-0030 cleanup, deferred to a follow-up packet (see Scope note above). This packet only adds to `consumes` / `consumes_detail` for Notify and Operator; it does not touch their `exposes` arrays.

## Affected Files
- `catalogs/nodes.json` — new Node entry.
- `catalogs/grid-health.json` — new release-state entry.
- `catalogs/contracts.json` — new contract entries under `honeydrunk-kernel`.
- `catalogs/relationships.json` — new Node edge + `exposes.contracts` + `consumes_detail` enrichment.

## NuGet Dependencies
None. This packet touches only catalog JSON; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Catalog data only — the Kernel/FeatureFlags/Actions/Notify/Operator code lands in packets 04–08.

## Acceptance Criteria
- [ ] `catalogs/nodes.json` contains a new `honeydrunk-featureflags` Node entry matching the existing Node-entry shape, sector Core, signal Seed
- [ ] `catalogs/grid-health.json` contains a new `honeydrunk-featureflags` release-state entry, signal Seed, version `0.0.0`, blockers listing the standup as scheduled in packet 05
- [ ] `catalogs/contracts.json` registers `IFeatureGate`, `ITargetingContext`, `InMemoryFeatureGate` in the `honeydrunk-kernel` node block's `interfaces` array, matching the existing entry shape
- [ ] `catalogs/relationships.json` `honeydrunk-kernel` `exposes.contracts` lists the three new type names, with all existing entries untouched
- [ ] `catalogs/relationships.json` has a new top-level entry for `honeydrunk-featureflags` with `consumes_detail["honeydrunk-kernel"]` including `IFeatureGate` and `ITargetingContext`
- [ ] `catalogs/relationships.json` `consumes_detail["honeydrunk-kernel"]` for `honeydrunk-notify` and `honeydrunk-operator` lists the new Kernel contracts (`IFeatureGate`, `ITargetingContext`) they will consume
- [ ] `catalogs/relationships.json` `honeydrunk-notify.consumes` contains `"honeydrunk-featureflags"`, and `consumes_detail["honeydrunk-featureflags"]` is populated with `["HoneyDrunk.FeatureFlags", "AddFeatureFlags"]`
- [ ] `catalogs/relationships.json` `honeydrunk-operator.consumes` contains both `"honeydrunk-featureflags"` and `"honeydrunk-audit"`, and `consumes_detail["honeydrunk-featureflags"]` and `consumes_detail["honeydrunk-audit"]` are populated (the audit detail lists `IAuditLog`, `AuditEntry`, and the `HoneyDrunk.Audit.Abstractions` package)
- [ ] `honeydrunk-operator.exposes.contracts` is NOT modified in this packet — the stale `IAuditLog` entry there is out-of-scope ADR-0030 cleanup (see Scope)
- [ ] All four catalog JSON files parse as valid JSON (no trailing commas, no merge conflicts, no broken arrays)
- [ ] No invariant change in this packet (invariants land in packet 00)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0055 D4 — `IFeatureGate` in Kernel.Abstractions; concrete in `HoneyDrunk.FeatureFlags`.** `IFeatureGate` and `ITargetingContext` live in `HoneyDrunk.Kernel.Abstractions`; `InMemoryFeatureGate` lives in `HoneyDrunk.Kernel.Abstractions.Testing` per invariant 15. Concrete `Microsoft.FeatureManagement.AzureAppConfiguration`-backed implementation lives in the new Node `HoneyDrunk.FeatureFlags` so the backend can be swapped (D15 escalation) without touching Kernel.

**ADR-0055 D3 — `TenantTargetingFilter` ships in `HoneyDrunk.FeatureFlags`.** A custom `IFeatureFilter` reading `RequestContext.TenantId` / `RequestContext.TenantTier` (per ADR-0026), matching against the flag's `tenants:` or `tiers:` configuration, falling back to a default rollout percentage. The only custom filter the Grid commits to at v1.

**ADR-0055 D14 Phase 1 — `HoneyDrunk.FeatureFlags` Node standup.** "Stand up the `HoneyDrunk.FeatureFlags` Node with the `Microsoft.FeatureManagement.AzureAppConfiguration`-backed implementation, the `TenantTargetingFilter`, and the App Configuration label conventions per D9."

**ADR-0055 Consequences — Affected Nodes.** "`HoneyDrunk.FeatureFlags` — new Node, standup governed by this ADR. Holds the `Microsoft.FeatureManagement.AzureAppConfiguration`-backed `IFeatureGate` implementation and the `TenantTargetingFilter`. Sector: Core." `catalogs/nodes.json` gains the new entry; `catalogs/contracts.json` gains `IFeatureGate` under the Kernel-published contracts.

## Constraints
- **Records drop the `I`, interfaces keep it.** Grid-wide naming rule. `IFeatureGate`, `ITargetingContext` are interfaces. `InMemoryFeatureGate` is a class — no `I`. No records ship in this contract set (`Feature` and `Variant` types are deferred to packet 04 if needed for the API surface; if records ship, they drop the `I`).
- **nodes.json has no `exposes` field.** The contract surface lives in `relationships.json` and `contracts.json`. Do not invent an `exposes` field on the new nodes.json entry.
- **Do not register the FeatureFlags package list yet.** Packet 05 (the Node standup) ships and registers the concrete package names (`HoneyDrunk.FeatureFlags`, `HoneyDrunk.FeatureFlags.Abstractions` if it splits, etc.). This packet records only what is known: the contract surface in `honeydrunk-kernel` and the new Node entry as Seed.
- **JSON hygiene.** All four catalog files must parse as valid JSON after the edits. Pay attention to comma placement at the tail of arrays.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0055`, `wave-1`

## Agent Handoff

**Objective:** Register ADR-0055's `IFeatureGate` contract surface and the new `HoneyDrunk.FeatureFlags` Node in the Grid catalogs.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Keep the contract/dependency catalogs accurate so implementation packets 04–08 read a correct graph.
- Feature: ADR-0055 Feature Flag rollout, Wave 1.
- ADRs: ADR-0055 D3/D4/D14 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0055 should be Accepted before its contract surface is recorded as catalog data.

**Constraints:**
- Records drop the `I`; interfaces keep it; `InMemoryFeatureGate` is a class.
- nodes.json has no `exposes` field — do not invent one.
- Do not register the FeatureFlags package list yet — packet 05 owns that.
- All four catalog JSON files must parse as valid JSON after edits.

**Key Files:**
- `catalogs/nodes.json` — new `honeydrunk-featureflags` Node entry.
- `catalogs/grid-health.json` — new `honeydrunk-featureflags` release-state entry.
- `catalogs/contracts.json` — new entries in the `honeydrunk-kernel` block's `interfaces` array.
- `catalogs/relationships.json` — `honeydrunk-kernel` `exposes.contracts`; new `honeydrunk-featureflags` entry; `honeydrunk-notify` gains `"honeydrunk-featureflags"` in `consumes` + a `consumes_detail["honeydrunk-featureflags"]` array + `IFeatureGate`/`ITargetingContext` added to `consumes_detail["honeydrunk-kernel"]`; `honeydrunk-operator` gains `"honeydrunk-featureflags"` and `"honeydrunk-audit"` in `consumes` + matching `consumes_detail` arrays + the Kernel contracts. **Do not modify `honeydrunk-operator.exposes.contracts` here — the stale `IAuditLog` is ADR-0030 cleanup, deferred.**

**Contracts:** None changed — this packet only records catalog metadata for contracts that packet 04 implements.
