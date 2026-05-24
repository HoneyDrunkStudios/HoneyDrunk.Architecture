---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.AI
labels: ["feature", "tier-2", "ai", "ops", "adr-0052", "wave-3"]
dependencies: ["packet:03"]
adrs: ["ADR-0052", "ADR-0016"]
accepts: ["ADR-0052"]
wave: 3
initiative: adr-0052-cost-governance
node: honeydrunk-ai
---

# Remove the AI-side ICostLedger and point AI.Abstractions at the new Kernel contract

## Summary
Reconcile the existing `HoneyDrunk.AI.Abstractions.ICostLedger` (two-member inference-only contract) against the new `HoneyDrunk.Kernel.Abstractions.ICostLedger` (five-member multi-source contract from ADR-0052 D7, shipped in packet 03). **Remove** the AI-side `ICostLedger.cs` (and the inference-specific `InferenceCost` / `CostSummary` records if they are only used by it), update `HoneyDrunk.AI.Abstractions` to depend on `HoneyDrunk.Kernel.Abstractions` for the cost-ledger contract, and update every provider package (`HoneyDrunk.AI.Providers.OpenAI`/`.Anthropic`/`.AzureOpenAI`/`.InMemory`) that referenced the old shape to compile against the Kernel contract. This is the version-bumping packet for the `HoneyDrunk.AI` solution in this initiative.

## Context
The existing `HoneyDrunk.AI.Abstractions.ICostLedger` (at `HoneyDrunk.AI/src/HoneyDrunk.AI.Abstractions/ICostLedger.cs`) was committed as part of the AI Node's seed surface per ADR-0016 D5:

```csharp
public interface ICostLedger
{
    Task RecordAsync(InferenceCost cost, CancellationToken cancellationToken = default);
    Task<CostSummary> GetSummaryAsync(string scope, DateTimeOffset since, CancellationToken cancellationToken = default);
}
```

It is inference-only (`InferenceCost` carries `ProviderId`, `ModelId`, `InputTokens`, `OutputTokens`, `EstimatedCost`, `OperationCorrelationId`) and category-agnostic (no `CostCategory` enum — the "scope" is a caller-defined string).

ADR-0052 D7 replaces this with a wider contract in `HoneyDrunk.Kernel.Abstractions`:

```csharp
public interface ICostLedger
{
    ValueTask RecordCostAsync(CostEvent evt, CancellationToken ct);
    ValueTask<decimal> GetMonthToDateAsync(CostCategory category, CancellationToken ct);
    ValueTask<bool> IsHardCapBreachedAsync(CostCategory category, CancellationToken ct);
    ValueTask<BudgetOverride?> GetActiveOverrideAsync(CostCategory category, CancellationToken ct);
    IAsyncEnumerable<CostEvent> QueryAsync(CostQuery query, CancellationToken ct);
}
```

The new contract is category-scoped (five `CostCategory` values), multi-source (`CostSource` discriminated union covers inference + Azure infra + SaaS + CI + domain), and makes the kill-switch read a first-class method.

**Relocation policy.** This is a **replace, not extend**. The AI-side `ICostLedger` is removed, not retained. Rationale:
- The two contracts have the same name and different shapes — keeping both in scope would force consumers to disambiguate with `using` aliases, which is a poor API.
- The new contract is a superset of the old by intent: the inference case becomes a `CostEvent` with `Source = LlmInferenceSource(...)`. The existing `InferenceCost` record maps 1:1 onto `LlmInferenceSource`.
- ADR-0016 D5 (the original "operator-configurable token cost rates and `ICostLedger` abstraction") and ADR-0052 D7 are deliberately aligned — D7 is the **expansion** of the seed surface D5 named, not a parallel surface.

