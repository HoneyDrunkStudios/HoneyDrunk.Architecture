---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-3", "meta", "docs", "adr-0048", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0048", "ADR-0044", "ADR-0046"]
wave: 2
initiative: adr-0048-schema-evolution
node: honeydrunk-architecture
---

# Update review.md D3 category 13 to delegate depth to the `database` specialist agent

## Summary
Extend `.claude/agents/review.md` D3 category 13 (Data and persistence integrity) to delegate depth review of migration-touching PRs to the specialist `database` agent (authored in packet 02), keeping the generalist `review` agent's surface-level check and naming the conditions under which a PR triggers the specialist delegation. Mirrors the same delegation pattern already used by ADR-0046's specialist agents for the cost/security/performance/AI-safety/accessibility categories.

## Context
ADR-0048's Follow-up Work names: "Update `.claude/agents/review.md` D3 category 13 to delegate depth review to `database`."

`.claude/agents/review.md` is the canonical generalist review-agent rubric established by ADR-0044 (the cloud-code-review initiative — see sibling folder `adr-0044-cloud-code-review/`, packets 04 and 09 which built and rolled out the twenty-category D3 rubric). Category 13 is **Data and persistence integrity** — the generalist already checks for migration-touching PRs as part of the standard surface; ADR-0048 D13 says the *depth* review (the seven specific checks the specialist owns) lives in the specialist file, with the generalist delegating.

