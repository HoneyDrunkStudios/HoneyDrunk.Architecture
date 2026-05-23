---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0043", "wave-2"]
dependencies: ["packet:02", "packet:03", "packet:04"]
adrs: ["ADR-0043", "ADR-0007"]
accepts: ["ADR-0043"]
wave: 2
initiative: adr-0043-continuous-backlog-generation
node: honeydrunk-architecture
---

# Amend the scope, node-audit, and product-strategist agents for the proposed/ output contract

## Summary
Amend three backlog-source agent definitions — `scope`, `node-audit`, `product-strategist` — so each produces packets into `generated/issue-packets/proposed/` with the mandatory `source` and `generator` frontmatter, and follows its per-source cadence and quality-control rules from ADR-0043 D4.

## Context
ADR-0043 D1 names four backlog sources; D8 states "each gains a documented scheduled invocation per D4. No prompt changes required at this ADR's acceptance" — but the agent *definitions* must document the new output contract so each source produces ADR-0043-compliant packets. `hive-sync` is handled in packet 05. This packet handles the other three source-owning agents:

- `scope` — owns the **Strategic** source. Currently writes packets into `generated/issue-packets/active/`. Must learn that source-triggered (agent-cadence) scope passes write to `proposed/`.
- `node-audit` — feeds the **Tactical** source. Currently a read-only agent that recommends handoffs. Must learn to commit its audit report to `generated/audits/` and route findings to `scope` for `proposed/` packets.
- `product-strategist` — owns the **Opportunistic** source. Scout mode must learn to write to `generated/scout-reports/` and route product-level findings to `pdr-composer` and in-scope findings to `proposed/` packets.

`netrunner`'s weekly-briefing role is packet 07; this packet covers the three packet-*producing* source agents.

This is an agent-definition (Markdown) packet. No code, no workflow, no .NET project. `.claude/agents/` is the agent source of truth per ADR-0007.

## Scope
- `.claude/agents/scope.md`
- `.claude/agents/node-audit.md`
- `.claude/agents/product-strategist.md`

## Proposed Implementation

