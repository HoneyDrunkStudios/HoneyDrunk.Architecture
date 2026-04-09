# ADR-0008: Work Tracking and Execution Flow

**Status:** Accepted
**Date:** 2026-04-09
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

## Context

HoneyDrunk spans 11+ repos operated by a solo developer with AI agents as collaborators. Work flows from ADRs into scoped issue packets, then into execution inside target repos, and finally into PRs. Until now there has been no documented convention for how a packet becomes a live work item, how its state is tracked, or how a cloud agent consumes it.

With ADR-0005 and ADR-0006 about to generate roughly 15 issues across 10 repos, the execution machinery has to be formalized before first use. Otherwise every rollout reinvents the same conventions — label schemes, field schemas, auto-add rules, agent trigger contracts — and drift starts on day one.

Per-repo GitHub Project boards are not viable at this scale. A solo dev cannot meaningfully maintain 11+ boards, and per-repo boards provide no cross-repo view of an initiative that cuts across Nodes. A single org-level tracking surface is required.

This ADR is about *process* architecture rather than system topology. The closest-fitting sector is **Meta** — `HoneyDrunk.Architecture` itself, the Grid's self-awareness layer, already owns ADRs, routing, and agent workflows, so work-item flow belongs alongside them.

This ADR depends on ADR-0005 and ADR-0006 (the first rollouts that will exercise the lifecycle) and on ADR-0007 (which makes `.claude/agents/` the single source of truth for the scope and adr-composer agents whose outputs feed this flow).

## Decision

Work tracking and execution are defined by nine bound decisions. Together they describe the system of record, the artifact chain, and the path from packet to merged PR.

### D1 — Single org-level GitHub Project v2 as the board

One Project at `github.com/orgs/HoneyDrunkStudios/projects/{N}` is the cross-repo tracking surface for every work item in the Grid. Not per-repo boards. Not Linear, Jira, Azure DevOps, or any external tool.

The issues themselves still live in their target repos — PR linking, branches, git history, and agent execution context all require it. The Project is a cross-repo **view**, not the system of record for the issues it aggregates.

### D2 — Issue location follows code location

Every tracked work item has a GitHub Issue in the target repo where the work will land. Issues are never filed in a central tracking repo. `HoneyDrunk.Architecture` holds issues only for work that lands in Architecture itself (docs, catalogs, ADRs, routing updates).

### D3 — Canonical custom field schema

The org Project carries exactly these custom fields:

| Field | Type | Values |
|---|---|---|
| `Status` | single select | `Backlog`, `Ready`, `In Progress`, `Blocked`, `Done` |
| `Wave` | single select | `Wave 1`, `Wave 2`, `Wave 3`, `N/A` |
| `Initiative` | single select | entries from `initiatives/active-initiatives.md` |
| `Node` | single select | NodeId values from `catalogs/nodes.json` |
| `Tier` | single select | `1`, `2`, `3` (per `routing/request-types.md`) |
| `ADR` | text | comma-separated ADR references, e.g. `ADR-0005, ADR-0006` |

### D4 — Canonical label conventions

Labels are authoritative in the issue; the board mirrors them into custom fields via workflow automation.

- `wave-{N}` — wave membership for ADR-driven rollouts
- `adr-{NNNN}` — traceability to governing ADRs
- `tier-{N}` — request type tier
- `blocked` — awaiting upstream work

A `hd-tracked` opt-in label is **not** required — see D5.

### D5 — Auto-add via org-wide repo filter

The Project's auto-add workflow is configured once, on the Project itself, with the filter `repo:HoneyDrunkStudios/*`. Every issue in every org repo is added automatically.

Label-gated auto-add (e.g. requiring an `hd-tracked` label) is explicitly rejected: a forgotten label causes silent visibility loss. The repo filter is foolproof and requires zero per-repo configuration.

### D6 — Packet → Issue → Board → PR lifecycle

Five stages, one owner each:

