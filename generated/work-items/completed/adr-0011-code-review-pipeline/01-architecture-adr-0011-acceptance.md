---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0011", "wave-1"]
dependencies: []
adrs: ["ADR-0011"]
wave: 1
initiative: adr-0011-code-review-pipeline
node: honeydrunk-architecture
---

# Feature: Accept ADR-0011 — code review and merge flow, finalize invariants 31–33

## Summary
Flip ADR-0011 from `Proposed` to `Accepted`, refresh the ADR index row, drop the "(Proposed — this invariant takes effect when ADR-0011 is accepted)" qualifier on invariants 31–33, register the rollout initiative in `active-initiatives.md` and `roadmap.md`, and verify that `.claude/agents/scope.md` and `.claude/agents/review.md` already reflect the ADR's D4/D6/D7 contracts (audit pass — both files were updated in advance).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0011 was drafted Proposed on 2026-04-12. Three things keep the current state honest but unfinished: invariants 31–33 already exist in `constitution/invariants.md` with their full text but carry a "(Proposed — this invariant takes effect when ADR-0011 is accepted)" qualifier; the ADR index row in `adrs/README.md` reads `Proposed`; and the agent definitions (`scope.md`, `review.md`) already cross-reference the ADR's decisions even though the decisions are not yet Accepted. The Grid is one PR away from a coherent state — this packet is that PR. After it lands, downstream packets in this initiative (SonarCloud workflow, agent-run amendment, label seeding, per-repo onboarding) become enforceable against live invariants rather than aspirational ones.

This packet is the **single mechanically-coupled flip** that ADRs require per the scope-agent acceptance convention: status flip, index row flip, qualifier strip, and trackers all land in one merge.

## Scope

All edits are in the `HoneyDrunk.Architecture` repo. No code. No secrets.

### Part A — ADR file flip

In `adrs/ADR-0011-code-review-and-merge-flow.md`, change the front-matter line:

```
**Status:** Proposed
```

to:

```
**Status:** Accepted
```

Do not edit any other text in the ADR body. Body edits to an Accepted ADR are out-of-scope here; if the ADR text needs revision, that lives in a separate ADR amendment.

### Part B — ADR index update

In `adrs/README.md`, the existing row for ADR-0011:

```
| [ADR-0011](ADR-0011-code-review-and-merge-flow.md) | Code Review and Merge Flow | Proposed | 2026-04-12 | Meta | Tiered PR pipeline with named owners and artifact contracts. Review agent is local-only (cost-disciplined); SonarCloud fills the third-party static analysis slot. Invariants 31–33. |
```

Change the Status cell from `Proposed` to `Accepted`. Leave the Date column at `2026-04-12` (the original draft date — the table tracks decision date, not acceptance date, per the existing convention with ADR-0010 which kept its 2026-04-12 date through acceptance). Optionally tighten the Impact text to acknowledge what is now binding:

```
| [ADR-0011](ADR-0011-code-review-and-merge-flow.md) | Code Review and Merge Flow | Accepted | 2026-04-12 | Meta | Tiered PR pipeline (tier-1 gates required; SonarCloud tier-2 on public repos; review agent tier-3 local-only). Invariants 31–33 binding. |
```

### Part C — Strip "Proposed" qualifier from invariants 31–33

In `constitution/invariants.md`, the three invariants currently read:

```markdown
31. **Every PR traverses the tier-1 gate before merge.**
    Build, unit tests, analyzers, vulnerability scan, and secret scan are required branch-protection checks on every .NET repo in the Grid, delivered via `pr-core.yml` in `HoneyDrunk.Actions`. Bypassing tier 1 via force-push to `main` or admin override is forbidden except for `hotfix-infra` scenarios where the gate itself is broken. See ADR-0011 D2 and D5 (Proposed — this invariant takes effect when ADR-0011 is accepted).

32. **Agent-authored PRs must link to their packet in the PR body.**
    The review agent resolves the packet via this link and uses it as the primary scope anchor. Absent the link, the PR is treated as out-of-band, must carry the `out-of-band` label, and receives a degraded review in which the agent runs against the Grid context only (invariants, boundaries, relationships, diff) without a packet-scope check. See ADR-0011 D3 and D9 (Proposed — this invariant takes effect when ADR-0011 is accepted).

33. **Review-agent and scope-agent context-loading contracts are coupled.**
    The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other. The coupling exists so there is no class of defect the scope agent could introduce at packet-authoring time that the review agent cannot catch at PR time for lack of information. See ADR-0011 D4 (Proposed — this invariant takes effect when ADR-0011 is accepted).
```

Strip the `(Proposed — this invariant takes effect when ADR-0011 is accepted)` qualifier from all three so they read as live rules. Final form:

```markdown
31. **Every PR traverses the tier-1 gate before merge.**
    Build, unit tests, analyzers, vulnerability scan, and secret scan are required branch-protection checks on every .NET repo in the Grid, delivered via `pr-core.yml` in `HoneyDrunk.Actions`. Bypassing tier 1 via force-push to `main` or admin override is forbidden except for `hotfix-infra` scenarios where the gate itself is broken. See ADR-0011 D2 and D5.

32. **Agent-authored PRs must link to their packet in the PR body.**
    The review agent resolves the packet via this link and uses it as the primary scope anchor. Absent the link, the PR is treated as out-of-band, must carry the `out-of-band` label, and receives a degraded review in which the agent runs against the Grid context only (invariants, boundaries, relationships, diff) without a packet-scope check. See ADR-0011 D3 and D9.

33. **Review-agent and scope-agent context-loading contracts are coupled.**
    The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other. The coupling exists so there is no class of defect the scope agent could introduce at packet-authoring time that the review agent cannot catch at PR time for lack of information. See ADR-0011 D4.
```

### Part D — Agent-definition audit (no edit expected)

`.claude/agents/scope.md` and `.claude/agents/review.md` were both updated ahead of this acceptance. The ADR follow-up bullets that named them are already reflected:

- **scope.md** — section "Coupling with the review agent (ADR-0011 D4, invariant 33)" is present (line 32 in the current file). No edit expected.
- **review.md** — section "Cost Discipline" is present (currently section 8 of the Review Process, beginning at line 122). The "Governing decision: ADR-0011" callout is present. The context-loading list explicitly states "must remain a superset of the scope agent's context load … per invariant 33." No edit expected.

**Verification at scope-time (2026-04-26):** the executor was confronted with a refine review claiming review.md only contained 4 of the 6 D6 items. Re-checking review.md lines 122–137 directly: all **six** items are present, in this order:

1. Hot-path logging without sampling
2. LLM calls without a cost cap
3. Unguarded CI jobs
4. Azure resources without SKU justification
5. Outbound HTTP in request hot paths
6. Unbounded catalog loops

The earlier refine grep that found only 4 was incomplete — possibly searching for partial header strings rather than the bullet text inside the section. The file is correct as written and **no edit is required**. The audit acceptance criterion below remains as a tripwire — if the file has drifted by execution time, the audit catches it.

**Audit task:** open both files and confirm:
1. `scope.md` mentions ADR-0011 D4 and invariant 33 in its "Before Scoping" section.
2. `review.md` references ADR-0011 in a top-level callout and contains a Cost Discipline section (lines 122–137 as of scope-time) listing the six checklist items from D6: hot-path logging without sampling; LLM calls without a cost cap; unguarded CI jobs; Azure resources without SKU justification; outbound HTTP in request hot paths; unbounded catalog loops.
3. The context-loading lists in the two files are mutually consistent — review.md must be a superset of scope.md per invariant 33.

If any of the three checks fails (drift since scope-time), document the gap in the PR body and add a line item to fix it as part of this PR. **No edit is expected based on the 2026-04-26 state of those files.**

