# ADR-0008: Work Tracking and Execution Flow

**Status:** Accepted
**Date:** 2026-04-09
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

## Context

HoneyDrunk spans 11+ repos operated by a solo developer with AI agents as collaborators. Work flows from ADRs into scoped work items, then into execution inside target repos, and finally into PRs. Until now there has been no documented convention for how a packet becomes a live work item, how its state is tracked, or how a cloud agent consumes it.

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
| `Status` | single select | `Backlog`, `Ready`, `In Progress`, `In Progress - Agent`, `Blocked`, `Done` |
| `Wave` | single select | `Wave 1`, `Wave 2`, `Wave 3`, `N/A` |
| `Initiative` | single select | entries from `initiatives/active-initiatives.md` |
| `Node` | single select | NodeId values from `catalogs/nodes.json` |
| `Tier` | single select | `1`, `2`, `3` (per `routing/request-types.md`) |
| `ADR` | text | comma-separated ADR references, e.g. `ADR-0005, ADR-0006` |
| `Actor` | single select | `Agent`, `Human` — who executes the work. Default `Agent`. Set `Human` when a work item cannot be delegated (repo creation, portal-only actions, payments, judgment calls). Mirrors the `human-only` label in D4. Primary visual surface for the "Agent Queue" board view. |

### D4 — Canonical label conventions

