# Dispatch Plan — ADR-0084: Discord as the Canonical Operator-Alerts Surface

**Initiative:** `adr-0084-discord-alerts`
**ADR:** ADR-0084 (Proposed → Accepted via packet 00)
**Sector:** Ops / Meta / cross-cutting
**Created:** 2026-05-26
**Landing zone:** `generated/work-items/proposed/` per ADR-0043 D3. Agents never self-promote to `active/`; the operator does that triage by hand.

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0084 commits Discord as the **single canonical operator-alerts surface** for the Grid. Eight bound sub-decisions: role/scope (D1), seven-channel taxonomy (D2), webhook-per-channel strategy (D3), GitHub-org-secret storage (D4), an inventoried alert-source roster (D5), the alert-routing table (D6), the Hedge vendor posture (D7), the privacy/signal-hygiene rules (D8), the `job-discord-notify.yml` implementation seam (D9), the new-source onboarding hook (D10), and the new invariant (D11) binding the discipline.

The forcing function is **ADR-0083 D5's T-30 / T-7 / T+0 credential-rotation escalation cadence** — Discord channels and webhooks must exist before that procedure has anywhere to publish to. ADR-0084 and ADR-0083 are tightly coupled at acceptance time: ADR-0083's escalation path lands in the routing table this ADR ships (D6 rows for T-30 / T-7 / T+0), and ADR-0083's `infrastructure/reference/sensitive-inventory.md` inventory gains seven new rows for the Discord webhook URLs.

The seven Discord webhook org secrets that ADR-0082 D-?? references as a conditional standup secret block (`DISCORD_WEBHOOK_OPS_ALERTS`, `DISCORD_WEBHOOK_SECURITY_ALERTS`, `DISCORD_WEBHOOK_AGENT_ACTIVITY`, `DISCORD_WEBHOOK_HIVE_ACTIVITY`, `DISCORD_WEBHOOK_RELEASE`, `DISCORD_WEBHOOK_ANNOUNCEMENTS`, `DISCORD_WEBHOOK_AUDIT_SENSITIVE`) are provisioned and seeded by this initiative — they are part of the human-prerequisite block of packet 02.

This initiative delivers:

- ADR acceptance + the one new invariant + initiative registration (Architecture).
- Discord channel creation + webhook provisioning + GitHub org-secret seeding (Architecture, human-only).
- `infrastructure/reference/sensitive-inventory.md` seven-row inventory append (Architecture).
- `infrastructure/walkthroughs/discord-webhook-rotation.md` rotation procedure (Architecture).
- `constitution/alert-routing.md` canonical routing table seeded from D6 (Architecture).
- `job-discord-notify.yml` reusable workflow with the D8 redaction pre-check (Actions).
- `infrastructure/scripts/discord-notify.ps1` home-server helper mirroring the workflow contract (Architecture).
- `constitution/node-standup.md` onboarding-hook step per D10 (Architecture).
- ADR-0080 D2 table amended to add the Discord row per D7 (Architecture).
- Phase-1 emitter wiring — CI failure on `main`, release events, NuGet publishes, scheduled-workflow failures, ADR-0083 credential-rotation escalation (Actions).
- Phase-2 emitter wiring — ADR-0044 review pipeline + ADR-0046 specialist invocations (Actions).
- Phase-3 emitter wiring — hive-sync findings, packet-lifecycle transitions, Dependabot/CodeQL/secret-scanning alerts, SonarCloud, CodeRabbit P0/P1 (Actions).
- Phase-4 emitter wiring — Azure budget alerts, App Insights internal-Grid error spikes (Actions).
- Notify runbook cross-reference making the operator-internal-vs-tenant-facing boundary explicit (Architecture).

