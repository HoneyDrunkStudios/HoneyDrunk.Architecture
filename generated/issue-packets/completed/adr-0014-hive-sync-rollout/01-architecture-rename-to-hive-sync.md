---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0014", "wave-1"]
dependencies: []
adrs: ["ADR-0014"]
accepts: ["ADR-0014"]
wave: 1
initiative: adr-0014-hive-sync-rollout
node: honeydrunk-architecture
---

# Feature: Rename `initiatives-sync` agent to `hive-sync`

## Summary
Rename the `.claude/agents/initiatives-sync.md` agent to `.claude/agents/hive-sync.md` (verbatim copy + delete), retire the `.github/workflows/initiatives-sync.yml` Anthropic/Claude-Code pipeline, add an OpenClaw runbook for the scheduled/manual `hive-sync` job, update the agent capability matrix to swap the row, and propagate the rename across cross-references in `CLAUDE.md`, `AGENTS.md`, and other repo-level documents. **No behavior change.** The agent still does only initiative reconciliation after this packet — Phases 2-6 add the new responsibilities. **ADR-0014 stays in `Proposed` status throughout the rollout** and auto-flips to `Accepted` via the Phase 5 auto-flip logic on the first sync run after Packet 06 closes, treated identically to every other Proposed ADR.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0014 broadens the sync agent's mandate from initiative-only reconciliation to full Hive board reconciliation, packet lifecycle management, non-initiative item tracking, and Proposed-ADR queue surfacing. The rename from `initiatives-sync` to `hive-sync` is the first step — it makes the broader scope discoverable from the agent name itself, and it gives subsequent phases a stable target file (`hive-sync.md`) to build on.

This packet is the entry point for the six-phase rollout. It is mostly a **pure rename**, plus one intentional runtime change: `hive-sync` is run by OpenClaw as a scheduled/manual agent job instead of by a GitHub Actions workflow that calls the Anthropic API. The agent file is renamed verbatim with targeted name-change edits, the CI workflow is removed, the OpenClaw runbook is added, the capability-matrix row is swapped, and cross-references are propagated. No reconciliation behavior changes; no invariants added; ADR-0014 stays in `Proposed` status until the Phase 5 auto-flip logic fires after Packet 06 closes.

## Scope

All edits are in the `HoneyDrunk.Architecture` repo. No code (no `.cs` files). No secrets.

### Part A — Rename the agent file

1. Read the existing `.claude/agents/initiatives-sync.md` in full.
2. Create `.claude/agents/hive-sync.md` containing the **exact same content** as `initiatives-sync.md`, with the following targeted edits and **no others**:
   - Change the YAML `name:` field from `initiatives-sync` to `hive-sync`.
   - Change the YAML `description:` field to: `Reconcile the Architecture repo with The Hive — initiative tracking files, packet lifecycle (active/completed), non-initiative board items, and the Proposed-ADR acceptance queue. Gathers live issue states via gh CLI and Hive board state via GraphQL. Opens a PR with all changes. Runs on schedule (Monday and Thursday) or manually.` (This description forecasts the broader mandate; Phases 2-4 implement the surfaces it names. Doing the description rewrite once in Phase 1 avoids a description churn each phase.)
   - Change the agent display heading from `# Initiatives Sync` to `# Hive Sync`.
   - Change the opening paragraph from `You are the **Initiatives Sync** agent.` to `You are the **Hive Sync** agent.`
   - Change the branch-name template from `chore/initiatives-sync-$(date +%Y-%m-%d)` to `chore/hive-sync-$(date +%Y-%m-%d)`.
   - Change the PR title template from `chore: sync initiative progress ($(date +%Y-%m-%d))` to `chore: sync hive state ($(date +%Y-%m-%d))`.
   - Change the PR-body wording from `the **initiatives-sync** agent via [agent-run]` to `the **hive-sync** agent via OpenClaw`.
   - Change the Output Summary heading from `## Initiatives Sync — {date}` to `## Hive Sync — {date}`.
3. Delete `.claude/agents/initiatives-sync.md`. The old file is removed in the same commit; no redirect, no compatibility shim.

