---
name: Alert Routing Table
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0084", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0084"]
wave: 2
initiative: adr-0084-discord-alerts
node: honeydrunk-architecture
source: strategic
generator: scope
---

# Ship constitution/alert-routing.md seeded from ADR-0084 D6, plus the hive-sync drift check

## Summary
Create `constitution/alert-routing.md` as the canonical, operational alert-routing reference seeded verbatim from ADR-0084 D6's table. Add a hive-sync drift check that diffs this file against ADR-0084 D6 and reports any divergence as a finding routed to `#hive-activity` (the same treatment ADR-0054 D4's routing-table receives).

## Context
ADR-0084 D6 pins the v1 alert-routing table inside the ADR itself as the committed shape. The ADR explicitly states: *"the operational reference copy lives at `constitution/alert-routing.md` (new file, landed by follow-up work) and stays in sync via a `hive-sync` check that diffs the two (parallel to ADR-0054 D4's table treatment)."* This packet ships that file plus the drift check.

Two reasons the operational copy and the ADR copy coexist: (1) emitters / agents reference `constitution/alert-routing.md` as the live operational document — citing an ADR section from code or workflow is friction-inducing, and ADRs are append-only-by-discipline; (2) D10's onboarding hook explicitly says new sources are added to `constitution/alert-routing.md` once it exists, not to the ADR by amendment. The ADR-copy stays as the committed-shape snapshot; the constitution copy is the live working surface.

ADR-0084 D6 has 24 routing rows covering: CI failure on `main`, deploy success/failure, NuGet publish success/failure, scheduled-workflow failure, credential-rotation escalation at three cadence points (T-30 / T-7 / T+0), ADR-0044 review verdict, ADR-0046 specialist invocation, ADR-0014 hive-sync drift, packet lifecycle transition, PR opened, PR merged, Dependabot/CodeQL High+, secret-scanning hit, SonarCloud quality-gate failure, CodeRabbit P0/P1, three Azure budget thresholds (50/75/90+100), App Insights internal-Grid error spike, Grid Health aggregator drift, and operator-authored announcement. Each row carries event source, destination channel(s), severity, and format hint.

## Scope
- `constitution/alert-routing.md` — new file. Seeded from ADR-0084 D6's table verbatim, plus a preamble explaining the file's role and the ADR-0084 cross-reference, plus a "How to add a new alert source" section that mirrors ADR-0084 D10's onboarding-hook requirements.
- `.claude/agents/hive-sync.md` (or equivalent agent definition file) — add a drift-check step that diffs `constitution/alert-routing.md` against ADR-0084 D6's table and emits a finding to `#hive-activity` on divergence. If the agent definition file's exact location differs, add the check at the same logical insertion point as the existing ADR-0054 D4 routing-table drift check.

## Proposed Implementation
1. Create `constitution/alert-routing.md` with three sections:
   - **Preamble** — explains that this is the operational copy of ADR-0084 D6's routing table, why it exists separately from the ADR (live working surface vs committed-shape snapshot), the hive-sync drift check that keeps it in sync, and the pointer to ADR-0084 as the governing decision.
   - **Routing table** — the full 24-row table from ADR-0084 D6, verbatim in structure (columns: `Event source | Destination channel | Severity | Format hint`). Maintain emoji prefixes and link placeholders exactly as ADR-0084 D6 specifies them (e.g., `❌ {repo} / {workflow}: {commit-short} — {link-to-run}`).
   - **How to add a new alert source** — mirrors ADR-0084 D10's onboarding hook: (1) add a row to this table, (2) pass `channel` and `severity` inputs through `job-discord-notify.yml`, (3) if projected volume exceeds 50 messages/day, declare a suppression rule per ADR-0084 D8. Cross-link the `constitution/node-standup.md` step ADR-0084 D10 amends (which lands in packet 07).
