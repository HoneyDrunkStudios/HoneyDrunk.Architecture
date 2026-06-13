# ADR-0054: Incident Response and On-Call Model for a One-Person Studio

**Status:** Proposed
**Date:** 2026-05-22
**Deciders:** HoneyDrunk Studios
**Sector:** Ops / cross-cutting

## Context

The Grid emits incident-shaped signals today — Application Insights alerts (ADR-0040), error-tracking captures (ADR-0045), Azure Monitor budget alerts (ADR-0052), canary failures (ADR-0012), DR drill outcomes (ADR-0036), Audit anomalies (ADR-0030) — but no governing decision binds any of them to a defined response process. The pieces that exist are scattered:

- **`generated/incidents/`** exists as a directory in this repo and is referenced by `CLAUDE.md` as the post-mortem log location; no ADR governs its template, lifecycle, or filing cadence. It is a slot waiting for a contract.
- **ADR-0036 (DR, Proposed)** mentions "drills" as a periodic exercise but does not define how a drill turns into an incident record, who acknowledges what, or what the post-drill review looks like.
- **ADR-0045 (Error Tracking, Proposed)** introduces alert paths off Application Insights' Failures blade and `IErrorReporter`, but stops at "alerts fire" — does not say where they page, who acknowledges, or under what severity.
- **ADR-0040 (Telemetry, Proposed)** mentions alerts as a downstream consumer of metrics/logs but explicitly defers the alert-routing decision.
- **ADR-0052 (Cost Discipline, Proposed)** defines Azure Monitor budget alerts at the subscription level and assigns thresholds, but treats "the alert fires and reaches the operator" as a solved problem.
- **ADR-0019 (Communications, Accepted)** owns the decision/orchestration surface that any tenant-facing incident communication must flow through; the templates for incident notification do not exist yet.

The forcing functions for deciding this now:

- **Notify Cloud GA (PDR-0002 / ADR-0027)** is the first paying-tenant surface. Shipping it without a defined incident-response process is a credible-paying-customer blocker — a customer asking "what happens when your platform goes down at 2 AM?" deserves an honest, documented answer.
- **The ADR-0034–0047 wave just landed** introducing observability, error tracking, cost alerts, and DR drills. Each of those produces signals that need a defined receiving end. Without this ADR, every alert path is improvised.
- **The AI-sector standup wave (ADR-0016–0025)** is about to introduce nine Nodes whose primary failure modes are operationally novel (LLM provider outages, agent-execution loops, eval-target failures). The blast-radius rules in `constitution/sector-interaction-map.md` need a paired response model.
- **The "studio" constraint is load-bearing.** Standard SRE on-call literature assumes a multi-person rotation, primary/secondary escalation, follow-the-sun coverage, and an "if no one acks in N minutes, page the next person" tree. HoneyDrunk Studios is one human plus AI agents. Escalation paths terminate at the single operator; "page the secondary" is `null`. Pretending otherwise produces an unworkable runbook and a credibility hit when the runbook visibly diverges from reality during the first real incident.

This ADR commits to the **severity taxonomy** the Grid uses to triage signals, the **operator availability windows** that are honestly publishable in SLAs, the **paging mechanism** (with redundancy because the primary paging path is itself a Grid Node), the **alert routing table** that maps every signal source to a severity and recipient, the **single-page rule** that prevents alert storms from drowning a single human, the **incident lifecycle and record template** that turns `generated/incidents/` into a contract, the **post-mortem cadence** that feeds incidents back into ADRs, the **external communication surface** for paying tenants, the **per-Node runbook convention**, the **game-day discipline** that exercises the process before reality does, and the **forward-looking amendment trigger** for when a second human gains prod credentials.

The decision is shaped throughout by the honesty constraint: published commitments must reflect what one human plus AI agents can actually deliver. Anything beyond that is theater.

## Decision

### D1 — Severity taxonomy

Four severity levels, defined by **customer impact** rather than internal pain. Internal pain is a real signal but a poor priority proxy — a noisy log that infuriates the operator is not a SEV-1; a quiet data-loss bug affecting one tenant is.

| Severity | Definition | Ack target | Communication target | Examples |
|----------|------------|------------|----------------------|----------|
| **SEV-1** | Production down for paying customers; data loss in flight; security breach in progress | **15 minutes** | First customer-facing update **within 1 hour**; updates every 60 min thereafter | Notify Cloud tenant gateway returning 5xx for >5 min; Vault unreachable Grid-wide; suspected unauthorized access to tenant data; Stripe payment-webhook drops causing billing failures |
| **SEV-2** | Production degraded for paying customers; significant feature unavailable; recovery achievable in < 4 hours | **30 minutes** | First customer-facing update **within 2 hours** if tenant-impacting; updates every 2 hours | Notify Cloud delivery latency > 5x baseline; one tenant blocked but Grid otherwise healthy; partial Audit ingestion failure (write path degraded but not dropped) |
| **SEV-3** | Internal-only impact, or single-tenant impact with workaround available | **Same business day** | Tenant-direct via Communications only if the tenant is already aware or the workaround needs explanation | Canary failure on a non-published package; a single tenant's quota exhausted requiring manual reset; non-critical dashboard offline |
| **SEV-4** | Cosmetic, no user impact, or affects only studios-internal tooling | **Next business day** | None | Marketing-site typo; broken link in an internal runbook; agent-side log noise; Architecture catalog drift not blocking work |

