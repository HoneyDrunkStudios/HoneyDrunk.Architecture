---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "adr-0043", "wave-3"]
dependencies: ["packet:02", "packet:03", "packet:05", "packet:06"]
adrs: ["ADR-0043"]
accepts: ["ADR-0043"]
wave: 3
initiative: adr-0043-continuous-backlog-generation
node: honeydrunk-architecture
---

# Phase 1 kickoff — validate the Strategic-source machinery end-to-end

## Summary
Run the first Strategic-source pass to **validate the machinery end-to-end**: invoke the `scope` agent against the Proposed ADRs in the ADR-0034 through ADR-0042 range and confirm the Strategic source produces correctly-routed, correctly-frontmattered output. This is a validation exercise, not a backlog-generation exercise. Because ADR-0034–0042 already have `active/` initiative folders, the expected and **acceptable PASS outcome is zero new packets plus a kickoff report** confirming the path works. Do not expect — or frame this as — a packet-producing run.

## Context
ADR-0043 D9 Phase 1 brings the Strategic source live. ADR-0043's Follow-up Work names the concrete kickoff: "Phase 1 kickoff: invoke `scope` against ADR-0034 through ADR-0042 to populate the first round of `proposed/` packets. This is also the first real-world test of the Strategic source."

These nine ADRs (the commercial/substrate batch — public package distribution, abstractions versioning, disaster recovery, payment/billing, sender deliverability, OSS license, telemetry retention, AI model registry, async idempotency) are tracked in `initiatives/current-focus.md` Future/Watch as "all Proposed; each gated on a forcing function." The Strategic source's job here is **not** to accept those ADRs — it is to demonstrate that when an ADR moves to Accepted, the Strategic source produces well-formed implementation packets into `proposed/` for human triage.