### `scope.md` — Strategic source
- **`active/` is the default; `proposed/` requires an explicit Strategic-source signal.** The agent definition must state the routing rule unambiguously: `scope` writes to `generated/issue-packets/active/` **by default and whenever the invocation mode is ambiguous**. Writing to `generated/issue-packets/proposed/` happens **only** when `scope` is invoked with an explicit agent-cadence Strategic-source signal (e.g. downstream of a `hive-sync`-detected ADR/PDR acceptance trigger, on the ADR-0043 cadence). If `scope` cannot positively confirm it is running as the Strategic source, it writes to `active/`.
- Rationale to state in the definition: the 11 concurrent sibling ADR initiatives are scoped by operator-directed `scope` runs and **must** land in `active/` so `file-packets.yml` files them. A `proposed/` default would silently strand them (`file-packets.yml` does not scan `proposed/`). Defaulting to `active/` makes misrouting fail safe.
- The distinction the agent definition must make explicit: **operator-directed runs and ambiguous-mode runs → `active/` (default); agent-cadence Strategic-source runs, only when explicitly signalled → `proposed/`.**
- Every Strategic-source packet carries `source: strategic` and `generator: scope` frontmatter (per packet 03's `issue-authoring-rules.md`).
- For operator-directed (human-initiated) scope passes, packets carry `generator: human` (the stable literal — never a GitHub handle) if the human is authoring directly, or `generator: scope` if `scope` itself authors them on the operator's instruction. Pin this in the definition; do not leave it open.
- Document the D4 Strategic quality control: when a decision implies more than 3 packets, `scope` produces a dispatch plan and a `refine` pass runs against the dispatch plan before packets land in `proposed/`.

### `node-audit.md` — Tactical source
- `node-audit` stays read-only with respect to code, but document that its audit report is now **committed** to `generated/audits/{node}-{YYYY-MM-DD}.md` as the audit trail — even when no packets graduate (ADR-0043 D4 Tactical: "we looked at this Node and chose not to act" is information).
- Document the handoff: `node-audit` findings the operator elects to act on are handed to `scope`, which writes them into `proposed/` as `source: tactical`, `generator: node-audit` — `generator` names the originating source agent (`node-audit`), since it is the agent that found the work. This is pinned, not left to the execution agent.
- Reference `initiatives/audit-rotation.md` (packet 04) as the schedule that selects which Node `node-audit` runs against each week.
- Preserve the existing read-only constraint — `node-audit` does not itself write packets; it writes its report to `generated/audits/` and hands findings to `scope`.

### `product-strategist.md` — Opportunistic source
- Document the monthly Scout-mode cadence as the Opportunistic backlog source.
- Scout output: ranked opportunities. High-ranked items become PDR drafts via `pdr-composer` (feeding back into the Strategic source on acceptance). Lower-ranked in-scope items become `source: opportunistic`, `generator: product-strategist` packets in `proposed/`. The remainder are filed in `generated/scout-reports/{YYYY-MM-DD}.md` for future re-evaluation.
- Document the D4 Opportunistic quality control: Scout output explicitly includes a "kill" / "build nothing right now" recommendation when warranted — the agent already carries this stance; the amendment makes the surfacing of it an ADR-0043 requirement.

### Common
- Each agent definition states the load-bearing discipline: agent-cadence-generated packets land in `proposed/`, never `active/`; the human is the only `proposed/` → `active/` authority (invariant 78 from packet 01). The one exception, stated above for `scope`: operator-directed and ambiguous-mode runs default to `active/` — `proposed/` requires an explicit Strategic-source signal.
- **`generator` convention (pinned across all three agents):** `generator: human` (the stable literal, never a GitHub handle) for human-authored packets; the agent name (`generator: scope`, `generator: node-audit`, `generator: product-strategist`) for agent-authored packets.

## Affected Files
- `.claude/agents/scope.md`
- `.claude/agents/node-audit.md`
- `.claude/agents/product-strategist.md`

## NuGet Dependencies
None. This packet edits Markdown agent-definition files; no .NET project is created or modified.

## Boundary Check
- [x] `.claude/agents/` is the single source of truth for agent definitions (ADR-0007); lives in `HoneyDrunk.Architecture`. Correct repo.
- [x] No code change in any repo.
- [x] `scope`'s existing operator-directed `active/` behaviour is preserved; only agent-cadence runs change to `proposed/`.

## Acceptance Criteria
- [ ] `scope.md` states unambiguously that `active/` is the default — operator-directed runs AND ambiguous-mode runs write to `active/`; only an explicit agent-cadence Strategic-source signal routes to `proposed/`
- [ ] `scope.md` records the rationale: a `proposed/` default would silently strand the concurrent sibling ADR initiatives, which `file-packets.yml` does not scan in `proposed/`
- [ ] `scope.md` documents the `source: strategic` / `generator: scope` frontmatter and the >3-packet → dispatch-plan + `refine` quality control
- [ ] All three agent definitions pin the `generator` convention: `human` literal for human-authored, agent name for agent-authored
- [ ] `node-audit.md` documents that the audit report is committed to `generated/audits/{node}-{YYYY-MM-DD}.md` even when no packets graduate
- [ ] `node-audit.md` documents the handoff to `scope` for `proposed/` packets and references `initiatives/audit-rotation.md` as its schedule
- [ ] `product-strategist.md` documents the monthly Scout cadence, the PDR-vs-packet-vs-scout-report routing, and the `source: opportunistic` / `generator: product-strategist` frontmatter
- [ ] `product-strategist.md` documents the "kill / build nothing" recommendation as an ADR-0043 D4 quality control
- [ ] All three agent definitions state the human-only `proposed/` → `active/` promotion rule
- [ ] Each amendment cross-references the relevant ADR-0043 D4 source section
- [ ] Invariant 33 honored: if any context-loading section in `scope.md` changes, the mirror in `review.md` is updated in the same PR (see Constraints)

## Human Prerequisites
None. Pure Architecture-repo agent-definition edits.

## Dependencies
- `packet:02` — the `generated/issue-packets/proposed/`, `generated/audits/`, and `generated/scout-reports/` directories must exist before agents are told to write into them.
- `packet:03` — the `source`/`generator` frontmatter contract must be documented in `issue-authoring-rules.md` first.
- `packet:04` — `node-audit.md` references `initiatives/audit-rotation.md`, which packet 04 authors.

## Referenced ADR Decisions

**ADR-0043 D1** — Four sources: Strategic (`scope`), Tactical (`node-audit` → `scope`), Opportunistic (`product-strategist` → `pdr-composer`), Reactive (`hive-sync`/`scope`).
**ADR-0043 D4 Strategic** — `scope` produces a dispatch plan when >3 packets are implied; `refine` runs against it before packets land in `proposed/`.
**ADR-0043 D4 Tactical** — `node-audit` output always triaged to `proposed/`; audit report committed to `generated/audits/{node}-{YYYY-MM-DD}.md` even when no packets graduate.
**ADR-0043 D4 Opportunistic** — Monthly Scout pass; ranked output; high → PDR draft, low in-scope → `proposed/` packet, remainder → `generated/scout-reports/`; explicit "kill" recommendation when warranted.
**ADR-0043 D8** — Each agent gains a documented scheduled invocation; "no prompt changes required at acceptance" — this packet documents the output contract, which is the minimal compliant amendment.
**ADR-0007** — `.claude/agents/` is the agent source of truth.

## Constraints
- **`active/` is the fail-safe default.** `scope` writes to `active/` for operator-directed runs and whenever the invocation mode is ambiguous. Routing to `proposed/` requires an explicit, positively-confirmed agent-cadence Strategic-source signal. This protects the 11 concurrent sibling ADR initiatives from being silently stranded in `proposed/`, which `file-packets.yml` does not scan.
- **Preserve `scope`'s operator-directed behaviour.** A human directly invoking `scope` to file an initiative still uses `active/` exactly as today.
- **`node-audit` stays read-only with respect to code.** It writes its report to `generated/audits/` and hands findings to `scope`; it does not author packets itself.
- **Invariant 33 — review/scope context coupling.** "The set of files loaded by the review agent must be a superset of the set loaded by the scope agent. Updates to either agent's context-loading section must be mirrored in the other." If this packet's `scope.md` edit does not touch the context-loading list, no `review.md` change is needed; if it does, mirror it in `review.md` in the same PR.

## Labels
`docs`, `tier-2`, `meta`, `adr-0043`, `wave-2`

## Agent Handoff

**Objective:** Amend `scope`, `node-audit`, and `product-strategist` to produce ADR-0043-compliant `proposed/` output with `source`/`generator` frontmatter and per-source quality controls.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the three packet-producing source agents emit packets per the ADR-0043 contract.
- Feature: ADR-0043 Continuous Backlog Generation rollout, Phase 1/2.
- ADRs: ADR-0043 (D1/D4/D8), ADR-0007 (agent source of truth).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — directories exist.
- `packet:03` — frontmatter contract documented.
- `packet:04` — `audit-rotation.md` exists.

**Constraints:**
- `active/` is the fail-safe default for `scope`; `proposed/` requires an explicit Strategic-source signal. Ambiguous mode → `active/`.
- Preserve `scope`'s operator-directed `active/` behaviour.
- `node-audit` stays code-read-only.
- `generator` pinned: `human` literal for humans, agent name for agents.
- Honor invariant 33 — mirror any `scope.md` context-loading change into `review.md`.

**Key Files:**
- `.claude/agents/scope.md`
- `.claude/agents/node-audit.md`
- `.claude/agents/product-strategist.md`
- `.claude/agents/review.md` (only if `scope.md`'s context-loading list changes)

**Contracts:** None changed.
