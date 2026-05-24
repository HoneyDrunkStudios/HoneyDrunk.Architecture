---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0070", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0070", "ADR-0071"]
accepts: ["ADR-0070"]
wave: 2
initiative: adr-0070-frontend-stack
node: honeydrunk-architecture
---

# Update the 2026-05-23 charter-aware ADR draft to reflect ADR-0070's resolution

## Summary
Update `generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md` to reflect that ADR-0070 has resolved its open operator question (cluster 7.7 — mobile platform direction) and partially resolved cluster 7.8 (Web.UI Node, now paired with ADR-0070 + ADR-0071). Cluster 4.1 (DX Baseline Per Node — `make repo` / `make test` / `make pack`) remains explicitly an open ADR candidate, now slightly **expanded in scope** because ADR-0070 commits the Grid to three stacks (React, Blazor, React Native + Expo) and the DX-baseline ADR will need to declare per-stack semantics for each.

## Context
ADR-0070 is the operator answer to a question the 2026-05-23 charter-aware draft flagged explicitly. From the draft's "Operator questions" section (around line 775):

> 4. **Mobile baseline: MAUI vs. native vs. React Native vs. Flutter.** Cluster 7.7. Big platform-direction decision; doesn't belong in a candidate document; flagging so the operator schedules it explicitly.

That decision is now made: ADR-0070 D3 picks React Native + Expo. The draft's text needs updating so future readers see the resolution rather than re-litigating the question.

Cluster 7.8 (HoneyDrunk.Web.UI) is paired with ADR-0070 via ADR-0071. ADR-0070 Accepted unblocks ADR-0071's acceptance checklist (which requires the paired ADR-0070 be Accepted first). The draft's cluster 7.8 row should be annotated to reflect the active ADRs.

Cluster 4.1 (DX Baseline Per Node) is unaffected by ADR-0070's outcome in terms of go/no-go, but the **scope expands**: with three stacks committed, the DX-baseline ADR will need to declare `make repo` / `make test` / `make pack` / `make smoke` semantics for each. The draft's cluster 4.1 row should note this.

This is a docs-sync packet. No code, no .NET project, no catalog change. It exists to keep the draft truthful so the next round of charter-aware ADR scheduling reads accurate context.

## Scope
- `generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md` — update the relevant rows and notes to reflect ADR-0070's resolution.

## Proposed Implementation

### Part A — Mark cluster 7.7 RESOLVED

Locate the cluster 7.7 row (around line 424):

```
| 7.7 | **HoneyDrunk.Mobile** | Creator (or Core) | Seed | iOS/Android baseline: GridContext propagation, push wiring, auth flows, file pickers; MAUI vs. native is the first decision |
```

Mark it RESOLVED in place (preserving the historical row — do not delete). Suggested form:

```
| 7.7 | **Mobile platform direction** | — | **RESOLVED 2026-05-24 by [ADR-0070](../../adrs/ADR-0070-frontend-platform-stack.md) D3** | Decision: React Native + Expo (MAUI / native / Flutter explicitly rejected). The originally-proposed "HoneyDrunk.Mobile" Node is no longer the correct shape — Expo's managed workflow + the per-PDR consumer-app Node pattern obviates a Grid-level mobile-baseline Node at v1. Per-PDR mobile build pipeline configuration (Expo EAS) lands when the first mobile PDR enters scaffolding. |
```

Also update the "Operator questions" entry (around line 775):

```
4. **Mobile baseline: MAUI vs. native vs. React Native vs. Flutter.** Cluster 7.7. Big platform-direction decision; doesn't belong in a candidate document; flagging so the operator schedules it explicitly.
```

to:

```
4. **Mobile baseline: MAUI vs. native vs. React Native vs. Flutter.** Cluster 7.7. **RESOLVED 2026-05-24 by ADR-0070 D3: React Native + Expo.**
```

Also update the cluster-7.7 entry in the "Recommended formalize-now subset" line (around line 432):

```
**Recommended formalize-now subset:** 7.1 Search, 7.2 Geo, 7.3 Realtime, 7.5 Signal, 7.9 Legal, 7.7 Mobile baseline. The rest can be deferred or folded.
```

