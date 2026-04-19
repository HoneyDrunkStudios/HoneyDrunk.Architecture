---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Observe
labels: ["feature", "tier-3", "ops", "new-node", "scaffolding", "adr-0010", "wave-2"]
dependencies: ["01-architecture-adr-0010-acceptance.md", "02-architecture-create-observe-repo.md"]
adrs: ["ADR-0010"]
wave: 2
initiative: adr-0010-observe-ai-routing-phase-1
node: honeydrunk-observe
---

# Feature: Scaffold `HoneyDrunk.Observe` repo, solution, and Abstractions package with Phase 1 contracts

## Summary
Stand up the `HoneyDrunk.Observe` repo with the Grid's standard solution structure and ship the first package — `HoneyDrunk.Observe.Abstractions` — containing the three Phase 1 observation contracts (`IObservationTarget`, `IObservationConnector`, `IObservationEvent`). Runtime package, connector packages, and live connector implementations are out of scope for this packet; Phase 2 covers the first connector.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Observe` (new, created by the paired human-only chore)

## Motivation
Phase 1 of the Observation Layer is defined as "Contracts and Stubs — Scope now." The Architecture repo has registered the Node in catalogs, but no code yet exists. This packet produces the repo scaffold and the Abstractions package so downstream Phase 2 work (first connector, normalization runtime) has a published contract surface to build against.

## Scope

### Repo scaffold

Create the standard Grid repo layout:

- `HoneyDrunk.Observe.slnx` at repo root
- `src/HoneyDrunk.Observe.Abstractions/` — contracts package project
- `tests/` — empty directory ready for future `.Tests` / `.Canary` projects (invariant 16)
- `.editorconfig` and `Directory.Build.props` matching the `HoneyDrunk.Vault` template
- `README.md` at repo root — one-paragraph purpose, packages list, repo status (Seed), link to the canonical Node entry in the public catalog. Do not embed ADR IDs in the narrative text.
- `CHANGELOG.md` at repo root (next to `.slnx`) — initial `0.1.0` entry describing the scaffold (invariant 12)
- `.github/workflows/` — at minimum `pr-core.yml` consumption from `HoneyDrunk.Actions` (call the reusable workflow); additional scan workflows may be deferred to a follow-up packet

### `HoneyDrunk.Observe.Abstractions` package

Create the contracts package with zero runtime dependencies on other HoneyDrunk packages (invariant 1). Permitted references:
- `Microsoft.Extensions.*` abstractions only (if needed for DI option types — likely not needed for pure contracts)

Define three interfaces with full XML documentation (invariant 13):

- **`IObservationTarget`** — Declares an external system to be observed. Carries an identity, a connector selector (the connector type to use), and a credential reference (the Vault secret name to resolve at connection time — the interface must NOT carry a raw credential). Suggested members: `TargetId`, `ConnectorKind`, `CredentialSecretName`, `DisplayName`, an extensibility bag for per-connector config.
- **`IObservationConnector`** — Provider-slot interface. Connector implementations (future Phase 2 packages) intake external events and translate to normalized observation events. Suggested members: `ConnectorKind` identifier, async `ConnectAsync(IObservationTarget target, CancellationToken ct)`, async enumerable / event-stream surface for incoming normalized events, `DisconnectAsync`.
- **`IObservationEvent`** — Canonical observation event. Suggested members: `EventId`, `TargetId`, `ObservedAt` (UTC timestamp), `Kind` (health, state-change, alert — enum or stringly-typed), `Severity`, `Payload` (normalized dictionary), `SourceConnector` (kind name).

Exact member shapes are at the executor's discretion — the constraint is: zero runtime HoneyDrunk dependencies, full XML docs, and the interfaces reflect the boundaries ADR-0010 draws.

Package contents:
- `src/HoneyDrunk.Observe.Abstractions/HoneyDrunk.Observe.Abstractions.csproj`
- `src/HoneyDrunk.Observe.Abstractions/IObservationTarget.cs`
- `src/HoneyDrunk.Observe.Abstractions/IObservationConnector.cs`
- `src/HoneyDrunk.Observe.Abstractions/IObservationEvent.cs`
- `src/HoneyDrunk.Observe.Abstractions/README.md`
- `src/HoneyDrunk.Observe.Abstractions/CHANGELOG.md`

## Acceptance Criteria

