---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ai", "docs", "agents", "adr-0051", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0051"]
wave: 1
initiative: adr-0051-agent-authorization
node: honeydrunk-architecture
---

# Update the scope agent with the tool-authoring checklist and the standup "Capability bundle definition" section

## Summary
Update `.claude/agents/scope.md` with two ADR-0051 additions: (1) a tool-authoring checklist that fires when a packet introduces a new tool to the Capabilities tool registry — requiring `RequiredCapabilities` declaration on the tool type and an accompanying update to at least one bundle in `policies/bundles/` so the tool is reachable; (2) a "Capability bundle definition" section the scope agent emits when authoring standup packets for any new AI-sector consumer (Lately, Hearth, Curiosities, etc.), so each consumer's standup includes its bundle YAML up front.

## Context
ADR-0051 D7 says required capabilities are declared "in the tool's own type" via `CapabilityRequirement[] RequiredCapabilities` — the tool *is* the source of truth for what it needs. ADR-0051 Operational Consequences names two corollary obligations: every new tool authored requires a capability declaration; every new tool authored requires a bundle update to grant any agent the right to invoke it (without the bundle update, the tool is unreachable). These are *authoring-time* obligations — the right enforcement surface is the scope agent's tool-authoring checklist plus the PR review that catches the omission.

ADR-0051's Follow-up Work section explicitly names two `scope.md` updates: (1) the tool-authoring checklist gains a "declare `RequiredCapabilities`" step (cross-ref `constitution/agent-capability-matrix.md`), and (2) the standup-ADR template gains a "Capability bundle definition" section. The standup-ADR template in this Grid is not a separate file — the template content is content guidance carried inside `.claude/agents/scope.md` and embodied in the existing AI-sector standup packets (`adr-0017-capabilities-standup/04-capabilities-node-scaffold.md`, etc.). Updating `scope.md` is therefore the single edit that lands both obligations.

This is a docs/agent-content packet. No code, no .NET project.

## Scope

- `.claude/agents/scope.md` — add the two new sections described below. Do not restructure the existing file; add the new sections in the most-natural location (likely near the existing "Quality Checklist" and "Self-Containment Rule" sections).

## Proposed Implementation

