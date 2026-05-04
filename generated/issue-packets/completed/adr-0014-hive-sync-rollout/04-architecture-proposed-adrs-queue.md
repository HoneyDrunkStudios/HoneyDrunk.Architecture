---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0014", "wave-4"]
dependencies: ["adr-0014-hive-sync-rollout/03-architecture-board-items-tracking"]
adrs: ["ADR-0014"]
accepts: ["ADR-0014"]
wave: 4
initiative: adr-0014-hive-sync-rollout
node: honeydrunk-architecture
---

# Feature: Surface Proposed-ADR acceptance queue in `initiatives/proposed-adrs.md`

## Summary
Extend `.claude/agents/hive-sync.md` with a scan of `adrs/ADR-*.md` frontmatter for files in `**Status:** Proposed`, and write the results to a new tracking file `initiatives/proposed-adrs.md`. The file lists every Proposed ADR on `main`, its sector, its date, and its days-in-Proposed count. The first agent run after this packet lands seeds the file from the current `adrs/` directory state. After this packet, four of the six ADR-0014 phases are landed: initiative reconciliation (Phase 1), packet lifecycle (Phase 2), non-initiative board items (Phase 3), and the read-only Proposed-ADR queue surface (Phase 4). Phases 5 (auto-acceptance + README sync) and 6 (drift detection) follow.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0014 D6 names the gap: ADRs filed Proposed sit in that state until the scope agent runs to flip them to Accepted, but there is no current surface showing which merged-but-Proposed ADRs are waiting for a scope run. The result is that ADRs accumulate in Proposed for longer than intended — at scoping time (2026-05-02), the `adrs/README.md` index shows ADR-0011 (Proposed since 2026-04-12), ADR-0012 (since 2026-04-13), ADR-0013 (since 2026-04-16), and ADR-0016 through ADR-0027 (all from 2026-04-19 onward) sitting in Proposed simultaneously. None are inherently stuck — they are simply uncoordinated against a visible queue.

This packet adds the queue. The output is a lightweight workflow surface, not an invariant: there is no rule requiring Proposed ADRs to be accepted within N days. The file is a reminder, not an enforcement. The `Days in Proposed` column is the only signal — a value drifting upward without explanation is a prompt to either schedule a scope run or document why the ADR is intentionally parked.

This packet implements **only** D6 (the read-only queue surface). The ADR-0014 acceptance flip is **not** in this packet — it is performed automatically by the Phase 5 auto-flip logic on the first sync run after Packet 06 closes (the trigger is "every implementing packet's issue is closed"). Treating ADR-0014 like every other Proposed ADR — flipped automatically when its implementing work is done — is cleaner than a manual mid-rollout flip and validates the auto-flip logic against the originating ADR.

The capability-matrix rollout-status caveat that Packet 01 attached to the `hive-sync` row is also **not** removed by this packet — it is removed by Packet 06, the actual closing packet of the rollout.

## Scope

All edits are in the `HoneyDrunk.Architecture` repo. No code (no `.cs` files). No secrets.

### Part A — Add a new tracking step to `hive-sync.md`

In `.claude/agents/hive-sync.md`, insert a new Step **between the existing Step 8 (Reconcile Non-Initiative Board Items, added by Packet 03) and Step 9 (Move Closed Packets to completed/, added by Packet 02)**. The new step is numbered Step 9, the lifecycle step (currently Step 9) becomes Step 10, and the Commit and Open PR step (currently Step 10) becomes Step 11. Renumber all section headings accordingly. The new step reads:

```markdown
### Step 9: Surface Proposed-ADR Acceptance Queue

Scan `adrs/ADR-*.md` frontmatter for files in `**Status:** Proposed`. Write the result to `initiatives/proposed-adrs.md`.

**9a. Enumerate ADR files on `main`.**

```bash
ls adrs/ADR-*.md > /tmp/adr-files.txt
```

The list comes from the on-disk repo (the agent's checkout, which is `main`). Files under `generated/adr-drafts/` are explicitly **excluded** — those are pre-PR drafts and are not yet on `main`.

**9b. Extract frontmatter for each.**

For each ADR file, read the first ~10 lines and extract:

- The ADR number (from the filename: `ADR-NNNN-...`)
- The Title (from the first `#` heading or from the `# ADR-NNNN: Title` line; whichever convention the file follows)
- The `**Status:** ...` line value
- The `**Date:** YYYY-MM-DD` line value
- The `**Sector:** ...` line value

