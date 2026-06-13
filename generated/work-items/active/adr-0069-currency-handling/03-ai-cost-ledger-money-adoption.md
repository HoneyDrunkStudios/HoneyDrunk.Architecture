---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.AI
labels: ["feature", "tier-2", "ai", "adr-0069", "wave-3"]
dependencies: ["work-item:02"]
adrs: ["ADR-0069", "ADR-0052"]
wave: 3
initiative: adr-0069-currency-handling
node: honeydrunk-ai
---

# Migrate the AI cost ledger from decimal to Money (USD-explicit)

## Summary
Migrate `HoneyDrunk.AI.Abstractions`'s `InferenceCost.EstimatedCost` and `CostSummary.TotalCost` from `decimal` to `Money`, with `CurrencyCode.Usd` as the explicit denomination at Phase 1 per ADR-0069 D10. Update `DefaultCostLedger`'s aggregation to operate on `Money` (sum of same-currency values) and surface the explicit USD denomination. This is the version-bumping packet for the `HoneyDrunk.AI` solution.

## Context
ADR-0069 D10 commits the AI-sector cost-rate cache (per ADR-0052) to **explicit `Money(rate, CurrencyCode.Usd)`** denomination, rather than the implicit `decimal` representation it carries today. The discipline forecloses the "we added a EUR-billed provider and silently treated its rates as USD" class of bug. The current `HoneyDrunk.AI.Abstractions` types:

- `InferenceCost(string ProviderId, string ModelId, int InputTokens, int OutputTokens, decimal EstimatedCost, string OperationCorrelationId)` — a record with a `decimal EstimatedCost` field carrying the implicit-USD inference cost.
- `CostSummary(string Scope, DateTimeOffset Since, DateTimeOffset Until, decimal TotalCost, int TotalCalls)` — a record with a `decimal TotalCost` field carrying the implicit-USD aggregate.
- `ICostLedger.RecordAsync(InferenceCost cost, ...)` and `ICostLedger.GetSummaryAsync(string scope, DateTimeOffset since, ...) → Task<CostSummary>` — the interface contract.

`DefaultCostLedger` (in `HoneyDrunk.AI.Cost`) aggregates `entry.Cost.EstimatedCost` via LINQ `Sum`, returning a `decimal`. The aggregate must be `Money` after this packet, with the currency preserved through the summation.

**Cross-Node version dependency.** This packet builds against the new `Money`/`CurrencyCode` surface shipped by packet 02 in `HoneyDrunk.Kernel`. The package reaches the NuGet feed only after a human tags/releases the `HoneyDrunk.Kernel` solution version that ships the new surface. This is the Wave 2→3 boundary's Human Prerequisite.

`HoneyDrunk.AI` is a live Node currently at version `0.1.0` (from `Directory.Build.props`) using `.NET 10.0`. This packet is the first packet on the AI solution in this initiative — per invariant 27 it bumps every non-test `.csproj` to the same new minor version (likely `0.1.0` → `0.2.0`; confirm at edit time). Per-package CHANGELOG: `HoneyDrunk.AI.Abstractions` gets an entry (changed surface); `HoneyDrunk.AI` gets an entry (runtime aggregation logic changed); the provider packages and the worker get no per-package CHANGELOG entry (alignment bump only — invariant 12).

**Breaking change.** Changing `InferenceCost.EstimatedCost` from `decimal` to `Money` and `CostSummary.TotalCost` from `decimal` to `Money` is a **breaking shape change** on `HoneyDrunk.AI.Abstractions`. Per ADR-0035 the pre-1.0 disclaimer applies — pre-1.0 Abstractions carry no compatibility promise — but this is still a real surface break and any internal callers must be updated in the same commit. Search `HoneyDrunk.AI` for every `InferenceCost(...)` construction and every `cost.EstimatedCost` / `summary.TotalCost` read; update each to the `Money` shape. The version bump (minor, since pre-1.0) reflects the additive-and-substitutive nature of the change.

**Aggregation discipline.** `DefaultCostLedger`'s `GetSummaryAsync` sums `EstimatedCost` across entries via LINQ `Sum`. After this change, the sum is `Money` and **must** respect the currency-mismatch rule (D2: cross-currency `+` throws). At Phase 1 every recorded entry is `Money(rate, CurrencyCode.Usd)` (every current AI provider — OpenAI, Anthropic, Azure OpenAI — bills in USD). If a future provider lands with a non-USD billing currency, the LINQ `Sum` over mixed currencies will throw `CurrencyMismatchException` at the read site — that throw is the **correct, deliberate behavior** per ADR-0069 D5 (multi-currency aware, multi-currency converting deferred). It is a load-bearing failure mode: it signals that the cost ledger needs the (deferred) FX-rate service to produce a unified denomination, and prevents a silent miscount. Document this in the `DefaultCostLedger.GetSummaryAsync` XML doc explicitly.

