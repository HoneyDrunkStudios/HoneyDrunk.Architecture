# ADR-0020: Stand Up the HoneyDrunk.Agents Node — Agent Runtime Substrate for the AI Sector

**Status:** Proposed
**Date:** 2026-04-19
**Deciders:** HoneyDrunk Studios
**Sector:** AI

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Reconcile `catalogs/contracts.json` entries for `honeydrunk-agents`: confirm the five stand-up interfaces (`IAgent`, `IAgentExecutionContext`, `IAgentLifecycle`, `IToolInvoker`, `IAgentMemory`), ensure `IAgentLifecycle` is present, and flag that no records are introduced at stand-up (record shapes are a scaffold-packet concern per D2)
- [ ] Add `honeydrunk-memory` and `honeydrunk-operator` to `catalogs/relationships.json` `consumes` for `honeydrunk-agents`, each with a `consumes_detail` contract list (Memory: `IMemoryStore`, `IMemoryScope`, `HoneyDrunk.Memory.Abstractions`; Operator: `IApprovalGate`, `ICircuitBreaker`, `HoneyDrunk.Operator.Abstractions`)
- [ ] Add `honeydrunk-actions` to `consumed_by_planned` on `honeydrunk-agents` with a `consumes_detail` entry for `IAgentLifecycle` (the cloud-agent trigger path)
- [ ] Update `catalogs/grid-health.json` `honeydrunk-agents` entry to reflect the stood-up contract surface and the contract-shape canary expectation
- [ ] Wire the contract-shape canary into Actions for `IAgent`, `IAgentExecutionContext`, `IToolInvoker`, and `IAgentMemory`
- [ ] Fix `repos/HoneyDrunk.Agents/boundaries.md` — remove `IMemoryScope` from the Agents-owned contracts list; `IMemoryScope` is a Memory-Node contract that Agents consumes, not one that Agents owns
- [ ] Fix `repos/HoneyDrunk.Agents/integration-points.md` canary description — the `Agents.Canary → AI` line should read that `IChatClient` is resolved directly from HoneyDrunk.AI, not "through `IToolInvoker`"; `IToolInvoker` routes tool calls to Capabilities, not inference to AI
- [ ] File the HoneyDrunk.Agents scaffold packet (solution structure, `HoneyDrunk.Standards` wiring, CI pipeline, `HoneyDrunk.Agents.Testing` in-memory fixture, initial implementations of `IAgent`, `IAgentLifecycle`, default `IToolInvoker`, default `IAgentMemory`, and the function-calling adapter scaffold per D12)
- [ ] Scope agent assigns final invariant numbers when flipping Status → Accepted

## Context

`HoneyDrunk.Agents` is cataloged in `catalogs/nodes.json` as the AI sector's agent-runtime substrate, but the repo is cataloged-not-yet-created — no packages, no contracts, no lifecycle, no execution engine, no CI. Flow, Sim, Lore, HoneyHub (when live), and the HoneyDrunk.Actions cloud-agent trigger path all need a single, shared contract surface for agent identity, lifecycle, and execution context, and none of them own that responsibility. Without a dedicated substrate, each Node ends up inventing its own agent abstraction and the agent surface fragments across the AI sector.

ADR-0016 stood up HoneyDrunk.AI as the inference substrate. ADR-0017 stood up HoneyDrunk.Capabilities as the tool-registry and dispatch substrate. ADR-0018 stood up HoneyDrunk.Operator as the human-policy enforcement and audit substrate. Those three Nodes form the AI sector's foundation — inference, action, policy. Agents is the first AI-sector foundation node after the three substrates: it composes AI, Capabilities, and Operator into a runtime that executes a named agent against a user or system request. The stand-up pattern is deliberately reused: contracts live in an `Abstractions` package, runtime composition is a separate package, downstream Nodes compile against `Abstractions` only, and a separate `Testing` fixture package ships at stand-up so consumers get one shared in-memory implementation instead of N divergent doubles.

The `catalogs/contracts.json` entry for `honeydrunk-agents` already lists five interfaces (`IAgent`, `IAgentExecutionContext`, `IAgentLifecycle`, `IToolInvoker`, `IAgentMemory`). Two small catalog and prose issues exist that should not be silently carried forward:

- `repos/HoneyDrunk.Agents/boundaries.md` lists `IMemoryScope` in Agents's "What Agents Owns" section. `IMemoryScope` is declared by the Memory Node per its own cataloged contract list (`IMemoryStore`, `IMemoryScope`, `IMemorySummarizer`). Agents consumes `IMemoryScope`; it does not own it. This is fixed as follow-up work, not in this ADR, but the boundary decision (D4 below) records the correct owner.
- `repos/HoneyDrunk.Agents/integration-points.md` describes the Agents→AI canary as "verifies `IChatClient` is resolved through `IToolInvoker` mechanism, inference result is returned." That phrasing conflates two distinct surfaces: `IChatClient` is Agents's direct dependency on HoneyDrunk.AI (inference), while `IToolInvoker` routes tool calls to Capabilities. The canary scope is correct; the description is not.

Agents's boundary against three adjacent Nodes needs explicit disambiguation before drift creeps in:

1. **Agents vs AI.** AI owns inference mechanics. Agents owns *who is doing the thinking and why* — agent identity, lifecycle, execution context. Agents calls `IChatClient` directly; AI does not know agents exist.
2. **Agents vs Capabilities.** Capabilities owns the tool registry and dispatcher. Agents owns `IToolInvoker`, which is the agent-facing projection that adapts the Capabilities registry into the agent execution loop. The registry is Capabilities's; the invoker is Agents's.
3. **Agents vs Flow.** Flow owns multi-agent sequencing and workflow state. Agents owns single-agent execution. Flow consumes Agents, not the other way around.

There is also a three-way term collision to pin before it spreads. The word "agent" is overloaded across the Grid vocabulary:

- **`HoneyDrunk.Agents`** (this Node, uppercase) — the AI-sector Node that owns agent-runtime primitives. Always written as `HoneyDrunk.Agents` when referring to the Node.
- **`.claude/agents/*.md`** (per ADR-0007) — on-disk authoring files that define Claude Code and GitHub Copilot agent *personas* (scope, review, adr-composer, etc.). These are authoring-layer artifacts, not runtime primitives. They have nothing to do with `HoneyDrunk.Agents` beyond the English word.
- **`capabilities:` frontmatter in ADR-0004** (superseded) — the now-removed authoring-time mapping label for agent definition files. ADR-0004 is superseded by ADR-0007 and the frontmatter was dropped; the word is recorded here only because it is in the historical record, not because it has a current referent.

This ADR always means the Node when it says "Agents" with a capital A, and always means a runtime agent (an instance executing inside `HoneyDrunk.Agents`) when it says "an agent" in lowercase. The authoring files in `.claude/agents/` are never referred to by this ADR's running text.

This ADR is the **stand-up decision** for the Agents Node — what it owns, what it does not own, which contracts it exposes, how downstream Nodes couple to it, and how it interacts with AI, Capabilities, Operator, Memory, and Flow. "Node" is used throughout in the ADR-0001 sense — a library-level building block producing one or more NuGet packages, not a deployable service. This ADR is not a scaffolding packet. Filing the repo, adding CI, wiring the in-memory fixture, and producing the first shippable packages all follow as separate issue packets once this ADR is accepted.

## Decision

### D1. HoneyDrunk.Agents is the AI sector's agent-runtime substrate

`HoneyDrunk.Agents` is the single Node in the AI sector that owns **agent-runtime primitives** — the contracts and runtime machinery that manage the full agent lifecycle, provide scoped execution contexts, and define how agents invoke tools and access memory. It is a shared substrate, not an orchestrator. It does not decide *what a specific agent should do*; it owns the mechanics of *how an agent is brought up, executed, and torn down* and *what context that execution runs inside*.

Agent *logic* — the prompts, tool bindings, and decision rules for a specific named agent (scope, review, netrunner, etc.) — lives outside this Node. `HoneyDrunk.Agents` is the runtime skeleton; the body of each agent is declared by whatever Node or authoring file owns that agent's persona. The Node provides the contracts (`IAgent`, `IAgentExecutionContext`) and the execution loop; consumers provide the agent implementations.

The parallel to Kernel is intentional: Kernel gives every Node in the Grid a context, a lifecycle, and an identity; Agents gives every AI-sector agent the same three things scoped to the AI sector. Agents is to the AI sector what Kernel is to Core.

### D2. Package families

The Agents Node ships the following package families, mirroring the stand-up shape used by ADR-0016 (AI), ADR-0017 (Capabilities), and ADR-0018 (Operator):

