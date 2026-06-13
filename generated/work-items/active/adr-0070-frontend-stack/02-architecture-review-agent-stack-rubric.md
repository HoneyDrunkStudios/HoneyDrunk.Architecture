---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0070", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0070", "ADR-0044", "ADR-0046"]
accepts: ["ADR-0070"]
wave: 2
initiative: adr-0070-frontend-stack
node: honeydrunk-architecture
---

# Add the ADR-0070 frontend-stack-compliance check to the review-agent rubric

## Summary
Extend `.claude/agents/review.md` so the review agent, when reviewing a PR that introduces or modifies a frontend surface, checks compliance with ADR-0070's three-stack policy. This is the symmetric pair of packet 01 (the scope-agent checklist update) — per invariant 33 the review-agent context must remain a superset of the scope-agent context, so any rule the scope agent enforces at packet-authoring time must also be catchable by the review agent at PR time.

## Context
Invariant 33 binds the scope-agent and review-agent context-loading contracts as a superset relationship:

> The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other. The coupling exists so there is no class of defect the scope agent could introduce at packet-authoring time that the review agent cannot catch at PR time for lack of information.

Packet 01 adds a frontend-stack-compliance item to the scope-agent's Quality Checklist. This packet's job is the symmetric addition on the review side. Without it, an out-of-policy stack could slip through if a packet was authored before packet 01 landed, or if a PR diverges from its packet (an `out-of-band` PR per invariant 32), and the review agent would have no rubric line to catch it.

ADR-0070's Operational Consequences explicitly anticipate this enforcement surface:

> AI-assistance gradient becomes a stack-selection input for future ADRs. Adopting a stack outside the React/.NET/native gradient (e.g., Elm, Svelte, Solid) carries the AI-multiplier cost and must justify the trade in the ADR that proposes it.

The review-agent rubric's section 2 (Architectural integrity) is the natural home — it already covers "Boundary enforcement," "Node governance," "Dependency hygiene," and "Architectural drift." A stack-compliance check fits naturally under Node governance / Architectural drift.

This is a docs/governance packet. No code, no .NET project.

## Scope
- `.claude/agents/review.md` — extend section 2 (Architectural integrity) with a frontend-stack-compliance bullet covering ADR-0070's three-stack policy. Match the existing format (concrete checks, Execution detail, Severity mapping).

## Proposed Implementation

### Part A — Section 2 (Architectural integrity) extension

In `.claude/agents/review.md`, locate the `### 2. Architectural integrity` section (search for the heading — do not rely on line numbers; two distinct sections at the same line cannot coexist if line numbers are cited). The section currently has four bullets (Boundary enforcement, Node governance, Dependency hygiene, Architectural drift). Add a fifth bullet:

```markdown
- **Frontend stack compliance per ADR-0070.** If the PR introduces or modifies a frontend surface, does it use the policy-correct stack? Consumer-facing web → React + TypeScript (Vite is the strong default; Next.js where SSR/SSG justifies it). Admin surface → Blazor only when it meets ADR-0070 D2's "simple enough" test (fewer than ~15 distinct views, fewer than ~30 interactive components, CRUD-shaped, internal/operator audience); larger admin surfaces use React. When the D2 thresholds are ambiguous or borderline, the default is React — the packet body should document the call (which thresholds were near, why React was picked, whether growth past the thresholds is expected within ~12 months). Mobile → React Native + Expo. Cross-stack design assets (tokens, primitive CSS, component contracts) flow through ADR-0071's Web.UI Node — not re-derived per surface. Out-of-policy stacks (Flutter, MAUI, native Swift/Kotlin, Vue/Svelte/Solid/Angular, Cordova/Ionic/Capacitor) require an ADR amendment cited in the PR body, not silent adoption.
```

The Execution detail and Severity mapping paragraphs already cover all five bullets in the section; consider tightening the existing prose only if a meaningful clarification is needed. Default: leave the prose unchanged — the new bullet adds to the existing scope of "Boundary enforcement, Node governance, Dependency hygiene, Architectural drift" without requiring rewording.

