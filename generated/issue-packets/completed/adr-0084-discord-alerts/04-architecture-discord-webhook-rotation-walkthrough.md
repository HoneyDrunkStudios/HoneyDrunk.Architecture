---
name: Discord Webhook Rotation Walkthrough
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0084", "wave-2"]
dependencies: ["packet:02"]
adrs: ["ADR-0084", "ADR-0083"]
wave: 2
initiative: adr-0084-discord-alerts
node: honeydrunk-architecture
source: strategic
generator: scope
---

# Ship infrastructure/walkthroughs/discord-webhook-rotation.md

## Summary
Author `infrastructure/walkthroughs/discord-webhook-rotation.md` per ADR-0083 D4's rotation-procedure pattern: regenerate the webhook in Discord → update the corresponding GitHub org secret → smoke-test by POSTing a test payload via `job-discord-notify.yml` (once it lands in packet 05) or via `infrastructure/scripts/discord-notify.ps1` (once it lands in packet 06).

## Context
ADR-0084 D4 explicitly defers this artifact: *"Rotation procedure per ADR-0083 D4 lands as `infrastructure/walkthroughs/discord-webhook-rotation.md` (regenerate the webhook in Discord → update the GitHub org secret → smoke-test). This composes naturally with ADR-0083; it does not amend it."*

Discord webhook URLs have no provider-imposed expiration. The rotation procedure exists for one trigger: **suspected compromise**. The blast-radius prose in `sensitive-inventory.md` (packet 03) and the inventory's cadence (`n/a — non-expiring (rotate on suspected compromise only)`) frame the procedure's narrow purpose. The walkthrough is therefore short — three steps plus a verification step — but must be precise so the operator does not panic-rotate the wrong webhook under time pressure.

The walkthrough is referenced from all seven rows of `sensitive-inventory.md` (packet 03). It is the single canonical procedure for any Discord webhook rotation. If a procedural change is needed across all seven webhooks, it lands here, not in seven places.

## Scope
- `infrastructure/walkthroughs/discord-webhook-rotation.md` — NEW file. Three numbered steps + verification, plus a preamble framing the procedure's trigger (suspected compromise) and a closing note on what to do if the rotation cascades (e.g., the leaked URL was used to post hostile content to `#announcements`).

## Proposed Implementation
1. Create `infrastructure/walkthroughs/discord-webhook-rotation.md` with:

   - **Preamble** — explains the procedure's narrow trigger: Discord webhook URLs do not expire, so this rotation runs only on suspected compromise (URL leaked into a commit, log, screenshot, chat message, or otherwise exposed beyond GitHub org secrets). Cross-links to: `infrastructure/reference/sensitive-inventory.md` for the seven webhook inventory rows, ADR-0084 D4 for the storage decision, ADR-0083 D4 for the procedure pattern, and Invariant 8 for the secret-handling discipline.

   - **Step 1 — Regenerate the webhook in Discord.** Server Settings → Integrations → Webhooks → select the channel's webhook → click "..." menu → Delete Webhook (or Reset URL if Discord supports it for the channel's webhook type). Then create a new incoming webhook with the same name (`webhook-{channel}`). Copy the new webhook URL.

   - **Step 2 — Update the GitHub org secret.** Settings → Secrets and variables → Actions → find the corresponding `DISCORD_WEBHOOK_{CHANNEL_UPPER_SNAKE}` secret → Update → paste new URL. Save.

   - **Step 3 — Smoke-test.** Trigger a test POST to confirm the new URL works. Two equivalent paths:
     - From GitHub Actions: trigger `job-discord-notify.yml` (packet 05) with `channel: {channel}`, `severity: info`, `title: "Webhook rotation smoke-test"`, `body: "Verifying rotation succeeded — please ignore."` via a manual `workflow_dispatch` on any repo that has access to the org secret.
     - From the home server: run `infrastructure/scripts/discord-notify.ps1 -Channel {channel} -Severity info -Title "Webhook rotation smoke-test" -Body "Verifying rotation succeeded — please ignore."` (packet 06).
     - Verify the message lands in the correct channel. If it does not land within 2 minutes, the URL update did not take — repeat Step 2.

   - **Step 4 — Cascade handling.** If the leaked URL was used to post hostile content (most likely for `#announcements`), additionally: (a) delete the hostile messages from the channel, (b) record the incident in `generated/incidents/` per ADR-0054 D7, (c) post a one-line incident summary to `#audit-sensitive` via the rotated webhook so the audit trail is complete. The five-business-day post-mortem cadence per ADR-0054 D-?? applies if a paying tenant was impacted (which is unlikely for operator-internal alerts but possible if a leaked `#announcements` URL was used for phishing against followers).

   - **Closing note** — record the rotation in the `sensitive-inventory.md` row's Notes column with a timestamp and the trigger (e.g., `Rotated 2026-MM-DD — URL leaked in screenshot post`). This is the only persistent audit trail; do not log the new URL value anywhere.

2. The walkthrough must not contain any concrete webhook URL value at any point. The procedure references the URL by location (Discord webhook config / GitHub org secret slot) but never by value.

## Affected Files
- `infrastructure/walkthroughs/discord-webhook-rotation.md` (NEW)

