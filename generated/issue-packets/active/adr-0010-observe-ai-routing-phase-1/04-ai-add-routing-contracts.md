---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.AI
labels: ["feature", "tier-2", "ai", "contracts", "adr-0010", "blocked", "wave-2"]
dependencies: ["01-architecture-adr-0010-acceptance.md", "honeydrunk-ai-standup-adr-and-scaffold (future initiative)"]
adrs: ["ADR-0010", "ADR-0005"]
wave: 2
initiative: adr-0010-observe-ai-routing-phase-1
node: honeydrunk-ai
status: deferred-pending-ai-standup
---

# Feature: Add `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration` to `HoneyDrunk.AI.Abstractions`

> **STATUS — deferred (2026-04-18):** This packet is parked. The HoneyDrunk.AI GitHub repo exists but is empty. Scaffolding choices for a foundational Node — solution layout, Microsoft.Extensions.AI alignment, package family split, inference-vs-routing contract boundaries, Pulse/Vault integration, first provider — are architectural decisions that deserve their own ADR. Bundling that scaffold into a routing-contracts packet would embed those decisions silently. **Do not file this packet until a HoneyDrunk.AI standup ADR (provisional `ADR-0014-honeydrunk-ai-standup`) is accepted and its scaffolding initiative has shipped `HoneyDrunk.AI.Abstractions` as a minimum-viable Abstractions package.** Once that foundation exists, the packet body below becomes fileable as a strict contracts-addition PR.

