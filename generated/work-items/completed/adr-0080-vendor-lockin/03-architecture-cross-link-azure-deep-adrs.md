---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0080", "wave-2"]
dependencies: ["work-item:00", "work-item:01"]
adrs: ["ADR-0080", "ADR-0076", "ADR-0077", "ADR-0078"]
wave: 2
initiative: adr-0080-vendor-lockin
node: honeydrunk-architecture
---

# Cross-link ADR-0076, ADR-0077, and ADR-0078 to governance/vendor-postures/azure.md

## Summary
Update the three Azure-deep ADRs that currently cite a future "vendor-exit playbook" with no defined home — **ADR-0076** (Cache for Redis), **ADR-0077** (Bicep IaC), and **ADR-0078** (Entra External ID) — so their Follow-up Work and References sections point at `governance/vendor-postures/azure.md` as the resolved canonical home. **Citation-only edits**; no decisions, invariants, or scope claims change in any of the three ADRs.

## Context
ADR-0080's Context section names the load-bearing observation: each of ADR-0076, ADR-0077, and ADR-0078 cites a future "vendor-exit playbook" or "vendor-exit hedge" against the candidate-surface document (`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md` cluster 2.1). ADR-0080 D5 creates `governance/vendor-postures/azure.md` as the resolved canonical home; packet 01 ships the stub.

This packet completes the resolution by updating each of the three ADRs to point at the new canonical home instead of the draft.

The specific cross-link sites in each ADR (locate by phrase, not line number — files drift; the **phrase** is the anchor):

- **ADR-0076-cache-backing-azure-cache-for-redis.md:**
  - Context / D3 reasoning paragraph containing the phrase *"Azure-deep-but-protocol-portable posture"* with a citation to *"future vendor-exit playbooks named in [charter-aware draft] cluster 2.1."*
  - Consequences section entry containing the phrase *"The vendor-exit playbook for Azure Cache for Redis"* with a citation to *"[charter-aware draft] cluster 2.1."*
  - References section entry containing the phrase *"vendor-exit playbook (future)"* citing the charter-aware draft cluster 2.1.

- **ADR-0077-infrastructure-as-code-bicep.md:**
  - Context paragraph containing the phrase *"A vendor-exit playbook ([charter-aware draft cluster 2.1]) is the right complement."*
  - D5 / Decision paragraph containing the phrase *"Per the vendor-exit posture (D5), if the Grid ever migrates to Terraform."*
  - Operational Consequences paragraph containing the phrase *"A vendor-exit playbook for Azure (per [charter-aware draft cluster 2.1]) is named as follow-up work."*
  - Out of Scope item containing the phrase *"Vendor-exit playbook content. Named as follow-up."*
  - Follow-up Work item containing the phrase *"Author the vendor-exit playbook for Azure per [charter-aware draft cluster 2.1] (separate ADR)."*
  - References section entry containing the phrase *"vendor-exit playbook (follow-up)"* citing the charter-aware draft cluster 2.1.

- **ADR-0078-end-user-identity-entra-external-id.md:**
  - D3 reasoning paragraph containing the phrase *"This is the cheap vendor-exit hedge (the same pattern from [ADR-0076] D3 and [ADR-0077] D5)."* (No candidate-doc citation here; the cross-link goes to `governance/vendor-postures/azure.md` as the new home.)
  - Invariants section text *"vendor-exit hedge"* — already explicit and does not cite the candidate doc; add a parenthetical pointing at `governance/vendor-postures/azure.md`.
  - Consequences section paragraph containing the phrase *"The Azure-deep posture is reinforced. Identity is one more Azure-native binding; the vendor-exit cost compounds."* (Add a footnote/reference to the Azure governance file.)
  - References section (if it has a cluster-2.1 entry): replace with a reference to `governance/vendor-postures/azure.md` and ADR-0080.

