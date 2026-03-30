# AI Sector — Architecture

**Sector:** AI
**Color:** `#D946EF` (synthMagenta)
**Purpose:** Agents and cognition primitives — lifecycles, memory, orchestration, and safety so autonomy is useful, auditable, and always under human direction.

This document defines the **AI-enabled system layer** of HoneyDrunk.OS. It covers every planned Node in the AI sector, their responsibilities, boundaries, inter-node relationships, and integration with the rest of the Grid — particularly HoneyHub.

---

## Design Principles

These principles govern all AI sector Nodes. They mirror the patterns already established by Core sector Nodes (Kernel, Transport, Vault, Data).

### Contract-First Design

Every AI Node exposes an Abstractions package with zero runtime dependencies. Consumers depend on contracts, never implementations. This is the same pattern as `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.Transport`, and `HoneyDrunk.Vault`.

### Provider Abstraction

Model providers, memory backends, knowledge stores, and evaluation runners are pluggable via the Provider Slot pattern. The same pattern Vault uses for `ISecretProvider` (Azure, AWS, File, InMemory) applies to AI providers (OpenAI, Anthropic, Azure OpenAI, local).

### Separation of Concerns

Agent runtime, inference, memory, knowledge, evaluation, capabilities, orchestration, and human oversight are **separate Nodes**. Each has one job. The temptation to build a monolithic "AI framework" is explicitly rejected.

Why this matters:
- A model provider swap should not require touching agent lifecycle code
- Memory backend changes should not affect inference contracts
- Safety controls must be independently deployable and auditable

### Observability-First

Every AI Node integrates with Pulse. Inference calls emit traces with token counts, latency, and model identifiers. Agent executions produce structured spans. Memory operations are metered. This is not optional — it is required by Grid invariant.

### Human-in-the-Loop

No AI Node operates without a path to human oversight. The Operator Node provides the control surface. Circuit breakers, approval gates, cost limits, and audit trails exist at the system level, not as afterthoughts bolted onto individual agents.

---

## Node Definitions

### HoneyDrunk.Agents

**Node ID:** `honeydrunk-agents`
**Previously known as:** AgentKit (renamed to follow `HoneyDrunk.{Name}` convention)
**Role:** Agent runtime and lifecycle system

**Owns:**
- Agent lifecycle management (register → initialize → execute → complete → decommission)
- Execution context — scoped per agent invocation, carrying GridContext, agent identity, memory references, and capability bindings
- Tool interfaces — the contract for how agents invoke capabilities (not the capabilities themselves)
- Memory interfaces — `IAgentMemory`, `IMemoryScope` (contracts only, not storage implementations)
- Orchestration hooks — extension points for the Flow Node to coordinate multi-agent sequences
- Agent identity — `AgentId`, capability declarations, authorization scope