## Summary
Add the three AI routing contracts defined in ADR-0010 Phase 1 to `HoneyDrunk.AI.Abstractions`. These contracts make application-code-level model hardcoding architecturally impossible (invariant 28) by providing a single entry point (`IModelRouter`) for model selection, a pluggable policy shape (`IRoutingPolicy`), and a machine-readable capability declaration (`ModelCapabilityDeclaration`) that policies reason over.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.AI`

## Motivation
ADR-0010 Layer 2 extends HoneyDrunk.AI with a routing layer — not a new Node. Until these contracts exist in `HoneyDrunk.AI.Abstractions`, invariant 28 ("application code must never hardcode a model name or provider") is unenforceable: callers have no alternative surface to target. This packet ships the contract surface only; the runtime `IModelRouter` implementation, cost-first `IRoutingPolicy`, and App Configuration wiring are Phase 2 deliverables.

## Prerequisite — HoneyDrunk.AI standup ADR + initiative

The HoneyDrunk.AI repo is empty as of 2026-04-18. This packet is intentionally narrow (contracts-addition, tier-2). It assumes `HoneyDrunk.AI.Abstractions` already exists with at least a `.csproj`, `HoneyDrunk.Standards` reference, README, and CHANGELOG. Scaffolding the package is **not in scope** here.

Before this packet can be filed:
1. A new ADR — provisionally `ADR-0014-honeydrunk-ai-standup` — must be drafted and accepted covering: solution layout, Microsoft.Extensions.AI alignment strategy, package family split (Abstractions / runtime / providers), inference-vs-routing contract boundaries, Pulse integration posture, Vault-backed credential model, and first provider (likely OpenAI or Anthropic).
2. A scoping/execution initiative derived from that ADR must ship the first-commit scaffold of `HoneyDrunk.AI`, including a minimum-viable `HoneyDrunk.AI.Abstractions` package.
3. Once (1) and (2) land, the AI routing contracts below become an additive PR on the existing Abstractions package.

If packet 04 is instead filed before the standup ADR, the executor must stop and flag rather than improvise a full repo scaffold. Silent scope creep in a foundational AI-sector Node is exactly the failure mode ADRs exist to prevent.

## Scope

Target package: **`HoneyDrunk.AI.Abstractions`** (assumed to already exist at packet-fileable time per the prerequisite above).

### Contracts to add

Three interfaces, all with full XML documentation (invariant 13):

- **`IModelRouter`** — Given a request with declared capability requirements, selects the appropriate model/provider. Suggested members: async `SelectAsync(IModelRouterRequest request, CancellationToken ct)` returning a selection result (provider identity, model identity, reasoning trace or policy-name for telemetry). Exact request/response shapes are at executor discretion — constraint: callers declare **what they need** (context size, modality, function calling, cost tier), not **which model**.
- **`IRoutingPolicy`** — Pluggable policy interface. Suggested members: `PolicyName`, async `EvaluateAsync(IModelRouterRequest request, IReadOnlyCollection<ModelCapabilityDeclaration> candidates, CancellationToken ct)` returning the selected capability declaration. First-wave policy kinds named in ADR-0010: cost-first, capability-first, latency-first, compliance-first — the interface must accommodate all four (all reduce to "rank candidates by some criterion").
- **`ModelCapabilityDeclaration`** — Machine-readable declaration of what a model can do. Suggested members: provider identity, model identity, context-window size, supported modalities (text/vision/audio — enum or flags), function-calling support (bool or enum), cost tier (per-token or tier-bucket), any other capability dimensions an executor finds necessary.

### Package updates

- `src/HoneyDrunk.AI.Abstractions/IModelRouter.cs` (new)
- `src/HoneyDrunk.AI.Abstractions/IRoutingPolicy.cs` (new)
- `src/HoneyDrunk.AI.Abstractions/ModelCapabilityDeclaration.cs` (new)
- `src/HoneyDrunk.AI.Abstractions/README.md` — add routing contracts to the public API surface list
- `src/HoneyDrunk.AI.Abstractions/CHANGELOG.md` — new version entry describing routing contracts addition
- Repo-level `CHANGELOG.md` (next to `.slnx`) — new version entry for the solution (invariant 27 — this is likely the first packet landing on HoneyDrunk.AI's solution in this initiative, so it is the bumping packet)
- All `.csproj` files in the solution (excluding test projects) updated to the same new version (invariant 27)

## Acceptance Criteria

- [ ] **Preflight (must pass before PR is opened):** `HoneyDrunk.AI.Abstractions` already exists in the target repo as part of a prior standup initiative. If the package is still absent, STOP — do not scaffold from this packet. Flag the missing prerequisite and request the AI standup ADR (`ADR-0014-honeydrunk-ai-standup` or successor) be drafted and its scaffolding initiative executed first.
- [ ] `HoneyDrunk.AI.Abstractions` contains the three new interfaces after this PR
- [ ] `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration` defined with full XML documentation (invariant 13)
- [ ] Abstractions project has zero runtime HoneyDrunk dependencies; only `Microsoft.Extensions.*` abstractions permitted (invariant 1)
- [ ] `HoneyDrunk.Standards` referenced with `PrivateAssets="all"` (invariant 26)
- [ ] Per-package `CHANGELOG.md` updated with the routing-contracts entry (invariant 12)
- [ ] Per-package `README.md` public-API section mentions the three new contracts (invariant 12)
- [ ] Repo-level `CHANGELOG.md` appends an entry (invariant 27 — whether this is a bumping packet depends on the state at filing time: if the AI standup initiative left the solution on an unreleased in-progress version, append only; if a release has shipped in between, this packet bumps)
- [ ] Every `.csproj` in the solution (excluding test projects) stays on the same version after this PR (invariant 27 — no partial bumps)
- [ ] **Cross-repo edit**: the PR includes a companion edit to `HoneyDrunk.Architecture/constitution/invariants.md` — invariant 28's `(Proposed — this invariant takes effect when ADR-0010 is accepted)` qualifier is removed once this PR merges. Because `HoneyDrunk.AI` and `HoneyDrunk.Architecture` are separate repos, this is coordinated as a paired PR (or a follow-up Architecture PR filed by the executor the moment this PR merges). The qualifier flip must happen atomically with `IModelRouter` shipping — not before (invariant would be transiently unsatisfiable), not long after (invariant would read stale). A simple convention: open the Architecture PR from the same branch-name suffix and merge it within the same hour as the AI PR.
- [ ] PR traverses tier-1 gate before merge
- [ ] PR body links back to this packet

## NuGet Dependencies

`src/HoneyDrunk.AI.Abstractions/HoneyDrunk.AI.Abstractions.csproj`:
- `<PackageReference Include="HoneyDrunk.Standards" Version="..." PrivateAssets="all" />` (required on every .NET project — invariant 26)
- No other runtime HoneyDrunk package references (invariant 1)
- Optional: `Microsoft.Extensions.AI.Abstractions` if the executor finds the routing contracts benefit from alignment with Microsoft's inference abstractions; not required

This packet does not scaffold the package. The project metadata (TargetFramework, nullable, implicit usings, HoneyDrunk.Standards reference) is assumed already in place from the AI standup initiative.

## Affected Packages
- `HoneyDrunk.AI.Abstractions` (additive edit — three new interface files, README/CHANGELOG updates)

## Boundary Check
- [x] Work belongs in `HoneyDrunk.AI` — routing is an extension of the existing AI Node per ADR-0010, not a new Node
- [x] Contracts only; no runtime, no policy implementations, no App Configuration integration — all Phase 2
- [x] Does not touch provider adapters (OpenAI, Anthropic, etc.) — those already conform to the slot pattern and are orthogonal

## Human Prerequisites
- [ ] `HoneyDrunkStudios/HoneyDrunk.AI` repo exists and is accessible — **verified 2026-04-18 at https://github.com/HoneyDrunkStudios/HoneyDrunk.AI (HTTP 200)**; repo confirmed empty (no scaffold yet)
- [ ] HoneyDrunk.AI standup ADR (provisional `ADR-0014-honeydrunk-ai-standup`) drafted, accepted, and its scaffolding initiative executed, resulting in a minimum-viable `HoneyDrunk.AI.Abstractions` package. Without this, the packet is not fileable.

## Dependencies
- `01-architecture-adr-0010-acceptance.md` — `catalogs/contracts.json` must list the three routing interfaces under `honeydrunk-ai` before this PR is merged
- **HoneyDrunk.AI standup ADR + initiative** — must ship `HoneyDrunk.AI.Abstractions` before this packet is fileable (see Prerequisite section above)

## Downstream Unblocks
- Phase 2 packets: runtime `ModelRouter` implementation in `HoneyDrunk.AI`, cost-first `IRoutingPolicy` implementation, App Configuration loader for policies (per invariant 28 and ADR-0005), first application-code migration to use `IModelRouter` instead of hardcoded model names

## Referenced ADR Decisions

**ADR-0010 (Observation Layer and AI Routing):**
- **§Layer 2 — AI Routing:** Not a new Node; an extension of HoneyDrunk.AI's existing responsibility. The AI Node already owns `IModelProvider` (provider slot). Routing adds `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration`.
- **§New contracts within HoneyDrunk.AI:**
  - `IModelRouter` — given a request with declared capability requirements, select the appropriate model/provider
  - `IRoutingPolicy` — pluggable policy interface (cost-first, capability-first, latency-first, compliance-first)
  - `ModelCapabilityDeclaration` — machine-readable declaration of what a model can do (context window, modalities, function calling support, cost tier)
- **§Routing policy storage:** Policies live in Azure App Configuration (ADR-0005) and are loaded at startup via `IConfigProvider` (Vault Node). No policies are hardcoded in application code. *(Storage wiring is Phase 2, not this packet — but the contract shapes must permit policies to be deserialized from App Configuration, i.e., they should be composed of JSON-friendly primitives, not opaque delegates.)*
- **§Does NOT own:** Model execution (still `IChatClient` / `IEmbeddingGenerator`) — do not modify those; safety controls (Operator); evaluation (Evals).

**ADR-0005 (Configuration and Secrets Strategy):** Three-tier config split — secrets in Key Vault, non-secret config in shared App Configuration, env vars bootstrap-only. Routing policies are non-secret, operator-tunable config → App Configuration is their home. Contracts defined in this packet must be deserializable from App Configuration key-value pairs.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only Microsoft.Extensions.* abstractions are permitted.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Repo-level CHANGELOG.md mandatory; per-package CHANGELOG updated for packages with actual changes. Every package directory must contain a README.md.

> **Invariant 13:** All public APIs have XML documentation.

> **Invariant 26:** HoneyDrunk.Standards must be explicitly listed on every new .NET project (PrivateAssets: all).

> **Invariant 27:** All projects in a solution share one version and move together. The first packet to land on a solution in an initiative bumps the version; subsequent packets on the same solution append to the CHANGELOG only. The repo-level CHANGELOG.md must always get an entry for the new version. Partial bumps are forbidden.

> **Invariant 28:** Application code must never hardcode a model name or provider. All model selection goes through IModelRouter in HoneyDrunk.AI. Routing policies are stored in App Configuration (ADR-0005) and are operator-configurable without a redeploy.

## Constraints

- **Contracts only — no implementations.** Do not ship a `ModelRouter` runtime class, a `CostFirstRoutingPolicy`, or App Configuration loaders in this packet. Those are Phase 2. This packet keeps the surface clean for parallel contract review.
- **Contracts must be JSON-serializable.** Policies live in App Configuration (ADR-0005). The shapes defined here must be composable from JSON primitives (strings, numbers, enums) so a Phase 2 loader can deserialize them without bespoke converters. Avoid delegates, `Func<>`, or captured lambdas in the contract surface.
- **Align with `Microsoft.Extensions.AI` where natural.** The `HoneyDrunk.AI` overview calls out alignment with `Microsoft.Extensions.AI`. If routing concepts have obvious analogues in that library, align the shapes; do not invent competing abstractions for their own sake.
- **Zero runtime HoneyDrunk dependencies on Abstractions** (invariant 1).
- **Version bump discipline** (invariant 27). This is the first packet landing on `HoneyDrunk.AI`'s solution in this initiative — it is the bumping packet. All `.csproj` files in the solution (excluding tests) move to the same new version in one commit. Partial bumps are forbidden.
- **No ADR IDs in README prose body** (user preference — ADR IDs stay in CHANGELOG entries and frontmatter, out of narrative sections).
- **Do not modify existing AI contracts** (`IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, `IInferenceResult`). The routing contracts are additive.

