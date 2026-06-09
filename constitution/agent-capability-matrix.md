# Agent Capability Matrix

Quick-reference card for all Claude Code agents in `.claude/agents/`. Use this to self-route before loading individual agent definitions.

## The Agents

| Agent | Trigger | Consumes | Produces | Does NOT do |
|-------|---------|----------|----------|-------------|
| **scope** | New work to decompose | Goal/user request, ADRs, catalogs, repo boundaries | Issue packets, dispatch plan, handoff | Execute work, write code, open PRs |
| **adr-composer** | New architectural decision needed | Context, existing ADRs for precedent | ADR draft in `generated/adr-drafts/` | Accept/reject decisions, file issues |
| **pdr-composer** | New product decision needed | Context, existing PDRs for precedent | PDR draft in `generated/pdr-drafts/` | Scope follow-up work, file issues |
| **netrunner** | "What's next?" briefing, cross-repo discovery, or weekly focus review | Keyword/goal, `catalogs/relationships.json`, `catalogs/nodes.json`, `routing/repo-discovery-rules.md`, `initiatives/current-focus.md`, `initiatives/active-initiatives.md`, `initiatives/roadmap.md`, `initiatives/proposed-adrs.md` | Ad-hoc briefing (verbal), and — in curator mode — updates to `initiatives/current-focus.md` (sole writer), plus the **narrative/ordering columns** of `initiatives/active-initiatives.md` (initiative ordering, descriptions, current-focus cross-refs) and `initiatives/roadmap.md` (item ordering within quarters, quarter promotion/demotion, current-focus annotations) | Touch hive-sync's columns on the shared files (`[x]` checkboxes, `**Status:**` fields, `> **Sync (date):**` blocks, closure annotations), edit any other file, generate packets, file issues, mutate The Hive board, make architectural decisions |
| **file-issues** | Packets ready to file as GitHub Issues | Issue packets from `generated/issue-packets/active/` | GitHub Issues in target repos (via gh CLI) | Edit packets post-filing, make decisions |
| **review** | PR opened or execution completed | PR diff, issue packet, ADR constraints | Review comments, pass/fail verdict | Merge, approve in GitHub UI |
| **node-audit** | Whole-Node health check (not a PR diff) | Node name, catalogs, `repos/{node}/*`, governing ADRs, repo code on disk | Findings report — verdict, blocking/changes/suggest, handoff recommendations | Edit files, file issues, open PRs, decide |
| **refine** | Draft exists, needs iteration | Draft doc (ADR, PDR, packet, design), feedback | Revised draft | Author from scratch, make binding decisions |
| **site-sync** | Repo release or content update | Release notes, ADRs, repo state | Site-sync packet in `generated/site-sync-packets/` | Publish to website directly |
| **hive-sync** | ADR-0086 runner schedule/manual dispatch | `gh` CLI issue states, `generated/issue-packets/filed-packets.json`, GraphQL Hive board state, all `catalogs/*.json`, `adrs/ADR-*.md` frontmatter, initiative files | Updated `initiatives/` files via PR (new branch per run), packet moves (active -> completed), `board-items.md`, `initiatives/proposed-adrs.md`, `initiatives/archived-initiatives.md`, `initiatives/drift-report.md`, **mechanical columns** on shared `initiatives/active-initiatives.md` (checkboxes, `**Status:**`, `> **Sync (date):**` blocks) and `initiatives/roadmap.md` (checkboxes, closure annotations), **catalog reconciliation** (`compatibility.json` `currentVersion` + `lastUpdated`, `modules.json` `version`, `services.json` `status` - derived from `grid-health.json`) | Edit `initiatives/current-focus.md` (netrunner owns it), touch netrunner's columns on shared files (initiative ordering, narrative descriptions, current-focus cross-refs, item ordering within quarters), edit `grid-health.json` / `nodes.json` / `relationships.json` / `contracts.json` / `signals.json` / `flow_config.json` / `flow_tiers.json`, auto-add catalog rows, create issues, make architectural decisions |
| **docs-sync** | ADR-0086 runner Friday schedule/manual dispatch | Grid repo Markdown docs, target repo code symbols, `catalogs/*.json`, ADR index, per-repo agent instructions | Per-run report under `generated/docs-sync-reports/`, and bounded PRs for mechanical documentation drift when write mode is enabled | Invent code behavior, execute examples, rewrite editorial prose without human review, create docs for seed/scaffold repos that do not yet have an actionable docs surface |

> **Status:** `hive-sync` is rolling out across ADR-0014 packets 01-06. The packet-lifecycle (active → completed), `board-items.md`, `initiatives/proposed-adrs.md`, ADR/PDR auto-acceptance, README index sync, and `initiatives/drift-report.md` surfaces become live as Packets 02-06 land.

---

## Loop-owning agents (ADR-0093)

Several of these agents are the **synthesizer** of a registered loop — they are the
behavior the loop invokes on each iteration. The loop is the first-class artifact (the
Loop Definition Record in `loops/`); the agent is one part of its anatomy. See
[`loop-engineering.md`](loop-engineering.md) and the [`loops/`](../loops/) registry.

| Loop | LDR | Synthesizer agent(s) | Tier |
|------|-----|----------------------|------|
| Hive reconciliation | `loop-0001-hive-sync` | `hive-sync` | A |
| Backlog — Strategic | `loop-0002-backlog-strategic` | `scope` | A |
| Backlog — Tactical | `loop-0003-backlog-tactical` | `node-audit` → `scope` | A |
| Backlog — Opportunistic | `loop-0004-backlog-opportunistic` | `product-strategist` → `pdr-composer` | A |
| Backlog — Reactive | `loop-0005-backlog-reactive` | `hive-sync` / `scope` | A |
| PR-activity autofix | `loop-0006-pr-activity-autofix` | session agent (build loop) | A |

