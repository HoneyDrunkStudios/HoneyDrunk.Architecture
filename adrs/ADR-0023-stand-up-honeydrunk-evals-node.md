# ADR-0023: Stand Up the HoneyDrunk.Evals Node — Evaluation and Quality Substrate for the AI Sector

**Status:** Proposed
**Date:** 2026-04-19
**Deciders:** HoneyDrunk Studios
**Sector:** AI

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Reconcile `catalogs/contracts.json` entries for `honeydrunk-evals` to the definitive D3 contract set: rename `IEvalRunner` → `IEvaluator`; rename `IEvalDataset` → `IEvalSuite`; promote `IEvalReport` → `EvalReport` with `kind: "type"` (records drop the `I` prefix per the grid-wide naming rule); add the `EvalCase` record entry with `kind: "type"`; add the `IEvalTarget` interface entry
- [ ] Update `catalogs/relationships.json` for `honeydrunk-evals`:
  - Add seven missing `consumes` edges: `honeydrunk-kernel`, `honeydrunk-agents`, `honeydrunk-capabilities`, `honeydrunk-operator`, `honeydrunk-knowledge`, `honeydrunk-memory` (and widen the already-present `honeydrunk-ai` edge per the next bullet)
  - Widen the AI `consumes_detail` entry from `["IChatClient", "HoneyDrunk.AI.Abstractions"]` to include `IEmbeddingGenerator`, `IModelProvider`, and `ModelCapabilityDeclaration` alongside `IChatClient` and `HoneyDrunk.AI.Abstractions`
  - Update `exposes.contracts` so it lists the D3 definitive set: `IEvaluator`, `IEvalScorer`, `IEvalSuite`, `IEvalTarget`, `EvalCase`, `EvalReport`
- [ ] Reconcile the `roadmap_focus` prose in `catalogs/nodes.json` for `honeydrunk-evals` (currently names `IEvaluator`, `IEvalDataset`, `IEvalScorer`) against the D3 definitive set — prose and edges must describe the same contract set
- [ ] Align `repos/HoneyDrunk.Evals/overview.md` and the Evals section of `constitution/ai-sector-architecture.md` to the D3 definitive set — correct the current references to `IEvalDataset` and `IEvalReport` and name `IEvalTarget`, `EvalCase`, and `EvalReport`
- [ ] Update `catalogs/grid-health.json` `honeydrunk-evals` entry to reflect the stood-up contract surface and the contract-shape canary expectation
- [ ] Wire the contract-shape canary into Actions for `IEvaluator`, `IEvalScorer`, `IEvalTarget`, and `EvalReport`
- [ ] Add `integration-points.md` and `active-work.md` to `repos/HoneyDrunk.Evals/`, matching the template used by `repos/HoneyDrunk.Agents/`
- [ ] File the HoneyDrunk.Evals scaffold packet (solution structure, `HoneyDrunk.Standards` wiring, CI pipeline, `HoneyDrunk.Evals.Providers.InMemory` fixture, default implementations of `IEvaluator`, `IEvalScorer`, and `IEvalTarget` with a `ChatTarget` default, reproducibility primitives, and the sensitivity-flag plumbing per D10)
- [ ] Scope agent assigns final invariant numbers when flipping Status → Accepted

## Context

`HoneyDrunk.Evals` is cataloged in `catalogs/nodes.json` as the AI sector's evaluation and quality substrate, but the repo is cataloged-not-yet-created — no packages, no contracts, no evaluator, no suite primitive, no scorer, no target adapter, no CI. Agents, Flow, Sim, Lore, and HoneyHub (when live) all need a shared way to measure AI output quality — run a suite of cases against a target, score the outputs against expected criteria, detect regressions across model and prompt changes, compare providers — and none of them own that responsibility. Without a dedicated substrate, each Node ends up inventing its own eval runner, its own scorer interface, its own report shape, and its own regression story, and the quality surface fragments across the AI sector.

ADR-0016 stood up HoneyDrunk.AI as the inference substrate. ADR-0017 stood up HoneyDrunk.Capabilities as the tool-registry and dispatch substrate. ADR-0018 stood up HoneyDrunk.Operator as the human-policy enforcement and audit substrate. ADR-0020 stood up HoneyDrunk.Agents as the agent-runtime foundation node that composes those three substrates into a runnable agent. ADR-0021 stood up HoneyDrunk.Knowledge as the external-information ingestion and retrieval substrate. ADR-0022 stood up HoneyDrunk.Memory as the agent-memory substrate. Evals is the next — and last — AI-sector foundation node. It closes the foundation after the three substrates (AI, Capabilities, Operator) and the foundation triad (Agents + Knowledge + Memory): everything the Grid builds on top of the AI sector needs a shared way to ask "is this actually working" and to detect when it stops working.

The stand-up pattern is deliberately reused: contracts live in an `Abstractions` package, runtime composition is a separate package, downstream Nodes compile against `Abstractions` only, and a first-wave `Providers.InMemory` package ships at stand-up so consumers have one shared in-memory backend they can compose in tests and in local development without standing up a production report store. The `.Providers.InMemory` name is chosen over `.Testing` deliberately — it matches the shape Knowledge (ADR-0021 D2) and Memory (ADR-0022 D2) took, and it signals that the in-memory backend is a production-shaped provider-slot implementation, not a test-only artifact. The `.Testing` pattern ADR-0017 D2 applied to Capabilities remains valid for that Node (where there is no provider-slot axis at the registry layer), but it is not the right shape for Evals, which has a clear provider-slot family on the report-persistence side.

The `catalogs/contracts.json` entry for `honeydrunk-evals` currently lists three interfaces (`IEvalRunner`, `IEvalScorer`, `IEvalSuite`), while the `catalogs/relationships.json` `exposes.contracts` list for the same Node says `IEvaluator`, `IEvalDataset`, `IEvalScorer`, `IEvalReport`, and the repo docs (`repos/HoneyDrunk.Evals/overview.md` and `constitution/ai-sector-architecture.md`) name `IEvaluator`, `IEvalDataset`, `IEvalScorer`, `IEvalReport`. Three different sources, three different contract sets, all seeded before any ADR pinned the Evals shape. This drift is precisely the problem this ADR is written to solve: the stand-up decision fixes the definitive contract set in D3, and every cataloged and prose reference is reconciled against it in the follow-up work section. Interfaces retain the `I` prefix and are cataloged with `kind: "interface"`; records drop the `I` prefix and are cataloged with `kind: "type"`, matching the grid-wide naming rule already applied by `ModelCapabilityDeclaration` (ADR-0016), `CapabilityDescriptor` (ADR-0017), the four governance records (ADR-0018), `KnowledgeSource` (ADR-0021), and the deferred record shapes pinned at ADR-0020 D3 and ADR-0022 D3.

