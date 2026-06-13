---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0085", "wave-1"]
dependencies: []
adrs: ["ADR-0085", "ADR-0007", "ADR-0014", "ADR-0043", "ADR-0044", "ADR-0081"]
accepts: ["ADR-0085"]
source: strategic
generator: scope
wave: 1
initiative: adr-0085-docs-sync
node: honeydrunk-architecture
---

# Accept ADR-0085, author `.claude/agents/docs-sync.md`, wire capability matrix, seed report directory, schedule OpenClaw Friday run

## Summary
Flip ADR-0085 from Proposed to Accepted, author the `docs-sync` agent definition under `.claude/agents/` per ADR-0007, add a row to `constitution/agent-capability-matrix.md` for `docs-sync`, expand the Execution Rules cross-repo-PR-authority list, seed `generated/docs-sync-reports/` with a README, and wire the Friday OpenClaw scheduled trigger. This is the Phase-1 plumbing packet — the agent runs in **report-only mode** at the end of this packet; no cross-repo PR authority is granted yet (Phase 2 lands that in packet 02).

## Context
ADR-0085 (Grid-Wide Documentation Currency Agent) is the Phase-1 acceptance gate for the whole `docs-sync` initiative. Every subsequent packet (01a, 02–06) references ADR-0085's decisions as live rules, so the acceptance flip must land first. ADR-0085 D8 explicitly defines Phase 1 as **agent definition + capability matrix wiring + report directory + GitHub App registration + OpenClaw scheduling + report-only run**. This packet covers all of Phase 1 **except** the GitHub App registration, which is broken into packet 01a as a discrete portal-heavy `Actor=Human` work unit (the agent-definition work in this packet is delegable; the App registration is not).

This is a docs/governance/agent-definition packet. No .NET project, no runtime code, no public API change. `Actor=Agent`.

## Scope
- `adrs/ADR-0085-grid-wide-documentation-currency-agent.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` (or the ADR index in use) — update the ADR-0085 row to Accepted.
- `.claude/agents/docs-sync.md` (new) — author the agent per ADR-0085 D1, D2, D3, D4, D5, D6, D7 with the tool list from D1 (`Read`, `Grep`, `Glob`, `Bash`, `Edit`, `Write`, `TodoWrite`). Phase-1 scope only: the agent definition documents all six phases for forward reference but the **active-phase guard** at the top of the agent prompt limits runtime behavior to Phase 1 (report-only, no cross-repo PR authority).
- `constitution/agent-capability-matrix.md` — add a new row for `docs-sync` between `hive-sync` and the closing material; expand the **Execution Rules** "agents authorized for cross-repo PR creation" sentence to name `docs-sync` (alongside the existing `file-issues` and `hive-sync`); update the Decision Tree section to add a `docs-sync` branch; update the Context Load Order's agent-specific table to add a `docs-sync` row listing the catalogs and per-repo files the agent reads; update the Artifact Map to include `docs-sync → generated/docs-sync-reports/{YYYY-MM-DD}.md` and (later phases) `→ per-repo PRs` and `→ generated/work-items/proposed/{date}-{repo}-docs-{slug}.md`.
- `generated/docs-sync-reports/README.md` (new) — directory seed explaining the format, retention policy ("no pruning at v1; revisit after 6 months" per ADR-0085 Operational Consequences), and that one file lands per Friday run.
- `infrastructure/openclaw/` (existing dir) — add or extend the `docs-sync` schedule entry for the Friday slot. ADR-0085 D6 says "weekly, Friday," consistent with `hive-sync`'s OpenClaw scheduling and explicitly avoiding the Monday/Thursday `hive-sync` slot. The actual schedule wiring follows the existing pattern in `infrastructure/openclaw/` and references ADR-0081 for the home-server execution surface.
- `initiatives/active-initiatives.md` — register the `adr-0085-docs-sync` initiative with this initiative's packet checklist (packets 01, 01a, 02–06).

