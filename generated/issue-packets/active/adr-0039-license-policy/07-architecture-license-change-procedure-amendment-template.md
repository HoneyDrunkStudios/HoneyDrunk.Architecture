---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0039", "wave-3"]
dependencies: ["packet:00"]
adrs: ["ADR-0039"]
accepts: ["ADR-0039"]
wave: 3
initiative: adr-0039-license-policy
node: honeydrunk-architecture
---

# Add the license-change procedure to the ADR amendment template (ADR-0039 D9)

## Summary
Add the ADR-0039 D9 license-change procedure to the ADR amendment template / ADR authoring guidance, so any future ADR that changes a Node's license follows the mandatory one-way-door process: an ADR amendment, a `LICENSE.next` file committed for at least one minor release before the change, a `<PackageReleaseNotes>` callout on the next release, and — for FSL Nodes — no shortening of the MIT delay window.

## Context
ADR-0039 D9 establishes that changing a Node's license is a one-way door ("you cannot un-MIT a previously released version") and defines a mandatory procedure for it. ADR-0039's Follow-up Work names this as a discrete deliverable: "Add license-change procedure (D9) to the ADR amendment template."

The `adrs/` directory has an ADR template (and a `README.md` index). Whether a separate "amendment" template exists or amendments are recorded inline in the amended ADR is something the implementing agent confirms — either way, the D9 procedure needs to be discoverable by anyone authoring a license-changing ADR.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- The ADR template / ADR authoring guidance in `adrs/` — add (or link to) the D9 license-change procedure as a checklist any license-changing ADR must follow.
- `adrs/README.md` — if it documents the ADR process or amendment conventions, add a pointer to the license-change procedure.
- If the Grid has a dedicated amendment template or an `adr-amendment` doc, that is the primary home for the procedure.

## Proposed Implementation
1. **Locate the ADR template / amendment guidance.** Find the ADR template file in `adrs/` (commonly `adrs/template.md` or `adrs/ADR-template.md`) and any amendment-process documentation. Confirm whether amendments are a distinct template or inline.
2. **Add the D9 license-change procedure.** As a clearly-labeled checklist titled e.g. "License-change procedure (ADR-0039 D9)", in the location an ADR author authoring a license change will see it:
   > Changing a Node's license is a **one-way door** — you cannot un-license a previously released version. A license change requires **all** of:
   > - [ ] An ADR amendment to ADR-0039 (or a superseding ADR) recording the change and its rationale.
   > - [ ] A `LICENSE.next` file committed alongside the existing `LICENSE` in the affected repo for **at least one minor release** before the change takes effect — giving downstream consumers a release of advance notice.
   > - [ ] A `<PackageReleaseNotes>` entry on the next package release of the affected package(s) explicitly calling out the license change.
   > - [ ] For FSL-licensed Nodes specifically: **no shortening of the MIT delay window** — the 2-year FSL-to-MIT conversion window may not be made shorter retroactively.
   > - [ ] An update to the affected Node's `license` field in `catalogs/nodes.json` (the catalog is the single source of truth — ADR-0039 D8).
3. **Keep it discoverable from `adrs/README.md`.** If `adrs/README.md` describes the ADR lifecycle or amendment process, add a one-line pointer to the license-change procedure so an author does not miss it.
4. **Do not duplicate the full D9 text into the ADR template verbatim and then drift.** Prefer: the template carries the checklist (it is operational and short), with a citation back to ADR-0039 D9 as the authority. If the Grid's convention is to link rather than inline, link.

## Affected Files
- the ADR template / amendment template in `adrs/`
- `adrs/README.md` (if it documents the ADR/amendment process)

## NuGet Dependencies
None. This packet edits Markdown governance/template files. No .NET project is created or modified.

## Boundary Check
- [x] ADR templates and authoring guidance live in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] The ADR template / amendment guidance in `adrs/` carries the ADR-0039 D9 license-change procedure as a checklist an author authoring a license change will see
- [ ] The checklist covers all of: ADR amendment; `LICENSE.next` committed for ≥ 1 minor release; `<PackageReleaseNotes>` callout on the next release; no shortening of an FSL MIT-delay window; `catalogs/nodes.json` `license` field update
- [ ] The procedure cites ADR-0039 D9 as the authority
- [ ] `adrs/README.md` points to the procedure if it documents the ADR/amendment process
- [ ] The procedure is not verbatim-duplicated in a way that will drift from ADR-0039 D9 — it is the operational checklist with a citation back to the ADR

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0039 D9 — License changes are an ADR amendment.** "Changing a Node's license is a one-way door (you cannot un-MIT a previously released version). License changes require: an ADR amendment to this ADR (or a superseding ADR); a `LICENSE.next` file committed alongside the existing `LICENSE` for at least one minor release before the change takes effect; a `<PackageReleaseNotes>` entry on the next package release explicitly calling out the license change; for FSL-licensed Nodes, no shortening of the MIT delay window. This procedure is mandatory because the upstream-consumer impact of a license surprise is high and irreversible for already-shipped versions."

**ADR-0039 D8 — License catalog.** `catalogs/nodes.json` is the single source of truth for each Node's license — a license change must update the catalog field, which is why the catalog update is in the D9 checklist.

**ADR-0039 Follow-up Work.** "Add license-change procedure (D9) to the ADR amendment template."

## Constraints
- **The procedure is mandatory and all-of, not any-of** — every checklist item is required for any license change.
- **One-way door** — the procedure exists because license changes on already-released versions are irreversible; the `LICENSE.next` advance-notice window is the load-bearing part.
- **No FSL window shortening** — call this out explicitly; it is a specific D9 sub-rule.
- **Cite, don't drift** — the template carries the operational checklist with a citation to ADR-0039 D9; the ADR remains the authority.
- This packet does not bump a package version (no .NET project). Agents never push tags (invariant 27).

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0039`, `wave-3`

## Agent Handoff

**Objective:** Add the ADR-0039 D9 license-change procedure to the ADR amendment template / authoring guidance.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Any future license-changing ADR follows the mandatory one-way-door procedure — amendment, `LICENSE.next` advance window, release-notes callout, no FSL-window shortening, catalog update.
- Feature: ADR-0039 Grid Open Source License Policy rollout, Wave 3.
- ADRs: ADR-0039 (D9, D8, Follow-up Work).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0039 acceptance (soft — references ADR-0039 D9 as a live rule).

**Constraints:**
- The procedure is mandatory and all-of.
- Call out the no-FSL-window-shortening sub-rule explicitly.
- Cite ADR-0039 D9 as the authority; do not verbatim-duplicate in a way that drifts.

**Key Files:**
- the ADR template / amendment template in `adrs/`
- `adrs/README.md`

**Contracts:** None changed.
