---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0065", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0065"]
accepts: ["ADR-0065"]
wave: 1
initiative: adr-0065-aspire-orchestration
node: honeydrunk-architecture
---

# Update tech-stack reference, scope agent, and review agent for the Aspire stance

## Summary
Update three documentation surfaces that ADR-0065 commits to update at acceptance: (a) `infrastructure/reference/tech-stack.md` — move the .NET Aspire row from "Planned / Future" to "Adopted" with the local-dev-only framing, and add a row noting the dev Service Bus namespace; (b) `.claude/agents/scope.md` — packets that introduce new multi-process Nodes must include an AppHost in their solution structure; (c) `.claude/agents/review.md` — new PR-review checklist items for multi-process Node PRs (must include or update the AppHost; Aspire-generated Bicep must not be checked into production deployment paths). No catalog schema change for Workshop — the `HoneyDrunk.Workshop` Node entry is deferred to the Workshop standup ADR per ADR-0065's own Follow-up Work.

## Context
ADR-0065's "Catalog and Reference Updates Required" section lists explicit doc edits to land at acceptance:

- `infrastructure/reference/tech-stack.md` line 152 — currently lists `.NET Aspire` under Planned / Future, target Q2–Q3 2026. ADR-0065 D1 adopts it; the row moves to "Adopted" with the local-dev-only framing.
- `infrastructure/reference/tech-stack.md` — add a row noting the dev Service Bus namespace runs at Basic tier (the operator-cost note from ADR-0065 D9 and the cost line in Operational Consequences).
- `.claude/agents/scope.md` — must require an AppHost in solution structure for new multi-process Nodes.
- `.claude/agents/review.md` — must check multi-process Node PRs for AppHost presence and check that Aspire-generated Bicep is not checked into production deployment paths.

The `HoneyDrunk.Workshop` Node entry in `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`, and `constitution/sectors.md` is **deferred** — per ADR-0065's Follow-up Work, the Workshop standup ADR is a separate follow-up. Memory note "New-Node scaffolding gets its own ADR; don't bundle scaffold into feature packets" applies. This packet does NOT add `honeydrunk-workshop` to any catalog and does NOT create `repos/HoneyDrunk.Workshop/` — those land when the Workshop standup ADR is filed and scoped.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `infrastructure/reference/tech-stack.md` — move the `.NET Aspire` row out of Planned / Future and into the appropriate adopted section; add a row for the dev Service Bus namespace cost note.
- `.claude/agents/scope.md` — append a rule into the existing packet-quality guidance that new multi-process Node standups must include an AppHost project.
- `.claude/agents/review.md` — append two new review-checklist items.

NOT in scope:
- `catalogs/nodes.json`, `relationships.json`, `grid-health.json` Workshop entries — deferred to the Workshop standup ADR (ADR-0065 Follow-up).
- `constitution/sectors.md` Workshop row — deferred to the Workshop standup ADR.
- `repos/HoneyDrunk.Workshop/` folder — deferred to the Workshop standup ADR.

## Proposed Implementation

### `infrastructure/reference/tech-stack.md`

