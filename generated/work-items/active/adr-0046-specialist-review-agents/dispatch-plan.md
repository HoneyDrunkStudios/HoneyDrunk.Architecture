# Dispatch Plan: Specialist Review Agents (ADR-0046)

**Date:** 2026-05-22 (initial scope).
**Trigger:** ADR-0046 (Specialist Review Agents) — Proposed 2026-05-21; scoped 2026-05-22.
**Type:** Single-repo. Every packet targets `HoneyDrunk.Architecture`. ADR-0046's Consequences are explicit: "No code-Node changes. This is entirely a Meta-sector decision about the agent surface." The five specialist agents review code across every Node, but the *agent definitions themselves* — and the pattern doc, the capability-matrix rows, the governance flip — live entirely in the Architecture repo.
**Sector:** Meta (ADR governance + agent definitions + reference docs + capability matrix).
**Status:** Draft — pending ADR-0046 acceptance. Packet 01 is the mechanically-coupled acceptance flip. Filing is automated on push to `main` via `file-work-items.yml`.
**Site sync required:** No. ADR-0046 produces governance docs and agent definitions; nothing public-facing on the Studios site.
**Rollback plan:** Every packet is Markdown — the ADR flip, one new invariant, a `copilot/` reference doc, five `.claude/agents/{name}.md` files, capability-matrix rows, a calibration note. All revert cleanly via `git revert`. The five agent files revert by deletion (each is a self-contained definition with no consumer that breaks on its absence — specialists are manually invoked, never imported). The phased D10 rollout is itself the blast-radius control: each phase is a discrete go/no-go, and packet 08's calibration gate stops the roster expanding if `cfo` underperforms.

## Summary

ADR-0046 codifies the **pattern** of specialist review agents — narrow-lens, deeper-rigor reviewers that complement the generalist `review` agent's twenty-category rubric from ADR-0044. It names a roster of five (`cfo`, `security`, `performance`, `ai-safety`, `a11y`), commits to manual invocation at v1, and stages the per-agent definition files as follow-up packets in D8 priority order. This initiative ships **eight packets across three waves**: the governance flip + pattern doc (Wave 1), the four near-term agent files plus the calibration gate (Wave 2 / 3), and the dormant `a11y` agent (Wave 3).

The relationship to ADR-0044 is **layering, not amendment** (ADR-0046 D7): ADR-0044's twenty-category rubric and the generalist `review` agent are untouched; specialists deepen five of the twenty categories on demand. This initiative does not modify `.claude/agents/review.md` or any existing agent — it only *adds* the five new specialist files plus the shared pattern doc.

## Relationship to ADR-0044

ADR-0046 is a **strict superset-by-addition** on top of the already-scoped ADR-0044 initiative (`active/adr-0044-cloud-code-review/`). The dependency is conceptual, not packet-level:

- **No `dependencies:` edge to ADR-0044 packets.** ADR-0046's packets do not block on ADR-0044's packets in the filing pipeline. ADR-0046 references ADR-0044's *decisions* (the twenty-category rubric, the upstream-awareness clause, the cloud review runner) as context, but the specialist agent files can be authored whether or not ADR-0044's rollout is complete — specialists are manually invoked and do not require the cloud-wired `job-review-agent.yml`.
- **The generalist `review` agent (ADR-0044) is the baseline; specialists layer above it.** ADR-0046 D1/D7 are explicit that specialists complement and do not replace `review`. The twenty-category rubric stays the shared standard; `cfo` deepens categories 6/17/18, `security` deepens 9, `performance` deepens 6 (runtime side), `ai-safety` deepens 18 (minus token/cost), `a11y` deepens 16.
- **Practical sequencing recommendation.** Although there is no hard blocking edge, it is cleaner to land ADR-0046's Wave 1 *after* ADR-0044 is Accepted, so the new ADR-0046 invariant (specialists are advisory) sits in `constitution/invariants.md` in the Code Review Invariants group cleanly. Packet 01 assigns the **reserved invariant number 81** — pre-allocated as part of a 12-ADR batch. The true current maximum invariant number in `constitution/invariants.md` is 51 (verified 2026-05-22); the 51→81 gap is intentional batch-reservation headroom. **If any invariant above 51 lands from outside this 12-ADR batch before merge, shift upward, never reuse a number** — packet 01's Human Prerequisite carries this rule.
- **OpenClaw runner (ADR-0024 / ADR-0044 packet 02b).** ADR-0046 D3 mentions specialists may be invoked "via Claude Code or the cloud-wired `job-review-agent.yml` (per ADR-0044) with the specialist agent named explicitly." At v1 this is **manual invocation only** — no CI trigger, no automatic OpenClaw firing. So ADR-0046 does *not* add work to the OpenClaw Grid Review Runner: the runner runs `review.md` (the generalist); specialists are a human-invoked path on top. If ADR-0046 D9's deferred CI-triggered invocation ever lands, *that* follow-up ADR would wire specialists into the runner — out of scope here.

