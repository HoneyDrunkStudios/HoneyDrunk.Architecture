# ADR-0022: Stand Up the HoneyDrunk.Memory Node — Agent-Memory Substrate for the AI Sector

**Status:** Proposed
**Date:** 2026-04-19
**Deciders:** HoneyDrunk Studios
**Sector:** AI

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Reconcile `catalogs/contracts.json` entries for `honeydrunk-memory`: confirm the three stand-up interfaces (`IMemoryStore`, `IMemoryScope`, `IMemorySummarizer`) already seeded in the catalog, and flag that no records are introduced at stand-up (record shapes — including the `MemoryEntry` shape that carries the embedding-model identifier per D6 — are a scaffold-packet concern)
- [ ] Update `catalogs/relationships.json` for `honeydrunk-memory`:
  - Add `IChatClient` to the Memory → AI `consumes_detail` list alongside `IEmbeddingGenerator` (summarization uses `IChatClient` from `HoneyDrunk.AI.Abstractions` per D5)
  - Add `honeydrunk-agents` to `consumed_by_planned` with a `consumes_detail` entry listing `IMemoryStore`, `IMemoryScope`, and `HoneyDrunk.Memory.Abstractions` (coordinate with the open ADR-0020 follow-up item on the Agents side so the two edges land in one reconciliation pass, not two)
