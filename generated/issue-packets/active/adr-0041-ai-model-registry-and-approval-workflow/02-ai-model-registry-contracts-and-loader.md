---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.AI
labels: ["feature", "tier-2", "ai", "adr-0041", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0041"]
accepts: ["ADR-0041"]
wave: 2
initiative: adr-0041-ai-model-registry-and-approval-workflow
node: honeydrunk-ai
---

# Add IModelRegistry, the registration records, and the models.json loader to HoneyDrunk.AI

## Summary
Implement the model registry: add `IModelRegistry`, `ModelRegistration`, `ProviderRegistration`, `CostProfile`, `ApprovalState`, `RoutingHints`, `ModelId`, `CapabilityPredicate`, and `IApprovalStateWriter` to `HoneyDrunk.AI.Abstractions`; implement a declarative `models.json` catalog and its loader (`DeclarativeModelRegistry`) in `HoneyDrunk.AI`. This is the foundational packet — the canary harness, the cost-aware policy, and the Audit emit all build on it.

## Context
ADR-0041 D1 decides the model registry is a declarative JSON catalog inside `HoneyDrunk.AI`, named `models.json`, loaded at startup and exposed via a new `IModelRegistry` interface in `HoneyDrunk.AI.Abstractions`. The registry is the single source of truth: routers, policies, and canaries consume it; no router instance reaches into raw configuration to find a model.

`HoneyDrunk.AI` is live at v0.1.0 (shipped 2026-05-20 via AI PR #5 for ADR-0016). The current `HoneyDrunk.AI.Abstractions` already carries `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration` (a frozen record per ADR-0016), `ModelCandidate`, `RoutedModel`, `RoutingDecision`, `ChatRequestSummary`, `IModelProvider`, `ICostLedger`. `HoneyDrunk.AI` runtime has `Routing/DefaultModelRouter.cs`, `Routing/CostFirstRoutingPolicy.cs`, `Routing/PolicyLoader.cs`, `Cost/DefaultCostLedger.cs`, `Telemetry/InferenceTelemetry.cs`, `ServiceCollectionExtensions.cs`, `AIOptions.cs`.

Today the `DefaultModelRouter` builds candidates by iterating `IModelProvider.DeclaredCapabilities` directly — there is no registry, no provider list, no per-model cost ceiling, no approval state. This packet adds the registry as the missing source of truth. It does not yet rewire `DefaultModelRouter` to consume it (that is packet 04, paired with the cost-aware policy) — this packet ships the registry, its records, and its loader as a standalone, fully-tested unit.

**This is the first packet in this initiative to land on the `HoneyDrunk.AI` solution — it bumps the solution version (invariant 27).**

## Scope
- `src/HoneyDrunk.AI.Abstractions/` — new contract files (see Proposed Implementation).
- `src/HoneyDrunk.AI/Registry/` — new folder: `DeclarativeModelRegistry.cs`, `ModelsCatalogLoader.cs`, `ModelsCatalogDocument.cs` (the JSON DTO shape).
- `src/HoneyDrunk.AI/models.json` — the declarative catalog data file (populated with provider records only at this packet — see packet 03 for model entries; ship with the four providers and zero models, or an empty-models seed, so the loader has a real file to parse).
- `src/HoneyDrunk.AI/HoneyDrunk.AI.csproj` — ensure `models.json` is included as content / embedded resource so the loader can read it at runtime.
- `src/HoneyDrunk.AI/ServiceCollectionExtensions.cs` — register `IModelRegistry` in DI.
- `tests/HoneyDrunk.AI.Abstractions.Tests/` and `tests/HoneyDrunk.AI.Tests/` — unit tests.
- Version bump across every non-test `.csproj` in the solution; CHANGELOG and README updates.

## Proposed Implementation

### `HoneyDrunk.AI.Abstractions` — new contracts
Follow the existing file-per-type convention and the Grid naming rule (records drop the `I`, interfaces keep it; enums have no `I`). All public types need XML doc (invariant 13).

1. **`ModelId.cs`** — `public readonly record struct ModelId(string Value)` — the opaque stable identifier (e.g. `anthropic.claude-sonnet-4-6`). Provide a `ToString()` override and validation that `Value` is non-empty. **This is a pinned decision, not an agent judgment call:** introduce the `readonly record struct ModelId(string Value)` and use it for the registry's own types — `ModelRegistration`, `IModelRegistry` query signatures, `IApprovalStateWriter`, etc. The naming honors the Grid rule (records drop the `I`). The frozen `ModelCapabilityDeclaration` keeps its `string ModelId` field unchanged (it is frozen per ADR-0016 — do not touch it). `ModelRegistration` maps between the two: it carries a `ModelId` (the struct) and, when it composes `ModelCapabilityDeclaration`, the declaration's `string ModelId` field holds `ModelId.Value`. Do not change `ModelCapabilityDeclaration`; do not make the registry types use bare `string`.
2. **`ApprovalState.cs`** — `public enum ApprovalState { Approved, Preview, Deprecated }`.
3. **`CostProfile.cs`** — `public sealed record CostProfile(decimal InputCostPerKToken, decimal OutputCostPerKToken, decimal? CachedInputCostPerKToken, decimal MaxBudgetPerCallUsd)`.
4. **`RoutingHints.cs`** — `public sealed record RoutingHints(string LatencyTier, string? GeographicPreference, IReadOnlyDictionary<string, string> Extra)` — opaque policy-axis hints. Keep it deliberately loose; ADR-0041 D1 says hints are policy-axis, consumed by `IRoutingPolicy`.
5. **`ProviderRegistration.cs`** — `public sealed record ProviderRegistration(string ProviderId, string Name, ProviderTransport Transport, string VaultKeyReference, IReadOnlyDictionary<string, string> DefaultHeaders, DataEgressPolicy DataEgressPolicy, int RetentionDays, string? RegionPolicy)`. Add supporting enums `ProviderTransport { HttpsApi, SelfHosted }` and `DataEgressPolicy { Yes, No, OptOut, None }` (`None` is the self-hosted implicit value per D9).
6. **`ModelRegistration.cs`** — `public sealed record ModelRegistration(ModelId ModelId, string ProviderId, ModelCapabilityDeclaration Capability, CostProfile CostProfile, ApprovalState ApprovalState, RoutingHints RoutingHints)`.
7. **`CapabilityPredicate.cs`** — a `public delegate bool CapabilityPredicate(ModelCapabilityDeclaration capability)`, or a small record carrying the required-capability flags. A delegate is the lightest reading of D1's `GetByCapability(CapabilityPredicate predicate)`.
8. **`IModelRegistry.cs`**:
   ```
   public interface IModelRegistry
   {
       IReadOnlyCollection<ModelRegistration> GetRegistered();
       ModelRegistration? GetById(ModelId id);
       IReadOnlyCollection<ModelRegistration> GetByCapability(CapabilityPredicate predicate);
   }
   ```
9. **`IApprovalStateWriter.cs`** — the constrained writer (D10): exposes only a method to change `ApprovalState` for an existing `ModelId`; cannot add or remove registrations. Signature suggestion: `ValueTask SetApprovalStateAsync(ModelId id, ApprovalState state, string reason, CancellationToken ct = default)`. The implementation in packet 03/05 records the flip in Audit; the interface itself stays in Abstractions. **Persistence note (see the registry-implementation section): the in-memory writer is a per-process overlay only — it is NOT the durable source of `ApprovalState`. The durable source is the `models.json` catalog file. The overlay is reconciled from `models.json` on every load.**

### `HoneyDrunk.AI` — registry implementation
1. **`Registry/ModelsCatalogDocument.cs`** — the JSON DTO mirroring `models.json` (a `providers` array and a `models` array). This is the deserialization shape; `DeclarativeModelRegistry` maps it to the Abstractions records.
2. **`Registry/ModelsCatalogLoader.cs`** — loads and deserializes `models.json`. Reads from an embedded resource or content file; uses `System.Text.Json`. Validates: every `models[].providerId` resolves to a `providers[].providerId`; `ModelId` values are unique; no model references an unknown provider. Throws a clear exception on a malformed catalog at startup (fail-fast — a bad registry must not start the Node).
3. **`Registry/DeclarativeModelRegistry.cs`** — `IModelRegistry` implementation over the loaded catalog. Read-only at runtime per D10. `ApprovalState` mutation goes through a separate `IApprovalStateWriter` implementation. **Ship the writer here as an in-memory overlay** so packet 03 only adds the Audit emit and the canary.
   - **`ApprovalState` persistence story (pinned — write this into the implementation):** the **durable source of `ApprovalState` is the `models.json` catalog file itself** — catalog-as-data, consistent with the `models.json` loader. The in-memory `IApprovalStateWriter` overlay is a *per-process* convenience only: a flip applied through it lives for the current process and is lost when the process ends. On every load, `DeclarativeModelRegistry` reconciles its in-memory state *from* `models.json` — `models.json` always wins. A durable approval-state change is made by *editing `models.json`* (packet 03's nightly workflow does this by opening a PR that edits `models.json`; it does not rely on an in-memory flip surviving). Make the overlay clearly subordinate to the file: document that the overlay is transient and reconciled-from-file on load.
4. **`models.json`** — seed with the four `ProviderRegistration` entries from ADR-0041 D2 (Anthropic, OpenAI, Azure OpenAI, `local`) and an **empty `models` array** (model entries are packet 03). Each provider record carries its `VaultKeyReference` as a Vault path string (never an inline key — D7), `DataEgressPolicy`, `RetentionDays`, `RegionPolicy`. Use placeholder Vault paths consistent with the Grid's secret-naming convention; the actual secrets are seeded by a human (see Human Prerequisites). For `local`, `Transport=SelfHosted`, `DataEgressPolicy=None`.
5. **`ServiceCollectionExtensions.cs`** — register `IModelRegistry` (singleton — the catalog is loaded once) and `IApprovalStateWriter` in the existing `AddHoneyDrunkAI` extension.
6. **`HoneyDrunk.AI.csproj`** — add `models.json` as `<EmbeddedResource>` (pinned — one runtime-resolvable source; do not use `<Content CopyToOutputDirectory>`). The loader reads it from the embedded resource stream. This gives a single, unambiguous runtime source and means the canary harness (packet 03) and all consumers resolve model data only through `IModelRegistry`, never by reading a loose file off disk.

### Tests
- `HoneyDrunk.AI.Abstractions.Tests` — extend `AbstractionsSmokeTests` to construct each new record and assert value semantics.
- `HoneyDrunk.AI.Tests` — `DeclarativeModelRegistry` tests: loads the four providers, `GetById` returns null for an unknown `ModelId`, `GetByCapability` filters correctly, the loader throws on a model referencing an unknown provider and on duplicate `ModelId`. Use the InMemory provider patterns already in the repo. No `Thread.Sleep` (invariant 51).

### Version bump
- This is the first packet on `HoneyDrunk.AI` in this initiative — bump every non-test `.csproj` in the solution to the same new **minor** version (new feature: the registry). `0.1.0` → `0.2.0`.
- Repo-level `CHANGELOG.md` gets a new `[0.2.0]` dated entry.
- Per-package `CHANGELOG.md` updated only for `HoneyDrunk.AI.Abstractions` (new contracts) and `HoneyDrunk.AI` (registry implementation). Provider packages are version-bumped to align but get NO changelog noise entry (invariant 27).
- Update `HoneyDrunk.AI.Abstractions/README.md` and `HoneyDrunk.AI/README.md` — the public API surface changed (new `IModelRegistry` etc.); README must reflect it (invariant 12).

## Affected Files
- `src/HoneyDrunk.AI.Abstractions/ModelId.cs`, `ApprovalState.cs`, `CostProfile.cs`, `RoutingHints.cs`, `ProviderRegistration.cs`, `ModelRegistration.cs`, `CapabilityPredicate.cs`, `IModelRegistry.cs`, `IApprovalStateWriter.cs` (new)
- `src/HoneyDrunk.AI/Registry/ModelsCatalogDocument.cs`, `ModelsCatalogLoader.cs`, `DeclarativeModelRegistry.cs` (new), plus the `IApprovalStateWriter` in-memory implementation
- `src/HoneyDrunk.AI/models.json` (new)
- `src/HoneyDrunk.AI/HoneyDrunk.AI.csproj`, `ServiceCollectionExtensions.cs`
- Every non-test `.csproj` (version bump)
- `CHANGELOG.md` (repo-level), `src/HoneyDrunk.AI.Abstractions/CHANGELOG.md`, `src/HoneyDrunk.AI/CHANGELOG.md`
- `src/HoneyDrunk.AI.Abstractions/README.md`, `src/HoneyDrunk.AI/README.md`
- Test files in `tests/HoneyDrunk.AI.Abstractions.Tests/` and `tests/HoneyDrunk.AI.Tests/`

## NuGet Dependencies
No new `PackageReference` is required — `System.Text.Json` is in the .NET 10 SDK shared framework. If the repo's `Directory.Build.props` does not already surface `System.Text.Json`, confirm it is available; do not add a redundant package reference. All new projects (none are created here) would need `HoneyDrunk.Standards` — but this packet creates no new project, only new files in existing projects, so no `PackageReference` change is expected. If a new project is created against expectation, it must reference `HoneyDrunk.Standards` (`PrivateAssets: all`).

## Boundary Check
- [x] All code in `HoneyDrunk.AI`. Routing rule maps AI-sector model/registry work to the AI Node.
- [x] No cross-Node runtime dependency added — `IModelRegistry` lives in `HoneyDrunk.AI.Abstractions`, consistent with invariant 44 (downstream AI Nodes depend on Abstractions only).
- [x] Abstractions package keeps zero HoneyDrunk runtime dependencies (invariant 1) — the new contracts are pure records/interfaces.

## Acceptance Criteria
- [ ] `HoneyDrunk.AI.Abstractions` exposes `IModelRegistry`, `IApprovalStateWriter`, `ModelRegistration`, `ProviderRegistration`, `CostProfile`, `ApprovalState`, `RoutingHints`, `ModelId`, `CapabilityPredicate`, each with XML documentation
- [ ] `HoneyDrunk.AI` has `DeclarativeModelRegistry : IModelRegistry` loading a declarative `models.json`
- [ ] `models.json` ships the four ADR-0041 D2 providers (Anthropic, OpenAI, Azure OpenAI, `local`) with an empty `models` array; provider API keys are Vault path references, never inline values
- [ ] The catalog loader fails fast on a malformed catalog: a model referencing an unknown provider, or a duplicate `ModelId`, throws at load
- [ ] `IModelRegistry` and `IApprovalStateWriter` are registered in DI via `AddHoneyDrunkAI`
- [ ] `IApprovalStateWriter` can only change `ApprovalState` — it has no add/remove-registration capability (D10)
- [ ] The `IApprovalStateWriter` overlay is documented and implemented as a transient per-process overlay; `DeclarativeModelRegistry` reconciles `ApprovalState` from `models.json` on load — `models.json` is the durable source of approval state
- [ ] `models.json` is included as `<EmbeddedResource>` (not `<Content>`); the loader reads it from the embedded resource stream
- [ ] Unit tests cover registry queries, the loader's fail-fast validation, and value semantics of the new records; no `Thread.Sleep` in any test
- [ ] Every non-test `.csproj` in the solution is bumped to the same new minor version (`0.2.0`); no partial bump
- [ ] Repo-level `CHANGELOG.md` has a new dated `[0.2.0]` entry; per-package changelogs updated only for `HoneyDrunk.AI.Abstractions` and `HoneyDrunk.AI` (no alignment-bump noise on provider packages)
- [ ] `HoneyDrunk.AI.Abstractions/README.md` and `HoneyDrunk.AI/README.md` reflect the new public API surface
- [ ] Solution builds; `pr.yml` tier-1 gate (build, unit tests, analyzers, vuln scan, secret scan) passes; the `api-compatibility.yml` contract-shape canary passes (this packet intentionally bumps the version, so additive Abstractions changes are allowed)

## Human Prerequisites
- [ ] Provider API keys must exist in Vault before any *live* model dispatch — Anthropic, OpenAI, and Azure OpenAI API keys seeded at the Vault paths `models.json` references. This is NOT in this packet's critical path: this packet ships only provider *registrations* with an empty `models` array and no live calls, so the keys are not needed for this packet's CI or merge. They become a prerequisite for packet 03's canary. Seed them at the agreed Vault paths (per ADR-0005 secret-naming) before packet 03 runs.

## Referenced ADR Decisions
**ADR-0041 D1 — Registry lives in `HoneyDrunk.AI`, declarative.** `models.json` loaded at startup, exposed via `IModelRegistry` with `GetRegistered()`, `GetById(ModelId)`, `GetByCapability(CapabilityPredicate)`. `ModelRegistration` carries `ModelId`, `ProviderId`, `ModelCapabilityDeclaration` (the frozen ADR-0016 record), `CostProfile`, `ApprovalState`, `RoutingHints`. The registry is the source of truth — no router reaches into raw configuration.

**ADR-0041 D2 — Approved providers.** Anthropic, OpenAI, Azure OpenAI, and a `local` placeholder (no models at v1).

**ADR-0041 D7 — Provider credentials.** Provider API keys live in Vault per ADR-0005; the registry references them by Vault path, never inline.

**ADR-0041 D9 — Self-hosted special case.** `ProviderId=local` is reserved; `DataEgressPolicy=None` is implicit; no self-hosted models at v1.

**ADR-0041 D10 — Registry is read-only at runtime.** `models.json` is edited by humans through packets. The only runtime mutation is the canary-driven `ApprovalState` flip through the constrained `IApprovalStateWriter`, which can only change `ApprovalState` and cannot add or remove registrations.

**Constraint — ModelCapabilityDeclaration is frozen (ADR-0016).** `ModelRegistration` *carries* `ModelCapabilityDeclaration` as-is. Do not modify or extend `ModelCapabilityDeclaration` — it is the frozen ADR-0016 record. Its current shape: `ModelCapabilityDeclaration(string ProviderId, string ModelId, int MaxContextTokens, bool SupportsStreaming, bool SupportsVision, bool SupportsFunctionCalling, string[] SupportedRegions, decimal? InputCostPerKToken, decimal? OutputCostPerKToken)`.

## Constraints
- **Do not modify `ModelCapabilityDeclaration`.** It is the frozen ADR-0016 record. `ModelRegistration` composes it; it does not change it.
- **`HoneyDrunk.AI.Abstractions` has zero HoneyDrunk runtime dependencies (invariant 1).** Only `Microsoft.Extensions.*` abstractions are permitted. The new contracts must be pure records/interfaces — no JSON-loading logic in Abstractions; that lives in the `HoneyDrunk.AI` runtime.
- **Records drop the `I`; interfaces keep it; enums have no `I` (Grid naming rule).**
- **All projects in a solution share one version (invariant 27).** Bump every non-test `.csproj` to the same new version in a single commit; partial bumps are forbidden. This packet is the bumping packet for the initiative; packets 03/04/05 append to the CHANGELOG only.
- **Registry is read-only at runtime (D10).** The loaded catalog is immutable; `IApprovalStateWriter` is the only in-process mutation seam and it only touches `ApprovalState`.
- **`models.json` is the durable source of `ApprovalState`.** The in-memory `IApprovalStateWriter` overlay is per-process and evaporates with the process; it is reconciled from `models.json` on every load. A durable approval-state change is a `models.json` edit (packet 03's nightly workflow opens a PR to make it). Do not present the in-memory overlay as durable state.
- **`models.json` is an `<EmbeddedResource>`.** One runtime-resolvable source; the loader reads the embedded stream. Do not use `<Content CopyToOutputDirectory>`.
- **`ModelId` is a `readonly record struct`.** The registry's own types use the `ModelId` struct; the frozen `ModelCapabilityDeclaration` keeps its `string ModelId` field; `ModelRegistration` maps between them. This is pinned — not an agent choice.
- **Provider keys are Vault path references (D7, invariant 9).** `models.json` carries Vault paths; never inline secret values. Secret scanning is a tier-1 gate — an inline key fails the build and is a real leak.
- **No model entries in `models.json` yet.** Models are added by packet 03 (with their canaries). This packet ships providers + empty models array.

## Labels
`feature`, `tier-2`, `ai`, `adr-0041`, `wave-2`

## Agent Handoff

**Objective:** Add the `IModelRegistry` contract surface and the declarative `models.json` loader to `HoneyDrunk.AI`.

**Target:** `HoneyDrunk.AI`, branch from `main`.

**Context:**
- Goal: Ship the model registry as the single source of truth for AI model metadata, per ADR-0041.
- Feature: ADR-0041 AI Model Registry and Approval Workflow rollout, Wave 2 — the foundational implementation packet.
- ADRs: ADR-0041 D1/D2/D7/D9/D10 (primary), ADR-0016 (`ModelCapabilityDeclaration` is frozen).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0041 should be Accepted before its registry is built.

**Constraints:**
- Do not modify the frozen `ModelCapabilityDeclaration` record.
- `ModelId` is a `readonly record struct ModelId(string Value)` for the registry's own types; `ModelCapabilityDeclaration` keeps `string ModelId`; `ModelRegistration` maps between them. Pinned, not a judgment call.
- `models.json` is the durable source of `ApprovalState`; the `IApprovalStateWriter` overlay is a transient per-process overlay, reconciled from the file on load.
- `models.json` ships as `<EmbeddedResource>` — one runtime source; no `<Content>`.
- `HoneyDrunk.AI.Abstractions` keeps zero HoneyDrunk runtime dependencies — pure records/interfaces only.
- Records drop the `I`, interfaces keep it, enums have no `I`.
- This is the version-bumping packet — bump every non-test `.csproj` to `0.2.0` together.
- Provider keys in `models.json` are Vault path references — never inline values (secret scan is a CI gate).

**Key Files:**
- `src/HoneyDrunk.AI.Abstractions/` — new contract files
- `src/HoneyDrunk.AI/Registry/` — new loader + registry implementation
- `src/HoneyDrunk.AI/models.json` — new catalog data
- `src/HoneyDrunk.AI/ServiceCollectionExtensions.cs`, `HoneyDrunk.AI.csproj`

**Contracts:**
- New (additive to `HoneyDrunk.AI.Abstractions`): `IModelRegistry`, `IApprovalStateWriter`, `ModelRegistration`, `ProviderRegistration`, `CostProfile`, `ApprovalState`, `RoutingHints`, `ModelId`, `CapabilityPredicate`.
- Unchanged: `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration`, `ModelCandidate`, `RoutedModel`, `RoutingDecision`, `ChatRequestSummary`, `IModelProvider`, `ICostLedger`.
