# ADR-0017: Stand Up the HoneyDrunk.Capabilities Node — Tool Registry and Dispatch Substrate for the AI Sector

**Status:** Proposed
**Date:** 2026-04-19
**Deciders:** HoneyDrunk Studios
**Sector:** AI

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Reconcile `catalogs/contracts.json`: deprecate the existing `ICapability` and `ICapabilityPermission` entries for `honeydrunk-capabilities` and add entries for the four separated contracts — `ICapabilityRegistry`, `CapabilityDescriptor`, `ICapabilityInvoker`, `ICapabilityGuard`
- [ ] Update `catalogs/grid-health.json` Capabilities entry to reflect the stood-up contract surface and scaffold expectations
- [ ] Wire the contract-shape canary into Actions for the four frozen contracts (`ICapabilityRegistry`, `CapabilityDescriptor`, `ICapabilityInvoker`, `ICapabilityGuard`)
- [ ] Add `integration-points.md` to `repos/HoneyDrunk.Capabilities/`, matching the template used by `repos/HoneyDrunk.Agents/`
- [ ] File the HoneyDrunk.Capabilities scaffold packet (solution structure, HoneyDrunk.Standards wiring, CI pipeline, `HoneyDrunk.Capabilities.Testing` InMemory fixture, default registry and dispatcher implementation)
- [ ] Scope agent assigns final invariant numbers when flipping Status → Accepted

## Context

`HoneyDrunk.Capabilities` is cataloged in `catalogs/nodes.json` as the AI sector's tool registry and dispatch layer, but the repo is cataloged but not yet created — no packages, no contracts, no dispatcher, no CI. Agents, Operator, Memory, Knowledge, and Evals all need a way to register, discover, and invoke agent-callable tools, and none of them own that responsibility. Without a dedicated substrate, each Node ends up inventing its own ad-hoc tool registry and the agent surface fragments.

ADR-0016 just stood up HoneyDrunk.AI as the inference substrate. Capabilities is the parallel stand-up on the *action* side — AI is "how a thought is executed against a model," Capabilities is "how an agent decides what tool to call and gets that call dispatched and authorized." The two Nodes together form the base of the AI sector. ADR-0016's pattern for stand-up is reused here deliberately: contracts live in an `Abstractions` package, runtime composition is a separate package, downstream Nodes compile against `Abstractions` only.

The current `catalogs/contracts.json` entry for `honeydrunk-capabilities` lists three interfaces (`ICapabilityRegistry`, `ICapability`, `ICapabilityPermission`) that were placeholders seeded with the Node entry. They conflate four separable concerns — identity and schema, registry lookup, dispatch, and authorization — behind a single interface. Before the Node scaffolds, the contract shape needs to be decided, because downstream consumers (starting with Agents) will compile against whatever ships first and lock it in.

There is also a naming collision to defuse before it spreads. The superseded ADR-0004 used `capabilities:` as YAML frontmatter on agent definition files to describe the tool primitives an agent needs (read_files, search_code, etc.). That usage is an authoring-time mapping concept and has nothing to do with the runtime tool-registry primitives this Node owns. This ADR names the runtime primitives explicitly and does not borrow the frontmatter word.

This ADR is the **stand-up decision** for the Capabilities Node — what it owns, what it does not own, which contracts it exposes, and how downstream Nodes couple to it. It is not a scaffolding packet. Filing the repo, adding CI, wiring the InMemory fixture, and producing the first shippable packages all follow as separate issue packets once this ADR is accepted.

## Decision

### D1. HoneyDrunk.Capabilities is the AI sector's tool-registry and dispatch substrate

`HoneyDrunk.Capabilities` is the single Node in the AI sector that owns **tool-registry primitives** — the contracts and runtime machinery that let agents discover available tools, describe their schemas, dispatch invocations, and gate execution on authorization. It is a shared substrate, not an orchestrator. It does not decide *which* tool an agent should use; it owns the mechanics of *how a tool becomes callable* and *how a call is routed and authorized*.

