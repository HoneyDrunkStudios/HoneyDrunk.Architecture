---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0046", "wave-3"]
dependencies: ["packet:03", "packet:04", "packet:05", "packet:06", "packet:07"]
adrs: ["ADR-0046", "ADR-0044", "ADR-0040", "ADR-0045"]
accepts: ["ADR-0046"]
wave: 3
initiative: adr-0046-specialist-review-agents
node: honeydrunk-architecture
---

# Phase-1 calibration — invoke `cfo`, record the go/no-go finding, and flip the capability-matrix roster live

## Summary
Run the ADR-0046 D10 Phase-1 calibration: retroactively invoke the newly authored `cfo` agent against the calibration PR (the ADR-0044/0046 review-agent ADR family — see step 0 to verify the PR number/state before use) and the recent observability ADRs (ADR-0040 / ADR-0045), capture the findings, and record the Phase-1 go/no-go verdict in a calibration note. The exit criterion is binary: did `cfo` produce findings the human would act on? If yes, operational Phase 2 (`security`) proceeds; if no, the specialist pattern itself is reconsidered before more specialists are *operated*.

This packet also performs the **consolidated capability-matrix flip**: it flips all five specialist rows (`cfo`, `security`, `performance`, `ai-safety`, `a11y`) in `constitution/agent-capability-matrix.md` from "planned" to "live" in one edit. Packets 03–07 deliberately leave the matrix untouched so the five row-flips do not collide as concurrent edits to the same table region; this packet runs after all five definition files exist and makes the flip once.

## Context
ADR-0046 D10 Phase 1 has two halves: author `.claude/agents/cfo.md` (packet 03), then **calibrate** — invoke `cfo` retroactively to test whether it earns its keep. ADR-0046 D10 is explicit: "Phase 1's exit criterion is 'did `cfo` produce findings the human acted on?' — if yes, Phase 2 starts; if no, the pattern itself is reconsidered before adding more specialists." This packet is that calibration half.

The calibration target is well-chosen by the ADR: the ADR-0040/0045 first drafts proposed Grafana Cloud + Sentry at ~$200/month before considering that Azure was already paid for and App Insights covered the use case. ADR-0046's Context cites this as the retroactively-justifying use case for `cfo`. Running `cfo` against the as-revised ADRs (and PR #162) tests whether the agent surfaces useful cost-discipline findings even against already-revised material — a stringent bar, since the obvious overcommit was already corrected.

This packet is the **gate** between the specialist roster's authoring and its operational rollout. It is `Actor=Agent` for the mechanical invocation, note-writing, and matrix flip, but the **go/no-go decision itself is the human's** (recorded as a Human Prerequisite). Note the scope distinction: the five specialist agent *files* are all authored by Wave 2 (packets 03–07) regardless of the calibration outcome — the calibration verdict governs operational *use*, not whether the roster files exist.

