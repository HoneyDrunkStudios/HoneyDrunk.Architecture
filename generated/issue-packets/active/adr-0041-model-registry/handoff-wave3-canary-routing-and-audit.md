# Handoff — Waves 3 & 4: Canary, Routing, and Audit Build-out

**Initiative:** `adr-0041-model-registry`
**Wave transition:** Wave 2 (registry foundation) → Wave 3 (canary + routing) → Wave 4 (audit + cost-guard)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 2 landed (packet 02)

`HoneyDrunk.AI` is at **v0.2.0**. `HoneyDrunk.AI.Abstractions` exposes `IModelRegistry`, `IApprovalStateWriter`, `ModelRegistration`, `ProviderRegistration`, `CostProfile`, `ApprovalState`, `RoutingHints`, `ModelId`, `CapabilityPredicate`. `HoneyDrunk.AI` has `DeclarativeModelRegistry` loading `models.json` (four providers — Anthropic, OpenAI, Azure OpenAI, `local` — and an empty `models` array). `IModelRegistry` and `IApprovalStateWriter` are registered in DI.

**The `[0.2.0]` CHANGELOG entry is open and in-progress.** Packets 03, 04, 05 append to it — none of them bump the version (invariant 27).

## Wave 3 — packets 03 and 04 run in parallel

They touch different seams and have no logical dependency, but **share the `HoneyDrunk.AI` solution** — coordinate the working branch, or land one and rebase the other. Both append to the in-progress `[0.2.0]` CHANGELOG.

### Packet 03 — capability canary + model lineup
- Populate `models.json` with the initial model lineup (Anthropic, OpenAI, Azure OpenAI), **every model at `ApprovalState=Preview`** (D4 — no model starts `Approved`).
- New `tests/HoneyDrunk.AI.Tests.Canaries` project — a capability canary per model, asserting each declared capability against a cheap live call, bounded at **$0.01 per call** (D3). The harness reads model data **strictly through `IModelRegistry`** — never the `models.json` embedded resource directly. The vision probe may exceed the $0.01 ceiling from image-token overhead — documented known limitation.
- Nightly per-environment workflow that runs the canaries and persists an `ApprovalState` change by **opening a PR that edits `models.json`** (≤24h fail → `Preview`, ≥7d → `Deprecated`). `models.json` is the durable source of approval state — the in-memory `IApprovalStateWriter` overlay is process-local and evaporates with the ephemeral nightly job, so the workflow must persist via the file, not an in-memory flip.
- The canary project is **excluded from the `pr.yml` tier-1 unit gate** — it is a live-provider tier, the same exception class as ADR-0047's container integration tier. It must not make the unit gate depend on external providers (invariant 15).
- Audit emit on `ApprovalState` flip via `IAuditLog` — see the Audit dependency note below.

### Packet 04 — cost-aware routing + per-call ceiling
- Rewire `DefaultModelRouter` to build candidates from `IModelRegistry` (D1 — the registry is the routing source of truth; no parallel `IModelProvider.DeclaredCapabilities` path).
- Exclude `ApprovalState.Deprecated` models from new dispatch.
- New `CostAwareRoutingPolicy` — the D5 default: capability match → latency-tier preference → lowest `CostProfile` → provider-health tie-break.
- Enforce `CostProfile.MaxBudgetPerCallUsd` before dispatch; **leave a clean seam for packet 05's Audit emit on rejection**.
- Explicit per-call override — implement `PinnedModelRoutingPolicy : IRoutingPolicy` + a `RoutingPolicies.Pinned(ModelId)` factory against the existing unchanged `IRoutingPolicy` (`PolicyName` + `Choose(IReadOnlyList<ModelCandidate>, ChatRequestSummary)` returning `RoutingDecision`). The interface needs no shape change — `RouteAsync` already accepts an `IRoutingPolicy`. Do not modify `IRoutingPolicy`.
- Provider-health tie-break uses a local `IProviderHealthSignal` seam (all-healthy default) — no runtime dependency on the Planned `HoneyDrunk.Observe` Node.

## Wave 4 — packet 05

- Emit an Audit entry on **every** dispatch — `(TenantId, ModelId, PolicyOverride?, CostUsd, Outcome)` — on success and on ceiling rejection. Wire into the seam packet 04 left.
- Per-tenant cost-guard layer that runs **before** the router (D6) — a per-tenant period ceiling, App-Configuration-sourced (invariant 45), backed by the existing `ICostLedger`.
- Audit entries go through `IAuditLog` (`HoneyDrunk.Audit.Abstractions`, hard dependency) — **never** through `InferenceTelemetry` or Pulse (invariant 47 — audit is not telemetry).

## Audit / Operator dependency — per-Node strategy (packets 03 and 05)

`HoneyDrunk.Audit` and `HoneyDrunk.Operator` are at different maturity, so the strategy differs per Node. ADR-0041 requires the Audit emit (`IAuditLog`, ADR-0030) and the per-tenant `ICostGuard` intersection (ADR-0018, in `HoneyDrunk.Operator`).