**Repo state at edit time.** `HoneyDrunk.AI` is at v0.1.0, **seed** status — the ADR-0016 Phase-1 scaffold packet (HoneyDrunk.AI#2) has not been executed. The repo currently contains only the `HoneyDrunk.AI.Abstractions` seed types committed at standup, plus a `DefaultCostLedger` skeleton in `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/DefaultCostLedger.cs` and a `ServiceCollectionExtensions` registration. The packet that scaffolds the full v0 .NET solution per ADR-0016 has not landed yet. **This is a known initiative-level blocker** — see the dispatch plan's cross-cutting concern on the AI-standup gate. If the ADR-0016 scaffold has not landed by execution time, this packet still ships against whatever exists in the AI repo (the abstraction-only relocation does not require the full standup); the v1 Cosmos implementation in packet 05 is the one that strictly requires the standup. **Check at execution time.**

**Dependency direction.** `HoneyDrunk.AI.Abstractions` adding a `PackageReference` on `HoneyDrunk.Kernel.Abstractions` is consistent with invariant 1 (Abstractions packages may reference other HoneyDrunk **abstraction** packages — only the runtime-dependency-on-runtime case is forbidden). Verify by inspecting the existing `HoneyDrunk.AI.Abstractions.csproj` at edit time — it may already reference `HoneyDrunk.Kernel.Abstractions` for the existing `IGridContext` / `TenantId` types; if not, add the reference.

**Provider packages.** Four provider packages (`HoneyDrunk.AI.Providers.OpenAI`, `.Anthropic`, `.AzureOpenAI`, `.InMemory`) reference `HoneyDrunk.AI.Abstractions` and may reference the old `ICostLedger` / `InferenceCost`. The packages emit cost telemetry by calling `RecordAsync(InferenceCost)`. After this packet they call `RecordCostAsync(CostEvent)` with the inference event constructed via `CostSource = new LlmInferenceSource(...)`. The provider packages all share the AI solution version (invariant 27) so they bump together.

**`DefaultCostLedger` in the AI runtime.** A `DefaultCostLedger` class exists at `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/DefaultCostLedger.cs` implementing the old `ICostLedger`. This packet rewrites it to implement the new Kernel contract, but **as a thin no-op / in-memory stub only** — the real v1 Cosmos-backed implementation is packet 05. The stub here exists so the solution compiles and the existing DI registration (`services.AddSingleton<ICostLedger, DefaultCostLedger>()`) does not break. Packet 05 replaces the stub with the real Cosmos backing.

**Catalog mirror.** Packet 01 marked the `honeydrunk-ai` `ICostLedger` entry as relocating; this packet's PR completes the relocation by removing the AI-side type, so the catalog entry can be **deleted** in a small catalog-cleanup follow-up after this packet merges. **This packet does not edit the Architecture-repo catalog.** The catalog cleanup is named in packet 09 (the playbook), not done here — the cross-repo edit would split the AI-code change across two PRs in two repos.

## Scope
- `HoneyDrunk.AI.Abstractions` — remove `ICostLedger.cs`, `InferenceCost.cs`, `CostSummary.cs` (and any other types that exist only to serve the removed interface). Add a `PackageReference` to `HoneyDrunk.Kernel.Abstractions` (the version that ships packet 03) if not already present.
- Every provider package (`HoneyDrunk.AI.Providers.OpenAI`/`.Anthropic`/`.AzureOpenAI`/`.InMemory`) — update every call site that used the old `RecordAsync(InferenceCost)` to call `RecordCostAsync(CostEvent)` with a `CostSource = new LlmInferenceSource(...)`. The `CostEvent.Amount` is the same value as the old `InferenceCost.EstimatedCost`; the category is `CostCategory.AiInference`; `AgentId` / `AgentRunId` are populated from ambient context if the dispatcher already plumbs them (see packet 06), otherwise `null`.
- `HoneyDrunk.AI` runtime — rewrite `DefaultCostLedger.cs` to implement the new five-member Kernel contract as a thin no-op / in-memory stub. The Cosmos-backed v1 implementation is packet 05; this stub exists only so the solution compiles.
- Solution-wide version bump per invariant 27 (every non-test `.csproj` shares one version).
- Per-package CHANGELOG entries for every package with a real change; no noise entries on alignment-only bumps.
- Repo-level `CHANGELOG.md`.
- `HoneyDrunk.AI.Abstractions/README.md` updated — the old `ICostLedger` is removed from the public API section; a pointer to `HoneyDrunk.Kernel.Abstractions.ICostLedger` replaces it.

## Proposed Implementation
1. **Delete the AI-side cost types.** Remove `HoneyDrunk.AI/src/HoneyDrunk.AI.Abstractions/ICostLedger.cs`, `InferenceCost.cs`, `CostSummary.cs`. Verify at edit time that no other Abstractions type still references these (search for `ICostLedger`, `InferenceCost`, `CostSummary` across the repo); if anything outside the to-be-removed set references them, file the dependent change in the same commit. The XML doc files emitted to `bin/` will refresh on the next build — no manual cleanup needed.
2. **Update `HoneyDrunk.AI.Abstractions.csproj`.** Add a `PackageReference` to `HoneyDrunk.Kernel.Abstractions` if not already present, pinned to the version that ships ADR-0052 packet 03 (the version that adds `ICostLedger` + supporting types). Check the AI.Abstractions csproj at edit time for the existing Kernel.Abstractions reference and update the version if needed.
3. **Update every provider package.** For each of `HoneyDrunk.AI.Providers.OpenAI`/`.Anthropic`/`.AzureOpenAI`/`.InMemory`, find every call to the old `ICostLedger.RecordAsync(InferenceCost)`. Replace with:
   ```csharp
   var costEvent = new CostEvent(
       Category: CostCategory.AiInference,
       Amount: estimatedCost,
       Timestamp: DateTimeOffset.UtcNow,
       Source: new LlmInferenceSource(providerId, modelId, inputTokens, outputTokens),
       Environment: gridContext.Environment,                  // from ambient GridContext if available
       CorrelationId: operationCorrelationId,
       TenantId:   gridContext.TenantId,                       // null if no tenant context
       AgentId:    gridContext.AgentId,                        // null if not under an agent
       AgentRunId: gridContext.AgentRunId);
   await costLedger.RecordCostAsync(costEvent, ct);
   ```
   The exact ambient-context plumbing depends on how `GridContext` / `IGridContext` is exposed in the provider; match the existing pattern. If the providers don't yet have `TenantId` / `AgentId` plumbed, pass `null` and XML-doc the limitation in the package CHANGELOG entry — that's a follow-up improvement, not a packet-04 blocker.
4. **Rewrite `DefaultCostLedger`.** Replace the existing `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/DefaultCostLedger.cs` implementation with a thin stub that satisfies the new Kernel `ICostLedger`:
   - `RecordCostAsync` — log the event at Debug via the existing `ILogger<DefaultCostLedger>` (do not write to durable storage; the stub is intentionally non-durable until packet 05).
   - `GetMonthToDateAsync` — return `0m` for every category (stub).
   - `IsHardCapBreachedAsync` — return `false` for every category (stub — the kill-switch does not fire in the stub).
   - `GetActiveOverrideAsync` — return `null` for every category.
   - `QueryAsync` — return an empty `IAsyncEnumerable<CostEvent>`.
   XML-doc the class: "Phase-1 stub per ADR-0052 D14 — non-durable, no kill-switch enforcement. Packet 05 replaces this with the Cosmos-backed v1 implementation."
5. **`ServiceCollectionExtensions`.** Update the existing `services.AddSingleton<ICostLedger, DefaultCostLedger>()` registration. The `using` may change from `HoneyDrunk.AI.Abstractions` to `HoneyDrunk.Kernel.Abstractions`; verify at edit time. Keep the registration — packet 05 replaces the implementation type while keeping the `ICostLedger` interface unchanged.
6. **Version-bump every non-test `.csproj` in the `HoneyDrunk.AI` solution to one new minor version** (invariant 27). The current solution version is 0.1.0; this packet is the first packet on the solution in this initiative, so it bumps. The bump is minor (`0.1.0` → `0.2.0`): the AI-side contract change is a removal but the AI Node is still at seed status — the only consumer is internal AI provider code, no external consumer pins on `HoneyDrunk.AI.Abstractions.ICostLedger` yet (the AI Node has had no GA release). Treat as additive minor on the rationale that no out-of-repo consumer existed; document this rationale in the PR.
7. **Per-package CHANGELOGs** — `HoneyDrunk.AI.Abstractions/CHANGELOG.md` gets an entry: "`ICostLedger`, `InferenceCost`, `CostSummary` removed — relocated to `HoneyDrunk.Kernel.Abstractions` per ADR-0052 D7. Consume the Kernel contract directly." `HoneyDrunk.AI/CHANGELOG.md` gets an entry: "`DefaultCostLedger` rewritten as a Phase-1 stub against the Kernel `ICostLedger` contract — non-durable, no kill-switch enforcement. Packet 05 replaces with the Cosmos backing." Each provider package CHANGELOG gets an entry: "Cost recording migrated to `HoneyDrunk.Kernel.Abstractions.ICostLedger`; inference events emit `CostEvent` with `LlmInferenceSource`." Repo-level `CHANGELOG.md` updated.
8. **`HoneyDrunk.AI.Abstractions/README.md`** — remove `ICostLedger` from the public-API section. Add a brief pointer: "Cost-governance contracts (`ICostLedger`, `CostEvent`, `CostCategory`, etc.) now live in `HoneyDrunk.Kernel.Abstractions` per ADR-0052 D7."

## Affected Files
- `HoneyDrunk.AI/src/HoneyDrunk.AI.Abstractions/ICostLedger.cs` — deleted
- `HoneyDrunk.AI/src/HoneyDrunk.AI.Abstractions/InferenceCost.cs` — deleted (verify no other reference first)
- `HoneyDrunk.AI/src/HoneyDrunk.AI.Abstractions/CostSummary.cs` — deleted (verify no other reference first)
- `HoneyDrunk.AI/src/HoneyDrunk.AI.Abstractions/HoneyDrunk.AI.Abstractions.csproj` — add/update `PackageReference` to `HoneyDrunk.Kernel.Abstractions`; version bump
- Every provider package `.csproj` — version bump; possibly an updated `PackageReference` to the new `HoneyDrunk.Kernel.Abstractions` version
- Every provider package source — call-site migration from `RecordAsync` to `RecordCostAsync`
- `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/DefaultCostLedger.cs` — rewritten as a stub against the Kernel contract
- `HoneyDrunk.AI/src/HoneyDrunk.AI/ServiceCollectionExtensions.cs` — verify the DI registration `using`
- `HoneyDrunk.AI.Abstractions/CHANGELOG.md`, every package CHANGELOG with a real change, repo-level `CHANGELOG.md`
- `HoneyDrunk.AI.Abstractions/README.md`

## NuGet Dependencies
- **`HoneyDrunk.AI.Abstractions`** — `PackageReference` to `HoneyDrunk.Kernel.Abstractions` at the version that ships ADR-0052 packet 03 (this initiative's packet 03 — confirm the released version at edit time, after the Wave-2 → Wave-3 human release tag on `HoneyDrunk.Kernel`; see the dispatch plan's human-release boundary).
- **Every provider package** — inherits the same `HoneyDrunk.Kernel.Abstractions` reference transitively via `HoneyDrunk.AI.Abstractions`; no new direct reference unless an existing one needs version-bumping.
- **`HoneyDrunk.AI`** — no new package; the stub `DefaultCostLedger` uses only types from `HoneyDrunk.Kernel.Abstractions` and the BCL.
- Tests follow the repo's existing stack; no new packages.

## Boundary Check
- [x] All edits in `HoneyDrunk.AI`. The AI-side relocation is the AI repo's concern; the Kernel-side addition was packet 03. No cross-repo coupling on this commit.
- [x] `HoneyDrunk.AI.Abstractions` referencing `HoneyDrunk.Kernel.Abstractions` is invariant-1-clean — Abstractions may reference other Abstractions; only runtime-on-runtime is forbidden.
- [x] No reference to `HoneyDrunk.Data` or any other non-Kernel HoneyDrunk runtime package — invariant 4 (DAG).
- [x] The stub `DefaultCostLedger` is non-durable by design; the durable Cosmos implementation is packet 05.

## Acceptance Criteria
- [ ] `HoneyDrunk.AI/src/HoneyDrunk.AI.Abstractions/ICostLedger.cs`, `InferenceCost.cs`, `CostSummary.cs` are deleted (and no other Abstractions type still references them)
- [ ] `HoneyDrunk.AI.Abstractions.csproj` references `HoneyDrunk.Kernel.Abstractions` at the version that ships ADR-0052 packet 03
- [ ] Every provider package's call site has migrated from `RecordAsync(InferenceCost)` to `RecordCostAsync(CostEvent)` with `Source = new LlmInferenceSource(...)`, `Category = CostCategory.AiInference`, and `Environment` populated from ambient context (or `Prod` as a deliberate default with an XML-doc note if no `GridContext` is available at the call site)
- [ ] `DefaultCostLedger` implements the new five-member Kernel `ICostLedger` as a non-durable stub: `RecordCostAsync` logs at Debug, `IsHardCapBreachedAsync` returns `false`, `GetActiveOverrideAsync` returns `null`, `QueryAsync` returns empty; XML-doc states "Phase-1 stub per ADR-0052 D14; packet 05 replaces with Cosmos backing"
- [ ] `ServiceCollectionExtensions` still registers `ICostLedger -> DefaultCostLedger`, now against the Kernel contract
- [ ] Every non-test `.csproj` in the `HoneyDrunk.AI` solution is at the same new minor version (e.g., `0.1.0` → `0.2.0`); invariant-27 single-commit version bump
- [ ] Per-package CHANGELOGs updated only for packages with real changes: `HoneyDrunk.AI.Abstractions` (the deletion), `HoneyDrunk.AI` (the `DefaultCostLedger` rewrite), each provider package (the call-site migration). No noise entries on alignment-only bumps
- [ ] Repo-level `CHANGELOG.md` updated
- [ ] `HoneyDrunk.AI.Abstractions/README.md` no longer lists `ICostLedger` in the public-API section; carries a pointer to the new Kernel contract
- [ ] The AI solution builds; existing unit tests pass; no `using HoneyDrunk.AI.Abstractions;` line remains that resolved the now-removed `ICostLedger` (the compiler will catch this)

## Human Prerequisites
- [ ] **Wave-2 → Wave-3 human release tag on `HoneyDrunk.Kernel`.** Packet 04 compiles against the `HoneyDrunk.Kernel.Abstractions` version that ships ADR-0052 packet 03. That artifact reaches the NuGet feed only after a human pushes the git release tag on `HoneyDrunk.Kernel`. After packet 03 merges, a human must tag/release the Kernel solution at its new version so this packet can compile. Agents merge code but never tag or publish (per the cross-cutting concern in every multi-repo initiative).

## Referenced ADR Decisions
**ADR-0052 D7 — Cost ledger implementation home.** Interface in `HoneyDrunk.Kernel.Abstractions`; v1 implementation in `HoneyDrunk.AI`. The interface in Kernel is unchanged across the promotion path; only the implementation moves when `HoneyDrunk.CostLedger` graduates to its own Node. The relocation in this packet is exactly the D7 commitment — the seed AI-side `ICostLedger` is removed, AI compiles against the Kernel contract going forward.

**ADR-0052 D1 — Five cost categories.** Inference events specifically use `CostCategory.AiInference`. The provider call-site migration encodes this — every inference event has `Category = CostCategory.AiInference`.

**ADR-0052 D14 Phase 1 — Loose initial caps; intentional permissive first month.** The Phase-1 stub `DefaultCostLedger` returns `IsHardCapBreachedAsync = false` for every category — the kill-switch is deliberately inert in the stub. Packet 05 ships the Cosmos backing with the real cap check; packet 06 wires `ILlmDispatcher` to call it. Until both land, the stub is the in-process behaviour.

**ADR-0016 D5 — Operator-configurable token cost rates and `ICostLedger` abstraction.** The original commitment that named `ICostLedger` as a Grid abstraction. ADR-0052 D7 is the **expansion** of that commitment, not a parallel surface. The relocation is therefore consistent with ADR-0016's intent — the abstraction moves to its natural home (Kernel) and gains the policy surface (caps, kill-switch, attribution) D5 left unspecified.

## Constraints
- **Replace, not extend.** The old AI-side `ICostLedger` is removed. Two `ICostLedger` interfaces in scope would force `using` aliases on every consumer; that is a worse API than the migration.
- **Stub, not implementation.** `DefaultCostLedger` is a Phase-1 non-durable stub. The Cosmos backing is packet 05. Do not implement Cosmos persistence in this packet.
- **One-commit version bump.** Every non-test `.csproj` shares the new minor version (invariant 27); partial bumps are forbidden.
- **Per-package CHANGELOG hygiene.** Only packages with real changes get entries. The `HoneyDrunk.AI` runtime gets an entry (the `DefaultCostLedger` rewrite); the four provider packages each get an entry (the call-site migration); `HoneyDrunk.AI.Abstractions` gets an entry (the deletion). No noise entries on alignment-only bumps (invariant 12/27).
- **No edit to the Architecture-repo catalog from this packet.** Packet 01 marked the AI `ICostLedger` entry as relocating; the catalog cleanup that deletes the entry is named in packet 09 (the playbook) to avoid splitting the AI-code change across two repos.
- **Do not touch `HoneyDrunk.Kernel`.** The Kernel-side contract addition was packet 03; this packet is AI-only.
- **No new Azure resource.** The stub is non-durable; the Cosmos provisioning is a Human Prerequisite on packet 05, not this packet.

## Labels
`feature`, `tier-2`, `ai`, `ops`, `adr-0052`, `wave-3`

## Agent Handoff

**Objective:** Remove the seed `HoneyDrunk.AI.Abstractions.ICostLedger` and its supporting types, point `HoneyDrunk.AI.Abstractions` and every AI provider package at the new `HoneyDrunk.Kernel.Abstractions.ICostLedger`, and rewrite `DefaultCostLedger` as a Phase-1 non-durable stub against the Kernel contract. Bump the `HoneyDrunk.AI` solution one minor version.

**Target:** `HoneyDrunk.AI`, branch from `main`.

**Context:**
- Goal: Complete the AI-side half of the ADR-0052 D7 relocation. The Kernel-side addition was packet 03; this packet replaces the old AI-side `ICostLedger` with the Kernel contract and migrates every call site.
- Feature: ADR-0052 Cost Governance rollout, Wave 3.
- ADRs: ADR-0052 D1/D7/D14 (primary), ADR-0016 D5 (the seed commitment this expands).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` — the Kernel contract surface (Kernel `0.9.0` or whichever version packet 03 lands at) must exist on the NuGet feed (gated by the human release-tag step on `HoneyDrunk.Kernel` after packet 03 merges).

**Constraints:**
- Replace, not extend — the old AI-side `ICostLedger` is deleted, not kept alongside.
- `DefaultCostLedger` is a Phase-1 stub — non-durable, no kill-switch enforcement. The Cosmos backing is packet 05.
- One-commit solution-wide version bump (invariant 27).
- Per-package CHANGELOG hygiene (invariant 12/27).
- Do not edit the Architecture-repo catalog from this packet — packet 09 (the playbook) handles the catalog cleanup.

**Key Files:**
- `HoneyDrunk.AI/src/HoneyDrunk.AI.Abstractions/` — deletions + csproj edit.
- Every provider package source + csproj.
- `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/DefaultCostLedger.cs` — rewritten as a stub.
- `HoneyDrunk.AI/src/HoneyDrunk.AI/ServiceCollectionExtensions.cs` — verify DI registration.
- Every CHANGELOG with a real change; repo-level `CHANGELOG.md`; `HoneyDrunk.AI.Abstractions/README.md`.

**Contracts:**
- Removed: `HoneyDrunk.AI.Abstractions.ICostLedger`, `InferenceCost`, `CostSummary`.
- Consumed: `HoneyDrunk.Kernel.Abstractions.ICostLedger`, `CostEvent`, `CostCategory`, `LlmInferenceSource`, `CostEnvironment`.
