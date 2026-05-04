---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0014", "wave-2"]
dependencies: ["adr-0014-hive-sync-rollout/01-architecture-rename-to-hive-sync"]
adrs: ["ADR-0014"]
accepts: ["ADR-0014"]
wave: 2
initiative: adr-0014-hive-sync-rollout
node: honeydrunk-architecture
---

# Feature: Add packet lifecycle (`active/` → `completed/`) to `hive-sync`

## Summary
Extend `.claude/agents/hive-sync.md` with the packet lifecycle workflow: when a filed issue is closed on GitHub, the `hive-sync` agent moves the packet file from `generated/issue-packets/active/` to `generated/issue-packets/completed/` and updates the path key in `generated/issue-packets/filed-packets.json`. Add the **packet-lifecycle invariant** to `constitution/invariants.md` (its numerical position is determined at execution time — see Part C). Run a one-time backfill in the same PR that moves every already-closed packet to `completed/` and updates `filed-packets.json` accordingly. After this packet, `active/` reliably represents only open work, and `completed/` is the archival home of closed packets.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0014 D2 names the gap: filed packets never leave `active/`. A historical-archive sibling directory exists today named `generated/issue-packets/retired/` with exactly one manually-moved file (`2026-04-12-org-secret-gh-issue-token.md`); every other closed packet still sits in `active/` next to live work. Over time this makes `active/` a partial view that no agent or human can rely on without cross-referencing GitHub issue state. Packet 01 renamed the agent and stabilized the target file; this packet adds the missing lifecycle step.

**Naming change.** The historical-archive directory is renamed from `retired/` to `completed/` as part of this packet's work — see Part D Step 0a. All references in this packet and in subsequent packets use `completed/` as the canonical name. The single existing file in `retired/` is moved to `completed/` along with the directory rename.

ADR-0014 D4 also designates `hive-sync` as the **single agent authorized to move packets between lifecycle directories**. This packet encodes that rule as the **packet-lifecycle invariant** and amends the agent's Constraints section to reflect the relaxed `filed-packets.json` write rule (the agent may update existing entries' `path` keys, but may not add or remove entries — that remains the `file-issues` agent's exclusive concern).

**Note on invariant numbering.** ADR-0014's authored text names the lifecycle invariant as #40 and the board-coverage invariant (Packet 03) as #39. Those numbers were correct at authorship but conflict with ADR-0012's pending acceptance, which renumbers its own invariants from 34-38 to 37-41. To avoid the collision, this packet does **not** hardcode an integer — it appends the invariant at the next available number after the current end of `constitution/invariants.md`. The acceptance criteria pin the **textual content** of the invariant, not the integer. See Part C for the lookup procedure.

## Scope

All edits are in the `HoneyDrunk.Architecture` repo. No code (no `.cs` files). No secrets.

### Part A — Add a new lifecycle step to `hive-sync.md`

In `.claude/agents/hive-sync.md`, insert a new Step **between the existing Step 7 (Archive Complete Initiatives) and Step 8 (Commit and Open PR)**. The new step is numbered Step 8, and the current Step 8 is renumbered Step 9. The new step reads:

```markdown
### Step 8: Move Closed Packets to completed/

For every entry in `/tmp/issue-states.json` whose `state` field is `closed`:

1. **Resolve the packet path.** The packet path is the key from `filed-packets.json` for this issue's URL. The path is relative to the repo root (e.g. `generated/issue-packets/active/adr-0005-0006-rollout/01-vault-bootstrap-extensions.md`).
2. **Skip already-completed packets.** If the path already starts with `generated/issue-packets/completed/`, the packet has been moved on a prior run. Continue.
2a. **Reconcile JSON-vs-disk drift.** If the path from `filed-packets.json` does **not** exist on disk, check whether a file with the same basename exists under `generated/issue-packets/completed/`. If yes, this is a manually-moved packet (such as `completed/2026-04-12-org-secret-gh-issue-token.md`) — update the JSON key to the actual completed path and continue **without** running `git mv` (the file is already in the right place). If no, **abort the backfill** and surface the orphan as a hard error; do not silently delete the JSON entry. Recovery requires a human to either find the missing file in git history or remove the stale JSON entry deliberately.
3. **Compute the new path.** The completed path mirrors the basename:
   - `generated/issue-packets/active/{initiative}/{NN-name}.md` → `generated/issue-packets/completed/{NN-name}.md`
   - `generated/issue-packets/active/standalone/{date}-{name}.md` → `generated/issue-packets/completed/{date}-{name}.md`
4. **Detect filename collisions.** If a file with the new basename already exists at the completed/ destination, prefix the initiative slug to disambiguate:
   - `generated/issue-packets/completed/{initiative}--{NN-name}.md`
   - For standalone packets, the date prefix already provides uniqueness; collisions there are unexpected and should fall back to `completed/standalone--{date}-{name}.md`.
5. **Move the file via `git mv`** so the move shows as a rename in the diff:
   ```bash
   git mv "${OLD_PATH}" "${NEW_PATH}"
   ```
6. **Update `filed-packets.json`.** Replace the key `OLD_PATH` with `NEW_PATH` while preserving the value (the GitHub issue URL). The JSON file is the single source of truth for packet→issue mapping; both keys are paths from the repo root. Use `jq` to do the rewrite atomically rather than a string-replace:
   ```bash
   jq --arg oldp "${OLD_PATH}" --arg newp "${NEW_PATH}" \
     'with_entries(if .key == $oldp then .key = $newp else . end)' \
     generated/issue-packets/filed-packets.json > /tmp/filed-packets.json
   mv /tmp/filed-packets.json generated/issue-packets/filed-packets.json
   ```
7. **Detect empty initiative subdirectories.** After moving the packet, if the source initiative directory under `generated/issue-packets/active/{initiative}/` no longer contains any `.md` files (excluding `dispatch-plan.md`), and the `dispatch-plan.md` is the only file remaining, also move the dispatch plan:
   ```bash
   if [[ -f "generated/issue-packets/active/${INITIATIVE}/dispatch-plan.md" ]] \
      && [[ -z "$(find "generated/issue-packets/active/${INITIATIVE}" -maxdepth 1 -name '*.md' ! -name 'dispatch-plan.md' -print -quit)" ]]; then
     git mv "generated/issue-packets/active/${INITIATIVE}/dispatch-plan.md" \
            "generated/issue-packets/completed/${INITIATIVE}--dispatch-plan.md"
     rmdir "generated/issue-packets/active/${INITIATIVE}"
   fi
   ```
   The dispatch plan retains its initiative-prefixed name in `completed/` so historical narratives stay discoverable (e.g. `completed/adr-0005-0006-rollout--dispatch-plan.md`).
8. **Standalone packets** (originally under `active/standalone/`) follow the same rule: closed issue → move to `completed/`. The `active/standalone/` directory itself is not removed even when empty — it is a long-lived staging area for one-off packets and may be re-populated at any time.

The moves and the `filed-packets.json` update are committed in the same PR as the initiative tracking updates from Steps 3-7. The entire sync is atomic and reviewable as one diff.
```

The numbering renumber is mechanical: the old Step 8 ("Commit and Open PR") becomes Step 9, and the section headings update accordingly. The body of the renamed Step 9 is unchanged.

### Part B — Update Constraints in `hive-sync.md`

Find the existing Constraints block at the bottom of `hive-sync.md`:

```markdown
## Constraints

- Never delete tracking checkboxes — only check them off or add annotations.
- Never modify `filed-packets.json` — it's the responsibility of the `file-issues` agent.
- Never create issues — that's `scope` and `file-issues`.
- Keep all file edits within `initiatives/` directories.
- Do not modify packet files in `generated/issue-packets/`.
```

Replace with:

```markdown
## Constraints

- Never delete tracking checkboxes — only check them off or add annotations.
- Never **add or remove entries** in `filed-packets.json` — that is the `file-issues` agent's exclusive responsibility. The `hive-sync` agent may update an existing entry's path key when moving its packet from `active/` to `completed/`, but must not introduce a new key or delete a key for any reason.
- Never create GitHub issues — that's `scope` and `file-issues`.
- Keep all initiative-tracking edits within `initiatives/` directories. Packet moves between `generated/issue-packets/active/` and `generated/issue-packets/completed/` are explicitly authorized for this agent (see Step 8 and the packet-lifecycle invariant in `constitution/invariants.md`).
- Never modify the **content** of any packet file under `generated/issue-packets/`. Moving a packet between `active/` and `completed/` is a path change, not a content change. Editing packet body text is forbidden under invariant 24.
- The `hive-sync` agent is the **only** agent that moves files between `active/` and `completed/`. The `scope` agent writes to `active/`. The `file-issues` agent reads from `active/` and writes to `filed-packets.json`. No other agent moves packets out of `active/` (see the packet-lifecycle invariant in `constitution/invariants.md`).
```