The edits are **wording-only**. No decisions change. No invariants change. No scope claims change. The three ADRs continue to commit exactly what they commit today — only their pointer for the "future vendor-exit playbook" is rerouted from the candidate doc to ADR-0080's new canonical home.

ADR-0080's Affected Nodes section names this packet's scope explicitly: *"ADR-0076, ADR-0077, ADR-0078 — the three ADRs whose 'cheap vendor-exit hedge' language now points at this ADR's `governance/vendor-postures/azure.md` per D5. No amendments required; the cross-reference is by-convention."*

This is a docs/cross-link packet. No code, no .NET project.

## Scope
- `adrs/ADR-0076-cache-backing-azure-cache-for-redis.md` — update the three citation sites listed above.
- `adrs/ADR-0077-infrastructure-as-code-bicep.md` — update the six citation sites listed above.
- `adrs/ADR-0078-end-user-identity-entra-external-id.md` — update the citation sites listed above; add a parenthetical/footnote where the existing text is "vendor-exit hedge" without a citation.

## Proposed Implementation

For each of the three ADRs, follow this edit pattern at every citation site:

1. **Where the existing text cites the candidate-surface doc** (`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md` cluster 2.1) **as a future "vendor-exit playbook":** replace the citation with a reference to `governance/vendor-postures/azure.md` (the resolved canonical home per ADR-0080 D5) and to ADR-0080 as the authorizing ADR. Preserve the rest of the sentence — only the pointer changes.

   Example replacement pattern (ADR-0077 Context paragraph):
   - **Before:** *"A vendor-exit playbook ([charter-aware draft cluster 2.1]) is the right complement; this ADR pre-stages the modularization that makes that playbook cheaper."*
   - **After:** *"A vendor-exit playbook ([`governance/vendor-postures/azure.md`](../governance/vendor-postures/azure.md), authorized by [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md)) is the right complement; this ADR pre-stages the modularization that makes that playbook cheaper."*

2. **Where the existing text mentions a "vendor-exit hedge" or "vendor-exit posture" without a citation:** add a parenthetical reference to `governance/vendor-postures/azure.md` and ADR-0080 so the reader can find the canonical home.

   Example replacement pattern (ADR-0078 D3 reasoning):
   - **Before:** *"This is the cheap vendor-exit hedge (the same pattern from ADR-0076 D3 and ADR-0077 D5)."*
   - **After:** *"This is the cheap vendor-exit hedge (the same pattern from ADR-0076 D3 and ADR-0077 D5; the Grid's umbrella posture and canonical Azure governance file are [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) and [`governance/vendor-postures/azure.md`](../governance/vendor-postures/azure.md))."*

3. **In each ADR's References section:** wherever the cluster-2.1 entry appears, replace it (or supplement it) with entries for both ADR-0080 and `governance/vendor-postures/azure.md`. The candidate-surface doc itself can remain in References if useful for historical context, but the cluster-2.1 description should no longer read "future" — the "future" has been resolved.

   Example replacement pattern (ADR-0077 References entry):
   - **Before:** `- [generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md] cluster 2.1 — vendor-exit playbook (follow-up)`
   - **After:** Two entries:
     - `- [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) — vendor lock-in posture umbrella (resolves the future-playbook footnote)`
     - `- [governance/vendor-postures/azure.md](../governance/vendor-postures/azure.md) — Azure exit-playbook canonical home (stub at acceptance; full per-surface content deferred)`

4. **For ADR-0077 specifically:** the Follow-up Work item "Author the vendor-exit playbook for Azure per [charter-aware draft cluster 2.1] (separate ADR)" should be retired or marked as **resolved**, because ADR-0080 has now authored the umbrella and the canonical home. Recommended replacement: *"~~Author the vendor-exit playbook for Azure per [charter-aware draft cluster 2.1] (separate ADR).~~ **Resolved 2026-05-24:** authorized by [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md); the Azure canonical home is [`governance/vendor-postures/azure.md`](../governance/vendor-postures/azure.md). Full per-surface content remains deferred per ADR-0080 D8."*