- **`HoneyDrunk.Audit` IS scaffolded** — buildable `HoneyDrunk.Audit.Abstractions` (`IAuditLog`) + `HoneyDrunk.Audit.Data` projects. Packets 03 and 05 take `HoneyDrunk.Audit.Abstractions` as a **HARD dependency** — `.Abstractions` only, never `HoneyDrunk.Audit.Data` (invariant 48) — and emit a real `AuditEntry`. Verify the package is on the feed at execution time; if it is not yet published, that is a **blocker to resolve** (publish it), not a reason to ship a permanent local audit seam. There is no long-lived `IDispatchAuditSink` interface. Packets 03 (canary-flip emit) and 05 (dispatch emit) both bind to the same `IAuditLog`.
- **`HoneyDrunk.Operator` has no `src/` at all** — cataloged but unscaffolded, no publishable `HoneyDrunk.Operator.Abstractions`. Packet 05's per-tenant cost-guard intersection uses a **local `ITenantCostGuard` seam** in `HoneyDrunk.AI.Abstractions`, backed by the existing `ICostLedger`. This local-seam fallback is correct and intended **only for the Operator `ICostGuard` intersection** — reconciling `ITenantCostGuard` with `ICostGuard` is a follow-up once `HoneyDrunk.Operator` is scaffolded.

## Interface signatures in play

`IModelRegistry.GetRegistered() / GetById(ModelId) / GetByCapability(CapabilityPredicate)` — packets 03 and 04 both consume this.

`IApprovalStateWriter` — packet 03's canary drives `ApprovalState` flips through it.

`IModelRouter.RouteAsync(ChatRequestSummary, IRoutingPolicy, CancellationToken)` — packet 04 rewires the implementation; the contract shape does not change.

`IRoutingPolicy.Choose(IReadOnlyList<ModelCandidate>, ChatRequestSummary)` — packet 04 adds `CostAwareRoutingPolicy` and `PinnedModelRoutingPolicy` implementations; prefer no shape change to the interface.

## Invariants binding Waves 3 & 4

- **Invariant 27** — no version bump in packets 03/04/05; append to the in-progress `[0.2.0]` CHANGELOG. Packet 02 was the bumping packet.
- **Invariant 15** — unit and in-process integration tests never depend on external services. The capability canary is a deliberate separate tier in its own `.Canaries` project, excluded from the unit gate.
- **Invariant 51** — no `Thread.Sleep` in test code; use `await` and polling primitives with explicit timeouts.
- **Invariant 47** — durable, attributable events are emitted via `IAuditLog` on a channel separate from observability telemetry. Audit records never flow to Pulse. Packet 05's dispatch Audit emit must not go through `InferenceTelemetry`.
- **Invariant 48** — runtime dependency on `HoneyDrunk.Audit.Abstractions` only, never `HoneyDrunk.Audit.Data`.
- **Invariant 45** — token cost rates, routing policies, and ceilings are sourced from Azure App Configuration via `IConfigProvider`; never compiled constants. Packet 05's per-tenant ceiling obeys this.
- **Invariant 39** — tenant mechanics (the per-tenant cost guard) stay at the intake edge; the core router stays tenant-agnostic for internal `TenantId.Internal` callers.
- **Invariant 46** — the `api-compatibility.yml` contract-shape canary gates `IChatClient`/`IEmbeddingGenerator`/`IModelProvider`/`IModelRouter`; any Abstractions change in packets 03–05 must be additive (covered by packet 02's bump) or it fails the canary.
- **New AI invariants 72, 73, 74 (from packet 00)** — invariant 72: no dispatch against an unregistered model (packet 04 enforces); invariant 73: every approved model has a passing 24h canary (packet 03 enforces); invariant 74: every dispatch emits an Audit entry (packet 05 enforces).

## Human prerequisites that gate live behaviour (not the agent's PR)

- Provider API keys seeded in Vault (Anthropic, OpenAI, Azure OpenAI) — needed for packet 03's nightly canary to make live calls.
- GitHub environment secrets / Vault access wired for the nightly canary workflow per environment.
- An App Configuration key for the per-tenant cost ceiling — packet 05's guard reads it; absent, it falls back to a safe default.
- Acceptance of the recurring canary cost (~$5/month at v1, bounded).

These happen before/around the agent PRs, not during — packets 03 and 05 stay `Actor=Agent`.

## Acceptance gate for the initiative

After packet 05: every AI dispatch in `HoneyDrunk.AI` routes off the registry, respects the per-call and per-tenant cost ceilings, excludes `Deprecated` models, and emits a forensic Audit entry. The nightly canary validates declared capabilities against provider reality and drives `ApprovalState`. All three ADR-0041 invariants are satisfied at the `HoneyDrunk.AI` boundary. `HoneyDrunk.AI` ships at v0.2.0.