## Downstream-impact (consumers of `InferenceCost.EstimatedCost` and `CostSummary.TotalCost`)

This packet is a **breaking shape change** on `HoneyDrunk.AI.Abstractions` — `decimal EstimatedCost` becomes `Money EstimatedCost`, `decimal TotalCost` becomes `Money TotalCost`. Pre-1.0 disclaimer applies (ADR-0035 D1), but every consumer that reads or constructs these fields must be updated in the same merge window.

**Confirmed scope at packet-authoring time (2026-05-24) — every consumer is inside the `HoneyDrunk.AI` solution.** A Grid-wide search for `HoneyDrunk.AI.Abstractions` `PackageReference` returns only the `HoneyDrunk.AI` solution's own projects. A symbol-level search for `.EstimatedCost`, `.TotalCost`, `new InferenceCost`, and `new CostSummary` field-access / constructor-call sites across the Grid returns:

- **Edited in this packet (primary shape change):**
  - `src/HoneyDrunk.AI.Abstractions/InferenceCost.cs` — `decimal EstimatedCost` → `Money EstimatedCost`
  - `src/HoneyDrunk.AI.Abstractions/CostSummary.cs` — `decimal TotalCost` → `Money TotalCost`
- **Edited in this packet (consumer refactor):**
  - `src/HoneyDrunk.AI.Abstractions/ICostLedger.cs` — interface signature unchanged (carried types change shape)
  - `src/HoneyDrunk.AI/Cost/DefaultCostLedger.cs` — aggregation rewritten to fold `Money`
  - `tests/HoneyDrunk.AI.Abstractions.Tests/AbstractionsSmokeTests.cs` — constructor calls + field reads updated
  - `tests/HoneyDrunk.AI.Tests/RuntimeTests.cs` — constructor calls + field reads updated
- **Tag/constant references (no shape change needed):**
  - `src/HoneyDrunk.AI/Telemetry/InferenceTelemetry.cs` — carries an `EstimatedCostTag` string constant (`"honeydrunk.ai.estimated_cost"`); no field-typed read of `cost.EstimatedCost` in this file today. If telemetry emit logic is added that reads `cost.EstimatedCost.Amount` for tracing, it picks up the new shape via `.Amount`; out of scope for this packet.
- **Verified clean (not field consumers):**
  - `src/HoneyDrunk.AI/Routing/CostFirstRoutingPolicy.cs`, `src/HoneyDrunk.AI/Routing/DefaultModelRouter.cs`, `src/HoneyDrunk.AI/Routing/PolicyLoader.cs`, `src/HoneyDrunk.AI/ServiceCollectionExtensions.cs`, `src/HoneyDrunk.AI.Providers.*/*.cs`, `tests/HoneyDrunk.AI.Providers.InMemory.Tests/InMemoryProviderTests.cs` — none of these directly read `.EstimatedCost`/`.TotalCost` or construct `InferenceCost`/`CostSummary` today. The executor still re-greps for `EstimatedCost`/`TotalCost`/`InferenceCost`/`CostSummary` at edit time in case the surface drifts between packet authoring and execution.

**No external (Capabilities / Operator / Agents / Memory / Knowledge / Evals) consumers exist today.** Those Nodes do not take a `PackageReference` on `HoneyDrunk.AI.Abstractions`; the cost ledger is consumed only inside the AI Node. This forecloses the cross-Node version-race risk for this packet — every consumer is in the same solution and is updated in the same commit.

**Future-cross-Node guidance.** If a future Node (e.g., `HoneyDrunk.Capabilities`, `HoneyDrunk.Operator`, `HoneyDrunk.Agents`, `HoneyDrunk.Memory`, `HoneyDrunk.Knowledge`, `HoneyDrunk.Evals`) takes a `PackageReference` on `HoneyDrunk.AI.Abstractions` after this packet ships, that Node's first cost-ledger consumer commit must pick up the new shape from the released `HoneyDrunk.AI.Abstractions` version. The `Money` adoption is recorded in:

- `HoneyDrunk.AI.Abstractions/CHANGELOG.md` under the version this packet ships — entry must read along the lines of "BREAKING: `InferenceCost.EstimatedCost` and `CostSummary.TotalCost` changed from `decimal` to `Money` (ADR-0069 D10). Consumers must reference `HoneyDrunk.Kernel.Abstractions` and update their construction / read sites."
- `HoneyDrunk.AI/CHANGELOG.md` — the `DefaultCostLedger` aggregation update with the cross-currency throw note.
- The repo-level `CHANGELOG.md` carries the BREAKING note at version-entry level.

**Release-notes guidance for the AI Node.** When the human releases the `HoneyDrunk.AI` solution after this packet's merge, the release notes (per-Node release process) flag the `Money` adoption as a **breaking pre-1.0 shape change**, list the call-site update pattern (`new InferenceCost(..., Money.Usd(decimalCost), ...)` and `summary.TotalCost.Amount` if a `decimal` is still genuinely needed), and link back to ADR-0069 D10. This is the signal future-Node-adopters look for.

## Scope
- `src/HoneyDrunk.AI.Abstractions/InferenceCost.cs` — change `decimal EstimatedCost` to `Money EstimatedCost`. Update the XML doc.
- `src/HoneyDrunk.AI.Abstractions/CostSummary.cs` — change `decimal TotalCost` to `Money TotalCost`. Update the XML doc.
- `src/HoneyDrunk.AI.Abstractions/HoneyDrunk.AI.Abstractions.csproj` — add `<PackageReference Include="HoneyDrunk.Kernel.Abstractions" Version="{the version shipped by packet 02}" />` (confirm with the released version).
- `src/HoneyDrunk.AI/Cost/DefaultCostLedger.cs` — update `GetSummaryAsync` to sum `Money` values via `Aggregate`. Seed selection (spelled out): on empty scope, seed `Money.Zero(CurrencyCode.Usd)`; on non-empty scope, seed `Money.Zero(scoped[0].Cost.EstimatedCost.CurrencyCode)` so the fold returns the same currency the entries carry. Document the cross-currency throw behavior in XML doc.
- Every internal call site that constructs `InferenceCost(...)` or reads `cost.EstimatedCost` / `summary.TotalCost` — provider packages, runtime tests, anywhere in `HoneyDrunk.AI*` that touches the shape. Search the repo and update each.
- All non-test `.csproj` files in the solution version-bumped together (invariant 27).
- `HoneyDrunk.AI.Abstractions/CHANGELOG.md` (real change) and `HoneyDrunk.AI/CHANGELOG.md` (real change). Provider/worker packages: alignment bump only, no per-package CHANGELOG entry.
- Repo-level `CHANGELOG.md` gets a new version entry.
- `HoneyDrunk.AI.Abstractions/README.md` updated for the new public-API surface shape.

## Proposed Implementation
1. **Add the Kernel.Abstractions package reference.** In `src/HoneyDrunk.AI.Abstractions/HoneyDrunk.AI.Abstractions.csproj`, add `<PackageReference Include="HoneyDrunk.Kernel.Abstractions" Version="X.Y.Z" />` where `X.Y.Z` is the released version from packet 02. Confirm the version is published on the feed before editing (this is the Wave 2→3 Human Prerequisite).
2. **`InferenceCost`** — change the constructor signature: `public sealed record InferenceCost(string ProviderId, string ModelId, int InputTokens, int OutputTokens, Money EstimatedCost, string OperationCorrelationId)`. Update the XML doc for `EstimatedCost` to describe `Money` semantics: "Per-currency-aware estimated cost. At Phase 1 every AI provider bills in USD; `Money` carries `CurrencyCode.Usd` explicitly per ADR-0069 D10."
3. **`CostSummary`** — change the constructor signature: `public sealed record CostSummary(string Scope, DateTimeOffset Since, DateTimeOffset Until, Money TotalCost, int TotalCalls)`. Update the XML doc for `TotalCost`.
4. **`DefaultCostLedger.GetSummaryAsync`** — replace `var totalCost = scoped.Sum(entry => entry.Cost.EstimatedCost);` with a `Money`-respecting aggregate. **Two seed cases, spelled out:**

   - **Empty scope** — `scoped.Length == 0`: seed is `Money.Zero(CurrencyCode.Usd)`. The Phase-1 default per ADR-0069 D10 — USD is the Grid-default currency, and an empty cost summary reads naturally as zero USD.
   - **Non-empty scope** — `scoped.Length > 0`: seed is `Money.Zero(scoped[0].Cost.EstimatedCost.CurrencyCode)`. Use the first entry's currency as the seed so the fold returns the same currency the entries denominate in. If every entry is USD (Phase 1), this is `Money.Zero(CurrencyCode.Usd)`. If a non-USD provider ever appears, the seed picks up that currency from the first entry; subsequent entries with a different currency throw `CurrencyMismatchException` via the `+` operator (D2) — which is the deliberate FX-service-gap signal per ADR-0069 D5.

   Implementation sketch:
   ```csharp
   var seed = scoped.Length == 0
       ? Money.Zero(CurrencyCode.Usd)
       : Money.Zero(scoped[0].Cost.EstimatedCost.CurrencyCode);
   var totalCost = scoped.Aggregate(seed, (acc, entry) => acc + entry.Cost.EstimatedCost);
   ```
   Cross-currency entries within a non-empty scope trigger `CurrencyMismatchException` at the second-entry `+` — that throw is deliberate per ADR-0069 D5 and surfaces the "deferred FX-rate service" gap rather than silently miscounting.