Tool *implementations* live in the Node that owns the domain (a "query database" tool is implemented by Data, a "send email" tool is implemented by Notify). Capabilities owns registration, discovery, descriptor schema, invocation dispatch, and the authorization gate.

### D2. Package families

The Capabilities Node ships the following package families, mirroring ADR-0016's package-family pattern for AI:

- `HoneyDrunk.Capabilities.Abstractions` — all interfaces, the `CapabilityDescriptor` record, and the invocation request/response shapes. Zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions.
- `HoneyDrunk.Capabilities` — runtime composition: default `ICapabilityRegistry`, default `ICapabilityInvoker`, DI wiring.
- `HoneyDrunk.Capabilities.Testing` — opt-in testing fixture package carrying an in-memory registry and dispatcher implementation for deterministic unit and integration tests. Consumed by downstream Nodes in test projects, never in production composition.

The `Testing` package is a separate NuGet artifact rather than a `Providers.*` slot because there is no family of providers at the registry layer (no OpenAI-vs-Anthropic axis on the tool-registry side). The in-memory implementation is a testing fixture, not a production backend.

### D3. Exposed contracts

Four contracts form the Capabilities Node's public boundary. These are the surfaces downstream Nodes are allowed to compile against:

| Contract | Kind | Purpose |
|---|---|---|
| `ICapabilityRegistry` | interface | Register, discover, and resolve tool descriptors by `(name, version)`. |
| `CapabilityDescriptor` | record | Machine-readable tool metadata — name, version, parameter schema, return schema, owning Node, permission requirements. Value type, no `I` prefix. |
| `ICapabilityInvoker` | interface | Dispatch a resolved capability invocation to its implementing Node and return the result. |
| `ICapabilityGuard` | interface | Authorization gate — checked by the invoker before dispatch; resolves against Auth policy. |

The existing `ICapability` and `ICapabilityPermission` entries in `catalogs/contracts.json` are superseded by this split and must be removed as part of the follow-up work. The conflation was a placeholder; the four separated surfaces each have a distinct job and a distinct consumer.

`CapabilityDescriptor` drops the `I` prefix deliberately: it is a record (value type) carrying tool metadata, not an interface. This matches the precedent set by `ModelCapabilityDeclaration` in ADR-0016. Both ADRs apply the grid-wide rule: records drop the `I` prefix; interfaces retain it.

### D4. Naming collision disambiguation

Two names in the Grid collide with this Node's scope and need explicit disambiguation so neither drift occurs in later docs:

- **`capabilities:` as ADR-0004 frontmatter** was an authoring-time mapping label for agent definition files (read_files, search_code, etc.). ADR-0004 is superseded and its frontmatter is an agent-definition concern, not a runtime tool-registry concern. The HoneyDrunk.Capabilities Node owns runtime tool-registry primitives. There is no shared concept between them beyond the English word.
- **HoneyDrunk.Actions** is the Ops-sector Node for CI/CD workflows (see ADR-0012). It has nothing to do with agent "tool actions." The word "action" in this ADR always refers to agent tool invocations, never CI workflows. When referring to the Ops Node it is always written as `HoneyDrunk.Actions`.

### D5. Authorization routes through Auth, not through a new Capabilities-to-Auth edge

`ICapabilityGuard` resolves authorization decisions by consulting Auth policy via the already-established `HoneyDrunk.Auth` contracts. No new edge is added to `catalogs/relationships.json`; the Capabilities → Auth dependency already exists. The guard interface is the *local* surface a downstream Node compiles against; its default implementation delegates to Auth.

This keeps the trust boundary in one place. Capabilities does not invent its own permission model, it projects Auth's policy into a tool-scoped form.

### D6. Tool-schema versioning — principle fixed, mechanism deferred