Evals's boundary against the adjacent Nodes needs explicit disambiguation before drift creeps in, and one particular concern — inference-bypass for deterministic evaluation — needs a contract carved for it at stand-up rather than left to a "figure it out later" escape hatch.

1. **Evals vs AI.** AI owns inference (`IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, `ModelCapabilityDeclaration` per ADR-0016). Evals does not re-implement inference. But Evals has a correctness hazard AI's router-centric surface does not directly serve: to benchmark *this specific model* against *this specific model* for regression detection, an eval harness must be able to pin a specific `IModelProvider` / `ModelCapabilityDeclaration` combination for the run, bypassing the routing policy that would otherwise pick a model for the caller. D6 pins how this bypass is shaped.
2. **Evals vs Operator.** Operator enforces live policy on outputs — `ISafetyFilter` blocks a live response that violates safety, `ICostGuard` blocks a live request that exceeds a cost ceiling, `IAuditLog` records the decision (per ADR-0018). Evals *observes and scores* the exact same outputs in a test context, looking for regression across model or prompt changes. Observing is not enforcing; the two surfaces do not overlap but they do compose — Evals may consume Operator's primitives as in-loop scoring signals (did the safety filter fire on this case, what was the cost of this case), pinned in D7.
3. **Evals vs Pulse.** Pulse owns telemetry ingestion and signal storage (per ADR-0010). Eval *runs* emit signals into Pulse the same way every other Node emits its telemetry. But the eval-signal telemetry surface has a deliberately different rule from every other AI-sector Node: eval signals may carry prompts and outputs (the case content being evaluated) unless the suite declares itself sensitive. This is a deliberate carve-out from Knowledge's "no content in telemetry" rule (ADR-0021 D10) and Memory's "no content in telemetry" rule (ADR-0022 D9), and it is pinned in D10. The reason is structural: regression diagnosis needs the actual prompt and output. A quality signal that a score dropped on case 42 is useless without the text of case 42.
4. **Evals vs Agents / Knowledge / Memory.** Agents runs agents, Knowledge retrieves documents, Memory persists agent-generated context. Evals does not run agents, retrieve documents, or persist agent context for its own sake. It evaluates agents, retrieval pipelines, and memory-backed workflows as *targets under test*. The target abstraction — the thing being evaluated — is the `IEvalTarget` interface pinned in D3 and D6, and it generalizes over "a chat model," "an agent," "a retrieval pipeline," "a memory-backed workflow" without Evals taking on any of their runtime responsibilities.
5. **`EvalReport` persistence.** Eval reports are not ephemeral telemetry. A Pulse signal records *that* a run happened and emits the top-line score; the `EvalReport` is the durable artifact — per-case scores, per-case inputs and outputs, full rubric breakdown, run metadata — that a regression investigation reads months later when a quality signal fires. This ADR pins the principle (`EvalReport` is durable, not ephemeral) in D13; the specific storage substrate (Data, Pulse-as-store, dedicated provider) is deferred to the scaffold packet, matching the staged-shape deferral pattern ADR-0017 D6 and ADR-0020 D12 applied.

This ADR is the **stand-up decision** for the Evals Node — what it owns, what it does not own, which contracts it exposes, how downstream Nodes couple to it, and how it interacts with AI, Capabilities, Operator, Agents, Knowledge, Memory, and Pulse. "Node" is used throughout in the ADR-0001 sense — a library-level building block producing one or more NuGet packages, not a deployable service. This ADR is not a scaffolding packet. Filing the repo, adding CI, wiring the in-memory provider, and producing the first shippable packages all follow as separate issue packets once this ADR is accepted.

## Decision

### D1. HoneyDrunk.Evals is the AI sector's evaluation and quality substrate

`HoneyDrunk.Evals` is the single Node in the AI sector that owns **evaluation primitives** — the contracts and runtime machinery that define an evaluation case, run a suite of cases against a target, score the outputs against expected criteria, produce a structured report, and emit quality signals that downstream Nodes can correlate to deployments or model changes. It is a shared substrate, not an application. It does not decide *what to evaluate* or *what score is good enough*; it owns the mechanics of *how a case is defined, how a target is invoked under test, how outputs are scored, and how results are reported*.

Evaluation *content* — the actual suites, cases, rubrics, and pass/fail thresholds — is decided by the consumers. Each consumer maintains its own suites for the concerns it cares about: Agents can ship suites that exercise agent behaviors; Knowledge can ship suites that exercise retrieval quality; Lore can ship suites that exercise wiki-compilation fidelity; the platform owner can ship suites that exercise cost-to-quality tradeoffs across providers. Evals provides the harness; consumers provide the content.

Evals is the last foundation node. The three substrates (AI, Capabilities, Operator) plus the foundation triad (Agents + Knowledge + Memory) give the Grid the primitives to run an AI workload end-to-end; Evals gives the Grid the primitives to know whether that workload is actually working and to notice when it stops. Standing up six of seven and deferring Evals would mean the foundation cannot self-evaluate — every downstream application would have to build its own regression story, and drift across those stories would be immediate.

### D2. Package families

The Evals Node ships the following package families, mirroring the stand-up shape used by ADR-0016 (AI), ADR-0017 (Capabilities), ADR-0018 (Operator), ADR-0020 (Agents), ADR-0021 (Knowledge), and ADR-0022 (Memory):

- `HoneyDrunk.Evals.Abstractions` — all interfaces (`IEvaluator`, `IEvalScorer`, `IEvalSuite`, `IEvalTarget`) and all records (`EvalCase`, `EvalReport`) per D3. Zero runtime dependencies beyond `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.AI.Abstractions` (for `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, and `ModelCapabilityDeclaration` on the target and scoring paths — see D5 and D6).
- `HoneyDrunk.Evals` — runtime composition: default `IEvaluator`, default `IEvalScorer` set (automated rubric scorers, a model-as-judge scorer), default `IEvalTarget` implementations including a `ChatTarget` that wraps `IChatClient` and optionally pins a `ModelCapabilityDeclaration`, DI wiring. Takes a first-class runtime dependency on `HoneyDrunk.AI.Abstractions` for target invocation and model-as-judge scoring (see D5), and composes `ISafetyFilter`, `ICostGuard`, and `IAuditLog` from `HoneyDrunk.Operator.Abstractions` as in-loop scoring signals (see D7).
- `HoneyDrunk.Evals.Providers.InMemory` — in-memory backend for report persistence and suite fixtures. Zero-network, deterministic, suitable for tests, local development, and seed evaluation runs. Consumed by downstream Nodes in test projects and in local composition; never in production composition of a real quality gate.

