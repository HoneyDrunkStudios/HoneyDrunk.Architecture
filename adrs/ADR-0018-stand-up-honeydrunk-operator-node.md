# ADR-0018: Stand Up the HoneyDrunk.Operator Node — Human-Policy Enforcement and Audit Substrate for the AI Sector

**Status:** Proposed
**Date:** 2026-04-19
**Deciders:** HoneyDrunk Studios
**Sector:** AI

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Reconcile `catalogs/contracts.json` for `honeydrunk-operator`: rename `ICostController` to `ICostGuard`, add `IDecisionPolicy` and `ISafetyFilter`, and add record entries for `CostEvent`, `AuditEntry`, `ApprovalRequest`, and `ApprovalDecision` (all four records entered with `kind: "type"` to match the grid schema)
- [ ] Update `catalogs/relationships.json` `consumed_by_planned` for `honeydrunk-operator` to include Agents, Flow, AI, Capabilities, and Evals, each with a `consumes_detail` entry listing the specific contract surfaces that edge exercises
- [ ] Update `catalogs/grid-health.json` `honeydrunk-operator` entry to reflect the stood-up contract surface and the contract-shape canary expectation
- [ ] Tighten prose drift in any repo or constitution doc still referencing `ICostController` so it reads `ICostGuard`
- [ ] Wire the contract-shape canary into Actions for the four frozen interfaces (`IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, `ISafetyFilter`)
- [ ] Add `integration-points.md` and `active-work.md` to `repos/HoneyDrunk.Operator/`, matching the templates used by `repos/HoneyDrunk.Agents/`
- [ ] File the HoneyDrunk.Operator scaffold packet (solution structure, `HoneyDrunk.Standards` wiring, CI pipeline, `HoneyDrunk.Operator.Testing` InMemory fixture, initial policy/breaker/gate implementations)
- [ ] Scope agent assigns final invariant numbers when flipping Status → Accepted

## Context

`HoneyDrunk.Operator` is cataloged in `catalogs/nodes.json` as the AI sector's human-policy enforcement and audit substrate, but the repo is cataloged-not-yet-created — no packages, no contracts, no gates, no breakers, no audit log, no CI. Agents, Flow, AI, Capabilities, and Evals each have at least one code path that should be policy-gated, cost-bounded, or audit-recorded, and none of them own that responsibility. Without a dedicated substrate, each Node ends up inventing its own ad-hoc approval flow, cost check, or audit log and the safety surface fragments.

ADR-0016 stood up HoneyDrunk.AI as the AI sector's inference substrate. ADR-0017 stood up HoneyDrunk.Capabilities as the tool-registry and dispatch substrate. Operator is the third leg of the AI-sector foundation — AI is "how a thought is executed against a model," Capabilities is "how an agent decides what tool to call and gets that call dispatched," Operator is "whether any of that is allowed, what it costs, and what gets recorded." The three Nodes together form the base of the AI sector and the pattern is deliberately reused: contracts live in an `Abstractions` package, runtime composition is a separate package, downstream Nodes compile against `Abstractions` only, and a separate `Testing` fixture package ships at stand-up so consumers get one shared in-memory implementation instead of N divergent doubles.

The existing `catalogs/contracts.json` entry for `honeydrunk-operator` lists four interfaces (`IApprovalGate`, `ICircuitBreaker`, `ICostController`, `IAuditLog`). That seed is incomplete against the repo's own overview and invariants: the overview commits to six interfaces and the invariants reference decision policies and safety filters that have no catalog entry. It also uses `ICostController`, while the repo overview and every downstream reference in the AI-sector context use `ICostGuard`. Before the Node scaffolds, the catalog and the prose need to converge on a single contract surface, because downstream consumers (starting with Agents and Flow) will compile against whatever ships first and lock it in.

Operator's boundary against two adjacent Nodes needs explicit disambiguation before drift creeps in. HoneyDrunk.Auth owns identity and authorization; Operator owns human policy enforcement on top of an already-authenticated, already-authorized action. HoneyDrunk.Communications owns outbound messaging workflows (ADR-0013); Operator raises approval *intent* but does not deliver the message itself. Both boundaries are easy to blur once the Node ships, so this ADR pins them now.

This ADR is the **stand-up decision** for the Operator Node — what it owns, what it does not own, which contracts it exposes, how downstream Nodes couple to it, and how it interacts with Auth and Communications. It is not a scaffolding packet. Filing the repo, adding CI, wiring the InMemory fixture, and producing the first shippable packages all follow as separate issue packets once this ADR is accepted.

## Decision

### D1. HoneyDrunk.Operator is the AI sector's human-policy enforcement and audit substrate

`HoneyDrunk.Operator` is the single Node in the AI sector that owns **human-policy primitives** — the contracts and runtime machinery that decide whether an agent action is allowed to proceed, whether it is within cost budget, and what record gets written when it runs. It is the only Node authorized to halt other AI-sector Nodes. It is a shared substrate, not a reasoning engine. It does not decide *what* an agent should do; it owns *whether the action is allowed*, *what it is permitted to spend*, and *what the immutable record says*.

The rule that anchors the Node's scope is repo-invariant 5: the system that decides what to do must never be the system that decides whether it is allowed. Agents, Flow, and AI propose actions; Operator decides whether those actions may execute and records the outcome.

### D2. Package families

The Operator Node ships the following package families, mirroring the stand-up shape used by ADR-0016 for AI and ADR-0017 for Capabilities:

- `HoneyDrunk.Operator.Abstractions` — all interfaces and the four governance records (`CostEvent`, `AuditEntry`, `ApprovalRequest`, `ApprovalDecision`). Zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions, per repo-invariant 1.
- `HoneyDrunk.Operator` — runtime composition: default approval gate, default circuit breaker, default cost guard, default safety filter, decision-policy evaluator, audit-log writer, DI wiring.
- `HoneyDrunk.Operator.Testing` — opt-in testing fixture package carrying in-memory implementations of every exposed interface for deterministic unit and integration tests. Consumed by downstream Nodes in test projects only, never in production composition.

The `Testing` package is a separate NuGet artifact rather than a `Providers.*` slot because there is no family of providers at the policy-enforcement layer (no OpenAI-vs-Anthropic axis on the approval or breaker side). The in-memory implementation is a testing fixture, not a production backend.

### D3. Exposed contracts

Ten surfaces form the Operator Node's public boundary — six interfaces and four records. These are the surfaces downstream Nodes are allowed to compile against:

| Contract | Kind | Purpose |
|---|---|---|
| `IApprovalGate` | interface | Raise an approval request, check status, consume a decision. Blocks the calling workflow until resolved or timed out. |
| `ICircuitBreaker` | interface | Trip, reset, and query the state of a named breaker. Halts agent, workflow, or inference execution when safety thresholds are breached. |
| `ICostGuard` | interface | Check and record spend against per-agent, per-tenant, and per-window budgets. Enforces hard limits; no soft warnings. |
| `IAuditLog` | interface | Append-only write and time-ordered read over the immutable audit trail. |
| `IDecisionPolicy` | interface | Evaluate a declarative rule set to produce allow / deny / require-approval against a given action context. |
| `ISafetyFilter` | interface | Validate an outbound content or action payload; rejections block the output, no log-and-continue path. |
| `CostEvent` | record | Records a spend event — agent, tenant, window, amount, unit, source. Written by `ICostGuard`, read by the audit log. |
| `AuditEntry` | record | Canonical append-only audit record — actor, action, context, outcome, correlation id. |
| `ApprovalRequest` | record | Machine-readable approval ask — subject, context, requested scope, expiry. |
| `ApprovalDecision` | record | Approval outcome — decision, approver identity, timestamp, reason. |

The four records drop the `I` prefix and are `kind: "type"` in the catalog. This applies the grid-wide rule — records drop the `I` prefix, interfaces retain it — already applied by `ModelCapabilityDeclaration` in ADR-0016 and `CapabilityDescriptor` in ADR-0017.

The existing `ICostController` entry in `catalogs/contracts.json` is superseded by `ICostGuard`. The rename matches the repo overview, invariant file, and every downstream reference already in the AI-sector context. `IDecisionPolicy`, `ISafetyFilter`, and the four records were missing from the catalog seed entirely and are added here.

### D4. Naming collision disambiguation

Two names in the Grid's vocabulary collide with this Node's scope and need explicit disambiguation so neither drift occurs in later docs:

- **`HoneyDrunk.Operator`** (this Node) is the AI sector's human-policy enforcement substrate. It owns approval, breaker, cost, audit, decision policy, and safety-filter contracts. References to the Node are always written as `HoneyDrunk.Operator`.
- **"operator"** used as a generic human-admin term refers to a human role — the person who configures policies, reviews alerts, tunes cost rates in App Configuration, and handles approvals. References to the human role are written in lowercase and in prose only (e.g. "operator-configurable cost rates," "operator-driven cadence"), never as a package or contract name.

The two are related — the Node is *for* the operator as a human role — but they are not interchangeable in docs, code, or catalog entries. This ADR uses `HoneyDrunk.Operator` whenever it refers to the Node and lowercase "operator" whenever it refers to the human. Follow-up docs should do the same.

### D5. Authorization routes through Auth; Operator enforces policy on top

`HoneyDrunk.Auth` owns identity verification and authorization (can this principal take this kind of action on this resource). Operator runs on top of Auth's decision and adds **human-policy** enforcement (is this action within cost budget, does it need human approval, is the output safe, does the circuit breaker allow execution).

The layering is directional:

1. Auth authenticates the caller and evaluates an authorization policy.
2. If Auth allows, Operator's gates, breakers, cost guards, and safety filters evaluate.
3. If all Operator checks pass, the action proceeds.

Operator does not invent its own identity model and does not duplicate Auth's permission model. `catalogs/relationships.json` already reflects the Operator → Auth edge; no change is required there.

### D6. Cost-rate and policy source — App Configuration via Vault

Cost-rate tables, budget windows, circuit-breaker thresholds, decision-policy rule sets, and safety-filter configuration all live in **Azure App Configuration** and are read through `IConfigProvider` from the Vault Node per ADR-0005. No rates, thresholds, or policies are hardcoded in application code. Rate and policy refresh is operator-driven — change the config value, restart or hot-reload, no deploy required.

This matches the same rule already set for AI-sector routing policy (ADR-0016 D5) and applies for the same reason: policy that humans tune at runtime is configuration, not code.

### D7. Telemetry emission — Pulse consumes, Operator does not depend

Operator emits telemetry for every gate outcome, breaker state change, cost event, and audit append via Kernel's `ITelemetryActivityFactory`. Pulse consumes that telemetry downstream. **Operator has no runtime dependency on Pulse.** The direction is one-way by contract: Operator emits, Pulse observes. Same rule as ADR-0016 D7 for AI and ADR-0017 D7 for Capabilities.

Pulse ingress back into Operator — feeding observed telemetry into breaker or cost-guard state — is out of scope for stand-up. See Alternatives Considered.

### D8. Approval notification uses an event-out pattern, not a runtime dependency on Communications

When `IApprovalGate` raises an `ApprovalRequest` that needs human attention, Operator emits an approval-needed event. HoneyDrunk.Communications subscribes to that event stream and owns the downstream workflow (resolve recipient, check preferences, check cadence, deliver via Notify) per ADR-0013.

Operator does **not** take a runtime dependency on Communications and does **not** call `ICommunicationOrchestrator` directly. The edge is outbound-only, which keeps Operator's Auth-adjacent safety-critical path free of an orchestration-layer dependency and keeps Communications as the single authority for *whether and how* a message reaches a human.

The specific **transport mechanism** for that event — whether it routes via `ITransportPublisher`, an integration event bus, or a Communications-side ingress contract — is deferred to the scaffold packet. The stand-up commitment is the pattern (event-out, no runtime edge), not the wire format. This matches ADR-0017 D6's treatment of tool-schema versioning (principle fixed at ADR, mechanism at scaffold). No Transport dependency is added to `catalogs/relationships.json` for this reason; if the scaffold packet selects Transport as the mechanism, that edge is added then.

### D9. Audit log is append-only and its write path is the source of truth

`IAuditLog` writes are append-only (repo-invariant 2). Entries cannot be modified or deleted once written. The audit log is the immutable record of all AI operations: every agent execution, every tool invocation, every inference call, every approval decision, every cost event, every circuit-breaker transition produces an `AuditEntry`.

Storage is backed by HoneyDrunk.Data (the existing `honeydrunk-operator` → `honeydrunk-data` edge in `catalogs/relationships.json`), using the `IRepository` and `IUnitOfWork` contracts. The append-only guarantee is enforced at the interface surface, not only at the storage layer: `IAuditLog` exposes no update or delete method. Consumers that need retention or archival work off the read surface, not by mutating entries.

### D10. Contract-shape canary on the four high-traffic interfaces

A contract-shape canary is added to the Operator Node's CI: it fails the build if any of the following four interfaces change shape (method signatures, parameter shapes) without a corresponding version bump:

- `IApprovalGate`
- `ICircuitBreaker`
- `ICostGuard`
- `ISafetyFilter`

These four are the hot path for every downstream consumer. Accidental shape drift on any of them breaks every AI-sector Node that gates, breaks, budgets, or filters. The canary makes this a compile-time failure at Operator's own CI, not a discovery at consumer sites.

`IDecisionPolicy`, `IAuditLog`, and the four records are not in the canary at stand-up — they are lower-traffic (policy is configuration-driven; audit is write-one-shape) and freezing their surface at stand-up would slow legitimate iteration in the first wave. They become canary candidates once the first real consumers are on them. This matches the pattern from ADR-0016 and ADR-0017 of freezing the four highest-traffic surfaces, not every exposed contract.

### D11. Downstream coupling rule

Downstream AI-sector Nodes (Agents, Flow, AI, Capabilities, Evals) and any domain Node that requires policy enforcement (Notify, Data, Vault, when agent-invoked) compile **only** against `HoneyDrunk.Operator.Abstractions`. They do not take a runtime dependency on `HoneyDrunk.Operator` or `HoneyDrunk.Operator.Testing` in production composition. Composition — which breaker implementation is active, which cost-rate table is loaded, which decision policy evaluator is wired — is a host-time concern, resolved at application startup from App Configuration.

Test projects may reference `HoneyDrunk.Operator.Testing` to pick up the in-memory fixture. Production projects must not.

This is the same abstraction/runtime split already applied for AI, Capabilities, Vault, and Transport. It is re-stated here because it is the specific rule that allows dependent Nodes to proceed on `Abstractions` alone without waiting for the full runtime.

### D12. Dependencies on Kernel, Auth, and Data are first-class

Operator takes first-class runtime dependencies on three Nodes:

- **HoneyDrunk.Kernel** — for `IGridContext`, lifecycle hooks, health and readiness, telemetry. Every Operator path is context-aware; a policy decision without correlation is an undebuggable policy decision.
- **HoneyDrunk.Auth** — for `IAuthorizationPolicy` evaluation. The default `IDecisionPolicy` and `IApprovalGate` implementations cannot produce an allow / deny / require-approval decision without knowing who the caller is and what they are authorized to do.
- **HoneyDrunk.Data** — for `IRepository`, `IUnitOfWork`, and the audit-log write path. The audit log's append-only guarantee and the cost guard's spend ledger both sit on Data's transactional surface.

`catalogs/relationships.json` already reflects these three edges and no change to `consumes` is required. The `consumed_by_planned` list on `honeydrunk-operator` — which should list Agents, Flow, AI, Capabilities, and Evals — is currently empty and is reconciled as follow-up work.

Downstream Nodes are not transitively required to reference Kernel, Auth, or Data in order to *use* Operator — they reference `HoneyDrunk.Operator.Abstractions` only. The three runtime dependencies are composed in at the host, not at the consumer.

## Consequences

### Unblocks

Accepting this ADR — and landing the follow-up scaffold packet that produces a first `Abstractions` release — unblocks every Node currently waiting on Operator:

- **HoneyDrunk.Agents** — can gate agent executions through `IApprovalGate`, halt runaway execution through `ICircuitBreaker`, and write agent-execution records through `IAuditLog`.
- **HoneyDrunk.Flow** — can pause workflows at approval gates via `IApprovalGate`, enforce per-workflow budgets via `ICostGuard`, and kill workflows via `ICircuitBreaker`.
- **HoneyDrunk.AI** — can bound inference spend via `ICostGuard`, filter outputs via `ISafetyFilter`, and halt runaway inference loops via `ICircuitBreaker`.
- **HoneyDrunk.Capabilities** — can chain `IDecisionPolicy` checks above `ICapabilityGuard`'s Auth-rooted authorization, adding human-policy (cost, approval, safety) on top of permission.
- **HoneyDrunk.Evals** — can run eval suites with `ISafetyFilter` and `ICostGuard` in the loop, and write eval-run records to `IAuditLog`.
- **HoneyDrunk.Communications** — receives approval-notification events without a reverse runtime dependency from Operator.

### New invariants (proposed for `constitution/invariants.md`)

Numbering is tentative — scope agent finalizes at acceptance.

- **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Operator.Abstractions`.** Composition against `HoneyDrunk.Operator` and `HoneyDrunk.Operator.Testing` is a host-time (and test-time) concern. See D11.
- **Cost-rate tables, circuit-breaker thresholds, decision policies, and safety-filter configuration are sourced from Azure App Configuration via Vault's `IConfigProvider`.** Hardcoded rates, thresholds, or policies in application code are forbidden. See D6.
- **Approval notifications are emitted as events; Operator does not take a runtime dependency on Communications.** See D8.
- **The Operator Node CI must include a contract-shape canary for `IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, and `ISafetyFilter`.** Shape drift on any of the four is a build failure, not a downstream discovery. See D10.

### Contract-shape canary becomes a requirement

The contract-shape canary in D10 is a gating requirement on the Operator Node's CI from the first scaffold. It is not a later hardening pass — the four frozen interfaces are the hot path for every agent, workflow, and inference gate and must be protected from day one.

### Catalog obligations

`catalogs/contracts.json` currently carries a seed that uses `ICostController`, omits `IDecisionPolicy` and `ISafetyFilter`, and has no entries for the four governance records. Accepting this ADR without reconciling those entries leaves the catalog in a stale state and downstream consumers compiling against a name (`ICostController`) that the Node will not ship. The reconciliation is tracked in the follow-up work section.

`catalogs/relationships.json`'s `consumed_by_planned` for `honeydrunk-operator` is currently empty; it should list Agents, Flow, AI, Capabilities, and Evals with per-edge `consumes_detail` contract lists. This is also tracked in the follow-up work section.

### Negative

- Six interfaces plus four records is more public surface than the four-interface seed that was previously cataloged. The trade is clarity of responsibility and independent testability against modestly more contracts to version. Given the contract-shape canary on only the four highest-traffic interfaces, the extra surfaces cost little to maintain.
- Shipping `HoneyDrunk.Operator.Testing` as an opt-in package adds a second first-wave release artifact. Without it, downstream Nodes would invent their own in-memory doubles of six interfaces apiece and they would drift. The cost is accepted; the pattern already holds for Capabilities (ADR-0017 D2).
- Deferring the approval-notification **transport mechanism** (D8) to the scaffold packet means the first real approval flow may surface a need to revisit the wire format. That is an acceptable cost for not over-committing at stand-up and matches ADR-0017 D6's treatment of versioning.
- Deferring Pulse ingress into Operator (emit-only at stand-up) means breaker and cost-guard state cannot yet react to observed telemetry automatically. Operator-driven tuning via App Configuration covers the stand-up need; automatic reactive tuning is a later concern.

## Alternatives Considered

### Fold safety and cost enforcement into the Agents runtime

Rejected. This conflates *deciding what to do* with *deciding whether an action is allowed* — the exact failure mode that repo-invariant 5 prohibits and that ADR-0013 calls out for the Pulse ↔ Operator split on the messaging side. The same argument applies here: the Node that proposes actions (Agents) must not be the Node that authorizes them (Operator). Additionally, Flow, AI, Capabilities, and Evals all need the same policy surface; putting it in Agents freezes non-agent consumers out of the substrate.

### Ship a single `IGovernanceGate` interface covering all six concerns

Rejected. This is the same argument ADR-0017 made against the single-interface `ICapability` placeholder. A god-interface conflates identity, decision, enforcement, and audit. Every downstream consumer ends up reaching through `IGovernanceGate` for one specific concern and coupling to the others incidentally. Six separated interfaces make each concern independently mockable, independently versioned, and independently canary-able.

### Defer the Operator stand-up until Agents or Flow needs it

Rejected. This is the same argument ADR-0016 rejected for AI and ADR-0017 rejected for Capabilities. Letting Agents, Flow, AI, Capabilities, and Evals invent their own approval, breaker, cost, and audit primitives ad hoc produces N incompatible surfaces with no shared record, no shared policy shape, and no place for the operator (human role) to tune thresholds consistently. The AI sector's foundation is AI (inference) + Capabilities (tools) + Operator (policy); standing up two of three and deferring the third leaves the substrate incomplete.

### Direct `HoneyDrunk.Operator` → `HoneyDrunk.Communications` runtime call for approval notifications

Rejected per D8. A runtime edge makes Operator's safety-critical path depend on an orchestration layer and couples approval gating to Communications availability. An event-out pattern lets Communications enforce preferences, cadence, and workflow logic without Operator having to know those exist — which is exactly the responsibility split ADR-0013 carved out for Communications in the first place.

### Separate cost-control Node outside Operator

Rejected. Cost, approval, audit, circuit-breaking, and safety filtering all share the same policy data model (App Configuration per D6), the same audit surface (`IAuditLog`), and the same downstream-consumer set. Splitting cost out produces a second trust boundary in the policy-enforcement hot path for no corresponding isolation benefit. ADR-0010 kept routing inside AI for the same reason; the same logic applies here to keeping cost inside Operator.

### Let HoneyDrunk.AI own `ICostGuard`

Rejected. Token-level cost *accounting* (how many tokens did this inference consume at what rate) is an inference-side concern and already lives in AI via `IInferenceResult` and the cost-rate tables routed through AI per ADR-0016 D5. Cost *governance* (does this agent / tenant / window have budget remaining, does execution halt when exceeded) is a human-policy concern and belongs in Operator. Putting the governance layer inside AI would drag approval gates and circuit breakers along with it, since a budget-exceeded condition often needs to trip a breaker and raise an approval — which puts Operator's full surface into AI and defeats the separation.

### Pulse signal ingress into Operator at stand-up

Deferred. Reactive closed-loop tuning — where observed telemetry from Pulse automatically trips breakers, adjusts cost guards, or changes decision policies — is an ADR-0010 concern (the observation-and-routing layer) and not a stand-up decision. Flagging it here so it is not lost: when ADR-0010 is accepted and the observation pipeline is live, the Operator Node will need an ingress surface for observed signals. That surface is not specified here and is not blocked by this ADR; emit-only at stand-up is the committed direction and any future ingress contract will be added as a distinct ADR concern.
