# Dispatch Plan — ADR-0051: AI Agent Authorization and Tool Scoping Model

**Initiative:** `adr-0051-agent-authorization`
**ADR:** ADR-0051 (Proposed → Accepted via packet 00)
**Sector:** AI / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0051 commits the Grid to a Phase 1–6 authorization model for AI agents: a third principal type (`AgentPrincipal`), versioned capability bundles granted by Operator, tool-level scoping at `IToolInvoker`, tenant-composing scope binding, delegated-execution intersection rules, time-bound grants, deny-by-default, and a declarative-config v1 bundle store with documented escalation paths.

The ADR's Phase 1 names a contract-only deliverable across `HoneyDrunk.Auth.Abstractions`, `HoneyDrunk.Capabilities.Abstractions`, and `HoneyDrunk.Kernel`. Phases 2–4 are the *runtime implementations* in the Capabilities, Operator, and Agents Nodes — all three of which currently live in **separate, in-flight standup initiatives** (`adr-0017-capabilities-standup`, `adr-0018-operator-standup`, `adr-0020-agents-standup`) whose scaffold packets have not yet executed. Per the user's standing convention ("New-Node / standup work gets its own ADR; don't bundle scaffold into feature packets"), this initiative ships **the governance, the abstractions in live Nodes, and the Audit event taxonomy** — and **defers the Capabilities runtime, the Operator grant API, the Agents execution-loop wiring, and the static-analyzer rule** to those Nodes' own standup tracks, which consume what ADR-0051 ships.

This initiative delivers: ADR acceptance + four new invariants + initiative registration (Architecture); catalog registration of the new contract surface (Architecture); `.claude/agents/scope.md` tool-authoring checklist + standup template update (Architecture); the `AgentPrincipal` / `AgentId` / `AgentRunId` types and context propagation slot in `HoneyDrunk.Kernel.Abstractions` (Kernel); the `AuthorizationDeniedException` plus extension of the existing `AuthorizationDenyCode` enum with the four new deny reasons in `HoneyDrunk.Auth.Abstractions` (Auth); and the `tool.invoke.granted` / `tool.invoke.denied` event-shape registration in `HoneyDrunk.Audit` (Audit).

**6 packets across 3 waves**, targeting **4 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Kernel`, `HoneyDrunk.Auth`, `HoneyDrunk.Audit`). All 6 are `Actor=Agent`, 0 `Actor=Human`. Packets 03 and 04 carry a Human Prerequisite (a human git-tag/release of the upstream Kernel and Auth NuGet packages so the downstream standup tracks can compile against them), but the *code* work is fully delegable.

## Trigger

ADR-0051 is Proposed with no scope. The forcing functions from the ADR's Context:

- **AI-sector standup blocker.** ADR-0017 (Capabilities), ADR-0018 (Operator), and ADR-0020 (Agents) are all Proposed and gesture at a "`// TODO: authorization model`" — Capabilities and Agents cannot ship their standup canaries without it. The standup canaries' purpose is *demonstrating tool authorization*, and there is nothing to demonstrate against.
- **ADR-0006 (Auth) does not anticipate agents-as-principals.** Adding a third principal type is not a hot-fix; it needs a committed shape before any consumer writes against it.
- **Invariant 10 ("Auth validates, never issues") must hold for agents.** Operator originates agent identity; Auth validates. The boundary is non-negotiable and shaped D8 substantively.
- **ADR-0030 (Audit, Accepted) and ADR-0031 (Audit standup, in flight) require every agent action to be audited with a first-class principal.** Without `AgentPrincipal`, every audit record from agent execution would degrade to `principal=anonymous-agent`, collapsing the AI-sector audit story.
- **Operator (ADR-0018) is itself an agent.** The granting surface must be expressive enough to describe Operator's own permissions without enabling recursive escalation — D8 of the ADR.

The model is concrete enough to commit; decompose it and ship the contract floor.

## Scope Detection