## Labels
`feature`, `tier-2`, `ai`, `contracts`, `adr-0010`, `wave-2`

## Agent Handoff

**Objective:** Add the three AI routing contracts (`IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration`) to `HoneyDrunk.AI.Abstractions`, scaffolding the package minimally if it does not yet exist. Contract surface only — no runtime, no policy implementations, no App Configuration wiring.

**Target:** HoneyDrunk.AI, branch from `main`

**Context:**
- Goal: Make invariant 28 enforceable by giving callers a routing surface to target instead of hardcoded model names
- Feature: ADR-0010 Phase 1 — Layer 2 contracts (AI routing)
- ADRs: ADR-0010 (primary), ADR-0005 (App Configuration is the home for routing policies — shape contracts to be JSON-friendly)

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `01-architecture-adr-0010-acceptance.md` — `contracts.json` listing and invariant 28 finalization must land first (parallel authoring OK, merge gate only)

**Constraints:**

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only Microsoft.Extensions.* abstractions are permitted.

> **Invariant 13:** All public APIs have XML documentation.

> **Invariant 26:** HoneyDrunk.Standards must be explicitly listed on every new .NET project (PrivateAssets: all).

> **Invariant 27:** First packet on a solution bumps the version; every `.csproj` in the solution (excluding tests) moves to the same version in one commit.

