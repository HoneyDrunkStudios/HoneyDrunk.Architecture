---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0044", "wave-1"]
dependencies: ["packet:01"]
adrs: ["ADR-0044", "ADR-0007", "ADR-0011"]
accepts: ["ADR-0044"]
wave: 1
initiative: adr-0044-cloud-code-review
node: honeydrunk-architecture
---

# Update review.md with the D3 twenty-category rubric execution detail

## Summary
Update `.claude/agents/review.md` with the per-category execution detail implementing ADR-0044 D3's twenty-category rubric — exactly what to look for and what counts as a finding at each severity per category — plus any clarifications the cloud-context execution surface needs (e.g. "context loaded from the architecture-repo checkout"). This is the agent-file half of the D3 rubric rollout; the upstream authoring agents are updated in packet 08.

## Context
ADR-0044 D3 binds **twenty named review categories and the questions within them** as the Grid's shared standard for any code change. Per ADR-0007's source-of-truth rule, the ADR binds the categories and questions; the detailed per-category execution detail lives in `.claude/agents/review.md`. The cloud-wired reviewer (packet 03) runs `review.md` directly — so the rubric must be present in `review.md` for `job-review-agent.yml` to function as designed. This packet, together with packet 08, is the work `current-focus.md` priority #7 ("ADR-0044 D3 rubric rollout") tracks.

## Scope
- `.claude/agents/review.md` — add the twenty-category rubric with per-category execution detail and severity expectations.
- No other agent files (those are packet 08).

## Proposed Implementation
For each of the twenty D3 categories, `review.md` gains a subsection giving the executable detail: what the reviewer inspects, what constitutes a finding, and the severity mapping (`Block` / `Request Changes` / `Suggest` per `copilot/pr-review-rules.md`). The twenty categories, verbatim from ADR-0044 D3:

1. Correctness and functional integrity
2. Architectural integrity
3. Maintainability
4. Reuse and ecosystem cohesion
5. SOLID and design principles
6. Performance and scalability
7. Reliability and resilience
8. Observability and diagnostics
9. Security
10. Enterprise readiness
11. Testing quality
12. API and contract design
13. Data and persistence integrity
14. Distributed systems concerns
15. CI/CD and delivery
16. Developer experience (DX)
17. Product and business alignment
18. AI and agent-specific concerns
19. Anti-entropy and long-term system health
20. Human factors

Each category's *questions* are bound by ADR-0044 D3 and must be reproduced faithfully; the *answers/checklists* (what counts as a finding, severity) are the editable agent-file content this packet authors. The full question text for each category is in ADR-0044 D3 sections 1-20 — reproduce the questions, then add the execution detail.

Additionally:
- Add a short note that the rubric is the Grid's **shared** standard applied symmetrically by authors and the reviewer (D3's upstream-awareness clause) — `review.md` applies the full rubric as the evaluation gate.
- Add a cloud-context clarification: when running under `job-review-agent.yml`, Grid context (invariants, catalogs, boundary files) is read from the `HoneyDrunk.Architecture` checkout the workflow performs; the agent must treat that checkout as the canonical context source.
- Confirm the severity taxonomy reference points at `copilot/pr-review-rules.md`.
- State that updates to the categories or their questions are amendments to ADR-0044 D3; updates to the per-category execution detail are edits to this file (no ADR ceremony) — and that `hive-sync` reconciles drift between D3 and this file.

## Affected Files
- `.claude/agents/review.md`

## NuGet Dependencies
None. This packet edits a Markdown agent-definition file; no .NET project is created or modified.

## Boundary Check
- [x] `.claude/agents/` is the single source of truth for agent definitions (ADR-0007); it lives in `HoneyDrunk.Architecture`. Correct repo.
- [x] No code change in any repo.

## Acceptance Criteria
- [ ] `.claude/agents/review.md` contains all twenty D3 categories with their questions reproduced faithfully from ADR-0044 D3
- [ ] Each category carries per-category execution detail: what to inspect, what counts as a finding, severity mapping (`Block` / `Request Changes` / `Suggest`)
- [ ] The shared-rubric / upstream-awareness principle is noted (the rubric is applied symmetrically by authors and reviewer; `review.md` is the evaluation gate)
- [ ] A cloud-context clarification is present (context read from the architecture-repo checkout)
- [ ] The severity taxonomy references `copilot/pr-review-rules.md`
- [ ] A note states D3 amendments vs agent-file edits and the `hive-sync` reconciliation expectation
- [ ] The review-agent context-loading section is unchanged from its current state except for the cloud-context clarification — invariant 33 superset-of-scope coupling preserved

## Human Prerequisites
None. Pure Architecture-repo agent-definition edit.

## Dependencies
- `packet:01` — ADR-0044 acceptance (soft; D3 is a live binding once ADR-0044 is Accepted).

## Referenced ADR Decisions

**ADR-0044 D3** — Twenty named review categories bound as the Grid's shared standard. The ADR binds categories and questions; per-category execution detail lives in `.claude/agents/review.md` per ADR-0007. The reviewer applies the full rubric as the evaluation gate; authors apply it upstream.
**ADR-0044 D1/D2** — The cloud-wired reviewer runs `review.md` directly; context is loaded from the architecture-repo checkout.
**ADR-0007** — `.claude/agents/` is the single source of truth for agent definitions.

## Constraints
> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled. The set of files loaded by the review agent must be a superset of the set loaded by the scope agent. Do not alter the context-loading list in this packet beyond the cloud-context clarification.

- **Reproduce the D3 questions faithfully.** The questions are ADR-bound; the execution detail is the editable content.
- **Do not change the context-loading contract.** Only the rubric content and a cloud-context clarification are in scope.

## Labels
`docs`, `tier-2`, `meta`, `adr-0044`, `wave-1`

## Agent Handoff

**Objective:** Add ADR-0044 D3's twenty-category rubric with per-category execution detail to `.claude/agents/review.md`, plus a cloud-context clarification.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the D3 rubric executable in `review.md` so the cloud-wired reviewer (packet 03) evaluates against it. This packet + packet 08 are `current-focus.md` priority #7.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 1.
- ADRs: ADR-0044 (D3 primary), ADR-0007 (agent-definition source of truth), ADR-0011 (context-loading coupling).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — ADR-0044 acceptance (soft).

**Constraints:**
- Reproduce the D3 questions faithfully; author the execution detail.
- Do not change the context-loading list beyond the cloud-context clarification (invariant 33).

**Key Files:**
- `.claude/agents/review.md`

**Contracts:** None.