2. Add the hive-sync drift check. Locate the existing ADR-0054 D4 routing-table drift check in the hive-sync agent definition (likely `.claude/agents/hive-sync.md` or a runbook inside `OpenClaw/` per ADR-0081). Add a parallel check for ADR-0084 D6 vs `constitution/alert-routing.md`. The check should:
   - Parse the table rows from both sources (the markdown table in the ADR's D6 section + the table in `constitution/alert-routing.md`).
   - Report any row that exists in one and not the other, or any row whose columns differ.
   - Emit findings to `#hive-activity` via `job-discord-notify.yml` (which lands in packet 05; until that lands, the drift check may log to the existing hive-sync output surface and gain the Discord post once the workflow exists).
3. Per ADR-0084 D10, the operational reference is the file edited by future onboarding packets, not the ADR. Document this explicitly in the file's preamble so a future scope agent does not edit the ADR's D6 table by mistake.

## Affected Files
- `constitution/alert-routing.md` (NEW)
- `.claude/agents/hive-sync.md` (or the equivalent hive-sync agent definition file; locate at packet authoring time)

## NuGet Dependencies
None. Markdown + agent-prompt edits only.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any other repo.
- [x] hive-sync agent definition lives in this repo per ADR-0014.

## Acceptance Criteria
- [ ] `constitution/alert-routing.md` exists, contains all 24 routing rows from ADR-0084 D6 verbatim in column structure (`Event source | Destination channel | Severity | Format hint`), and carries the emoji prefixes and link placeholders exactly as ADR-0084 D6 specifies
- [ ] The file's preamble explains: (a) it is the operational copy of ADR-0084 D6, (b) hive-sync diffs the two and reports drift, (c) ADR-0084 is the governing decision, (d) future onboarding packets edit this file, not the ADR
- [ ] The file's "How to add a new alert source" section mirrors ADR-0084 D10's three-step requirement (row addition, `channel`+`severity` wiring, volume estimate with optional suppression rule above 50/day)
- [ ] The hive-sync agent definition gains a drift check that parses the table rows from both sources and reports any divergence to `#hive-activity` (initially via existing hive-sync output surface; gains Discord post via `job-discord-notify.yml` once packet 05 lands — note this as a TODO in the agent prompt, not a missing implementation)
- [ ] The drift check sits next to the existing ADR-0054 D4 routing-table drift check in the agent definition (same insertion point, same structure)
- [ ] No edit to `adrs/ADR-0084-discord-operator-alerts-surface.md` D6 table — the ADR copy stays as the committed-shape snapshot

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0084 D6 — Alert-routing table.** Pins v1 routing for 24 sources. Severity is advisory at v1, not enforced (Info / Medium / High / Critical). Tenant-facing incident pages (ADR-0054 D4) continue via Notify + PagerDuty; Discord may receive a mirror but is not a substitute. Lives canonically in `constitution/alert-routing.md` (this packet); the ADR-0084 D6 table is the committed-shape snapshot; hive-sync diffs the two parallel to ADR-0054 D4's table treatment.

**ADR-0084 D10 — Onboarding hook.** New alert sources require: (1) a row on the table (this file, post-packet-01), (2) the specific `channel` and `severity` inputs passed to `job-discord-notify.yml`, (3) a volume estimate and, if above 50/day, an explicit suppression rule per ADR-0084 D8. The onboarding hook attaches to `constitution/node-standup.md` (amended by packet 07).

**ADR-0084 D8 — Privacy and signal-hygiene rules.** Volume bounding: any new source projected above 50 messages/day on average requires a per-source severity floor and/or duplicate-suppression rule. The "How to add a new alert source" section in `constitution/alert-routing.md` must surface this rule.

**ADR-0014 hive-sync — drift check pattern.** hive-sync already runs a drift check for ADR-0054 D4's routing table; this packet adds a parallel check for ADR-0084 D6. The implementation pattern is established; this is duplication of an existing scaffold.

## Constraints
- **The ADR-0084 D6 table is not edited by this packet.** The ADR copy is the committed-shape snapshot per ADR-0084 D6's preamble; the constitution copy is the live working surface. Future onboarding packets edit `constitution/alert-routing.md`, not ADR-0084. If the two diverge, hive-sync reports it.
- **Verbatim column structure.** The four columns from ADR-0084 D6 (Event source | Destination channel | Severity | Format hint) must be preserved exactly in `constitution/alert-routing.md`. The drift check parses this structure; deviation breaks the check.
- **Emoji prefixes and link placeholders preserved.** ADR-0084 D6's format hints include emojis (`❌`, `🔑`, `🐝`, `🎯`, `🔄`, `✅`, `🆕`, `✔️`, `🛡️`, `📊`, `🐰`, `💰`, `🐞`, `🕸️`) and link placeholders (`{link-to-run}`, `{pr-link}`, `{issue-link}`, etc.). Preserve verbatim.
- **Hive-sync drift check is forward-compatible.** The check posts to `#hive-activity` via `job-discord-notify.yml`, which lands in packet 05. Mark this as a TODO in the agent prompt so the implementation is staged: log to the existing hive-sync output surface immediately; switch to `job-discord-notify.yml` post-packet-05. Do not block packet 01 on packet 05.
- **Strict PR body discipline.** `Authorship: agent`, `Work Item: <path>`.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `adr-0084`, `wave-2`

## Agent Handoff

**Objective:** Create `constitution/alert-routing.md` as the operational copy of ADR-0084 D6's table, plus the hive-sync drift check.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Ship the live working surface for alert routing so future onboarding packets and emitters reference one canonical file.
- Feature: ADR-0084 Discord operator-alerts rollout, Wave 2.
- ADRs: ADR-0084 (primary, D6 and D10), ADR-0054 (D4 routing-table drift-check pattern), ADR-0014 (hive-sync agent), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** work-item:00 (ADR-0084 acceptance must land first — this packet's preamble references ADR-0084 as Accepted, not Proposed).

**Constraints:**
- The ADR-0084 D6 table stays as the committed-shape snapshot; `constitution/alert-routing.md` is the live working surface. Do not edit ADR-0084 D6.
- Preserve column structure, emoji prefixes, and link placeholders verbatim — the drift check parses them.
- The hive-sync drift check is forward-compatible: log to existing hive-sync output surface immediately, switch to `job-discord-notify.yml` post-packet-05 (marked as TODO in the agent prompt).
- PR body: `Authorship: agent`, `Work Item: <path>`.

**Key Files:**
- `constitution/alert-routing.md` (NEW)
- `.claude/agents/hive-sync.md` (or equivalent — locate at authoring time)
- `adrs/ADR-0084-discord-operator-alerts-surface.md` (read-only reference for D6 table content)

**Contracts:** None changed.
