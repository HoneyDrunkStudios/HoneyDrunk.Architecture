# ADR-0043: Continuous Backlog Generation Strategy

**Status:** Accepted
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

The ADR commits to **what** the sources are, **which agents** own them, the **packet handoff contract**, the **triage discipline**, and the execution surface. The original proposed text deferred scheduling; that deferral is now closed by ADR-0086. Backlog generation runs through the ADR-0086 pull-based local Grid Agent Runner, using declarative job specs, Codex prompts, PR write mode, and Discord completion notifications via the runner's Key Vault-resolved path.

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
- Reactive packets may also include `priority: urgent` for high+ CVE, production incident, or canary-failure-past-grace items. Non-urgent packets either omit `priority` or set a lower local value for briefing sorting only.

### D3 — Three-state packet lifecycle: `proposed/` → `active/` → `completed/`

The current `generated/issue-packets/` layout has `active/` and `completed/` as observed conventions. This ADR formalizes a three-state lifecycle with explicit directories:

- **`proposed/`** — agent-generated, awaiting human triage. Not yet a GitHub issue. May be edited or deleted without ceremony. The human's queue.
- **`active/`** — human-promoted, filed as a GitHub issue via `file-issues`, in flight. Existing convention.
- **`completed/`** — closed in GitHub, moved here by `hive-sync`. Existing convention.

The `proposed/` → `active/` transition is the **only** point at which a human says "yes, do this." Agents never self-promote. This is the load-bearing discipline that keeps agent-generated noise from becoming agent-generated work.