Labels are authoritative in the issue. The board mirrors them into custom fields via a **custom GitHub Action** (the label→field mirror workflow in `HoneyDrunk.Actions`, packet filed 2026-04-10 as HoneyDrunk.Actions#22). GitHub Projects v2 does **not** ship native label→field mapping — the mirroring promised here requires the custom workflow to be built and installed. Until it lands, filed issues need a one-shot field backfill via `gh project item-edit`.

- `wave-{N}` — wave membership for ADR-driven rollouts
- `adr-{NNNN}` — traceability to governing ADRs
- `tier-{N}` — request type tier
- `blocked` — awaiting upstream work
- `human-only` — opt-out label marking work an agent cannot execute end-to-end (repo creation, payments, portal actions that cannot be delegated, judgment calls on new designs). Absence of the label means the issue is agent-eligible by default. Distinguished from "Human Prerequisites" sections inside packets, which list portal steps that precede *agent-eligible* work.

A `hd-tracked` opt-in label is **not** required — see D5.

**Agent Queue view.** The Hive project board should carry a saved view named "Agent Queue" filtered to `Actor=Agent AND Status in (Backlog, Ready)`. The filter uses the `Actor` custom field (D3) rather than the label directly, because labels are not shown as first-class pills on Projects v2 board cards — only custom single-select fields are. The `human-only` label is the opt-out *data*; the `Actor` field is the *visual display surface*. The label→field mirror workflow keeps them in sync automatically; until it lands, both are set manually when filing an issue.

### D5 — Auto-add via org-wide repo filter

The Project's auto-add workflow is configured once, on the Project itself, with the filter `repo:HoneyDrunkStudios/*`. Every issue in every org repo is added automatically.

Label-gated auto-add (e.g. requiring an `hd-tracked` label) is explicitly rejected: a forgotten label causes silent visibility loss. The repo filter is foolproof and requires zero per-repo configuration.

**Operational note:** this workflow must be enabled manually in the portal (board → `...` menu → Workflows → Auto-add to project → filter `repo:HoneyDrunkStudios/*` → toggle on). It is *not* enabled by default. Until it is enabled, every filed issue requires a manual `gh project item-add` to land on the board. Additionally, auto-add only runs forward — issues filed before enablement must be added manually (this happened to the 11 issues in the ADR-0005/0006 rollout on 2026-04-10).

### D6 — Packet → Issue → Board → PR lifecycle

Five stages, one owner each:

1. **Spec** — Work item in `HoneyDrunk.Architecture/generated/work-items/*.md`. Owned by the scope agent. **Immutable once written.**
2. **Ticket** — GitHub Issue in the target repo. Body is short and links to the packet file. Created by a batch-filing script.
3. **Dashboard** — Project board item, created via the auto-add workflow. Live state lives in custom fields.
4. **Execution** — Claude Agent SDK (cloud) or local Claude Code, triggered when `Status` transitions to `Ready`. The agent reads the packet via the issue link, executes against the target repo, and opens a PR.
5. **Merge** — PR merges, issue closes, board item → `Done` via workflow.

### D7 — Artifact responsibilities

This formalizes what the scope agent already emits, and pins down what each artifact is **for**.

- **Work item** — the spec. Immutable. One source of truth for *what* and *why*.
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
generated/work-items/
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

## Amendment (2026-05-21) — Initiative Slug Naming

D10's `{initiative-slug}` was always unconstrained text, but every initiative authored under ADR-0008 to date has been ADR-driven and used the form `adr-NNNN-{descriptor}/`. This amendment makes the slug convention explicit so PDR-driven and product-driven initiatives have a clear home.

**Rule:**

- **ADR-driven initiative** — slug is `adr-NNNN-{descriptor}/` (e.g., `adr-0027-notify-cloud-standup/`). Required when the work executes an Accepted ADR.
- **PDR-driven or product-driven initiative** — slug is a plain descriptor with no prefix (e.g., `notify-cloud-billing/`, `notify-cloud-soft-launch/`). Used when the work executes a Product Decision Record or a sustained product push without a governing ADR. The `Initiative` field on The Hive carries the trace back to PDR-NNNN; the folder name stays human-readable.
- **Business-driven initiative** — slug is a plain descriptor (e.g., `mailbox-switch/`). Used when a BDR (`business/decisions/`) governs the work.

ADR-prefix and plain-slug initiatives are otherwise structurally identical — dispatch plan, numbered packets, archival as a unit, immutability under invariant 24 — and live under the same `active/` and `archive/` parents. The scope agent picks the form based on whether an ADR or a PDR/BDR is the governing decision.

Not every Notify Cloud (or other product) work item belongs in an initiative. Single features, single bugs, and one-off chores still go to `active/standalone/` per D10. The initiative folder is only for multi-packet pushes with a dispatch plan.

## Amendment (2026-06-01) — Implementation-Notes Packets (As-Built Reconciliation)

A decision (ADR/PDR/BDR) and its packets are written *before* the work. Implementation routinely teaches things the decision and packets could not foresee — a packet's path filter was wrong, a chosen mechanism changed shape, an environment behaved differently than assumed, a "deferred" option turned out to be the right one to adopt early. This is normal and healthy: agility means the map updates when the territory pushes back. But the lifecycle as written (D6/D7) had **nowhere to record what actually shipped and, more importantly, *why* it diverged** — and packets are immutable (invariant 24), so the delta cannot be back-written into them. The dispatch plan is the wrong home: it is the *forward* narrative, updated at wave boundaries. And `hive-sync` — which flips ADR status and moves closed initiative folders to `completed/` (invariant 111) — has no knowledge of the how or the why; it sees board state, not implementation reasoning.

**Rule:**

- **Every initiative's dispatch ends with an Implementation-Notes packet.** The scope agent emits it as the final task in the wave plan, carrying `dependencies:` on every implementation packet in the initiative, `target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture`, and `actor: Agent`. Its packet body is a *stub* — it specifies what the notes must cover (below), not the notes themselves.
- **The implementing agent authors it — not the scope agent, not `hive-sync`.** Whoever did the work holds the how and the why; that knowledge cannot be reconstructed from board state after the fact. `hive-sync` keeps the mechanical jobs (Proposed→Accepted flip on packet closure, `active/`→`completed/` move per invariant 111); it does **not** write implementation notes. Authoring them is the implementer's closing task, run after the implementation packets merge and before the initiative moves to `completed/`.
- **Deliverable:** `implementation-notes.md` in the initiative folder, alongside `dispatch-plan.md`. For a decision-driven initiative it *also* appends a dated `## Implementation Notes (YYYY-MM-DD)` pointer section to the governing ADR/PDR/BDR, so the delta is discoverable at the decision — not buried in the packet folder.
- **Contents (minimum):** (1) what shipped, in a paragraph; (2) **deltas** — each material way the implementation diverged from the decision and/or the packets, written as *decided ➜ as-built*; (3) **why** each delta happened (the implementation learning); (4) PR/commit pointers; (5) follow-ups surfaced during the work; (6) known deviations from conventions, made explicit rather than silent. The original decision and packets are **not** edited — the notes are a retrospective overlay that preserves the decision history while recording reality.
- **New artifact type (extends D7).** Implementation notes join the taxonomy: *spec* (packet — immutable), *narrative* (dispatch plan — mutable at wave boundaries), *baton* (handoff — ephemeral), and now *as-built* (implementation notes — authored once by the implementer at initiative close, a retrospective record, neither a spec nor live state; edited only to correct error).
- **Scope-agent + filing.** The scope agent definition is updated in this change (`.claude/agents/scope.md` § Implementation-Notes Packet) to always emit the Implementation-Notes packet as the final task. `file-work-items.yml` files it like any other packet — no filing change needed.

**Work Tracking Invariant 110** (in `constitution/invariants.md`): *Every initiative closes with an implementation-notes record authored by the implementing agent, capturing what shipped and why it diverged from the decision and its packets. `hive-sync` **verifies the record exists and gates completion/archival on it** — an initiative whose tracked issues are all closed but whose record is missing is held `In Progress` and flagged, not completed. `hive-sync` flips status and moves the folder to `completed/`; it never authors the record.*

> **Refinement (2026-06-04).** The gate clause above (`hive-sync` verifies + holds-and-flags when the record is missing) was added after the original amendment shipped only the "does not author" half — without the verify gate, `hive-sync`'s issue-closure-driven `active/`→`completed/` move (invariant 111) would advance an initiative to complete with no implementation-notes record, silently. Invariant 110 and `hive-sync` Steps 3/7 now enforce the gate.

**Why a rule, not a habit:** without it, the only durable record is the *intended* design (decision + immutable packets), which drifts silently from the *actual* system the moment implementation teaches anything. The reconciliation note closes the loop — decision → plan → reality → recorded learning — and lands the learning with the one party who holds it.

## Consequences

### Process Consequences

- Every future rollout follows this lifecycle without reinvention. Wave 1 of ADR-0005 / ADR-0006 is the first exercise of it.
- Execution of the ADR-0005 / ADR-0006 Wave 1 packets **must wait** until the org Project is configured per this ADR. Otherwise the first 15 issues land without correct fields and labels and have to be backfilled.
- Dispatch plans no longer carry live status. Updating them outside wave boundaries is an anti-pattern under invariant 25.

### New Invariants

The following invariants must be added to `constitution/invariants.md` under a new **Work Tracking Invariants** section:

23. **Every tracked work item has a GitHub Issue in its target repo.** No work tracked exclusively in packet files, chat logs, or external tools.
24. **Work items are immutable specifications.** State lives on the Project board, never in the packet file. If requirements change materially, write a new packet rather than editing the old one.
25. **Dispatch plans are initiative narratives, not live state.** The org Project board is the source of truth for in-flight work. Dispatch plans are updated at wave boundaries as historical records.

### Follow-up Work

None of the following is part of this ADR. Each is a discrete follow-up and should be scoped separately.

- One-time org Project setup — create / confirm the Project, add the six custom fields from D3, configure auto-add with `repo:HoneyDrunkStudios/*`, and save canonical views (By Wave, By Node, Blocked). Portal walkthrough in `HoneyDrunk.Architecture/infrastructure/`.
- Packet-filing script in `HoneyDrunk.Actions` (e.g. `scripts/file-work-items.sh`) to batch-file packets from `generated/work-items/` into their target repos with correct labels.
- Minor update to the scope agent definition referencing ADR-0008 as its output schema contract.
- Minor update to the adr-composer agent definition referencing ADR-0008 when it tells the user to delegate to the scope agent.

## Unresolved Consequences

These are known gaps in the ADR-0008 system that have been identified but not yet resolved. They are tracked here so agents reading this ADR know what they cannot rely on today.

### D4 Gap — RESOLVED (2026-04-12)

`HoneyDrunk.Actions#22` delivered and closed. `hive-field-mirror.yml` is a reusable workflow in HoneyDrunk.Actions. It fires on `issues.opened/labeled/unlabeled/edited` events and via `workflow_call`. The `hive-project-mirror.sh` script handles the GraphQL field writes. `hive-backfill-issue.sh` handles manual one-shot backfills. The workflow also adds the issue to The Hive if it isn't already there (via `addProjectV2ItemById`), which partially covers D5.

**Remaining action for D4:** Each sibling repo must add a caller workflow — see D5 below.

### D5 Gap — RESOLVED via D6 for the Primary Flow

**Portal approach — not viable.** GitHub Projects v2 auto-add workflow only allows single-repo selection in the portal UI; org-wide `repo:HoneyDrunkStudios/*` filter is not exposed. Rejected.

**Why D5 is not the right solution for the primary path:**

The primary flow is: work items are authored in Architecture repo → PR merged → a batch-filing action in `HoneyDrunk.Actions` reads packets and creates issues in target repos. That action calls `hive-project-mirror.sh` immediately after each `gh issue create`, so the issue lands on The Hive with all fields populated at filing time. No per-repo event triggers, no auto-add, no deferred sync needed.

D6 (batch-filing action — now operational, see below) is the correct fix. With D6 in production and incorporating the mirror step, D5 is fully resolved for all issues filed through the official packet flow.

**Residual gap — out-of-band issues:** Issues filed manually (not through a packet) in any repo will not trigger the mirror. Options:
- Accept the manual `gh project item-add` + `scripts/hive-backfill-issue.sh` pattern for occasional one-offs.
- Optionally add a 10-line caller workflow to individual repos as they become active. Not required — this is purely defensive coverage for edge cases.

### D6 Gap — RESOLVED (operational by 2026-05-20)

The batch-filing action shipped: `HoneyDrunk.Actions/scripts/file-work-items.sh` invoked by `HoneyDrunk.Actions/.github/workflows/file-work-items.yml`. Both are referenced as existing in standalone packet `2026-05-20-actions-file-work-items-body-length-precheck.md`, and `generated/work-items/filed-work-items.json` shows it has been operating across many initiatives (ADR-0010, 0011, 0012, 0015, 0016, 0017, 0029 and more) — each entry maps a packet path to the auto-filed GitHub issue URL.

What the action does in practice:

1. Triggered from Architecture repo on PR merge to `main` (or manually via `workflow_dispatch`)
2. Reads frontmatter from newly merged packets in `generated/work-items/active/` (target_repo, labels, tier, wave, adrs, initiative, dependencies)
3. Runs `gh issue create` with correct labels in the target repo
4. Calls `hive-project-mirror.sh` for the new issue URL — adds it to The Hive and sets all fields from frontmatter
5. Sets issue `Status` to `Backlog` on The Hive
6. Resolves the `dependencies:` frontmatter array into `addBlockedBy` GraphQL calls so blocking relationships surface natively

This single action replaced manual `gh issue create` + `hive-backfill-issue.sh` per packet and eliminated the bottleneck described in the prior framing of this gap.

`HIVE_FIELD_MIRROR_TOKEN` is configured as an org secret (without it the production runs in `filed-work-items.json` would not have succeeded).

**Residual hardening (tracked separately):**

- **Standalone packet `2026-05-20-actions-file-work-items-body-length-precheck.md`** — adds two structural fixes to `scripts/file-work-items.sh`:
  1. Pre-flight body-length check (fail fast before any `gh issue create` calls if any packet exceeds the 65k GitHub issue-body cap)
  2. Continue-on-failure for per-packet creation (don't exit on first failure; report a summary)

  Real-world driver: PR #152 (ADR-0031 standup) tripped this when packet 03 (86 KB body) was rejected and packet 04 never attempted. The standalone packet captures the fix; track its filing/execution on The Hive.

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
