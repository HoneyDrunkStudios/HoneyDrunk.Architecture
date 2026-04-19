# ADR-0024: Stand Up the HoneyDrunk.Flow Node — Workflow-Orchestration Substrate for the AI Sector

**Status:** Proposed
**Date:** 2026-04-19
**Deciders:** HoneyDrunk Studios
**Sector:** AI

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Reconcile `catalogs/contracts.json` entries for `honeydrunk-flow` to the definitive D3 contract set: `IWorkflowEngine`, `IWorkflow`, `IWorkflowStep`, `IWorkflowState`, `ICompensation` — five interfaces only; no records introduced at stand-up (record shapes — workflow-definition descriptors, step-result envelopes, compensation-context types — are deferred to the scaffold packet per the D5/D6 principle pin, and when introduced apply the grid-wide naming rule with `kind: "type"`)
- [ ] Update `catalogs/relationships.json` for `honeydrunk-flow`:
  - Add `honeydrunk-operator` to `consumes` with `consumes_detail` `["IApprovalGate", "ICircuitBreaker", "ICostGuard", "IAuditLog", "HoneyDrunk.Operator.Abstractions"]`
  - Add `honeydrunk-communications` to `consumes` with `consumes_detail` `["ICommunicationOrchestrator", "HoneyDrunk.Communications.Abstractions"]`
  - Add `honeydrunk-sim` and `honeydrunk-evals` to `consumed_by_planned` with per-edge `consumes_detail` reflecting Sim's read-only consumption of workflow definitions and Evals's consumption of `IWorkflowEngine` for workflow-level suite evaluation
  - Reconcile `exposes.contracts` to the D3 definitive set: `IWorkflowEngine`, `IWorkflow`, `IWorkflowStep`, `IWorkflowState`, `ICompensation`
- [ ] Coordinate the bidirectional `honeydrunk-flow` ↔ `honeydrunk-communications` edge with the consumer-side entry on Communications (ADR-0019 D10 pinned Communications's outbound edge; this ADR pins Flow's inbound consumption of `ICommunicationOrchestrator`, and both sides of the edge must be coherent in the catalog)
- [ ] Align `repos/HoneyDrunk.Flow/overview.md`, `repos/HoneyDrunk.Flow/boundaries.md`, `repos/HoneyDrunk.Flow/invariants.md`, and the Flow section of `constitution/ai-sector-architecture.md` to the D3 definitive set and the D4 boundary decision test
- [ ] Update `catalogs/grid-health.json` `honeydrunk-flow` entry to reflect the stood-up contract surface and the contract-shape canary expectation
- [ ] Wire the contract-shape canary into Actions for `IWorkflowEngine`, `IWorkflow`, `IWorkflowStep`, and `ICompensation` (four hot-path surfaces per D11)
- [ ] Add `integration-points.md` and `active-work.md` to `repos/HoneyDrunk.Flow/`, matching the template used by `repos/HoneyDrunk.Agents/`
- [ ] File the HoneyDrunk.Flow scaffold packet (solution structure, `HoneyDrunk.Standards` wiring, CI pipeline, `HoneyDrunk.Flow.Providers.InMemory` state backend, default `IWorkflowEngine` with in-process coordination, event-out approval-resume mechanism per D7, workflow-definition authoring shape per D13)
- [ ] Scope agent assigns final invariant numbers when flipping Status → Accepted

## Context

`HoneyDrunk.Flow` is cataloged in `catalogs/nodes.json` as the AI sector's workflow-orchestration substrate, but the repo is cataloged-not-yet-created — no packages, no contracts, no engine, no step primitive, no compensation surface, no state store, no CI. Agents is a single-agent runtime per ADR-0020; Operator enforces per-decision policy per ADR-0018; Communications orchestrates intent-to-channel routing per ADR-0019; none of them own *multi-step coordination across time* — the thing that runs a "research → draft → approve → publish" pipeline over hours or days, persists state across process restarts, compensates partial failures, and resumes after a human approval event. Lore already declares a runtime dependency on `IWorkflowEngine` in `catalogs/relationships.json`; HoneyHub (when live) will plan at the org-timescale and hand executable pipelines to Flow; Sim needs workflow definitions as read-only fixtures to simulate; Evals needs `IWorkflowEngine` as an `IEvalTarget` to score workflow-level behavior. Without a dedicated substrate, each of those Nodes either blocks or invents its own mini-orchestrator, and the coordination surface fragments across the AI sector.

ADR-0016 stood up HoneyDrunk.AI as the inference substrate. ADR-0017 stood up HoneyDrunk.Capabilities as the tool-registry and dispatch substrate. ADR-0018 stood up HoneyDrunk.Operator as the human-policy enforcement and audit substrate. ADR-0020 stood up HoneyDrunk.Agents as the agent-runtime foundation node that composes those three substrates into a runnable single-agent execution. ADR-0021 stood up HoneyDrunk.Knowledge as the external-information ingestion and retrieval substrate. ADR-0022 stood up HoneyDrunk.Memory as the agent-memory substrate. ADR-0023 stood up HoneyDrunk.Evals as the evaluation and quality substrate. Flow is the first Node **above** the foundation: everything up to Evals gave the Grid the primitives to run and evaluate an AI workload; Flow is the first Node that composes those primitives into *multi-step, stateful, long-running pipelines* that can span multiple agents, a human approval checkpoint, and an outbound communication — things no single foundation Node owns on its own.

The stand-up pattern is deliberately reused: contracts live in an `Abstractions` package, runtime composition is a separate package, downstream Nodes compile against `Abstractions` only, and a first-wave `Providers.InMemory` package ships at stand-up so consumers have one shared in-memory backend for workflow-state persistence that they can compose in tests and in local development without standing up a production state store. The `.Providers.InMemory` name is chosen over `.Testing` deliberately — it matches the shape Knowledge (ADR-0021 D2), Memory (ADR-0022 D2), and Evals (ADR-0023 D2) took, and it signals that the in-memory backend is a production-shaped provider-slot implementation on Flow's state-persistence axis, not a test-only artifact. The `.Testing` pattern ADR-0017 D2 applied to Capabilities remains valid for that Node (where there is no provider-slot axis at the registry layer), but it is not the right shape for Flow, which has a clear provider-slot family on the workflow-state-persistence side.