- `HoneyDrunk.Agents.Abstractions` — all interfaces and any stand-up-time records. Zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions and the three upstream `Abstractions` packages Agents composes (`HoneyDrunk.AI.Abstractions`, `HoneyDrunk.Capabilities.Abstractions`, `HoneyDrunk.Operator.Abstractions`). No third-party AI-runtime packages are compile-time dependencies of `Abstractions` — see D13.
- `HoneyDrunk.Agents` — runtime composition: default `IAgent` harness, default `IAgentLifecycle`, default `IToolInvoker` (composes against `ICapabilityRegistry` / `ICapabilityInvoker`), default `IAgentMemory` (composes against `IMemoryStore` / `IMemoryScope`), agent-registry, DI wiring. The function-calling adapter (D12) ships in this package.
- `HoneyDrunk.Agents.Testing` — opt-in testing fixture package carrying in-memory implementations of every exposed interface, a deterministic clock hook for lifecycle tests, and a recording execution logger for assertion-based tests. Consumed by downstream Nodes in test projects, never in production composition.

The `Testing` package is a separate NuGet artifact rather than a `Providers.*` slot because there is no family of providers at the agent-runtime layer (no OpenAI-vs-Anthropic axis here — that axis lives in AI, which Agents composes). The in-memory implementation is a testing fixture, not a production backend.

No record shapes are frozen at stand-up. The five exposed surfaces are interfaces (see D3). Any records introduced later — `AgentId` value type, lifecycle-phase enums promoted to records, invocation-request shapes — land at the scaffold packet or in a later ADR, at which point they apply the grid-wide naming rule (records drop the `I` prefix, interfaces retain it; set 2026-04-19) already applied by `ModelCapabilityDeclaration` in ADR-0016, `CapabilityDescriptor` in ADR-0017, and the four governance records in ADR-0018.

### D3. Exposed contracts

Five interfaces form the Agents Node's public boundary at stand-up. These are the surfaces downstream Nodes are allowed to compile against:

| Contract | Kind | Purpose |
|---|---|---|
| `IAgent` | interface | Core agent interface — identity, capability declarations, execution entry point. |
| `IAgentExecutionContext` | interface | Agents-owned execution context extending Kernel's `IAgentExecutionContext` with AI-specific bindings (memory references, tool bindings, inference binding). |
| `IAgentLifecycle` | interface | Lifecycle hooks for agents: register → initialize → execute → complete → decommission. |
| `IToolInvoker` | interface | How agents call tools — resolves through Capabilities's `ICapabilityRegistry` and dispatches through `ICapabilityInvoker`. |
| `IAgentMemory` | interface | Memory read/write from the agent's perspective — backed by Memory Node storage via `IMemoryScope`. |

All five surfaces are interfaces at stand-up. No records are introduced. The `AgentId` value type, any lifecycle-phase enums, and the invocation-request/response shapes are **deferred to the scaffold packet** — the stand-up contract is the five interfaces named above and the principle that any records added later apply the grid-wide naming rule (records drop the `I` prefix, interfaces retain it). Catalog entries use `kind: "interface"` for the five contracts in this ADR and `kind: "type"` for any records the scaffold packet introduces. No `kind: "record"` is used anywhere in the catalog schema.

This matches the deferral pattern ADR-0017 D6 used for tool-schema versioning (principle fixed at ADR, mechanism at scaffold) and keeps the stand-up decision tight on the surfaces downstream consumers compile against.

### D4. Boundary rule with AI, Capabilities, Operator, Memory, and Flow (definitive)

The surrounding Nodes need an explicit boundary test so that drift does not creep in once Agents ships. The rule below is the decision test Agents applies when an ambiguous concern is proposed.

**Decision test — for any concern in the agent-runtime path, ask:**

1. Does it compute an inference result against a model (chat, embedding, completion)? → **AI**.
2. Does it describe, register, or dispatch a callable tool? → **Capabilities**.
3. Does it gate whether an action is allowed, bound cost, raise approval, filter output, or trip a breaker? → **Operator**.
4. Does it persist, retrieve, or summarize agent memory? → **Memory**.
5. Does it coordinate multiple agents or sequence multiple agent calls across time? → **Flow**.
6. Does it manage agent identity, lifecycle, execution context, or the agent-facing projection of the above (how *this* agent calls inference, tools, memory, gates)? → **Agents**.

Under this test, several subtleties are worth naming explicitly:

- **`IToolInvoker` is Agents, `ICapabilityRegistry` is Capabilities.** The registry is the authoritative catalog of callable tools. The invoker is the agent-facing adapter that resolves a tool-call request emitted by the agent runtime, routes it through Capabilities, and applies the authorization gate. The registry has zero knowledge of agents; the invoker exists precisely because agents do.
- **`IAgentMemory` is Agents, `IMemoryScope` is Memory.** Memory owns the scope primitive (an Agents-authored memory is still a Memory-Node resource). `IAgentMemory` is the agent-facing adapter over a resolved memory scope. This is analogous to the `IToolInvoker` / `ICapabilityRegistry` split.
- **`IAgent` is owned by Agents, not AI.** An agent is not a chat client with a different name. Agent identity, capability declarations, and lifecycle are separate from the inference client. Consumers that want "call the model with a prompt and get a string back" use `IChatClient` directly; consumers that want "execute the named agent with a request and get the agent's full action trace" use `IAgent`.

`catalogs/relationships.json` currently lists Agents's `consumes` as `honeydrunk-kernel`, `honeydrunk-ai`, `honeydrunk-capabilities`. Memory and Operator are missing and are added as follow-up work (see the checklist at the top of this ADR). Memory is added because `IAgentMemory` composes against `IMemoryScope`/`IMemoryStore`. Operator is added because `IAgent` execution calls into `IApprovalGate` and `ICircuitBreaker` on the safety-critical path. Both edges are real at the default-implementation layer.

### D5. Tool invocation composes upstream — `IToolInvoker` does not re-implement the Capabilities registry

`IToolInvoker` is Agents's agent-facing adapter over the Capabilities registry and dispatcher. Its default implementation in `HoneyDrunk.Agents` takes a first-class runtime dependency on `HoneyDrunk.Capabilities.Abstractions` (`ICapabilityRegistry`, `ICapabilityInvoker`, `ICapabilityGuard`) and composes them into the per-invocation shape an agent expects: resolve the requested tool by `(name, version)`, run the authorization gate, dispatch the invocation, surface the result back into the agent's execution context. Agents does not invent its own registry, its own dispatcher, or its own authorization model.

The authorization path flows through Capabilities's `ICapabilityGuard`, which itself projects `HoneyDrunk.Auth` policy per ADR-0017 D5 and D10. Agents does not reach into Auth directly on the tool path; it reaches into Capabilities, and Capabilities reaches into Auth. This keeps the trust boundary in one place and matches the layering ADR-0017 fixed.

Downstream Nodes that compile against `HoneyDrunk.Agents.Abstractions` see `IToolInvoker` as a plain interface. They do not inherit a transitive compile-time dependency on `HoneyDrunk.Capabilities.Abstractions` from that reference alone — composition is resolved at the host. The same abstraction/runtime split already applied for AI, Capabilities, Vault, and Transport.

### D6. Memory access composes upstream — `IAgentMemory` does not own storage

`IAgentMemory` is Agents's agent-facing adapter over the Memory Node's scoped storage surface. Its default implementation in `HoneyDrunk.Agents` takes a first-class runtime dependency on `HoneyDrunk.Memory.Abstractions` (`IMemoryStore`, `IMemoryScope`) and projects them into the per-agent shape: resolve the agent's scope from its identity, read/write through that scope, delegate summarization to `IMemorySummarizer` when configured, emit telemetry on every access. Agents does not own storage, does not own scope resolution, and does not own summarization strategy.

The two upstream compositions (D5 tool invocation through Capabilities, D6 memory access through Memory) are the reason Agents is not marketable as a standalone Node — its default runtime only works when composed with its peers. The `Abstractions` package is consumable alone, because it is just interface declarations; the `HoneyDrunk.Agents` runtime package is not. This matches the first-class-runtime-dependency pattern ADR-0017 D10 applied for Capabilities → Auth and ADR-0019 D5 applied for Communications → Notify.

The `repos/HoneyDrunk.Agents/boundaries.md` file lists `IMemoryScope` under Agents-owned contracts. That is wrong and is fixed as follow-up work (see the checklist at the top of this ADR). The owner of `IMemoryScope` is the Memory Node.

### D7. Safety-gate composition with Operator — invoke, do not emit

`IAgent` execution calls into `IApprovalGate` and `ICircuitBreaker` on the safety-critical path before any action that requires human oversight or that could trip a cost/risk threshold. The default `IAgent` implementation in `HoneyDrunk.Agents` takes a first-class runtime dependency on `HoneyDrunk.Operator.Abstractions` for these gates. This is an **invocation edge**, not an event edge — Agents calls Operator synchronously on the hot path, which is the shape Operator is designed for per ADR-0018 D11.