### Part C — Add the packet-lifecycle invariant

In `constitution/invariants.md`, **append** the packet-lifecycle invariant under a new section heading **at the end of the file** (after the last existing invariant).

**Step 1: Determine the invariant number.**

Read `constitution/invariants.md` and find the highest existing invariant number (look for `^[0-9]+\.` at line starts under the existing invariant sections). The new invariant's number is `max + 1`. Do **not** hardcode `40` or any other integer — the next-available number depends on what has merged before this packet.

```bash
# Lookup pattern (the executing agent runs this or equivalent)
LIFECYCLE_NUM=$(grep -oE '^[0-9]+\.' constitution/invariants.md | tr -d '.' | sort -n | tail -1 | awk '{print $1+1}')
echo "Lifecycle invariant will be numbered ${LIFECYCLE_NUM}"
```

At scoping time (2026-05-02), `invariants.md` ends at invariant 36; ADR-0012's pending acceptance is expected to renumber its invariants to 37-41 if it lands first; ADR-0015's accepted invariants are already at 34-36. The lifecycle invariant might therefore be #37, #40, #42, or another value depending on what has merged. The agent picks whatever is correct at execution time.

**Step 2: Append the invariant under a "Hive Sync Invariants" section.**

If a `## Hive Sync Invariants` section does not yet exist in the file, create it at the end. Use this template, substituting `{N}` with the value computed in Step 1:

```markdown
## Hive Sync Invariants

{N}. **Completed issue packets are moved to `completed/`.** When a filed issue is closed on GitHub, the `hive-sync` agent moves its source packet from `generated/issue-packets/active/` to `generated/issue-packets/completed/` and updates the `path` key in `generated/issue-packets/filed-packets.json`. No other agent moves packets between lifecycle directories. The `hive-sync` agent may update existing entries' paths in `filed-packets.json` but may not add or remove entries (that remains the `file-issues` agent's exclusive concern). See ADR-0014 D2, D4.
```

**Existing-section safety net.** If a "Hive Sync Invariants" section already exists (because Packet 03 landed first and created it for the board-coverage invariant), append the lifecycle invariant inside that section as the next-available number rather than creating a duplicate section.

**Cross-reference safety.** ADR-0014's authored text names this invariant as "40" and the board-coverage invariant (Packet 03) as "39". Those numbers may not match the actual integers chosen at execution time. The agent must not edit the ADR-0014 source to "correct" the numbers — the ADR carries an explicit parenthetical noting that the integers were authored at draft time and the live numbers in `invariants.md` are authoritative. Acceptance criteria below pin the **textual content** of the invariant, not the integer.

### Part D — One-time backfill

In the same PR, run the agent's new Step 8 logic against the **current** `/tmp/issue-states.json` data. The backfill is not a separate commit — it is the natural first execution of the new lifecycle.

**Step 0a: Rename the historical-archive directory.** Before any packet moves, rename `generated/issue-packets/retired/` to `generated/issue-packets/completed/`. The single existing file (`2026-04-12-org-secret-gh-issue-token.md`) moves with it.

```bash
git mv generated/issue-packets/retired generated/issue-packets/completed
```

This is a one-time directory rename. After it lands, all backfill moves and all future agent runs use `completed/` as the destination. The pre-existing `filed-packets.json` mismatch for `2026-04-12-org-secret-gh-issue-token.md` (its key still reads `active/standalone/...`) is corrected by Step 2a's DRIFT branch later in the backfill — Step 0a only handles the directory rename, not the JSON key.

