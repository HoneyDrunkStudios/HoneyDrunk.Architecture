---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0070", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0070"]
accepts: ["ADR-0070"]
wave: 2
initiative: adr-0070-frontend-stack
node: honeydrunk-architecture
---

# Add the ADR-0070 frontend-stack-compliance check to the scope-agent quality checklist

## Summary
Extend `.claude/agents/scope.md` so the scope agent, when authoring a packet for a frontend surface, enforces ADR-0070's three-stack policy at packet-authoring time. This is the enforcement surface ADR-0070 names in its Invariants section: "the scope agent's checklist gains a 'frontend stack matches ADR-0070' item at packet authoring time." Without this update, packets can silently propose out-of-policy stacks (Flutter, MAUI, native Swift/Kotlin, Blazor for a large consumer surface, Vue/Svelte/Solid) and the policy degrades to honor-system.

## Context
ADR-0070's Consequences/Invariants section is explicit about the enforcement surface:

> No new Grid-wide invariants in `constitution/invariants.md`. The following are committed conventions enforced by per-PDR scoping (the scope agent's checklist gains a "frontend stack matches ADR-0070" item at packet authoring time):
> - New consumer-facing web surfaces use React + TypeScript.
> - New admin surfaces use Blazor only when they meet D2's "simple enough" test.
> - New mobile surfaces use React Native + Expo.
> - Cross-stack design assets flow through ADR-0071's Web.UI Node.

The scope agent's `Quality Checklist` (around line 269 of `.claude/agents/scope.md`) is the natural home — it already enforces things like "Acceptance criteria include repo-level CHANGELOG.md update," "Labels include type, tier, and sector," and "All referenced invariants are inlined as full text." A stack-compliance line fits the existing format exactly.

The `Self-Containment Rule` section (around line 299) also benefits from a corresponding note: when a packet declares a frontend surface, the ADR-0070 stack constraints must be **inlined** in the packet body, not referenced by ADR ID, so the executing agent in the target repo (which has no access to the Architecture repo) can verify compliance without round-tripping.

This is a docs/governance packet. No code, no .NET project.

## Scope
- `.claude/agents/scope.md` — add a frontend-stack-compliance check to the Quality Checklist; add a stack-text-inlining note to the Self-Containment Rule.

## Proposed Implementation

### Part A — Quality Checklist addition

In `.claude/agents/scope.md`, locate the `## Quality Checklist` section (around line 269). Append (in the same checkbox style and severity tone as the existing items):

```markdown
- [ ] Frontend-surface stack compliance per ADR-0070: if the packet authors or scaffolds a frontend surface, the stack matches the ADR-0070 three-stack policy — React + TypeScript for consumer-facing web; Blazor only for admin surfaces meeting D2's "simple enough" test (~15 views, ~30 interactive components, CRUD-shaped, internal/operator audience); React Native + Expo for mobile. Cross-stack design assets flow through ADR-0071's Web.UI Node. Out-of-policy stacks (Flutter, MAUI, native Swift/Kotlin, Vue/Svelte/Solid/Angular, Cordova/Ionic/Capacitor) require an explicit ADR amendment before the packet is filed. **D2 tie-breaker:** when the admin surface's view/component count is ambiguous or borderline against the ~15/~30 thresholds, default to React + TypeScript and document the call in the packet body (which thresholds the surface is near, why React was picked over Blazor, whether the surface is expected to grow past the thresholds within ~12 months). Blazor is the exception, React is the default.
```

### Part B — Self-Containment Rule extension

In the `## Self-Containment Rule` section (around line 299), add a fifth bullet after the existing four (inline invariant text, summarize ADR decisions, include relevant boundary rules, frontmatter must include all board fields):

```markdown
5. **Inline ADR-0070 stack constraints when a packet authors a frontend surface.** The four stack rules (React + TS for consumer web; Blazor for simple admin; React Native + Expo for mobile; cross-stack design via Web.UI) are scoping conventions, not numbered invariants — so they will not be on the executing agent's invariants.md reading list. Inline the relevant rule(s) into the packet body so the executor can verify compliance without round-tripping to the Architecture repo.
```

### Part C — Mirror the change in review.md

Per invariant 33 ("Review-agent and scope-agent context-loading contracts are coupled. The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other."), the corresponding review-agent check lives in packet 02 of this initiative. This packet's PR description should reference packet 02's PR (or note that packet 02 lands in the same wave) so the coupling is visible to the reviewer.

This packet does **not** edit `.claude/agents/review.md` directly — that is packet 02's scope, intentionally separated to keep each packet single-concern.

## Affected Files
- `.claude/agents/scope.md`

## NuGet Dependencies
None. This packet touches only Markdown agent definition files; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. The scope-agent definition lives here.
- [x] No code change in any other repo.
- [x] Single-concern: scope-agent change only. The paired review-agent change is packet 02.

## Acceptance Criteria
- [ ] `.claude/agents/scope.md` Quality Checklist contains a frontend-stack-compliance item matching the text in Part A (or a substantively equivalent revision that names React + TS for consumer web, Blazor for simple admin meeting D2's test, RN + Expo for mobile, Web.UI for cross-stack design, the D2 ambiguous-threshold default-to-React tie-breaker with documentation-in-packet-body requirement, and out-of-policy stacks needing an ADR amendment)
- [ ] `.claude/agents/scope.md` Self-Containment Rule contains a bullet about inlining ADR-0070 stack constraints when a packet authors a frontend surface
- [ ] No edit to `.claude/agents/review.md` in this packet (that is packet 02's scope; the symmetric update lands there)
- [ ] No catalog change
- [ ] No invariant change
- [ ] No code change in any repo

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0070 D1 — React + TypeScript for consumer-facing web.** Every consumer-facing web surface uses React, TypeScript, Vite as the strong build-tool default (Next.js where SSR/SSG justifies it). Blazor is not the default for consumer web.

**ADR-0070 D2 — Blazor for simple admin only.** Permitted when the surface is fewer than ~15 distinct views, fewer than ~30 interactive components, CRUD-shaped, with internal/operator-facing audience.

**ADR-0070 D3 — React Native + Expo for mobile.** Every mobile surface uses RN + Expo. MAUI, native Swift/Kotlin, Flutter, Cordova/Ionic/Capacitor are not adopted.

**ADR-0070 D5 — Cross-stack design via Web.UI (ADR-0071).** Tokens and primitive CSS are stack-agnostic and ship from the Web.UI Node.

**ADR-0070 Invariants — scoping convention, not numbered invariants.** "The scope agent's checklist gains a 'frontend stack matches ADR-0070' item at packet authoring time." This packet is the enforcement step.

**Invariant 33 — Review-agent and scope-agent context-loading contracts are coupled.** The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other. The coupling exists so there is no class of defect the scope agent could introduce at packet-authoring time that the review agent cannot catch at PR time for lack of information. This packet's symmetric pair is packet 02 (review.md update).

## Constraints
- **Single concern.** This packet touches `.claude/agents/scope.md` only. The review-agent update is packet 02 — keeping them separate keeps each PR readable.
- **Match the existing format.** The new checklist item rides the same checkbox/sentence shape as the existing items in the Quality Checklist (see the items already in the file).
- **Cite the ADR by ID; inline the substance.** The checklist item references ADR-0070, but states the policy in full (React + TS consumer web; Blazor simple admin per D2; RN + Expo mobile) so a scope-agent run that has not just re-read ADR-0070 still has the rule.
- **No catalog or invariant edits.** This is the scope-agent surface — not a catalog or constitution change.

## Labels
`feature`, `tier-2`, `meta`, `docs`, `adr-0070`, `wave-2`

## Agent Handoff

**Objective:** Add the frontend-stack-compliance check to `.claude/agents/scope.md` so future packets are checked against ADR-0070 at packet-authoring time, and require inlining the stack rules in any packet that authors a frontend surface.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Bind ADR-0070's three-stack policy as scope-agent-enforceable scoping conventions at packet-authoring time.
- Feature: ADR-0070 Frontend Platform Stack rollout, Wave 2.
- ADRs: ADR-0070 (primary), ADR-0071 (paired Web.UI Node), ADR-0044 + ADR-0046 (review/scope agent coupling — see invariant 33).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — hard. ADR-0070 must be Accepted before its policy is bound into the scope-agent rubric.

**Constraints:**
- Single concern: `.claude/agents/scope.md` only. The symmetric review-agent edit is packet 02.
- Match existing checklist format and severity tone.
- Inline the stack rules' substance — do not reduce to "see ADR-0070."

**Key Files:**
- `.claude/agents/scope.md` (Quality Checklist section near line 269; Self-Containment Rule section near line 299)

**Contracts:** None changed.
