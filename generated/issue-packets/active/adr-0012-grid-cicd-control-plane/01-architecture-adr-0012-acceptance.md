---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0012", "wave-1"]
dependencies: []
adrs: ["ADR-0012"]
wave: 1
initiative: adr-0012-grid-cicd-control-plane
node: honeydrunk-architecture
---

# Feature: Accept ADR-0012 — Grid CI/CD Control Plane, finalize invariants 37-41, amend review agent

## Summary
Flip ADR-0012 from `Proposed` to `Accepted`, renumber the ADR's five invariants from 34-38 (the draft's numbering) to 37-41 (since ADR-0015 has claimed 34-36 in the meantime), add the renumbered invariant text under a new "Grid CI/CD Invariants" section in `constitution/invariants.md`, refresh the ADR index row, register the rollout initiative in `active-initiatives.md` and `roadmap.md`, and amend `.claude/agents/review.md` with the new "caller workflow without `permissions:`" Request Changes rule mandated by ADR-0012's follow-up work.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0012 was drafted Proposed on 2026-04-13. The draft text numbers its invariants 34-38, but ADR-0015 (Container Hosting Platform, Proposed 2026-04-18) has since landed and claims 34-36 in `constitution/invariants.md`. ADR-0012's invariants must therefore be renumbered to 37-41 before they land. Three additional things keep the current state honest but unfinished: the ADR index row in `adrs/README.md` reads `Proposed`; the rollout initiative is not yet registered in `active-initiatives.md` or `roadmap.md`; and `.claude/agents/review.md` does not yet contain the Request Changes rule for caller workflows that omit `permissions:` (a follow-up the ADR explicitly names). The Grid is one PR away from a coherent state — this packet is that PR. After it lands, downstream packets in this initiative (catalog `tracked_workflows`, grid-health aggregator, consumer-usage refresh, action-pins inventory, D4 retrofit audit, caller-permissions audit, Node 20 bump) become enforceable against live invariants rather than aspirational ones.

This packet is the **single mechanically-coupled flip** that ADRs require per the scope-agent acceptance convention: status flip, index row flip, invariant renumber + add, initiative trackers, and the review-agent amendment all land in one merge.

## Scope

All edits are in the `HoneyDrunk.Architecture` repo. No code. No secrets.

### Part A — ADR file flip

In `adrs/ADR-0012-grid-cicd-control-plane.md`, change the front-matter line:

```
**Status:** Proposed
```

to:

```
**Status:** Accepted
```

Inside the ADR body, the "Grid CI/CD Invariants" subsection (currently lines ~204-214) begins:

> The following invariants must be added to `constitution/invariants.md` under a new **Grid CI/CD Invariants** section, numbered 34 onwards. Invariants 1-28 are the existing enforcement surface; 29-30 are reserved for ADR-0010; 31-33 are ADR-0011's code review invariants; 34 onwards are this ADR's.

Update that paragraph to read:

> The following invariants are added to `constitution/invariants.md` under a new **Grid CI/CD Invariants** section, numbered 37 onwards. Invariants 1-28 are the existing enforcement surface; 29-30 are reserved for ADR-0010; 31-33 are ADR-0011's code review invariants; 34-36 are ADR-0015's hosting-platform invariants; 37 onwards are this ADR's.

Then renumber the four numbered list items in that subsection from `34.` `35.` `36.` `37.` `38.` to `37.` `38.` `39.` `40.` `41.`. Do not edit any of the invariant prose itself — only the leading numbers and the introductory paragraph above.

Do not edit any other text in the ADR body. Body edits to an Accepted ADR beyond the renumber + acceptance flip are out-of-scope here.

### Part B — ADR index update

In `adrs/README.md`, the existing row for ADR-0012 reads `Proposed`. Update it to `Accepted` with the acceptance date set to the merge date of this packet's PR. Format and column layout match the existing rows for ADR-0010 and ADR-0011.

### Part C — Constitution invariants

In `constitution/invariants.md`, after invariant 36 (the last ADR-0015 hosting-platform invariant), add a new section:

```markdown
## Grid CI/CD Invariants

37. **`HoneyDrunk.Actions` is the source of truth for shared CI/CD configuration.** Shared tool configurations (gitleaks rules, CodeQL query packs, Trivy policy, dotnet-format rules, etc.) live under `HoneyDrunk.Actions/.github/config/`. Caller repos do not duplicate these files; they consume them via reusable-workflow checkout at job runtime. A caller repo may commit a `.<tool>.<ext>` at its root as a per-repo override, which is expected to extend the shared baseline rather than replace it. See ADR-0012 D2, D3.

38. **Reusable workflows invoke tool CLIs directly.** Wrapping a tool in a third-party marketplace action is forbidden for any tool that provides a stable CLI. Exceptions: first-party GitHub actions under `actions/*`, `github/codeql-action/*`, and composite actions authored inside `HoneyDrunk.Actions`. See ADR-0012 D4.

39. **Caller workflows declare a `permissions:` block that is a superset of the reusable workflow's declared permissions.** Callers that omit `permissions:` inherit the repository default, which is insufficient for any reusable workflow that requests a `write` scope. Validation failure is not detected until the next scheduled run; grid-health (invariant 40) is the safety net. See ADR-0012 D5.

40. **Grid pipeline health is centrally visible.** The `HoneyDrunk.Actions` `🕸️ Grid Health` issue is the single canonical view of CI/CD state across the Grid, updated at least daily by the grid-health aggregator. Staleness of that issue is itself a signal — the aggregator's own failure surfaces as the issue not updating. Real-time per-failure notification is separately delivered by the operator's GitHub profile notification settings ("Only notify for failed workflows"), and both mechanisms are mandatory. See ADR-0012 D6, D7.

41. **New Grid repos are added to `HoneyDrunk.Architecture/repos/` at creation time.** The grid-health aggregator reads the repo catalog to know which repos to poll; a repo missing from the catalog is invisible to grid observability. This invariant re-mandates the existing ADR-0008 / architecture-repo convention from the CI/CD visibility angle. See ADR-0012 D6.
```

The invariant text is taken from ADR-0012's body verbatim except for the two cross-references — invariant 39 references invariant 40 (was 37 in draft), and invariant 40 references the operator's profile notifications via D6/D7. Both cross-references are updated in this same edit.

### Part D — Initiative trackers

In `initiatives/active-initiatives.md`, add a new "In Progress" entry between the existing ADR-0010 and ADR-0005/0006 entries (or in the most appropriate slot relative to chronology):

```markdown
### Grid CI/CD Control Plane (ADR-0012)
**Status:** In Progress
**Scope:** Architecture, Actions
**Initiative:** `adr-0012-grid-cicd-control-plane`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Land the follow-up work for ADR-0012 — `tracked_workflows` catalog extension, `grid-health-report.yml` aggregator, `consumer-usage.md` refresh, `action-pins.md` inventory, D4 direct-CLI retrofit audit, caller-workflow `permissions:` audit across all 11 Grid repos, and the Node 20 deprecated-action bump. The aggregator (D6) is the headline deliverable; the other packets close visibility, documentation, and operational gaps named in the ADR's Unresolved Consequences.

**Tracking:**
- [ ] Architecture#NN: Accept ADR-0012 — flip status, renumber invariants 34-38 to 37-41, register initiative, amend review.md (packet 01)
- [ ] Architecture#NN: GitHub profile notifications runbook at `infrastructure/github-notifications.md` (packet 02)
- [ ] Architecture#NN: Add `tracked_workflows` to repo catalog (packet 03)
- [ ] Actions#NN: Author `grid-health-report.yml` aggregator (packet 04)
- [ ] Actions#NN: Refresh `docs/consumer-usage.md` with canonical `permissions:` blocks per D5 (packet 05)
- [ ] Actions#NN: Author `docs/action-pins.md` inventory (packet 06)
- [ ] Actions#NN: D4 direct-CLI retrofit audit + re-run nightly-security across 11 repos (packet 07)
- [ ] Architecture#NN: Caller-workflow `permissions:` audit across 11 Grid repos (packet 08)
- [ ] Actions#NN: Bump Node 20 deprecated actions, update pin inventory (packet 09)
```

In `initiatives/roadmap.md`, add an entry under the "Process & Tooling" or equivalent section noting `adr-0012-grid-cicd-control-plane` as in-progress with a one-liner: "Grid CI/CD control plane: tracked_workflows catalog, grid-health aggregator, caller-permissions audit, Node 20 action bump."

### Part E — Amend `.claude/agents/review.md` with caller-permissions Request Changes rule

In `.claude/agents/review.md`, the existing review-checklist sections are numbered `### 0. Resolve the Packet` through `### 8. Cost Discipline`. There is **no** `## CI/CD Concerns` heading today; the only existing CI rule lives inside `### 8. Cost Discipline` as the "Unguarded CI jobs" bullet, but caller-permissions is not a cost concern. Add a **new** `### 9. CI/CD Workflow Compliance` section immediately after `### 8. Cost Discipline`, with the caller-permissions rule as its first bullet:

```markdown
### 9. CI/CD Workflow Compliance

- **Caller workflow that omits `permissions:` while calling a reusable HoneyDrunk.Actions workflow** — Request Changes. Under `workflow_call`, the callee's `permissions:` block is purely documentary; effective token scope is the caller's. A caller without an explicit `permissions:` block inherits the repository default (`contents: read`, all writes `none`) and any reusable workflow that needs a `write` scope fails at workflow-load time on every scheduled run. The fix is to add a top-level `permissions:` block to the caller that is a superset of the callee's declared needs. Canonical baselines are in `HoneyDrunk.Actions/docs/consumer-usage.md`. See invariant 39 and ADR-0012 D5.

Severity: **Request Changes** for any caller that omits `permissions:` or under-grants relative to the callee's declared needs.
```

The new section follows the exact same heading + body + Severity-line shape as `### 8. Cost Discipline`. Future CI/CD review rules (e.g., the action-pin-inventory staleness rule named in packet 06, or the marketplace-wrapper rule named in packet 07) have a known landing zone here — they extend this section as additional bullets rather than introducing yet another heading.

This is the only edit to `review.md` in this packet. The agent's context-loading section (the part that pairs with `scope.md` per invariant 33) is unchanged — invariant 33's symmetry is preserved because no new file is added to either agent's required reading list by this packet.

**Pre-existing hygiene note (do not "fix" in this packet):** `constitution/invariants.md` line 110 contains the italic note `_Invariants 29–30 are reserved for the Observation Layer (ADR-0010). They will be added here when ADR-0010 is accepted._` ADR-0010 is in fact already Accepted (per `adrs/README.md`), so this reservation marker is stale. Cleanup of the marker — promoting invariants 29-30 from "reserved" to actual prose — belongs to a separate ADR-0010-acceptance follow-up packet, not here. **Leave the marker untouched.** Do not delete it, do not duplicate it, and when inserting the new "Grid CI/CD Invariants" section after invariant 36 (Part C above), do not accidentally rewrite the surrounding numbering.

### Part F — Catalog (no edits)

`catalogs/relationships.json` is **not edited** by this packet. ADR-0012 introduces no new agent coupling, no new node, no new contract surface. The existing `agent_couplings` array (added by ADR-0011) is correct as written.

`catalogs/grid-health.json` is **not edited** by this packet. The `tracked_workflows` extension lives in packet 03 of this initiative and lands as a separate concern from ADR acceptance.

## Affected Files
- `adrs/ADR-0012-grid-cicd-control-plane.md` — status flip, renumber paragraph + four list items
- `adrs/README.md` — index row Status column
- `constitution/invariants.md` — append "Grid CI/CD Invariants" section with five renumbered invariants
- `initiatives/active-initiatives.md` — new In Progress entry
- `initiatives/roadmap.md` — entry under Process & Tooling
- `.claude/agents/review.md` — add caller-permissions Request Changes rule

## NuGet Dependencies
None. This is a docs/markdown change; no .NET projects touched.

## Boundary Check
- [x] Architecture-only edits. No code repo touched.
- [x] No new contract surface. No new ADR.
- [x] Invariant 33 symmetry preserved — the review.md edit is to the rule list, not the context-loading contract.

## Acceptance Criteria
- [ ] `adrs/ADR-0012-grid-cicd-control-plane.md` reads `**Status:** Accepted`.
- [ ] The renumber paragraph + four list-item numbers in the ADR's "Grid CI/CD Invariants" section read 37-41 (not 34-38). The five invariant prose blocks are unchanged.
- [ ] `adrs/README.md` row for ADR-0012 reads `Accepted` with the merge date.
- [ ] `constitution/invariants.md` contains a "Grid CI/CD Invariants" section with invariants 37-41 in the exact prose specified above. The cross-reference inside invariant 39 reads "(invariant 40)".
- [ ] `initiatives/active-initiatives.md` contains the new "Grid CI/CD Control Plane (ADR-0012)" In Progress entry with the nine-item Tracking list.
- [ ] `initiatives/roadmap.md` references `adr-0012-grid-cicd-control-plane` as in-progress.
- [ ] `.claude/agents/review.md` contains a new `### 9. CI/CD Workflow Compliance` section inserted immediately after `### 8. Cost Discipline`, with the caller-workflow `permissions:` Request Changes rule as its first bullet, matching the heading + body + Severity-line shape of section 8.
- [ ] `constitution/invariants.md` line 110 (`_Invariants 29–30 are reserved for the Observation Layer (ADR-0010)..._`) is unchanged. The new "Grid CI/CD Invariants" section is appended **after** invariant 36 without modifying or duplicating that earlier reservation marker.
- [ ] The PR diff touches only the six files listed in Affected Files. No other file is modified.
- [ ] Repo-level `CHANGELOG.md` entry created or appended for this version with a one-line summary referencing ADR-0012 acceptance.

## Human Prerequisites
None. This packet is fully delegable. The acceptance flip is a docs change.

## Referenced Invariants

> **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Filing is the point of no return. Before a packet is filed, it may be amended to fill in missing operational context (e.g. NuGet dependencies, key files, constraints) without violating this rule. After filing, state lives on the org Project board, never in the packet file. If requirements change materially post-filing, write a new packet rather than editing the old one. See ADR-0008.

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled. The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other. The coupling exists so there is no class of defect the scope agent could introduce at packet-authoring time that the review agent cannot catch at PR time for lack of information. See ADR-0011 D4.

The Part E review.md edit is to the **review rule list**, not the context-loading section, so invariant 33 symmetry is preserved by construction. If the agent executing this packet finds itself needing to add a new file to review.md's required-reading list, **stop and surface the divergence** rather than silently breaking symmetry.

## Referenced ADR Decisions

**ADR-0012 D5 (Caller workflows declare a `permissions:` block):** Under `workflow_call` the callee's `permissions:` block is documentary only; effective token scope is the caller's. Callers must declare a top-level `permissions:` superset of the callee's needs. Canonical baselines for `nightly-security.yml`, `nightly-deps.yml`, and `pr-core.yml` callers are listed in the ADR body and are the reference for packet 05's `consumer-usage.md` refresh.

**ADR-0012 D6 (Grid Health aggregator):** A scheduled `grid-health-report.yml` workflow in `HoneyDrunk.Actions` reads the repo catalog, polls workflow run state via `gh api`, classifies each (repo, workflow) pair as Pass/Fail/Stale/Missing, renders markdown, and find-or-creates a single `🕸️ Grid Health` issue plus per-repo failure issues. This packet does not implement the aggregator (that is packet 04) but does add the invariants that make it mandatory.

**ADR-0012 D7 (GitHub profile notifications):** Real-time per-failure notification is delivered by the operator's GitHub Settings → Notifications → Actions → "Only notify for failed workflows" configuration. This is a user-side step covered by packet 02's runbook.

## Dependencies
None. This packet is the entry point for the initiative; all other packets reference it for invariant numbers.

## Labels
`feature`, `tier-2`, `meta`, `docs`, `adr-0012`, `wave-1`

## Agent Handoff

**Objective:** Land ADR-0012 acceptance + invariants 37-41 + initiative trackers + review.md rule in one merge.
**Target:** HoneyDrunk.Architecture, branch from `main`

**Context:**
- Goal: Move ADR-0012 from Proposed to Accepted and unblock the rollout's downstream packets.
- Feature: ADR-0012 Grid CI/CD Control Plane.
- ADRs: ADR-0012.

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- **Invariant 24:** Packets are immutable once filed. This packet's body must not be edited post-filing; subsequent corrections are new packets.
- **Invariant 33:** review-agent and scope-agent context-loading contracts are coupled. The Part E edit is to the review rule list, not the context-loading section, so symmetry is preserved. Do not add new files to review.md's required-reading section in this packet — that would require a coordinated edit to scope.md.
- **No edits outside the six listed files.** The PR diff is bounded.
- **Invariant numbering precedence.** ADR-0015 owns 34-36 (already in invariants.md). ADR-0012's invariants are 37-41. The renumber must happen in both the ADR body and `constitution/invariants.md`.

**Key Files:**
- `adrs/ADR-0012-grid-cicd-control-plane.md` — the ADR being accepted; the Grid CI/CD Invariants subsection contains the prose to copy verbatim into `invariants.md`.
- `adrs/README.md` — ADR index, follow the existing row format.
- `constitution/invariants.md` — append the new section after invariant 36; existing sections are untouched.
- `initiatives/active-initiatives.md` — model the new entry after the existing ADR-0010 / ADR-0005 entries.
- `initiatives/roadmap.md` — short one-liner under Process & Tooling.
- `.claude/agents/review.md` — append the new Request Changes rule alongside existing rules.

**Contracts:** No code or schema contracts changed. The only contract surface touched is the constitution itself.