**No overlap, no duplication.** ADR-0044 builds the review *machinery* (runner, workflow, twenty-category rubric, risk-class catalog, post-merge audits). ADR-0046 adds *more reviewer minds* on top of that machinery. The two initiatives touch the same conceptual surface (`.claude/agents/`, `copilot/`, `constitution/invariants.md`) but distinct files — ADR-0046 creates new files and adds rows; it edits nothing ADR-0044 created.

## Phase ↔ Wave mapping

ADR-0046 D10 stages a five-phase rollout. This initiative's three waves map to the phases as follows — the waves build the *artifacts*; the ADR's phases are the *operational milestones* layered on top.

- **Wave 1** = ADR-0046 D10 pre-Phase-1 foundation: the governance flip (packet 01) and the pattern doc + roster registration (packet 02).
- **Wave 2** = the four near-term agent files. Packet 03 (`cfo`) is D10 Phase 1; packets 04/05/06 (`security`/`performance`/`ai-safety`) are D10 Phases 2/3/4. All four are authored as Wave 2 because authoring is delegable work with no inter-agent dependency — but their *operational* phases (when each lens is first used in anger) remain staggered per D10. The five specialist agent **files** are all authored by the end of Wave 2/3 regardless of the calibration outcome; packet 08's go/no-go gate governs operational *use* of the non-`cfo` lenses, not whether the roster is built.
- **Wave 3** = packet 07 (`a11y`, D10 Phase 5 — zero near-term need, file authored ready) and packet 08 (the D10 Phase-1 calibration gate plus the consolidated capability-matrix flip). Packets 03–07 deliberately do **not** edit `constitution/agent-capability-matrix.md` — the five "planned → live" row-flips are consolidated into packet 08 so they do not collide as concurrent edits to the same table region.

**Authoring order vs operational order.** ADR-0046 D8 gives a *priority* order for authoring (`cfo` → `security` → `performance` → `ai-safety` → `a11y`); the packet ordinals 03–07 follow it exactly. The packets carry the right `dependencies:` so the filing pipeline wires the graph; the *operational* go-live of each lens still follows D10's phased cadence, which is a human-cadence matter, not a packet dependency.

## Wave Diagram

### Wave 1 — Foundation

Packet 01 first (the acceptance flip). Then packet 02 — depends only on 01.

- [ ] `HoneyDrunk.Architecture`: **Accept ADR-0046** — flip status, finalize the one new invariant, register the initiative — [`01-architecture-adr-0046-acceptance.md`](01-architecture-adr-0046-acceptance.md)
- [ ] `HoneyDrunk.Architecture`: Codify the specialist-agent pattern (`copilot/specialist-review-rules.md`) and register the five-agent roster in the capability matrix — [`02-architecture-specialist-agent-pattern-and-roster-doc.md`](02-architecture-specialist-agent-pattern-and-roster-doc.md)
  - Blocked by: `work-item:01`.

