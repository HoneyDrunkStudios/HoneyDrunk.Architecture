---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0047", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0047", "ADR-0044"]
accepts: ["ADR-0047"]
wave: 2
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-architecture
---

# Update `.claude/agents/review.md` Testing Quality checklist per ADR-0047 D13

## Summary
Update the Testing Quality checklist in `.claude/agents/review.md` so the `review` agent enforces the concrete ADR-0047 standards on every PR — the testing pyramid, the per-tier coverage thresholds, the required-tier rule (invariant 50), the no-`Thread.Sleep` rule (invariant 51), the D10 naming/structure conventions, and the contract-test expectation — per the ADR-0047 D13 mapping to ADR-0044 D3 category 11.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0047 Consequences names "Update `.claude/agents/review.md` Testing Quality checklist per D13" as explicit follow-up. ADR-0047 D13 is the binding decision: "ADR-0044 D3 category 11 (Testing Quality) binds the `review` agent to a per-PR testing checklist. … This ADR binds the frameworks and structural standards; `.claude/agents/review.md` binds the per-PR checklist that enforces them." ADR-0047 D1's opening Context paragraph names this as a forcing function: "That checklist is meaningless without a committed framework for what 'good' looks like." ADR-0047 now supplies the framework; this packet wires it into the reviewer's checklist.

This is a docs/governance packet — it edits an agent definition, not code.

## Scope
- `.claude/agents/review.md` — the Testing Quality section (the ADR-0044 D3 category 11 entry).

## Proposed Implementation
Per ADR-0047 D13, update the Testing Quality checklist so each ADR-0044 D3 category-11 sub-bullet maps to a concrete, checkable standard:

| ADR-0044 D3 cat 11 sub-bullet | Concrete standard the reviewer checks |
|---|---|
| Coverage quality (happy/failure/edge/concurrency) | Per-tier thresholds from ADR-0047 D3 — Tier 0 85/80, Tier 1 75/70, Tier 2 60/55 (warn); plus reviewer judgment that the tests cover failure and edge paths, not just the happy path |
| Test architecture (maintainable, not brittle) | ADR-0047 D7 — AutoFixture for don't-care data, hand-written Builders for shape-significant data; ADR-0047 D10 naming/structure conventions |
| Verification depth (unit/integration/contract/E2E) | ADR-0047 D1 pyramid; D4 contract tests in Tier 2a `Contracts/`; invariant 50 — every Node has `*.Tests.Unit`, deployable Nodes also `*.Tests.Integration`, HTTP-fronted Nodes also `*.Tests.E2E` |
| Anti-patterns (testing internals, excessive mocking, non-deterministic) | ADR-0047 D10 — no `Thread.Sleep` (invariant 51, now analyzer-enforced per packet 03); async tests return `Task`/`ValueTask` not `void`, no `.Result`/`.Wait()`; AAA with one logical assertion |

Concretely, the checklist must add explicit checkable items so the reviewer flags:
1. A PR that adds a test project not matching the `*.Tests.Unit` / `*.Tests.Integration` / `*.Tests.Integration.Containers` / `*.Tests.E2E` naming (ADR-0047 D4/D10).
2. A deployable Node PR that ships without a `*.Tests.Integration` project, or an HTTP-fronted Node PR without `*.Tests.E2E` (invariant 50).
3. Test code containing `Thread.Sleep` (invariant 51) — note this is now also an analyzer error per packet 03, so the reviewer treats it as defence-in-depth.
4. Async test methods returning `void`, or using `.Result` / `.Wait()` (ADR-0047 D10).
5. A new `*.Abstractions` package or backing implementation that ships without a corresponding contract test under `Contracts/` (ADR-0047 D4).
6. Test stacks declaring `Moq` or `FluentAssertions` instead of `NSubstitute` / `AwesomeAssertions` (ADR-0047 D2) — post-migration, a reintroduction is a regression.

The checklist items are inlined in full in `review.md` (the review agent has no access to the ADR at PR time — same self-containment rule the scope agent follows).