The reconciliation Workflow body, Decision Rules, Constraints, and Gather Data steps are **not modified** in this packet beyond the targeted naming/PR wording above. Subsequent phases (02, 03, 04) add new reconciliation steps; this phase is a rename plus runtime migration to OpenClaw.

### Part B — Retire the GitHub Actions agent-run pipeline and document the OpenClaw job

1. Read `.github/workflows/initiatives-sync.yml` in full so the removed runtime is reviewable.
2. Delete `.github/workflows/initiatives-sync.yml`. Do **not** create `.github/workflows/hive-sync.yml`.
3. Add `infrastructure/openclaw/hive-sync.md` documenting the OpenClaw runtime contract for this job:
   - schedule: Monday/Thursday, matching the current cadence unless Oleg later changes it in OpenClaw cron;
   - target: isolated OpenClaw `agentTurn`, not GitHub Actions;
   - working repo: `HoneyDrunk.Architecture`;
   - prompt source: `.claude/agents/hive-sync.md`;
   - allowed tools/capabilities: read/write/edit files, run `gh`, run GraphQL via `gh api graphql`, create/update the reconciliation PR;
   - output: concise executive summary to Oleg with files changed, PR URL, and any blockers;
   - safety: read-only with respect to The Hive board except for PR creation in Architecture; no GraphQL mutations to board fields.

The old workflow used `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/agent-run.yml@main`, `provider: claude`, and `secrets.ANTHROPIC_API_KEY`. That is intentionally retired. The GitHub Actions pipeline is no longer the brain; OpenClaw owns scheduling/manual execution, and GitHub remains the source of truth plus PR surface. If a CI file is ever reintroduced, it should be a dumb health/validation trigger, not an Anthropic API caller.

### Part C — Update the agent capability matrix

In `constitution/agent-capability-matrix.md`:

1. **Replace the `initiatives-sync` row** in the main agent table (currently the last row) with a `hive-sync` row matching the structure of the other rows. The new row must read:

```markdown
| **hive-sync** | OpenClaw Monday/Thursday schedule or manual OpenClaw dispatch | `gh` CLI issue states, `generated/issue-packets/filed-packets.json`, GraphQL Hive board state, `catalogs/grid-health.json`, `catalogs/nodes.json`, `adrs/ADR-*.md` frontmatter, initiative files | Updated `initiatives/` files via PR (new branch per run), packet moves (active → completed), `board-items.md`, `proposed-adrs.md` | Create issues, modify `filed-packets.json` entries (may update existing paths only), make architectural decisions |
```

   The "Consumes" and "Produces" columns reflect the **full** post-Phase-4 mandate, not the Phase-1 reality. Doing the capability-matrix update once at the rename avoids three subsequent matrix edits in Phases 2-4. The actual behavior at the end of this packet is still initiative-only reconciliation; the matrix forecasts the rollout.

   **Status caveat.** Add an explicit note in the matrix immediately above the row (or as a footnote on the row) flagging that the broader mandate lands across the full six-packet rollout. Suggested wording: `> **Status:** rolling out across ADR-0014 packets 01-06. The packet-lifecycle (active → completed), `board-items.md`, `proposed-adrs.md`, ADR/PDR auto-acceptance, README index sync, and `drift-report.md` surfaces become live as Packets 02-06 land.` The footnote is removed in Packet 06 once the full mandate is in place.

2. **Update the decision tree.** Find the entry:

```
Do initiative tracking files need reconciliation with GitHub issue states?
  → yes → initiatives-sync (automated weekly, or invoke manually)
```

   Replace it with:

```
Do Architecture-repo files need reconciliation with The Hive (initiatives, packet lifecycle, non-initiative items, Proposed-ADR queue)?
  → yes → hive-sync (OpenClaw scheduled Monday/Thursday, or invoke manually)
```

3. **Update the Execution Rules bullet** that mentions the agent:

   Find: `and `initiatives-sync` (which runs via Claude Code Action in CI, creates a date-based branch, and opens or updates a PR for initiative-file reconciliation).`

   Replace with: `and `hive-sync` (which runs via OpenClaw scheduled/manual agent job, creates a date-based branch, and opens or updates a PR for full Architecture-repo reconciliation with The Hive — initiative files, packet lifecycle, board items, and Proposed-ADR queue).`

