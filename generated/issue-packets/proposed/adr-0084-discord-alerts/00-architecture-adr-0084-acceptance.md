---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0084", "wave-1"]
dependencies: []
adrs: ["ADR-0084"]
accepts: ["ADR-0084"]
wave: 1
initiative: adr-0084-discord-alerts
node: honeydrunk-architecture
source: strategic
generator: scope
---

# Accept ADR-0084 — flip status, claim 1 invariant, register the initiative

## Summary
Flip ADR-0084 (Discord as the Canonical Operator-Alerts Surface) from Proposed to Accepted: update the ADR header, add the ADR-0084 row to `adrs/README.md`, claim a 1-invariant reservation in `constitution/invariant-reservations.md`, add the new D11 invariant under that number to `constitution/invariants.md`, and register the `adr-0084-discord-alerts` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0084 commits Discord as the **single canonical operator-alerts surface** for the Grid — the real-time, day-to-day operational pager surface for the solo operator across CI failures, security signals, agent activity, release events, hive-sync drift, and credential-rotation escalations. Eight bound sub-decisions: role and scope (D1), six operator-alerts channels + one audit channel (D2), webhook-per-channel strategy (D3), GitHub-org-secret storage (D4), an inventoried alert-source roster (D5), the alert-routing table (D6), the Hedge vendor posture (D7), the privacy/signal-hygiene rules (D8), the `job-discord-notify.yml` implementation seam (D9), the new-source onboarding hook (D10), and the new invariant (D11) binding the discipline.

The forcing function is **ADR-0083 D5's T-30 / T-7 / T+0 credential-rotation escalation cadence** — Discord channels and webhooks must exist before that procedure has anywhere to publish to. ADR-0083 D3 picked GitHub issues as the canonical **tracking** surface (because closed issues are an audit trail and AI agents can walk them) but explicitly named chat-webhook (Discord specifically) as the right **alerting** surface; this ADR closes the gap.

The ADR's Affected Nodes section is explicit: `HoneyDrunk.Vault.Rotation`, `HoneyDrunk.Communications`, `HoneyDrunk.Notify`, `HoneyDrunk.Pulse`, `HoneyDrunk.Observe`, `HoneyDrunk.Audit` are all **unchanged at runtime**. The work surface is Architecture (governance, constitution, infrastructure reference, helper script) and Actions (the reusable workflow + phased emitter retrofits). No application code in any Core / Ops / AI / Service Node changes.

This is a docs/governance-only packet. No code, no workflow, no .NET project. The concrete artifacts — `constitution/alert-routing.md`, the Discord portal provisioning, the seven external-credential rows, the rotation walkthrough, the reusable workflow, the home-server helper, the standup-procedure amendment, the ADR-0080 D2 amendment, the Notify-runbook cross-link, the four phased emitter-wiring rollouts — land in packets 01–13. Every other packet in this initiative references ADR-0084's D-decisions as live rules, so the acceptance flip must land first.