- [ ] `HoneyDrunk.Observe.slnx` exists at the repo root and includes the Abstractions project
- [ ] `src/HoneyDrunk.Observe.Abstractions/` project created targeting .NET 10.0
- [ ] Project references `HoneyDrunk.Standards` with `PrivateAssets="all"` (StyleCop + EditorConfig analyzers)
- [ ] Zero runtime HoneyDrunk package references on the Abstractions project (invariant 1)
- [ ] Three interfaces (`IObservationTarget`, `IObservationConnector`, `IObservationEvent`) defined with full XML documentation (invariant 13)
- [ ] Repo-level `README.md` describes the Node's purpose and lists planned packages (Abstractions shipped; runtime + connectors planned)
- [ ] Repo-level `CHANGELOG.md` created with `0.1.0` initial entry at the solution level (invariant 12, 27)
- [ ] Per-package `README.md` and `CHANGELOG.md` present in `src/HoneyDrunk.Observe.Abstractions/` (invariant 12)
- [ ] `.github/workflows/pr-core.yml` present, consuming the reusable workflow from `HoneyDrunk.Actions`
- [ ] `tests/` directory exists as a placeholder (invariant 16 — no test code in runtime packages)
- [ ] `HoneyDrunkStudios/HoneyDrunk.Observe` PR traverses the tier-1 gate (build, analyzers, unit tests if any, vuln scan, secret scan) before merge
- [ ] PR body links back to this packet

## NuGet Dependencies

`src/HoneyDrunk.Observe.Abstractions/HoneyDrunk.Observe.Abstractions.csproj`:
- `<PackageReference Include="HoneyDrunk.Standards" Version="..." PrivateAssets="all" />` — StyleCop + EditorConfig analyzers (required on every new .NET project per invariant 26)
- No other package references required for Phase 1 contracts. If the executor finds DI option types are needed, adding `Microsoft.Extensions.Options.ConfigurationExtensions` is permitted (Abstractions invariant permits `Microsoft.Extensions.*`).

## Affected Packages
New: `HoneyDrunk.Observe.Abstractions`

## Boundary Check
- [x] Work belongs in `HoneyDrunk.Observe` — a newly-created Node whose catalog registration was completed by packet 01
- [x] Abstractions-only; no runtime, no connector implementations, no Vault calls — those come in Phase 2 per ADR-0010
- [x] Contracts stay within the Observe boundary — no cross-repo types introduced

## Human Prerequisites
- [ ] `HoneyDrunkStudios/HoneyDrunk.Observe` repo must exist (created by the paired `02-architecture-create-observe-repo.md` chore)
- [ ] `HoneyDrunk.Standards` NuGet package must be resolvable by the target repo's CI (it is — every Grid repo references it)