## Proposed Implementation

### ADR flip mechanics
1. Edit `adrs/ADR-0085-grid-wide-documentation-currency-agent.md`: change the header line `**Status:** Proposed` to `**Status:** Accepted`.
2. Update the ADR index row for ADR-0085 to Accepted.
3. Do **not** add any new numbered invariant in this packet. ADR-0085 D9 names three invariant candidates (A, B, C) but explicitly defers the decision to the Phase 6 acceptance packet (packet 06) so the operator can observe the agent's behavior before locking the rigidity in.

### Author `.claude/agents/docs-sync.md`
Follow the `.claude/agents/hive-sync.md` shape (which is the closest precedent per ADR-0085 D1, D5). The agent file must include:

- Frontmatter: `name: docs-sync`, `description:` (the one-line role per ADR-0085 D1), `tools:` (`Read`, `Grep`, `Glob`, `Bash`, `Edit`, `Write`, `TodoWrite`).
- A top-of-file **active-phase guard** stating the current rollout phase (Phase 1: report-only). The agent's runtime behavior is gated on this guard. The guard is updated by packets 02–05 as each phase activates. Until packet 02 lands, the guard rejects any attempt to invoke `gh pr create` against a target repo.
- Sections matching the structure of `hive-sync.md`: Studio Philosophy reference, Update Workflow with numbered Steps, dedup rules (D7), interaction-with-other-agents table (D5), fallback packet path (D4).
- The **two write surfaces** description from ADR-0085 D4: (a) the per-repo PR (deferred to Phase 2; guard rejects in Phase 1); (b) the Architecture-repo report PR at `generated/docs-sync-reports/{YYYY-MM-DD}.md` with stable branch name `chore/docs-sync-report-{YYYY-MM-DD}`.
- **Six detection categories** (D3) authored verbatim with their severity (`block`/`warn`/`note`), each with the example checks from the ADR.
- The **dedup rules** from D7 in full: append-only-by-date reports, stable per-repo branch reuse, auto-fix idempotency, editorial-finding packet dedup against existing `proposed/` packets with `generator: docs-sync`, sticky "first surfaced" date, `block`-severity no-grace-period exception, PR-failure backoff after 3 consecutive runs.
- A **boundaries** section enumerating what the agent does NOT touch: in-product OpenAPI (Scalar; ADR-0075 D1), per-Node Docusaurus sites (ADR-0075 D2), Studios marketing site (`site-sync`; ADR-0075 D3), Architecture repo's internal tracking files (`hive-sync`; ADR-0014), XML doc comments (Invariant 13).