ADR-0018 D8 established that when an `IApprovalGate` raises an `ApprovalRequest` needing human attention, Operator emits an approval-needed event that Communications consumes. That event-out edge is owned by Operator; Agents does not duplicate it. Agents simply awaits the approval decision from its `IApprovalGate` call and proceeds, times out, or is told to halt. Agents has no runtime dependency on Communications, and the approval-needed event never passes through Agents's surface.

This composition is what `repos/HoneyDrunk.Agents/integration-points.md` records as the Agents→Operator canary; the canary's scope is correct even while the Agents→AI canary description needs the fix noted in Context and in the follow-up checklist.

### D8. State boundary — Agents holds execution-scope state, not agent history

Agents holds **execution-scope state** for the duration of a single `IAgent` run: the current `IAgentExecutionContext`, the tool bindings, the open memory scope, the in-progress tool-call sequence, the lifecycle phase, the correlation id. All of this is scoped to the execution and disposed when `complete` or `decommission` runs.

Agents does **not** hold:

- **Persistent agent memory.** That is Memory's job — `IAgentMemory` writes through to `IMemoryStore` as part of the execution, and what is remembered across executions is defined by Memory's scope rules, not by Agents's runtime.
- **Multi-step workflow state.** That is Flow's job — when a single agent call is part of a larger workflow (welcome → wait 2 days → follow-up, or plan → execute → verify), the between-step state lives in Flow. Agents knows only the single call currently running.
- **Audit trail.** That is Operator's job — `IAuditLog` (ADR-0018 D9) is the immutable record of agent executions. Agents writes `AuditEntry` records through Operator during lifecycle transitions; Agents does not keep its own history.

The state rule is: if a piece of data must survive the end of the `IAgent` execution, it belongs in Memory, Flow, or Operator depending on what kind of data it is. Anything Agents holds is execution-local and ephemeral.

### D9. Telemetry emission — Pulse consumes, Agents does not depend

Agents emits telemetry for every lifecycle transition (register, initialize, execute, complete, decommission), every inference call (via AI's telemetry hook), every tool invocation (via Capabilities's telemetry hook), every gate outcome (via Operator's telemetry hook), and every memory access (via Memory's telemetry hook) via Kernel's `ITelemetryActivityFactory`. Pulse consumes that telemetry downstream. **Agents has no runtime dependency on Pulse.** The direction is one-way by contract: Agents emits, Pulse observes. Same rule as ADR-0016 D7 for AI, ADR-0017 D7 for Capabilities, ADR-0018 D7 for Operator, and ADR-0019 D7 for Communications.

Pulse signal ingress back into Agents — reactive tuning of agent parallelism, per-agent cost caps, or lifecycle timing based on observed telemetry — is out of scope for stand-up. It is flagged in Alternatives Considered as a deferred concern.

### D10. Contract-shape canary

A contract-shape canary is added to the Agents Node's CI: it fails the build if any of the following four interfaces change shape (method signatures, parameter shapes) without a corresponding version bump:

- `IAgent`
- `IAgentExecutionContext`
- `IToolInvoker`
- `IAgentMemory`

These four are the hot path for every downstream consumer. Accidental shape drift on any of them breaks every Node that consumes the Agents runtime (Flow, Sim, Lore, HoneyHub when live, the Actions cloud-agent trigger path). The canary makes this a compile-time failure at Agents's own CI, not a discovery at consumer sites.

`IAgentLifecycle` is not in the canary at stand-up. It is lower-traffic (lifecycle hooks are implemented by a smaller set of consumers than the hot-path contracts) and freezing its surface at stand-up would slow legitimate iteration in the first wave. It becomes a canary candidate once the first real consumer (the Actions cloud-agent trigger path per the Agents `integration-points.md`) is on it. This matches the pattern ADR-0016, ADR-0017, and ADR-0018 established of freezing the hot-path surfaces, not every exposed contract.

### D11. Agent registry is in-process at stand-up

The default `IAgentLifecycle` implementation maintains an in-process agent registry — a per-host dictionary keyed by agent identity. Registration happens during Node startup; resolution happens per invocation. The registry is not shared across processes or hosts at stand-up.

A cross-host shared agent registry (agents registered in one process and resolved from another, likely backed by HoneyDrunk.Data for persistence) is a future concern and is flagged in Alternatives Considered. The stand-up's job is to ship the contract surface and the in-process default so downstream Nodes can compile and run end-to-end in development. Production deployment of any distributed agent fleet will require a persistence story for the registry, which is a later ADR's problem.

### D12. Function-calling adapter lives in HoneyDrunk.Agents, not in AI or Capabilities

