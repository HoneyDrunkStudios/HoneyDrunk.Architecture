# Dispatch Plan: ADR-0010 Observation Layer & AI Routing — Phase 1

**Date:** 2026-04-18
**Trigger:** ADR-0010 (Observation Layer and AI Routing) — Proposed 2026-04-12, Phase 1 scoped today
**Type:** Multi-repo
**Sector:** Meta + Ops + AI
**Site sync required:** No (internal contract/catalog work; site catalogs auto-follow once live)
**Rollback plan:** Architecture-side edits revert cleanly via `git revert`. The new `HoneyDrunk.Observe` repo, if created and then deferred, can be archived rather than deleted (GitHub archive is non-destructive). The AI Abstractions additions are additive — they introduce no breaking changes for existing callers, so rollback is a version-bump revert.

## Summary

ADR-0010 introduced two new architectural layers — the Observation Layer (new Node `HoneyDrunk.Observe` in the Ops sector) and the AI Routing Layer (extension of existing `HoneyDrunk.AI`). The ADR explicitly partitions the work into three phases. This initiative ships **Phase 1 only** — contracts, catalogs, and stubs — so Phase 2 (first GitHub connector + cost-first routing policy) and Phase 3 (HoneyHub integration, blocked on HoneyHub Phase 1) can be scoped later without getting lost.

Phase 1 touches three repos:
- `HoneyDrunk.Architecture` — catalog registration, repo context folder, sectors, invariants, trackers, ADR index flip
- `HoneyDrunk.Observe` — **new repo** (must be created by a human-only chore first), then scaffolded with the Phase 1 Abstractions package and three contracts
- `HoneyDrunk.AI` — three new routing contracts added to `HoneyDrunk.AI.Abstractions` (or the package scaffolded if it does not yet exist)

## Phase 2 and Phase 3 — not in this initiative

Explicitly deferred to keep scope honest. Tracking lives in three places so nothing gets lost:

1. **`initiatives/active-initiatives.md`** — this initiative's entry carries a "Next (Phase 2)" and a "Deferred (Phase 3)" section
2. **ADR-0010 Phase Plan section** — canonical spec for what Phase 2 and 3 are
3. **`initiatives/roadmap.md`** — Phase 2 bulleted under Q3 2026; Phase 3 in Future

**Phase 2 triggers** (scope when these land):
- Phase 1 packets all merged
- There is a concrete first-use case for the GitHub connector (e.g., an external repo we want to observe)
- An initial policy shape for cost-first routing is needed by a live application-code caller

**Phase 3 triggers:**
- HoneyHub Phase 1 is live (per ADR-0003)
- There is a business case for feeding external-project observations into HoneyHub's knowledge graph

## Execution Model

Execution is **manual on Codex Cloud** matching the ADR-0005/0006 rollout pattern. All fileable packets go on the board in one pass; wave is execution guidance, not a filing gate. The scaffold packet against `HoneyDrunk.Observe` cannot be filed until the new repo exists — that is the one blocked packet.

### Wave 1 — Foundation (Architecture + repo creation)

Run these first. They establish the catalog identity and GitHub surface that Wave 2 consumes.

- [ ] `HoneyDrunk.Architecture`: Accept ADR-0010 — catalog registration, repo context folder, sector update, invariants 28–30 finalized, ADR index flipped, initiative/roadmap trackers — [`01-architecture-adr-0010-acceptance.md`](01-architecture-adr-0010-acceptance.md)
- [ ] `HoneyDrunk.Architecture` (**human-only chore**): Create the `HoneyDrunk.Observe` GitHub repo — [`02-architecture-create-observe-repo.md`](02-architecture-create-observe-repo.md)
  - `Actor=Human`, `human-only` label. 3-minute portal task. Root blocker for the scaffold packet below.