**Multi-repo, multi-Node — but bounded.** The contract surface lands in `HoneyDrunk.Kernel.Abstractions` (the zero-dependency contract layer every Node already consumes — same precedent as `IGridContext`, `TenantId`, idempotency types), `HoneyDrunk.Auth.Abstractions` (the established home of `IAuthorizationPolicy`, `AuthorizationDenyCode`, etc.), and `HoneyDrunk.Audit` (event-shape registry). `HoneyDrunk.Architecture` carries governance, catalogs, and the `scope.md` / standup-template update.

**Capabilities.Abstractions types are NOT shipped here.** The ADR D14 Phase 1 also names `CapabilityBundle`, `Capability`, `CapabilityRequirement`, `ScopeBindingMode`, `CapabilityBundleRef` for `HoneyDrunk.Capabilities.Abstractions`. The Capabilities repo is empty (LICENSE + README only); its scaffold lands in `adr-0017-capabilities-standup` packet 04. This initiative does NOT inject types into an empty repo — that violates the "standup work gets its own ADR" rule and would create an ordering hazard for the in-flight Capabilities standup track. Those types belong in the Capabilities scaffold, and that scaffold's packet must be amended to ship the ADR-0051 contracts as part of its first commit. See Cross-Cutting Concerns for the amendment surface.

**Contract is additive — no forced downstream cascade.** Every type this initiative ships is *additive* to `HoneyDrunk.Kernel.Abstractions` / `HoneyDrunk.Auth.Abstractions` (the four new `AuthorizationDenyCode` values are additive to the enum; new types are additive). Per ADR-0035, this is an additive minor bump (`HoneyDrunk.Kernel` `0.7.0` → `0.8.0`; `HoneyDrunk.Auth` to the next minor version), not a breaking change. Downstream Nodes consuming these Abstractions are not *forced* to update — they adopt the contract when their own authorization paths are amended in their own initiatives.

**No new-Node scaffolding.** Every target repo in *this* initiative is a live, scaffolded Node. No empty cataloged repo is touched. The new-Node work for Capabilities/Operator/Agents stays in the existing standup initiatives.

## Cross-Cutting Concerns

### Mapping ADR-0051's "`RequestContext`" to the Grid's actual context contracts

ADR-0051 D1 says `AgentPrincipal` "flows through `RequestContext` (the existing carrier for `UserPrincipal` / `ServicePrincipal` per ADR-0006)." There is no type named `RequestContext` in the codebase, and the named "existing" `UserPrincipal` / `ServicePrincipal` types **also do not exist today**. The Grid's actual context contracts are `IGridContext` / `IOperationContext` in `HoneyDrunk.Kernel.Abstractions/Context/` and the authentication surface in `HoneyDrunk.Auth.Abstractions` (`AuthenticatedIdentity`, `IAuthorizationPolicy`, `AuthorizationRequest`, `AuthorizationDecision`).

