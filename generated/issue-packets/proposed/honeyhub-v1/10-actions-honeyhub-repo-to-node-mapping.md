---
name: Repo-to-Node Mapping
type: cross-repo-change
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-1", "meta", "honeyhub", "adr-0091", "wave-2"]
dependencies: ["packet:02"]
adrs: ["ADR-0091", "ADR-0082"]
accepts: ADR-0091
source: human
generator: scope
wave: 2
initiative: honeyhub-v1
node: honeydrunk-honeyhub
actor: agent
---

# Chore: Add HoneyDrunk.HoneyHub → honeydrunk-honeyhub mapping to repo-to-node.yml (in HoneyDrunk.Actions)

## Summary
Add the `HoneyDrunk.HoneyHub` → `honeydrunk-honeyhub` row to `HoneyDrunk.Actions/.github/config/repo-to-node.yml` so issue routing and the grid-health aggregator resolve issues filed against the new repo back to its Node identity. This is the routing half of the new-repo registration; it was split out of packet 02 because that packet targets `HoneyDrunk.Architecture` and this work edits a file in `HoneyDrunk.Actions` (one target repo per packet). It depends on packet 02 — the `HoneyDrunk.HoneyHub` repo must exist before the mapping is meaningful.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Actor
**`Agent`.** This is a small, agent-eligible single-line config edit + PR against `HoneyDrunk.Actions` `main`. No org-admin rights are required (unlike packet 02's repo-creation work).

## Motivation
Per **invariant 41** (*new Grid repos are added to `HoneyDrunk.Architecture/repos/` at creation time — a repo missing from the catalog is invisible to grid observability*) and **ADR-0082 mandatory step 7** (routing / grid-health resolution), a new Node repo must be mapped in `repo-to-node.yml` so issue routing and the grid-health aggregator can resolve issues filed against the repo back to its Node identity (`honeydrunk-honeyhub`). Without this mapping, issues filed against `HoneyDrunk.HoneyHub` cannot be resolved to the Node, breaking grid observability. This was historically the most frequently missed standup step, which is why it is its own tracked packet.

Packet 02 creates the GitHub repo (Architecture-targeted tracking work); this packet lands the routing mapping in `HoneyDrunk.Actions`. The two travel in parallel after packet 02: packet 02 (repo + branch protection + labels + clone) and this packet (repo-to-node mapping) are both Phase B work but live in different target repos, so they are separate packets per the one-target-repo-per-packet rule.

## Steps

### Step 1 — Add the mapping row
Edit `HoneyDrunk.Actions/.github/config/repo-to-node.yml` and add a row mapping `HoneyDrunk.HoneyHub` → `honeydrunk-honeyhub`, matching the format of the existing rows (one `RepoName: node-id` line per repo):

```yaml
HoneyDrunk.HoneyHub: honeydrunk-honeyhub
```

### Step 2 — Open and merge the PR
Branch from `main`, commit the single-line addition, open a PR against `HoneyDrunk.Actions` `main`, link this packet (invariant 32), and merge once the tier-1 gate passes.

## Acceptance Criteria
- [ ] `HoneyDrunk.Actions/.github/config/repo-to-node.yml` contains a `HoneyDrunk.HoneyHub: honeydrunk-honeyhub` row (matching the existing rows' format).
- [ ] The change is merged to `HoneyDrunk.Actions` `main`.
- [ ] PR body links this packet (invariant 32).

## Dependencies
- `packet:02` — the `HoneyDrunk.HoneyHub` GitHub repo must exist before the repo-to-node mapping is meaningful. This packet runs in parallel with packet 03 once packet 02 is Done.

## Downstream Unblocks
- None directly; the mapping makes issues filed against `HoneyDrunk.HoneyHub` (e.g. packet 03 and Phase 2 packets) resolvable to the `honeydrunk-honeyhub` Node identity in grid observability.

## Agent Handoff
**Objective:** Add the `HoneyDrunk.HoneyHub` → `honeydrunk-honeyhub` row to `HoneyDrunk.Actions/.github/config/repo-to-node.yml` and merge it to `main`.
**Target:** `HoneyDrunkStudios/HoneyDrunk.Actions`, branch from `main`.
**Context:** The routing half of the Phase B standup for `HoneyDrunk.HoneyHub` (ADR-0082 mandatory step 7). Split out of packet 02 because that packet targets `HoneyDrunk.Architecture`; this edit lives in `HoneyDrunk.Actions` (one target repo per packet).

**Acceptance Criteria:** as listed above.

**Dependencies:** packet 02 Done (repo exists).

**Constraints:**
- Invariant 41 (new Grid repos are added to `HoneyDrunk.Architecture/repos/` at creation time; a repo missing from the catalog is invisible to grid observability) — the `repo-to-node.yml` mapping is the routing half of this.
- ADR-0082 mandatory step 7 (routing / grid-health resolution) — the new repo must be mapped so issue routing and the grid-health aggregator resolve issues back to the Node identity.

**Key Files:**
- `HoneyDrunk.Actions/.github/config/repo-to-node.yml`.

**Contracts:** None.
