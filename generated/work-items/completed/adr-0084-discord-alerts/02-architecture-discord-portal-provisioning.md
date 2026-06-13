---
name: Discord Portal Provisioning
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "ops", "adr-0084", "wave-2", "human-only"]
dependencies: ["work-item:00"]
adrs: ["ADR-0084"]
wave: 2
initiative: adr-0084-discord-alerts
node: honeydrunk-architecture
source: strategic
generator: scope
---

# Provision seven Discord channels + webhooks + seed seven GitHub org secrets

## Summary
Create the seven operator-alerts channels in the existing HoneyDrunk Discord server, provision an incoming webhook per channel via Server Settings → Integrations → Webhooks, and seed each webhook URL as a GitHub organization-level secret under the `DISCORD_WEBHOOK_{CHANNEL_UPPER_SNAKE}` naming pattern.

## Context
ADR-0084 D2 commits seven channels and D4 commits seven org secrets. None of this work can be delegated — it is portal-click work against vendor surfaces (Discord and GitHub) the agent has no API path into. Until this packet completes, every downstream packet in Wave 2 is blocked: packet 03 (external-credentials inventory rows) describes real webhooks, not placeholders; packet 04 (rotation walkthrough) needs concrete URLs and secret names to document the procedure against; packet 05 (`job-discord-notify.yml`) cannot run its smoke tests without real webhooks; packet 06 (home-server helper) needs at minimum the secret-name convention to read from local secret storage; and the entire Wave 4 emitter rollout (packets 10–13) consumes the secrets.

The seven channels are pre-named by ADR-0084 D2 (`#ops-alerts`, `#security-alerts`, `#agent-activity`, `#hive-activity`, `#release`, `#announcements`, `#audit-sensitive`). The seven secrets are pre-named by ADR-0084 D4 (`DISCORD_WEBHOOK_OPS_ALERTS`, `DISCORD_WEBHOOK_SECURITY_ALERTS`, `DISCORD_WEBHOOK_AGENT_ACTIVITY`, `DISCORD_WEBHOOK_HIVE_ACTIVITY`, `DISCORD_WEBHOOK_RELEASE`, `DISCORD_WEBHOOK_ANNOUNCEMENTS`, `DISCORD_WEBHOOK_AUDIT_SENSITIVE`). The `#audit-sensitive` channel is the only one of the seven that warrants more careful access scoping — private-by-permission via Discord role-gating, and its org secret is **not** exposed to public-repo workflows by default (consumed only by Architecture / Vault / Audit / private repos).

Per ADR-0082's standup-procedure secret-block listing (lines 217–223), these seven secrets are now part of the canonical conditional-secret block any Node whose workflows emit operator-actionable events depends on. ADR-0084 acceptance is the trigger that makes the secret block real.

## Scope
This packet is **human-only**. The agent contributes nothing to the work itself; it exists as a tracked work item so the dependency wiring (packets 03 / 04 / 05 / 06 → packet 02) is captured in the filing pipeline.

### Discord portal actions
- Create seven channels in the existing HoneyDrunk Discord server (lowercase-with-hyphens per Discord convention):
  - `#ops-alerts`
  - `#security-alerts`
  - `#agent-activity`
  - `#hive-activity`
  - `#release`
  - `#announcements`
  - `#audit-sensitive` (set as private channel; restrict to operator-only role)
- For each channel, create an incoming webhook (Server Settings → Integrations → Webhooks → New Webhook). Use the channel name as the webhook name (e.g., `webhook-ops-alerts`). Copy each webhook URL.

### GitHub organization secrets
- Seed each webhook URL as a GitHub organization-level secret in `HoneyDrunkStudios` org (Settings → Secrets and variables → Actions → New organization secret):
  - `DISCORD_WEBHOOK_OPS_ALERTS`
  - `DISCORD_WEBHOOK_SECURITY_ALERTS`
  - `DISCORD_WEBHOOK_AGENT_ACTIVITY`
  - `DISCORD_WEBHOOK_HIVE_ACTIVITY`
  - `DISCORD_WEBHOOK_RELEASE`
  - `DISCORD_WEBHOOK_ANNOUNCEMENTS`
  - `DISCORD_WEBHOOK_AUDIT_SENSITIVE`
- For six of the seven (all except `DISCORD_WEBHOOK_AUDIT_SENSITIVE`), set `Repository access: All repositories` (or `Selected repositories` matching the Grid's existing org-secret convention if `All repositories` is too broad — operator's judgment).
- For `DISCORD_WEBHOOK_AUDIT_SENSITIVE`, set `Repository access: Selected repositories` and select only: `HoneyDrunk.Architecture`, `HoneyDrunk.Vault`, `HoneyDrunk.Audit`, and any other private repos as the operator deems appropriate. Per ADR-0084 D4: *"is also a GitHub org secret but is not exposed to public-repo workflows by default (consumed only by Architecture / Vault / Audit / private repos)."*

### No file changes
This packet creates no commits, no files, no PRs. It is a tracked work item closed manually by the operator once the portal work is complete.

