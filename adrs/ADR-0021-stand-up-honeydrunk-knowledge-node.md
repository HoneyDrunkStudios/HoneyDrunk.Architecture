# ADR-0021: Stand Up the HoneyDrunk.Knowledge Node — External Knowledge Ingestion and Retrieval Substrate for the AI Sector

**Status:** Proposed
**Date:** 2026-04-19
**Deciders:** HoneyDrunk Studios
**Sector:** AI

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Reconcile `catalogs/contracts.json` entries for `honeydrunk-knowledge`: promote `IKnowledgeSource` to `KnowledgeSource` with `kind: "type"` (records drop the `I` prefix per the grid-wide naming rule); confirm the three remaining interfaces (`IKnowledgeStore`, `IDocumentIngester`, `IRetrievalPipeline`) already seeded in the catalog
- [ ] Update `catalogs/relationships.json` for `honeydrunk-knowledge`: change the `exposes.contracts` list so it reads `KnowledgeSource` instead of `IKnowledgeSource`; add `honeydrunk-agents` to `consumed_by_planned` with `consumes_detail` of `["IRetrievalPipeline", "HoneyDrunk.Knowledge.Abstractions"]`
- [ ] Reconcile the `grid_relationship` prose in `catalogs/nodes.json` for `honeydrunk-knowledge` ("Consumed by Agents (knowledge retrieval), Lore (knowledge compilation), HoneyHub (context for planning)") against `catalogs/relationships.json` edges (currently `consumed_by_planned` is `["honeydrunk-sim", "honeydrunk-lore"]`) — the prose and the edge list must describe the same set of consumers
- [ ] Update `catalogs/grid-health.json` `honeydrunk-knowledge` entry to reflect the stood-up contract surface and the contract-shape canary expectation
- [ ] Wire the contract-shape canary into Actions for `IKnowledgeStore`, `IDocumentIngester`, `IRetrievalPipeline`, and `KnowledgeSource`
- [ ] Add `integration-points.md` and `active-work.md` to `repos/HoneyDrunk.Knowledge/`, matching the template used by `repos/HoneyDrunk.Agents/`
- [ ] File the HoneyDrunk.Knowledge scaffold packet (solution structure, `HoneyDrunk.Standards` wiring, CI pipeline, `HoneyDrunk.Knowledge.Providers.InMemory` fixture, default implementations of `IKnowledgeStore`, `IDocumentIngester`, and `IRetrievalPipeline`, and the embedding-model-identifier carry through `KnowledgeSource` per D6)
- [ ] Scope agent assigns final invariant numbers when flipping Status → Accepted

## Context

`HoneyDrunk.Knowledge` is cataloged in `catalogs/nodes.json` as the AI sector's external-information ingestion and retrieval substrate, but the repo is cataloged-not-yet-created — no packages, no contracts, no ingester, no retrieval pipeline, no CI. Sim, Lore, Agents, and HoneyHub (when live) all need a shared way to ingest external documents, chunk and embed them, and query them back with source attribution, and none of them own that responsibility. Without a dedicated substrate, each Node ends up inventing its own ingestion pipeline, chunking strategy, and attribution model, and the knowledge surface fragments across the AI sector.

ADR-0016 stood up HoneyDrunk.AI as the inference substrate. ADR-0017 stood up HoneyDrunk.Capabilities as the tool-registry and dispatch substrate. ADR-0018 stood up HoneyDrunk.Operator as the human-policy enforcement and audit substrate. ADR-0020 stood up HoneyDrunk.Agents as the agent-runtime foundation node that composes those three substrates into a runnable agent. Knowledge is the next AI-sector foundation node after the four substrates (AI, Capabilities, Operator, Agents): it is the Node that owns *what the Grid knows about the outside world* and *how that knowledge is made retrievable to agents, workflows, and applications*. The stand-up pattern is deliberately reused: contracts live in an `Abstractions` package, runtime composition is a separate package, downstream Nodes compile against `Abstractions` only, and a first-wave `Providers.InMemory` package ships at stand-up so consumers have one shared in-memory backend they can compose in tests and in local development without standing up Azure AI Search or Postgres pgvector.

