---
name: HoneyHub Launch-Blocking Checkpoint
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.HoneyHub
labels: ["chore", "tier-2", "ai", "distribution-90", "honeyhub"]
dependencies: []
adrs: ["PDR-0011", "ADR-0090", "ADR-0091", "ADR-0092"]
source: human
generator: scope
wave: 2
initiative: distribution-90
node: honeydrunk-honeyhub
actor: agent
---

# Chore: Close the HoneyHub v0.1.0 launch-blocking PR stack

## Summary
Finish the in-flight HoneyHub work that gates a public v0.1.0: the routing PR (#33), the agent-discovery rework, and the Sonar onboarding (#35). This packet is a **checkpoint, not a re-scope** — the work is already defined in the `honeyhub-v1` initiative and in-repo; this packet exists so Distribution 90's launch sequencing (tag → demo → post → submissions) has an explicit "launch-blocking subset done" gate to block on.

## Context
Distribution 90 launches HoneyHub v0.1.0 publicly (packets 08–11). The cockpit is shipped and runnable (Phase 2 complete: bridge core, pairing/allowlists, `claude.local` adapter, local store, run screen, WebSocket transport). The remaining in-flight items as of 2026-06-09:

1. **Routing (#33)** — synced-snapshot routing engine; was blocked on an Architecture invariant-45 amendment commit. Verify current state against live GitHub before starting (local checkouts are routinely stale — check `gh pr list`/`gh issue list` on the repo, not a working copy).
2. **Agent-discovery rework** (branch `fix/honeyhub-copilot-agents-folder`) — global `~/.claude/agents` + `~/.copilot/agents` scanning; one entry per name, runnable on multiple backends. Source conventions: Claude = every `.claude/agents/*.md`; Copilot = `.github/` files with "agent" in the name; Codex = none. Read-only, allowlisted roots only, metadata-only.
3. **Sonar onboarding (#35)** — SonarCloud analysis on PRs.

**Launch-blocking judgment:** items 1–2 are launch-blocking (they are user-facing v0.1.0 features per PDR-0011 §6: agent-discovery is in the v1 scope; routing ships free-tier). Item 3 (Sonar) is launch-*adjacent* CI hygiene — close it if cheap, but it must not hold the tag; record an explicit operator call in the issue if it slips past the tag.

## Scope
- Whatever the three in-flight items already touch in `HoneyDrunk.HoneyHub`. No new feature scope may ride along under this packet.

## Human Prerequisites
- [ ] If #33 is still blocked on the Architecture invariant-45 amendment, land/merge that amendment commit in `HoneyDrunk.Architecture` first (operator or a separate ADR-governed change — NOT part of this packet).
- [ ] Operator merge-approval on each PR per normal review flow (Copilot + CodeRabbit + Grid Review all land and resolve before merging).

## Acceptance Criteria
- [ ] Routing PR (#33 or its successor) merged to `main`.
- [ ] Agent-discovery rework merged to `main` (global folder scanning, one-entry-per-name multi-backend model, read-only/allowlisted/metadata-only).
- [ ] Sonar (#35) merged, OR an explicit recorded decision that it ships post-tag.
- [ ] `main` is green: workspace builds, tests pass, the cockpit drives a real `claude.local` session end-to-end (`cargo run -p honeyhub-bridge-host` + PWA connect smoke).
- [ ] Repo-level `CHANGELOG.md` reflects all merged work under the in-progress version entry (invariants 12/27: every shipped change gets a changelog entry; the first packet to land on a solution in an initiative bumps the version, subsequent packets append to the existing entry — packet 08 owns the 0.1.0 freeze).

## Dependencies
None within Distribution 90 (this is the upstream gate). External: the invariant-45 amendment in Architecture for #33, tracked in the `honeyhub-v1` initiative.

## Downstream Unblocks
Packets 08 (tag v0.1.0), 09 (demo), and transitively 10–11.

## Agent Handoff

**Objective:** Merge the launch-blocking in-flight HoneyHub stack (routing, agent-discovery) plus Sonar if cheap, leaving `main` green and demo-able.
**Target:** `HoneyDrunkStudios/HoneyDrunk.HoneyHub`, existing in-flight branches / branch from `main`.
**Context:**
- Goal: Distribution 90 Wave 2 — the "launch-blocking subset done" gate for the v0.1.0 public launch.
- The substantive specs live in the `honeyhub-v1` initiative packets and the in-flight PRs/branches; do not re-scope them here.

**Acceptance Criteria:** as listed above.

**Dependencies:** Architecture invariant-45 amendment for #33 (verify live state first).

**Constraints:**
- Verify cross-repo and PR state against **live GitHub** (`gh pr view`, `gh api`), never local sibling checkouts.
- PDR-0011 `[Firm]` boundaries hold: no editor/terminal features, PRs-as-artifacts write boundary, local-first data default, honest capability flags, cloud = BYOK-only / never subscription auth.
- Every PR body carries `Authorship:` plus exactly one of `Work Item:` / `Out-of-band reason:` (pr-core enforces the strict format).
- All three reviewers (Copilot, CodeRabbit, Grid Review) must land and all threads resolve before merge.
- Agent-authored PRs must link to their packet in the PR body (invariant 32).

**Key Files:**
- Per the in-flight PRs (routing engine, agent-discovery scanner in the bridge, Sonar workflow config).

**Contracts:**
- ADR-0090 bridge contract; ADR-0092 session/usage-telemetry/routing decisions (already implemented in-repo — do not change contract shapes under this packet).