## Scope
- **Step 0 — verify the calibration PR.** Before invoking `cfo`, confirm the PR number and state with `gh pr view <number> -R HoneyDrunkStudios/HoneyDrunk.Architecture --json number,state,title`. The intended target is the ADR-0044/0046 review-agent ADR family PR (recorded at scope time as PR #162, "docs(adr): add 11 Proposed ADRs 0034-0044…", MERGED). If the number or state has drifted, use the actual PR for that ADR family and record the corrected reference in the calibration note.
- Invoke the `cfo` agent (from packet 03) retroactively against:
  - The verified calibration PR — the ADR-0044/0046 review-agent ADR family.
  - ADR-0040 (Telemetry Backend and Retention) and ADR-0045 (Grid-Wide Error Tracking) — the observability ADRs whose first drafts carried the cost overcommit.
- `generated/post-merge-audits/` or a calibration note under the initiative folder — record the `cfo` findings and the Phase-1 go/no-go verdict. The execution agent picks the location consistent with current convention (ADR-0044 packet 15 created `generated/post-merge-audits/`; if that directory exists, a calibration note there is the natural home; otherwise a `cfo-phase-1-calibration.md` note alongside the dispatch plan in this initiative folder is acceptable).
- Capture any concrete cost-discipline findings `cfo` produces against the calibration PR's branch as commits on that branch, per ADR-0046 D10 Phase 1 ("capture any findings as commits on the same branch") — only if the PR is still open and the findings are actionable; if the PR has merged (as PR #162 has), record the findings in the calibration note as retrospective observations.
- `constitution/agent-capability-matrix.md` — **flip all five specialist rows** (`cfo`, `security`, `performance`, `ai-safety`, `a11y`) from "planned" to "live" in a single edit, and update the status note accordingly. This flip records that the five definition files now exist (which is true once packets 03–07 merge, independent of the calibration verdict). For `a11y`, the row note retains that the lens is dormant until consumer-app UI work begins.

## Proposed Implementation
1. **Verify the calibration PR (step 0).** Run `gh pr view 162 -R HoneyDrunkStudios/HoneyDrunk.Architecture --json number,state,title`. Confirm it is the ADR-0044/0046 review-agent ADR family PR; record number and state in the calibration note. If drifted, find and use the correct PR.
2. With `cfo.md` in place (packet 03) and the global hardlink re-synced (packet 03's Human Prerequisite), invoke `cfo` against each calibration target. For the ADRs, this is the upstream-awareness use case (D5): `cfo` reviewing an ADR's cost commitments.
3. Collect the findings into a calibration note. The note records, per target: what `cfo` flagged, at what severity (`Block` / `Request Changes` / `Suggest`), and whether the finding is one the human would have acted on had it surfaced at draft time.
4. Write the Phase-1 verdict: **Go** if `cfo` produced at least one finding the human judges actionable (the pattern earns its keep — operational Phase 2 proceeds); **No-go / reconsider** if `cfo` produced only noise (the specialist pattern is reconsidered before `security` is *operated* — its lens should not be used in anger until the reconsideration concludes).
5. Flip all five rows in `constitution/agent-capability-matrix.md` from "planned" to "live." This flip reflects that the definition files exist and is independent of the calibration verdict — a No-go verdict pauses *operational use* of the lenses, not the legibility of the roster.
6. Note the calibration outcome's effect on the rest of the initiative: a No-go verdict does not retroactively un-author any specialist file or undo the matrix flip, but it pauses *operational use* of `security`/`performance`/`ai-safety`/`a11y` pending a human decision on whether to amend ADR-0046's roster.

## Affected Files
- A calibration note — `generated/post-merge-audits/cfo-phase-1-calibration.md` or `generated/issue-packets/active/adr-0046-specialist-review-agents/cfo-phase-1-calibration.md` (execution agent chooses per convention).
- `constitution/agent-capability-matrix.md` — the consolidated five-row flip from "planned" to "live."
- Possibly commits on the calibration PR's branch (only if that PR is open and findings are actionable; PR #162 is merged, so this is unlikely).

## NuGet Dependencies
None. This packet runs an agent and writes a Markdown note; no .NET project is created or modified.

## Boundary Check
- [x] The calibration note, the matrix flip, and any branch commits are in `HoneyDrunk.Architecture`. Correct repo.
- [x] No code change in any other repo.
- [x] Invoking an agent, recording its output, and flipping matrix rows are Meta-sector governance activities.

## Acceptance Criteria
- [ ] Step 0 ran: the calibration PR's number and state were verified via `gh pr view` and recorded in the calibration note (intended target PR #162, MERGED)
- [ ] `cfo` has been invoked retroactively against the verified calibration PR, ADR-0040, and ADR-0045
- [ ] A calibration note records, per target, what `cfo` flagged, at what severity, and whether the finding is actionable
- [ ] The note states an explicit Phase-1 verdict: Go (operational Phase 2 proceeds) or No-go (specialist pattern reconsidered before the other lenses are operated)
- [ ] If the calibration PR is open and `cfo` produced actionable findings, those are captured as commits on that branch; if it has merged, the findings are recorded in the note as retrospective observations
- [ ] `constitution/agent-capability-matrix.md` has all five specialist rows (`cfo`, `security`, `performance`, `ai-safety`, `a11y`) flipped from "planned" to "live," with the status note updated and the `a11y` dormant-lens note retained
- [ ] The note states the effect of the verdict on operational rollout (a No-go pauses operational *use* of `security`/`performance`/`ai-safety`/`a11y` pending a roster-reconsideration decision; it does not un-author any file or undo the matrix flip)
- [ ] The repo-level `CHANGELOG.md` gets an entry for the capability-matrix roster going live

## Human Prerequisites
- [ ] **Make the Phase-1 go/no-go decision.** ADR-0046 D10 makes this a human judgment: did `cfo` produce findings worth acting on? The agent assembles the evidence and proposes a verdict; the human ratifies or overturns it. A No-go means the operational *use* of `security`/`performance`/`ai-safety`/`a11y` is paused pending a decision on whether to amend ADR-0046's roster — that pause is a human call, not an automated one. The agent files themselves remain authored and the matrix flip stands regardless.
- [ ] Confirm that `cfo.md` (and ideally the other four specialist files) is hardlink-synced into `~/.claude/agents/` and Claude Code has been restarted, so the `cfo` agent is actually invocable before this calibration runs (this is the carry-over of packets 03–07's Human Prerequisites — a single re-sync covers the batch).

## Dependencies
- `packet:03` — `cfo.md` must exist before it can be invoked.
- `packet:04`, `packet:05`, `packet:06`, `packet:07` — all five specialist definition files must exist before this packet's consolidated capability-matrix row-flip can mark the full roster "live." The calibration itself only needs `cfo` (packet 03), but the matrix flip needs all five.

## Referenced ADR Decisions

**ADR-0046 D10 Phase 1** — Author `cfo.md`, then retroactively invoke it against the ADR-0044/0046 review-agent ADR family PR (recorded as PR #162 — verify before use), capturing findings as commits on the same branch. The retroactive run is the v1 calibration: if `cfo` produces useful findings against an already-revised PR, it earns its keep.
**ADR-0046 D10** — Each phase is a discrete go/no-go. Phase 1's exit criterion: did `cfo` produce findings the human acted on? Yes → Phase 2 starts; no → the pattern is reconsidered before adding more specialists.
**ADR-0046 Context** — The ADR-0040/0045 first-draft cost overcommit (~$200/month Grafana Cloud + Sentry) is the retroactively-justifying use case for `cfo`.
**ADR-0046 D5** — Specialists are upstream-aware; invoking `cfo` against an ADR is the authoring-time application of the lens.
**ADR-0040 / ADR-0045** — The observability ADRs whose first drafts carried the cost overcommit; the calibration targets.
**ADR-0044** — The calibration PR (PR #162 at scope time) is part of the ADR-0044/0046 review-agent ADR family; the cloud-review machinery `cfo` complements.

## Constraints
> **New ADR-0046 invariant:** Specialist review agents are advisory and complementary to the `review` agent. `cfo` findings do not gate merge — the human is the final arbiter. The calibration measures finding *quality*, not a pass/fail gate.

- **Verify the calibration PR first.** Step 0 is mandatory — confirm PR #162's number and state via `gh pr view` before invoking `cfo` against it; do not assume the number.
- **The verdict is the human's.** The agent assembles evidence and proposes; the human decides. Do not record a Go verdict without the human's ratification.
- **A No-go pauses operational use, not authoring.** A No-go verdict pauses the operational *use* of the `security`/`performance`/`ai-safety`/`a11y` lenses pending a roster-reconsideration decision; it does not delete any already-authored specialist file and does not undo the capability-matrix flip — all five files are authored by Wave 2 regardless of the verdict.
- **Calibrate against as-revised material.** The ADR-0040/0045 obvious overcommit was already corrected — `cfo` is being tested against the stringent bar of finding value in already-revised ADRs, which is the deliberate point.

## Labels
`docs`, `tier-2`, `meta`, `adr-0046`, `wave-3`

## Agent Handoff

**Objective:** Verify the calibration PR, run the ADR-0046 D10 Phase-1 calibration — retroactively invoke `cfo` against that PR and ADR-0040/0045, record findings, propose a go/no-go verdict for the human to ratify — and flip all five specialist rows in the capability matrix to "live."

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Test whether the `cfo` specialist earns its keep before *operating* more specialists; mark the full roster live in the capability matrix.
- Feature: ADR-0046 Specialist Review Agents rollout, Phase 1 calibration.
- ADRs: ADR-0046 (D10 primary), ADR-0040/0045 (calibration targets), ADR-0044 (calibration-PR context).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` — `cfo.md` must exist (calibration target agent).
- `packet:04`, `packet:05`, `packet:06`, `packet:07` — all five definition files must exist before the consolidated matrix flip.

**Constraints:**
- Step 0 is mandatory: verify PR #162's number/state via `gh pr view` before invoking `cfo`.
- The go/no-go verdict is the human's to ratify.
- A No-go pauses operational *use* of the other lenses; it does not un-author any file or undo the matrix flip.
- Calibrate against as-revised material — the stringent-bar test is deliberate.

**Key Files:**
- `generated/post-merge-audits/cfo-phase-1-calibration.md` (or a calibration note in this initiative folder)
- `.claude/agents/cfo.md` (the agent being calibrated)
- `constitution/agent-capability-matrix.md` (the consolidated five-row flip)

**Contracts:** None.
