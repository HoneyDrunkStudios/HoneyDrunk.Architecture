---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0088", "wave-1"]
dependencies: []
adrs: ["ADR-0088", "ADR-0081", "ADR-0086"]
accepts: ["ADR-0088"]
wave: 1
initiative: adr-0088-openclaw-decommission
node: honeydrunk-architecture
---

# Accept ADR-0088 — decommission OpenClaw; supersede ADR-0081; register the teardown initiative

## Summary
Flip ADR-0088 (Decommission OpenClaw from the HoneyDrunk Grid) from Proposed to Accepted. Flip ADR-0081 (Home Server for OpenClaw and Local Agent Infrastructure) to `Status: Superseded by ADR-0088`. Update `adrs/README.md` (mark ADR-0088 Accepted; mark ADR-0081 Superseded). Remove ADR-0081 from `initiatives/proposed-adrs.md`'s queue. Register the `adr-0088-openclaw-decommission` initiative in `initiatives/active-initiatives.md`. **No teardown side effects** — this packet is the acceptance gate and supersession bookkeeping only. The D3 Group-1 prerequisite (the ADR-0086 runner is proven load-bearing for every workload OpenClaw hosted) is recorded as this packet's acceptance gate; if it is not met, the teardown halts here.

## Context
ADR-0086 already moved the review transport off OpenClaw and built a portable scheduled-agent runner (`infrastructure/workers/grid-agent-runner/`) that covers every workload OpenClaw was reserved for. ADR-0086's Follow-up Work explicitly deferred "a dedicated OpenClaw-decommission ADR is being authored to supersede ADR-0081 and own deletion of the secret + bridge." ADR-0088 is that ADR. This packet lands its acceptance and the ADR-0081 supersession, which is the precondition every downstream teardown packet references as a live rule.

ADR-0081's broad organizing premise — *OpenClaw is the host for all local automation, and the home server exists to host OpenClaw* — no longer holds. What survives ADR-0081's supersession, re-homed under ADR-0086: the home-server **hardware and security premise** (the always-on mini-PC, the no-router-port-forwarding posture, the least-privilege/recoverable security checklist, the local-agent-sandbox idea). ADR-0081 is superseded because its *organizing premise* is dead, not because the home server is. **The home server itself is retained.**

This is a docs/governance-only packet. No code, no workflow, no .NET project, no teardown action. `Actor=Agent`.

## Group-1 prerequisite — the acceptance gate (D3 / D5), made concrete and falsifiable
ADR-0088 D3 Group 1 and D5's abort gate are the binding precondition for this entire initiative: no OpenClaw workload is torn down before its ADR-0086 replacement is proven. The refine pass replaced the original trust-based "operator records a confirmation" phrasing with a **checkable list**, split into the part that is *already provably green* and the *open items* to verify before Wave 2 (the hive-sync + Lore smoke records, plus packet 00a — the committed `docs-sync` job spec — being Done).

### Part A — the review path: ALREADY GREEN (provable from `main`, no operator action)
The review-substrate cutover shipped. Verified against each repo's `main` via the GitHub API on 2026-05-30:
- All 13 non-Actions/Architecture repos (Audit, Auth, Communications, Data, Kernel, Notify, Pulse, Standards, Transport, Vault, Vault.Rotation, Web.Rest, AI) carry `runner: local-worker` in `.honeydrunk-review.yaml` on `main`.
- Every one of those repos' `.github/workflows/pr-review.yml` callers is on the clean form — calling `job-review-request.yml@main` with **no** `openclaw-*` inputs and **no** `openclaw-webhook-secret`.
- The `grid-review` job spec is present and live in `infrastructure/workers/grid-agent-runner/config/jobs/grid-review.psd1`.

So the review path's Group-1 requirement is **satisfied by the current Grid state**, not pending an operator attestation. This is recorded here as fact; no checkbox is required for it.