**What this packet actually validates — read honestly.** ADR-0043 D4 Strategic says the Strategic source triggers *on acceptance*. The nine ADRs in the 0034–0042 range are still Proposed and **already have scoped `active/` initiative folders**. This packet therefore very likely produces **zero new `proposed/` packets** — and that is the expected, acceptable PASS. Its real deliverable is proof that the Strategic-source machinery (the `scope` agent's `proposed/`-routing, the `source`/`generator` frontmatter, the directory plumbing) operates correctly end-to-end, and a kickoff report recording that. This packet does not generate backlog; it validates a path. Do not reframe it as a backlog-producing run, and do not treat a zero-packet result as a failure.

This is a process/validation packet. No code, no workflow, no .NET project — its deliverable is a kickoff report, plus `proposed/` packet files only in the unlikely event an in-range ADR has no `active/` folder.

## Scope
- For each Proposed ADR in the ADR-0034 to ADR-0042 range that does **not** already have a scoped initiative folder under `generated/issue-packets/active/`, run a `scope` pass and write the resulting packets to `generated/issue-packets/proposed/`.
- **Exclude** ADRs that already have an `active/` initiative folder: as of scoping, `active/` contains `adr-0034-public-package-distribution`, `adr-0035-abstractions-versioning`, `adr-0036-disaster-recovery-and-backup-policy`, `adr-0037-payment-and-billing-integration`, `adr-0038-outbound-sender-identity-and-deliverability`, `adr-0039-grid-open-source-license-policy`, `adr-0040-telemetry-backend-and-retention`, `adr-0041-ai-model-registry-and-approval-workflow`, and `adr-0042-idempotency-contract-for-async-boundaries`. The execution agent must re-check `active/` at execution time — **only ADRs in the 0034–0042 range with no existing folder get a Strategic pass.** If every ADR in the range already has a folder (likely, given the list above), this packet's deliverable shrinks to the kickoff report alone (see below) — that is an acceptable and expected outcome; record it.
- `generated/briefings/` — write a short Phase-1 kickoff report `generated/briefings/{YYYY-MM-DD}-phase-1-kickoff.md` (or fold into the first weekly briefing if one has run) recording: which ADRs were scoped, how many `proposed/` packets were produced, which ADRs were skipped because they already have a folder, and an assessment of whether the Strategic source produced useful output (the Phase-1 go/no-go signal per ADR-0043 D9).

## Proposed Implementation
1. Enumerate `adrs/ADR-00{34..42}-*.md`; read each `**Status:**`.
2. Cross-reference `generated/issue-packets/active/` for an existing `adr-00NN-*` initiative folder.
3. For each ADR with **Proposed status and no existing folder**: run a `scope` pass producing packets with `source: strategic`, `generator: scope` frontmatter into `generated/issue-packets/proposed/`, named `{YYYY-MM-DD}-{repo}-{description}.md` per ADR-0008 D10. These are dry-run packets — they reference a Proposed (not Accepted) ADR and stay in `proposed/` until the parent ADR is accepted.
4. Write the kickoff report to `generated/briefings/`.
5. If all nine ADRs already have folders, step 3 produces nothing — this is the expected PASS. The kickoff report records that the Strategic-source machinery is validated (directory routing, `source`/`generator` frontmatter, the `scope` `proposed/` path all confirmed working by packets 05/06 and this run), states that zero new packets is a correct and acceptable outcome here, and recommends the next genuine Strategic trigger (the next real ADR acceptance) as the first true backlog-producing run.

## Affected Files
- `generated/issue-packets/proposed/*.md` (new — zero or more, depending on how many ADRs in range lack a folder)
- `generated/briefings/{YYYY-MM-DD}-phase-1-kickoff.md` (new)

## NuGet Dependencies
None. This packet produces Markdown packet files and a report; no .NET project is created or modified.

## Boundary Check
- [x] All output under `HoneyDrunk.Architecture/generated/`. Correct repo per routing.
- [x] No code change in any repo. The `proposed/` packets *describe* future cross-repo work but are not themselves filed as issues — they await human triage.
- [x] No ADR is accepted or modified by this packet.

## Acceptance Criteria
- [ ] Every Proposed ADR in the ADR-0034–0042 range has been checked for an existing `active/` initiative folder
- [ ] For each in-range Proposed ADR without a folder, a `scope` pass has produced `proposed/` packets with `source: strategic` and `generator: scope` frontmatter
- [ ] All produced packets are in `generated/issue-packets/proposed/`, none in `active/`
- [ ] A Phase-1 kickoff report exists in `generated/briefings/` recording ADRs scoped, packet counts, ADRs skipped, and the Strategic-source go/no-go assessment
- [ ] If all in-range ADRs already have folders, the kickoff report explicitly records that zero new packets is the expected, acceptable PASS and states the machinery is validated
- [ ] The kickoff report frames this run as a machinery validation, not a backlog-generation exercise
- [ ] No ADR status is changed by this packet

## Human Prerequisites
- [ ] Review the Phase-1 kickoff report and make the Phase-1 go/no-go call (ADR-0043 D9: "If Phase 1 generates more noise than value, Phases 2–4 don't auto-start"). The dry-run `proposed/` packets remain parked until their parent ADRs are accepted; the human decides at a weekly briefing whether to keep, refine, or drop them.

## Dependencies
- `packet:02` — the `generated/issue-packets/proposed/` and `generated/briefings/` directories must exist.
- `packet:03` — the `source`/`generator` frontmatter contract must be documented before packets are produced with those fields.
- `packet:05` — the `hive-sync` Strategic trigger documents how Strategic passes are triggered in steady state; this kickoff is the first manual exercise of that path.
- `packet:06` — `scope.md` must document the agent-cadence-Strategic-runs-write-to-`proposed/` behaviour before `scope` is run as the Strategic source.

## Referenced ADR Decisions

**ADR-0043 D4 Strategic** — The Strategic source triggers on ADR/PDR acceptance; `scope` produces one packet per implementation step, a dispatch plan when >3 packets are implied, with a `refine` pass before packets land.
**ADR-0043 D9 Phase 1** — Strategic source live; this kickoff is "the first real-world test of the Strategic source"; each phase is an independent go/no-go.
**ADR-0043 Follow-up Work** — "Phase 1 kickoff: invoke `scope` against ADR-0034 through ADR-0042 to populate the first round of `proposed/` packets."

## Constraints
- **Dry run — no acceptance.** The ADR-0034–0042 batch is Proposed and gated on forcing functions. This packet does not accept any of them. Its packets stay in `proposed/` until the parent ADR is genuinely accepted.
- **`proposed/` only.** No packet produced here goes to `active/`; the human triages.
- **Skip already-scoped ADRs.** Any ADR with an existing `active/adr-00NN-*` folder is excluded — re-scoping it would duplicate filed work.
- **Honor the >3-packet quality control.** If a scoped ADR implies more than 3 packets, produce a dispatch plan and note that a `refine` pass is owed before the packets would be promoted.

## Labels
`chore`, `tier-2`, `meta`, `adr-0043`, `wave-3`

## Agent Handoff

**Objective:** Run the first Strategic-source pass against the Proposed ADR-0034–0042 batch, seeding `generated/issue-packets/proposed/` and writing a Phase-1 kickoff report.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Validate the Strategic source end-to-end and produce the first round of `proposed/` packets.
- Feature: ADR-0043 Continuous Backlog Generation rollout, Phase 1 kickoff.
- ADRs: ADR-0043 (D4 Strategic, D9 Phase 1).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — directories exist.
- `packet:03` — frontmatter contract documented.
- `packet:05` — `hive-sync` Strategic trigger documented.
- `packet:06` — `scope.md` `proposed/` behaviour documented.

**Constraints:**
- Dry run — accept no ADR; `proposed/` only; skip already-scoped ADRs; honor the >3-packet dispatch-plan rule.

**Key Files:**
- `adrs/ADR-0034-*.md` through `adrs/ADR-0042-*.md` (read-only, to scope)
- `generated/issue-packets/active/` (read-only, to detect already-scoped ADRs)
- `generated/issue-packets/proposed/*.md` (new output)
- `generated/briefings/{YYYY-MM-DD}-phase-1-kickoff.md` (new report)

**Contracts:** None.
