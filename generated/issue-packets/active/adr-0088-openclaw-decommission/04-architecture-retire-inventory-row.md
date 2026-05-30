---
name: Infrastructure
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "infrastructure", "adr-0088", "wave-3"]
dependencies: ["packet:03"]
adrs: ["ADR-0088", "ADR-0083"]
accepts: []
wave: 3
initiative: adr-0088-openclaw-decommission
node: honeydrunk-architecture
---

# Retire the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` inventory triplet + node-standup matrix row (gated on secret deletion)

## Summary
**Gated on packet 03 confirming the org secret is actually deleted (invariant 103).** Remove the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row from `infrastructure/reference/sensitive-inventory.md`; remove (or tombstone) `infrastructure/walkthroughs/openclaw-webhook-secret-rotation.md`; remove the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row from the per-class org-secret binding matrix in `constitution/node-standup.md`. This completes the inventory-triplet retirement (row + walkthrough + standing issue — issue #527 was closed in packet 03) plus the obsolete matrix-row removal (D3 Group 4 step 10).

## Context
ADR-0088 D3 Group 3 steps 7–8 and Group 4 step 10, **all gated on step 6 (the secret deletion in packet 03):**

> 7. **Only after step 6 succeeds:** remove the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row from `infrastructure/reference/sensitive-inventory.md`.
> 8. **Only after step 6 succeeds:** remove (or tombstone) `infrastructure/walkthroughs/openclaw-webhook-secret-rotation.md`.
> 10. Remove the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row from the `constitution/node-standup.md` per-class org-secret binding matrix. It is obsolete: nothing posts review results upstream through a webhook secret under ADR-0086.

The **invariant-103 ordering is the load-bearing constraint of this packet**: if these removals ran before the secret deletion, the inventory would claim the Grid holds nothing while the secret still existed in GitHub — a false inventory, which is exactly the failure mode invariant 103 exists to prevent. The drift-detection workflow (`external-credentials-check.yml`) reads the inventory as truth; deleting the row while the secret lived would blind the watcher to a live credential. That is why this packet is **blocked-by packet 03** and the agent must verify packet 03's deletion confirmation before merging.

The inventory row to remove is in `infrastructure/reference/sensitive-inventory.md` (the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row, `Kind: webhook-signing-secret`, `Rotates: yes`, `Current Expiration 2026-08-28`, linking to `openclaw-webhook-secret-rotation.md`). The matrix row to remove is in `constitution/node-standup.md` (line ~185): `| `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` | ADR-0044 review-pipeline upstream emission | Any Node whose `.honeydrunk-review.yaml` has `enabled: true` and posts review results upstream |`.

This is a docs-only packet. `Actor=Agent`. **Do not file or merge until packet 03 confirms the secret is gone.**

## Scope
- `infrastructure/reference/sensitive-inventory.md` — remove the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row entirely (the live secret no longer exists, so no row is required; it is not a `Rotates: no` survivor — it is gone).
- `infrastructure/walkthroughs/openclaw-webhook-secret-rotation.md` — remove the file, or replace its body with a one-line tombstone pointing at ADR-0088 (the walkthrough already anticipates this: "If the webhook bridge is fully decommissioned, retire this secret and its inventory row instead of rotating"). Default: **remove the file** and ensure no live link points at it.
- `constitution/node-standup.md` — remove the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row from the per-class org-secret binding matrix (the D8 matrix). Do NOT remove the OpenClaw skills-mirroring note at line 112 / line 98 of ADR-0082 — that is a separate ADR-0007 mirroring reference, out of scope here.
- Grep for any remaining live links to `openclaw-webhook-secret-rotation.md` (e.g. from the inventory's `Rotation Procedure` column — removed with the row; from any onboarding doc) and remove/rewrite them.

## Proposed Implementation
1. **Verify the gate.** Confirm packet 03's PR/issue body records the secret deleted and #527 closed. If not confirmed, do not proceed — this packet must not land before the deletion.
2. Remove the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row from `infrastructure/reference/sensitive-inventory.md`. The row is gone, not converted to `Rotates: no` — the secret no longer exists.
3. Remove `infrastructure/walkthroughs/openclaw-webhook-secret-rotation.md` (default) or replace with a one-line tombstone per the Decision Point below.
4. Remove the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row from the `constitution/node-standup.md` per-class org-secret binding matrix.
5. Grep for and remove/rewrite any live links to the removed walkthrough and any remaining inventory references to the secret.
6. Update `CHANGELOG.md`, explicitly noting the invariant-103 ordering (row removed only after packet 03 confirmed the secret deleted).

## Decision Point — remove vs. tombstone the walkthrough
ADR-0088 D3 step 8 says "remove (or tombstone)." Default: **remove the file.** The ADR record and the CHANGELOG carry the history; a rotation walkthrough for a secret that no longer exists is drift. If the operator prefers an explicit tombstone (e.g. to preserve the URL for any external bookmark), replace the body with one line: `> Retired per ADR-0088 — `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` was decommissioned (not rotated); the secret, the webhook bridge, and the OpenClaw runtime are gone. See ADR-0088 D3.` Either is acceptable; removal is the default.

## Affected Files
- `infrastructure/reference/sensitive-inventory.md` (row removed)
- `infrastructure/walkthroughs/openclaw-webhook-secret-rotation.md` (removed, or one-line tombstone)
- `constitution/node-standup.md` (matrix row removed)
- `CHANGELOG.md`

## NuGet Dependencies
None. Markdown edits/removals only; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any repo.
- [x] **Blocked-by packet 03** — the invariant-103 gate. This packet must not land before the secret is confirmed deleted.
- [x] `constitution/invariants.md` is NOT edited (ADR-0088 D6). Invariant 103's *text* is untouched; this packet honors its *ordering constraint*.
- [x] The OpenClaw skills-mirroring note (ADR-0007 mirroring reference) is NOT removed — that is a separate concern out of scope here; only the org-secret binding-matrix row is removed.

## Acceptance Criteria
- [ ] Packet 03's secret-deletion confirmation is verified before this packet lands (recorded in this packet's PR body)
- [ ] The `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row is removed from `infrastructure/reference/sensitive-inventory.md` (removed entirely — not converted to `Rotates: no`)
- [ ] `infrastructure/walkthroughs/openclaw-webhook-secret-rotation.md` is removed (default) or replaced with a one-line ADR-0088 tombstone
- [ ] The `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row is removed from the `constitution/node-standup.md` per-class org-secret binding matrix
- [ ] No live link to the removed walkthrough remains anywhere in the repo (verified by grep for `openclaw-webhook-secret-rotation`)
- [ ] The OpenClaw skills-mirroring note in `constitution/node-standup.md` is unchanged (only the binding-matrix row is removed)
- [ ] `constitution/invariants.md` is unchanged
- [ ] `external-credentials-check.yml` no longer has an `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row to read (confirmed by the inventory row's absence; the workflow itself lives in HoneyDrunk.Actions and reads the inventory — no edit to the workflow needed here)
- [ ] CHANGELOG.md records the inventory-triplet retirement and matrix-row removal, explicitly noting the invariant-103 ordering (row removed only after packet 03 confirmed the secret deleted)

## Human Prerequisites
- [ ] **Confirm packet 03 deleted the secret and closed #527 before this packet's PR merges.** This is the invariant-103 gate: the inventory row must not be removed until the secret it describes is actually gone. Verify via packet 03's PR/issue body and, if desired, `gh api /orgs/HoneyDrunkStudios/actions/secrets` showing no such secret. Record the verification in this packet's PR body.

## Dependencies
- `packet:03` — secret deletion + #527 closure (**hard, invariant-103 gate** — the inventory triplet retires only after the secret is confirmed deleted).

## Referenced ADR Decisions
**ADR-0088 D3 Group 3 steps 7–8 — Retire the inventory row + walkthrough, gated on secret deletion.** Only after the secret is deleted: remove the inventory row; remove/tombstone the rotation walkthrough.

**ADR-0088 D3 Group 4 step 10 — Remove the obsolete node-standup matrix row.** Nothing posts review results upstream through a webhook secret under ADR-0086, so the matrix row is obsolete.

**ADR-0088 D3 (Group 3 rationale) — the invariant-103 ordering.** "If steps 7–9 ran before step 6, the inventory would claim the Grid holds nothing while the secret still existed in GitHub — a false inventory, which is exactly the failure mode invariant 103 exists to prevent. The drift-detection workflow reads the inventory as truth; deleting the row while the secret lives would blind the watcher to a live credential."

**ADR-0088 D6 — No new invariants.** `constitution/invariants.md` is not edited.

## Constraints
> **Invariant 103:** *Every credential, identifier, secret, or load-bearing identity binding the Grid holds must have a row in `infrastructure/reference/sensitive-inventory.md`; rotation-needing rows additionally carry a `Current Expiration`, a walkthrough, and an open standing rotation issue.* The corollary is symmetric: the inventory must **not** carry a row for a credential the Grid no longer holds. Once packet 03 deletes the secret, this packet removes the row to keep the inventory honest. The ordering is hard — the row must outlive the secret right up to deletion, then be removed; never the reverse.

> **Invariant 8:** *Secret values never appear in logs, traces, exceptions, or telemetry.* The inventory never held the value; removing the row touches names and metadata only.

- **Verify the gate first.** Do not land this packet until packet 03 confirms the secret is deleted. This is the single most important constraint of this packet.
- **Remove the row, do not convert it.** The secret is gone, so the row is removed entirely — not downgraded to `Rotates: no`.
- **Do not edit `constitution/invariants.md`** (ADR-0088 D6). This packet honors invariant 103's ordering; it does not change its text.
- **Do not remove the OpenClaw skills-mirroring note** — only the org-secret binding-matrix row is in scope.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `infrastructure`, `adr-0088`, `wave-3`

## Agent Handoff

**Objective:** Remove the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` inventory row, the rotation walkthrough, and the node-standup binding-matrix row — only after packet 03 confirms the secret is deleted (invariant-103 gate).

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Complete D3 Group 3 steps 7–8 + Group 4 step 10 — retire the inventory triplet and the obsolete matrix row, keeping the inventory honest post-deletion.
- Feature: ADR-0088 OpenClaw decommission, Wave 3 (D3 Group 3, invariant-103 gate).
- ADRs: ADR-0088 (primary, D3 + the invariant-103 rationale), ADR-0083 (the inventory + invariant 103 this row belongs to).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` — secret deletion + #527 closure (hard, invariant-103 gate).

**Constraints:**
- Verify packet 03's deletion confirmation before landing — the inventory row must not be removed until the secret is gone (invariant 103).
- Remove the row entirely; do not convert to `Rotates: no`.
- Do not edit `constitution/invariants.md`.
- Do not remove the OpenClaw skills-mirroring note; only the binding-matrix row.

**Key Files:**
- `infrastructure/reference/sensitive-inventory.md`
- `infrastructure/walkthroughs/openclaw-webhook-secret-rotation.md`
- `constitution/node-standup.md`
- `CHANGELOG.md`

**Contracts:** None.
