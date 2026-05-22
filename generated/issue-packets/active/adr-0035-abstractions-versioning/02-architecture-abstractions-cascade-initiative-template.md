---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0035", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0035", "ADR-0008"]
accepts: ["ADR-0035"]
wave: 1
initiative: adr-0035-abstractions-versioning
node: honeydrunk-architecture
---

# Author the abstractions-cascade initiative template (ADR-0035 D7)

## Summary
Create `initiatives/templates/abstractions-cascade.md` — the reusable initiative template for a coordinated major-version cascade of a Kernel-level Abstractions package, so the next ABI cascade (the second instance of the Kernel Adoption Alignment pattern) is scoped with explicit shape rather than triaged ad hoc.

## Context
ADR-0035 D7 commits the Grid to a procedure: when a major-version bump on a Kernel-level Abstractions package will cascade through dependent Nodes, the cascade is scoped as a named **initiative** under the ADR-0008 D10 slug convention (`adr-NNNN-<kebab>`), not as ad-hoc packets. ADR-0035's Context records why: the first Kernel Adoption Alignment initiative (11/11 closed, in exit review) "was triaged ad-hoc as an 'alignment initiative' because there was no policy. The next one will be the same unless this is decided." ADR-0026's `IGridContext.TenantId` strict-typing break "shipped as part of a coordinated cascade with no recorded deprecation window."

ADR-0035's Consequences (Affected Nodes) names the deliverable directly: "HoneyDrunk.Architecture — initiative slug convention (ADR-0008 D10) gains the cascade variant; an example template lives at `initiatives/templates/abstractions-cascade.md`." This packet authors that template.

D7 also adds an invariant (landed by packet 00): "A major-version cascade is an initiative, not a loose set of packets." This template is the artifact that makes that invariant operable — the scope agent fills it out when an ABI cascade is triggered.

This is a docs/governance-only packet. No code, no workflow, no .NET project. The `initiatives/templates/` directory does not exist yet — this packet creates it.

## Scope
- Create `initiatives/templates/` directory (new).
- Create `initiatives/templates/abstractions-cascade.md` — the cascade-initiative template.
- If `initiatives/` carries an index or `README.md` that lists its contents, add a row for the new `templates/` directory.

## Proposed Implementation
Author `initiatives/templates/abstractions-cascade.md` as a fill-in-the-blanks template that an agent (`scope`) instantiates when a major Abstractions bump triggers a cascade. ADR-0035 D7 enumerates exactly the fields the instantiated initiative file must record — the template provides a labeled slot for each:

1. **Bumping Node and version delta** — e.g. `Kernel.Abstractions 1.x → 2.0.0`. The package, the from-version, the to-version.
2. **Every downstream Node and the version it must move to** — a table of consumer Nodes, each with its target version. The template instructs the author to derive the consumer set from `catalogs/relationships.json` (the `consumed_by` / `consumes_detail` fields).
3. **Upgrade order** — the topological order downstream Nodes upgrade in, derived from `catalogs/relationships.json`. The template references the canonical Core Node order (`Kernel → Transport → Vault → Auth → Web.Rest → Data`) as the default and instructs the author to extend it for AI-sector / Ops Nodes per the dependency graph.
4. **`main` freeze status during the cascade** — a freeze/no-freeze decision with rationale, recorded per Node.
5. **Pre-release window dates (ADR-0035 D5)** — the `-preview.N` start date, the 14-calendar-day minimum-in-market floor, the `-rc.N` label and its 7-day floor, and the planned stable date. The template includes the no-skip rule (`1.0.0 → 2.0.0-preview.1 → … → 2.0.0-rc.1 → 2.0.0`, never direct).
6. **Deprecation-window record (ADR-0035 D6)** — for any member removed at the cascade's major, the minor release that first marked it `[Obsolete]`, the `DiagnosticId`, the `UrlFormat` migration-doc link, and confirmation the 60-day window (1.0+) has elapsed.

The template also includes the standard initiative-file sections an instantiated cascade needs — wave diagram, packet checklist, rollback plan, site-sync flag — matching the shape of existing dispatch plans (e.g. `kernel-adoption-alignment/dispatch-plan.md`, `adr-0034-public-package-distribution/dispatch-plan.md`). Mark clearly which sections are D7-mandated (1–6 above) and which are general initiative boilerplate.

