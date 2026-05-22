---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0044", "wave-2"]
dependencies: ["packet:04", "packet:07"]
adrs: ["ADR-0044", "ADR-0007"]
accepts: ["ADR-0044"]
wave: 2
initiative: adr-0044-cloud-code-review
node: honeydrunk-architecture
---

# Amend execution-surface prompts — emit Authorship line and surface the D3 authoring checklist

## Summary
Amend the execution-surface prompts (Codex packet-execution prompt, Copilot in-IDE custom instructions, Claude Code authoring-mode system instructions) so each (a) emits the correct `Authorship:` line and commit trailer per D6, and (b) surfaces the load-bearing D3 authoring categories as a brief pre-diff checklist per D3's upstream-awareness clause.

## Context
ADR-0044 D6 says the Codex/Copilot/Claude-Code execution surfaces are amended in follow-up packets to emit the `Authorship:` line automatically — a small change to each surface's commit/PR-creation template — so the `authorship-check` job (packet 07) does not fail agent PRs. D3's upstream-awareness clause additionally requires each execution surface to surface the load-bearing authoring categories (Correctness, Code Quality, SOLID, Reuse, Security, Performance, Testing, AI/agent-specific, Human Factors) as a brief authoring checklist, with the remaining categories by reference. This packet is the prompt-side amendment; the `authorship-check` CI enforcement is packet 07.

This packet covers the prompt/instruction text that lives in `HoneyDrunk.Architecture` (`.claude/agents/` execution-surface definitions and any Codex/Copilot prompt artifacts checked in here). Where an execution surface's instructions live outside this repo (e.g. a Codex cloud-config artifact in HoneyDrunk.Actions), this packet documents the required change and the dispatch plan notes the follow-up; the canonical authoring discipline still originates from D3.

## Scope
- The Claude Code authoring-mode system instructions (per ADR-0007, in `.claude/`).
- The Codex packet-execution prompt artifact (wherever it is checked in — `.claude/agents/` or a Codex-config doc in this repo; if it lives in HoneyDrunk.Actions, document the required change here and flag for a follow-up Actions packet).
- The Copilot in-IDE custom instructions artifact (`.github/copilot-instructions.md` or the equivalent checked into this repo's tooling docs).

## Proposed Implementation

### Authorship line + commit trailer (D6)
Each execution surface emits, on every PR it creates:
- A PR-body line `Authorship: <class>` — `agent-codex`, `agent-copilot`, or `agent-claude-code` respectively.
- A commit trailer: `Authorship: <class>` and `Co-authored-by:` per the existing commit-trailer convention.

So: Codex emits `Authorship: agent-codex`; Claude Code emits `Authorship: agent-claude-code`; Copilot-assisted PRs are accepted by the human and declare `agent-copilot` (or `mixed` where the human's contribution is substantial — the human picks).

### D3 authoring checklist (D3 upstream-awareness)
Each execution surface's prompt/instructions gains a brief authoring checklist surfacing the load-bearing categories the agent must consider *before producing a diff*: Correctness, Code Quality (Maintainability), SOLID, Reuse, Security, Performance, Testing, AI/agent-specific, Human Factors. The remaining eleven categories are referenced (a pointer to ADR-0044 D3 / `review.md`), not inlined — the checklist stays brief so it is actually read.

The instruction must state that this is the **authoring discipline** — the agent applies the rubric upstream so the reviewer catches less downstream.

## Affected Files
- The Claude Code authoring-mode system-instruction file
- The Codex packet-execution prompt artifact (or a documented follow-up if it lives outside this repo)
- The Copilot in-IDE custom-instructions artifact

## NuGet Dependencies
None. This packet edits prompt/instruction Markdown; no .NET project is created or modified.

## Boundary Check
- [x] Execution-surface prompts that live in `HoneyDrunk.Architecture` are edited here. Any artifact outside this repo is documented as a follow-up, not edited cross-repo.
- [x] No code change in any repo.

## Acceptance Criteria
- [ ] The Claude Code authoring-mode instructions emit `Authorship: agent-claude-code` (PR body + commit trailer)
- [ ] The Codex packet-execution prompt emits `Authorship: agent-codex` (PR body + commit trailer); if the artifact lives outside this repo, the required change is documented and a follow-up Actions packet is flagged
- [ ] The Copilot in-IDE custom instructions direct the human to declare `agent-copilot` (or `mixed`) on accepted PRs
- [ ] Each execution surface's instructions carry the brief D3 authoring checklist (the nine load-bearing categories) with the remainder by reference
- [ ] Each instruction states this is the upstream authoring discipline per ADR-0044 D3
- [ ] The classes emitted exactly match the five D6 classes; no new class invented

## Human Prerequisites
- [ ] If any execution-surface prompt artifact lives outside `HoneyDrunk.Architecture` (e.g. a Codex cloud-config in HoneyDrunk.Actions), confirm its location and either route that change to a follow-up Actions packet or apply it manually

## Dependencies
- `packet:04` — `review.md` rubric (**hard** — the authoring checklist must use the same category names as the rubric).
- `packet:07` — `authorship-check` job (soft — the emitted `Authorship:` line is what `authorship-check` validates; landing the emitters before/with the check avoids failing agent PRs).

## Referenced ADR Decisions

**ADR-0044 D6** — Codex/Copilot/Claude-Code execution surfaces are amended in follow-up packets to emit the `Authorship:` line automatically (commit/PR-creation template change), plus the commit trailer (`Authorship:` and `Co-authored-by:`).
**ADR-0044 D3 (upstream-awareness clause)** — Each execution surface's prompt references D3 as the authoring discipline; the load-bearing categories (Correctness, Code Quality, SOLID, Reuse, Security, Performance, Testing, AI-specific, Human Factors) are surfaced as a brief authoring checklist, the rest by reference.
**ADR-0007** — `.claude/agents/` is the single source of truth for agent definitions.

## Constraints
- **Exactly the five D6 classes.** Do not invent authorship classes.
- **Keep the checklist brief.** Nine load-bearing categories inline; the rest by reference. A long checklist is not read.
- **No cross-repo edits.** Document, do not edit, any artifact outside `HoneyDrunk.Architecture`.

## Labels
`docs`, `tier-2`, `meta`, `adr-0044`, `wave-2`

## Agent Handoff

**Objective:** Amend the Codex / Copilot / Claude Code execution-surface prompts to emit the `Authorship:` line + commit trailer (D6) and surface the brief D3 authoring checklist (D3 upstream-awareness).

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make agent PRs declare authorship automatically (so `authorship-check` passes) and make the rubric an upstream authoring discipline.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 2.
- ADRs: ADR-0044 (D6, D3), ADR-0007.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:04` — `review.md` rubric (hard).
- `packet:07` — `authorship-check` (soft).

**Constraints:**
- Exactly the five D6 classes; brief checklist; no cross-repo edits.

**Key Files:**
- Claude Code authoring-mode instructions; Codex packet-execution prompt; Copilot custom instructions.

**Contracts:** Emits the `Authorship:` line consumed by `authorship-check` (packet 07).