**Authorship gate (`[Firm]`):** an agent may *propose* a new loop into `loops/proposed/`;
**only a human promotes** an LDR into `loops/`. No agent self-promotes a loop into
existence — the same discipline `scope` follows for packets (`proposed/` → `active/`).

---

## Decision Tree: Which Agent?

```
Is there an architectural trade-off to record?
  → yes → adr-composer
  
Is there a product/feature decision to record?
  → yes → pdr-composer

Do I need to understand which repos are affected by a change, or ask "what's next?"
  → yes → netrunner (then scope if work follows)

Is `initiatives/current-focus.md` stale, or is it the weekly focus review?
  → yes → netrunner (curator mode)

Do I need to decompose a goal into executable issue packets?
  → yes → scope

Are packets already written and ready to become GitHub Issues?
  → yes → file-issues

Is there a draft that needs iteration/improvement?
  → yes → refine

Has a PR been opened and needs a review pass?
  → yes → review

Do I want a whole-repo health audit of a single Node (drift, boundary overlap, producer/consumer correctness)?
  → yes → node-audit

Did a Node release something that the website should announce?
  → yes → site-sync

Do Architecture-repo files need reconciliation with The Hive (initiatives, packet lifecycle, non-initiative items, Proposed-ADR queue)?
  → yes → hive-sync (ADR-0086 runner schedule/manual dispatch)

Do Grid repo docs need a full currency sweep against current code and catalog truth?
  → yes → docs-sync (ADR-0086 runner Friday schedule/manual dispatch)
```

---

## Execution Rules

These apply to all agents:

- **Claude Code agents plan and generate artifacts; they do not execute code changes.** Execution is Codex or Copilot.
- **Agents do not modify files inside other repos directly.** Cross-repo work goes through issue packets → GitHub Issues → Codex.
- **Agents do not make binding architectural decisions alone.** ADR drafts go to the developer for review before Accepted status.
- **Agents do not push to remote.** No `git push`, no `gh pr create` except `file-issues` (which is authorized for `gh issue create`), `hive-sync` (which runs via the ADR-0086 runner, creates a date-based branch, and opens or updates a reconciliation PR), and `docs-sync` (which opens bounded documentation PRs only within ADR-0085's authority model). During ADR-0014 Packet 01, `hive-sync` still performs initiative-file reconciliation only; packets 02-06 expand it to packet lifecycle, board items, Proposed-ADR queue, ADR/PDR auto-acceptance, README sync, and drift detection.

---

## Context Load Order (all agents)

Before any work, load in this order:

1. `constitution/manifesto.md`
2. `constitution/terminology.md`
3. `constitution/invariants.md`
4. `constitution/sectors.md`
5. `routing/request-types.md` → classify the request
6. Agent-specific context (see below)

### Agent-specific additional context

| Agent | Additional files |
|-------|----------------|
| scope | `catalogs/relationships.json`, `catalogs/nodes.json`, `routing/execution-rules.md`, `repos/{target}/boundaries.md`, `repos/{target}/invariants.md`, issue template from `issues/templates/` |
| adr-composer | Existing ADRs in `ADRs/` for format and precedent |
| pdr-composer | Existing PDRs in `PDRs/` for format and precedent |
| netrunner | `catalogs/relationships.json`, `catalogs/nodes.json`, `routing/repo-discovery-rules.md`, `initiatives/current-focus.md`, `initiatives/active-initiatives.md`, `initiatives/proposed-adrs.md`, `initiatives/archived-initiatives.md` |
| file-issues | `generated/issue-packets/active/` dispatch plan, `copilot/issue-authoring-rules.md` |
| hive-sync | `generated/issue-packets/filed-packets.json`, `catalogs/grid-health.json`, `catalogs/nodes.json`, `initiatives/`, `adrs/ADR-*.md` (frontmatter), GraphQL Hive board query results |
| docs-sync | `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/contracts.json`, `catalogs/grid-health.json`, target repo README/CHANGELOG/docs/agent-instruction files, target repo code symbol search |
| review | ADRs referenced in packet frontmatter, `constitution/invariants.md` |
| node-audit | `catalogs/relationships.json`, `catalogs/nodes.json`, `catalogs/contracts.json`, `catalogs/compatibility.json`, `repos/{node}/overview.md`, `boundaries.md`, `invariants.md`, `initiatives/active-initiatives.md`, governing ADRs, repo code on disk |
| refine | The draft being refined; its governing ADR/PDR if applicable |
| site-sync | `routing/site-sync-rules.md`, `generated/site-sync-packets/` |

---

## Artifact Map

```
Goal / User Request
  │
  ├─ adr-composer → generated/adr-drafts/{slug}.md
  ├─ pdr-composer → generated/pdr-drafts/{slug}.md
  │
  ├─ netrunner   → [briefing mode: verbal "what's next" / impact analysis — no file output]
  │              → [curator mode: writes initiatives/current-focus.md (sole writer)]
  ├─ node-audit  → [verbal findings report on one Node — no file output]
  │
  └─ scope       → generated/issue-packets/active/{initiative}/
                      ├─ dispatch-plan.md
                      ├─ handoff-{wave}.md
                      ├─ 01-{repo}-{description}.md
                      └─ ...
                          │
                          └─ file-issues → GitHub Issues in target repos
                                              │
                                              └─ Codex / Claude Agent SDK
                                                    │
                                                    └─ PR → review → merged
                                                                │
                                                                └─ site-sync → generated/site-sync-packets/
```