## Scope
- `adrs/ADR-0084-discord-operator-alerts-surface.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — add or update the ADR-0084 row in the index table. If a row already exists, update its Status column to Accepted. If no row exists, append one in the existing six-column table format (`| ADR-XXXX | Title | Status | Date | Sector | Impact |`), citing the ADR's Sector (`Ops / Meta / cross-cutting`), Date (`2026-05-25`), and a one-sentence impact summary.
- `constitution/invariants.md` — add one new invariant (see Proposed Implementation for exact text), numbered **{N1}** per the reservation claimed in `constitution/invariant-reservations.md`.
- `constitution/invariant-reservations.md` — claim the next free block of size 1 above the highest existing reservation; add an `Active Reservations` row for ADR-0084 with the placeholder number.
- `initiatives/active-initiatives.md` — register the `adr-0084-discord-alerts` initiative with the wave structure and packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0084 header: `**Status:** Proposed` → `**Status:** Accepted`. No other D-decision text edit in this packet.
2. Update the ADR-0084 index row in `adrs/README.md`. Append a new row in the existing six-column format with `Status: Accepted` for ADR-0084. Match the existing row format exactly; do not invent columns. Use the ADR's title verbatim from its header: "Discord as the Canonical Operator-Alerts Surface."
3. **Claim the invariant-number block.** Open `constitution/invariant-reservations.md`. Read the `Active Reservations` table and find the highest reservation already claimed. As of authoring, the highest sibling reservation is ADR-0080 at 99–101, making the next free number **102**. Pick the next contiguous block of size 1 above the current ceiling — this becomes `{N1}` for this packet. Add a row to the `Active Reservations` table with `Range | ADR-0084 | Proposed → Accepted | <one-line description and (N1) summary; packet 00 path>` matching the format of sibling rows. "First merge wins" applies — if another ADR packet-00 races, the second author shifts upward by editing this file plus the `{N1}` placeholder in this packet body and in `constitution/invariants.md`.
4. Add one new invariant to `constitution/invariants.md`, numbered **{N1}** per step 3. The text, taken verbatim-in-substance from ADR-0084 D11:

   > **{N1} — Every operator-actionable Grid event that the operator must see in real time** — CI failure on `main`, deploy event, NuGet publish, scheduled-workflow failure, credential-rotation escalation, agent verdict, hive-sync drift, security alert, budget threshold, internal-Grid error spike — **must publish to Discord via `HoneyDrunk.Actions/.github/workflows/job-discord-notify.yml`** (for GitHub-Actions-hosted emitters) **or via the equivalent `infrastructure/scripts/discord-notify.*` helper** (for emitters hosted on the home server per ADR-0081). The destination channel and severity must match an entry on the alert-routing table in `constitution/alert-routing.md` (or, until that file lands, ADR-0084 D6). **No Discord channel may receive secret values, customer PII, or full stack traces** (Invariant 8 extended to webhook payloads per ADR-0084 D8). Ad-hoc `curl` to a Discord webhook URL outside the reusable workflow / helper script is forbidden — the reusable-workflow boundary is what allows redaction, formatting consistency, and vendor-posture swap per ADR-0080 D2.
   >
   > Enforcement: human review at PR time, supplemented by the `review` agent per ADR-0044 D3 categories 9 (Security — Secret handling) and 14 (Distributed systems — Observability / Notification discipline). The `hive-sync` agent surfaces emitters firing into Discord without a corresponding alert-routing-table entry.
   >
   > Complements (does not replace) Invariant 8 — the secret-redaction discipline that pre-existed and that this invariant explicitly extends to webhook payloads.

   Create a new `## Operator Alerts Invariants` section. The file's existing sectioning groups invariants by topic (Dependency / Context / Secrets / Packaging / Testing / Infrastructure & Configuration / Work Tracking / AI / Code Review / Hosting Platform / Hive Sync / Multi-Tenant Boundary / Communications / Audit / Vendor Posture). Operator alerts is a new cross-cutting topic; place the new section after `## Vendor Posture Invariants` (or after the existing tail section, whichever is structurally last).
5. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder. Match the format used by ADR-0080, ADR-0077, ADR-0045, ADR-0042, and other sibling ADR-acceptance initiative entries.

## Affected Files
- `adrs/ADR-0084-discord-operator-alerts-surface.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency — operator-alert surface is a governance concern; no contract cascade.

## Acceptance Criteria
- [ ] ADR-0084 header reads `**Status:** Accepted`
- [ ] An ADR-0084 row exists in `adrs/README.md` with Status `Accepted`, Date `2026-05-25`, Sector `Ops / Meta / cross-cutting`, title `Discord as the Canonical Operator-Alerts Surface`, and a one-sentence impact summary in the existing six-column row format
- [ ] `constitution/invariant-reservations.md` carries an `Active Reservations` row claiming a contiguous block of size 1 for ADR-0084 above the highest existing reservation, with the `(N1)` summary and the packet 00 path
- [ ] `constitution/invariants.md` carries the new operator-alerts invariant (every operator-actionable event publishes via `job-discord-notify.yml` or the home-server helper; no secret values, customer PII, or full stack traces in any channel; ad-hoc `curl` forbidden) numbered with the `{N1}` block claimed in `invariant-reservations.md`, under a new `## Operator Alerts Invariants` section, citing ADR-0084
- [ ] The new invariant text complements (does not replace) Invariant 8 — the relationship is named, not implied
- [ ] `initiatives/active-initiatives.md` registers the `adr-0084-discord-alerts` initiative with a packet checklist matching the structure used by sibling initiative entries (ADR-0080, ADR-0077, ADR-0045)
- [ ] No catalog schema change in this packet (no `catalogs/contracts.json`, `catalogs/grid-health.json`, `catalogs/relationships.json`, or `catalogs/nodes.json` edit — see dispatch plan §"Why no catalog packet")
- [ ] No `constitution/alert-routing.md` creation in this packet (that lands in packet 01)
- [ ] No Discord channel creation, webhook provisioning, or GitHub org-secret seeding in this packet (that lands in packet 02 as `Actor=Human`)
- [ ] No edits to ADR-0080 in this packet (Discord row amendment lands in packet 08)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0084 D1 — Role and scope.** Discord is the canonical operator-alerts surface, nothing more. Discord IS: real-time operational pager, visible-by-default shared timeline, read-mostly surface. Discord is NOT: a Communications concern (ADR-0019 boundary — operator alerts have no preferences, no cadence, no tenant scope, no lifecycle workflows; fail every Communications boundary test), a Notify concern (ADR-0073 — operator alerts are not email/SMS/push and consumers are not users with preferences), a Notify Cloud concern (PDR-0002 — multi-tenant commercial path, operator is internal), customer-facing community management (the PDR-0002 §G Notify Cloud public Discord is a separate surface in different channels behind community-role permissions), or the home-server's job (ADR-0081 native desktop notifications are complementary, not substitutes — Discord is mobile-and-desktop, anywhere-the-operator-is).