- [ ] Reconcile `grid_relationship` prose in `catalogs/nodes.json` for `honeydrunk-memory` against the `catalogs/relationships.json` edges once the AI detail and the Agents consumer edge are added — prose and edges must describe the same contract set
- [ ] Update `catalogs/grid-health.json` `honeydrunk-memory` entry to reflect the stood-up contract surface and the contract-shape canary expectation
- [ ] Wire the contract-shape canary into Actions for `IMemoryStore`, `IMemoryScope`, and `IMemorySummarizer`
- [ ] Add `integration-points.md` and `active-work.md` to `repos/HoneyDrunk.Memory/`, matching the template used by `repos/HoneyDrunk.Agents/` and `repos/HoneyDrunk.Knowledge/`
- [ ] Correct short-term memory ownership prose in `repos/HoneyDrunk.Memory/overview.md`, `repos/HoneyDrunk.Memory/boundaries.md`, and `constitution/ai-sector-architecture.md` to reflect Position A (short-term memory is owned by Agents's `IAgentExecutionContext`; Memory owns long-term only). The current wording lists short-term memory under Memory's owned surface, which contradicts this ADR and ADR-0020 D8
- [ ] File the HoneyDrunk.Memory scaffold packet (solution structure, `HoneyDrunk.Standards` wiring, CI pipeline, `HoneyDrunk.Memory.Providers.InMemory` fixture, default implementations of `IMemoryStore`, `IMemoryScope`, and `IMemorySummarizer`, and the embedding-model-identifier carry through the `MemoryEntry` record shape per D6)
- [ ] Scope agent assigns final invariant numbers when flipping Status → Accepted

## Context

`HoneyDrunk.Memory` is cataloged in `catalogs/nodes.json` as the AI sector's agent-memory substrate, but the repo is cataloged-not-yet-created — no packages, no contracts, no store, no scope primitive, no summarizer, no CI. Agents, Flow, Sim, and HoneyHub (when live) all need a shared way for agents to remember context across executions — per-agent scope, Grid-wide scope rules, and summarization when memory grows beyond its threshold — and none of them own that responsibility. Without a dedicated substrate, each Node ends up inventing its own scope primitive, its own storage shape, and its own summarization strategy, and the agent-memory surface fragments across the AI sector.

ADR-0016 stood up HoneyDrunk.AI as the inference substrate. ADR-0017 stood up HoneyDrunk.Capabilities as the tool-registry and dispatch substrate. ADR-0018 stood up HoneyDrunk.Operator as the human-policy enforcement and audit substrate. ADR-0020 stood up HoneyDrunk.Agents as the agent-runtime foundation node that composes those three substrates into a runnable agent. ADR-0021 stood up HoneyDrunk.Knowledge as the external-information ingestion and retrieval substrate. Memory is the next AI-sector foundation node and closes the **foundation triad** of agent-facing substrates: Agents (runtime identity and lifecycle), Knowledge (externally sourced information), Memory (agent-generated, subjective context). Every first-wave consumer (Flow, Sim, Lore, HoneyHub when live, Evals) compiles against at least one leg of the triad, and nothing inside the AI sector can be called "ready for an agent to run end-to-end" until all three are stood up.

The stand-up pattern is deliberately reused: contracts live in an `Abstractions` package, runtime composition is a separate package, downstream Nodes compile against `Abstractions` only, and a first-wave `Providers.InMemory` package ships at stand-up so consumers have one shared in-memory backend they can compose in tests and in local development without standing up SQL Server or Cosmos DB.

The `catalogs/contracts.json` entry for `honeydrunk-memory` already lists three interfaces (`IMemoryStore`, `IMemoryScope`, `IMemorySummarizer`). All three are correctly interfaces — Memory's stand-up surface is all behaviour, no value shapes at the cataloged level. The `MemoryEntry` record that carries per-entry metadata (identity, timestamp, embedding-model identifier, scope coordinates) is a scaffold-packet concern and is deferred from this ADR the same way ADR-0020 D3 deferred agent record shapes and ADR-0021 D3 deferred retrieval request/response shapes. Any records introduced at scaffold apply the grid-wide naming rule already applied by `ModelCapabilityDeclaration` in ADR-0016, `CapabilityDescriptor` in ADR-0017, the four governance records in ADR-0018, and `KnowledgeSource` in ADR-0021 — records drop the `I` prefix and are cataloged with `kind: "type"`.

Memory's boundary against the adjacent Nodes needs explicit disambiguation before drift creeps in, and two pieces of existing prose must be named as drift so they can be corrected in follow-up:

1. **Memory vs Agents.** The `repos/HoneyDrunk.Memory/overview.md` and `repos/HoneyDrunk.Memory/boundaries.md` files currently describe short-term (conversation-scoped) memory as Memory-owned. ADR-0020 D8 pinned execution-scope state (including the in-progress tool-call sequence, the open memory scope reference, and conversation-turn state for the running execution) inside `IAgentExecutionContext`. This ADR resolves the overlap definitively (D4, D7): short-term memory that lives only for the duration of a single agent execution is Agents's, carried on `IAgentExecutionContext`; long-term memory that must survive across executions is Memory's, backed by `IMemoryStore`. The current prose in Memory's repo docs and in `constitution/ai-sector-architecture.md` where it claims short-term ownership for Memory is corrected as follow-up work.
2. **Memory vs Knowledge.** Memory owns agent-generated, subjective context (what an agent learned or decided across its own executions). Knowledge owns externally sourced, objective information (documents, APIs, datasets). Both share the embedding infrastructure in HoneyDrunk.AI via `IEmbeddingGenerator` per ADR-0016 D3, but they are semantically and operationally distinct and their storage, lifecycle, and access rules differ. This is the mirror of the boundary ADR-0021 D4 drew from the Knowledge side, restated here from the Memory side.
3. **Memory vs Flow.** Conversation transcripts — the multi-turn exchange between a user (or system) and an agent — are Memory's, with each turn stored as a `MemoryEntry`. Workflow state — the between-step state of a multi-agent or multi-step Flow pipeline — is Flow's. A transcript is not a workflow; a workflow is not a transcript. This is pinned in D4 and in D9.
4. **Memory vs Operator.** Operator owns human-policy and audit. Memory owns agent-generated storage. When an operational concern touches Memory — bulk read of a user's memories for audit, bulk delete for right-to-erasure, cross-agent access for an operator view — the policy decision is Operator's (via `IApprovalGate` and `IDecisionPolicy` per ADR-0018), and Memory enforces the access shape the policy permits. Pinned in D6 and D11.

There is one additional concern to pin at stand-up: **embedding-model coherence** on the agent-memory side. The same hazard ADR-0021 D6 pinned for Knowledge applies here in a softer form — a memory is only retrievable by similarity search if the query embedding and the stored memory embedding came from the same model. Memory's rule is level (b) coherence (per D6): each `MemoryEntry` records the embedding-model identifier used at write time; similarity retrieval against a mismatched model errors or returns empty rather than silently producing wrong results. Router-level pinning (level c) remains deferred to ADR-0010 alongside Knowledge's level (c) deferral.

This ADR is the **stand-up decision** for the Memory Node — what it owns, what it does not own, which contracts it exposes, how downstream Nodes couple to it, and how it interacts with AI, Agents, Knowledge, Operator, and Flow. "Node" is used throughout in the ADR-0001 sense — a library-level building block producing one or more NuGet packages, not a deployable service. This ADR is not a scaffolding packet. Filing the repo, adding CI, wiring the in-memory provider, and producing the first shippable packages all follow as separate issue packets once this ADR is accepted.

## Decision

### D1. HoneyDrunk.Memory is the AI sector's agent-memory substrate

`HoneyDrunk.Memory` is the single Node in the AI sector that owns **agent-generated memory primitives** — the contracts and runtime machinery that persist what an agent learned or decided across executions, scope that memory by tenant/project/agent so an agent only sees its authorized entries, summarize memories when they grow beyond a configured threshold, and delegate embedding calls and summarization inference to HoneyDrunk.AI. It is a shared substrate, not an application. It does not decide *what an agent should remember*; it owns the mechanics of *how an agent-generated entry is written, scoped, retrieved, summarized, and forgotten*.

Memory *content* — the actual entries, the summarization thresholds, the retention policy — is decided by the consumers (Agents drives the write path during execution; Operator drives retention and erasure policy via `IDecisionPolicy`; Sim seeds memories for scenario runs). Memory provides the storage, scoping, summarization orchestration, and retrieval primitives; consumers provide the entries and the policies.

Memory, together with Agents and Knowledge, forms the **foundation triad** of agent-facing AI-sector substrates. Agents is the runtime skeleton (who is doing the thinking); Knowledge is the objective-information surface (what the outside world knows); Memory is the subjective-context surface (what this agent remembers from its own runs). Each of the three has a narrow, well-defined owner, and each compiles only against its own `Abstractions` plus Kernel's and AI's.

### D2. Package families

The Memory Node ships the following package families, mirroring the stand-up shape used by ADR-0016 (AI), ADR-0017 (Capabilities), ADR-0018 (Operator), ADR-0020 (Agents), and ADR-0021 (Knowledge):

- `HoneyDrunk.Memory.Abstractions` — all interfaces, the `MemoryEntry` record when introduced at scaffold, and the scope/query request/response shapes. Zero runtime dependencies beyond `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.AI.Abstractions` (for `IEmbeddingGenerator` on the similarity-search path and `IChatClient` on the summarization path — see D5).
- `HoneyDrunk.Memory` — runtime composition: default `IMemoryStore`, default `IMemoryScope`, default `IMemorySummarizer`, DI wiring. Takes a first-class runtime dependency on `HoneyDrunk.AI.Abstractions` for embedding and summarization calls (see D5), and on `HoneyDrunk.Auth.Abstractions` for the scope-escalation policy gate (see D6).
- `HoneyDrunk.Memory.Providers.InMemory` — in-memory backend for `IMemoryStore`. Zero-network, deterministic, suitable for tests, local development, and Evals fixtures. Consumed by downstream Nodes in test projects and in local composition; never in production composition.

Two additional provider slots are named in the repo overview — `HoneyDrunk.Memory.Providers.SqlServer` and `HoneyDrunk.Memory.Providers.CosmosDB`. Those provider packages are **not first-wave**. They ship under separate issue packets once `InMemory` has exercised the provider-slot shape and once the first real production consumer (Agents running outside of dev/test, or HoneyHub when live) has landed a persistence requirement. The stand-up commitment is the contract surface plus `InMemory`; production backends follow.

No separate `HoneyDrunk.Memory.Testing` package is introduced at stand-up. The `Providers.InMemory` package already plays that role — it is the in-memory backend every downstream test project can compose. This matches the pattern ADR-0021 D2 set for Knowledge; Memory is a stores-and-providers Node where the in-memory fixture is a production-shaped backend under the provider-slot family, not a test-only artifact. If a real need for shared test helpers emerges later (fixture builders, deterministic clock hooks, recording loggers), `HoneyDrunk.Memory.Testing` ships later under its own packet.

### D3. Exposed contracts

Three interfaces form the Memory Node's public boundary at stand-up. These are the surfaces downstream Nodes are allowed to compile against:

| Contract | Kind | Purpose |
|---|---|---|
| `IMemoryStore` | interface | Write, read, search, and delete memory entries. The storage-facing surface that provider packages implement. |
| `IMemoryScope` | interface | Scoped memory access — an agent only sees its authorized memories through a resolved scope. Gates cross-scope access via the Auth policy path (see D6). |
| `IMemorySummarizer` | interface | Compress memory entries beyond a configured threshold. Delegates embedding generation to `IEmbeddingGenerator` and summarization inference to `IChatClient` (both from HoneyDrunk.AI per D5). Kept public so consumers can swap the summarization strategy. |

All three surfaces are interfaces at stand-up. No records are introduced in this ADR. The `MemoryEntry` record (per-entry metadata: entry identity, scope coordinates, timestamp, embedding-model identifier, optional summary-of relationship to a superseded entry) and any query/response record shapes are **deferred to the scaffold packet**. The stand-up contract is the three interfaces named above and the principle that any records introduced at scaffold apply the grid-wide naming rule (records drop the `I` prefix, interfaces retain it). Catalog entries use `kind: "interface"` for the three contracts in this ADR and `kind: "type"` for any records the scaffold packet introduces. No `kind: "record"` is used anywhere in the catalog schema.

This matches the deferral pattern ADR-0020 D3 used for agent record shapes (principle fixed at ADR, record shapes at scaffold) and ADR-0021 D3 used for retrieval request/response shapes.

### D4. Boundary rule with Agents, AI, Knowledge, Flow, and Operator (definitive)

The surrounding Nodes need an explicit boundary test so that drift does not creep in once Memory ships. The rule below is the decision test Memory applies when an ambiguous concern is proposed.

**Decision test — for any concern in the agent-memory path, ask:**

1. Does it compute an embedding vector or a chat/summarization completion against a model? → **AI** (Memory delegates to `IEmbeddingGenerator` and `IChatClient`).
2. Does it manage agent identity, lifecycle, execution context, or conversation-turn state scoped to a single running execution? → **Agents** (short-term memory lives on `IAgentExecutionContext`; see D7).
3. Does it ingest, chunk, store, or retrieve *externally sourced* information (documents, web content, API responses, structured data)? → **Knowledge**.
4. Does it persist, scope, retrieve, or summarize *agent-generated* content (what an agent learned or decided across its executions, including long-lived conversation transcripts)? → **Memory**.
5. Does it coordinate multiple agents or sequence multi-step workflow state (between-step intermediate state, compensation state, step-level inputs and outputs)? → **Flow**.
6. Does it decide whether an operational action on agent-generated data (bulk read, bulk delete, cross-scope access) is permitted, or audit such an action? → **Operator** (Operator owns the policy; Memory enforces the access shape; see D6 and D11).

Under this test, several subtleties are worth naming explicitly:

- **Short-term memory is Agents's, not Memory's (Position A).** The short-term/long-term split that previously lived in Memory's repo docs is resolved here: execution-scope conversation state, the in-progress turn sequence, and any context that only needs to survive until `IAgentLifecycle.complete` runs lives on `IAgentExecutionContext`, owned by Agents per ADR-0020 D8. Memory owns only what must survive the end of the execution. This boundary is load-bearing: it prevents two Nodes from holding the same conversation turn under different names and it keeps Memory's storage surface from being pulled into the hot execution path of every agent tick.
- **Conversation transcripts *are* Memory's — each turn is a `MemoryEntry`.** When a transcript needs to persist across executions (the user talks to the same agent tomorrow and expects continuity), each turn is written as a `MemoryEntry` through `IMemoryStore` and scoped through `IMemoryScope`. This is agent-generated content and it lives in Memory. The distinction from short-term memory is the lifetime: a transcript turn that only matters for the current agent tick stays on `IAgentExecutionContext`; a transcript turn that must be there next time the user talks to the agent is a Memory write.
- **Workflow state is Flow's, not Memory's.** Between-step intermediate state in a Flow pipeline (the result of step 1 being consumed by step 2, compensation state, step-level retry counters) is Flow's storage concern. Memory does not store workflow state even if a workflow step happens to invoke an agent whose memory writes happen during the step.
- **Knowledge and Memory both use `IEmbeddingGenerator` — that is not overlap.** Both Nodes compose AI's embedding surface per ADR-0016 D3. They do not share storage, they do not share scope semantics, and they do not share attribution rules. The shared dependency on AI is a shared-substrate pattern, not a responsibility blur.

`catalogs/relationships.json` currently lists Memory's `consumes` as `honeydrunk-kernel`, `honeydrunk-ai`. The AI edge is under-specified — it lists `IEmbeddingGenerator` but does not list `IChatClient`, which Memory's default `IMemorySummarizer` consumes per D5. The Agents edge on `consumed_by_planned` is missing. Both corrections are tracked in the follow-up work section at the top of this ADR and are coordinated with the open ADR-0020 Agents→Memory edge so the reconciliation lands in one pass.

### D5. Embedding and summarization inference compose upstream — Memory does not re-implement model access

`IMemoryStore`'s similarity-search path takes an optional embedding for its query shape. The default implementation in `HoneyDrunk.Memory` does not generate that embedding itself — it calls `IEmbeddingGenerator` from `HoneyDrunk.AI.Abstractions` per ADR-0016 D3. The write-side embedding for a new `MemoryEntry` (for future similarity retrieval) is also generated via `IEmbeddingGenerator`. Memory does not invent its own embedding abstraction, does not talk to model providers directly, and does not cache embeddings in a way that bypasses AI's telemetry or cost accounting.

`IMemorySummarizer`'s compression path is new surface for this stand-up: when memories grow beyond the configured threshold, the default summarizer calls `IChatClient` from `HoneyDrunk.AI.Abstractions` to produce the compressed summary, then re-embeds the summary via `IEmbeddingGenerator`, writes a new summary `MemoryEntry`, and supersedes the originals. This is why Memory's runtime edge to AI is **both** `IEmbeddingGenerator` and `IChatClient`, not `IEmbeddingGenerator` alone — the current catalog wording must be widened. Summarization is inference, not just vector math, and inference goes through AI.

Downstream Nodes that compile against `HoneyDrunk.Memory.Abstractions` see `IMemoryStore`, `IMemoryScope`, and `IMemorySummarizer` as plain interfaces. They inherit a transitive compile-time dependency on `HoneyDrunk.AI.Abstractions` through `Abstractions` shapes that reference AI types — this is accepted and matches the way ADR-0020 D5 and D6 and ADR-0021 D5 treated upstream `Abstractions`-level edges. The runtime edge to `HoneyDrunk.AI` (composition, router selection, provider choice) is still resolved at the host, not at the consumer.

### D6. `IMemoryScope.Escalate()` is gated by Auth; bulk operational reads route through Operator's `IApprovalGate`

`IMemoryScope` is the authorization-window primitive for agent memory — an agent only sees entries whose scope coordinates match the resolved scope. The normal path is narrow and automatic: an agent runs under a given `(TenantId, ProjectId, AgentId)` and its resolved scope mechanically constrains reads to that tuple. No authorization question is raised on the hot path.

There are two escape paths that do raise an authorization question, and this ADR pins both:

- **Scope escalation from within the agent path — `IMemoryScope.Escalate()`.** When an agent needs to read beyond its normal scope (for example, a coordinator agent needing to consult another agent's memory for handoff), the escalation surface is `IMemoryScope.Escalate()` and it is gated by the Auth policy path — Memory's default scope implementation composes `IAuthenticatedIdentityAccessor` and `IAuthorizationPolicy` from `HoneyDrunk.Auth.Abstractions` and asks Auth whether the current identity is permitted to widen the scope. A denied escalation errors; an approved escalation returns a widened scope that Memory then enforces on subsequent reads. This keeps the authorization decision in Auth (the Grid's single source of identity and policy) and keeps Memory enforcing the shape the decision permits, matching the layering ADR-0017 D5 set for Capabilities → Auth and ADR-0018 D5 set for Operator → Auth.
- **Bulk operational reads from outside the agent path — routed through Operator's `IApprovalGate`.** Operational flows (an administrative view of a tenant's memories, an audit export, a cross-agent debug read) do not run under an agent's resolved scope and are not the same concern as `Escalate()`. These routes go through Operator's `IApprovalGate` per ADR-0018: the caller raises an `ApprovalRequest`, a human decision is recorded as an `ApprovalDecision`, Operator's `IAuditLog` appends the decision, and the bulk read only proceeds if the gate returns approved. Memory exposes a bulk-read shape on `IMemoryStore` that the Operator-mediated path consumes; raw provider-level access (bypassing `IMemoryStore`) is not permitted for operational flows.

The split between the two escape paths is deliberate. `IMemoryScope.Escalate()` is an agent-runtime concern — it happens inside an agent execution, is synchronous, and has a policy question that Auth can answer immediately. Bulk operational reads are a human-policy concern — they happen outside any agent execution, may require asynchronous human approval, and need the full approval/audit trail Operator already owns. Using `IApprovalGate` for every `Escalate()` call would drag Operator into every agent execution that legitimately needs a slightly wider scope; using `Escalate()` for bulk operational reads would bypass the human approval and audit that those reads require.

### D7. State boundary — Memory holds long-term agent-generated state; Agents holds execution-scope state

Memory holds **long-term agent-generated state** — the persistent store of memory entries (including cross-execution conversation transcripts), their scope coordinates, their embeddings, their summarization lineage, and their retention metadata. All of this is backed by the configured provider (SQL Server, Cosmos DB, InMemory) via `IMemoryStore` and is the source of truth for what an agent remembers across its executions.

Memory does **not** hold:

- **Short-term, execution-scoped state.** That is Agents's job — `IAgentExecutionContext` per ADR-0020 D8 holds the current tool-call sequence, the in-progress inference state, and any conversation-turn state that only needs to live until `IAgentLifecycle.complete` runs. When the execution ends, that state is disposed with the context; it does not flow into Memory unless the agent explicitly writes a `MemoryEntry`.
- **Workflow state.** That is Flow's job. If a memory write is one step in a larger workflow, the between-step intermediate state lives in Flow, not in Memory.
- **Audit trail.** That is Operator's job. Memory writes, reads, and deletes emit telemetry per D10, but the immutable record of *who did what and when on an approval-gated operation* lives in Operator's `IAuditLog`. Memory does not duplicate the audit record.
- **Content-safety decisions.** That is Operator's `ISafetyFilter` on the agent output path per ADR-0018 D3. Memory stores what it is told to store; filtering what an agent is allowed to *reveal* from its memory on an output boundary is an Operator concern.

The rule is: if a piece of agent-adjacent data must survive the end of the `IAgent` execution, it is Memory's (if it is agent-generated content) or Flow's (if it is workflow between-step state) or Operator's (if it is approval/audit/cost record). Agents holds everything execution-local and ephemeral; Memory holds everything long-term and agent-generated.

### D8. Memory content never leaves the store except through `IMemoryStore`

Provider packages must preserve the `IMemoryStore` and `IMemoryScope` contract. No provider may return memory content through a surface other than `IMemoryStore` — no direct database handle, no raw ADO query, no "advanced" escape hatch that bypasses the scope check. This is the same shape ADR-0021 D7 set for Knowledge's attribution guarantee: providers that cannot preserve the contract cannot implement the interface.

The reason is that `IMemoryScope` enforcement is the Grid's authorization boundary for agent-generated content. Letting a consumer query the provider directly would bypass scope enforcement and let an agent (or a badly-scoped call site) read another agent's memories. Every production path for reading or writing a memory goes through `IMemoryStore`, and `IMemoryStore` is the single surface where the scope check is applied.

This extends `repos/HoneyDrunk.Memory/invariants.md` item 2 ("Memory scoping is mandatory") from a Node-local invariant to a Grid-level one. The cost of enforcing the rule at the interface level is small; the cost of finding out at a consumer site that a badly-scoped call read another tenant's memories is very large.

### D9. Telemetry emission — Pulse consumes, Memory does not depend; content never leaves the store

Memory emits telemetry for every write (scope coordinates, entry size, embedding-model identifier, duration), every read/search (scope coordinates, result count, query latency, embedding-model identifier, provider identity), every summarization event (source entry count, summary entry identity, embedding-model identifier), and every delete or supersede (scope coordinates, entry count) via Kernel's `ITelemetryActivityFactory`. Pulse consumes that telemetry downstream. **Memory has no runtime dependency on Pulse.** The direction is one-way by contract: Memory emits, Pulse observes. Same rule as ADR-0016 D7 for AI, ADR-0017 D7 for Capabilities, ADR-0018 D7 for Operator, ADR-0019 D7 for Communications, ADR-0020 D9 for Agents, and ADR-0021 D10 for Knowledge.

Critically, **Memory content never appears in telemetry**. The telemetry surface carries metadata only — scope coordinates, entry identity, entry size, query latency, result count, model identifier — never the actual memory payload, query text, or retrieved content. This extends `repos/HoneyDrunk.Memory/invariants.md` item 5 to the Grid level. The separation is structural, not advisory: the telemetry activity factory never receives content payloads from Memory code paths.

Pulse signal ingress back into Memory — reactive tuning of summarization threshold, retention cadence, or scope-resolution caching based on observed telemetry — is out of scope for stand-up. It is flagged in Alternatives Considered as a deferred concern and matches the emit-only stance every prior AI-sector stand-up took.

### D10. Embedding-model coherence — `MemoryEntry` records the ingest-time model; mismatched similarity retrieval errors

Every `MemoryEntry` (introduced at scaffold per D3) carries an explicit **embedding-model identifier** — the `ModelCapabilityDeclaration` identity (or equivalent stable string from ADR-0016's model-capability surface) of the model that produced the embedding stored for that entry. This is not advisory metadata; it is a contract field on the record, the same role `KnowledgeSource` plays for Knowledge per ADR-0021 D6.

The similarity-retrieval rule is deterministic: `IMemoryStore`'s similarity search must produce its query vector using a model that matches the stored entries' embedding-model identifier. If the caller's configured embedding model does not match the stored entries' recorded model, the search **errors or returns an empty result set** for those entries — it never produces a cross-model similarity score. This is the stand-up's level (b) coherence guarantee on the memory side, consistent with the coherence floor ADR-0021 D6 set for Knowledge.

Stricter **level (c) coherence** — router-level pinning that prevents a caller from even requesting a mismatched model, centralised through `IModelRouter` so embedding-model choice is policy-driven rather than caller-driven — is flagged as a later concern and is not in scope for this stand-up. ADR-0010 (which introduces `IModelRouter` and `IRoutingPolicy`) is still Proposed, and router-level pinning is a routing concern, not a Memory concern. The Memory Node records the model identifier and enforces coherence at the similarity-retrieval boundary; the routing layer, when it lands, may add the pinning policy on top without changing Memory's contract. This deferral is symmetric with ADR-0021 D6.

Re-embedding an entry under a new model is treated as supersession: the old entry is superseded, a new entry with the new embedding-model identifier is written, and future similarity retrieval uses the new model. This keeps the coherence rule compatible with operator-driven model migrations.

### D11. Right-to-erasure and bulk-delete contract — principle pinned, surface deferred

Operational concerns around retention and erasure are real — a user requests deletion of their historical conversations, a tenant churns and their agent memories must be purged, an operator needs to force-delete a range of memories for compliance. The **principle** is pinned at stand-up:

- **Policy lives in Operator.** Retention windows, right-to-erasure triggers, bulk-delete approval rules, and the human-policy decision about whether a given bulk operation is permitted all live in Operator via `IDecisionPolicy` per ADR-0018, are approved via `IApprovalGate`, and are audit-recorded via `IAuditLog`.
- **Enforcement lives in Memory.** When Operator decides a bulk-delete is permitted, the actual delete executes through Memory's `IMemoryStore` — the same surface D8 pins as the only way memory content crosses the Node boundary.

The **bulk-delete API surface** itself — the exact shape of a bulk-delete request on `IMemoryStore`, how it interacts with scope, how it handles partial failure, how it interacts with summarized entries whose originals are being deleted — is **deferred**. The stand-up surface is per-entry and per-scope delete only. A full bulk-delete / right-to-erasure API lands under its own ADR once Operator's `IDecisionPolicy` shape is concrete (ADR-0018 is Proposed; the policy surface matures before Memory depends on it) and once the first real erasure request drives the shape decision. This deferral is named explicitly in Alternatives Considered.

The ingest-side symmetry with Knowledge holds: ingest-time content-safety scanning is Operator's `ISafetyFilter` concern on the output boundary per ADR-0018 D3 and ADR-0021 D11, not a Memory ingest-time concern. If an ingest-side scan becomes necessary, it composes Operator, not a second safety model inside Memory.

### D12. Contract-shape canary

A contract-shape canary is added to the Memory Node's CI: it fails the build if any of the following three surfaces change shape (method signatures, parameter shapes, record members when records land at scaffold) without a corresponding version bump:

- `IMemoryStore`
- `IMemoryScope`
- `IMemorySummarizer`

All three Memory-owned surfaces are in the canary from stand-up because Memory's boundary is narrow (three surfaces, no large auxiliary contract set) and all three are on the hot path for every real consumer. Accidental shape drift on any of them breaks every Node that reads or writes agent memory (Agents via `IMemoryScope` and `IMemoryStore`, Flow via Memory composition, Sim via fixture writes, Evals via deterministic memory seeds, HoneyHub when live). The canary makes this a compile-time failure at Memory's own CI, not a discovery at consumer sites. This matches the pattern ADR-0016, ADR-0017, ADR-0018, ADR-0020, and ADR-0021 established of freezing the hot-path surfaces.

When the `MemoryEntry` record lands at the scaffold packet, its shape is added to the canary the same way `KnowledgeSource` is in ADR-0021 D12.

## Consequences

### Unblocks

Accepting this ADR — and landing the follow-up scaffold packet that produces a first `Abstractions` release plus the `Providers.InMemory` backend — unblocks the Nodes currently waiting on Memory:

- **HoneyDrunk.Agents** — can compile its default `IAgentMemory` implementation against `IMemoryStore` and `IMemoryScope` per ADR-0020 D6 without inventing its own storage or scope abstractions. The Agents→Memory edge that ADR-0020 flagged as missing from the relationships catalog becomes real.
- **HoneyDrunk.Flow** — can compose single-agent executions with persistent memory writes across workflow steps without owning memory storage.
- **HoneyDrunk.Sim** — can seed scenario-specific memory fixtures through `Providers.InMemory` and exercise agents against deterministic memory states.
- **HoneyDrunk.Evals** — can register deterministic memory fixtures and assert against scope-enforced memory reads.
- **HoneyDrunk.Lore** — can persist agent-generated curation decisions across runs through Memory, separate from the externally-sourced knowledge Lore compiles through ADR-0021.
- **HoneyHub (when live)** — can assign context-aware tasks to agents that carry per-agent learned context across sessions, without adopting a second storage substrate.

### New invariants (proposed for `constitution/invariants.md`)

Numbering is tentative — scope agent finalizes at acceptance.

- **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Memory.Abstractions`.** Composition against `HoneyDrunk.Memory` and any `HoneyDrunk.Memory.Providers.*` package is a host-time concern. See D2.
- **Agents never persist agent-generated state outside `IMemoryStore` and `IMemoryScope`.** Execution-scope state stays on `IAgentExecutionContext`; anything that must survive the execution is written through Memory's surface. See D7 and ADR-0020 D8.
- **Memory content never leaves the Node except through `IMemoryStore`.** Provider packages may not expose raw database handles, direct query surfaces, or any escape hatch that bypasses `IMemoryScope`. See D8.
- **Every `MemoryEntry` records the embedding-model identifier used at write time, and similarity retrieval against a mismatched model errors or returns empty.** Memory never produces a cross-model similarity score. See D10.
- **Memory content never appears in telemetry.** Only metadata — scope coordinates, entry identity, entry size, query latency, result count, model identifier — may cross the telemetry boundary. See D9.
- **`IMemoryScope.Escalate()` is gated by Auth; bulk operational reads are gated by Operator's `IApprovalGate`.** No escape path crosses scope without one of the two authorization paths. See D6.
- **The Memory Node CI must include a contract-shape canary for `IMemoryStore`, `IMemoryScope`, and `IMemorySummarizer`.** Shape drift on any of the three is a build failure, not a downstream discovery. See D12.

### Contract-shape canary becomes a requirement

The contract-shape canary in D12 is a gating requirement on the Memory Node's CI from the first scaffold. It is not a later hardening pass — the three frozen surfaces are the hot path for every Node that reads or writes agent memory and must be protected from day one.

### Catalog obligations

`catalogs/contracts.json` carries the three-interface seed for `honeydrunk-memory` that this ADR confirms; no rename or deprecation is required on the contracts catalog side and the follow-up work is a verification plus a flag that records are deferred to scaffold. `catalogs/relationships.json` for `honeydrunk-memory` must have the Memory → AI `consumes_detail` widened from `IEmbeddingGenerator` alone to include `IChatClient` (summarization path per D5), and must add `honeydrunk-agents` to `consumed_by_planned` with a `consumes_detail` entry for `IMemoryStore`, `IMemoryScope`, and `HoneyDrunk.Memory.Abstractions`. The latter edge is coordinated with the open ADR-0020 follow-up item on the Agents side so both directions of the edge land in one reconciliation pass. The `grid_relationship` prose in `catalogs/nodes.json` for Memory must match the reconciled edges. `catalogs/grid-health.json` needs the Memory entry updated to reflect the stood-up contract surface and the contract-shape canary expectation. All reconciliations are tracked in the follow-up work section at the top of this ADR.

### Negative

- **Three exposed surfaces plus the scope-escalation authorization rule plus the embedding-model-coherence rule is more public surface than a minimal "single `IMemoryStore`" design would ship.** The trade is clarity of responsibility, correctness of cross-model retrieval, scope enforcement at the interface level, and independent testability against modestly more contract surface to version. Given the contract-shape canary on all three surfaces, the extra surface costs little to maintain.
- **Correcting the short-term-memory ownership prose in `repos/HoneyDrunk.Memory/overview.md`, `repos/HoneyDrunk.Memory/boundaries.md`, and `constitution/ai-sector-architecture.md` is a follow-up docs edit that may surface downstream references.** Accepted: the corrected wording brings Memory's docs into agreement with ADR-0020 D8 and with this ADR, and any downstream reference to "Memory owns short-term memory" is fixed at the same time.
- **Shipping `Providers.InMemory` at stand-up without SQL Server or Cosmos DB means no production-ready backend exists at first release.** Accepted: `InMemory` is enough to unblock Agents, Flow, Sim, and Evals on the contract surface, and the first production backend lands under its own issue packet once a real consumer needs it.
- **Deferring the right-to-erasure and bulk-delete contract (D11) means the stand-up `IMemoryStore` has per-entry and per-scope delete only.** A full bulk-delete surface lands once Operator's `IDecisionPolicy` shape is concrete and once a real erasure request drives the shape decision. This is the same staged-shape pattern ADR-0017 D6 and ADR-0020 D12 applied to deferred mechanism decisions.
- **Deferring level (c) embedding-model coherence (router-level pinning) means callers can in principle configure the embedding model and get a clean error on mismatch rather than being prevented from requesting the wrong model in the first place.** Accepted at stand-up; the pinning surface belongs in the routing layer, not in Memory, and ADR-0010 is still Proposed. This is symmetric with ADR-0021 D6's level (c) deferral.
- **Pulse ingress back into Memory (reactive tuning of summarization threshold, retention cadence, scope-resolution caching) is deferred.** Operator-driven tuning via App Configuration covers the stand-up need; automatic reactive tuning is a later concern and matches the emit-only stance every prior AI-sector stand-up took.
- **Cross-host shared memory-scope registry is not in scope at stand-up.** A scope resolved in one process is valid only in that process. Persistence of scope resolutions across hosts is a later concern, parallel to the cross-host agent-registry deferral ADR-0020 D11 recorded.

## Alternatives Considered

### Fold Memory into HoneyDrunk.Knowledge

Rejected. Memory owns agent-generated, subjective context (what an agent learned or decided across executions). Knowledge owns externally sourced, objective information (documents, APIs, datasets). The two have different lifecycles (agent-execution-driven writes and summarizations vs operator-driven ingest and supersede), different access rules (per-agent scope vs Grid-wide attribution), and different storage semantics (scope-enforced with summarization lineage vs source-attributed with version lineage). Folding them would collapse both surfaces into a single conflated model and would force every consumer to reason about "is this chunk something an agent decided or something a document said" from the storage layer up. ADR-0021 D4 and this ADR's D4 jointly settle this boundary from both sides.

### Fold Memory into HoneyDrunk.Agents

Rejected. Agents owns agent runtime — identity, lifecycle, execution context, and execution-scope state only per ADR-0020 D8. Memory is the long-term substrate for agent-generated content that must survive the end of an execution. Folding Memory into Agents would either (a) inflate Agents's state boundary to cover cross-execution persistence, breaking ADR-0020 D8's execution-scope-only pin, or (b) silently duplicate the storage surface in Agents and fragment the scope model. Keeping them separate preserves ADR-0020's narrow agent-runtime charter and keeps Memory's scope surface the single source of authorization for long-term agent-generated data.

### Ship `IMemorySummarizer` as internal to the runtime package

Rejected per Q3. Evals needs to mock summarization deterministically; Sim needs to seed scenario-specific summarization outcomes; and downstream consumers legitimately want to swap the summarization strategy (a small-model summarizer for dev, a higher-quality summarizer for production, a no-op summarizer for short-lived test runs). Keeping `IMemorySummarizer` public is a tiny amount of extra contract surface (one interface, covered by the D12 canary) in exchange for the testing and deployment flexibility the split buys. This matches the public-interface posture Capabilities took for `ICapabilityGuard` (ADR-0017) and Operator took for `ISafetyFilter` (ADR-0018).

### Ship the right-to-erasure and bulk-delete contract at stand-up

Deferred per Q5. The principle is pinned in D11 (policy in Operator, enforcement in Memory), but the exact shape of the bulk-delete surface on `IMemoryStore` depends on Operator's `IDecisionPolicy` maturing (ADR-0018 is Proposed) and on a real erasure request driving the concrete shape. Shipping a speculative bulk-delete API at stand-up would likely have to be revised once a real request lands, and the stand-up surface is per-entry and per-scope delete, which is sufficient for the first-wave consumers (Agents, Flow, Sim, Evals). The deferral is named explicitly here and in D11 so it is not lost.

### Short-term memory owned by Memory (Position B)

Rejected per Q2. The `repos/HoneyDrunk.Memory/overview.md` and `repos/HoneyDrunk.Memory/boundaries.md` files previously described Memory as owning short-term (conversation-scoped) memory. ADR-0020 D8 pinned execution-scope state inside `IAgentExecutionContext`, which means two Nodes would otherwise both claim ownership of conversation-turn state that only needs to live until the execution ends. Position A — Agents owns short-term, Memory owns long-term only — resolves the overlap cleanly: execution-ephemeral state stays on the execution context and is disposed with it; anything that must survive the execution is written through `IMemoryStore`. The alternative position (Memory owns both short-term and long-term) would keep Memory on the hot execution path of every agent tick, drag storage semantics into turn-by-turn state, and conflict with ADR-0020 D8's execution-scope-only pin.

### Strict level (c) router-level embedding-model pinning at stand-up

Deferred per Q3 and symmetric with ADR-0021 D6. Level (b) coherence — `MemoryEntry` records the ingest-time model and similarity retrieval errors on mismatch — is the correctness floor and lands in this ADR. Level (c) — router-level pinning so callers cannot even request a mismatched model — is a routing concern and belongs in `IModelRouter` per ADR-0010. ADR-0010 is still Proposed; layering a pinning surface on a not-yet-accepted router is premature. The level (b) floor is sufficient for the first-wave consumers; level (c) can compose on top without changing Memory's contract when the routing layer accepts.

### Ingest-time PII / content-safety scanner inside Memory

Deferred, matching ADR-0021 D11. Operator's `ISafetyFilter` (ADR-0018 D3) already covers the immediate need on the output-side: when a memory entry flows out of Memory toward an agent or a user-facing path, the safety filter runs on the output boundary. Adding an ingest-side pipeline at stand-up would duplicate a capability Operator already owns and would create a second safety model in the AI sector. If a future use case requires rejecting content at write time rather than filtering it at read time, the concern gets its own ADR and likely composes Operator's existing `ISafetyFilter` on the ingest side the same way ADR-0021 framed it for Knowledge.

### Cross-host shared memory-scope registry at stand-up

Deferred. Persisting scope resolutions so a scope resolved in one process is valid in another requires a persistence model, a cache invalidation story, and a distributed-consistency story for scope escalation. None of that is stand-up work. This parallels the treatment ADR-0020 D11 gave the cross-host agent-registry concern: in-process for the first wave, distributed under its own ADR once a cross-host requirement lands.

### Pulse signal ingress into Memory at stand-up

Deferred. Reactive closed-loop tuning — where observed telemetry from Pulse automatically adjusts summarization threshold, retention cadence, or scope-resolution caching — is the same class of concern ADR-0018 flagged for Operator, ADR-0020 flagged for Agents, and ADR-0021 flagged for Knowledge. It is not a stand-up decision. Emit-only at stand-up is the committed direction; any future ingress contract will be added as a distinct ADR concern.

### Defer the Memory stand-up until Agents needs it

Rejected. ADR-0020 D6 already depends on `IMemoryStore` and `IMemoryScope` for the default `IAgentMemory` implementation, and the Agents → Memory edge is already in ADR-0020's follow-up checklist. "Agents already needs it" is not hypothetical — it is in the last accepted stand-up's own obligations. Continuing to defer Memory would leave Agents's default memory projection compiling against a non-existent `Abstractions` package and would force every consumer that wants a real agent execution (Sim, Flow, Evals, HoneyHub when live) to reinvent the memory substrate. The AI sector's foundation is AI (inference) + Capabilities (tools) + Operator (policy) + Agents (runtime) + Knowledge (external information) + Memory (agent context); standing up five of six and deferring Memory leaves the triad (Agents + Knowledge + Memory) incomplete and blocks the downstream consumers that are ready to compile against it.