4. **Update the Agent-specific additional context table.** Replace the row:

```
| initiatives-sync | `generated/issue-packets/filed-packets.json`, `catalogs/grid-health.json`, `catalogs/nodes.json`, `initiatives/` |
```

   with:

```
| hive-sync | `generated/issue-packets/filed-packets.json`, `catalogs/grid-health.json`, `catalogs/nodes.json`, `initiatives/`, `adrs/ADR-*.md` (frontmatter), GraphQL Hive board query results |
```

### Part D — Propagate the rename across cross-references

Run a repo-wide search for the literal string `initiatives-sync` after Parts A-C land. Each remaining occurrence (excluding the deleted file path and excluding `.git/`) must be inspected and updated:

- **`adrs/README.md`** — the ADR-0014 description column currently reads: `Supersedes `initiatives-sync` with a `hive-sync` agent that covers all Hive items (not just packet-sourced ones) and owns the packet lifecycle from filed → retired. Closes drift introduced by nightly-security issues and unretired packets.` Replace the **entire description column** with: `Renames `initiatives-sync` to `hive-sync` with a broader mandate.` (The shorter wording is intentional — the index row is a quick-reference; details belong in the ADR body.) Do not change the ADR-0014 row's Status column — it remains `Proposed` until Packet 04.
- **`adrs/ADR-0014-hive-architecture-reconciliation-agent.md`** — the ADR body extensively references `initiatives-sync` as the predecessor. **Do not edit the ADR body.** References to `initiatives-sync` are correct as the predecessor name throughout the ADR text. The Status front-matter line stays `Proposed` throughout the rollout; ADR-0014 auto-flips on the first sync run after Packet 06 closes, via the Phase 5 auto-flip logic.
- **Other ADRs (ADR-0008, ADR-0007, ADR-0011, ADR-0012, etc.)** — historical references to `initiatives-sync` in Accepted ADRs are left as-is. Accepted ADRs are immutable historical records.
- **Existing in-flight packets under `generated/issue-packets/active/`** — historical references to `initiatives-sync` in already-filed packets must not be edited (invariant 24: packets are immutable once filed). Leave them as-is. The set of files matching this rule includes any Wave 2+ packet of any other in-flight initiative; it is acceptable for those packets to mention `initiatives-sync` because they were filed before this rename.
- **`CLAUDE.md`** at the repo root — if it references the agent by name, update to `hive-sync`.
- **`AGENTS.md`** at the repo root — if it references the agent by name, update to `hive-sync`.
- **Any `.github/workflows/*.yml` file** — no workflow should call the sync agent after this packet. The old Anthropic-backed pipeline is intentionally removed; OpenClaw owns the runtime.

The verifier command for the agent executing this packet:

```bash
git grep -n "initiatives-sync" -- ":(exclude).git/*"
```

After the propagation edit, the only remaining matches must be (a) inside `adrs/ADR-*.md` files (Accepted ADRs, immutable), (b) inside `generated/issue-packets/active/**/*.md` files filed before this rename (immutable per invariant 24), (c) inside `generated/issue-packets/retired/**/*.md` if any, and (d) any historical commit message in the git log (which `git grep` does not search). All other matches must be eliminated.

On 2026-05-02, repo-level `CLAUDE.md`, `AGENTS.md`, and `README.md` do not contain `initiatives-sync` references. The propagation step is precautionary against undetected drift between scoping and execution.

### Part E — No surface creation yet

This packet does **not** create `initiatives/board-items.md` or `initiatives/proposed-adrs.md`. Those files are introduced by Packets 03 and 04 respectively. This packet does not modify `constitution/invariants.md`. The two Hive-Sync invariants are added by Packets 02 and 03.

This packet does **not** add lifecycle logic to the agent file. The agent workflow steps in `hive-sync.md` after this packet are byte-identical to `initiatives-sync.md`'s Workflow steps (modulo the targeted name/PR wording edits in Part A). Validation: the Step 1 through Step 8 substantive content (the GraphQL queries, file lists, decision rules, output formats) must be unchanged after Part A.