**Severity is set at the source** (the alert config or the operator on declaration) and **can be promoted but not demoted without a recorded reason** in the incident record. Promotion (SEV-3 → SEV-2 → SEV-1) is one-way without justification; demotion requires a `severity_change` entry in the incident timeline naming why the impact assessment changed.

The thresholds map to ADR-0036's DR tiers approximately — Tier 0 Nodes (Vault, Audit, Notify Cloud tenant data) failures default to SEV-1 unless explicitly downgraded; Tier 1 (Notify, Memory, Knowledge) default to SEV-2; Tier 2 (Pulse, Flow, Evals) default to SEV-3. The defaults are starting points, not ceilings.

### D2 — Operator availability windows

The studio is one human. Pretending otherwise is the failure mode this decision exists to prevent.

**Coverage hours for paying-tenant impact (SEV-1 / SEV-2 on tenant-facing surfaces):**
- **09:00–21:00 Eastern Time, 7 days a week.**
- This is a 12-hour window across all 7 days, chosen because it spans typical North American business waking hours, leaves a defined off-window for sleep and recovery, and is the largest window one person can reasonably commit to without burnout in the first year of operation.
- The window is **documented**, **published in Notify.Cloud's SLA**, and **explicitly named in tenant agreements**. The honesty constraint (D13) means we do not advertise coverage we cannot deliver.

**Outside coverage hours (21:00–09:00 ET) for SEV-1 / SEV-2:**
- Alerts still **page** via the paging mechanism (D3). The operator is not committed to wake-up response, but the page is recorded so morning triage is informed.
- Ack target shifts to **"best effort within 2 hours of waking"** with no committed wall-clock SLA.
- This is the **explicit trade-off** of being a one-person studio. Notify Cloud's SLA reflects this (next paragraph).
- For tenants requiring 24/7 coverage, the SLA cannot honestly be offered until D12's "second human with prod credentials" trigger fires. Those tenants are not in our addressable market in 2026.

**Internal Grid (no paying-tenant impact):**
- **No out-of-hours pages** for SEV-3 / SEV-4 ever.
- SEV-1 / SEV-2 on internal-only surfaces (e.g., Architecture catalog corruption, internal Studios.HoneyDrunk.com outage) page during coverage hours only.
- Out-of-hours alerts on internal surfaces are batched into a morning digest delivered at 09:00 ET start of next coverage period.

**SLA implications for Notify Cloud (cross-ref PDR-0002 / ADR-0027):**
- Published SLA: **99.5% monthly uptime within coverage hours; 99.0% monthly uptime overall.**
- Acknowledgment SLA: **15 min within coverage, best-effort outside.**
- Resolution SLA: **commitment varies by severity**, with explicit out-of-hours carve-outs.
- ADR-0027 is a **blocker** for any tighter SLA than this; revising the SLA upward requires revising this ADR (D13).

### D3 — Paging mechanism

Push-to-phone via two redundant paths. The first path is the Grid's own Notify Node; the second is an external paging vendor. **Both required** because "Notify is itself down" is a credible failure mode, and the operator cannot acknowledge a page that depends on the failing system to deliver itself.

**Primary path: Notify Communications channel.**
- Alerts route through `HoneyDrunk.Notify` per ADR-0019 (Communications owns decision/orchestration; Notify owns intake/delivery).
- Delivery target: the operator's personal phone via push notification (initially APNs/FCM through a small Studios-internal companion app, or via SMS if the companion app is not yet built).
- Latency target: **< 30 seconds from alert fire to phone receipt** under healthy Grid conditions.
- Cost: bundled into the Notify infrastructure already running.

**Secondary path: External paging vendor.**
- **PagerDuty** is the chosen vendor for v1.
- Tier: **PagerDuty Starter** (~$21/user/month at 2026 list pricing for the lowest paid tier; the free tier is acceptable for testing but lacks SMS reliability needed for SEV-1).
- Justification (cross-ref ADR-0052): PagerDuty Starter is ~$21–25/month for one user, fits within the cost-discipline envelope, and provides the redundant SMS + phone-call path that survives Notify-itself-down scenarios. OpsGenie was considered (Atlassian-bundled, similar feature set); rejected on continuity grounds — PagerDuty has the larger ecosystem of integrations with Azure Monitor (ADR-0040) and the existing Stripe/GitHub webhooks the Grid already uses.
- Delivery path: alert source → PagerDuty webhook → PagerDuty escalation policy → SMS + phone call to operator's phone number.
- The PagerDuty path is **the source of truth for acknowledgment** because it has a true ack-button surface; Notify-pushed alerts include a deep-link to the PagerDuty incident for ack.

**Both paths fire for every SEV-1 / SEV-2.** SEV-3 fires Notify only (no PagerDuty cost burn for non-paging-worthy events). SEV-4 fires neither — surfaces in the morning digest.