If `**Status:**` is anything other than `Proposed` (case-insensitive match against `Proposed`, `Accepted`, `Superseded`, `Rejected`), skip the file. Files without a `**Status:**` line are also skipped — that is a malformed ADR and is out-of-scope for this surface.

**9c. Compute days-in-Proposed.**

For each Proposed ADR, compute `today - {Date frontmatter value}` in days. Use the calendar date in the ADR's `**Date:**` field, not git history. If the date is unparseable, render `?` for that row's days column rather than failing the whole step.

**9d. Render `initiatives/proposed-adrs.md`.**

Fully rewrite the file each run. The structure is:

```markdown
# Proposed ADRs Awaiting Acceptance

Tracked automatically by the hive-sync agent. These ADRs are on `main`
in Proposed state and are waiting for a scope-agent run to flip them
to Accepted. The Days in Proposed column surfaces staleness; nothing
forces an ADR to be accepted within a deadline.

Last synced: {YYYY-MM-DD}

| ADR | Title | Sector | Dated | Days in Proposed |
|-----|-------|--------|-------|------------------|
| [ADR-0011](../adrs/ADR-0011-code-review-and-merge-flow.md) | Code Review and Merge Flow | Meta | 2026-04-12 | 20 |
```

Rules:

- **The file is fully rewritten each run.** No append-only history. The list reflects current reality at sync time.
- **Empty state is a single line, not a missing table.** When no Proposed ADRs exist, replace the table with the single line `_No Proposed ADRs — the queue is clear._` so the file itself still exists as a known location.
- **Sort order:** ascending ADR number (ADR-0011 before ADR-0012 before ADR-0013, etc.). This matches how the `adrs/README.md` index is ordered.
- **Hyperlink target:** the relative path from `initiatives/proposed-adrs.md` to the ADR file (`../adrs/ADR-NNNN-...md`).

**9e. Drafts are out-of-scope.**

Files under `generated/adr-drafts/` are explicitly excluded. Those drafts are pre-PR — they live in the working tree but have not yet merged to `main` and are not eligible for scope-agent acceptance. Including them would conflate "still being authored" with "merged but waiting on scope," which defeats the surface's purpose.

**9f. Acceptance is the scope agent's job, not this agent's.**