This packet does **not** flip ADR-0014's status. The ADR remains `Proposed` for the duration of the rollout and auto-flips on the first sync run after Packet 06 closes, via the Phase 5 auto-flip logic. Bundling the acceptance flip with any single phase was considered and rejected: an Accepted ADR with missing invariants/surfaces would misrepresent the on-disk state during the rollout. Letting the auto-flip handle ADR-0014 makes it the end-to-end validation that the new behavior works on the originating ADR.

### Part F — Initiative trackers

In `initiatives/active-initiatives.md`, add a new "In Progress" entry. Insert it after the existing ADR-0010 entry (the first one in In Progress) so the chronological grouping matches existing patterns:

```markdown
### Hive Sync Rollout (ADR-0014)
**Status:** In Progress
**Scope:** Architecture
**Initiative:** `adr-0014-hive-sync-rollout`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Rename `initiatives-sync` to `hive-sync` and broaden its mandate to cover the packet lifecycle (active → completed), non-initiative board items, the Proposed-ADR/PDR queue, ADR/PDR auto-acceptance + README index sync, and a drift report. Closes the drift introduced by nightly-security issues having no Architecture-repo presence, completed packets lingering in `active/`, and ADRs/PDRs that drift out of sync with their implementing work or with the rest of the repo. Single repo (Architecture); six sequential phases. ADR-0014 itself auto-flips to Accepted via Phase 5's logic on the first run after Packet 06 closes.

**Tracking:**
- [ ] Architecture#NN: Rename agent + capability matrix (packet 01)
- [ ] Architecture#NN: Add packet lifecycle and Hive-Sync invariant for lifecycle (packet 02)
- [ ] Architecture#NN: Track non-initiative board items + Hive-Sync invariant for board coverage (packet 03)
- [ ] Architecture#NN: Surface Proposed-ADR acceptance queue (packet 04)
- [ ] Architecture#NN: ADR/PDR auto-acceptance + README index sync (packet 05)
- [ ] Architecture#NN: Drift detection + close out the rollout (packet 06)
```

The ADR-0014 acceptance flip is **not** in any packet's manual scope — it is performed automatically by the Phase 5 auto-flip logic on the first sync run after Packet 06 closes (when all six implementing packets' issues are closed). This is the same logic that handles every other Proposed ADR; ADR-0014 is treated identically to any other Proposed ADR with implementing packets.

In `initiatives/roadmap.md`, add an entry under the "Process & Tooling" or equivalent existing section noting `adr-0014-hive-sync-rollout` as in-progress with a one-liner: "Hive Sync rollout: rename initiatives-sync to hive-sync, add packet lifecycle, board-items tracking, and Proposed-ADR queue."

## Affected Files

- `.claude/agents/hive-sync.md` — **new** (verbatim copy of `initiatives-sync.md` with targeted name/PR wording edits per Part A)
- `.claude/agents/initiatives-sync.md` — **deleted**
- `infrastructure/openclaw/hive-sync.md` — **new** (OpenClaw scheduled/manual runtime contract)
- `.github/workflows/initiatives-sync.yml` — **deleted**
- `.github/workflows/hive-sync.yml` — **must not exist**
- `constitution/agent-capability-matrix.md` — row swap, decision tree, execution rules, additional-context table
- `CLAUDE.md` — if referenced
- `AGENTS.md` — if referenced
- `initiatives/active-initiatives.md` — new In Progress entry
- `initiatives/roadmap.md` — new entry under Process & Tooling
- `CHANGELOG.md` — append entry referencing the agent rename (create the file if it does not yet exist; one bullet per phase across the rollout)

The new agent file and the new OpenClaw runtime runbook are **created**; the old agent file and old GitHub Actions workflow are **deleted** in the same PR. Git diff for the rename is two creates + two deletes plus textual diffs in the new files where the targeted name/runtime edits were made.

## NuGet Dependencies

None. This is a docs/markdown/YAML change; no .NET projects touched.

## Boundary Check

- [x] Architecture-only edits. No other repo touched. No production code in any repo.
- [x] No new contract surface. No new ADR.
- [x] Invariant 33 symmetry preserved — the agent rename does **not** change the context-loading section of any agent (`scope.md` and `review.md` are untouched). The capability-matrix table is updated, but the matrix is metadata, not a context-loading contract. `board-items.md` and `proposed-adrs.md` (introduced by later packets) are outputs of `hive-sync`, not inputs to scope or review; neither agent's context-loading list needs an addition.
- [x] Invariant 24 preserved — no edits to existing filed packets under `generated/issue-packets/active/` or `generated/issue-packets/retired/`.

