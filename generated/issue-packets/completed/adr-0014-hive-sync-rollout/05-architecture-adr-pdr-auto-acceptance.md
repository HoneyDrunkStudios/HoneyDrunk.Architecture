---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0014", "wave-5"]
dependencies: ["adr-0014-hive-sync-rollout/04-architecture-proposed-adrs-queue"]
adrs: ["ADR-0014"]
accepts: ["ADR-0014"]
wave: 5
initiative: adr-0014-hive-sync-rollout
node: honeydrunk-architecture
---

# Feature: Auto-accept ADRs/PDRs and sync README indexes

## Summary
Introduce a new `accepts:` packet frontmatter field that distinguishes "this packet implements this decision" from "this packet references this decision" (the existing `adrs:` field, which remains unchanged). Update `.claude/agents/scope.md` to write `accepts:` for new packets going forward. Generalize Step 9 in `.claude/agents/hive-sync.md` from "list Proposed ADRs" to "for each Proposed ADR/PDR with at least one packet declaring it in `accepts:` and every such packet's issue closed, auto-flip to Accepted; otherwise surface in the queue with progress columns." Add Step 10 (or extend Step 9) to reconcile `adrs/README.md` and `pdrs/README.md` Status/Date columns against each ADR/PDR file's frontmatter. Generalize `initiatives/proposed-adrs.md` to also cover PDRs (single combined file) so the queue is one place. Auto-flips are capped at `MAX_FLIPS_PER_RUN` (initial value 3) per run to keep PRs reviewable. After this packet, an ADR whose implementing packets are all closed will auto-flip on the next sync run; a manual edit to an ADR's Status front-matter that does not update the README index will be reconciled on the next run.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0014 D6 (landed in Packet 04) created `proposed-adrs.md` as a visibility surface for ADRs awaiting acceptance. That surface is read-only — the agent never flipped an ADR's Status. ADR-0014 D7 and D8 (added by the same scope review that produced this packet) extend the agent's authority in two bounded ways:

1. **Auto-flip Proposed → Accepted** when all implementing packets are closed. The trigger is unambiguous (every implementing GitHub issue is in the `closed` state) and the edit is one line of frontmatter.
2. **Reconcile README index Status/Date columns** against ADR/PDR frontmatter every run. Manual edits to ADR Status that miss the README leave the index stale; this packet closes that drift.

ADR-0014 D6 also implicitly assumed only ADRs need a queue; PDRs follow the same Proposed → Accepted pattern (see `pdrs/PDR-0001-...md` and `pdrs/PDR-0002-...md`) and should share the surface. This packet generalizes the queue to cover both.

**The `accepts:` frontmatter field is new with this packet.** Today's `adrs:` field is used loosely as a "decisions referenced by this packet" cataloging field. Repurposing it as an implementing-packet declaration would silently change the semantics of every existing filed packet (per invariant 24, those bodies are immutable), retroactively making them auto-flip eligible on the first run. The new `accepts:` field is opt-in: only packets authored with the new convention count toward auto-flip. Packets 01-06 of this rollout carry `accepts: ["ADR-0014"]` (added pre-filing per invariant 24's pre-filing amendment allowance); future packets will carry `accepts:` as scope.md instructs (Part F below).

The auto-flip is bounded to prevent over-reach. Four guard rules:

- **At least one packet declaring the decision in `accepts:` must exist.** ADRs/PDRs with no `accepts:`-declaring packets stay Proposed — this includes legacy ADRs whose implementing packets pre-date this convention (those packets do not carry `accepts:`). Legacy ADRs remain manually-flippable via the scope agent until rescoped with `accepts:`-bearing packets.
- **Every `accepts:`-declaring packet's issue must be closed.** If any is open, the ADR shows in the queue with a `pending: N issues open` marker but is not flipped.
- **Reverse direction (Accepted → Proposed) is never auto-flipped.** Even if an implementing issue is reopened post-acceptance, the agent surfaces the situation in the queue's "anomalies" section but does not revert the ADR.
- **`MAX_FLIPS_PER_RUN` cap.** Initial value 3. If more than 3 ADRs/PDRs qualify for auto-flip in one run, the agent flips the first 3 (sorted ascending by ID) and surfaces the rest in `proposed-adrs.md` "Pending Flip" section with a banner ("flip queue exceeds per-run limit; will continue next run"). This keeps a single sync PR reviewable.