**Wave 1 exit criteria (before starting Wave 2 on Codex Cloud):**
- ADR-0010 index row reads `Accepted`
- `catalogs/nodes.json`, `relationships.json`, `contracts.json`, `grid-health.json`, `modules.json` all reference `honeydrunk-observe`
- Remaining catalog files (`services.json`, `signals.json`, `compatibility.json`, `flow_config.json`, `flow_tiers.json`) explicitly audited with decisions documented
- `repos/HoneyDrunk.Observe/` context folder committed
- `constitution/sectors.md` (table + Dependency Flow block), `sector-interaction-map.md`, `ai-sector-architecture.md` all reflect Observe + AI routing
- `agent-capability-matrix.md` audited (expected: no edits)
- Invariants 29, 30 live in `constitution/invariants.md` with full text. **Invariant 28 keeps its "Proposed" qualifier until packet 04 ships — do NOT flip in Wave 1.**
- `HoneyDrunkStudios/HoneyDrunk.Observe` repo exists on GitHub with default branch, branch protection, and LICENSE/README committed

### Wave 2 — Observe contract surface

Only the Observe side ships in Wave 2 of this initiative. The AI routing-contracts packet is **deferred** (see next section).

- [ ] `HoneyDrunk.Observe` (**BLOCKED on `02-architecture-create-observe-repo.md`**): Scaffold repo, solution, and `HoneyDrunk.Observe.Abstractions` with three contracts — [`03-observe-abstractions-scaffold.md`](03-observe-abstractions-scaffold.md)
  - **Blocked on:** `02-architecture-create-observe-repo.md` closing. File this packet via the Next Steps script embedded in packet 02.

**Wave 2 exit criteria:**
- `HoneyDrunk.Observe.Abstractions` published (preview or release) with the three observation contracts
- PR traverses tier-1 gate and merges
- Phase 1 tracking in `active-initiatives.md` reflects completion of the Observe side; the AI side remains tracked as deferred

### Deferred — packet 04 (AI routing contracts)

[`04-ai-add-routing-contracts.md`](04-ai-add-routing-contracts.md) is **parked pending a HoneyDrunk.AI standup ADR**. The repo exists on GitHub but is empty, and scaffolding choices for a foundational AI-sector Node — solution layout, Microsoft.Extensions.AI alignment strategy, package family split, inference-vs-routing contract boundaries, Pulse/Vault integration, first provider — are architectural decisions that deserve their own ADR (provisional `ADR-0014-honeydrunk-ai-standup`).

**What happens next:**
1. A new ADR draft (`ADR-0014-honeydrunk-ai-standup` or next-available number) is authored via the adr-composer agent
2. ADR is accepted
3. A scoping initiative derived from that ADR ships the HoneyDrunk.AI first-commit scaffold including a minimum-viable `HoneyDrunk.AI.Abstractions` package
4. Packet 04 becomes fileable as a strict additive contracts PR on the now-existing Abstractions package
5. Invariant 28's "Proposed" qualifier flip rides alongside that PR, as originally specified

Do **not** file packet 04 against the empty HoneyDrunk.AI repo. The packet's Preflight acceptance criterion directs the executor to stop and flag rather than improvise a scaffold.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board and the exit criteria above are met, the entire `active/adr-0010-observe-ai-routing-phase-1/` folder moves to `archive/adr-0010-observe-ai-routing-phase-1/` in a single commit. Partial archival is forbidden.

## `gh` CLI Commands — File Fileable Issues In One Pass

Paths are relative to the `HoneyDrunk.Architecture` repo root. The scaffold packet against `HoneyDrunk.Observe` is excluded — it is filed by the Next Steps script inside packet 02 after the repo is created.