## Affected Files
- `.claude/agents/review.md`

## NuGet Dependencies
None. This packet edits a Markdown agent definition; no .NET project is created or modified.

## Boundary Check
- [x] Agent definitions live in `HoneyDrunk.Architecture` `.claude/agents/` per ADR-0007 (single source of truth for agent definitions).
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `.claude/agents/review.md` Testing Quality section maps each ADR-0044 D3 category-11 sub-bullet to a concrete ADR-0047 standard per the D13 table
- [ ] The checklist contains explicit checkable items for: test-project naming convention, required-tier coverage (invariant 50), `Thread.Sleep` (invariant 51), async-`void`/`.Result`/`.Wait()`, missing contract tests, and `Moq`/`FluentAssertions` reintroduction
- [ ] Every standard is inlined in full in `review.md` — no bare "see ADR-0047" pointer (self-containment rule)
- [ ] The per-tier coverage numbers (85/80, 75/70, 60/55) are stated explicitly in the checklist
- [ ] No change to the review agent's context-loading section in this packet (invariant 33 — the context-loading coupling between `review.md` and `scope.md` is out of scope here; this packet touches only the Testing Quality checklist)
- [ ] No catalog schema change

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0047 D13 — Relationship to ADR-0044 D3 category 11.** "This ADR binds the frameworks and structural standards; `.claude/agents/review.md` binds the per-PR checklist that enforces them." The D13 table maps each category-11 sub-bullet to its standard's home (D1, D3, D4, D7, D10).

**ADR-0047 D1, D3, D4, D7, D10** — the pyramid, per-tier coverage, integration/contract tests, test-data strategy, and naming/structure conventions the checklist now enforces.

**ADR-0044 D3 category 11 (Testing Quality)** — the rubric category that binds the `review` agent to a per-PR testing checklist.

## Referenced Invariants
> **Invariant 50 — Every Node has a `*.Tests.Unit` project; deployable Nodes also have a `*.Tests.Integration` project; HTTP-fronted Nodes also have a `*.Tests.E2E` project.** A missing required test tier is a CI gate failure.

> **Invariant 51 — Test code contains no `Thread.Sleep`.** Async work waits via `await`, polling primitives with explicit timeouts, or synchronously-completing fakes.

> **Invariant 33 — Review-agent and scope-agent context-loading contracts are coupled.** The set of files loaded by the review agent must be a superset of those loaded by the scope agent. *(Noted because this packet edits `review.md`; it touches only the Testing Quality checklist, not the context-loading section, so no mirrored `scope.md` edit is triggered. If a future packet changes either agent's context-loading list, that coupling must be honored.)*

## Constraints
- **Touch only the Testing Quality checklist.** Do not edit the review agent's context-loading section — that is invariant-33-coupled to `scope.md` and out of scope here.
- **Inline every standard in full.** The review agent reads `review.md` at PR time with no ADR access — bare ADR pointers fail the self-containment rule.
- **State the coverage numbers explicitly** — 85/80, 75/70, 60/55 — do not write "the D3 thresholds."

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0047`, `wave-2`

## Agent Handoff

**Objective:** Update the Testing Quality checklist in `.claude/agents/review.md` so the `review` agent enforces the concrete ADR-0047 standards on every PR, per the ADR-0047 D13 mapping.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make ADR-0044 D3 category 11 (Testing Quality) enforceable — give the reviewer the concrete "what good looks like" framework ADR-0047 supplies.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 2.
- ADRs: ADR-0047 (D13, D1, D3, D4, D7, D10), ADR-0044 (D3 category 11), ADR-0007 (agent definitions live in `.claude/agents/`).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- packet:00 — ADR-0047 acceptance (the checklist encodes Accepted decisions).

**Constraints:**
- Touch only the Testing Quality checklist — not the context-loading section (invariant 33 coupling).
- Inline every standard in full (self-containment).
- State coverage numbers explicitly.

**Key Files:**
- `.claude/agents/review.md` — Testing Quality section.

**Contracts:** None changed.