After this packet lands, the first run will auto-flip only ADRs/PDRs that have `accepts:`-declaring packets — most likely none on first run, since this rollout's six packets are the first to carry `accepts:` and they're not all closed yet. ADR-0014 itself auto-flips on the first run after Packet 06 closes (when all six `accepts: ["ADR-0014"]` packets' issues are closed). This is the end-to-end validation that the auto-flip works on the originating ADR.

## Scope

All edits are in the `HoneyDrunk.Architecture` repo. No code (no `.cs` files). No secrets.

### Part A — Generalize Step 9 (Proposed-ADR Queue) into ADR/PDR auto-acceptance

In `.claude/agents/hive-sync.md`, **replace** the existing Step 9 body (added by Packet 04) with the new logic. The step heading remains `### Step 9: Surface Proposed-ADR Acceptance Queue` but is renamed to `### Step 9: ADR/PDR Acceptance Reconciliation`. The new body reads:

```markdown
### Step 9: ADR/PDR Acceptance Reconciliation

Resolve every Proposed ADR/PDR's implementing-packet state, auto-flip the ones whose implementing issues are all closed, and surface the rest in `initiatives/proposed-adrs.md` with progress columns.

**9a. Build the implementing-packet index from `accepts:` fields.**

For each packet under `generated/issue-packets/active/**/*.md` and `generated/issue-packets/completed/**/*.md`, parse the YAML frontmatter and extract the `accepts:` field (if present and non-empty). Build an in-memory map:

```text
ADR-0011 → [
  { path: "active/adr-0011-...rollout/01-...md", issue_url: "...", state: "open|closed" },
  ...
]
PDR-0001 → [...]
ADR-0014 → [
  { path: "active/adr-0014-hive-sync-rollout/01-architecture-rename-to-hive-sync.md", ... },
  ...all six packets in this rollout...
]
```

The `state` value comes from `/tmp/issue-states.json` (already populated by Step 1b for this packet's issue URLs). The `accepts:` field can list both ADR and PDR identifiers (e.g., `accepts: ["ADR-0026", "PDR-0002"]`). Packets without `accepts:` or with an empty `accepts:` list contribute to no entry — they may have `adrs:` references but they do not gate any decision's acceptance. **This is the key disambiguation** between cataloging-style references (`adrs:`) and implementation-completion gating (`accepts:`).

**On legacy packets.** Today's filed packets in `active/` and `completed/` were authored before this convention and **do not carry `accepts:`**. Per invariant 24 their bodies are immutable, so they will never be retrofitted. The auto-flip therefore does **not** consider them. Legacy Proposed ADRs (whose implementing packets pre-date `accepts:`) stay manually-flippable via the scope agent until rescoped with new `accepts:`-bearing packets. This is the deliberate design choice that prevents the first-run cascade risk.

**9b. Decide each Proposed ADR/PDR.**

For each `adrs/ADR-*.md` and `pdrs/PDR-*.md` file whose `**Status:**` frontmatter line (after `rstrip` of trailing whitespace) reads exactly `Proposed`:

1. Look up its number in the implementing-packet index.
2. Decide:
   - **No entry in the index (zero `accepts:`-declaring packets):** category = `awaiting`. Do not flip.
   - **Entry exists, every packet's `state == "closed"`:** category = `ready`. Stage for flip in 9c (subject to the per-run cap).
   - **Entry exists, at least one packet is `open`:** category = `pending`. Do not flip. Record `closed_count` and `total_count` for the queue file.
3. **Anomaly check.** If any implementing packet was previously closed (from `/tmp/prev-issue-states.json` if present from prior runs) and is now open, mark the ADR/PDR for the queue's "Anomalies" section. The agent does not revert the Status — anomalies are surface-only.

**Status-string canonicalization.** Status values that are **not** the bare strings `Proposed`, `Accepted`, `Superseded`, or `Rejected` (after rstrip) are treated as **annotated** values — the file is skipped for auto-flip and for README index reconciliation. Examples in the current corpus: ADR-0003's `Accepted (Phase 1)`, ADR-0004's `Superseded by [ADR-0007](...)`. Annotated values are author-maintained and the agent does not normalize them.

**9c. Apply auto-flips, capped by `MAX_FLIPS_PER_RUN`.**

```bash
MAX_FLIPS_PER_RUN=3
```

Sort the `ready`-category list ascending by ID (ADRs first, then PDRs). Take the first `MAX_FLIPS_PER_RUN` entries; the rest are deferred to a future run and listed in `proposed-adrs.md` "Pending Flip" section with a banner.

For each entry being flipped:

```bash
# Tolerate trailing whitespace (markdown line-break style); the body is not touched.
sed -i -E 's/^\*\*Status:\*\* Proposed[[:space:]]*$/**Status:** Accepted/' "$ADR_PATH"
```

After all flips, re-read each flipped file to confirm the edit landed (defense against sed pattern misses — e.g., file uses `**Status:**  Proposed` with a double space, or some other shape that breaks the regex). If the file is still `Proposed` after the sed, **append a row to `proposed-adrs.md` "Anomalies" section** describing the miss (e.g., `ADR-NNNN | sed pattern miss: status line shape '**Status:**  Proposed' did not match expected pattern`). Do not retry, do not crash. This is more durable than a PR-description-only log because it persists across runs until the underlying file is fixed.

**9d. Render `initiatives/proposed-adrs.md`.**

Fully rewrite the file each run with the post-flip state. Structure:

```markdown
# Proposed ADRs and PDRs Awaiting Acceptance

Tracked automatically by the hive-sync agent. ADRs/PDRs with all implementing
issues closed are auto-flipped to Accepted on each run; the rest are listed
here with progress.

Last synced: {YYYY-MM-DD}

## Awaiting (no `accepts:`-declaring packets yet)

These have no packets declaring them in `accepts:` frontmatter. Auto-flip
will not happen until the scope agent files at least one packet that
declares the decision in `accepts:`. Legacy Proposed ADRs whose
implementing packets pre-date the `accepts:` convention also appear here
and remain manually-flippable until rescoped.

| ID | Title | Sector | Dated | Days in Proposed |
|----|-------|--------|-------|------------------|
| ... | ... | ... | ... | ... |

## In Progress (implementing packets filed; some issues still open)

| ID | Title | Sector | Dated | Closed/Total | Days in Proposed |
|----|-------|--------|-------|--------------|------------------|
| ... | ... | ... | ... | 2/4 | 12 |

## Pending Flip (qualified for auto-flip but exceeds MAX_FLIPS_PER_RUN this run)

> Flip queue exceeds the per-run limit (3); the entries below will flip on subsequent runs.

| ID | Title | Sector | Dated | All Implementing Packets Closed Since |
|----|-------|--------|-------|---------------------------------------|
| ... | ... | ... | ... | YYYY-MM-DD |

## Anomalies

Surface-only items. The agent does not act on these — the human/scope agent does.

| Category | ID / Item | Detail | First Surfaced |
|----------|-----------|--------|----------------|
| reopened-issue | ADR-NNNN | Issue {url} was closed at {date}, now open again | YYYY-MM-DD |
| sed-miss | ADR-NNNN | status line shape did not match expected pattern | YYYY-MM-DD |
| missing-readme-row | ADR-NNNN | file exists but no row in `adrs/README.md` | YYYY-MM-DD |
| orphan-readme-row | ADR-NNNN | README row points to missing file | YYYY-MM-DD |

## Flipped This Run

ADRs/PDRs whose Status was changed by **this** sync run from `Proposed` to `Accepted`. Regenerated each run from the current run's flips only — for the historical record of when each ADR was accepted, see the file's `**Date:**` frontmatter and `adrs/README.md` Date column.

| ID | Title | Triggering Packets |
|----|-------|---------------------|
| ... | ... | ... |
```

Rules:

- **Sort:** ascending number within each section; ADRs before PDRs.
- **Empty sections:** render the line `_None._` so structure is preserved.
- **The "Flipped This Run" section** is per-run, not cumulative. The next run regenerates it from that run's flips only. Historical acceptance dates live in ADR/PDR frontmatter and the README index.
- **The "Anomalies" section is rebuilt each run.** Anomalies that disappear between runs are silently dropped — `proposed-adrs.md` is a current-state surface, not an audit trail. Long-running drift items belong in `drift-report.md` (Packet 06), which preserves First Surfaced dates. The "First Surfaced" column in this Anomalies table reflects the current run's date for items first detected this run; for items persisting from prior runs, the date carries over via the same parser approach Packet 06 uses (Step 11h) — implementations of 9d and 11h share the parser code path.
- **Days in Proposed** uses the ADR/PDR file's `**Date:**` frontmatter as the start, `today` as the end.
- **Empty file (everything in all categories is empty AND nothing flipped this run):** render `_No Proposed ADRs/PDRs — the queue is clear._` as the body.

**9e. Reconcile `adrs/README.md` and `pdrs/README.md` Status/Date columns.**

After the auto-flips in 9c, both index files may be stale. For each `adrs/ADR-*.md` and `pdrs/PDR-*.md`:

1. Read the file's `**Status:**` and `**Date:**` frontmatter values. **`rstrip` trailing whitespace before comparing** — frontmatter lines may carry trailing whitespace (markdown line-break style) that is invisible but causes naive equality to fail. Confirmed corpus examples at scoping time: ADRs 0001-0006 and PDR-0001 use `**Status:** Accepted  ` (two trailing spaces).
2. **Skip annotated Status values.** If the frontmatter Status (after rstrip) is anything other than `Proposed`, `Accepted`, `Superseded`, or `Rejected`, the file uses an annotated Status (e.g., `Accepted (Phase 1)`, `Superseded by [ADR-0007](...)`). The agent does not reconcile these — annotated Status values are author-maintained.
3. Locate the row in the corresponding README that links to this file. Match the link target by extracting the ADR/PDR number from the filename (`ADR-NNNN-...md`) and finding the row whose first cell contains a markdown link whose target ends with `ADR-NNNN-...md` (resilient to leading `./` or other path-prefix variations in the index).
4. If the row's Status column (after rstrip) does not match the frontmatter Status, update it.
5. If the row's Date column (after rstrip) does not match the frontmatter Date, update it.
6. If no row exists for an ADR/PDR file: append an entry to the queue file's "Anomalies" section with category `missing-readme-row` — do not synthesize a row (Title/Sector/Impact require human judgment).
7. If a README row links to a file that does not exist: append to "Anomalies" with category `orphan-readme-row` — do not auto-delete (the file may be in the process of being renamed).

The Title, Sector, and Impact columns are author-maintained; the agent does not touch them. The link text and link target are also unchanged unless the agent is reconciling a flipped file (in which case neither the link nor any non-Status/Date column changes).
```

**Renumbering note.** This packet replaces the body of the existing Step 9 in place; no new step number is added and no other step is renumbered. After this packet lands, Step 10 remains "Move Closed Packets to completed/" (from Packet 02, carried through Packets 03 and 04) and Step 11 remains "Commit and Open PR". Packet 06 will later insert Step 11 (Drift Detection) and push Commit to Step 12.

**PR-title signal for runs that flip ADRs/PDRs.** When a sync run performs at least one auto-flip, the agent appends ` (N flips)` to the PR title (e.g., `chore: sync hive state (2026-05-15) (1 flip)` or `(3 flips)`). This makes semantically significant runs visible in the PR list without opening the body. Runs with zero flips keep the existing title shape unchanged. Update the agent's Step 12 (Commit and Open PR) PR-title formatting accordingly.

### Part B — Update Constraints in `hive-sync.md`

Find the Constraints block (last touched by Packets 02 and 03). Replace the bullet that currently reads:

```markdown
- The `hive-sync` agent **never modifies any ADR file**. It reads `**Status:**` frontmatter to surface Proposed ADRs but does not flip status, edit body, or rename. ADR acceptance is the `scope` agent's coordinated mechanical flip; ADR drafting is the `adr-composer` agent's job.
```

with:

```markdown
- The `hive-sync` agent's authority over ADR/PDR files is **bounded to a single edit**: flipping `**Status:** Proposed` to `**Status:** Accepted` when every implementing packet's issue is closed. The agent never edits the ADR/PDR body, never renames the file, never flips the reverse direction (Accepted → Proposed), and never sets any other status (Superseded/Rejected). ADR drafting is the `adr-composer` agent's job; coordinated multi-edit acceptance flips that include invariant additions or surface creation are the `scope` agent's job (see ADR-0014 D7).
- The `hive-sync` agent's authority over `adrs/README.md` and `pdrs/README.md` is bounded to **the Status and Date columns only**. Title, Sector, and Impact columns are author-maintained; the agent never touches them. Link text and link targets are also untouched.
```

Append a new bullet to the Constraints block:

```markdown
- The `hive-sync` agent surfaces missing-row and orphan-row anomalies in `proposed-adrs.md` "Anomalies" section but **never auto-adds or auto-deletes README index rows**. Adding a row requires Title/Sector/Impact context the agent does not have; deleting one risks silent loss when an ADR file is in the middle of a rename.
```

### Part C — Update Step 1 (Gather Data) preamble

In `.claude/agents/hive-sync.md`, find Step 1g (added by Packet 04) and **replace** it with a generalized version that also enumerates PDRs:

```markdown
**1g. Enumerate ADR and PDR frontmatter (for Step 9 reconciliation).**

```bash
ls adrs/ADR-*.md > /tmp/adr-files.txt
ls pdrs/PDR-*.md > /tmp/pdr-files.txt
```

For each file in both lists, read the first ~10 lines and extract the frontmatter fields (Status, Date, Sector). Also build the **implementing-packet index** described in Step 9a — for each packet under `generated/issue-packets/{active,completed}/`, parse the YAML frontmatter `adrs:` and `pdrs:` fields. Write the parsed result to `/tmp/decision-frontmatter.json` for use by Step 9.
```

### Part D — Generalize and re-seed `initiatives/proposed-adrs.md`

The file `initiatives/proposed-adrs.md` was created by Packet 04 with an ADRs-only single-table structure. After this packet lands, the same file covers ADRs **and** PDRs and gains the new five-section structure (Awaiting / In Progress / Pending Flip / Anomalies / Flipped This Run).

The first agent run after Packet 05 lands rewrites the file to the new structure from live state. The PR for Packet 05 itself does not pre-seed the file with the new structure — the rewrite happens on the first sync run, exactly the same way every other tracking file in this rollout is seeded.

If you want the new structure visible immediately in the merge commit (e.g., for review confidence), the executing OpenClaw agent **may** dry-run the new logic locally and include the resulting file in the PR. This is optional — the next scheduled/manual OpenClaw run will produce it regardless.

### Part E — Initiative trackers

Update the existing "Hive Sync Rollout (ADR-0014)" entry in `initiatives/active-initiatives.md` (last touched by Packet 04) by checking off Packet 05:

```markdown
- [x] Architecture#NN: ADR/PDR auto-acceptance + README index sync (packet 05)
```

The Packet 06 checkbox remains unchecked. No closing Sync annotation is added by this packet — that is Packet 06's job, the actual closing packet of the rollout.

### Part F — Update `.claude/agents/scope.md` to write the new `accepts:` packet frontmatter field

The `accepts:` field is a new convention introduced by this packet. The scope agent (which writes packet bodies and frontmatter) must learn to populate it. Edit `.claude/agents/scope.md` as follows:

1. **Locate the packet-frontmatter template** (or the section describing what fields to emit on each packet). It currently includes `adrs:` as a list of referenced decisions.
2. **Add an `accepts:` field** alongside `adrs:`. Description: `accepts:` is the list of Proposed ADRs and PDRs that this specific packet's closure (combined with the closure of every other packet declaring the same decision in `accepts:`) signals as the acceptance trigger. `adrs:` continues to mean "decisions referenced or touched by this packet" — a cataloging field for drift detection and human cross-referencing.
3. **Specify the convention rules:**
   - Only Proposed ADRs/PDRs go into `accepts:`. Already-Accepted decisions belong only in `adrs:` (referenced) or are omitted if irrelevant.
   - A packet may have an empty `accepts:` (or omit the field entirely) if it does not gate any decision's acceptance — e.g., a hardening packet that touches Accepted infrastructure.
   - A packet may declare multiple decisions in `accepts:` if it is one piece of a multi-decision rollout (e.g., a packet implementing both ADR-0026 and PDR-0002 simultaneously).
4. **Add a short example** showing the field next to existing fields:

   ```yaml
   adrs: ["ADR-0026", "PDR-0002"]
   accepts: ["PDR-0002"]   # this packet implements PDR-0002; ADR-0026 is just referenced
   ```

5. **Document the legacy-data note:** packets filed before Packet 05 lands do not carry `accepts:`. They are not auto-flip eligible. ADRs whose only implementing packets pre-date this convention remain manually-flippable via the scope agent until rescoped.

This update is part of the same PR as the agent file edit. Per invariant 33, `scope.md` and `review.md` context-loading sections must remain coupled — but `accepts:` is a frontmatter field, not a context-loading addition, so this Part F does **not** trigger an invariant-33 review-agent update.

## Affected Files

- `.claude/agents/hive-sync.md` — replace Step 9 body, replace Step 1g, update Constraints block
- `.claude/agents/scope.md` — add the `accepts:` frontmatter field convention (Part F)
- `initiatives/proposed-adrs.md` — file structure changes; first sync run after merge re-renders to the new structure (or the executing agent dry-runs and includes the new file in the PR)
- `initiatives/active-initiatives.md` — check off Packet 05
- `CHANGELOG.md` — append entry referencing the auto-acceptance + README sync addition + the new `accepts:` field convention

## NuGet Dependencies

None. This is a docs/markdown change; no .NET projects touched.

## Boundary Check

- [x] Architecture-only edits. No other repo touched.
- [x] No new code or build artifact.
- [x] **The agent now writes to ADR/PDR Status frontmatter and README Status/Date columns** — this is a deliberate expansion of `hive-sync`'s mutation surface, justified in ADR-0014 D7/D8. The expansion is bounded by the Constraints block (Part B) and is enumerated in the agent's mutation surface area (ADR-0014 Architectural Consequences).
- [x] Invariant 24 preserved — no edits to filed packet bodies. The agent reads packet frontmatter (`adrs:`, `pdrs:`) but does not modify packet content.
- [x] Invariant 33 preserved — `scope.md` and `review.md` context-loading sections are untouched.

## Acceptance Criteria

- [ ] `.claude/agents/hive-sync.md` Step 9 is renamed from "Surface Proposed-ADR Acceptance Queue" to "ADR/PDR Acceptance Reconciliation" and contains the 9a-9e logic from Part A verbatim (substantively).
- [ ] Step 1g is generalized to enumerate both `adrs/ADR-*.md` and `pdrs/PDR-*.md`, plus the implementing-packet index built from packet `accepts:` fields. The file `/tmp/decision-frontmatter.json` is the named output.
- [ ] Step 9a uses the new `accepts:` packet frontmatter field — **not** `adrs:` — to determine implementing packets. Packets without `accepts:` (or with empty `accepts:`) do not contribute to any decision's auto-flip eligibility.
- [ ] Step 9c uses the regex `^\*\*Status:\*\* Proposed[[:space:]]*$/**Status:** Accepted/` (tolerates trailing whitespace).
- [ ] Step 9c implements the `MAX_FLIPS_PER_RUN = 3` cap; excess candidates are surfaced in `proposed-adrs.md` "Pending Flip" section.
- [ ] Step 9e skips Status values that are not in `{Proposed, Accepted, Superseded, Rejected}` (after rstrip). Annotated values like ADR-0003's `Accepted (Phase 1)` and ADR-0004's `Superseded by [ADR-0007](...)` are not modified.
- [ ] Step 9c writes sed-miss anomalies to `proposed-adrs.md` "Anomalies" section (not just PR description).
- [ ] The Constraints block contains the bounded-authority text from Part B (replaces the prior "never modifies any ADR file" bullet) plus the new anomaly-surface bullet.
- [ ] `.claude/agents/scope.md` is updated per Part F to instruct writing `accepts:` for new packets, with the example and convention rules described there. The `adrs:` field convention is unchanged.
- [ ] On the first scheduled/manual OpenClaw run after this PR merges:
  - Every Proposed ADR with at least one packet declaring it in `accepts:` whose every issue is `closed` is flipped to `Accepted` (subject to the `MAX_FLIPS_PER_RUN` cap). The flip is a single-line `**Status:**` edit; the ADR body is unchanged.
  - Every Proposed PDR matching the same criterion is flipped.
  - `adrs/README.md` and `pdrs/README.md` index rows have Status and Date columns matching the post-flip frontmatter (rstrip applied; annotated values skipped).
  - `initiatives/proposed-adrs.md` is rewritten to the new five-section structure (Awaiting / In Progress / Pending Flip / Anomalies / Flipped This Run).
- [ ] No ADR or PDR file's body is modified by `hive-sync`. `git diff -- adrs/ pdrs/` after a sync run shows only one-line Status changes (and Date changes if the ADR/PDR file's frontmatter Date was edited manually since the previous run).
- [ ] No README index row's Title, Sector, or Impact column is modified by `hive-sync`.
- [ ] If an `ADR-NNNN.md` file exists with no corresponding README row, the `hive-sync` PR includes an entry in `proposed-adrs.md` "Anomalies" section with category `missing-readme-row`. The agent does not synthesize the row.
- [ ] `initiatives/active-initiatives.md` "Hive Sync Rollout (ADR-0014)" Tracking list shows the Packet 05 checkbox checked and the Packet 06 checkbox unchecked. No closing Sync annotation is added by this packet.
- [ ] Repo-level `CHANGELOG.md` entry appended for this version.