1. **Tool-Authoring Checklist (new sub-section)** — add a new sub-section under the existing "Quality Checklist" (or, if a cleaner location exists, in its own near-end section "Tool-Authoring Rule"). The content:

   ```
   ## Tool-Authoring Rule

   When a packet introduces a new tool to the Capabilities tool registry (a new
   class implementing `ITool` in `HoneyDrunk.Capabilities` or in a Node that
   registers a tool), the packet MUST include all four items:

   - [ ] The tool declares `CapabilityRequirement[] RequiredCapabilities`
         on its own type (the tool is the source of truth — never centralize
         capability requirements in a separate config file). The empty array is
         allowed only for tools that genuinely require no capabilities; this is
         rare and warrants a comment justifying the empty set.
   - [ ] At least one capability bundle in `policies/bundles/*.yaml` is
         updated to grant the tool's required capabilities, so at least one
         agent can invoke the tool. A tool with no granting bundle is
         unreachable and the omission is loud at PR review (the registry knows
         the tool but no agent can call it).
   - [ ] Every new capability string introduced is added to
         `policies/capabilities/grid-vocabulary.yaml`. The Capabilities Node
         validates every capability reference against the vocabulary at
         startup; typos fail the standup canary.
   - [ ] The tool's `RequiredCapabilities` declaration appears in the packet's
         "Affected Files" or "Proposed Implementation" so reviewers can
         confirm the declaration matches the bundle update.

   See ADR-0051 D7, D9, and Operational Consequences.
   ```

2. **Standup "Capability bundle definition" section (new sub-section)** — add a new sub-section either in the "Self-Containment Rule" area or in a dedicated "Standup Packet Conventions" section if scope.md has one (review the file at execution time). The content:

   ```
   ## Standup Packet Conventions — Capability Bundle Definition

   Standup ADRs for AI-sector consumers (Lately, Hearth, Curiosities, and any
   future agent-driven Node) MUST decompose their standup packets with a
   "Capability bundle definition" section that includes:

   - The bundle name in the `bundle:<consumer-name>` namespace (e.g.,
     `bundle:lately-content-publisher`).
   - The bundle version (`@v1` for first-shipping).
   - The complete capability set the bundle grants — every capability the
     consumer's agent execution path will exercise. Wildcards are forbidden in
     production bundles (`bundle:local-dev-all` is the one explicit exception,
     env-guarded per ADR-0051 D12 / invariant 80).
   - The tenant-binding mode for each capability (`None`, `Tenant`, or
     `OnBehalfOfPrincipal`); the `{runtime}` placeholder where the bundle is
     granted across multiple tenants.
   - The grant lifetime expectation (matched to ADR-0051 D6's defaults: 1h
     ad-hoc, 30d long-running, 24h infra-sweep, 8h dev).
   - A note on whether the consumer is autonomous (no `OnBehalfOf`) or
     delegated (carries an `OnBehalfOf` user/service principal). Delegated
     consumers must note that the effective capability set is the
     **intersection** of the bundle and the granting principal's permissions
     (ADR-0051 D5).

   The bundle YAML itself lands in the consumer's standup PR — typically in
   `HoneyDrunk.Capabilities/policies/bundles/<consumer-name>.v1.yaml` rather
   than in the consumer's own repo (bundle definitions live in the
   Capabilities repo per ADR-0051 D9; the consumer's standup PR opens a
   cross-repo change set or is split into a Capabilities packet that lands
   first).

   See ADR-0051 D2, D6, D9, D14 Phase 5.
   ```

3. Inline the relevant invariant text in both sub-sections (per the Self-Containment Rule already in `scope.md`) rather than citing invariant numbers alone.

## Affected Files
- `.claude/agents/scope.md`

## NuGet Dependencies
None. This packet touches only one Markdown agent-content file; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly. `.claude/agents/scope.md` is the canonical scope agent definition for the Grid.
- [x] No code change in any other repo. The hardlinked global copy in `~/.claude/agents/scope.md` (per the project memory) refreshes when the user re-syncs after merge; no second-repo edit needed.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `.claude/agents/scope.md` has a new "Tool-Authoring Rule" sub-section with the four-item checklist (RequiredCapabilities declaration; at least one granting bundle; every new capability string in `grid-vocabulary.yaml`; declaration appears in packet Affected Files / Proposed Implementation)
- [ ] `.claude/agents/scope.md` has a new "Standup Packet Conventions — Capability Bundle Definition" sub-section listing the six required bundle-definition fields (name, version, capability set, scope binding mode, lifetime, autonomous-vs-delegated)
- [ ] Both new sub-sections inline the relevant ADR-0051 decision text per the Self-Containment Rule already in scope.md — citations like "see ADR-0051 D7" appear alongside, not instead of, the rule text
- [ ] No structural reorg of `scope.md` — the two new sub-sections are additions; existing content is unchanged
- [ ] No `.claude/agents/scope.md` change that violates the existing review-agent / scope-agent coupling (invariant 33). If the change is purely additive checklists and conventions, the review agent's context loading is unaffected; if any change touches the scope-agent context-loading contract, mirror it in `review.md` and call it out in the PR description
- [ ] No catalog, invariant, or ADR-status edit in this packet (those land in packets 00 and 01)

## Human Prerequisites
- [ ] **Re-sync the global hardlinked copy after merge.** Per the project memory ("Architecture agents hardlinked globally"), the 10 Architecture agents are hardlinked into `~/.claude/agents/`. The hardlink reflects file content automatically, but Claude Code requires a restart to re-register agent content. After the PR merges, restart Claude Code so the updated scope agent reads the new sub-sections on its next invocation. This is a one-time post-merge step; the code work itself is fully delegable.

## Referenced ADR Decisions

**ADR-0051 D7 — Tool registry: required-capabilities declared in code.** Every tool registered with the Capabilities Node declares its required capability set in its own type's `CapabilityRequirement[] RequiredCapabilities`. The tool is the source of truth; capability requirements live next to the implementation, version with it, and are reviewed as part of the tool's PR. v1 is static — capability changes require a redeploy.

**ADR-0051 D9 — v1 policy storage.** Capability bundles live in `HoneyDrunk.Capabilities/policies/bundles/*.yaml`; the authoritative capability vocabulary lives in `policies/capabilities/grid-vocabulary.yaml`. The Capabilities Node loads and validates both at startup; validation failures fail the standup canary.

**ADR-0051 D2 — Capability bundles, not raw capability grants.** Bundles are namespaced under `bundle:`, versioned (`@v3`), reviewed once at authoring time, granted by name. The bundle indirection is load-bearing for review surface, versioning, Operator UX, and audit stable-identifier purposes.

**ADR-0051 D5 — Effective capabilities are the intersection.** When `AgentPrincipal.OnBehalfOf` is populated, the effective capability set is `intersect(union(agent.Bundles[*].Capabilities), union(OnBehalfOf.Permissions))` — the agent never exceeds the bundle, and the agent never exceeds the granting principal's permissions.

**ADR-0051 D6 — Time-bound grants.** Defaults: 1h ad-hoc; 30d long-running; 24h infra-sweep; 8h dev. 90-day upper bound. Long-running agents at 30 days re-grant via an Operator workflow with explicit re-confirmation.

**ADR-0051 D14 Phase 5 — AI sector consumers.** Each new consumer (Lately, Hearth, ...) authors its capability bundle in `policies/bundles/` as part of standup. The standup template gets a "Capability bundle definition" section.

## Constraints

- **Self-containment.** Per `scope.md`'s own Self-Containment Rule, inline the relevant invariant and ADR-decision text in the new sub-sections rather than only citing the ADR number. The downstream scope-agent invocation has no guaranteed access to the ADR file.
- **Review/scope coupling — invariant 33.** Review-agent and scope-agent context-loading contracts are coupled; the review agent's context-loading list (`review.md`) must remain a superset of the scope agent's. If this packet's `scope.md` edit changes the *context-loading contract* (the files scope.md says to load at startup), mirror the change in `review.md` in the same PR. If the edit is purely additive checklists and standup conventions — as designed in this packet — no `review.md` change is needed. The PR description must explicitly state which case applies.
- **No re-org.** The two new sub-sections are additions in the most-natural locations; no existing content is moved or renamed.
- **`bundle:local-dev-all` is the one exception to wildcard prohibition.** State this explicitly in the Tool-Authoring Rule so the standup-checklist text does not accidentally read as forbidding all wildcards.

## Labels
`feature`, `tier-2`, `ai`, `docs`, `agents`, `adr-0051`, `wave-1`

## Agent Handoff

**Objective:** Add the Tool-Authoring Rule checklist and the Capability Bundle Definition standup-section to `.claude/agents/scope.md`, so future packets that introduce tools or stand up AI-sector consumers honor ADR-0051's authorization model from the first commit.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Move ADR-0051's tool-authoring and bundle-definition obligations from the ADR's Follow-up Work into the scope agent's executable surface, so the obligations are enforced at packet-authoring time, not discovered at PR review.
- Feature: ADR-0051 AI Agent Authorization rollout, Wave 1.
- ADRs: ADR-0051 D2/D5/D6/D7/D9/D14 (primary), ADR-0044/0046 (review-and-specialist-agent ecology this fits into).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0051 should be Accepted before its rules are translated into the scope agent's executable checklists.

**Constraints:**
- Inline invariant and ADR-decision text per scope.md's Self-Containment Rule.
- If the edit touches the scope-agent context-loading contract, mirror it in `review.md` in the same PR (invariant 33). The designed edit is additive checklists only — state this in the PR description.
- No structural reorg of `scope.md`.
- Note `bundle:local-dev-all` as the one explicit wildcard exception.

**Key Files:**
- `.claude/agents/scope.md` — the two new sub-sections.

**Contracts:** None changed.
