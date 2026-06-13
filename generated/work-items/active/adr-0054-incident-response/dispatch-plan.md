# Dispatch Plan — ADR-0054: Incident Response and On-Call Model for a One-Person Studio

**Initiative:** `adr-0054-incident-response`
**ADR:** ADR-0054 (Proposed → Accepted via packet 00)
**Sector:** Ops / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0054 binds the scattered incident-shaped signals the Grid already emits (App Insights alerts per ADR-0040, error captures per ADR-0045, budget alerts per ADR-0052, canary failures per ADR-0012, DR drill outcomes per ADR-0036, Audit anomalies per ADR-0030, Stripe webhook failures per ADR-0037) to a defined response process shaped by the one-person-studio constraint. The decisions: four severity levels keyed to **customer impact** (D1); a 09:00–21:00 ET / 7-day coverage window honestly published in tenant SLAs (D2); redundant paging via Notify primary + PagerDuty Starter secondary (D3); a single-source routing table mapping every signal source to a severity and recipient (D4); a single-page (fingerprint-dedup) rule that prevents alert storms from drowning a single human (D5); a seven-state incident lifecycle (D6); an incident-record template at `generated/incidents/YYYY-MM-DD-<slug>.md` with machine-readable front-matter (D7); a 5-business-day post-mortem SLA for SEV-1/2 and a blameless template (D8); tenant-facing communication via Statuspage (deferred Starter until first paying tenant) and `HoneyDrunk.Communications` templates (D9); a per-Node runbook convention at `repos/{node}/runbooks/` with a minimum file set (D10); quarterly game days (D11); a forward-looking second-human hand-off appendix gated on a specific trigger (D12); and a honesty constraint binding all published SLAs to actually-deliverable reality (D13).

This initiative delivers: the three new invariants (incident-record-for-every-SEV-1/2, 5-business-day post-mortem SLA, minimum runbook set), the catalog registrations of `generated/incidents/` as a contract and `repos/{node}/runbooks/` as a per-Node convention, the D7/D8 markdown templates as concrete files plus the `HoneyDrunk.Actions` generators that scaffold them, the PagerDuty Starter account + escalation policy + webhook configuration (human/portal), the Statuspage v0 static-page fallback (human, with deferred Starter), the Notify-side primary paging path (companion-app push integration, with v0 SMS fallback), the Pulse synthetic paging-path probe, the `HoneyDrunk.Communications` tenant-email templates per D9, the Azure Monitor → PagerDuty webhook wiring per the D4 routing table, the per-Node runbook minimum-set rollout playbook, the operator-agent prompt-template amendment per D10, the game-day-discipline doc and the first game-day schedule per D11, and the Notify Cloud draft-SLA language update per D2.