**Failure mode for the paging mechanism itself:**
- Pulse (ADR-0028) runs a synthetic probe every 5 minutes that fires a fake SEV-3 alert and verifies arrival on both Notify and PagerDuty paths. If either path goes silent for > 15 minutes, the **other path** fires a SEV-2 about the missing path.
- This is the "who watches the watchmen" pattern. The Pulse probe is itself a Grid-health-monitored synthetic.

### D4 — Alert sources and routing table

Every signal source the Grid produces routes through this table. The source declares the SEV at emission; the routing layer (Notify Communications + PagerDuty) honors it.

| Source | Signal | Default SEV | Routing | Notes |
|--------|--------|-------------|---------|-------|
| App Insights alerts (ADR-0040) | Failure rate >5% over 5 min on tenant-facing endpoint | SEV-1 | Notify + PagerDuty | Tenant-facing endpoint defined by tag `surface=tenant`. |
| App Insights alerts (ADR-0040) | Failure rate >5% over 10 min on internal endpoint | SEV-2 | Notify + PagerDuty within coverage; Notify-only outside | |
| App Insights alerts (ADR-0040) | Latency p95 >2x baseline on tenant-facing endpoint | SEV-2 | Notify + PagerDuty | |
| `IErrorReporter` capture (ADR-0045) | New unique problem ID with >10 occurrences in 1h on tenant traffic | SEV-2 | Notify + PagerDuty within coverage | |
| `IErrorReporter` capture (ADR-0045) | Existing problem ID exceeding 100/h regression threshold | SEV-3 | Notify only | |
| Azure Monitor budget (ADR-0052) | Spend forecast >120% of monthly budget | SEV-2 | Notify + PagerDuty within coverage | Cost-out incident; treated as customer-impact-adjacent because billing runway is operational. |
| Azure Monitor budget (ADR-0052) | Spend actual >80% mid-month | SEV-3 | Notify only | |
| Canary failure (ADR-0012) | Published-package canary fails post-publish | SEV-2 | Notify + PagerDuty within coverage | Blocks downstream consumers; named in ADR-0034. |
| Canary failure (ADR-0012) | Nightly grid-health canary fails on non-published Node | SEV-3 | Notify only | |
| Audit (ADR-0030) | Write-path failure (single event drop) | SEV-1 | Notify + PagerDuty | Audit data loss is a trust-substrate breach. |
| Audit (ADR-0030) | Ingestion latency >30 min | SEV-2 | Notify + PagerDuty within coverage | |
| Vault (ADR-0005/0006) | Vault unreachable from any Node for >2 min | SEV-1 | Notify + PagerDuty | Cascades to every Node; pre-empt the blast. |
| Vault (ADR-0005/0006) | Secret-rotation failure | SEV-2 | Notify + PagerDuty within coverage | |
| DR drill (ADR-0036) | Manual SEV declaration during drill | as declared | per declaration | Drills exercise the full path. |
| Notify Cloud tenant report | Tenant opens a SEV-1 ticket via in-product surface | SEV-1 | Notify + PagerDuty | Tenant-initiated; the surface authenticates the tenant before promoting. |
| Stripe webhook (ADR-0037) | Payment webhook failure >5 min | SEV-2 | Notify + PagerDuty within coverage | Billing path is operationally critical. |

The table lives in this ADR for the v1 commitment; the operational reference copy lives in `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` (per D10) and stays in sync via a `hive-sync` check that diffs the two.

### D5 — Single-page rule

**Each alert pages once. Repeated firing of the same fingerprint within 1 hour does not re-page.**

Rationale: a single human cannot multi-thread acknowledgments. An alert storm (one root cause, fifty downstream alerts) drowns the SEV signal. The first page wins; subsequent pages within the dedup window are silently aggregated into the original incident record.

