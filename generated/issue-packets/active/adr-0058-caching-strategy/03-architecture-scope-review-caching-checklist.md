---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0058", "wave-2"]
dependencies: ["packet:00", "packet:01"]
adrs: ["ADR-0058"]
wave: 2
initiative: adr-0058-caching-strategy
node: honeydrunk-architecture
---

# Update scope.md and review.md with the ADR-0058 caching checklist

## Summary
Per ADR-0058's "Catalog and Constitution Obligations": update `.claude/agents/scope.md` and `.claude/agents/review.md` so both agents check for tenant-keying (D5), classification inheritance (D6), and that the invalidation lane is named (D7) whenever a packet introduces a new cache. Coupled context-loading per invariant 33 — both files updated in the same packet so they do not drift. Docs-only packet against the Architecture repo's agent definitions.

## Context
ADR-0058 explicitly calls out an agent-checklist obligation under "Catalog and Constitution Obligations":

> Update `.claude/agents/scope.md` and `.claude/agents/review.md` checklists per Invariant 33 (coupled context-loading): when a packet introduces a new cache, the reviewer checks tenant-keying (D5), classification inheritance (D6), and that the invalidation lane is named (D7).

Invariant 33 ("Review-agent and scope-agent context-loading contracts are coupled") makes this a single-packet, both-files update — they must move together so neither agent has a class of cache-related defect the other cannot see.

The three checks the agents gain:

1. **Tenant-keying (D5)** — if a packet introduces a cache that holds tenant-scoped data, the cache keys MUST follow the `tenant-{tenantId}-{logical-key}` convention; the discipline lives at the call site.
2. **Classification inheritance (D6)** — if a cached value's source is Restricted-tier or Sensitive-PII per ADR-0049, the cache inherits Restricted-tier handling (encrypted at rest, never in telemetry, subject to right-to-erasure).
3. **Invalidation lane named (D7)** — if a packet introduces a cache, the packet body MUST name exactly one of the three invalidation lanes (in-process direct invocation; Service Bus topic via Transport; Event Grid system topic) for that cache. A cache without a named lane is incomplete.

This is a docs/agent-config packet. No code, no .NET project.

## Scope
- `.claude/agents/scope.md` — extend the agent's quality-check / packet-authoring sections with the three cache obligations, placed where the existing checklist items live (likely under "Quality Checklist" or a similar section — verify at edit time).
- `.claude/agents/review.md` — extend the agent's review-category checklist with the same three checks, placed in whatever security / boundary / multi-tenant category structure the file already uses (likely category 9 Security / D5-tenant; category 9 Security / D6-classification; a new caching subcategory or appended into the boundary-preservation section for D7-lane).

## Proposed Implementation
1. **`.claude/agents/scope.md`** — locate the file's checklist or quality-check section (matching the "Quality Checklist" pattern visible in the agent's reference text). Add three new checklist items, each phrased as a positive obligation:
   - "If a packet introduces a cache that holds tenant-scoped data, the cache keys follow the `tenant-{tenantId}-{logical-key}` convention; the packet body inlines this rule as a Constraint."
   - "If a cached value's source is classified Restricted-tier or Sensitive PII per the data-classification regime, the cache inherits Restricted-tier handling (encrypted at rest, never in telemetry, subject to right-to-erasure); the packet body inlines this rule as a Constraint."
   - "If a packet introduces a cache, the packet body names exactly one of the three invalidation lanes (in-process direct invocation; Service Bus topic via Transport; Event Grid system topic) for that cache."
2. **`.claude/agents/review.md`** — locate the review-category structure (matching the D3 twenty-category rubric pattern). Add three new check items into the appropriate categories:
   - **Tenant-keying check** — under the multi-tenant or Security category. Phrasing: "When a cache holds tenant-scoped data, verify keys follow `tenant-{tenantId}-{logical-key}`. Bare logical keys for tenant-owned values are a leak risk (two tenants sharing an email or recipient ID will collide)."
   - **Classification-inheritance check** — under the Security or Data-Classification category. Phrasing: "When a cache holds values whose source is Restricted-tier or Sensitive PII, verify Restricted-tier handling at the backing (encryption-at-rest, no telemetry leak, erasure-event hook). The cache is a transmission medium, not a laundering surface."
   - **Invalidation-lane check** — under the boundary-preservation or Architecture category. Phrasing: "When a cache is introduced, verify the packet names exactly one of the three invalidation lanes (in-process; Service Bus topic; Event Grid system topic). A cache without a named lane is incomplete; mixing lanes per cache is forbidden."
