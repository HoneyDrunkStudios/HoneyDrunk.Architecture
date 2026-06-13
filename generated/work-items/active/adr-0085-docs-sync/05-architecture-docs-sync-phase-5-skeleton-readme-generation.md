---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0085", "wave-5"]
dependencies: ["work-item:04"]
adrs: ["ADR-0085"]
accepts: []
source: strategic
generator: scope
wave: 5
initiative: adr-0085-docs-sync
node: honeydrunk-architecture
---

# Phase 5 — enable skeleton README auto-generation for repos missing required artifacts

## Summary
Activate Phase 5 of the ADR-0085 rollout: update the active-phase guard in `.claude/agents/docs-sync.md` to add **skeleton README generation** to the permitted auto-fix list for `block`-severity missing-required-artifact findings (D3 #1). When a repo with `*.csproj` projects has no root `README.md`, the agent auto-generates a skeleton from the Node's manifest in `catalogs/nodes.json` and includes a clear `<!-- docs-sync generated skeleton; please review -->` marker. This is the **highest-judgment auto-fix category** in the rollout — it lands last, after the operator has trust calibration from Phases 2–3 mechanical fixes and Phase-4 detection-only.

## Context
ADR-0085 D8 Phase 5 says: "Auto-generate skeleton README from `catalogs/nodes.json` Node manifest when a repo with `*.csproj` projects has no root README, marked as a docs-sync skeleton requiring human review. This is the highest-judgment auto-fix category; lands last so the operator has trust calibration from Phases 2–3."

The reason skeleton generation lands last:
- It writes *new prose* rather than rewriting existing strings.
- The generated content is a starting point requiring human review, not a finished doc — so the failure mode is "operator must edit before merging" rather than "operator must revert."
- Idempotency is satisfied by file-existence gating: the skeleton is generated **only when the file does not exist**; once the human creates or edits the README, subsequent runs do not regenerate.
- A repo with `*.csproj` projects but no root README is a hard invariant-12 violation — generating a skeleton is closer to "draw the operator's attention with a starting point" than "make an editorial decision the operator did not ask for."

This packet does **not** add skeleton generation for any other missing-artifact category (per-package READMEs, root CHANGELOGs, per-package CHANGELOGs, `AGENTS.md`, `CLAUDE.md`). Per-package READMEs are an obvious future expansion but are deferred to a follow-up packet against observed Phase-5 trust calibration. CHANGELOG skeletons would require generating release history, which is a different shape of work.

## Scope
- `.claude/agents/docs-sync.md` — update the **active-phase guard**: bump active phase from 4 to 5; expand `PERMITTED_AUTO_FIX_CATEGORIES` to add `missing-required-artifact:root-readme` (a sub-category specifier — only root README generation, not per-package or any other missing-artifact case).
- `.claude/agents/docs-sync.md` — author the **skeleton README generation logic**: detection condition (repo has at least one `*.csproj` AND `README.md` does not exist at repo root); content template sourced from `catalogs/nodes.json` Node manifest (Node name, sector, brief description, top-level purpose); mandatory marker `<!-- docs-sync generated skeleton; please review -->` at top of file; included sections (Title, Description, Status badges placeholder, Installation snippet using `<PackageId>` resolved from any `*.csproj` in the repo, Public API summary placeholder, Contributing pointer); idempotency rule (re-running on a repo where the file now exists produces no diff — the agent does **not** regenerate).
- `.claude/agents/docs-sync.md` — confirm the **`block`-severity dedup-grace exception** from D7 continues to apply: a `block` finding (missing required README) generates a packet AND a fresh PR commit every run until the underlying issue is fixed, even if a `proposed/` packet exists. At Phase 5 this means the agent also generates the skeleton on the same Friday run, in the same `chore/docs-sync-{YYYY-MM-DD}` branch.
- `constitution/agent-capability-matrix.md` — update the `docs-sync` row's "Produces" column to reflect the Phase-5 expansion (skeleton README generation for repos with `*.csproj` but no root README, with the `<!-- generated skeleton -->` marker).
- `generated/docs-sync-reports/README.md` — append a Phase-5 note documenting the skeleton-generation policy, the file-existence idempotency gate, the mandatory marker, and the limitation that only root READMEs are generated (no per-package READMEs, no CHANGELOGs, no agent-instruction docs).

## Proposed Implementation

### Active-phase guard update

```
ACTIVE PHASE: 5 (Phase 5 per ADR-0085 D8 — skeleton README generation added for missing-required-artifact:root-readme)
PERMITTED AUTO-FIX CATEGORIES: ["version-drift",
                                "catalog-reference-drift",
                                "dead-intra-repo-link",
                                "missing-required-artifact:root-readme"]   # new at Phase 5
PERMITTED AUTO-FIX SUB-CATEGORIES NOT INCLUDED: ["missing-required-artifact:per-package-readme",
                                                  "missing-required-artifact:root-changelog",
                                                  "missing-required-artifact:per-package-changelog",
                                                  "missing-required-artifact:agents-md"]
DETECTION CATEGORIES (all phases): unchanged from Phase 4 — includes all six categories.
IDEMPOTENCY GATE: skeleton generation is gated on README.md not existing at repo root. Once the
                  human creates or edits the README, subsequent runs do not regenerate.
MANDATORY MARKER: every generated skeleton starts with `<!-- docs-sync generated skeleton; please review -->`.
```

### Skeleton README content template
The skeleton sources content from `catalogs/nodes.json`'s entry for the target Node:

```markdown
<!-- docs-sync generated skeleton; please review -->

# {Node Name}

> **Status:** docs-sync skeleton — please review and replace this content.

{One-line description from catalogs/nodes.json}

## Status

<!-- status badges placeholder; populate with build/coverage/version badges per Grid convention -->

## Installation

```sh
dotnet add package {PackageId resolved from any *.csproj in the repo}
```

## Public API

<!-- summary of public types/interfaces/methods — see catalogs/contracts.json for the canonical list -->

## Contributing

See the repo-wide contributing guide.
```

The agent fills in `{Node Name}`, `{One-line description}`, and `{PackageId}` from `catalogs/nodes.json` and the first `*.csproj` it finds. The bracketed `<!-- ... -->` placeholders are deliberately preserved so the human knows what to fill in.

### Idempotency
- File-existence gate: the agent checks if `README.md` exists at the repo root **before** generating. If it exists (regardless of content), the agent does nothing.
- This means the human can create a minimal `README.md` (even just a title) to silence the skeleton-generator; subsequent runs respect the existing file.
- The `block` finding does **not** clear from the report until the underlying invariant-12 violation is actually fixed (a non-empty README with the standard sections per `repos/{node}/` template). The skeleton generation lands a starting point; the operator finishes the work.

### Interaction with the `block`-severity dedup-grace exception (D7)
D7 says: "`block`-severity findings have no dedup grace period. A `block` finding (e.g., a missing required README) generates a packet AND a fresh PR commit every run until the underlying issue is fixed."

At Phase 5 this means:
- The agent generates the skeleton on the first Friday run after Phase 5 lands.
- If the human has not yet reviewed and replaced the skeleton content by the next Friday, the agent does **not** regenerate (file-existence gate).
- A `proposed/` packet is also generated for the `block` finding (per D7's "block findings generate a packet every run until fixed"), and the dedup rule from Phase 2 protects existing un-triaged packets — so this is bounded.
- The skeleton's presence does **not** clear the `block` finding from the report; the report continues to surface "missing standard sections" or "skeleton not yet replaced" until the operator finishes the work.

### Capability-matrix update
- `docs-sync` row's "Produces" column: append "skeleton README generation for repos with `*.csproj` but no root README (with `<!-- generated skeleton -->` marker)" to the cross-repo PR scope.
- No new line in the Artifact Map.

### Report-directory README update
Append a Phase-5 section to `generated/docs-sync-reports/README.md`:
- As of Phase 5, the per-Node sections include skeleton-README-generation entries when applicable.
- Skeleton generation is gated on `README.md` not existing at the repo root (idempotency); the human can create even a minimal README to silence the generator.
- Skeleton READMEs always start with `<!-- docs-sync generated skeleton; please review -->` and explicitly flag that the operator must finish the work.
- Per-package READMEs, CHANGELOGs, and agent-instruction docs are **not** skeleton-generated at Phase 5 — those remain `block`-or-`note` findings in the report for human action. Future packets may expand this if Phase-5 trust calibration is positive.

## Affected Files
- `.claude/agents/docs-sync.md`
- `constitution/agent-capability-matrix.md`
- `generated/docs-sync-reports/README.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any other repo (the runtime skeleton READMEs land via cross-repo PRs, post-merge).
- [x] No new runtime dependency between Nodes.
- [x] No `HoneyDrunk.Actions` change.

## Acceptance Criteria
- [ ] `.claude/agents/docs-sync.md` active-phase guard reads Phase 5; `PERMITTED_AUTO_FIX_CATEGORIES` now includes `missing-required-artifact:root-readme`; sub-categories explicitly NOT included (per-package READMEs, CHANGELOGs, agent-instruction docs) are listed
- [ ] The skeleton-README content template is documented with the mandatory `<!-- docs-sync generated skeleton; please review -->` marker, the `catalogs/nodes.json`-sourced fill-ins, and the placeholder `<!-- ... -->` blocks preserved for human action
- [ ] The file-existence idempotency gate is documented: the agent checks for `README.md` at repo root before generating; if present, no action
- [ ] The interaction with the `block`-severity dedup-grace exception is documented: skeleton lands the starting point, but the `block` finding remains in the report until the operator finishes the work
- [ ] `constitution/agent-capability-matrix.md` `docs-sync` row's "Produces" column reflects the Phase-5 expansion
- [ ] `generated/docs-sync-reports/README.md` has a Phase-5 section describing the skeleton-generation policy, the idempotency gate, the marker, and the deliberate sub-category limitation (only root READMEs at Phase 5)
- [ ] The repo-level `CHANGELOG.md` carries an entry for this Phase-5 activation
- [ ] No README update required at repo root

## Human Prerequisites
- [ ] Confirm Phase 4's exit criterion (manageable false-positive rate on dependency-graph and agent-instruction drift findings) is met before this packet's PR merges.
- [ ] After this packet's PR merges, watch the first 2–4 Phase-5 runs closely: confirm the skeleton-generation only fires for repos with `*.csproj` AND no root README; the mandatory marker is present; the file-existence gate works (re-running on a repo where the human has subsequently created any README produces no skeleton).
- [ ] Plan to **review every skeleton README the agent generates** before its PR merges — Phase 5 is the highest-judgment auto-fix in the rollout, and operator review is the safety mechanism.

## Dependencies
- `work-item:04` — **hard**. Phase 4 must be observed working before Phase 5 lands the highest-judgment auto-fix.

## Referenced ADR Decisions

**ADR-0085 D3 #1 (Missing required artifacts)** — A repo with `*.csproj` projects but no root `README.md` is an Invariant 12 violation, severity `block`.
**ADR-0085 D4 (skeleton-README disposition, verbatim):** "Missing required artifact (no root README in a repo with `*.csproj`) → **Conditionally yes** — agent generates a skeleton README from `catalogs/nodes.json` Node manifest, marked `<!-- docs-sync generated skeleton; please review -->`."
**ADR-0085 D7 (`block`-severity dedup-grace exception, verbatim):** "`block`-severity findings have no dedup grace period. A `block` finding (e.g., a missing required README) generates a packet AND a fresh PR commit every run until the underlying issue is fixed, even if a `proposed/` packet exists. This is deliberate: missing required docs are an Invariant 12 violation and the per-week reminder is the floor."
**ADR-0085 D7 (auto-fix idempotency, verbatim):** "skeleton-README generation is gated on the file not existing, so it cannot re-fire on a repo whose README the human has since created."
**ADR-0085 D8 Phase 5** — Auto-generate skeleton README from `catalogs/nodes.json` Node manifest when a repo with `*.csproj` projects has no root README. Highest-judgment auto-fix category; lands last so the operator has trust calibration from Phases 2–3.

## Constraints
> **Invariant 12 (verbatim excerpt):** Repo-level `CHANGELOG.md` next to the `.slnx` file: Mandatory. Every repo must have one. Every package directory must also contain a `README.md` describing the package's purpose, installation, and public API surface. New projects must have both files from the first commit.

> **ADR-0085 D7 (auto-fix idempotency, applied verbatim):** Skeleton-README generation is gated on the file not existing, so it cannot re-fire on a repo whose README the human has since created.

- **Only root README skeletons at Phase 5.** Per-package READMEs, CHANGELOGs, and agent-instruction docs are NOT skeleton-generated. Future packets may expand if Phase-5 trust calibration is positive.
- **Mandatory marker.** Every generated skeleton starts with `<!-- docs-sync generated skeleton; please review -->`. Without it, downstream readers cannot tell the file is agent-generated.
- **File-existence gate is the idempotency mechanism.** The human can silence the generator by creating any README — even a minimal one.
- **The `block` finding does not clear from the report when the skeleton lands.** Only when the operator finishes the work (replaces the skeleton content with real documentation that satisfies invariant 12's standard sections) does the finding clear.
- **PR metadata for this packet's implementation PR:** `Authorship: agent-claude-code` + `Work Item: HoneyDrunkStudios/HoneyDrunk.Architecture#<issue-number>` once filed.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `adr-0085`, `wave-5`

## Agent Handoff

**Objective:** Activate Phase 5 of ADR-0085: add skeleton README generation to the `docs-sync` permitted auto-fix list for repos with `*.csproj` but no root README, scoped narrowly to root READMEs only (not per-package, not CHANGELOGs, not agent-instruction docs).

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land Phase 5 of ADR-0085 after Phase 4's exit criterion is met. Highest-judgment auto-fix in the rollout; lands last for trust calibration.
- Feature: Grid-Wide Documentation Currency Agent rollout, Phase 5.
- ADRs: ADR-0085 (D3 #1, D4, D7, D8 Phase 5), Invariant 12.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:04` — hard.

**Constraints:**
- Only root READMEs at Phase 5.
- Mandatory `<!-- docs-sync generated skeleton; please review -->` marker.
- File-existence gate is the idempotency mechanism — the human can silence by creating any README.
- The `block` finding stays in the report until the operator finishes the work.
- Operator review is the safety mechanism — review every skeleton PR before merge.

**Key Files:**
- `.claude/agents/docs-sync.md` (active-phase guard + skeleton-generation logic)
- `constitution/agent-capability-matrix.md`
- `generated/docs-sync-reports/README.md`

**Contracts:** None changed.