The delegation pattern is the one ADR-0046 established (its packet 02 documents the pattern in `copilot/specialist-review-rules.md` — when that lands; this packet does not depend on it landing first because the delegation language follows ADR-0044 D3's existing format). The generalist keeps the surface-level check ("is this PR migration-touching at all?"); when the answer is yes, the rubric instructs the operator to invoke the `database` specialist for depth review.

**Why this is its own packet, separate from packet 02.** Packet 02 creates the `database.md` agent file in isolation. Packet 03 wires it into the generalist `review` rubric. Splitting the two keeps the responsibilities clean: a revert of packet 02 (the agent file) does not affect `review.md`, and a revert of packet 03 (the delegation language) does not affect the agent file. Either piece can be re-iterated without disturbing the other.

This is a docs/agent-configuration packet. No code, no .NET project.

## Scope
- `.claude/agents/review.md` — extend D3 category 13 (Data and persistence integrity) with delegation language to the `database` specialist.
- No edit to `database.md` (packet 02 owns it).
- No edit to `scope.md` (packet 04 owns the scope-side pre-flight detection).
- No edit to any other agent file.

## Proposed Implementation
1. **Locate D3 category 13** in `.claude/agents/review.md`. The categories were established by ADR-0044 packets 04 and 09 (rubric-roll-out); the rubric is a twenty-category list. Category 13 is titled along the lines of "Data and persistence integrity" — confirm the exact title at edit time and match the existing capitalization/format.

2. **Add the delegation language.** The extension is additive — it does not remove the generalist's existing checks (which include surface-level "is the migration named clearly?", "is there a CHANGELOG entry?", "does the migration touch the right Node's `DbContext`?"). It adds:

   - A **trigger statement**: "If the PR touches any file under `*/Migrations/`, `*/Backfill/`, or any file referenced from a `DbContext`, the generalist `review` agent stops at surface-level checks and delegates depth review to the `database` specialist agent (per ADR-0048 D13)."
   - A **brief enumeration of the depth-review surface** the specialist owns, so the operator knows what the generalist is no longer doing in detail: D2 expand/contract conformance, D5 backward-compatibility window adequacy, D6 online primitives on tables ≥ 100k rows, D8 Audit append-only-by-interface constraints, D9 tenant scoping, D10 `[Rollback]` declaration, D12 round-trip test presence, EF Core idiom (`MigrationBuilder.Sql(...)` and `--idempotent` cleanliness).
   - An **invocation note**: "At v1 the operator manually invokes the `database` specialist per ADR-0046 D3. CI-triggered specialist invocation is a deferred follow-up under ADR-0046 D9."
   - An **advisory-posture reminder**: "Findings from both `review` (surface) and `database` (depth) are advisory; the human is the final arbiter (ADR-0011 D5, ADR-0046 D1)."

3. **Match the format of any existing category-13 entries.** If category 13 already references ADR-0042 idempotency-store touches or ADR-0030 audit-substrate touches (as the rubric may have been amended by other initiatives), preserve those references and add the new ADR-0048 D13 delegation alongside them. The delegation block lives at the **end** of category 13's checklist as a "for migration-touching PRs, delegate to `database`" stanza, not replacing the existing surface checks.

4. **Severity scale alignment.** Per ADR-0044 D3, the rubric uses a severity scale (blocking / strong / advisory). The delegation language inherits the scale — surface-level findings from the generalist follow the existing scale; depth findings from the specialist follow the same scale (packet 02 specified this). No new severity is introduced.

## Affected Files
- `.claude/agents/review.md`

## NuGet Dependencies
None. This packet touches only a Markdown agent-rubric file; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly. `.claude/agents/review.md` is governance content that lives in this repo.
- [x] No code change in any other repo.
- [x] The review-rubric is the ADR-0044-established surface; this packet extends category 13 of that rubric, consistent with ADR-0048 D13's explicit instruction.

## Acceptance Criteria
- [ ] `.claude/agents/review.md` D3 category 13 (Data and persistence integrity) carries a delegation stanza naming the `database` specialist agent
- [ ] The trigger condition is named: PRs touching `*/Migrations/`, `*/Backfill/`, or any file referenced from a `DbContext`
- [ ] The depth-review surface the specialist owns is enumerated (D2, D5, D6, D8, D9, D10, D12, EF Core idiom)
- [ ] The invocation mode is named as manual at v1 per ADR-0046 D3
- [ ] The advisory posture is preserved (both `review` surface and `database` depth findings are advisory; human is final arbiter)
- [ ] Existing category-13 checks (if any reference ADR-0042 or ADR-0030) are preserved, not replaced
- [ ] The severity scale matches the existing rubric's scale (blocking / strong / advisory per ADR-0044 D3)
- [ ] No edits to `database.md` (packet 02 owns it) or `scope.md` (packet 04 owns the pre-flight detection)
- [ ] No invariant change in this packet

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0048 D13 — Specialist `database` agent on every migration-touching PR.** The agent walks `Migrations/`, `Backfill/`, and DbContext-referenced files. The seven-category rubric (D2/D5/D6/D8/D9/D10/D12 plus EF Core idiom) is owned by the specialist; the generalist `review` agent delegates depth review on migration-touching PRs. The agent is "also invoked from the `scope` agent when packets imply schema changes" — but the `scope`-side wiring is packet 04, not this packet.

**ADR-0048 Follow-up Work — review delegation.** "Update `.claude/agents/review.md` D3 category 13 to delegate depth to `database`." This packet executes that follow-up.

**ADR-0044 D3 — Twenty-category review rubric and severity scale.** The rubric is the generalist `review` agent's checklist. Category 13 is Data and persistence integrity. The severity scale (blocking / strong / advisory) is reused by both generalist and specialist.

**ADR-0046 D1 — Specialists complement, do not replace, the `review` agent.** Specialist findings do not gate merge any more than the generalist's do — the advisory posture of ADR-0011 D5 is preserved. The delegation language inherits this posture.

**ADR-0046 D3 — Manual invocation only at v1.** No CI triggers; the operator decides when a lens applies. The delegation language reflects this.

**ADR-0011 D5 — Review agent is advisory; findings do not gate merge.** Preserved by the delegation language.

## Constraints
- **Additive, not replacing.** Existing category-13 surface checks (CHANGELOG entries, naming clarity, repo-correctness) are kept. The new delegation stanza is appended; it does not delete or rewrite existing language.
- **Match the rubric's existing format.** Severity tags, capitalization, list style — match the file's established conventions. ADR-0044 packets 04 and 09 set the format; do not invent a parallel structure.
- **Manual invocation at v1.** The delegation language names manual invocation per ADR-0046 D3. Do not write language that implies CI-triggered specialist invocation; that is a deferred follow-up under ADR-0046 D9.
- **Advisory posture preserved.** Both the surface check (generalist) and the depth review (specialist) are advisory. The merge gate stays with the human and CI.
- **`database` agent file may not have landed yet.** Packet 02 creates `database.md`. If packets 02 and 03 are executed in parallel and packet 02's PR hasn't merged when packet 03's PR is written, the delegation language still references `.claude/agents/database.md` as the target — the link will resolve once packet 02 merges. Either packet may merge first; the delegation language is text-only and is robust to either order. If packet 02 is reverted, packet 03's delegation language becomes a forward-reference; in that case, also revert packet 03.

## Labels
`feature`, `tier-3`, `meta`, `docs`, `adr-0048`, `wave-2`

## Agent Handoff

**Objective:** Extend `.claude/agents/review.md` D3 category 13 with delegation language pointing at the `database` specialist agent.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Wire the generalist `review` agent's surface check to delegate depth review of migration-touching PRs to the `database` specialist authored in packet 02.
- Feature: ADR-0048 Schema Evolution rollout, Wave 2.
- ADRs: ADR-0048 D13 (primary), ADR-0044 D3 (rubric format and severity scale), ADR-0046 D1/D3 (specialist pattern and manual-invocation at v1), ADR-0011 D5 (advisory posture).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0048 must be Accepted so the delegation language can cite its decisions as live rules.

**Constraints:**
- Additive — do not delete existing category-13 surface checks.
- Match the rubric's existing format and severity scale.
- Manual invocation at v1 per ADR-0046 D3.
- Advisory posture preserved.

**Key Files:**
- `.claude/agents/review.md` (specifically D3 category 13).

**Contracts:** None changed.