Strike 7.7 from the formalize-now subset (the question is now resolved; no formalization ADR is needed at the cluster level):

```
**Recommended formalize-now subset:** 7.1 Search, 7.2 Geo, 7.3 Realtime, 7.5 Signal, 7.9 Legal. ~~7.7 Mobile baseline~~ (resolved by ADR-0070 D3). The rest can be deferred or folded.
```

Also strike from the "HoneyDrunk.Mobile Node ADR — gate on first consumer-PDR mobile build" line (around line 712), or annotate it RESOLVED.

### Part B — Annotate cluster 7.8 with paired ADRs

Locate the cluster 7.8 row (around line 425):

```
| 7.8 | **HoneyDrunk.Web.UI** | Creator | Seed | Reusable web frontend kit: design tokens, auth widgets, dashboards — for non-Studios apps |
```

Annotate with the paired ADRs:

```
| 7.8 | **HoneyDrunk.Web.UI** | Creator | Seed | Reusable web frontend kit: design tokens, auth widgets, dashboards — for non-Studios apps. **Paired with [ADR-0070](../../adrs/ADR-0070-frontend-platform-stack.md) (Accepted 2026-05-24) and [ADR-0071](../../adrs/ADR-0071-stand-up-honeydrunk-web-ui-node.md) (Proposed; standup pending).** |
```

Also update the "Web frontend baseline" row in the "Sector candidates" table (around line 380):

```
| **Web frontend baseline (beyond Studios)** | Notify Cloud admin UI, Hearth web, others | New Node: `HoneyDrunk.Web.UI` |
```

Annotate:

```
| **Web frontend baseline (beyond Studios)** | Notify Cloud admin UI, Hearth web, others | New Node: `HoneyDrunk.Web.UI` — **standup ADR [ADR-0071](../../adrs/ADR-0071-stand-up-honeydrunk-web-ui-node.md) Proposed (paired with [ADR-0070](../../adrs/ADR-0070-frontend-platform-stack.md) Accepted 2026-05-24)** |
```

### Part C — Expand cluster 4.1 (DX Baseline) scope note

Locate cluster 4.1 (around line 276):

```
### 4.1 DX Baseline Per Node (`make repo`, `make test`, `make pack`, `make smoke`)
```

Add a scope expansion note in the cluster's body (the existing prose around this header) — something like:

```
**Scope expanded 2026-05-24:** ADR-0070 (Accepted) commits the Grid to three frontend stacks (React + TypeScript + Vite/Next; Blazor; React Native + Expo). The DX-baseline ADR must declare `make repo` / `make test` / `make pack` / `make smoke` semantics for **each** stack — not just .NET — because each stack's idioms differ. This expansion does not change the ADR's go/no-go; it does change the per-stack matrix the ADR is expected to commit.
```

Also update cluster 4.1's row in the "Ranked priority" table (around line 690):

```
| 9 | **DX Baseline Per Node (`make repo` contract)** | 4.1 | Substrate hygiene; reduces cost of every future cross-Node ADR. |
```

Annotate:

```
| 9 | **DX Baseline Per Node (`make repo` contract)** | 4.1 | Substrate hygiene; reduces cost of every future cross-Node ADR. **Scope: per-stack matrix (React, Blazor, RN+Expo, .NET) per ADR-0070.** |
```

### Part D — Anything else in the draft that mentions the now-resolved questions

Use the Grep tool with pattern `MAUI|Flutter|HoneyDrunk\.Mobile` against the draft file and either annotate each remaining hit with "RESOLVED by ADR-0070 D3" or strike where appropriate. Preserve the historical text — annotate, do not erase, so the draft remains a faithful record of what the operator was considering on 2026-05-23.

## Affected Files
- `generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`

## NuGet Dependencies
None. This packet touches only Markdown draft notes; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. ADR-draft documents live here.
- [x] No code change in any other repo.
- [x] No invariant change.
- [x] Preserves historical record — annotate, don't erase. The draft is a snapshot of operator thinking at 2026-05-23; the RESOLVED markings update the snapshot's resolution status without rewriting history.

