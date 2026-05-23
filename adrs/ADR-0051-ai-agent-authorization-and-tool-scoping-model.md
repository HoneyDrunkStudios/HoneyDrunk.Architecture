# ADR-0051: AI Agent Authorization and Tool Scoping Model

**Status:** Proposed
**Date:** 2026-05-22
**Deciders:** HoneyDrunk Studios
**Sector:** AI / cross-cutting

## Context

The AI sector standup wave (ADR-0016 through ADR-0025) introduces nine Nodes, three of which already presume an authorization substrate that the Grid has not yet committed to:

- **ADR-0017 (`HoneyDrunk.Capabilities`, Proposed)** names a Tool Registry and an `IToolInvoker` dispatcher, and gestures at "tool permissioning" without defining the permissioning model itself.
- **ADR-0018 (`HoneyDrunk.Operator`, Proposed)** describes the operator surface that *grants* tool access to agents, but defers the grant primitive's shape.
- **ADR-0020 (`HoneyDrunk.Agents`, Proposed)** describes an agent execution loop that invokes tools through `IToolInvoker`, and assumes the invoker can deny calls — but the deny mechanism is left as `// TODO: authorization model`.

Three places where the gap is load-bearing, all currently empty. ADR-0016's catalog/standup is Accepted; the three downstream ADRs are blocked on this one. The packets for Capabilities (0/4 closed) and Agents (0/4 closed) are stalled at the standup canary because the standup canary is *demonstrating tool authorization* and there is nothing to demonstrate against.

The forcing functions for deciding this now:

- **The AI-sector standup blocker.** Capabilities and Agents cannot ship their standup canaries until the authorization model is concrete. ADR-0017 explicitly defers to "a future authorization ADR"; this is that ADR.
- **ADR-0006 (Auth) does not anticipate agents-as-principals.** `IAuthorizationPolicy` is shaped around human (`UserPrincipal`) and service-to-service (`ServicePrincipal`) cases. The Auth Node's contract is "given a principal and a resource, decide allow/deny" — the principal-typing surface is closed today, and adding a third principal type is not a hot-fix.
- **Invariant 10 ("Auth validates, never issues") must hold for agents.** Whatever the agent-identity story is, the issuer cannot be Auth itself; identity origination lives somewhere else (Operator, per D8) and Auth validates the assertion. The boundary is non-negotiable; this ADR works within it.
- **ADR-0030 (Audit Substrate, Accepted) requires every agent action to be audited.** Audit's contract assumes the actor is identifiable. Without a first-class agent identity, every audit record from agent execution would carry a degenerate `principal=anonymous-agent`, which collapses the entire audit story for the AI sector.
- **ADR-0031 (Audit Standup) is in flight** and will start emitting on agent-execution paths once the AI sector stands up. Agent identity needs to be defined *before* those paths emit, not retrofitted after.
- **Operator (ADR-0018) is itself an agent.** The granting surface runs as an agent with grant capabilities — which means the authorization model must be expressive enough to describe Operator's own permissions *without enabling recursive escalation*. This is a real constraint that shapes D8 substantively.
- **PDR-0001 and PDR-0003 (Lately) imply long-running content agents** that act on behalf of end users. "On behalf of" is not a footnote — it's a permission-shape decision (intersection vs union per D5) that affects whether a runaway agent can exceed the granting user's permissions.

The shape of the decision: an **agent principal type**, **capability bundles** (versioned, granted by Operator), **tool scoping** at the `IToolInvoker` boundary, **tenant-scoped capabilities** composable with ADR-0026 tenant primitives, **delegated-execution intersection rules**, **time-bound grants**, **deny-by-default**, and a **declarative config v1** for the bundle store with a documented escalation to dynamic policy.

## Decision

### D1 — Agents are a first-class principal type

The Grid commits to **three principal types**, not two:

| Principal Type | Issued By | Identifies | Lifetime |
|----------------|-----------|------------|----------|
| `UserPrincipal` | Auth (via external IdP per ADR-0006) | A human end-user | Session-bound |
| `ServicePrincipal` | Auth (via managed identity / workload identity) | A Node or deployable service | Process-bound |
| **`AgentPrincipal`** | **Operator (per D8)** | **An AI agent invocation** | **Run-bound (per `AgentRunId`)** |

`AgentPrincipal` has the following identity shape (added to `HoneyDrunk.Auth.Abstractions`):

```
public sealed record AgentPrincipal(
    AgentId Id,              // Stable across runs (e.g., "lately-content-publisher")
    AgentRunId RunId,        // Per-invocation correlation
    Principal? OnBehalfOf,   // Optional delegated principal (User or Service)
    CapabilityBundleRef[] Bundles,  // Granted bundles at run start
    DateTimeOffset NotAfter  // Per D6 expiry
) : Principal;
```

`AgentId` is a stable string identifier registered with Operator at agent creation; `AgentRunId` is a `Guid` per invocation; `OnBehalfOf` is null when the agent acts autonomously (e.g., a scheduled `netrunner` sweep) and populated when the agent runs on behalf of a user/tenant principal (e.g., a Lately publisher acting for a creator).

`AgentPrincipal` flows through `RequestContext` (the existing carrier for `UserPrincipal` / `ServicePrincipal` per ADR-0006), and is orthogonal to but composable with ADR-0026's `TenantId` — an `AgentPrincipal` can have a `TenantId` set in the `RequestContext` independent of its `OnBehalfOf` relationship (an autonomous agent operating on a specific tenant's data is a valid shape).