Every registered tool descriptor carries an explicit `version` field. The public registry key is the pair `(name, version)` — a tool with an incompatible schema change ships under a new version and existing consumers continue to resolve the prior version until they opt in.

The specific versioning *model* — whether versions are name-suffixed strings, strict semver on the package, or a hybrid — is **deferred to the scaffold packet**. The stand-up contract is: versioning is required, descriptors declare it, and registry lookup is version-aware. How the version string is formatted is an implementation detail the scaffold packet will settle.

### D7. Telemetry emission — Pulse consumes, Capabilities does not depend

Capabilities emits telemetry for every registration, resolution, and invocation via Kernel's `ITelemetryActivityFactory`. Pulse consumes that telemetry downstream. **Capabilities has no runtime dependency on Pulse.** The direction is one-way by contract: Capabilities emits, Pulse observes. Same rule as ADR-0016 D7 for AI.

### D8. Contract-shape canary

A contract-shape canary is added to the Capabilities Node's CI: it fails the build if any of the four frozen contracts change shape (method signatures, parameter shapes, record members) without a corresponding version bump:

- `ICapabilityRegistry`
- `CapabilityDescriptor`
- `ICapabilityInvoker`
- `ICapabilityGuard`

These four are the hot path for every downstream consumer. Accidental shape drift on any of them breaks every AI-sector Node that registers or invokes tools. The canary makes this a compile-time failure at Capabilities's own CI, not a discovery at consumer sites. This matches ADR-0016 D8's rationale for the AI Node's four frozen contracts.

### D9. Downstream coupling rule

Downstream AI-sector Nodes (Agents, Operator, Memory, Knowledge, Evals) and domain Nodes that *expose* tools (Data, Notify, Vault, etc.) compile **only** against `HoneyDrunk.Capabilities.Abstractions`. They do not take a runtime dependency on `HoneyDrunk.Capabilities` or on `HoneyDrunk.Capabilities.Testing` in production composition. Composition — which registry implementation is active, which guard is wired — is a host-time concern, resolved at application startup.

Test projects may reference `HoneyDrunk.Capabilities.Testing` to pick up the in-memory fixture. Production projects must not.

This is the same abstraction/runtime split already applied for AI, Vault, and Transport. It is re-stated here because it is the specific rule that allows dependent Nodes to proceed on `Abstractions` alone without waiting for the full runtime.

### D10. Dependency on Auth is first-class

Capabilities takes a first-class runtime dependency on HoneyDrunk.Auth for authorization resolution. This is not an optional coupling — the default `ICapabilityGuard` implementation cannot produce an allow/deny decision without Auth. `catalogs/relationships.json` already reflects this edge and no change is required there.

Downstream Nodes are not transitively required to reference Auth to *use* Capabilities — they reference `HoneyDrunk.Capabilities.Abstractions` only. The Auth dependency is composed in at the host, not at the consumer.

## Consequences

### Unblocks

Accepting this ADR — and landing the follow-up scaffold packet that produces a first `Abstractions` release — unblocks every Node currently waiting on Capabilities:

- **HoneyDrunk.Agents** — can resolve and invoke tools through `ICapabilityRegistry` and `ICapabilityInvoker` rather than hardcoding tool bindings.
- **HoneyDrunk.Operator** — can gate agent tool calls through `ICapabilityGuard` and layer approval/circuit-breaker policies on top of the guard's decision.
- **HoneyDrunk.Memory / HoneyDrunk.Knowledge** — can register their query surfaces as tools instead of publishing Node-specific APIs for agents.
- **Domain Nodes that expose tools (Data, Notify, Vault)** — have a registration target for agent-callable operations and a schema to version them against.
- **HoneyDrunk.Evals** — can register deterministic test tools via `HoneyDrunk.Capabilities.Testing` and exercise agent paths without real side effects.

### New invariants (proposed for `constitution/invariants.md`)

Numbering is tentative — scope agent finalizes at acceptance.

