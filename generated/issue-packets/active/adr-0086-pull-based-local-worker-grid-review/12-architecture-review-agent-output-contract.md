---
name: Infrastructure
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "infrastructure", "adr-0086", "wave-2"]
dependencies: ["packet:03"]
adrs: ["ADR-0086", "ADR-0007", "ADR-0044"]
accepts: []
wave: 2
initiative: adr-0086-pull-based-local-worker-grid-review
node: honeydrunk-architecture
---

# Preserve the canonical Grid Review output contract

## Summary
Clarify the canonical `.claude/agents/review.md` output format so every review surface emits the established Grid Review verdict shape: top metadata (`Risk Level`, `Review Confidence`, `Change Type`, `Blast Radius`, `Operational Sensitivity`, `Requires ADR`), emoji section headers, and the full review-evidence footer.

This is a source-of-truth update, not a runner-local override. Packet 03 builds the ADR-0086 runner substrate and must continue to consume `.claude/agents/review.md` rather than duplicating review instructions. This packet authorizes the prompt contract clarification needed after the runner started synthesizing Codex and Claude outputs into one PR-facing comment.

## Context
ADR-0086 originally scoped packet 03 as a transport/substrate change and said `.claude/agents/review.md` would not change. During pilot review, the operator confirmed that the runner must preserve the richer Grid Review comment format used by the prior path, including emoji headings and the detailed review categories. A runner-local synthesis prompt is not allowed to become the only source for that format; ADR-0007 makes `.claude/agents/` the source of truth for agent behavior.

The correction is therefore to make the canonical review agent prompt own the established format, then have the runner synthesis prompt mirror that canonical contract.

## Scope
- Update only the `.claude/agents/review.md` output-format block.
- Preserve the existing review process, context-loading contract, severity guide, and ADR-0044 D3 rubric.
- Ensure ADR-0086 runner synthesis mirrors the canonical format and does not post per-agent raw sections.
- Document that packet 03 remains a runner-substrate packet and does not authorize arbitrary review-agent prompt changes.

## Acceptance Criteria
- [ ] `.claude/agents/review.md` defines the Grid Review output format with the top metadata fields, `✅ Verdict`, emoji section checklist, and reviewed-scope evidence footer.
- [ ] The runner synthesis prompt mirrors the canonical format rather than inventing a different PR-facing shape.
- [ ] Packet 03 is not mutated to retroactively authorize its own scope change.
- [ ] ADR-0086 text records that this follow-on packet amended the output contract while preserving ADR-0007 source-of-truth discipline.
- [ ] UTF-8 output from child CLIs is preserved so emoji and punctuation survive in PR comments.

## Dependencies
- `packet:03` — runner framework and synthesis path.

## Referenced ADR Decisions

**ADR-0007** — `.claude/agents/` is the canonical source of truth for agent definitions. Runner code may invoke and synthesize agent output, but must not fork the review contract into runner-only prompt text.

**ADR-0044 D1/D3** — The Grid Review Runner posts advisory PR comments and the review agent applies the full architecture-aware rubric.

**ADR-0086 D1/D3/D8** — The local worker consumes the canonical review agent file and posts one synthesized PR verdict when multiple independent review passes are required.

## Constraints
- Do not duplicate the review rubric into runner-only code as the canonical contract.
- Do not relax the context-loading contract or ADR-0044 D3 review categories.
- Do not mutate filed packets other than adding this follow-on packet.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `infrastructure`, `adr-0086`, `wave-2`

## Agent Handoff

**Objective:** Update the canonical review-agent output contract to the established Grid Review format and align ADR-0086 runner synthesis with it.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Acceptance Criteria:** As listed above.

**Key Files:**
- `.claude/agents/review.md`
- `infrastructure/workers/grid-agent-runner/lib/Synthesis.psm1`
- `infrastructure/workers/grid-agent-runner/lib/Agent.psm1`
- `adrs/ADR-0086-pull-based-local-worker-grid-review-runner.md`