### Part B — the non-review scheduled jobs: the open items to verify before Wave 2
The review-cutover check does **not** cover the non-review scheduled workloads OpenClaw also hosted. This is the open precondition. Required evidence before any Wave 2 packet files:
- **`hive-sync`** — job spec present at `config/jobs/hive-sync.psd1` (verified present) **and** a smoke record of at least one successful local-worker run.
- **Lore — `lore-source`, `lore-ingest`, `lore-signal-review`** — job specs present at `config/jobs/lore-{source,ingest,signal-review}.psd1` (all three verified present) **and** a smoke record of at least one successful local-worker run each.
- **`docs-sync` (ADR-0085)** — **committed prerequisite: packet 00a authors + smoke-tests a `docs-sync` runner job spec.** As of 2026-05-30 no `docs-sync` job spec existed in `config/jobs/` (the dir held `grid-review`, `hive-sync`, `lore-ingest`, `lore-signal-review`, `lore-source`, `post-merge-audit`), and docs-sync's ADR-0085 execution surface was "OpenClaw scheduled trigger." The operator resolved this open question in favor of **keeping docs-sync automated** (option (a), not the manual-floor option (b)): packet **00a** (Wave 0, the earliest packet in this initiative) authors `config/jobs/docs-sync.psd1`, validates it against the runner's job-spec schema (`Assert-GridAgentJobSpec`), and captures a dry-run smoke record, so docs-sync's ADR-0085 weekly-Friday cadence runs on the ADR-0086 local worker. This is now a **hard precondition** of the Group-1 gate, alongside the hive-sync + Lore smoke records — there is **no operator a/b decision left to make**. Packet 05 re-points ADR-0085's prose onto the worker with no manual-floor caveat; packet 02 only stops docs-sync's OpenClaw schedule once packet 00a is Done.

The gate is satisfied when: the four present job specs (hive-sync + the three Lore jobs) each have a smoke record, **and** packet 00a has landed the `docs-sync` job spec with its dry-run smoke record (the docs-sync surface is no longer an open choice — it is the committed automated scheduler). The agent does not perform the hive-sync/Lore smoke runs (operational/observational), but it **records the concrete evidence** (job-spec presence is verifiable from the repo; the hive-sync/Lore smoke records are the operator's input; packet 00a's status is verifiable from The Hive) in the PR body. This packet may still flip the ADRs even if Part B is not yet green — the *decision* to retire OpenClaw is made — but the dispatch plan must not file Wave 2 packets until Part B's evidence is recorded, including packet 00a being Done.

## Scope
- `adrs/ADR-0088-decommission-openclaw-from-the-grid.md` — flip `**Status:** Proposed` → `**Status:** Accepted`.
- `adrs/ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md` — flip `**Status:** Proposed` → `**Status:** Superseded by ADR-0088`. Add a one-line supersession banner near the top (after Status, before Context) pointing at ADR-0088 and noting the home-server hardware/security premise survives re-homed under ADR-0086.
- `adrs/README.md` — update the ADR-0088 row (line 95) status from `Proposed` to `Accepted`; update the ADR-0081 row (line 89) status from `Proposed` to `Superseded by ADR-0088` with a brief "(home-server premise re-homed under ADR-0086)" pointer in its description.
- `initiatives/proposed-adrs.md` — remove the ADR-0081 row (line 63: `ADR-0081-HOME-SERVER-FOR-OPENCLAW-...` — already pre-annotated "remove this row in ADR-0088 packet 00").
- `initiatives/active-initiatives.md` — register the `adr-0088-openclaw-decommission` initiative with the 5-wave / 9-packet structure (Waves 0–4, including the Wave-0 `docs-sync` job-spec prerequisite packet 00a; place it after the ADR-0086 entry, its closest topical neighbor). Note that this initiative *completes* the teardown ADR-0086 deferred and *supersedes* ADR-0081.

## Proposed Implementation
1. Edit ADR-0088 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Edit ADR-0081 header: `**Status:** Proposed` → `**Status:** Superseded by ADR-0088`. Insert a banner after the Status block, before Context:

   > **Superseded by ADR-0088 (2026-05-30).** OpenClaw is fully retired as a Grid substrate; the ADR-0086 pull-based local worker is the canonical home for all scheduled/triggered agent work. The home-server **hardware and security premise** of this ADR survives — re-homed under [ADR-0086](./ADR-0086-pull-based-local-worker-grid-review-runner.md) D4, which names the home server as the runner host. ADR-0081 is superseded because its OpenClaw-centric *organizing premise* is dead, not because the home server is. See ADR-0088 D1.