1. **Spec** — Issue packet in `HoneyDrunk.Architecture/generated/issue-packets/*.md`. Owned by the scope agent. **Immutable once written.**
2. **Ticket** — GitHub Issue in the target repo. Body is short and links to the packet file. Created by a batch-filing script.
3. **Dashboard** — Project board item, created via the auto-add workflow. Live state lives in custom fields.
4. **Execution** — Claude Agent SDK (cloud) or local Claude Code, triggered when `Status` transitions to `Ready`. The agent reads the packet via the issue link, executes against the target repo, and opens a PR.
5. **Merge** — PR merges, issue closes, board item → `Done` via workflow.

### D7 — Artifact responsibilities

This formalizes what the scope agent already emits, and pins down what each artifact is **for**.

- **Issue packet** — the spec. Immutable. One source of truth for *what* and *why*.
- **Dispatch plan** — the initiative narrative. Why the rollout exists, wave dependencies, rollback plan, exit criteria. **Not** a live tracker; it is a historical record updated at wave boundaries.
- **Handoff** — the baton pass between waves. Read once at wave transition. Documents the public surface Wave N+1 may assume from Wave N. Ephemeral.
- **GitHub Issue** — the execution ticket. Short body, links to the packet. State lives in Project custom fields.
- **Project board** — the live state. The only place to answer "what is in flight right now?"

### D8 — Cloud agent execution model

A reusable GitHub Actions workflow lives in `HoneyDrunk.Actions` (already covered by an ADR-0005 Wave 1 packet). Its contract:

- Trigger: `projects_v2_item.edited` when `Status` transitions to `Ready`
- Checks out both the target repo and `HoneyDrunk.Architecture` (for packet + ADR context)
- Runs the Claude Agent SDK against the packet file
- The agent opens a PR, comments on the issue with the PR link, and transitions `Status` → `In Progress`
- On PR merge, a companion workflow transitions `Status` → `Done`

This is the single execution path for cloud-driven work. No alternative cloud agent entrypoints are sanctioned.

### D9 — Scope agent output aligns to this schema

The scope agent's packet frontmatter (`wave`, `target_repo`, `labels`, `adrs`, `tier`) already aligns with the fields in D3 and the labels in D4. The scope agent's `.md` file output continues to be the contract between scoping and execution. This ADR promotes the on-the-fly conventions invented during the ADR-0005 / ADR-0006 scoping run to permanent schema.

### D10 — Packet file layout and archival

Packets, dispatch plans, and handoffs are grouped by **initiative**, and the filesystem carries only one distinction: **active vs archived**. Per-packet lifecycle (Backlog / Ready / In Progress / Done) lives exclusively on the org Project board per D7 and is never reflected in file paths or filenames.

**Layout:**

```
generated/issue-packets/
├── active/
│   └── {initiative-slug}/
│       ├── dispatch-plan.md
│       ├── handoff-{wave-or-purpose}.md        (zero or more)
│       ├── 01-{target-repo-short}-{kebab-description}.md
│       ├── 02-{target-repo-short}-{kebab-description}.md
│       └── ...
├── archive/
│   └── {initiative-slug}/                       (same structure, frozen)
└── active/standalone/
    └── {YYYY-MM-DD}-{target-repo-short}-{kebab-description}.md
```

**Rules:**

- **Initiative folders are the archival unit.** When every work item in an initiative reaches `Done` and the dispatch plan's exit criteria are met, the whole folder is moved from `active/` to `archive/` in a single commit. Partial archival is forbidden — an initiative is either wholly active or wholly archived.
- **Dispatch plan and handoffs live alongside their packets** in the same initiative folder. The dispatch plan is always named `dispatch-plan.md`. Handoffs are named `handoff-{wave-or-purpose}.md`. This co-location means the entire story of an initiative lives in one directory.
- **Numeric prefixes replace date prefixes inside initiative folders.** The prefix (`01-`, `02-`, …) reflects execution order from the dispatch plan, not calendar date. Inside a bounded folder, execution order is more useful than creation date.
- **Standalone packets** — one-off work not tied to an initiative — live in `active/standalone/` and keep date-prefixed filenames (`{YYYY-MM-DD}-{target}-{description}.md`). They archive individually to `archive/standalone/` when their issue closes. This is the one exception to initiative-granularity archival, justified by the lack of an enclosing initiative.
- **Moving a file between `active/` and `archive/` is not an edit.** Invariant 24 (packets are immutable specs) forbids content changes; file relocation preserves content and is tracked by git as a rename. The immutability rule applies to what a packet *says*, not to where it *lives*.
- **`ls active/` is the filesystem-level answer to "what rollouts are in flight?"** This complements the org Project board — the board answers per-work-item questions, the filesystem answers per-initiative questions.
- **The dispatch plan is the exception to immutability.** Per D7 it is a living narrative, updated at wave boundaries. All other artifacts (packets, handoffs) are immutable under invariant 24.