5. **XML-doc the cross-currency throw.** `DefaultCostLedger.GetSummaryAsync`'s XML doc must include: "Throws `CurrencyMismatchException` if the recorded entries span multiple currencies. At Phase 1 every AI provider bills in USD; mixed-currency aggregation requires the FX-rate service (out of scope per ADR-0069 D5 / D12)."
6. **Update every call site** in `src/HoneyDrunk.AI/`, `src/HoneyDrunk.AI.Providers.*/`, `tests/HoneyDrunk.AI.Tests/`, `tests/HoneyDrunk.AI.Abstractions.Tests/`, `tests/HoneyDrunk.AI.Providers.InMemory.Tests/`. Every `new InferenceCost(..., estimatedCost, ...)` becomes `new InferenceCost(..., Money.Usd(estimatedCost), ...)`. Every `summary.TotalCost` read that expected `decimal` extracts `.Amount` if a `decimal` is genuinely needed (e.g. for logging) — but prefer to flow `Money` through.
7. **Bump versions.** Every non-test `.csproj` in `HoneyDrunk.AI.slnx` moves to the same new minor (invariant 27). Confirm the source-of-truth version at edit time — `Directory.Build.props` shows `0.1.0` today; if it has moved, take the next minor over `main`'s actual state. Update `HoneyDrunk.AI.Abstractions/CHANGELOG.md` (real change), `HoneyDrunk.AI/CHANGELOG.md` (real change in `DefaultCostLedger`), and the repo-level `CHANGELOG.md`. Provider packages and the worker: alignment bump only, no per-package CHANGELOG entry (invariant 12).
8. **README.** Update `src/HoneyDrunk.AI.Abstractions/README.md` to reflect the new shape of `InferenceCost` and `CostSummary` (invariant 12 — public API surface change).
9. **Tests.** Update unit tests that construct or read these types. Add a test asserting that the `GetSummaryAsync` aggregate's `CurrencyCode` is `Usd` when the scope contains USD entries; add a test asserting that a mixed-currency scope throws `CurrencyMismatchException` (the deliberate failure mode).

## Affected Files
- `src/HoneyDrunk.AI.Abstractions/InferenceCost.cs`
- `src/HoneyDrunk.AI.Abstractions/CostSummary.cs`
- `src/HoneyDrunk.AI.Abstractions/HoneyDrunk.AI.Abstractions.csproj` (Kernel.Abstractions package reference + version bump)
- `src/HoneyDrunk.AI.Abstractions/CHANGELOG.md`, `src/HoneyDrunk.AI.Abstractions/README.md`
- `src/HoneyDrunk.AI/Cost/DefaultCostLedger.cs` (aggregation refactor)
- `src/HoneyDrunk.AI/CHANGELOG.md`
- All other `.csproj` files in `HoneyDrunk.AI.slnx` (alignment version bump)
- Every internal call site that touches `InferenceCost.EstimatedCost` or `CostSummary.TotalCost` (search across `src/HoneyDrunk.AI*/` and `tests/`)
- Repo-level `CHANGELOG.md`

## NuGet Dependencies
- **New:** `HoneyDrunk.Kernel.Abstractions` `X.Y.Z` (the version shipped by packet 02) on `HoneyDrunk.AI.Abstractions`. The Kernel.Abstractions package is the **only** runtime HoneyDrunk dependency added — invariant 1 still holds on Kernel.Abstractions itself (no upstream HoneyDrunk runtime); invariant 1 does not bind downstream Abstractions packages.
- No new test packages — existing test stack covers the new assertions.
- No new packages elsewhere.