3. **Cite the source.** Each new check item should reference ADR-0058 D5/D6/D7 by D-letter (not by ADR-number-in-prose — agent files are internal architecture artifacts where ADR citation by ID is acceptable and matches the surrounding convention; verify by scanning the file's existing references).
4. **Both files updated in the same commit / PR.** Invariant 33's coupling rule means scope.md and review.md must not diverge — one without the other is the anti-pattern the invariant exists to prevent.

## Affected Files
- `.claude/agents/scope.md`
- `.claude/agents/review.md`

## NuGet Dependencies
None. Markdown / agent-config packet.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture` (`.claude/agents/` is the canonical home for the Grid's agent definitions).
- [x] No code change in any other repo.
- [x] Both agents updated in the same PR per invariant 33.

## Acceptance Criteria
- [ ] `.claude/agents/scope.md` carries three new checklist items: tenant-keying (D5), classification inheritance (D6), invalidation lane named (D7)
- [ ] `.claude/agents/review.md` carries three matching check items, placed in the appropriate review-category sections (Security / Multi-Tenant / Boundary)
- [ ] Both files' new items reference ADR-0058 D5/D6/D7 by D-letter
- [ ] Both files are updated in the same commit / PR (invariant 33 — coupled context-loading contracts)
- [ ] No existing checklist items are removed or renumbered
- [ ] No ADR status edit in this packet

## Human Prerequisites
None. (Note: after this packet merges, the user should restart Claude Code so the updated agent files re-register — this is a runtime hygiene step the user owns, not a packet acceptance criterion.)

## Referenced ADR Decisions
**ADR-0058 D5 — Tenant-key isolation.** Any cache holding tenant-scoped data must prefix-key by `TenantId` using `{cache-purpose}:tenant-{tenantId}:{logical-key}`. The discipline lives at the call site; the backing stores what it is given.

**ADR-0058 D6 — Classification inheritance.** Cached values inherit the classification of their source per ADR-0049. Restricted-tier values inherit Restricted-tier handling (encrypted at rest, never in telemetry, subject to right-to-erasure).

**ADR-0058 D7 — Three named invalidation lanes.** In-process direct invocation; Service Bus topic via Transport; Event Grid system topic. Mutually exclusive per cache.

**ADR-0058 Catalog and Constitution Obligations.** Explicit: "Update `.claude/agents/scope.md` and `.claude/agents/review.md` checklists per Invariant 33 (coupled context-loading): when a packet introduces a new cache, the reviewer checks tenant-keying (D5), classification inheritance (D6), and that the invalidation lane is named (D7)."

**Invariant 33 — Review-agent and scope-agent context-loading contracts are coupled.**
> The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other. The coupling exists so there is no class of defect the scope agent could introduce at packet-authoring time that the review agent cannot catch at PR time for lack of information.

## Constraints
- **Both files updated in the same PR (invariant 33).** Do NOT land scope.md and review.md in separate PRs — the coupling rule forbids divergence even temporarily.
- **Positive obligations, not "if you remember."** Phrase the new items as obligations that fail review if absent, not as soft "consider checking" prompts.
- **Cite by D-letter only.** ADR-0058 D5/D6/D7 — not "ADR-0058" alone. The D-letters anchor the specific decisions; "ADR-0058" without a D-letter is ambiguous to a downstream reader.
- **Do not duplicate the invariant 33 text** in either file beyond what is already there; the new check items reference D5/D6/D7 by source, not by rewriting the coupling rule.
- **No ADR status flip.**

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0058`, `wave-2`

## Agent Handoff

**Objective:** Add three new caching checklist items (D5 tenant-keying, D6 classification inheritance, D7 named lane) to both `.claude/agents/scope.md` and `.claude/agents/review.md` in a single PR per invariant 33.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Ensure both scope-time packet authoring and PR-time review catch missing tenant-keying, missing classification inheritance, and missing invalidation-lane declaration on any new cache packet.
- Feature: ADR-0058 Grid-Wide Caching Strategy rollout, Wave 2.
- ADRs: ADR-0058 D5/D6/D7 (primary), ADR-0049 (classification regime), ADR-0026 (tenant primitives), ADR-0044 (review rubric structure for review.md placement).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — initiative registered so this packet has a known initiative anchor.
- `packet:01` — invariants 82/83/84 live in `constitution/invariants.md` before the agents reference D5/D6/D7 as canonical caching rules.

**Constraints:**
- Both files updated in the same PR (invariant 33). Do NOT split.
- Positive obligations; the review agent fails review if a new-cache packet does not name a lane, etc.
- Cite by D-letter (D5/D6/D7) so the rules are unambiguous.

**Key Files:**
- `.claude/agents/scope.md`
- `.claude/agents/review.md`

**Contracts:** None changed. Agent configuration only.