**Does NOT own:**
- Model provider integrations (that's HoneyDrunk.AI)
- Inference logic (that's HoneyDrunk.AI)
- Tool/capability definitions (that's HoneyDrunk.Capabilities)
- Memory storage (that's HoneyDrunk.Memory)
- Workflow sequencing (that's HoneyDrunk.Flow)
- Safety controls (that's HoneyDrunk.Operator)

**Key Contracts:**
- `IAgent` — core agent interface
- `IAgentExecutionContext` — extends Kernel's existing `IAgentExecutionContext`
- `IAgentLifecycle` — lifecycle hooks (parallels Kernel's `IStartupHook`/`IShutdownHook`)
- `IToolInvoker` — how agents call tools
- `IAgentMemory` — memory read/write from agent perspective

**Depends on:** Kernel (context, lifecycle, identity), AI (inference), Capabilities (tool registry)

**Packages:**
- `HoneyDrunk.Agents.Abstractions` — contracts only
- `HoneyDrunk.Agents` — runtime implementation

---

### HoneyDrunk.AI

**Node ID:** `honeydrunk-ai`
**Role:** Model and provider abstraction layer

**Owns:**
- Normalized inference contracts — chat completion, text completion, embeddings, structured output
- Provider adapters — OpenAI, Anthropic, Azure OpenAI, local models
- Request/response normalization — uniform types regardless of provider
- Token and latency telemetry — every inference call emits Pulse traces with model, tokens in/out, latency, cost estimate
- Model selection and routing — choosing the right model for a given request based on capability requirements

**Does NOT own:**
- Agent lifecycle (that's HoneyDrunk.Agents)
- Orchestration logic (that's HoneyDrunk.Flow)
- Prompt management or evaluation (that's HoneyDrunk.Evals)

**Key Contracts:**
- `IChatClient` — aligned with `Microsoft.Extensions.AI` when adopted
- `IEmbeddingGenerator` — aligned with `Microsoft.Extensions.AI`
- `IModelProvider` — provider slot interface
- `IInferenceResult` — normalized response with metadata (tokens, model, latency)

**Provider Slot Pattern:**
```
HoneyDrunk.AI.Abstractions          → contracts
HoneyDrunk.AI                       → runtime, routing, telemetry
HoneyDrunk.AI.Providers.OpenAI      → OpenAI adapter
HoneyDrunk.AI.Providers.Anthropic   → Anthropic adapter
HoneyDrunk.AI.Providers.AzureOpenAI → Azure OpenAI adapter
HoneyDrunk.AI.Providers.Local       → local/ONNX models
```

**Depends on:** Kernel (context, telemetry), Vault (API keys), Pulse (inference telemetry)

**Note:** The tech stack already plans adoption of `Microsoft.Extensions.AI` (`IChatClient`/`IEmbeddingGenerator`) for Q3 2026. HoneyDrunk.AI should align with these abstractions rather than invent competing ones. The provider adapters wrap `Microsoft.Extensions.AI` implementations with Grid context enrichment, Pulse telemetry, and Vault-backed credential resolution.

---

### HoneyDrunk.Memory

**Node ID:** `honeydrunk-memory`
**Role:** Persistent and contextual memory system for agents

**Owns:**
- Short-term memory — conversation-scoped, cleared after agent execution completes
- Long-term memory — persists across executions, scoped by tenant/project/agent
- Memory storage and retrieval — write, read, search, forget
- Indexing and summarization — compress and index memories for efficient retrieval
- Scoped memory isolation — `TenantId`/`ProjectId`/`AgentId` boundaries enforced at the storage level

**Does NOT own:**
- External knowledge ingestion (that's HoneyDrunk.Knowledge)
- Embedding generation (that's HoneyDrunk.AI)

**Key Contracts:**
- `IMemoryStore` — write/read/search/delete
- `IMemoryScope` — scoped memory access (agent sees only its authorized memories)
- `IMemorySummarizer` — compress memories beyond a threshold

**Storage Backends (Provider Slot):**
```
HoneyDrunk.Memory.Abstractions
HoneyDrunk.Memory
HoneyDrunk.Memory.Providers.SqlServer
HoneyDrunk.Memory.Providers.CosmosDB
HoneyDrunk.Memory.Providers.InMemory
```

**Depends on:** Kernel (context, scoping), Data (persistence patterns), AI (embeddings for similarity search)

**Boundary with Knowledge:** Memory is agent-generated context (what the agent learned, decided, experienced). Knowledge is externally sourced information (documents, APIs, structured data). They may share embedding infrastructure via HoneyDrunk.AI but are semantically distinct stores.

---

### HoneyDrunk.Knowledge

**Node ID:** `honeydrunk-knowledge`
**Role:** External knowledge ingestion and retrieval

**Owns:**
- Document ingestion — ingest files, web content, API responses, structured data
- Chunking and embedding — split documents into retrievable units, generate embeddings via HoneyDrunk.AI
- Retrieval pipelines (RAG) — given a query, find relevant knowledge chunks
- Source attribution — every retrieved chunk traces back to its source document and version
- Knowledge versioning — documents can be updated; retrieval reflects the current version

**Does NOT own:**
- Embedding generation (delegates to HoneyDrunk.AI)
- Agent memory (that's HoneyDrunk.Memory)

**Key Contracts:**
- `IKnowledgeStore` — ingest, query, delete sources
- `IDocumentIngester` — parse and chunk documents
- `IRetrievalPipeline` — query → ranked results with attribution
- `IKnowledgeSource` — metadata about an ingested source (origin, version, last updated)

**Storage Backends (Provider Slot):**
```
HoneyDrunk.Knowledge.Abstractions
HoneyDrunk.Knowledge
HoneyDrunk.Knowledge.Providers.AzureAISearch
HoneyDrunk.Knowledge.Providers.PostgresVector
HoneyDrunk.Knowledge.Providers.InMemory
```

**Depends on:** Kernel (context), AI (embeddings), Data (persistence patterns)

---

### HoneyDrunk.Evals

**Node ID:** `honeydrunk-evals`
**Role:** Evaluation and quality layer for AI behavior

**Owns:**
- Prompt evaluation — run a prompt against a model and score the output against expected criteria
- Regression testing — detect when model upgrades or prompt changes degrade output quality
- Model comparison — run the same evaluation set against multiple models/providers and compare
- Output quality scoring — structured rubrics (factuality, relevance, safety, format compliance)
- Evaluation datasets — versioned sets of inputs + expected outputs + scoring criteria

**Does NOT own:**
- Inference execution (delegates to HoneyDrunk.AI)
- Agent behavior rules (that's HoneyDrunk.Operator for safety, HoneyDrunk.Agents for runtime)

**Key Contracts:**
- `IEvaluator` — run an evaluation suite, return scored results
- `IEvalDataset` — collection of eval cases with expected outputs
- `IEvalScorer` — scoring function (automated or model-as-judge)
- `IEvalReport` — structured evaluation results

**Depends on:** AI (inference for running evaluations), Pulse (emitting evaluation metrics)

**Integration with Pulse:** Evaluation results are emitted as Pulse signals. HoneyHub can consume these to detect quality regressions tied to specific deployments or model changes, closing the feedback loop between model updates and product quality.

---

### HoneyDrunk.Capabilities

**Node ID:** `honeydrunk-capabilities`
**Role:** Tool and action registry for agents

**Owns:**
- Tool definitions and schemas — what tools exist, what parameters they accept, what they return
- Discovery and registration — agents query the registry to find available tools
- Permissioning — which agents are authorized to invoke which tools
- Versioning — tool schemas evolve; consumers bind to specific versions
- Execution dispatch — route a tool invocation to its implementing service

**Does NOT own:**
- Tool implementation (implementations live in the Node that owns the domain — e.g., a "query database" tool is implemented by Data, registered in Capabilities)
- Agent lifecycle (that's HoneyDrunk.Agents)

**Key Contracts:**
- `ICapabilityRegistry` — register, discover, resolve tools
- `ICapabilityDescriptor` — tool schema (name, parameters, return type, permissions)
- `ICapabilityInvoker` — execute a tool invocation
- `ICapabilityGuard` — permission check before invocation

**Depends on:** Kernel (context, identity for permission checks), Auth (authorization policies)

**Design note:** This follows the same pattern as Vault's provider slots but for agent tools. A tool is a capability descriptor (contract) + an implementation (provider). The registry is the discovery mechanism. Agents interact with tools through `IToolInvoker` (defined in Agents.Abstractions) which resolves tools through the Capabilities registry.

---

### HoneyDrunk.Flow

**Node ID:** `honeydrunk-flow`
**Previously known as:** Orchestrator
**Role:** Execution-level workflow engine

**Owns:**
- Multi-step workflow definitions — sequences, branches, parallel execution
- Long-running process management — workflows that span minutes, hours, or days
- Retry and compensation — when a step fails, retry with backoff or execute compensation logic
- Agent chaining — output of one agent feeds as input to the next
- State persistence — workflow state survives process restarts
- Checkpoint and resume — workflows can pause for human approval (via Operator) and resume

**Does NOT own:**
- Agent execution (delegates to HoneyDrunk.Agents)
- Inference (delegates to HoneyDrunk.AI)
- Planning decomposition (that's HoneyHub)

**Key Contracts:**
- `IWorkflow` — workflow definition (steps, transitions, compensation)
- `IWorkflowEngine` — execute, pause, resume, cancel workflows
- `IWorkflowStep` — single step in a workflow (may invoke an agent, tool, or external service)
- `IWorkflowState` — persistent state for a running workflow
- `ICompensation` — rollback logic for a failed step

**Depends on:** Kernel (context, lifecycle), Agents (agent execution), Data (state persistence), Transport (async step coordination)

**Boundary with HoneyHub:** HoneyHub plans work at the organizational level (Goals → Features → Tasks). Flow executes work at the runtime level (workflow steps, retries, compensation). HoneyHub decides *what* workflows to run. Flow runs them. HoneyHub operates on days/weeks timescales. Flow operates on seconds/minutes/hours.

---

### HoneyDrunk.Operator

**Node ID:** `honeydrunk-operator`
**Encompasses:** Governor (decision authority) + operational controls
**Role:** Human control plane for the Hive

**Owns:**
- Approval gates — workflows and agent actions that require human sign-off before proceeding
- Safety controls — content filtering, output validation, action scope limits
- Circuit breakers — kill switches for agent execution, inference calls, or entire workflows
- Cost controls — budget limits per agent, per workflow, per time window; halt when exceeded
- Incident intervention — emergency stop, manual override, forced workflow cancellation
- Audit trail — immutable log of every AI decision, tool invocation, and human override
- Decision authority — allow/deny/require-approval for agent actions based on policy

**Does NOT own:**
- Inference execution (that's HoneyDrunk.AI)
- Agent runtime (that's HoneyDrunk.Agents)
- Reasoning or planning logic (that's HoneyHub)

**Key Contracts:**
- `IApprovalGate` — request approval, check status, receive decision
- `ICircuitBreaker` — trip, reset, check state
- `ICostGuard` — check budget, record spend, enforce limits
- `IAuditLog` — append-only log of actions and decisions
- `IDecisionPolicy` — rules for auto-approve, auto-deny, or require-human
- `ISafetyFilter` — validate outputs before they leave the system

**Depends on:** Kernel (context, identity), Auth (authorization), Pulse (operational telemetry), Data (audit persistence)

**Design note:** Operator is the only Node with authority to halt other AI Nodes. It does not participate in reasoning — it observes and constrains. This separation is critical: the system that decides what to do must never be the system that decides whether it's allowed to do it.

---

### HoneyDrunk.Sim

**Node ID:** `honeydrunk-sim`
**Role:** Simulation and planning layer

**Owns:**
- Scenario modeling — define hypothetical scenarios and simulate outcomes
- Plan evaluation — given a proposed workflow or agent action, estimate the result before executing
- Risk analysis — identify failure modes, cost exposure, and safety concerns in a proposed plan
- Pre-execution validation — dry-run a workflow against simulated state before committing to real execution

**Does NOT own:**
- Real execution (that's Flow/Agents)
- Real inference (may use HoneyDrunk.AI for simulation inference, but does not produce production outputs)

**Key Contracts:**
- `ISimulator` — run a scenario, return projected outcomes
- `IScenario` — scenario definition (initial state, actions, constraints)
- `IRiskAssessment` — risk evaluation result (failure modes, probabilities, mitigations)
- `IPlanValidator` — validate a proposed plan before real execution

**Depends on:** AI (inference for simulation), Knowledge (context for scenarios), Agents (agent behavior models)

**Design note:** Sim is optional for initial AI sector delivery. It becomes critical when agents operate autonomously at scale — the ability to preview actions before committing is a safety multiplier. Early implementation can be simple (rule-based risk scoring). Mature implementation uses model-based simulation.

---

## HoneyHub Integration

HoneyHub is the **primary interface and orchestration surface** for the Hive. It exposes capabilities from multiple AI Nodes but does not own their domain logic.

### What HoneyHub Surfaces

| Surface | Source Node | What It Exposes |
|---------|------------|-----------------|
| Agent execution | HoneyDrunk.Agents | Trigger agents, observe execution, receive results |
| Inference | HoneyDrunk.AI | Model selection for planning tasks (internal use) |
| Decision authority | HoneyDrunk.Operator | Approval gates, cost status, safety alerts |
| Knowledge queries | HoneyDrunk.Knowledge | Retrieve context for planning and decomposition |

### What HoneyHub Does NOT Own

- **Agent runtime** — Agents owns lifecycle and execution
- **Inference logic** — AI owns provider abstraction and model routing
- **Operational authority** — Operator owns safety controls and circuit breakers
- **Memory systems** — Memory and Knowledge own their respective stores
- **Workflow execution** — Flow owns runtime orchestration
- **Evaluation** — Evals owns quality scoring and regression testing
- **Tool registry** — Capabilities owns tool definitions and permissions

### Integration Pattern

HoneyHub interacts with AI Nodes through their Abstractions contracts. It never depends on runtime packages directly. This mirrors how Web.Rest depends on `Kernel.Abstractions` and `Transport` contracts, not internal implementations.

```
HoneyHub
  ├── reads: Agents.Abstractions (agent registry, status)
  ├── reads: AI.Abstractions (model selection for internal planning)
  ├── reads: Operator.Abstractions (approval status, cost budget)
  ├── reads: Knowledge.Abstractions (context retrieval)
  ├── writes: Task assignments → GitHub Issues → Agents consume
  └── reads: Pulse signals → correlate to Goals
```

---

## System Flows

### Execution Flow

An agent receives a task and executes it through inference and tools.

```
HoneyHub (task assignment)
  → Agents (agent lifecycle, execution context)
    → AI (inference via provider)
      → Provider (OpenAI / Anthropic / Azure)
    → Capabilities (tool invocation)
      → Target Node (tool implementation)
    → Memory (read/write agent memory)
  → Operator (audit log entry)
  → Pulse (execution telemetry)
```

### Knowledge Flow

External knowledge is ingested, indexed, and made available to agents and HoneyHub.

```
Documents / APIs / Data
  → Knowledge (ingest, chunk, embed)
    → AI (generate embeddings)
    → Knowledge Store (persist indexed chunks)

Query time:
  Agent or HoneyHub
    → Knowledge (retrieval pipeline)
      → AI (embed query)
      → Knowledge Store (similarity search)
    → Ranked results with source attribution
```

### Memory Flow

Agents read and write scoped memory across executions.

```
Agent execution:
  Agent → Memory (read relevant memories for context)
  Agent → (performs work)
  Agent → Memory (write new memories from execution)

Memory maintenance:
  Memory → AI (summarize old memories)
  Memory → Memory Store (persist compressed memories)
```

### Control Flow

Human oversight constrains AI behavior at every level.

```
Human
  → Operator (set policies, budgets, safety rules)
    → Agents (agent-level constraints: which tools, which repos)
    → Flow (workflow-level constraints: approval gates, circuit breakers)
    → AI (model-level constraints: allowed models, token limits)
    → Capabilities (tool-level constraints: which tools agents can invoke)
```

### Decision Flow

HoneyHub's planning decisions pass through Operator for authorization.

```
HoneyHub (proposes action: deploy workflow, assign agent, execute plan)
  → Operator / Decision Policy
    → Auto-approve (policy allows, within budget, low risk)
    → Auto-deny (policy forbids, over budget, safety violation)
    → Require approval (policy uncertain, high cost, high risk)
      → Human reviews → approve / deny
  → Action proceeds or is blocked
```

### Evaluation Flow

Model and prompt changes are validated against quality baselines.

```
Model upgrade or prompt change
  → Evals (run regression suite against new model/prompt)
    → AI (inference on eval dataset)
    → Evals (score outputs against expected criteria)
  → Pulse (emit eval results as signals)
  → HoneyHub (correlate quality signal to Features/Goals)
  → Operator (alert if regression exceeds threshold)
```

---

## Boundary Definitions

### Why Separation Matters

The AI sector has nine Nodes. This might seem excessive compared to the six Core Nodes. But the same reasoning that separates Kernel, Transport, Data, and Vault applies here — with even more force, because AI systems have unique failure modes.

**Agent runtime vs inference must be separated** because:
- Model providers change frequently. A provider swap should be a config change, not an agent rewrite.
- Agent lifecycle and inference lifecycle are different. An agent may outlive many inference calls. Coupling them means agent stability depends on inference stability.
- Testing agents independently of models (with mock providers) requires the boundary.

**Inference vs control must be separated** because:
- The system that executes actions must not be the system that decides whether those actions are safe.
- Operator must be independently deployable. If safety controls are embedded in the agent runtime, you cannot update safety rules without redeploying agents.
- Audit requirements demand that the control plane has no dependency on the execution plane.

**Memory vs knowledge must be separated** because:
- Memory is agent-subjective (what this agent remembers). Knowledge is objective (what documents say).
- Access control differs. An agent's memory is private. Knowledge may be shared across agents.
- Storage, indexing, and lifecycle differ. Memories are summarized and eventually forgotten. Knowledge is versioned and persisted.

### Risks of Collapsing Layers

| Collapsed Layers | Risk |
|-----------------|------|
| Agents + AI | Model provider changes break agent code. Testing agents requires live models. |
| Agents + Operator | No independent safety controls. Agent bugs compromise safety. |
| Memory + Knowledge | Confused scoping. Agent-specific context leaks into shared knowledge. |
| Flow + Agents | Single-agent workflows work. Multi-agent or human-in-the-loop workflows require extracting Flow later. |
| Capabilities + Agents | Tool definitions coupled to agent runtime. Adding tools requires agent Node changes. |

### How This Mirrors Core Patterns

| Core Pattern | AI Equivalent |
|-------------|---------------|
| Kernel provides context → all Nodes consume | Kernel context flows through all AI Nodes via GridContext |
| Vault abstracts secret providers | AI abstracts model providers |
| Transport abstracts message brokers | Capabilities abstracts tool implementations |
| Data abstracts persistence providers | Memory + Knowledge abstract storage providers |
| Kernel defines `IStartupHook`/`IShutdownHook` | Agents defines `IAgentLifecycle` |
| Kernel enforces context propagation | Operator enforces safety policies |

---

## Dependency Graph

```
Kernel (foundation for everything)
  │
  ├── AI ← Vault (API keys)
  │    │
  │    ├── Agents ← Capabilities ← Auth (permissions)
  │    │    │
  │    │    ├── Memory ← Data (persistence)
  │    │    │
  │    │    ├── Knowledge ← Data (persistence)
  │    │    │
  │    │    └── Flow ← Transport (async coordination)
  │    │              ← Data (state persistence)
  │    │
  │    └── Evals
  │
  ├── Operator ← Auth (authorization)
  │             ← Data (audit persistence)
  │             ← Pulse (operational telemetry)
  │
  └── Sim ← AI, Knowledge, Agents
```

All AI Nodes depend on Kernel.Abstractions for GridContext. All emit telemetry to Pulse. No AI Node depends on HoneyHub directly — HoneyHub consumes AI Node contracts, not the other way around.

---

## Sector Summary

| Node | ID | Role | Depends On |
|------|----|------|-----------|
| HoneyDrunk.Agents | `honeydrunk-agents` | Agent runtime, lifecycle, execution context | Kernel, AI, Capabilities |
| HoneyDrunk.AI | `honeydrunk-ai` | Model/provider abstraction, inference contracts | Kernel, Vault, Pulse |
| HoneyDrunk.Memory | `honeydrunk-memory` | Agent memory storage and retrieval | Kernel, Data, AI |
| HoneyDrunk.Knowledge | `honeydrunk-knowledge` | External knowledge ingestion and RAG | Kernel, Data, AI |
| HoneyDrunk.Evals | `honeydrunk-evals` | Evaluation, regression testing, model comparison | AI, Pulse |
| HoneyDrunk.Capabilities | `honeydrunk-capabilities` | Tool registry, discovery, permissions | Kernel, Auth |
| HoneyDrunk.Flow | `honeydrunk-flow` | Workflow engine, sagas, compensation | Kernel, Agents, Data, Transport |
| HoneyDrunk.Operator | `honeydrunk-operator` | Human oversight, safety, audit, cost control | Kernel, Auth, Data, Pulse |
| HoneyDrunk.Sim | `honeydrunk-sim` | Simulation, plan evaluation, risk analysis | AI, Knowledge, Agents |