```bash
PACKETS="generated/issue-packets/active/adr-0010-observe-ai-routing-phase-1"

# --- Wave 1: Foundation ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Accept ADR-0010 — register Observe, catalogs, constitution, invariants 29-30" \
  --body-file $PACKETS/01-architecture-adr-0010-acceptance.md \
  --label "feature,tier-2,meta,docs,catalog,adr-0010,wave-1"

# Wave 1 human-only chore — create the HoneyDrunk.Observe GitHub repo
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Create HoneyDrunk.Observe GitHub repo (human-only, gates Observe scaffold)" \
  --body-file $PACKETS/02-architecture-create-observe-repo.md \
  --label "chore,tier-1,meta,new-node,adr-0010,human-only,wave-1"

# --- Wave 2: Observe contracts (filed by packet 02's Next Steps after repo exists) ---
# gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Observe \
#   --title "Scaffold HoneyDrunk.Observe repo, solution, and Abstractions package" \
#   --body-file $PACKETS/03-observe-abstractions-scaffold.md \
#   --label "feature,tier-3,new-node,ops,scaffolding,adr-0010,wave-2"

# --- Deferred: packet 04 (AI routing contracts) — DO NOT FILE until HoneyDrunk.AI standup ADR lands ---
# HoneyDrunk.AI repo is empty. Scaffolding it requires its own ADR (provisional ADR-0014-honeydrunk-ai-standup)
# and a follow-up scaffolding initiative. Once HoneyDrunk.AI.Abstractions exists, packet 04 becomes fileable.
# gh issue create --repo HoneyDrunkStudios/HoneyDrunk.AI \
#   --title "Add IModelRouter, IRoutingPolicy, ModelCapabilityDeclaration to HoneyDrunk.AI.Abstractions" \
#   --body-file $PACKETS/04-ai-add-routing-contracts.md \
#   --label "feature,tier-2,ai,contracts,adr-0010,wave-2"
```

After filing, add each issue to The Hive (`gh project item-add 4 --owner HoneyDrunkStudios --url <ISSUE_URL>`), set board fields per `infrastructure/github-projects-field-ids.md` (Wave, Initiative = `adr-0010-observe-ai-routing-phase-1`, Node, Tier, Actor = Agent/Human), and wire `addBlockedBy` relationships:

- `03-observe-abstractions-scaffold` blocked-by `01-architecture-adr-0010-acceptance`
- `03-observe-abstractions-scaffold` blocked-by `02-architecture-create-observe-repo`
- `04-ai-add-routing-contracts` — not filed in this initiative; blocked-by future HoneyDrunk.AI standup ADR initiative

## Notes

- **Acceptance precedes flip.** Per the scope-agent convention, ADRs start Proposed; the scope agent flips the status to Accepted once the acceptance PR merges. Packet 01 handles the flip as part of the same PR — that is the one allowed moment where the flip happens, and it is mechanically coupled to the PR merging.
- **Observe sector is Ops, not Meta.** Early catalog speculation placed Observe under Meta; the ADR explicitly resolved this: Ops (matching Pulse's runtime-pipeline classification). If the ADR index row's Impact text still says "Blocked on Observe vs Pulse boundary decision," packet 01 refreshes it.
- **Invariant 28 flip is in Wave 2, not Wave 1.** Packet 01 intentionally leaves the `(Proposed...)` qualifier on invariant 28. The qualifier flip rides alongside packet 04's PR because that is when `IModelRouter` — the surface the invariant requires — actually ships. Flipping earlier creates a transient window where the invariant reads as a live rule pointing at a non-existent interface.
- **Phase 2 and Phase 3 are not in this initiative.** This is deliberate. When Phase 1 merges, the active-initiatives.md entry keeps the next-phase pointers visible so the work does not go dormant.
- **Execution order is manual.** Wave labels drive the board's Wave field per ADR-0008 D3, but they are not a filing gate. The blocked-by relationships above enforce the real ordering.

## Known Gaps (pre-existing — not owned by this initiative)

- **`infrastructure/github-projects-field-ids.md` does not exist.** Both the "After filing" guidance above and packet 02's Next Steps script reference it as the source of truth for board custom-field option IDs. This is a pre-existing dangling reference also relied on by the ADR-0005/0006 rollout's packet 05, `scope.md`, and `file-packets.ps1`. **Consequence for this initiative:** the human executing packet 02 must currently hand-populate Wave / Initiative / Node / Tier / Actor field values via the GitHub UI or by copy-pasting IDs from another already-filed packet's project-item state. Recommendation: ship `infrastructure/github-projects-field-ids.md` as a **separate standalone packet**, not as part of this initiative. Do not let it block Phase 1 filing.