The production-grade report store (SQL Server, Cosmos DB, Pulse-backed, or something new) is **not first-wave**. The provider slot exists at stand-up via `Providers.InMemory`; a durable production backend ships under a separate issue packet once a real consumer (HoneyHub when live, or the first production regression-detection workflow) drives the shape. This is the same staged-shape pattern ADR-0021 D2 and ADR-0022 D2 applied to provider slots. Pinning `EvalReport` as durable (D13) is independent of committing to a specific substrate for that durability.

No separate `HoneyDrunk.Evals.Testing` package is introduced at stand-up. The `Providers.InMemory` package already plays that role — it is the in-memory backend every downstream test project can compose. This differs from Capabilities (ADR-0017 D2), which ships `.Testing` because there is no provider-slot axis at the registry layer; Evals, like Knowledge and Memory, has a clear provider-slot axis (report persistence) and the in-memory fixture belongs there.

### D3. Exposed contracts

Six surfaces form the Evals Node's public boundary at stand-up — four interfaces and two records. These are the surfaces downstream Nodes are allowed to compile against, and they are the definitive set against which the three drifted cataloged sources (contracts.json, relationships.json, overview.md) are reconciled per the follow-up work section.

| Contract | Kind | Purpose |
|---|---|---|
| `IEvaluator` | interface | Run a suite of cases against a target, collect scored results, produce an `EvalReport`. The top-level orchestration surface. |
| `IEvalScorer` | interface | Scoring function over a case output. Automated (regex, schema validation, rubric) or model-as-judge (using `IChatClient`). Marked deterministic vs non-deterministic per the Node-local invariant. |
| `IEvalSuite` | interface | Named, versioned collection of `EvalCase`s with a rubric specification. Replaces `IEvalDataset` from the previous catalog prose. Versioning is a Node-local invariant already. |
| `IEvalTarget` | interface | The thing being evaluated — a chat model, an agent, a retrieval pipeline, a memory-backed workflow. Abstracts over what the case is run against without binding Evals to any consumer's runtime surface. See D6. |
| `EvalCase` | record | A single evaluation case — input, expected output or rubric criteria, per-case metadata (case identity, suite version, tags). Value type; `kind: "type"` in the catalog. |
| `EvalReport` | record | Structured evaluation results — per-case scores, per-case inputs and outputs (subject to D10 sensitivity rules), rubric breakdown, run metadata (target identity, model-capability identity, suite version, timestamp). Value type; `kind: "type"` in the catalog. Durable per D13. |

`EvalCase` and `EvalReport` are new record entries at the catalog level and apply the grid-wide naming rule (no `I` prefix, `kind: "type"`). `IEvalTarget` is a new interface entry. The `IEvalRunner` / `IEvalDataset` / `IEvalReport` names that appear in the current cataloged sources are renamed/promoted to `IEvaluator` / `IEvalSuite` / `EvalReport` per the follow-up work section. No `kind: "record"` is used anywhere in the catalog schema.

Specific `IEvalTarget` implementation shapes — `AgentTarget` wrapping an `IAgent` execution, `RetrievalTarget` wrapping an `IRetrievalPipeline`, `MemoryTarget` wrapping a memory-backed workflow — are **deferred to the scaffold packet**. The stand-up commitment is the `IEvalTarget` interface itself plus a default `ChatTarget` shape (wrapping `IChatClient` with optional `ModelCapabilityDeclaration` pinning per D6). The generalisation over agent / retrieval / memory targets is pinned at the contract level in D6 and D8; the concrete target shapes land with scaffold. This matches the deferral pattern ADR-0020 D3 used for agent record shapes, ADR-0021 D3 used for retrieval request/response shapes, and ADR-0022 D3 used for `MemoryEntry`.

### D4. Boundary rule with AI, Capabilities, Operator, Agents, Knowledge, Memory, and Pulse (definitive)

The surrounding Nodes need an explicit boundary test so that drift does not creep in once Evals ships. The rule below is the decision test Evals applies when an ambiguous concern is proposed.

**Decision test — for any concern in the evaluation path, ask:**