## Boundary Check
- [x] All edits in `HoneyDrunk.AI`. Routing rule "AI, cost ledger, model, capability → HoneyDrunk.AI" maps exactly.
- [x] The new HoneyDrunk dependency is `HoneyDrunk.Kernel.Abstractions` only — the canonical zero-dependency contracts package. No cross-Node runtime coupling introduced.
- [x] No change to other Nodes; consumer-side migration is local to the AI Node.

## Acceptance Criteria
- [ ] `InferenceCost.EstimatedCost` is `Money` (was `decimal`); the XML doc reflects the Phase-1 USD-explicit denomination per ADR-0069 D10
- [ ] `CostSummary.TotalCost` is `Money` (was `decimal`); the XML doc reflects the same
- [ ] `HoneyDrunk.AI.Abstractions` takes a `PackageReference` on `HoneyDrunk.Kernel.Abstractions` at the version shipped by packet 02
- [ ] `DefaultCostLedger.GetSummaryAsync` aggregates `Money` correctly when every entry is USD; throws `CurrencyMismatchException` on mixed-currency scopes (deliberate per ADR-0069 D5)
- [ ] `DefaultCostLedger.GetSummaryAsync`'s XML doc documents the cross-currency throw as the deferred-FX-service signal
- [ ] Every internal call site in `HoneyDrunk.AI` solution that constructs `InferenceCost` or reads `EstimatedCost` / `TotalCost` is updated; the solution builds end-to-end
- [ ] Every non-test `.csproj` in the solution is at the same new minor version in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new version entry dated to the merge, describing the `Money` adoption
- [ ] `HoneyDrunk.AI.Abstractions/CHANGELOG.md` has an entry describing the breaking shape change on `InferenceCost.EstimatedCost` and `CostSummary.TotalCost`
- [ ] `HoneyDrunk.AI/CHANGELOG.md` has an entry describing the `DefaultCostLedger` aggregation update
- [ ] Provider packages and the worker (alignment bumps only) get NO per-package CHANGELOG entry (invariant 12)
- [ ] `HoneyDrunk.AI.Abstractions/README.md` reflects the new public-API surface shape
- [ ] Unit tests cover the USD-only happy path and the mixed-currency `CurrencyMismatchException` path
- [ ] No use of `Money.Zero` (no-arg) — D2 forbids zero-without-currency; all seeds are `Money.Zero(CurrencyCode.Usd)` at Phase 1
- [ ] The `pr-core.yml` tier-1 gate passes; any HoneyDrunk.AI canary suite passes (or is updated coherently with the new shape)

## Human Prerequisites
- [ ] `HoneyDrunk.Kernel` solution at the version shipped by packet 02 must be tagged and released to the package feed before this packet's branch can compile. Agents merge code; humans tag/release. See the Wave 2→3 handoff for the release procedure.

## Referenced ADR Decisions
**ADR-0069 D10 — Cost ledger is USD-explicit.** The ADR-0052 in-memory cost-rate cache is denominated in USD at Phase 1. The cache value type is updated to `Money` (rather than raw `decimal`), with `CurrencyCode.Usd` as the implicit constructor. Records the denomination explicitly to foreclose the silent-USD-assumption bug class.

**ADR-0069 D5 — Multi-currency aware, not multi-currency converting.** The Grid stores in the source currency; aggregate-revenue reporting that requires a single denomination performs FX conversion at read time against an FX-rate service (deferred per D12). At the AI cost ledger today, every recorded entry is USD; mixed-currency aggregation is not supported and the `CurrencyMismatchException` is the load-bearing signal that the deferred FX-rate service is needed.

**ADR-0069 D1 — `Money` shape.** `Money(decimal Amount, CurrencyCode CurrencyCode)`. Static factories include `Money.Usd(decimal)`. `Money.Zero(CurrencyCode)` is the only zero shortcut.

**ADR-0069 D2 — Cross-currency arithmetic throws.** `Money + Money` with different currencies throws `CurrencyMismatchException`. The throw is the deliberate failure mode for mixed-currency aggregation in `DefaultCostLedger.GetSummaryAsync`.

**ADR-0052 (referenced) — `ICostLedger` policy.** The AI cost ledger is the operationally-live consumer ADR-0069 D10 amends.

