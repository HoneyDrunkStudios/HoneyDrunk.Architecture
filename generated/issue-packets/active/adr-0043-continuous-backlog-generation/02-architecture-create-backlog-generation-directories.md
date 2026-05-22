---
name: Architecture Decision
type: architecture-decision
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "docs", "adr-0043", "wave-1"]
dependencies: ["packet:01"]
adrs: ["ADR-0043", "ADR-0008"]
accepts: ["ADR-0043"]
wave: 1
initiative: adr-0043-continuous-backlog-generation
node: honeydrunk-architecture
---

# Create the four new backlog-generation directories with READMEs

## Summary
Create the four new generated directories ADR-0043 calls for — `generated/issue-packets/proposed/`, `generated/audits/`, `generated/scout-reports/`, `generated/briefings/` — each seeded with a `README.md` describing its purpose, contents, and lifecycle.

## Context
ADR-0043 D3 formalizes a three-state packet lifecycle. The `active/` and `completed/` packet directories already exist; the new `proposed/` directory is the agent-generated triage queue. Three other generated directories hold the audit-trail outputs of the Tactical and Opportunistic sources and the weekly-briefing triage surface. ADR-0043's Follow-up Work section lists "Create the new directories" as the first concrete task. Directories cannot be committed empty to git, so each gets a README that doubles as its documentation.

This is a docs/scaffolding-only packet. No code, no workflow, no .NET project.

## Scope
Create these four directories, each with a `README.md`:

- `generated/issue-packets/proposed/` — agent-generated packets awaiting human triage. Not yet GitHub issues. May be edited or deleted without ceremony. The human's queue. Per ADR-0043 D3.
- `generated/audits/` — `node-audit` reports from the Tactical source, named `{node}-{YYYY-MM-DD}.md`. Committed for the audit trail even when no packets graduate. Per ADR-0043 D4 Tactical.
- `generated/scout-reports/` — `product-strategist` Scout-mode reports from the Opportunistic source, named `{YYYY-MM-DD}.md`. Holds lower-ranked opportunities filed for future re-evaluation. Per ADR-0043 D4 Opportunistic.
- `generated/briefings/` — `netrunner` weekly triage briefings, named `{YYYY-MM-DD}.md`, plus the rolling out-of-band file `urgent.md` for `priority: urgent` reactive packets. Per ADR-0043 D5, D6.

## Proposed Implementation
Each `README.md` states: the directory's purpose, what files land there and their naming convention, which agent writes to it, the lifecycle rules, and a cross-reference to ADR-0043's governing decision.

**`generated/issue-packets/proposed/README.md`** must additionally state the load-bearing discipline: agents write here, never to `active/`; the `proposed/` → `active/` transition is a human-only decision (invariant 78 from packet 01); `proposed/` is allowed to accumulate; stale packets older than 30 days are surfaced in the weekly briefing for "promote, refine, or drop" triage and are never auto-archived.

The README must also state explicitly: **`generated/issue-packets/proposed/` is deliberately OUTSIDE the `file-packets.yml` path filter.** That workflow triggers only on `generated/issue-packets/active/**/*.md`. Packets sitting in `proposed/` are therefore *structurally incapable* of auto-filing — they cannot become GitHub issues until a human moves them into `active/`. This is the backward-compatibility and human-gate guarantee made concrete: the directory boundary, not agent discipline alone, enforces it.

**`generated/briefings/README.md`** must document both the dated weekly briefing files and the rolling `urgent.md` file, and note that `urgent.md` is the out-of-band surface for `priority: urgent` reactive packets per ADR-0043 D6.

Naming conventions to record verbatim in the relevant READMEs:
- `proposed/` packets: `{YYYY-MM-DD}-{repo}-{description}.md` per ADR-0008 D10.
- `audits/`: `{node}-{YYYY-MM-DD}.md`.
- `scout-reports/`: `{YYYY-MM-DD}.md`.
- `briefings/`: `{YYYY-MM-DD}.md` plus the fixed-name `urgent.md`.

## Affected Files
- `generated/issue-packets/proposed/README.md` (new)
- `generated/audits/README.md` (new)
- `generated/scout-reports/README.md` (new)
- `generated/briefings/README.md` (new)

## NuGet Dependencies
None. This packet creates Markdown documentation files only; no .NET project is created or modified.

## Boundary Check
- [x] All directories under `HoneyDrunk.Architecture/generated/`. Correct repo per routing.
- [x] No code change in any repo.
- [x] No catalog or invariant change (those are in packet 01).

## Acceptance Criteria
- [ ] `generated/issue-packets/proposed/` exists with a `README.md` documenting purpose, naming, lifecycle, and the human-only-promotion discipline
- [ ] The `proposed/README.md` explicitly states that `proposed/` is outside the `file-packets.yml` path filter (`active/**` only), so packets there cannot auto-file
- [ ] `generated/audits/` exists with a `README.md` documenting purpose and the `{node}-{YYYY-MM-DD}.md` naming
- [ ] `generated/scout-reports/` exists with a `README.md` documenting purpose and the `{YYYY-MM-DD}.md` naming
- [ ] `generated/briefings/` exists with a `README.md` documenting the dated weekly briefing files and the rolling `urgent.md` file
- [ ] Each README cross-references the relevant ADR-0043 decision (D3 / D4 / D5 / D6)
- [ ] No packet files are placed in `proposed/` in this packet — the directory ships with only its README (packet 08 seeds the first packets)

## Human Prerequisites
None. Pure Architecture-repo scaffolding.

## Dependencies
- `packet:01` — ADR-0043 must be Accepted so these directories are created against live decisions, not a Proposed ADR.

## Referenced ADR Decisions

**ADR-0043 D3** — Three-state lifecycle: `proposed/` (agent-generated, awaiting triage) → `active/` (human-promoted) → `completed/`. `proposed/` accumulates; stale entries surface in the weekly briefing; never auto-archived.
**ADR-0043 D4** — Tactical audit reports go to `generated/audits/{node}-{YYYY-MM-DD}.md` even when no packets graduate; Opportunistic lower-ranked items go to `generated/scout-reports/{YYYY-MM-DD}.md`.
**ADR-0043 D5/D6** — The weekly briefing is committed to `generated/briefings/{YYYY-MM-DD}.md`; `priority: urgent` reactive packets are additionally surfaced in the rolling `generated/briefings/urgent.md`.
**ADR-0043 Follow-up Work** — "Create the new directories: `generated/issue-packets/proposed/`, `generated/audits/`, `generated/scout-reports/`, `generated/briefings/`."

## Constraints
- Directories must contain a `README.md` so git tracks them — never commit a bare `.gitkeep` where a documented README belongs.
- Do not place any packet files in `proposed/` in this packet; it ships with only its README.

## Labels
`chore`, `tier-1`, `meta`, `docs`, `adr-0043`, `wave-1`

## Agent Handoff

**Objective:** Create the four ADR-0043 generated directories, each with a documenting README.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Provide the on-disk surfaces the four backlog sources and the briefing write to.
- Feature: ADR-0043 Continuous Backlog Generation rollout, Phase 1.
- ADRs: ADR-0043 (D3/D4/D5/D6), ADR-0008 (packet naming).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — ADR-0043 Accepted.

**Constraints:**
- README per directory; no bare `.gitkeep`.
- No packet files placed in `proposed/`.

**Key Files:**
- `generated/issue-packets/proposed/README.md`
- `generated/audits/README.md`
- `generated/scout-reports/README.md`
- `generated/briefings/README.md`

**Contracts:** None.