## Acceptance Criteria

- [ ] `.claude/agents/hive-sync.md` exists and contains the targeted name/PR wording edits described in Part A; all other reconciliation logic is byte-identical to the deleted `.claude/agents/initiatives-sync.md`.
- [ ] `.claude/agents/initiatives-sync.md` does not exist.
- [ ] `.github/workflows/initiatives-sync.yml` does not exist.
- [ ] `.github/workflows/hive-sync.yml` does not exist.
- [ ] `infrastructure/openclaw/hive-sync.md` exists and documents the OpenClaw scheduled/manual runtime contract.
- [ ] `constitution/agent-capability-matrix.md` no longer contains a row for `initiatives-sync`. It contains exactly one row for `hive-sync` with the Consumes/Produces columns specified in Part C, plus the rollout-status caveat described in Part C.1.
- [ ] `constitution/agent-capability-matrix.md` decision tree, execution rules, and Agent-specific additional context table are updated per Part C (1)-(4).
- [ ] `git grep -n "initiatives-sync"` returns matches only inside `adrs/ADR-*.md`, `generated/issue-packets/active/**/*.md` (filed before this packet), or `generated/issue-packets/retired/**/*.md`. No matches in `.claude/`, `.github/workflows/`, `constitution/`, `CLAUDE.md`, `AGENTS.md`, or `initiatives/`.
- [ ] `adrs/README.md` ADR-0014 row Status column reads `Proposed` (unchanged); the description column has been updated to "Renames `initiatives-sync` to `hive-sync` with a broader mandate."
- [ ] `adrs/ADR-0014-hive-architecture-reconciliation-agent.md` Status front-matter line reads `**Status:** Proposed` (unchanged by this packet).
- [ ] `initiatives/active-initiatives.md` contains a "Hive Sync Rollout (ADR-0014)" In Progress entry with the six-item Tracking list described in Part F.
- [ ] `initiatives/roadmap.md` references `adr-0014-hive-sync-rollout`.
- [ ] The PR diff touches only the files listed in Affected Files.
- [ ] The OpenClaw `hive-sync` scheduled/manual job runs successfully on its next trigger and produces a PR identical **in structure** (same five initiative files reconciled, same PR title pattern under the new name) to what `initiatives-sync.yml` produced. The PR title text changes from `chore: sync initiative progress (...)` to `chore: sync hive state (...)`; the title pattern, branch convention, body layout, and reconciled-file set are unchanged. This criterion is verified post-merge by observing the next OpenClaw run; reviewers may ask Honeyclaw/Oleg to trigger it manually if immediate validation is needed.
- [ ] Repo-level `CHANGELOG.md` entry created or appended for this version with a one-line summary referencing the agent rename. (If `CHANGELOG.md` does not exist at the repo root, create it with a single H1 `# Changelog` and an `## Unreleased` section, then append the entry under that section. Subsequent packets append to the same file.)

## Human Prerequisites

None. This packet is fully delegable.

The `ANTHROPIC_API_KEY` usage in the old GitHub Actions workflow is removed with the workflow. The `INITIATIVES_SYNC_TOKEN` secret may remain in GitHub until Oleg cleans it up, but it is no longer consumed by this runtime. OpenClaw uses the machine's authenticated `gh` context for issue/project reads and PR creation.

## Referenced Invariants

> **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Filing is the point of no return. Before a packet is filed, it may be amended to fill in missing operational context (e.g. NuGet dependencies, key files, constraints) without violating this rule. After filing, state lives on the org Project board, never in the packet file. If requirements change materially post-filing, write a new packet rather than editing the old one.

This invariant is the reason Part D instructs leaving `initiatives-sync` references inside already-filed packets untouched. Updating filed packets retroactively is forbidden.

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled. The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other.

This invariant does not directly govern the `hive-sync` agent (which is neither scope nor review), but it constrains what this packet may touch. The packet must not edit the context-loading sections of `scope.md` or `review.md`. The capability-matrix changes in Part C are metadata, not context-loading contracts, and are exempt.

