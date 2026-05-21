# Sector Interaction Map

How the Grid's sectors communicate, depend on, and constrain each other. Use this for blast-radius reasoning before starting cross-repo work. The catalog DAG (`catalogs/relationships.json`) is authoritative for node-level dependencies; this document explains the *sector-level* picture.

---

## Sector Overview

```
┌─────────────────────────────────────────────────────────┐
│                        META                             │
│   Architecture (HQ) · Studios (Website) · Lore (Wiki)  │
│         Reads all sectors. Writes to none.              │
└───────────────────────┬─────────────────────────────────┘
                        │ governs / routes
          ┌─────────────┼─────────────────┐
          ▼             ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌───────────────────────┐
│     CORE     │  │      OPS       │  │          AI           │
│              │  │                │  │                       │
│ Kernel       │  │ Pulse          │  │ Agents · AI · Memory  │
│ Transport    │  │ Observe        │  │ Knowledge · Evals     │
│ Vault        │  │ Comms → Notify │  │ Capabilities · Flow   │
│ Auth         │  │ Actions        │  │ Operator · Sim        │
│ Web.Rest     │  │                │  │                       │
│ Data         │  │                │  │                       │
└──────┬───────┘  └──────┬───────┘  └────────────┬──────────┘
       │                 │                        │
       │  provides       │  observes              │  governs
       │  primitives     │  Core runtime          │  itself via
       └──────────┬──────┘  events                │  Operator
                  │                               │
                  ▼                               │
         ┌────────────────┐                       │
         │   HoneyHub     │◄──────────────────────┘
         │  (Proposed)    │
         │ Control Plane  │
         └────────────────┘
```

---

## Core Sector — The Foundation

**Direction:** Everything depends on Core. Core depends on nothing inside the Grid.

Core Nodes provide contracts that all other sectors consume:

| Core Node | What other sectors consume |
|-----------|---------------------------|
| **Kernel** | `IGridContext`, `INodeContext`, `IOperationContext`, `IStartupHook`, `IHealthContributor`, `IAgentExecutionContext` — consumed by every live Node and all AI sector Nodes |
| **Transport** | `ITransportPublisher`, `ITransportConsumer`, `IMessageHandler` — consumed by Web.Rest, Data, and planned by Flow |
| **Vault** | `ISecretStore`, `IConfigProvider` — consumed by Auth; planned by AI (model API keys), Operator (cost controls) |
| **Auth** | `IAuthenticatedIdentityAccessor`, `IAuthorizationPolicy` — consumed by Web.Rest; planned by Capabilities, Operator |
| **Data** | `IRepository`, `IUnitOfWork`, `IOutboxStore` — planned by Memory, Knowledge, Flow, Operator |

**Blast radius rule:** Any breaking change in Kernel cascades to every other sector. Treat Kernel changes as Grid-wide events, not single-repo changes. Always run canary tests across all dependents before publishing.

---

## Ops Sector — The Nervous System

**Direction:** Ops depends on Core. Ops is consumed by everything else as a telemetry sink and notification channel, but Ops never calls back into its consumers.

```
Core ──────► Ops
             │
             ├─ Pulse: receives telemetry FROM all sectors
             ├─ Observe: intakes events FROM external systems into the Grid
             ├─ Communications: decides why/when/who for outbound messages
             │    └─► Notify: sends notifications TO external channels (email, SMS)
             └─ Actions: provides CI/CD workflows TO all repos
```

**Communications ↔ Notify split:** Communications is the decision and orchestration layer — it owns message intent, recipient resolution, preferences, suppression, cadence, and multi-step flows. Notify is the delivery engine — it owns rendering, provider adapters, retries, queueing, and delivery tracking. If the concern is delivery mechanics, it belongs in Notify. If the concern is message logic or workflow, it belongs in Communications.

**Pulse ↔ Observe split:** Pulse is outbound telemetry from the Grid to external sinks. Observe is inbound observation from external systems into the Grid. They sit in the same sector because both are runtime signal pipelines, but their directions and ownership boundaries are opposite.