The `catalogs/contracts.json` entry for `honeydrunk-knowledge` already lists four contracts (`IKnowledgeStore`, `IDocumentIngester`, `IRetrievalPipeline`, `IKnowledgeSource`). Three of those are correctly interfaces. The fourth — `IKnowledgeSource` — is named as an interface but its job is to carry metadata about an ingested source (origin, version, last-updated timestamp, embedding-model identifier). That is a value shape, not a behaviour surface, and it should be a record under the grid-wide naming rule already applied by `ModelCapabilityDeclaration` in ADR-0016, `CapabilityDescriptor` in ADR-0017, and the four governance records in ADR-0018. Records drop the `I` prefix and are cataloged with `kind: "type"`. Interfaces keep the `I` prefix and are cataloged with `kind: "interface"`. No `kind: "record"` is used anywhere in the catalog schema.

Knowledge's boundary against two adjacent Nodes needs explicit disambiguation before drift creeps in. HoneyDrunk.Memory owns agent-generated, subjective context (what an agent learned or decided across executions). Knowledge owns externally sourced, objective information (documents, APIs, datasets). Both share the embedding infrastructure in HoneyDrunk.AI via `IEmbeddingGenerator` per ADR-0016 D3, but they are semantically and operationally distinct and their storage, lifecycle, and access rules differ. HoneyDrunk.Lore is an application built on top of Knowledge — it compiles an LLM-maintained wiki from what Knowledge ingests. Knowledge is the infrastructure; Lore is the application. HoneyDrunk.Sim also needs Knowledge (scenario-driven agent runs need access to the same retrieval surface Lore uses), so Knowledge cannot be folded into Lore without cutting Sim off from the substrate.