5. **For ADR-0076 specifically:** the Consequences entry — *"The vendor-exit playbook for Azure Cache for Redis (when authored per [charter-aware draft] cluster 2.1) cites D3 as the hedge that pre-pays the migration cost."* — update similarly. Pattern: *"The vendor-exit playbook for Azure (per [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md), canonical home [`governance/vendor-postures/azure.md`](../governance/vendor-postures/azure.md)) cites D3 as the hedge that pre-pays the migration cost for the Cache for Redis surface specifically."*

6. **Do NOT modify any decision, invariant, scope claim, or non-citation text.** The edits are surgical. Every D-decision, every Invariants-section entry, every scope/non-scope claim in each ADR remains exactly as written.

7. **Verify path resolution.** From `adrs/{ADR-file}.md`, the relative path to `governance/vendor-postures/azure.md` is `../governance/vendor-postures/azure.md`. Confirm against the existing convention used elsewhere in the same ADR (e.g., how `adrs/` content links to `constitution/invariants.md` or `catalogs/nodes.json`).

8. **If an ADR's wording does not match the phrase-cite from the Context section above** (e.g., the file has been edited since 2026-05-24 when this packet was authored): apply the same edit pattern to the current text using `grep` against the cited phrase as the locator. The phrase-cites above are anchors, not contracts; the **pattern** is the contract.

## Affected Files
- `adrs/ADR-0076-cache-backing-azure-cache-for-redis.md`
- `adrs/ADR-0077-infrastructure-as-code-bicep.md`
- `adrs/ADR-0078-end-user-identity-entra-external-id.md`

## NuGet Dependencies
None. This packet touches only ADR Markdown files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.
- [x] No D-decision, Invariants, or scope-claim text changes in any of the three target ADRs — citation-only edits.