The `proposed/` directory is allowed to accumulate; stale packets older than 30 days are surfaced in the weekly briefing for "promote, refine, or drop" triage. Old `proposed/` packets are not auto-archived (they were generated by an agent that thought they mattered; the human, not a timer, decides they don't).

### D4 — Per-source cadence and quality-control rules

Each source has a default cadence and a per-source quality control to prevent the failure mode that source is most prone to.

**Strategic — scheduled scan with event semantics.**
Trigger: the ADR-0086 `backlog-strategic-scope` job runs after `hive-sync`, detects ADR/PDR status changes to `Accepted` or accepted decisions with missing implementation packets, and invokes scope-like decomposition once per acceptance. The 14-day age-out on `Proposed` decisions is a secondary trigger to surface stale decisions for "accept or kill," not to scope unaccepted work.
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

`priority: urgent` reactive packets (high+ CVE, production incident) are surfaced **out-of-band** in `generated/briefings/urgent.md` and are not required to wait for the Monday briefing. The human is notified through Discord using the ADR-0086 runner notification path, with routing governed by `constitution/alert-routing.md`: ordinary backlog-generation runs route to `#hive-activity`; urgent security items route to `#security-alerts`; urgent operational incidents route to `#ops-alerts`. All other packets wait for the weekly briefing.

This is the only escape hatch on the weekly-only triage cadence. It exists so the cadence itself does not become the bottleneck for incidents.

### D7 — Execution surface is ADR-0086 Grid Agent Runner

The backlog-generation schedules in D4 run through the ADR-0086 pull-based local Grid Agent Runner. The committed jobs are:

- `backlog-strategic-scope` — scheduled after `hive-sync`, writes strategic proposed packets and a per-run source report.
- `backlog-tactical-audit` — weekly Node rotation, writes `generated/audits/{node}-{YYYY-MM-DD}.md` and tactical proposed packets for actionable findings.
- `backlog-opportunistic-scout` — weekly scheduler with a monthly guard, writes `generated/scout-reports/{YYYY-MM-DD}.md` and opportunistic proposed packets or PDR-request packets when warranted.
- `backlog-weekly-briefing` — weekly netrunner pass, writes `generated/briefings/{YYYY-MM-DD}.md` and may refresh netrunner-owned focus surfaces.

Every job runs in `WriteMode = "pr"` by default. Proposed packets are therefore generated in reviewable Architecture PRs before they reach `main`, and agents still do not promote anything from `proposed/` to `active/`.

### D8 — Relationship to existing agents and ADRs

- **ADR-0008** (work tracking) defines the packet → issue → board → PR pipeline. This ADR fills in the empty slot upstream of it.
- **ADR-0014** (hive-sync) already runs on a schedule through the ADR-0086 runner. It gains two new responsibilities: surfacing ADR/PDR acceptance signals consumed by the Strategic source (D4); generating or queuing Reactive packet candidates from drift/incidents/scans (D4).
- **ADR-0086** (pull-based local Grid Agent Runner) is the execution surface for all scheduled backlog-generation sources and the weekly briefing.
- **ADR-0084** (Discord operator alerts) is the visibility surface for runner completion and urgent reactive signals.
- **ADR-0007** (agents as source of truth) governs the agent surface this ADR coordinates. No agent definition changes; this ADR composes existing agents.
- **`netrunner`, `node-audit`, `scope`, `product-strategist`, `hive-sync`** — each gains a documented scheduled invocation or runner-backed wrapper per D4.

### D9 — Staged rollout

The accepted rollout is full automation, not a manual trial:

- **Phase 1:** Accept the ADR, create the `proposed/`, audit, scout, and briefing surfaces, and add the source/generator packet contract.
- **Phase 2:** Register all four ADR-0086 backlog-generation jobs, their Codex prompts, Discord routing rows, and Task Scheduler defaults.
- **Phase 3:** Let weekly PRs prove signal quality. Tune cadence, prompt strictness, and deduplication in follow-up packets rather than leaving sources manual.
- **Phase 4:** Expand reactive inputs beyond drift as the upstream emitters mature: CVEs, incidents, and canary failures.

Each source still has a quality gate, but the runner jobs exist from the start. The control point is PR review plus `proposed/` triage, not withholding automation.

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
- `priority: urgent` reactive packets require an out-of-band notification mechanism. ADR-0086 supplies that mechanism through Discord notifications governed by ADR-0084 / `constitution/alert-routing.md`; `generated/briefings/urgent.md` remains the durable rolling file.
- Sources will sometimes recommend conflicting work (a Tactical audit finding contradicting a Strategic ADR direction). Triage at the weekly briefing is the resolution point; the ADR wins.

### Follow-up Work

- Create the new directories: `generated/issue-packets/proposed/`, `generated/audits/`, `generated/scout-reports/`, `generated/briefings/`.
- Author `initiatives/audit-rotation.md` with the initial 12-Node rotation order.
- Amend `hive-sync` for the ADR-acceptance trigger and drift-to-packet conversion (per D8).
- Amend `copilot/issue-authoring-rules.md` to require the `source` and `generator` frontmatter fields.
- Add ADR-0086 runner job specs and Codex prompts for Strategic, Tactical, Opportunistic, and Weekly Briefing automation.
- Add Discord alert-routing rows and runner notification summaries for backlog-generation jobs.
- Phase 1 kickoff: run `backlog-strategic-scope` against currently Accepted decisions with missing implementation packets, starting with the ADR-0034 through ADR-0042 wave where still relevant.

## Alternatives Considered

### Continue manual sourcing indefinitely

Rejected. The Grid's scope (12+ live Nodes, expanding) and the studio's headcount (1 developer) make manual sourcing a hard throughput cap. The current state — most repos under-improved relative to their potential — is the failure mode being addressed.

### A single "backlog generator" agent that owns all sources

Rejected. Each source has different inputs, different cadences, and different failure modes; collapsing them into one agent obscures the rules per source and conflates "audit a Node" with "scope an ADR" with "find market opportunities." The existing per-source agents are correctly factored; the missing piece is the coordination layer this ADR provides.

### Skip the `proposed/` directory; agents create GitHub issues directly

Rejected. The agent-generated → human-triaged gate is the single most important quality control in the design. Removing it means agent noise becomes GitHub issue spam, which then has to be triaged in GitHub (worse UX than triaging local files) or accepted as work the team didn't actually choose. The friction of `proposed/` → `active/` is the feature.

### Keep the execution surface deferred

Rejected by the 2026-06-02 acceptance amendment. ADR-0086 now provides the reversible local-runner substrate that did not exist when the proposed text was written. Keeping the surface deferred would preserve the manual bottleneck this ADR exists to remove.

### Daily briefing instead of weekly

Considered and rejected per D5. Daily is the right cadence for a multi-developer team where work needs handoff at end-of-day. For a solo + agents shop, daily becomes interruption; weekly is the cadence where signal exceeds noise.

### Bi-weekly briefing instead of weekly

Considered. Cheaper on human attention. Rejected on responsiveness: reactive-source packets (especially security CVEs) need at most a week of triage delay, and the weekly briefing is what surfaces them. Bi-weekly is the fallback if weekly proves heavier than expected (D5 Operational Consequences).

### Use GitHub Projects as the `proposed/` surface instead of a directory

Rejected. The packet-as-markdown-file pattern is what makes the downstream pipeline (refine, file-issues, scope) work; it is also what makes packets reviewable in a PR. GitHub Projects is the right surface for `active/` (and is per ADR-0008); using it for `proposed/` would split the packet-authoring tooling across two surfaces unnecessarily.
