---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0014", "wave-6"]
dependencies: ["adr-0014-hive-sync-rollout/05-architecture-adr-pdr-auto-acceptance"]
adrs: ["ADR-0014"]
accepts: ["ADR-0014"]
wave: 6
initiative: adr-0014-hive-sync-rollout
node: honeydrunk-architecture
---

# Feature: Surface drift between Accepted decisions and the rest of the Architecture repo

## Summary
Add a drift-detection step to `.claude/agents/hive-sync.md` that runs last in the agent's workflow, scans the repo for inconsistencies between Accepted ADRs/PDRs and the catalogs/constitution/agent files, and writes the results to a new tracking file `initiatives/drift-report.md`. The agent **only surfaces drift; it never auto-fixes** — every category requires architectural judgment that belongs to the scope/adr-composer agents or to a human. The drift-report uses a "First Surfaced" sticky-date column to reveal long-standing drift; this is the single exception to `hive-sync`'s "fully rewritten" rule for tracking files.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0014 D9 names the gap. ADRs and PDRs name invariants, agents, nodes, and contracts that should exist elsewhere in the repo — in `constitution/invariants.md`, `constitution/agent-capability-matrix.md`, `catalogs/nodes.json`, and `.claude/agents/`. When an ADR is authored that names invariant 42 but `invariants.md` ends at 41, that's drift. When `agent-capability-matrix.md` lists an agent that has no `.claude/agents/{name}.md` file (or vice versa), that's drift. When `catalogs/nodes.json` lists a node whose GitHub repo does not exist (or an Accepted ADR names a node that's missing from `nodes.json`), that's drift.

Drift is corrosive because each individual gap is small and easy to ignore, but the aggregate erodes trust in the Architecture repo as a source of truth. Today there is no surface that lists drift; gaps are discovered ad-hoc when an agent tries to look up something that should exist.

This packet adds a single drift report covering five categories. The agent surfaces the drift but does not fix it — fixing would require:

- Writing invariant prose, sector references, and ADR linkage (an ADR-author or scope-agent task).
- Writing matrix Trigger/Consumes/Produces/Cannot-Do columns (an agent-author task).
- Writing nodes.json sector, ownership, and dependency fields (an architecture-author task).
- Creating GitHub repos with the right config (a human task plus repo bootstrap).

The agent's role stops at "this is wrong." Resolution is owned by the agents/humans who have the right context.

The five categories are the **initial scope**. Future ADRs may add categories as new drift patterns become visible.

## Scope

All edits are in the `HoneyDrunk.Architecture` repo. No code (no `.cs` files). No secrets.

### Part A — Add Step 11 (Drift Detection) to `hive-sync.md`

In `.claude/agents/hive-sync.md`, insert a new Step **between the existing Step 10 (Move Closed Packets to completed/, from Packet 02 — note: this was renumbered as Steps shifted from Packets 03-04-05) and the final Commit step**. The new step is numbered Step 11; the Commit step becomes Step 12. The new step reads:

```markdown
### Step 11: Drift Detection

Scan the repo for inconsistencies between Accepted ADRs/PDRs and the catalogs/constitution/agent files. Surface findings in `initiatives/drift-report.md`. Do not auto-fix.

This step runs **last** in the workflow (before the Commit step). It sees the post-mutation state — auto-flips from Step 9, packet moves from Step 10, and any other writes performed earlier — so its findings reflect the PR's outgoing state, not the incoming state.

**11a. Read the previous drift-report.md to preserve "First Surfaced" dates.**

```bash
if [[ -f initiatives/drift-report.md ]]; then
  cp initiatives/drift-report.md /tmp/prev-drift-report.md
fi
```

The previous file's "First Surfaced" column values are read into an in-memory map keyed by `{category, item-identity}`. New items get today's date; items that persist from a prior run keep their original First Surfaced date.

**11b. Drift category 1 — Invariants named in Accepted ADRs but missing from `invariants.md`.**

For each `adrs/ADR-*.md` file with `**Status:** Accepted`:

1. Scan the body for patterns that name invariants. Three patterns to support (more may be added in follow-ups):
   - Section heading "Grid Tracking Invariants" or "Hive Sync Invariants" or similar followed by numbered prose `^\d+\. \*\*[^*]+\*\*`
   - Inline references "invariant N" or "invariants N–M" with descriptive text
   - "The following invariant(s) should be added to `constitution/invariants.md`:" followed by numbered prose
2. Extract each named invariant's **bold-title text** (the `**...**` opening of the prose).
3. Verify the title text appears in `constitution/invariants.md` as the bold opening of any numbered invariant. The number does not need to match — only the title text. (The title is the stable identity; numbers shift as invariants are appended.)
4. List any title that is missing.

Output rows: `| ADR | Invariant Title | First Surfaced |`.

**11c. Drift category 2 — Capability matrix rows with no agent file.**

Read `constitution/agent-capability-matrix.md`. For each row in the main agent table, extract the agent name (the `**name**` cell). Verify a file exists at `.claude/agents/{name}.md`. List any missing files.

Output rows: `| Agent Name | Matrix Row Excerpt | First Surfaced |`.

**11d. Drift category 3 — Agent files with no capability matrix row.**

List every file matching `.claude/agents/*.md`. For each, extract the YAML `name:` field. Verify the name appears as a row in `constitution/agent-capability-matrix.md`'s main agent table.

**Meta-agent exclusion list.** Some agents are meta-decision-making and intentionally absent from the runtime matrix. Initial exclusion list (maintained inline in `hive-sync.md` and referenced from `constitution/agent-capability-matrix.md`'s "Decision Authority" section):

```text
adr-composer
pdr-composer
scope
file-issues
review
refine
netrunner
node-audit
product-strategist
site-sync
```

(Note: `initiatives-sync` is **not** in this list because Packet 01 deleted the file. By Packet 06's execution time, no `initiatives-sync.md` exists in `.claude/agents/` and Step 11d would not see it. The rolled-back-Packet-01 edge case — `initiatives-sync.md` reappears via revert — is not handled here; if that happens, add `initiatives-sync` back to the exclusion list as a transient entry.)

Agent files matching the exclusion list are not surfaced as drift. Agent files NOT in the matrix AND NOT in the exclusion list are surfaced. The exclusion list lives at the top of Step 11d in `hive-sync.md` so it is editable in the same review surface as the drift logic.

Output rows: `| Agent File | First Surfaced |`.

**11e. Drift category 4 — Nodes in `nodes.json` whose GitHub repo does not exist.**

Read `catalogs/nodes.json`. For each entry, extract the `repo` field (or the `name` field if `repo` is absent — convention varies). Run:

```bash
gh repo view "HoneyDrunkStudios/${REPO}" --json name 2>&1 | grep -q '^{' || echo "missing: ${REPO}"
```

For repos that fail to resolve (the `gh` call returns a non-`{` line), surface the entry. Authentication errors (401/403) are NOT drift — surface them as a separate "Auth issues" subsection so the operator can fix the token rather than the catalog.

Output rows: `| Node | Repo | First Surfaced |`.

**11f. Drift category 5 — Nodes named in Accepted ADRs but missing from `nodes.json`.**

For each `adrs/ADR-*.md` file with `**Status:** Accepted`:

1. Scan the body for patterns that name nodes. Initial pattern: `HoneyDrunk\.[A-Z][A-Za-z]*` capturing the canonical Grid-namespace form.
2. **Apply the seed exclusion list** (below). Names in the exclusion list are not flagged as drift even if they don't appear in `nodes.json`.
3. For each remaining unique match, verify it appears as an entry in `catalogs/nodes.json` (by name).
4. List any names that are missing.

Output rows: `| ADR | Node Name | First Surfaced |`.

**Inline seed exclusion list** (maintained at the top of Step 11f in `hive-sync.md` so changes are reviewed alongside drift logic):

```text
HoneyDrunk.Studios          # public website (PDR-0001, PDR-0002, ADR-0003) — not a Grid Node
HoneyDrunk.Architecture     # this repo — meta-decisions live here, not a deployable Node
HoneyDrunk.Standards        # shared standards repo — referenced from ADRs but not a runtime Node
HoneyDrunk.Actions          # CI/CD control plane (ADR-0012) — has its own catalog presence; commonly named in passing
HoneyDrunk.Lore             # narrative/canon repo — not a runtime Node
HoneyDrunk.CoreWorkspace    # workspace meta-repo — not a Node
```

The exclusion list grows as new false-positive patterns surface. It is reviewable code, not a config file — adding an entry requires the same code-review surface as adding a drift category. If the exclusion list grows beyond ~15 entries, consider extracting to a sibling file `initiatives/drift-exclusions.md` that the operator maintains; for the first cut, inline is simplest.

**Remaining false-positive risk after the seed list:** ADRs may mention novel `HoneyDrunk.X` names in passing (e.g., a hypothetical "HoneyDrunk.Audit" mentioned in a comparison sentence). The agent does not have semantic disambiguation; the operator extends the exclusion list as new false positives appear. Initial implementation: surface all matches not in the seed list; if false positives become noisy, extend the list.

**11g. Render `initiatives/drift-report.md`.**

Use the structure from ADR-0014 D9 verbatim:

```markdown
# Drift Report

Tracked automatically by the hive-sync agent. Items listed here are
inconsistencies between Accepted decisions and the rest of the Architecture
repo. The agent surfaces these — it does not fix them. Resolution is the
scope/adr-composer/human's responsibility.

Last synced: {YYYY-MM-DD}

## Invariants Named in ADRs but Missing from `invariants.md`

| ADR | Invariant Title | First Surfaced |
|-----|-----------------|----------------|
| ... | ... | ... |

## Capability Matrix Rows with No Agent File

| Agent Name | Matrix Row Excerpt | First Surfaced |
|------------|--------------------|----------------|
| ... | ... | ... |

## Agent Files with No Capability Matrix Row

| Agent File | First Surfaced |
|------------|----------------|
| ... | ... |

## Nodes in `nodes.json` with Missing GitHub Repos

| Node | Repo | First Surfaced |
|------|------|----------------|
| ... | ... | ... |

### Auth Issues (token-scope problems, not drift)

| Repo | Status | First Surfaced |
|------|--------|----------------|
| ... | ... | ... |

## Nodes Named in ADRs but Missing from `nodes.json`

| ADR | Node Name | First Surfaced |
|-----|-----------|----------------|
| ... | ... | ... |
```

Empty section bodies render as `_No drift detected._`. Empty entire file (no drift in any category) renders as a single line `_No drift detected across any category. The Architecture repo is in sync with its Accepted decisions._` after the header.

**11h. Persistence rule for First Surfaced dates.**

When rewriting the file, look up each item in the previous file's content. If the same item (by category + identity) was present, copy its First Surfaced value. If new, use today's date. This is the single exception to `hive-sync`'s "fully rewritten each run" convention — the audit trail of "how long has this been broken" is too valuable to discard each run.

The identity rules per category:
- Invariants: `(ADR-NNNN, Invariant Title)` is the key.
- Matrix rows with no agent file: `Agent Name`.
- Agent files with no row: `Agent File`.
- Missing repos: `Repo`.
- Auth issues: `Repo`.
- ADR-named nodes: `(ADR-NNNN, Node Name)`.

**Concrete parser implementation.** The previous file's tables are markdown pipe-delimited; awk on `|` splits cells. Each section's header line uniquely identifies the category. Build a `prev_first_surfaced` associative array keyed by `"category|identity"`:

```bash
# After 11a copies the previous file to /tmp/prev-drift-report.md, parse it.
declare -A PREV_DATES

# Helper: extract rows from a section (between section header and next ## header)
extract_section() {
  local file="$1"
  local section_header="$2"
  awk -v section="$section_header" '
    $0 == section {p=1; next}
    /^## / && p==1 {p=0}
    p && /^\| [^|-]/ {print}
  ' "$file"
}

# Category 1: invariants — key = (ADR, Title), date in column 4
while IFS='|' read -r _ adr title date _; do
  adr=$(echo "$adr" | xargs); title=$(echo "$title" | xargs); date=$(echo "$date" | xargs)
  [[ -z "$adr" || "$adr" == "ADR" || "$adr" == --* ]] && continue
  PREV_DATES["invariants|${adr}|${title}"]="$date"
done < <(extract_section /tmp/prev-drift-report.md "## Invariants Named in ADRs but Missing from \`invariants.md\`")

# Category 2: matrix rows — key = Agent Name, date in column 4
while IFS='|' read -r _ agent _ date _; do
  agent=$(echo "$agent" | xargs); date=$(echo "$date" | xargs)
  [[ -z "$agent" || "$agent" == "Agent Name" || "$agent" == --* ]] && continue
  PREV_DATES["matrix-rows|${agent}"]="$date"
done < <(extract_section /tmp/prev-drift-report.md "## Capability Matrix Rows with No Agent File")

# Category 3: agent files — key = Agent File, date in column 3
while IFS='|' read -r _ file date _; do
  file=$(echo "$file" | xargs); date=$(echo "$date" | xargs)
  [[ -z "$file" || "$file" == "Agent File" || "$file" == --* ]] && continue
  PREV_DATES["agent-files|${file}"]="$date"
done < <(extract_section /tmp/prev-drift-report.md "## Agent Files with No Capability Matrix Row")

# Category 4: missing repos — key = Repo, date in column 4
while IFS='|' read -r _ node repo date _; do
  repo=$(echo "$repo" | xargs); date=$(echo "$date" | xargs)
  [[ -z "$repo" || "$repo" == "Repo" || "$repo" == --* ]] && continue
  PREV_DATES["missing-repos|${repo}"]="$date"
done < <(extract_section /tmp/prev-drift-report.md "## Nodes in \`nodes.json\` with Missing GitHub Repos")

# Auth issues subsection: same key as missing repos but separate prefix
while IFS='|' read -r _ repo _ date _; do
  repo=$(echo "$repo" | xargs); date=$(echo "$date" | xargs)
  [[ -z "$repo" || "$repo" == "Repo" || "$repo" == --* ]] && continue
  PREV_DATES["auth-issues|${repo}"]="$date"
done < <(extract_section /tmp/prev-drift-report.md "### Auth Issues (token-scope problems, not drift)")

# Category 5: ADR-named nodes — key = (ADR, Node Name), date in column 4
while IFS='|' read -r _ adr node date _; do
  adr=$(echo "$adr" | xargs); node=$(echo "$node" | xargs); date=$(echo "$date" | xargs)
  [[ -z "$adr" || "$adr" == "ADR" || "$adr" == --* ]] && continue
  PREV_DATES["adr-named-nodes|${adr}|${node}"]="$date"
done < <(extract_section /tmp/prev-drift-report.md "## Nodes Named in ADRs but Missing from \`nodes.json\`")

# When rendering each row in the new file, look up:
#   first_surfaced=${PREV_DATES["category|identity"]:-$(date +%Y-%m-%d)}
```

**Edge case handling:**

- **No previous file:** if `/tmp/prev-drift-report.md` does not exist (first run after Packet 06 lands), `PREV_DATES` is empty and every row gets today's date. This is the seed.
- **Previous file has malformed table rows:** the awk extraction skips rows starting with `--` (separator lines) and the header row. Other malformed rows (rare) get silently skipped — the worst case is a date reset for that one item, which is acceptable.
- **Empty-state line in a category:** when the previous file rendered `_No drift detected._` for a section, no rows are extracted, no entries land in `PREV_DATES`. New items in that category on this run all get today's date — correct.
- **Items moved between categories:** if a drift item changes category (e.g., a missing repo gets fixed but the same name now drifts as ADR-named node), the First Surfaced date resets — that's correct because it's a different drift.
```

The Commit step (currently Step 11 after Packet 04) is renumbered to Step 12. All in-text Step references inside the agent file are updated to match.

### Part B — Update Constraints in `hive-sync.md`

Append three new bullets to the Constraints block:

```markdown
- The `hive-sync` agent **never auto-fixes drift** detected by Step 11. Surfacing is the bound. Auto-fixing invariants, matrix rows, agent files, or `nodes.json` would require architectural judgment the agent does not have.
- The `initiatives/drift-report.md` file is **mostly** rewritten on every sync run, with one exception: the "First Surfaced" column values for items that persist from prior runs are preserved. This exception is the audit-trail value — operators see how long an item has been drifting. New items get today's date; vanished items disappear without record.
- The meta-agent exclusion list in Step 11d is **part of the agent file** (not a separate config file) so changes to it are reviewed alongside drift-detection logic. Adding to the exclusion list requires architectural intent — usually because a new meta-agent has been added to `.claude/agents/` that is correctly absent from the runtime matrix.
```

### Part C — Create `initiatives/drift-report.md`

Create the file with the structure described in Part A 11g, populated with **the current state of the repo** at this packet's execution time. The first run is the seed.

**Seed scope at scoping time** (snapshot, may shift between scoping and execution):

The exact seed depends on what's on `main` at execution. Likely findings (informational only — the agent derives the seed live):

- ADR-0011's invariants 31-33 may be named in the ADR but not yet in `invariants.md` (depending on whether ADR-0011's acceptance packet has merged before this one).
- ADR-0012's invariants 34-38 (or 37-41 post-renumber) may or may not be present.
- ADR-0014's two new invariants may or may not be present.
- `agent-capability-matrix.md` row vs `.claude/agents/` checks may surface known gaps the user has not yet addressed.
- `nodes.json` entries for `HoneyDrunk.AI`, `HoneyDrunk.Notify.Cloud`, etc. may correspond to ADRs in Proposed status (those ADRs are not Accepted yet, so 11f does not flag them — only Accepted ADRs are scanned).

The executing agent must derive the seed from live state, not from this list.

If at execution time no drift exists, the file is created with the empty-state line per Part A 11g.

### Part D — Reference the meta-agent exclusion list (single-sourced)

The exclusion list has **one canonical home**: `.claude/agents/hive-sync.md` Step 11d (executable form, used by the agent at run time). The capability matrix file gets a **pointer** to this canonical location, not a duplicate of the list. Single-sourcing prevents the F7-flagged drift problem where the matrix doc and the runtime list could diverge silently.

This packet adds a brief reference section to `constitution/agent-capability-matrix.md` after the main agent table:

```markdown
## Meta-Agent Exclusion List

Some agents authored under `.claude/agents/` are meta-decision-making (decision-authoring, scoping, or review activities) rather than runtime workflow steps. They are intentionally absent from the main agent table above.

The canonical exclusion list is maintained in `.claude/agents/hive-sync.md` Step 11d (the drift detector reads it at run time). To add a new meta-agent or remove an obsolete entry, edit Step 11d directly. Single-sourcing prevents the two-list-drift problem where the doc and the runtime list diverge silently.

At the time of writing, the list covers: `adr-composer`, `pdr-composer`, `scope`, `file-issues`, `review`, `refine`, `netrunner`, `node-audit`, `product-strategist`, `site-sync`. See Step 11d for the current authoritative list.
```

If a new meta-agent is added under `.claude/agents/`, the runtime list in Step 11d is the single edit required. The matrix doc's reference paragraph does not need to be updated unless the textual snapshot becomes badly stale.

### Part E — Remove the capability-matrix rollout-status caveat

Packet 01 attached a rollout-status caveat to the `hive-sync` row in `constitution/agent-capability-matrix.md`:

```text
> **Status:** rolling out across ADR-0014 packets 01-06. The packet-lifecycle
> (active → completed), `board-items.md`, `proposed-adrs.md`, ADR/PDR
> auto-acceptance, README index sync, and `drift-report.md` surfaces become
> live as Packets 02-06 land.
```

By the time Packet 06 lands, every surface named in the caveat exists and the agent's full mandate is realized. **Remove the caveat.** The `hive-sync` row's Trigger / Consumes / Produces / Sync Responsibility text is unchanged; only the rollout footnote is removed.

### Part F — Initiative trackers + initiative completion

Update the existing "Hive Sync Rollout (ADR-0014)" entry in `initiatives/active-initiatives.md` (last touched by Packet 05) by checking off Packet 06:

```markdown
- [x] Architecture#NN: Drift detection + close out the rollout (packet 06)
```

After Packet 06 lands, the initiative is genuinely complete. Add the closing Sync annotation under the entry's tracking list:

```markdown
> **Sync ({merge-date}):** All six packets closed. ADR-0014 will auto-flip to Accepted on the next sync run via the Phase 5 logic — the trigger is "every implementing packet's issue closed," which is now true. Initiative complete. The `hive-sync` agent now owns six reconciliation surfaces: initiative tracking files (D1), packet lifecycle (D2), board items (D3), Proposed-ADR/PDR queue (D6) with auto-acceptance (D7), README index Status/Date columns (D8), and drift report (D9). Ready to archive — the next scheduled `hive-sync` run takes ownership of the archival sequence.
```

The expected post-merge archival behavior — six steps the next sync run should perform automatically:

1. All six ADR-0014 packet files are moved from `generated/issue-packets/active/adr-0014-hive-sync-rollout/` to `generated/issue-packets/completed/`. Basenames preserved (no collisions expected): `01-architecture-rename-to-hive-sync.md`, `02-architecture-packet-lifecycle.md`, `03-architecture-board-items-tracking.md`, `04-architecture-proposed-adrs-queue.md`, `05-architecture-adr-pdr-auto-acceptance.md`, `06-architecture-drift-detection.md`.
2. The dispatch plan moves to `generated/issue-packets/completed/adr-0014-hive-sync-rollout--dispatch-plan.md` (initiative-prefixed because the bare basename `dispatch-plan.md` would collide with future initiatives).
3. The empty initiative subdirectory `generated/issue-packets/active/adr-0014-hive-sync-rollout/` is removed.
4. The "Hive Sync Rollout (ADR-0014)" entry moves from `initiatives/active-initiatives.md` to `initiatives/archived-initiatives.md` with a `**Completed:** {merge-date}` line appended below the entry.
5. The `filed-packets.json` keys for all six ADR-0014 packets are updated to point at the `completed/` paths.
6. **ADR-0014 itself auto-flips to Accepted** via the Phase 5 logic (every implementing packet closed → auto-flip). `adrs/ADR-0014-...md` Status frontmatter changes from `Proposed` to `Accepted`; `adrs/README.md` ADR-0014 row's Status column updates to match. This step is the final validation that the auto-flip logic works correctly on the originating ADR.

**Manual fallback.** If any of the six steps does not happen on the first or second post-merge sync run, the human reviewer manually completes the missed step and files a follow-up issue noting the agent's gap. Do **not** treat the gap as silent — every step above must be observable in the next sync PR.

## Affected Files

- `.claude/agents/hive-sync.md` — add Step 11 (Drift Detection), renumber Commit step to Step 12, append three bullets to Constraints
- `constitution/agent-capability-matrix.md` — append "Meta-Agent Exclusion List" section (Part D); remove the rollout-status caveat that Packet 01 attached to the `hive-sync` row (Part E)
- `initiatives/drift-report.md` — **new file**, seeded from current repo state
- `initiatives/active-initiatives.md` — check off Packet 06, add the closing Sync annotation
- `CHANGELOG.md` — append entry referencing the drift detection addition, the rollout-status caveat removal, and the rollout completion

## NuGet Dependencies

None. This is a docs/markdown change; no .NET projects touched.

## Boundary Check

- [x] Architecture-only edits. No other repo touched.
- [x] No new code or build artifact.
- [x] **The agent's runtime code path is read-only** with respect to all five drift categories. No catalogs, invariants, matrix rows, or agent files are modified by Step 11.
- [x] The new file `drift-report.md` is owned solely by `hive-sync`; it is not added to scope.md or review.md context-loading lists. Invariant 33 symmetry is preserved.
- [x] Invariant 24 preserved — no edits to filed packet bodies.

## Acceptance Criteria

- [ ] `.claude/agents/hive-sync.md` contains a Step 11 titled "Drift Detection" with the 11a-11h logic from Part A. The Commit step (formerly Step 11 after Packet 04) is renumbered to Step 12. All in-text step references are updated.
- [ ] The Constraints block contains the three new bullets specified in Part B (no auto-fix; First Surfaced exception; exclusion list lives in agent file).
- [ ] `initiatives/drift-report.md` exists. It contains:
  - The header text from Part A 11g (verbatim)
  - The `Last synced:` line with the current date (or the merge date)
  - All five drift category sections (Invariants / Matrix Rows with No Agent File / Agent Files with No Matrix Row / Missing Repos / ADR-Named Missing Nodes), each with either a populated table or `_No drift detected._`
  - The "Auth Issues" subsection inside the Missing Repos section
  - If no drift exists in any category: the file's body is replaced with the single empty-state line from 11g
- [ ] No catalog file (`catalogs/*.json`), no constitution file (`constitution/*.md` other than the matrix exclusion-list section being added), no agent file (`.claude/agents/*.md`), and no ADR/PDR file is modified by this PR. `git diff -- catalogs/ constitution/ .claude/ adrs/ pdrs/` after the agent runs in CI shows changes only in the matrix file's new exclusion-list section (one-time addition by this packet) and the agent file's Step 11 / Constraints additions.
- [ ] `constitution/agent-capability-matrix.md` contains the "Meta-Agent Exclusion List" section per Part D — a brief pointer paragraph that references `hive-sync.md` Step 11d as the canonical list, **not** a duplicate of the entries.
- [ ] `constitution/agent-capability-matrix.md` no longer contains the rollout-status caveat that Packet 01 attached to the `hive-sync` row (per Part E). The row's Trigger / Consumes / Produces / Sync Responsibility text is unchanged.
- [ ] The exclusion list lives only in `hive-sync.md` Step 11d. The matrix doc's snapshot listing of agent names (intended for human-readable orientation) does not have to match Step 11d byte-for-byte; the runtime list in Step 11d is authoritative.
- [ ] On the **second** scheduled run after this PR merges, items that persisted from the first run keep their First Surfaced dates. (The first run seeds today's date everywhere; the second run validates persistence.)
- [ ] `initiatives/active-initiatives.md` "Hive Sync Rollout (ADR-0014)" entry shows Packet 06's checkbox as checked and contains the closing Sync annotation per Part F. The entry is ready to be archived by the next sync run, and ADR-0014 is queued for auto-flip on the same run.
- [ ] **End-to-end validation criterion (post-merge, observed by the human reviewer):** after this PR merges and all six issues close, the next scheduled `hive-sync` run produces a PR in which:
  1. `adrs/ADR-0014-hive-architecture-reconciliation-agent.md` Status frontmatter line reads `**Status:** Accepted` (auto-flipped by the Phase 5 logic — Packets 01-06 all carry `accepts: ["ADR-0014"]` and their issues are all closed).
  2. `adrs/README.md` ADR-0014 row Status column reads `Accepted`.
  3. `initiatives/proposed-adrs.md` "Flipped This Run" section includes ADR-0014 (or, if the file is rewritten before reading the auto-flipped ADRs, the section is regenerated correctly on the run after).
  4. The "Hive Sync Rollout (ADR-0014)" initiative is archived to `archived-initiatives.md` with a `**Completed:**` date.
  5. The six packet files are moved to `generated/issue-packets/completed/` with `filed-packets.json` keys updated.

  This criterion is the end-to-end test that the Phase 5 auto-flip works on the originating ADR — concrete proof rather than wishful thinking. If any of the five sub-conditions does not hold on the first or second post-merge sync run, the operator manually completes the missed step and files a follow-up issue documenting the gap.
- [ ] Repo-level `CHANGELOG.md` entry appended for this version with a one-line summary referencing the drift detector and the rollout completion.

## Human Prerequisites

None for the agent-side code changes. Operational notes for the human reviewer:

- [ ] After merge, observe the **first scheduled Monday/Thursday run** of `hive-sync.yml` to confirm `drift-report.md` is regenerated correctly. Expect the file to contain whatever drift exists on `main` at that moment — possibly populated, possibly empty. Spot-check a few entries against the actual repo state.
- [ ] After the **second** scheduled run, verify First Surfaced dates persisted for any items that were present in both runs. (The persistence logic in 11h is the trickiest part of this packet to get right; the second-run check is the validator.)
- [ ] After merge, observe that the next sync run also performs the six-step archival described in Part F (above). If any step is missed, manually complete it and file a follow-up issue noting the gap.

## Referenced Invariants

> **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Filing is the point of no return. Before a packet is filed, it may be amended to fill in missing operational context (e.g. NuGet dependencies, key files, constraints) without violating this rule. After filing, state lives on the org Project board, never in the packet file. If requirements change materially post-filing, write a new packet rather than editing the old one.

This invariant is unaffected by Step 11 — drift detection reads files but never edits packets.

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled. The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other.

This packet does not touch `scope.md` or `review.md`. The new file `drift-report.md` is the `hive-sync` agent's own surface; it is not part of either the scope or review agent's required-reading list.

## Referenced ADR Decisions

**ADR-0014 D9 (Drift detection):** Surface inconsistencies between Accepted ADRs/PDRs and the rest of the Architecture repo. Five initial categories: invariants, matrix-rows-without-agents, agent-files-without-rows, nodes-without-repos, ADRs-naming-uncatalogued-nodes. Surface-only — no auto-fix. The "First Surfaced" sticky-date column is the single exception to the "fully rewritten each run" rule.

**ADR-0014 Phase Plan, Phase 6 exit criterion:** "every drift category lists either current items with `First Surfaced` dates or the empty-state line. The agent does not auto-fix any of these — resolution is human/scope-agent work."

**ADR-0014 Alternative-rejected (auto-fix catalogs/constitution):** Auto-fixing invariants, matrix rows, and `nodes.json` entries was considered and rejected. Each fix requires architectural judgment (invariant prose, matrix Trigger/Consumes/Produces, node sector/dependencies) that the agent does not have. Surfacing-without-fixing puts the operator in the loop where the judgment belongs.

## Dependencies

- Wave 5: [Packet 05 — ADR/PDR auto-acceptance + README index sync](./05-architecture-adr-pdr-auto-acceptance.md)

Reason: this packet adds Step 11 after Step 10 (lifecycle, from Packet 02). Packet 05 must land first so the Step numbering and the agent's overall workflow shape are stable. Step 11 also reads `adrs/ADR-*.md` `**Status:**` frontmatter to filter for Accepted ADRs — Packet 05's auto-flip logic determines which ADRs are Accepted at run time, so running Step 11 before Step 9's flips would surface drift against ADRs that were about to be auto-accepted.

## Labels

`feature`, `tier-2`, `meta`, `docs`, `adr-0014`, `wave-6`

## Agent Handoff

**Objective:** Add Step 11 (Drift Detection) to `hive-sync`. Create `initiatives/drift-report.md` with five drift categories. Add the meta-agent exclusion list to both the agent file and the capability matrix. Remove the rollout-status caveat that Packet 01 attached to the matrix's `hive-sync` row. Close out the ADR-0014 rollout by checking off Packet 06 and adding the closing Sync annotation. ADR-0014 itself will auto-flip to Accepted on the first scheduled run after this PR merges (the trigger condition — every implementing packet's issue closed — is satisfied at that moment).

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main` (suggested branch name: `chore/adr-0014-hive-sync-phase-6`).

**Context:**
- Goal: Sixth and final phase of the ADR-0014 rollout. Adds drift surfacing without auto-fix.
- Feature: ADR-0014 — Hive–Architecture Reconciliation Agent.
- ADRs: ADR-0014.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Packet 05 (this initiative, Wave 5) must merge first.

**Constraints:**
- **Invariant 24** (full text above) — no edits to filed packet bodies.
- **Invariant 33** (full text above) — `scope.md` and `review.md` context-loading sections are not modified.
- **Read-only with respect to all five drift categories.** Step 11 only writes to `drift-report.md`. It never modifies any catalog, invariant, matrix row, agent file, ADR, or PDR.
- **First Surfaced dates persist across runs.** This is the single exception to `hive-sync`'s "fully rewritten each run" convention. Implementation must read the previous file's contents before rewriting.
- **The exclusion list lives in the agent file.** Adding/removing entries is a code change reviewed alongside drift logic.

**Key Files:**
- `.claude/agents/hive-sync.md` — insert Step 11, renumber Commit to Step 12, append Constraints bullets.
- `constitution/agent-capability-matrix.md` — append "Meta-Agent Exclusion List" section (Part D); remove the rollout-status caveat attached by Packet 01 (Part E).
- `initiatives/drift-report.md` — create with seeded content from live repo state.
- `initiatives/active-initiatives.md` — check off Packet 06, add the closing Sync annotation.
- `CHANGELOG.md` — append entry.

**Contracts:**
- The bold-title regex pattern in 11b is the contract between ADR authors (who write `**Title text**` in invariant prose) and the drift detector. ADRs that deviate from this convention will be missed — that's a scoping bug, not a `hive-sync` bug. The pattern is documented in 11b for ADR authors to follow.
- The `HoneyDrunk\.[A-Z][A-Za-z]*` regex in 11f is the contract for Node naming. Nodes named with hyphens or non-canonical casing will not be detected. The regex is documented in 11f.
- The meta-agent exclusion list is **single-sourced** in `hive-sync.md` Step 11d. The matrix's "Meta-Agent Exclusion List" section references the canonical list rather than duplicating it, so there is no drift surface to enforce. To add or remove an entry, edit Step 11d directly.
