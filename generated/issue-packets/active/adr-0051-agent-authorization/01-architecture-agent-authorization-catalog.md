---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ai", "docs", "adr-0051", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0051"]
accepts: ["ADR-0051"]
wave: 1
initiative: adr-0051-agent-authorization
node: honeydrunk-architecture
---

# Register the agent-authorization contract surface in the Grid catalogs

## Summary
Record ADR-0051's new contract surface as catalog data: register `AgentPrincipal`, `AgentId`, `AgentRunId`, and the `IOperationContext.Agent` extension under the `honeydrunk-kernel` Node in `catalogs/contracts.json`; register `AuthorizationDeniedException` and the extended `AuthorizationDenyCode` enum members under `honeydrunk-auth`; register the `tool.invoke.granted` and `tool.invoke.denied` event names under `honeydrunk-audit`; append the new type names to the matching `exposes.contracts` arrays in `catalogs/relationships.json`; update `consumes_detail` for Nodes that pick up new dependencies; and refresh the `repos/HoneyDrunk.Capabilities/`, `repos/HoneyDrunk.Operator/`, `repos/HoneyDrunk.Agents/` integration-points docs to reflect the authorization substrate they now consume.

## Context
ADR-0051 commits new contracts in three live repos and additions to the in-flight Capabilities/Operator/Agents standup tracks. The Grid catalogs are the discoverability surface — `catalogs/contracts.json` registers each Node's contracts in its node block's `interfaces` array, and `catalogs/relationships.json` lists each Node's contract names under `exposes.contracts` plus `consumes_detail` per consumer. (`catalogs/nodes.json` has **no** `exposes` field — the `exposes` object lives on relationships.json entries.) This packet keeps both catalogs accurate so the implementation packets (03, 04, 05) and the downstream Capabilities/Operator/Agents standup packets read an accurate contract/dependency graph.

ADR-0051 names `CapabilityBundle`, `Capability`, `CapabilityRequirement`, `ScopeBindingMode`, `CapabilityBundleRef`, and the `RequiredCapabilities` extension to `ICapabilityInvoker` for `HoneyDrunk.Capabilities.Abstractions`. The Capabilities repo is currently a stub (LICENSE + README); these types ship via the `adr-0017-capabilities-standup` packet 04 scaffold, not this initiative. This packet **does not** register those types under `honeydrunk-capabilities` — that registration lands inside the Capabilities standup track's catalog-registration packet (already filed as packet 01 there, with its own scope to amend at execution time per the dispatch plan's Follow-Up Work). What this packet **does** do for Capabilities is update `repos/HoneyDrunk.Capabilities/integration-points.md` to record that the Node consumes `AgentPrincipal` from Kernel and `AuthorizationDeniedException` from Auth, and emits the `tool.invoke.*` audit events.

This is a catalog/docs packet. No code, no .NET project.

## Scope

