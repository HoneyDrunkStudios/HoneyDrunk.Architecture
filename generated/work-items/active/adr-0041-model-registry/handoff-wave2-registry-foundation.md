# Handoff — Wave 2: Registry Foundation

**Initiative:** `adr-0041-model-registry`
**Wave transition:** Wave 1 (governance + catalog) → Wave 2 (registry foundation)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 1 landed

- **Packet 00** — ADR-0041 flipped to **Accepted**. Three new invariants added to `constitution/invariants.md` under the `## AI Invariants` section as the pre-reserved numbers **72, 73, 74**:
  - **72** — No AI dispatch happens against an unregistered model.
  - **73** — Every approved model has a passing capability canary in the last 24 hours.
  - **74** — Every AI dispatch emits an Audit entry recording `(TenantId, ModelId, PolicyOverride?, CostUsd, Outcome)`.
- **Packet 01** — the model-registry contract surface (`IModelRegistry`, `ModelRegistration`, `ProviderRegistration`, `CostProfile`, `ApprovalState`, `RoutingHints`, `IApprovalStateWriter`) is registered in the `honeydrunk-ai` block's `interfaces` array in `catalogs/contracts.json`, and in the `honeydrunk-ai` entry's `exposes.contracts` array in `catalogs/relationships.json` (`catalogs/nodes.json` is not touched — it has no `exposes` field). The approval-workflow policy is recorded as a cross-cutting AI-sector note.

ADR-0041's decisions are now live rules. Packet 02 implements the contracts the catalog already advertises.

## What Wave 2 must deliver (packet 02)

Build the model registry in **`HoneyDrunk.AI`** (live Node, currently v0.1.0):

- **`HoneyDrunk.AI.Abstractions`** — add `IModelRegistry`, `IApprovalStateWriter`, `ModelRegistration`, `ProviderRegistration`, `CostProfile`, `ApprovalState`, `RoutingHints`, `ModelId`, `CapabilityPredicate`. Pure records/interfaces/enums — zero HoneyDrunk runtime dependencies (invariant 1).
- **`HoneyDrunk.AI`** — `DeclarativeModelRegistry : IModelRegistry`, the `models.json` catalog (four providers, empty `models` array) shipped as an `<EmbeddedResource>`, the fail-fast `ModelsCatalogLoader`, the `IApprovalStateWriter` transient per-process overlay, DI registration.

`ModelId` is a `readonly record struct ModelId(string Value)` used for the registry's own types; the frozen `ModelCapabilityDeclaration` keeps `string ModelId`; `ModelRegistration` maps between them. Pinned decision — not an agent choice.

**`ApprovalState` persistence:** `models.json` is the durable source of approval state. The `IApprovalStateWriter` overlay is per-process only — `DeclarativeModelRegistry` reconciles `ApprovalState` from `models.json` on load. A durable flip is a `models.json` edit (packet 03's nightly workflow opens a PR to do it). The overlay is subordinate to the file.

## Interface signatures for downstream packets

`IModelRegistry` (the shape packets 03/04/05 consume):
```
public interface IModelRegistry
{
    IReadOnlyCollection<ModelRegistration> GetRegistered();
    ModelRegistration? GetById(ModelId id);
    IReadOnlyCollection<ModelRegistration> GetByCapability(CapabilityPredicate predicate);
}
```

`ModelRegistration` carries: `ModelId`, `ProviderId`, the frozen `ModelCapabilityDeclaration`, `CostProfile`, `ApprovalState`, `RoutingHints`.

`CostProfile` carries per-token costs plus `MaxBudgetPerCallUsd` — the per-call ceiling packet 04 enforces.

`ApprovalState` is `{ Approved, Preview, Deprecated }`. Packet 04 excludes `Deprecated` from new dispatch; packet 03's canary persists a flip by opening a PR that edits `models.json` (the durable source) — the in-memory `IApprovalStateWriter` flip is process-local.

`IApprovalStateWriter` — the constrained writer: changes only `ApprovalState` in the per-process overlay, cannot add/remove registrations (D10). Not the durable store — `models.json` is.

## Frozen contract — do not touch

`ModelCapabilityDeclaration` is frozen per ADR-0016. `ModelRegistration` composes it as-is. Current shape:
```
ModelCapabilityDeclaration(string ProviderId, string ModelId, int MaxContextTokens,
    bool SupportsStreaming, bool SupportsVision, bool SupportsFunctionCalling,
    string[] SupportedRegions, decimal? InputCostPerKToken, decimal? OutputCostPerKToken)
```

## Invariants binding Wave 2

- **Invariant 1** — `HoneyDrunk.AI.Abstractions` has zero runtime dependencies on other HoneyDrunk packages; only `Microsoft.Extensions.*` abstractions are permitted. The new contracts are pure records/interfaces — no JSON-loading logic in Abstractions.
- **Invariant 27** — all projects in a solution share one version and move together. Packet 02 is the bumping work-item: bump every non-test `.csproj` to `0.2.0` in one commit. Partial bumps are forbidden. Packets 03/04/05 append to the CHANGELOG only.
- **Invariant 9 / D7** — provider API keys in `models.json` are Vault path references, never inline values. Secret scanning is a tier-1 CI gate.
- **Invariant 13** — all public APIs have XML documentation.
- **New AI invariant 72** — no AI dispatch against an unregistered model. The registry is the enforcement substrate; packet 02 builds it.

## Acceptance gate for the wave

Packet 02's PR passes the `pr.yml` tier-1 gate and the `api-compatibility.yml` contract-shape canary (the new contracts are additive, paired with the `0.2.0` bump). `HoneyDrunk.AI` is at `0.2.0` with `IModelRegistry` shipped and `models.json` carrying the four ADR-0041 D2 providers and an empty `models` array. Wave 3 (packets 03 and 04) can then start in parallel.