The `catalogs/contracts.json` entry for `honeydrunk-flow` currently lists three interfaces (`IWorkflow`, `IWorkflowEngine`, `IWorkflowStep`), while the `catalogs/relationships.json` `exposes.contracts` list for the same Node says `IWorkflow`, `IWorkflowEngine`, `IWorkflowStep`, `IWorkflowState`, `ICompensation` — five interfaces. The repo overview at `repos/HoneyDrunk.Flow/overview.md` also names all five. This is a smaller drift than the three-way split Evals faced (ADR-0023 Context), but it is drift nonetheless, and it is reconciled here by pinning the D3 definitive set against every cataloged and prose reference.

Flow's boundary against the adjacent Nodes needs explicit disambiguation before drift creeps in, and two particular concerns — the "agent" term collision ADR-0020 D1 flagged, and the Flow-vs-Communications boundary ADR-0019 D10 started — need carving at stand-up rather than left to a "figure it out later" escape hatch.

1. **Flow vs Agents.** Agents owns *single-agent execution* — the lifecycle, execution context, and one-agent-at-a-time runtime per ADR-0020 D1. Flow owns *coordination across multiple single-agent executions and non-agent steps*. The parallel ADR-0020 D12 drew for the function-calling loop applies here: the loop of "model → tool-call → next model call" lives in **one** Node (Agents). The loop of "step 1 → wait → step 2 → human approval → step 3" lives in **one** Node — Flow — and no other AI-sector Node may introduce an equivalent multi-step coordination loop. This is pinned in D1.
2. **Flow vs Operator.** Operator enforces live policy — `IApprovalGate` raises approval requests, `ICircuitBreaker` halts execution when thresholds are breached, `ICostGuard` bounds cost, `IAuditLog` records decisions per ADR-0018. Flow *consumes* those primitives synchronously on the critical path when a workflow step requires them, and subscribes asynchronously to the approval-needed event Operator emits (ADR-0018 D8) so a paused workflow can resume when the approval decision lands. Flow does not re-implement any of those surfaces. D7 pins the resume mechanism shape.
3. **Flow vs Communications.** Communications orchestrates outbound message intent into channel-appropriate delivery per ADR-0019. When a workflow step's purpose is to send a notification ("the approval is required," "the workflow completed," "the weekly digest has been compiled"), the step delegates to `ICommunicationOrchestrator` from `HoneyDrunk.Communications.Abstractions`. Flow is a consumer of Communications, not a parallel messaging layer. ADR-0019 D10 pinned the Communications side of this edge at the planned level; this ADR pins the Flow side at the runtime level. D8 records the rule and calls out that `HoneyDrunk.Flow.Abstractions` stays clean — the Communications dependency lives in the runtime package only, so downstream consumers compiling against `HoneyDrunk.Flow.Abstractions` do not inherit Communications transitively.
4. **Flow vs Memory.** Memory is the agent-memory substrate per ADR-0022 — it stores what an agent remembers across executions. Flow holds **coordination state** — the between-step data that defines where a workflow is in its own pipeline (which step is current, what the last step's output was, which steps have checkpointed, what compensation path has been recorded). These are structurally different. When a workflow step invokes an agent, that agent writes to Memory during *its own* execution — that is Agents's runtime behavior per ADR-0022 D4's Memory-vs-Agents rule, not a Flow concern. Flow never writes to Memory on its own behalf. D9 pins the state boundary and the principle that there is no direct `honeydrunk-flow` → `honeydrunk-memory` edge in relationships.json: the edge, where it exists, is indirect through Agents.
5. **Flow vs HoneyHub.** HoneyHub is the planner and decomposer at the org-timescale (goals → features → tasks → dispatched work, per ADR-0002 and ADR-0003). Flow is the executor at the runtime-timescale (seconds → minutes → hours → days of a single workflow instance). HoneyHub decides *what* workflows to run; Flow runs them. The two-tier separation is already in `repos/HoneyDrunk.Flow/boundaries.md` and is confirmed in D4.

This ADR is the **stand-up decision** for the Flow Node — what it owns, what it does not own, which contracts it exposes, how downstream Nodes couple to it, and how it interacts with Agents, Operator, Communications, Memory, Knowledge, Evals, Sim, Lore, Pulse, and HoneyHub. "Node" is used throughout in the ADR-0001 sense — a library-level building block producing one or more NuGet packages, not a deployable service. This ADR is not a scaffolding packet. Filing the repo, adding CI, wiring the in-memory provider, producing the first shippable packages, and specifying the event-out resume transport mechanism all follow as separate issue packets once this ADR is accepted.

## Decision

### D1. HoneyDrunk.Flow is the AI sector's workflow-orchestration substrate

`HoneyDrunk.Flow` is the single Node in the AI sector that owns **workflow-orchestration primitives** — the contracts and runtime machinery that define a multi-step pipeline, execute its steps in order (or in parallel), persist the between-step state across process restarts, compensate partial failures in the correct order, and resume execution after a human-in-the-loop approval or an external event. It is a shared substrate, not an application. It does not decide *what pipelines to run* (that is HoneyHub when live, or the consumer directly); it owns the mechanics of *how a pipeline is declared, how its state is carried across steps, how failures are compensated, and how a paused run resumes*.

Pipeline *content* — the specific steps, their ordering, the compensation mapping, the retry policies, the approval gates — is decided by the consumers. Each consumer maintains the workflow definitions for the concerns it cares about: Agents can ship multi-agent coordination workflows; Lore can ship compile-the-wiki workflows; HoneyHub can ship dispatch-and-supervise workflows; application Nodes can ship their own domain pipelines. Flow provides the engine; consumers provide the workflows.

Flow is the first Node above the foundation. Everything up to Evals is a foundation node — the primitives that let the Grid run and evaluate an AI workload. Flow is the first Node that *composes* those primitives into something larger than a single execution: a multi-step coordination loop that can span multiple agents, a human approval checkpoint, an outbound communication, and a durable state that outlives any single process. The parallel ADR-0020 D12 drew for the function-calling loop ("loop lives in one Node") applies directly here: the multi-step coordination loop lives in **one** Node — Flow — and no other AI-sector Node may introduce an equivalent loop. Letting Agents, Operator, Communications, or application Nodes each invent their own mini-orchestrator would produce incompatible coordination surfaces and no shared state, compensation, or resume story.

### D2. Package families

The Flow Node ships the following package families, mirroring the stand-up shape used by ADR-0016 (AI), ADR-0017 (Capabilities), ADR-0018 (Operator), ADR-0019 (Communications), ADR-0020 (Agents), ADR-0021 (Knowledge), ADR-0022 (Memory), and ADR-0023 (Evals):

- `HoneyDrunk.Flow.Abstractions` — all interfaces (`IWorkflowEngine`, `IWorkflow`, `IWorkflowStep`, `IWorkflowState`, `ICompensation`) per D3. Zero runtime dependencies beyond `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Agents.Abstractions` (for `IAgent` / `IAgentExecutionContext` on the agent-step path — see D5). Crucially, `HoneyDrunk.Flow.Abstractions` does **not** take a compile-time dependency on `HoneyDrunk.Operator.Abstractions` or `HoneyDrunk.Communications.Abstractions` — both of those are runtime-only edges consumed inside the default `HoneyDrunk.Flow` package (see D7 and D8). Consumers of `Abstractions` do not inherit Operator or Communications transitively.
- `HoneyDrunk.Flow` — runtime composition: default `IWorkflowEngine` with in-process coordination, default `IWorkflowStep` adapters for agent-invocation steps and compensation-registration steps, retry and backoff primitives, workflow-definition authoring shape (D13), the event-out resume mechanism against Operator's approval events (D7), and DI wiring. Takes first-class runtime dependencies on `HoneyDrunk.Agents.Abstractions` (for `IAgent` invocation on agent steps), `HoneyDrunk.Operator.Abstractions` (for `IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, `IAuditLog` composition on safety-critical paths), and `HoneyDrunk.Communications.Abstractions` (for `ICommunicationOrchestrator` on outbound-message steps).
- `HoneyDrunk.Flow.Providers.InMemory` — in-memory backend for workflow-state persistence. Zero-network, deterministic, suitable for tests, local development, and seed workflow runs. Consumed by downstream Nodes in test projects and in local composition; never in production composition of a real long-running workflow.

The production-grade state store (SQL Server via Data, Cosmos DB, a dedicated provider, or something introduced specifically for workflow state) is **not first-wave**. The provider slot exists at stand-up via `Providers.InMemory`; a durable production backend ships under a separate issue packet once a real consumer (Lore's wiki-compilation workflow, HoneyHub's dispatch workflows when live, or the first production agent-chaining pipeline) drives the shape. This is the same staged-shape pattern ADR-0021 D2, ADR-0022 D2, and ADR-0023 D2 applied to provider slots. Pinning `IWorkflowState` as a durable surface (D9, D12) is independent of committing to a specific substrate for that durability.

No separate `HoneyDrunk.Flow.Testing` package is introduced at stand-up. The `Providers.InMemory` package already plays that role — it is the in-memory backend every downstream test project can compose. This differs from Capabilities (ADR-0017 D2), which ships `.Testing` because there is no provider-slot axis at the registry layer; Flow, like Knowledge, Memory, and Evals, has a clear provider-slot axis (workflow-state persistence) and the in-memory fixture belongs there.

### D3. Exposed contracts

Five interfaces form the Flow Node's public boundary at stand-up. These are the surfaces downstream Nodes are allowed to compile against, and they are the definitive set against which the cataloged sources (contracts.json, relationships.json, overview.md) are reconciled per the follow-up work section.

| Contract | Kind | Purpose |
|---|---|---|
| `IWorkflowEngine` | interface | Top-level orchestration surface — start, pause, resume, cancel, compensate, and query the status of a workflow instance. The per-instance engine lifecycle entry point. |
| `IWorkflow` | interface | A named, versioned workflow definition — its steps, transitions, compensation mapping, and metadata. Declarative; describes the pipeline shape. |
| `IWorkflowStep` | interface | A single unit of work within a workflow — execute, compensate, retry-policy declaration. Steps may invoke agents, call tools, wait for external events, or emit messages. |
| `IWorkflowState` | interface | Persistent state for a running workflow instance — current step, step outputs carried forward, checkpoints, compensation log, correlation identity, causation chain. The durable between-step data. |
| `ICompensation` | interface | Rollback logic for a failed step — declared alongside a step's forward execution and invoked in reverse order when the workflow fails or is cancelled after the step completed. |

All five surfaces are interfaces at stand-up. No records are introduced. Record shapes — workflow-definition descriptors (name, version, step graph), step-result envelopes (output payload, outcome, duration), compensation-context types (the failure reason, the state at failure, the rollback trace) — are **deferred to the scaffold packet**. When introduced they apply the grid-wide naming rule (records drop the `I` prefix and catalog with `kind: "type"`; interfaces retain the `I` prefix and catalog with `kind: "interface"`). This matches the deferral pattern ADR-0020 D3 used for agent record shapes, ADR-0021 D3 used for retrieval request/response shapes, ADR-0022 D3 used for `MemoryEntry`, and ADR-0023 D3 used for concrete `IEvalTarget` shapes. No `kind: "record"` is used anywhere in the catalog schema.

`IWorkflowState` and `ICompensation` are new interface entries relative to the current `catalogs/contracts.json` three-interface seed. The reconciliation is tracked in the follow-up work section.

### D4. Boundary rule with Agents, Operator, Communications, Memory, Knowledge, Evals, Sim, Lore, Pulse, and HoneyHub (definitive)

The surrounding Nodes need an explicit boundary test so that drift does not creep in once Flow ships. The rule below is the decision test Flow applies when an ambiguous concern is proposed.

**Decision test — for any concern in the orchestration path, ask:**

1. Does it execute a single agent against an inference + tools + memory stack? → **Agents** (Flow invokes `IAgent` from a workflow step; it does not own the agent execution loop itself, which lives inside Agents per ADR-0020 D12).
2. Does it enforce a live production policy — approve, halt, cost-gate, or audit — for a specific decision? → **Operator** (Flow composes Operator primitives synchronously on the critical path per D7; it does not re-implement enforcement).
3. Does it orchestrate an outbound message to a human recipient over a specific channel? → **Communications** (Flow emits an intent to `ICommunicationOrchestrator` from a message step per D8; it does not own channel selection, preferences, or cadence).
4. Does it persist agent-generated content across executions? → **Memory** (through Agents — see D9; Flow holds coordination state only and has no direct Memory edge).
5. Does it ingest or retrieve externally-sourced knowledge? → **Knowledge** (through Agents, which consumes `IRetrievalPipeline` during agent execution; Flow does not invoke retrieval from its coordination layer).
6. Does it score a workflow's output against a rubric or detect regression? → **Evals** (Evals consumes `IWorkflowEngine` as an `IEvalTarget` per ADR-0023 D4/D6; Flow does not own scoring).
7. Does it simulate a workflow against deterministic fixtures for risk or outcome analysis? → **Sim** (Sim consumes `IWorkflow` definitions as read-only fixtures and runs them through its own simulation substrate; Flow does not own simulation).
8. Does it plan work at the org-timescale — decompose goals into features, features into tasks, tasks into dispatched work? → **HoneyHub** (HoneyHub decides *what* workflows Flow runs; Flow runs them at the runtime timescale per ADR-0002, ADR-0003, and `repos/HoneyDrunk.Flow/boundaries.md`).
9. Does it ingest telemetry or host signal streams? → **Pulse** (Flow emits workflow lifecycle, step, and compensation telemetry into Pulse per D10 but has no runtime dependency on Pulse, matching the emit-only stance every prior AI-sector stand-up took).
10. Does it declare a multi-step pipeline, coordinate between-step state across time, compensate partial failures, or resume after a pause? → **Flow**.

Under this test, several subtleties are worth naming explicitly:

- **The multi-step coordination loop lives in one Node.** The rule ADR-0020 D12 pinned for the function-calling loop ("loop lives in one Node — Agents — and no other AI-sector Node may introduce an equivalent loop") applies here at the coordination layer. The loop of "step 1 → pause → step 2 → human approval → step 3" lives in Flow and nowhere else. This is pinned in D1 and is the single most important cross-Node rule this ADR establishes.
- **The agent-term collision is managed.** ADR-0020 D1 disambiguated "agent" across three referents (the `HoneyDrunk.Agents` Node, on-disk `.claude/agents/*.md` authoring personas, and the deprecated ADR-0004 frontmatter). Flow compounds this only slightly: a workflow step that invokes an agent invokes an `IAgent` from `HoneyDrunk.Agents`. A workflow itself is not an agent, and a workflow definition is not a Claude agent persona. This ADR always means an `IAgent` runtime instance when it says "an agent" in lowercase, and always means `HoneyDrunk.Agents` when it capitalizes.
- **A naming-disambiguation precedent applies.** ADR-0012 named `HoneyDrunk.Actions` as the CI/CD control plane, and ADR-0017's "action" surface in Capabilities deliberately sidestepped collision by using "capability" instead. This ADR adopts the same posture for Flow's step surface: an `IWorkflowStep` is a *step*, not an "action," not a "capability," and not a "GitHub Action." The term-collision-management precedent ADR-0017 established is followed: when multiple Grid-facing vocabularies share a word, each Node picks a distinct term for its own surface rather than re-using the shared word.
- **Flow consumes; it does not coordinate ownership.** When an agent step composes inference, tools, and memory, it does so *through* `IAgent` — Agents owns the composition per ADR-0020 D5/D6. Flow never reaches around `IAgent` to invoke `IChatClient`, `IToolInvoker`, or `IAgentMemory` directly from a workflow step. This is the Flow analogue of ADR-0020 D5's rule ("Agents does not invent its own registry"): Flow does not invent its own agent-runtime composition, and any attempt to reach through to the inner surfaces is a boundary violation.

`catalogs/relationships.json` currently lists Flow's `consumes` as `honeydrunk-kernel`, `honeydrunk-agents`, `honeydrunk-data`, `honeydrunk-transport`. Operator and Communications are missing at the runtime-composition level and are added as follow-up work, with Sim and Evals added to `consumed_by_planned`. The follow-up section at the top of this ADR lists every edge that needs reconciliation.

### D5. Agent-step composition — Flow invokes `IAgent`, not the underlying stack

`IWorkflowStep`'s default agent-step adapter takes a first-class runtime dependency on `HoneyDrunk.Agents.Abstractions` and invokes `IAgent` per ADR-0020 D3 from the step's execution path. Flow does not invent its own agent abstraction, does not talk to `IChatClient` or `IToolInvoker` directly, and does not manage `IAgentExecutionContext` lifecycle itself. The agent step supplies the request, awaits the result, and carries the result forward as part of `IWorkflowState` to the next step.

When a workflow has multiple agent steps in sequence ("research agent → draft agent → reviewer agent"), each step invokes a distinct `IAgent` execution — per ADR-0020 D8, each agent's execution-scope state is disposed when its invocation ends. Flow does **not** keep the upstream agent's execution context alive for the downstream agent; the downstream agent receives only what Flow has carried forward in `IWorkflowState`. This is deliberate and matches ADR-0020 D8's "execution-scope state is ephemeral" rule: Flow coordinates between agents at the workflow-state level, not at the execution-context level.

Downstream Nodes that compile against `HoneyDrunk.Flow.Abstractions` see the five surfaces in D3 as plain interfaces. They inherit a transitive compile-time dependency on `HoneyDrunk.Agents.Abstractions` through the agent-step shape — this is accepted and matches the way ADR-0020 D5, ADR-0021 D5, ADR-0022 D5, and ADR-0023 D5 treated upstream `Abstractions`-level edges. The runtime edges to `HoneyDrunk.Agents`, `HoneyDrunk.Operator`, and `HoneyDrunk.Communications` (runtime composition) are resolved at the host, not at the consumer.

### D6. Compensation model — orchestration-based, per-step, at stand-up

When a workflow step fails (after exhausting its retry budget, or when a downstream step fails and the pipeline is rolling back), Flow executes the registered `ICompensation` for each previously-completed step in reverse order. This is **orchestration-based compensation**: the engine owns the compensation sequence, walks the step list, and invokes each step's declared compensation. The compensation sequence is deterministic, driven by the persisted `IWorkflowState`, and idempotent — a compensation that has already run is skipped on resume.

This replaces and pins what `repos/HoneyDrunk.Flow/invariants.md` item 3 ("failed steps execute compensation before the workflow fails") already sketched: the principle is already Node-local; this ADR elevates the orchestration-based model to the cross-Node level and names it as the stand-up commitment.

**Choreography-based saga primitives** — where each step publishes an event on completion and a compensating handler subscribes to a failure event elsewhere, without a central orchestrator walking the compensation sequence — are **deferred to a future ADR**. Orchestration-based compensation is sufficient for the first wave of consumers (Lore's wiki-compilation workflow, HoneyHub's dispatch workflows when live, the first agent-chaining pipelines), and it avoids standing up a distributed-saga substrate before a real consumer drives the shape. The deferral is flagged in Alternatives Considered.

### D7. Approval resume via event-out — Flow subscribes, Operator emits

`IWorkflowEngine` composes `IApprovalGate` from `HoneyDrunk.Operator.Abstractions` per ADR-0018 D3 on the approval-required path. When a workflow step requires human approval, Flow records the pause in `IWorkflowState`, the step returns a "paused-awaiting-approval" outcome, and the engine releases its hold on the execution thread — the workflow is now durable-paused and will resume when the approval decision lands.

The **resume mechanism** is event-out via Transport: Operator emits the approval-needed event per ADR-0018 D8, the human acts (through Communications per ADR-0019 D10), Operator records the decision and emits an approval-decision event, and Flow subscribes to that event. When the event lands, Flow looks up the paused workflow instance by correlation, rehydrates `IWorkflowState` from the state store, and resumes execution from the step after the approval gate. This shape is symmetric with ADR-0018 D8's treatment of the approval-needed event: Operator emits, consumers subscribe; the Transport mechanism (which broker, which envelope shape, which subscription surface) is deferred to the scaffold packet.

The deferral of the Transport mechanism is intentional and matches the ADR-0018 D8 pattern: the principle (Flow subscribes to an approval-decision event; Flow does not block synchronously on `IApprovalGate` for long-running human approvals) is pinned at stand-up, and the wire shape is the scaffold's concern. A synchronous `await approvalGate.WaitForDecision()` would kill durable workflow semantics — a paused workflow must survive process restarts, and a blocked thread cannot. That path is rejected explicitly in Alternatives Considered.

Flow also composes `ICircuitBreaker`, `ICostGuard`, and `IAuditLog` from `HoneyDrunk.Operator.Abstractions` per ADR-0018 for synchronous in-loop checks: before a step executes, the engine consults `ICostGuard` (is the workflow under budget?) and `ICircuitBreaker` (is execution allowed?), and after a step executes, the engine writes an `AuditEntry` through `IAuditLog` recording the step's decision. These are invocation edges on the critical path — same shape as ADR-0020 D7's Agents → Operator invocation edge.

### D8. Communications composition — message steps delegate to `ICommunicationOrchestrator`

When a workflow step's purpose is to send a notification (approval-required message to the human reviewer, completion notice to the consumer, digest publication, etc.), the step composes `ICommunicationOrchestrator` from `HoneyDrunk.Communications.Abstractions` per ADR-0019 D3 and emits the intent. Flow does not talk to `INotificationSender` directly, does not own channel selection, recipient resolution, preference checking, or cadence policy — all of that belongs to Communications per ADR-0019.

This is a **first-class runtime dependency** of `HoneyDrunk.Flow`. The dependency lives in the runtime package only. `HoneyDrunk.Flow.Abstractions` stays clean — consumers compiling against `Abstractions` do not inherit `HoneyDrunk.Communications.Abstractions` transitively. The rule is the same split ADR-0019 D5 enforced for Communications → Notify: the abstraction layer has zero peer-Node dependencies; the runtime layer has them where composition demands.

ADR-0019 D10 pinned the Communications side of the Flow ↔ Communications edge at the planned level ("Communications is planned as consumed by Flow for workflow-step message emission"). This ADR pins the Flow side at the runtime level and names the specific contract consumed (`ICommunicationOrchestrator`). The bidirectional edge needs coherent catalog entries on both sides — tracked in the follow-up work section.

The rule that Flow delegates outbound messaging to Communications is load-bearing for the D4 boundary: a workflow step that directly calls `INotificationSender` would collapse the ADR-0019 boundary (Communications is bypassed, preferences and cadence are skipped, intent is lost). This path is rejected explicitly in Alternatives Considered.

### D9. State boundary — Flow holds coordination state, not agent or memory state

Flow holds **coordination state** — the `IWorkflowState` for every in-flight workflow instance (which step is current, what each completed step's output was, which steps have checkpointed, what compensations have been recorded, the workflow's correlation id, the step-to-step causation chain), the `IWorkflow` definitions (authored content — step graph, transitions, compensation mapping), and the per-instance execution state during an active step run. All of this is backed by `Providers.InMemory` at stand-up, with the production state store deferred per D2.

Flow does **not** hold:

- **Agent state.** That is Agents's job. When a workflow step invokes an `IAgent`, the agent's execution context, tool-call sequence, and short-term memory live on `IAgentExecutionContext` per ADR-0020 D8 for the duration of that step's invocation and are disposed when the invocation ends. Flow carries the agent's *result* (the output payload) forward in `IWorkflowState`; it does not carry the agent's execution context forward.
- **Long-term agent memory.** That is Memory's job per ADR-0022. When an agent invoked from a workflow step writes to memory, the write goes through `IAgentMemory` → `IMemoryStore` / `IMemoryScope` inside Agents's runtime — Flow is not on that path. **There is no direct `honeydrunk-flow` → `honeydrunk-memory` edge in `catalogs/relationships.json`** because Flow never writes to Memory on its own behalf; the edge, where it exists functionally, is indirect through Agents. This is deliberate and pinned here explicitly to prevent drift.
- **Audit trail.** That is Operator's job per ADR-0018 D9. Flow writes `AuditEntry` records through `IAuditLog` during workflow lifecycle transitions and step decisions per D7; the immutable audit record lives with Operator, not in `IWorkflowState`.
- **Knowledge sources.** That is Knowledge's job per ADR-0021. When an agent invoked from a workflow step retrieves documents, the retrieval goes through `IRetrievalPipeline` inside Agents's runtime — Flow is not on that path and never invokes retrieval from its coordination layer.
- **Outbound message history.** That is Communications's job per ADR-0019. When a message step delegates to `ICommunicationOrchestrator`, the send record lives with Communications (and, through Communications, with Notify); Flow records only that the step ran and what outcome it reported.

The rule is: if a piece of data must survive the end of the workflow or must answer a question about a specific non-Flow concern (what the agent thought, what document it read, what message went to whom), it belongs with its owner Node. Flow's state is strictly the pipeline's own shape — where it is, what it has produced so far, what it needs to compensate if it fails.

### D10. Workflow-lifecycle telemetry — Pulse consumes, Flow does not depend

Flow emits telemetry for every workflow lifecycle transition (start, pause, resume, cancel, complete, fail, compensate), every step execution (step identity, step outcome, duration, retry count, cost marker), every compensation invocation (which step, which compensation, outcome), and every state-persistence event (checkpoint write, state rehydration on resume) via Kernel's `ITelemetryActivityFactory`. Pulse consumes that telemetry downstream. **Flow has no runtime dependency on Pulse.** The direction is one-way by contract: Flow emits, Pulse observes. Same rule as every prior AI-sector stand-up.

The content-in-telemetry posture follows the content-telemetry pattern ADR-0021 D10 and ADR-0022 D9 pinned: workflow-lifecycle telemetry is **metadata-only** (identities, outcomes, durations, costs) and does not carry step input or output payloads. This differs from the deliberate eval-signal carve-out ADR-0023 D10 established (eval signals may carry prompts and outputs unless the suite declares itself sensitive, for regression-diagnosis reasons); workflow telemetry has no equivalent regression-diagnosis pressure on payload content, so the conservative "no content" rule applies. Step outputs are recoverable through `IWorkflowState` if an investigator needs them; telemetry is not the retrieval path.

Pulse signal ingress back into Flow — reactive workflow rescheduling, reactive cost-threshold tuning, reactive retry-policy adjustment based on observed production telemetry — is out of scope for stand-up. It is flagged in Alternatives Considered as a deferred concern and matches the emit-only stance every prior AI-sector stand-up took.

### D11. Contract-shape canary

A contract-shape canary is added to the Flow Node's CI: it fails the build if any of the following four surfaces change shape (method signatures, parameter shapes) without a corresponding version bump:

- `IWorkflowEngine`
- `IWorkflow`
- `IWorkflowStep`
- `ICompensation`

These four are the hot path for every real consumer. `IWorkflowEngine` is every workflow-running caller's entry point (Lore, HoneyHub when live, application pipelines, Evals via `IEvalTarget`). `IWorkflow` is the authoring surface every consumer declares pipelines against. `IWorkflowStep` is the injection surface for custom step types. `ICompensation` is the rollback surface every failure path depends on. Accidental shape drift on any of them breaks every Node that declares or runs workflows. The canary makes this a compile-time failure at Flow's own CI, not a discovery at consumer sites. This matches the pattern ADR-0016 through ADR-0023 established of freezing the hot-path surfaces.

`IWorkflowState` is not in the stand-up canary because its shape is expected to evolve as the production state store lands and reveals persistence-layer requirements (indexes, query shapes, snapshot boundaries). It becomes a canary candidate once the production store ships and the shape settles.

### D12. `IWorkflowState` is durable, not ephemeral — storage substrate deferred to scaffold

`IWorkflowState` is the durable artifact of an in-flight workflow run. A Pulse signal records *that* a workflow has a lifecycle event; `IWorkflowState` is the full artifact (current step, step outputs carried forward, checkpoints, compensation log, correlation identity, causation chain) that resume must rehydrate. The two are complements, not substitutes.

Pinning durability at the contract level means downstream consumers can rely on `IWorkflowState` surviving across runs, processes, and deployments. A workflow that pauses for a human approval can wait hours or days; the state must survive a process restart, a deployment, a host failover. Without durable state, "long-running" degrades to "runs only as long as one process is alive," which is not what Flow is for.

The **storage substrate** — whether `IWorkflowState` persists via `HoneyDrunk.Data.Abstractions` per the Data Node (currently listed on Flow's `consumes` edge), via a dedicated provider slot, or via something introduced specifically for workflow state — is **deferred to the scaffold packet**. The stand-up commitment is the durability principle plus `Providers.InMemory` as the first-wave backend. A production-grade store ships under a separate issue packet once a real consumer (Lore's wiki-compilation workflow, HoneyHub's dispatch workflows when live) drives the shape. This matches the staged-shape pattern ADR-0017 D6, ADR-0020 D12, ADR-0022 D11, and ADR-0023 D13 applied to deferred mechanism decisions.

### D13. Workflow-definition authoring shape — deferred to scaffold

How a consumer *authors* an `IWorkflow` — whether via a fluent C# builder, via a configuration-bound record graph loaded from App Configuration, via a declarative YAML/JSON surface, via attribute-based declaration on step handler classes, or via something else — is **deferred to the scaffold packet**. The stand-up commitment is the `IWorkflow` interface in D3 and the principle that authoring happens against `HoneyDrunk.Flow.Abstractions` (the authoring surface does not require the runtime package). The wire shape of the authoring layer lands with scaffold when the first real consumer (Lore, HoneyHub when live, an application pipeline) drives the shape.

This is the same deferral pattern ADR-0017 D6 applied to tool-schema versioning (principle at ADR, mechanism at scaffold) and ADR-0022 D8 applied to scope-resolution policy. Pinning the authoring shape prematurely would likely require revision when the first real consumer surfaces requirements the ADR could not predict.

### D14. Distributed engine deferred — in-process coordination at stand-up

The default `IWorkflowEngine` implementation runs **in-process** at stand-up: the engine, the state store (via `Providers.InMemory` or a Data-backed provider), and the step executor all live in one host. A workflow instance is coordinated by one engine instance, and resume after an event lands in the same host that was running the engine when the pause happened (or any host in the deployment — the state is durable, the engine is stateless aside from its connection to the state store and the event subscription).

A **cross-host distributed workflow engine** — where a workflow instance can be coordinated by a pool of engine instances across hosts with distributed locking, work stealing, or partition ownership — is **deferred to a future ADR**. In-process coordination is sufficient for the first wave of consumers, and standing up a distributed coordinator before a real production workload drives the partitioning and lock semantics would likely require revision. The deferral is flagged in Alternatives Considered.

The in-process default is not a deployment constraint on the consumer: a consumer can run multiple hosts, each running its own `HoneyDrunk.Flow` runtime composition, with a shared state store. What is deferred is the *coordinated* distributed engine where multiple engine instances cooperate on the same workflow instance. Independent engines on independent instances is fine.

## Consequences

### Unblocks

Accepting this ADR — and landing the follow-up scaffold packet that produces a first `Abstractions` release plus the `Providers.InMemory` backend — unblocks the Nodes currently waiting on Flow:

- **HoneyDrunk.Lore** — can compile against `IWorkflowEngine` for its wiki-compilation workflow (ingest → compile → review → publish) that already lists Flow on its `consumes` edge.
- **HoneyDrunk.Sim** — can consume `IWorkflow` definitions as read-only fixtures to run scenario-driven simulations of workflow behavior.
- **HoneyDrunk.Evals** — can use `IWorkflowEngine` as an `IEvalTarget` (a scaffold-deferred `WorkflowTarget` shape per ADR-0023 D3/D6) for workflow-level regression testing — "does this pipeline still produce equivalent outputs after an agent change."
- **HoneyHub (when live)** — can plan at the org-timescale and dispatch executable workflows to Flow at the runtime-timescale per the two-tier separation in `repos/HoneyDrunk.Flow/boundaries.md`.
- **Application Nodes with domain pipelines** — can ship multi-step workflows with retries, compensation, and approval gates without inventing their own orchestrator.

### New invariants (proposed for `constitution/invariants.md`)

Numbering is tentative — scope agent finalizes at acceptance.

- **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Flow.Abstractions`.** Composition against `HoneyDrunk.Flow` and any `HoneyDrunk.Flow.Providers.*` package is a host-time concern. See D2 and D8.
- **The multi-step coordination loop lives in `HoneyDrunk.Flow` and nowhere else.** No other AI-sector Node may introduce an equivalent loop of "step 1 → pause → step 2 → human approval → step 3." See D1 and D4.
- **Flow holds coordination state only.** Agent state, agent memory, audit trail, knowledge sources, and outbound message history live with their owner Nodes. See D9.
- **There is no direct `honeydrunk-flow` → `honeydrunk-memory` edge.** When a workflow step invokes an agent, the agent writes Memory during its own execution; Flow is not on the Memory edge. See D9.
- **Flow delegates outbound messaging to Communications.** No workflow step invokes `INotificationSender` directly; all message steps go through `ICommunicationOrchestrator`. See D8.
- **Approval-gated workflows pause durably; no synchronous block on `IApprovalGate`.** Resume is event-out via Transport per ADR-0018 D8's pattern. See D7.
- **`IWorkflowState` is durable, not ephemeral telemetry.** See D12.
- **`HoneyDrunk.Flow.Abstractions` does not take compile-time dependencies on `HoneyDrunk.Operator.Abstractions` or `HoneyDrunk.Communications.Abstractions`.** Both are runtime-only edges. See D2 and D8.
- **The Flow Node CI must include a contract-shape canary for `IWorkflowEngine`, `IWorkflow`, `IWorkflowStep`, and `ICompensation`.** Shape drift on any of the four is a build failure, not a downstream discovery. See D11.

### Contract-shape canary becomes a requirement

The contract-shape canary in D11 is a gating requirement on the Flow Node's CI from the first scaffold. It is not a later hardening pass — the four frozen surfaces are the hot path for every Node that declares or runs workflows and must be protected from day one.

### Catalog obligations

`catalogs/contracts.json` currently carries a three-interface seed for `honeydrunk-flow` (`IWorkflow`, `IWorkflowEngine`, `IWorkflowStep`) that does not match the `catalogs/relationships.json` `exposes.contracts` list or the repo overview (both of which already name all five). This ADR's D3 pins the definitive five-interface set and the follow-up work section reconciles `contracts.json` to it. `catalogs/relationships.json` for `honeydrunk-flow` needs two missing `consumes` edges added (Operator, Communications) and two `consumed_by_planned` edges added (Sim, Evals), along with the bidirectional Flow ↔ Communications edge coordination with ADR-0019 D10. `catalogs/grid-health.json` gets the Flow entry updated for the stood-up contract surface and the canary expectation. All reconciliations are tracked in the follow-up work section at the top of this ADR.

### Negative

- **Five interfaces plus the event-out resume mechanism plus the `Abstractions`-stays-clean rule on Operator and Communications is more public-and-internal surface than a minimal "single `IWorkflowEngine` plus a step bag" design would ship.** The trade is clarity of responsibility, a clean Abstractions layer that does not transitively drag Operator and Communications into consumers, durable long-running semantics, and independent testability against modestly more contract surface to version. Given the contract-shape canary on the four hot-path surfaces, the extra surface costs little to maintain.
- **Reconciling a three-way drift between `contracts.json` (three interfaces), `relationships.json` (five interfaces), and the repo overview (five interfaces) at the same time as standing up the Node is more follow-up work than a greenfield stand-up would require.** Accepted: the drift is the problem this ADR solves, and reconciling it now rather than carrying forward three variants is the point of pinning the D3 definitive set.
- **Shipping `Providers.InMemory` at stand-up without a production state store means no production-ready `IWorkflowState` backend exists at first release.** Accepted: `InMemory` is enough to unblock all first-wave consumers on the contract surface, and the durability principle is pinned independent of the storage substrate per D12. The first production backend lands under its own issue packet once Lore or HoneyHub (when live) drives the shape.
- **Deferring the event-out Transport mechanism (D7) and the workflow-definition authoring shape (D13) to the scaffold packet means the first real consumer may surface a need to revisit those shapes.** Accepted: this is the same cost ADR-0017 D6, ADR-0018 D8, ADR-0020 D12, ADR-0022 D11, and ADR-0023 D13 accepted for their equivalent deferrals, and it is cheaper than pinning a shape before a real consumer drives it.
- **Orchestration-based compensation (D6) and in-process coordination (D14) are both "good enough for the first wave" choices that may need revision when the first distributed or saga-heavy consumer lands.** Accepted: both are deliberate first-wave commitments, and the alternatives (choreography-based saga primitives, cross-host distributed engine) are flagged in Alternatives Considered for future ADRs.
- **`IWorkflowState` being durable without a committed storage substrate leaves a decision to make in the scaffold.** Accepted: the durability principle is stable independent of the substrate, and committing to a specific store (Data, dedicated provider) before a production consumer exists would likely require revision. This matches the ADR-0023 D13 pattern.
- **Pulse ingress back into Flow (reactive rescheduling, reactive policy tuning) is deferred.** Operator-driven and consumer-driven workflow tuning via App Configuration covers the stand-up need; automatic reactive tuning is a later concern and matches the emit-only stance every prior AI-sector stand-up took.

## Alternatives Considered

### Fold Flow into HoneyDrunk.Agents

Rejected. Agents owns single-agent execution per ADR-0020 D1. Folding multi-step coordination into Agents would drag Operator, Communications, multi-agent sequencing, long-running state, and compensation into a Node whose hot path is the single-agent execution loop. The two have different lifecycles (a single-agent execution is seconds; a workflow can be hours or days), different state models (agent state is execution-scope-ephemeral per ADR-0020 D8; workflow state is durable per D12), and different downstream consumers. Multi-agent and human-in-the-loop coordination require a separate coordinator, and ADR-0020 D12's "loop lives in one Node" argument applies in reverse here: the single-agent loop is Agents's, and the multi-step coordination loop is Flow's. Keeping them separate is the load-bearing boundary.

### Fold Flow into HoneyHub

Rejected. HoneyHub is the planner at the org-timescale per ADR-0002 and ADR-0003 — goals, features, tasks, dispatched work. Flow is the executor at the runtime-timescale — step-by-step pipeline execution with retries, compensation, and approvals. The two operate at structurally different timescales (days/weeks vs seconds/minutes/hours) and at structurally different abstraction levels (planning/decomposition vs execution/coordination). Folding them would put either planning semantics into a runtime engine or execution semantics into a planner, and `repos/HoneyDrunk.Flow/boundaries.md` already records the two-tier separation as a first-class rule. The separation is preserved here.

### Ship `HoneyDrunk.Flow.Testing` instead of `HoneyDrunk.Flow.Providers.InMemory`

Rejected per D2 and option A locked with the user. Flow has a clear provider-slot axis on the workflow-state-persistence side (SQL Server via Data, Cosmos DB, a dedicated provider, or something new — any of which could ship later under the `Providers.*` family). The in-memory backend belongs on that axis as a production-shaped fixture under `Providers.InMemory`, not as a test-only `.Testing` artifact. The `.Testing` pattern ADR-0017 D2 set for Capabilities remains valid for that Node (where there is no provider-slot axis at the registry layer); it is the wrong shape for Flow, which matches Knowledge (ADR-0021 D2), Memory (ADR-0022 D2), and Evals (ADR-0023 D2) on this axis.

### Choreography-based saga primitives at stand-up

Deferred per D6 and option C locked with the user. Saga-style compensation — where each step publishes an event on completion and compensating handlers subscribe to a failure event elsewhere, without a central orchestrator walking the compensation sequence — is a legitimate pattern for distributed transactions across autonomous services. At stand-up, orchestration-based compensation (D6) is sufficient for the first wave of consumers, avoids standing up a distributed-saga substrate before a real consumer drives the shape, and matches the in-process coordination default (D14). Choreography-based saga primitives are a future-ADR concern.

### Synchronous block on `IApprovalGate` for long-running human approvals

Rejected per D7 and option B locked with the user. A `while (!await approvalGate.HasDecision()) { ... }` path — or any variant that synchronously holds a thread waiting for a human approval that may take hours or days — kills durable workflow semantics. The blocked thread cannot survive a process restart, and the "paused workflow" becomes "workflow that runs only as long as one process is alive." The event-out resume pattern pinned in D7 (symmetric with ADR-0018 D8's approval-needed event emission) is the correct shape: Flow records the pause in `IWorkflowState`, releases the thread, and subscribes to the approval-decision event. When the event lands, the engine rehydrates state and resumes. The Transport mechanism is deferred per ADR-0018 D8's precedent.

### Flow invokes `INotificationSender` from HoneyDrunk.Notify directly

Rejected per D8. A workflow step that calls `INotificationSender` directly would collapse the ADR-0019 D1/D3 boundary: channel selection, recipient resolution, preference checking, and cadence policy all belong to Communications. Bypassing Communications means every workflow would either re-implement those concerns or skip them entirely, and the ADR-0013 orchestration layer would fragment. Flow composes `ICommunicationOrchestrator` per D8 and leaves channel and policy concerns to Communications.

### Widen `IWorkflowStep` to carry a simulation signature for Sim

Deferred. Sim consumes `IWorkflow` definitions as **read-only fixtures** per the D4 boundary rule — it runs its own simulation substrate against the definition, asserting on step ordering, state transitions, and risk scoring. Widening `IWorkflowStep` with a simulation-specific method (for example `SimulateAsync`) would inflate every step implementation with a concern only Sim has, and it would muddy the execute/compensate shape `IWorkflowStep` owns. If Sim surfaces a need for richer introspection into step shapes, the right path is a Sim-side target abstraction (parallel to Evals's `IEvalTarget`) that adapts over `IWorkflow` read-only — not a widened `IWorkflowStep`. This is a future Sim-ADR concern.

### Cross-host distributed workflow engine at stand-up

Deferred per D14. A coordinated distributed engine — multiple engine instances cooperating on a single workflow instance with distributed locking, work stealing, or partition ownership — requires a production workload that drives the partitioning and lock semantics. At stand-up, in-process coordination is sufficient, and committing to a distributed coordinator before a real consumer drives the shape would likely require revision. The in-process default is not a deployment constraint on consumers (multiple independent hosts running independent engines with a shared durable state store is fine); what is deferred is coordinated distribution.

### Defer the Flow stand-up until HoneyHub or Sim needs it

Rejected. Lore's `consumes` edge in `catalogs/relationships.json` already lists `honeydrunk-flow` with `consumes_detail` `["IWorkflowEngine", "HoneyDrunk.Flow.Abstractions"]` — Lore is already declared to consume Flow for its wiki-compilation workflow. Deferring Flow would leave Lore either blocked on its consume-Flow path or inventing its own orchestrator, and the divergence across Lore, HoneyHub (when live), Sim, and Evals would be immediate. The foundation plus Flow gives the Grid the first substrate capable of running multi-step AI pipelines; standing it up now is what lets the foundation's downstream consumers actually compose those pipelines.

### Pulse signal ingress into Flow at stand-up

Deferred per D10. Reactive closed-loop tuning — where observed Pulse telemetry automatically re-schedules workflows, adjusts cost thresholds, or tunes retry policies — is the same class of concern ADR-0018 flagged for Operator, ADR-0020 flagged for Agents, ADR-0021 flagged for Knowledge, ADR-0022 flagged for Memory, and ADR-0023 flagged for Evals. It is not a stand-up decision. Emit-only at stand-up is the committed direction; any future ingress contract will be added as a distinct ADR.

### Direct `honeydrunk-flow` → `honeydrunk-memory` edge

Rejected per D9 and option D locked with the user. Flow holds coordination state only. When a workflow step invokes an agent, that agent writes to Memory during *its own* execution — Memory is on Agents's runtime edge, not on Flow's. Adding a direct Flow → Memory edge would either (a) duplicate the Memory writes Agents already owns (drift), or (b) give Flow a second Memory-access path that sees scopes Agents does not see (boundary violation). The edge stays indirect through Agents, and `catalogs/relationships.json` `honeydrunk-flow.consumes` does not include `honeydrunk-memory`. This is pinned here explicitly to prevent drift.