1. Locate the `.NET Aspire` row currently under "Planned / Future → Developer Experience" (line 152 at authoring time). Move it into the appropriate adopted/in-use section of the file (the file's existing convention groups adopted tech by topic — match its structure). The updated framing, per ADR-0065 D1/D5:

   > **.NET Aspire** — Adopted as the Grid's local-dev orchestrator (per ADR-0065). Local-dev only: per-Node `{Node}.AppHost` for solo Node work, per-scenario AppHosts in `HoneyDrunk.Workshop` for cross-Node scenarios. Production deployment authoring stays in `HoneyDrunk.Standards` shared workflows and curated Bicep per ADR-0015 — Aspire's generator is never the production path.

2. Add a row (under Azure infrastructure / messaging, wherever Service Bus is already listed; if Service Bus has no row, add one):

   > **Azure Service Bus — dev namespace** — `sb-hd-dev`, Basic tier, runs continuously. One topic per Grid topic; per-developer-session subscriptions. ~$10/month known recurring cost (per ADR-0052 cost ledger). No emulator exists for Service Bus, so dev uses the real namespace per ADR-0065 D9.

### `.claude/agents/scope.md`

Append (or extend the existing relevant section — match the agent file's structure) a rule under the packet-quality / scope-decomposition guidance:

> **AppHost requirement for new multi-process Nodes.** Packets that introduce a new multi-process containerized Node (a deployable Node with more than one runtime entry point — e.g. Functions + Worker) must include a `{Node}.AppHost` project in the proposed solution structure. Single-process Nodes may include one optionally; library-only Nodes (no runtime) do not. See ADR-0065 D2/D7 and the related invariant.

### `.claude/agents/review.md`

Append two review-checklist items in the appropriate rubric section (ADR-0044 D3 governs the rubric structure — match its category placement; the two items belong in the deployment / infrastructure category):

> - [ ] **Multi-process Node AppHost** — If the PR touches a deployable Node with more than one runtime entry point (Functions + Worker, host + sidecar, etc.), the PR includes or updates the Node's `{Node}.AppHost` project. Missing AppHost on a multi-process Node is a finding (severity: medium). See ADR-0065 D2/D7.
> - [ ] **No Aspire-generated Bicep in production deployment paths** — Aspire's `azd`/`AzurePublisher` outputs (Bicep, ARM, `azure.yaml`) must not be checked into the repo's production deployment surface (`infrastructure/bicep/`, `infrastructure/arm/`, or equivalent). Sandbox-only files are acceptable in a clearly-scoped `.aspire/` or `bin/` path; production authoring is `HoneyDrunk.Standards` shared workflows + curated Bicep per ADR-0015. See ADR-0065 D5 and the related invariant.

Per [`scope.md`](../../../../.claude/agents/scope.md)'s coupling rule with `review.md` (ADR-0011 D4, invariant 33 — "Review-agent and scope-agent context-loading contracts are coupled"), these two surfaces are amended together in this packet.

## Affected Files
- `infrastructure/reference/tech-stack.md`
- `.claude/agents/scope.md`
- `.claude/agents/review.md`

NOT touched by this work-item:
- `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json` — Workshop entries are deferred to the Workshop standup ADR.
- `constitution/sectors.md` — Workshop row deferred to the Workshop standup ADR.
- `repos/HoneyDrunk.Workshop/` — deferred to the Workshop standup ADR.

## NuGet Dependencies
None. This packet touches only Markdown documentation; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.
- [x] Workshop standup is explicitly deferred to its own ADR; this packet does not touch nodes.json or relationships.json.

## Acceptance Criteria
- [ ] `infrastructure/reference/tech-stack.md` no longer lists `.NET Aspire` under Planned / Future; the row appears in an adopted section with the local-dev-only framing and the ADR-0015 cross-reference
- [ ] `infrastructure/reference/tech-stack.md` carries a row for the dev Service Bus namespace (`sb-hd-dev`, Basic tier, ~$10/month, per-session subscription convention)
- [ ] `.claude/agents/scope.md` carries the AppHost-requirement rule for new multi-process Nodes, citing ADR-0065 D2/D7
- [ ] `.claude/agents/review.md` carries the two new review-checklist items (multi-process Node AppHost presence; no Aspire-generated Bicep in production deployment paths), citing ADR-0065 D2/D5/D7 and the related invariants
- [ ] No edit to `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`, or `constitution/sectors.md` (Workshop entry deferred)
- [ ] No `repos/HoneyDrunk.Workshop/` folder created (deferred)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0065 D1 — Aspire is the Grid's local-dev orchestrator, local-dev only.** Native .NET, OTLP dashboard, low ceremony.

**ADR-0065 D2 — Two-tier AppHost shape.** Per-Node AppHost (`{Node}.AppHost`) for solo work; per-scenario AppHost in `HoneyDrunk.Workshop` for cross-Node scenarios.

**ADR-0065 D5 — Production deployment is separate from Aspire.** `HoneyDrunk.Standards` + curated Bicep is the authority. Aspire's generator is never the production path.

**ADR-0065 D7 — Migration is incremental, per-Node.** Multi-process Nodes need an AppHost; library-only Nodes do not.

**ADR-0065 D9 — Real dev Service Bus, no shim.** One `sb-hd-dev` namespace, Basic tier, per-session subscriptions, ~$10/month recurring cost.

**ADR-0065 Catalog and Reference Updates Required.** Lists the tech-stack.md edits, the scope.md/review.md agent-file edits, and the Workshop catalog entries explicitly deferred to the Workshop standup ADR.

**ADR-0065 Follow-up Work.** "File the `HoneyDrunk.Workshop` standup ADR as a separate paired follow-up."

## Constraints
- **Invariant 33 — review and scope context-loading contracts are coupled.** When `.claude/agents/scope.md` adds a new rule that the review surface should catch, the matching review-rubric item lands in the same change. Both edits are in this packet.
- **Workshop is a deferred standup.** Do not add Workshop entries to catalogs, sectors, or `repos/` in this packet. Memory note "New-Node scaffolding gets its own ADR" applies.
- **Match existing file structure.** `.claude/agents/scope.md` and `review.md` have established sectioning; add new items in the topically correct location rather than appending arbitrarily.
- **No ADR-ID noise in narrative docs.** Per the memory note "No ADR numbers in docs or comments — skip ADR IDs in README sections/code comments; runtime packet-data references are fine," the new review-checklist items may reference ADR-0065 (it is governance metadata, not narrative prose), but the tech-stack.md row should *describe* the decision, with the ADR ID present as a citation tail rather than dominating the prose — match the existing tech-stack.md rows' style.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0065`, `wave-1`

## Agent Handoff

**Objective:** Update tech-stack.md, scope.md, and review.md to reflect ADR-0065's Aspire adoption.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the documentation surfaces ADR-0065 commits to update at acceptance, so downstream packets and future scope/review work read the new rules.
- Feature: ADR-0065 Multi-Service Local Dev Orchestration rollout, Wave 1.
- ADRs: ADR-0065 (primary), ADR-0011 / ADR-0044 (review/scope agent governance), ADR-0015 (Container Apps — referenced by the production-deployment carve-out).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0065 should be Accepted before its decisions become live narrative in scope/review/tech-stack.

**Constraints:**
- Workshop is deferred to a separate standup ADR (per ADR-0065's Follow-up Work and the user's "new-Node scaffolding gets its own ADR" preference) — do not add Workshop entries to catalogs/sectors/repos here.
- Review and scope rule additions land together in this packet (invariant 33 — coupled context-loading contracts).

**Key Files:**
- `infrastructure/reference/tech-stack.md`
- `.claude/agents/scope.md`
- `.claude/agents/review.md`

**Contracts:** None changed — documentation edits only.