## NuGet Dependencies
None. Markdown only.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any other repo.
- [x] Walkthrough document is governance documentation, not Node contract; no catalog change.

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/discord-webhook-rotation.md` exists with four sections: Preamble + Step 1 (Discord regenerate) + Step 2 (GitHub org-secret update) + Step 3 (smoke-test) + Step 4 (cascade handling) + Closing note
- [ ] The preamble explicitly states the procedure's narrow trigger (suspected compromise) and cross-links to `infrastructure/reference/sensitive-inventory.md`, ADR-0084 D4, ADR-0083 D4, and Invariant 8
- [ ] Step 3 documents both smoke-test paths — `job-discord-notify.yml` (GitHub Actions, packet 05) and `discord-notify.ps1` (home server, packet 06) — with the verification cadence (message lands within 2 minutes; if not, repeat Step 2)
- [ ] Step 4 cross-links to ADR-0054 D7 (incident records) and the audit-trail discipline for `#audit-sensitive` notification post-rotation
- [ ] The closing note specifies that the rotation is recorded in the `sensitive-inventory.md` row's Notes column with a timestamp and trigger (e.g., `Rotated YYYY-MM-DD — <trigger>`); the new URL value is not logged anywhere
- [ ] No webhook URL value appears anywhere in the document (per Invariant 8 and ADR-0084 D8)
- [ ] The document references the canonical channel names (`#ops-alerts`, `#security-alerts`, `#agent-activity`, `#hive-activity`, `#release`, `#announcements`, `#audit-sensitive`) and the canonical secret-name pattern (`DISCORD_WEBHOOK_{CHANNEL_UPPER_SNAKE}`) verbatim from ADR-0084 D2 / D4

## Human Prerequisites
None — packet 02 (the human-only provisioning) is a hard dependency. The walkthrough documents how to rotate webhooks that already exist.

## Referenced ADR Decisions
**ADR-0084 D4 — Webhook URL storage.** *"Rotation procedure per ADR-0083 D4 lands as `infrastructure/walkthroughs/discord-webhook-rotation.md` (regenerate the webhook in Discord → update the GitHub org secret → smoke-test). This composes naturally with ADR-0083; it does not amend it."* The walkthrough is the canonical procedure for any Discord webhook rotation; `sensitive-inventory.md` rows point at this file as the rotation-walkthrough authority.

**ADR-0084 D8 — Privacy and signal-hygiene rules.** Webhook URLs are secret values per Invariant 8. The walkthrough must not contain any concrete URL value; references the URL by location (Discord webhook config / GitHub org secret slot) but never by value.

**ADR-0084 D9 — Implementation seam.** The smoke-test path uses `job-discord-notify.yml` (CI emitters) or `infrastructure/scripts/discord-notify.ps1` (home-server emitters). Both consume the rotated webhook URL via secret resolution; verifying the new URL is the smoke-test purpose.

**ADR-0083 D4 — Rotation procedure pattern.** ADR-0083 specifies that each external-SaaS credential has a per-credential rotation walkthrough at `infrastructure/walkthroughs/{credential-family}-rotation.md`. The Discord rotation walkthrough follows this pattern.

**ADR-0054 D7 — Incident record discipline.** When a leaked webhook URL is used for hostile content, the cascade-handling step records the incident in `generated/incidents/` per ADR-0054 D7. The five-business-day post-mortem cadence applies if a paying tenant was impacted.

**Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** Extends to walkthrough documents per ADR-0084 D8 — webhook URLs are not pasted into `discord-webhook-rotation.md`.

## Constraints
- **No webhook URL values in the walkthrough.** The procedure references URLs by location (Discord webhook config / GitHub org secret slot) but never by concrete value.
- **Smoke-test path is forward-compatible.** The walkthrough references `job-discord-notify.yml` (packet 05) and `discord-notify.ps1` (packet 06). Both land in the same wave; the walkthrough may be authored before they exist (the procedure is correct; the referenced tools land within the wave).
- **Cascade-handling step references real cross-ADR procedures.** ADR-0054 D7 (incident records) and `#audit-sensitive` audit-trail discipline are real, established procedures. Cite them precisely.
- **Strict PR body discipline.** `Authorship: agent`, `Packet: <path>`.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `adr-0084`, `wave-2`

## Agent Handoff

**Objective:** Author `infrastructure/walkthroughs/discord-webhook-rotation.md` as the single canonical procedure for any Discord webhook rotation.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the rotation walkthrough so all seven `sensitive-inventory.md` rows (packet 03) have a real procedure to point at and the operator can rotate a leaked webhook under time pressure without ambiguity.
- Feature: ADR-0084 Discord operator-alerts rollout, Wave 2.
- ADRs: ADR-0084 (D4, D8, D9), ADR-0083 (D4 — rotation-procedure pattern), ADR-0054 (D7 — incident records), Invariant 8 (secret values never in files).

**Acceptance Criteria:** As listed above.

**Dependencies:** packet:02 (the seven webhooks and secrets must exist before the rotation procedure is meaningful).

**Constraints:**
- No webhook URL values in the walkthrough.
- Smoke-test path references `job-discord-notify.yml` (packet 05) and `discord-notify.ps1` (packet 06) — both land in the same wave; forward-compatible authoring is fine.
- Cascade-handling step cites ADR-0054 D7 (incident records) precisely.
- PR body: `Authorship: agent`, `Packet: <path>`.

**Key Files:**
- `infrastructure/walkthroughs/discord-webhook-rotation.md` (NEW)
- `adrs/ADR-0084-discord-operator-alerts-surface.md` (read-only — D4 / D8 / D9 reference)
- `adrs/ADR-0083-external-saas-credential-rotation.md` (read-only — D4 rotation-procedure pattern)
- `adrs/ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md` (read-only — D7 incident-record discipline)

**Contracts:** None changed.