1. Does it make the inference call (chat completion, embedding) against a model? → **AI** (Evals composes `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, and `ModelCapabilityDeclaration` per D5 and D6; it never talks to providers directly).
2. Does it discover or invoke a tool? → **Capabilities** (when an eval target is an agent that invokes tools, the dispatch path goes through Capabilities's `ICapabilityInvoker`, not through an Evals-owned shim).
3. Does it enforce a live-production policy — block a response that violates safety, block a request that exceeds a cost ceiling, write an audit record of a human approval? → **Operator** (Evals *observes* Operator primitives as in-loop signals per D7; it does not re-implement policy enforcement).
4. Does it manage agent identity, lifecycle, or execution context? → **Agents** (when the target is an agent, Evals invokes `IAgent` through `IEvalTarget`; it does not own agent state).
5. Does it ingest or retrieve externally-sourced information? → **Knowledge** (when the target is a retrieval pipeline, Evals invokes `IRetrievalPipeline` through `IEvalTarget`; Knowledge owns ingest and attribution).
6. Does it persist agent-generated content across executions? → **Memory** (when the target is a memory-backed workflow, Evals seeds `Providers.InMemory` fixtures and invokes the workflow through `IEvalTarget`; Memory owns the scope and storage semantics).
7. Does it define a rubric, run a suite of cases against a target, score outputs, and produce a structured report? → **Evals**.
8. Does it ingest telemetry or host signal streams? → **Pulse** (Evals emits eval signals into Pulse per D10 but has no runtime dependency on Pulse, matching the emit-only stance every prior AI-sector stand-up took).

Under this test, several subtleties are worth naming explicitly:

- **Evals is an observer, not an enforcer.** `repos/HoneyDrunk.Evals/invariants.md` item 5 ("Evals never modifies the model or prompt under test") is already Node-local; this ADR elevates the read-only principle to the cross-Node level. Evals sees Operator primitives, records whether they fired, and scores that as a signal — it does not itself gate a live production path.
- **Agent-behavior evaluation is in scope at the contract level.** `IEvalTarget` generalises over agent targets by design: an `AgentTarget` (deferred to scaffold) wraps an `IAgent` execution, and suites can assert on the agent's tool-call sequence, its final output, or its intermediate state. This is not a later-ADR concern — the contract-level decision is pinned here. What defers is the concrete `AgentTarget` shape (what surface it exposes to scorers), not whether Evals supports agent evaluation.
- **Retrieval and memory evaluation are in scope at the contract level for the same reason.** The same generalisation covers `RetrievalTarget` (wrapping an `IRetrievalPipeline`) and `MemoryTarget` (wrapping a memory-backed workflow). Concrete shapes defer; contract-level support does not.
- **Model comparison is Evals's core job, not a special case.** `IEvalTarget` pins a specific `ModelCapabilityDeclaration` per target instance. Running the same suite against two targets (each pinning a different model) is the comparison operation. This is why pinning a specific model is a first-class contract concern rather than a special flag (see D6).

`catalogs/relationships.json` currently lists Evals's `consumes` as `honeydrunk-ai` alone, with `consumes_detail` limited to `IChatClient` and `HoneyDrunk.AI.Abstractions`. Under this ADR, the `consumes` list widens to include `honeydrunk-kernel`, `honeydrunk-agents`, `honeydrunk-capabilities`, `honeydrunk-operator`, `honeydrunk-knowledge`, and `honeydrunk-memory` (seven missing edges), and the AI `consumes_detail` widens to include `IEmbeddingGenerator`, `IModelProvider`, and `ModelCapabilityDeclaration` alongside `IChatClient` and the package reference. The corrections are tracked in the follow-up work section at the top of this ADR.

### D5. Inference and tool composition — Evals does not re-implement

`IEvalTarget`'s default `ChatTarget` takes a first-class runtime dependency on `HoneyDrunk.AI.Abstractions` and invokes `IChatClient` (or `IEmbeddingGenerator` for embedding-centric targets) per ADR-0016 D3. Evals does not invent its own chat-completion or embedding abstraction, does not talk to model providers directly, and does not cache or batch inference in a way that bypasses AI's telemetry or cost accounting. The `ChatTarget` pins a `ModelCapabilityDeclaration` when the suite wants deterministic model selection (see D6); otherwise, it relies on `IChatClient` and whatever router composition the host has wired.

The **model-as-judge** scorer path also goes through `IChatClient`. When a scorer uses a model to evaluate an output (rubric-as-prompt, rated response), the scorer composes `IChatClient` from `HoneyDrunk.AI.Abstractions` — it never instantiates a model provider or dispatches to a routing layer of its own. Model-as-judge scorers are explicitly marked non-deterministic per the existing Node-local invariant.

When an eval target is an agent (a scaffold-deferred `AgentTarget`), the execution path invokes `IAgent` per ADR-0020 and — through the agent's own runtime — composes `ICapabilityInvoker` per ADR-0017, `IMemoryStore` and `IMemoryScope` per ADR-0022, and `IRetrievalPipeline` per ADR-0021. Evals does not re-wrap any of these surfaces; it invokes `IAgent` and lets the agent runtime compose the substrates it was built on. The same applies to `RetrievalTarget` (wraps `IRetrievalPipeline`) and `MemoryTarget` (wraps a memory-backed workflow).

Downstream Nodes that compile against `HoneyDrunk.Evals.Abstractions` see the six surfaces in D3 as plain interfaces and records. They inherit a transitive compile-time dependency on `HoneyDrunk.AI.Abstractions` through target and scoring shapes — this is accepted and matches the way ADR-0020 D5, ADR-0021 D5, and ADR-0022 D5 treated upstream `Abstractions`-level edges. The runtime edges to `HoneyDrunk.AI`, `HoneyDrunk.Agents`, `HoneyDrunk.Capabilities`, `HoneyDrunk.Operator`, `HoneyDrunk.Knowledge`, and `HoneyDrunk.Memory` (composition, target wiring) are resolved at the host, not at the consumer.

### D6. `IEvalTarget` is the router-bypass boundary — Evals pins models; AI's router is not widened

Regression testing requires pinning a specific `IModelProvider` / `ModelCapabilityDeclaration` for a run. Running the same suite against "whatever the router picks today" would mask the exact thing regression testing is built to detect — that a model or routing-policy change degraded behavior. The question then is *where* the pinning primitive lives: widen `IChatClient` to take an explicit-model overload (Option A), have Evals compose `IModelProvider` directly (Option B), or introduce an `IEvalTarget` abstraction that owns the pinning (Option C, chosen).

**Option A (widen `IChatClient`) is rejected.** Adding an explicit-model overload to `IChatClient` would break the contract-shape canary ADR-0016 D8 pinned on that surface, inflate every caller's API surface with a concern only Evals has (and only in eval contexts), and undermine the routing layer's single-source-of-truth role for model selection in production paths. One Node's special case should not reshape the Grid's hottest interface.

**Option B (Evals composes `IModelProvider` directly) is rejected.** Pulling `IModelProvider` composition into Evals's runtime would either (a) duplicate the provider-discovery logic the router already owns, or (b) give Evals a second composition path that sees models the router does not see. Both produce drift. Evals should not own a second routing surface.

**Option C (`IEvalTarget` abstraction) is chosen.** `IEvalTarget` is the Evals-side abstraction over "the thing being evaluated." For a `ChatTarget`, the target pins a `ModelCapabilityDeclaration` and, at invocation time, composes `IModelProvider` (from `HoneyDrunk.AI.Abstractions`, sourced through the host's DI container the same way AI's runtime package resolves providers) for that specific capability declaration. This is a legitimate use of `IModelProvider` — it is what the router itself composes — but it does *not* widen `IChatClient` and does *not* duplicate routing policy. The target is an evaluation-time harness, explicitly labeled as bypassing the router, and the `ModelCapabilityDeclaration` identity it pins is recorded on every `EvalReport` (D12) so the bypass is auditable.

The router-bypass is narrow and deliberate. It exists because evaluation cannot use the routing layer — the routing layer is one of the things evaluation is designed to detect regressions in. Outside of the `IEvalTarget` path, every production inference call in the Grid goes through `IChatClient` and whatever router composition is wired.

### D7. Operator composition as in-loop scoring signals — Evals observes, does not enforce

`IEvalScorer` implementations may compose three Operator primitives from `HoneyDrunk.Operator.Abstractions` per ADR-0018 as in-loop scoring signals:

- `ISafetyFilter` — did the safety filter fire on this case's output? What rule fired, at what boundary? A suite can score "how often does our output violate safety rules" as a regression signal.
- `ICostGuard` — what was the cost of this case? Did it exceed a soft threshold? A suite can score "cost-per-case" as a regression signal.
- `IAuditLog` — if a case triggered an approval path (in a live-like eval run), was it recorded? A suite can assert on the audit trail as a behavioral expectation.

This is deliberate composition, not a new Operator surface. Evals does not *invoke* `ISafetyFilter` to *block* an output — it invokes it to *observe* what the filter would have done and score that observation. Evals does not *write* to `IAuditLog` from its own path — it reads the audit record Operator produced during the target's execution (if the target path recorded one) and correlates it with the case.

The distinction — observes vs enforces — is load-bearing for D4's "Evals is an observer, not an enforcer" rule and for the Evals-vs-Operator boundary. Wiring the Operator primitives as observable scoring inputs gives consumers the regression story for "safety-filter firing rate changed between model X and model Y" without entangling Evals with Operator's production-enforcement path.

### D8. Downstream coupling rule

Downstream Nodes that need evaluation — Agents (ships agent-behavior suites), Flow (ships workflow-level suites), Sim (exercises targets against scenario fixtures), Lore (validates wiki-compilation quality), HoneyHub (when live, aggregates eval signals for regression alerts) — compile **only** against `HoneyDrunk.Evals.Abstractions`. They do not take a runtime dependency on `HoneyDrunk.Evals` or on any `HoneyDrunk.Evals.Providers.*` package. Composition — which scorer set is wired, which report store backs `EvalReport` persistence — is a host-time concern, resolved at application startup from App Configuration per ADR-0005.

This is the same abstraction/runtime split already applied for AI, Capabilities, Operator, Agents, Knowledge, and Memory. It is re-stated here because it is the specific rule that allows consumers to define suites and targets against `Abstractions` alone without pulling in the full runtime, and it is the rule that keeps `Providers.InMemory` out of production composition.

### D9. State boundary — Evals holds suite definitions and report artifacts, not agent / memory / knowledge state

Evals holds **suite and report state** — the `IEvalSuite` definitions and their `EvalCase` collections (authored content), the accumulated `EvalReport` artifacts from past runs (durable per D13), and the in-flight run state during an active evaluation. All of this is backed by `Providers.InMemory` at stand-up, with the production report store deferred per D2.

Evals does **not** hold:

- **Agent state.** That is Agents's job. When an `AgentTarget` runs during evaluation, the agent's execution context, tool-call sequence, and short-term memory live on `IAgentExecutionContext` per ADR-0020 D8 for the duration of that target invocation and are disposed when the invocation ends.
- **Long-term agent memory.** That is Memory's job. When a `MemoryTarget` runs during evaluation, the memory entries live in the configured Memory provider (`Providers.InMemory` for eval fixtures) per ADR-0022; Evals seeds fixtures but does not own the scope or the storage.
- **Knowledge sources.** That is Knowledge's job. When a `RetrievalTarget` runs during evaluation, the knowledge sources live in the configured Knowledge provider (`Providers.InMemory` for eval fixtures) per ADR-0021; Evals seeds fixtures but does not own ingestion, attribution, or the retrieval pipeline.
- **Audit trail.** That is Operator's job. Evals emits telemetry per D10 and records `EvalReport` artifacts per D13, but the immutable record of *who approved a production action and when* lives in Operator's `IAuditLog`. Evals reads audit entries as scoring signals per D7; it does not duplicate the record.
- **Live safety decisions.** That is Operator's `ISafetyFilter` on the live-production output boundary per ADR-0018 D3. Evals observes filter behavior as a scoring signal per D7; it does not itself gate a live production path.

The rule is: if a piece of data is *content being evaluated* or *a structured result of an evaluation*, it is Evals's. Everything else — the agent's state, the retrieved documents, the stored memories, the audit trail — stays with its owner Node.

### D10. Eval-signal telemetry — deliberate carve-out: content is permitted unless the suite declares sensitive

Evals emits telemetry for every suite run (suite identity, suite version, target identity, model-capability identity, run start/end timestamps), every per-case result (case identity, per-scorer scores, outcome, duration, per-case inference cost), and every regression event (suite, case, score delta, previous baseline) via Kernel's `ITelemetryActivityFactory`. Pulse consumes that telemetry downstream. **Evals has no runtime dependency on Pulse.** The direction is one-way by contract: Evals emits, Pulse observes. Same rule as every prior AI-sector stand-up.

**Eval-signal telemetry may carry prompts and outputs — the case content being evaluated — unless the suite declares itself sensitive.** This is a **deliberate carve-out** from the content-never-in-telemetry rule Knowledge pinned in ADR-0021 D10 and Memory pinned in ADR-0022 D9. Eval signals are a new telemetry category, structurally distinct from Knowledge's retrieval telemetry and Memory's read/write telemetry, and they carry different payloads by design.

The reason for the carve-out is structural: regression diagnosis requires the actual prompt and output. A Pulse signal that case 42 of suite X dropped from score 0.95 to score 0.62 on model upgrade Y is useless for diagnosis without the text of case 42's input, the text of the new output, and the text of the expected output the rubric was scored against. Stripping content from eval signals would force every investigator to round-trip to `EvalReport` storage (D13) for every signal, which defeats the purpose of emitting a signal in the first place — the signal is supposed to give the reviewer enough information to triage without another lookup.

The carve-out is not unconditional. Every `IEvalSuite` carries a **sensitivity flag**. When a suite declares itself sensitive (for example, a suite whose inputs are derived from real user prompts, or a suite whose outputs may contain regulated content), the eval-signal telemetry emits metadata only — identity, scores, durations — exactly like Knowledge's and Memory's telemetry rule. The sensitive signal still goes to Pulse; it just does not carry content.

The sensitivity flag is a scaffold-packet concern in its concrete shape (where on the suite it lives, how it propagates through `IEvaluator` to the telemetry emission), but the principle — carve-out by default, content stripped when the suite is sensitive — is pinned at stand-up. Both the carve-out and the sensitivity-flag rule are called out in Consequences as new invariants and in Alternatives Considered against the "content strictly forbidden" option.

Pulse signal ingress back into Evals — reactive suite selection, reactive threshold tuning, reactive re-run based on observed production telemetry — is out of scope for stand-up. It is flagged in Alternatives Considered as a deferred concern and matches the emit-only stance every prior AI-sector stand-up took.

### D11. Evals is a read-only observer of targets

Provider packages and target implementations must preserve the read-only principle. No `IEvalTarget` implementation may modify the target under test — no writes to the target's state, no mutation of the suite during a run, no side effects that persist past the evaluation run. This extends `repos/HoneyDrunk.Evals/invariants.md` item 5 ("Evals never modifies the model or prompt under test") from a Node-local invariant to a Grid-level one.

The rule is enforceable at the interface level: `IEvalTarget` exposes an invocation surface that returns an output, not a surface that mutates. An `AgentTarget` that writes agent memory as part of the evaluation is not modifying the target from Evals's perspective — the memory write is part of the agent's behavior and that behavior is what the evaluation is scoring. What is forbidden is Evals itself reaching around the target to change its state. The target's own behavior is fair game; the harness's behavior is not.

### D12. `EvalReport` records the full run provenance — model-capability identity, suite version, target identity, timestamps

Every `EvalReport` record carries the complete provenance of the run it describes: the suite identity and version, the target identity, the `ModelCapabilityDeclaration` identity (when the target pinned one per D6), the run start and end timestamps, the scorer set used, the per-case outcomes. This is not advisory metadata; it is a contract field on the record, matching the role `KnowledgeSource` plays for Knowledge per ADR-0021 D6 and the embedding-model identifier plays for Memory per ADR-0022 D10.

Provenance is the regression story's foundation. A quality signal months later that points to "model upgrade from `gpt-4.0` to `gpt-4.1` caused a 30% regression on suite X" depends on `EvalReport` having recorded the model-capability identity on every historical run. Without the provenance field, cross-run comparison degrades to guesswork.

### D13. `EvalReport` is durable, not ephemeral telemetry — storage substrate deferred to scaffold

`EvalReport` is the durable artifact of an evaluation run. A Pulse signal records *that* a run happened (suite identity, top-line scores, regression flags); the `EvalReport` is the full artifact (per-case scores, per-case inputs and outputs, full rubric breakdown, run provenance per D12) that a regression investigation reads months later when a signal fires. The two are complements, not substitutes.

Pinning durability at the contract level means downstream consumers can rely on `EvalReport` surviving across runs, processes, and deployments. Investigators correlate a Pulse signal from today with an `EvalReport` from six months ago without that `EvalReport` having to be re-derived from retained raw telemetry.

The **storage substrate** — whether `EvalReport` persists via `HoneyDrunk.Data.Abstractions` per ADR-0001's Data Node, via a Pulse-backed store, via a dedicated provider slot, or via something introduced specifically for reports — is **deferred to the scaffold packet**. The stand-up commitment is the durability principle plus `Providers.InMemory` as the first-wave backend. A production-grade store ships under a separate issue packet once a real consumer (HoneyHub when live, or the first production regression-detection workflow) drives the shape. This matches the staged-shape pattern ADR-0017 D6 applied to deferred mechanism decisions, ADR-0020 D12 applied to deferred placement-vs-mechanism decisions, and ADR-0022 D11 applied to deferred right-to-erasure surface.

### D14. Contract-shape canary

A contract-shape canary is added to the Evals Node's CI: it fails the build if any of the following four surfaces change shape (method signatures, parameter shapes, record members) without a corresponding version bump:

- `IEvaluator`
- `IEvalScorer`
- `IEvalTarget`
- `EvalReport`

These four are the hot path for every real consumer. `IEvaluator` is every suite-running caller's entry point; `IEvalScorer` is the injection surface for custom scoring; `IEvalTarget` is the injection surface for custom targets and the router-bypass boundary per D6; `EvalReport` is the durable artifact shape per D13. Accidental shape drift on any of them breaks every Node that ships suites or consumes reports (Agents, Flow, Sim, Lore, HoneyHub when live). The canary makes this a compile-time failure at Evals's own CI, not a discovery at consumer sites. This matches the pattern ADR-0016 through ADR-0022 established of freezing the hot-path surfaces.

`IEvalSuite` and `EvalCase` are not in the stand-up canary because their shapes are expected to evolve modestly as concrete target shapes (`AgentTarget`, `RetrievalTarget`, `MemoryTarget`) land at scaffold and surface case-level requirements. They become canary candidates once the scaffold packet lands and the shapes settle.

## Consequences

### Unblocks

Accepting this ADR — and landing the follow-up scaffold packet that produces a first `Abstractions` release plus the `Providers.InMemory` backend — unblocks the Nodes currently waiting on Evals:

- **HoneyDrunk.Agents** — can ship agent-behavior suites against `IEvalTarget` (`AgentTarget` at scaffold) and assert on tool-call sequences, memory writes, and final outputs without inventing an agent-testing harness.
- **HoneyDrunk.Knowledge** — can ship retrieval-quality suites against `IEvalTarget` (`RetrievalTarget` at scaffold) that exercise `IRetrievalPipeline` against seeded `Providers.InMemory` fixtures.
- **HoneyDrunk.Memory** — can ship memory-workflow suites against `IEvalTarget` (`MemoryTarget` at scaffold) that seed deterministic memory state and exercise summarization and retrieval paths.
- **HoneyDrunk.Flow** — can ship workflow-level suites that evaluate multi-step pipelines as a single `IEvalTarget` and detect regressions in between-step behavior.
- **HoneyDrunk.Sim** — can run scenario-driven evaluation by feeding `EvalCase` fixtures through scenario targets and asserting against the resulting `EvalReport`.
- **HoneyDrunk.Lore** — can validate wiki-compilation fidelity by evaluating the retrieval-to-compilation pipeline as a composed target.
- **HoneyHub (when live)** — can consume eval signals from Pulse, aggregate regression alerts across deployments, and correlate quality deltas to specific model or prompt changes.

### New invariants (proposed for `constitution/invariants.md`)

Numbering is tentative — scope agent finalizes at acceptance.

- **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Evals.Abstractions`.** Composition against `HoneyDrunk.Evals` and any `HoneyDrunk.Evals.Providers.*` package is a host-time concern. See D2 and D8.
- **Evals is a read-only observer of targets.** No `IEvalTarget` implementation may mutate the target under test from the harness side; the target's own behavior is what the evaluation scores. See D11.
- **Every `EvalReport` records the full run provenance — suite identity and version, target identity, `ModelCapabilityDeclaration` identity (when a model was pinned), timestamps, scorer set.** `EvalReport` without provenance is not a valid report. See D12.
- **`EvalReport` is durable, not ephemeral telemetry.** A Pulse signal does not substitute for an `EvalReport`; the two are complements. See D13.
- **Eval-signal telemetry may carry prompts and outputs unless the suite declares itself sensitive.** This is a deliberate carve-out from Knowledge's and Memory's content-never-in-telemetry rule; sensitive suites strip content from emitted signals. See D10.
- **Router bypass is permitted only through `IEvalTarget`.** No other Node introduces an alternate inference path that pins a `ModelCapabilityDeclaration` outside the routing layer; Evals's carve-out is narrow and auditable via `EvalReport` provenance per D12. See D6.
- **The Evals Node CI must include a contract-shape canary for `IEvaluator`, `IEvalScorer`, `IEvalTarget`, and `EvalReport`.** Shape drift on any of the four is a build failure, not a downstream discovery. See D14.

### Contract-shape canary becomes a requirement

The contract-shape canary in D14 is a gating requirement on the Evals Node's CI from the first scaffold. It is not a later hardening pass — the four frozen surfaces are the hot path for every Node that ships suites or consumes reports and must be protected from day one.

### Catalog obligations

`catalogs/contracts.json` currently carries a three-interface seed for `honeydrunk-evals` (`IEvalRunner`, `IEvalScorer`, `IEvalSuite`) that does not match the current `catalogs/relationships.json` `exposes.contracts` list (`IEvaluator`, `IEvalDataset`, `IEvalScorer`, `IEvalReport`) or the repo prose (`IEvaluator`, `IEvalDataset`, `IEvalScorer`, `IEvalReport`). This ADR's D3 pins the definitive set and the follow-up work section lists each rename, promotion, and addition against each cataloged source. `catalogs/relationships.json` for `honeydrunk-evals` needs seven missing `consumes` edges added (Kernel, Agents, Capabilities, Operator, Knowledge, Memory, plus widening the AI edge's `consumes_detail`) and `exposes.contracts` reconciled to the D3 set. `catalogs/nodes.json` `roadmap_focus` prose is corrected to name the D3 surfaces. `repos/HoneyDrunk.Evals/overview.md` and the Evals section of `constitution/ai-sector-architecture.md` are aligned to the D3 set. `catalogs/grid-health.json` gets the Evals entry updated for the stood-up contract surface and the canary expectation. All reconciliations are tracked in the follow-up work section at the top of this ADR.

