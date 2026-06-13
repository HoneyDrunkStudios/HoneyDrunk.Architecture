---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Knowledge
labels: ["feature", "tier-2", "ai", "scaffold", "adr-0021"]
dependencies: ["work-item:01", "work-item:02", "work-item:02b", "adr-0016-honeydrunk-ai-standup/03-ai-node-scaffold"]
adrs: ["ADR-0021", "ADR-0016"]
accepts: ADR-0021
wave: 3
initiative: adr-0021-knowledge-standup
node: honeydrunk-knowledge
---

# Feature: Stand up the HoneyDrunk.Knowledge repo — solution, three packages, contracts, CI, InMemory provider

## Summary

Bring the near-empty `HoneyDrunk.Knowledge` repo from zero to first-shippable per ADR-0021. Land the solution, the three package families (`Abstractions`, runtime, `Providers.InMemory`), the four D3 surfaces in `HoneyDrunk.Knowledge.Abstractions` (three interfaces + `KnowledgeSource` record), default runtime implementations composing AI's `IEmbeddingGenerator` per D5, the in-memory provider backend, the standard CI pipeline, and the contract-shape canary scoped to `HoneyDrunk.Knowledge.Abstractions` per D12 and the canary invariant (number assigned by packet 02).

Unblocks Lore, Sim, Agents (retrieval composition), HoneyHub (when live), Evals.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Knowledge`

## Motivation

ADR-0021 establishes what HoneyDrunk.Knowledge is. The repo is cloned (LICENSE + README only). Five downstream consumers blocked.

This scaffold ships the contract surface plus an in-memory backend; production backends (`Providers.AzureAISearch`, `Providers.PostgresVector`) follow as separate packets.

## Proposed Implementation

### Repository layout

```
HoneyDrunk.Knowledge/
├── HoneyDrunk.Knowledge.slnx
├── Directory.Build.props
├── CHANGELOG.md
├── README.md
├── .editorconfig
├── .gitignore
├── .github/workflows/
│   ├── pr-core.yml
│   ├── release.yml
│   ├── nightly-deps.yml
│   ├── nightly-security.yml
│   └── api-compatibility.yml
├── src/
│   ├── HoneyDrunk.Knowledge.Abstractions/
│   │   ├── HoneyDrunk.Knowledge.Abstractions.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── IKnowledgeStore.cs
│   │   ├── IDocumentIngester.cs
│   │   ├── IRetrievalPipeline.cs
│   │   ├── KnowledgeSource.cs
│   │   └── (retrieval request/response records — minimum needed)
│   ├── HoneyDrunk.Knowledge/
│   │   ├── HoneyDrunk.Knowledge.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── ServiceCollectionExtensions.cs
│   │   ├── Storage/DefaultKnowledgeStore.cs
│   │   ├── Ingestion/DefaultDocumentIngester.cs    (composes IEmbeddingGenerator)
│   │   ├── Retrieval/DefaultRetrievalPipeline.cs   (composes IEmbeddingGenerator; enforces D6)
│   │   └── Telemetry/KnowledgeTelemetry.cs
│   └── HoneyDrunk.Knowledge.Providers.InMemory/
│       ├── HoneyDrunk.Knowledge.Providers.InMemory.csproj
│       ├── README.md
│       ├── CHANGELOG.md
│       ├── InMemoryKnowledgeStore.cs
│       └── (in-memory index/storage internals)
└── tests/
    ├── HoneyDrunk.Knowledge.Abstractions.Tests/
    ├── HoneyDrunk.Knowledge.Tests/
    └── HoneyDrunk.Knowledge.Providers.InMemory.Tests/
```

### Solution

`Directory.Build.props` sets `net10.0`, nullable, warnings-as-errors, `Version` 0.1.0 (test projects excluded via `IsTestProject`).

### Contract details — `HoneyDrunk.Knowledge.Abstractions`

```csharp
// IKnowledgeStore.cs
namespace HoneyDrunk.Knowledge.Abstractions;