**Deprecated:** The prior convention of sibling `generated/dispatch-plans/` and `generated/handoffs/` folders is retired. All three artifact types are co-located inside their initiative folder.

## Consequences

### Process Consequences

- Every future rollout follows this lifecycle without reinvention. Wave 1 of ADR-0005 / ADR-0006 is the first exercise of it.
- Execution of the ADR-0005 / ADR-0006 Wave 1 packets **must wait** until the org Project is configured per this ADR. Otherwise the first 15 issues land without correct fields and labels and have to be backfilled.
- Dispatch plans no longer carry live status. Updating them outside wave boundaries is an anti-pattern under invariant 25.

### New Invariants

The following invariants must be added to `constitution/invariants.md` under a new **Work Tracking Invariants** section:

23. **Every tracked work item has a GitHub Issue in its target repo.** No work tracked exclusively in packet files, chat logs, or external tools.
24. **Issue packets are immutable specifications.** State lives on the Project board, never in the packet file. If requirements change materially, write a new packet rather than editing the old one.
25. **Dispatch plans are initiative narratives, not live state.** The org Project board is the source of truth for in-flight work. Dispatch plans are updated at wave boundaries as historical records.

### Follow-up Work

None of the following is part of this ADR. Each is a discrete follow-up and should be scoped separately.

- One-time org Project setup — create / confirm the Project, add the six custom fields from D3, configure auto-add with `repo:HoneyDrunkStudios/*`, and save canonical views (By Wave, By Node, Blocked). Portal walkthrough in `HoneyDrunk.Architecture/infrastructure/`.
- Packet-filing script in `HoneyDrunk.Actions` (e.g. `scripts/file-packets.sh`) to batch-file packets from `generated/issue-packets/` into their target repos with correct labels.
- Minor update to the scope agent definition referencing ADR-0008 as its output schema contract.
- Minor update to the adr-composer agent definition referencing ADR-0008 when it tells the user to delegate to the scope agent.

## Alternatives Considered

### Per-repo Project boards

Rejected. 11+ boards for a solo dev is unmaintainable, and per-repo boards destroy the cross-repo view an initiative depends on. The whole point of an initiative like ADR-0005 is that it cuts across Nodes — fragmenting tracking per Node defeats it.

### External tool (Linear, Jira, Azure DevOps)

Rejected. Introduces a second system of record alongside GitHub Issues, breaks native PR linking without extra integrations, adds licensing cost, and violates the "fewer moving parts" principle the solo-dev posture depends on.

### Central tracking repo for all issues

Rejected. Breaks PR linking to the real code repo, breaks per-Node git history of discussion, and breaks the per-Node blast-radius isolation the Grid is built around.

### Label-gated auto-add (`hd-tracked`)

Rejected. A forgotten label causes silent visibility loss. The `repo:HoneyDrunkStudios/*` repo filter is foolproof and eliminates per-repo configuration entirely.

### Tracking state via `status:` frontmatter in packet files

Rejected. Duplicates state with the board, drifts trivially, and violates the immutability of specs. State belongs on the board, the spec belongs in the packet — no overlap.

### Local Claude Code only, no cloud agent entrypoint

Rejected. Works at current scale, but does not scale to parallel execution across repos, and leaves the existing HoneyDrunk.Actions cloud-agent ambitions stranded. The cloud path is defined now so local execution remains a superset rather than a divergence.

### A single ADR covering both the decision and the workflow YAML

Rejected for scope. This ADR covers the *decision*: system of record, lifecycle, schema, and artifact responsibilities. The actual workflow YAML is implementation detail and belongs in a packet against `HoneyDrunk.Actions`, not in this ADR body.
