# Dispatch Plan — ADR-0014 Hive Sync Rollout

**Initiative:** `adr-0014-hive-sync-rollout`
**Sector:** Meta
**Governing ADR:** [ADR-0014 — Hive–Architecture Reconciliation Agent](../../../../adrs/ADR-0014-hive-architecture-reconciliation-agent.md) (Proposed 2026-04-16; this initiative flips it to Accepted via the Phase 5 auto-flip logic on the first sync run after Packet 06 closes — every implementing packet's issue is closed at that moment, satisfying the auto-flip trigger)
**Trigger:** ADR-0014 phase plan executes the six-phase rollout for renaming `initiatives-sync` to `hive-sync`, adding the packet lifecycle, non-initiative board tracking, Proposed-ADR queue, ADR/PDR auto-acceptance + README index sync, and drift detection.
**Single repo:** `HoneyDrunkStudios/HoneyDrunk.Architecture`

## Summary

ADR-0014 redefines the agent that reconciles Architecture state with The Hive. Today, `initiatives-sync` only knows about packet-sourced issues and never moves completed packets out of `active/`. After this initiative, a renamed `hive-sync` agent owns six jobs: (1) initiative reconciliation (unchanged), (2) packet lifecycle management (`active/` → `completed/`), (3) non-initiative board tracking (`board-items.md`), (4) Proposed-ADR/PDR acceptance queue (`proposed-adrs.md`), (5) ADR/PDR auto-acceptance + README index sync, and (6) drift detection (`drift-report.md`).

Each phase corresponds to one packet. Packets sit on a strict serial chain because every packet edits `.claude/agents/hive-sync.md` in overlapping regions — running them in parallel would force later PRs to absorb earlier renumbering. **Strict 1 → 2 → 3 → 4 → 5 → 6 serial execution is the chosen path for review-bandwidth reasons.** A solo dev reviewing one PR at a time prefers the linear order; isolated parallelization (e.g., Packets 03 and 04 after Packet 02 lands) is technically possible at the cost of one rebase but is not the planned path.

## Wave Diagram

```
Wave 1: Agent rename + capability matrix (D1, D5)
   └─ Architecture: 01-architecture-rename-to-hive-sync

Wave 2: Packet lifecycle + lifecycle invariant + one-time completed/ backfill (D2, D4)
   └─ Architecture: 02-architecture-packet-lifecycle
       Blocked by: Wave 1

Wave 3: Non-initiative board-items tracking + board-coverage invariant (D3)
   └─ Architecture: 03-architecture-board-items-tracking
       Blocked by: Wave 2

Wave 4: Proposed-ADR queue (read-only surface) (D6)
   └─ Architecture: 04-architecture-proposed-adrs-queue
       Blocked by: Wave 3

Wave 5: ADR/PDR auto-acceptance + README index Status/Date sync (D7, D8)
   └─ Architecture: 05-architecture-adr-pdr-auto-acceptance
       Blocked by: Wave 4

Wave 6: Drift detection + meta-agent exclusion list (D9)
   └─ Architecture: 06-architecture-drift-detection
       Blocked by: Wave 5
```

## Packet List

| # | Packet | Repo | Wave | Depends On |
|---|--------|------|------|------------|
| 01 | [Rename `initiatives-sync` → `hive-sync`](./01-architecture-rename-to-hive-sync.md) | Architecture | 1 | — |
| 02 | [Add packet lifecycle (`active/` → `completed/`) to `hive-sync`](./02-architecture-packet-lifecycle.md) | Architecture | 2 | 01 |
| 03 | [Track non-initiative board items in `board-items.md`](./03-architecture-board-items-tracking.md) | Architecture | 3 | 02 |
| 04 | [Surface Proposed-ADR queue + flip ADR-0014 to Accepted](./04-architecture-proposed-adrs-queue.md) | Architecture | 4 | 03 |
| 05 | [Auto-accept ADRs/PDRs + sync README indexes](./05-architecture-adr-pdr-auto-acceptance.md) | Architecture | 5 | 04 |
| 06 | [Surface drift between Accepted decisions and the rest of the repo](./06-architecture-drift-detection.md) | Architecture | 6 | 05 |

## Phase Mapping

- **Wave 1 = ADR-0014 Phase 1** — pure rename (D1, D5). Same behavior; new name. ADR-0014 stays in `Proposed`.
- **Wave 2 = ADR-0014 Phase 2** — D2 packet lifecycle, D4 single-writer rule, lifecycle invariant, one-time backfill.
- **Wave 3 = ADR-0014 Phase 3** — D3 non-initiative tracking, board-coverage invariant, seed run from current Hive state.
- **Wave 4 = ADR-0014 Phase 4** — D6 Proposed-ADR queue (read-only surface). Seed run from current `adrs/` Proposed entries. ADR-0014 itself appears in the seed because its Status is still `Proposed` at this point — the auto-flip happens later, after Packet 06 closes.
- **Wave 5 = ADR-0014 Phase 5** — D7 ADR/PDR auto-acceptance based on `accepts:`-frontmatter packet closure (a new packet field introduced by this packet); D8 README index Status/Date column sync; introduces `MAX_FLIPS_PER_RUN` cap. Generalizes the read-only Wave 4 queue surface into runtime automation. Updates `scope.md` to write the new `accepts:` field for future packets.
- **Wave 6 = ADR-0014 Phase 6** — D9 drift detection. Five categories surfaced in `drift-report.md`; surface-only, no auto-fix. Closes the rollout.

## Site Sync

**Not required.** This is a Meta-sector internal workflow change. No public website surface (HoneyDrunk.Studios) is affected.

## Rollback Plan

Each phase is a single PR against `HoneyDrunk.Architecture/main`. Rollback for any phase is a `git revert` on that PR.

- **Phase 1 revert** restores `initiatives-sync.md`, the workflow file name, and all references. ADR-0014 stays in `Proposed` (no flip happened in Phase 1).
- **Phase 2 revert** removes the lifecycle logic from `hive-sync.md`. Packets that the backfill moved to `completed/` are moved back to `active/` (the revert restores the old paths in `filed-packets.json` and `git mv`s the packets back). The agent reverts to "no lifecycle management." The lifecycle invariant added in this phase is removed from `constitution/invariants.md` in the same revert.
- **Phase 3 revert** removes `board-items.md` and the GraphQL query logic. The board-coverage invariant added in this phase is removed from `constitution/invariants.md` in the same revert.
- **Phase 4 revert** removes `proposed-adrs.md` and the ADR-frontmatter scan logic. Phase 4 does **not** flip ADR-0014's Status, does **not** edit `adrs/README.md`, and does **not** touch the capability-matrix caveat — those concerns moved to Phases 5 (auto-flip) and 6 (caveat removal). The Phase 4 revert is therefore a clean removal of the read-only queue surface.
- **Phase 5 revert** restores Step 9's read-only behavior (queue without auto-flip), removes the README index sync, and reverts the bounded ADR/PDR write authorization in the Constraints block. Any ADR/PDR auto-flipped during the run between Phase 5 merge and revert keeps its `Accepted` status — the revert does not roll back individual ADR Status edits since those are intentional historical edits, not a logical regression.
- **Phase 6 revert** removes Step 11 (Drift Detection), removes `initiatives/drift-report.md`, removes the meta-agent exclusion list section from `agent-capability-matrix.md`, and reverts the three Constraints bullets added in this phase.

Phases revert independently as long as later phases have not added cross-references in the agent file. The agent file itself is the only shared artifact across phases — the cleanest rollback is to revert the most recent phase's PR, not skip-revert.

## Acceptance Workflow Notes

Per the [ADR acceptance workflow](../../../../adrs/README.md), ADRs are filed Proposed. The scope agent flips the status to Accepted **after** the implementing PR(s) merge. For ADR-0014, the implementation spans six PRs across Waves 1-6; the flip is performed **automatically** by the Phase 5 auto-flip logic (which Packet 05 introduces) on the first sync run after Packet 06 closes — at which point every implementing packet's issue is closed, and the auto-flip's trigger condition is satisfied. ADR-0014 is treated identically to every other Proposed ADR; the validation that auto-flip works correctly on the originating ADR is a deliberate end-to-end test of the new behavior.

**Why the flip is deferred to the auto-flip after Wave 6:**

- ADR-0014 mandates new invariants and surfaces across all six phases (D1-D9). If the ADR were marked `Accepted` in any earlier wave, the on-disk state would not match the ADR text for the duration of the rollout (3-6 weeks). A reader of `adrs/ADR-0014-...md` would see an Accepted ADR whose mandated behaviors did not yet exist.
- The user-memory rule "scope agent flips status to Accepted after PR merge, never on first draft" is satisfied — and one step better, the **agent itself** flips it after every implementing PR has merged. ADR-0014 is treated identically to every other Proposed ADR.
- This is also the **end-to-end validation** that the Phase 5 auto-flip logic works correctly. The originating ADR is the natural test case — if the auto-flip is buggy, ADR-0014 stays Proposed and the bug is loud (visible in `proposed-adrs.md`, in the ADR's frontmatter, and in `adrs/README.md`). If the auto-flip is correct, ADR-0014 lands as Accepted on the first run after Packet 06 closes — concrete proof the new behavior works.

ADR-0014 itself is treated identically to every other Proposed ADR. The Phase 5 auto-flip logic (Packet 05) fires for any Proposed ADR whose implementing packets are all closed. Once Packet 06 closes, that condition is satisfied for ADR-0014 — the next sync run will auto-flip it to Accepted. No manual flip is performed mid-rollout. This validates the auto-flip logic against the originating ADR.

## Filing Commands

These commands are for the `file-issues` agent. **Do not run from the scope agent.**

```bash
# Wave 1
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Rename initiatives-sync to hive-sync" \
  --body-file "generated/issue-packets/active/adr-0014-hive-sync-rollout/01-architecture-rename-to-hive-sync.md" \
  --label "feature,tier-2,meta,docs,adr-0014,wave-1"

# Wave 2 (after Wave 1 closes)
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Add packet lifecycle (active to completed) to hive-sync" \
  --body-file "generated/issue-packets/active/adr-0014-hive-sync-rollout/02-architecture-packet-lifecycle.md" \
  --label "feature,tier-2,meta,docs,adr-0014,wave-2"

# Wave 3 (after Wave 2 closes)
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Track non-initiative board items in board-items.md" \
  --body-file "generated/issue-packets/active/adr-0014-hive-sync-rollout/03-architecture-board-items-tracking.md" \
  --label "feature,tier-2,meta,docs,adr-0014,wave-3"

# Wave 4 (after Wave 3 closes)
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Proposed-ADR acceptance queue + flip ADR-0014 to Accepted" \
  --body-file "generated/issue-packets/active/adr-0014-hive-sync-rollout/04-architecture-proposed-adrs-queue.md" \
  --label "feature,tier-2,meta,docs,adr-0014,wave-4"

# Wave 5 (after Wave 4 closes)
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Auto-accept ADRs/PDRs and sync README indexes" \
  --body-file "generated/issue-packets/active/adr-0014-hive-sync-rollout/05-architecture-adr-pdr-auto-acceptance.md" \
  --label "feature,tier-2,meta,docs,adr-0014,wave-5"

# Wave 6 (after Wave 5 closes)
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Surface drift between Accepted decisions and the repo" \
  --body-file "generated/issue-packets/active/adr-0014-hive-sync-rollout/06-architecture-drift-detection.md" \
  --label "feature,tier-2,meta,docs,adr-0014,wave-6"
```

## Project Board Wiring

After filing each issue, add to The Hive (Project #4) and set fields. Each packet's frontmatter declares `wave`, `tier`, `node`, `initiative`, and `adrs` so the filer can map them onto Project field IDs. Default `Actor=Agent` for all six packets — no `human-only` label.

After filing, wire `addBlockedBy` to encode the strict 1 → 2 → 3 → 4 → 5 → 6 chain.