### Negative

- **Six exposed surfaces (four interfaces plus two records) plus the router-bypass rule plus the sensitivity-flag rule is more public surface than a minimal "single `IEvaluator` plus a report bag" design would ship.** The trade is clarity of responsibility, regression-grade provenance, a clean pinning primitive that does not widen AI's hottest interface, and independent testability against modestly more contract surface to version. Given the contract-shape canary on the four hot-path surfaces, the extra surface costs little to maintain.
- **Reconciling three drifted cataloged sources (contracts.json, relationships.json, repo overview) at the same time as standing up the Node is more follow-up work than a greenfield stand-up would require.** Accepted: the drift is the problem this ADR solves, and reconciling it now — rather than adding a fourth variant — is the point of pinning the D3 definitive set in this ADR.
- **Shipping `Providers.InMemory` at stand-up without a production report store means no production-ready `EvalReport` backend exists at first release.** Accepted: `InMemory` is enough to unblock all first-wave consumers on the contract surface, and the durability principle is pinned independent of the storage substrate per D13. The first production backend lands under its own issue packet once HoneyHub or a production regression workflow drives the shape.
- **The eval-signal content carve-out (D10) creates a third category in the Grid's telemetry rules (`no content` for Knowledge and Memory, `content permitted unless sensitive` for Evals).** Accepted: the carve-out is structurally necessary — regression diagnosis without content is almost always useless — and the sensitivity flag gives consumers a way to opt out of the carve-out when the suite's content is regulated. The three-category rule is explicit in the new invariants so future readers find it before re-deriving it.
- **`IEvalTarget`'s router-bypass primitive creates a narrow exception to ADR-0016's "all inference goes through the router" norm.** Accepted and auditable: every bypass is recorded on the corresponding `EvalReport`'s `ModelCapabilityDeclaration` provenance field per D12, and the bypass is only exposed through `IEvalTarget` (no other Node has a parallel surface). The narrow exception is cheaper than the alternatives — widening `IChatClient` or duplicating provider composition — and it is contained at Evals's boundary.
- **Concrete target shapes (`AgentTarget`, `RetrievalTarget`, `MemoryTarget`) are deferred to scaffold.** Accepted: the stand-up commitment is the `IEvalTarget` contract itself plus a default `ChatTarget`. Agent/retrieval/memory targets land at scaffold with the concrete case-level requirements that drive their shapes. This matches the deferral pattern ADR-0020 D3, ADR-0021 D3, and ADR-0022 D3 applied.
- **Pulse ingress back into Evals (reactive suite selection, reactive re-run) is deferred.** Operator-driven and consumer-driven suite selection via App Configuration covers the stand-up need; automatic reactive tuning is a later concern and matches the emit-only stance every prior AI-sector stand-up took.
- **Pinning the `EvalReport` durability principle without committing to a storage substrate leaves a decision to make in the scaffold.** Accepted: the durability principle is stable independent of the substrate, and committing to a specific store (Data, Pulse-backed, dedicated) before a production consumer exists would likely require revision when HoneyHub or a production workflow lands.

