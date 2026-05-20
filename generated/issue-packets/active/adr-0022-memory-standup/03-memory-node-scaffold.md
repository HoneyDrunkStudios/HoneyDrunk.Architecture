---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Memory
labels: ["feature", "tier-2", "ai", "scaffold", "adr-0022"]
dependencies: ["packet:01", "packet:02", "packet:02b"]
adrs: ["ADR-0022", "ADR-0016", "ADR-0020"]
accepts: ADR-0022
wave: 3
initiative: adr-0022-memory-standup
node: honeydrunk-memory
---

# Feature: Stand up the HoneyDrunk.Memory repo — solution, three packages, contracts, CI, InMemory provider

## Summary

Bring `HoneyDrunk.Memory` from zero to first-shippable per ADR-0022. Land the solution, three packages (`Abstractions`, runtime, `Providers.InMemory`), three D3 interfaces in Abstractions, the `MemoryEntry` record (per-entry metadata including embedding-model identifier per D10), default runtime composing AI's `IEmbeddingGenerator` + `IChatClient` (per D5) and Auth's `IAuthorizationPolicy` (per D6), in-memory provider, standard CI, contract-shape canary scoped to Abstractions per D12 (number assigned by packet 02).

Unblocks Agents (`IAgentMemory` composition per ADR-0020 D6), Flow (indirectly via Agents), Sim (fixture composition), Evals (fixture composition), Lore (curation persistence), HoneyHub when live.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Memory`

## Motivation

ADR-0022 establishes Memory's contract surface. Repo is cloned (LICENSE + README only).

## Proposed Implementation

### Repository layout

```
HoneyDrunk.Memory/
├── HoneyDrunk.Memory.slnx
├── Directory.Build.props
├── CHANGELOG.md
├── README.md
├── .editorconfig
├── .gitignore
├── .github/workflows/{pr-core,release,nightly-deps,nightly-security,api-compatibility}.yml
├── src/
│   ├── HoneyDrunk.Memory.Abstractions/
│   │   ├── HoneyDrunk.Memory.Abstractions.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── IMemoryStore.cs
│   │   ├── IMemoryScope.cs
│   │   ├── IMemorySummarizer.cs
│   │   ├── MemoryEntry.cs
│   │   └── (query/scope request/response records)
│   ├── HoneyDrunk.Memory/
│   │   ├── HoneyDrunk.Memory.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── ServiceCollectionExtensions.cs
│   │   ├── Storage/DefaultMemoryStore.cs
│   │   ├── Scope/DefaultMemoryScope.cs           (composes Auth for Escalate())
│   │   ├── Summarization/DefaultMemorySummarizer.cs  (composes IEmbeddingGenerator + IChatClient)
│   │   └── Telemetry/MemoryTelemetry.cs
│   └── HoneyDrunk.Memory.Providers.InMemory/
│       ├── HoneyDrunk.Memory.Providers.InMemory.csproj
│       ├── README.md
│       ├── CHANGELOG.md
│       └── InMemoryMemoryStore.cs
└── tests/
    ├── HoneyDrunk.Memory.Abstractions.Tests/
    ├── HoneyDrunk.Memory.Tests/
    └── HoneyDrunk.Memory.Providers.InMemory.Tests/
```

### Contract details — `HoneyDrunk.Memory.Abstractions`

```csharp
// IMemoryStore.cs
namespace HoneyDrunk.Memory.Abstractions;

using HoneyDrunk.Kernel.Abstractions.Identity;  // TenantId, ProjectId