### Part E — Catalog: register the agent-coupling

Invariant 33 establishes a real coupling between two agent definition files (`.claude/agents/scope.md` and `.claude/agents/review.md`). Today, the catalogs in `catalogs/` describe Node-to-Node coupling (`relationships.json`), public contracts (`contracts.json`), and the rest of the structural Grid map. Agent-to-agent coupling is a new relationship kind — it does not naturally fit the `nodes` array in `relationships.json` because agents are not Nodes, but it is structurally a relationship and machine-discoverability matters (the review agent's context-loading audit benefits from the catalog being authoritative).

Add a sibling top-level key `agent_couplings` to `catalogs/relationships.json`. Schema:

```json
{
  "nodes": [ ... existing ... ],
  "agent_couplings": [
    {
      "id": "scope-review-context-loading",
      "kind": "context_load_superset",
      "agents": ["scope", "review"],
      "rule": "review.md context-loading list must be a superset of scope.md context-loading list",
      "governing_invariant": 33,
      "governing_adr": "ADR-0011",
      "rationale": "There must be no class of defect the scope agent could introduce at packet-authoring time that the review agent cannot catch at PR time for lack of information."
    }
  ]
}
```

This is additive — existing tooling that reads `relationships.json` for the `nodes` key continues to work unchanged. Future agent-coupling kinds (output formats, tool-permission relationships, etc.) extend this same array.

### Part F — Initiative + roadmap trackers

#### `initiatives/active-initiatives.md`

Add a new **In Progress** entry, ordered alphabetically/numerically alongside the existing `ADR-` entries:

```markdown
### Code Review Pipeline (ADR-0011)
**Status:** In Progress
**Scope:** Architecture, Actions, plus per-repo SonarCloud onboarding (Wave 3, deferred)
**Initiative:** `adr-0011-code-review-pipeline`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Accept ADR-0011 and ship the pipeline plumbing it requires: SonarCloud reusable workflow in HoneyDrunk.Actions, packet-link injection into the cloud execution workflow's PR body (carries invariant 32), `out-of-band` label seeded across active repos, SonarCloud organization setup walkthrough, plus the first two per-repo SonarCloud onboardings as templates (Kernel and Web.Rest). Remaining .NET repos (Transport, Vault, Auth, Data, Pulse, Notify, Vault.Rotation, Actions) are tracked here but not scoped — they roll out as a follow-up wave once the templates prove out.

**Tracking (Wave 1 — foundation):**
- [ ] Architecture#NN: Accept ADR-0011 — flip status, index, invariants 31–33 qualifier strip, agent-coupling catalog entry, audit agent files, register initiative (this packet)
- [ ] Actions#NN: Author `job-sonarcloud.yml` reusable workflow
- [ ] Actions#NN: Amend `agent-run.yml` to inject packet link into PR body (invariant 32 enforcement — prompt-side + post-hoc workflow assert)
- [ ] Architecture#NN: SonarCloud organization setup walkthrough doc
- [ ] Actions#NN: Labels-as-code config + reusable `seed-labels.yml` workflow (packet 05a)
- [ ] Actions#NN: Cross-repo fan-out — `out-of-band` label on the eleven Grid repos via `seed-labels-fanout.yml` + PAT (packet 05b, hard-blocked on 05a)

**Tracking (Wave 2 — template rollout):**
- [ ] Kernel#NN: Onboard SonarCloud (first canonical .NET template)
- [ ] Web.Rest#NN: Onboard SonarCloud (ASP.NET Core variant template)

**Deferred (Wave 3 — post-template fan-out, scope after Wave 2 lands):**
- Transport, Vault, Auth, Data, Pulse, Notify, Vault.Rotation, Actions — eight per-repo SonarCloud onboardings, each a small (~5-line `sonar-project.properties` + branch-protection toggle + reusable-workflow call) packet
- HoneyDrunk.Studios — TypeScript/Next.js posture, separate from the .NET fan-out; SonarCloud-JS onboarding evaluated as a one-off when Studios CI is otherwise wired

**Out of scope (Unresolved Consequences in the ADR):**
- Integration tests (Gap 1) — slot defined, no test runner yet
- E2E / Playwright tests (Gap 3) — slot defined, no infra
- Cost discipline tooling (Gap 4) — review agent's checklist covers it qualitatively
- Private-repo SonarCloud (Gap 5) — opt-in per repo, no Wave-3 fan-out
```

#### `initiatives/roadmap.md`

Add a Q2 2026 bullet (place near the existing ADR-0009/ADR-0015 process bullets):

```markdown
- [ ] **Code Review Pipeline (ADR-0011)** — SonarCloud reusable workflow, agent-run packet-link injection, `out-of-band` label seeding, SonarCloud org walkthrough, first two per-repo onboardings (Kernel + Web.Rest) as templates; remaining 8 .NET repos deferred to Wave 3
```

No Q3 entry — the deferred fan-out belongs in this initiative once Wave 2 lands; no new quarter is needed.

## Acceptance Criteria

### ADR file
- [ ] `adrs/ADR-0011-code-review-and-merge-flow.md` line `**Status:** Proposed` flipped to `**Status:** Accepted`
- [ ] No other text in the ADR body changed in this PR (body edits to an Accepted ADR require a separate amendment)

### ADR index
- [ ] `adrs/README.md` ADR-0011 row Status flipped to `Accepted`
- [ ] Date column unchanged (`2026-04-12`)
- [ ] Impact text optionally tightened to acknowledge invariants 31–33 are now binding

### Invariants
- [ ] `constitution/invariants.md`: invariant 31's `(Proposed — this invariant takes effect when ADR-0011 is accepted)` qualifier removed; rule reads as live
- [ ] `constitution/invariants.md`: invariant 32's `(Proposed — this invariant takes effect when ADR-0011 is accepted)` qualifier removed; rule reads as live
- [ ] `constitution/invariants.md`: invariant 33's `(Proposed — this invariant takes effect when ADR-0011 is accepted)` qualifier removed; rule reads as live
- [ ] No other invariants edited

### Agent-definition audit
- [ ] `.claude/agents/scope.md` audit confirms ADR-0011 D4 / invariant 33 cross-reference present in "Before Scoping" section; outcome documented in PR body (`audit pass — no edits required` is the expected line)
- [ ] `.claude/agents/review.md` audit confirms (a) ADR-0011 governing-decision callout, (b) Cost Discipline section listing the six D6 checklist items, (c) context-loading list is a superset of scope.md's per invariant 33; outcome documented in PR body
- [ ] If any audit check fails, the gap is fixed in this PR and the fix is itself an acceptance criterion

### Catalog
- [ ] `catalogs/relationships.json`: new top-level `agent_couplings` array added (sibling to existing `nodes` array) with one entry: `id: "scope-review-context-loading"`, `kind: "context_load_superset"`, `agents: ["scope", "review"]`, `governing_invariant: 33`, `governing_adr: "ADR-0011"`. Schema is additive — existing tooling that reads `nodes` is unaffected.

### Trackers
- [ ] `initiatives/active-initiatives.md`: new "Code Review Pipeline (ADR-0011)" In Progress entry present with Wave 1 / Wave 2 / Wave 3 / out-of-scope sections
- [ ] `initiatives/roadmap.md`: new Q2 2026 bullet for ADR-0011 present

### General
- [ ] No ADR IDs added to README-style narrative prose anywhere in this PR (per user convention: ADR IDs stay in frontmatter / index tables / dedicated invariant references, not in body narrative)
- [ ] Repo-level `CHANGELOG.md` entry — Architecture is docs-only and currently has no `CHANGELOG.md` next to a `.slnx`; if no changelog file exists, skip per the existing Architecture-repo precedent. If one is later added, this acceptance row should ship a "ADR-0011 accepted" entry — not a blocker today.

## Affected Packages
None. Docs and constitution only.

## NuGet Dependencies
None. No .NET changes in this packet.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture` — correct repo per the routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture".
- [x] No code changes in any other repo.
- [x] ADR-0011 is the governing decision. Invariants 31–33 are *its* invariants, not borrowed from another ADR. The qualifier strip is mechanically coupled to the status flip.

## Human Prerequisites
None. This packet is a pure Architecture-repo edit and does not require any portal or GitHub org actions. Downstream packets (SonarCloud organization setup walkthrough — packet 04) carry the human portal work.

## Dependencies
None. This is the Wave-1 foundation packet that all downstream work in this initiative depends on.

## Downstream Unblocks
- `02-actions-job-sonarcloud-workflow.md` — `job-sonarcloud.yml` references invariants 31 and 33 by number; the qualifier strip lets the workflow's documentation describe them as live rules.
- `03-actions-agent-run-packet-link.md` — invariant 32 ("Agent-authored PRs must link to their packet in the PR body") becomes the enforced rationale once accepted; without acceptance the workflow change is aspirational.
- `04-architecture-sonarcloud-org-walkthrough.md` — references ADR-0011 D11 SonarCloud-as-third-party choice; the doc is more credible against an Accepted ADR.
- `05a-actions-labels-as-code.md` and `05b-actions-out-of-band-label-fanout.md` — invariant 32's "must carry the `out-of-band` label" clause is the load-bearing reference for both packets.
- `06-kernel-sonarcloud-onboarding.md`, `07-web-rest-sonarcloud-onboarding.md` — both reference invariant 31 (tier-1 gate) and ADR-0011 D11 (SonarCloud-as-tool); both become enforceable against a binding rule.
- The `agent_couplings` catalog entry (Part E above) gives downstream tools (review-agent self-audit, future grid-health linters) a machine-discoverable signal of the invariant 33 coupling.

## Referenced ADR Decisions

**ADR-0011 (Code Review and Merge Flow):**
- **D1:** GitHub PR is the system of record for review state. Branch protection enforces the gate.
- **D2:** Ordered tier-1 → tier-5 review pipeline. Tier 1 = build, unit tests, analyzers, vulnerability scan, secret scan (all required). Tier 2 = integration tests + SonarCloud (SonarCloud is required on public repos). Tier 3 = LLM reviewers (Copilot automatic-cloud, review agent local-only). Tier 4 = E2E. Tier 5 = human merge.
- **D3:** Per-stage artifact contracts. Review agent's input is non-negotiable: packet file via PR body link.
- **D4:** Review agent's context-loading contract is the symmetric peer of the scope agent's. Coupled and bound by invariant 33.
- **D5:** Review agent is advisory, not a required check. Tier-1 gates remain required via branch protection.
- **D6:** Cost discipline is a named review-agent responsibility — six-item checklist baked into `.claude/agents/review.md`.
- **D7:** Grid-alignment check is a named review-agent responsibility — packet honor, boundary respect, invariant preservation.
- **D8:** Failure surfaces — branch protection blocks tier-1 / SonarCloud / E2E; advisory comments do not.
- **D9:** Out-of-band PRs (no packet link) get a degraded review and must carry the `out-of-band` label.
- **D10:** Review agent runs locally via Claude Code, invoked by the human. Deliberately not cloud-wired. The automatic LLM reviewer slot is filled by GitHub Copilot.
- **D11:** SonarCloud is the third-party static analysis tool. Public-repos-first. Quality gate is a required branch-protection check on public repos. Private-tier opt-in only.

## Referenced Invariants

> **Invariant 24 (work-tracking):** Issue packets are immutable once filed as a GitHub Issue. Filing is the point of no return. State lives on the org Project board, not in the packet file.

> **Invariant 31 (becoming live in this PR):** Every PR traverses the tier-1 gate before merge. Build, unit tests, analyzers, vulnerability scan, and secret scan are required branch-protection checks on every .NET repo in the Grid, delivered via `pr-core.yml` in `HoneyDrunk.Actions`. Bypassing tier 1 via force-push to `main` or admin override is forbidden except for `hotfix-infra` scenarios where the gate itself is broken.

> **Invariant 32 (becoming live in this PR):** Agent-authored PRs must link to their packet in the PR body. The review agent resolves the packet via this link and uses it as the primary scope anchor. Absent the link, the PR is treated as out-of-band, must carry the `out-of-band` label, and receives a degraded review in which the agent runs against the Grid context only (invariants, boundaries, relationships, diff) without a packet-scope check.

> **Invariant 33 (becoming live in this PR):** Review-agent and scope-agent context-loading contracts are coupled. The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other.

## Constraints
- **Status flip is mechanically coupled to the PR.** Per the scope-agent acceptance convention, ADRs flip from `Proposed` to `Accepted` only on the PR that ships their acceptance work. Not before, not after.
- **Do not edit ADR-0011 body text.** Only the front-matter `Status` line. Body amendments require a separate ADR or a follow-up.
- **Do not touch invariants 1–30 or 34–36.** Only invariants 31, 32, 33 lose their qualifier in this PR.
- **Audit-only on agent files.** `.claude/agents/scope.md` and `.claude/agents/review.md` were updated ahead of this packet. The audit acceptance criteria check that the prior updates are present and correct; do not introduce drive-by edits unless the audit fails.
- **No ADR IDs in narrative prose.** Per user convention. ADR IDs belong in frontmatter, index tables, and dedicated invariant cross-references — not in the body narrative of `repos/*/overview.md`-style docs. This applies if any new narrative text is added; the per-section ADR references in `constitution/invariants.md` and `adrs/README.md` are *index entries*, not narrative, and remain.

## Labels
`feature`, `tier-2`, `meta`, `docs`, `adr-0011`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0011 from `Proposed` to `Accepted` in one atomic Architecture-repo PR. Strip the "(Proposed)" qualifier from invariants 31–33. Refresh the ADR index. Audit `scope.md` and `review.md` for the cross-references the ADR mandates (no edits expected). Add the `scope-review-context-loading` agent-coupling entry to `catalogs/relationships.json` (machine-discoverable invariant 33 coupling). Register the rollout initiative in the trackers.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Move ADR-0011 from Proposed to Accepted by doing the Architecture-side work it requires (status flip, invariant qualifier strip, ADR index, audit, trackers).
- Feature: ADR-0011 Code Review and Merge Flow rollout.
- ADRs: ADR-0011 (primary), ADR-0008 (initiative/packet conventions, cloud execution workflow context for packet 03), ADR-0009 (vulnerability scan that ADR-0011 D2 builds on), ADR-0007 (agent definitions live in `.claude/agents/`).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- See "Constraints" section above — inlined for agent consumption.
- Status flip is mechanically coupled to this PR; no early flip.
- Audit-only on agent files; do not edit `scope.md` or `review.md` unless the audit fails.
- Do not touch invariants outside 31–33.

**Key Files:**
- `adrs/ADR-0011-code-review-and-merge-flow.md` — front-matter Status line only
- `adrs/README.md` — ADR-0011 row
- `constitution/invariants.md` — invariants 31, 32, 33 (qualifier strip)
- `.claude/agents/scope.md` — audit only (no edit expected)
- `.claude/agents/review.md` — audit only (no edit expected)
- `catalogs/relationships.json` — add `agent_couplings` sibling array with the `scope-review-context-loading` entry (invariant 33 coupling, machine-discoverable)
- `initiatives/active-initiatives.md` — new "Code Review Pipeline (ADR-0011)" entry
- `initiatives/roadmap.md` — Q2 2026 bullet

**Contracts:** None. Docs and constitution only.