**14 packets across 4 waves**, targeting **2 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Actions`). 13 are `Actor=Agent`; 1 (`02`) is `Actor=Human` (Discord portal channel-creation + webhook provisioning + GitHub org-secret seeding cannot be delegated).

## Trigger

ADR-0084 is Proposed with no scope. The forcing functions (from the ADR's Context):

- **ADR-0083 D5 escalation cadence has no saliency-appropriate surface today.** T-30 / T-7 / T+0 against the SonarCloud token (the first realistic firing window — 60-day SaaS cap means the first rotation is realistically within 30–60 days of ADR-0083 acceptance) needs a higher-attention channel than "another label-filtered issue in a 350-issue backlog." ADR-0083 D3 picked GitHub issues as the **tracking** surface but explicitly named chat-webhook as the right **alerting** surface; this ADR closes the gap.
- **Operator-internal signal is scattered across four surfaces today.** GitHub issue notifications buried in a 350-issue backlog; GitHub Actions failure emails in the same inbox as marketing email; manual checks of Actions tabs / Grid Health aggregator / SaaS dashboards; the operator's GitHub profile notifications. No single place is *"the operator pager."*
- **ADR-0044 / ADR-0046 / ADR-0014 / ADR-0032 / ADR-0034 / ADR-0054 each produce signal with no defined real-time alerting destination.** Review-agent verdicts are PR-comment-bound; specialist invocations the same; hive-sync drift, NuGet publishes, deploy events, internal-Grid error spikes all emit signal that benefits from a glanceable surface separate from the GitHub-email-and-issues firehose.
- **ADR-0054 D4 presupposes a real-time operator channel that is not the same surface paying tenants get.** ADR-0054 pins Notify + PagerDuty for paying-tenant SEV-1/SEV-2 pages; the operator-internal day-to-day surface was never named. This ADR names it: Discord, with the seven-channel taxonomy.

## Scope Detection

**Multi-repo (`HoneyDrunk.Architecture` + `HoneyDrunk.Actions`).** Per ADR-0084 §Affected Nodes:

- `HoneyDrunk.Architecture` (primary) — constitution edits, infrastructure reference + walkthrough, governance amendments, the home-server helper script.
- `HoneyDrunk.Actions` — the reusable workflow `job-discord-notify.yml` and every CI emitter retrofit (phased one packet per emitter family).

Nodes explicitly **unchanged at runtime** per the ADR: Communications (D1 boundary), Notify (D1 boundary), Notify Cloud (D1 boundary), Pulse / Observe / Audit (D5 + invariant 47 carve-out), Vault.Rotation (D4 — Discord webhooks are not workload runtime secrets). No application code in any Core / Ops / AI / Service Node changes. No Node standup ADR is implied; only the existing `constitution/node-standup.md` procedure gains a step per D10.

**Routing rule match:** "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" and "workflow, CI, GitHub Actions, pipeline, PR check, release → HoneyDrunk.Actions." Both repos are owned by HoneyDrunkStudios.

## Wave Diagram

### Wave 1 (No Dependencies — governance acceptance)
- [ ] **00** — Architecture: Accept ADR-0084, claim 1 invariant in `constitution/invariant-reservations.md`, add the D11 invariant under that number, register the initiative in `initiatives/active-initiatives.md`. `Actor=Agent`.

### Wave 2 (Substrate provisioning — depends on Wave 1, partially parallel)
- [ ] **01** — Architecture: ship `constitution/alert-routing.md` seeded from ADR-0084 D6, plus the hive-sync drift check that diffs this file against ADR-0084 D6. `Actor=Agent`. Blocked by: 00.
- [ ] **02** — Architecture (human-only): create seven Discord channels in the existing server, provision seven webhooks, seed seven `DISCORD_WEBHOOK_*` GitHub organization secrets. `Actor=Human`. Blocked by: 00.
- [ ] **03** — Architecture: append seven Discord webhook rows to `infrastructure/reference/sensitive-inventory.md` per ADR-0083 D2 (cadence `n/a — non-expiring`, blast-radius prose per channel, owner solo-dev). `Actor=Agent`. Blocked by: 02 (the webhooks must exist before the inventory describes them — the inventory references real provisioned credentials, not placeholders).
- [ ] **04** — Architecture: ship `infrastructure/walkthroughs/discord-webhook-rotation.md` (regenerate webhook in Discord → update GitHub org secret → smoke-test). `Actor=Agent`. Blocked by: 02 (the walkthrough references concrete webhook URLs and GitHub secret names; the procedure is only useful once they exist).
- [ ] **05** — Actions: ship `HoneyDrunk.Actions/.github/workflows/job-discord-notify.yml` reusable workflow per ADR-0084 D9, including the D8 redaction pre-check and contract validation. `Actor=Agent`. Blocked by: 02 (the workflow's smoke tests POST to real webhooks).
- [ ] **06** — Architecture: ship `infrastructure/scripts/discord-notify.ps1` home-server helper mirroring the D9 contract — same inputs, same redaction rules, reads webhook URLs from local secret storage per ADR-0081 D5. `Actor=Agent`. Blocked by: 02.

### Wave 3 (Governance integration — depends on Wave 2)
- [ ] **07** — Architecture: amend `constitution/node-standup.md` to add the operator-alert-routing step per ADR-0084 D10 (parallel to ADR-0083 D6's external-credential-onboarding step). `Actor=Agent`. Blocked by: 01.
- [ ] **08** — Architecture: amend ADR-0080 D2 per-vendor table to add the Discord row per ADR-0084 D7 (Hedge, named hedges, days-scale exit cost). `Actor=Agent`. Blocked by: 00.
- [ ] **09** — Architecture: cross-link this ADR from the Notify runbook surface where ADR-0054 D10 alert routing lives — make the operator-internal-Discord vs tenant-facing-Notify+PagerDuty boundary explicit. `Actor=Agent`. Blocked by: 00.

### Wave 4 (Phased emitter rollout — depends on Wave 2 reusable workflow)
- [ ] **10** — Actions: Phase 1 emitter retrofit — wire CI-failure-on-`main`, release events ([ADR-0033](deploy) success/failure), NuGet publish ([ADR-0034](publish) success/failure), scheduled-workflow failures (nightly-deps, nightly-security, hive-field-mirror, weekly-governance, external-credentials-check, grid-health aggregator), and the ADR-0083 credential-rotation escalation T-30 / T-7 / T+0 to `job-discord-notify.yml`. `Actor=Agent`. Blocked by: 05. **Hard external dep on ADR-0083 packet 05** (this packet edits `external-credentials-check.yml`).
- [ ] **11** — Actions: Phase 2 emitter retrofit — wire ADR-0044 Grid Review pipeline verdicts and ADR-0046 specialist invocations to `#agent-activity`. `Actor=Agent`. Blocked by: 05.
- [ ] **12** — Actions: Phase 3 emitter retrofit — wire hive-sync drift findings, packet-lifecycle transitions (`active/` → `completed/`), PR opened / merged events, GitHub Dependabot / CodeQL High+ alerts, GitHub secret-scanning hits, SonarCloud quality-gate failures, CodeRabbit P0/P1 findings to the routing-table-pinned channels. `Actor=Agent`. Blocked by: 05.
- [ ] **13** — Actions: Phase 4 emitter retrofit — wire Azure budget threshold alerts (ADR-0052 50/75/90/100%) and App Insights internal-Grid error-spike / failure-rate alerts (ADR-0040 + ADR-0045 alert rules). `Actor=Agent`. Blocked by: 05.

