---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0043", "wave-1"]
dependencies: ["packet:01"]
adrs: ["ADR-0043", "ADR-0008"]
accepts: ["ADR-0043"]
wave: 1
initiative: adr-0043-continuous-backlog-generation
node: honeydrunk-architecture
---

# Amend issue-authoring-rules.md for the source/generator/priority frontmatter and the three-state lifecycle

## Summary
Amend `copilot/issue-authoring-rules.md` to require the new `source` and `generator` frontmatter fields on every packet, document the optional `priority` field, and document the three-state `proposed/` → `active/` → `completed/` packet lifecycle and naming conventions ADR-0043 D2/D3 introduce.

## Context
ADR-0043 D2 makes the issue packet the canonical output of every backlog source and adds two mandatory frontmatter fields: `source` (which backlog stream produced the packet) and `generator` (which agent authored it). D3 formalizes the three-state lifecycle with a new `proposed/` directory. D6 introduces a `priority: urgent` flag on reactive packets. `copilot/issue-authoring-rules.md` is the quality contract every packet-authoring agent (`scope`, and via this rollout the other sources) loads — it must carry these new requirements or the new fields will be inconsistently applied. ADR-0043's Follow-up Work explicitly lists "Amend `copilot/issue-authoring-rules.md` to require the `source` and `generator` frontmatter fields."

This is a docs-only packet. No code, no workflow, no .NET project.

## Scope
- `copilot/issue-authoring-rules.md` — add the new frontmatter fields and lifecycle documentation.

## Proposed Implementation
Amend `copilot/issue-authoring-rules.md` as follows.