## Acceptance Criteria
- [ ] ADR-0076 — every "vendor-exit playbook" / "vendor-exit hedge" citation that pointed at the candidate-surface document (`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md` cluster 2.1) now points at `governance/vendor-postures/azure.md` and references ADR-0080; the References section carries entries for both
- [ ] ADR-0077 — every "vendor-exit playbook" citation now points at `governance/vendor-postures/azure.md` and references ADR-0080; the Follow-up Work item "Author the vendor-exit playbook for Azure" is marked **resolved** with the date 2026-05-24 and a pointer to ADR-0080; the References section carries entries for both
- [ ] ADR-0078 — the existing "vendor-exit hedge" mentions carry parenthetical pointers to `governance/vendor-postures/azure.md` and ADR-0080; the References section (if present) carries entries for both
- [ ] No D-decision text in any of the three ADRs is modified — diffs against pre-edit show only citation/footnote changes
- [ ] No Invariants section text in any of the three ADRs is modified
- [ ] No Status flip in any of the three ADRs (they retain their current Proposed/Accepted state)
- [ ] All new relative paths from `adrs/{ADR-file}.md` to `governance/vendor-postures/azure.md` resolve correctly (`../governance/vendor-postures/azure.md`)
- [ ] The candidate-surface document (`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`) is NOT modified by this packet — it remains a historical artifact recording the candidate-surfacing observation
- [ ] No edits to `governance/vendor-postures/azure.md` itself (packet 01's content is preserved)
- [ ] No edits to `governance/vendor-postures/github.md` (packet 02's content is preserved)
- [ ] No edits to `constitution/invariants.md` (invariants land in packet 00)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0080 Affected Nodes — ADR-0076, ADR-0077, ADR-0078.** Explicit: *"the three ADRs whose 'cheap vendor-exit hedge' language now points at this ADR's `governance/vendor-postures/azure.md` per D5. No amendments required; the cross-reference is by-convention."*

**ADR-0080 D5 — Per-vendor exit-playbook stubs and canonical home.** `governance/vendor-postures/` is the canonical home for per-vendor governance documentation. Future ADRs that name new vendor relationships cite this directory as the place where Accept-posture documentation lives.

**ADR-0080 Follow-up Work.** Names this packet's scope: *"Update ADR-0076, ADR-0077, and ADR-0078 follow-up notes to cite `governance/vendor-postures/azure.md` as the home for the future-state 'vendor-exit playbook' they reference (citation-only; no decision change)."*

**ADR-0076 D3 (preserved by this packet, not modified).** Standard Redis protocol only is the cheap vendor-exit hedge. The hedge text is preserved; only the pointer to where the playbook lives is updated.

**ADR-0077 D2/D5 (preserved by this packet, not modified).** Modularize by concern; the vendor-exit posture is acknowledged. The decisions are preserved; only the pointer is updated.

**ADR-0078 D3 (preserved by this packet, not modified).** OIDC-standard claims only is the cheap vendor-exit hedge. The decision is preserved; only the pointer is updated.

## Constraints
- **Citation-only edits.** No D-decision, Invariants-section, or scope-claim text changes in any of the three target ADRs. The edits are surgical pointers and References entries.
- **Pattern, not line numbers.** The Proposed Implementation locates each citation site by **phrase**, not by line number. Files drift; line numbers stale; phrases survive. Use `grep` (or equivalent) against the cited phrase to locate each edit site in the current file state.
- **Preserve the candidate-surface document.** The cluster-2.1 candidate doc is a historical artifact; do not edit it or remove its mention from References — supplement it with the new canonical-home entry. The candidate doc records the surfacing observation; this ADR resolves it.
- **Mark the ADR-0077 Follow-up Work item resolved, do not delete it.** The resolved-with-date pattern preserves the trail of how the item was closed. Same pattern as completed checkboxes in `initiatives/active-initiatives.md`.
- **Path resolution from `adrs/`.** `../governance/vendor-postures/azure.md` — one level up from `adrs/`, then into `governance/vendor-postures/`. Verify against the convention the ADR already uses for `constitution/` or `catalogs/` links.
- **Packet 01 must merge first.** The cross-link target `governance/vendor-postures/azure.md` must exist before this packet's edits land. If packet 01 has not landed, the cross-link points at a non-existent file.
- **No edits to ADRs outside the three named.** ADR-0080, ADR-0040, ADR-0045, ADR-0005, and others mention vendor-exit concerns; their integration is by the ADR-0080 umbrella, not by per-ADR cross-link. Only ADR-0076, ADR-0077, ADR-0078 had the explicit "future playbook" footnote that this packet resolves.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `adr-0080`, `wave-2`

## Agent Handoff

**Objective:** Update ADR-0076, ADR-0077, and ADR-0078 so their "future vendor-exit playbook" citations point at `governance/vendor-postures/azure.md` (the resolved canonical home authorized by ADR-0080 D5).

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Resolve the dangling footnote pointers. The three ADRs each cite a future playbook that now exists as a stub at `governance/vendor-postures/azure.md`; the cross-link makes the resolution discoverable.
- Feature: ADR-0080 Vendor Lock-In Posture rollout, Wave 2.
- ADRs: ADR-0080 D5 + Follow-up Work (primary — authorizes this packet); ADR-0076, ADR-0077, ADR-0078 (the three ADRs whose text is edited — citation-only).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — `governance/vendor-postures/azure.md` must exist before this packet's cross-links can resolve.

**Constraints:**
- Citation-only — no D-decision, Invariants, or scope-claim text changes.
- Preserve the candidate-surface doc as a historical artifact; supplement, do not erase.
- Apply the **pattern** by phrase-search; the packet cites no line numbers and the citation sites are anchored by phrase, not position.
- Only the three named ADRs (ADR-0076, ADR-0077, ADR-0078) are edited.

**Key Files:**
- `adrs/ADR-0076-cache-backing-azure-cache-for-redis.md`
- `adrs/ADR-0077-infrastructure-as-code-bicep.md`
- `adrs/ADR-0078-end-user-identity-entra-external-id.md`

**Contracts:** None changed.