## Human Prerequisites

None. This packet is fully delegable.

**Operational note for the human reviewer:**

- [ ] After merge, observe the **first scheduled/manual OpenClaw run** of `hive-sync`. Spot-check that any ADRs/PDRs flipped to Accepted in that run are correctly identified — i.e., their implementing packets are genuinely all closed. If a flip is wrong (rare; would indicate a packet's `adrs:` frontmatter is misleading), manually revert the ADR's Status to `Proposed` in a follow-up PR. The agent will not re-flip until at least one issue closes again, so the manual revert is stable.

## Referenced Invariants

> **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Filing is the point of no return. Before a packet is filed, it may be amended to fill in missing operational context (e.g. NuGet dependencies, key files, constraints) without violating this rule. After filing, state lives on the org Project board, never in the packet file. If requirements change materially post-filing, write a new packet rather than editing the old one.

This invariant constrains the implementing-packet index (Step 9a): the agent reads packet frontmatter `adrs:` / `pdrs:` fields but never modifies packet content. The auto-flip logic does not edit any packet — it only edits the ADR/PDR file referenced by the packet's frontmatter.

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled. The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other.

This packet does not touch `scope.md` or `review.md`. The new mutation surfaces (`adrs/`, `pdrs/`, README indexes) are owned by `hive-sync` alone; they are not part of either the scope or review agent's required-reading list.

## Referenced ADR Decisions

**ADR-0014 D7 (ADR/PDR auto-acceptance):** Auto-flip Proposed → Accepted when (a) at least one implementing packet exists, and (b) every implementing GitHub issue is closed. Packet-existence guard prevents auto-acceptance of pure-documentation ADRs that have no implementing work. Reverse-direction flips (Accepted → Proposed) are explicitly never automated. Anomalies (post-acceptance issue reopens) are surfaced but not acted on.

**ADR-0014 D8 (README index reconciliation):** Status and Date columns in `adrs/README.md` and `pdrs/README.md` are reconciled to ADR/PDR frontmatter every run. Title/Sector/Impact columns are author-maintained. Missing rows and orphan rows are surfaced as anomalies, never auto-fixed.

**ADR-0014 Phase Plan, Phase 5 exit criterion:** "every Proposed ADR/PDR with all implementing issues closed has been flipped to Accepted; every README index row's Status and Date columns match the file's frontmatter."

## Dependencies

- Wave 4: [Packet 04 — Surface Proposed-ADR queue (read-only)](./04-architecture-proposed-adrs-queue.md)

Reason: this packet replaces the Step 9 body that Packet 04 introduced. The Step 9 hook must already exist (created by Packet 04) before this packet can rewrite its contents. Packet 04 created `initiatives/proposed-adrs.md` as a read-only surface; this packet adds the auto-flip mutation authority and the README index sync, generalizing the queue into runtime automation.

## Labels

`feature`, `tier-2`, `meta`, `docs`, `adr-0014`, `wave-5`

## Agent Handoff

**Objective:** Replace the read-only `proposed-adrs.md` queue (from Packet 04) with the auto-acceptance + README sync logic. Generalize coverage to include PDRs. Surface anomalies (reopened issues, missing/orphan README rows) without acting on them.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main` (suggested branch name: `chore/adr-0014-hive-sync-phase-5`).

**Context:**
- Goal: Fifth phase of the ADR-0014 rollout. Adds bounded mutation authority over ADR/PDR Status frontmatter and README index columns.
- Feature: ADR-0014 — Hive–Architecture Reconciliation Agent.
- ADRs: ADR-0014.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Packet 04 (this initiative, Wave 4) must merge first.

**Constraints:**
- **Invariant 24** (full text above) — packet bodies are immutable; the agent reads frontmatter but does not edit. Packets 01-06 of this rollout carry `accepts: ["ADR-0014"]` (added pre-filing per the invariant's pre-filing amendment allowance).
- **Invariant 33** (full text above) — `scope.md` and `review.md` context-loading sections are not modified. The Part F edit to `scope.md` adds a frontmatter-field convention, not a context-loading entry.
- **Bounded ADR/PDR write authority.** The agent only flips `Proposed` → `Accepted` and only when all four guard rules pass (at least one `accepts:`-declaring packet; all such packets' issues closed; status string is canonical; per-run cap not exceeded). It never edits the body, renames, or sets any other status.
- **Bounded README write authority.** Status and Date columns only. Title/Sector/Impact are author-maintained. Annotated Status values (e.g., `Accepted (Phase 1)`) are skipped.
- **Anomaly surfacing, not auto-fixing.** Reopened issues, missing rows, orphan rows, and sed-pattern misses go into the queue file's "Anomalies" section. The agent never auto-reverts a flip and never auto-adds or deletes README rows.
- **Idempotency.** A re-run with the same input produces the same output. Specifically: an ADR auto-flipped on run N is `Accepted` on run N+1, so the auto-flip logic is a no-op on subsequent runs (the ADR is no longer `Proposed`).
- **`MAX_FLIPS_PER_RUN = 3`** caps the auto-flip count per run. Excess candidates are surfaced as "Pending Flip" and processed on subsequent runs.

**Key Files:**
- `.claude/agents/hive-sync.md` — replace Step 9 body, replace Step 1g, update Constraints block.
- `.claude/agents/scope.md` — add the `accepts:` frontmatter-field convention (Part F).
- `adrs/ADR-*.md` files (Proposed-status only with at least one `accepts:`-declaring packet whose every issue is closed) — Status front-matter line may flip from `Proposed` to `Accepted` on the first sync run after merge. On the first run, that set is likely empty (no packets yet carry `accepts:` other than Packets 01-06 of this rollout, which won't all be closed yet).
- `pdrs/PDR-*.md` files — same.
- `adrs/README.md` — Status and Date columns reconciled (canonical statuses only; annotated skipped).
- `pdrs/README.md` — same.
- `initiatives/proposed-adrs.md` — re-rendered with the new five-section structure on first run after merge.
- `initiatives/active-initiatives.md` — Packet 05 checkbox checked.
- `CHANGELOG.md` — append entry.

**Contracts:**
- The packet frontmatter `adrs:` and `pdrs:` fields are the contract between scoping (which lists ADRs/PDRs implemented) and `hive-sync` (which reads those lists). A scoped packet that omits `adrs:` will not contribute to auto-acceptance; that's a scoping bug, not a `hive-sync` bug.
- The ADR/PDR Status frontmatter line shape (`**Status:** Proposed` / `**Status:** Accepted`) is the contract between author convention and `hive-sync`'s sed pattern. ADRs that deviate from this shape are not auto-flipped.