**ADR-0035 D1 / pre-1.0 disclaimer (referenced) — pre-1.0 breaking change semantics.** `HoneyDrunk.AI.Abstractions` is pre-1.0; substitutive shape changes are permitted without major bump, but a minor bump still moves the version. Every non-test `.csproj` in the solution shares the bump (invariant 27).

## Constraints
- **Invariant 27 — solution-wide version bump in one commit.** Every non-test `.csproj` moves together. Partial bumps are forbidden.
- **Invariant 12 — per-package CHANGELOGs only for packages with functional changes.** `HoneyDrunk.AI.Abstractions` and `HoneyDrunk.AI` get entries; provider/worker packages (alignment bumps only) get none.
- **Invariant 13 — XML docs on every public API.** Updated for the new shape.
- **Invariant 1 (referenced) — does not bind here.** `HoneyDrunk.AI.Abstractions` is a downstream Abstractions package; taking a dependency on `HoneyDrunk.Kernel.Abstractions` is allowed (Kernel.Abstractions is the canonical zero-dependency contracts package every downstream Abstractions package is permitted to consume).
- **No `Money.Zero` (no-arg).** D2 forbids zero-without-currency. Phase-1 aggregator seed is `Money.Zero(CurrencyCode.Usd)`.
- **Cross-currency throw is deliberate.** D5 — do not silently convert; do not hide the exception. XML-doc it as the FX-service gap signal.
- **No FX-rate service.** D12 — out of scope here. If a non-USD provider is added later, the FX-rate service ADR commits the provider; this packet does not pre-build it.

## Labels
`feature`, `tier-2`, `ai`, `adr-0069`, `wave-3`

## Agent Handoff

**Objective:** Migrate the AI cost ledger from `decimal` to `Money(amount, CurrencyCode.Usd)` per ADR-0069 D10; preserve the deliberate cross-currency throw as the deferred-FX-service signal.

**Target:** `HoneyDrunk.AI`, branch from `main`.

**Context:**
- Goal: Make the cost-rate denomination explicit; foreclose the silent-USD-assumption bug class; deliver ADR-0069 D10's commitment.
- Feature: ADR-0069 Currency Handling rollout, Wave 3 — AI cost-ledger adoption.
- ADRs: ADR-0069 D1/D2/D5/D10/D12 (primary), ADR-0052 (cost-governance — the policy this amends), ADR-0035 (pre-1.0 versioning).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` — `Money`/`CurrencyCode` must exist in `HoneyDrunk.Kernel.Abstractions` and the Kernel package must be released on the feed before this packet can compile.

**Constraints:**
- The cross-currency `CurrencyMismatchException` from `DefaultCostLedger.GetSummaryAsync` is the **deliberate** failure mode — do not catch and silently convert; do not hide. Document it in XML doc as the deferred-FX-service signal.
- `Money.Zero(CurrencyCode.Usd)` is the Phase-1 aggregator seed. No `Money.Zero` (no-arg) — D2 forbids it.
- Every non-test `.csproj` in the solution version-bumped in one commit (invariant 27).
- Per-package CHANGELOGs only for `HoneyDrunk.AI.Abstractions` and `HoneyDrunk.AI` (real changes). Provider/worker packages: no per-package entry (alignment bumps only).
- Search the entire solution for `InferenceCost` constructions and `EstimatedCost`/`TotalCost` reads; update each. The change is breaking on `HoneyDrunk.AI.Abstractions` but pre-1.0, so a minor bump is sufficient.

**Key Files:**
- `src/HoneyDrunk.AI.Abstractions/InferenceCost.cs`
- `src/HoneyDrunk.AI.Abstractions/CostSummary.cs`
- `src/HoneyDrunk.AI.Abstractions/HoneyDrunk.AI.Abstractions.csproj`
- `src/HoneyDrunk.AI/Cost/DefaultCostLedger.cs`
- All other `.csproj` files in `HoneyDrunk.AI.slnx` (alignment version bump)
- `HoneyDrunk.AI.Abstractions/CHANGELOG.md`, `README.md`; `HoneyDrunk.AI/CHANGELOG.md`; repo-level `CHANGELOG.md`
- Every call site that touches the migrated fields

**Contracts:**
- `InferenceCost` (existing record, breaking field type change) — `EstimatedCost` is now `Money`.
- `CostSummary` (existing record, breaking field type change) — `TotalCost` is now `Money`.
- `ICostLedger` (existing interface, unchanged) — the interface members' signatures don't change; the carried types do.
- New dependency: `HoneyDrunk.Kernel.Abstractions` `X.Y.Z` (`Money`, `CurrencyCode`).
