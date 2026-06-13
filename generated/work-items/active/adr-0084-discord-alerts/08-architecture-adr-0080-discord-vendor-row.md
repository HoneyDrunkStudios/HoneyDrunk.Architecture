---
name: ADR-0080 D2 — Add Discord Vendor Row
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0084", "adr-0080", "wave-3"]
dependencies: ["work-item:00"]
adrs: ["ADR-0084", "ADR-0080"]
wave: 3
initiative: adr-0084-discord-alerts
node: honeydrunk-architecture
source: strategic
generator: scope
---

# Amend ADR-0080 D2 per-vendor table to add the Discord row per ADR-0084 D7

## Summary
Add a Discord row to ADR-0080 D2's per-vendor posture table (the canonical Grid-wide vendor-posture table) per ADR-0084 D7. Discord is assigned **Hedge (active)** with named hedges (webhook-only integration, no bot, content lives in the Grid, the `job-discord-notify.yml` + `discord-notify.ps1` two-seam shape, GitHub org secrets) and a days-scale exit cost (swap to Slack / Mattermost / Matrix / Teams / email-digest by editing the two seams and the seven webhook URLs per emitter).

## Context
ADR-0080 D2's Cascade Impact section explicitly anticipates this amendment: *"ADR-0080 D2 table gains a Discord row per D7 (amendment, not supersession)."* ADR-0084 D7 specifies the row content in full — vendor name, surface, posture, specific hedges in place, estimated exit cost.

This is an amendment (not a supersession) — ADR-0080's existing rows are unchanged, the table gains one new row. The amendment is text-only at the ADR level; no companion `governance/vendor-postures/discord.md` file is created because Hedge postures use the source ADR (ADR-0084) as their document-of-record per ADR-0080 D5 (*"For 'Hedge (active)' and 'Abstract (already portable)' vendors, no separate file is required at this ADR's acceptance. The source ADR is the document of record"*).

This packet's edit is purely additive at ADR-0080. The Cascade Impact section in ADR-0080 itself documents the amendment as expected work; this packet is the execution.

## Scope
- `adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md` — add a Discord row to the D2 per-vendor table. No other text edit.

## Proposed Implementation
1. Open `adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md`. Locate the D2 per-vendor table.
2. Append a new row using ADR-0084 D7's exact column content:

   | Vendor | Surface(s) | Posture | Specific hedges in place | Estimated exit cost |
   |---|---|---|---|---|
   | **Discord** | Operator-alerts surface (ADR-0084) | **Hedge (active)** | Webhook-only integration shape — no bot, no Discord-proprietary feature dependency, no Discord-Modules-equivalent vendor leakage; alert *content* lives in the Grid (inventory files, GitHub Actions logs, incident records); Discord receives a textual *projection* of those sources, never the source of truth; the reusable `job-discord-notify.yml` workflow (D9) is the single Grid-side seam; per-channel webhook URLs in GitHub org secrets are the only configuration | Days. Swap to Slack / Mattermost / Matrix / Teams (or even an email digest, per the candidate-surface document's preservation-grade fallback) by changing the webhook URL per emitter and the post-formatting in `job-discord-notify.yml` |

   The row content is taken verbatim from ADR-0084 D7's table. Match the existing ADR-0080 D2 table's column structure (the columns should be identical — Vendor / Surface(s) / Posture / Specific hedges in place / Estimated exit cost — but verify against the live ADR-0080 D2 at packet-08 execution time and follow the live structure if it has been amended).

3. Below the table (or as a footnote, matching ADR-0080's existing convention for per-row sub-notes), add a brief cross-reference to ADR-0084 D7's "Why Hedge, not Accept, not Abstract" rationale and the re-evaluation triggers (material price change, ToS drift conflicting with build-in-public stance, operator-pattern shift). This narrative is informational and does not change ADR-0080's decisions; it surfaces the Discord-specific re-evaluation context for a future ADR-0080 D4 trigger conversation.

4. No edit to ADR-0080's D-decisions, no edit to other rows in the D2 table, no creation of `governance/vendor-postures/discord.md` (Hedge postures use the source ADR per ADR-0080 D5).

## Affected Files
- `adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md`

## NuGet Dependencies
None. Markdown only.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any other repo.
- [x] ADR edit is governance; no Node contract change.

## Acceptance Criteria
- [ ] ADR-0080 D2's per-vendor table carries a new row for Discord with exact content matching ADR-0084 D7's table row (Vendor: Discord; Surface(s): Operator-alerts surface (ADR-0084); Posture: Hedge (active); specific hedges in place — webhook-only integration, no bot, content lives in Grid, `job-discord-notify.yml` is single seam, per-channel webhook URLs in GitHub org secrets; exit cost: Days)
- [ ] The row appears at the appropriate position in the D2 table — match the table's existing ordering convention (alphabetical / by-posture-grouping / by-acceptance-date — follow ADR-0080's live structure)
- [ ] A brief cross-reference to ADR-0084 D7's "Why Hedge" rationale and re-evaluation triggers appears below the table (or as a footnote per ADR-0080's existing convention)
- [ ] No edit to ADR-0080's D-decisions, no edit to other rows in the D2 table
- [ ] No creation of `governance/vendor-postures/discord.md` — Hedge postures use the source ADR per ADR-0080 D5
- [ ] ADR-0080's status (Accepted) is unchanged; this is an additive amendment

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0084 D7 — Vendor posture: Hedge, with named hedges.** Discord assigned **Hedge (active)**. The amendment is added to ADR-0080 D2's per-vendor table by follow-up packet. Specific hedges in place: webhook-only integration shape (no bot, no Discord-proprietary feature dependency); alert content lives in the Grid (inventory files, GitHub Actions logs, incident records), Discord receives a textual projection; `job-discord-notify.yml` is the single Grid-side seam; per-channel webhook URLs in GitHub org secrets are the only configuration. Estimated exit cost: Days (swap to Slack / Mattermost / Matrix / Teams / email-digest by changing the webhook URL per emitter and the post-formatting in `job-discord-notify.yml`).