**ADR-0084 D2 — Seven-channel taxonomy.** `#ops-alerts` (CI failures, deploy events, scheduled-workflow failures, credential-rotation escalations); `#security-alerts` (Dependabot/SonarCloud/CodeRabbit/CodeQL flagged issues, secret-scan hits, ADR-0056 security-review surfaces, GitHub Advanced Security alerts); `#agent-activity` (ADR-0044 Grid Review verdicts, ADR-0046 specialist invocations, ADR-0079 Codex/Claude/CodeRabbit/Copilot reviewer activity, OpenClaw session boundaries); `#hive-activity` (issue board state changes per ADR-0014, PRs opened/merged/closed, hive-sync drift findings, packet lifecycle transitions); `#release` (NuGet publishes per ADR-0034, version tag events, ADR-0033 deploy successes/failures across dev/staging/prod, release-notes generation per ADR-0012); `#announcements` (operator-authored summaries; v1 operator-only, eventual community-facing); `#audit-sensitive` (credential expiry dates not values, Vault rotation events, ADR-0030 audit anomalies, ADR-0049 Internal/Confidential classifications — private channel with restricted webhook; sensitive-by-permission not sensitive-by-payload — Invariant 8 still applies).

**ADR-0084 D3 — Webhook strategy.** Native Discord incoming webhooks, one per channel, no bot bridge, no fan-out worker. Webhooks are dead-simple HTTP POST endpoints with no state, no process to maintain, no auth model beyond the secret URL itself. Matches the ADR-0080 Hedge posture (D7) because swapping to Slack / Mattermost / Matrix / Teams is a webhook-URL change per emitter, not a rebuild of the routing layer.

**ADR-0084 D4 — Webhook URL storage.** Each channel's webhook URL is a GitHub organization-level secret with naming pattern `DISCORD_WEBHOOK_{CHANNEL_UPPER_SNAKE}`. Seven secrets total: `DISCORD_WEBHOOK_OPS_ALERTS`, `DISCORD_WEBHOOK_SECURITY_ALERTS`, `DISCORD_WEBHOOK_AGENT_ACTIVITY`, `DISCORD_WEBHOOK_HIVE_ACTIVITY`, `DISCORD_WEBHOOK_RELEASE`, `DISCORD_WEBHOOK_ANNOUNCEMENTS`, `DISCORD_WEBHOOK_AUDIT_SENSITIVE`. The `#audit-sensitive` webhook is not exposed to public-repo workflows by default. Each Discord webhook URL is an external-SaaS credential per ADR-0083 D1's CI/ops-machinery category; lands in `infrastructure/reference/sensitive-inventory.md` as seven inventory rows. Discord webhook URLs have no provider-imposed expiration; cadence `n/a — non-expiring (rotate on suspected compromise only)`.

**ADR-0084 D5 — Alert sources.** A defined roster, not a free-for-all. New emitters require an entry on the roster before they may consume a webhook secret. Sources at v1: GitHub Actions CI failure on `main`, deploy events per ADR-0033, NuGet publishes per ADR-0034, scheduled-workflow failures (nightly-deps, nightly-security, hive-field-mirror, weekly-governance, external-credentials-check, grid-health aggregator), ADR-0083 credential-rotation escalation, ADR-0044 review pipeline, ADR-0046 specialist invocations, ADR-0014 hive-sync findings, GitHub PR opened/merged, GitHub Dependabot/CodeQL/secret-scanning, SonarCloud quality-gate failures, CodeRabbit P0/P1 findings, Azure budget alerts per ADR-0052, App Insights error/failure-rate alerts per ADR-0040/0045, operator-authored announcements. Deliberately not on the list: Pulse telemetry firehose (invariant 47 — audit/telemetry distinct from Discord), audit log tail (ADR-0030 — durable, attributable, query via `IAuditQuery`; only rare anomalies post to `#audit-sensitive`), customer-facing notifications (D1 — owned by Communications/Notify/Notify Cloud).