## Acceptance Criteria
- [ ] Seven channels exist in the HoneyDrunk Discord server with exact names: `#ops-alerts`, `#security-alerts`, `#agent-activity`, `#hive-activity`, `#release`, `#announcements`, `#audit-sensitive`
- [ ] `#audit-sensitive` is configured as a private channel with operator-only role permissions
- [ ] Seven incoming webhooks exist (one per channel) — each tested by a manual POST from the operator's machine confirming a payload lands in the correct channel
- [ ] Seven GitHub organization secrets exist in `HoneyDrunkStudios` org under the exact names: `DISCORD_WEBHOOK_OPS_ALERTS`, `DISCORD_WEBHOOK_SECURITY_ALERTS`, `DISCORD_WEBHOOK_AGENT_ACTIVITY`, `DISCORD_WEBHOOK_HIVE_ACTIVITY`, `DISCORD_WEBHOOK_RELEASE`, `DISCORD_WEBHOOK_ANNOUNCEMENTS`, `DISCORD_WEBHOOK_AUDIT_SENSITIVE`
- [ ] Six of the seven secrets (all except `DISCORD_WEBHOOK_AUDIT_SENSITIVE`) carry the org-wide access policy matching the existing Grid convention for org secrets used by all repos
- [ ] `DISCORD_WEBHOOK_AUDIT_SENSITIVE` carries `Repository access: Selected repositories` with the selected list scoped to Architecture / Vault / Audit / other private repos per operator judgment — never exposed to public-repo workflows
- [ ] Webhook URLs are not pasted into any commit, comment, issue, or chat message — only into the GitHub org-secret form

## Human Prerequisites
- [ ] Operator has Manage Server permission on the HoneyDrunk Discord server (needed to create channels and webhooks)
- [ ] Operator has Owner or Admin role on the HoneyDrunkStudios GitHub org (needed to create organization-level secrets)
- [ ] Operator has access to a private notes surface to track the seven webhook URLs during transit from Discord → GitHub (the URLs themselves are secret values per ADR-0084 D8 / Invariant 8; do not log, paste, or commit them)
- [ ] After completing the work, close this packet's filed issue manually with a comment summarizing what was done — do NOT include any webhook URL or secret value in the close comment
- [ ] After this packet closes, manually unblock downstream packets (03 / 04 / 05 / 06) via the GitHub blocked-by UI if the file-work-items pipeline did not automatically resolve the edges

## Referenced ADR Decisions
**ADR-0084 D2 — Channel taxonomy.** Six operator-alerts channels plus one private audit channel. Names: `#ops-alerts`, `#security-alerts`, `#agent-activity`, `#hive-activity`, `#release`, `#announcements`, `#audit-sensitive`. Discord naming convention: lowercase-with-hyphens. `#audit-sensitive` is private-by-permission (Discord channel-role-gated).

**ADR-0084 D3 — Webhook strategy.** Native Discord incoming webhooks, one per channel, no bot bridge. Dead-simple HTTP POST endpoints with no state, no process to maintain, no auth model beyond the secret URL itself.

**ADR-0084 D4 — Webhook URL storage.** GitHub organization-level secrets with naming pattern `DISCORD_WEBHOOK_{CHANNEL_UPPER_SNAKE}`. The `#audit-sensitive` webhook is the only one of the seven that warrants more careful access scoping; it is also a GitHub org secret but is **not** exposed to public-repo workflows by default (consumed only by Architecture / Vault / Audit / private repos).

**ADR-0084 D8 — Privacy and signal-hygiene rules.** Webhook URLs are secret values per Invariant 8. They never appear in logs, traces, exceptions, telemetry, commits, comments, or chat messages. Treat them with the same discipline as API keys.

**Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** Only secret names/identifiers may be traced. This extends to webhook URLs per ADR-0084 D8.

**ADR-0082 standup-procedure secret block (lines 217–223).** These seven secrets are now part of the canonical conditional-secret block any Node whose workflows emit operator-actionable events depends on. ADR-0084 acceptance + this packet's provisioning makes the secret block real for the Grid.

## Constraints
- **Webhook URLs are secret values.** Never paste them into commits, comments, issue bodies, or chat. The only acceptable destination is the GitHub org-secret form.
- **`#audit-sensitive` is private.** Both at the Discord channel-permission level and at the GitHub org-secret repository-access level. Do not expose to public-repo workflows.
- **Channel and secret names are exact.** Do not abbreviate, pluralize, hyphenate differently, or otherwise drift. Every downstream packet uses these exact names; a typo here cascades.
- **No commit produced by this packet.** This is a portal-only work item. The agent who runs this packet (a human) closes it with a manual GitHub-issue close, not a PR merge.

## Labels
`chore`, `tier-2`, `meta`, `ops`, `adr-0084`, `wave-2`, `human-only`

## Agent Handoff

**Objective:** Provision the seven Discord operator-alerts channels, webhooks, and corresponding GitHub org secrets. **`Actor=Human`** — this packet has no agent-doable surface.

**Target:** `HoneyDrunk.Architecture` (issue tracking only; no commit produced).

**Context:**
- Goal: Make the seven Discord channels and webhook URLs real so downstream packets in Wave 2 and Wave 4 have concrete substrate to reference.
- Feature: ADR-0084 Discord operator-alerts rollout, Wave 2 — the human-only gate.
- ADRs: ADR-0084 (D2, D3, D4, D8), Invariant 8 (webhook URLs are secrets), ADR-0082 (these seven secrets are now part of the canonical conditional standup-secret block).

**Acceptance Criteria:** As listed above.

**Dependencies:** work-item:00 (ADR-0084 must be Accepted before the seven channels are created — channel creation references decisions that are committed only at acceptance; provisioning against a Proposed ADR is premature).

**Constraints:** As listed above. No code, no commit, no PR. Webhook URLs are secret values per Invariant 8.

**Key Files:** None — portal work only.

**Contracts:** None changed.