public interface IKnowledgeStore
{
    Task IngestAsync(KnowledgeSource source, IReadOnlyList<KnowledgeChunk> chunks, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<RetrievedChunk>> QueryAsync(KnowledgeQuery query, CancellationToken cancellationToken = default);
    Task DeleteAsync(string sourceId, CancellationToken cancellationToken = default);
    Task<KnowledgeSource?> GetSourceAsync(string sourceId, CancellationToken cancellationToken = default);
}

public sealed record KnowledgeChunk(string Content, int Position, float[] Embedding, IReadOnlyDictionary<string, string> Metadata);

public sealed record KnowledgeQuery(string QueryText, float[]? QueryEmbedding, int MaxResults, IReadOnlyDictionary<string, string> Filters, string EmbeddingModelIdentifier);

public sealed record RetrievedChunk(string Content, int Position, double SimilarityScore, KnowledgeSource Source, IReadOnlyDictionary<string, string> Metadata);
```

```csharp
// IDocumentIngester.cs
public interface IDocumentIngester
{
    Task<KnowledgeSource> IngestAsync(IngestionRequest request, CancellationToken cancellationToken = default);
}

public sealed record IngestionRequest(string SourceUri, string ContentType, string OriginContent, IReadOnlyDictionary<string, string> Metadata, IngestionOptions? Options);
public sealed record IngestionOptions(int ChunkSize, int ChunkOverlap, string? EmbeddingModelIdentifier);
```

```csharp
// IRetrievalPipeline.cs
public interface IRetrievalPipeline
{
    Task<IReadOnlyList<RetrievedChunk>> QueryAsync(string queryText, RetrievalOptions? options = null, CancellationToken cancellationToken = default);
}

public sealed record RetrievalOptions(int MaxResults, IReadOnlyDictionary<string, string> Filters, string? EmbeddingModelIdentifier);
```

```csharp
// KnowledgeSource.cs (record — no I prefix)
public sealed record KnowledgeSource(
    string SourceId,
    string Origin,
    string Version,
    DateTimeOffset LastUpdated,
    string EmbeddingModelIdentifier,         // D6 — required for retrieval coherence
    string ContentType,
    IReadOnlyDictionary<string, string> Metadata);
```

Per invariant 1, `HoneyDrunk.Knowledge.Abstractions` carries `Microsoft.Extensions.*` abstractions only, **with one explicit exception**: it takes a compile-time reference to `HoneyDrunk.Kernel.Abstractions` (context types) and `HoneyDrunk.AI.Abstractions` (for `IEmbeddingGenerator`, which appears in `IDocumentIngester` and/or `IRetrievalPipeline` member signatures per ADR-0021 D5). The transitive `HoneyDrunk.AI.Abstractions` edge to every downstream consumer is the explicit decision recorded in ADR-0021 D5: "Downstream Nodes inherit a transitive compile-time dependency on `HoneyDrunk.AI.Abstractions` because `IEmbeddingGenerator` appears in the Abstractions surface — this is accepted and matches the way ADR-0020 D5/D6 treated Agents's `Abstractions`-level edges." **No other HoneyDrunk reference is allowed in Abstractions** — no `HoneyDrunk.Kernel` (runtime), no `HoneyDrunk.AI` (runtime), no `HoneyDrunk.Data`, no Vault, no anything else.

**Strict Abstractions stance — `EmbeddingModelIdentifier` shape.** `KnowledgeSource.EmbeddingModelIdentifier` is `string`. Knowledge does not import `ModelCapabilityDeclaration` from `HoneyDrunk.AI.Abstractions` into the record's member shape — the `string` identifier carries the model identity at the record level, and the `IEmbeddingGenerator` reference at the interface level is the only AI-record shape Knowledge inherits. This keeps Knowledge's record surface stable across AI's record-shape revisions.

### Runtime details — `HoneyDrunk.Knowledge`

`HoneyDrunk.Knowledge` references:
- `HoneyDrunk.Knowledge.Abstractions` (project)
- `HoneyDrunk.Kernel.Abstractions` (for telemetry-factory and context abstractions)
- `HoneyDrunk.AI.Abstractions` (for `IEmbeddingGenerator` per ADR-0021 D5 — concrete generator wired by host into DI)
- `HoneyDrunk.Data.Abstractions` (for `IRepository` / `IUnitOfWork` — concrete data runtime wired by host)
- `Microsoft.Extensions.DependencyInjection.Abstractions`, `Microsoft.Extensions.Hosting.Abstractions`, `Microsoft.Extensions.Logging.Abstractions`

Three default implementations:

- **`DefaultDocumentIngester` — RAG (chunk-and-embed) paradigm; extensibility seam reserved.** Parses content into fixed-size overlapping chunks, generates per-chunk embeddings via `IEmbeddingGenerator`, persists chunks + embeddings + `KnowledgeSource` via `IKnowledgeStore`. Records the embedding-model identifier on `KnowledgeSource`. **This default targets the RAG paradigm only.** Alternative ingestion paradigms — most notably structured-wiki ingestion where the unit of retrieval is a semantically meaningful entry with hand-curated edges rather than an embedding-positioned chunk — are explicitly out of scope for the default ingester and are supported via the provider-extension seam: consumers ship their own `IDocumentIngester` implementation alongside a matching `IKnowledgeStore` shape, and host composition wires the alternative pair in place of the default. The `IDocumentIngester` interface itself is paradigm-agnostic; only the default implementation is RAG-locked. Document this in the runtime package README and on the `IDocumentIngester` XML doc.
- **`DefaultRetrievalPipeline`** — embeds the query via `IEmbeddingGenerator`, delegates to `IKnowledgeStore.QueryAsync`. Enforces D6: if `KnowledgeQuery.EmbeddingModelIdentifier` does not match the source's recorded model, returns empty / errors rather than producing cross-model similarity scores. Enforces D8 (mandatory confidence scores) by requiring every `RetrievedChunk` returned by the underlying store to carry a non-null `SimilarityScore`. Alternative retrieval paradigms (e.g. structured-wiki graph traversal, hybrid sparse + dense retrieval) are supported via host-substituted `IRetrievalPipeline` implementations.
- **`DefaultKnowledgeStore`** — façade over the configured provider package; default DI registration wires `InMemoryKnowledgeStore` for dev / test, with production hosts swapping in a real provider.
- **`KnowledgeTelemetry`** — per-ingest, per-retrieval, per-mutation activities emitted via `ITelemetryActivityFactory`. **Content NEVER carried in telemetry** per D10. Only metadata.

### Providers.InMemory details

`InMemoryKnowledgeStore` — in-process dictionary keyed by `sourceId` and chunk position. Naive linear-scan similarity for queries (cosine similarity over stored embeddings). Suitable for tests, dev, fixtures — never production. Source attribution round-trips through every chunk per D7.

### CI workflows

Five workflow files. `api-compatibility.yml` path-filtered to `src/HoneyDrunk.Knowledge.Abstractions/**`.

### `HoneyDrunk.Standards`

Per invariant 26.

### Documentation

Repo README — purpose, package matrix, "How to consume" snippet with `AddHoneyDrunkKnowledge()` + `AddInMemoryKnowledgeStore()`, link to ADR-0021. Note the embedding-model coherence rule (D6) and the source-attribution guarantee (D7). Per-package README + CHANGELOG.

## Affected Files
Entire repo. See "Repository layout".

## NuGet Dependencies

### `HoneyDrunk.Knowledge.Abstractions.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | Context types (`IGridContext`, `IOperationContext`) referenced in interface signatures. |
| `HoneyDrunk.AI.Abstractions` | **Required** per ADR-0021 D5 — `IEmbeddingGenerator` appears in `IDocumentIngester` / `IRetrievalPipeline` member signatures. The transitive compile-time edge to every downstream consumer is the explicit ADR-0021 D5 decision. |

(No `HoneyDrunk.AI`, no `HoneyDrunk.Data` runtime references in Abstractions — only `.Abstractions` peers, per invariant 1.)

### `HoneyDrunk.Knowledge.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | Telemetry factory abstractions, context types |
| `HoneyDrunk.AI.Abstractions` | `IEmbeddingGenerator` per ADR-0021 D5 — runtime resolves the concrete generator from DI; the runtime package does not take a hard dependency on `HoneyDrunk.AI` because the embedding generator implementation is host-composed (host references `HoneyDrunk.AI` and wires the generator into DI). |
| `HoneyDrunk.Data.Abstractions` | `IRepository`, `IUnitOfWork` for non-in-memory persistence — runtime package references the contract surface, never the data runtime. |
| `Microsoft.Extensions.DependencyInjection.Abstractions`, `.Hosting.Abstractions`, `.Logging.Abstractions` | |

Project reference: `HoneyDrunk.Knowledge.Abstractions`.

**Rationale for `.Abstractions`-only references in the runtime package:** Invariant 2 prohibits runtime packages from depending on other Nodes' runtime packages. Knowledge's runtime needs the `IEmbeddingGenerator` interface (to call) and the `IRepository` interface (to persist), but the concrete implementations are wired by the consuming host — so the runtime package compiles against the `.Abstractions` peers and lets DI resolve the concretes. Hosts pull in `HoneyDrunk.AI` and `HoneyDrunk.Data` themselves.

### `HoneyDrunk.Knowledge.Providers.InMemory.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |

Project reference: `HoneyDrunk.Knowledge.Abstractions`.

### Test projects: standard.

## Boundary Check
- [x] All work inside `HoneyDrunk.Knowledge`.
- [x] `HoneyDrunk.Knowledge.Abstractions` references only `HoneyDrunk.Kernel.Abstractions` + `HoneyDrunk.AI.Abstractions` HoneyDrunk peers (plus `Microsoft.Extensions.*`); no runtime-package references per invariant 1 / ADR-0021 D5.
- [x] `HoneyDrunk.Knowledge` runtime package references only `.Abstractions` peers (no other runtime packages) per invariant 2.
- [x] `Providers.InMemory` references only `HoneyDrunk.Knowledge.Abstractions` (invariant 3).
- [x] Content never appears in telemetry (D10 / invariant 61 — default; collision-check at edit time authoritative).
- [x] `KnowledgeSource` carries `EmbeddingModelIdentifier`; retrieval enforces coherence (D6 / invariant 59 — default).
- [x] Every `RetrievedChunk` carries `SimilarityScore`; Knowledge does not threshold (D8 / invariant 60 — default).
- [x] Records drop `I` prefix; interfaces keep `I` per the grid-wide naming rule.

## Acceptance Criteria
- [ ] `HoneyDrunk.Knowledge.slnx` builds clean.
- [ ] Three D3 interfaces + `KnowledgeSource` record present with XML docs.
- [ ] `HoneyDrunk.Knowledge.Abstractions` references `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.AI.Abstractions` (and only those two HoneyDrunk peers, plus `Microsoft.Extensions.*`). No `HoneyDrunk.Kernel`, no `HoneyDrunk.AI`, no `HoneyDrunk.Data`, no `HoneyDrunk.Data.Abstractions` in Abstractions.
- [ ] `HoneyDrunk.Knowledge` runtime package references only `.Abstractions` peers — specifically `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.AI.Abstractions`, `HoneyDrunk.Data.Abstractions`, plus the project reference to `HoneyDrunk.Knowledge.Abstractions`. No `HoneyDrunk.Kernel`, no `HoneyDrunk.AI`, no `HoneyDrunk.Data` runtime references (per invariant 2).
- [ ] `HoneyDrunk.Knowledge.Providers.InMemory` references only `HoneyDrunk.Knowledge.Abstractions`.
- [ ] `AddHoneyDrunkKnowledge()` resolves all three interfaces.
- [ ] `DefaultDocumentIngester` records `EmbeddingModelIdentifier` on `KnowledgeSource` and rejects ingestion without a model identifier. Unit test verifies.
- [ ] `DefaultDocumentIngester` is RAG-paradigm only (chunk + embed); the runtime package README and the `IDocumentIngester` XML doc document the extensibility seam for alternative paradigms (e.g. structured-wiki ingestion) via host-substituted `IDocumentIngester` implementations.
- [ ] `DefaultRetrievalPipeline` enforces embedding-model coherence (returns empty / errors on mismatch). Unit test verifies the mismatch path.
- [ ] `DefaultRetrievalPipeline` requires every `RetrievedChunk` from the store to carry a non-null `SimilarityScore`; results without a score fail loudly rather than silently returning. Unit test verifies (D8 / invariant 60 — default).
- [ ] Source attribution round-trips through `IKnowledgeStore.QueryAsync` (every `RetrievedChunk` carries a valid `KnowledgeSource`). Unit test verifies.
- [ ] `KnowledgeTelemetry` emits per-ingest / per-retrieval / per-mutation activities. **Content does NOT appear in activity tags or attributes.** Unit test verifies by asserting that activity payloads contain only metadata.
- [ ] `InMemoryKnowledgeStore` works deterministically; round-trips ingestion + retrieval + delete. Unit test verifies.
- [ ] All five `.github/workflows/*.yml` present.
- [ ] `api-compatibility.yml` path-filtered to Abstractions; scaffolding PR reports `status: skipped` (expected).
- [ ] `pr-core.yml` passes.
- [ ] Repo + per-package `CHANGELOG.md` + `README.md` present.
- [ ] All `src/*.csproj` Version 0.1.0; tests excluded.
- [ ] Manual confirmation `v0.1.0` tag triggers `release.yml` (verify; do not push yet).
- [ ] **No `Providers.AzureAISearch` or `Providers.PostgresVector` in this packet** — they ship under separate follow-up packets.
- [ ] **No content in telemetry.** `rg -n "activity\.SetTag.*content|activity\.AddAttribute.*content" src/` returns zero matches that would expose chunk or query payloads.
- [ ] **`KnowledgeSource` is a `sealed record` (interface naming check).** `rg -nP '\binterface\s+KnowledgeSource\b' src/` returns zero matches; `rg -nP '\bsealed\s+record\s+KnowledgeSource\b' src/HoneyDrunk.Knowledge.Abstractions/` returns exactly one match.

## Human Prerequisites
- [ ] Packet 02b complete.
- [ ] **Confirm `HoneyDrunk.AI.Abstractions 0.1.0` has shipped to NuGet** before this packet's scaffolding agent starts work. The cross-initiative dependency `adr-0016-honeydrunk-ai-standup/03-ai-node-scaffold` in this packet's frontmatter is wired by `file-work-items.yml`, but the agent still needs the package available on a feed to compile against — confirm at `https://www.nuget.org/packages/HoneyDrunk.AI.Abstractions` or the internal feed before approving the wave-3 dispatch.
- [ ] After merge, push tag `v0.1.0`.
- [ ] **Branch protection sequencing.** Add `api-compatibility / abstractions-shape` to required checks post-merge.
- [ ] No Azure provisioning required.
- [ ] After merge + tag, file SonarCloud onboarding follow-up.
- [ ] File `Providers.AzureAISearch` and `Providers.PostgresVector` follow-up packets when a real production consumer drives the shape.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages — only `Microsoft.Extensions.*` abstractions are permitted, with explicit exceptions only where another `.Abstractions` peer is required by interface signature. Knowledge's `Abstractions` carries `HoneyDrunk.Kernel.Abstractions` (context types) and `HoneyDrunk.AI.Abstractions` (for `IEmbeddingGenerator`, appearing in `IDocumentIngester` / `IRetrievalPipeline` member signatures) per ADR-0021 D5 — this is the explicit, accepted exception.

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. `HoneyDrunk.Knowledge` references only `.Abstractions` peers — `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.AI.Abstractions`, `HoneyDrunk.Data.Abstractions` — and lets hosts wire the concrete implementations into DI.

> **Invariant 3:** Provider packages depend on the parent Node's contracts package, not internal implementation details. `HoneyDrunk.Knowledge.Providers.InMemory` references only `HoneyDrunk.Knowledge.Abstractions`.

> **Invariant 11:** One repo per Node.

> **Invariant 12:** Semantic versioning with CHANGELOG and README — repo-level and per-package.

> **Invariant 13:** All public APIs have XML documentation.

> **Invariant 26:** Work items for .NET code work must include an explicit `## NuGet Dependencies` section.

> **Invariant 27:** All projects in a solution share one version and move together.

> **Knowledge downstream-coupling invariant (number assigned by packet 02; default 57):** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Knowledge.Abstractions`. Composition against `HoneyDrunk.Knowledge` and any `HoneyDrunk.Knowledge.Providers.*` package is a host-time concern.

> **Knowledge source-attribution invariant (default 58):** Every retrieved chunk carries the `KnowledgeSource` identity, the chunk's position within the source, and the source version. No mode, flag, or provider returns an unattributed chunk.

> **Knowledge embedding-coherence invariant (default 59):** Every `KnowledgeSource` records the embedding-model identifier used at ingest time; retrieval against a mismatched model errors or returns empty. Knowledge never produces a cross-model similarity score.

> **Knowledge confidence-score invariant (default 60):** Every `IRetrievalPipeline` result carries a per-chunk relevance/confidence score; Knowledge applies no cutoff threshold. Provider packages that cannot expose a stable score for every returned chunk cannot back `IRetrievalPipeline`.

> **Knowledge content-never-in-telemetry invariant (default 61):** Only metadata — source id, chunk count, query latency, result count, model identifier — may cross the telemetry boundary. Document text, chunk contents, query text, and retrieved chunk contents are NEVER carried in Pulse signals.

> **Knowledge contract-shape canary invariant (default 62):** CI canary on `IKnowledgeStore`, `IDocumentIngester`, `IRetrievalPipeline`, and `KnowledgeSource`.

## Referenced ADR Decisions

**ADR-0021 D1:** External-knowledge ingestion + retrieval substrate.

**ADR-0021 D2:** Three packages — Abstractions + runtime + Providers.InMemory.

**ADR-0021 D3:** Four surfaces; `IKnowledgeSource` promoted to `KnowledgeSource` record.

**ADR-0021 D5:** Embedding calls compose `IEmbeddingGenerator` from AI.

**ADR-0021 D6:** Embedding-model coherence enforced at retrieval; mismatched model errors.

**ADR-0021 D7:** Source attribution mandatory.

**ADR-0021 D8:** Confidence scores mandatory.

**ADR-0021 D10:** Content NEVER in telemetry.

**ADR-0021 D11:** Content-safety is Operator's `ISafetyFilter` on output side — Knowledge does not own ingest-time scanning.

**ADR-0021 D12:** Canary on all four surfaces.

**ADR-0016 D3 (referenced):** `IEmbeddingGenerator` is a HoneyDrunk.AI.Abstractions interface.

## Dependencies
- `work-item:01` — catalog registration must land first so the contract surface is registered before scaffold lands the actual types.
- `work-item:02` — invariants must land first so packet 03 can reference them by their final assigned numbers (defaults 57-62; collision-check at edit time authoritative).
- `work-item:02b` — repo + local clone verification must complete first; the scaffolding agent assumes a clean checkout on `main`.
- `adr-0016-honeydrunk-ai-standup/03-ai-node-scaffold` — **hard cross-initiative dependency.** Knowledge's Abstractions package compiles against `HoneyDrunk.AI.Abstractions` per ADR-0021 D5 (the `IEmbeddingGenerator` reference). The AI Abstractions package must have shipped at least one published version (0.1.0) before this packet can build. If AI's scaffold packet has not filed yet, `file-work-items.yml` will block this packet's filing until the AI scaffold packet's GitHub Issue exists.

## Labels
`feature`, `tier-2`, `ai`, `scaffold`, `adr-0021`

## Agent Handoff

**Objective:** Take the `HoneyDrunk.Knowledge` repo (LICENSE + README) and ship 0.1.0 with the four D3 surfaces, default runtime composing AI's `IEmbeddingGenerator`, `Providers.InMemory` backend, full CI, and the contract-shape canary scoped to Abstractions.

**Target:** HoneyDrunk.Knowledge, branch from `main`.

**Context:**
- Goal: Unblock Lore, Sim, Agents (retrieval), HoneyHub, Evals.
- Feature: ADR-0021 standup, packet 03.
- ADRs: ADR-0021 (standup); ADR-0016 (AI source of `IEmbeddingGenerator`).

**Constraints:**

- **Invariant 1 (Abstractions package dependencies).** `HoneyDrunk.Knowledge.Abstractions` references `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.AI.Abstractions` and `Microsoft.Extensions.*` peers — and nothing else from HoneyDrunk. The `HoneyDrunk.AI.Abstractions` edge is the explicit ADR-0021 D5 decision (because `IEmbeddingGenerator` appears in `IDocumentIngester` / `IRetrievalPipeline` member signatures). Do NOT add `HoneyDrunk.Kernel`, `HoneyDrunk.AI`, `HoneyDrunk.Data`, or `HoneyDrunk.Data.Abstractions` to Abstractions.
- **Invariant 2 (runtime → only Abstractions).** `HoneyDrunk.Knowledge` runtime references only `.Abstractions` peers — `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.AI.Abstractions`, `HoneyDrunk.Data.Abstractions`. Hosts wire the concrete runtime implementations (`HoneyDrunk.AI`, `HoneyDrunk.Data`, etc.) into DI; the Knowledge runtime package does not take hard runtime-package dependencies.
- **Invariant 3 (provider package dependencies).** `HoneyDrunk.Knowledge.Providers.InMemory` references only `HoneyDrunk.Knowledge.Abstractions`. No reference to the runtime package, Kernel, AI, Data, or any other HoneyDrunk peer.
- **Invariant 58 (default — source attribution):** Every `RetrievedChunk` carries a valid `KnowledgeSource` identity, chunk position, and source version. No anonymous-retrieval mode anywhere.
- **Invariant 59 (default — embedding-model coherence):** `KnowledgeSource.EmbeddingModelIdentifier` is required (non-empty `string`). `DefaultRetrievalPipeline` enforces coherence — a query embedded with a model that does not match the source's recorded model returns empty / errors rather than producing a cross-model similarity score.
- **Invariant 60 (default — mandatory confidence scores):** Every `RetrievedChunk` carries a non-null `SimilarityScore`. Knowledge does NOT apply a cutoff threshold; thresholding is a consumer concern. The retrieval pipeline rejects store results with missing scores.
- **Invariant 61 (default — content never in telemetry):** No document text, chunk content, query text, or retrieved chunk text appears in any activity tag, attribute, baggage entry, log message, or exception payload. Only metadata (source id, chunk count, query latency, result count, model identifier) crosses the telemetry boundary.
- **Strict Abstractions stance — `EmbeddingModelIdentifier` shape.** `KnowledgeSource.EmbeddingModelIdentifier` is `string`, not `ModelCapabilityDeclaration`. The `string` identifier keeps the record decoupled from AI's record-shape revisions while the `IEmbeddingGenerator` reference at the interface level carries the type identity needed at compile time.
- **RAG-paradigm default ingester with extensibility seam.** `DefaultDocumentIngester` is chunk-and-embed only (RAG paradigm). Alternative ingestion paradigms (most notably structured-wiki ingestion) are supported via host-substituted `IDocumentIngester` + matching `IKnowledgeStore` implementations; the runtime package README and the `IDocumentIngester` XML doc must document this seam.
- **Records drop `I`; interfaces keep it.** `KnowledgeSource`, `KnowledgeChunk`, `KnowledgeQuery`, `RetrievedChunk`, `IngestionRequest`, `IngestionOptions`, `RetrievalOptions` are records (no `I` prefix). `IKnowledgeStore`, `IDocumentIngester`, `IRetrievalPipeline` are interfaces (keep `I` prefix).
- **Canary on scaffolding PR is expected to skip.** Verification post-merge via throwaway breaking-change PR.
- **No `Providers.AzureAISearch` or `Providers.PostgresVector` in this packet.** Provider slot exists; production backends ship in follow-up packets.
- **Invariant numbers above are defaults.** Packet 02 lands the actual numbers via collision-check at edit time (default band 57-62). If the band shifts during 02's filing, packet 03 source is amended in lockstep before filing (pre-filing carve-out per invariant 24).

**Key Files:**
- `HoneyDrunk.Knowledge.slnx`, `Directory.Build.props`
- `src/HoneyDrunk.Knowledge.Abstractions/` — 3 interfaces + `KnowledgeSource` record + supporting records
- `src/HoneyDrunk.Knowledge/` — `DefaultDocumentIngester`, `DefaultRetrievalPipeline`, `DefaultKnowledgeStore`, `KnowledgeTelemetry`, `ServiceCollectionExtensions`
- `src/HoneyDrunk.Knowledge.Providers.InMemory/` — `InMemoryKnowledgeStore`
- `.github/workflows/*.yml`
- `README.md`, `CHANGELOG.md` (repo + per-package)
- `tests/`

**Contracts:** Four D3 surfaces authored fresh.