## Acceptance Criteria
- [ ] Cluster 7.7 row carries a "RESOLVED 2026-05-24 by ADR-0070 D3" annotation and the originally-proposed "HoneyDrunk.Mobile" Node is noted as no longer the correct shape (Expo + per-PDR Nodes obviate it)
- [ ] The "Operator questions" entry for the mobile-baseline decision is annotated RESOLVED with the ADR-0070 D3 reference
- [ ] The "Recommended formalize-now subset" line strikes 7.7 (annotated with the resolution reference) — the rest of the list is unchanged
- [ ] The "HoneyDrunk.Mobile Node ADR" line in the "Ranked priority" or follow-up list is struck or annotated RESOLVED
- [ ] Cluster 7.8 row is annotated with the paired ADRs (ADR-0070 Accepted, ADR-0071 Proposed)
- [ ] The "Web frontend baseline" row carries the paired-ADRs annotation
- [ ] Cluster 4.1 (DX Baseline) carries a scope-expansion note: ADR-0070's three-stack commitment expands the DX-baseline ADR scope to a per-stack matrix
- [ ] No other section of the draft is altered beyond the annotations above
- [ ] No catalog edit, no invariant edit, no ADR-body edit

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0070 D3 — React Native + Expo for mobile.** One codebase for iOS and Android. MAUI, native Swift/Kotlin, Flutter, Cordova/Ionic/Capacitor are not adopted. This resolves the charter-aware draft's cluster 7.7 mobile-platform-direction question.

**ADR-0070 D4 — Three-stack tax acknowledged.** The DX-baseline ADR (charter-aware draft cluster 4.1) must declare `make repo` / `make test` / `make pack` / `make smoke` semantics for each of the three stacks (React, Blazor, RN+Expo) plus .NET.

**ADR-0071 — HoneyDrunk.Web.UI Node standup (Proposed; paired with ADR-0070).** The Web.UI Node ships tokens, primitive CSS, and per-stack component implementations. ADR-0071's acceptance gates on ADR-0070 being Accepted (which packet 00 of this initiative delivers).

**Charter-aware draft (2026-05-23) — operator-thinking snapshot.** The draft records what the operator was considering at the time of authoring. Updates to it should annotate the snapshot's resolution status without erasing the original text — the draft remains a historical record.

## Constraints
- **Annotate, do not erase.** The draft is a snapshot of operator thinking on 2026-05-23. Mark the resolved items with their resolution + reference, but preserve the original text so the draft reads as a faithful record.
- **No edits outside the named clusters.** Cluster 7.7, cluster 7.8, the cluster 4.1 scope note, and the "Operator questions" / "Ranked priority" / "Web frontend baseline" / "Recommended formalize-now subset" entries that reference those clusters. Other clusters are unaffected by ADR-0070.
- **No ADR body edits.** ADR-0070's body stays as-is (packet 00 only flipped the Status header). ADR-0071's body stays as-is — it is still Proposed and outside this initiative's scope.
- **Path resolution.** The draft is at `generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`. Links from the draft to ADRs use `../../adrs/` (two levels up from `generated/adr-drafts/` to repo root, then into `adrs/`).

## Labels
`chore`, `tier-2`, `meta`, `docs`, `adr-0070`, `wave-2`

## Agent Handoff

**Objective:** Update the 2026-05-23 charter-aware ADR draft so cluster 7.7 (mobile platform) reads RESOLVED, cluster 7.8 (Web.UI) carries the paired-ADR annotation, and cluster 4.1 (DX Baseline) carries the scope-expansion note that ADR-0070's three-stack commitment imposes.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Keep the charter-aware draft truthful so the next round of charter-aware ADR scheduling reads accurate context.
- Feature: ADR-0070 Frontend Platform Stack rollout, Wave 2.
- ADRs: ADR-0070 (primary), ADR-0071 (paired Web.UI Node — Proposed).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0070 should be Accepted before its resolution is recorded in the draft.

**Constraints:**
- Annotate, do not erase — the draft is a historical snapshot.
- No edits outside the named clusters and their referenced entries.
- No ADR body edits.

**Key Files:**
- `generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`

**Contracts:** None changed.
