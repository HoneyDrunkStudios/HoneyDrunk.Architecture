---
name: Infrastructure
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "infrastructure", "adr-0086", "wave-2"]
dependencies: ["packet:07"]
adrs: ["ADR-0086", "ADR-0006", "ADR-0044"]
accepts: []
wave: 2
initiative: adr-0086-pull-based-local-worker-grid-review
node: honeydrunk-architecture
---

# Decommission the OpenClaw review-runner substrate at Phase A → Phase B cutover

## Summary
Mark the legacy OpenClaw-hosted Grid Review Runner contract doc (`infrastructure/openclaw/grid-review-runner.md`) as superseded by ADR-0086 and the new scheduled-agent-runner doc, with a clear pointer to the new authority. Cross-link from the new `infrastructure/workers/grid-agent-runner/README.md` (landed by packet 03). Document the operator-side review decommission steps — Cloudflare Tunnel hostname removal, ADR-0044 webhook-signing secret rotation in Vault per ADR-0006, and OpenClaw process cleanup of the review-runner role — as Human Prerequisites. Non-review OpenClaw/Honeyclaw jobs are not killed by this packet; they remain running only until their equivalent ADR-0086 runner job specs are smoke-tested and cut over.

## Context
ADR-0086 D10 commits a discrete cutover: "Once the local worker is operating on `HoneyDrunk.Architecture` and Phase A (per D11) is green, the OpenClaw webhook bridge for **review traffic specifically** is taken down." Three concrete actions are enumerated:

1. **`job-review-request.yml`'s webhook-emitting form** in `HoneyDrunk.Actions` is rewritten as the label-and-comment form per D2 — **already done in packet 05** (Wave 1).
2. **The Cloudflare Tunnel hostname for review traffic** (e.g., `grid-review.honeydrunkstudios.com` per ADR-0081 D6 line 151) is removed. Tunnels for other workloads are unaffected.
3. **The webhook-signing secret** used for ADR-0044's primary path is rotated out per ADR-0006's secret-rotation discipline.