**Step 0b: Hoist `/tmp/issue-states.json` generation.** The Step 1b shell pipeline (already in `hive-sync.md` from Phase 1) populates `/tmp/issue-states.json` from `filed-packets.json` plus `gh issue view` calls. Run that pipeline next — every subsequent step in the backfill reads `/tmp/issue-states.json`. An OpenClaw agent executing this packet from a fresh checkout/session has no warm `/tmp` cache; if Step 1b is skipped, the backfill produces no moves and silently passes.

**Step 1: Dry-run preview (mandatory).** Before any `git mv` or `jq` rewrite runs, the agent generates a textual preview of every action the backfill would take, posts it as a PR description (or as the first commit's body), and only then proceeds:

```bash
# Dry-run: print every planned action without writing anything
jq -r 'to_entries[] | [.key, .value] | @tsv' \
  generated/issue-packets/filed-packets.json \
  | while IFS=$'\t' read -r OLD_PATH ISSUE_URL; do
      STATE=$(jq -r --arg url "$ISSUE_URL" '.[$url].state // "unknown"' /tmp/issue-states.json)
      if [[ "$STATE" != "closed" ]]; then continue; fi

      if [[ "$OLD_PATH" == generated/issue-packets/completed/* ]]; then
        echo "SKIP    already-completed: $OLD_PATH"
        continue
      fi

      if [[ ! -f "$OLD_PATH" ]]; then
        BASENAME=$(basename "$OLD_PATH")
        if [[ -f "generated/issue-packets/completed/$BASENAME" ]]; then
          echo "DRIFT   json-key→completed only: $OLD_PATH → generated/issue-packets/completed/$BASENAME"
        else
          echo "ORPHAN  missing on disk:       $OLD_PATH (issue=$ISSUE_URL)"
        fi
        continue
      fi

      # Compute target (replicate Step 8 logic)
      BASENAME=$(basename "$OLD_PATH")
      INITIATIVE=$(echo "$OLD_PATH" | sed -E 's|generated/issue-packets/active/([^/]+)/.*|\1|')
      NEW_PATH="generated/issue-packets/completed/$BASENAME"
      if [[ -f "$NEW_PATH" ]]; then
        NEW_PATH="generated/issue-packets/completed/${INITIATIVE}--${BASENAME}"
      fi
      echo "MOVE    $OLD_PATH → $NEW_PATH"
    done > /tmp/backfill-preview.txt

cat /tmp/backfill-preview.txt
```

If `/tmp/backfill-preview.txt` contains any `ORPHAN` line, **abort** — surface the orphans, do not commit. The orphan case means a `filed-packets.json` entry points at a non-existent file with no completed sibling; this is a data-integrity bug that requires human review. If only `MOVE`, `SKIP`, and `DRIFT` lines are present, the backfill is safe to execute.

**Step 2: Transactional execution.** Run the move loop with `set -e` so a failure mid-loop aborts immediately. Apply all `filed-packets.json` path updates in **one** `jq` rewrite at the end of the move loop, then verify the rewrite succeeded by re-reading the JSON before committing. If the `jq` rewrite fails or produces malformed JSON, run `git checkout -- generated/issue-packets/` to roll back all moves and the JSON edit in one shot; do **not** leave the workspace in a half-moved state.

```bash
set -euo pipefail

# Build the in-memory map of OLD_PATH → NEW_PATH from the dry-run preview's MOVE lines
declare -A MOVE_MAP
while IFS= read -r line; do
  if [[ "$line" =~ ^MOVE[[:space:]]+(.+)[[:space:]]+→[[:space:]]+(.+)$ ]]; then
    MOVE_MAP["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
  fi
done < /tmp/backfill-preview.txt

# Phase A: git mv every entry
for OLD in "${!MOVE_MAP[@]}"; do
  git mv "$OLD" "${MOVE_MAP[$OLD]}"
done

# Phase B: rewrite filed-packets.json in one shot, including DRIFT path-key fixups
jq --slurpfile updates <(...build a JSON of {old:new} pairs from MOVE_MAP and DRIFT lines...) \
   'with_entries(
      .key as $k
      | if ($updates[0] | has($k))
        then .key = $updates[0][$k]
        else .
        end
    )' generated/issue-packets/filed-packets.json > /tmp/filed-packets.json.new

# Verify the rewrite is parseable JSON and has the same number of entries
jq 'length' /tmp/filed-packets.json.new > /dev/null
test "$(jq 'length' /tmp/filed-packets.json.new)" \
   = "$(jq 'length' generated/issue-packets/filed-packets.json)" || {
  echo "ENTRY-COUNT MISMATCH — aborting and rolling back"
  git checkout -- generated/issue-packets/
  exit 1
}

mv /tmp/filed-packets.json.new generated/issue-packets/filed-packets.json
```

**Step 3: Move dispatch plans for fully-completed initiatives.** After the move loop, scan `generated/issue-packets/active/` for initiative subdirectories whose only remaining file is `dispatch-plan.md`. For each, `git mv` the dispatch plan to `completed/{initiative}--dispatch-plan.md` and `rmdir` the empty subdirectory. This step is run only after the move loop completes successfully.

**Step 4: Commit and review.** Commit all moves + the `filed-packets.json` rewrite + the agent file edit + the `invariants.md` edit + the dispatch-plan moves as a single commit (or as a small stack of clearly-labeled commits within the same PR). The PR description includes the `/tmp/backfill-preview.txt` output as a reviewer aid.

**Idempotency / recovery on interruption.** If the agent crashes between Phase A and Phase B (moves done, JSON not yet updated), recovery is `git checkout -- generated/issue-packets/` to roll back. Re-run the backfill from Step 1 (dry-run preview) — the SKIP branch in Step 8.2 handles already-completed entries, and the DRIFT branch in Step 2a handles the manually-moved exception, so a re-run produces the same end state. Do not re-run partial steps; always start from the dry-run preview.

**Diff noise on Windows hosts.** Per `project_windows_crlf_gotcha.md`, `jq` on the user's Windows box emits CRLF line endings. OpenClaw may run on Windows or Linux depending on host, so normalize generated JSON before commit. If the dry-run is performed locally on Windows for sanity, the resulting JSON's line endings may be CRLF — pipe through `tr -d '\r'`, `dos2unix`, or an equivalent normalization step before committing.

**Closed-packet inventory at scoping time** (2026-05-02; a snapshot, may shift between scoping and execution):

The agent should not rely on this list. It must regenerate the list from live `gh issue view` queries against every entry in `filed-packets.json`. The list below is informational only — it shows the rough volume the executing agent should expect.

Many of the entries in `filed-packets.json` are already known closed via `initiatives/active-initiatives.md` annotations:

- `adr-0005-0006-rollout/01-vault-bootstrap-extensions.md` (Vault#9 closed 2026-04-12)
- `adr-0005-0006-rollout/02-vault-event-driven-cache-invalidation.md` (Vault#10 closed 2026-04-12)
- `adr-0005-0006-rollout/03-architecture-infra-setup.md` (Architecture#7 closed 2026-04-11)
- `adr-0005-0006-rollout/05-create-vault-rotation-repo.md` (Architecture#8 closed 2026-04-11)
- `adr-0009-package-scanning-rollout/01-kernel-wire-up-scan-workflows.md` (Kernel#14 closed 2026-04-16)
- `adr-0009-package-scanning-rollout/02-auth-wire-up-scan-workflows.md` (Auth#6 closed 2026-04-12)
- `adr-0009-package-scanning-rollout/03-data-wire-up-scan-workflows.md` (Data#5 closed 2026-04-16)
- `adr-0009-package-scanning-rollout/04-transport-wire-up-scan-workflows.md` (Transport#14 closed 2026-04-12)
- `adr-0009-package-scanning-rollout/05-vault-wire-up-scan-workflows.md` (Vault#13 closed 2026-04-12)
- `adr-0009-package-scanning-rollout/08-web-rest-wire-up-scan-workflows.md` (Web.Rest#5 closed 2026-04-16)
- `standalone/2026-04-10-actions-project-label-field-mirror-workflow.md` (Actions#22, closed)

…and likely several others closed since 2026-04-20 (the date of the most recent active-initiatives.md sync). The executing agent is the source of truth for what is actually closed.

**Pre-existing exception.** The single file currently in `completed/` (`generated/issue-packets/completed/2026-04-12-org-secret-gh-issue-token.md`) was manually moved before this packet existed. Its corresponding `filed-packets.json` key still reads `generated/issue-packets/active/standalone/2026-04-12-org-secret-gh-issue-token.md` (an inconsistency — see entry in `filed-packets.json` line 35). The backfill must detect this mismatch and update the `filed-packets.json` key to `generated/issue-packets/completed/2026-04-12-org-secret-gh-issue-token.md` so the file's mapping becomes consistent. The packet file itself is already in the right place; only the JSON key is wrong.

### Part E — Initiative trackers

Update the existing "Hive Sync Rollout (ADR-0014)" entry in `initiatives/active-initiatives.md` (created by Packet 01) by checking off Packet 02:

```markdown
- [x] Architecture#NN: Add packet lifecycle and Hive-Sync invariant for lifecycle (packet 02)
```

The other Tracking checkboxes remain unchecked.

## Affected Files

- `.claude/agents/hive-sync.md` — add Step 8 (Move Closed Packets to completed/), renumber old Step 8 to Step 9, replace Constraints block
- `constitution/invariants.md` — append "Hive Sync Invariants" section (or extend existing one) with the packet-lifecycle invariant at the next-available number
- `generated/issue-packets/retired/` — **renamed** to `generated/issue-packets/completed/` (Step 0a); the existing file (`2026-04-12-org-secret-gh-issue-token.md`) moves with the directory
- `generated/issue-packets/filed-packets.json` — path-key updates for every closed packet plus the pre-existing `completed/2026-04-12-...` mismatch correction
- `generated/issue-packets/active/**/*.md` — moves (via `git mv`) for every closed packet
- `generated/issue-packets/active/{initiative}/dispatch-plan.md` — moves for any initiative whose packets are now all completed
- `generated/issue-packets/completed/**/*.md` — destinations for every moved packet
- `initiatives/active-initiatives.md` — check off Packet 02 in the Hive Sync Rollout tracking list
- `CHANGELOG.md` — append entry referencing the packet-lifecycle addition, the directory rename (`retired/` → `completed/`), and the new invariant

The exact set of moved packet files depends on what is closed at execution time. The PR diff will be large (one rename per closed packet plus the JSON edit plus the agent-file edit plus the invariants.md edit).

## NuGet Dependencies

None. This is a docs/markdown/JSON change and file moves; no .NET projects touched.

## Boundary Check

- [x] Architecture-only edits. No other repo touched.
- [x] Packet content is unchanged. Only the path of each packet changes.
- [x] `filed-packets.json` writes are limited to existing keys' path values — no entries added or removed.
- [x] Invariant 24 preserved — moving a packet between `active/` and `completed/` is a path change, not a content edit. No packet body is modified.
- [x] Invariant 33 preserved — neither `scope.md` nor `review.md` is touched.

## Acceptance Criteria

- [ ] `.claude/agents/hive-sync.md` contains a Step 8 titled "Move Closed Packets to completed/" with the full procedure described in Part A. The step is positioned between the old Step 7 (Archive Complete Initiatives) and the renumbered Step 9 (Commit and Open PR).
- [ ] The renumbered Step 9 (Commit and Open PR) body is unchanged from the previous Step 8 body.
- [ ] The Constraints block at the bottom of `hive-sync.md` matches the text in Part B verbatim.
- [ ] `constitution/invariants.md` contains a "Hive Sync Invariants" section (created by this packet, or extended if Packet 03 landed first) containing the packet-lifecycle invariant. The numbering is chosen by Part C's lookup procedure (next-available integer at execution time). The **textual content** of the invariant matches the prose in Part C verbatim — the integer prefix may differ from the ADR-0014 authored value (40) without causing a fail.
- [ ] For every entry in `filed-packets.json` whose linked GitHub issue is closed at PR creation time:
  - the packet file is at a path under `generated/issue-packets/completed/` (not `active/`)
  - the corresponding `filed-packets.json` key is the new completed path
  - the value (issue URL) is unchanged
- [ ] For every closed packet that originated under `active/{initiative}/`, the basename is preserved in `completed/` (e.g. `01-vault-bootstrap-extensions.md`). Collision-prefix `{initiative}--{name}.md` is used **only** when a basename collision is detected.
- [ ] For every initiative subdirectory under `active/` whose all packets are closed, the dispatch plan has been moved to `completed/{initiative}--dispatch-plan.md` and the empty initiative subdirectory has been removed.
- [ ] The pre-existing exception (`completed/2026-04-12-org-secret-gh-issue-token.md` was manually-moved but its `filed-packets.json` key still reads `active/standalone/...`) is corrected: the `filed-packets.json` key for this entry reads `generated/issue-packets/completed/2026-04-12-org-secret-gh-issue-token.md`.
- [ ] No file under `generated/issue-packets/active/` corresponds to a closed GitHub issue (verified by re-running the Step 1b shell against the post-merge state).
- [ ] No packet file's body content is changed. Only paths change. Verifiable by `git diff --diff-filter=R` showing renames-only.
- [ ] **The dry-run preview output is attached to the PR description** (or the first commit body) and contains zero `ORPHAN` lines. Any `DRIFT` or `MOVE` lines in the preview are reflected in the actual diff.
- [ ] `generated/issue-packets/filed-packets.json` parses as valid JSON and the entry count is unchanged from the pre-PR state (the rewrite updates path keys but adds/removes no entries).
- [ ] `git grep -n "initiatives-sync"` in this PR's branch finds no new occurrences relative to the Wave 1 baseline. (Sanity check: this packet should not reintroduce the old name.)
- [ ] `initiatives/active-initiatives.md` "Hive Sync Rollout (ADR-0014)" entry shows Packet 02's checkbox as checked.
- [ ] Repo-level `CHANGELOG.md` entry appended for this version with a one-line summary referencing the packet-lifecycle addition.

## Human Prerequisites

None. This packet is fully delegable. The executing agent runs the backfill as part of its normal PR creation flow — no portal steps, no manual moves.

## Referenced Invariants

> **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Filing is the point of no return. Before a packet is filed, it may be amended to fill in missing operational context (e.g. NuGet dependencies, key files, constraints) without violating this rule. After filing, state lives on the org Project board, never in the packet file. If requirements change materially post-filing, write a new packet rather than editing the old one.

The lifecycle move is a **path change**, not a content change, and therefore does not violate invariant 24. The packet body bytes are byte-identical before and after the move; only the path key in `filed-packets.json` and the file's location on disk are different. This is the same distinction that allowed the manual `completed/2026-04-12-org-secret-gh-issue-token.md` move in the past.

> **Invariant 25:** Dispatch plans are initiative narratives, not live state. The org Project board is the source of truth for in-flight work. Dispatch plans are updated at wave boundaries as historical records.

This invariant explains why a fully-completed initiative's dispatch plan is moved to `completed/` rather than deleted: the dispatch plan is a historical record of the initiative narrative, and `completed/` is the archival home for that narrative.

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled. The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other.

This packet does not touch `scope.md` or `review.md` and therefore does not affect the symmetry. If the executing agent finds itself wanting to add `filed-packets.json` to either agent's required-reading list, **stop and surface the divergence** rather than silently breaking symmetry.

## Referenced ADR Decisions

**ADR-0014 D2 (Packet lifecycle move):** When the agent discovers a filed issue is closed and the issue's packet still exists under `active/`, the agent moves the packet file to `completed/`. Move not copy; preserve the filename; collision-prefix with the initiative slug if needed; subdirectory cleanup when all packets in an initiative are completed (including the dispatch plan); standalone packets follow the same rule; `filed-packets.json` is updated; the moves are committed in the same PR as initiative tracking updates.

**ADR-0014 D4 (Single-writer rule):** No other agent may move files between `active/` and `completed/`. The `scope` agent writes to `active/`. The `file-issues` agent reads from `active/` and writes to `filed-packets.json`. The `hive-sync` agent is the only agent that moves files out of `active/`. This keeps the packet lifecycle linear and avoids race conditions between agents. The lifecycle is: scope writes packet → active/ → file-issues files issue → filed-packets.json updated, packet unchanged → issue lives on GitHub / The Hive → issue closes on GitHub → hive-sync moves packet → completed/, updates filed-packets.json path.

**ADR-0014 Phase Plan, Phase 2 exit criterion:** "`generated/issue-packets/active/` contains only packets for open issues."

**ADR-0014 Alternative-rejected (mirroring `active/`'s structure under `completed/`):** A flat layout under `completed/` with collision-prefixing is the deliberate choice. The structured archive (`completed/{initiative}/{NN-name}.md`) was considered and rejected as harder for the agent to implement and reason about. The agent must follow the flat layout described in Part A.

## Dependencies

- Wave 1: [Packet 01 — Rename `initiatives-sync` → `hive-sync`](./01-architecture-rename-to-hive-sync.md)

Reason: this packet edits `.claude/agents/hive-sync.md`, which does not exist until Packet 01 lands. The new lifecycle Step references the agent's existing Step structure (Steps 1-7 from `initiatives-sync.md` carried over verbatim), so this packet must run after the rename has stabilized the file.

## Labels

`feature`, `tier-2`, `meta`, `docs`, `adr-0014`, `wave-2`

## Agent Handoff

**Objective:** Add lifecycle management to `hive-sync.md` (active → completed moves), encode the packet-lifecycle invariant under "Hive Sync Invariants" at the next-available number, and run the one-time backfill of currently-closed packets — all in one PR.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main` (suggested branch name: `chore/adr-0014-hive-sync-phase-2`).

**Context:**
- Goal: Second of six phases in the ADR-0014 rollout. Eliminates packet drift in `active/`.
- Feature: ADR-0014 — Hive–Architecture Reconciliation Agent.
- ADRs: ADR-0014.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Packet 01 (this initiative, Wave 1) must merge first. The `hive-sync.md` file and `infrastructure/openclaw/hive-sync.md` runbook are products of Packet 01.

**Constraints:**
- **Invariant 24** (full text above) — packet body content must not be edited. The lifecycle operation is a path-only move. `git mv` is the canonical command; copy + delete is forbidden because the diff would lose the rename.
- **Invariant 25** (full text above) — dispatch plans move to `completed/` as historical records when the initiative is fully completed; they are not deleted.
- **Invariant 33** (full text above) — `scope.md` and `review.md` context-loading sections must not change.
- **Single-writer rule (ADR-0014 D4):** This packet is the **only** authorization for `hive-sync` to write `filed-packets.json` path keys. The agent must not add or remove entries.
- **Atomic PR:** the agent file edit, the invariants edit, the backfill moves, and the `filed-packets.json` rewrite are all in one PR. Splitting them would leave the repo in an inconsistent intermediate state.
- **Dry-run before destructive steps.** Part D Step 1 generates `/tmp/backfill-preview.txt`. The agent **must** verify the preview contains zero `ORPHAN` lines before any `git mv` or JSON rewrite runs. The preview is included in the PR body as a reviewer aid.
- **JSON-vs-disk drift handled explicitly.** Part A Step 2a is the single branch in the algorithm where `filed-packets.json` is updated without a corresponding `git mv`. The pre-existing `completed/2026-04-12-org-secret-gh-issue-token.md` triggers this branch.
- **Transactional rollback.** If the `jq` rewrite produces malformed JSON or an entry-count mismatch, the agent runs `git checkout -- generated/issue-packets/` to revert all moves and the JSON edit in one shot, then surfaces the failure rather than committing a partial state.
- **No hardcoded invariant number.** Part C looks up the next-available integer at execution time. Do not write a literal `40.` into `invariants.md` if the file's current max is something else (e.g., 36, 41). The acceptance criteria pin the prose, not the integer.

**Key Files:**
- `.claude/agents/hive-sync.md` — insert Step 8, renumber old Step 8 to Step 9, replace Constraints block.
- `constitution/invariants.md` — append "Hive Sync Invariants" section (or extend existing) with the packet-lifecycle invariant at the next-available number (Part C lookup).
- `generated/issue-packets/filed-packets.json` — path-key rewrite for every closed packet + the pre-existing `completed/2026-04-12-org-secret-gh-issue-token.md` mismatch.
- `generated/issue-packets/active/**/*.md` — `git mv` for every closed packet.
- `generated/issue-packets/completed/` — destination directory.
- `initiatives/active-initiatives.md` — check off Packet 02.

**Contracts:**
- `filed-packets.json` schema (informal, by example): a flat object whose keys are repo-relative packet paths and whose values are GitHub issue URLs. Adding or removing keys is forbidden for this agent. Updating an existing key's path string while preserving the value is the only authorized write.
