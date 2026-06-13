---
name: Infrastructure
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "ops", "infrastructure", "human-only", "adr-0088", "wave-3"]
dependencies: ["work-item:02"]
adrs: ["ADR-0088", "ADR-0006", "ADR-0044", "ADR-0083"]
accepts: []
wave: 3
initiative: adr-0088-openclaw-decommission
node: honeydrunk-architecture
---

# Delete the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` org secret; close issue #527 (decommission, no successor)

## Summary
Human-only org-admin chore: delete the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` org Actions secret at `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions`. This is the single OpenClaw-bound credential that exists. Then close standing rotation issue **#527** (`[Rotate] OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET — expires 2026-08-28`) with a comment recording the **decommission** (not a rotation), referencing ADR-0088. **Do not open a successor standing issue** — there is no longer a credential to rotate. No GitHub App or App private key is deleted (none is OpenClaw's — `honeydrunk-grid-review` is the retained ADR-0086 worker identity). **This packet is the hard prerequisite for packet 04** — the inventory triplet retires only after this deletion is confirmed (invariant 103).

## Context
ADR-0088 D3 Group 3, steps 6 and 9:

> 6. **Delete the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` org Actions secret** at `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions`. This is the single OpenClaw-bound credential that exists. No GitHub App or App private key is deleted (none is OpenClaw's).
> 9. **Only after step 6 succeeds:** close GitHub issue **#527** with a comment recording the decommission (not a rotation), referencing this ADR. **Do not open a successor standing issue** — there is no longer a credential to rotate.

This is the **point of no return** per ADR-0088 D5: once deleted, the prior HMAC value is gone (invariant 8: the inventory never held the value). Rolling back means *minting a new secret* and re-creating both ends, not "undeleting." This is acceptable because the webhook bridge it signed is already torn down (packet 02, the blocker for this packet) and the review transport has been the pull-based worker since ADR-0086.

This packet is also where ADR-0088 D4's access-policy anomaly resolves: `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` carries the `All repositories` access policy, which contradicts node-standup's "Selected repositories is the default for org secrets containing live credentials." Because the secret is **deleted** outright, no access-policy remediation is needed — deletion resolves the drift. This packet records that the deletion also closes the anomaly.

`Actor=Human` — agents cannot delete org secrets. The agent's only role is to author the CHANGELOG record and verify (via `gh`) that the secret is gone and #527 is closed, once the operator performs the deletion.

## Scope (operator/org-admin actions — in Human Prerequisites)
- Delete the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` org Actions secret.
- Close issue #527 with a decommission comment referencing ADR-0088; do not open a successor.
- Confirm no GitHub App or App private key is deleted.

## Repo-side record
- `CHANGELOG.md` — record the secret deletion (name + timestamp, never value), the closure of #527 as a decommission with no successor, and the resolution of the D4 `All repositories` access-policy anomaly by deletion.

## Boundary Check
- [x] Org-admin action in GitHub org settings; the record lands in `HoneyDrunk.Architecture`.
- [x] No code change in any repo.
- [x] **Blocked-by packet 02** — the webhook bridge the secret signed is torn down first, so deletion is clean (D5).
- [x] **Hard prerequisite for packet 04** — the inventory triplet retires only after this deletion is confirmed (invariant 103).
- [x] No GitHub App or App private key is deleted (none is OpenClaw's; `honeydrunk-grid-review` is the retained ADR-0086 worker identity).
- [x] **The inventory row is NOT removed in this packet** — packet 04 removes it, gated on this deletion. Removing the row here, before/with the deletion, would be acceptable only because the secret is also gone — but the ADR sequences the row removal as a separate gated packet to keep the invariant-103 ordering auditable. Do not touch `sensitive-inventory.md` here.

## Acceptance Criteria
- [ ] The `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` org Actions secret no longer exists in org settings (verified — e.g. `gh api /orgs/HoneyDrunkStudios/actions/secrets` shows no such secret)
- [ ] Issue #527 is closed with a comment recording the decommission (not a rotation) and referencing ADR-0088
- [ ] No successor standing rotation issue is opened (ADR-0088 D3 step 9)
- [ ] No GitHub App or App private key is deleted; `honeydrunk-grid-review` (app_id 3841539) remains installed and is confirmed as the retained ADR-0086 worker identity
- [ ] `CHANGELOG.md` records the secret deletion (name + timestamp, never value), the #527 closure as a decommission with no successor, and the D4 access-policy anomaly resolved by deletion
- [ ] The `infrastructure/reference/sensitive-inventory.md` row is NOT modified in this packet (packet 04 owns the gated removal)
- [ ] The PR/issue body carries the operator's confirmation (secret deleted at YYYY-MM-DD HH:MM; #527 closed; no successor opened) as the audit record and as the signal packet 04 reads to proceed

## Human Prerequisites
- [ ] **Packet 02 (runtime/bridge/tunnel teardown) must have completed.** The webhook bridge the secret signed must be gone first (D5 — so deletion is clean; nothing is left verifying signatures against a now-deleted secret).
- [ ] **Delete the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` org Actions secret.** Go to `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions`, find `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`, and delete it. This is irreversible for the HMAC value (D5 point of no return).
- [ ] **Before deleting, confirm nothing live still references it.** Run a `gh` org-wide code search for the secret name; the only references should be the deprecated (declared-but-unreferenced) inputs in `HoneyDrunk.Actions/job-review-request.yml` (removed in packet 06) and governance docs (reconciled in packets 04/05). No live workflow should consume it.
- [ ] **Close issue #527** (`[Rotate] OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET — expires 2026-08-28`) with a comment: "Decommissioned per ADR-0088 — the webhook bridge and OpenClaw runtime are torn down and the org secret is deleted. This is a decommission, not a rotation; no successor rotation issue is opened (ADR-0088 D3 step 9)." Do **not** open a successor.
- [ ] **Confirm no GitHub App is deleted.** Verify `honeydrunk-grid-review` (app_id 3841539) remains installed — it is the retained ADR-0086 worker identity, not OpenClaw's.
- [ ] **Record the confirmation in this packet's PR/issue body** (secret deleted at YYYY-MM-DD HH:MM; #527 closed; no successor). Packet 04 reads this confirmation as its gate.

## Dependencies
- `work-item:02` — operator runtime/bridge/tunnel teardown (the bridge the secret signed must be gone before deletion; D5).

## Referenced ADR Decisions
**ADR-0088 D3 Group 3 step 6 — Delete the org secret.** The single OpenClaw-bound credential that exists. No GitHub App or App private key is deleted.

**ADR-0088 D3 Group 3 step 9 — Close issue #527 as a decommission.** Comment recording the decommission, referencing ADR-0088. Do not open a successor — there is no longer a credential to rotate.

**ADR-0088 D4 — Access-policy anomaly resolved by deletion.** `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` carried `All repositories` (contradicting the `Selected repositories` default for live-credential org secrets). Deletion resolves the drift; no separate remediation needed.

**ADR-0088 D5 — Point of no return.** Secret deletion is the irreversible step for this credential. Rollback = minting a new secret and re-creating both ends, not undeleting. Acceptable because the bridge is already torn down (packet 02) and the review transport is the pull-based worker.

**Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The inventory never held the secret value; the deletion destroys the value with no recoverable copy. The CHANGELOG/PR record carries the secret *name* and timestamp only — never the value.

**Invariant 103 (the gate this packet feeds) — Every credential the Grid holds must have a row in `infrastructure/reference/sensitive-inventory.md`; rotation-needing rows additionally carry a `Current Expiration`, a walkthrough, and an open standing rotation issue.** Until this packet deletes the secret, the row must remain (the inventory must reflect what the Grid actually holds). Packet 04 removes the row only after this deletion is confirmed — the row removal is *forbidden* before the secret is gone, because that would make the inventory claim the Grid holds nothing while the secret still existed.

## Constraints
- **This is the point of no return.** Confirm packet 02 is complete and nothing live still references the secret before deleting.
- **Decommission, not rotation.** Close #527 as a decommission; do NOT open a successor rotation issue (D3 step 9).
- **Do not touch `sensitive-inventory.md` here.** The row removal is packet 04, gated on this deletion (invariant 103). Keeping the steps separate keeps the ordering auditable.
- **Do not delete any GitHub App.** `honeydrunk-grid-review` is the retained worker identity; no OpenClaw App exists.
- **Never write the secret value anywhere** (invariant 8). The record carries the name and timestamp only.
- **No access-policy remediation needed** — deletion resolves the D4 `All repositories` anomaly; do not attempt to narrow the policy before deleting.

## Labels
`chore`, `tier-2`, `meta`, `ops`, `infrastructure`, `human-only`, `adr-0088`, `wave-3`

## Agent Handoff

**Objective (Actor=Human):** Delete the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` org Actions secret and close issue #527 as a decommission with no successor. Confirm no GitHub App is deleted. Record the confirmation (the signal packet 04 reads as its invariant-103 gate). No inventory edit here.

**Target:** GitHub org settings + issue #527; record in `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Complete D3 Group 3 step 6 + step 9 — the point-of-no-return secret deletion and the standing-issue closure.
- Feature: ADR-0088 OpenClaw decommission, Wave 3 (D3 Group 3).
- ADRs: ADR-0088 (primary, D3 Group 3 + D4 + D5), ADR-0006 (secret lifecycle — deletion-vs-rotation path), ADR-0044 (the secret's origin), ADR-0083 (the inventory the row belongs to).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` — runtime/bridge/tunnel teardown (the bridge must be gone first; D5).

**Constraints:**
- Point of no return — confirm packet 02 done and nothing live references the secret first.
- Decommission, not rotation — close #527, no successor.
- Do not touch `sensitive-inventory.md` (packet 04 owns the gated removal).
- Do not delete any GitHub App.
- Never write the secret value (invariant 8).

**Key Files:**
- `CHANGELOG.md` (the deletion record + the gate signal for packet 04)

**Contracts:** None.