Packet 05 handled (1) at the workflow level. This packet handles (2) and (3) at the operator/infrastructure level — both are portal/manual work — plus the docs-side supersession marking. It is filed at Wave 2 because Phase-A go (packet 07's exit) is the precondition: ADR-0086 D10 is explicit that the decommission is "a discrete cutover at the end of Phase A: the worker proves itself on `HoneyDrunk.Architecture`, then the webhook bridge is taken down, then Phase B begins."

ADR-0086 D10 is also explicit on the scheduled-job posture: the review bridge is decommissioned at Phase A -> B cutover; `hive-sync` and Lore jobs remain on their current OpenClaw/Honeyclaw schedules until the equivalent ADR-0086 runner job specs are installed, smoke-tested, and recorded, then the old schedules are disabled per job.

This packet is `Actor=Agent` for the docs/markdown work; the operator-side portal work is in Human Prerequisites.

## Scope

### Architecture-repo doc edits (the agent's work)
- `infrastructure/openclaw/grid-review-runner.md` — add a top-of-document supersession banner pointing at the new authority and at ADR-0086. Do not delete the file (it is the historical record of the OpenClaw runtime contract; the supersession marker is the canonical signal).
- `infrastructure/workers/grid-agent-runner/README.md` — add a cross-link to the now-superseded `infrastructure/openclaw/grid-review-runner.md` for historical context. (The new README was authored in packet 03; this packet adds the back-link.)
- `infrastructure/openclaw/hive-sync.md` — add a migration note pointing at ADR-0086 runner job spec `hive-sync` and clarifying that the OpenClaw schedule remains active only until the runner smoke test and cutover packet record success.
- `infrastructure/README.md` (or whichever index file enumerates `infrastructure/` contents) — update the entry for the OpenClaw review-runner doc to mark it as superseded if such an index exists; if not, no edit there.

### Operator-side actions (Human Prerequisites)
- Cloudflare Tunnel: remove the `grid-review.honeydrunkstudios.com` hostname (or whichever hostname currently routes review traffic per `infrastructure/reference/owned-domains.md` and ADR-0081 D6). Other tunnel hosts remain.
- HoneyDrunk.Vault: rotate out the ADR-0044 webhook-signing secret per ADR-0006 (Tier-2 third-party secret rotation discipline). The secret was named in ADR-0044's CI-surface Key Vault — locate it via `infrastructure/reference/azure-resource-inventory.md` or the existing rotation records; mark the rotation in Log Analytics per invariant 22.
- OpenClaw host: disable any review-runner role / cron / poll job. Leave `hive-sync` and Lore schedules running unless their ADR-0086 runner job specs already have a recorded smoke-test cutover.

## Proposed Implementation

### Supersession banner on the legacy doc
At the top of `infrastructure/openclaw/grid-review-runner.md`, immediately above the existing "**Status:** ADR-0044 Phase 1 runtime contract" line, insert:

```markdown
> **Superseded by ADR-0086 (2026-05-26).**
>
> The OpenClaw-hosted webhook-bridge runtime described below is the historical
> Grid Review Runner. As of Phase A → Phase B cutover of the
> `adr-0086-pull-based-local-worker-grid-review` initiative, the canonical
> Grid Review Runner is the **pull-based local scheduled agent runner** documented in
> [`../workers/grid-agent-runner/README.md`](../workers/grid-agent-runner/README.md).
>
> This document is preserved as the historical contract record. Non-review
> OpenClaw/Honeyclaw jobs remain active only until their equivalent ADR-0086
> runner job specs are smoke-tested and cut over.
```

Also update the existing `**Status:**` line:
- Before: `**Status:** ADR-0044 Phase 1 runtime contract`
- After: `**Status:** Superseded — historical record. See ADR-0086 D10.`

### Cross-link from the new README
In `infrastructure/workers/grid-agent-runner/README.md` (authored by packet 03), add a "Predecessor / historical record" section at the bottom linking to `infrastructure/openclaw/grid-review-runner.md` for readers who want to understand what the review runtime replaced. Also link `infrastructure/openclaw/hive-sync.md` as a migration predecessor for the `hive-sync` job spec.

### CHANGELOG entry
`CHANGELOG.md` records:
- The Phase A → Phase B cutover decision (Phase A passed; cutover authorized).
- The legacy OpenClaw review-runner doc marked superseded.
- The Cloudflare Tunnel hostname removed (Human Prerequisite — recorded as completed by the operator before this packet's PR merges).
- The ADR-0044 webhook-signing secret rotated out per ADR-0006 (Human Prerequisite).
- Scheduled OpenClaw/Honeyclaw jobs explicitly left running until equivalent runner-job cutovers are recorded.

## Affected Files
- `infrastructure/openclaw/grid-review-runner.md` (in-place edit: banner + status update)
- `infrastructure/workers/grid-agent-runner/README.md` (in-place edit: add back-link section)
- `infrastructure/openclaw/hive-sync.md` (in-place edit: migration note)
- `infrastructure/README.md` (in-place edit if it carries an OpenClaw-runner entry)
- `CHANGELOG.md`

## NuGet Dependencies
None. Markdown edits only; no .NET project is created or modified.

## Boundary Check
- [x] All Architecture-repo edits live in `infrastructure/` — the established home for portal walkthroughs, infrastructure contracts, and operator playbooks.
- [x] No code change in any repo.
- [x] OpenClaw/Honeyclaw non-review jobs are not disabled blindly; they remain active until equivalent runner-job smoke tests and cutovers are recorded (ADR-0086 D10).
- [x] `adrs/ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md` is **NOT** edited — ADR-0086 Follow-up Work is explicit that the ADR-0081 D1 review-webhook-bridge bullet edit belongs to ADR-0081's own acceptance/amendment cycle (ADR-0081 is still Proposed). This packet does not touch ADR-0081's body.

## Acceptance Criteria
- [ ] `infrastructure/openclaw/grid-review-runner.md` carries the supersession banner at the top and the `**Status:** Superseded` line
- [ ] The supersession banner cross-links to the new `infrastructure/workers/grid-agent-runner/README.md` and references ADR-0086 D10
- [ ] `infrastructure/workers/grid-agent-runner/README.md` carries a "Predecessor / historical record" section linking back to the legacy review doc and the hive-sync predecessor doc
- [ ] `infrastructure/openclaw/hive-sync.md` carries a migration note pointing at the ADR-0086 `hive-sync` runner job spec
- [ ] If `infrastructure/README.md` (or another index) enumerates the OpenClaw runner doc, its entry is updated to mark it superseded
- [ ] The Cloudflare Tunnel hostname for review traffic (e.g. `grid-review.honeydrunkstudios.com`) has been removed by the operator before this packet's PR merges (recorded in PR body)
- [ ] The ADR-0044 webhook-signing secret has been rotated out of HoneyDrunk.Vault per ADR-0006 by the operator before this packet's PR merges (recorded in PR body; rotation logged in Log Analytics per invariant 22)
- [ ] OpenClaw's review-runner role has been disabled on the home-server host by the operator (cron/poll job stopped); `hive-sync` and Lore schedules remain running unless their ADR-0086 runner-job cutover is already recorded, and the PR body records this verification
- [ ] `adrs/ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md` is unchanged in this packet (the D1 review-webhook-bridge bullet edit is explicitly out of scope per ADR-0086 Follow-up Work — it belongs to ADR-0081's own acceptance cycle)
- [ ] `.claude/agents/review.md` is unchanged
- [ ] `constitution/invariants.md` is unchanged
- [ ] CHANGELOG.md records the cutover decision, the docs supersession, and a pointer to the operator-side actions

## Human Prerequisites
- [ ] **Packet 07 (Phase-A cutover) must have shipped with a recorded go decision.** If Phase A failed verification, do not file this packet; diagnose and re-run Phase A first.
- [ ] **Remove the Cloudflare Tunnel hostname for review traffic.** The hostname is `grid-review.honeydrunkstudios.com` per ADR-0081 D6 (line 151) — verify against `infrastructure/reference/owned-domains.md` and the Cloudflare portal. Remove only this hostname; leave all other tunnel hosts untouched.
- [ ] **Rotate out the ADR-0044 webhook-signing secret in HoneyDrunk.Vault** per ADR-0006. The secret name is whatever ADR-0044 packet 02b (or its predecessor) wrote into the CI-surface Key Vault — check `infrastructure/reference/azure-resource-inventory.md` and the rotation records. Rotation steps: generate a new value (or simply delete the secret if no replacement is needed since the webhook bridge is dead), log the rotation in Log Analytics per invariant 22, and confirm nothing else in the Grid still references the secret (a `gh code search` for the secret name across the org confirms).
- [ ] **Disable OpenClaw's review-runner role.** Stop any cron/poll job that polls for review-request artifacts or comments. Confirm `hive-sync` and Lore schedules are either still running or have explicit ADR-0086 runner cutover records — `journalctl` / OpenClaw dashboard inspection per the operator's usual procedure.
- [ ] **Document the operator-side actions in this packet's PR body** as a short checklist (Cloudflare hostname removed at YYYY-MM-DD HH:MM; secret rotated at YYYY-MM-DD HH:MM with rotation-log link; OpenClaw review-runner disabled at YYYY-MM-DD HH:MM; other workloads verified running). The PR is the audit record.

## Dependencies
- `packet:07` — Phase-A cutover (**hard** — ADR-0086 D10 is explicit that decommission happens at Phase A → Phase B cutover, not before).

## Referenced ADR Decisions

**ADR-0086 D10** — Decommission OpenClaw on the review path at cutover. Three actions: rewrite `job-review-request.yml` (done in packet 05); remove the Cloudflare Tunnel hostname for review traffic; rotate out the webhook-signing secret per ADR-0006. OpenClaw's other roles are unaffected. The decommission is a discrete cutover at the end of Phase A, not a long parallel-run period.

**ADR-0086 Follow-up Work** — Explicit: "Update ADR-0081 D1's Implementation Notes to remove the review-webhook-bridge workload bullet. **Not performed in this ADR pass** because ADR-0081 is still Proposed and the edit shape is one line — leave it to ADR-0081's acceptance/amendment cycle." This packet honors that constraint — ADR-0081 is not edited here.

**ADR-0006** — Secret rotation discipline. Tier-2 third-party secrets rotate ≤ 90 days; exceptions logged in Log Analytics (invariant 22). Decommissioned secrets are simply rotated/removed and the rotation is logged.

**ADR-0044 packet 02b** — Authored the OpenClaw webhook-signing secret and the `grid-review-runner.md` contract doc that this packet supersedes. (Packet 02b itself is not edited — its packet file is in `completed/`; the doc it produced is the supersession target.)

**Invariant 22** — Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace. The webhook-signing secret rotation logs there per ADR-0006 discipline.

## Constraints
> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. The rotation log records the secret name and rotation timestamp, not the value.

> **Invariant 9:** Vault is the only source of secrets. The webhook-signing secret existed in Vault; its rotation/removal stays in Vault.

> **Invariant 22:** Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace. The rotation logs there.

- **Do not disable non-review OpenClaw/Honeyclaw jobs here.** ADR-0086 D10 is explicit — `hive-sync` and Lore schedules cut over only after equivalent runner jobs are smoke-tested and recorded.
- **Do not edit `adrs/ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md`.** ADR-0086 Follow-up Work and ADR-0081's Proposed status make this explicit. The one-line D1 Implementation Notes edit belongs to ADR-0081's own acceptance cycle, not here.
- **Do not delete `infrastructure/openclaw/grid-review-runner.md`.** It is preserved as the historical contract record with a supersession banner.
- **Cloudflare hostname removal is surgical.** Remove only the review-traffic hostname; leave every other tunnel host alone.
- **Phase A go is the precondition.** If packet 07's exit criteria were not met, this packet is not filed — diagnose Phase A first.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `infrastructure`, `adr-0086`, `wave-2`

## Agent Handoff

**Objective:** Mark the legacy OpenClaw review-runner contract doc as superseded, cross-link the new local-worker README, and document the operator-side decommission steps (Cloudflare hostname removal, webhook-signing secret rotation, OpenClaw review-role disable) as Human Prerequisites. Do not edit ADR-0081.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Complete the Phase A → Phase B cutover by retiring the OpenClaw review-runner substrate. Phase B (packet 09 fan-out) begins after this packet merges.
- Feature: ADR-0086 Pull-Based Local Worker rollout, Phase A → Phase B cutover.
- ADRs: ADR-0086 (primary, D10 + Follow-up Work), ADR-0006 (rotation discipline), ADR-0081 (referenced; not edited).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:07` — Phase-A cutover (hard).

**Constraints:**
- Non-review OpenClaw/Honeyclaw jobs preserved until runner-job cutover.
- Do NOT edit ADR-0081.
- Do NOT delete the legacy doc; mark it superseded.
- Cloudflare hostname removal is surgical (only the review hostname).
- Phase A go is the precondition.

**Key Files:**
- `infrastructure/openclaw/grid-review-runner.md`
- `infrastructure/workers/grid-agent-runner/README.md`
- `infrastructure/openclaw/hive-sync.md`
- `infrastructure/README.md` (if it carries an OpenClaw-runner entry)
- `CHANGELOG.md`

**Contracts:** None.