Packets 03–06 within Wave 2 can land in parallel once packet 02 (the human-only provisioning) completes.

**Packets 10–13 merge into ONE Actions PR at file time** per the operator's "one PR per repo per initiative" convention. Each packet remains a discrete issue on The Hive for tracking purposes (each phase's acceptance criteria are independently checkable), but the file-issues pipeline files them as four sibling issues that all link to one consolidated PR against `HoneyDrunk.Actions`. The PR body lists all four packet paths in its `Work Item:` metadata (multi-packet PRs are supported via newline-separated `Work Item:` entries). If the consolidated PR grows too large to review (operator's judgment at PR-authoring time), the PR may be split along natural seams — but the file-issues pipeline handles the four-into-one mapping as the default. This honors the operator's PR-cadence preference (memory item `[PR cadence: prefer follow-ups]` + `[User: Oleg / HoneyDrunk Studios] one PR per repo per initiative`).

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0084](./00-architecture-adr-0084-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [constitution/alert-routing.md + hive-sync drift check](./01-architecture-alert-routing-table.md) | Architecture | Agent | 2 | 00 |
| 02 | [Discord channels + webhooks + GitHub org secrets](./02-architecture-discord-portal-provisioning.md) | Architecture | Human | 2 | 00 |
| 03 | [sensitive-inventory.md seven-row inventory append](./03-architecture-external-credentials-discord-rows.md) | Architecture | Agent | 2 | 02 |
| 04 | [discord-webhook-rotation walkthrough](./04-architecture-discord-webhook-rotation-walkthrough.md) | Architecture | Agent | 2 | 02 |
| 05 | [job-discord-notify.yml reusable workflow](./05-actions-job-discord-notify-workflow.md) | Actions | Agent | 2 | 02 |
| 06 | [infrastructure/scripts/discord-notify.ps1 home-server helper](./06-architecture-discord-notify-home-helper.md) | Architecture | Agent | 2 | 02 |
| 07 | [constitution/node-standup.md D10 step](./07-architecture-node-standup-alert-routing-step.md) | Architecture | Agent | 3 | 01 |
| 08 | [ADR-0080 D2 table — add Discord row](./08-architecture-adr-0080-discord-vendor-row.md) | Architecture | Agent | 3 | 00 |
| 09 | [Notify runbook cross-link — operator vs tenant boundary](./09-architecture-notify-runbook-cross-link.md) | Architecture | Agent | 3 | 00 |
| 10 | [Phase 1 emitter wiring — CI, release, NuGet, cron, ADR-0083 escalation](./10-actions-phase1-emitter-wiring.md) | Actions | Agent | 4 | 05 |
| 11 | [Phase 2 emitter wiring — ADR-0044 review + ADR-0046 specialist](./11-actions-phase2-agent-activity-wiring.md) | Actions | Agent | 4 | 05 |
| 12 | [Phase 3 emitter wiring — hive-sync, packet lifecycle, GH security, Sonar, CodeRabbit](./12-actions-phase3-security-and-hive-wiring.md) | Actions | Agent | 4 | 05 |
| 13 | [Phase 4 emitter wiring — Azure budget + App Insights error spikes](./13-actions-phase4-budget-and-error-wiring.md) | Actions | Agent | 4 | 05 |

## Cross-ADR Coupling with ADR-0083

ADR-0084 and ADR-0083 are tightly coupled at acceptance time but **not at filing time** — both ADRs are Proposed today, and neither has a filed packet set in `active/`. Therefore:

- This initiative's `dependencies:` arrays use `work-item:NN` references for intra-folder edges and `external_dependencies:` entries (with `{adr-0083-packet-NN-issue-number}` placeholders) for the ADR-0083 cross-initiative edges.
- The ADR-0083-side coupling is captured both in **narrative** here and as **structured `external_dependencies:`** in the relevant packets (03, 04, 05, 10, 12, 13 reference ADR-0083 packet 01 — the `sensitive-inventory.md` seed; packet 10 references ADR-0083 packet 05 — the `external-credentials-check.yml` workflow):
  - Packet 03 (sensitive-inventory.md Discord rows) appends seven rows to the file ADR-0083 packet 01 creates. `external_dependencies: ["HoneyDrunkStudios/HoneyDrunk.Architecture#{adr-0083-packet-01-issue-number}"]`.
  - Packet 10 wires the T-30 / T-7 / T+0 routing to `#ops-alerts` / `#security-alerts` / `#audit-sensitive` per ADR-0084 D6's three rows for the escalation cadence; ADR-0083's `external-credentials-check.yml` workflow (ADR-0083 packet 05) becomes the **emitter**, this ADR ships the **destination**. Packet 10 declares a hard `external_dependencies:` on ADR-0083 packet 05.

## Cross-Initiative Ordering Constraint

**This is an enforcement constraint, not a suggestion.**

1. **ADR-0084 is promoted from `proposed/` to `active/` FIRST.** Once filed, each ADR-0084 packet has a real GitHub issue number.
2. **The operator then updates ADR-0083 packets 05 and 06 in `proposed/`** with concrete `{Repo}#N` dependencies pointing at the filed ADR-0084 issues (specifically: ADR-0083 packet 05 depends on ADR-0084 packet 10 — the Discord notify wiring — and on ADR-0084 packet 02 — the org-secret seeding).
3. **ADR-0083 is then promoted to `active/`.** Its packets file with real cross-initiative dependencies wired.

Reverse ordering (ADR-0083 first) would file ADR-0083 packet 05 with placeholder `{adr-0084-packet-NN-issue-number}` text that no automation can resolve, leaving the blocked-by edges broken. Operators must not skip step 2 — placeholders left unresolved at file time become tombstones.

## Version Bumps

- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/docs edits only. No CHANGELOG version bump required by these packets (the repo-level CHANGELOG may receive a dated entry per the repo's existing convention for ADR-acceptance events; match what ADR-0042 / ADR-0045 / ADR-0077 / ADR-0080 acceptance packets did).
- **`HoneyDrunk.Actions`** — workflow changes follow the repo's existing CHANGELOG cadence. Packet 05 is a new reusable workflow (additive); packets 10–13 are call-site additions to existing workflows. Per invariant 27, the first packet in the initiative that lands on `HoneyDrunk.Actions` bumps the version in the repo-level CHANGELOG; subsequent packets append to that in-progress version entry.

## Cross-Cutting Concerns

### Why no catalog packet

This initiative deliberately omits a catalog edit. The seven Discord channels and webhooks are not Node contracts; they are operational substrate documented in `constitution/alert-routing.md` (packet 01) and `infrastructure/reference/sensitive-inventory.md` (packet 03). `catalogs/contracts.json` registers Node contracts (interfaces, workflows, schemas); `catalogs/grid-health.json` tracks Node readiness; neither has a slot for operator-alert substrate. The `nodes.json` `HoneyDrunk.Actions` entry already covers the reusable-workflow Node generically; no new node row is needed.

### Why packet 02 is `Actor=Human`

Discord channel creation, webhook URL provisioning (Server Settings → Integrations → Webhooks → New Webhook per channel), and GitHub organization-secret seeding (Settings → Secrets and variables → Actions → New organization secret) are all portal-clicks against vendor surfaces that the agent has no API path into. The seven secrets must be present **before** packet 05's workflow smoke tests run, before packet 03's inventory rows describe real URLs, and before packet 04's walkthrough has a concrete rotation procedure to document. This is the load-bearing manual gate of the initiative; everything in Wave 2 except packet 01 blocks on it.

### Why no canary or contract-shape test

`job-discord-notify.yml` is a reusable workflow, not a .NET contract; it has no canary test. The redaction pre-check in packet 05 has unit-test coverage where feasible (the pattern-match function is testable), but the end-to-end smoke test is "POST a test payload to the test channel, verify the message lands, verify a payload containing a fake-secret-shape is rejected by the pre-check." The smoke test runs at packet 05 acceptance and is re-runnable on demand; it is not a CI gate (gating reusable-workflow merges on a live Discord POST would create a CI dependency on Discord's uptime, which contradicts the Hedge posture from D7).

### Site sync

No site-sync flag. ADR-0084 is internal Grid governance; the seven channels and the alerting substrate are internal operations, not a public-facing Studios website surface. No `HoneyDrunk.Studios` packet needed.

### Coordination with the parallel ADR-0083 initiative

When ADR-0083 is scoped into `proposed/adr-0083-saas-credential-rotation/`, its dispatch plan should:

1. Cite this initiative's packet 02 (Discord channels + webhooks + org secrets) as a hard prerequisite to ADR-0083's external-credentials-check workflow packet — the workflow has no destination until packet 02 lands.
2. Cite this initiative's packet 10 (Phase-1 emitter wiring, which adds T-30 / T-7 / T+0 notify calls to `external-credentials-check.yml`) as the source of the Discord wiring — ADR-0083 packet 05 ships the workflow scaffold WITHOUT Discord branches; ADR-0084 packet 10 adds them by editing the workflow.
3. Cite this initiative's packet 03 (sensitive-inventory.md Discord rows) as the inventory append that ADR-0083 packet 01's `sensitive-inventory.md` receives — the seven Discord rows are seeded by this initiative, not by ADR-0083.

These coordinations are not enforceable from this initiative's side; they are the ADR-0083 scope agent's responsibility. This dispatch plan documents the coupling so the ADR-0083 scoping pass is informed.

## Rollback Plan

- **Packet 00 (acceptance + invariant):** revert the PR. ADR-0084 returns to Proposed; the new invariant is removed; the reservation row is removed; the initiative entry in `active-initiatives.md` is removed. No runtime impact.
- **Packet 01 (alert-routing.md):** revert the PR. `constitution/alert-routing.md` is deleted; the hive-sync drift check is removed. No runtime impact (no emitters reference it yet at Wave 2).
- **Packet 02 (human provisioning):** Discord channels and webhooks are deleted in the portal; GitHub org secrets are deleted in Settings. The operator may also revoke webhook URLs at any time post-creation for partial rollback. The seven downstream packets (03–06, 10–13) become blocked again until re-provisioned.
- **Packets 03 / 04 / 06 / 07 / 08 / 09:** revert each PR; the corresponding file is deleted or reverts to its pre-PR state. No runtime impact (these are governance/docs).
- **Packet 05 (`job-discord-notify.yml`):** revert the PR; the reusable workflow is deleted. Downstream consumers (packets 10–13) fail at `workflow_call` resolution — the operator may need to revert each consumer in turn.
- **Packets 10–13 (emitter retrofits):** revert each PR per emitter family; the corresponding `job-discord-notify` call sites are removed from each workflow. The emitting workflow returns to its pre-retrofit notification posture (GitHub email + Grid Health aggregator). No data loss.

Full initiative rollback returns the operator to the pre-ADR-0084 surface: GitHub email + 350-issue backlog + manual SaaS-dashboard checks. The lock-in is one-way only at packet 02 (the seven secrets are provisioned and need explicit deletion); every other packet is reversible by `git revert`.

## Filing

Filing is automated. Once the operator promotes this folder from `proposed/` to `active/`, on push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

No cross-initiative `{Repo}#N` dependencies in this folder's `dependencies:` arrays — every entry is a `work-item:NN` reference, all of which resolve within this folder once filed. The ADR-0083 coupling lives in narrative; the ADR-0083 scope agent wires its side of the coupling when that initiative is scoped.