**Why a third principal type instead of treating agents as service principals:** services are long-lived and identified by deployment identity; agents are short-lived, identified by invocation, and carry a delegation relationship (`OnBehalfOf`) that services do not. Conflating the two would force `ServicePrincipal` to grow optional fields it does not need elsewhere, and would lose the audit-time distinction between "a service ran" and "an agent ran inside a service" — a distinction Audit (ADR-0030/0031) needs.

### D2 — Capability bundles, not raw capability grants

A **capability** is a named, fine-grained permission expressed as a dotted string with optional scope:

```
notify.send                    # Send a notification (any tenant)
notify.send:tenant=acme        # Send a notification, scoped to tenant "acme"
data.query.readonly            # Read-only data queries (any tenant)
vault.secret.read:scope=billing/*   # Read secrets under the billing scope
audit.append                   # Append to the Audit log (per ADR-0030)
grid.tool.invoke:tool=publish-post  # Invoke a specific tool by name
```

Capabilities are **never granted directly to agents.** Agents are granted **capability bundles** — named, versioned sets of capabilities authored at the Operator surface:

```
bundle:lately-content-publisher@v3
  - notify.send:tenant={runtime}
  - data.query.readonly:tenant={runtime}
  - grid.tool.invoke:tool=draft-post
  - grid.tool.invoke:tool=publish-post
  - audit.append

bundle:netrunner-architecture-sweep@v1
  - data.query.readonly:tenant=studios-internal
  - grid.tool.invoke:tool=scan-repos
  - grid.tool.invoke:tool=update-catalogs
  - audit.append
```

The bundle indirection is load-bearing:

- **Review surface.** A capability bundle's contents are reviewed once at authoring time; subsequent agent grants reference the bundle by name. Without bundles, every grant is a fresh review of N raw capabilities.
- **Versioning.** Bundles carry semantic versions (`@v3`). Upgrading the bundle is an explicit decision; agents are pinned to a specific version unless re-granted. This prevents "we added a capability to the bundle and now every agent that holds it has new powers" silent privilege creep.
- **Operator UX.** The grant UI / config surface enumerates bundles (small N), not capabilities (large N).
- **Auditability.** Audit records reference `bundle:lately-content-publisher@v3` as the grant source, which is a stable identifier resolvable to the exact capability set at that version.

Bundles are namespaced under `bundle:` to keep them distinguishable from capabilities in logs and audit records.

### D3 — Tool scoping via `IToolInvoker` authorization check

Every tool registered with the Capabilities Node (per ADR-0017) declares its **required capability set** in its metadata. The `ITool` interface in `HoneyDrunk.Capabilities.Abstractions` is extended:

```
public interface ITool
{
    string Name { get; }
    ToolDescription Description { get; }
    CapabilityRequirement[] RequiredCapabilities { get; }  // NEW
    ValueTask<ToolResult> ExecuteAsync(ToolInvocation invocation, CancellationToken ct);
}

public sealed record CapabilityRequirement(
    string Capability,            // e.g., "notify.send"
    ScopeBindingMode Scope        // None | Tenant | OnBehalfOfPrincipal | Custom
);
```

`IToolInvoker.InvokeAsync(toolName, args, RequestContext ctx)` performs the following ordered checks before dispatching to the tool:

1. Resolve `toolName` to a registered `ITool`. Unknown tool → `ToolNotFoundException` (not an authz failure; surfaces the typo distinctly).
2. Extract the `AgentPrincipal` from `ctx`. Missing or non-agent principal → `AuthorizationDeniedException` with reason `principal_type_mismatch`. (Tools registered with the Capabilities Node are *only* invoked by agents; service-to-service or user-direct invocation paths route differently.)
3. Compute the agent's **effective capabilities** at this moment (per D4, D5, D6).
4. For each `CapabilityRequirement` on the tool: check the requirement is satisfied by the effective set, with scope resolution against `RequestContext.TenantId` / `OnBehalfOf` as the `ScopeBindingMode` dictates.
5. If all requirements pass: dispatch to `ITool.ExecuteAsync` and emit a `tool.invoke.granted` audit record.
6. If any requirement fails: throw `AuthorizationDeniedException` and emit a `tool.invoke.denied` audit record with the failing capability and the agent's effective set (capability names only, not values).

The authorization check lives in `IToolInvoker`'s default implementation in `HoneyDrunk.Capabilities` — every tool gets it for free. Tool authors do not write `if (!authorized) throw` boilerplate; the registry-level check is the single enforcement point. This is the Grid analog of ASP.NET's `[Authorize]` attribute model — declarative requirement, framework-level enforcement.

**Failures are always audited (per ADR-0030).** A silent deny is forbidden; the audit record is part of the deny contract. The audit shape is defined in D10.

### D4 — Tenant scoping composes with ADR-0026 primitives

A capability may be **tenant-scoped** with one of three binding modes:

- **`ScopeBindingMode.None`** — the capability applies regardless of tenant. Example: `audit.append` (every agent must always be able to append audit; the Grid invariant).
- **`ScopeBindingMode.Tenant`** — the capability is scoped to a specific tenant (or `{runtime}` placeholder). Example: `notify.send:tenant={runtime}` is satisfied iff the agent's effective set contains `notify.send:tenant=<X>` where `<X>` matches `RequestContext.TenantId`.
- **`ScopeBindingMode.OnBehalfOfPrincipal`** — the capability is scoped to the principal the agent is acting for. Used when the agent's authority derives from the user's authority (e.g., reading the user's Vault scope).

The `{runtime}` placeholder in bundle definitions binds at grant time, not at definition time. When Operator grants `bundle:lately-content-publisher@v3` to an agent acting on tenant `acme`, the placeholder resolves to `tenant=acme`. This avoids a combinatorial explosion of per-tenant bundle copies.

**Cross-Grid agents** (agents that operate on the studio itself rather than a tenant — `netrunner` for the Architecture repo, `hive-sync` for the catalogs, etc.) have a reserved tenant scope: `tenant=studios-internal`. The reserved scope is the explicit, recognizable identifier for "this agent operates on the studio's own surface, not on any customer tenant." Operator refuses to grant `tenant=studios-internal` bundles to agents that have an `OnBehalfOf` populated with a customer principal — the combination is nonsensical and is rejected at grant time, not at execution time.

### D5 — Delegation: effective capabilities are the **intersection**

When an `AgentPrincipal` has `OnBehalfOf` populated with a non-null `Principal`, the agent's **effective capability set** at execution time is computed as:

```
effective = intersect(
    union(agent.Bundles[*].Capabilities),
    union(OnBehalfOf.Permissions)
)
```

The **intersection**, not the union. This is the central safety property of the delegation model:

- The agent **cannot exceed** the granting principal's permissions, even if the bundle would otherwise allow it. If a user has only `data.query.readonly` and the agent's bundle includes `data.write`, the effective set excludes `data.write` for this invocation.
- The agent **cannot exceed** its bundle, even if the granting principal would otherwise allow it. A user with admin permissions cannot accidentally elevate the agent past its granted bundle.

The user / service principal's "permissions" are resolved via the existing `IAuthorizationPolicy` surface in ADR-0006 — the agent authorization model **composes** with the existing Auth model rather than replacing it. The composition is the additional check at `IToolInvoker`; `IAuthorizationPolicy` continues to govern direct-user calls.

**Both identities are audited.** Every authz decision audit record carries both `AgentPrincipal.Id` / `AgentRunId` and (when present) the `OnBehalfOf.Id`. The Audit query "what did agent X do on behalf of user Y" is a first-class shape.

**Autonomous agents** (no `OnBehalfOf`) use only their bundle's capability set; there is no `OnBehalfOf` to intersect with. This is correct: an autonomous agent's authority *is* its bundle. The autonomous case typically uses `tenant=studios-internal` per D4.

### D6 — Time-bound grants with `NotAfter`

Every capability grant carries an optional `NotAfter` expiry timestamp. The defaults:

| Grant Source | Default `NotAfter` | Rationale |
|--------------|--------------------|-----------|
| Operator ad-hoc grant for a one-shot task | **1 hour** | Most operator-driven agent invocations are short. A grant that outlives the task is needless attack surface. |
| Long-running agent bundle (Lately publisher, Hearth content worker) | **30 days** | These agents run continuously; daily-grant friction would block them. The 30-day cycle forces an explicit re-grant decision monthly. |
| `netrunner` / `hive-sync` / other infra-sweep agents | **24 hours** | Daily re-grant aligns with the scheduled-sweep cadence and surfaces unused agents quickly. |
| `bundle:local-dev-all` (per D12) | **8 hours** | A dev's working day. Refreshed by re-running the local-dev bootstrap. |

Operator's grant API accepts an explicit `notAfter` parameter; if omitted, the default for the grant type applies. Operator's grant API rejects `notAfter` further than 90 days in the future for any grant type — the upper bound is a forcing function against "I'll just grant it for a year" sprawl. Long-running agents at the 30-day cycle re-grant via an automated Operator workflow that requires explicit re-confirmation, not silent renewal.

At `IToolInvoker` check time, `DateTimeOffset.UtcNow > AgentPrincipal.NotAfter` short-circuits to `AuthorizationDeniedException` with reason `grant_expired`. The expiry check is the first capability check, before bundle resolution — an expired grant is never elaborated.

### D7 — Tool registry: required-capabilities declared in code

The Tool Registry (per ADR-0017) is queried at the Capabilities Node startup and held in-memory. Tool metadata (including `RequiredCapabilities`) is declared in the tool's own type:

```
public sealed class PublishPostTool : ITool
{
    public string Name => "publish-post";
    public ToolDescription Description => /* ... */;
    public CapabilityRequirement[] RequiredCapabilities => new[]
    {
        new("grid.tool.invoke:tool=publish-post", ScopeBindingMode.None),
        new("notify.send:tenant={runtime}", ScopeBindingMode.Tenant),
        new("data.write:tenant={runtime}", ScopeBindingMode.Tenant),
    };
    public ValueTask<ToolResult> ExecuteAsync(...) { /* ... */ }
}
```

The capability requirements live next to the tool implementation, version with it, and are reviewed as part of the tool's PR. This is intentionally not centralized in a separate config — the tool *is* the source of truth for what it needs.

**v1 is static.** Capability changes (new required capability on an existing tool, changed scope binding) require a redeploy of the Capabilities Node. This is a constraint, not a feature — it forces capability changes through the same PR review path as any other code change, which is the right surface for "this tool now needs the ability to write tenant data" at v1 scale.

**Dynamic policy (v2)** — runtime-mutable tool requirements driven by an admin UI — is named in D13 as a documented escalation but not implemented now. Adding it requires a policy store with versioning, propagation guarantees, and a rollback story. The cost is real; the v1 scale doesn't justify it.

### D8 — Operator interaction: privileged but non-recursive

The Operator Node (ADR-0018) is the **only** surface that issues `AgentPrincipal` tokens and the **only** surface that grants/revokes capability bundles. Operator's grant API:

```
POST /grants
  { agentId, bundleName, bundleVersion, tenantBinding?, onBehalfOf?, notAfter? }

DELETE /grants/{grantId}
```

Operator itself **runs as an agent.** Its bundle (`bundle:grid-operator@v1`) includes the grant-issuance capabilities:

```
bundle:grid-operator@v1
  - operator.grant.issue:bundleName={whitelist}
  - operator.grant.revoke
  - audit.append
  - data.query.readonly:tenant=studios-internal
```

The critical safety property: **Operator cannot grant itself new capabilities.** This is enforced two ways:

1. **`operator.grant.issue:bundleName={whitelist}`** — the grant-issue capability is scoped to a whitelist of bundle names that **excludes `bundle:grid-operator@*`**. Operator can grant any bundle in the whitelist; it cannot grant the bundle that includes the grant-issue capability itself. The whitelist is part of the bundle's static definition and changing it requires a redeploy of the bundle store (per D9).
2. **Operator startup validation.** At Operator's standup canary, the Capabilities Node validates that `bundle:grid-operator`'s whitelist does not include any bundle whose capabilities include `operator.grant.issue:*`. If it does, Operator refuses to start. This is a startup-time recursion check, not a runtime check.

The cycle is broken structurally. Operator can grant new bundles to other agents; Operator cannot escalate itself, even with a bug or a misconfigured grant. The only way to expand Operator's own capabilities is via a Grid-level PR to the bundle definitions, which is the right review surface.

**Revocation** is immediate. Revoking a grant invalidates the `AgentPrincipal` for subsequent invocations; in-flight invocations complete with the previously-resolved capability set (revoking mid-call would create partial-state failures that are worse than the brief grant overlap). The `NotAfter` check (D6) bounds the worst-case overlap window anyway.

### D9 — v1 policy storage: declarative config in the Capabilities Node repo

Capability bundles at v1 live in a `policies/` directory inside the `HoneyDrunk.Capabilities` repository:

```
HoneyDrunk.Capabilities/
  src/
  policies/
    bundles/
      lately-content-publisher.v3.yaml
      netrunner-architecture-sweep.v1.yaml
      grid-operator.v1.yaml
      local-dev-all.v1.yaml
    capabilities/
      grid-vocabulary.yaml      # Authoritative list of valid capability strings
```

YAML over JSON for human edit-and-review ergonomics; capability bundles are read by humans during reviews as often as by machines at runtime.

**Why in-repo and not in a separate `HoneyDrunk.Policies` repo:** the bundle definitions are tightly coupled to the Capabilities Node's tool registry — adding a new tool typically requires adding capability references in one or more bundles. Co-locating them keeps the PR boundary clean (one PR adds the tool and updates the bundle that grants it). A separate repo would mean cross-repo PRs for every new tool, which is the friction-cost ADR-0008 explicitly works to reduce.

**Loading and validation.** At Capabilities Node startup:

1. Load every `*.yaml` under `policies/bundles/` and parse to `CapabilityBundle` records.
2. Validate every capability string against `policies/capabilities/grid-vocabulary.yaml` (typo-catching).
3. Validate the D8 non-recursion property on `bundle:grid-operator`.
4. Validate the D12 dev-only property on `bundle:local-dev-all`.
5. Hash the bundle set and emit the hash as a startup log (for audit/diff against the previous deployment).

Validation failures fail the startup canary, which fails CI per ADR-0011.

**v2 (dynamic store with admin UI)** — when warranted — is named as the escalation path in D13. Triggers include: bundle count exceeding ~50 (declarative-file review starts losing signal), multi-tenant SaaS posture requiring per-tenant custom bundles (the static file becomes incorrect), and operator-team growth requiring non-developer bundle authoring. None apply at v1.

### D10 — Audit record shape for authz decisions

Every authz decision emits an Audit record (per ADR-0030 D? — Audit's append-only contract). The record shape:

| Field | Type | Notes |
|-------|------|-------|
| `event` | string | `tool.invoke.granted` or `tool.invoke.denied` |
| `agent.id` | string | `AgentPrincipal.Id` |
| `agent.runId` | guid | `AgentPrincipal.RunId` |
| `agent.bundles` | string[] | `["bundle:lately-content-publisher@v3", ...]` |
| `onBehalfOf.type` | string? | `"user"` / `"service"` / null |
| `onBehalfOf.id` | string? | Pseudonymous principal ID (per ADR-0045 D7 PII rules) |
| `tenant.id` | string? | From `RequestContext.TenantId` |
| `tool.name` | string | The invoked tool |
| `tool.requiredCapabilities` | string[] | Capability names only |
| `effective.capabilities` | string[] | Names only — values/scopes elaborated, but no secret values |
| `decision` | string | `"grant"` / `"deny"` |
| `deny.reason` | string? | `"capability_missing"` / `"scope_mismatch"` / `"grant_expired"` / `"principal_type_mismatch"` |
| `deny.missingCapability` | string? | The specific capability that failed |
| `timestamp` | datetime | UTC |
| `traceId` | string | Per ADR-0040 — links the audit record to its trace |

The record is **emitted via `IAuditAppender`** (the Audit Node's interface), not by direct write. The `IToolInvoker` default implementation depends on `IAuditAppender` — if Audit is unavailable, tool invocation **denies** (fail-closed per ADR-0030's invariant), not allows. The "we couldn't audit, so we proceeded anyway" failure mode is explicitly rejected.

The audit volume is bounded by tool-invocation volume, which at v1 is single-digit invocations per second across the Grid. Audit ingest cost is non-issue at this scale; the long-retention (730 days per ADR-0040 D3) cost is also non-issue.

### D11 — Deny by default; typed exceptions

The authorization model is **deny by default**:

- An `AgentPrincipal` with **no granted bundles** has an empty effective capability set. Every tool invocation denies.
- An `AgentPrincipal` whose bundles **do not include** the required capability for a given tool denies.
- An `AgentPrincipal` whose grant has **expired** (`NotAfter < now`) denies.
- A non-agent principal invoking the Capabilities tool surface denies with `principal_type_mismatch`.

**Failures are typed, not silent.** `AuthorizationDeniedException` is the single exception type, with structured detail:

```
public sealed class AuthorizationDeniedException : Exception
{
    public DenyReason Reason { get; }
    public string? MissingCapability { get; }
    public string ToolName { get; }
    public AgentId AgentId { get; }
    // ...
}
```

The Agents Node's execution loop catches `AuthorizationDeniedException` and surfaces it to the LLM as a structured tool-result error (`{"error": "authorization_denied", "missing": "notify.send:tenant=acme"}`) — the LLM can reason about the deny rather than re-trying the same tool blindly. This is materially better than the silent skip (the LLM has no idea why the action didn't happen) or the generic exception (the LLM cannot distinguish "denied" from "tool crashed").

**No "default allow" mode.** There is no environment flag, no debug bypass, no admin override that flips the default. The dev-environment accommodation is the `bundle:local-dev-all` mechanism in D12, which is itself a *granted bundle subject to the same model* — not a bypass of the model.

### D12 — Local-dev affordance: `bundle:local-dev-all`, env-guarded

Local development needs a way to run agents without authoring per-tool bundles for every quick test. The accommodation:

`bundle:local-dev-all@v1` is defined in `policies/bundles/local-dev-all.v1.yaml` with a wildcard capability set:

```
name: local-dev-all
version: 1
capabilities:
  - "*"
  - "notify.send:tenant=*"
  - "data.*:tenant=*"
  - "grid.tool.invoke:tool=*"
environments:
  - local
  - dev
```

The `environments` field is **enforced at Capabilities Node startup**:

1. The Node reads `ASPNETCORE_ENVIRONMENT` (or equivalent per ADR-0033).
2. For every bundle with a non-empty `environments` field, the current environment must appear in the list.
3. If `bundle:local-dev-all` is loaded and the current environment is `staging` or `prod`, the Node **refuses to start**, emits a fatal log line, and exits non-zero.

The check is at startup, not at grant time, because the failure surface is unambiguous and immediate — a misconfigured prod deploy that ships with `bundle:local-dev-all` enabled simply does not run. Production cannot accidentally use the dev-all bundle; the only way it could is by stripping the `environments` check from the Node code, which is a visible code change with a review surface.

Cross-references ADR-0033 (environment configuration). The same `ASPNETCORE_ENVIRONMENT` value that drives connection strings and feature flags drives the bundle gate.

`bundle:local-dev-all` is granted only by the local-dev bootstrap script; it is **not** granted by Operator (Operator's whitelist per D8 excludes it). This ensures the dev bundle cannot leak into a deployed environment via an Operator API call, even if the environment check were bypassed.

### D13 — Documented escalation paths

The v1 model is sufficient for current Grid scale. Three escalations are named in advance so the v2 decisions arrive with context, not as surprises:

| Escalation Trigger | v1 Limitation | v2 Direction |
|---|---|---|
| Bundle count > ~50, or operator-team growth needs non-developer authoring | YAML in repo + PR-based authoring is the bottleneck | Move to a dynamic policy store (Cosmos-backed) with an Operator admin UI for bundle CRUD; preserve the YAML as an export/import format for review-as-code |
| Multi-tenant SaaS posture with per-tenant custom bundles | Static bundles cannot represent "tenant `acme` has its own custom bundle" | Per-tenant bundle namespaces in the store; tenant-scoped Operator admin |
| Policy complexity exceeds the capability/bundle model (e.g., time-of-day restrictions, geofencing, attribute-based access) | Capability strings are coarse | Adopt Open Policy Agent (OPA) sidecar; capability resolution delegates to OPA's Rego policy; the `IToolInvoker` check becomes an OPA query. The agent principal and bundle model stay; the *evaluation engine* is swapped. |

OPA is explicitly named as the v2 escalation rather than the v1 default because at one developer with ~10 active bundles, OPA's expressivity is unused and its operational surface (sidecar, policy compilation pipeline, debugging Rego) is real cost. The v1 model can mature into the OPA model when the simpler one stops fitting; the abstraction (`IAuthorizationPolicy` extended with agent-principal handling) is portable to either backing.

### D14 — Phased rollout

- **Phase 1 (Week 1–2) — Abstractions.** Add `AgentPrincipal`, `AgentId`, `AgentRunId`, `CapabilityBundle`, `Capability`, `CapabilityRequirement`, `ScopeBindingMode`, `AuthorizationDeniedException` to `HoneyDrunk.Auth.Abstractions` and `HoneyDrunk.Capabilities.Abstractions`. Update `RequestContext` to carry `AgentPrincipal`. No behavior changes; abstractions only.
- **Phase 2 (Week 2–4) — Capabilities Node v1.** Stand up `HoneyDrunk.Capabilities` per ADR-0017 with the bundle-store loader (D9), the `IToolInvoker` default authorization check (D3), the deny-by-default contract (D11), the `bundle:local-dev-all` env-guard (D12), and the recursion check on `bundle:grid-operator` (D8). Standup canary demonstrates: agent with bundle → tool invocation succeeds; agent without bundle → typed deny; expired grant → typed deny; `local-dev-all` in `prod` env → Node refuses to start.
- **Phase 3 (Week 4–6) — Operator Node v1.** Stand up `HoneyDrunk.Operator` per ADR-0018 with the grant/revoke API, the bundle whitelist, the `bundle:grid-operator` self-grant. Operator runs as an agent against the Capabilities Node it administers. Standup canary demonstrates: Operator grants a bundle → agent gains capabilities; Operator tries to grant itself a new capability → rejected; grant expires → agent loses capabilities.
- **Phase 4 (Week 6–8) — Agents Node v1.** Stand up `HoneyDrunk.Agents` per ADR-0020. Execution loop carries `AgentPrincipal` through `RequestContext`, invokes tools through `IToolInvoker`, surfaces `AuthorizationDeniedException` to the LLM as structured tool errors. Standup canary demonstrates: an agent with a real bundle (`bundle:netrunner-architecture-sweep@v1`) executes against a local Capabilities Node and audits every invocation.
- **Phase 5 (Month 3+) — AI sector consumers.** Lately, Hearth, and any other AI consumer integrate against the live Capabilities + Operator surfaces. Bundle definitions per consumer land in `policies/bundles/`. Each consumer's standup canary includes its bundle and authorization path.
- **Phase 6 (When v2 trigger fires) — Dynamic store or OPA per D13.** Not before.

Each phase is a discrete go/no-go.

## Consequences

### Affected Nodes

- **HoneyDrunk.Auth** — `Abstractions` package gains `AgentPrincipal` and related types. The runtime Auth Node is unchanged at v1 (it does not issue agent tokens; Operator does — Invariant 10 preserved). Auth's `IAuthorizationPolicy` continues to govern human/service paths.
- **HoneyDrunk.Capabilities** — primary affected Node. Implements the `IToolInvoker` authorization check, the bundle-store loader, the recursion check, the env-guard. Owns `policies/bundles/` and `policies/capabilities/grid-vocabulary.yaml`.
- **HoneyDrunk.Operator** — primary affected Node. Implements the grant/revoke API; runs as an agent against Capabilities. The Operator standup ADR (ADR-0018) becomes implementable upon this ADR's acceptance.
- **HoneyDrunk.Agents** — primary affected Node. Execution loop carries `AgentPrincipal` and surfaces typed deny errors to the LLM. The Agents standup ADR (ADR-0020) becomes implementable upon this ADR's acceptance.
- **HoneyDrunk.Audit** — gains the `tool.invoke.granted` / `tool.invoke.denied` event taxonomy. The Audit Node's event-shape registry (per ADR-0030/0031) extends to recognize these events; no schema-breaking change.
- **HoneyDrunk.Kernel** — `RequestContext` (the existing carrier) gains an `AgentPrincipal?` slot alongside the existing `UserPrincipal?` / `ServicePrincipal?` slots. This is an additive change with no breaking impact.
- **HoneyDrunk.Architecture** — `catalogs/contracts.json` gains the new abstractions under Auth and Capabilities; `constitution/ai-sector-architecture.md` cross-references this ADR as the authorization substrate.
- **All future AI-sector consumers (Lately, Hearth, etc.)** — each consumer authors its capability bundle in `policies/bundles/` as part of standup. The standup template (per `.claude/agents/scope.md`) gets a new "Capability bundle definition" section.
- **Observation / Audit emission** — every `IToolInvoker.InvokeAsync` call emits exactly one audit record per outcome; volume is bounded by tool invocations.

### Invariants

Adds three:

- **Invariant: agent identity originates at Operator, never at Auth.** Auth validates `AgentPrincipal` claims; it does not mint them. Preserves Invariant 10 ("Auth validates, never issues") for the new principal type. CI gate: a static analyzer rule that flags any direct construction of `AgentPrincipal` outside `HoneyDrunk.Operator`.
- **Invariant: every tool invocation through `IToolInvoker` produces an Audit record.** Granted or denied. If Audit is unavailable, the invocation denies. CI gate: a contract test (per ADR-0047 Tier 2a contract-tests pattern) that exercises the deny-when-audit-unavailable path.
- **Invariant: `bundle:local-dev-all` is loadable only in `local` or `dev` environments.** Loading it in `staging` or `prod` fails Capabilities Node startup. CI gate: a startup-canary test in the prod environment configuration validates the Node refuses to start with the dev bundle in scope.

Additionally:

- **Invariant: Operator cannot grant itself any bundle whose capabilities include `operator.grant.issue:*`.** Enforced at Capabilities Node startup (the recursion check, per D8). CI gate: the startup canary verifies the check fires on a deliberately-corrupted `bundle:grid-operator` definition.

(Final numbering assigned at constitution update time; `hive-sync` reconciles per the ADR-0044 pattern.)

### Operational Consequences

- **Every new tool authored requires a capability declaration.** The `scope` agent's tool-authoring checklist gains a "declare `RequiredCapabilities`" step (cross-ref `constitution/agent-capability-matrix.md`). Tools without explicit requirements default to **deny-all** (the empty required set fails because the principal-type check denies non-agents and there is no agent with the implicit "no requirement" satisfaction path), making the omission loud rather than silent.
- **Every new tool authored requires a bundle update.** Adding a tool to the registry without granting any bundle the right to invoke it makes the tool unreachable. The PR review surface catches this; the `scope` agent's checklist reinforces it.
- **Bundle definitions are PR-reviewed.** Changes to `policies/bundles/` require code review like any other change. This is the v1 review surface for "should this agent have this power"; v2 dynamic stores add an admin-UI review surface but do not remove this one.
- **Operator running as an agent is a chicken-and-egg setup case.** At first bring-up of the Capabilities Node, no agent has any bundle (the bundles are loaded, but no `AgentPrincipal` exists yet). The bootstrap path: a bootstrap script (run once, locally, by the developer) issues the initial `AgentPrincipal` for Operator directly into the Capabilities Node's grant store, bypassing the Operator-issued path. The bootstrap script is the only code path that can do this; subsequent grants flow through Operator. The bootstrap is audited as `event=operator.bootstrap` for a permanent record.
- **Long-running agents (Lately, Hearth) need a renewal workflow.** Operator's renewal workflow is a 30-day cycle that requires explicit re-confirmation. The friction is intentional; the alternative (silent renewal) defeats the time-bound-grant safety property.
- **The `policies/` directory becomes a sensitive review surface.** Changes to capability vocabularies or bundles deserve specialist review (per ADR-0046, the specialist-review agent pattern). A `policy-review` agent specialist is recommended as follow-up.
- **Local development requires running the Capabilities Node locally** (or against a shared dev instance). The InMemory provider per Invariant 15 supports a fake Capabilities Node for unit tests; integration tests use the real Node per the Tier 2a / 2b split (ADR-0047 D4).
- **Authorization-check overhead is single-digit microseconds per invocation** (in-memory dictionary lookups against the resolved bundle set; no cryptographic or network operations). Tool invocation is the user-facing latency, not the authz check.

### Follow-up Work

- Author `AgentPrincipal`, `AgentId`, `AgentRunId`, `CapabilityBundle`, `Capability`, `CapabilityRequirement`, `ScopeBindingMode`, `AuthorizationDeniedException`, `DenyReason` in `HoneyDrunk.Auth.Abstractions` / `HoneyDrunk.Capabilities.Abstractions`.
- Extend `RequestContext` in `HoneyDrunk.Kernel` with the `AgentPrincipal?` slot.
- Implement the bundle-store loader, the `IToolInvoker` authz check, the env-guard, and the recursion check in `HoneyDrunk.Capabilities`.
- Implement the grant/revoke API and the Operator-as-agent bootstrap in `HoneyDrunk.Operator`.
- Wire `AgentPrincipal` propagation through `HoneyDrunk.Agents`' execution loop; surface `AuthorizationDeniedException` as a structured LLM tool error.
- Extend `HoneyDrunk.Audit` event taxonomy with `tool.invoke.granted` / `tool.invoke.denied`.
- Author the initial bundle set: `bundle:lately-content-publisher`, `bundle:netrunner-architecture-sweep`, `bundle:hive-sync`, `bundle:grid-operator`, `bundle:local-dev-all`, plus the per-AI-consumer bundles as they stand up.
- Author the `grid-vocabulary.yaml` enumerating the v1 capability strings.
- Add the static analyzer rule enforcing `AgentPrincipal` construction only inside `HoneyDrunk.Operator`.
- Add the contract test (per ADR-0047 Tier 2a) exercising the "Audit unavailable → tool invocation denies" path.
- Add the startup canary validating the recursion check and the env-guard.
- Update `constitution/invariants.md` with the four new invariants.
- Update `catalogs/contracts.json` with the new public abstractions under Auth and Capabilities.
- Update `constitution/ai-sector-architecture.md` to cross-reference this ADR as the authorization substrate.
- Update `.claude/agents/scope.md` with the "declare `RequiredCapabilities`" step and the "update bundle" step in the tool-authoring checklist.
- Update the standup-ADR template (per ADR-0046) with the "Capability bundle definition" section.
- Author a `policy-review` specialist agent (per ADR-0046) for `policies/bundles/` changes.

## Alternatives Considered

### RBAC roles (single string identifier per agent)

Considered. Map each agent to a role (`role:content-publisher`); the role's permissions are hard-coded. Familiar from .NET's `[Authorize(Roles = "Admin")]`.

Rejected. Roles are too coarse for tool-level scoping. The "Lately publisher can call `publish-post` but not `delete-post`" distinction requires either a proliferation of roles (`role:lately-publisher-no-delete`) or a separate per-tool ACL system on top of roles. Capabilities-as-strings collapse both surfaces into one model that fits tool-level granularity natively. Role-based models also lack the bundle indirection — there is no review surface separating "what this role means" from "who has this role."

### Per-tool ACLs (no bundles, just tool grants)

Considered. Each agent has a list of allowed tools. No abstraction layer.

Rejected for two reasons. First, it does not handle non-tool capabilities (audit append, tenant scoping, secret reads) — every capability has to become a "virtual tool" to fit the model, which is an awkward shoehorn. Second, the lack of bundles means every grant is a fresh review of N tool grants; bundles exist precisely to compress that review surface. The per-tool-ACL model is what you'd build if tool invocation were the only thing agents do, and that's not true.

### Open Policy Agent (OPA) at v1

Considered. Mature, expressive, industry-standard. Rego policies could express the entire model (agent + bundle + intersection + scope) with room to grow.

Rejected as **v1**, recommended as **v2 escalation** (per D13). The reasoning is the same shape as ADR-0040's "App Insights over Honeycomb": v1 doesn't need the polish; the operational surface (sidecar, policy CI pipeline, Rego debugging, version-skew between the policy and the consumer) is real cost; the abstraction is portable to OPA when the simpler model stops fitting. Adopting OPA at v1 for one developer with ~10 bundles is over-investment.

The `IAuthorizationPolicy` extensions in this ADR are designed to be portable to an OPA backing — the bundle resolution and capability evaluation become an OPA query rather than an in-memory check, but the public surface (`IToolInvoker`, `AgentPrincipal`, `CapabilityRequirement`) is unchanged. The v1→v2 swap is a backing change, not an API change.

### A separate `HoneyDrunk.Policies` repo for bundle definitions

Considered. Separating policy from code is a common pattern (keeps the security review surface independent).

Rejected. The bundle definitions are tightly coupled to the Capabilities Node's tool registry — new tools require new bundle grants — and a separate repo would force cross-repo PRs for every tool addition. ADR-0008's PR-flow assumptions and the `scope` agent's packet model both prefer single-repo PRs. The review-surface argument is preserved by adding a `policy-review` specialist agent (per ADR-0046) for `policies/` changes, without splitting the repo.

### Union (not intersection) for delegation

Considered (briefly). Effective capability set = union of bundle and `OnBehalfOf` permissions. The union allows an agent acting on behalf of an admin user to do anything the admin can do.

Rejected. The intersection is the entire safety property of delegation. The union model is what produces "Lately's content agent accidentally deleted the user's account because the user happened to have admin powers." The intersection guarantees the agent **never** exceeds what its bundle allows, even if the granting principal could; and **never** exceeds what the granting principal allows, even if the bundle would. Both bounds are load-bearing.

### Always-on default-allow with deny-list policies

Rejected immediately. Deny-list models in any nontrivial system devolve into "we forgot to add X to the deny list and now every agent can do X." The deny-by-default discipline is non-negotiable for an agent-driven system where the actors are LLM-driven and the failure modes include "the agent picked an action we didn't think it would pick."

### Bake `AgentPrincipal` into `ServicePrincipal` (no third type)

Considered. Treat agents as a flavor of service with `OnBehalfOf` carried as optional state.

Rejected. The audit-time distinction between "a service ran" and "an agent ran inside a service" matters for the AI-sector audit story; conflating them loses that distinction. The `ServicePrincipal` shape would also need optional fields (`agentId`, `agentRunId`, `bundles`) that are meaningless for non-agent services. A separate type is cleaner; the modeling cost is small.

### Grant capabilities directly without bundles

Considered. Agent `X` has capabilities `[notify.send:tenant=acme, data.query.readonly:tenant=acme, audit.append]`. No bundle indirection.

Rejected on the four reasons in D2: review surface (every grant is a fresh review), versioning (no way to pin to a curated set), Operator UX (enumeration of N capabilities vs. small-N bundles), auditability (no stable identifier for the grant source). The bundle indirection costs a small modeling layer and buys all four properties; the trade is clearly worth it.

### Static tool requirements only — no scope binding

Considered. Tools declare required capabilities but capabilities have no scope (`notify.send`, not `notify.send:tenant=acme`). Cross-tenant isolation enforced elsewhere.

Rejected. Tenant-scoping at the capability level is the cleanest place to express it — the same `notify.send` capability can be granted scoped or unscoped, and the `IToolInvoker` check is the single enforcement point. Moving tenant scoping to a separate layer (per-tool tenant-check logic, or middleware) duplicates the check surface and creates ways for tenant-bleed bugs to live.

### Defer the authorization model until Capabilities ships and discover requirements from use

Rejected. Capabilities cannot ship its standup canary without an authorization model — the canary's whole purpose is demonstrating tool authorization. "Defer and discover" produces the same blocker we have today, in a month. The model is concrete enough to commit; commit it.

### Defer to "after Notify Cloud GA" because tenancy is the load-bearing complication

Considered. Notify Cloud is the first real multi-tenant surface; agent-level tenant scoping is most exercised there.

Rejected for the same reason as above plus: the autonomous-agent case (`netrunner`, `hive-sync`) needs tenant scoping immediately (`tenant=studios-internal`), and the AI-sector standup wave needs the authorization model before Notify Cloud GA lands. The model handles the tenancy case from day one; refining it post-GA is acceptable, deferring it pre-GA is not.
