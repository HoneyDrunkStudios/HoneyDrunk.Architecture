---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0044", "wave-2"]
dependencies: ["work-item:04", "work-item:07"]
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

**All three execution-surface artifacts live in `HoneyDrunk.Architecture` — confirmed at scoping time, no cross-repo edit and no follow-up Actions packet is required:**

- **Copilot in-IDE custom instructions** → `.github/copilot-instructions.md` (exists in this repo).
- **Claude Code authoring-mode instructions** → `copilot/global-instructions.md`, the Grid-wide all-agents instruction file (exists in this repo). The per-repo `CLAUDE.md` files are out of scope here — the canonical authoring discipline belongs in the shared `global-instructions.md` so every repo's Claude Code session inherits it.
- **Codex packet-execution discipline** → Codex has **no dedicated prompt artifact**; it executes against work items and handoff prompts whose format is defined in `routing/sdlc.md` (the "Handoff Protocol: Claude Code → Codex" section) and `copilot/issue-authoring-rules.md`. The Codex authoring discipline is therefore added to `routing/sdlc.md`'s handoff-protocol section and reflected in the work-item Agent Handoff template, not to a separate Codex config. The `Authorship: agent-codex` emission is a commit/PR-trailer convention recorded in `routing/sdlc.md` and `copilot/global-instructions.md` (the section covering all agents' commit conventions).

## Scope
- `copilot/global-instructions.md` — the Claude Code (and shared all-agent) authoring-mode instructions: add the `Authorship:` emission convention and the brief D3 authoring checklist.
- `.github/copilot-instructions.md` — the Copilot in-IDE custom instructions: add the human-declares-`agent-copilot` guidance and the brief D3 authoring checklist.
- `routing/sdlc.md` — the "Handoff Protocol: Claude Code → Codex" section: add the `Authorship: agent-codex` emission requirement and a reference to the D3 authoring checklist as the discipline Codex applies before producing a diff.

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
- `copilot/global-instructions.md` (Claude Code / shared all-agent authoring-mode instructions)
- `.github/copilot-instructions.md` (Copilot in-IDE custom instructions)
- `routing/sdlc.md` (Codex handoff-protocol section — Codex's `Authorship:` emission + D3 authoring discipline)

## NuGet Dependencies
None. This packet edits prompt/instruction Markdown; no .NET project is created or modified.

## Boundary Check
- [x] All three execution-surface artifacts (`copilot/global-instructions.md`, `.github/copilot-instructions.md`, `routing/sdlc.md`) live in `HoneyDrunk.Architecture` — all edits are in-repo, no cross-repo edit and no follow-up Actions packet needed.
- [x] No code change in any repo.

## Acceptance Criteria
- [ ] `copilot/global-instructions.md` instructs Claude Code to emit `Authorship: agent-claude-code` (PR body + commit trailer)
- [ ] `routing/sdlc.md`'s Codex handoff-protocol section requires Codex PRs to emit `Authorship: agent-codex` (PR body + commit trailer)
- [ ] `.github/copilot-instructions.md` directs the human to declare `agent-copilot` (or `mixed`) on Copilot-assisted accepted PRs
- [ ] Each of the three artifacts carries the brief D3 authoring checklist (the nine load-bearing categories) with the remainder by reference
- [ ] Each artifact states this is the upstream authoring discipline per ADR-0044 D3
- [ ] The classes emitted exactly match the five D6 classes; no new class invented

## Human Prerequisites
None. All three execution-surface artifacts (`copilot/global-instructions.md`, `.github/copilot-instructions.md`, `routing/sdlc.md`) live in `HoneyDrunk.Architecture` and are edited directly by this packet — no portal step, no cross-repo coordination.

## Dependencies
- `work-item:04` — `review.md` rubric (**hard** — the authoring checklist must use the same category names as the rubric).
- `work-item:07` — `authorship-check` job (soft — the emitted `Authorship:` line is what `authorship-check` validates; landing the emitters before/with the check avoids failing agent PRs).

## Referenced ADR Decisions

**ADR-0044 D6** — Codex/Copilot/Claude-Code execution surfaces are amended in follow-up packets to emit the `Authorship:` line automatically (commit/PR-creation template change), plus the commit trailer (`Authorship:` and `Co-authored-by:`).
**ADR-0044 D3 (upstream-awareness clause)** — Each execution surface's prompt references D3 as the authoring discipline; the load-bearing categories (Correctness, Code Quality, SOLID, Reuse, Security, Performance, Testing, AI-specific, Human Factors) are surfaced as a brief authoring checklist, the rest by reference.
**ADR-0007** — `.claude/agents/` is the single source of truth for agent definitions.

## Constraints
- **Exactly the five D6 classes.** Do not invent authorship classes.
- **Keep the checklist brief.** Nine load-bearing categories inline; the rest by reference. A long checklist is not read.
- **All three artifacts are in-repo.** `copilot/global-instructions.md`, `.github/copilot-instructions.md`, and `routing/sdlc.md` all live in `HoneyDrunk.Architecture` — edit them directly; there is no cross-repo artifact and no follow-up packet to flag.

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
- `work-item:04` — `review.md` rubric (hard).
- `work-item:07` — `authorship-check` (soft).

**Constraints:**
- Exactly the five D6 classes; brief checklist; all three artifacts are in-repo (no cross-repo edit, no follow-up packet).

**Key Files:**
- `copilot/global-instructions.md`, `.github/copilot-instructions.md`, `routing/sdlc.md`.

**Contracts:** Emits the `Authorship:` line consumed by `authorship-check` (packet 07).
