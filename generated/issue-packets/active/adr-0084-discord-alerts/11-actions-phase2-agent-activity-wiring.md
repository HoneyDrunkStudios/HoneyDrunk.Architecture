---
name: Phase 2 Emitter Wiring — ADR-0044 Review + ADR-0046 Specialist
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "adr-0084", "adr-0044", "adr-0046", "wave-4"]
dependencies: ["packet:05"]
adrs: ["ADR-0084", "ADR-0044", "ADR-0046"]
wave: 4
initiative: adr-0084-discord-alerts
node: honeydrunk-actions
source: strategic
generator: scope
---

# Wire Phase 2 emitters — ADR-0044 review pipeline + ADR-0046 specialist invocations → #agent-activity

## Summary
Retrofit the ADR-0044 Grid Review pipeline (`job-review-request.yml` or its home-server-hosted bridge successor per ADR-0081) and the ADR-0046 specialist-agent invocation workflow to call `job-discord-notify.yml` (packet 05) targeting `#agent-activity` with `severity: info`. Per ADR-0084 D6: review verdict format `🐝 review on {repo}#{pr}: {verdict} — {pr-link}`; specialist invocation format `🎯 {specialist} on {repo}#{pr}: {verdict} — {pr-link}`.

## Target Workflow
**File:** `.github/workflows/job-review-request.yml` (ADR-0044) and the ADR-0046 specialist invocation workflow (located at packet-11 authoring time)
**Family:** code-review (cloud-wired) per ADR-0044 / ADR-0046

## Motivation
ADR-0084 D6 routes both ADR-0044 review verdicts and ADR-0046 specialist invocations to `#agent-activity` with Info severity. The channel is designed for the "rolling timeline of agent activity" the operator pattern-matches against — *"did Claude and Codex disagree on this PR?" without opening every PR* per ADR-0084 D1.

ADR-0084 Follow-up Work names this packet: *"Phase 2 rollout — wire the ADR-0044 review pipeline and ADR-0046 specialist invocations to `#agent-activity`. Cross-link from ADR-0044's follow-up notes."* The cross-link from ADR-0044 is captured by ADR-0084's Cascade Impact: *"ADR-0044 follow-up note added: if the review-pipeline events are surfaced here, the ADR-0044 D3 rubric category 14 (Distributed systems — Observability) gains 'review-event publication to `#agent-activity`' as a check."* This rubric-extension note lands separately (it is a docs edit to `.claude/agents/review.md`), not in this packet — this packet is the workflow-side wiring.

## Proposed Change
Per ADR-0084 D6 routing:

### ADR-0044 review pipeline wiring
Add a `notify-discord` step to `job-review-request.yml` (or the home-server-hosted bridge successor per ADR-0081 — locate at packet-11 authoring time):

```yaml
notify-discord:
  needs: <review-job-id>
  if: always() && needs.<review-job-id>.outputs.verdict != ''
  uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-discord-notify.yml@main
  with:
    channel: agent-activity
    severity: info
    title: "🐝 review on ${{ github.event.repository.name }}#${{ github.event.pull_request.number }}: ${{ needs.<review-job-id>.outputs.verdict }}"
    link: ${{ github.event.pull_request.html_url }}
    metadata: |
      {"agent":"grid-review","verdict":"${{ needs.<review-job-id>.outputs.verdict }}","pr":"${{ github.event.pull_request.html_url }}"}
  secrets: inherit
```

The exact `<review-job-id>` and the verdict-output mechanism depend on the live `job-review-request.yml` structure at packet execution time. Verdicts per ADR-0044 D3 are one of: `Approve` / `Request Changes` / `Comment`. If the review pipeline emits via a webhook to the home-server bridge per ADR-0081 (rather than via a GitHub Actions job), the notify wiring instead happens in the home-server-side bridge code calling `infrastructure/scripts/discord-notify.ps1` per packet 06 — the routing decision (cloud vs home server) depends on ADR-0044 + ADR-0081 implementation state at packet execution time.

### ADR-0046 specialist invocation wiring
Add a `notify-discord` step to the ADR-0046 specialist invocation workflow (locate at packet-11 authoring time — may be a separate workflow file, may be a job in the ADR-0044 pipeline). Same shape as the review pipeline notify step, but with the specialist-specific title format:

```yaml
notify-discord:
  needs: <specialist-job-id>
  if: always() && needs.<specialist-job-id>.outputs.verdict != ''
  uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-discord-notify.yml@main
  with:
    channel: agent-activity
    severity: info
    title: "🎯 ${{ needs.<specialist-job-id>.outputs.specialist }} on ${{ github.event.repository.name }}#${{ github.event.pull_request.number }}: ${{ needs.<specialist-job-id>.outputs.verdict }}"
    link: ${{ github.event.pull_request.html_url }}
    metadata: |
      {"agent":"specialist","specialist":"${{ needs.<specialist-job-id>.outputs.specialist }}","verdict":"${{ needs.<specialist-job-id>.outputs.verdict }}","pr":"${{ github.event.pull_request.html_url }}"}
  secrets: inherit
```

