# Discord Webhook Rotation

**Credential family:** Discord webhook URLs (see [`infrastructure/reference/sensitive-inventory.md`](../reference/sensitive-inventory.md) — the nine Discord webhook rows: seven Actions org-secret webhooks + two ADR-0086 runner Key-Vault webhooks).
**Cadence:** None — Discord webhook URLs do not expire. They remain valid until manually revoked.
**Owner:** solo-dev
**Governing ADRs:** [ADR-0084](../../adrs/ADR-0084-discord-operator-alerts-surface.md) D4 (webhook URL storage), [ADR-0083](../../adrs/ADR-0083-external-saas-credential-rotation.md) D4 (rotation-procedure pattern).

---

## When to rotate

The **only** trigger is **suspected compromise**. Because Discord webhook URLs have no provider-imposed expiration, there is no scheduled rotation and no standing rotation issue — the inventory rows carry `Expiration Cadence: n/a — non-expiring (rotate on suspected compromise only)`.

Rotate immediately if a webhook URL is exposed beyond its secret store — for example committed to a repo, written to a log, captured in a screenshot, pasted into a chat message, or otherwise disclosed outside the GitHub org secret (Actions webhooks) or the `kv-hd-automation-dev` Key Vault (ADR-0086 runner webhooks).

This is a narrow procedure. Identify the exact channel and emitter class of the compromised webhook before you start, so you do not panic-rotate the wrong one under time pressure. There are two delivery paths and they store their webhooks in two different places (per ADR-0084 D4):

- **Actions webhooks** — GitHub org secrets `DISCORD_WEBHOOK_{CHANNEL_UPPER_SNAKE}`, consumed by `job-discord-notify.yml` in HoneyDrunk.Actions.
- **ADR-0086 runner webhooks** — Azure Key Vault `kv-hd-automation-dev` secrets `Discord--{ChannelPascalCase}--RunnerWebhookUrl`, resolved at runtime by the pull-based runner.

A channel served by both classes (`#agent-activity`, `#hive-activity` at v1) has **two independent webhooks**; rotating one does not affect the other. Confirm which one leaked.

Secret-handling discipline per [Invariant 8](../../constitution/invariants.md) and ADR-0084 D8 applies throughout: the new webhook URL is a secret value and must never be logged, pasted into a PR/issue/commit, or echoed into a Discord payload. This walkthrough references the URL only by location, never by value.

## Rotation steps

### Step 1 — Regenerate the webhook in Discord

1. Open the Discord server **Server Settings -> Integrations -> Webhooks**.
2. Select the compromised channel's webhook.
3. Open the **...** menu and **Delete Webhook** (or **Reset URL** if Discord offers it for that webhook type) — this invalidates the leaked URL immediately.
4. Recreate an incoming webhook on the same channel with the **same name** (`webhook-{channel}`).
5. **Copy the new webhook URL.** Hold it only in the clipboard long enough to paste it into the secret store in Step 2 — do not save it anywhere else.

### Step 2 — Update the store the webhook lives in

Pick the path matching the compromised webhook's emitter class.

**For an Actions webhook — update the GitHub org secret.**

1. Go to the GitHub org **Settings -> Secrets and variables -> Actions**.
2. Find the corresponding `DISCORD_WEBHOOK_{CHANNEL_UPPER_SNAKE}` secret (for example `DISCORD_WEBHOOK_OPS_ALERTS`).
3. Click **Update**, paste the new URL, and save.

**For an ADR-0086 runner webhook — update the Key Vault secret in `kv-hd-automation-dev`.**

1. Update the secret `Discord--{ChannelPascalCase}--RunnerWebhookUrl` (for example `Discord--AgentActivity--RunnerWebhookUrl`):

   ```sh
   az keyvault secret set \
     --vault-name kv-hd-automation-dev \
     --name "Discord--AgentActivity--RunnerWebhookUrl" \
     --value "<new-webhook-url>"
   ```

2. The runner resolves this secret by name at job time; no redeploy is required.

### Step 3 — Smoke-test

Confirm the new URL works before considering the rotation complete.

**For an Actions webhook:** manually dispatch a caller of `job-discord-notify.yml` (HoneyDrunk.Actions) targeting the rotated channel — for example `channel: {channel}`, `severity: info`, `title: "Webhook rotation smoke-test"`, `body: "Verifying rotation succeeded — please ignore."` — via `workflow_dispatch` on a repo that has access to the org secret.

**For an ADR-0086 runner webhook:** trigger a runner job that posts to the rotated channel (or re-run the runner's notify path).

Verify the test message lands in the correct channel within roughly **2 minutes**. If it does not, the secret update did not take — repeat **Step 2** and re-test.

### Step 4 — Cascade handling (only if the leaked URL was used for hostile content)

If the leaked webhook URL was used to post hostile content (most likely for `#announcements`), additionally:

1. **Delete the hostile messages** from the affected channel.
2. **Record the incident** in `generated/incidents/` per [ADR-0054](../../adrs/ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) D7.
3. **Post a one-line incident summary to `#audit-sensitive`** via the rotated webhook so the audit trail is complete (no secret values, no payload — just the incident reference).

The five-business-day post-mortem cadence per ADR-0054 applies if a paying tenant was impacted — unlikely for operator-internal alerts, but possible if a leaked `#announcements` URL was used for phishing against followers.

## Closing note

Record the rotation in the affected row's `Notes` column in [`infrastructure/reference/sensitive-inventory.md`](../reference/sensitive-inventory.md) with a timestamp and the trigger — for example `Rotated 2026-MM-DD — URL leaked in screenshot post`. That row Notes entry is the only persistent audit trail for a non-expiring credential. **Never log the new URL value anywhere** — not in the inventory, not in the incident record, not in a Discord payload (Invariant 8 / ADR-0084 D8).
