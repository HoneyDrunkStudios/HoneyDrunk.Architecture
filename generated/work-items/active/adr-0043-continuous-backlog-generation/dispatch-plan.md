# Dispatch Plan: Continuous Backlog Generation (ADR-0043)

**Date:** 2026-05-22 (initial scope).
**Trigger:** ADR-0043 (Continuous Backlog Generation Strategy) — Proposed 2026-05-21; scoped 2026-05-22 (priority #5 on `current-focus.md`).
**Type:** Single-repo. Every packet targets `HoneyDrunk.Architecture`. ADR-0043 D8 is explicit: "No code-Node changes. This is entirely a Meta-sector decision about how work flows into the existing pipeline." The four backlog *sources* eventually produce packets for all Nodes, but the *machinery* this initiative builds — directories, agent-definition amendments, the rotation file, the briefing mode, the rules amendment — lives entirely in the Architecture repo.
**Sector:** Meta (governance + agent definitions + tracking files).
**Status:** Draft — pending ADR-0043 acceptance. Packet 01 is the mechanically-coupled acceptance flip. Filing is automated on push to `main` via `file-work-items.yml`.
**Site sync required:** No. ADR-0043 produces governance docs and agent definitions; nothing public-facing on the Studios site.
**Rollback plan:** Every packet is Markdown — governance docs, agent definitions, tracking files, directory READMEs. All revert cleanly via `git revert`. The four new directories revert by deletion (each holds only a README until packet 08 runs). The agent-definition amendments (packets 05/06/07) revert to the prior agent behaviour by reverting the file. Packet 08's `proposed/` output is dry-run packet files that are never filed as issues until a human triages them — reverting packet 08 simply removes those files from the queue. The phased rollout (D9) is itself the blast-radius control: each phase is a discrete go/no-go and Phases 2–4 do not auto-start if Phase 1 underperforms.

## Summary

ADR-0043 fills the empty slot **upstream** of the packet pipeline. Downstream of a packet is industrialized (file → issue → board → PR per ADR-0008); upstream — *finding* and *queuing* the work — was artisanal. ADR-0043 commits to four named backlog sources (Strategic, Tactical, Opportunistic, Reactive), a weekly triage briefing, a three-state packet lifecycle (`proposed/` → `active/` → `completed/`), and a packet-handoff contract.

This initiative ships **eight packets across three waves**. It explicitly defers (per ADR-0043 D7) the *execution surface* — whether the source cadences run via OpenClaw cron, GitHub Actions cron, a `/loop` slash command, or manual invocation. That choice is a separate follow-up ADR due within 90 days of acceptance. Until then, the *shape* this initiative builds is honored by the human invoking the appropriate agent on the documented cadence.

## Phase ↔ Wave mapping

ADR-0043 D9 stages the rollout. This initiative's three waves build the *machinery*; the ADR's four *phases* are operational milestones that run on the machinery once it exists.

- **Wave 1** = the Phase-1 foundation (acceptance, directories, the rules contract, the rotation schedule).
- **Wave 2** = the agent amendments that make the sources and the briefing real (`hive-sync`, `scope`/`node-audit`/`product-strategist`, `netrunner`).
- **Wave 3** = the Phase-1 kickoff dry run that validates the Strategic source.

ADR-0043 D9's Phase 2 (Tactical rotation begins Week 3), Phase 3 (Opportunistic Scout; Reactive expands to CVE/incidents), and Phase 4 (execution-surface follow-up ADR) are operational milestones *after* this initiative's eight packets land — they are not packets here. Phase 3's CVE/incident reactive sub-sources and Phase 4's execution-surface ADR are out-of-scope follow-ups (see below).

## Wave Diagram

### Wave 1 — Foundation (Phase 1)

Packet 01 first (the acceptance flip). Then 02, 03, 04 in parallel — all depend only on 01.

- [ ] `HoneyDrunk.Architecture`: **Accept ADR-0043** — flip status, finalize the two new invariants, register the initiative — [`01-architecture-adr-0043-acceptance.md`](01-architecture-adr-0043-acceptance.md)
- [ ] `HoneyDrunk.Architecture`: Create the four backlog-generation directories with READMEs — [`02-architecture-create-backlog-generation-directories.md`](02-architecture-create-backlog-generation-directories.md)
  - Blocked by: `work-item:01`.
- [ ] `HoneyDrunk.Architecture`: Amend `issue-authoring-rules.md` for `source`/`generator`/`priority` + the three-state lifecycle — [`03-architecture-issue-authoring-rules-source-generator-fields.md`](03-architecture-issue-authoring-rules-source-generator-fields.md)
  - Blocked by: `work-item:01`.
- [ ] `HoneyDrunk.Architecture`: Author `initiatives/audit-rotation.md` with the 12-Node rotation — [`04-architecture-author-audit-rotation-file.md`](04-architecture-author-audit-rotation-file.md)
  - Blocked by: `work-item:01`.

### Wave 2 — Source and briefing agents (Phase 1/2)

Runs after Wave 1. Packets 05, 06, 07 — each depends on the directories (02) and the frontmatter contract (03); 06 also needs the rotation file (04).

- [ ] `HoneyDrunk.Architecture`: Amend `hive-sync` — Strategic acceptance trigger + Reactive drift-to-packet conversion — [`05-architecture-hive-sync-strategic-and-reactive-triggers.md`](05-architecture-hive-sync-strategic-and-reactive-triggers.md)
  - Blocked by: `work-item:02`, `work-item:03`.
- [ ] `HoneyDrunk.Architecture`: Amend `scope`/`node-audit`/`product-strategist` for the `proposed/` output contract — [`06-architecture-source-agents-proposed-output-contract.md`](06-architecture-source-agents-proposed-output-contract.md)
  - Blocked by: `work-item:02`, `work-item:03`, `work-item:04`.
- [ ] `HoneyDrunk.Architecture`: Add the Weekly Briefing mode to `netrunner` — [`07-architecture-netrunner-weekly-briefing-mode.md`](07-architecture-netrunner-weekly-briefing-mode.md)
  - Blocked by: `work-item:02`, `work-item:03`.

### Wave 3 — Phase-1 kickoff dry run

Runs after Wave 2. Packet 08 — the first real exercise of the Strategic source.

- [ ] `HoneyDrunk.Architecture`: Phase 1 kickoff — run the Strategic source against the Proposed ADR-0034–0042 batch — [`08-architecture-phase-1-strategic-source-kickoff.md`](08-architecture-phase-1-strategic-source-kickoff.md)
  - Blocked by: `work-item:02`, `work-item:03`, `work-item:05`, `work-item:06`.

## Blocking relationships

The filing pipeline wires `addBlockedBy` from each packet's `dependencies:` frontmatter. For reference:

- `02` ← `01`
- `03` ← `01`
- `04` ← `01`
- `05` ← `02`, `03`
- `06` ← `02`, `03`, `04`
- `07` ← `02`, `03`
- `08` ← `02`, `03`, `05`, `06`

## Actor classification

Every packet is **`Actor=Agent`** — all eight are Markdown governance/agent/tracking edits within delegable reach. No packet carries the `human-only` label. Three packets carry Human Prerequisites that are *confirmation* steps, not blockers on the agent's critical path:

- **Packet 01** — the human confirms before merge that no invariant above 51 has landed from outside the 12-ADR batch (which would force the reserved 78/79 block to shift upward).
- **Packet 04** — the human confirms the audit-rotation order (the agent proposes a defensible default from `nodes.json`).
- **Packet 08** — the human makes the Phase-1 go/no-go call on the kickoff report (ADR-0043 D9: Phases 2–4 do not auto-start if Phase 1 is more noise than value).

## Out-of-scope items from ADR-0043

- **The execution-surface follow-up ADR (D7).** ADR-0043 explicitly defers whether the source cadences run via OpenClaw cron, GitHub Actions cron, a `/loop` slash command, or manual invocation. A follow-up ADR decides this within 90 days of acceptance, after the first `node-audit` rotation quarter and the first Scout pass. **Not a packet here** — it is a new ADR, routed to `adr-composer` when the 90-day window or the informing data arrives.
- **Reactive CVE and incident sub-sources (D9 Phase 3).** Packet 05 wires Reactive-for-*drift* only — the lowest-cost sub-source, "already 80% built into `hive-sync`." The security-CVE sub-source (ADR-0009 nightly scan → `priority: urgent` packet) and the incident sub-source (`generated/incidents/` → corrective-action packet) expand in Phase 3. Each is its own follow-up packet against the then-current `hive-sync`.
- **Canary-failure Reactive sub-source (D4 Reactive).** ADR-0043 D4 lists "canary failing past its grace window" as a Reactive trigger. Like the CVE/incident sub-sources, this is a Phase-3 expansion; not scoped here.
- **The Opportunistic Scout cadence going live (D9 Phase 3).** Packet 06 documents `product-strategist`'s output contract; the monthly Scout pass actually beginning is a Phase-3 operational milestone, not a packet.

## current-focus.md priority correspondence

`current-focus.md` priority #5 ("Land ADR-0043 — Backlog Generation") is discharged by this initiative. Its exit signal — "ADR-0043 Accepted; `generated/work-items/proposed/` directory + Strategic source live" — is satisfied by packet 01 (Accepted), packet 02 (`proposed/` directory), and packets 05/06/08 (Strategic source live and exercised). When all eight packets reach `Done` on The Hive, priority #5 should be marked complete and dropped from the ranked list at the next ADR-0043 weekly briefing. (Pleasingly recursive: ADR-0043's own completion is triaged by the briefing surface ADR-0043 creates.)

## Agents intentionally NOT amended

ADR-0043 D4's Strategic path invokes the `refine` agent (a `refine` pass runs against the dispatch plan when a decision implies more than 3 packets). **`refine.md` is deliberately left unchanged** by this initiative: `refine` already reviews dispatch plans as its existing function and needs no new behaviour to play its ADR-0043 role. The gap is intentional and explained here, not silent — there is no missing packet.

## Notes

- **Invariant numbers are pre-reserved at 78-79.** ADR-0043's two new invariants take the hard-reserved numbers 78 and 79 (packet 01). The true current max in `constitution/invariants.md` is 51 (verified). 78-79 are pre-reserved as part of a 12-ADR batch to avoid colliding with ADR-0044 over 52/53. **If any invariant above 51 lands from outside this batch before merge, shift this block upward, never reuse a number.** Packet 01 must not scan for "next free."
- **Acceptance precedes flip.** ADR-0043 stays Proposed until packet 01's PR merges. Packet 01 is the mechanically-coupled acceptance flip.
- **Single-repo initiative.** Unlike most multi-repo ADR rollouts, every packet here targets `HoneyDrunk.Architecture`. The dispatch plan exists because the eight packets have a real dependency chain across three waves, not because the work spans repos.
- **Packet 08 is a machinery validation, not a backlog run.** Packet 08 runs the Strategic source against the ADR-0034–0042 batch purely to validate the machinery end-to-end (`proposed/` routing, `source`/`generator` frontmatter, the `scope` path). Those ADRs already have `active/` folders, so the expected and **acceptable PASS outcome is zero new packets plus a kickoff report** confirming the path works. Packet 08 does not oversell itself as generating backlog; a zero-packet result is success, not failure.
- **Invariant 33 coupling.** Packet 06 amends `scope.md`. If that edit touches `scope.md`'s context-loading section, the mirror in `review.md` must be updated in the same PR (invariant 33: review-agent context must be a superset of scope-agent context). Packet 06's acceptance criteria carry this check.
- **The dispatch plan is the one exception to packet immutability** (ADR-0008 D7). It is updated at wave boundaries as the historical record.

## Archival

Per ADR-0008 D10 and ADR-0043 D3, when every packet reaches `Done` on The Hive and ADR-0043's Phase-1 go decision is recorded, the `active/adr-0043-continuous-backlog-generation/` folder moves to `completed/` in a single commit. ADR-0043 D3 formalizes the lifecycle as `proposed/` → `active/` → `completed/`; there is no `archive/` state, and invariant 37 confirms completed packets move to `completed/`. The Phase-2/3/4 operational milestones and the execution-surface follow-up ADR are tracked separately — they are not appended to this initiative folder.