**Why Hedge, not Accept, not Abstract** (ADR-0084 D7): Not Accept because Discord is replaceable (value is the rich client and existing operator usage pattern, not any Discord-specific API). Not Abstract because Abstract requires a Grid-defined interface with multiple compatible implementations enforced by canary tests; an `IChatNotifier` abstraction backed by per-vendor implementations is conceivable but premature at v1 (one operator, one chat product).

**Re-evaluation triggers** (ADR-0084 D7): Material price change (Discord's webhook feature is currently free with no documented usage limit; if that changes, posture re-evaluates against Slack / Mattermost / Matrix); ToS drift conflicting with the charter's build-in-public stance; operator-pattern shift (if the operator's daily flow moves away from Discord, the alerting surface follows).

**ADR-0080 D2 — Per-vendor posture table.** The canonical Grid-wide vendor-posture table. This packet appends a Discord row per ADR-0084 D7. ADR-0080's existing decisions are unchanged.

**ADR-0080 D5 — Per-vendor governance file structure.** *"For 'Hedge (active)' and 'Abstract (already portable)' vendors, no separate file is required at this ADR's acceptance. The source ADR is the document of record."* Discord is Hedge; ADR-0084 is the document-of-record; no `governance/vendor-postures/discord.md` is created.

**ADR-0080 D4 — Decision-point triggers.** The re-evaluation triggers from ADR-0080 D4 apply to Discord unchanged; ADR-0084 D7 names the Discord-specific ones to watch.

**ADR-0080 Cascade Impact (Discord row amendment).** *"ADR-0080 D2 table gains a Discord row per D7 (amendment, not supersession)."* This packet is the execution.

## Constraints
- **Append, do not edit existing rows.** ADR-0080's other vendor rows (Azure, GitHub, Cloudflare, Stripe, Anthropic, OpenAI, Resend, Twilio, Expo) are unchanged.
- **Row content is verbatim from ADR-0084 D7.** Do not paraphrase or restructure.
- **Match ADR-0080 D2's live column structure at packet-08 execution time.** If ADR-0080 has been amended in a way that changes the columns, follow the live structure.
- **No `governance/vendor-postures/discord.md` file** — Hedge postures use the source ADR (ADR-0084) per ADR-0080 D5.
- **Strict PR body discipline.** `Authorship: agent`, `Work Item: <path>`.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0084`, `adr-0080`, `wave-3`

## Agent Handoff

**Objective:** Add the Discord row to ADR-0080 D2's per-vendor posture table per ADR-0084 D7.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the vendor-posture amendment so the canonical Grid-wide vendor-posture table reflects the new Discord surface this initiative ships.
- Feature: ADR-0084 Discord operator-alerts rollout, Wave 3.
- ADRs: ADR-0084 (D7 — Discord posture decision), ADR-0080 (D2 per-vendor table, D5 governance-file rules, D4 re-evaluation triggers, Cascade Impact amendment expectation).

**Acceptance Criteria:** As listed above.

**Dependencies:** work-item:00 (ADR-0084 must be Accepted before its D7 row content is committed to ADR-0080).

**Constraints:**
- Append, do not edit existing rows. ADR-0080's other vendor rows are unchanged.
- Row content verbatim from ADR-0084 D7.
- Match ADR-0080 D2's live column structure.
- No `governance/vendor-postures/discord.md` — Hedge postures use the source ADR per ADR-0080 D5.
- PR body: `Authorship: agent`, `Work Item: <path>`.

**Key Files:**
- `adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md`
- `adrs/ADR-0084-discord-operator-alerts-surface.md` (read-only — D7 row content + rationale + re-evaluation triggers)

**Contracts:** None changed.
