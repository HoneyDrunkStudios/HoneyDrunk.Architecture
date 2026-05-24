---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "security", "docs", "adr-0056", "wave-3"]
dependencies: ["packet:01"]
adrs: ["ADR-0056", "ADR-0014"]
accepts: ["ADR-0056"]
wave: 3
initiative: adr-0056-threat-model
node: honeydrunk-architecture
---

# Amend the standup-ADR template + extend hive-sync to enforce threat-model entry on every standup

## Summary
Two governance-plumbing tasks from ADR-0056 D5 / Follow-up Work: (1) amend the standup-ADR authoring template (the shape every Node standup ADR follows — ADR-0014 onward) to require a "threat model entry" section, and (2) extend `hive-sync` (per ADR-0014) to fail the constitution scan if a standup ADR references a Node not present in `constitution/threat-model.md`. Together these enforce invariant `{N1}` (added by packet 00) at authoring time and at constitution-scan time.

## Context
Invariant `{N1}` (added by packet 00) commits the Grid to: every Node standup ADR includes a "threat model entry" section, and the artifact is updated in the same PR that moves the standup ADR to Accepted. ADR-0056 D5 names two enforcement points:

1. **Standup-ADR template — author-time enforcement.** The template's structure carries the "threat model entry" section so authors of new standup ADRs see the requirement before they write the ADR. Without the template amendment, invariant `{N1}` is only enforced at scan-time — after the ADR is drafted — which means authors discover the gap during PR review rather than during authoring.
2. **`hive-sync` constitution scan — merge-time enforcement.** ADR-0014's `hive-sync` agent already scans the constitution; this packet extends the scan to check that every Accepted standup ADR references a Node that appears in `constitution/threat-model.md`'s boundary inventory and asset inventory (where the Node touches new boundaries or assets). A standup ADR moved to Accepted without a corresponding artifact update fails the scan.

Both enforcement points point at the **same content discipline**: when a Node is stood up, its boundaries and assets are added to the threat model in the same PR as the standup. The template makes the requirement visible; `hive-sync` makes the requirement merge-gating.

**Standup-ADR template location.** Standup ADRs follow a shape established by ADR-0014 onward (ADR-0016 HoneyDrunk.AI, ADR-0017 Capabilities, ADR-0018 Operator, ADR-0019 Communications, ADR-0020 Agents, ADR-0021 Knowledge, ADR-0022 Memory, ADR-0023 Evals, ADR-0024 Flow, ADR-0025 Sim, ADR-0027 Notify Cloud, ADR-0031 Audit). There is no single template file at a known path in this repo (verified via search — `adrs/` has no `templates/` subdirectory, only the ADRs themselves). The "template" in ADR-0056 D5 is the **shape of the standup-ADR authoring guidance**. The executor of this packet identifies the canonical location for that guidance — likely a comment in a representative standup ADR, or a new doc at `adrs/standup-template.md` if no canonical location exists — and amends it.

**`hive-sync` extension.** ADR-0014's `hive-sync` agent lives in `.claude/agents/hive-sync.md` and (per the existing rollout — Architecture#61 through #66, all closed) already runs a constitution scan with packet-lifecycle, board-coverage, Proposed-ADR-queue, ADR/PDR auto-acceptance, and drift-detection checks. This packet adds one more scan rule: a standup-ADR-vs-artifact Node-list consistency check. The rule's logic, in plain terms: list every standup ADR (those that match a "Stand Up the HoneyDrunk.X Node" title pattern, or carry a `standup` label in `accepts:` frontmatter); for each, find the Node it stands up; check that the Node's name appears in `constitution/threat-model.md` either in the boundary inventory (section 3) or the asset inventory (section 4) or via an explicit "Node has no new boundaries or assets — see threat-model entry in the ADR body" note in the standup ADR. If the Node is missing, emit a scan failure naming the standup ADR.

**Backfill posture.** Existing Accepted standup ADRs (ADR-0019, ADR-0031, possibly others) **predate** invariant `{N1}`. The `hive-sync` extension's scan logic distinguishes pre-invariant-`{N1}` standups (Accepted before this initiative's packet 00) from post-invariant-`{N1}` standups (Accepted after). Pre-invariant-`{N1}` standups are not flagged retroactively. New Accepted standups (after packet 00 merges) must comply or fail the scan. This is the "the discipline is forward, not retroactive" posture — consistent with how ADR-0044's PR-discipline rolled out.

**This is a docs + agent-config packet. No code, no .NET project.**