**New mandatory frontmatter fields — FORWARD-ONLY.** Add `source` and `generator` to the frontmatter requirements (the file's "Quality Checks" list currently calls for `wave`, `initiative`, `node`, `adrs`, `tier`). The rule text must state explicitly that the requirement is **forward-only / non-retroactive**: it applies to packets authored *after ADR-0043 acceptance*. The ~25 sibling initiative folders already filed under `active/` were authored without these fields, are valid as-authored, and are **not** retroactively rewritten — invariant 24 (filed packets are immutable) governs them. The rule, like invariant 79, carries this carve-out in its own wording, not only as a note.

- `source` — one of `strategic` | `tactical` | `opportunistic` | `reactive`. Names which ADR-0043 backlog stream produced the packet. Required on every packet authored after ADR-0043 acceptance.
- `generator` — names who authored the packet. Required on every packet authored after ADR-0043 acceptance. Auditability of "who said this should be done."

**`generator` value convention — pinned, do not improvise.** Document this decisively in the file:
- **Human-authored packets** use the stable literal `generator: human`. Never use a GitHub handle — handles can change; the literal is stable and machine-comparable.
- **Agent-authored packets** use the agent's name: `generator: scope`, `generator: node-audit`, `generator: product-strategist`, `generator: hive-sync`, etc.
- For human-authored packets, `source` reflects the closest matching stream (typically `strategic` for ADR-driven work).

**Optional `priority` field — `urgent`-only.** Document `priority: urgent` as an optional frontmatter field carried by Reactive-source packets for high+ CVEs and production incidents (ADR-0043 D6). The field's **only valid value is `urgent`**; **absence of the field means normal priority**. Do not introduce `priority: normal` or `priority: high` — those values do not exist in the schema. State this explicitly so an execution agent does not invent them. `priority: urgent` packets are surfaced out-of-band in `generated/briefings/urgent.md`.

**Three-state lifecycle.** Add a short section documenting the `proposed/` → `active/` → `completed/` lifecycle from ADR-0043 D3:
- `proposed/` — agent-generated, awaiting human triage; not yet a GitHub issue; may be edited or deleted freely.
- `active/` — human-promoted, filed as a GitHub issue, in flight.
- `completed/` — closed in GitHub, moved here by `hive-sync`.
- State the load-bearing rule: agents never self-promote; the `proposed/` → `active/` transition is the only human-decision gate (invariant 78 from packet 01).
- State the structural enforcement: **`generated/issue-packets/proposed/` is deliberately outside the `file-packets.yml` path filter**, which watches only `generated/issue-packets/active/**`. Agent-generated packets in `proposed/` are therefore structurally incapable of auto-filing — they cannot become GitHub issues until a human moves them to `active/`. This makes the human gate a directory boundary, not merely an agent-discipline convention.

**Naming convention scope.** Note that the `{YYYY-MM-DD}-{repo}-{description}.md` packet-naming convention (already in the file) applies to `proposed/` packets too; the two-digit-prefix initiative-folder form applies once a multi-repo set is promoted to `active/`.

## Affected Files
- `copilot/issue-authoring-rules.md`

## NuGet Dependencies
None. This packet edits a Markdown rules file; no .NET project is created or modified.

## Boundary Check
- [x] `copilot/issue-authoring-rules.md` lives in `HoneyDrunk.Architecture`. Correct repo per routing.
- [x] No code change in any repo.
- [x] No agent-definition edit in this packet (agent amendments are packets 05–07).

## Acceptance Criteria
- [ ] `copilot/issue-authoring-rules.md` requires `source` (one of `strategic`/`tactical`/`opportunistic`/`reactive`) on every packet authored after ADR-0043 acceptance
- [ ] The file requires `generator` on every packet authored after ADR-0043 acceptance
- [ ] The `source`/`generator` rule text is explicitly forward-only — it states that existing already-filed packets are not retroactively rewritten (invariant 24)
- [ ] The file pins the `generator` convention: `generator: human` (stable literal, never a GitHub handle) for human-authored packets; the agent name for agent-authored packets
- [ ] The file documents `priority` as `urgent`-only, states that absence means normal priority, and states that `priority: normal`/`priority: high` are not valid values
- [ ] The file documents the optional `priority: urgent` field and its tie to `generated/briefings/urgent.md`
- [ ] The file documents the three-state `proposed/` → `active/` → `completed/` lifecycle and the human-only-promotion rule
- [ ] The file states that `proposed/` is outside the `file-packets.yml` `active/**` path filter, so `proposed/` packets cannot auto-file
- [ ] The Quality Checks frontmatter checklist line is updated to include `source` and `generator`
- [ ] The amendment cross-references ADR-0043 D2, D3, and D6

## Human Prerequisites
None. Pure Architecture-repo docs edit.

## Dependencies
- `packet:01` — ADR-0043 must be Accepted; this packet documents its D2/D3/D6 decisions as live rules. The human-only-promotion rule references invariant 78 added in packet 01.

## Referenced ADR Decisions

**ADR-0043 D2** — The packet is the canonical output of every source. New `source` field (`strategic`/`tactical`/`opportunistic`/`reactive`) and `generator` field (authoring agent) are mandatory frontmatter.
**ADR-0043 D3** — Three-state lifecycle `proposed/` → `active/` → `completed/`; agents never self-promote.
**ADR-0043 D6** — `priority: urgent` reactive packets (high+ CVE, production incident) are surfaced out-of-band in `generated/briefings/urgent.md`.
**ADR-0043 Follow-up Work** — "Amend `copilot/issue-authoring-rules.md` to require the `source` and `generator` frontmatter fields."

## Constraints
- Document, do not redesign. The packet body structure and existing frontmatter fields are unchanged; this adds three fields and one lifecycle section.
- **The `source`/`generator` requirement is forward-only.** The rule text itself must say it applies to packets authored after ADR-0043 acceptance. The ~25 sibling initiative folders already in `active/` were authored without these fields, are valid as-authored, and are never retroactively rewritten — invariant 24 (filed packets are immutable) governs them. Do not write a rule that is retroactively false the moment it lands.
- **`priority` is `urgent`-only.** The only valid value is `urgent`; absence means normal. Do not document or imply `priority: normal` or `priority: high`.
- **`generator` is a fixed convention.** `human` for human-authored packets (the stable literal, never a GitHub handle); the agent name for agent-authored packets. Do not leave this open for the execution agent to choose.

## Labels
`docs`, `tier-2`, `meta`, `adr-0043`, `wave-1`

## Agent Handoff

**Objective:** Add the `source`/`generator`/`priority` frontmatter fields and the three-state lifecycle to `copilot/issue-authoring-rules.md`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the new ADR-0043 packet contract a live quality rule every authoring agent loads.
- Feature: ADR-0043 Continuous Backlog Generation rollout, Phase 1.
- ADRs: ADR-0043 (D2/D3/D6), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — ADR-0043 Accepted.

**Constraints:**
- Document, do not redesign; fields are additive.
- The `source`/`generator` rule is forward-only — its text must carve out existing already-filed packets (invariant 24); do not write a retroactively-false rule.
- `priority` is `urgent`-only; absence means normal; no `normal`/`high` values.
- `generator` convention is pinned: `human` literal for humans, agent name for agents.

**Key Files:**
- `copilot/issue-authoring-rules.md`

**Contracts:** Packet frontmatter schema — adds `source` (required), `generator` (required), `priority` (optional).
