---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0043", "wave-2"]
dependencies: ["work-item:02", "work-item:03"]
adrs: ["ADR-0043", "ADR-0007"]
accepts: ["ADR-0043"]
wave: 2
initiative: adr-0043-continuous-backlog-generation
node: honeydrunk-architecture
---

# Add the weekly-briefing triage mode to the netrunner agent

## Summary
Amend the `netrunner` agent definition with a Weekly Briefing mode: a scheduled (weekly) triage report committed to `generated/briefings/{YYYY-MM-DD}.md` that summarizes new `proposed/` packets, closed and stale `active/` work, stale proposals, the top-3 recommended next actions, and any `priority: urgent` reactive packets — the single human-AI sync surface ADR-0043 D5 defines.

## Context
ADR-0043 D1 names one triage surface — the weekly briefing — and assigns it to `netrunner`. D5 makes it "the single review surface": the standing human-AI sync where the human reads, makes `proposed/` → `active/` triage decisions, and the week's work flows from the resulting `active/` queue. There is no other standing review (daily briefings were considered and rejected in D9).

`netrunner` today produces an on-demand tactical "what's next?" briefing. The Weekly Briefing mode is a related but distinct output: it is scheduled, it is committed as a dated artifact, and its contents are fixed by ADR-0043 D5. This packet adds that mode to the agent definition without removing the existing on-demand briefing.

This is an agent-definition (Markdown) packet. No code, no workflow, no .NET project. `.claude/agents/` is the agent source of truth per ADR-0007.

## Scope
- `.claude/agents/netrunner.md` — add the Weekly Briefing mode.

## Proposed Implementation
Add a "Weekly Briefing" mode section to `netrunner.md`. The mode produces one Markdown file at `generated/briefings/{YYYY-MM-DD}.md`. Its contents are fixed by ADR-0043 D5 — document each section:

1. **New `proposed/` packets since the last briefing**, grouped by `source` (`strategic` / `tactical` / `opportunistic` / `reactive`). `netrunner` determines "since the last briefing" by reading the most recent prior file in `generated/briefings/`.
2. **`active/` packets that closed since the last briefing.**
3. **`active/` packets open more than 14 days with no status change** — the stale-work surface.
4. **`proposed/` packets older than 30 days** — the stale-proposal surface, flagged for "promote, refine, or drop" triage.
5. **The top-3 recommended next actions for the week ahead.**
6. **Any `priority: urgent` reactive packets**, cross-referenced to `generated/briefings/urgent.md`.

Document the framing rules from ADR-0043:
- The briefing is **not** a backlog source — it is the human-facing triage trigger. Sources fill the queue; the briefing surfaces the head of it.
- Cadence is weekly (Monday-of-each-week). Document that daily was rejected (D9) and bi-weekly is the fallback if weekly proves heavier than budgeted (D5 Operational Consequences) — the cadence is the lever before reducing sources.
- The briefing is read-only with respect to packets — `netrunner` does not promote, edit, or delete packets. It summarizes; the human triages.
- `priority: urgent` reactive packets do not wait for the Monday briefing — they are surfaced out-of-band in `generated/briefings/urgent.md` per D6. The weekly briefing still lists them (section 6) so they are not lost, but the urgent file is their primary surface.

Document that the existing on-demand "what's next?" briefing modes (full briefing, "what shipped?", single-Node deep dive, etc.) are unchanged — the Weekly Briefing is an additional, scheduled, file-committed mode.

## Affected Files
- `.claude/agents/netrunner.md`

## NuGet Dependencies
None. This packet edits a Markdown agent-definition file; no .NET project is created or modified.

## Boundary Check
- [x] `.claude/agents/` is the single source of truth for agent definitions (ADR-0007); lives in `HoneyDrunk.Architecture`. Correct repo.
- [x] No code change in any repo.
- [x] `netrunner`'s read-only / non-mutating posture is preserved — the Weekly Briefing summarizes, it does not triage.

## Acceptance Criteria
- [ ] `netrunner.md` has a Weekly Briefing mode section producing `generated/briefings/{YYYY-MM-DD}.md`
- [ ] The six fixed sections (new proposed by source, closed active, stale active >14d, stale proposed >30d, top-3, urgent packets) are documented
- [ ] The mode documents "since the last briefing" as derived from the most recent prior file in `generated/briefings/`
- [ ] The weekly cadence is documented, with daily rejected and bi-weekly noted as the fallback lever
- [ ] The briefing is documented as read-only with respect to packets — `netrunner` summarizes, the human triages
- [ ] The `priority: urgent` out-of-band path via `generated/briefings/urgent.md` is documented
- [ ] The existing on-demand briefing modes are documented as unchanged
- [ ] The amendment cross-references ADR-0043 D1, D5, D6, D9

## Human Prerequisites
None. Pure Architecture-repo agent-definition edit.

## Dependencies
- `work-item:02` — the `generated/briefings/` directory (and `urgent.md`) must exist before `netrunner` is told to write the weekly briefing into it.
- `work-item:03` — the briefing reads packet `source` and `priority` frontmatter; that contract must be documented in `issue-authoring-rules.md` first.

## Referenced ADR Decisions

**ADR-0043 D1** — The weekly briefing is the one named triage surface, owned by `netrunner`, committed to `generated/briefings/{YYYY-MM-DD}.md`.
**ADR-0043 D5** — The weekly briefing is the single review surface; its six fixed sections; the human triages `proposed/` → `active/` from it. Bi-weekly is the fallback cadence lever.
**ADR-0043 D6** — `priority: urgent` reactive packets are surfaced out-of-band in `generated/briefings/urgent.md` and do not wait for the Monday briefing.
**ADR-0043 D9** — Daily briefings considered and rejected for a solo + agents shop; the weekly briefing begins Phase 2 / Week 3.
**ADR-0007** — `.claude/agents/` is the agent source of truth.

## Constraints
- **Additive mode.** The Weekly Briefing is a new mode; the existing on-demand `netrunner` briefing behaviour is unchanged.
- **Read-only with respect to packets.** `netrunner` summarizes the `proposed/` queue; it never promotes, edits, or deletes packets. Triage is the human's act at the briefing.
- The briefing's six sections are fixed by ADR-0043 D5 — do not add or drop sections.

## Labels
`docs`, `tier-2`, `meta`, `adr-0043`, `wave-2`

## Agent Handoff

**Objective:** Add a scheduled Weekly Briefing mode to `netrunner` that commits the ADR-0043 D5 triage report to `generated/briefings/`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Give the human a single weekly triage surface that drains the `proposed/` queue.
- Feature: ADR-0043 Continuous Backlog Generation rollout, Phase 2 (briefing begins Week 3).
- ADRs: ADR-0043 (D1/D5/D6/D9), ADR-0007 (agent source of truth).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` — `generated/briefings/` exists.
- `work-item:03` — `source`/`priority` frontmatter contract documented.

**Constraints:**
- Additive mode; existing on-demand briefing unchanged.
- Read-only with respect to packets.
- Six fixed sections per D5.

**Key Files:**
- `.claude/agents/netrunner.md`

**Contracts:** None changed.
