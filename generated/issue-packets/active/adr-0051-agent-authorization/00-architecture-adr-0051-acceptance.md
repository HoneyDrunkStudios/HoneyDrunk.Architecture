---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ai", "docs", "adr-0051", "wave-1"]
dependencies: []
adrs: ["ADR-0051"]
accepts: ["ADR-0051"]
wave: 1
initiative: adr-0051-agent-authorization
node: honeydrunk-architecture
---

# Accept ADR-0051 — flip status, add four authorization invariants, register the initiative

## Summary
Flip ADR-0051 (AI Agent Authorization and Tool Scoping Model) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the four new authorization invariants ADR-0051 commits in its Consequences/Invariants section to `constitution/invariants.md`, and register the `adr-0051-agent-authorization` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0051 decides the Grid's authorization model for AI agents: a third principal type (`AgentPrincipal`), versioned capability bundles granted by the Operator Node, tool-level scoping at the `IToolInvoker` boundary, tenant-composing scope binding, delegated-execution intersection rules, time-bound grants, deny-by-default with typed exceptions, declarative-config v1 bundle storage in the Capabilities repo, and documented escalation paths (dynamic store, OPA) for v2. It was authored 2026-05-22 in the AI-sector authorization-substrate batch.

The ADR's forcing functions: ADR-0017/0018/0020 (Capabilities/Operator/Agents standups) are blocked because their standup canaries demonstrate authorization and have nothing to demonstrate against; ADR-0006's Auth shape does not anticipate agents-as-principals; ADR-0030/0031's Audit substrate requires a first-class agent principal so audit records don't collapse to `principal=anonymous-agent`; Operator is itself an agent and the model must describe its own permissions without enabling recursive escalation; PDR-0001/0003's "on behalf of" semantics need committed delegation rules.

The ADR decides (concise restatement; full text in the ADR):
- **D1** — agents are a first-class principal type. `AgentPrincipal(Id, RunId, OnBehalfOf?, Bundles[], NotAfter)`, issued by Operator, run-bound by `AgentRunId`, composable with `TenantId`.
- **D2** — capability bundles, not raw capability grants. Bundles are namespaced under `bundle:`, versioned (`@v3`), reviewed once and granted by name.
- **D3** — tool scoping via `IToolInvoker` authorization check. Six-step ordered check (resolve tool, extract principal, compute effective capabilities, requirement match with scope resolution, dispatch + audit-granted, or deny + audit-denied).
- **D4** — tenant scoping composes with ADR-0026. Three `ScopeBindingMode`s (`None`, `Tenant`, `OnBehalfOfPrincipal`); `{runtime}` placeholder binds at grant time; reserved `tenant=studios-internal` for cross-Grid agents.
- **D5** — delegation is the **intersection** of bundle capabilities and `OnBehalfOf` permissions. Both bounds are load-bearing safety properties.
- **D6** — time-bound grants with `NotAfter`. Defaults: 1h ad-hoc, 30d long-running, 24h infra-sweep, 8h dev. 90-day upper bound.
- **D7** — tool registry: required capabilities declared in the tool's own type via `CapabilityRequirement[] RequiredCapabilities`. v1 is static (redeploy required); dynamic v2 deferred.
- **D8** — Operator is privileged but **non-recursive**. `bundle:grid-operator@v1` holds grant-issuance but its `operator.grant.issue:bundleName={whitelist}` explicitly excludes `bundle:grid-operator@*`. Capabilities Node startup validates the recursion check; refuses to start on violation.
- **D9** — v1 policy storage: declarative `policies/bundles/*.yaml` + `policies/capabilities/grid-vocabulary.yaml` in the `HoneyDrunk.Capabilities` repo. Loaded + validated at startup; failure fails the canary.
- **D10** — audit record shape for authz decisions (13 fields). Emitted via `IAuditAppender`. Audit unavailable → deny (fail-closed).
- **D11** — deny by default; typed `AuthorizationDeniedException` with structured detail. No "default allow" mode, no debug bypass.
- **D12** — local-dev affordance: `bundle:local-dev-all@v1` with wildcard capabilities, gated by the `environments: [local, dev]` field. Capabilities Node refuses to start if it loads `local-dev-all` in `staging` or `prod`. Operator's whitelist excludes it.
- **D13** — documented escalation paths (dynamic store + admin UI; per-tenant bundles; OPA).
- **D14** — phased rollout (1: abstractions; 2: Capabilities v1; 3: Operator v1; 4: Agents v1; 5: AI consumers; 6: v2 escalations).