The loop that turns a model's structured function-call output into one or more `IToolInvoker` invocations, collects the results, and feeds them back into the next inference call is an **agent-runtime concern** and lives inside the `HoneyDrunk.Agents` runtime package. No other AI-sector Node may introduce an equivalent loop.

The rationale is boundary integrity. The function-calling loop composes three things: an `IChatClient` call (AI), a sequence of `IToolInvoker` calls (Agents → Capabilities), and the `IAgentExecutionContext` carrying state between them. AI owns inference mechanics and has no knowledge of agents or tools; putting the loop there would drag both concerns into the inference layer. Capabilities owns tool dispatch and has no knowledge of inference; putting the loop there would drag inference into the dispatch layer. The loop belongs in the Node that already composes all three — Agents — and this ADR pins it there so that no later Node (Flow, Sim, Lore, HoneyHub, the Actions cloud-agent trigger path, or any future AI-sector addition) is tempted to re-implement it.

The specific **mechanism** for adapting model-provider function-call payloads into `IToolInvoker` requests — whether via a generic adapter keyed by `ModelCapabilityDeclaration`, per-provider adapters slotted behind an `IFunctionCallAdapter` interface, or a shape-translation layer living alongside `IToolInvoker` — is **deferred to the scaffold packet**. The stand-up commits to the placement (Agents owns it) and the rule (no other Node implements an equivalent loop), not to the wire shape. This matches ADR-0017 D6's treatment of tool-schema versioning (principle at ADR, mechanism at scaffold) and ADR-0018 D8's treatment of approval-event transport.

No prior ADR pinned this placement. This ADR pins it now before the first real agent execution forces an ad-hoc decision at a consumer.

### D13. `Abstractions` package has no third-party AI-runtime dependencies; runtime may take them

`HoneyDrunk.Agents.Abstractions` declares only the five interfaces in D3 (plus any records introduced at scaffold) and depends on nothing beyond `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.AI.Abstractions`, `HoneyDrunk.Capabilities.Abstractions`, `HoneyDrunk.Operator.Abstractions`, and `HoneyDrunk.Memory.Abstractions` (the last is added once the `Abstractions` package reference graph is finalized; at stand-up time Memory is a planned edge, see the follow-up checklist). No third-party AI-runtime packages (for example `Microsoft.Extensions.AI`, any provider SDK, any agent-framework library) are compile-time dependencies of `Abstractions`. This preserves the zero-dependency posture already committed for the corresponding `Abstractions` packages in ADR-0016, ADR-0017, and ADR-0018, and already invariant-pinned for Agents by `repos/HoneyDrunk.Agents/invariants.md` item 1.

The `HoneyDrunk.Agents` runtime package is permitted to take third-party compile-time dependencies where the function-calling adapter (D12) or the default implementations genuinely benefit — for example, consuming `Microsoft.Extensions.AI` shape-compatible types (ADR-0016 D6) in the adapter layer, or pulling in a model-provider SDK's function-call payload types at the adapter seam. Whether the runtime package actually takes any such dependency at stand-up is a **scaffold-packet decision**, not a stand-up decision. This ADR pins the principle — `Abstractions` no third-party; runtime may — and defers the mechanism.

## Consequences

### Unblocks

Accepting this ADR — and landing the follow-up scaffold packet that produces a first `Abstractions` release — unblocks the Nodes currently waiting on Agents:

- **HoneyDrunk.Flow** — can compile against `IAgent` and `IAgentExecutionContext` for single-agent execution inside a workflow step, without inventing its own agent abstraction.
- **HoneyDrunk.Sim** — can compile against `IAgent` for scenario-driven agent runs against deterministic AI fixtures (via AI's `InMemory` provider from ADR-0016).
- **HoneyDrunk.Lore** — can compile against `IAgent` as the execution surface for lore-side agent-driven content generation.
- **HoneyDrunk.Actions (cloud-agent trigger path)** — can compile against `IAgentLifecycle` to drive agent initialization from CI/CD workflow triggers.
- **HoneyHub (when live)** — can assign tasks to agents through `IAgent` rather than reaching into provider SDKs.
- **HoneyDrunk.Evals** — can register deterministic test agents via `HoneyDrunk.Agents.Testing` and exercise agent paths end-to-end without real inference, tool dispatch, or memory writes.

### New invariants (proposed for `constitution/invariants.md`)

Numbering is tentative — scope agent finalizes at acceptance.

- **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Agents.Abstractions`.** Composition against `HoneyDrunk.Agents` and `HoneyDrunk.Agents.Testing` is a host-time (and test-time) concern. See D2, D5, D6.
- **Agents never call model providers directly.** All inference flows through `IChatClient` from `HoneyDrunk.AI.Abstractions`. This extends the same rule already recorded in `repos/HoneyDrunk.Agents/invariants.md` item 4.
- **Agents never call tool implementations directly.** All tool invocations flow through `IToolInvoker`, which composes against Capabilities's `ICapabilityRegistry` and `ICapabilityInvoker` and applies `ICapabilityGuard`. This extends `repos/HoneyDrunk.Agents/invariants.md` item 5 to the cross-Node boundary level.
- **Agents never write persistent agent state directly.** All memory access flows through `IAgentMemory`, which composes against Memory's `IMemoryStore` and `IMemoryScope`. See D6 and D8.
- **The function-calling loop (model tool-call output → `IToolInvoker` invocations → next inference call) lives in the `HoneyDrunk.Agents` runtime package and nowhere else.** No other AI-sector Node may introduce an equivalent loop. See D12.
- **`HoneyDrunk.Agents.Abstractions` takes no third-party AI-runtime compile-time dependencies.** See D13 and `repos/HoneyDrunk.Agents/invariants.md` item 1.
- **The Agents Node CI must include a contract-shape canary for `IAgent`, `IAgentExecutionContext`, `IToolInvoker`, and `IAgentMemory`.** Shape drift on any of the four is a build failure, not a downstream discovery. See D10.

### Contract-shape canary becomes a requirement

The contract-shape canary in D10 is a gating requirement on the Agents Node's CI from the first scaffold. It is not a later hardening pass — the four frozen interfaces are the hot path for every Node that runs an agent and must be protected from day one.

### Catalog obligations

`catalogs/contracts.json` carries the five-interface seed that this ADR confirms. No rename or deprecation is required on the contracts catalog side; the follow-up work is a verification and a flag that no records are introduced at stand-up. `catalogs/relationships.json` for `honeydrunk-agents` has Memory and Operator missing from `consumes` and Actions missing from `consumed_by_planned`; all three edges are real under this ADR and are reconciled as follow-up work. `catalogs/grid-health.json` needs its entry updated to reflect the stood-up contract surface and the contract-shape canary expectation. All reconciliations are tracked in the follow-up work section at the top of this ADR.

### Negative

- **Five interfaces plus one function-calling adapter is more public surface than a minimal "single `IAgent` entry point" design would ship.** The trade is clarity of responsibility and independent testability against modestly more contracts to version. Given the contract-shape canary on only the four highest-traffic interfaces, the extra surface costs little to maintain.
- **Shipping `HoneyDrunk.Agents.Testing` as an opt-in package adds a second first-wave release artifact.** Without it, downstream Nodes would invent their own in-memory doubles of five interfaces apiece and they would drift. The cost is accepted; the pattern already holds for Capabilities (ADR-0017 D2) and Operator (ADR-0018 D2).
- **Deferring record shapes (`AgentId`, lifecycle-phase enums, invocation-request shapes) to the scaffold packet means the first real consumer may surface a need to revisit the descriptor shape.** That is an acceptable cost for not over-committing at stand-up and matches the deferral pattern from ADR-0017 D6 and ADR-0018 D8.
- **Deferring the function-calling adapter mechanism to the scaffold packet (D12) means the first real function-calling flow may surface a need to revisit the wire format.** This is the same cost as the record-shape deferral and is accepted for the same reason.
- **The in-process agent registry (D11) is not suitable for production deployment of a distributed agent fleet.** That is accepted at stand-up; the production-readiness gate for a cross-host registry is a later ADR.
- **Pulse ingress back into Agents (reactive tuning) is deferred.** Operator-driven tuning via App Configuration and Operator's cost guards cover the stand-up need; automatic reactive tuning of agent parallelism or per-agent caps is a later concern.

## Alternatives Considered

### Fold agent runtime into HoneyDrunk.AI

Rejected. AI owns inference mechanics. Agents owns agent identity, lifecycle, and the execution context that composes inference with tools, memory, and safety gates. Folding agent runtime into AI would put three other sectors' concerns (Capabilities, Operator, Memory) into the inference Node and would collapse the "inference substrate" boundary ADR-0016 just established. Every consumer that wants raw `IChatClient` would drag agent runtime into their dependency graph even when they do not run agents. The four-Node foundation (AI, Capabilities, Operator, Agents) is correct.

### Fold the function-calling adapter into HoneyDrunk.Capabilities

Rejected. Capabilities owns tool registration and dispatch. The function-calling adapter composes a model call with a sequence of tool calls and a piece of agent-scope execution state (`IAgentExecutionContext`). Capabilities has no knowledge of inference and no reason to acquire it; putting the adapter there would drag AI and Agents dependencies into a Node whose charter is strictly registry-and-dispatch. See D12.

### Fold the function-calling adapter into HoneyDrunk.AI

Rejected. AI owns inference mechanics and has no knowledge of tools, agents, or execution context. Putting the adapter in AI would drag Capabilities and Agents dependencies into the inference substrate and collapse ADR-0016's zero-downstream-awareness posture for AI. See D12.

### Ship `IAgent` as a god-interface covering lifecycle, execution, tool invocation, and memory

Rejected. This is the same argument ADR-0017 made against the single-interface `ICapability` placeholder and ADR-0018 made against the single-interface `IGovernanceGate`. A god-interface conflates identity, lifecycle, tool invocation, and memory access. Every downstream consumer ends up reaching through `IAgent` for one specific concern and coupling to the others incidentally. Five separated interfaces make each concern independently mockable, independently versioned, and independently canary-able, and make the execution-context split from D8 enforceable at the type level rather than by convention.

### Defer the Agents stand-up until Flow or Sim needs it

Rejected. This is a mirror of the argument ADR-0016, ADR-0017, and ADR-0018 rejected for AI, Capabilities, and Operator. Letting Flow, Sim, Lore, HoneyHub, and the Actions cloud-agent trigger path each invent their own agent abstraction produces N incompatible surfaces with no shared lifecycle, no shared tool-invocation path, no shared memory projection, and no shared safety-gate composition. The AI sector's foundation is AI (inference) + Capabilities (tools) + Operator (policy) + Agents (runtime); standing up three of four and deferring the fourth leaves downstream Nodes (Flow, Sim, Lore, HoneyHub, Actions cloud-agent path) blocked on a substrate that nobody owns.

### Make `IMemoryScope` Agents-owned

Rejected. `IMemoryScope` is the Memory Node's scope primitive — the authorized-read-window abstraction that constrains what an agent can see inside Memory's storage. Agents consumes a resolved scope; Memory defines what a scope is and how it resolves. The existing wording in `repos/HoneyDrunk.Agents/boundaries.md` that lists `IMemoryScope` under Agents-owned contracts is a drift error, not a design decision, and is fixed as follow-up work per the checklist at the top of this ADR. If Agents owned `IMemoryScope`, Memory's whole scope model would fragment: two Nodes would compete for scope semantics and downstream consumers would have to reconcile them. Keeping scope ownership in Memory matches the pattern ADR-0017 D5 used for Capabilities → Auth and ADR-0018 D5 used for Operator → Auth.

### Cross-host shared agent registry backed by Data at stand-up

Deferred. Persisting the agent registry in HoneyDrunk.Data so that agents registered in one process are resolvable from another requires a persistence model, a cache invalidation story, a distributed-lock or last-writer-wins story on concurrent registrations, and a schema migration plan. None of that is stand-up work. The in-process registry in D11 is sufficient for the first wave of consumers (Flow, Sim, Evals in dev; HoneyHub and Actions cloud-agent path when they ship). When the first cross-host registration requirement lands, it gets its own ADR and a Data-backed registry implementation ships alongside.

### `Microsoft.Extensions.AI` types as compile-time dependencies of `HoneyDrunk.Agents.Abstractions` at stand-up

Deferred per D13 and ADR-0016 D6. `Abstractions` packages in the Grid do not take third-party AI-runtime compile-time dependencies. The runtime package (`HoneyDrunk.Agents`) is permitted to consume MEAI shape-compatible types at the function-calling adapter seam if the scaffold packet decides that is the right mechanism, but that is a scaffold-packet decision, not a stand-up decision. This keeps the `Abstractions` surface versionable on the Grid's own cadence and matches the same posture ADR-0016 D6 already set for AI.

### Pulse signal ingress into Agents at stand-up

Deferred. Reactive closed-loop tuning — where observed telemetry from Pulse automatically adjusts agent parallelism, per-agent cost caps, lifecycle timing, or registry-level throttles — is the same class of concern ADR-0018 flagged for Operator. It is not a stand-up decision. Flagging it here so it is not lost: when the observation pipeline is live, the Agents Node will need an ingress surface for observed signals. That surface is not specified here and is not blocked by this ADR; emit-only at stand-up is the committed direction and any future ingress contract will be added as a distinct ADR concern.