### Capability matrix wiring
- Add a new row for `docs-sync` to the matrix table in `constitution/agent-capability-matrix.md`. Columns: Trigger ("OpenClaw scheduled Friday or manual dispatch"); Consumes (catalogs/*.json, per-repo READMEs/CHANGELOGs/AGENTS.md/CLAUDE.md/`.github/copilot-instructions.md`/`docs/`, `*.csproj` files, prior run report); Produces (per-run report at `generated/docs-sync-reports/{YYYY-MM-DD}.md`; mechanical-fix cross-repo PRs in Phase 2+; fallback `proposed/` packets for editorial findings); Does NOT do (touch in-product OpenAPI, Docusaurus, Studios site, Architecture-repo tracking files, XML doc comments; merge PRs; promote `proposed/` → `active/`).
- Update the Execution Rules paragraph that names `file-issues` and `hive-sync` as the only agents authorized for cross-repo writes — add `docs-sync` to the list, with the bounded-scope qualifier (mechanical exact-string drift only; editorial work falls back to `proposed/`).
- Update the Decision Tree to add: "Is documentation drift suspected Grid-wide? → docs-sync (OpenClaw scheduled Friday)."
- Update the Context Load Order table to add a `docs-sync` row listing the catalogs and per-repo files the agent reads (the read list from ADR-0085 D2).
- Update the Artifact Map to add `docs-sync → generated/docs-sync-reports/{YYYY-MM-DD}.md (always) + cross-repo PRs (Phase 2+) + proposed/{date}-{repo}-docs-{slug}.md (fallback)`.

### Seed `generated/docs-sync-reports/`
- Create `generated/docs-sync-reports/README.md` documenting:
  - One file per Friday run, named `{YYYY-MM-DD}.md`, append-only by date (D7).
  - Format: a section per Node listing all findings (whether or not auto-fixed), links to the per-repo PR opened (or skipped, with reason), and a Grid-wide summary.
  - The report is committed to Architecture via a small PR `chore/docs-sync-report-{YYYY-MM-DD}` using the same authoring discipline as `hive-sync`'s reconciliation PR.
  - No pruning policy at v1; revisit after 6 months per ADR-0085 Operational Consequences.

### OpenClaw schedule
- Add a `docs-sync` schedule entry under `infrastructure/openclaw/` for the Friday slot. Reference the existing `hive-sync` schedule entries (Monday + Thursday per ADR-0014 / ADR-0081) as the precedent shape — same OpenClaw scheduled-trigger format, different cron.
- The schedule entry's payload invokes the `docs-sync` agent in Phase-1 mode (report-only). The manual cadence is the floor per ADR-0043 D7's deferral pattern; the agent runs manually on the Friday cadence until the OpenClaw scheduled trigger is observed firing reliably.

### Register the initiative
- `initiatives/active-initiatives.md` — add an `adr-0085-docs-sync` block with the packet checklist (01, 01a, 02, 03, 04, 05, 06). The `hive-sync` agent will reconcile the checklist as packets close.

## Affected Files
- `adrs/ADR-0085-grid-wide-documentation-currency-agent.md` (flip Status)
- `adrs/README.md` (or the ADR index file in use)
- `.claude/agents/docs-sync.md` (new)
- `constitution/agent-capability-matrix.md`
- `generated/docs-sync-reports/README.md` (new)
- `infrastructure/openclaw/` (new or extended schedule entry — match the file shape used for `hive-sync`)
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files and an OpenClaw schedule entry; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.
- [x] No new GitHub Actions workflow in HoneyDrunk.Actions (ADR-0085 Affected Nodes explicitly says no `HoneyDrunk.Actions` change at v1).

## Acceptance Criteria
- [ ] ADR-0085 header reads `**Status:** Accepted`
- [ ] ADR index row for ADR-0085 reflects Accepted
- [ ] `.claude/agents/docs-sync.md` exists and follows the `hive-sync.md` shape, with frontmatter, active-phase guard limiting runtime to Phase 1 (report-only, no cross-repo PR authority), Update Workflow steps, dedup rules from D7, interaction-with-other-agents table from D5, fallback packet path from D4, six detection categories from D3 with severities, and the boundaries section enumerating what is NOT touched
- [ ] `constitution/agent-capability-matrix.md` has a new `docs-sync` row in the matrix table, the Execution Rules paragraph names `docs-sync` as a cross-repo-PR-authorized agent (with the bounded-scope qualifier), the Decision Tree includes a `docs-sync` branch, the Context Load Order table has a `docs-sync` row, and the Artifact Map includes the `docs-sync` outputs
- [ ] `generated/docs-sync-reports/README.md` exists and documents the file-per-run convention, format, branch-naming, and the "no pruning at v1; revisit after 6 months" policy
- [ ] OpenClaw schedule entry for `docs-sync` Friday run is present under `infrastructure/openclaw/` and references ADR-0081 for the execution surface
- [ ] `initiatives/active-initiatives.md` registers the `adr-0085-docs-sync` initiative with a checklist of packets 01, 01a, 02–06
- [ ] **No new numbered invariant added in this packet.** D9 candidates A/B/C are deferred to packet 06 per ADR-0085 D8 Phase 6 and D9.
- [ ] The repo-level `CHANGELOG.md` carries a new entry for this change (per invariant 12 — Architecture repo's CHANGELOG entry covers ADR-0085 acceptance + agent + capability-matrix expansion in a single coherent entry)
- [ ] No README update required at repo root (the agent definition is an internal artifact, not a public-API or install-surface change)

## Human Prerequisites
- [ ] Confirm the active-phase guard wording in `.claude/agents/docs-sync.md` reads correctly before merge — the guard is the safety mechanism that prevents the agent from acting beyond its current rollout phase. The wording must be unambiguous: until packet 02 lands and updates the guard, any attempted `gh pr create` against a target repo is refused by the agent itself.
- [ ] Confirm the OpenClaw Friday slot does not collide with any other scheduled agent (current schedule: `hive-sync` Monday + Thursday per ADR-0014; Friday is unclaimed).

## Dependencies
None. This is the first packet in the initiative.

## Referenced ADR Decisions

**ADR-0085 D1** — Stand up `docs-sync` as a new Meta-sector agent at `.claude/agents/docs-sync.md` per ADR-0007 source-of-truth convention. Tools: Read, Grep, Glob, Bash, Edit, Write, TodoWrite. Hosting: Architecture repo, same pattern as `hive-sync` and `site-sync`.
**ADR-0085 D2** — Scope of documentation surfaces the agent owns (root + per-package README, root + per-package CHANGELOG, AGENTS.md, CLAUDE.md, `.github/copilot-instructions.md`, `docs/`). Existence + accuracy checks. v1 accuracy is the **tractable cut**: symbol lookup, string comparison, catalog cross-reference, version comparison, dependency-graph cross-check, install-snippet syntactic check (no `dotnet add` execution).
**ADR-0085 D3** — Six detection categories with severities (`block`/`warn`/`note`): (1) missing required artifacts, (2) version drift, (3) symbol-reference drift, (4) catalog-reference drift, (5) dependency-graph drift, (6) agent-instruction drift. Ordered most-signal-dense-first.
**ADR-0085 D4** — Authority model: direct cross-repo PRs (Phase 2+) + per-run report in Architecture. Branch naming `chore/docs-sync-{YYYY-MM-DD}`. Editorial findings fall back to `proposed/{YYYY-MM-DD}-{repo}-docs-{slug}.md` packets per the standard `copilot/issue-authoring-rules.md` format with `source: reactive`, `generator: docs-sync` frontmatter.
**ADR-0085 D5** — Interaction with `hive-sync`, `site-sync`, `node-audit`, `scope`, `review`, `netrunner`, `file-issues`. Strictly disjoint write surfaces with `hive-sync`. Adjacent and complementary to `site-sync`. Complementary to `node-audit`. Downstream of fallback packet path for `scope`. Per-PR review for every docs-sync PR via `review` (ADR-0044 D7 PR-size discipline applies).
**ADR-0085 D6** — Cadence: weekly, Friday. Full sweep, not event-driven. Execution surface: OpenClaw scheduled trigger per ADR-0081, with manual dispatch supported. ADR-0043 D7 deferral pattern honored — manual cadence is the floor until OpenClaw scheduling lands.
**ADR-0085 D7** — Dedup and noise control rules. Single most important quality control.
**ADR-0085 D8** — Six-phase rollout. **Phase 1: agent definition + matrix wiring + report directory + GitHub App registration + OpenClaw scheduling + report-only run** (this packet covers all of Phase 1 except the App, which is packet 01a).
**ADR-0085 D9** — Three candidate invariants A/B/C. **Decided in packet 06 (Phase 6), not this packet.**
**ADR-0007** — `.claude/agents/` source-of-truth convention; the agent file lives in `HoneyDrunk.Architecture/.claude/agents/`.
**ADR-0014 D7** — `hive-sync` auto-flips Proposed ADRs to Accepted when their `accepts:` packets all close. This packet's `accepts: ["ADR-0085"]` frontmatter is the wiring; the auto-flip fires once all packets in this initiative close.
**ADR-0043 D3** — Three-state packet lifecycle `proposed/` → `active/` → `completed/`. Agents never self-promote; humans triage `proposed/` → `active/` at the weekly briefing (D5).
**ADR-0043 D7** — Execution-surface deferral pattern; manual cadence is the floor.
**ADR-0081** — OpenClaw home-server execution surface for scheduled agent runs.

## Constraints
> **Invariant 12 (excerpt):** Every package directory must contain a `README.md` describing the package's purpose, installation, and public API surface. Two tiers of CHANGELOG.md (repo-level + per-package). New projects must have both files from the first commit.

> **Invariant 23:** Every tracked work item has a GitHub Issue in its target repo. No work tracked exclusively in packet files, chat logs, or external tools.

> **Invariant 24:** Work items are immutable once filed as a GitHub Issue. Pre-filing amendments are permitted to fill in missing operational context; post-filing corrections require a new packet.

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled. (Not directly violated here; `docs-sync` is a third agent with its own context contract, but the principle of explicit context loading applies.)

> **ADR-0043 D3 (verbatim):** Agents never self-promote `proposed/` → `active/`. This packet does not change that. `docs-sync`'s cross-repo PR authority (Phase 2+) is a **different surface entirely** — it is reconciliation of shared truth into target repos, not promotion of agent-generated work inside the Architecture repo's packet lifecycle.

- **Acceptance precedes flip.** ADR-0085 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Do not grant cross-repo PR authority in this packet.** The active-phase guard in the agent file must reject any `gh pr create` against a target repo until packet 02 updates the guard. Phase 1 is **report-only**.
- **Do not author any new numbered invariant in this packet.** D9 candidates A/B/C are decided in packet 06 (Phase 6).
- **Do not change `HoneyDrunk.Actions`.** ADR-0085 Affected Nodes explicitly says no change at v1; Authorship-enum addition is a Phase-6 decision.
- **PR metadata for the implementation PR:** `Authorship: agent-claude-code` + `Work Item: HoneyDrunkStudios/HoneyDrunk.Architecture#<issue-number>` once filed. No `Out-of-band reason:`.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0085`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0085 to Accepted, author the `docs-sync` agent definition (Phase-1-guarded, report-only), wire the capability matrix, seed the report directory, register the Friday OpenClaw schedule, and register the initiative in trackers.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land Phase 1 of ADR-0085 — agent exists, can be invoked, produces a useful report; no cross-repo PR authority yet.
- Feature: Grid-Wide Documentation Currency Agent rollout, Phase 1 (plumbing).
- ADRs: ADR-0085 (primary, all Decisions), ADR-0007 (agent source-of-truth), ADR-0014 (`hive-sync` precedent), ADR-0043 (`proposed/` lifecycle), ADR-0044 (Authorship enum), ADR-0081 (OpenClaw execution surface).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- Acceptance precedes flip — ADR-0085 stays Proposed until this PR merges.
- Active-phase guard in agent file is mandatory; without it, the agent could act beyond Phase 1 scope.
- No cross-repo PR authority granted in this packet (deferred to packet 02).
- No new numbered invariants in this packet (D9 deferred to packet 06).
- No `HoneyDrunk.Actions` change (deferred to packet 06's Authorship-enum decision).

**Key Files:**
- `adrs/ADR-0085-grid-wide-documentation-currency-agent.md`
- `adrs/README.md`
- `.claude/agents/docs-sync.md` (new)
- `.claude/agents/hive-sync.md` (precedent shape; do not edit)
- `constitution/agent-capability-matrix.md`
- `generated/docs-sync-reports/README.md` (new)
- `infrastructure/openclaw/` (existing dir; match `hive-sync` schedule entry shape)
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