**Key cross-sector rule:** The Ops ↔ AI boundary is precise:
- **Pulse owns the data pipeline.** It collects, routes, and stores telemetry. It does not reason about what the data means.
- **AI sector (specifically Operator) owns the meaning layer.** Operator reads Pulse data to make safety and oversight decisions. It never writes to Pulse.

**Blast radius rule:** Pulse changes affect every Node that emits telemetry (all of them). Actions changes affect every repo's CI pipeline. Communications changes affect all message workflows but not delivery mechanics. Scope these carefully and validate with nightly CI runs before rolling out.

---

## AI Sector — The Cognition Layer

**Direction:** AI sector depends heavily on Core. AI sector Nodes depend on each other in a specific graph.

```
Kernel ──────────────────────────────► Agents, AI, Memory, Knowledge,
                                        Evals, Capabilities, Flow, Operator, Sim
Vault ────────────────────────────────► AI (model API keys), Operator (cost controls)
Auth ─────────────────────────────────► Capabilities (tool permissioning), Operator
Data ─────────────────────────────────► Memory, Knowledge, Flow, Operator
Pulse ────────────────────────────────► AI (inference telemetry), Evals, Operator

AI (inference) ───────────────────────► Agents (model calls), Memory (embeddings),
                                         Knowledge (embeddings), Evals (model scoring)
Capabilities (tool registry) ─────────► Agents (IToolInvoker resolution)
Memory (storage) ─────────────────────► Agents (IAgentMemory), Knowledge (shared infra)
Flow (orchestration) ─────────────────► Agents (multi-step coordination)
Operator (oversight) ─────────────────► Agents, Flow (approval gates, circuit breakers)
```

**AI sector internal rule:** No AI Node calls another AI Node's implementation directly — only through contracts. The same contract-first pattern as Core applies here.

**Blast radius rule:** AI sector is currently all Seed phase — nothing is deployed. When the first AI Nodes launch, treat each new inter-AI dependency as a canary surface that needs explicit integration tests.

---

## Meta Sector — Self-Awareness

**Direction:** Meta depends on Core for tooling but does not have runtime dependencies. Architecture and Lore are read-only from all other sectors' perspective.

```
Architecture (this repo)
  ├─ Reads all sectors' catalogs, ADRs, repo context
  ├─ Provides routing, governance, and agent definitions
  └─ Does NOT receive signals from production at runtime

Lore (planned)
  ├─ Ingests from Architecture, ADRs, GitHub state
  ├─ Compiles living wiki for agents and developer
  └─ Read-only output (no writes back to source repos)

Studios
  ├─ Public website — reads release notes and site-sync packets
  └─ No runtime Grid dependencies
```

---

## HoneyHub — The Orchestration Brain (Proposed)

**Direction:** HoneyHub reads from Core, Ops, and AI sectors. It writes *task assignments* back to GitHub Issues (which then trigger Ops/CI workflows). It is not yet deployed.

When live, HoneyHub closes the loop:

```
Core runtime events (via Pulse/Ops)
  │
  ▼
HoneyHub Knowledge Graph
  │
  ├─ Interprets signals against Goals
  ├─ Adjusts plans
  └─ Issues task assignments (GitHub Issues → Codex)
       │
       ▼
     Target repo execution (Core, AI, Ops)
```

Until HoneyHub is live, the Architecture repo (Meta) serves as the manual planning surface. See ADR-0003.

---

## Cross-Sector Change Classification

| Change type | Sectors touched | Tier | Start point |
|-------------|----------------|------|-------------|
| Kernel contract change | All | 3 | Architecture repo (ADR required) |
| Transport provider change | Core, Ops, AI | 2 | Architecture repo |
| Vault/secrets strategy change | Core, AI, Ops | 3 | Architecture repo (ADR required) |
| New AI Node bring-up | AI (+ Core deps) | 2–3 | Architecture repo |
| Notify/Pulse deployment | Ops | 2 | Target repo |
| New observation connector | Ops (+ Vault dep) | 2 | Target repo (HoneyDrunk.Observe) |
| GitHub Actions workflow change | All (CI) | 2 | HoneyDrunk.Actions |
| Site-sync / docs update | Meta | 1 | Architecture repo |
| HoneyHub integration | Meta, All | 3 | Architecture repo (ADR required) |
