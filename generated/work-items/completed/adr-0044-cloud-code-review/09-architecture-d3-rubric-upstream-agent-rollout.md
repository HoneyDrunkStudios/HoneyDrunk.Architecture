---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0044", "wave-2"]
dependencies: ["work-item:04"]
adrs: ["ADR-0044", "ADR-0007", "ADR-0014"]
accepts: ["ADR-0044"]
wave: 2
initiative: adr-0044-cloud-code-review
node: honeydrunk-architecture
---

# Roll the D3 rubric into the upstream authoring agents (scope, adr-composer, pdr-composer, refine, node-audit)

## Summary
Add a section to each upstream authoring agent definition — `scope.md`, `adr-composer.md`, `pdr-composer.md`, `refine.md`, `node-audit.md` — referencing ADR-0044 D3 and the subset of the twenty-category rubric relevant to that agent's authoring surface, per D3's upstream-awareness clause. Together with packet 04 (the `review.md` half), this packet is `current-focus.md` priority #7, "ADR-0044 D3 rubric rollout."

## Context
ADR-0044 D3's most important structural decision is that the twenty-category rubric is **not the reviewer's private checklist** — it is the Grid's shared standard applied symmetrically by every agent that *authors* code or scoped work, not only by the reviewer that evaluates the result. An author who applies the rubric upstream prevents the problem; a reviewer who applies it downstream catches what slipped through. Catching a problem at authoring time costs nothing; catching it at review costs a review cycle. Packet 04 added the rubric to `review.md`. This packet binds the **authoring** surfaces. `current-focus.md` priority #7 tracks both packets as one logical rollout, gated on ADR-0044 landing (priority #3).

## Scope
Each of the five agent files gains one new section referencing D3 and the relevant category subset:
- `.claude/agents/scope.md`
- `.claude/agents/adr-composer.md`
- `.claude/agents/pdr-composer.md`
- `.claude/agents/refine.md`
- `.claude/agents/node-audit.md`

The execution-surface prompts (Codex packet-execution prompt, Copilot in-IDE custom instructions, Claude Code authoring-mode system instructions) are handled in packet 10 — keep this packet to the five `.claude/agents/` files.

## Proposed Implementation
Per ADR-0044 D3's upstream-awareness clause, each file gets a section referencing D3 with the relevant subset and severity expectations:

- **`scope.md`** — when decomposing a packet, evaluate which categories apply: failure mode (Reliability), observability required (Observability), security blast radius (Security), testing strategy (Testing), anti-entropy risk (Anti-Entropy), correctness/scope adherence (Correctness), AI/agent implications (Category 18). Packets that omit relevant categories produce changes that miss them at execution time.
- **`adr-composer.md`** — when proposing an ADR, reason against the categories that apply: architectural drift (Architectural Integrity), cost (Performance / Cost / Product alignment), long-term entropy (Anti-Entropy), security/compliance (Security / Enterprise Readiness), AI/agent implications (Category 18).
- **`pdr-composer.md`** — same as `adr-composer`, with extra weight on Category 17 (Product / Business Alignment) and Category 19 (Anti-Entropy and Long-Term Health).
- **`refine.md`** — a rubric-completeness check: evaluate whether the packet (and dispatch plan) accounts for the categories the work touches. A packet that ignores Reliability, Observability, or Anti-Entropy where those clearly apply surfaces as a `refine` finding.
- **`node-audit.md`** — a section referencing D3 as the systemic-health rubric: walk the rubric to identify systemic gaps that span PRs rather than living in any single one; findings flow to packets per ADR-0043.

Each section must:
- Reference ADR-0044 D3 as the binding decision.
- State that updates to the rubric are amendments to D3 and propagate via agent-file updates per ADR-0007's source-of-truth rule.
- Note that drift between D3 and any agent file's referenced category list is an anti-pattern that `hive-sync` reconciles (per ADR-0014).

## Affected Files
- `.claude/agents/scope.md`
- `.claude/agents/adr-composer.md`
- `.claude/agents/pdr-composer.md`
- `.claude/agents/refine.md`
- `.claude/agents/node-audit.md`

## NuGet Dependencies
None. This packet edits Markdown agent-definition files; no .NET project is created or modified.

## Boundary Check
- [x] `.claude/agents/` is the single source of truth for agent definitions (ADR-0007); lives in `HoneyDrunk.Architecture`. Correct repo.
- [x] No code change in any repo.

## Acceptance Criteria
- [ ] `scope.md` has a section referencing ADR-0044 D3 and the scoping-relevant category subset (Correctness scope adherence, Reliability, Observability, Security, Testing, Anti-Entropy, AI/agent)
- [ ] `adr-composer.md` has a section referencing D3 and the decision-relevant subset (Architectural Integrity, Cost, Anti-Entropy, Security/Compliance, AI/agent)
- [ ] `pdr-composer.md` has the same with extra weight on Category 17 and Category 19
- [ ] `refine.md` has a section defining the rubric-completeness check on packets and dispatch plans
- [ ] `node-audit.md` has a section referencing D3 as the systemic-health rubric
- [ ] Every section states the D3-amendment vs agent-file-edit distinction and the `hive-sync` drift-reconciliation expectation
- [ ] Each section is consistent with the rubric content in `review.md` (packet 04) — same category names, same numbering

## Human Prerequisites
None. Pure Architecture-repo agent-definition edits.

## Dependencies
- `work-item:04` — `review.md` twenty-category rubric (**hard** — the upstream sections must reference the same category names/numbering authored in `review.md`; doing this packet first risks divergence).

## Referenced ADR Decisions

**ADR-0044 D3 (upstream-awareness clause)** — The twenty-category rubric is the Grid's shared standard applied symmetrically by authoring agents (`scope`, `adr-composer`, `pdr-composer`, `refine`, execution agents, `node-audit`) and by the `review` agent. Each agent definition gains a section referencing D3 and the relevant category subset. Updates to the rubric are D3 amendments propagating via agent-file updates.
**ADR-0007** — `.claude/agents/` is the single source of truth for agent definitions.
**ADR-0014** — `hive-sync` reconciles drift between D3 and any agent file's referenced category list.

## Constraints
- **Consistency with `review.md`.** Use the exact category names and numbering authored in packet 04 — divergence between the upstream and review surfaces is the anti-pattern D3 explicitly warns against.
- **Reference, not duplication.** The upstream agents reference D3 and a *subset*; they do not re-author the full per-category execution detail (that lives in `review.md`).
- This packet is the upstream half of `current-focus.md` priority #7; packet 04 is the `review.md` half.

## Labels
`docs`, `tier-2`, `meta`, `adr-0044`, `wave-2`

## Agent Handoff

**Objective:** Add a D3-referencing section to each of `scope.md`, `adr-composer.md`, `pdr-composer.md`, `refine.md`, `node-audit.md`, binding the relevant rubric-category subset per D3's upstream-awareness clause.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the twenty-category rubric the shared upstream authoring standard, not just the reviewer's checklist. This packet + packet 04 are `current-focus.md` priority #7.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 2.
- ADRs: ADR-0044 (D3 upstream-awareness), ADR-0007, ADR-0014.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:04` — `review.md` rubric (hard).

**Constraints:**
- Use the exact category names/numbering from `review.md`.
- Reference D3 and a subset; do not duplicate the full execution detail.

**Key Files:**
- `.claude/agents/scope.md`, `adr-composer.md`, `pdr-composer.md`, `refine.md`, `node-audit.md`

**Contracts:** None.