**13 packets across 4 waves**, targeting **5 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Notify`, `HoneyDrunk.Communications`, `HoneyDrunk.Pulse`, `HoneyDrunk.Actions`). 9 `Actor=Agent`, 4 `Actor=Human` (PagerDuty provisioning, Statuspage v0 standup, Azure Monitor → PagerDuty wiring, first game-day execution).

## Trigger

ADR-0054 is Proposed with no scope. The forcing functions (from the ADR's Context):

- **Notify Cloud GA (PDR-0002 / ADR-0027)** is the first paying-tenant surface and cannot ship a published SLA without this ADR's coverage-hour and acknowledgment commitments behind it.
- **The ADR-0034–0047 wave just landed** introducing observability (ADR-0040), error tracking (ADR-0045), cost alerts (ADR-0052), and DR drills (ADR-0036) — each emits signals that need a defined receiving end. Without ADR-0054 every alert path is improvised.
- **The AI-sector standup wave (ADR-0016–0025)** is about to introduce nine Nodes with operationally novel failure modes whose blast radius needs a paired response model.
- **The one-person constraint is load-bearing.** Standard SRE on-call literature assumes multi-person rotation; pretending otherwise produces an unworkable runbook and a credibility hit at the first real incident — this is the failure mode ADR-0054 exists to prevent.

## Scope Detection

**Multi-repo.** ADR-0054 touches `HoneyDrunk.Architecture` (acceptance, three invariants, `generated/incidents/` formalization, `repos/{node}/runbooks/` convention, the D7/D8 templates, the D9 SLA/comms language, the D10 operator-agent amendment, the D11 game-day doc, and a number of human/portal walkthroughs), `HoneyDrunk.Notify` (the primary paging path — companion-app push integration or v0 SMS fallback through Notify), `HoneyDrunk.Communications` (the D9 tenant-email templates), `HoneyDrunk.Pulse` (the D3 synthetic paging-path probe), and `HoneyDrunk.Actions` (the D7/D8 incident-record + post-mortem generators). The D10 minimum runbook set is fanned out via a playbook (packet 10) rather than as premature per-Node packets — that is a deliberate decision to keep the rollout incremental.

## Wave Diagram

### Wave 1 (governance — no dependencies)

- [ ] **00** — Architecture: Accept ADR-0054, add the three new invariants (every SEV-1/2 produces an incident record; every SEV-1/2 has a post-mortem filed within 5 business days; every deployable Node has the minimum runbook set), register the initiative. `Actor=Agent`.
- [ ] **01** — Architecture: register `generated/incidents/` as a contract, add `repos/{node}/runbooks/` as a per-Node convention, add the `runbook_compliance` field to `catalogs/contracts.json` per Node. `Actor=Agent`. Blocked by: 00.
- [ ] **02** — Architecture: author the D7 incident-record template and the D8 blameless post-mortem template as concrete markdown files at `generated/incidents/_templates/`. `Actor=Agent`. Blocked by: 00.
- [ ] **03** — Architecture: provision the **PagerDuty Starter** account, escalation policy, and Azure Monitor / Stripe / generic-webhook integrations. `Actor=Human`. Blocked by: 00.

### Wave 2 (the paging substrate and tenant comms — depend on Wave 1)

- [ ] **04** — Notify: implement the primary paging path — companion-app push integration with the v0 SMS fallback. `Actor=Agent`. Blocked by: 00, 03 (the operator's phone number / Notify-side push credentials surface during PagerDuty setup).
- [ ] **05** — Communications: author the D9 tenant-email templates (SEV-1/2 declaration, update, resolution) in the `HoneyDrunk.Communications` template catalog. `Actor=Agent`. Blocked by: 00.
- [ ] **06** — Pulse: add the synthetic paging-path probe — every 5 minutes fires a fake SEV-3 and verifies arrival on both Notify and PagerDuty paths; either silent for > 15 minutes the other fires a SEV-2 about the missing path. `Actor=Agent`. Blocked by: 03, 04.
- [ ] **07** — Architecture: provision **Atlassian Statuspage** — the v0 static-page fallback under `Studios.HoneyDrunk.com` now, with the Statuspage Starter ($29/month) adoption deferred to first paying tenant. `Actor=Human`. Blocked by: 00.

### Wave 3 (routing wiring and the generators — depend on Wave 2)

- [ ] **08** — Actions: author the incident-record and post-mortem markdown generators as a reusable workflow / CLI scaffold that drops a pre-filled file into `generated/incidents/` from the template. `Actor=Agent`. Blocked by: 02.
- [ ] **09** — Architecture (Human): wire every alert source from the D4 routing table to PagerDuty via webhook — Azure Monitor → PagerDuty action groups for App Insights alerts (ADR-0040), `IErrorReporter` captures (ADR-0045), Azure Monitor budget alerts (ADR-0052), canary failures (ADR-0012), Audit and Vault failure paths (ADR-0030 / ADR-0005), Stripe webhook failures (ADR-0037). `Actor=Human`. Blocked by: 03.

### Wave 4 (per-Node and operator surface, then exercise — depend on Wave 3)

- [ ] **10** — Architecture: author the per-Node runbook minimum-set rollout playbook — the `restart.md` / `rollback.md` / `health-check.md` / `common-sev2-patterns.md` / `escalation.md` scaffold and the per-Node fanout strategy. `Actor=Agent`. Blocked by: 00.
- [ ] **11** — Architecture: amend the operator-agent prompt template (per ADR-0018) to consult `repos/{affected-node}/runbooks/` during the Investigating / Mitigating phases. `Actor=Agent`. Blocked by: 10.
- [ ] **12** — Architecture: author the D11 game-day discipline doc, the game-day-scaffolding scenario list, and schedule the **first game day for 30 days post-acceptance**. Update Notify Cloud's draft SLA language per D2. `Actor=Human` for the first game-day **execution**; `Actor=Agent` for authoring the doc and scheduling. Split: keep both in one packet, classify as Agent for the authoring (the human-prerequisites cover the execution). Blocked by: 04, 06, 08, 09 (the game day exercises the whole paging substrate).

Packets within a wave run in parallel where their dependencies allow. Most Wave 2/3 packets depend on Wave 1 governance + PagerDuty provisioning landing first; Wave 4 sequences after the paging substrate and generators are in place because the game day exercises that substrate end-to-end.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0054](./00-architecture-adr-0054-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Incident + runbook catalog registration](./01-architecture-incident-catalog-and-runbook-convention.md) | Architecture | Agent | 1 | 00 |
| 02 | [D7 incident-record + D8 post-mortem templates](./02-architecture-incident-and-post-mortem-templates.md) | Architecture | Agent | 1 | 00 |
| 03 | [PagerDuty Starter provisioning + escalation policy](./03-architecture-pagerduty-provisioning.md) | Architecture | Human | 1 | 00 |
| 04 | [Notify primary paging path](./04-notify-primary-paging-path.md) | Notify | Agent | 2 | 00, 03 |
| 05 | [Communications tenant-email templates](./05-communications-tenant-incident-email-templates.md) | Communications | Agent | 2 | 00 |
| 06 | [Pulse synthetic paging-path probe](./06-pulse-paging-path-synthetic-probe.md) | Pulse | Agent | 2 | 03, 04 |
| 07 | [Statuspage v0 static + deferred Starter](./07-architecture-statuspage-provisioning.md) | Architecture | Human | 2 | 00 |
| 08 | [Actions incident + post-mortem generators](./08-actions-incident-and-post-mortem-generators.md) | Actions | Agent | 3 | 02 |
| 09 | [Azure Monitor → PagerDuty wiring per D4](./09-architecture-alert-routing-pagerduty-wiring.md) | Architecture | Human | 3 | 03 |
| 10 | [Per-Node runbook minimum-set playbook](./10-architecture-per-node-runbook-playbook.md) | Architecture | Agent | 4 | 00 |
| 11 | [Operator-agent runbook-consult amendment](./11-architecture-operator-agent-runbook-amendment.md) | Architecture | Agent | 4 | 10 |
| 12 | [Game-day doc + first scheduled exercise + SLA language](./12-architecture-game-day-doc-and-sla-language.md) | Architecture | Agent | 4 | 04, 06, 08, 09 |

## Invariant Numbering

Packet 00 adds **three** new invariants per ADR-0054's Consequences/Invariants section: every SEV-1/2 produces a record in `generated/incidents/` with the D7 front-matter; every SEV-1/2 has a post-mortem filed within 5 business days of close; every deployable Node has the D10 minimum runbook set. The verified current maximum invariant number in `constitution/invariants.md` is **53**. ADR-0054 lands in the 12-ADR batch whose numbers above 51 are pre-reserved; the three numbers used here are appended sequentially in the next available batch slot. Record the chosen numbers in packet 00. Include the batch note: "These invariants are pre-reserved as part of a 12-ADR batch; if any invariant from outside this batch lands first, shift upward, never reuse."

## Cross-Cutting Concerns

### Coordination with sibling ADRs

ADR-0054 is the receiving end for signals defined by:

- **ADR-0040 (Telemetry Backend)** — App Insights alerts and Azure Monitor alert rules are the primary signal source per the D4 routing table. Packet 09's PagerDuty wiring runs against the App Insights resource ADR-0040 packet 02 provisions.
- **ADR-0045 (Grid-Wide Error Tracking)** — `IErrorReporter` captures into App Insights Failures are a signal source per D4. Packet 09 wires the Failures-blade alert rule.
- **ADR-0052 (Cost Discipline)** — Azure Monitor budget alerts route to PagerDuty per D4. PagerDuty Starter itself is named in the cost-discipline envelope (~$21–25/month, exempt from its own budget alert).
- **ADR-0036 (Disaster Recovery)** — DR drills produce incident records via this ADR; severity defaults map approximately to DR tiers.
- **ADR-0030 (Audit)** — Audit write-path failures are SEV-1 per D4 (trust-substrate breach). Audit alerting wired in packet 09.
- **ADR-0019 (Communications)** — D9 tenant-email templates land in the Communications catalog; the D9 surface is Communications-owned per ADR-0019's decision/orchestration ownership.
- **ADR-0018 (Operator agent)** — packet 11's prompt-template amendment is governed by ADR-0018's agent-definition surface.
- **ADR-0028 (Pulse synthetics)** — packet 06's paging-path probe runs on the Pulse synthetic-monitoring surface ADR-0028 defines.
- **ADR-0027 (Notify Cloud)** — D2's published SLA is a Notify Cloud GA prerequisite. The in-product SEV-1 ticket surface and tenant in-product banner mentioned in D9 are deferred until Notify Cloud lands; their orchestration is noted in packet 05's referenced ADRs but not implemented here.

### Site sync

No site-sync flag for the ADR itself. The **Statuspage** v0 fallback (packet 07) is a static page rendered under `Studios.HoneyDrunk.com` — that surface change is delivered by the Studios website work, not by this initiative's `target_repo: HoneyDrunk.Studios` packet. The static-page content is a small static asset; updating `HoneyDrunk.Studios` to add the route is a follow-on Studios PR, scoped from packet 07's walkthrough — not a separate packet here.

### Honesty constraint (D13)

D13 is policy, not implementation. It surfaces in this initiative through:

- Packet 12's Notify Cloud SLA language update (the SLA must reflect 09:00–21:00 ET coverage; tighter terms require an ADR amendment).
- A note on every sales/tenant-agreement template that tighter SLAs flag this ADR (handled in packet 12's SLA-language work; the contract-template editing itself is a business workflow outside the scope of work items).
- The D12 "second human" trigger is recorded in ADR-0054 as an appendix; no infrastructure work for it is done now. When the trigger fires, an ADR amendment packet is filed at that time.

## Version Bumps

- **`HoneyDrunk.Notify`** — packet 04 lands on the solution. The version-bump rule (invariant 27): this packet is the first ADR-0054 packet on the solution → minor bump (new paging integration). Per-package CHANGELOG entries only for packages with actual changes.
- **`HoneyDrunk.Communications`** — packet 05 lands on the solution; first ADR-0054 packet on the solution → minor bump (new template catalog entries).
- **`HoneyDrunk.Pulse`** — packet 06 lands on the solution; first ADR-0054 packet on Pulse → minor bump (new synthetic probe).
- **`HoneyDrunk.Actions`** — not a versioned .NET solution; packet 08 is a workflow/YAML change. CHANGELOG updated per the repo convention if it keeps one.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; catalog/doc/governance edits only.

## Rollback Plan

- **Packets 00–02 (governance/templates):** revert the PR. ADR returns to Proposed; the three invariants, catalog entries, and template files removed. No runtime impact.
- **Packet 03 (PagerDuty provisioning):** the PagerDuty Starter account is cancellable from the PagerDuty UI (no contract — month-to-month). The escalation policy and integrations are configuration in the PagerDuty UI — deletable. The walkthrough doc remains for re-execution.
- **Packet 04 (Notify paging path):** revert the PR; `HoneyDrunk.Notify` solution version rolls back. No tenant depends on the paging path — the paging surface is operator-internal.
- **Packet 05 (Communications templates):** revert the PR; the Communications version rolls back. No active orchestration consumes the new templates until packet 09's alert wiring fires a SEV-1/2 — the revert is contained.
- **Packet 06 (Pulse probe):** revert the PR; the synthetic probe stops running. The other paging paths remain operational.
- **Packet 07 (Statuspage v0):** revert the Studios PR adding the static-page route. No external subscribers exist at v0 (the page is static, no notification surface).
- **Packet 08 (Actions generators):** revert the PR. Incident records and post-mortems can be authored manually from the template files (packet 02) until the generator returns.
- **Packet 09 (alert wiring):** delete the PagerDuty webhook integrations and the Azure Monitor action-group webhook configuration in the portal. Alerts revert to the pre-ADR state (App Insights / Azure Monitor email-only or unrouted).
- **Packet 10–11 (runbook playbook + operator-agent amendment):** revert the PRs. Docs only.
- **Packet 12 (game-day doc + SLA language):** revert the PR. The first scheduled game day can be cancelled by deleting the calendar entry — no runtime impact.
- **Substrate-level escape hatch:** D13 explicitly names "amend the ADR" as the response when commitments and capacity diverge. The ADR amendment is the architectural rollback for the *commitments themselves* — D12's second-human trigger fires when capacity changes, otherwise the SLAs stay matched to the one-person reality.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.