public interface IMemoryStore
{
    Task WriteAsync(MemoryEntry entry, IMemoryScope scope, CancellationToken cancellationToken = default);
    Task<MemoryEntry?> ReadAsync(string entryId, IMemoryScope scope, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<MemoryEntry>> SearchAsync(MemoryStoreQuery query, IMemoryScope scope, CancellationToken cancellationToken = default);
    Task DeleteAsync(string entryId, IMemoryScope scope, CancellationToken cancellationToken = default);
    Task SupersedeAsync(string entryId, MemoryEntry replacement, IMemoryScope scope, CancellationToken cancellationToken = default);
}

public sealed record MemoryStoreQuery(string? QueryText, float[]? QueryEmbedding, IReadOnlyDictionary<string, string> Filters, int MaxResults, string EmbeddingModelIdentifier);
```

> **Naming note — record name disambiguation from Agents.** Memory's query record is `MemoryStoreQuery`, not `MemoryQuery`. `HoneyDrunk.Agents.Abstractions` exposes `IAgentMemory` with its own `MemoryWriteRequest` / `MemoryQueryRequest` / `MemoryReadResult` record family (those are the agent-facing intent shapes that lower onto Memory's `MemoryEntry` / `MemoryStoreQuery`). Per Agents' own refine, the Agents-side records will be renamed to `AgentMemoryWriteRequest` / `AgentMemoryQueryRequest` / `AgentMemoryReadResult`. Memory's lower-layer storage shape is named `MemoryStoreQuery` (note the `Store` qualifier) so the boundary is visibly distinct on both sides — Agents' `AgentMemoryQueryRequest` lowers into Memory's `MemoryStoreQuery`. The persisted shape (`MemoryEntry`) keeps its plain name because the read result on the Agents side lifts back from `MemoryEntry`, not the other way around.

```csharp
// IMemoryScope.cs
using HoneyDrunk.Kernel.Abstractions.Identity;  // TenantId, ProjectId

public interface IMemoryScope
{
    TenantId TenantId { get; }
    ProjectId ProjectId { get; }
    string AgentId { get; }   // string until Kernel ships strong AgentId — follow-up packet rotates this once available
    bool IsEscalated { get; }
    Task<IMemoryScope> EscalateAsync(ScopeEscalationRequest request, CancellationToken cancellationToken = default);
}

public sealed record ScopeEscalationRequest(string Reason, string[] RequestedAccess, IReadOnlyDictionary<string, string> Context);
```

```csharp
// IMemorySummarizer.cs
public interface IMemorySummarizer
{
    Task<MemoryEntry> SummarizeAsync(IReadOnlyList<MemoryEntry> entries, SummarizationOptions options, CancellationToken cancellationToken = default);
}

public sealed record SummarizationOptions(int TargetTokenBudget, string EmbeddingModelIdentifier);
```

```csharp
// MemoryEntry.cs (record — no I prefix)
using HoneyDrunk.Kernel.Abstractions.Identity;  // TenantId, ProjectId

public sealed record MemoryEntry(
    string EntryId,
    TenantId TenantId,                  // strong type from Kernel.Abstractions per ADR-0026 D1/D2 (Accepted)
    ProjectId ProjectId,                // strong type from Kernel.Abstractions
    string AgentId,                     // string until Kernel ships strong AgentId — follow-up packet rotates this once available
    string Content,
    float[]? Embedding,
    string EmbeddingModelIdentifier,   // D10 — required for coherence
    DateTimeOffset WrittenAt,
    string? SummaryOfEntryId,           // non-null if this entry summarizes another
    IReadOnlyDictionary<string, string> Metadata);
```

Per invariant 1, `HoneyDrunk.Kernel.Abstractions` is on the allowed list for Abstractions packages alongside `Microsoft.Extensions.*`. **No other HoneyDrunk references in Abstractions** — no AI, no Auth, no Data. `TenantId`/`ProjectId` are strong types from Kernel; `AgentId` stays `string` until Kernel ships the matching strong type.

**Abstractions stance — Kernel-Abstractions is the allowed dependency.** Memory.Abstractions consumes `HoneyDrunk.Kernel.Abstractions` for strong-typed identifiers per invariant 1 (Kernel.Abstractions is the allowed Grid-level abstraction) and per ADR-0026 D1/D2 — Memory is the Grid's authorization boundary for agent-generated content, and stringly-typing tenancy here would re-introduce exactly the footgun ADR-0026 eliminated. `MemoryEntry.EmbeddingModelIdentifier` stays `string`, not `ModelCapabilityDeclaration` (no transitive AI.Abstractions reference at stand-up).

### Boundary with Agents' `IAgentMemory` records

`HoneyDrunk.Agents.Abstractions.IAgentMemory` exposes the agent-facing intent layer:

| Agents (intent layer) | Memory (storage layer) | Direction |
|---|---|---|
| `AgentMemoryWriteRequest` | `MemoryEntry` | lowers into |
| `AgentMemoryQueryRequest` | `MemoryStoreQuery` | lowers into |
| `AgentMemoryReadResult` | `MemoryEntry` | lifts from |

The pair lowering is one-way: Agents owns the agent-side intent records (now name-prefixed with `Agent` per Agents' own refine), Memory owns the storage records. A consumer composing against `IAgentMemory` (the default `IAgentMemory` per ADR-0020 D6) never sees `MemoryEntry` directly — they hand `AgentMemoryWriteRequest` to the agent, the default `IAgentMemory` implementation lowers it into `MemoryEntry` and writes through `IMemoryStore.WriteAsync(MemoryEntry, IMemoryScope, ...)`. The naming (`MemoryStoreQuery` not `MemoryQuery`, `AgentMemoryQueryRequest` not `MemoryQueryRequest`) is what keeps the boundary visible at every callsite.

### Runtime details — `HoneyDrunk.Memory`

`HoneyDrunk.Memory` references:
- `HoneyDrunk.Memory.Abstractions` (project)
- `HoneyDrunk.Kernel.Abstractions` (telemetry, context, `TenantId` / `ProjectId` strong types)
- `HoneyDrunk.AI.Abstractions` (`IEmbeddingGenerator` + `IChatClient` per D5)
- `HoneyDrunk.Auth.Abstractions` (`IAuthorizationPolicy` + `IAuthenticatedIdentityAccessor` for `Escalate` per D6)
- `HoneyDrunk.Data.Abstractions` (`IRepository` + `IUnitOfWork` for non-in-memory persistence — conditional, defer if Data refactor pending)
- Microsoft.Extensions.* (DI, Hosting, Logging)

Default implementations:

- **`DefaultMemoryStore`** — façade; default DI wires `InMemoryMemoryStore` for dev/test.
- **`DefaultMemoryScope`** — composes Auth. `EscalateAsync` consults `IAuthorizationPolicy` against the current identity; denied escalation throws; approved returns a widened scope with `IsEscalated: true`.
- **`DefaultMemorySummarizer`** — calls `IChatClient.CompleteAsync` on the configured summarization prompt, re-embeds the summary via `IEmbeddingGenerator`, writes a new `MemoryEntry` with `SummaryOfEntryId` populated, supersedes originals via `IMemoryStore.SupersedeAsync`.
- **`MemoryTelemetry`** — per-write / per-read / per-summarize / per-supersede activities. **Content NEVER carried** per D9. Only scope coordinates, entry identity, sizes, durations, model identifiers.

> **D3 surface clarification — supersession is the fifth method.** ADR-0022 D3 names four operations (write, read, search, delete) in the body table. D10 introduces supersession as the model-rotation mechanic ("re-embedding an entry under a new model is treated as supersession — the old entry is superseded and a new entry with the new embedding-model identifier is written"). At scaffold, supersession is exposed as a fifth method on `IMemoryStore` — `SupersedeAsync(entryId, replacement, scope, ct)` — and a `SummaryOfEntryId` field on `MemoryEntry` (non-null when the entry summarizes another) so summarizer-driven supersession is observable at the record level. Both are public surface, both are covered by the D12 contract-shape canary, and both reflect a D10-mandated mechanism rather than an undocumented expansion. The catalog `contracts.json` description for `IMemoryStore` updates to "write, read, search, delete, **and supersede** memory entries" (packet 01 carries that catalog edit if it lands first; otherwise the scaffold PR includes a one-line follow-up note for packet 01 to amend).

### Providers.InMemory details

`InMemoryMemoryStore` — in-process dictionary keyed by `(TenantId, ProjectId, AgentId, EntryId)` where `TenantId` and `ProjectId` are the strong-typed record-structs from `HoneyDrunk.Kernel.Abstractions.Identity`. Enforces scope check on every read. Linear-scan similarity over stored embeddings. Suitable for tests, dev, fixtures.

### CI workflows

Five files; `api-compatibility.yml` path-filtered to `src/HoneyDrunk.Memory.Abstractions/**`.

### `HoneyDrunk.Standards`

Per invariant 26.

### Documentation

Repo README — purpose, package matrix, "How to consume" snippet, link to ADR-0022. Note the embedding-model coherence rule (D10), the content-never-in-telemetry rule (D9), the Position A short-term/long-term boundary (D4/D7).

## Affected Files
Entire repo. See layout.

## NuGet Dependencies

### `HoneyDrunk.Memory.Abstractions.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | `TenantId`, `ProjectId` strong types per ADR-0026 D1/D2 — invariant 1 allows Kernel.Abstractions |

(No other PackageReference. Invariant 1 allows `Microsoft.Extensions.*` abstractions plus `HoneyDrunk.Kernel.Abstractions`.)

### `HoneyDrunk.Memory.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | Telemetry, context, strong-typed identifiers |
| `HoneyDrunk.AI.Abstractions` | `IEmbeddingGenerator` + `IChatClient` per D5 |
| `HoneyDrunk.Auth.Abstractions` | `IAuthorizationPolicy` + `IAuthenticatedIdentityAccessor` per D6 |
| `HoneyDrunk.Data.Abstractions` | `IRepository` + `IUnitOfWork` for non-in-memory persistence |
| `Microsoft.Extensions.DependencyInjection.Abstractions`, `.Hosting.Abstractions`, `.Logging.Abstractions` | |

Project reference: `HoneyDrunk.Memory.Abstractions`.

### `HoneyDrunk.Memory.Providers.InMemory.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |

Project reference: `HoneyDrunk.Memory.Abstractions`. **No reference to runtime / Kernel / AI / Auth / Data.**

### Test projects: standard.

## Boundary Check
- [x] `HoneyDrunk.Memory.Abstractions` references only the Grid's Abstractions-allow-list — `HoneyDrunk.Kernel.Abstractions` + `Microsoft.Extensions.*` (invariant 1).
- [x] `Providers.InMemory` references only `HoneyDrunk.Memory.Abstractions` (invariant 3).
- [x] Position A applied — Memory holds long-term only; execution-scope state stays on `IAgentExecutionContext` (Agents).
- [x] `IMemoryScope` enforces scope at every `IMemoryStore` call (Memory content-only-through-`IMemoryStore` invariant — number assigned by packet 02, default 62).
- [x] `MemoryEntry.EmbeddingModelIdentifier` is required (Memory embedding-coherence invariant — number assigned by packet 02, default 63).
- [x] Content NEVER in telemetry (Memory content-never-in-telemetry invariant — number assigned by packet 02, default 64).
- [x] Records drop `I`; interfaces keep it.
- [x] `TenantId` / `ProjectId` are the strong types from `HoneyDrunk.Kernel.Abstractions.Identity` per ADR-0026 D1/D2 (Accepted). `AgentId` stays `string` pending a Kernel-side `AgentId` ULID record-struct.

## Acceptance Criteria
- [ ] `HoneyDrunk.Memory.slnx` builds clean.
- [ ] Three D3 interfaces + `MemoryEntry` record + `MemoryStoreQuery` query record present with XML docs.
- [ ] `IMemoryStore` exposes `WriteAsync` / `ReadAsync` / `SearchAsync` / `DeleteAsync` / `SupersedeAsync` (D3 four + D10 supersession).
- [ ] `IMemoryScope.TenantId` is `HoneyDrunk.Kernel.Abstractions.Identity.TenantId` (strong type), not `string`. Same for `ProjectId`. `AgentId` stays `string`.
- [ ] `MemoryEntry.TenantId` / `ProjectId` use the Kernel strong types; `AgentId` is `string`.
- [ ] `HoneyDrunk.Memory.Abstractions.csproj` PackageReference set is exactly `{ HoneyDrunk.Standards (PrivateAssets=all), HoneyDrunk.Kernel.Abstractions }`. No other `HoneyDrunk.*` references.
- [ ] `Providers.InMemory` references only `HoneyDrunk.Memory.Abstractions`.
- [ ] `AddHoneyDrunkMemory()` resolves all three interfaces.
- [ ] `IMemoryStore.WriteAsync` rejects `MemoryEntry` with null/empty `EmbeddingModelIdentifier` (or short-circuits write — implementation choice, but D10 requires it be non-empty). Unit test verifies.
- [ ] `DefaultMemoryStore.SearchAsync` errors / returns empty when `MemoryStoreQuery.EmbeddingModelIdentifier` mismatches the stored entries' models (D10). Unit test verifies the mismatch path.
- [ ] `DefaultMemoryScope.EscalateAsync` calls `IAuthorizationPolicy` (mocked); denied escalation throws; approved returns widened scope. Unit test verifies both.
- [ ] `DefaultMemorySummarizer` calls `IChatClient.CompleteAsync` and `IEmbeddingGenerator.GenerateAsync`. Writes a new `MemoryEntry` with `SummaryOfEntryId` populated. Unit test verifies.
- [ ] `MemoryTelemetry` emits per-write/read/summarize/supersede activities. **Activity tags / attributes contain only metadata.** Unit test asserts that content text does not appear in any activity payload.
- [ ] `InMemoryMemoryStore` enforces scope on every read/write. Cross-scope read attempts return empty (or throw, depending on impl choice). Unit test verifies.
- [ ] All five `.github/workflows/*.yml` present.
- [ ] `api-compatibility.yml` path-filtered to Abstractions; scaffolding PR reports `status: skipped`.
- [ ] `pr-core.yml` passes.
- [ ] Repo + per-package `CHANGELOG.md` + `README.md` present.
- [ ] All `src/*.csproj` Version 0.1.0; tests excluded.
- [ ] Manual confirmation `v0.1.0` tag triggers `release.yml`.
- [ ] **No `Providers.SqlServer` or `Providers.CosmosDB` in this packet.**
- [ ] **No bulk-delete API in this packet.** Per ADR-0022 D11, the API surface is deferred. Per-entry and per-scope delete (`IMemoryStore.DeleteAsync`) is the only delete surface at stand-up.
- [ ] **No content in telemetry.** Verified by test fixture.

## Human Prerequisites
- [ ] Packet 02b complete.
- [ ] After merge, push tag `v0.1.0`.
- [ ] **Upstream Abstractions check.** AI Abstractions (`IEmbeddingGenerator`, `IChatClient`) + Auth Abstractions (`IAuthorizationPolicy`) must be available. If AI Abstractions is missing, ship `DefaultMemorySummarizer` and `DefaultMemoryStore` similarity path as placeholder no-ops + warnings. If Auth Abstractions is missing, ship `DefaultMemoryScope.EscalateAsync` as throw-not-implemented + warning. Follow-up packets wire real composition.
- [ ] **Branch protection sequencing.** Add `api-compatibility / abstractions-shape` to required checks post-merge.
- [ ] No Azure provisioning required.
- [ ] After merge + tag, file SonarCloud onboarding follow-up.
- [ ] File `Providers.SqlServer` and `Providers.CosmosDB` follow-ups when production consumers drive the shape.
- [ ] File bulk-delete API follow-up once Operator's `IDecisionPolicy` shape concrete + a real erasure request drives shape.
- [ ] File bulk-read API follow-up alongside bulk-delete once Operator's `IApprovalGate` matures (ADR-0022 D6 names the gate, D11 defers the surface — pair the bulk-read and bulk-delete surfaces in one follow-up ADR so both human-policy-gated paths land together).
- [ ] File a follow-up packet to rotate `IMemoryScope.AgentId` and `MemoryEntry.AgentId` from `string` to the Kernel `AgentId` strong type once `HoneyDrunk.Kernel.Abstractions.Identity.AgentId` ships (parallel to ADR-0026's `TenantId` promotion). Includes contract-shape canary update at the same time.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.

> **Invariant 3:** Providers reference parent Node's contracts, not internal implementation details.

> **Invariant 11:** One repo per Node.

> **Invariant 12, 13, 26, 27.** Standard.

> **Memory downstream-coupling invariant (number assigned by packet 02, default 60):** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Memory.Abstractions`.

> **Memory no-Agent-state-outside-IMemoryStore invariant (default 61):** Agents never persist state outside Memory's surface.

> **Memory content-only-through-IMemoryStore invariant (default 62):** No provider escape hatches.

> **Memory embedding-coherence invariant (default 63):** `MemoryEntry` records ingest-time embedding model; mismatched retrieval errors.

> **Memory content-never-in-telemetry invariant (default 64):** Only metadata crosses telemetry boundary.

> **Memory scope-escalation-gated invariant (default 65):** Escalate gated by Auth; bulk reads by Operator.

> **Memory contract-shape canary invariant (default 66):** CI canary on three Abstractions surfaces.

## Referenced ADR Decisions

**ADR-0022 D1:** Agent-memory substrate.

**ADR-0022 D2:** Three packages — Abstractions + runtime + Providers.InMemory.

**ADR-0022 D3:** Three interfaces at stand-up; `MemoryEntry` record introduced at scaffold (this packet).

**ADR-0022 D4 / D7 (Position A):** Short-term on `IAgentExecutionContext` (Agents); Memory owns long-term only.

**ADR-0022 D5:** Embedding (`IEmbeddingGenerator`) + summarization (`IChatClient`) compose AI.

**ADR-0022 D6:** Scope escalation gated by Auth; bulk reads gated by Operator's `IApprovalGate`.

**ADR-0022 D8:** Memory content never leaves except through `IMemoryStore`.

**ADR-0022 D9:** Content NEVER in telemetry.

**ADR-0022 D10:** Embedding-model coherence at similarity retrieval.

**ADR-0022 D11:** Right-to-erasure principle pinned; bulk-delete API deferred.

**ADR-0022 D12:** Canary on three surfaces.

**ADR-0016 D3 (referenced):** `IEmbeddingGenerator`, `IChatClient` from `HoneyDrunk.AI.Abstractions`.

**ADR-0020 D8 (referenced):** Execution-scope state on `IAgentExecutionContext`. Memory does not duplicate.

## Dependencies
- `packet:01`, `packet:02`, `packet:02b`

## Labels
`feature`, `tier-2`, `ai`, `scaffold`, `adr-0022`

## Agent Handoff

**Objective:** Ship `HoneyDrunk.Memory 0.1.0` with three D3 interfaces, `MemoryEntry` record, default runtime composing AI + Auth, `Providers.InMemory`, CI, canary.

**Target:** HoneyDrunk.Memory, branch from `main`.

**Constraints:**
- **Invariant 1:** Abstractions zero `HoneyDrunk.*` references.
- **Invariant 3 applied to Providers.InMemory:** References only Abstractions.
- **Position A:** Memory owns long-term only. No execution-scope-state surface in Memory.
- **`MemoryEntry.EmbeddingModelIdentifier` required.** Non-empty string. Write rejects if absent.
- **Embedding-model coherence at search.** Mismatched model returns empty / errors.
- **Content NEVER in telemetry.** Activity tags / attributes contain only metadata. No `entry.content`, no `query.text`, no `result.content` in any tag/attribute.
- **No bulk-delete API.** Per-entry and per-scope `DeleteAsync` only.
- **No bulk-read API.** Deferred alongside bulk-delete until Operator's `IApprovalGate` matures.
- **Abstractions stance — Kernel.Abstractions allowed.** `TenantId` / `ProjectId` from `HoneyDrunk.Kernel.Abstractions.Identity` per ADR-0026 D1/D2. `AgentId` stays `string` until Kernel ships the strong type. `EmbeddingModelIdentifier` stays `string` (no transitive AI.Abstractions reference at stand-up).
- **Records drop `I`; interfaces keep it.**
- **Memory's query record is `MemoryStoreQuery`, not `MemoryQuery`.** This is the lower-layer storage shape; Agents' `IAgentMemory` exposes `AgentMemoryQueryRequest` which lowers into `MemoryStoreQuery`. Persisted shape stays `MemoryEntry`.
- **Canary skip on scaffolding PR expected.**
- **Upstream conditional.** If AI/Auth Abstractions missing, placeholder no-ops + warnings.

**Telemetry-content-leak test pattern.** The "content NEVER in telemetry" assertion must use a **unique-token sentinel** strategy, not a key-name allow-list. Test arrangement: write a `MemoryEntry` whose `Content` contains a unique token (e.g., `"SENTINEL-DO-NOT-LEAK-{guid}"`); issue a `SearchAsync` whose `QueryText` contains a second sentinel (`"QUERY-SENTINEL-{guid}"`); capture every emitted `Activity` (and every tag/baggage value, recursively) for write / read / search / summarize / supersede; assert that **no captured tag value, no baggage value, no event payload contains either sentinel token**. A key-name allow-list (e.g., "tags named `entry.content` or `query.text` must be absent") is insufficient — it catches naming convention violations but not someone embedding content inside `entry.metadata` or `result.summary`. The sentinel approach catches any code path that puts content into telemetry regardless of where in the activity structure it lands.

**Key Files:**
- `HoneyDrunk.Memory.slnx`, `Directory.Build.props`
- `src/HoneyDrunk.Memory.Abstractions/` — 3 interfaces + `MemoryEntry` record + supporting records (`MemoryStoreQuery`, `ScopeEscalationRequest`, `SummarizationOptions`)
- `src/HoneyDrunk.Memory/` — `DefaultMemoryStore`, `DefaultMemoryScope`, `DefaultMemorySummarizer`, `MemoryTelemetry`, `ServiceCollectionExtensions`
- `src/HoneyDrunk.Memory.Providers.InMemory/` — `InMemoryMemoryStore`
- `.github/workflows/*.yml`
- `README.md`, `CHANGELOG.md` (repo + per-package)
- `tests/`

**Contracts:** Three D3 interfaces + `MemoryEntry` record + `MemoryStoreQuery` query record authored fresh. `IMemoryStore` exposes five methods (write / read / search / delete / supersede); `IMemoryScope` carries strong-typed `TenantId` + `ProjectId` from `HoneyDrunk.Kernel.Abstractions.Identity` plus a `string AgentId` placeholder pending Kernel's strong type.