### ADR-0079 multi-perspective reviewer activity (deferred clarification)
ADR-0084 D2's `#agent-activity` channel description includes *"ADR-0079 Codex/Claude/CodeRabbit/Copilot reviewer activity"*. ADR-0079's review-stack reviewers (Copilot, CodeRabbit, Codex review, Claude review) each emit their findings as PR comments, not as workflow outputs the Grid controls. Wiring ADR-0079 reviewer activity to `#agent-activity` requires either (a) a GitHub event-webhook bridge that listens for new PR comments from those reviewers and posts a summary, or (b) per-reviewer post-step hooks where each reviewer's invoking workflow emits a Discord notify. Neither path is in ADR-0084 Follow-up Work as a Phase 2 deliverable explicitly — Phase 2 names ADR-0044 + ADR-0046 only. This packet handles ADR-0044 + ADR-0046; ADR-0079 reviewer-activity wiring is deferred to a follow-up packet (likely Phase 3 or a separate ADR-0079-scope packet) when the implementation pattern is clear. Note this explicitly in the PR body.

## Consumer Impact
This packet edits workflows that consumer repos call via `workflow_call` (the ADR-0044 review pipeline runs on every PR in repos that opt in per `.honeydrunk-review.yaml` → `enabled: true` per invariant 52). Consumer repos transitively gain Discord notifications for their review verdicts without consumer-side edits.

## Breaking Change?
- [ ] Yes — consumers need to update their caller workflows
- [x] No — backward compatible (additive: new notify step; existing review pipeline behavior unchanged)

## Acceptance Criteria
- [ ] ADR-0044 review pipeline (`job-review-request.yml` or its home-server-hosted bridge successor per ADR-0081 — locate at packet execution time) carries a notify call to `job-discord-notify.yml` with `channel: agent-activity`, `severity: info`, title matching `🐝 review on {repo}#{pr}: {verdict}`, and `link: <pr-html-url>`
- [ ] ADR-0046 specialist invocation workflow carries a notify call with `channel: agent-activity`, `severity: info`, title matching `🎯 {specialist} on {repo}#{pr}: {verdict}`, and `link: <pr-html-url>`
- [ ] Both notify steps use `secrets: inherit` and fire on `always() && verdict != ''` so the post happens regardless of preceding-job exit code
- [ ] The `metadata` JSON for each emitter carries enough structured context for future filtering (`agent`, `verdict`, `pr` for review; `agent`, `specialist`, `verdict`, `pr` for specialist)
- [ ] If the ADR-0044 review pipeline executes on the home server per ADR-0081 (rather than in GitHub Actions), the notify wiring instead invokes `infrastructure/scripts/discord-notify.ps1` per packet 06 with equivalent inputs — the routing decision is captured in the PR body
- [ ] ADR-0079 reviewer-activity wiring (Codex/Claude/CodeRabbit/Copilot) is **explicitly noted as deferred** in the PR body — Phase 2 per ADR-0084 Follow-up Work names ADR-0044 + ADR-0046 only; ADR-0079 wiring is follow-up
- [ ] Per invariant 27, `HoneyDrunk.Actions/CHANGELOG.md` appends to the in-progress version entry (the version was bumped by packet 05) documenting Phase 2 emitter wiring
- [ ] `HoneyDrunk.Actions/README.md` updated to note the review-pipeline Discord emission
- [ ] All affected workflows pass `actionlint` and the repo's existing CI gate post-edit
- [ ] No ad-hoc `curl` to `DISCORD_WEBHOOK_AGENT_ACTIVITY` introduced per ADR-0084 D11

## NuGet Dependencies
None. CI workflow, no .NET project changed.

## Boundary Check
- [x] All edits in `HoneyDrunk.Actions` (and possibly the home-server-side bridge repo if the review pipeline executes there per ADR-0081 — but the helper script that runs there lives in `HoneyDrunk.Architecture/infrastructure/scripts/` per packet 06, and the calling code is whatever runs on the home server; either way, this packet covers the wiring at whichever seam exists).
- [x] No code change in any application Node.
- [x] Adopting workflows are existing review-pipeline workflows; the notify-step retrofit is additive.

## Human Prerequisites
- [ ] After workflow edits land, manually trigger or wait for the next PR review and the next specialist invocation to verify the Discord post lands in `#agent-activity`. Document the verification in the PR.

## Referenced ADR Decisions
**ADR-0084 D2 — Channel taxonomy / `#agent-activity`.** *"ADR-0044 Grid Review verdicts (summary line + PR link), ADR-0046 specialist invocations, ADR-0079 Codex/Claude/CodeRabbit/Copilot reviewer activity, OpenClaw session boundaries. Optional 'agent-noisy' suppression rule per D8 below."* This packet wires the ADR-0044 + ADR-0046 portions of that description; ADR-0079 reviewer-activity wiring is deferred follow-up.

**ADR-0084 D6 — Alert-routing table.** Review verdict format `🐝 review on {repo}#{pr}: {verdict} — {pr-link}`; specialist invocation format `🎯 {specialist} on {repo}#{pr}: {verdict} — {pr-link}`. `channel: agent-activity`, `severity: info` for both.