## Scope
- The canonical standup-ADR authoring guidance — amend to require a "threat model entry" section. If no canonical guidance file exists, create one at `adrs/standup-template.md` (or the established location for ADR-authoring guidance — match the existing convention).
- `.claude/agents/hive-sync.md` — extend the constitution-scan section with the standup-ADR-vs-artifact Node-list consistency rule.

## Proposed Implementation

### 1. Standup-ADR template amendment

Identify the canonical location for standup-ADR authoring guidance. Verified at scope time: no `adrs/standup-template.md` or `adrs/templates/` exists; standup ADRs are authored from prior examples (ADR-0019, ADR-0031, etc.). The executor:

- **Option A** — if a canonical authoring guidance doc exists (verify in `adrs/`, `.github/`, or the `copilot/` instructions), amend it.
- **Option B** — if no canonical doc exists, create `adrs/standup-template.md` with the standup-ADR shape distilled from the existing standup ADRs (the section structure: Status / Date / Deciders / Sector / Context / Decision / Consequences / Alternatives Considered) and add the "threat model entry" requirement.

The "threat model entry" section, to be inserted in the standup-template under Decision (after the contract/interface freezes, before Consequences):

```markdown
### D_N — Threat model entry

This Node introduces the following new trust boundaries (per ADR-0056 D2):
- {TB-N: description, or "none — this Node introduces no new boundary"}

This Node introduces the following new assets (per ADR-0056 D3):
- {asset name, sensitivity class per ADR-0049, RPO/RTO per ADR-0036, primary defenses}
- {or "none — this Node introduces no new asset"}

STRIDE pass against the boundaries this Node touches:
- TB-N (boundary name): S/T/R/I/D/E — one line per letter naming the threat-mitigation pair

AI overlay (Nodes in the AI sector, or any Node executing LLM calls or invoking agent tools):
- AI-N: {applicable threat → mitigation → residual risk}, or "n/a — Node does not execute LLM calls or invoke agent tools"

The artifact `constitution/threat-model.md` is updated in this same PR to reflect the new boundaries, assets, and threat entries. The standup ADR cannot move from Proposed to Accepted until that artifact-update commit lands.
```

If a representative standup ADR is the canonical guidance (no separate template file), add a comment block at the top noting the threat-model-entry requirement and pointing at ADR-0056 D5 + invariant `{N1}`.

### 2. `hive-sync` constitution-scan extension

Amend `.claude/agents/hive-sync.md` to add a new sub-scan within its constitution-scan responsibility. The scan rule (in plain English — `hive-sync` documents agent behavior in prose, not code):

> **Standup-ADR vs. threat-model artifact consistency.** For every standup ADR with `**Status:** Accepted` and a merge date after {packet 00's merge date — substitute at edit time}, check that the Node it stands up appears in `constitution/threat-model.md` — either in section 3 (boundary inventory), section 4 (asset inventory), or referenced by name within a STRIDE-pass entry in section 5. If the Node is named in the standup ADR but absent from the artifact, emit a scan failure naming the standup ADR and the missing Node. Pre-invariant-`{N1}` standup ADRs (Accepted before the cutoff date) are not flagged retroactively — they ride forward under the existing artifact whether or not they are explicitly named.

The exact wording in `hive-sync.md` follows the existing scan-rule conventions in that file (mirror the language of the packet-lifecycle scan, the board-coverage scan, the ADR/PDR queue scan).

State the failure-mode posture: a scan failure is **advisory**, not auto-blocking — `hive-sync` runs through OpenClaw scheduled/manual execution (per ADR-0014 D3 and invariant 38) and emits findings; the operator triages and closes the gap. This is consistent with the existing scan behavior; no new gating semantics are introduced.

### 3. Cross-reference to invariant `{N1}`

In both the template amendment and the `hive-sync` rule, include a `cf. invariant `{N1}`` cross-reference so a reader landing in either doc can trace back to the constitutional rule.

## Affected Files
- The canonical standup-ADR authoring guidance — verified location at edit time (either an existing file or a new `adrs/standup-template.md`).
- `.claude/agents/hive-sync.md`

## NuGet Dependencies
None. This packet touches only Markdown governance and agent-config files; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. The standup-ADR authoring surface and `.claude/agents/hive-sync.md` both live here. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] `hive-sync` is the right enforcement surface — ADR-0014 names it as the constitution-scan agent; ADR-0056 D5 specifies the constitution scan as the enforcement point for invariant `{N1}`.