The `hive-sync` agent **never** flips an ADR's status. Reading is the bound; writing the status field requires architectural judgment that belongs to the scope agent. This step is read-only with respect to ADR files. If the executing agent is tempted to "be helpful" and flip an obviously-stale Proposed ADR, **do not.** The acceptance flip is a coordinated edit (status + ADR-index row + invariant additions if any + initiative trackers + sometimes review-agent edits) that the scope agent owns end-to-end.
```

### Part B — Update Constraints in `hive-sync.md`

Append two new bullets to the Constraints block:

```markdown
- The `hive-sync` agent **never modifies any ADR file**. It reads `**Status:**` frontmatter to surface Proposed ADRs but does not flip status, edit body, or rename. ADR acceptance is the `scope` agent's coordinated mechanical flip; ADR drafting is the `adr-composer` agent's job.
- The `initiatives/proposed-adrs.md` file is **fully rewritten on every sync run**, same as `board-items.md`. Hand-edits will be overwritten.
```

### Part C — Create `initiatives/proposed-adrs.md`

Create the file with the structure described in Part A 9d, populated with the **current state of `main`** at this packet's execution time. The first run is the seed.

**Seed scope at scoping time** (snapshot, may shift between scoping and execution):

The seed should include every ADR currently in Proposed status. As of 2026-05-02, that set is approximately:

- ADR-0011 — Code Review and Merge Flow (Meta, 2026-04-12)
- ADR-0012 — HoneyDrunk.Actions as Grid CI/CD Control Plane (Meta, 2026-04-13)
- ADR-0013 — Communications Orchestration Layer (Ops, 2026-04-16)
- ADR-0016 — Stand Up the HoneyDrunk.AI Node (AI, 2026-04-19)
- ADR-0017 — Stand Up the HoneyDrunk.Capabilities Node (AI, 2026-04-19)
- ADR-0018 — Stand Up the HoneyDrunk.Operator Node (AI, 2026-04-19)
- ADR-0019 — Stand Up the HoneyDrunk.Communications Node (Ops, 2026-04-19)
- ADR-0020 — Stand Up the HoneyDrunk.Agents Node (AI, 2026-04-19)
- ADR-0021 — Stand Up the HoneyDrunk.Knowledge Node (AI, 2026-04-19)
- ADR-0022 — Stand Up the HoneyDrunk.Memory Node (AI, 2026-04-19)
- ADR-0023 — Stand Up the HoneyDrunk.Evals Node (AI, 2026-04-19)
- ADR-0024 — Stand Up the HoneyDrunk.Flow Node (AI, 2026-04-19)
- ADR-0025 — Stand Up the HoneyDrunk.Sim Node (AI, 2026-04-19)
- ADR-0026 — Grid Multi-Tenant Primitives (Core / Ops / Infrastructure, 2026-05-02)
- ADR-0027 — Stand Up the HoneyDrunk.Notify.Cloud Node (Ops, 2026-05-02)

**ADR-0014 itself appears in the seed** because its Status is `Proposed` at this packet's execution time and remains `Proposed` until the Phase 5 auto-flip logic fires after Packet 06 closes. ADR-0014 is treated identically to every other Proposed ADR.

The executing agent must derive the seed from live filesystem state, not from this list. The list is informational — its main purpose is to help the reviewer eyeball the resulting file's plausibility.

### Part D — Update the agent's "Step 1: Gather Data" preamble

In `.claude/agents/hive-sync.md`, update Step 1 to add a new sub-step **1g**:

```markdown
**1g. Enumerate ADR frontmatter (for Step 9 reconciliation).**

```bash
ls adrs/ADR-*.md > /tmp/adr-files.txt
```