### Wave 2 — Near-term specialist agents

Runs after Wave 1. Packets 03, 04, 05, 06 — each depends on the acceptance flip (01) and the pattern doc / template (02). They can run in parallel.

- [ ] `HoneyDrunk.Architecture`: Author the `cfo` specialist agent (cost + AI-cost) — [`03-architecture-author-cfo-agent.md`](03-architecture-author-cfo-agent.md)
  - Blocked by: `work-item:01`, `work-item:02`.
- [ ] `HoneyDrunk.Architecture`: Author the `security` specialist agent — [`04-architecture-author-security-agent.md`](04-architecture-author-security-agent.md)
  - Blocked by: `work-item:01`, `work-item:02`.
- [ ] `HoneyDrunk.Architecture`: Author the `performance` specialist agent — [`05-architecture-author-performance-agent.md`](05-architecture-author-performance-agent.md)
  - Blocked by: `work-item:01`, `work-item:02`.
- [ ] `HoneyDrunk.Architecture`: Author the `ai-safety` specialist agent — [`06-architecture-author-ai-safety-agent.md`](06-architecture-author-ai-safety-agent.md)
  - Blocked by: `work-item:01`, `work-item:02`.

### Wave 3 — Dormant agent and the calibration gate

Runs after Wave 2. Packet 07 has zero near-term invocation surface (D10 Phase 5); packet 08 is the D10 Phase-1 calibration gate plus the consolidated capability-matrix flip — it depends on `cfo` (packet 03) for the calibration and on all five definition files (packets 03–07) for the matrix row-flip.

- [ ] `HoneyDrunk.Architecture`: Author the `a11y` specialist agent (file authored ready; lens dormant until UI work starts) — [`07-architecture-author-a11y-agent.md`](07-architecture-author-a11y-agent.md)
  - Blocked by: `work-item:01`, `work-item:02`.
- [ ] `HoneyDrunk.Architecture`: Phase-1 calibration — invoke `cfo`, record the go/no-go finding, flip the five-agent roster live in the capability matrix — [`08-architecture-cfo-phase-1-calibration-run.md`](08-architecture-cfo-phase-1-calibration-run.md)
  - Blocked by: `work-item:03`, `work-item:04`, `work-item:05`, `work-item:06`, `work-item:07`.

## Blocking relationships

The filing pipeline wires `addBlockedBy` from each packet's `dependencies:` frontmatter. For reference:

- `02` ← `01`
- `03` ← `01`, `02`
- `04` ← `01`, `02`
- `05` ← `01`, `02`
- `06` ← `01`, `02`
- `07` ← `01`, `02`
- `08` ← `03`, `04`, `05`, `06`, `07`

Note: packet 08 depends on `03` (`cfo`) because the calibration invokes `cfo`, and on `04`–`07` because its consolidated capability-matrix row-flip marks all five specialist rows "live" and therefore needs all five definition files to exist first. The calibration verdict itself only concerns `cfo`; it *gates* the operational *use* of the other four lenses by D10's go/no-go discipline, but that operational pause is a human-cadence matter (see "Actor classification"), not a filing-pipeline dependency. The five agent files are all authored regardless of the verdict.

## Actor classification

Every packet is **`Actor=Agent`** — all eight are Markdown governance / agent-definition / reference-doc edits within delegable reach. No packet carries the `human-only` label. Several packets carry Human Prerequisites that are not blockers on the agent's critical path:

- **Packet 01** — the human confirms the assigned invariant number before merge. The reserved number is **81**, pre-allocated as part of a 12-ADR batch (true current max in `constitution/invariants.md` is 51, verified 2026-05-22; the gap is intentional reservation headroom). If an invariant above 51 lands from outside the batch before merge, shift upward — never reuse a number.
- **Packets 03, 04, 05, 06, 07** — after each PR merges, the human must **re-sync the global agent hardlinks** so the new specialist registers in `~/.claude/agents/`, then restart Claude Code. The Architecture agents are hardlinked globally; a newly added file is not picked up until the re-sync. This is a post-PR manual action, not in the agent's critical path. If packets 03–06 land in close succession, one re-sync after the batch covers them all; packet 07 (`a11y`) may merge later and warrant its own re-sync.
- **Packet 08** — the human makes the Phase-1 go/no-go call on the `cfo` calibration. ADR-0046 D10 makes this an explicit human judgment: did `cfo` produce findings worth acting on? A No-go pauses the *operational use* of the `security`/`performance`/`ai-safety`/`a11y` lenses pending a roster-reconsideration decision; it does not un-author any specialist file (all five are authored by Wave 2/3 regardless) and does not undo packet 08's consolidated capability-matrix flip. Packet 08 also requires a `gh pr view` verification of the calibration PR (#162) before invoking `cfo`.

## Out-of-scope items from ADR-0046

- **CI-triggered invocation (D9).** ADR-0046 D3 commits to manual invocation only at v1. If the manual cadence proves insufficient, a follow-up ADR amends D3 to add trigger-based automatic invocation — and *that* ADR would wire specialists into the OpenClaw Grid Review Runner / `job-review-agent.yml`. ADR-0046 D9 says to consider it only after Phase 1's manual cadence is observed for ≥30 days. **Not a packet here.**
- **Output-format standardization (D9).** Moot under manual invocation; becomes load-bearing only if D9's automatic invocation lands. **Not a packet here.**
- **Failure-mode discipline (D9).** "What stops `cfo` from blocking every PR?" is moot under manual invocation. **Not a packet here.**
- **Roster expansion (D9).** Privacy/GDPR, SRE, migration safety, anti-entropy, DX are named follow-up candidates. Each lands as a future ADR amendment with the same D2-shaped justification. **Not a packet here.**
- **Specialist-of-specialists meta-agent (D9).** Speculative; only relevant if D9's automation lands. **Not a packet here.**
- **The operational go-live of each lens.** Packets 03–07 *author* the agent files and packet 08 marks the roster "live" in the capability matrix; D10's phased cadence governs *when each lens is first used in anger*. The first-use milestones are operational matters the human runs on the cadence, not packets. Packet 08's go/no-go verdict gates *operational use* of the non-`cfo` lenses from Phase 2 onward — it does not gate whether the agent files are built (they all are, by Wave 2/3).

## Notes

- **Acceptance precedes flip.** ADR-0046 stays Proposed until packet 01's PR merges. Packet 01 is the mechanically-coupled acceptance flip.
- **Single-repo initiative.** Every packet targets `HoneyDrunk.Architecture`. The dispatch plan exists because the eight packets have a real three-wave dependency chain and a conceptual relationship to ADR-0044 worth documenting — not because the work spans repos.
- **Global hardlink re-sync.** Each new agent file (packets 03–07) needs the `~/.claude/agents/` hardlink re-sync and a Claude Code restart before the agent is invocable. This is called out as a Human Prerequisite in every agent-authoring packet and is the single recurring manual action in this initiative.
- **`review.md` is not touched.** ADR-0046 Consequences: "Existing agents are not modified." This initiative only *adds* files and rows. Invariant 33 (review/scope context-loading coupling) is not engaged — no existing agent's context-loading section changes.
- **The dispatch plan is the one exception to packet immutability** (ADR-0008 D7). It is updated at wave boundaries as the historical record.

## Archival

Per ADR-0008 D10, when every packet reaches `Done` on The Hive and ADR-0046's Phase-1 go decision is recorded (packet 08), the `active/adr-0046-specialist-review-agents/` folder moves to `completed/` in a single commit. The D10 Phase 2–5 operational go-lives and any D9 follow-up ADR are tracked separately — they are not appended to this initiative folder.