There is one additional concern to pin at stand-up: **embedding-model coherence**. A retrieval request is only meaningful if the query embedding and the stored chunk embeddings come from the same embedding model (or from models known to be compatible). If Knowledge is ingested with model A's embeddings and later queried with model B's embeddings, the vector similarity metric is nonsense and the retrieval returns noise. This is a well-known RAG correctness hazard and it must not be left implicit. The stand-up decision is **level (b) coherence** — `KnowledgeSource` records the embedding-model identifier used at ingest time, and a retrieval against a mismatched model errors or returns empty rather than silently producing wrong results. Stricter **level (c) coherence** — router-level pinning so callers cannot even request a mismatched model — is a later concern (ADR-0010's `IModelRouter` is still Proposed and the pinning surface belongs in routing, not in Knowledge).

This ADR is the **stand-up decision** for the Knowledge Node — what it owns, what it does not own, which contracts it exposes, how downstream Nodes couple to it, and how it interacts with AI, Memory, Lore, Sim, and Agents. "Node" is used throughout in the ADR-0001 sense — a library-level building block producing one or more NuGet packages, not a deployable service. This ADR is not a scaffolding packet. Filing the repo, adding CI, wiring the in-memory provider, and producing the first shippable packages all follow as separate issue packets once this ADR is accepted.

## Decision

### D1. HoneyDrunk.Knowledge is the AI sector's external-knowledge ingestion and retrieval substrate

`HoneyDrunk.Knowledge` is the single Node in the AI sector that owns **external-knowledge primitives** — the contracts and runtime machinery that ingest documents, parse and chunk them into retrievable units, resolve embeddings through HoneyDrunk.AI, store the results with source attribution and version metadata, and expose a retrieval pipeline that returns ranked, attributed results. It is a shared substrate, not an application. It does not decide *what* to ingest or *what* to do with retrieved results; it owns the mechanics of *how external information enters the Grid* and *how it is queried back with attribution and a confidence score*.

Knowledge *content* — the actual documents, the taxonomy decisions, the curation — lives in the consumers (Lore curates its wiki content; Sim curates its scenario fixtures; Agents-driven applications curate whatever domain information they need). Knowledge provides the ingestion, chunking, embedding-orchestration, storage, and retrieval primitives; consumers provide the sources.

The parallel with ADR-0020's framing of Agents is intentional. Agents is the agent-runtime foundation node that composes AI, Capabilities, and Operator into a runnable agent. Knowledge is the foundation node that gives every agent, workflow, and application in the AI sector access to the same grounded-information surface, backed by the same attribution guarantees and the same embedding-model coherence rules. Knowledge is to RAG what Agents is to agent execution: a single substrate so consumers do not each roll their own.

### D2. Package families

The Knowledge Node ships the following package families, mirroring the stand-up shape used by ADR-0016 (AI), ADR-0017 (Capabilities), ADR-0018 (Operator), and ADR-0020 (Agents):

- `HoneyDrunk.Knowledge.Abstractions` — all interfaces, the `KnowledgeSource` record (D3), and the retrieval request/response shapes. Zero runtime dependencies beyond `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.AI.Abstractions` (for `IEmbeddingGenerator`).
- `HoneyDrunk.Knowledge` — runtime composition: default `IKnowledgeStore`, default `IDocumentIngester`, default `IRetrievalPipeline`, DI wiring. Takes a first-class runtime dependency on `HoneyDrunk.AI.Abstractions` for embedding calls (see D5).
- `HoneyDrunk.Knowledge.Providers.InMemory` — in-memory backend for `IKnowledgeStore`. Zero-network, deterministic, suitable for tests, local development, and Evals fixtures. Consumed by downstream Nodes in test projects and in local composition; never in production composition.

Two additional provider slots are named in the repo overview — `HoneyDrunk.Knowledge.Providers.AzureAISearch` and `HoneyDrunk.Knowledge.Providers.PostgresVector`. Those provider packages are **not first-wave**. They ship under separate issue packets once `InMemory` has exercised the provider-slot shape and once the first real consumer (Sim or Lore) has landed a retrieval path against the substrate. The stand-up commitment is the contract surface plus `InMemory`; production backends follow.

No separate `HoneyDrunk.Knowledge.Testing` package is introduced at stand-up. The `Providers.InMemory` package already plays that role — it is the in-memory backend every downstream test project can compose. Whether a separate `Testing` package is warranted later (for shared test helpers, fixture builders, deterministic clock hooks) is deferred to Alternatives Considered. The pattern differs from Capabilities, Operator, and Agents (all of which ship a `Testing` package alongside the runtime) because Knowledge's in-memory fixture is a production-shaped backend under the provider-slot family, not a test-only artifact.

### D3. Exposed contracts

Four surfaces form the Knowledge Node's public boundary at stand-up — three interfaces and one record. These are the surfaces downstream Nodes are allowed to compile against:

| Contract | Kind | Purpose |
|---|---|---|
| `IKnowledgeStore` | interface | Ingest, query, and delete knowledge sources. The storage-facing surface that provider packages implement. |
| `IDocumentIngester` | interface | Parse and chunk documents into retrievable units; delegate embedding generation to `IEmbeddingGenerator` (HoneyDrunk.AI). |
| `IRetrievalPipeline` | interface | Query → ranked results with source attribution and confidence scores. The agent-facing and application-facing RAG entry point. |
| `KnowledgeSource` | record | Metadata about an ingested source — origin, version, last-updated timestamp, embedding-model identifier (see D6). Value type, no `I` prefix, `kind: "type"` in the catalog. |

The currently-cataloged `IKnowledgeSource` entry is superseded by `KnowledgeSource`. The rename applies the grid-wide naming rule: records drop the `I` prefix and are cataloged with `kind: "type"`; interfaces retain the `I` prefix and are cataloged with `kind: "interface"`. This matches the precedent set by `ModelCapabilityDeclaration` in ADR-0016, `CapabilityDescriptor` in ADR-0017, and the four governance records (`CostEvent`, `AuditEntry`, `ApprovalRequest`, `ApprovalDecision`) in ADR-0018.

Retrieval request and response shapes (query text, filter clauses, ranked-result envelope with attribution and score) are **deferred to the scaffold packet**. The stand-up contract is the four surfaces named above and the principle that any records introduced later apply the grid-wide naming rule. This matches the deferral pattern ADR-0017 D6 used for tool-schema versioning and ADR-0020 D3 used for agent record shapes.

### D4. Boundary rule with AI, Memory, Lore, Sim, and Agents (definitive)

The surrounding Nodes need an explicit boundary test so that drift does not creep in once Knowledge ships. The rule below is the decision test Knowledge applies when an ambiguous concern is proposed.

**Decision test — for any concern in the external-information path, ask:**

1. Does it compute an embedding vector against a model? → **AI** (Knowledge delegates to `IEmbeddingGenerator`).
2. Does it persist, scope, or summarize *agent-generated* context (things an agent learned or decided across executions)? → **Memory**.
3. Does it ingest, chunk, store, or retrieve *externally sourced* information (documents, web content, API responses, structured data)? → **Knowledge**.
4. Does it compile an LLM-maintained wiki from ingested sources, with human-readable markdown outputs and auto-indexes? → **Lore** (an application on top of Knowledge).
5. Does it drive scenario-based agent runs against a fixed information snapshot? → **Sim** (a consumer of Knowledge, not a Knowledge concern).
6. Does it manage agent identity, lifecycle, or execution context? → **Agents** (Agents composes Knowledge via `IRetrievalPipeline` at the execution layer, not by owning any Knowledge surface).

Under this test, several subtleties are worth naming explicitly:

- **Embedding generation is AI's, not Knowledge's.** `IDocumentIngester` calls `IEmbeddingGenerator` during chunk processing. Knowledge does not wrap `IEmbeddingGenerator` behind its own abstraction; consumers that need embeddings for non-Knowledge purposes still reach for `IEmbeddingGenerator` directly. See D5.
- **`KnowledgeSource` is Knowledge's, not Memory's.** Memory has its own scope primitive (`IMemoryScope`, per ADR-0020 D6) for agent-generated data. `KnowledgeSource` is the externally-sourced analog: it carries origin/version/timestamp/embedding-model identity for documents Knowledge ingested. The two do not overlap.
- **Lore is an application, not a Knowledge sibling.** Lore consumes `IRetrievalPipeline` and `IKnowledgeStore` to build its wiki. Lore never reaches into provider packages, never implements `IKnowledgeStore`, and never shares storage semantics with Knowledge. This keeps Knowledge reusable by Sim and by any future non-Lore application.

`catalogs/relationships.json` currently lists Knowledge's `consumes` as `honeydrunk-kernel`, `honeydrunk-data`, `honeydrunk-ai` and lists `consumed_by_planned` as `honeydrunk-sim` and `honeydrunk-lore`. The prose in `catalogs/nodes.json` additionally names Agents and HoneyHub as consumers. The prose-versus-edges drift is real: Agents needs `IRetrievalPipeline` for the knowledge-retrieval execution path, and that edge should be recorded on `consumed_by_planned`. HoneyHub is treated as "when live" prose only and does not create a catalog obligation at stand-up, matching the same treatment ADR-0020 gave HoneyHub in the Agents stand-up. Both corrections are tracked in the follow-up work section at the top of this ADR.

### D5. Embedding calls compose upstream — Knowledge does not re-implement embedding

`IDocumentIngester` is the point where Knowledge generates embeddings for every chunk. Its default implementation in `HoneyDrunk.Knowledge` takes a first-class runtime dependency on `HoneyDrunk.AI.Abstractions` and calls `IEmbeddingGenerator` per ADR-0016 D3 to produce the vector for each chunk. Knowledge does not invent its own embedding abstraction, does not talk to model providers directly, and does not cache embeddings in a way that bypasses AI's telemetry or cost accounting.

The retrieval path is symmetric: `IRetrievalPipeline.Query(queryText)` calls `IEmbeddingGenerator` to produce the query vector, then delegates to `IKnowledgeStore` to find the nearest matches. The embedding call is part of the retrieval hot path and is accounted for in AI's telemetry and cost ledger exactly the same way an ingestion-side call is.

Downstream Nodes that compile against `HoneyDrunk.Knowledge.Abstractions` see `IKnowledgeStore`, `IDocumentIngester`, and `IRetrievalPipeline` as plain interfaces. They inherit a transitive compile-time dependency on `HoneyDrunk.AI.Abstractions` because `IEmbeddingGenerator` appears in the Abstractions surface — this is accepted and matches the way ADR-0020 D5 and D6 treated Agents's `Abstractions`-level edges to AI, Capabilities, Operator, and Memory. The runtime edge to `HoneyDrunk.AI` (composition, router selection, provider choice) is still resolved at the host, not at the consumer.

### D6. Embedding-model coherence — `KnowledgeSource` records the ingest-time model; mismatched retrieval errors

Every `KnowledgeSource` record carries an explicit **embedding-model identifier** — the `ModelCapabilityDeclaration` identity (or equivalent stable string from ADR-0016's model-capability surface) of the model that produced the embeddings stored for that source's chunks. This is not advisory metadata; it is a contract field on the record.

The retrieval rule is deterministic: `IRetrievalPipeline.Query` must produce its query vector using a model that matches the stored chunks' embedding-model identifier. If the caller's configured embedding model does not match the source's recorded model, the pipeline **errors or returns an empty result set** — it never produces a cross-model similarity score. This is the stand-up's level (b) coherence guarantee.

Stricter **level (c) coherence** — router-level pinning that prevents a caller from even requesting a mismatched model, centralised through `IModelRouter` so embedding-model choice is policy-driven rather than caller-driven — is flagged as a later concern and is not in scope for this stand-up. ADR-0010 (which introduces `IModelRouter` and `IRoutingPolicy`) is still Proposed, and router-level pinning is a routing concern, not a Knowledge concern. The Knowledge Node records the model identifier and enforces coherence at the retrieval boundary; the routing layer, when it lands, may add the pinning policy on top without changing Knowledge's contract.

Re-ingesting a source under a new embedding model is treated as a new version of that source (per the existing versioning invariant in `repos/HoneyDrunk.Knowledge/invariants.md` item 3). The previous version's chunks are superseded; retrieval reflects the current version's embedding-model identity. This keeps the coherence rule compatible with operator-driven model migrations: re-ingest, supersede, retrieve against the new model.

### D7. Source attribution is mandatory — no anonymous retrieval

Every chunk returned by `IRetrievalPipeline` carries source attribution: the `KnowledgeSource` identity, the chunk's position within the source, and the version of the source the chunk came from. There is no mode, flag, or provider in which retrieval returns an unattributed chunk. Provider packages that cannot preserve source attribution through their storage shape cannot implement `IKnowledgeStore`; the interface contract requires the attribution to round-trip.

This extends `repos/HoneyDrunk.Knowledge/invariants.md` item 2 ("every retrieved chunk has source attribution") from a Node-local invariant to a Grid-level one, and is listed below as a new invariant for `constitution/invariants.md`. The rationale is the same one that pins the audit-log append-only guarantee in ADR-0018 D9: the cost of enforcing the rule at the interface level is small, and the cost of finding out at an agent-facing consumer that a chunk has no source is very large.

### D8. Confidence scores are mandatory — consumers threshold, Knowledge does not

Every result from `IRetrievalPipeline` includes a relevance/confidence score per chunk. Knowledge does **not** apply a cutoff threshold; thresholding is a consumer concern. The retrieval pipeline returns ranked results with scores; consumers (Lore, Sim, Agents's `IRetrievalPipeline` composition) decide what score is good enough for their use case.

This keeps the score contract stable (consumers know the range and the semantics once) and keeps policy (cutoff thresholds) where it belongs — at the application layer, not baked into the substrate. It matches `repos/HoneyDrunk.Knowledge/invariants.md` item 5 and elevates it to the cross-Node contract level.

### D9. State boundary — Knowledge holds ingestion and retrieval state, not agent or workflow state

Knowledge holds **ingestion and retrieval state** — the persistent store of ingested sources, their chunks, their embeddings, their version history, and their source attribution. All of this is backed by the configured provider (Azure AI Search, Postgres pgvector, InMemory) via `IKnowledgeStore` and is the source of truth for what the Grid knows about external information.

Knowledge does **not** hold:

- **Agent memory.** That is Memory's job. What an agent learned or decided during an execution lives in Memory via `IMemoryStore` and `IMemoryScope`. Knowledge never stores agent-generated content under its own surface.
- **Workflow state.** That is Flow's job. If a retrieval is one step in a larger workflow, the between-step state lives in Flow, not in Knowledge.
- **Audit trail.** That is Operator's job. Ingestion events and retrieval events are telemetry-level concerns per D10, not audit-level concerns. If a specific retrieval path needs to be audit-recorded, the caller writes the `AuditEntry` through Operator's `IAuditLog`; Knowledge does not own that record.
- **Content-safety decisions.** That is Operator's `ISafetyFilter` on the retrieval-side (per ADR-0018 D3). See D11.

### D10. Telemetry emission — Pulse consumes, Knowledge does not depend; content never leaves the store

Knowledge emits telemetry for every ingestion event (source id, chunk count, embedding-model identifier, duration), every retrieval event (query latency, result count, embedding-model identifier, provider identity), and every store mutation (insert, supersede, delete) via Kernel's `ITelemetryActivityFactory`. Pulse consumes that telemetry downstream. **Knowledge has no runtime dependency on Pulse.** The direction is one-way by contract: Knowledge emits, Pulse observes. Same rule as ADR-0016 D7 for AI, ADR-0017 D7 for Capabilities, ADR-0018 D7 for Operator, ADR-0019 D7 for Communications, and ADR-0020 D9 for Agents.

Critically, **Knowledge content never appears in telemetry**. The telemetry surface carries metadata only — source id, chunk count, query latency, result count, model identifier — never the actual document text, chunk contents, query text, or retrieved chunk contents. This extends `repos/HoneyDrunk.Knowledge/invariants.md` item 7 to the Grid level. The separation is structural, not advisory: the telemetry activity factory never receives content payloads from Knowledge code paths.

Pulse signal ingress back into Knowledge — reactive tuning of chunking strategy, retrieval ranking weights, or index rebuild cadence based on observed telemetry — is out of scope for stand-up. It is flagged in Alternatives Considered as a deferred concern and matches the emit-only stance every prior AI-sector stand-up took.

### D11. Content-safety is a retrieval-side concern handled by Operator, not an ingest-time Knowledge concern

Ingest-time content-safety scanning (scanning every ingested document for disallowed content before it enters the store) is **not** a stand-up concern for Knowledge. Operator's `ISafetyFilter` (per ADR-0018 D3) already owns output-side content filtering: when an agent retrieves a chunk and routes it toward a user-facing or agent-facing path, the safety filter runs on the output boundary. This covers the immediate safety need for the first-wave consumers (Sim, Lore, Agents) without requiring Knowledge to own a scanning pipeline.

Ingest-time scanning is flagged in Alternatives Considered. If a future use case requires rejecting content at the ingest boundary rather than filtering it at the retrieval boundary, the concern gets its own ADR and likely composes Operator's `ISafetyFilter` on the ingest side the same way it composes on the output side. Knowledge does not invent a second safety model.

### D12. Contract-shape canary

A contract-shape canary is added to the Knowledge Node's CI: it fails the build if any of the following four surfaces change shape (method signatures, parameter shapes, record members) without a corresponding version bump:

- `IKnowledgeStore`
- `IDocumentIngester`
- `IRetrievalPipeline`
- `KnowledgeSource`

These four are the hot path for every downstream consumer. Accidental shape drift on any of them breaks every Node that ingests or queries Knowledge (Sim, Lore, Agents via `IRetrievalPipeline`, HoneyHub when live). The canary makes this a compile-time failure at Knowledge's own CI, not a discovery at consumer sites. This matches the pattern ADR-0016, ADR-0017, ADR-0018, and ADR-0020 established of freezing the highest-traffic surfaces.

All four Knowledge-owned surfaces are in the canary from stand-up because Knowledge's boundary is narrow (four surfaces, no large auxiliary contract set) and all four are on the hot path for every real consumer. There is no lower-traffic tier to carve out.

## Consequences

### Unblocks

Accepting this ADR — and landing the follow-up scaffold packet that produces a first `Abstractions` release plus the `Providers.InMemory` backend — unblocks the Nodes currently waiting on Knowledge:

- **HoneyDrunk.Lore** — can compile its LLM-maintained wiki on top of `IRetrievalPipeline` and `IKnowledgeStore` without inventing its own ingestion or retrieval abstractions.
- **HoneyDrunk.Sim** — can ingest scenario fixtures through `IDocumentIngester` and exercise agents against deterministic retrieval via `Providers.InMemory`.
- **HoneyDrunk.Agents** — can compose `IRetrievalPipeline` into the agent execution path as a ground-truth source for grounded responses, without reaching into provider SDKs or embedding APIs directly.
- **HoneyDrunk.Evals** — can register deterministic retrieval fixtures via `Providers.InMemory` and assert against known-source ranked results.
- **HoneyHub (when live)** — can assign grounded-context tasks to agents by pre-loading Knowledge sources and referencing them from plans, without adopting a second RAG infrastructure.

### New invariants (proposed for `constitution/invariants.md`)

Numbering is tentative — scope agent finalizes at acceptance.

- **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Knowledge.Abstractions`.** Composition against `HoneyDrunk.Knowledge` and any `HoneyDrunk.Knowledge.Providers.*` package is a host-time concern. See D2.
- **Every retrieved chunk carries source attribution — the `KnowledgeSource` identity, the chunk's position, and the source version.** The `IRetrievalPipeline` interface contract guarantees this; provider packages that cannot preserve attribution cannot implement `IKnowledgeStore`. See D7.
- **Every `KnowledgeSource` records the embedding-model identifier used at ingest time, and a retrieval against a mismatched model errors or returns empty.** Knowledge never produces a cross-model similarity score. See D6.
- **Knowledge content never appears in telemetry.** Only metadata — source id, chunk count, query latency, result count, model identifier — may cross the telemetry boundary. See D10.
- **The Knowledge Node CI must include a contract-shape canary for `IKnowledgeStore`, `IDocumentIngester`, `IRetrievalPipeline`, and `KnowledgeSource`.** Shape drift on any of the four is a build failure, not a downstream discovery. See D12.

### Contract-shape canary becomes a requirement

The contract-shape canary in D12 is a gating requirement on the Knowledge Node's CI from the first scaffold. It is not a later hardening pass — the four frozen surfaces are the hot path for every Node that ingests or queries Knowledge and must be protected from day one.

### Catalog obligations

`catalogs/contracts.json` carries the four-surface seed for `honeydrunk-knowledge`, but `IKnowledgeSource` is seeded as an interface and must be promoted to the `KnowledgeSource` record with `kind: "type"` per D3. `catalogs/relationships.json`'s `exposes.contracts` list for `honeydrunk-knowledge` carries the same rename and must also add `honeydrunk-agents` to `consumed_by_planned` with a `consumes_detail` entry for `IRetrievalPipeline`. The `grid_relationship` prose in `catalogs/nodes.json` names Agents, Lore, and HoneyHub as consumers while the `relationships.json` edges list only Sim and Lore; the two must be reconciled to describe the same consumer set. `catalogs/grid-health.json` needs the Knowledge entry updated to reflect the stood-up contract surface and the contract-shape canary expectation. All reconciliations are tracked in the follow-up work section at the top of this ADR.

### Negative

- **Four exposed surfaces plus the embedding-model-coherence rule is more public surface than a minimal "single `IKnowledgeStore`" design would ship.** The trade is clarity of responsibility, correctness of cross-model retrieval, and independent testability against modestly more contract surface to version. Given the contract-shape canary on all four surfaces, the extra surface costs little to maintain.
- **Promoting `IKnowledgeSource` to `KnowledgeSource` is a catalog rename that breaks any prose reference to `IKnowledgeSource` already in repo docs.** The rename is necessary to apply the grid-wide naming rule consistently and is a one-time cost accepted at stand-up rather than deferred.
- **Shipping `Providers.InMemory` at stand-up without Azure AI Search or Postgres pgvector means no production-ready backend exists at first release.** Accepted: `InMemory` is enough to unblock Sim, Lore, Agents, and Evals on the contract surface, and the first production backend lands under its own issue packet once a real consumer needs it.
- **Deferring the ingest-time content-safety pipeline (D11) means ingestion accepts any document the caller passes in.** Operator's `ISafetyFilter` on the retrieval side covers the immediate need; if an ingestion-side gate becomes necessary, it lands under its own ADR and composes Operator rather than inventing a second safety model.
- **Deferring level (c) embedding-model coherence (router-level pinning) means callers can in principle configure the embedding model and get a clean error on mismatch rather than being prevented from requesting the wrong model in the first place.** Accepted at stand-up; the pinning surface belongs in the routing layer, not in Knowledge, and ADR-0010 is still Proposed.
- **Pulse ingress back into Knowledge (reactive tuning) is deferred.** Operator-driven tuning via App Configuration covers the stand-up need; automatic reactive tuning of chunking strategy or ranking weights is a later concern and matches the emit-only stance every prior AI-sector stand-up took.

## Alternatives Considered

### Fold Knowledge into HoneyDrunk.Memory

Rejected. Memory owns agent-generated, subjective context (what an agent learned or decided across executions). Knowledge owns externally sourced, objective information (documents, APIs, datasets). The two have different lifecycles (agent executions vs operator-driven ingest/re-ingest), different access rules (per-agent scope vs Grid-wide attribution), and different storage semantics (append-with-summarization vs supersede-on-new-version). Folding them would collapse both surfaces into a single conflated model and would force every consumer to reason about "is this chunk something an agent decided or something a document said" from the storage layer up.

### Fold Knowledge into HoneyDrunk.Lore

Rejected. Knowledge is infrastructure; Lore is an application that uses the infrastructure to build an LLM-maintained wiki. Folding Knowledge into Lore would prevent Sim, Agents, and HoneyHub (when live) from reaching the retrieval substrate without pulling in Lore's wiki-compilation pipeline, which none of them need. The split (Knowledge as substrate, Lore as application on top) matches the same responsibility layering ADR-0020 drew for Agents (substrate) and Flow (application composing agents into workflows).

### Keep `IKnowledgeSource` as an interface

Rejected per Q1. `IKnowledgeSource` carries metadata (origin, version, last-updated timestamp, embedding-model identifier) — a value shape, not a behaviour surface. The grid-wide naming rule applies: records drop the `I` prefix and are cataloged with `kind: "type"`. `ModelCapabilityDeclaration` (ADR-0016), `CapabilityDescriptor` (ADR-0017), and the four governance records in ADR-0018 set the precedent. Keeping `IKnowledgeSource` as an interface would create a second convention in the catalog and make the naming rule unenforceable.

### Ship `HoneyDrunk.Knowledge.Testing` separate from `Providers.InMemory` at stand-up

Deferred per Q2. `Providers.InMemory` already plays the role of a deterministic, zero-network backend that downstream test projects can compose. Adding a second `Testing` package at stand-up would duplicate that role or force an awkward split (fixture helpers in `Testing`, backend in `Providers.InMemory`). If a real need for shared test helpers emerges (fixture builders, deterministic clock hooks, recording loggers), `HoneyDrunk.Knowledge.Testing` ships later under its own packet. The stand-up commitment is the four-surface contract plus the `InMemory` provider; test ergonomics on top is a follow-on concern.

### Strict router-level embedding-model-coherence enforcement (level c) at stand-up

Deferred per Q3. Level (b) coherence — `KnowledgeSource` records the ingest-time model and retrieval errors on mismatch — is the correctness floor and lands in this ADR. Level (c) — router-level pinning so callers cannot even request a mismatched model — is a routing concern and belongs in `IModelRouter` per ADR-0010. ADR-0010 is still Proposed; layering a pinning surface on a not-yet-accepted router is premature. The level (b) floor is sufficient for the first-wave consumers (Sim, Lore, Agents, Evals); level (c) can compose on top without changing Knowledge's contract when the routing layer accepts.

### Content-safety scanning at ingest time

Deferred per Q7. Operator's `ISafetyFilter` (ADR-0018 D3) already covers the immediate need on the retrieval/output side: when a chunk flows out of Knowledge toward an agent or a user-facing path, the safety filter runs on the output boundary. Adding an ingest-side pipeline at stand-up would duplicate a capability Operator already owns and would create a second safety model in the AI sector. If a future use case requires rejecting content at ingest rather than filtering at retrieval, the concern gets its own ADR and likely composes Operator's existing `ISafetyFilter` on the ingest side.

### Pulse signal ingress into Knowledge at stand-up

Deferred. Reactive closed-loop tuning — where observed telemetry from Pulse automatically adjusts chunking strategy, retrieval ranking weights, or index rebuild cadence — is the same class of concern ADR-0018 flagged for Operator and ADR-0020 flagged for Agents. It is not a stand-up decision. Emit-only at stand-up is the committed direction; any future ingress contract will be added as a distinct ADR concern.

### Defer the Knowledge stand-up until Lore or Sim needs it

Rejected. This is a mirror of the argument ADR-0016, ADR-0017, ADR-0018, and ADR-0020 rejected for AI, Capabilities, Operator, and Agents. Letting Lore and Sim each invent their own ingestion pipeline, chunking strategy, embedding orchestration, and retrieval model produces N incompatible surfaces with no shared attribution guarantee, no shared embedding-model coherence rule, and no shared provider slot. The AI sector's foundation is AI (inference) + Capabilities (tools) + Operator (policy) + Agents (runtime) + Knowledge (external information) + Memory (agent context); standing up five of six and deferring Knowledge leaves downstream applications (Lore, Sim, HoneyHub when live) blocked on a substrate that nobody owns.