**ADR-0084 D6 — Alert-routing table.** Pins v1 routing for every source. Severity advisory at v1, not enforced (Info / Medium / High / Critical for glance-level disposition and future filtering hook). Tenant-facing incident pages (ADR-0054 D4) continue via Notify + PagerDuty; Discord may receive a mirror but is not a substitute for the PagerDuty escalation path for paying-tenant SEV-1/SEV-2. Lives canonically in `constitution/alert-routing.md` (packet 01); the ADR is the committed shape, `alert-routing.md` is the operational reference copy, hive-sync diffs the two.

**ADR-0084 D7 — Vendor posture.** Discord assigned **Hedge (active)** per ADR-0080's three-posture taxonomy. Webhook-only integration, no bot, no Discord-proprietary feature dependency; alert content lives in the Grid (inventory files, GitHub Actions logs, incident records), Discord receives a textual projection; `job-discord-notify.yml` is the single Grid-side seam; per-channel webhook URLs in GitHub org secrets are the only configuration. Estimated exit cost: days (swap to Slack / Mattermost / Matrix / Teams or email-digest fallback by changing the webhook URL per emitter and the post-formatting in `job-discord-notify.yml`). Not Accept (replaceable, value is the rich client and existing operator usage pattern, not any Discord-specific API). Not Abstract (Abstract requires a Grid-defined interface with multiple compatible implementations enforced by canary tests; building an `IChatNotifier` abstraction is premature at v1 — one operator, one chat product). Re-evaluation triggers per ADR-0080 D4 apply unchanged; Discord-specific ones: material price change, ToS drift conflicting with build-in-public stance, operator-pattern shift.

**ADR-0084 D8 — Privacy and signal-hygiene rules.** Non-negotiable at the alert-payload level, enforced by the same secret-redaction discipline as logs (Invariant 8 and ADR-0049): no secret values, no customer PII, no full stack traces, no customer-bound content from Notify Cloud, volume bounding (50 messages/day per source — sources projected above that require a per-source severity floor and/or duplicate-suppression rule), channel-appropriate posting (sources route to one channel per the table; cross-posting only when the table specifies). v2 considerations deferred: role-mentions per severity, duplicate-suppression / fingerprint dedup parallel to ADR-0054 D5's 1-hour window, threaded follow-ups.

**ADR-0084 D9 — Implementation seam.** Single reusable workflow `HoneyDrunk.Actions/.github/workflows/job-discord-notify.yml` per ADR-0012 reusable-workflow pattern. Inputs: `channel`, `severity`, `title`, `body` (optional), `link` (optional), `metadata` (optional JSON). Handles message formatting consistently across emitters, applies D8 redaction at the formatting boundary (pre-check rejects messages matching common secret patterns — same discipline as `VaultTelemetry`), POSTs to the correct webhook URL. Every CI emitter routes through this workflow; ad-hoc `curl` is forbidden per D11. For emitters outside GitHub Actions (home-server-hosted ADR-0044 bridge, scheduled local automations per ADR-0081), a small shared helper script lives in `HoneyDrunk.Architecture/infrastructure/scripts/discord-notify.ps1` and reads webhook URLs from local secret storage per ADR-0081 D5's machine-secret discipline.

**ADR-0084 D10 — Onboarding hook.** New alert sources require: (1) a row on D6's routing table (or its `alert-routing.md` successor), (2) the specific `channel` and `severity` inputs to `job-discord-notify.yml`, (3) a volume estimate and, if above 50/day, an explicit suppression rule per D8. Attaches to the ADR-0082 procedure document `constitution/node-standup.md`: any Node standup that introduces a new operational event surface gains a step parallel to ADR-0083 D6's external-credential-onboarding step.