**Severity guidance for the new bullet** (consistent with the existing section 2 severity mapping):
- **Block** for an out-of-policy stack adoption without a cited ADR amendment (e.g., a PR that adds a Flutter mobile client, or a Vue.js consumer web surface).
- **Request Changes** for an in-policy stack used out-of-context (e.g., Blazor used for a 30-view multi-section consumer-facing dashboard that exceeds D2's "simple enough" threshold; React + TypeScript used for a tiny 3-screen admin surface where Blazor would be a better fit and the operator has not explicitly chosen otherwise).
- **Suggest** for cross-stack design assets being re-derived locally instead of flowing through Web.UI (per ADR-0071) — once Web.UI is past Phase 1 and the consumer surface exists.

### Part B — Optional: corresponding entry in the ADR-0044 D3 rubric (section 2 — Architectural integrity)

The ADR-0044 D3 review rubric (lower in the file) is the operational checklist consumed by the cloud-review runner. Its section 2 ("Architectural integrity") mirrors the Review Process section 2 and already lists Boundary enforcement, Node governance, Dependency hygiene, and Architectural drift. Locate it by searching for the section heading — do not cite line numbers, since the upper Review Process §2 and the lower D3 §2 share heading text and the rubric is actively edited.

Add the same frontend-stack-compliance bullet to the ADR-0044 D3 section 2 (verbatim or close to it — the rubric prefers tighter prose; match the existing bullets' length and form). The two sections (Review Process §2 and D3 §2) are kept symmetric per the existing pattern.

If the file's structure has shifted by the time this packet executes (e.g., the D3 rubric was further refactored), the substantive obligation is: **the review agent has a rule that fires on out-of-policy frontend-stack adoption**. The placement is "wherever the D3 rubric's Architectural-integrity / Node-governance section currently lives."

## Affected Files
- `.claude/agents/review.md`

## NuGet Dependencies
None. This packet touches only the Markdown review-agent definition; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. The review-agent definition lives here.
- [x] No code change in any other repo.
- [x] Symmetric pair to packet 01 — neither packet edits the other's file.
- [x] Honors invariant 33 (scope/review coupling): packet 01 + packet 02 land together so the review agent's rule-set is a superset of the scope agent's.

## Acceptance Criteria
- [ ] `.claude/agents/review.md` Review Process section 2 (Architectural integrity) contains a frontend-stack-compliance bullet matching Part A (or a substantively equivalent revision that names React + TS for consumer web, Blazor for simple admin per D2, RN + Expo for mobile, Web.UI for cross-stack design, and out-of-policy stacks requiring an ADR amendment) — locate by heading, not line number
- [ ] The ADR-0044 D3 review rubric's Architectural integrity section (lower in the same file) also contains the same or equivalent bullet — symmetric coverage so the cloud-review runner enforces the rule. Locate by heading, not line number
- [ ] Severity mapping for the new bullet is consistent with the existing section 2 severity mapping (Block for out-of-policy without an ADR amendment; Request Changes for D2-threshold violations; Suggest for cross-stack-design re-derivation)
- [ ] No edit to `.claude/agents/scope.md` in this packet (that is packet 01's scope)
- [ ] No catalog change
- [ ] No invariant change
- [ ] No code change in any repo

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0070 D1 — React + TypeScript for consumer-facing web.** Vite strong default; Next.js where SSR/SSG justifies it.

**ADR-0070 D2 — Blazor for simple admin only.** Permitted when the surface meets the "simple enough" test (fewer than ~15 views, fewer than ~30 interactive components, CRUD-shaped, internal/operator-facing audience). Larger admin surfaces use React.

**ADR-0070 D3 — React Native + Expo for mobile.** One codebase for iOS and Android. MAUI, native Swift/Kotlin, Flutter, Cordova/Ionic/Capacitor are not adopted.

**ADR-0070 D5 — Cross-stack design system via Web.UI (ADR-0071).** Tokens and primitive CSS are stack-agnostic. Components ship per stack but trace back to a shared design contract.

**ADR-0070 Invariants — scoping convention, enforced by scope agent and review agent.** Not a numbered invariant; both agents are responsible.

**ADR-0044 D3 — review-agent rubric.** `.claude/agents/review.md` carries the multi-category D3 rubric. New cross-cutting policy rules extend the existing categories; do not invent a new top-level category for one rule.

**Invariant 33 — Review-agent and scope-agent context-loading contracts are coupled.** The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other. The coupling exists so there is no class of defect the scope agent could introduce at packet-authoring time that the review agent cannot catch at PR time for lack of information. This packet's pair is packet 01.

## Constraints
- **Extend, do not fork.** The new bullet rides in section 2 (Architectural integrity) — the natural home alongside Boundary enforcement, Node governance, Dependency hygiene, and Architectural drift. Do not invent a new top-level "Frontend stack" category.
- **Mirror in the D3 rubric.** The lower-in-file ADR-0044 D3 rubric also gets the bullet in its symmetric section 2. The cloud-review runner consumes the D3 rubric.
- **Match the existing severity tone.** The severity guidance reads as "Block for X, Request Changes for Y, Suggest for Z" — consistent with the section's existing severity mapping.
- **Single concern.** This packet edits `.claude/agents/review.md` only. The scope-agent edit is packet 01.
- **Invariant 33 honored.** Packet 01 (scope.md) and packet 02 (review.md) land together so neither agent has a rule the other doesn't.

## Labels
`feature`, `tier-2`, `meta`, `docs`, `adr-0070`, `wave-2`

## Agent Handoff

**Objective:** Add the frontend-stack-compliance check to `.claude/agents/review.md` so the review agent enforces ADR-0070's three-stack policy at PR time, symmetric with packet 01's scope-agent rule.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Bind ADR-0070's policy as a review-agent rule, mirroring packet 01's scope-agent rule.
- Feature: ADR-0070 Frontend Platform Stack rollout, Wave 2.
- ADRs: ADR-0070 (primary), ADR-0044 (the D3 rubric this extends), ADR-0046 (specialist review agents — review/scope coupling source per invariant 33).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — hard. ADR-0070 must be Accepted before its policy is bound into the review rubric.

**Constraints:**
- Extend section 2 (Architectural integrity) — do not fork a new top-level category.
- Mirror the same bullet into the ADR-0044 D3 rubric (lower in the file).
- Match the existing severity tone (Block / Request Changes / Suggest).
- Single concern: `.claude/agents/review.md` only. The scope-agent edit is packet 01.

**Key Files:**
- `.claude/agents/review.md` — Review Process section 2 (Architectural integrity) and the ADR-0044 D3 rubric's Architectural integrity section lower in the same file. Locate both by heading, not by line number.

**Contracts:** None changed.
