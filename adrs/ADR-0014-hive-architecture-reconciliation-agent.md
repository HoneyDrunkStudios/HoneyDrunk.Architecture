# ADR-0014: Hive–Architecture Reconciliation Agent

**Status:** Proposed
**Date:** 2026-04-16
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

## Context

The Architecture repo's sync story was designed when the only source of GitHub issues was the scope → file-issues pipeline. The `initiatives-sync` agent runs Monday and Thursday, reads `filed-packets.json`, queries live issue states via `gh`, and reconciles five initiative tracking files (`active-initiatives.md`, `current-focus.md`, `releases.md`, `roadmap.md`, `archived-initiatives.md`). That loop was complete when packets were the only way work entered the system.

Two developments have broken that assumption:

1. **The nightly security job (ADR-0009, ADR-0012) now creates issues directly in target repos.** The `hive-field-mirror` workflow (landed via Actions#22) fires on `issues.opened` and wires these issues into The Hive with correct Node, Wave, and Tier fields. The issues are real work items with board presence, but the Architecture repo knows nothing about them — they have no packets, no initiative association, and no entry in any tracking file.

2. **Issue packets have no lifecycle completion step.** When a filed issue is closed on GitHub, `initiatives-sync` checks it off in the initiative tracking files, but the source packet remains in `generated/issue-packets/active/`. The `retired/` directory exists and has exactly one manually-moved file. There is no agent or automated step that moves completed packets out of `active/`. Over time, `active/` accumulates closed work alongside open work, and any agent or human reading the directory cannot distinguish live packets from historical ones without cross-referencing GitHub issue state.

Together these gaps mean the Architecture repo is drifting from being the "command center" (ADR-0002) toward being a partial view that only tracks initiative-scoped work and never cleans up after itself.

A third, softer pressure: as the Grid grows, more non-initiative issue sources are likely — dependency update PRs that auto-file issues, future observability alerts, the grid-health aggregator's per-repo failure issues (ADR-0012 D6). Each new source widens the gap between "what's on The Hive" and "what Architecture knows about." Closing the gap once, structurally, is cheaper than patching it per-source.

The `initiatives-sync` agent is the natural home for this work — it already owns the "read live issue state, update Architecture files" loop. But its current mandate is too narrow: it only reads issues that appear in `filed-packets.json`, and it only writes to initiative tracking files. Broadening its mandate to cover all Hive items and the packet lifecycle is the subject of this ADR.

Sector is **Meta**, consistent with ADR-0002 (Architecture as command center), ADR-0007 (agent definitions), and ADR-0008 (work tracking).

## Decision

### D1 — The `initiatives-sync` agent is superseded by a `hive-sync` agent with broader mandate

The current `initiatives-sync` agent (`.claude/agents/initiatives-sync.md`) is replaced by a `hive-sync` agent that retains all of `initiatives-sync`'s responsibilities and adds four new ones:

1. **Initiative reconciliation** — unchanged from today. Read `filed-packets.json`, query issue states, update initiative tracking files.
2. **Packet lifecycle management** — move completed packets from `active/` to `retired/`. See D2.
3. **Non-initiative issue tracking** — ensure all issues on The Hive that did not originate from packets are tracked in a new Architecture surface. See D3.
4. **Proposed-ADR acceptance queue** — surface ADRs still in `Status: Proposed` so the scope agent can be run on them. See D6.

The agent retains the Monday/Thursday schedule (and manual trigger). The name change from `initiatives-sync` to `hive-sync` reflects the broadened scope and makes it discoverable — agents reading the capability matrix can infer from the name that this agent covers The Hive board holistically, not just initiative-linked issues.

The old `initiatives-sync.md` agent file is deleted, not kept as a redirect. The capability matrix (`constitution/agent-capability-matrix.md`) is updated in the same PR that lands the new agent definition.

### D2 — The `hive-sync` agent moves completed packets to `retired/`

When the agent discovers that a filed issue is closed (via `gh issue view`), and the issue's packet still exists under `generated/issue-packets/active/`, the agent moves the packet file to `generated/issue-packets/retired/`.

Rules:

- **Move, not copy.** The packet leaves `active/` entirely. A reader of `active/` can trust that everything there represents open work.
- **Preserve the filename.** The file keeps its original name (e.g., `01-vault-bootstrap-extensions.md` → `retired/01-vault-bootstrap-extensions.md`). If a name collision occurs in `retired/` (unlikely, since packets are date-prefixed or initiative-scoped), the agent prefixes the initiative slug: `adr-0005-0006-rollout--01-vault-bootstrap-extensions.md`.
- **Initiative subdirectories.** When all packets in an initiative subdirectory under `active/` have been moved to `retired/`, the agent also moves the `dispatch-plan.md` to `retired/` and removes the now-empty initiative subdirectory.
- **`filed-packets.json` is updated.** The path key in `filed-packets.json` is updated to reflect the new location under `retired/`. This keeps the mapping accurate for any agent that reads it. This is a narrow exception to the current convention that `filed-packets.json` is only written by the `file-issues` agent — the `hive-sync` agent may update existing entries' paths but may not add or remove entries.
- **Standalone packets** (under `active/standalone/`) follow the same rule: closed issue → move to `retired/`.
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

No other agent may move files between `active/` and `retired/`. The `scope` agent writes to `active/`. The `file-issues` agent reads from `active/` and writes to `filed-packets.json`. The `hive-sync` agent is the only agent that moves files out of `active/`. This keeps the packet lifecycle linear and avoids race conditions between agents.

The lifecycle is:

```
scope writes packet → active/
file-issues files issue → filed-packets.json updated, packet unchanged
issue lives on GitHub / The Hive
issue closes on GitHub
hive-sync moves packet → retired/, updates filed-packets.json path
```

### D5 — The capability matrix and agent tooling are updated

The `constitution/agent-capability-matrix.md` is updated:

- Remove the `initiatives-sync` row.
- Add a `hive-sync` row with:
  - **Trigger:** Monday/Thursday schedule, manual
  - **Consumes:** `filed-packets.json`, GitHub issue states (gh CLI), The Hive board state (GraphQL), `grid-health.json`, `nodes.json`, initiative tracking files, `adrs/ADR-*.md` frontmatter
  - **Produces:** Updated initiative tracking files, packet moves (active → retired), `board-items.md`, `proposed-adrs.md`, PR
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

## Consequences

### Architectural Consequences

- **The Architecture repo becomes a complete mirror of The Hive's issue state**, not a partial view filtered to initiative work. Any agent or human reading the Architecture repo can answer "what is the Grid working on right now?" without consulting GitHub directly.
- **`generated/issue-packets/active/` becomes a reliable indicator of open work.** Completed packets no longer linger. Agents that scan `active/` for outstanding work (e.g., a future prioritization agent) can trust the directory contents.
- **`filed-packets.json` gains a second writer.** Today only `file-issues` writes to it; after this ADR, `hive-sync` also updates path entries when moving packets. The two agents write to non-overlapping concerns (file-issues adds entries, hive-sync updates paths of existing entries), so no conflict is expected, but the shared-write surface should be noted.
- **The initiative tracking files are unchanged in structure.** `hive-sync` continues to update them exactly as `initiatives-sync` did. The new tracking surfaces are `board-items.md` and `proposed-adrs.md`.
- **The ADR lifecycle gains a visibility step.** Proposed ADRs that have been merged to `main` but not yet accepted by the scope agent are now listed in a dedicated file with age. This does not change the lifecycle itself — scope agent is still the only thing that flips status — but it makes the queue visible.

### Process Consequences

- **New non-initiative issue sources require no agent changes.** When a new automated process (grid-health aggregator, future dependency bots, etc.) creates issues that land on The Hive via the mirror action, `hive-sync` automatically picks them up on the next run. No per-source wiring is needed.
- **The Monday/Thursday cadence means packet moves lag by 1–3 days.** A packet whose issue closes on Tuesday moves to `retired/` on Thursday. This is acceptable — the packets are archival, not operational, and the initiative tracking files are updated in the same run.
- **Manual trigger remains available** for immediate sync after a burst of issue closures (e.g., after a wave of PRs lands).

### Grid Tracking Invariants

The following invariant should be added to `constitution/invariants.md`:

39. **The Architecture repo tracks all Hive board items.** Every issue on The Hive is represented in either the initiative tracking files (for packet-originated work) or `initiatives/board-items.md` (for non-initiative work). The `hive-sync` agent is responsible for maintaining this correspondence. See ADR-0014 D1, D3.

40. **Completed issue packets are moved to `retired/`.** When a filed issue is closed on GitHub, the `hive-sync` agent moves its source packet from `generated/issue-packets/active/` to `generated/issue-packets/retired/` and updates the path in `filed-packets.json`. No other agent moves packets between lifecycle directories. See ADR-0014 D2, D4.

### Follow-up Work

- **Author the `hive-sync` agent definition** at `.claude/agents/hive-sync.md`. Incorporates all current `initiatives-sync` logic plus the D2/D3/D4 additions. Single packet; medium complexity.
- **Delete `.claude/agents/initiatives-sync.md`** in the same PR as the new agent definition.
- **Create `initiatives/board-items.md`** with the initial table structure. Can be seeded by a one-time backfill run of the new agent.
- **Create `initiatives/proposed-adrs.md`** with the initial table structure. Seeded by the first hive-sync run after Phase 4 lands.
- **Update `constitution/agent-capability-matrix.md`** to reflect the agent rename and expanded responsibilities.
- **Update `constitution/invariants.md`** with invariants 39–40.
- **Backfill `retired/` directory** by running the new agent against all currently-closed issues in `filed-packets.json`. One-time operation.
- **Add `Initiative` select option** for non-initiative values (e.g., `N/A` or `operational`) on The Hive, if one does not already exist, so the mirror action can tag security/operational issues with a meaningful Initiative value.

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

### Mirror `active/`'s initiative-subdirectory structure under `retired/`

Considered and rejected for the first cut. A structured archive (`retired/adr-0009-package-scanning-rollout/01-kernel-...md`) is tidier for humans browsing history, but it complicates `filed-packets.json` path updates and the "all packets from this initiative are done" detection (agent has to reason about two parallel subtrees). The flat layout with collision-prefixing is simpler for the agent to implement and reason about. If browsing friction becomes a problem later, a follow-up ADR can re-organize `retired/` without changing the agent's write path — the directory is archival.

## Phase Plan

The decision lands in three phases so each is independently verifiable and the invariants can be added only after the behavior they describe exists.

### Phase 1 — Agent rename and capability matrix (D1, D5)

- Create `.claude/agents/hive-sync.md`, copying the current `initiatives-sync.md` logic verbatim as a starting point.
- Delete `.claude/agents/initiatives-sync.md`.
- Update `constitution/agent-capability-matrix.md` to swap the row.
- Update any references to `initiatives-sync` in CLAUDE.md / AGENTS.md / agent cross-references.
- No behavior change yet — the agent still does only initiative reconciliation. This phase is a pure rename so the next phases land on a stable name.

Exit criterion: the agent runs on its Monday/Thursday schedule under the new name and produces the same PR it did before.

### Phase 2 — Packet lifecycle (D2, D4)

- Add the active → retired move logic to `hive-sync.md`.
- Relax the `initiatives-sync` constraint that forbids writing to `filed-packets.json` — the new agent may update existing entries' `path` keys.
- One-time backfill run: move every packet whose issue is already closed into `retired/` and update `filed-packets.json` paths. This runs as part of the PR that lands Phase 2, so the first "normal" sync after merge starts from a clean state.
- Add invariant 40 to `constitution/invariants.md` in the same PR.

Exit criterion: `generated/issue-packets/active/` contains only packets for open issues.

### Phase 3 — Non-initiative board tracking (D3)

- Add GraphQL Hive-board query logic to `hive-sync.md`.
- Create `initiatives/board-items.md` with the initial table structure.
- First run seeds the file from the current board state (the nightly-security issues already on The Hive become the initial Open rows).
- Add invariant 39 to `constitution/invariants.md` in the same PR.

Exit criterion: every issue on The Hive appears in either an initiative tracking file or `board-items.md`.

### Phase 4 — Proposed-ADR acceptance queue (D6)

- Add `adrs/ADR-*.md` frontmatter scanning to `hive-sync.md`.
- Create `initiatives/proposed-adrs.md`.
- First run seeds the file with all currently-Proposed ADRs on `main`.

Exit criterion: the Proposed ADRs on `main` all appear in `proposed-adrs.md` with their days-in-Proposed count.

## References

- ADR-0002 — HoneyHub as command center (establishes the Architecture repo's sync mandate)
- ADR-0007 — Claude agents as source of truth (agent definition conventions)
- ADR-0008 — Work tracking and execution flow (packet lifecycle, `filed-packets.json` semantics)
- ADR-0009 — Package scanning policy (the nightly security job that creates non-initiative issues)
- ADR-0011 — Code review and merge flow (PR conventions followed by this agent)
- ADR-0012 — Grid CI/CD control plane (`hive-field-mirror` action; future grid-health aggregator is D6)