3. In `adrs/README.md`: change the ADR-0088 row's status cell to `Accepted`; change the ADR-0081 row's status cell to `Superseded by ADR-0088` and append "(home-server premise re-homed under ADR-0086 D4)" to its description.
4. In `initiatives/proposed-adrs.md`: delete the ADR-0081 line (line 63, pre-annotated for removal here).
5. In `initiatives/active-initiatives.md`: add the `adr-0088-openclaw-decommission` initiative entry with the wave/packet checklist for this folder, the D3 Group-1 prerequisite gate, and the invariant-103 gate (packet 04 blocked by packet 03).
6. Update `CHANGELOG.md` with an entry noting ADR-0088 acceptance, the ADR-0081 supersession, and the initiative registration.

## Affected Files
- `adrs/ADR-0088-decommission-openclaw-from-the-grid.md`
- `adrs/ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md`
- `adrs/README.md`
- `initiatives/proposed-adrs.md`
- `initiatives/active-initiatives.md`
- `CHANGELOG.md`

## NuGet Dependencies
None. Markdown governance files only; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.
- [x] `constitution/invariants.md` is NOT edited (ADR-0088 D6 — no new invariants).
- [x] ADR-0044 and ADR-0079 are NOT edited (ADR-0088 D2 — already superseded-in-part by ADR-0086; re-superseding forbidden).
- [x] No teardown action — no file removal, no secret deletion, no operator step. Those are downstream packets.

## Acceptance Criteria
- [ ] ADR-0088 header reads `**Status:** Accepted`
- [ ] ADR-0081 header reads `**Status:** Superseded by ADR-0088` and carries the supersession banner pointing at ADR-0088 and noting the home-server premise survives under ADR-0086 D4
- [ ] `adrs/README.md` ADR-0088 row status reads `Accepted`
- [ ] `adrs/README.md` ADR-0081 row status reads `Superseded by ADR-0088` with the home-server-premise pointer in its description
- [ ] The ADR-0081 row is removed from `initiatives/proposed-adrs.md`
- [ ] `initiatives/active-initiatives.md` registers the `adr-0088-openclaw-decommission` initiative with the 5-wave / 9-packet structure (Waves 0–4, including the Wave-0 `docs-sync` job-spec prerequisite packet 00a), the Group-1 prerequisite gate, and the invariant-103 (03→04) gate
- [ ] The PR body records the concrete Group-1 evidence: Part A (the review path) noted as already-green from `main` (13 repos `runner: local-worker` + clean callers + `grid-review.psd1` present), and Part B (non-review scheduled jobs) with a smoke record for `hive-sync` + the three Lore jobs AND confirmation that packet 00a landed the `docs-sync` job spec with its dry-run smoke record (the docs-sync surface is the committed automated scheduler — no manual-floor option remains) — OR an explicit note that Part B is not yet green and Wave 2 packets must not file until it is, packet 00a included
- [ ] `constitution/invariants.md` is unchanged
- [ ] `adrs/ADR-0044-...md` and `adrs/ADR-0079-...md` are unchanged
- [ ] No `infrastructure/openclaw/*` file is removed in this packet (that is packet 01)
- [ ] No inventory, walkthrough, node-standup-matrix, or secret change in this packet (those are packets 04 / 02 / 03)
- [ ] CHANGELOG.md updated with the ADR-0088 acceptance + ADR-0081 supersession + initiative registration entry

## Human Prerequisites
- [ ] **Part A (review path) — no action; recorded as already green.** The review-substrate cutover shipped: 13 repos carry `runner: local-worker` on `main`, their `pr-review.yml` callers are on the clean (no-`openclaw-*`) form, and `grid-review.psd1` is a live job spec. Verifiable from `main`; cite it in the PR body.
- [ ] **Part B (non-review scheduled jobs) — the open items before Wave 2.** Provide a smoke record of a successful local-worker run for **`hive-sync`** and each of **`lore-source`, `lore-ingest`, `lore-signal-review`** (all four job specs are verified present in `config/jobs/`). These four are the operator-side verification the review-cutover check does not cover. The fifth non-review workload, `docs-sync`, is covered by committed packet 00a (its job spec + dry-run smoke), not an operator smoke record here — confirm 00a is Done.
- [ ] **Part B — confirm packet 00a landed the `docs-sync` job spec (ADR-0085).** The operator chose to keep docs-sync automated: packet **00a** (Wave 0) authors `config/jobs/docs-sync.psd1` + a dry-run smoke record, re-homing docs-sync's weekly-Friday cadence onto the ADR-0086 worker. This is now a committed prerequisite — **no a/b choice remains**. Confirm packet 00a is Done (verifiable from The Hive) and record it in this packet's PR body. Packet 05 re-points ADR-0085's prose onto the worker with no manual-floor caveat; packet 02 only stops docs-sync's OpenClaw schedule once packet 00a is Done.
- [ ] Record the Group-1 evidence (or the not-yet-green state) in this packet's PR body. This is the D5 abort gate: if Part B is unproven for any workload, the teardown halts before Wave 2 for that workload.

