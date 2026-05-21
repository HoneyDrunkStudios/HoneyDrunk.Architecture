# ADR-0043: Continuous Backlog Generation Strategy

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

## Context

Work creation in the Grid is manual today. The pipeline downstream of a packet is well-defined — `file-issues` creates GitHub issues, project-board fields are set, blocking relationships are wired, the issue lands in Codex/Copilot's queue (per ADR-0008). **The pipeline upstream of a packet is not.** A packet exists because a human (or an agent prompted by a human) sat down and wrote one.

This is a bottleneck. The Grid is 12 live Nodes + 13 Seed Nodes + Meta surface; the studio is one developer plus AI agents. The repos can each be improved and expanded, and there is no system that **finds** that work, **queues** it, and **surfaces** it for triage. Concrete evidence:

- The 9 ADRs proposed today (0034–0042) imply 50+ packets across at least 8 repos once accepted; without a deliberate scope pass on acceptance, those will be created ad-hoc as the next person remembers them.
- `initiatives/current-focus.md` lists "Archive / Exit-Criteria Review" against multiple 100%-closed rollouts that have been ready for review for weeks; no scheduled trigger turns "ready" into "queued."
- `node-audit` exists and is opinionated about per-Node health, but no rotation runs it; the audit surface is dormant unless invoked.
- `hive-sync` produces `initiatives/drift-report.md` for human eyes; drift items never become packets unless a human reads the report and writes one.
- `product-strategist` Scout mode exists to surface opportunities; it has never been invoked on a cadence.

The asymmetry is the problem: **execution is wired; sourcing is not.** Downstream is industrialized; upstream is artisanal. With a solo developer, an artisanal upstream is a hard cap on throughput.

Five existing agents already cover the sourcing surfaces individually (`scope`, `node-audit`, `product-strategist`, `hive-sync`, `netrunner`). None of them are coordinated, scheduled, or contracted to produce packets as their output. This ADR is that coordination.

The ADR commits to **what** the sources are, **which agents** own them, the **packet handoff contract**, and the **triage discipline**. It explicitly defers **how** the schedule is executed (OpenClaw cron, GitHub Actions cron, a Claude Code `/loop` slash command, or manual invocation against a checklist) — that choice is independently reversible and worth deferring until at least one source has run long enough to inform the trade-off.

## Decision

### D1 — Four backlog-source streams plus a triage surface

The Grid commits to four named sources of agent-generated packets and one named triage surface. Each source produces packets into `generated/issue-packets/proposed/` (D3); the triage surface reads from there.

| Source | Trigger | Owning agent | Output |
|--------|---------|--------------|--------|
| **Strategic** | An ADR or PDR moves to `Accepted`, or a `Proposed` decision ages past 14 days | `scope` (invoked downstream of `hive-sync` acceptance detection) | One packet per implementation step the decision implies; one dispatch plan per multi-repo rollout |
| **Tactical** | Rotating Node-of-the-week (12 live Nodes → quarterly cycle) | `node-audit` → `scope` | One packet per audit finding the human elects to act on |
| **Opportunistic** | Monthly cadence | `product-strategist` Scout mode → `pdr-composer` (if a finding rises to product-level) | Either PDR drafts (feeding back into the Strategic source) or direct packets for in-scope improvements |
| **Reactive** | Continuous, event-driven — drift detected by `hive-sync`; security CVE published against a Grid dependency (ADR-0009 nightly scan); incident logged in `generated/incidents/`; canary failing past its grace window | `hive-sync` / `scope` | One packet per actionable item; severity gates the human-triage delay (D6) |

The triage surface:

| Surface | Cadence | Owning agent | Output |
|---------|---------|--------------|--------|
| **Weekly briefing** | Weekly | `netrunner` | A single markdown report committed to `generated/briefings/{YYYY-MM-DD}.md` summarizing: new packets generated since last briefing, blockers, stale work, and the recommended top-3 for the week ahead |

The briefing is **not** a backlog source; it is the human-facing triage trigger. Sources fill the queue; the briefing drains it (or rather, surfaces the head of it for the human to drain).

### D2 — Packet is the canonical output of every source