## Referenced ADR Decisions

**ADR-0014 D1 (Agent rename):** The current `initiatives-sync` agent is replaced by a `hive-sync` agent. The old `initiatives-sync.md` agent file is **deleted, not kept as a redirect**. The capability matrix is updated in the same PR that lands the new agent definition. Phase 1 is **a pure rename so the next phases land on a stable name** — no behavior change is introduced.

**ADR-0014 D5 (Capability matrix updates):** Remove the `initiatives-sync` row. Add a `hive-sync` row with Trigger, Consumes, Produces, and Sync Responsibility describing the full broadened mandate. The agent's tool list is unchanged from `initiatives-sync` (Read, Grep, Glob, Edit, Write, Bash, TodoWrite); no new tools are required.

**ADR-0014 Phase Plan, Phase 1 exit criterion:** "the agent runs on its Monday/Thursday schedule under the new name and produces the same PR it did before." This now means the OpenClaw scheduled/manual job, not a GitHub Actions Anthropic pipeline.

## Dependencies

None. This packet is the entry point for the initiative.

## Labels

`feature`, `tier-2`, `meta`, `docs`, `adr-0014`, `wave-1`

## Agent Handoff

**Objective:** Rename the `initiatives-sync` agent to `hive-sync` (verbatim copy + delete + OpenClaw runtime migration + capability matrix swap + cross-reference cleanup). No behavior change. ADR-0014 stays in `Proposed` throughout the rollout and auto-flips on the first sync run after Packet 06 closes, via the Phase 5 auto-flip logic.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main` (suggested branch name: `chore/adr-0014-hive-sync-phase-1`).

**Context:**
- Goal: First of six phases in the ADR-0014 rollout. Establishes the new agent name as a stable target for Phases 2-6.
- Feature: ADR-0014 — Hive–Architecture Reconciliation Agent.
- ADRs: ADR-0014.

**Acceptance Criteria:** As listed in the Acceptance Criteria section above.

**Dependencies:** None.

**Constraints:**
- **Invariant 24** (full text above) — do not edit any file under `generated/issue-packets/active/` or `generated/issue-packets/retired/`. Filed packets, including those that mention `initiatives-sync`, stay frozen.
- **Invariant 33** (full text above) — the rename must not modify `.claude/agents/scope.md` or the context-loading section of `.claude/agents/review.md`. The capability matrix is metadata and is in scope.
- **Agent logic rename, no reconciliation behavior change.** The agent workflow body of `hive-sync.md` after Part A must be byte-identical to `initiatives-sync.md`'s workflow body except for the targeted name/PR wording edits. No new reconciliation Step, no removed reconciliation Step, no lifecycle logic yet. The runtime migration is isolated to deleting the GitHub Actions pipeline and documenting the OpenClaw job.
- **Runtime migration removes the Anthropic pipeline.** The old GitHub Actions workflow is deleted; no replacement workflow calls the Anthropic API.
- **ADR-0014 stays in Proposed.** Do not edit the ADR's Status front-matter line. Do not edit the `adrs/README.md` Status column for ADR-0014. The flip is owned by the Phase 5 auto-flip logic on the first sync run after Packet 06 closes.
- **Accepted ADRs are immutable historical records.** Part D leaves references inside other ADR files untouched.

**Key Files:**
- `.claude/agents/initiatives-sync.md` — read in full, then delete.
- `.claude/agents/hive-sync.md` — create with the targeted name/PR wording edits.
- `.github/workflows/initiatives-sync.yml` — read in full, then delete.
- `infrastructure/openclaw/hive-sync.md` — create with the OpenClaw scheduled/manual runtime contract.
- `constitution/agent-capability-matrix.md` — replace four locations per Part C.
- `adrs/README.md` — update the description column for the ADR-0014 row only; leave the Status column unchanged.
- `initiatives/active-initiatives.md` — add new In Progress entry.
- `initiatives/roadmap.md` — add Process & Tooling entry.
- `CHANGELOG.md` — append entry (create file if absent).
- `CLAUDE.md`, `AGENTS.md` — update if they reference the old agent name.

**Contracts:** No code contracts. The only contract surface touched is the constitution's agent capability matrix (a documentation contract).
