---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "adr-0044", "wave-3"]
dependencies: ["work-item:03b", "work-item:13"]
adrs: ["ADR-0044"]
accepts: ["ADR-0044"]
wave: 3
initiative: adr-0044-cloud-code-review
node: honeydrunk-actions
---

# Activate D8 multi-perspective review for high-risk-Node PRs

## Summary
Extend the `job-review-request.yml` / OpenClaw runner path so that a non-`human` PR touching a high-risk Node - detected via the `review_risk_class` field in `catalogs/grid-health.json` - switches the first pass to the highest-quality locally available review profile and automatically runs a second, contrarian-prompt pass as an independent session, posted as a separate comment.

## Target Workflow
**Files:** `.github/workflows/job-review-request.yml` and the Architecture-owned OpenClaw runner config/runbook
**Family:** pr-core

## Motivation
ADR-0044 D8 requires a non-`human` PR touching a high-risk Node to receive two independent LLM-review perspectives before merge. Phase 3 (D11) activates D8 "once `review_risk_class` lands in `catalogs/grid-health.json`" - that field is delivered by packet 13. This packet wires the request/runner path to consume the field and escalate. Two same-runner passes is the default because it is cheapest and automatic under OpenClaw/Codex; `/ultrareview` and a `refine` pass are alternative escalation paths the human may invoke instead.

## Proposed Change

### High-risk detection
- The workflow reads `catalogs/grid-health.json` (already available via the architecture-repo checkout) and resolves the target repo's `review_risk_class`.
- For `"trigger": "any"` Nodes, any non-`human` PR is high-risk.
- For `"trigger": "path"` Nodes, the workflow checks whether the PR diff touches any `high_risk_paths` glob.
- `human` PRs never trigger D8 (D8 is scoped to non-`human` PRs).

### Escalation behavior (per D8)
When a high-risk touch is detected on a non-`human` PR:
- **First pass switches to the highest-quality locally available review profile** - overrides the `model` default for this PR.
- **A second pass runs automatically** using a deliberately contrarian prompt ("identify ways the first reviewer was wrong"). The two passes are **independent sessions**, posted as **separate comments**.
- The PR body's recorded escalation path notes "two same-agent passes (default)". If the human invoked `/ultrareview` or a `refine` pass instead, the workflow respects that and does not double-run.

### PR-size discipline tightening (D11 Phase 3)
ADR-0044 D11 Phase 3 also moves PR-size discipline "from warnings to auto-comments at the > 800 threshold." Packet 07 shipped `pr-size-check` with the `> 800` path warnings-only and a documented single-point toggle. **This packet flips that toggle** - at `> 800`, `pr-size-check` now auto-comments requesting a split or `refine` pass as the standard behavior (still not a hard merge block - the PR can merge on a logged human override per D7). Make the `pr-core.yml` change here so the Phase-3 discipline tightening lands atomically with D8 activation.

## Consumer Impact
- High-risk-Node PRs now spend more review budget/latency (higher-attention pass + a second pass) - this is the intended D8 cost-for-safety trade. Standard-Node PRs are unaffected.
- The `> 800` PR-size auto-comment now posts as standard Phase-3 behavior across every `pr-core.yml` consumer.

## Breaking Change?
- [ ] Yes
- [x] No - escalation is additive and advisory; the `> 800` change is a posture shift within an existing job, still non-blocking.

## Acceptance Criteria
- [ ] the request/runner path reads `review_risk_class` from `catalogs/grid-health.json` and resolves the target repo's class
- [ ] `"trigger": "any"` and `"trigger": "path"` (diff-glob match) detection both work; `human` PRs never trigger D8
- [ ] On a high-risk non-`human` PR: the first pass uses the highest-quality locally available review profile; a second contrarian-prompt pass runs as an independent session posted as a separate comment
- [ ] The PR records which escalation path was used; `/ultrareview` or `refine` invoked by the human suppresses the auto double-run
- [ ] `pr-size-check`'s `> 800` path is flipped from warnings-only to auto-comment (Phase-3 tightening); still non-blocking with a logged-override path
- [ ] `docs/CHANGELOG.md` updated; `docs/consumer-usage.md` notes the Phase-3 behavior changes

## Human Prerequisites
- [ ] The Phase-2 → Phase-3 go decision must be made; D8 activation should follow observed Phase-2 review quality
- [ ] Confirm OpenClaw/Codex can run two independent passes for high-risk PRs within acceptable latency

## Dependencies
- `work-item:03b` - `job-review-request.yml` / OpenClaw runner trigger path (**hard** - this packet extends it).
- `work-item:13` - `review_risk_class` catalog field (**hard** - D8 activation is explicitly gated on this field landing).

## Referenced ADR Decisions

**ADR-0044 D8** - Non-`human` PRs touching a high-risk Node get two independent LLM-review perspectives; the runner uses the highest-quality locally available review profile for the first pass and auto-runs a contrarian second pass as a separate session/comment. High-risk catalog lives in `catalogs/grid-health.json` `review_risk_class`. `/ultrareview` and `refine` are alternative human-invoked escalation paths.
**ADR-0044 D11 Phase 3** - D8 activates once `review_risk_class` lands; PR-size discipline moves from warnings to auto-comments at the `> 800` threshold.
**ADR-0044 D7** - `> 800` lines: CI auto-comments requesting a split or `refine`; the PR can still merge on a logged human override.

## Constraints
> **Invariant 31:** Every PR traverses the tier-1 gate before merge. D8's second pass and the `> 800` auto-comment are advisory - neither becomes a required check.

- **Two same-agent passes is the default.** Do not implement `/ultrareview` or `refine` as the automatic path - they are human-invoked alternatives.
- **Independent sessions.** The contrarian pass must be a fresh session, not a continuation of the first - independence is the point.
- **`> 800` stays non-blocking.** Phase 3 tightens it to an auto-comment, not a hard gate; the logged-override merge path is preserved per D7.

## Labels
`ci`, `tier-2`, `ops`, `adr-0044`, `wave-3`

## Agent Handoff

**Objective:** Activate D8 multi-perspective review in the OpenClaw runner path (higher-attention first pass + contrarian second pass on high-risk-Node non-`human` PRs) and flip `pr-size-check`'s `> 800` path to auto-comment (Phase-3 tightening).

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Phase-3 discipline tightening - multi-perspective review for high-risk Nodes, harder PR-size posture.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 3.
- ADRs: ADR-0044 (D8, D7, D11 Phase 3).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:03b` - `job-review-request.yml` / OpenClaw runner trigger path (hard).
- `work-item:13` - `review_risk_class` field (hard).

**Constraints:**
- Two same-agent passes is the default; independent sessions; `> 800` stays non-blocking.

**Key Files:**
- `.github/workflows/job-review-request.yml`
- `.github/workflows/pr-core.yml` (the `pr-size-check` `> 800` toggle)
- `docs/CHANGELOG.md`, `docs/consumer-usage.md`

**Contracts:** Consumes `review_risk_class` from `catalogs/grid-health.json` (packet 13).