## Dependencies
None. This is the first packet in the initiative.

## Referenced ADR Decisions
**ADR-0088 D1 — Supersede ADR-0081 in full.** ADR-0081's broad premise (OpenClaw hosts all local automation) no longer holds. The home-server hardware/security premise survives, re-homed under ADR-0086 D4. ADR-0081 moves to `Status: Superseded by ADR-0088`, its README row updated, its `proposed-adrs.md` row removed — in the same pass that records ADR-0088's acceptance.

**ADR-0088 D2 — Do not re-supersede ADR-0044 / ADR-0079.** They are already "superseded in part by ADR-0086." Re-superseding would muddy the supersession graph. This ADR cross-references ADR-0086 as the replacement substrate and completes the physical teardown ADR-0086 deferred.

**ADR-0088 D3 Group 1 / D5 — Prerequisite gate.** No OpenClaw workload is torn down before its ADR-0086 replacement is proven. The teardown halts before Group 2 if any replacement is unproven.

**ADR-0088 D6 — No new invariants.** This ADR adds no invariants and does not edit `constitution/invariants.md`.

## Constraints
- **Acceptance precedes any teardown.** ADR-0088 stays Proposed until this packet's PR merges. No downstream teardown packet (01–06) acts before this one.
- **Do not edit `constitution/invariants.md`.** ADR-0088 D6 is explicit — no new invariants; invariant 103 governs the teardown ordering but its text is untouched.
- **Do not edit ADR-0044 or ADR-0079.** ADR-0088 D2 is explicit — already superseded-in-part by ADR-0086; re-superposition is forbidden.
- **Do not perform any teardown action here.** No file removal, no secret deletion, no operator step, no inventory/walkthrough/matrix edit. This packet is acceptance + supersession bookkeeping only.
- **The home server is retained.** The supersession of ADR-0081 retires the OpenClaw premise, not the machine. The banner must make this explicit.
- **Invariant 8 (referenced for the downstream chain):** *Secret values never appear in logs, traces, exceptions, or telemetry.* The inventory never held the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` value; the downstream deletion (packet 03) destroys the value with no recoverable copy. Recorded here so the supersession narrative is consistent with D5's point-of-no-return.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0088`, `wave-1`

## Agent Handoff

**Objective:** Accept ADR-0088, supersede ADR-0081 in full, update the ADR index and proposed-ADR queue, and register the teardown initiative. No teardown side effects.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0088 so the OpenClaw-teardown packets can reference its decisions as live rules, and resolve ADR-0081's dead Proposed premise.
- Feature: ADR-0088 OpenClaw decommission, Wave 1 (D3 Group 1 — acceptance + prerequisite gate).
- ADRs: ADR-0088 (primary), ADR-0081 (superseded in full), ADR-0086 (the replacement substrate; referenced, not edited).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- Acceptance precedes any teardown — ADR-0088 stays Proposed until this PR merges.
- `constitution/invariants.md` is not edited (ADR-0088 D6).
- ADR-0044 and ADR-0079 are not edited (ADR-0088 D2).
- The home server is retained — the ADR-0081 supersession kills the OpenClaw premise, not the machine.
- No teardown action of any kind here (no file removal, no secret deletion, no matrix/inventory edit).
- Record the D3 Group-1 prerequisite confirmation in the PR body.

**Key Files:**
- `adrs/ADR-0088-decommission-openclaw-from-the-grid.md`
- `adrs/ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md`
- `adrs/README.md`
- `initiatives/proposed-adrs.md`
- `initiatives/active-initiatives.md`
- `CHANGELOG.md`

**Contracts:** None.