**Decided, not deferred:** the `AgentPrincipal` slot lives on `IOperationContext` (the per-operation context — short-lived, matching `AgentRunId`'s per-invocation lifetime), exposed as an optional `AgentPrincipal? Agent { get; }` member. The longer-lived `IGridContext` carries Grid-level identity (Node, Sector, Environment); per-operation principals belong on `IOperationContext`. `UserPrincipal` and `ServicePrincipal` as named types are **deferred** to a future Auth amendment — Auth's existing `AuthenticatedIdentity` already carries the human/service identity story under a different shape, and forcing the three-principal-type renaming today is out of scope. Packet 03 ships `AgentPrincipal` as a standalone record; the `Principal` abstract base class named by the ADR is also deferred until the matching `UserPrincipal` / `ServicePrincipal` types arrive in their own initiative. This is recorded so the operator does not file a packet against a non-existent type.

### `DenyReason` naming collision

ADR-0051 D11 declares a new `DenyReason` enum carrying `capability_missing`, `scope_mismatch`, `grant_expired`, `principal_type_mismatch`. **A `DenyReason` type already exists** in `HoneyDrunk.Auth.Abstractions/DenyReason.cs` — a `readonly record struct` combining `AuthorizationDenyCode` (the existing enum) and `string Message`. The collision is real.

**Decided, not deferred:** packet 04 extends the existing `AuthorizationDenyCode` enum with four new members — `CapabilityMissing`, `ScopeMismatch`, `GrantExpired`, `PrincipalTypeMismatch` — and reuses the existing `DenyReason` record struct as the carrier. `AuthorizationDeniedException` (genuinely new) takes a `DenyReason` directly, so it composes with the existing surface rather than fragmenting it. This is cleaner than introducing a parallel enum and aligns with the Auth conventions already in place. Packet 04 references the existing types by name and adds enum members; no parallel structure is created.

### Capabilities.Abstractions types — deferred to ADR-0017 standup, amendment required

ADR-0051 D2/D3 names `CapabilityBundle`, `Capability`, `CapabilityRequirement`, `ScopeBindingMode`, `CapabilityBundleRef`, and `IToolInvoker`'s extension with `RequiredCapabilities` for `HoneyDrunk.Capabilities.Abstractions`. ADR-0017's packet 04 (the Capabilities scaffold) already names the four exposed contracts — `ICapabilityRegistry`, `CapabilityDescriptor`, `ICapabilityInvoker`, `ICapabilityGuard` — and lands them in the first commit. The ADR-0051 types belong in that same scaffold as additions to packet 04's contract list.

**Two notes are required to keep ADR-0017 and ADR-0051 consistent:**

1. ADR-0017 standup packet 04 must be **amended at execution time** to additionally ship `CapabilityBundle`, `Capability`, `CapabilityRequirement`, `ScopeBindingMode`, `CapabilityBundleRef`, and the `RequiredCapabilities` extension on `ICapabilityInvoker`'s parameters surface. The amendment must reference ADR-0051's acceptance (packet 00 in this initiative) as a hard dependency so the bundle types land in the same commit as the registry types.
2. The Capabilities Node also implements the **bundle-store loader, the `IToolInvoker` authorization check, the env-guard, and the recursion check** (ADR-0051 D3, D8, D9, D12). These are the Phase 2 deliverables in ADR-0051's D14 phased rollout. They are appropriately Capabilities-Node implementation work — they do not fit *this* initiative's "abstractions only" scope and they cannot be filed against an empty repo. The right home is **a follow-up packet inside `adr-0017-capabilities-standup`** that lands *after* the standup scaffold (packet 04 there) closes. The follow-up packet's draft is named explicitly in this initiative's Follow-Up Work section as a tracked item.

**Operator grant/revoke API + bootstrap + `bundle:grid-operator` recursion check (D8)** — deferred to `adr-0018-operator-standup`, similarly amended/followed up. **Agents execution loop wiring + `AuthorizationDeniedException` → structured LLM tool error (D11 / D14 Phase 4)** — deferred to `adr-0020-agents-standup`.

This split honors invariant 24 (packet immutability) for already-filed packets in those tracks: the *amendments* are to packet **drafts** not yet filed, which is permissible until the file-work-items workflow runs.

### Static analyzer rule — deferred to Operator standup

ADR-0051 names an analyzer rule that flags direct construction of `AgentPrincipal` outside `HoneyDrunk.Operator`. The analyzer is a `HoneyDrunk.Standards.Analyzers` change, but its enforcement target is `HoneyDrunk.Operator`. The analyzer rule cannot be authored until the analyzer's target type exists (packet 03 here) AND the protected Node exists (Operator's scaffold). The right home is the Operator standup track; recorded here as a follow-up.

### `tool.invoke.granted` / `tool.invoke.denied` audit event taxonomy