**ADR-0084 D9 — Implementation seam.** Every CI emitter routes through `job-discord-notify.yml`; if the emitter is home-server-hosted per ADR-0081, it routes through `infrastructure/scripts/discord-notify.ps1` (packet 06) instead. This packet picks the seam matching the live ADR-0044 execution surface at packet execution time.

**ADR-0084 D11 — New invariant.** Every operator-actionable Grid event must publish via the canonical seams. Ad-hoc `curl` is forbidden.

**ADR-0084 Cascade Impact — ADR-0044 follow-up note.** *"if the review-pipeline events are surfaced here, the ADR-0044 D3 rubric category 14 (Distributed systems — Observability) gains 'review-event publication to `#agent-activity`' as a check."* This rubric-extension note is a docs edit to `.claude/agents/review.md` and lands separately — not in this packet.

**ADR-0044 — Grid Review pipeline.** The review pipeline emits a verdict per PR. ADR-0044 D3's rubric categories define the verdict shape; this packet routes the verdict summary to Discord without changing the rubric.

**ADR-0046 — Specialist review agents.** Specialist-agent invocations emit a verdict per invocation. This packet routes the specialist's verdict summary to Discord.

**ADR-0081 — Home server for OpenClaw and local agent infrastructure.** The ADR-0044 review pipeline may execute on the home server (via a webhook bridge) rather than in GitHub Actions; if so, the notify wiring uses `infrastructure/scripts/discord-notify.ps1` (packet 06) instead of `job-discord-notify.yml`.

**Invariant 52 — Every non-draft PR on an `enabled` repo runs the cloud-wired `review` agent.** Consumer repos with `.honeydrunk-review.yaml` → `enabled: true` get review-pipeline runs; this packet's wiring means they also get `#agent-activity` Discord posts.

## Constraints
- **Use the canonical seam matching the ADR-0044 execution surface.** If the review pipeline runs in GitHub Actions, use `job-discord-notify.yml`; if it runs on the home server per ADR-0081, use `infrastructure/scripts/discord-notify.ps1`. Do not author ad-hoc `curl`.
- **ADR-0079 reviewer-activity wiring is deferred.** Phase 2 per ADR-0084 Follow-up Work names ADR-0044 + ADR-0046 only. Note the deferral in the PR body.
- **Title/body templates verbatim from ADR-0084 D6's format-hint column.** `🐝` for ADR-0044, `🎯` for ADR-0046. Match emoji and placeholder names exactly.
- **`metadata` JSON carries structured context for future filtering.** The v2 deferred-concerns in ADR-0084 D8 (severity-based mentions, dedup, threaded follow-ups) consume this metadata; capture enough now to enable later without re-wiring.
- **Append to in-progress CHANGELOG entry per invariant 27.**
- **Strict PR body discipline.** `Authorship: agent`, `Packet: <path>`.

## Labels
`ci`, `tier-2`, `ops`, `adr-0084`, `adr-0044`, `adr-0046`, `wave-4`

## Agent Handoff

**Objective:** Wire ADR-0044 review-pipeline verdicts and ADR-0046 specialist invocations to `#agent-activity` via the canonical seam (`job-discord-notify.yml` or `discord-notify.ps1` depending on execution surface).

**Target:** `HoneyDrunk.Actions` (and the home-server-hosted bridge code if the review pipeline runs there per ADR-0081 — locate the calling code at packet authoring time and edit it via the appropriate repo).

**Context:**
- Goal: Land the rolling-timeline-of-agent-activity surface so the operator can pattern-match agent verdicts without opening every PR.
- Feature: ADR-0084 Discord operator-alerts rollout, Wave 4.
- ADRs: ADR-0084 (D2 channel description, D6 routing, D9 seam, D11 invariant, Cascade Impact ADR-0044 follow-up), ADR-0044 (review pipeline + verdict shape), ADR-0046 (specialist invocations), ADR-0081 (home-server execution surface), Invariants 27/38/39/52.

**Acceptance Criteria:** As listed above.

**Dependencies:** packet:05 (`job-discord-notify.yml` must exist). Packet:06 (`discord-notify.ps1`) is a dependency only if the review pipeline executes on the home server — packet 06 is in the same wave so the dependency is structurally satisfied if execution lands on home server.

**Constraints:**
- Use the canonical seam matching the ADR-0044 execution surface (cloud or home server).
- ADR-0079 reviewer-activity wiring is deferred; note in PR body.
- Title/body templates verbatim from ADR-0084 D6.
- `metadata` JSON carries structured context for future filtering.
- Append to in-progress CHANGELOG entry per invariant 27.
- PR body: `Authorship: agent`, `Packet: <path>`.

**Key Files:**
- `.github/workflows/job-review-request.yml` (ADR-0044 — locate live filename)
- ADR-0046 specialist invocation workflow (locate at packet authoring time)
- Home-server-side bridge code (if applicable per ADR-0081)
- `CHANGELOG.md` (append to in-progress entry)
- `README.md`

**Contracts:** None changed at the consumer-API level. Workflow-internal: review pipeline and specialist invocations now emit Discord posts in addition to PR comments.