For each file, read the first ~10 lines and extract the frontmatter fields described in Step 9b. Write the parsed result to `/tmp/adr-frontmatter.json` for use by Step 9.
```

The Step 1g addition consolidates the I/O. Step 9 reads `/tmp/adr-frontmatter.json` rather than re-parsing files.

### Part E — Initiative trackers

Update the existing "Hive Sync Rollout (ADR-0014)" entry in `initiatives/active-initiatives.md` (created by Packet 01, last touched by Packets 02-03) by checking off Packet 04:

```markdown
- [x] Architecture#NN: Surface Proposed-ADR acceptance queue (packet 04)
```

The Packet 05 and Packet 06 checkboxes remain unchecked. The closing Sync annotation is added by Packet 06 (the actual closing packet) — this packet does not write any Sync annotation.

## Affected Files

- `.claude/agents/hive-sync.md` — add Step 1g, add Step 9 (Surface Proposed-ADR Acceptance Queue), renumber subsequent steps, append two bullets to Constraints
- `initiatives/proposed-adrs.md` — **new file**, seeded from the current `adrs/` directory state
- `initiatives/active-initiatives.md` — check off Packet 04 (Sync annotation is added by Packet 06, the closing packet)
- `CHANGELOG.md` — append entry referencing the Proposed-ADR queue addition

## NuGet Dependencies

None. This is a docs/markdown change; no .NET projects touched.

## Boundary Check

- [x] Architecture-only edits. No other repo touched.
- [x] No new code or build artifact.
- [x] **Read-only with respect to ADR files** — Step 9 added by this packet only reads `**Status:**` frontmatter; it never modifies any ADR. The agent's Constraints block (Part B) explicitly forbids the runtime code from flipping an ADR's status. Auto-flip authority is granted to `hive-sync` by Packet 05 (D7), not this packet.
- [x] Invariant 24 preserved — no edits to existing filed packets.
- [x] Invariant 33 preserved — `scope.md` and `review.md` context-loading sections are untouched. `proposed-adrs.md` is a `hive-sync` output, not an input to scope or review.

## Acceptance Criteria

- [ ] `.claude/agents/hive-sync.md` contains a Step 1g titled "Enumerate ADR frontmatter (for Step 9 reconciliation)" inside the existing Step 1 (Gather Data).
- [ ] `.claude/agents/hive-sync.md` contains a Step 9 titled "Surface Proposed-ADR Acceptance Queue" with the frontmatter scan, days-in-Proposed computation, and rendering logic specified in Part A.
- [ ] The lifecycle step (formerly Step 9 after Packet 03) is renumbered to Step 10. The Commit and Open PR step is renumbered to Step 11. All in-text step references inside the agent file are updated to match.
- [ ] The Constraints block contains the two new bullets specified in Part B (no ADR modification by the runtime agent; full rewrite of `proposed-adrs.md`).
- [ ] `initiatives/proposed-adrs.md` exists. It contains:
  - The header text from Part A 9d (verbatim)
  - The `Last synced:` line with the current date (or the merge date)
  - Either a populated table sorted ascending by ADR number, or the `_No Proposed ADRs — the queue is clear._` empty-state line
- [ ] If at execution time any ADR-NNNN file under `adrs/` has `**Status:** Proposed`, that ADR appears in the table with the correct number, title, sector, dated value, and a numeric (or `?`) days-in-Proposed value. **ADR-0014 itself appears in the table** at this packet's seed time because its Status is still `Proposed` until the Phase 5 auto-flip logic fires after Packet 06 closes. This is intentional — ADR-0014 is treated identically to every other Proposed ADR.
- [ ] No file under `generated/adr-drafts/` appears in `proposed-adrs.md`.
- [ ] **No ADR file** under `adrs/` is modified by this PR. `git diff -- adrs/` shows zero changes in `adrs/`.
- [ ] **`constitution/agent-capability-matrix.md` retains the rollout-status caveat** attached by Packet 01. The caveat is removed by Packet 06, not this packet.
- [ ] `initiatives/active-initiatives.md` "Hive Sync Rollout (ADR-0014)" entry shows Packet 04's checkbox as checked. Packet 05 and Packet 06 checkboxes remain unchecked. No closing Sync annotation is added by this packet.
- [ ] Repo-level `CHANGELOG.md` entry appended for this version with a one-line summary referencing the Proposed-ADR queue addition.

## Human Prerequisites

None for the agent-side code changes. Operational note for the human reviewer:

- [ ] After merge, observe the **next scheduled/manual OpenClaw run** of `hive-sync` to confirm the agent regenerates `proposed-adrs.md` correctly from live filesystem state. The first run is the seed (this PR); the second run is the validation. Confirm ADR-0014 **does** appear in the table at this point (it's still `Proposed`); the auto-flip happens later, after Packet 06 closes.

This is a post-merge sanity check, not a blocker on PR merge. The full archival of the Hive Sync Rollout initiative is owned by Packet 06.

## Referenced Invariants

> **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Filing is the point of no return. Before a packet is filed, it may be amended to fill in missing operational context (e.g. NuGet dependencies, key files, constraints) without violating this rule. After filing, state lives on the org Project board, never in the packet file. If requirements change materially post-filing, write a new packet rather than editing the old one.

This invariant constrains the writes this packet performs — it adds Step 9 to `hive-sync.md`, creates `initiatives/proposed-adrs.md`, and edits the active-initiatives entry to check off the Packet 04 box. None of these writes touch existing filed packets.

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled. The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other.

This packet does not touch `scope.md` or `review.md`. The new file `proposed-adrs.md` is the `hive-sync` agent's own surface; it is not part of either the scope or review agent's required-reading list.

## Referenced ADR Decisions

**ADR-0014 D6 (Proposed-ADR acceptance queue):** Scan `adrs/ADR-*.md` for files with a `**Status:** Proposed` frontmatter line. For each match, extract the ADR number, title, sector, and date. Write the results to `initiatives/proposed-adrs.md` with a `Days in Proposed` column. Presence on `main` is sufficient — the agent does not correlate to PRs. The file is fully rewritten each run. Draft ADRs under `generated/adr-drafts/` are excluded. Empty state is a single line, not a missing file. The workflow is intentionally lightweight — a reminder, not an enforcement.

**ADR-0014 Phase Plan, Phase 4 exit criterion:** "the Proposed ADRs on `main` all appear in `proposed-adrs.md` with their days-in-Proposed count."

**ADR acceptance workflow** (per the user-memory convention and `adrs/README.md`): ADRs start Proposed; the scope agent flips them to Accepted **after** the implementing PR merges, never on first draft. The Proposed-ADR queue file is the visibility surface that supports this workflow — it tells the operator "here is the queue of ADRs whose initiatives have not been scoped or whose acceptance flip has not been filed."

## Dependencies

- Wave 3: [Packet 03 — Track non-initiative board items in `board-items.md`](./03-architecture-board-items-tracking.md)

Reason: this packet inserts Step 9 ahead of the lifecycle and commit steps, requiring those steps to already exist (so they can be renumbered correctly). The pattern of adding a new tracking surface, appending a Constraints bullet, and check-marking the initiative tracker all follows the Wave 3 shape — Wave 3 establishes the precedent, Wave 4 finalizes it.

## Labels

`feature`, `tier-2`, `meta`, `docs`, `adr-0014`, `wave-4`

## Agent Handoff

**Objective:** Add the ADR frontmatter scan and the read-only `proposed-adrs.md` tracking surface to `hive-sync`. Seed `proposed-adrs.md` from the current `adrs/` directory state. Check off Packet 04 in the initiative tracker. This packet implements only D6 (the read-only surface); D7 (auto-acceptance) and D9 (drift detection) follow in Packets 05 and 06.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main` (suggested branch name: `chore/adr-0014-hive-sync-phase-4`).