## Dependencies
- `01-architecture-adr-0010-acceptance.md` — catalog registration and repo context folder must exist before the scaffold is filed (the scaffold PR's review agent reads the Architecture context)
- `02-architecture-create-observe-repo.md` — target repo must exist on GitHub

## Downstream Unblocks
- Phase 2 packets (future): Observe runtime package, `HoneyDrunk.Observe.Connectors.GitHub` first-increment connector, cost-first routing policy wiring

## Referenced ADR Decisions

**ADR-0010 (Observation Layer and AI Routing):**
- **§Layer 1 / New Node:** `HoneyDrunk.Observe` owns both observation contracts and per-system connector packages. Single repo, provider-slot pattern (same as Vault and Transport). First-wave connector slots: GitHub, Azure, HTTP — but those are Phase 2, not this packet.
- **§Package families:** `HoneyDrunk.Observe.Abstractions` (contracts + observation-state model), `HoneyDrunk.Observe` (runtime, Phase 2), `HoneyDrunk.Observe.Connectors.*` (per-external-system packages, Phase 2).
- **§Owns:** Observation contracts and state model; event normalization (Phase 2 runtime); observation state; connector implementations (Phase 2 per-connector).
- **§Does NOT own:** Outbound telemetry (Pulse), plan adjustments (HoneyHub when live), internal Grid telemetry (Pulse), routing observations to HoneyHub (integration point, not a connector concern).
- **§Sector:** Ops.
- **§Phase 1 — Contracts and Stubs:** "Define `IObservationTarget`, `IObservationConnector`, `IObservationEvent` in `HoneyDrunk.Observe.Abstractions`." That is exactly the scope of this packet.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only Microsoft.Extensions.* abstractions are permitted.

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Repo-level CHANGELOG.md (next to the .slnx file) is mandatory; every version that ships must have an entry. Every package directory must contain a README.md. New projects must have both files from the first commit.

> **Invariant 13:** All public APIs have XML documentation. Enforced by HoneyDrunk.Standards analyzers.

> **Invariant 16:** No test code in runtime packages. Tests live in dedicated .Tests or .Canary projects only.

> **Invariant 26:** Issue packets for .NET code work must include an explicit NuGet Dependencies section. HoneyDrunk.Standards must be explicitly listed on every new .NET project (StyleCop + EditorConfig analyzers, PrivateAssets: all).

> **Invariant 27:** All projects in a solution share one version and move together. First packet to land on a solution in an initiative bumps the version; subsequent packets on the same solution append to the CHANGELOG only. The repo-level CHANGELOG.md must always get an entry for the new version.

> **Invariant 29:** Observation connectors must delegate credential resolution to Vault. No connector stores credentials directly. Connection secrets (webhook secrets, API tokens for external services) are resolved via ISecretStore at connection establishment. *(No Vault integration in this packet — connectors are Phase 2 — but the `IObservationTarget` interface must carry a credential **reference** [Vault secret name], never a raw credential, so Phase 2 connectors can honor this invariant.)*

> **Invariant 30:** HoneyDrunk.Observe events must be normalized to the canonical observation format before routing out of the Observe boundary. Raw external formats (GitHub webhook JSON, Azure alert schema) never cross the Observe boundary — only normalized IObservationEvent types. *(This packet defines that canonical format — `IObservationEvent` — so Phase 2 connectors have a normalization target.)*

## Constraints

- **Zero runtime HoneyDrunk dependencies on Abstractions** (invariant 1). No reference to Kernel, Vault, or any other Grid package — contracts stand alone.
- **`IObservationTarget` carries a credential reference, not a credential.** The interface must expose something like `CredentialSecretName` (the Vault secret name to resolve) — never `ApiKey`, `Password`, `Token`, or similar raw-credential shapes. This preserves invariant 29 at the contract level.
- **`IObservationEvent` is the normalization target.** Design it with enough fidelity (event kind, severity, payload, source connector identity, observed-at timestamp) that a Phase 2 GitHub connector can map a webhook to a single `IObservationEvent` without losing critical info.
- **Do not scaffold runtime or connector packages in this packet.** Only Abstractions. Phase 2 adds runtime and first connector. Scope creep here makes the PR reviewable only as a giant-bang change.
- **No ADR IDs in README narrative** (user preference). ADR IDs belong in frontmatter and CHANGELOG entries, not prose body text.
- **HoneyDrunk.Standards on every new project** (invariant 26). This is non-negotiable — CI fails without it.
- **Version starts at `0.1.0`, not `1.0.0`.** Seed-tier Nodes start pre-1.0. `CHANGELOG.md` entry is "Added — Initial scaffold; HoneyDrunk.Observe.Abstractions package with IObservationTarget, IObservationConnector, IObservationEvent contracts."

## Labels
`feature`, `tier-3`, `ops`, `new-node`, `scaffolding`, `adr-0010`, `wave-2`

## Agent Handoff

**Objective:** Scaffold `HoneyDrunk.Observe` with the Phase 1 Abstractions package and its three contracts, following Grid conventions (invariants 1, 11–13, 16, 26, 27) and the credential-reference pattern required by invariant 29.

**Target:** HoneyDrunk.Observe, branch from `main`

**Context:**
- Goal: Ship the first package for the new Observation Layer Node, exposing contracts that Phase 2 connectors will implement
- Feature: ADR-0010 Phase 1 — Contracts and Stubs
- ADRs: ADR-0010 (primary — defines the contracts and provider-slot pattern)

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `01-architecture-adr-0010-acceptance.md` (merged) — catalog entries and repo context folder exist
- `02-architecture-create-observe-repo.md` (closed) — target repo exists on GitHub

**Constraints:**

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only Microsoft.Extensions.* abstractions are permitted.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Every package directory must contain a README.md. New projects must have both files from the first commit.

> **Invariant 13:** All public APIs have XML documentation.

> **Invariant 26:** HoneyDrunk.Standards must be explicitly listed on every new .NET project (PrivateAssets: all).

> **Invariant 27:** The first packet to land on a solution in an initiative bumps the version. Starting version is `0.1.0`.

> **Invariant 29:** The `IObservationTarget` interface must expose a credential **reference** (Vault secret name), never a raw credential.

> **Invariant 30:** The `IObservationEvent` contract is the canonical normalization target that future connectors map to.

- No runtime, no connector packages — Abstractions only
- No ADR IDs in README prose body

**Key Files:**
- `HoneyDrunk.Observe.slnx` (new)
- `src/HoneyDrunk.Observe.Abstractions/HoneyDrunk.Observe.Abstractions.csproj` (new)
- `src/HoneyDrunk.Observe.Abstractions/IObservationTarget.cs` (new)
- `src/HoneyDrunk.Observe.Abstractions/IObservationConnector.cs` (new)
- `src/HoneyDrunk.Observe.Abstractions/IObservationEvent.cs` (new)
- `src/HoneyDrunk.Observe.Abstractions/README.md` (new)
- `src/HoneyDrunk.Observe.Abstractions/CHANGELOG.md` (new)
- `README.md` (new)
- `CHANGELOG.md` (new)
- `.editorconfig` (new, mirror HoneyDrunk.Vault)
- `Directory.Build.props` (new, mirror HoneyDrunk.Vault)
- `.github/workflows/pr-core.yml` (new, reusable workflow call)

**Contracts:**
- `IObservationTarget` — external-system declaration with credential reference
- `IObservationConnector` — provider-slot interface for connector implementations
- `IObservationEvent` — canonical normalized observation event
