# ADR-0014: Hive–Architecture Reconciliation Agent

**Status:** Proposed
**Date:** 2026-04-16
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

## Context

The Architecture repo's sync story was designed when the only source of GitHub issues was the scope → file-issues pipeline. The `initiatives-sync` agent runs Monday and Thursday, reads `filed-packets.json`, queries live issue states via `gh`, and reconciles five initiative tracking files (`active-initiatives.md`, `current-focus.md`, `releases.md`, `roadmap.md`, `archived-initiatives.md`). That loop was complete when packets were the only way work entered the system.

Two developments have broken that assumption:

1. **The nightly security job (ADR-0009, ADR-0012) now creates issues directly in target repos.** The `hive-field-mirror` workflow (landed via Actions#22) fires on `issues.opened` and wires these issues into The Hive with correct Node, Wave, and Tier fields. The issues are real work items with board presence, but the Architecture repo knows nothing about them — they have no packets, no initiative association, and no entry in any tracking file.

2. **Issue packets have no lifecycle completion step.** When a filed issue is closed on GitHub, `initiatives-sync` checks it off in the initiative tracking files, but the source packet is not reconciled through a defined Architecture-side packet lifecycle. The `generated/issue-packets/completed/` tree already exists and contains completed packets, but there is no agent or automated step that consistently moves newly completed packets out of `active/` and keeps the two trees aligned with live GitHub issue state. Over time, `active/` accumulates closed work alongside open work, and any agent or human reading the directory cannot distinguish live packets from historical ones without cross-referencing GitHub issue state.

Together these gaps mean the Architecture repo is drifting from being the "command center" (ADR-0002) toward being a partial view that only tracks initiative-scoped work and never cleans up after itself.

A third, softer pressure: as the Grid grows, more non-initiative issue sources are likely — dependency update PRs that auto-file issues, future observability alerts, the grid-health aggregator's per-repo failure issues (ADR-0012 D6). Each new source widens the gap between "what's on The Hive" and "what Architecture knows about." Closing the gap once, structurally, is cheaper than patching it per-source.

The `initiatives-sync` agent is the natural home for this work — it already owns the "read live issue state, update Architecture files" loop. But its current mandate is too narrow: it only reads issues that appear in `filed-packets.json`, and it only writes to initiative tracking files. Broadening its mandate to cover all Hive items and the packet lifecycle is the subject of this ADR.

Sector is **Meta**, consistent with ADR-0002 (Architecture as command center), ADR-0007 (agent definitions), and ADR-0008 (work tracking).

## Decision

### D1 — The `initiatives-sync` agent is superseded by a `hive-sync` agent with broader mandate

The current `initiatives-sync` agent (`.claude/agents/initiatives-sync.md`) is replaced by a `hive-sync` agent that retains all of `initiatives-sync`'s responsibilities and adds four new ones:

1. **Initiative reconciliation** — unchanged from today. Read `filed-packets.json`, query issue states, update initiative tracking files.
2. **Packet lifecycle management** — move completed packets from `active/` to `completed/`. See D2.
3. **Non-initiative issue tracking** — ensure all issues on The Hive that did not originate from packets are tracked in a new Architecture surface. See D3.
4. **Proposed-ADR acceptance queue** — surface ADRs still in `Status: Proposed` so the scope agent can be run on them. See D6.

The agent retains the Monday/Thursday schedule (and manual trigger). The name change from `initiatives-sync` to `hive-sync` reflects the broadened scope and makes it discoverable — agents reading the capability matrix can infer from the name that this agent covers The Hive board holistically, not just initiative-linked issues.

The old `initiatives-sync.md` agent file is deleted, not kept as a redirect. The capability matrix (`constitution/agent-capability-matrix.md`) is updated in the same PR that lands the new agent definition.

### D2 — The `hive-sync` agent moves completed packets to `completed/`

When the agent discovers that a filed issue is closed (via `gh issue view`), and the issue's packet still exists under `generated/issue-packets/active/`, the agent moves the packet file to `generated/issue-packets/completed/`.

Rules:

- **Move, not copy.** The packet leaves `active/` entirely. A reader of `active/` can trust that everything there represents open work.
- **Preserve the filename.** The file keeps its original name (e.g., `01-vault-bootstrap-extensions.md` → `completed/01-vault-bootstrap-extensions.md`). If a name collision occurs in `completed/` (unlikely, since packets are date-prefixed or initiative-scoped), the agent prefixes the initiative slug: `adr-0005-0006-rollout--01-vault-bootstrap-extensions.md`.
- **Initiative subdirectories.** When all packets in an initiative subdirectory under `active/` have been moved to `completed/`, the agent also moves the `dispatch-plan.md` to `completed/` and removes the now-empty initiative subdirectory.
- **`filed-packets.json` is updated.** The path key in `filed-packets.json` is updated to reflect the new location under `completed/`. This keeps the mapping accurate for any agent that reads it. This is a narrow exception to the current convention that `filed-packets.json` is only written by the `file-issues` agent — the `hive-sync` agent may update existing entries' paths but may not add or remove entries.
- **Standalone packets** (under `active/standalone/`) follow the same rule: closed issue → move to `completed/`.
- **The PR includes the moves.** Packet moves are committed in the same PR as initiative tracking updates, so the entire sync is atomic and reviewable.

### D3 — Non-initiative issues on The Hive are tracked in `initiatives/board-items.md`

A new file, `initiatives/board-items.md`, tracks issues on The Hive that did not originate from the packet pipeline. These include:

- Issues created by the nightly security job (`security` + `automated` labels)
- Issues created by the grid-health aggregator (ADR-0012 D6, `[grid-health]` title prefix)
- Any other issue added to The Hive that has no corresponding entry in `filed-packets.json`

The file structure:

```markdown
# Board Items — Non-Initiative Work

Tracked automatically by the hive-sync agent. Items listed here are on
The Hive but did not originate from a scoped issue packet.

Last synced: {YYYY-MM-DD}

## Open

| Issue | Repo | Node | Labels | Opened | Status |
|-------|------|------|--------|--------|--------|
| [#42 🔒 Nightly Security Scan - ...](url) | Vault | Vault | security, automated | 2026-04-15 | Backlog |

## Recently Closed

| Issue | Repo | Node | Labels | Opened | Closed |
|-------|------|------|--------|--------|--------|
| [#38 🔒 Nightly Security Scan - ...](url) | Auth | Auth | security, automated | 2026-04-10 | 2026-04-12 |
```

Rules:

- **The agent queries The Hive board via GraphQL** (`gh api graphql`) to list all items, then subtracts the set of issues known from `filed-packets.json`. The remainder are non-initiative items.
- **Open items are always listed.** Closed items are listed in "Recently Closed" for 30 days after closure, then removed. This keeps the file from growing unboundedly while preserving short-term audit trail.
- **The agent does not set or modify Hive fields.** That remains the mirror action's job (for auto-wired issues) or the file-issues agent's job (for packets). The `hive-sync` agent is read-only with respect to The Hive board — it reads state and writes to Architecture files, never the reverse.
- **No initiative association is assigned.** These items are explicitly non-initiative work. If a non-initiative item is later scoped into an initiative (e.g., a recurring security finding spawns a remediation initiative), the scope agent creates packets, and the item naturally moves from `board-items.md` into the initiative tracking files on the next sync.

### D4 — The `hive-sync` agent is the single agent authorized to move packets between lifecycle directories

No other agent may move files between `active/` and `completed/`. The `scope` agent writes to `active/`. The `file-issues` agent reads from `active/` and writes to `filed-packets.json`. The `hive-sync` agent is the only agent that moves files out of `active/`. This keeps the packet lifecycle linear and avoids race conditions between agents.

The lifecycle is:

```
scope writes packet → active/
file-issues files issue → filed-packets.json updated, packet unchanged
issue lives on GitHub / The Hive
issue closes on GitHub
hive-sync moves packet → completed/, updates filed-packets.json path
```

### D5 — The capability matrix and agent tooling are updated

The `constitution/agent-capability-matrix.md` is updated:

- Remove the `initiatives-sync` row.
- Add a `hive-sync` row with:
  - **Trigger:** Monday/Thursday schedule, manual
  - **Consumes:** `filed-packets.json`, GitHub issue states (gh CLI), The Hive board state (GraphQL), `grid-health.json`, `nodes.json`, initiative tracking files, `adrs/ADR-*.md` frontmatter
  - **Produces:** Updated initiative tracking files, packet moves (active → completed), `board-items.md`, `proposed-adrs.md`, PR
  - **Sync Responsibility:** Reconciles Architecture repo tracking with live GitHub/Hive state; manages packet lifecycle; tracks non-initiative board items; surfaces the Proposed-ADR acceptance queue

The `hive-sync` agent's tool list is unchanged from `initiatives-sync`: Read, Grep, Glob, Edit, Write, Bash, TodoWrite. No new tools are required — the added responsibilities use the same `gh` CLI and file operations the agent already has access to.

### D6 — Proposed ADRs awaiting scope-agent acceptance are tracked in `initiatives/proposed-adrs.md`

The ADR lifecycle is: draft authored → filed as Proposed in `/adrs/` → PR merged → scope agent runs → status flipped to Accepted. There is no current surface showing which merged-but-Proposed ADRs are waiting for a scope run, so they tend to sit in Proposed longer than intended.

The `hive-sync` agent closes this gap by maintaining `initiatives/proposed-adrs.md`. On every run:

1. Scan `adrs/ADR-*.md` for files with a `**Status:** Proposed` frontmatter line.
2. For each match, extract the ADR number, title, sector, and date.
3. Write the results to `initiatives/proposed-adrs.md` using this structure:

```markdown
# Proposed ADRs Awaiting Acceptance

Tracked automatically by the hive-sync agent. These ADRs are on `main` in
Proposed state and are waiting for a scope-agent run to flip them to Accepted.

Last synced: {YYYY-MM-DD}

| ADR | Title | Sector | Dated | Days in Proposed |
|-----|-------|--------|-------|------------------|
| [ADR-0014](../adrs/ADR-0014-hive-architecture-reconciliation-agent.md) | Hive–Architecture Reconciliation Agent | Meta | 2026-04-16 | 2 |
```

Rules:

- **Presence on `main` is sufficient.** The agent does not try to correlate to the originating PR — if the ADR file is on `main` and still Proposed, it qualifies. This is simpler than reasoning about PR state and matches reality: scope runs are what flip status, not PR merges.
- **The file is fully rewritten each run.** No append-only history — the list reflects current reality. If Proposed ADRs persist for months, the `Days in Proposed` column surfaces the staleness without the agent needing its own state.
- **Draft ADRs are ignored.** Files under `generated/adr-drafts/` are explicitly excluded — those are pre-PR and not ready for scope-agent runs.
- **Empty state is a single line, not a missing file.** When no Proposed ADRs exist, the table is replaced with `_No Proposed ADRs — the queue is clear._` so the file itself still exists as a known location.

This is intentionally a lightweight workflow surface, not an invariant. There is no rule requiring Proposed ADRs to be accepted within N days — the file is a reminder, not an enforcement.

### D7 — The `hive-sync` agent auto-accepts ADRs and PDRs whose implementing work is complete

Building on D6's surface, the agent **mutates** ADR/PDR Status frontmatter when the conditions for acceptance are met.

**A new `accepts:` packet frontmatter field is introduced** to disambiguate "this packet implements this decision" from "this packet references this decision." The existing `adrs:` field continues to mean "this packet references these ADRs" (used by Step 11f / drift category 5 for ADR-named-Node detection); the new `accepts:` field means "closing all of this packet's issues, together with closing the issues of every other packet that lists this decision in its `accepts:`, is the implementation completion signal." Most packets either have an empty `accepts:` (e.g., a hardening packet that touches an Accepted ADR's surface but doesn't implement a Proposed decision) or list the Proposed ADR/PDR they are part of implementing.

The auto-flip rule:

For each `adrs/ADR-*.md` file with `**Status:** Proposed`:

1. Find every packet under `generated/issue-packets/active/**/*.md` and `generated/issue-packets/completed/**/*.md` whose YAML frontmatter `accepts:` field contains the ADR's number (e.g., `accepts: ["ADR-0011"]`). Packets with no `accepts:` field, or whose `accepts:` list is empty, are not implementers — they may have an `adrs:` reference but they do not gate acceptance.
2. For each such packet, look up its GitHub issue state from `/tmp/issue-states.json`.
3. Decide:
   - **At least one packet exists AND every implementing issue is `closed`:** flip the ADR's `**Status:** Proposed` line to `**Status:** Accepted` and update the matching row in `adrs/README.md` (Status column).
   - **At least one packet exists AND any implementing issue is `open`:** the ADR appears in `proposed-adrs.md` with the closed/open count in a new column.
   - **No implementing packet exists:** the ADR appears in `proposed-adrs.md` as "Awaiting" — no packets means no work has been scoped yet, and the agent does not auto-flip. **This includes ADRs whose implementing packets pre-date Packet 05** — those packets do not carry `accepts:` (the convention is new), so legacy ADRs stay manually-flippable via the scope agent until rescoped with `accepts:`-bearing packets.

The same rule applies to `pdrs/PDR-*.md` against `pdrs/README.md`. PDRs use the same `**Status:** Proposed` / `**Status:** Accepted` convention. The `accepts:` field can list both ADR and PDR identifiers (e.g., `accepts: ["ADR-0026", "PDR-0002"]`) — the field's semantic is "this packet is part of accepting these decisions."

**Why introduce a new field instead of repurposing `adrs:`.** Today's `adrs:` field is used loosely as a "decisions referenced by this packet" cataloging field. Repurposing it as an implementing-packet declaration would silently change the semantics of every existing filed packet (per invariant 24, those bodies are immutable), retroactively making them auto-flip eligible on the first run. The new `accepts:` field is opt-in: only packets authored with the new convention count toward auto-flip, eliminating the historical-data cascade risk. The `adrs:` field remains useful for drift detection and human-readable cross-referencing.

**Why a packet-existence guard is necessary.** Some ADRs are pure documentation decisions with no implementing work (e.g., a clarifying ADR about an existing convention). Auto-flipping those without a packet present would mean any Proposed ADR with no packets could be flipped immediately on the next run, defeating the scope-agent acceptance step. The guard ("at least one packet exists") forces every Proposed ADR to be either (a) actively scoped via packets carrying `accepts:`, or (b) explicitly listed in `proposed-adrs.md` as "Awaiting" — never silently accepted.

**Why this is not bidirectional sync.** D7 *does* mutate ADR/PDR files, which is a reversal of the read-only stance D6 took for files under `adrs/`. The reversal is bounded:

- The agent only flips `Proposed` → `Accepted`. It never flips the reverse direction (Accepted → Proposed → ... ) and never edits the ADR body. The flip is a one-line frontmatter edit.
- The trigger is unambiguous: all implementing GitHub issues are closed. There is no judgment call.
- Reverting is trivial: a human or scope agent can flip the Status back to `Proposed` if the auto-flip was premature, and the agent will not re-flip until a closed → re-opened → closed cycle on at least one issue. (A simple way to defeat the auto-flip until ready: leave one issue open.)
- The agent does **not** add invariants, edit catalogs, or modify any other file as part of the flip. Those edits remain the scope/adr-composer agent's responsibility (D9 only surfaces them).

The original D6 surface is preserved — `proposed-adrs.md` still lists every Proposed ADR. After D7, the file grows from a single Proposed-ADR table into a multi-section structure (the implementing packet's specific shape may evolve; current Packet 05 uses five sections: Awaiting / In Progress / Pending Flip / Anomalies / Flipped This Run). The implementing packet documents the exact shape; the ADR's intent is "the queue surfaces enough information for an operator to see at a glance which Proposed ADRs are awaiting work, which are in-progress, which were just flipped, and which exceeded the per-run flip cap."

### D8 — Index rows in `adrs/README.md` and `pdrs/README.md` are reconciled to ADR/PDR frontmatter every run

The README index files in `adrs/` and `pdrs/` carry a Status column and a Date column. Today these can drift from the ADR/PDR file's own frontmatter — a manual edit to the ADR Status that doesn't update the README leaves the index stale.

On every run, after D7 has applied any auto-flips, the agent:

1. Lists every `adrs/ADR-*.md` file and reads its `**Status:**` and `**Date:**` frontmatter.
2. Locates the corresponding row in `adrs/README.md` (matched by the ADR number link).
3. If the Status column or Date column does not match the file's frontmatter, updates the row to match. Other columns (Title, Sector, Impact) are unchanged.
4. Repeats steps 1-3 for `pdrs/PDR-*.md` against `pdrs/README.md`.

**Rules:**

- **The agent is authoritative for Status and Date columns only.** Title, Sector, and Impact columns are author-maintained and the agent does not touch them.
- **A row missing from the index is surfaced, not auto-added.** If an `ADR-*.md` file exists without a corresponding README row, the agent flags it in `proposed-adrs.md` rather than synthesizing a row — Title/Sector/Impact require human judgment.
- **A row in the index for a missing file is surfaced, not auto-deleted.** If a README row links to an ADR file that does not exist, the agent flags it. Either the file was renamed (manual cleanup needed) or the row is wrong.
- **D8 runs after D7.** Auto-flips from D7 are reflected in D8's reconciliation pass — the README row's Status column matches the post-flip frontmatter Status.

### D9 — Drift detection between ADRs/PDRs and the rest of the Architecture repo (surface-only, no auto-fix)

ADRs and PDRs name invariants, agents, nodes, contracts, and surfaces that should exist elsewhere in the repo. When an ADR is authored that names invariant `42` but `constitution/invariants.md` has only 41 entries, that's drift. When `agent-capability-matrix.md` lists an agent that has no `.claude/agents/{name}.md` file, that's drift. The agent surfaces these inconsistencies in a new file `initiatives/drift-report.md` so they can be addressed by a human or by the scope/adr-composer agents.

D9 is **read-only**. The agent never auto-fixes drift in catalogs, constitution, or anywhere outside the four mutation surfaces it is explicitly authorized to write (initiative tracking files, packet-lifecycle moves, board-items.md, proposed-adrs.md, ADR/PDR Status frontmatter, README index Status/Date columns). Auto-fixing catalogs, invariants, or capability matrix rows would require architectural judgment the agent does not have.

The drift report covers (initial scope; new categories may be added in follow-up ADRs):

1. **Invariants named in Accepted ADRs that are missing from `constitution/invariants.md`.** The agent parses each Accepted ADR for "Invariants \d+(–\d+)?" patterns and the body text describing them, then verifies each named invariant exists in `invariants.md` by textual content match. Missing invariants are listed.
2. **Rows in `constitution/agent-capability-matrix.md` whose agent file does not exist.** Every row's agent name is checked against `.claude/agents/{name}.md` — missing files are listed.
3. **Agent files in `.claude/agents/` with no row in the capability matrix.** Excluding meta agents (`adr-composer`, `pdr-composer`, etc., enumerated in `constitution/agent-capability-matrix.md`'s "Decision Authority" section) — un-listed agents are surfaced as either (a) a missing matrix row, or (b) candidates for the meta-agent exclusion list.
4. **Nodes named in `catalogs/nodes.json` whose GitHub repo does not exist.** The agent runs `gh repo view HoneyDrunkStudios/{NodeRepo}` for each entry and reports missing repos. Repos confirmed missing represent either a planning-vs-reality gap or a stale catalog entry.
5. **Nodes named in Accepted ADRs that are missing from `catalogs/nodes.json`.** Pattern: ADRs that name a Node (e.g., "HoneyDrunk.AI", "HoneyDrunk.Notify.Cloud") expect that Node to be in `nodes.json`. If not, surface for catalog update.

The drift-report.md structure:

```markdown
# Drift Report

Tracked automatically by the hive-sync agent. Items listed here are
inconsistencies between Accepted decisions and the rest of the Architecture
repo. The agent surfaces these — it does not fix them. Resolution is the
scope/adr-composer/human's responsibility.

Last synced: {YYYY-MM-DD}

## Invariants Named in ADRs but Missing from `invariants.md`

| ADR | Invariant Name | First Surfaced |
|-----|----------------|----------------|
| ... | ... | ... |

## Capability Matrix Rows with No Agent File

| Agent Name | Matrix Row | First Surfaced |
|------------|------------|----------------|
| ... | ... | ... |

## Agent Files with No Capability Matrix Row

| Agent File | First Surfaced |
|------------|----------------|
| ... | ... |

## Nodes in `nodes.json` with Missing GitHub Repos

| Node | Repo | First Surfaced |
|------|------|----------------|
| ... | ... | ... |

## Nodes Named in ADRs but Missing from `nodes.json`

| ADR | Node Name | First Surfaced |
|-----|-----------|----------------|
| ... | ... | ... |

_(empty section bodies render as `_No drift detected._`)_
```

**Rules:**

- **The "First Surfaced" column is sticky.** When an item first appears in the report, the agent records the date. On subsequent runs, the date does not change unless the item disappears and reappears. This lets the operator see how stale a drift item is, similar to `Days in Proposed`.
- **The file is fully rewritten each run except the First Surfaced dates** (which are preserved across runs from the previous file's contents). This is the single exception to the "fully rewritten" rule for `hive-sync`-managed surfaces; the operator's audit trail of "how long has this been broken" is the value preserved.
- **Empty sections render as a known line, not a missing section.** `_No drift detected._` keeps the file structure stable.
- **D9 runs last** in the agent's workflow, after D7's auto-flips and D8's index sync. Drift detection sees the post-mutation state.

## Consequences

### Architectural Consequences

- **The Architecture repo becomes a complete mirror of The Hive's issue state**, not a partial view filtered to initiative work. Any agent or human reading the Architecture repo can answer "what is the Grid working on right now?" without consulting GitHub directly.
- **`generated/issue-packets/active/` becomes a reliable indicator of open work.** Completed packets no longer linger. Agents that scan `active/` for outstanding work (e.g., a future prioritization agent) can trust the directory contents.
- **`filed-packets.json` gains a second writer.** Today only `file-issues` writes to it; after this ADR, `hive-sync` also updates path entries when moving packets. The two agents write to non-overlapping concerns (file-issues adds entries, hive-sync updates paths of existing entries), so no conflict is expected, but the shared-write surface should be noted.
- **The initiative tracking files are unchanged in structure.** `hive-sync` continues to update them exactly as `initiatives-sync` did. The new tracking surfaces are `board-items.md` and `proposed-adrs.md`.
- **The ADR lifecycle gains a visibility step (D6) and an automation step (D7).** Proposed ADRs that have been merged to `main` but not yet accepted are listed in a dedicated file with age (D6). Additionally, ADRs whose implementing packets are all closed are auto-flipped to Accepted by `hive-sync` (D7) — the scope agent is no longer the only thing that flips status, but its scope is preserved for the harder cases (initial draft → Proposed, or any case requiring architectural judgment about whether the implementation actually realized the decision). Auto-acceptance is bounded: it requires implementing packets to exist and all their issues to be closed; otherwise the ADR remains Proposed.
- **The Architecture repo gains a single-page drift report (D9).** `initiatives/drift-report.md` lists inconsistencies between Accepted ADRs/PDRs and the rest of the repo (invariants, agent matrix, catalogs). The agent surfaces these but does not fix them — that remains the scope/adr-composer agent's or human's responsibility. The "First Surfaced" sticky-date column reveals long-standing drift that is silently being ignored.
- **`hive-sync`'s mutation surface area is enumerable.** After D7 and D8 land, the agent writes to: initiative tracking files (D1), packet-lifecycle moves (D2), `board-items.md` (D3), `proposed-adrs.md` (D6), ADR/PDR Status frontmatter (D7), README index Status/Date columns (D8), and `drift-report.md` (D9). Every other file in the repo is read-only with respect to `hive-sync`. The list is short and documented in the agent's Constraints; any future expansion is itself an ADR-level decision.

### Process Consequences

- **New non-initiative issue sources require no agent changes.** When a new automated process (grid-health aggregator, future dependency bots, etc.) creates issues that land on The Hive via the mirror action, `hive-sync` automatically picks them up on the next run. No per-source wiring is needed.
- **The Monday/Thursday cadence means packet moves lag by 1–3 days.** A packet whose issue closes on Tuesday moves to `completed/` on Thursday. This is acceptable — the packets are archival, not operational, and the initiative tracking files are updated in the same run.
- **Manual trigger remains available** for immediate sync after a burst of issue closures (e.g., after a wave of PRs lands).

### Grid Tracking Invariants

The following invariants should be added to `constitution/invariants.md`. The numbers shown (39, 40) are the values at the time of authorship (2026-04-16); the actual integers used at execution time are determined by the next-available position in `invariants.md` when each implementing packet lands. The implementing packets (Phases 2-3) explicitly look up the next-available number rather than hardcoding these integers, so cross-references in this ADR ("invariant 39", "invariant 40") may not match the live numbering in `invariants.md`. See `invariants.md` for the authoritative current numbering.

39. **The Architecture repo tracks all Hive board items.** Every issue on The Hive is represented in either the initiative tracking files (for packet-originated work) or `initiatives/board-items.md` (for non-initiative work). The `hive-sync` agent is responsible for maintaining this correspondence. See ADR-0014 D1, D3.

40. **Completed issue packets are moved to `completed/`.** When a filed issue is closed on GitHub, the `hive-sync` agent moves its source packet from `generated/issue-packets/active/` to `generated/issue-packets/completed/` and updates the path in `filed-packets.json`. No other agent moves packets between lifecycle directories. See ADR-0014 D2, D4.

### Follow-up Work

- **Author the `hive-sync` agent definition** at `.claude/agents/hive-sync.md`. Incorporates all current `initiatives-sync` logic plus the D2/D3/D4 additions. Single packet; medium complexity.
- **Delete `.claude/agents/initiatives-sync.md`** in the same PR as the new agent definition.
- **Create `initiatives/board-items.md`** with the initial table structure. Can be seeded by a one-time backfill run of the new agent.
- **Create `initiatives/proposed-adrs.md`** with the initial table structure. Seeded by the first hive-sync run after Phase 4 lands.
- **Create `initiatives/proposed-pdrs.md`** (or extend `proposed-adrs.md` to cover both) in Phase 5.
- **Create `initiatives/drift-report.md`** with the initial structure in Phase 6.
- **Update `constitution/agent-capability-matrix.md`** to reflect the agent rename and expanded responsibilities.
- **Update `constitution/invariants.md`** with invariants 39–40 (Phases 2-3) and any additional invariants the auto-acceptance logic warrants (Phase 5; the bounded ADR/PDR write authorization may deserve invariant status).
- **Backfill `completed/` directory** by running the new agent against all currently-closed issues in `filed-packets.json`. One-time operation.
- **Add `Initiative` select option** for non-initiative values (e.g., `N/A` or `operational`) on The Hive, if one does not already exist, so the mirror action can tag security/operational issues with a meaningful Initiative value.
- **Define the meta-agent exclusion list** for D9's "agent files with no matrix row" check. Candidates include `adr-composer`, `pdr-composer`, `scope`, `file-issues`, `review`, etc. that exist in `.claude/agents/` but represent meta-decision-making rather than runtime workflows. Ship the list in Phase 6 alongside the drift detector.

## Alternatives Considered

### A separate `ops-sync` agent for non-initiative items, leaving initiatives-sync unchanged

Rejected. Two agents reading live issue state from the same board on overlapping schedules is a coordination burden for no gain. The sync logic is identical — query issues, compare against Architecture files, update — and splitting it means two PRs per sync cycle, two agent definitions to maintain, and a seam where initiative vs. non-initiative classification can drift. A single agent with a broader mandate is simpler.

### Track non-initiative items in `filed-packets.json` by synthesizing packet entries

Rejected. `filed-packets.json` maps packet files to GitHub issues. Non-initiative issues have no packet file. Synthesizing empty or stub packets to make the mapping work would violate the invariant that packets are authored by the scope agent and represent scoped, intentional work. The mapping file's semantics should remain clean: if there's an entry, there's a real packet. Non-initiative items get their own tracking surface (`board-items.md`).

### Have each issue source (nightly security, grid-health, etc.) write its own Architecture tracking

Rejected. This distributes the "Architecture knows about all work" responsibility across every issue source, which is exactly the per-repo-config anti-pattern ADR-0012 rejected for CI/CD configuration. A single sync agent reading from the board is the same "collapse distributed state onto one owner" move the Grid has made repeatedly.

### Broaden the agent to also write back to The Hive (set fields, update status)

Rejected. The `hive-sync` agent reads The Hive and writes to Architecture files. The reverse direction — reading Architecture state and writing to The Hive — is handled by `file-issues` (for new issues) and `hive-field-mirror` (for field updates on existing issues). Giving `hive-sync` write access to the board would create bidirectional sync, which is a coordination hazard: a field set by the mirror action could be overwritten by `hive-sync` on the next run if the two disagree on source of truth. Unidirectional data flow (Hive → Architecture for tracking, Architecture → Hive for issue creation) is strictly simpler.

### Move packets immediately at issue-close time via a GitHub Actions workflow

Rejected. A `workflow_dispatch` or `issues.closed` trigger could move packets in real-time, but it would require the workflow to check out the Architecture repo, find the packet, `git mv` it, and push — a cross-repo write from a workflow running in the target repo. This is fragile (requires a PAT with Architecture-repo push access from every target repo's workflow), and the 1–3 day latency from the Monday/Thursday schedule is acceptable for an archival operation.

### Auto-fix catalogs, invariants, and capability matrix when drift is detected (D9 alternative)

Rejected for the first cut. D9's drift detector could in principle add missing invariants to `invariants.md`, add missing matrix rows for orphan agent files, or add missing nodes to `nodes.json`. Each of those auto-fixes requires architectural judgment the agent does not have:

- An invariant named in an ADR has prose, sector, and decision references that have to be written by the ADR author or the scope agent.
- A matrix row has Trigger, Consumes, Produces, and Cannot-Do columns that are decisions about agent boundaries, not transcriptions.
- A `nodes.json` entry has sector, ownership, and dependency fields that are architecture-level metadata.

Surfacing-without-fixing means the operator sees the drift, makes the architectural decision, and either runs the scope agent (for a packet-driven fix) or the adr-composer (for a new ADR). The agent's role stops at "this is wrong" — fixing is owned by agents that have the right context.

A future ADR may revisit this if a particular drift category proves to be reliably mechanical (e.g., adding a node to `nodes.json` from a freshly-Accepted stand-up ADR is mechanical enough that automation could be safe). That would be its own decision.

### Auto-flip ADRs from Accepted back to Proposed if implementing issues are reopened

Rejected. D7 only flips Proposed → Accepted; it never flips the reverse direction. Reopening an issue post-acceptance is a strong signal that something went wrong, but reverting an ADR's Status is an architectural decision (does the reopen mean the decision is wrong, or does it mean a new bug needs a new packet?). The agent surfaces the situation in `proposed-adrs.md` (showing the Accepted ADR with a closed-then-reopened packet) but does not auto-revert.

### Mirror `active/`'s initiative-subdirectory structure under `completed/`

Considered and rejected for the first cut. A structured archive (`completed/adr-0009-package-scanning-rollout/01-kernel-...md`) is tidier for humans browsing history, but it complicates `filed-packets.json` path updates and the "all packets from this initiative are done" detection (agent has to reason about two parallel subtrees). The flat layout with collision-prefixing is simpler for the agent to implement and reason about. If browsing friction becomes a problem later, a follow-up ADR can re-organize `completed/` without changing the agent's write path — the directory is archival.

## Phase Plan

The decision lands in six phases so each is independently verifiable and the invariants can be added only after the behavior they describe exists.

### Phase 1 — Agent rename and capability matrix (D1, D5)

- Create `.claude/agents/hive-sync.md`, copying the current `initiatives-sync.md` logic verbatim as a starting point.
- Delete `.claude/agents/initiatives-sync.md`.
- Update `constitution/agent-capability-matrix.md` to swap the row.
- Update any references to `initiatives-sync` in CLAUDE.md / AGENTS.md / agent cross-references.
- No behavior change yet — the agent still does only initiative reconciliation. This phase is a pure rename so the next phases land on a stable name.

Exit criterion: the agent runs on its Monday/Thursday schedule under the new name and produces the same PR it did before.

### Phase 2 — Packet lifecycle (D2, D4)

- Add the active → completed move logic to `hive-sync.md`.
- Relax the `initiatives-sync` constraint that forbids writing to `filed-packets.json` — the new agent may update existing entries' `path` keys.
- One-time backfill run: move every packet whose issue is already closed into `completed/` and update `filed-packets.json` paths. This runs as part of the PR that lands Phase 2, so the first "normal" sync after merge starts from a clean state.
- Add invariant 40 to `constitution/invariants.md` in the same PR.

Exit criterion: `generated/issue-packets/active/` contains only packets for open issues.

### Phase 3 — Non-initiative board tracking (D3)

- Add GraphQL Hive-board query logic to `hive-sync.md`.
- Create `initiatives/board-items.md` with the initial table structure.
- First run seeds the file from the current board state (the nightly-security issues already on The Hive become the initial Open rows).
- Add invariant 39 to `constitution/invariants.md` in the same PR.

Exit criterion: every issue on The Hive appears in either an initiative tracking file or `board-items.md`.

### Phase 4 — Proposed-ADR acceptance queue (D6, read-only)

- Add `adrs/ADR-*.md` frontmatter scanning to `hive-sync.md`.
- Create `initiatives/proposed-adrs.md`.
- First run seeds the file with all currently-Proposed ADRs on `main`. ADR-0014 itself appears in the seed because its Status is still `Proposed` — the Phase 5 auto-flip logic (D7) handles ADR-0014 the same way it handles every other Proposed ADR, on the first sync run after Packet 06 closes.
- This phase is **read-only** with respect to ADR files. Auto-flip authority is granted to `hive-sync` in Phase 5.

Exit criterion: the Proposed ADRs on `main` all appear in `proposed-adrs.md` with their days-in-Proposed count.

### Phase 5 — ADR/PDR auto-acceptance and README index sync (D7, D8)

- **Introduce the new `accepts:` packet frontmatter field.** Update `.claude/agents/scope.md` to instruct the scope agent to write `accepts: ["ADR-NNNN"]` (or `"PDR-NNNN"`) on packets that are part of implementing a Proposed decision, in addition to the existing `adrs:` field which continues to be a cataloging reference. Packets that don't implement a Proposed decision either omit `accepts:` or use an empty list.
- Add a packet-to-decision resolution step to `hive-sync.md`: parse every packet's `accepts:` frontmatter and map it to a `{ADR-NNNN: [issue-state, ...]}` and `{PDR-NNNN: [issue-state, ...]}` index.
- Add the auto-flip logic: for each Proposed ADR/PDR, if at least one packet declares it in `accepts:` and all such packets' issues are closed, edit the file's Status frontmatter to `Accepted`.
- Generalize Step 9 (Surface Proposed-ADR Acceptance Queue) to also cover PDRs. Either render a single combined queue file or create a parallel `initiatives/proposed-pdrs.md`.
- Add the README index sync: after auto-flips, reconcile `adrs/README.md` and `pdrs/README.md` Status/Date columns to each ADR/PDR file's frontmatter.
- Update Constraints in `hive-sync.md` to acknowledge the bounded ADR/PDR write authorization (D7's reversal of the read-only stance for those files).
- Add a `MAX_FLIPS_PER_RUN` guard (initial value 3) so that a backlog of completed implementing-packets does not cascade into one un-reviewable PR. Excess candidates are surfaced in `proposed-adrs.md` as "Pending Flip" with a banner noting the queue exceeds the per-run limit.
- First run after Phase 5 lands flips **only** ADRs/PDRs that have at least one packet with `accepts:` declaring them. Legacy Proposed ADRs (whose implementing packets pre-date the convention) stay Proposed until rescoped with `accepts:`-bearing packets.

Exit criterion: every Proposed ADR/PDR with at least one `accepts:`-declaring packet whose every issue is closed has been flipped to Accepted (subject to `MAX_FLIPS_PER_RUN`); every README index row's Status and Date columns match the file's frontmatter.

### Phase 6 — Drift detection (D9)

- Add a drift-detection step to `hive-sync.md` that runs last in the workflow.
- Create `initiatives/drift-report.md` with the structure described in D9.
- Implement the five drift categories (invariants, agent matrix rows, agent files, missing repos, ADR-named-but-uncatalogued nodes).
- Implement the "First Surfaced" sticky-date column by reading the previous file's contents before rewriting.
- First run seeds the file with whatever drift exists on `main` at execution time.

Exit criterion: every drift category lists either current items with `First Surfaced` dates or the empty-state line. The agent does not auto-fix any of these — resolution is human/scope-agent work.

## References

- ADR-0002 — HoneyHub as command center (establishes the Architecture repo's sync mandate)
- ADR-0007 — Claude agents as source of truth (agent definition conventions)
- ADR-0008 — Work tracking and execution flow (packet lifecycle, `filed-packets.json` semantics)
- ADR-0009 — Package scanning policy (the nightly security job that creates non-initiative issues)
- ADR-0011 — Code review and merge flow (PR conventions followed by this agent)
- ADR-0012 — Grid CI/CD control plane (`hive-field-mirror` action; future grid-health aggregator is D6)