- **`catalogs/contracts.json`** — three node blocks updated:
  - `honeydrunk-kernel`: append `AgentPrincipal`, `AgentId`, `AgentRunId` to the `interfaces` array; record the `IOperationContext.Agent` member extension as a note on the existing `IOperationContext` entry (or append a sub-entry per the existing file's convention).
  - `honeydrunk-auth`: append `AuthorizationDeniedException` to the `interfaces` array. Note the additive enum extension on the existing `AuthorizationDenyCode` entry (four new members: `CapabilityMissing`, `ScopeMismatch`, `GrantExpired`, `PrincipalTypeMismatch`).
  - `honeydrunk-audit`: register the two new event names `tool.invoke.granted` and `tool.invoke.denied` in the event-shape registry section (matching the existing event registry conventions; if the file does not yet model events explicitly, add a short `events` section under `honeydrunk-audit` listing the event names with a one-line shape note pointing to ADR-0051 D10).

- **`catalogs/relationships.json`**:
  - Append `AgentPrincipal`, `AgentId`, `AgentRunId` to the `honeydrunk-kernel` entry's `exposes.contracts` array.
  - Append `AuthorizationDeniedException` to the `honeydrunk-auth` entry's `exposes.contracts` array.
  - Update `consumes_detail` for the Nodes that consume the new contracts: `honeydrunk-capabilities` (consumes `AgentPrincipal` from Kernel and `AuthorizationDeniedException` + the extended `AuthorizationDenyCode` from Auth — the Capabilities standup track is in flight); `honeydrunk-operator` (consumes `AgentPrincipal` from Kernel; emits `AgentPrincipal` per D1/D8); `honeydrunk-agents` (consumes `AgentPrincipal` from Kernel and `AuthorizationDeniedException` from Auth); `honeydrunk-audit` (consumes `AgentPrincipal` to record agent identity in audit fields). No new top-level Node-to-Node edge is created — every affected Node already consumes `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Auth.Abstractions`.

- **`catalogs/nodes.json`** — **not edited.** nodes.json entries have no `exposes` field; the contract surface lives in relationships.json and contracts.json.

- **`repos/HoneyDrunk.Capabilities/integration-points.md`** — add an "Authorization substrate" section noting:
  - Consumes `AgentPrincipal` from `HoneyDrunk.Kernel.Abstractions` for the principal-type check at `IToolInvoker.InvokeAsync`.
  - Consumes `AuthorizationDeniedException` + the extended `AuthorizationDenyCode` from `HoneyDrunk.Auth.Abstractions` to throw typed deny errors.
  - Emits `tool.invoke.granted` / `tool.invoke.denied` events to `HoneyDrunk.Audit` per ADR-0051 D10.
  - Loads `policies/bundles/*.yaml` and `policies/capabilities/grid-vocabulary.yaml` at startup; runs the recursion check on `bundle:grid-operator` (ADR-0051 D8) and the env-guard on `bundle:local-dev-all` (ADR-0051 D12).
  - Cross-references ADR-0051 (substrate) and ADR-0017 (Capabilities standup).

- **`repos/HoneyDrunk.Operator/integration-points.md`** — create this file if it does not yet exist (the Operator standup track adds it; if absent at execution time, create it with the standard integration-points template matching `repos/HoneyDrunk.Agents/integration-points.md`). Add an "Authorization substrate" section noting:
  - Issues `AgentPrincipal` tokens via the grant API (`POST /grants`); revokes via `DELETE /grants/{grantId}`.
  - Runs `bundle:grid-operator@v1` as an agent against the Capabilities Node it administers.
  - Operator's bundle is non-recursive: `operator.grant.issue:bundleName={whitelist}` excludes `bundle:grid-operator@*` (ADR-0051 D8).
  - Bootstrap path: a one-time local script seeds the initial `AgentPrincipal` for Operator directly into the Capabilities Node's grant store, audited as `event=operator.bootstrap`.
  - Cross-references ADR-0051 and ADR-0018.

- **`repos/HoneyDrunk.Agents/integration-points.md`** — add an "Authorization substrate" section noting:
  - Carries `AgentPrincipal` through the execution loop on the `IOperationContext` (ADR-0051 D1; this initiative's packet 03 ships the slot).
  - Invokes tools through `IToolInvoker`; the registry-level authz check is enforced by the Capabilities Node, not by Agents.
  - Catches `AuthorizationDeniedException` and surfaces it to the LLM as a structured tool-result error: `{"error": "authorization_denied", "missing": "<capability>"}` (ADR-0051 D11).
  - Cross-references ADR-0051 and ADR-0020.

## Proposed Implementation

1. **`catalogs/contracts.json`** — locate the `honeydrunk-kernel`, `honeydrunk-auth`, `honeydrunk-audit` node blocks (do not rely on line numbers). For each, append entries to the `interfaces` array matching the existing `{ "name", "kind", "description" }` shape. Records drop the `I`; interfaces keep the `I`. Examples:
   - `AgentPrincipal` — `kind: type` — "Record. The Operator-issued principal for an AI agent invocation. Carries AgentId, AgentRunId, optional OnBehalfOf principal, the granted CapabilityBundleRef[], and NotAfter expiry."
   - `AgentId` — `kind: type` — "Record. Stable string identifier for an agent across runs (e.g., lately-content-publisher)."
   - `AgentRunId` — `kind: type` — "Record. Guid per agent invocation, used for correlation and audit."
   - `AuthorizationDeniedException` — `kind: type` — "Typed exception thrown by IToolInvoker when authorization fails. Carries the DenyReason, the missing capability (if applicable), the tool name, and the agent identity."
   - Note `AuthorizationDenyCode` is an existing entry; the four new enum members (`CapabilityMissing`, `ScopeMismatch`, `GrantExpired`, `PrincipalTypeMismatch`) are additive — record them in a sub-note under the existing entry rather than re-entering it.
   - For Audit's event-shape registry, add `tool.invoke.granted` and `tool.invoke.denied` with a one-line shape pointer to ADR-0051 D10's 13-field table.

2. **`catalogs/relationships.json`** — append the new type names to `honeydrunk-kernel`/`honeydrunk-auth` `exposes.contracts`. Do not touch existing entries. Then update `consumes_detail` for `honeydrunk-capabilities`, `honeydrunk-operator`, `honeydrunk-agents`, `honeydrunk-audit` as listed in Scope. Do not add a new top-level edge.

3. **`catalogs/nodes.json`** — no edit.

4. **`repos/HoneyDrunk.Capabilities/integration-points.md`** — add the "Authorization substrate" section (the file already exists if the ADR-0017 catalog packet has run; if it does not, this is where it ought to land per ADR-0017's intent — check at execution time and create with the standard template if absent).

5. **`repos/HoneyDrunk.Operator/integration-points.md`** — create if absent, add the "Authorization substrate" section.

6. **`repos/HoneyDrunk.Agents/integration-points.md`** — add the "Authorization substrate" section. The file already exists.

7. Do not touch ADR-0017/0018/0020's existing integration-points content beyond the targeted section addition — the standup tracks may be amending these files in parallel; keep the diffs scoped.

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `repos/HoneyDrunk.Capabilities/integration-points.md` (create if absent)
- `repos/HoneyDrunk.Operator/integration-points.md` (create if absent)
- `repos/HoneyDrunk.Agents/integration-points.md`

## NuGet Dependencies
None. This packet touches only catalog JSON and Markdown; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Catalog data + per-repo integration-points docs only — the Kernel/Auth/Audit code lands in packets 03–05; the Capabilities/Operator/Agents code lands in those Nodes' own standup initiatives.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` registers `AgentPrincipal`, `AgentId`, `AgentRunId` under `honeydrunk-kernel`, matching the existing entry shape
- [ ] `catalogs/contracts.json` registers `AuthorizationDeniedException` under `honeydrunk-auth`; the existing `AuthorizationDenyCode` entry is annotated with the four new enum members
- [ ] `catalogs/contracts.json` registers `tool.invoke.granted` and `tool.invoke.denied` event shapes under `honeydrunk-audit` per ADR-0051 D10
- [ ] `catalogs/relationships.json` lists the new type names in `honeydrunk-kernel` and `honeydrunk-auth` `exposes.contracts` arrays, all existing entries untouched
- [ ] `catalogs/relationships.json` `consumes_detail` for `honeydrunk-capabilities`, `honeydrunk-operator`, `honeydrunk-agents`, `honeydrunk-audit` lists the new contracts each consumes
- [ ] `catalogs/nodes.json` is NOT modified (it has no `exposes` field)
- [ ] No new top-level Node-to-Node edge is created (the dependency on `HoneyDrunk.Kernel.Abstractions` / `HoneyDrunk.Auth.Abstractions` already exists for all affected Nodes)
- [ ] `repos/HoneyDrunk.Capabilities/integration-points.md` has an "Authorization substrate" section listing the four ADR-0051 consumption points (AgentPrincipal, AuthorizationDeniedException, audit emissions, policies/ loading + recursion + env-guard)
- [ ] `repos/HoneyDrunk.Operator/integration-points.md` exists (created if absent) with an "Authorization substrate" section
- [ ] `repos/HoneyDrunk.Agents/integration-points.md` has an "Authorization substrate" section listing AgentPrincipal propagation and AuthorizationDeniedException handling
- [ ] No `CapabilityBundle` / `Capability` / `CapabilityRequirement` / `ScopeBindingMode` / `CapabilityBundleRef` / `RequiredCapabilities` registration under `honeydrunk-capabilities` in this packet — those land via `adr-0017-capabilities-standup` (see dispatch-plan Follow-Up Work)
- [ ] No invariant change in this packet (invariants land in packet 00)
- [ ] No `.claude/agents/scope.md` change in this packet (that update lands in packet 02)

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0051 D1 — Three principal types.** `AgentPrincipal(Id, RunId, OnBehalfOf?, Bundles[], NotAfter)`, Operator-issued, run-bound. Flows through the per-operation context.

**ADR-0051 D8 — Non-recursive Operator.** `bundle:grid-operator@v1` whitelist excludes `bundle:grid-operator@*`; the recursion is broken structurally. Capabilities Node startup validates the property.

**ADR-0051 D10 — Audit shape.** 13-field record per authz decision, emitted via `IAuditAppender`, names `tool.invoke.granted` and `tool.invoke.denied`. Fail-closed when Audit is unavailable.

**ADR-0051 D11 — `AuthorizationDeniedException`.** Single typed exception with structured detail (`Reason`, `MissingCapability`, `ToolName`, `AgentId`). The Agents Node execution loop catches and surfaces to the LLM as a structured tool error.

**ADR-0051 D12 — `bundle:local-dev-all` env-guard.** Capabilities Node refuses to start if `bundle:local-dev-all` is loaded with `ASPNETCORE_ENVIRONMENT` in `staging` or `prod`. Operator's whitelist also excludes it.

**ADR-0051 Consequences — Affected Nodes.** `HoneyDrunk.Auth` (Abstractions gain `AgentPrincipal` and related types; runtime unchanged at v1 — Auth does not issue agent tokens). `HoneyDrunk.Capabilities` (primary affected; implements the authz check + bundle store + env-guard + recursion check). `HoneyDrunk.Operator` (primary affected; implements grant/revoke + bootstrap). `HoneyDrunk.Agents` (primary affected; execution loop carries the principal). `HoneyDrunk.Audit` (extends event taxonomy). `HoneyDrunk.Kernel` (`IOperationContext` gains the slot — this packet's authority).

## Constraints

- **Records drop the `I`, interfaces keep it.** Grid-wide naming rule: `AgentPrincipal`, `AgentId`, `AgentRunId` are records (no `I`); `IOperationContext` is an interface; `AuthorizationDeniedException` is a class.
- **Do not register Capabilities.Abstractions types in this packet.** `CapabilityBundle`, `Capability`, `CapabilityRequirement`, `ScopeBindingMode`, `CapabilityBundleRef`, and the `RequiredCapabilities` extension are shipped by `adr-0017-capabilities-standup` packet 04 (the Capabilities scaffold). Registering them here would duplicate the catalog entries that scaffold packet will create.
- **No new Node-to-Node edge.** Every affected Node already consumes `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Auth.Abstractions`. The contracts are additive; only `consumes_detail` is enriched, not the edge list.
- **nodes.json is NOT edited.** It has no `exposes` field.

## Labels
`feature`, `tier-2`, `ai`, `docs`, `adr-0051`, `wave-1`

## Agent Handoff

**Objective:** Register ADR-0051's authorization contract surface in the Grid catalogs and update the per-Node integration-points docs that consume it.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Keep the contract/dependency catalogs accurate so implementation packets 03–05 and the downstream Capabilities/Operator/Agents standup packets read a correct graph.
- Feature: ADR-0051 AI Agent Authorization rollout, Wave 1.
- ADRs: ADR-0051 D1/D8/D10/D11/D12 (primary), ADR-0017/0018/0020 (standup tracks this catalog supports), ADR-0030/0031 (Audit substrate).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0051 should be Accepted before its contract surface is recorded as catalog data.

**Constraints:**
- Records drop the `I`; interfaces keep it.
- Do not register `Capabilities.Abstractions` types here — those land via `adr-0017-capabilities-standup`.
- No new top-level Node-to-Node edge — only `consumes_detail` enrichment.
- nodes.json is NOT edited — it has no `exposes` field.
- Scope the integration-points file edits to the targeted "Authorization substrate" sections; do not touch unrelated content (the standup tracks may be editing those files in parallel).

**Key Files:**
- `catalogs/contracts.json` — new entries in the `honeydrunk-kernel`, `honeydrunk-auth`, `honeydrunk-audit` blocks.
- `catalogs/relationships.json` — `exposes.contracts` additions and `consumes_detail` enrichment.
- `repos/HoneyDrunk.Capabilities/integration-points.md`, `repos/HoneyDrunk.Operator/integration-points.md`, `repos/HoneyDrunk.Agents/integration-points.md` — "Authorization substrate" sections.

**Contracts:** None changed — this packet only records catalog metadata for contracts that packets 03–05 (and the AI-sector standup tracks) implement.