**Fingerprint definition:**
- App Insights alerts: the alert rule ID + the operation name + the impacted endpoint.
- `IErrorReporter` captures: the problem ID (per ADR-0045 D6's `application_Version` fingerprinting).
- Canary failures: the canary's NodeName + canary name.
- Other sources: source-declared fingerprint string in the alert payload.

**Dedup window:** 1 hour from first fire. After 1 hour, the fingerprint re-pages if still firing — this is the "still broken after an hour" signal and meaningful.

**Auto-resolve:** when the underlying condition clears for **5 minutes** continuous, the routing layer emits an "all clear" Notify push (Notify-path only, no PagerDuty page) referencing the original incident record. The operator confirms-or-disputes-clearance in the incident record.

**Operator manual override:**
- The operator can mark an incident `acknowledged` from PagerDuty or from a Notify deep-link; this suppresses re-pages on the same fingerprint until the operator explicitly closes the incident.
- The operator can mark an incident `resolved` to trigger auto-resolve early.

### D6 — Incident lifecycle

Incidents move through seven states. Each state transition is **recorded in the incident record** with a timestamp.

```
Open → Acknowledged → Investigating → Mitigating → Resolved → Reviewing → Closed
```

| State | Entry condition | Exit condition | Operator action |
|-------|----------------|----------------|-----------------|
| **Open** | Alert fires; incident record created | Operator acknowledges via PagerDuty or Notify deep-link | None required to enter; ack is the exit |
| **Acknowledged** | Operator clicks ack | Operator begins active investigation | Initial assessment; SEV confirm/promote |
| **Investigating** | Operator begins root-cause work | Operator identifies a mitigation path | Triage; check runbooks (D10); engage operator agent (ADR-0018) for suggestions |
| **Mitigating** | Operator begins applying a fix or workaround | Underlying condition clears | Apply fix; monitor for clearance |
| **Resolved** | Underlying condition clears for ≥5 min | Operator marks closed after post-incident steps | "All clear" Notify sent; customer communication if SEV-1/2 |
| **Reviewing** | Resolved; post-mortem required (SEV-1/2) | Post-mortem filed | Author post-mortem per D8 |
| **Closed** | Post-mortem filed (if required) or 5 business days elapsed (SEV-3) | Terminal | None |

Each state has an entry timestamp in the incident record front-matter. The full lifecycle is queryable across `generated/incidents/*.md`; a future `hive-sync` task produces a rolling MTTA / MTTR dashboard.

### D7 — Incident record template

Every incident produces a markdown file at `generated/incidents/YYYY-MM-DD-<slug>.md`. The slug is `<sev>-<short-description>` (e.g., `2026-05-22-sev1-notify-cloud-tenant-gateway-down.md`).

**Template:**

```markdown
---
incident_id: INC-2026-0042
severity: SEV-1
status: Closed
opened_at: 2026-05-22T14:23:00Z
acknowledged_at: 2026-05-22T14:31:00Z
investigating_at: 2026-05-22T14:35:00Z
mitigating_at: 2026-05-22T14:52:00Z
resolved_at: 2026-05-22T15:18:00Z
reviewing_at: 2026-05-22T15:20:00Z
closed_at: 2026-05-26T11:00:00Z
customer_impact: yes
affected_tenants: [tenant-acme, tenant-globex]
affected_nodes: [HoneyDrunk.Notify.Cloud, HoneyDrunk.Notify.Worker]
alert_sources: [app-insights:notify-cloud-failure-rate, pagerduty:INC-2026-0042]
mtta_minutes: 8
mtmitigate_minutes: 29
mttr_minutes: 55
post_mortem_required: yes
post_mortem_link: ./post-mortems/2026-05-22-sev1-notify-cloud-tenant-gateway-down.md
---

# INC-2026-0042: Notify Cloud tenant gateway down

## Summary
One-paragraph customer-facing summary. What was affected, when, for how long.

## Timeline
- 14:23 UTC — App Insights alert fired (failure rate 87% on POST /v1/notifications)
- 14:23 UTC — PagerDuty + Notify pages dispatched
- 14:31 UTC — Operator acknowledged from phone
- 14:35 UTC — Operator opened App Insights Failures blade; identified...
- 14:52 UTC — Mitigation applied: rolled back container revision to v0.5.3
- 15:18 UTC — Failure rate returned to baseline; auto-resolve fired
- 15:20 UTC — Operator confirmed resolution; began post-mortem

## Root cause
Or "unknown — investigating" if not yet identified at incident close.

## Mitigation
What was done to restore service.

## Customer communication
- 14:35 UTC — Status page updated
- 14:50 UTC — Tenant email sent via Communications (ADR-0019) to acme, globex
- 15:18 UTC — Status page resolved
- 15:25 UTC — Tenant resolution email sent

## Follow-ups
- [ ] ARC-1234: Add regression test for the failure mode
- [ ] NTFY-0089: Tighten rollback automation per ADR-0036 D4
- [ ] PDR amendment: SLA target needs to reflect this class of failure

## Post-mortem
[Link to ./post-mortems/...]
```

**Notes on the template:**
- Front-matter fields are **machine-readable** (`hive-sync` consumes them for the rolling MTTA/MTTR dashboard and the incident-volume report).
- `mtta_minutes`, `mtmitigate_minutes`, `mttr_minutes` are computed from the timestamps and recorded for trend visibility.
- The timeline is **append-only during the incident** (operator types into it as events happen) and frozen at close.
- "Unknown — investigating" is a **valid root cause at incident close** if true; the post-mortem is where it gets refined.
- Follow-ups link to work items (per ADR-0008) or ADR amendments; an incident that produces no follow-ups is itself a signal worth noting.

### D8 — Post-mortem cadence

| Severity | Post-mortem required | Deadline | Format |
|----------|----------------------|----------|--------|
| SEV-1 | **Yes** | 5 business days from close | Full blameless template (see below) |
| SEV-2 | **Yes** | 5 business days from close | Full blameless template |
| SEV-3 | Optional (operator discretion) | If filed, 10 business days | Lightweight |
| SEV-4 | Not required | N/A | N/A |

**Blameless post-mortem template** (lives at `generated/incidents/post-mortems/YYYY-MM-DD-<slug>.md`):

```markdown
---
incident_id: INC-2026-0042
post_mortem_id: PM-2026-0042
authored_at: 2026-05-26T10:30:00Z
participants: [operator]
related_adrs: [ADR-0027, ADR-0036, ADR-0045]
follow_up_work_items: [generated/work-items/active/standalone/2026-05-26-notify-cloud-rollback-automation.md]
---

# PM-2026-0042: Notify Cloud tenant gateway down (2026-05-22)

## What happened
Factual narrative; no blame language.

## Impact
Customer impact, business impact, internal cost (operator hours).

## Root cause
Technical root cause. May be "five whys" depth.

## What went well
Things that worked. The alert fired correctly. The runbook applied. The rollback completed in <10 min.

## What went poorly
Things that didn't. The first-hit fingerprint didn't dedup correctly and re-paged at minute 60. Status page update was 15 min late.

## Where we got lucky
Things that worked by accident, not by design. Catching these is the whole point of the blameless review.

## Action items
Concrete follow-ups, each linked to a work item or ADR amendment. Owner, deadline, status.

## Glossary / Links
Relevant ADRs, dashboards, related incidents.
```

**Blameless principle:** the post-mortem describes systems, processes, and tools — never individual fault. In a one-person studio, the operator IS the only individual; blameless language is doubly important because self-blame is the failure mode. The point is to fix the system, not the human.

**Post-mortems feed back into the Grid:**
- Action items become work items (ADR-0008) or ADR amendments.
- Patterns across multiple post-mortems trigger ADR-level changes (e.g., three post-mortems naming the same boundary failure → ADR amendment to the boundary contract).
- Quarterly retrospective reads the last 90 days of post-mortems and produces a meta-report.

### D9 — Communication channels

**Internal:**
- Incident record file in `generated/incidents/` (per D7).
- Operator dashboard (future; the v1 dashboard is the directory listing of `generated/incidents/` filtered by status).

**External — paying tenants:**

| Surface | Tool | When updated | Notes |
|---------|------|--------------|-------|
| Status page | **Atlassian Statuspage** ($29/month Starter at 2026 pricing) v1 if budget permits; **static page in Studios.HoneyDrunk.com** v0 fallback | Within 30 min of SEV-1 / SEV-2 declaration with tenant impact; updates every 60 min during active incident; resolution within 30 min of close | Trade-off: Statuspage gives proper subscriber notifications, RSS, history; static page gives nothing but is free. Choose Statuspage when first paying tenant exists; before that, static is acceptable. |
| Tenant email | `HoneyDrunk.Communications` (ADR-0019) | SEV-1 with confirmed tenant impact: at declaration, hourly thereafter, at resolution. SEV-2 with confirmed tenant impact: at declaration if >30 min ETA to mitigation, at resolution | Templates defined below. |
| In-product banner | Notify Cloud tenant portal (future, ADR-0027) | SEV-1 with confirmed tenant impact: at declaration, removed at resolution | Render-only; no extra ops surface. |

**Tenant email templates** (lives in HoneyDrunk.Communications per ADR-0019 D3):

*SEV-1 / SEV-2 declaration:*
```
Subject: [HoneyDrunk Notify] Incident in progress affecting your account
We are currently investigating an issue affecting <tenant-name>. The impact you may see is <human description>.
Incident ID: INC-YYYY-NNNN
Status: <status>
Next update: within 60 minutes
You can follow updates at status.honeydrunkstudios.com.
```

*Update:*
```
Subject: [HoneyDrunk Notify] Update on INC-YYYY-NNNN
<one paragraph update>
Next update: within 60 minutes
```

*Resolution:*
```
Subject: [HoneyDrunk Notify] INC-YYYY-NNNN resolved
The issue affecting <tenant-name> has been resolved as of <time UTC>.
Cause: <one-line>
A post-mortem will be published within 5 business days.
Thank you for your patience.
```

The templates are **versioned in Communications** so they update without an ADR amendment; the SLA they reference (within 60 min, 5 business days) is bound by this ADR and changes only via amendment.

### D10 — Runbooks

**Per-Node runbooks live in `repos/{node}/runbooks/`.** This convention is added by this ADR; existing repos that have ad-hoc runbook content migrate it under the new directory.

**Minimum per-Node runbook set:**

| File | Content | Required? |
|------|---------|-----------|
| `restart.md` | How to restart the Node's services (Container App revision restart, Function App restart, etc.) | Yes for deployable Nodes |
| `rollback.md` | How to roll back to the previous tagged release (cross-ref ADR-0033 tag → environment mapping) | Yes for deployable Nodes |
| `health-check.md` | How to verify the Node is healthy (which endpoints to probe, which dashboard to consult, expected metric ranges) | Yes for all Nodes |
| `common-sev2-patterns.md` | The handful of known SEV-2-class failure modes with diagnostic steps and mitigation | Yes for deployable Nodes |
| `escalation.md` | What to escalate, where, when (e.g., "Vault unavailability with no recovery in 30 min → page Azure support") | Yes for Tier 0 Nodes (ADR-0036); optional otherwise |

**Operator agent integration (ADR-0018):**
- The operator agent **consumes the runbooks** when generating mitigation suggestions during the Investigating / Mitigating phases of an incident.
- The agent's prompt template is amended (per ADR-0018) to include "consult `repos/{affected-node}/runbooks/` for the affected Node before suggesting mitigations."
- Runbook content quality directly affects operator-agent suggestion quality; runbook neglect is a feedback loop.

**Runbook freshness:**
- A runbook **older than 90 days that has not been touched** is flagged in the nightly `hive-sync` report.
- After every SEV-1 / SEV-2 post-mortem, the affected Node's runbooks are reviewed and updated if relevant.
- Game days (D11) exercise the runbooks; an exercise that finds a runbook gap requires a same-day patch.

### D11 — Game days

**Quarterly chaos exercise.** The operator manually triggers a known failure mode in a non-production environment (or in production within a coordinated window when the failure mode is safe to trigger) and runs through the incident process end-to-end.

**Game-day scenarios** (rotate across quarters):
- Kill a Container App revision mid-traffic.
- Expire a Vault secret without rotation.
- OOM a worker process.
- Pull the network from a downstream dependency.
- Simulate a runaway cost incident (cross-ref ADR-0052 — burn budget rapidly).
- Simulate an Audit write-path outage.
- Simulate a Stripe webhook failure (cross-ref ADR-0037).

**Game-day discipline:**
- Scenario is chosen and documented 1 week in advance.
- Exercise runs through the full lifecycle (D6): page fires → ack → investigate → mitigate → resolve → post-mortem.
- Post-game-day post-mortem identifies process gaps, runbook gaps, and tooling gaps.
- Findings either get fixed within 30 days or filed as ADR amendments / work items.

**First game day target: 30 days after this ADR accepts.**

**Pairs with ADR-0036 DR drills:**
- DR drills exercise data recovery (restore from backup, fail over).
- Game days exercise process (does the alert fire, does the page deliver, does the operator know what to do).
- The two are complementary; some scenarios qualify as both (e.g., "restore a Cosmos DB from backup" is a DR drill that also exercises the incident response process for the duration of the restore).

### D12 — On-call hand-off (forward-looking; appendix only)

**Current state (2026):** one human operator. No rotation. No hand-off protocol.

**Future state trigger:** "hired or contracted human #2 who has prod credentials and capacity to receive pages." This is a **specific, observable trigger**, not an aspirational goal. The trigger fires when:
- A second person has Vault credentials for production.
- That person has signed a contract acknowledging on-call expectations.
- That person has been onboarded to PagerDuty as an escalation target.

**When the trigger fires, this ADR is amended** to add the v2 rotation pattern. The proposed v2 pattern (recorded here so it isn't re-litigated under deadline):

- Primary on-call: rotates weekly.
- Secondary on-call: the other person, week-on / week-off.
- Coverage hours expand to 24/7 once two people share the load.
- Escalation: primary → secondary after 15 min ack timeout (SEV-1) or 30 min (SEV-2).
- Tools: PagerDuty rotation schedule replaces the static escalation policy.

**This is an appendix, not a current commitment.** Building infrastructure for two-person rotation today is over-engineering. The trigger and the v2 pattern are recorded so the transition is smooth when (and only when) the trigger fires.

### D13 — Honesty about limits

The SLAs and process commitments in this ADR reflect **what one human plus AI agents can actually deliver**. Anything tighter is theater, and theater produces customer trust failures larger than the underlying limit.

**The honesty constraint applies to:**
- Notify Cloud's published SLA (per D2).
- Tenant agreements' incident response commitments.
- Status-page promises about update cadence.
- The "we'll respond within X" claim on any external surface.

**If a future commercial commitment requires tighter SLAs than this ADR delivers** — for example, a tenant offering meaningful revenue in exchange for a 99.9% SLA with 5-minute ack outside coverage hours — **this ADR is a blocker for that commitment and must be revisited first**. The order is: amend ADR → hire / contract the human #2 (D12 trigger) → publish the tighter SLA. Not: publish the SLA → hope to backfill.

**The blocker is explicit:**
- Sales conversations referencing tighter SLAs flag this ADR.
- The operator does not commit to tighter terms verbally or in contract drafts without ADR amendment.
- The ADR-amendment process forces the cost-of-coverage conversation (hiring, on-call comp, tooling upgrade) **before** the commitment exists.

## Consequences

### Affected Nodes

- **HoneyDrunk.Notify** — primary affected Node. Implements the primary paging path (D3). Routes alerts per the D4 table. Owns the Notify-side companion-app push integration. Existing alert paths into Notify are restructured to conform to the routing table.
- **HoneyDrunk.Communications** — owns tenant-email templates and the orchestration to send them (ADR-0019). Templates from D9 land in the Communications template catalog. Banner-on-tenant-portal orchestration lands when Notify Cloud portal lands (ADR-0027).
- **HoneyDrunk.Pulse** — adds the synthetic paging-path probe per D3. Pulse runs the every-5-minute fake-SEV-3 verification across both Notify and PagerDuty paths.
- **HoneyDrunk.Observe** — alert configurations defined in App Insights and routed per D4. ADR-0040's alert-routing-deferred clause closes here.
- **HoneyDrunk.Audit** — failure-path alerts wired per D4. Audit write-path failure is a SEV-1 because it breaches the trust substrate (ADR-0030).
- **HoneyDrunk.Vault** — failure-path alerts wired per D4. Vault unavailability cascade is pre-empted by SEV-1 routing.
- **HoneyDrunk.Actions** — reusable workflow templates for incident-record creation; game-day-exercise scaffolding workflow.
- **HoneyDrunk.Architecture** — `generated/incidents/` formalized as a contract (D7 template). `repos/{node}/runbooks/` directory added per D10. `catalogs/contracts.json` gains a "runbook compliance" field per Node.
- **All Nodes (per D10)** — minimum runbook set required for deployable Nodes; health-check.md required for all Nodes.
- **HoneyDrunk.Notify.Cloud (future, ADR-0027)** — implements the in-product banner, the tenant in-product SEV-1 ticket surface, and the SLA published per D2.

### Invariants

Adds three:

- **Invariant: every paying-tenant-impacting incident (SEV-1 / SEV-2) produces a record in `generated/incidents/` with the D7 template's required front-matter.** Missing records is a CI gate failure (the gate is implemented as a `hive-sync` check that diffs PagerDuty's incident log against the directory).
- **Invariant: every SEV-1 and SEV-2 incident has a post-mortem filed within 5 business days of close.** Missing post-mortems flag in the nightly `hive-sync` report.
- **Invariant: every deployable Node has the minimum runbook set per D10.** Missing runbooks block the Node's next release tag.

(Final invariant numbering assigned at constitution update time; `hive-sync` reconciles per the ADR-0044 pattern.)

### Operational Consequences

- **PagerDuty Starter is a new recurring cost** (~$21–25/month). Fits within ADR-0052's cost-discipline envelope. The cost is named in the budget alert routing as an exempt category — paging tooling itself doesn't fire its own budget alerts.
- **Atlassian Statuspage Starter** ($29/month) is a recommended-but-deferred adoption. The v0 fallback (static page in Studios.HoneyDrunk.com) is acceptable until the first paying tenant exists; the Starter tier adopts at first paying-tenant onboarding.
- **The 09:00–21:00 ET coverage window is binding.** Operator schedule planning (vacation, focus blocks, deep-work periods) must account for paging within the window. Outside-window pages still fire but are best-effort; the operator is not bound to wake up.
- **The companion-app push integration (D3 primary path) is initial work.** v0 may use SMS via Notify if the companion app isn't ready; the trade-off is slightly higher delivery latency for v0.
- **The incident-record template enforces discipline.** During a real SEV-1, the operator is typing into the timeline as events happen. This is a non-trivial cognitive load; the alternative (reconstruct after the fact) loses fidelity. The discipline is judged worth the load.
- **The 5-business-day post-mortem SLA is a real commitment.** Skipping post-mortems is the failure mode of all on-call systems; building the deadline in as an invariant (not a guideline) is the protection.
- **Game days take time** (estimated 4–8 hours per quarter for prep, exercise, and post-mortem). Calendared as a fixed obligation, not optional.
- **The blast-radius rules in `constitution/sector-interaction-map.md` are the input to severity defaults.** When that map updates, the D4 routing table updates with it.
- **The honesty constraint (D13) constrains sales conversations.** This is a feature; the alternative is operationally-disastrous commitments.

### Follow-up Work

- Implement the PagerDuty integration: account creation, escalation policy, webhook configuration.
- Wire App Insights alerts (ADR-0040) to PagerDuty per the D4 routing table.
- Wire `IErrorReporter` captures (ADR-0045) to PagerDuty per the D4 routing table.
- Wire Azure Monitor budget alerts (ADR-0052) to PagerDuty per the D4 routing table.
- Wire canary failure alerts (ADR-0012) to PagerDuty per the D4 routing table.
- Build the Notify-side companion-app push integration (or commit v0 SMS fallback).
- Build the Pulse synthetic paging-path probe (D3).
- Create `repos/{node}/runbooks/` directories and the minimum file set per D10 across all deployable Nodes.
- Author the D7 incident-record template as a generator in `HoneyDrunk.Actions`.
- Author the D8 post-mortem template as a generator in `HoneyDrunk.Actions`.
- Author tenant-email templates per D9 in Communications.
- Schedule first game day for 30 days post-acceptance per D11.
- Cross-link this ADR from PDR-0002 (Notify Cloud GA) as a release prerequisite.
- Update Notify Cloud's draft SLA language per D2.
- Add the `hive-sync` checks for: incident-record / PagerDuty diff; post-mortem deadline tracking; runbook freshness; runbook minimum-set compliance.
- Update operator-agent (ADR-0018) prompt template to consult per-Node runbooks during incident mitigation.

## Alternatives Considered

### No formal incident process — handle ad hoc

The status quo. Considered as the explicit alternative. **Rejected** because:

- Customer trust requires demonstrable process. A tenant asking "what happens when you go down?" deserves a documented answer, and "we'll figure it out" is not credible at the price points Notify Cloud will charge.
- Process emerges anyway under load; ad-hoc-emerged process is invariably worse than ahead-of-time-designed process because it's invented during a SEV-1 when cognition is already at the limit.
- `generated/incidents/` already exists as a slot waiting for a contract; leaving it unfilled is choosing chaos with extra steps.
- Post-mortems do not happen without a binding cadence; lessons compound into the same incident recurring.

### Adopt standard SRE on-call model wholesale

Considered. The Google SRE book and PagerDuty's reference materials describe a mature on-call discipline that has been refined across thousands of organizations. **Rejected** because the model's load-bearing assumption — multi-person rotation with primary, secondary, and follow-the-sun coverage — does not transfer to a one-person studio. Adopting the SRE vocabulary while violating its preconditions produces a runbook that visibly diverges from reality during the first real incident, which is the credibility failure mode this ADR exists to prevent.

The honest answer is to **adapt** the SRE patterns to the one-person constraint: severity taxonomy yes, post-mortem cadence yes, runbook discipline yes; primary/secondary escalation no, follow-the-sun no, 24/7 coverage no. This is the chosen path.

### Single-vendor paging (PagerDuty only, no Notify path)

Considered. PagerDuty alone is sufficient for paging in steady state. **Rejected** because the failure mode "Notify is itself down and so the Grid's primary alerting path is down" is undetectable without an external check, and the external check needs its own delivery path. PagerDuty plus Notify provides the redundant paths; either alone is a single point of failure for paging itself.

### Single-vendor paging (Notify only, no PagerDuty)

Considered. Cheapest option. Notify already exists. **Rejected** because Notify-is-down is the failure mode that loses the alert. The operator cannot ack a page they didn't receive because the failing system was responsible for delivering it. PagerDuty's external delivery via SMS + phone call survives a full Grid outage.

### OpsGenie instead of PagerDuty

Considered. Atlassian-bundled, similar feature set, comparable pricing. **Rejected** on continuity — PagerDuty has the larger ecosystem of pre-built integrations with the tools the Grid already uses (Azure Monitor, GitHub, Stripe webhooks). The integration cost over the next 12 months is the deciding factor; switching cost later is low if the calculus changes.

### Free PagerDuty tier only

Considered. PagerDuty's free tier supports basic paging. **Rejected** for SEV-1 use because the free tier lacks SMS reliability guarantees and phone-call escalation that survive cellular network glitches. The $21–25/month Starter tier delivers the reliability needed for paying-tenant SLAs.

### Skip post-mortems for SEV-2 incidents

Considered. SEV-2 incidents are by definition not catastrophic; the argument is that post-mortem overhead on every SEV-2 is disproportionate. **Rejected** because SEV-2 incidents are where pattern-matching across incidents catches the boundary-failure trends that prevent the next SEV-1. Treating SEV-2 as "didn't matter much, no review needed" loses the highest-leverage learning signal. SEV-3 is the cutoff because by SEV-3 the impact is too localized to support pattern-matching value.

### Pages outside coverage hours for SEV-2

Considered. The argument: SEV-2 still matters; paging the operator at 3 AM is the price of running production. **Rejected** because the SEV-2 / SEV-1 boundary already captures the distinction "wake me up vs not." SEV-1 wakes the operator (best-effort, per D2); SEV-2 outside hours is logged for morning triage but does not wake. The trade-off is explicit in the published SLA. Tightening this requires the D12 trigger (second human).

### Self-host the paging path (no external vendor)

Considered. Some open-source paging tools exist (e.g., Karma, Alertmanager + custom delivery). **Rejected** because self-hosting the paging path means the paging path's reliability is one's own ops problem — exactly the recursion this ADR avoids. PagerDuty's reliability is their core product; we buy theirs rather than build our own.

### Adopt Atlassian Statuspage from day one regardless of paying-tenant status

Considered. Status pages are good practice even pre-customer. **Rejected** on cost discipline (ADR-0052) — $29/month for a status page with no audience to consume it is poor ROI. The v0 fallback (static page in Studios.HoneyDrunk.com) is acceptable until the first paying tenant exists; the upgrade to Statuspage Starter happens at first onboarding, which is the moment the surface earns its cost.

### Skip runbooks; rely on the operator agent (ADR-0018) to generate mitigations on the fly

Considered. The operator agent is capable of suggesting mitigations without pre-authored runbooks. **Rejected** because:

- Agent suggestion quality is directly downstream of context quality; runbooks are concentrated, vetted context that improves suggestions materially.
- Runbooks are the artifact that game days (D11) and post-mortems (D8) update; without them, the learning loop has nowhere to deposit findings.
- Runbooks are readable by humans, including a future second human (D12). Agent-only mitigation strategies don't transfer to human onboarding.

The runbook + operator agent combination is strictly better than either alone.

### Defer this ADR until the first paying tenant exists

Considered. The argument: incident response is over-engineering before there's any production traffic to respond to. **Rejected** because:

- The AI-sector standup wave is producing alert volume now (canary failures, error captures, budget alerts).
- The Notify Cloud GA work cannot ship without published SLAs, and SLAs cannot be published without this ADR's commitments behind them.
- Building the process during the first incident is the failure mode this ADR exists to prevent.
- The cost of acting now (one ADR, one PagerDuty subscription, a runbook discipline) is low; the cost of acting under fire is much higher.

### Promise 24/7 coverage despite being one person

Considered (or rather, considered-and-feared as the temptation under sales pressure). **Rejected categorically** per D13. Published commitments must match deliverable reality. The cost of breaking a 24/7 promise (one tenant churns, broadcasts to peers, the reputation damage compounds) exceeds the cost of not making it (some prospects walk; the ones who close are matched to actual capacity). The honesty constraint is load-bearing.