Add a short header note: this template is for **major-version ABI cascades only**. A minor (additive) bump does not cascade — downstream Nodes pick it up on their own cadence (no consumer recompile is forced by an additive change, per ADR-0035 D2's binary-compatibility guarantee). The template is the D7 procedure made concrete; instantiating it is mandatory for a major cascade and not used otherwise.

Cross-reference: the template should point to ADR-0035 D5/D6/D7 and ADR-0008 D10 (the `adr-NNNN-<kebab>` slug convention) as the governing decisions, and note `kernel-adoption-alignment` as the retroactive first instance of the pattern.

## Affected Files
- `initiatives/templates/` (new directory)
- `initiatives/templates/abstractions-cascade.md` (new)
- `initiatives/` index / `README.md` if one exists (add a row for `templates/`)

## NuGet Dependencies
None. This packet creates a Markdown template; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly. Initiative templates are an architecture-repo artifact.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `initiatives/templates/abstractions-cascade.md` exists
- [ ] The template has a labeled, fill-in slot for each of the six ADR-0035 D7 fields: bumping Node + version delta; downstream Nodes + target versions; topological upgrade order; `main` freeze status; pre-release window dates (D5); deprecation-window record (D6)
- [ ] The template instructs the author to derive the downstream-Node set and upgrade order from `catalogs/relationships.json`
- [ ] The template includes the D5 no-skip pre-release rule and the 14-day / 7-day floors, and the D6 60-day deprecation window
- [ ] The template includes the general initiative sections (wave diagram, packet checklist, rollback plan, site-sync flag) and clearly distinguishes D7-mandated sections from boilerplate
- [ ] The template header states it is for major-version ABI cascades only and references ADR-0035 D5/D6/D7 + ADR-0008 D10
- [ ] `kernel-adoption-alignment` is referenced as the retroactive first instance of the pattern
- [ ] If `initiatives/` has an index, it lists the new `templates/` directory

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0035 D7 — Coordinated cascade procedure.** When a major-version bump on a Kernel-level Abstractions package will cascade through dependent Nodes (the Kernel Adoption Alignment pattern), the cascade is scoped as a named initiative under the ADR-0008 D10 slug convention, not as ad-hoc packets. The initiative file records: the bumping Node and its version delta; every downstream Node and the version it must move to; the topological upgrade order per `catalogs/relationships.json`; the freeze/no-freeze status of `main` during the cascade; the pre-release window dates (D5). "This becomes the second instance of the Kernel Adoption Alignment pattern with explicit shape rather than retroactive triage."

**ADR-0035 D5 — Pre-release channel.** New majors ship as `X.0.0-preview.N` first; a `-preview` release is in market a minimum of 14 calendar days with at least one internal Grid consumer pinned to it; `-rc.N` is the final pre-stable label, minimum 7 calendar days; no version skips.

**ADR-0035 D6 — Deprecation window.** A removed member carries `[Obsolete(message, error: false)]` with a `DiagnosticId` and a `UrlFormat` pointing to a migration doc, for at least one minor release; the window is a minimum of 60 calendar days between the first obsoleting minor and the removing major (1.0+; pre-1.0 collapses to "next minor").

**ADR-0035 Consequences — Affected Nodes.** "HoneyDrunk.Architecture — initiative slug convention (ADR-0008 D10) gains the cascade variant; an example template lives at `initiatives/templates/abstractions-cascade.md`."

**ADR-0008 D10 — Initiative slug convention.** Generated artifacts live under `generated/issue-packets/active/` grouped by initiative; the initiative slug follows `adr-NNNN-<kebab>`. The cascade variant of this convention is what D7 invokes.

## Constraints
- **Template, not an instantiated initiative.** This packet authors the blank template only. It does not scope or trigger any actual cascade — there is no live ABI cascade in flight. Filling the template out is future scope-agent work when a major bump is decided.
- **Major cascades only.** The template explicitly does not apply to minor/additive bumps — those do not force a consumer recompile (ADR-0035 D2 binary-compat guarantee) and need no cascade initiative.
- **Derive, do not hardcode, the consumer set.** The template instructs the author to read `catalogs/relationships.json` at instantiation time; it must not bake in a static Node list that will go stale.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0035`, `wave-1`

## Agent Handoff

**Objective:** Author `initiatives/templates/abstractions-cascade.md` — the reusable initiative template for a coordinated major-version Abstractions cascade, per ADR-0035 D7.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the ADR-0035 D7 "a major cascade is an initiative" invariant operable with a concrete fill-in template.
- Feature: ADR-0035 Abstractions Versioning and Deprecation Policy rollout, Wave 1.
- ADRs: ADR-0035 (D5/D6/D7 + Affected Nodes), ADR-0008 (D10 initiative slug convention).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0035 acceptance (soft — references ADR-0035 D7 as a live rule).

**Constraints:**
- See "Constraints" — inlined for agent consumption.
- Template only — do not scope or trigger an actual cascade.
- Major cascades only — the template does not apply to minor/additive bumps.
- The template derives the consumer set from `catalogs/relationships.json` at instantiation time; do not hardcode a Node list.

**Key Files:**
- `initiatives/templates/abstractions-cascade.md` (new)
- `initiatives/` index / `README.md` (if present)

**Contracts:** None — this is a governance template, not a runtime contract.