Every source produces packets in the format already governed by `copilot/issue-authoring-rules.md` and the templates in `issues/templates/`. No source produces a different artifact (no "audit reports" filed elsewhere, no "drift items" parked in a separate format). This invariant exists so the downstream pipeline (`file-issues` → GitHub → Codex) is uniform regardless of what produced the packet.

The contract:

- A packet is a markdown file in `generated/issue-packets/proposed/{YYYY-MM-DD}-{repo}-{description}.md` per ADR-0008 D10 naming.
- The packet's frontmatter includes a new `source` field: `strategic` | `tactical` | `opportunistic` | `reactive`. This is how triage later filters and how `hive-sync` reconciles per-source backlogs.
- The packet's frontmatter includes a `generator` field naming the agent that produced it. Auditability of "who said this should be done."

### D3 — Three-state packet lifecycle: `proposed/` → `active/` → `completed/`

The current `generated/issue-packets/` layout has `active/` and `completed/` as observed conventions. This ADR formalizes a three-state lifecycle with explicit directories:

- **`proposed/`** — agent-generated, awaiting human triage. Not yet a GitHub issue. May be edited or deleted without ceremony. The human's queue.
- **`active/`** — human-promoted, filed as a GitHub issue via `file-issues`, in flight. Existing convention.
- **`completed/`** — closed in GitHub, moved here by `hive-sync`. Existing convention.

The `proposed/` → `active/` transition is the **only** point at which a human says "yes, do this." Agents never self-promote. This is the load-bearing discipline that keeps agent-generated noise from becoming agent-generated work.