ADR-0051 is a **substrate / contract** ADR. The concrete code — `AgentPrincipal` in Kernel, `AuthorizationDeniedException` + deny codes in Auth, Audit event-shape registration, and follow-up Capabilities / Operator / Agents implementations — lands across this initiative's remaining packets and the three AI-sector standup initiatives (`adr-0017-capabilities-standup`, `adr-0018-operator-standup`, `adr-0020-agents-standup`). Every other packet references ADR-0051's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0051-ai-agent-authorization-and-tool-scoping-model.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0051 row Status column to Accepted.
- `constitution/invariants.md` — add four new authorization invariants under a new `## Authorization Invariants` section, numbered **`{N1}, {N2}, {N3}, {N4}`** — the four-wide block reserved for ADR-0051 in `constitution/invariant-reservations.md` (see Constraints).
- `initiatives/active-initiatives.md` — register the `adr-0051-agent-authorization` initiative with the packet checklist for this folder.

## Proposed Implementation

1. Edit the ADR-0051 header: `**Status:** Proposed` → `**Status:** Accepted`.

2. Update the ADR-0051 index row in `adrs/README.md` to Accepted.

3. Read `constitution/invariant-reservations.md` and confirm the four-wide block reserved for ADR-0051 (today: **54–57**). If the reservations file has shifted because another ADR landed first, take the new next-free block and update every `{N1}`/`{N2}`/`{N3}`/`{N4}` placeholder below before committing. The reservations-file row stays "Proposed" until this packet merges, then moves to **Reservation History** with the merge date.

   Add the four new invariants to `constitution/invariants.md`, numbered **`{N1}, {N2}, {N3}, {N4}`**, under a new `## Authorization Invariants` section placed after the `## Audit Invariants` section. The text, taken verbatim-in-substance from ADR-0051's Consequences/Invariants section:

   - **`{N1}` — Agent identity originates at Operator, never at Auth.** The `HoneyDrunk.Operator` Node is the only surface that issues `AgentPrincipal` tokens. Auth validates the principal claims; Auth does not mint them. This preserves invariant 10 ("Auth validates, never issues") for the third principal type. CI gate: a static analyzer rule in `HoneyDrunk.Standards.Analyzers` flags any direct construction of `AgentPrincipal` outside the `HoneyDrunk.Operator` assembly. See ADR-0051 D1, D8.

   - **`{N2}` — Every tool invocation through `IToolInvoker` produces an Audit record.** Granted invocations emit `tool.invoke.granted`; denied invocations emit `tool.invoke.denied`. The record shape is defined by ADR-0051 D10 (13 fields). If the Audit substrate is unavailable, the tool invocation **denies** — silent allow-on-audit-failure is forbidden. CI gate: a contract test (per ADR-0047 Tier 2a) exercises the deny-when-audit-unavailable path. See ADR-0051 D3, D10.

   - **`{N3}` — `bundle:local-dev-all` is loadable only in `local` or `dev` environments.** The `HoneyDrunk.Capabilities` Node reads `ASPNETCORE_ENVIRONMENT` at startup; if `bundle:local-dev-all` is present in the loaded bundle set and the environment is `staging` or `prod`, the Node refuses to start, emits a fatal log line, and exits non-zero. The check is at startup, not at grant time. Operator's whitelist further excludes `bundle:local-dev-all` from any grant path, so the bundle cannot leak into deployed environments via API. CI gate: a startup-canary test in the prod environment configuration validates the Node refuses to start with the dev bundle in scope. See ADR-0051 D12.

   - **`{N4}` — Operator cannot grant itself any bundle whose capabilities include `operator.grant.issue:*`.** The grant-issuance capability is whitelisted to bundle names that exclude `bundle:grid-operator@*`. The Capabilities Node validates this recursion property at startup by walking `bundle:grid-operator`'s whitelist and verifying no whitelisted bundle's capability set contains `operator.grant.issue:*`. Violation fails the standup canary, which fails CI per ADR-0011. The cycle is broken structurally; Operator can grant other agents new capabilities, but it cannot escalate itself even with a bug or a misconfigured grant. See ADR-0051 D8.

4. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0051-ai-agent-authorization-and-tool-scoping-model.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md` — the ADR-0051 row in **Active Reservations** is populated by this packet's PR (or already populated by an upstream authoring commit; verify) and moved to **Reservation History** on merge
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0051 header reads `**Status:** Accepted`
- [ ] The ADR-0051 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariants.md` carries four new authorization invariants (agent identity originates at Operator; every tool invocation through `IToolInvoker` produces an Audit record; `bundle:local-dev-all` is loadable only in local/dev; Operator cannot grant itself the grant-issuance capability), numbered **`{N1}, {N2}, {N3}, {N4}`** (claimed from `constitution/invariant-reservations.md`) under a new `## Authorization Invariants` section, each citing ADR-0051
- [ ] `constitution/invariant-reservations.md` has an ADR-0051 row in **Active Reservations** with the four-wide block this packet consumed; on merge, the row is moved to **Reservation History** with the merge date
- [ ] `initiatives/active-initiatives.md` registers the `adr-0051-agent-authorization` initiative with a packet checklist
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)
- [ ] No `.claude/agents/scope.md` change in this packet (that update lands in packet 02)

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0051 D1 — Three principal types.** The Grid commits to `UserPrincipal` (Auth-issued, session-bound), `ServicePrincipal` (Auth-issued, process-bound), and `AgentPrincipal` (Operator-issued, run-bound). `AgentPrincipal` carries `AgentId` (stable across runs), `AgentRunId` (per-invocation), optional `OnBehalfOf` (delegated User/Service principal), the granted `CapabilityBundleRef[]`, and `NotAfter` expiry.

**ADR-0051 D8 — Non-recursive Operator.** `bundle:grid-operator@v1` includes `operator.grant.issue:bundleName={whitelist}` where the whitelist excludes `bundle:grid-operator@*`. Capabilities Node startup walks the whitelist and rejects any bundle whose capabilities include `operator.grant.issue:*`. Refuses to start on violation.

**ADR-0051 D10 — Audit shape.** 13 fields including `event` (`tool.invoke.granted` / `tool.invoke.denied`), `agent.id`, `agent.runId`, `agent.bundles`, `onBehalfOf.*`, `tenant.id`, `tool.name`, `tool.requiredCapabilities`, `effective.capabilities`, `decision`, `deny.reason`, `deny.missingCapability`, `timestamp`, `traceId`. Emitted via `IAuditAppender`; fail-closed when Audit is unavailable.

**ADR-0051 D11 — Deny by default.** Empty effective capability set denies every invocation. Expired grants deny. Non-agent principals invoking the tool surface deny with `principal_type_mismatch`. `AuthorizationDeniedException` is the single typed exception with structured detail.

**ADR-0051 D12 — `bundle:local-dev-all` env-guard.** The bundle's `environments: [local, dev]` field is enforced at Capabilities Node startup against `ASPNETCORE_ENVIRONMENT`. Production startup with this bundle in scope refuses to start. Operator's whitelist also excludes it.

**ADR-0051 Consequences — Invariants.** ADR-0051 adds exactly four invariants in its Consequences section: (1) agent identity originates at Operator; (2) every tool invocation through `IToolInvoker` produces an Audit record (deny on Audit unavailable); (3) `bundle:local-dev-all` is loadable only in local/dev; (4) Operator cannot grant itself the grant-issuance capability.

## Acceptance Notes — Implementation Deviations