## Acceptance Criteria
- [ ] The canonical standup-ADR authoring guidance carries a "threat model entry" section requirement that names: new trust boundaries (if any) per ADR-0056 D2, new assets (if any) per ADR-0056 D3, STRIDE pass against boundaries the Node touches, AI overlay if applicable, and the requirement that `constitution/threat-model.md` is updated in the same PR
- [ ] If no canonical guidance doc existed at scope time, `adrs/standup-template.md` was created with the standup-ADR shape distilled from existing standups + the threat-model-entry requirement
- [ ] `.claude/agents/hive-sync.md` carries a new sub-scan rule: standup-ADR-vs-artifact Node-list consistency, with the pre-invariant-`{N1}` backfill exemption (standups Accepted before packet 00's merge date are not flagged retroactively)
- [ ] Both edits cross-reference invariant `{N1}` (cf. invariant `{N1}`)
- [ ] The `hive-sync` rule follows the existing scan-rule conventions in the file (advisory findings, no new auto-blocking semantics)
- [ ] No existing Accepted standup ADR is modified retroactively to add a threat-model-entry section (backfill is explicitly forward-only)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0056 D5 — Per-new-Node review cadence.** Node standup ADRs include a "threat model entry" section that adds the Node to the artifact: new trust boundaries (if any), new assets (if any), STRIDE pass against the boundaries the Node touches, AI overlay if the Node is in the AI sector. The standup ADR cannot move from Proposed to Accepted until the artifact-update commit lands. Enforcement: the `hive-sync` constitution-scan job fails if a standup ADR references a Node not present in the artifact.

**Invariant `{N1}` (added by packet 00) — Every Node standup ADR includes a "threat model entry" section, and the artifact is updated in the same PR that moves the standup ADR to Accepted.** Enforced by `hive-sync` constitution scan.

**ADR-0014 — `hive-sync` agent and the constitution scan surface.** `hive-sync` runs through OpenClaw scheduled/manual execution per invariant 38; the constitution scan is its mechanism for surfacing drift. Scan findings are advisory (per the existing rollout pattern), not auto-blocking.

## Constraints
- **Inline the requirement; do not just cite invariant `{N1}`.** Both the template and the `hive-sync` rule write out the substance (boundaries, assets, STRIDE pass, AI overlay, same-PR artifact update). Number-only references defeat the author's ability to act on the rule.
- **Forward-only backfill.** Existing Accepted standup ADRs (predate this initiative) are not modified retroactively. The `hive-sync` scan distinguishes pre/post-invariant-`{N1}` standups using a date cutoff (packet 00's merge date) — substitute that cutoff date in `hive-sync.md` at edit time.
- **Advisory findings, not auto-blocking.** The new `hive-sync` rule follows the existing scan conventions — emit a finding, the operator triages and closes. Do not introduce new merge-blocking semantics in `hive-sync.md` for this rule (or any other — that's not `hive-sync`'s contract per ADR-0014).
- **Standup-template location verified at edit time.** Verified at scope time: no `adrs/standup-template.md` or `adrs/templates/` exists. If a canonical guidance file is found at edit time (in `adrs/`, `.github/`, or `copilot/`), amend it; otherwise create `adrs/standup-template.md`.

## Labels
`feature`, `tier-2`, `meta`, `security`, `docs`, `adr-0056`, `wave-3`

## Agent Handoff

**Objective:** Amend the standup-ADR authoring template (or create one if missing) to require a "threat model entry" section; extend `hive-sync`'s constitution scan with a standup-ADR-vs-artifact Node-list consistency rule.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make invariant `{N1}` enforceable at author time (the template) and at scan time (`hive-sync`).
- Feature: ADR-0056 Threat Model and Security Review Cadence rollout, Wave 3.
- ADRs: ADR-0056 D5 (primary); ADR-0014 (`hive-sync` agent surface); invariant `{N1}` (added by packet 00).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — hard. `constitution/threat-model.md` must exist for both the template language and the `hive-sync` scan rule to reference it concretely.

**Constraints:**
- Inline the requirement substance in both surfaces — no number-only invariant references.
- Forward-only backfill — existing Accepted standup ADRs are not retroactively flagged.
- Advisory findings — follow existing `hive-sync` conventions; no new merge-blocking semantics.
- Standup-template location verified at edit time — amend existing guidance or create `adrs/standup-template.md`.

**Key Files:**
- The canonical standup-ADR authoring guidance (verified at edit time)
- `.claude/agents/hive-sync.md`

**Contracts:** None changed. Governance + agent-config edits only.