The `proposed/` directory is allowed to accumulate; stale packets older than 30 days are surfaced in the weekly briefing for "promote, refine, or drop" triage. Old `proposed/` packets are not auto-archived (they were generated by an agent that thought they mattered; the human, not a timer, decides they don't).

### D4 — Per-source cadence and quality-control rules

Each source has a default cadence and a per-source quality control to prevent the failure mode that source is most prone to.

**Strategic — event-driven, not scheduled.**
Trigger: `hive-sync` detects an ADR/PDR status change to `Accepted`. Scope runs once per acceptance. The 14-day age-out on `Proposed` decisions is a secondary trigger to surface stale decisions for "accept or kill," not to scope unaccepted work.
Quality control: scope produces a dispatch plan when more than 3 packets are implied; `refine` runs against the dispatch plan before any packets land in `proposed/`. This is the standard ADR-0008 D5 path; this ADR just makes it automatic instead of human-invoked.

**Tactical — rotating Node, one per week.**
The rotation order is recorded in `initiatives/audit-rotation.md` (new file) — 12 live Nodes covered per quarter, then the cycle repeats. Seed Nodes enter the rotation as they scaffold.
Quality control: `node-audit` is opinionated and will sometimes recommend things you don't want. Output is **always** triaged to `proposed/` and the human picks which findings become `active/`. The audit report itself is committed to `generated/audits/{node}-{YYYY-MM-DD}.md` for the audit trail even if no packets graduate.

**Opportunistic — monthly Scout pass.**
Monthly is deliberate; Scout fatigue is real. Output is ranked opportunities; high-ranked items become PDR drafts (feeding back into the Strategic source on acceptance), lower-ranked items either become direct packets for in-scope improvements or are filed in `generated/scout-reports/{YYYY-MM-DD}.md` for future re-evaluation.
Quality control: Scout output explicitly includes a "kill" recommendation when warranted (the `product-strategist` agent is willing to recommend "build nothing right now" per its definition; that recommendation surfaces too). Avoids the "anything is better than nothing" failure mode.

**Reactive — continuous, severity-gated.**
- Drift: `hive-sync` already runs on a schedule; this ADR adds the rule "drift items at severity ≥ medium become packets in `proposed/`." Low-severity drift remains in the report only.
- Security CVE: ADR-0009 nightly scan finding high+ CVE → immediate packet in `proposed/` with `priority: urgent` frontmatter. Surfaced in the **next** weekly briefing **and** out-of-band-flagged in `generated/briefings/urgent.md` (a rolling file).
- Incident: every entry in `generated/incidents/` produces a follow-up packet for the corrective action; the incident file links to the packet.
- Canary failure past grace window: packet generated automatically, linked to the canary run.
Quality control: deduplication. `hive-sync` checks for existing `proposed/` or `active/` packets covering the same finding before creating a new one. This is the single most important quality control — reactive sources are the easiest to spam.

### D5 — Triage discipline: weekly briefing as the single review surface

The Monday-of-each-week briefing (D1) is the standing human-AI sync. Its contents:

- New `proposed/` packets since the last briefing, grouped by source.
- `active/` packets that closed since the last briefing.
- `active/` packets that have been open more than 14 days with no status change (the stale-work surface).
- `proposed/` packets older than 30 days (the stale-proposal surface).
- The top-3 recommended next actions for the week.
- Any `priority: urgent` reactive packets.

The human reads the briefing, makes triage decisions (`proposed/` → `active/`, or delete), and the rest of the week's work flows from the resulting `active/` queue.

There is no other standing review. Daily netrunner briefings were considered and rejected (D9): solo developers do not need a daily standup; weekly is the right cadence for a solo + agents shop.

### D6 — Severity gates triage delay, not triage itself

`priority: urgent` reactive packets (high+ CVE, production incident) are surfaced **out-of-band** in `generated/briefings/urgent.md` and are not required to wait for the Monday briefing. The human is notified through whatever mechanism the execution surface (D7) provides. All other packets wait for the weekly briefing.

This is the only escape hatch on the weekly-only triage cadence. It exists so the cadence itself does not become the bottleneck for incidents.

### D7 — Execution surface is deferred

This ADR does **not** decide whether the schedules in D4 run via OpenClaw cron, GitHub Actions cron, a Claude Code `/loop` slash command, or human-invoked checklists. The choice is independently reversible — every source is a known agent invocation — and the right choice is informed by which sources prove highest-signal in the first 60 days.

The deferral is bounded: a follow-up ADR (or an amendment to this one) decides the execution surface within 90 days of acceptance, after the first quarter of `node-audit` rotation has run at least once and the first `Scout` pass has been evaluated.

Until that ADR lands, the **shape** of this one is honored manually: the human invokes the appropriate agent for each source on the documented cadence. This is suboptimal but unambiguous — the manual cadence is the floor, automation is the optimization.

### D8 — Relationship to existing agents and ADRs

- **ADR-0008** (work tracking) defines the packet → issue → board → PR pipeline. This ADR fills in the empty slot upstream of it.
- **ADR-0014** (hive-sync) already runs on a schedule (OpenClaw). It gains two new responsibilities: detecting ADR/PDR acceptance to trigger Strategic scope (D4); generating Reactive packets from drift/incidents/scans (D4).
- **ADR-0007** (agents as source of truth) governs the agent surface this ADR coordinates. No agent definition changes; this ADR composes existing agents.
- **`netrunner`, `node-audit`, `scope`, `product-strategist`, `hive-sync`** — each gains a documented scheduled invocation per D4. No prompt changes required at this ADR's acceptance.

### D9 — Staged rollout

Per the conversation that produced this ADR, the rollout is staged to validate the highest-leverage sources first:

- **Phase 1 (Week 1–2):** Strategic source live (event-driven on ADR-0042 → packets for the 9 newly-accepted-when-they-graduate ADRs). Reactive source live for drift (lowest implementation cost; already 80% built into hive-sync).
- **Phase 2 (Week 3–8):** Tactical rotation begins; first Node audit runs Week 3, weekly cadence thereafter. Weekly briefing begins Week 3.
- **Phase 3 (Month 3+):** Opportunistic Scout begins. Reactive sources expand to security CVE and incidents.
- **Phase 4 (Month 4+):** Execution-surface follow-up ADR; manual cadence converts to scheduled automation per its decision.

Each phase is an independent go/no-go. If Phase 1 generates more noise than value, Phases 2–4 don't auto-start.

## Consequences

### Affected Nodes

- **HoneyDrunk.Architecture** (this repo) — primary affected Node; new directories (`generated/issue-packets/proposed/`, `generated/audits/`, `generated/scout-reports/`, `generated/briefings/`), new index file `initiatives/audit-rotation.md`, expanded `hive-sync` responsibilities per D8.
- **No code-Node changes.** This is entirely a Meta-sector decision about how work flows into the existing pipeline.
- **`hive-sync` agent** — gains the ADR-acceptance trigger (D4 Strategic) and the drift-to-packet conversion (D4 Reactive). Both are amendments to its existing run loop; ADR-0014's mandate already permits them.

### Invariants

Adds two:

- **Invariant: every agent-generated packet lands in `generated/issue-packets/proposed/`, never directly in `active/`.** Agents do not self-promote; a human is the only `proposed/` → `active/` transition authority.
- **Invariant: every packet carries `source` and `generator` frontmatter fields.** Auditability of agent-generated work is non-negotiable.

### Operational Consequences

- The `proposed/` directory becomes a new accumulating surface. Expected steady-state: 5–20 entries depending on which week of the rotation. Acceptable; the weekly briefing keeps it bounded by human attention.
- Audit findings the human declines to action still leave a record in `generated/audits/` even though no packet is created. This is desirable — "we looked at this Node and chose not to act" is information.
- The weekly briefing is a new committed artifact and a new recurring expectation on the human. ~30 minutes of triage per week at steady state. If this proves heavier than budgeted, the cadence (D5) is the lever; reduce to bi-weekly before reducing sources.
- `priority: urgent` reactive packets require an out-of-band notification mechanism. Until D7 decides the execution surface, the human checks `generated/briefings/urgent.md` opportunistically; this is the manual-cadence floor's known cost.
- Sources will sometimes recommend conflicting work (a Tactical audit finding contradicting a Strategic ADR direction). Triage at the weekly briefing is the resolution point; the ADR wins.

### Follow-up Work

- Create the new directories: `generated/issue-packets/proposed/`, `generated/audits/`, `generated/scout-reports/`, `generated/briefings/`.
- Author `initiatives/audit-rotation.md` with the initial 12-Node rotation order.
- Amend `hive-sync` for the ADR-acceptance trigger and drift-to-packet conversion (per D8).
- Amend `copilot/issue-authoring-rules.md` to require the `source` and `generator` frontmatter fields.
- Phase 1 kickoff: invoke `scope` against ADR-0034 through ADR-0042 to populate the first round of `proposed/` packets. This is also the first real-world test of the Strategic source.
- Author the execution-surface follow-up ADR within 90 days (D7).

## Alternatives Considered

### Continue manual sourcing indefinitely

Rejected. The Grid's scope (12+ live Nodes, expanding) and the studio's headcount (1 developer) make manual sourcing a hard throughput cap. The current state — most repos under-improved relative to their potential — is the failure mode being addressed.

### A single "backlog generator" agent that owns all sources

Rejected. Each source has different inputs, different cadences, and different failure modes; collapsing them into one agent obscures the rules per source and conflates "audit a Node" with "scope an ADR" with "find market opportunities." The existing per-source agents are correctly factored; the missing piece is the coordination layer this ADR provides.

### Skip the `proposed/` directory; agents create GitHub issues directly

Rejected. The agent-generated → human-triaged gate is the single most important quality control in the design. Removing it means agent noise becomes GitHub issue spam, which then has to be triaged in GitHub (worse UX than triaging local files) or accepted as work the team didn't actually choose. The friction of `proposed/` → `active/` is the feature.

### Decide the execution surface in this ADR

Rejected per D7. The right surface depends on which sources prove highest-signal; deciding now is decision-under-uncertainty in service of nothing. The 90-day deferral is bounded so the deferral itself does not become permanent.

### Daily briefing instead of weekly

Considered and rejected per D5. Daily is the right cadence for a multi-developer team where work needs handoff at end-of-day. For a solo + agents shop, daily becomes interruption; weekly is the cadence where signal exceeds noise.

### Bi-weekly briefing instead of weekly

Considered. Cheaper on human attention. Rejected on responsiveness: reactive-source packets (especially security CVEs) need at most a week of triage delay, and the weekly briefing is what surfaces them. Bi-weekly is the fallback if weekly proves heavier than expected (D5 Operational Consequences).

### Use GitHub Projects as the `proposed/` surface instead of a directory

Rejected. The packet-as-markdown-file pattern is what makes the downstream pipeline (refine, file-issues, scope) work; it is also what makes packets reviewable in a PR. GitHub Projects is the right surface for `active/` (and is per ADR-0008); using it for `proposed/` would split the packet-authoring tooling across two surfaces unnecessarily.
