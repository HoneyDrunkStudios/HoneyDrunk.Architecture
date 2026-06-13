---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0088", "wave-4"]
dependencies: ["work-item:01", "work-item:02"]
adrs: ["ADR-0088", "ADR-0007", "ADR-0082"]
accepts: []
wave: 4
initiative: adr-0088-openclaw-decommission
node: honeydrunk-architecture
---

# Retire the ADR-0007 Operational Addendum (OpenClaw-skills-mirroring rule) + its node-standup and agent-skills-map wirings

## Summary
The ADR-0007 "Operational Addendum: OpenClaw Skills" is a **binding companion-skill rule** — "any newly added Architecture agent must also be mirrored by an OpenClaw skill when the behavior is expected to be reusable from OpenClaw" — and it is wired into two live governance surfaces:

- `constitution/node-standup.md` step 15 (~line 112): "`.github/copilot-instructions.md` … **Mirrored to OpenClaw skills per ADR-0007's Operational Addendum** when applicable."
- `copilot/agent-skills-map.md`: the "OpenClaw skill" inventory column (lines ~76–88), the surrounding OpenClaw-surface prose (line ~70, ~74), and the entire "OpenClaw Skill Pairing Rule" section (lines ~90–102).

The addendum also references the `infrastructure/openclaw/` directory (addendum step 5: "in-repo operational runbooks or scheduled-work contracts may live under `infrastructure/openclaw/`") — the directory **packet 01 deletes**. Once OpenClaw is decommissioned, this rule is dead but still binding-by-text: an agent reading node-standup step 15 today would try to mirror a new agent into a runtime that no longer exists. This packet **retires/annotates** the rule across all three surfaces so the governance text stops mandating OpenClaw-skill pairing.

## Context
This finding is not in ADR-0088 D3's original 12-step group list — it surfaced in the refine pass as a **live orphan**: a binding rule the decommission strands. It belongs to ADR-0088's intent (D1: "OpenClaw is fully retired as a Grid substrate") and is the natural completion of the governance cleanup. ADR-0007 itself is **not superseded** — its core decision ("`.claude/agents/*.md` is the source of truth for Claude Code and Copilot agent definitions") survives intact and is untouched. Only its **Operational Addendum** (a companion-skill maintenance rule, explicitly scoped to OpenClaw) is retired, because the runtime it served is gone.

The rule is honest to retire once the OpenClaw **runtime** is torn down (packet 02) and the `infrastructure/openclaw/` directory it points at is removed (packet 01). Hence this packet depends on packets 01 and 02, not on the secret deletion (packet 03) — the rule is about the runtime/skills surface, not the webhook secret. It runs in Wave 4 alongside the other governance-currency cleanup.

This is a docs/governance-only packet. `Actor=Agent`. No code, no workflow, no secret, no .NET project.