ADR-0051 D10 specifies the exact audit-record shape: 13 fields including `event`, `agent.id`, `agent.runId`, `agent.bundles`, `onBehalfOf.*`, `tenant.id`, `tool.name`, `tool.requiredCapabilities`, `effective.capabilities`, `decision`, `deny.reason`, `deny.missingCapability`, `timestamp`, `traceId`. The Audit Node (live, v0.1.0 per the ADR-0031 standup track) maintains an event-shape registry per ADR-0030/0031's contract. Packet 05 extends the registry to recognize these two event names and their field shapes. The runtime emission (the `IToolInvoker` calling `IAuditAppender.AppendAsync`) is the Capabilities Node's job — this packet only registers that **Audit knows these shapes exist** so post-emit query and validation paths recognize them.

The "Audit unavailable → tool invocation denies" contract test (ADR-0051 D10, "If Audit is unavailable, tool invocation **denies**") is named in ADR-0047 D4 Tier 2a contract-tests pattern. Adding the contract test is a follow-up to ADR-0047's testing-pattern rollout, written against the IToolInvoker authz check in the Capabilities Node track. Not in this initiative.

### Long-running grant renewal workflow — deferred to Operator standup

ADR-0051 D6 names a 30-day renewal cycle for long-running agents (Lately publisher, Hearth content worker). The renewal workflow runs from Operator and requires explicit re-confirmation. It is Operator-Node operational work and lands in the Operator standup or a follow-up Operator initiative.

### `policy-review` specialist agent — deferred to ADR-0046 specialist-roster initiative

ADR-0051's Follow-up Work lists a `policy-review` specialist agent (per ADR-0046) for `policies/bundles/` changes. ADR-0046 is the umbrella for specialist-agent additions; the `policy-review` specialist is a new entry in that roster. It lands in `adr-0046-specialist-review-agents` follow-up scope, after the `policies/bundles/` directory actually exists (which arrives with the Capabilities scaffold).

### Site sync

No site-sync flag. ADR-0051 is internal AI-sector substrate — no public-facing Studios website content changes.

## Wave Diagram

### Wave 1 (No Dependencies — governance + catalog + agent updates)

- [ ] **00** — Architecture: Accept ADR-0051, add four new invariants (numbers **78, 79, 80, 81**), register the initiative. `Actor=Agent`.
- [ ] **01** — Architecture: register the new authorization contract surface in the Grid catalogs and add the Cross-Cutting Concerns to `repos/HoneyDrunk.Capabilities/`, `repos/HoneyDrunk.Operator/`, `repos/HoneyDrunk.Agents/` integration-points docs. `Actor=Agent`. Blocked by: 00.
- [ ] **02** — Architecture: update `.claude/agents/scope.md` with the "tool-authoring checklist" + "Capability bundle definition" section for standup packets. `Actor=Agent`. Blocked by: 00.

> **Invariant numbering.** The current verified maximum in `constitution/invariants.md` is **53**. Invariant numbers **78, 79, 80, 81** are reserved for ADR-0051 as part of a forward batch alongside ADR-0042's reserved 75/76/77; if any invariant above 53 lands from outside this batch before packet 00 merges, shift the block upward, never reuse a number.

### Wave 2 (Depends on Wave 1 — abstractions in live Nodes, parallel)

