# Rotating `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`

The signing secret that authenticates Grid Review webhook payloads (per [ADR-0044](../../adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D2). It is a shared HMAC secret: the same value is configured on **both** the sender (the `HoneyDrunk.Actions` review-request workflow) and the receiver (the home-server review bridge). Rotation must update both ends in one window or signature verification fails closed. Per ADR-0083 D4.

> **What breaks if you forget:** review-request webhook payloads fail signature verification at the receiver, so the Grid Review runner stops processing review requests. (Under [ADR-0086](../../adrs/ADR-0086-pull-based-local-worker-grid-review-runner.md) the review transport is the pull-based label/comment queue; this secret remains live for any webhook-bridge path that still verifies it. If the webhook bridge is fully decommissioned, retire this secret and its inventory row instead of rotating.)

## Prerequisites and identity

You need admin access to the `HoneyDrunkStudios` GitHub org secrets and to the home-server review-bridge configuration that holds the receiver-side copy.

## Steps

1. **Generate a new secret.** Produce a high-entropy random value (e.g. `openssl rand -hex 32`). Copy it; do not commit it anywhere.
2. **Update the receiver first.** Set the new value in the home-server review-bridge config (the receiver that verifies the signature). Keep the old value accepted transiently if the bridge supports dual-secret verification; otherwise plan for a brief window in step 4.
3. **Update the GitHub org secret.** https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions → `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` → **Update** → paste the new value → **Save**.
4. **Verify.** Trigger a review request (open or re-label a test PR per `.honeydrunk-review.yaml`) and confirm the receiver accepts the payload signature (the review runner picks the request up; no signature-verification error in the bridge logs). A verification failure means the two ends are out of sync — re-check steps 2–3.
5. **Retire the old value** at the receiver once verification passes (if dual-secret verification was used).
6. **Close the standing rotation issue.** Open issue in `HoneyDrunk.Architecture` labeled `external-credential-rotation` titled `[Rotate] OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET — expires {previous-date}` → comment with the new rotation date → **Close**.
7. **Open the next standing issue.** New issue `[Rotate] OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET — expires {new-date}`, labeled `external-credential-rotation`, body linking this walkthrough + the inventory row.
8. **Update the inventory row.** Edit `infrastructure/reference/sensitive-inventory.md` → the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row → set `Current Expiration` to the new date. Commit + PR.

## Cross-references

- [`../reference/sensitive-inventory.md`](../reference/sensitive-inventory.md) — the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row.
- [ADR-0044](../../adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D2 — the webhook-signing-secret contract.
- [ADR-0086](../../adrs/ADR-0086-pull-based-local-worker-grid-review-runner.md) — the pull-based review transport that supersedes the OpenClaw webhook path.
- ADR-0083 D4 — the rotation-walkthrough convention this file implements.