## Scope
- `adrs/ADR-0007-claude-agents-as-source-of-truth.md` — the "Operational Addendum: OpenClaw Skills" section (lines ~65–79). **Retire/annotate** it: mark the addendum as retired per ADR-0088 (OpenClaw is decommissioned; the companion-skill rule no longer applies), with a forward pointer to ADR-0088. Preserve ADR-0007's core decision and the rest of the ADR untouched. Recommended posture (Decision Point below): keep the section heading as a historical marker with a one-paragraph "Retired per ADR-0088" annotation, rather than deleting the narrative wholesale — an ADR is partly a historical record.
- `constitution/node-standup.md` step 15 (~line 112) — remove the clause "**Mirrored to OpenClaw skills per ADR-0007's Operational Addendum** when applicable." so the step reads as the plain `.github/copilot-instructions.md` requirement with no dead OpenClaw-mirroring mandate. The rest of step 15 (the per-repo copilot-instructions file pointing back to Architecture's) is unchanged.
- `copilot/agent-skills-map.md`:
  - Line ~70 — the "OpenClaw is an operator/runtime surface…" paragraph. Retire/annotate (OpenClaw is decommissioned per ADR-0088).
  - Line ~74 — the inventory-table preamble naming "OpenClaw skill names" / the OpenClaw workspace `skills/` directory. Reconcile.
  - Lines ~76–88 — the **"OpenClaw skill" table column** listing `honeydrunk-adr-composer`, `honeydrunk-scope`, etc. Remove the column (the companion skills no longer exist as a runtime), or annotate the table as retired-pairing. Default: remove the OpenClaw-skill column, keeping the agent inventory (Agent / Purpose / Invokes) intact — the inventory itself is still useful; only the OpenClaw pairing column is dead.
  - Lines ~90–102 — the "OpenClaw Skill Pairing Rule" section. Remove or annotate as retired per ADR-0088.

## Decision Point — annotate vs. delete
ADR-0007 is an *accepted* ADR; the documentation-currency convention favors **annotating with a forward pointer to ADR-0088** over wholesale deletion of the addendum narrative (historical record). For `node-standup.md` and `agent-skills-map.md` — which are **operational governance**, not historical ADRs — the bias is toward **removing the dead mandate/column** outright, because a contributor reads these as live instructions and a stale "mirror to OpenClaw" rule actively misdirects. Firm requirement: after this packet, **no governance surface mandates or implies a live OpenClaw-skill pairing**, and node-standup step 15 carries no OpenClaw-mirroring clause. Whether the ADR-0007 addendum is annotated-in-place or removed is the operator's call; the node-standup clause and the agent-skills-map pairing rule/column should be removed.

## Proposed Implementation
1. Retire/annotate the ADR-0007 "Operational Addendum: OpenClaw Skills" section (lines ~65–79) with a "Retired per ADR-0088 (2026-05-30)" note and a forward pointer; leave ADR-0007's core decision untouched.
2. Remove the "Mirrored to OpenClaw skills per ADR-0007's Operational Addendum when applicable." clause from `constitution/node-standup.md` step 15.
3. In `copilot/agent-skills-map.md`: remove the OpenClaw-skill inventory column (keep Agent / Purpose / Invokes), retire the OpenClaw-surface prose (line ~70, ~74), and remove/annotate the "OpenClaw Skill Pairing Rule" section.
4. Grep the repo for any other live reference to "OpenClaw skill", "Operational Addendum", or "skills-mirroring" and reconcile dead mandates (do NOT edit ADR-0082's line ~98 skills-mirroring reference if it is a pure historical citation — but if it asserts a live pairing requirement, past-tense it; coordinate with packet 05 which owns ADR-0082).
5. Confirm no dead link to the removed `infrastructure/openclaw/` directory remains in the addendum text (the directory is removed in packet 01).
6. Update `CHANGELOG.md`, noting the ADR-0007 Operational Addendum retirement and the node-standup / agent-skills-map cleanup.

## Affected Files
- `adrs/ADR-0007-claude-agents-as-source-of-truth.md` (Operational Addendum section, lines ~65–79)
- `constitution/node-standup.md` (step 15, ~line 112)
- `copilot/agent-skills-map.md` (lines ~70, ~74, ~76–88, ~90–102)
- `CHANGELOG.md`

## NuGet Dependencies
None. Markdown/governance edits only; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any repo.
- [x] **ADR-0007's core decision is NOT changed** — only its OpenClaw-specific Operational Addendum is retired. ADR-0007 is not superseded.
- [x] `constitution/invariants.md` is NOT edited (ADR-0088 D6).
- [x] ADR-0044 / ADR-0079 are NOT edited (ADR-0088 D2).
- [x] **Depends on packets 01 + 02** — the rule is honest to retire once the OpenClaw runtime is torn down (02) and the `infrastructure/openclaw/` directory it cites is removed (01). Not gated on the secret (packet 03).
- [x] Coordinates with packet 05 on ADR-0082 (line ~98 skills-mirroring reference) — this packet does not edit ADR-0082; packet 05 owns it.

## Acceptance Criteria
- [ ] The ADR-0007 "Operational Addendum: OpenClaw Skills" section is retired/annotated as superseded-by-decommission per ADR-0088, with a forward pointer; ADR-0007's core decision is unchanged and the ADR is NOT marked Superseded
- [ ] `constitution/node-standup.md` step 15 no longer contains the "Mirrored to OpenClaw skills per ADR-0007's Operational Addendum" clause; the rest of step 15 is unchanged
- [ ] `copilot/agent-skills-map.md`: the OpenClaw-skill inventory column is removed (Agent / Purpose / Invokes retained), the OpenClaw-surface prose (line ~70, ~74) is retired/annotated, and the "OpenClaw Skill Pairing Rule" section is removed or annotated as retired per ADR-0088
- [ ] No governance surface mandates or implies a live OpenClaw-skill pairing after this packet (verified by grep for `OpenClaw skill` / `Operational Addendum` / `skills-mirroring`)
- [ ] No dead link to the removed `infrastructure/openclaw/` directory remains in the ADR-0007 addendum text
- [ ] `constitution/invariants.md` is unchanged
- [ ] ADR-0044 / ADR-0079 are unchanged; ADR-0082 is not edited here (packet 05 owns its skills-mirroring reference)
- [ ] CHANGELOG.md records the ADR-0007 Operational Addendum retirement + the node-standup / agent-skills-map cleanup

## Human Prerequisites
None. Pure docs/governance work delegable end-to-end to the agent. (It does require packets 01 + 02 to have landed/the runtime to be gone — that is a `dependencies:` gate, not a human prerequisite.)

## Dependencies
- `work-item:01` — the `infrastructure/openclaw/` directory removal (the addendum cites that directory; retiring the rule after the directory is gone keeps the text honest).
- `work-item:02` — the OpenClaw runtime teardown (the companion-skill rule is honest to retire once the OpenClaw runtime it served no longer exists).

## Referenced ADR Decisions
**ADR-0088 D1 — OpenClaw is fully retired as a Grid substrate.** The companion-skill mirroring rule served the OpenClaw runtime; with that runtime gone, the rule is a live orphan and is retired.

**ADR-0007 (core decision retained) — `.claude/agents/*.md` is the source of truth for Claude Code and Copilot agent definitions.** This decision is untouched. Only the OpenClaw-specific Operational Addendum (a companion-skill maintenance rule) is retired. ADR-0007 is NOT superseded.

**ADR-0088 D6 — No new invariants.** `constitution/invariants.md` is not edited.

**ADR-0088 D2 — Do not re-supersede ADR-0044 / ADR-0079.** Those ADRs are not edited.

## Constraints
- **Retire the addendum, not ADR-0007.** ADR-0007's core decision survives; the ADR stays Accepted. Only the OpenClaw Operational Addendum is retired/annotated.
- **Remove the dead mandate from operational governance.** node-standup step 15 and the agent-skills-map pairing rule are live instructions; a stale "mirror to OpenClaw" clause misdirects contributors. Remove it, do not merely soften it.
- **Keep the agent inventory.** In `agent-skills-map.md`, only the OpenClaw-skill column and the pairing rule are dead; the Agent / Purpose / Invokes inventory is still useful and stays.
- **Do not edit ADR-0082 here.** Its line ~98 skills-mirroring reference is packet 05's concern; coordinate, do not overlap.
- **Do not edit `constitution/invariants.md`** (ADR-0088 D6), ADR-0044, or ADR-0079 (ADR-0088 D2).

## Labels
`chore`, `tier-2`, `meta`, `docs`, `adr-0088`, `wave-4`

## Agent Handoff

**Objective:** Retire the ADR-0007 "Operational Addendum: OpenClaw Skills" companion-skill rule and remove its live wirings in `constitution/node-standup.md` step 15 and `copilot/agent-skills-map.md` (OpenClaw-skill column + pairing-rule section), so no governance surface mandates OpenClaw-skill pairing for a decommissioned runtime. Leave ADR-0007's core decision intact.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Close the live orphan the OpenClaw decommission strands — the ADR-0007 addendum's binding companion-skill rule and its node-standup / agent-skills-map wirings.
- Feature: ADR-0088 OpenClaw decommission, Wave 4 (governance cleanup beyond D3's original 12 steps; surfaced in the refine pass).
- ADRs: ADR-0088 (primary, D1 intent), ADR-0007 (addendum retired, core decision retained), ADR-0082 (coordinated — packet 05 owns its skills-mirroring reference).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — `infrastructure/openclaw/` directory removal (the addendum cites it).
- `work-item:02` — OpenClaw runtime teardown (the rule served that runtime).

**Constraints:**
- Retire the addendum, not ADR-0007 — its core decision and Accepted status survive.
- Remove the dead mandate from node-standup step 15 and the agent-skills-map pairing rule (operational governance — do not merely soften).
- Keep the Agent / Purpose / Invokes inventory in agent-skills-map; only the OpenClaw-skill column + pairing rule are removed.
- Do not edit ADR-0082 (packet 05), `constitution/invariants.md`, ADR-0044, or ADR-0079.

**Key Files:**
- `adrs/ADR-0007-claude-agents-as-source-of-truth.md` (lines ~65–79)
- `constitution/node-standup.md` (step 15, ~line 112)
- `copilot/agent-skills-map.md` (lines ~70, ~74, ~76–88, ~90–102)
- `CHANGELOG.md`

**Contracts:** None.