> **Invariant 28:** Application code must never hardcode a model name or provider. All model selection goes through IModelRouter. Routing policies are stored in App Configuration and are operator-configurable without a redeploy.

- Contracts only — no runtime, no policies
- JSON-serializable shapes (no delegates in the contract surface) so App Configuration can carry policies
- Do not modify existing AI contracts (`IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, `IInferenceResult`)
- No ADR IDs in README narrative body

**Key Files:**

In `HoneyDrunk.AI` (all assumed present from AI standup initiative; this packet is additive):
- `src/HoneyDrunk.AI.Abstractions/IModelRouter.cs` (new)
- `src/HoneyDrunk.AI.Abstractions/IRoutingPolicy.cs` (new)
- `src/HoneyDrunk.AI.Abstractions/ModelCapabilityDeclaration.cs` (new)
- `src/HoneyDrunk.AI.Abstractions/README.md` (update — add routing contracts to public API list)
- `src/HoneyDrunk.AI.Abstractions/CHANGELOG.md` (update — add routing contracts entry)
- `CHANGELOG.md` (repo root — update)
- `.csproj` version alignment per invariant 27 if a version bump is warranted

In `HoneyDrunk.Architecture` (paired PR — see cross-repo acceptance criterion above):
- `constitution/invariants.md` — remove the `(Proposed — this invariant takes effect when ADR-0010 is accepted)` qualifier from invariant 28, making it read as a live enforceable rule the moment `IModelRouter` ships

**Contracts:**
- `IModelRouter` — policy-driven model selection entry point
- `IRoutingPolicy` — pluggable selection strategy
- `ModelCapabilityDeclaration` — machine-readable model capability shape