These are scoped, time-bound deviations from ADR-0051's literal text that downstream packets carry. Accepting this packet implicitly accepts the deviations below; they are not amendments to the ADR. A future Auth amendment (or a follow-up packet) is expected to close each one.

- **Placeholder `OnBehalfOfPrincipal` record (Packet 03 / Kernel.Abstractions).** ADR-0051 D1 names `Principal? OnBehalfOf` referencing the typed `UserPrincipal` / `ServicePrincipal` siblings of a `Principal` base. Those types do not exist in `HoneyDrunk.Auth.Abstractions` today, and introducing them would expand this initiative beyond agent authorization. Packet 03 ships a small dedicated record `OnBehalfOfPrincipal(string Kind, string Id, string? TenantId)` as a structurally-equivalent placeholder carrying exactly the fields ADR-0051 D10's audit shape (`onBehalfOf.type`, `onBehalfOf.id`) consumes — nothing more. The placeholder is removed (or upgraded to a typed `Principal` reference) when the named `Principal`/`UserPrincipal`/`ServicePrincipal` base lands in a separate Auth amendment. This packet does NOT introduce `UserPrincipal` / `ServicePrincipal` / `Principal` types. Packet 03 must mark `OnBehalfOfPrincipal` in its XML doc as `[Obsolete-on-arrival-of-Principal-base]` semantics — i.e., a `<remarks>` block calling out the deferred rename so a future executor doesn't mistake the placeholder for the final shape.

## Constraints
- **Acceptance precedes flip.** ADR-0051 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers are claimed from `constitution/invariant-reservations.md`.** The current verified maximum in `constitution/invariants.md` is **53**. ADR-0051 has reserved the next four-wide block in `invariant-reservations.md` (today: **54–57**, used as `{N1}/{N2}/{N3}/{N4}`). Before committing, the executor (a) re-reads `invariant-reservations.md`, (b) confirms ADR-0051's row still holds a contiguous four-wide block, (c) substitutes the four `{N*}` placeholders in this packet body with the actual numbers, (d) writes the same numbers into `constitution/invariants.md`, and (e) on merge, moves the row from **Active Reservations** to **Reservation History** with the merge date. If a collision shifted the block, take the new next-free contiguous block and update both files in the same commit. Do not renumber existing invariants; never reuse a claimed number.
- **New section.** The four authorization invariants are a new cross-cutting topic; create a `## Authorization Invariants` section after `## Audit Invariants` rather than appending to an unrelated section.
- **Catalog edits do not happen in this packet.** Packet 01 owns `catalogs/*.json` reconciliation; packet 02 owns the `.claude/agents/scope.md` update. Keep this packet's blast radius to ADR + invariants + initiative tracker.

## Labels
`chore`, `tier-3`, `ai`, `docs`, `adr-0051`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0051 to Accepted, add the four authorization invariants to `constitution/invariants.md`, and register the agent-authorization initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0051 so the remaining packets in this initiative — and the three AI-sector standup initiatives that consume it — can reference its decisions as live rules.
- Feature: ADR-0051 AI Agent Authorization rollout, Wave 1.
- ADRs: ADR-0051 (primary), ADR-0006 (Auth contract surface this composes with), ADR-0008 (initiative/packet conventions), ADR-0030/0031 (Audit substrate this emits to).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0051 stays Proposed until this PR merges.
- Claim the four-wide invariant block from `constitution/invariant-reservations.md` (today: **54–57**; use as `{N1}/{N2}/{N3}/{N4}`) and substitute the actual numbers before commit. Add the four new invariants under a new `## Authorization Invariants` section; do not renumber existing invariants. Current verified max in `invariants.md` is 53. If a collision shifted the block, take the new next-free contiguous range and update both files in the same commit. Never reuse a claimed number.
- Inline the full invariant text — do not just cite "see ADR-0051 D8." The constitution must be self-contained for readers who do not load the ADR.
- No catalog edits in this packet; packet 01 owns that.
- No `.claude/agents/scope.md` edit in this packet; packet 02 owns that.

**Key Files:**
- `adrs/ADR-0051-ai-agent-authorization-and-tool-scoping-model.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