## Alternatives Considered

### Fold Evals into HoneyDrunk.AI

Rejected. AI owns inference — `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration` per ADR-0016. Evals is a consumer of inference, not a provider of it, and folding evaluation into AI would inflate AI's charter from "canonical inference surface" to "canonical inference surface plus evaluation harness plus report persistence," dragging suite definitions, scorers, and report shapes into a Node whose hot path is already the most canary-protected in the sector. The two have different lifecycles (inference is per-call live production; evaluation is per-suite read-only observation), different state (AI holds no state across calls; Evals holds suites and reports), and different downstream consumers. Keeping them separate preserves AI's narrow inference charter and keeps Evals's observer role from drifting into inference ownership.

### Fold Evals into HoneyDrunk.Operator

Rejected. Operator enforces live production policy — `ISafetyFilter`, `ICostGuard`, `IApprovalGate`, `IAuditLog`, `IDecisionPolicy` per ADR-0018. Evals observes and scores outputs; it does not gate a live production path. The two are structurally different: Operator is an enforcer (decides whether an action proceeds), Evals is an observer (records whether an action's output met a rubric). Folding them would either inflate Operator's charter to include read-only observation (breaking its clean policy-enforcement role) or force Evals to inherit Operator's audit-write responsibilities (breaking its read-only invariant per D11). The observes-vs-enforces distinction in D4 and D7 is precisely the boundary that keeps the two Nodes clean, and it is the distinction that lets Evals *compose* Operator primitives as scoring signals without *becoming* Operator.

### Widen `IChatClient` with an explicit-model overload for router bypass

Rejected per D6 Option A. `IChatClient` is the Grid's canonical chat-completion surface and is frozen under ADR-0016 D8's contract-shape canary. Adding an explicit-model overload would (a) break the canary or require an expensive version bump on the hottest interface in the Grid, (b) inflate every caller's API surface with a concern only Evals has, and (c) create a second model-selection path that competes with the routing layer's single source of truth. One Node's special case should not reshape the Grid's hottest interface.

### Evals composes `IModelProvider` directly without `IEvalTarget`

Rejected per D6 Option B. Pulling `IModelProvider` composition into Evals's runtime would either duplicate the router's provider-discovery logic or introduce a second composition path that sees models the router does not see. Both produce drift, and both give Evals a routing-layer responsibility that belongs in AI. The chosen path (Option C — `IEvalTarget` pins `ModelCapabilityDeclaration` and composes `IModelProvider` through the host's DI container at evaluation time) keeps routing policy in AI, keeps the bypass narrow, and makes it auditable through `EvalReport` provenance.

### `IEvalReport` as an interface rather than a record

Rejected. `EvalReport` carries value-type data — per-case scores, per-case inputs and outputs, rubric breakdown, run provenance. That is a record shape, not a behavior surface. The grid-wide naming rule applies: records drop the `I` prefix and are cataloged with `kind: "type"`; interfaces keep the `I` prefix and are cataloged with `kind: "interface"`. `ModelCapabilityDeclaration` (ADR-0016), `CapabilityDescriptor` (ADR-0017), the four governance records (ADR-0018), and `KnowledgeSource` (ADR-0021) set the precedent. Keeping `IEvalReport` as an interface would create a second convention in the catalog and make the naming rule unenforceable.

### Keep three different cataloged contract sets (contracts.json, relationships.json, repo prose)

Rejected. The three-way drift between the three cataloged sources — `contracts.json` naming `IEvalRunner`/`IEvalScorer`/`IEvalSuite`, `relationships.json` naming `IEvaluator`/`IEvalDataset`/`IEvalScorer`/`IEvalReport`, and the repo overview naming the latter — is the concrete problem this ADR solves. Leaving the three variants in place would make every downstream compile-against-Abstractions attempt contingent on which cataloged source the consumer read first. The D3 definitive set plus the follow-up work section reconciles all three against a single authoritative contract surface.

### Agent-behavior evaluation deferred entirely to a later ADR

Rejected. Agent-behavior evaluation is a first-class use case for Evals — Agents's roadmap already lists suites that exercise tool-call sequences, memory writes, and final-output fidelity. Deferring agent-behavior evaluation at the contract level would mean the `IEvalTarget` abstraction could not generalise over agent targets without a follow-up contract revision, and downstream consumers would have to invent their own agent-testing harness in the meantime. `IEvalTarget` is defined in D3 and D6 to generalise over agent, retrieval, and memory targets at the contract level. What *is* deferred (to scaffold) is the concrete shape of `AgentTarget`, `RetrievalTarget`, and `MemoryTarget` — the surface each exposes to scorers — not whether Evals supports them at the contract level.

### Ship `HoneyDrunk.Evals.Testing` instead of `HoneyDrunk.Evals.Providers.InMemory`

Rejected. Evals has a clear provider-slot axis on the report-persistence side (SQL Server, Cosmos DB, Pulse-backed, or a dedicated store — any of which could ship later under the `Providers.*` family). The in-memory backend belongs on that axis as a production-shaped fixture under `Providers.InMemory`, not as a test-only `.Testing` artifact. The `.Testing` pattern ADR-0017 D2 set for Capabilities remains valid for that Node (where there is no provider-slot axis at the registry layer); it is the wrong shape for Evals, which matches Knowledge (ADR-0021 D2) and Memory (ADR-0022 D2) on this axis.

### Eval reports in Pulse only, no durable persistence

Deferred. The durability principle — `EvalReport` is a durable artifact, not ephemeral telemetry — is pinned at D13 specifically because Pulse-as-report-store is a legitimate *implementation* choice but not a legitimate *contract* substitute for durability. A quality signal pointing to a six-month-old regression needs the full `EvalReport` for the run that the signal refers to; retention-limited telemetry cannot guarantee the report is still recoverable. The storage *substrate* decision (Data vs Pulse vs dedicated) is deferred to scaffold per D13; the durability *principle* is not.

### Content in telemetry strictly forbidden (match Knowledge and Memory)

Rejected per D10. Strict forbidding would make eval-signal telemetry almost useless for its primary use case — regression diagnosis. A signal that case 42 of suite X dropped from 0.95 to 0.62 on model upgrade Y, without the text of case 42, requires an investigator to round-trip to `EvalReport` storage for every signal before triage can begin. The carve-out (content permitted by default, stripped when the suite declares itself sensitive) preserves the diagnosis-grade utility of eval signals while giving consumers a clean opt-out for regulated content. The sensitivity flag is the contract the three-category telemetry rule rests on; without the flag, the carve-out would be unconditional and the regulated-content use case would be unsupported.

### Pulse signal ingress into Evals at stand-up

Deferred per Q7. Reactive closed-loop tuning — where observed Pulse telemetry automatically re-selects suites, triggers re-runs, or adjusts score thresholds — is the same class of concern ADR-0018 flagged for Operator, ADR-0020 flagged for Agents, ADR-0021 flagged for Knowledge, and ADR-0022 flagged for Memory. It is not a stand-up decision. Emit-only at stand-up is the committed direction; any future ingress contract will be added as a distinct ADR.

### Defer the Evals stand-up until Flow or Sim needs it

Rejected. Every Node in the AI sector that shipped before Evals has a regression story it cannot write without this substrate. Agents ships agent-behavior suites (ADR-0020's downstream obligation); Knowledge ships retrieval-quality suites (ADR-0021's downstream obligation); Memory ships memory-workflow suites (ADR-0022's downstream obligation); HoneyHub when live aggregates eval signals. Deferring Evals would leave every one of those Nodes either blocked on regression testing or inventing their own harness, and the divergence across those harnesses would be immediate. The foundation cannot self-evaluate without this Node, and the foundation triad plus the three substrates is not "done" until Evals stands up to close it.