- **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Capabilities.Abstractions`.** Composition against `HoneyDrunk.Capabilities` and `HoneyDrunk.Capabilities.Testing` is a host-time (and test-time) concern. See ADR-0017 D9.
- **Every registered capability descriptor carries an explicit version; the registry key is `(name, version)`.** Unversioned registration is a build failure. See ADR-0017 D6.
- **Authorization for capability invocation is resolved through `HoneyDrunk.Auth` policy via `ICapabilityGuard`.** Capabilities does not maintain an independent permission model. See ADR-0017 D5 and D10.
- **The Capabilities Node CI must include a contract-shape canary for `ICapabilityRegistry`, `CapabilityDescriptor`, `ICapabilityInvoker`, and `ICapabilityGuard`.** Shape drift on any of the four is a build failure, not a downstream discovery. See ADR-0017 D8.

### Contract-shape canary becomes a requirement

The contract-shape canary in D8 is a gating requirement on the Capabilities Node's CI from the first scaffold. It is not a later hardening pass — the four frozen contracts are the hot path for every agent tool invocation and must be protected from day one.

### Catalog obligations

`catalogs/contracts.json` currently carries seeded entries (`ICapability`, `ICapabilityPermission`) that this ADR supersedes. Accepting the ADR without reconciling those entries leaves the catalog in a stale state. The reconciliation is tracked in the follow-up work section.

### Negative

- The four-contract split is more surface area than the single-interface placeholder that was previously cataloged. The trade is clarity of responsibility and independent testability against modestly more contracts to version. Given the contract-shape canary, extra surfaces cost little to maintain.
- Shipping `HoneyDrunk.Capabilities.Testing` as an opt-in package adds a second first-wave release artifact. Without it, downstream Nodes would invent their own in-memory doubles and they would drift. The cost is accepted.
- Deferring the specific tool-schema versioning *mechanism* to the scaffold packet means the first real tool registration may surface a need to revisit the descriptor shape. That is an acceptable cost for not over-committing at stand-up.

## Alternatives Considered

### Keep the single-interface `ICapability` placeholder

Rejected. A single interface conflates identity, schema, dispatch, and authorization. Every downstream consumer ends up reaching through `ICapability` for one specific concern and coupling to the others incidentally. Splitting the four surfaces at stand-up makes each independently mockable, independently versioned, and makes the authorization gate a first-class surface rather than a side effect of invocation.

### Give Capabilities its own permission model instead of routing to Auth

Rejected. A second permission model in the Grid is a second trust boundary, and the two models drift. Auth already owns authorization. `ICapabilityGuard` is a projection, not a replacement. ADR-0017 D5 and D10 make this explicit.

### Put tool registration in HoneyDrunk.Agents directly

Rejected. Agents owns agent runtime and lifecycle. Folding the tool registry into Agents couples tool surface to agent surface, pushes authorization logic into the agent runtime, and prevents non-agent consumers (Evals scripts, Operator audits) from using the registry without standing up a full agent context. A separate Node per `catalogs/nodes.json` is correct.

### Skip the `HoneyDrunk.Capabilities.Testing` fixture and let each consumer write its own

Rejected. This is how drift starts. If Agents, Operator, and Evals each roll their own in-memory registry, they will diverge in subtle ways (how version resolution handles misses, whether guards short-circuit, how invocation errors surface) and those divergences leak into test-only behaviour that masks real bugs. Shipping one fixture in the stand-up release makes the expected semantics concrete.

### Defer the Capabilities stand-up and let Agents define its own tool-invocation abstractions

Rejected. This is a mirror of the argument ADR-0016 rejected for AI. Letting Agents invent tool registration internally produces a surface that is hard to retrofit into a shared Node later, and it freezes out the other consumers (Operator, Evals, domain Nodes registering their own tools). The AI sector needs both inference (AI) and action (Capabilities) substrates before its member Nodes can proceed.