- [ ] **03** — Kernel: add `AgentPrincipal`, `AgentId`, `AgentRunId` to `HoneyDrunk.Kernel.Abstractions/Agents/` (the existing `Agents/` subfolder); extend `IOperationContext` with an optional `AgentPrincipal? Agent { get; }`. `Actor=Agent`. Blocked by: 00. **Version-bumping packet for `HoneyDrunk.Kernel` (`0.7.0` → `0.8.0`; if ADR-0042's packet 02 already bumped to `0.8.0`, this packet appends to that line — see Version Bumps).**
- [ ] **04** — Auth: add `AuthorizationDeniedException` to `HoneyDrunk.Auth.Abstractions`; extend the existing `AuthorizationDenyCode` enum with four new members (`CapabilityMissing`, `ScopeMismatch`, `GrantExpired`, `PrincipalTypeMismatch`). `Actor=Agent`. Blocked by: 00. **Version-bumping packet for `HoneyDrunk.Auth`.**

### Wave 3 (Depends on Wave 2 — Audit event taxonomy)

- [ ] **05** — Audit: register `tool.invoke.granted` and `tool.invoke.denied` event names and the 13-field shape in the Audit event-shape registry per ADR-0051 D10. `Actor=Agent`. Blocked by: 03, 04. **Version-bumping packet for `HoneyDrunk.Audit`.**

Packets within a wave run in parallel. **Wave-1 packets 00, 01, 02 share Architecture** — 00 is the acceptance + invariants, 01 is catalog/integration-points, 02 is scope.md/template. They could land as one PR; kept as separate packets for review surface and per the "one logical change per packet" rule. **Wave-2 packets 03 and 04 are independent** — different repos. Packet 05 in Wave 3 hard-blocks behind both Wave-2 packets because the audit event-shape registration references the `AgentPrincipal` type (packet 03) and the deny codes (packet 04).

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0051](./00-architecture-adr-0051-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Authorization contract catalog + integration-points](./01-architecture-agent-authorization-catalog.md) | Architecture | Agent | 1 | 00 |
| 02 | [Scope agent + standup template tool-authoring updates](./02-architecture-scope-agent-tool-authoring-updates.md) | Architecture | Agent | 1 | 00 |
| 03 | [Kernel `AgentPrincipal` + `IOperationContext` slot](./03-kernel-agent-principal-and-operation-context-slot.md) | Kernel | Agent | 2 | 00 |
| 04 | [Auth `AuthorizationDeniedException` + deny-code extension](./04-auth-authorization-denied-exception-and-deny-codes.md) | Auth | Agent | 2 | 00 |
| 05 | [Audit `tool.invoke.*` event shapes](./05-audit-tool-invoke-event-shapes.md) | Audit | Agent | 3 | 03, 04 |

## Version Bumps

- **`HoneyDrunk.Kernel`** — packet 03 is the first ADR-0051 packet on the solution. If ADR-0042's packet 02 has already bumped Kernel `0.7.0` → `0.8.0`, packet 03 here appends to the in-progress `[0.8.0]` CHANGELOG and does NOT bump again (invariant 27). If ADR-0042's bump has NOT yet landed at execution time, packet 03 is the bumping packet (`0.7.0` → `0.8.0`). The executor must verify the current solution version before bumping. Per-package CHANGELOG: `HoneyDrunk.Kernel.Abstractions` gets an entry from packet 03 (real changes — new types + `IOperationContext` extension).
- **`HoneyDrunk.Auth`** — packet 04 bumps the whole solution one minor version (additive deny-code values + new `AuthorizationDeniedException`). Confirm the current version at execution time. Per-package CHANGELOG: `HoneyDrunk.Auth.Abstractions` gets an entry; non-Abstractions packages are alignment bumps only (no CHANGELOG entry per invariant 12/27).
- **`HoneyDrunk.Audit`** — packet 05 bumps the whole solution one minor version (event-shape registry extension is an additive feature). Confirm the current version at execution time.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance / catalog / docs edits only.

## Rollback Plan

- **Packets 00–02 (governance/catalog/agent docs):** revert the PR. ADR-0051 returns to Proposed; the four invariants and catalog entries are removed; the scope.md/standup-template updates revert. No runtime impact.
- **Packet 03 (Kernel `AgentPrincipal` + context slot):** revert the PR; the `HoneyDrunk.Kernel.Abstractions` types disappear; the `IOperationContext` extension rolls back. Additive — no consuming Node depends on the new types at runtime until it composes them; the revert is contained to `HoneyDrunk.Kernel`.
- **Packet 04 (Auth `AuthorizationDeniedException` + deny codes):** revert the PR; the new `AuthorizationDenyCode` values leave the enum; `AuthorizationDeniedException` leaves the assembly. Additive — no current Auth caller throws/handles `AuthorizationDeniedException` (the type is intended for `IToolInvoker` consumption which has not landed); the revert is contained to `HoneyDrunk.Auth`.
- **Packet 05 (Audit event taxonomy):** revert the PR; the two event-shape registrations leave the registry. No consumer of Audit's registry has wired itself to these events yet — Capabilities (the emitter) has not landed. Contained to `HoneyDrunk.Audit`.