**ADR-0084 D11 — New invariant.** Every operator-actionable Grid event must publish to Discord via `job-discord-notify.yml` (GitHub-Actions emitters) or `discord-notify.*` helper (home-server emitters). Destination channel and severity must match an entry on `constitution/alert-routing.md`. No Discord channel may receive secret values, customer PII, or full stack traces. Ad-hoc `curl` to a Discord webhook URL outside the reusable workflow / helper script is forbidden. Enforcement: human review at PR time + the ADR-0044 `review` agent (categories 9 and 14) + hive-sync surfacing emitters firing without a routing-table entry. Number assigned at acceptance by claiming the next free block in `constitution/invariant-reservations.md`. Complements (does not replace) Invariant 8.

## Constraints
- **Acceptance precedes flip.** ADR-0084 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant number `{N1}` — claim via the reservation registry.** Do not hardcode the invariant number in this packet. Read `constitution/invariant-reservations.md`, pick the next contiguous block of size 1 above the current ceiling, add the `Active Reservations` row in the same PR that writes this packet, and substitute the chosen number for the `{N1}` placeholder throughout this packet body and in `constitution/invariants.md`. "First merge wins" applies — if two ADR packet-00s race, the second author shifts upward by editing the registry plus every placeholder before pushing. Never reuse a number already claimed by another sibling reservation (today: ADR-0051 54–57; ADR-0049 58–60; ADR-0054 61–63; ADR-0060 64–66; ADR-0050 67–68; ADR-0063 69–73; ADR-0064 74–77; ADR-0065 78–79; ADR-0066 80–82; ADR-0068 83–86; ADR-0071 87–89; ADR-0077 90–92; ADR-0078 93–94; ADR-0079 95–98; ADR-0080 99–101).
- **New section.** The new invariant is a new cross-cutting topic; create an `## Operator Alerts Invariants` section after the existing tail section rather than appending to an unrelated section.
- **Invariant text names its upstream relationship explicitly.** The text must state that it **complements (does not replace) Invariant 8** — the connection is structural (extension of secret-redaction discipline to webhook payloads), not displacement. The existing Invariant 8 text is not modified; `{N1}` is additive.
- **No alert-routing.md creation, no Discord portal action, no infrastructure/ file creation, no ADR-0080 edit in this packet.** Those land in subsequent packets per the dispatch plan. This packet is the governance/invariants flip only.
- **Match the existing `adrs/README.md` row format.** Six-column markdown table (`| ID | Title | Status | Date | Sector | Impact |`). Append the ADR-0084 row in that format. Do not invent columns.
- **Strict PR body discipline.** PR body must carry `Authorship: <enum>` and exactly one of `Packet:` / `Out-of-band reason:` — free-form text breaks pr-core checks. Use `Authorship: agent` (this packet is fully agent-authorable) and `Packet: generated/issue-packets/proposed/adr-0084-discord-alerts/00-architecture-adr-0084-acceptance.md` (or its `active/` path once promoted).

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0084`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0084 to Accepted, claim 1 invariant in the reservation registry, add the D11 invariant to `constitution/invariants.md`, and register the discord-alerts initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0084 so packets 01–13 can reference its decisions as live rules and start shipping the operator-alerts substrate.
- Feature: ADR-0084 Discord operator-alerts rollout, Wave 1.
- ADRs: ADR-0084 (primary), Invariant 8 (referenced by the new invariant — complement, not replace), ADR-0008 (initiative/packet conventions), ADR-0014 (ADR-acceptance reconciliation pattern that `hive-sync` follows), ADR-0080 (vendor posture taxonomy this ADR's D7 lands inside), ADR-0083 (forcing function; coupling narrated, no `dependencies:` entries).

**Acceptance Criteria:** As listed above.

**Dependencies:** None — Wave 1 governance flip.

**Constraints:**
- Acceptance precedes flip — ADR-0084 stays Proposed until this PR merges.
- Claim the invariant number via `constitution/invariant-reservations.md` — read the registry, pick the next contiguous block of size 1 above the current ceiling, add the row, substitute `{N1}` throughout the packet body and in `constitution/invariants.md`. Do not renumber existing invariants; create a new `## Operator Alerts Invariants` section after the tail section.
- The new invariant text states that it **complements (does not replace) Invariant 8** — structural extension of secret-redaction discipline to webhook payloads, not displacement.
- No alert-routing.md creation, no Discord portal action, no infrastructure/ file creation, no ADR-0080 edit in this packet.
- Match the existing `adrs/README.md` six-column row format when appending the ADR-0084 row.
- PR body must carry `Authorship: <enum>` and `Packet: <path>` — no free-form text in the metadata fields.

**Key Files:**
- `adrs/ADR-0084-discord-operator-alerts-surface.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
