# Handoff: Wave 1 → Wave 2 — ADR-0013 Communications Bring-Up

**Date written:** 2026-05-02
**Read at:** Wave 1 → Wave 2 transition (after packets 01 and 02 have merged/closed)
**Audience:** The Codex Cloud / Claude Code agent starting work on `03-communications-scaffold.md`

This handoff is a one-shot baton pass. It is read at the transition and then left alone — it is not a live tracker.

## Wave 1 completion state

Before starting Wave 2, confirm the following are true:

- [ ] Packet 01 PR merged to `HoneyDrunk.Architecture:main`
- [ ] ADR-0013 index row in `adrs/README.md` reads `Accepted`
- [ ] `ADR-0013-communications-orchestration-layer.md` header reads `**Status:** Accepted`
- [ ] `repos/HoneyDrunk.Communications/` directory exists with five files (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`) — these become the review agent's scope context for the scaffold PR
- [ ] `repos/HoneyDrunk.Notify/boundaries.md` and `integration-points.md` refreshed to acknowledge Communications as a downstream consumer of `INotificationSender`
- [ ] `initiatives/active-initiatives.md` has the "ADR-0013 Communications Bring-Up" entry with Wave 1–4 tracking and Phase 3 deferral
- [ ] `initiatives/roadmap.md` has Q2 2026 (Phase 1+2) and Q3 2026 (Phase 3) bullets
- [ ] Catalog audit completed (typically no edits — verify with `grep "honeydrunk-communications"` across the catalogs to confirm presence)
- [ ] Packet 02 chore closed — `HoneyDrunkStudios/HoneyDrunk.Communications` exists on GitHub with default branch `main`, branch protection mirrored from `HoneyDrunk.Notify`, LICENSE/README committed
- [ ] Labels seeded on the new repo via the Next Steps script in packet 02 (feature, tier-3, new-node, ops, scaffolding, adr-0013, wave-2)
- [ ] Packet 03 (`03-communications-scaffold.md`) filed as an issue against `HoneyDrunkStudios/HoneyDrunk.Communications` via the Next Steps script in packet 02

If any box is unchecked, stop and resolve it before starting Wave 2. The scaffold PR's review agent reads these files as scope context; if they are missing, the review degrades and Wave 2 quality drops.

## Wave 2 packet (scaffold only)

Only one packet in Wave 2.

### Packet 03 — `03-communications-scaffold.md` → target `HoneyDrunk.Communications`

Scaffolds the new repo with:
- `HoneyDrunk.Communications.slnx`
- `src/HoneyDrunk.Communications.Abstractions/` project (empty shell — no `.cs` files beyond optional `AssemblyInfo`)
- `src/HoneyDrunk.Communications/` project (empty shell, references Abstractions)
- `tests/.gitkeep` placeholder
- Repo-root `README.md`, `CHANGELOG.md` (version 0.1.0), `.editorconfig`, `Directory.Build.props`
- Per-package `README.md` and `CHANGELOG.md` for both projects
- `.github/workflows/pr-core.yml` consuming the `HoneyDrunk.Actions` reusable validate-pr workflow

**No public types, no contracts, no concrete implementations.** The scaffold PR exists to prove the build + CI plumbing works on a clean slate. Phase 1 contracts ship in packet 04 (Wave 3); Phase 2 welcome flow ships in packet 05 (Wave 4).

## Reference repos for templates

- `.editorconfig`, `Directory.Build.props` — copy from `HoneyDrunk.Notify` (closest shape — Ops sector, two main packages, one repo)
- `pr-core.yml` workflow — copy from `HoneyDrunk.Notify/.github/workflows/pr-core.yml`. If Notify references a specific HoneyDrunk.Actions ref/tag, mirror it exactly.
- Branch protection rules — already mirrored from `HoneyDrunk.Notify` by the human in packet 02

## New package versions to reference after Wave 2 merges

- `HoneyDrunk.Communications.Abstractions` — `0.1.0` (built but not published yet — publish workflow ships in Phase 1 packet 04)
- `HoneyDrunk.Communications` — `0.1.0` (built but not published yet)

Both projects move together per invariant 27. The first packet (03 — scaffold) bumps to 0.1.0 because it is the first packet to land on the solution. Per invariant 27 phrasing: "The first packet to land on a solution in an initiative bumps the version; subsequent packets on the same solution append to the CHANGELOG only" — but **packet 04 will also bump (to 0.2.0) and packet 05 will also bump (to 0.3.0)** because Phase 1 and Phase 2 each ship distinct shipped behavior worth a version increment, not just additional commits to the same in-progress version.

That is consistent with invariant 27 and the existing initiative pattern (e.g., ADR-0010 Wave 2 bumped Observe.Abstractions to 0.1.0 as its first version because packet 03 there was the first packet on a fresh solution; subsequent packets in that initiative would have continued bumping if there had been more).

## Invariants that govern Wave 2

- **Invariant 1** — Abstractions has zero runtime HoneyDrunk dependencies. Empty Abstractions project naturally honors this; verify after authoring.
- **Invariant 2** — Runtime depends on Abstractions only at this layer. The scaffold packet adds NO Kernel reference yet (that arrives in packet 04). The runtime project has a single `<ProjectReference>` to Abstractions; that's it.
- **Invariant 11** — One repo per Node. New repo created in packet 02; this packet stands up its skeleton.
- **Invariant 12** — Repo-level CHANGELOG and per-package README + CHANGELOG mandatory from first commit. The scaffold PR creates all of them.
- **Invariant 16** — No test code in runtime packages. `tests/.gitkeep` placeholder honors this.
- **Invariant 26** — `HoneyDrunk.Standards` on every new project, `PrivateAssets="all"`. Both projects must reference it.
- **Invariant 27** — First packet bumps. Both projects start at 0.1.0.
- **Invariant 31** — PR traverses tier-1 gate. `pr-core.yml` is the wiring.
- **Invariant 32** — PR body links back to the packet.

## Out of scope for Wave 2

Reminder — do not attempt:
- Defining `ICommunicationOrchestrator`, `IMessageIntent`, `IRecipientResolver`, `IPreferenceStore`, `ICadencePolicy` — these are Phase 1 (packet 04)
- Adding `HoneyDrunk.Kernel.Abstractions` or `HoneyDrunk.Kernel` references — Phase 1 (packet 04)
- Adding `HoneyDrunk.Notify.Abstractions` reference — Phase 2 (packet 05)
- Implementing the welcome flow, in-memory stores, decision log, follow-up scheduler — Phase 2 (packet 05)
- Adding test projects (HoneyDrunk.Communications.Tests / .Canary) — Phase 2 (packet 05) populates them
- Adding publish workflows (release-abstractions.yml, release-runtime.yml) — packet 04 / 05
- Provisioning any Azure resources — Phase 3 (separate initiative)

If scope feels small, that is intentional — the scaffold packet exists to prove the foundation is sound on an empty solution before any contract surface lands.

## Following Wave 2 → Wave 3 transition

After packet 03 merges, file packet 04 (`04-communications-phase1-contracts.md`) by hand:

```bash
PACKETS="generated/issue-packets/active/adr-0013-communications-bringup"

ISSUE_URL=$(gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Communications \
  --title "Phase 1: define 5 seed contracts in Abstractions and wire Kernel integration" \
  --body-file "$PACKETS/04-communications-phase1-contracts.md" \
  --label "feature,tier-2,ops,contracts,adr-0013,wave-3")
echo "Filed: $ISSUE_URL"

# Add to The Hive and set board fields per the standard pattern.
gh project item-add 4 --owner HoneyDrunkStudios --url "$ISSUE_URL"

# Wire the blocking relationship (packet 04 blocked by packet 03's issue)
# Replace <packet-04-node-id> and <packet-03-node-id> with values from `gh api graphql` lookup.
gh api graphql -f query='mutation { addBlockedBy(input: { issueId: "<packet-04-node-id>" blockingIssueId: "<packet-03-node-id>" }) { issue { number } blockingIssue { number } } }'
```

Same pattern for packet 05 after packet 04 merges. Packets 04 and 05 do not need a separate handoff document — the dispatch plan and the packet bodies themselves carry enough context. If divergence is discovered between expected and actual state at those transitions, file a follow-up issue and stop rather than improvising.

## On encountering divergence

If an executor discovers Wave 1 output has drifted from what this handoff describes — e.g., `repos/HoneyDrunk.Communications/` is missing files, or the new GitHub repo does not exist, or the catalog audit found drift that was not fixed — do not improvise. Stop, file a follow-up issue against `HoneyDrunk.Architecture` describing the drift, and wait for resolution. Silent improvisation at the boundary is how the review agent's scope check breaks.