**Context:**
- Goal: Fourth phase of the six-phase ADR-0014 rollout. Adds the read-only Proposed-ADR queue surface; auto-acceptance and drift detection follow in Packets 05 and 06.
- Feature: ADR-0014 — Hive–Architecture Reconciliation Agent.
- ADRs: ADR-0014.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Packet 03 (this initiative, Wave 3) must merge first.

**Constraints:**
- **Invariant 24** (full text above) — no edits to filed packet bodies.
- **Invariant 33** (full text above) — `scope.md` and `review.md` context-loading sections are not modified.
- **Read-only with respect to ADR files.** The Step 9 logic added to `hive-sync.md` only reads `**Status:**` frontmatter; it never modifies any ADR. Auto-flip authority is granted to `hive-sync` by Packet 05, not this packet.
- **Drafts under `generated/adr-drafts/` are excluded.** Pre-PR ADR work is not part of the queue.
- **Full rewrite of `proposed-adrs.md` each run.** No append-only history. No hand-edits preserved. (Packet 05 generalizes this file's structure; the rewrite rule continues to apply.)
- **Sort order is ascending ADR number.** Match the `adrs/README.md` index convention.
- **Empty state is a known line, not a missing file.** The `_No Proposed ADRs — the queue is clear._` text is the exact empty-state marker.

**Key Files:**
- `.claude/agents/hive-sync.md` — insert Step 1g, insert Step 9, renumber Steps 10-11, append Constraints bullets.
- `initiatives/proposed-adrs.md` — create with seeded content from live filesystem.
- `initiatives/active-initiatives.md` — check off Packet 04 only.
- `CHANGELOG.md` — append entry referencing the queue addition.

**Contracts:**
- The ADR frontmatter shape (`**Status:**`, `**Date:**`, `**Sector:**` lines, ADR number from filename, title from first heading) is the contract between this agent and every ADR author. New ADRs that omit any of these fields will fail the parse and either be skipped (Status missing) or render with `?` (Date unparseable). The contract is documented in `adrs/README.md` and is enforced by convention, not by a schema check.
- `proposed-adrs.md`'s table columns are the contract between the agent and human readers. Adding columns is forward-compatible; removing is breaking.
