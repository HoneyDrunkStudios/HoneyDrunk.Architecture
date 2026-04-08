# Grid Sectors

The HoneyDrunk Grid is organized into Sectors — narrative groupings that express the Grid's purpose and identity. Sectors are the same taxonomy used on the live website.

## Core

Foundational primitives for everything else — kernel abstractions, data conventions, and reliable transport that make the Grid feel like one codebase. Core defines the rules of the system so every other sector builds on solid ground.

**Color:** `#7B61FF` (violetFlux)

| Node | Signal | Responsibility |
|------|--------|---------------|
| **Kernel** | Live | Context propagation, lifecycle, configuration, identity primitives |
| **Transport** | Live | Transport-agnostic messaging, middleware pipeline, outbox |
| **Vault** | Live | Secrets and configuration with multi-provider support |
| **Auth** | Live | JWT validation, policy-based authorization, Vault-backed keys |
| **Web.Rest** | Live | Response envelopes, correlation, exception mapping |
| **Data** | Live | Repository pattern, unit of work, tenant-aware data, transactional outbox |

## Ops

From commit to production with confidence — pipelines, deployment orchestration, telemetry surfaces, and automation that keep shipping boring, safe, and repeatable.

**Color:** `#FF8C00` (cyberOrange)

| Node | Signal | Responsibility |
|------|--------|---------------|
| **Pulse** | Seed | Multi-backend telemetry pipeline, OTel integration, OTLP collector |
| **Notify** | Live | Channel-agnostic notification dispatch (email, SMS) |
| **Actions** | Live | Reusable GitHub Actions workflows for the Grid |

## Meta

The ecosystem's self-awareness — registries, documentation, and knowledge systems that let the Hive understand itself.

**Color:** `#FFFF00` (neonYellow)

| Node | Signal | Responsibility |
|------|--------|---------------|
| **Architecture** | Live | Grid command center — ADRs, routing, catalogs, agent workflows |
| **Studios** | Live | HoneyDrunk Studios public website |
| **Lore** | Seed | LLM-compiled living knowledge wiki — ingests, compiles, self-maintains, answers |

## HoneyNet

Proactive defense for the Hive — breach simulations, secure-by-default SDKs, and rapid recovery frameworks.

**Color:** `#00FF41` (matrixGreen)

*No real Nodes yet. Planned: BreachLab.exe, HoneySentinel.*

## Creator

Tools that turn imagination into momentum — from marketing automation to creative analytics.

**Color:** `#14B8A6` (chromeTeal)

*No real Nodes yet. Planned: HoneyDrunk.Signal, Forge.*

## Market

Applied innovation for the open world — public-facing apps that validate HoneyDrunk.OS in the wild.

**Color:** `#F5B700` (aurumGold)

*No real Nodes yet. Planned: Arcadia, DreamMarket, HiveXP, Tether.*

## HoneyPlay

Gaming, narrative, and media — worlds to explore, leagues to compete in, and creative sandboxes.

**Color:** `#FF2A6D` (neonPink)

*No real Nodes yet. Planned: Draft, Game Prototype.*

## Cyberware

Robotics, simulation, and hardware interfaces — where physical motion meets digital logic.

**Color:** `#00D1FF` (electricBlue)

*No real Nodes yet. Planned: HoneyMech.Courier, HoneyMech.Sim, HoneyMech.Servo.*

## AI

Agents and cognition primitives — lifecycles, memory, orchestration, and safety so autonomy is useful, auditable, and always under human direction.

**Color:** `#D946EF` (synthMagenta)

See [ai-sector-architecture.md](ai-sector-architecture.md) for the comprehensive architecture definition.

| Node | Signal | Responsibility |
|------|--------|---------------|
| **Agents** | Seed | Agent runtime, lifecycle, execution context, tool/memory interfaces |
| **AI** | Seed | Model/provider abstraction, normalized inference contracts |
| **Memory** | Seed | Agent memory — short-term, long-term, scoped storage and retrieval |
| **Knowledge** | Seed | External knowledge ingestion, embeddings, RAG pipelines |
| **Evals** | Seed | Prompt evaluation, regression testing, model comparison |
| **Capabilities** | Seed | Tool registry, discovery, permissioning, versioning |
| **Flow** | Seed | Workflow engine, multi-step pipelines, sagas, compensation |
| **Operator** | Seed | Human oversight — approvals, safety, circuit breakers, cost controls, audit |
| **Sim** | Seed | Simulation, plan evaluation, risk analysis |

## Dependency Flow (Real Nodes)

```
Kernel
├── Transport → Kernel.Abstractions
├── Vault → Kernel
├── Auth → Kernel, Vault
├── Web.Rest → Kernel.Abstractions, Transport, Auth
├── Data → Kernel, Transport
├── Notify → Kernel.Abstractions
└── Pulse → Kernel.Abstractions (optional)
```