**No operational escape hatch is needed.** Nothing this initiative ships executes against production traffic — it's all contract surface and registry data. The runtime enforcement points (the `IToolInvoker` authz check, the bundle store, the env-guard) land in the AI-sector standup tracks, where their own rollback plans apply.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

## Follow-Up Work (out of scope — tracked, not filed by this initiative)

- **ADR-0017 (Capabilities standup) — amend packet 04 draft** to ship `CapabilityBundle`, `Capability`, `CapabilityRequirement`, `ScopeBindingMode`, `CapabilityBundleRef`, and the `RequiredCapabilities`-bearing extension to `ICapabilityInvoker` in the first commit. Add ADR-0051 packet 00 as a hard dependency on packet 04. The standup canary must demonstrate ADR-0051 D14 Phase 2 acceptance (agent with bundle → tool invocation succeeds; agent without bundle → typed deny; expired grant → typed deny; `bundle:local-dev-all` in `prod` env → Node refuses to start).
- **ADR-0017 (Capabilities standup) — Phase 2 runtime follow-up packet** (lands after the scaffold closes): the bundle-store loader (`policies/bundles/*.yaml` + `policies/capabilities/grid-vocabulary.yaml` loader, hash-and-log at startup), the `IToolInvoker` default authorization check (ordered 6-step check per ADR-0051 D3), the env-guard (`bundle:local-dev-all` startup gate per D12), and the recursion check on `bundle:grid-operator` (per D8). Plus the initial bundle YAML set: `bundle:lately-content-publisher@v3`, `bundle:netrunner-architecture-sweep@v1`, `bundle:hive-sync@v1`, `bundle:grid-operator@v1`, `bundle:local-dev-all@v1`.
- **ADR-0018 (Operator standup) — amend the standup draft** to ship the grant/revoke API (`POST /grants`, `DELETE /grants/{grantId}`), the Operator-as-agent bootstrap path (`event=operator.bootstrap` audit emission), the static-analyzer rule in `HoneyDrunk.Standards.Analyzers` that flags direct `AgentPrincipal` construction outside `HoneyDrunk.Operator`. Add long-running grant renewal workflow (30-day cycle with explicit re-confirmation) as Operator follow-up.
- **ADR-0020 (Agents standup) — amend the standup draft** to wire `AgentPrincipal` propagation through the execution loop and surface `AuthorizationDeniedException` to the LLM as a structured tool-result error (`{"error": "authorization_denied", "missing": "<capability>"}`). Standup canary demonstrates ADR-0051 D14 Phase 4 acceptance.
- **ADR-0047 (Testing patterns) — new packet**: the contract test (Tier 2a) exercising "Audit unavailable → tool invocation denies" against the `IToolInvoker` authz check shipped by the Capabilities standup follow-up. Parks until Capabilities Phase 2 ships.
- **ADR-0046 (Specialist review agents) — new packet**: author the `policy-review` specialist agent for `policies/bundles/` changes. Parks until `policies/bundles/` exists in the Capabilities repo.
- **`Principal` abstract base + `UserPrincipal` / `ServicePrincipal` types** — when the three-principal-type renaming is warranted, a follow-up Auth amendment can introduce the named `Principal` base and rename the existing `AuthenticatedIdentity`-shaped surface. Out of scope for ADR-0051; named here so the next Auth review knows the gap exists.
- **OPA / dynamic policy store (ADR-0051 D13 v2 escalation)** — fires only when one of D13's named triggers (bundle count > ~50, per-tenant custom bundles, attribute-based access needs) is observed. Recorded.
