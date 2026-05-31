# Alert Routing

**Source ADR:** [ADR-0084](../adrs/ADR-0084-discord-operator-alerts-surface.md) (Discord as the Canonical Operator-Alerts Surface).

## What this document is

This is the **operational reference copy** of [ADR-0084](../adrs/ADR-0084-discord-operator-alerts-surface.md) D6's alert-routing table — the live working surface every emitter and agent references for "which channel and severity does this alert route to."

It exists separately from the ADR for two reasons:

1. **Emitters and agents reference a live document, not an ADR section.** Citing an ADR section from a workflow, helper script, or agent prompt is friction-inducing, and ADRs are append-only-by-discipline. This file is the surface those consumers point at.
2. **Onboarding edits land here, not in the ADR.** Per [ADR-0084](../adrs/ADR-0084-discord-operator-alerts-surface.md) D10, new alert sources are added to **this file** with a cross-reference back to the ADR — not to the ADR's D6 table by amendment.

**The ADR-0084 D6 table is the committed-shape snapshot; this file is the live working surface.** The two are kept in sync by a `hive-sync` drift check (per [ADR-0014](../adrs/ADR-0014-hive-architecture-reconciliation-agent.md)) that diffs this file against ADR-0084 D6 and reports any divergence to `#hive-activity` — the same treatment [ADR-0054](../adrs/ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) D4's routing table receives. If the two diverge, hive-sync surfaces it as a finding.

**ADR-0084 is the governing decision.** A future onboarding packet that needs to add or change a routing rule edits **this file** (per ADR-0084 D10), not the ADR's D6 table. Do not edit the ADR's D6 table to land new sources — that table is the committed-shape snapshot, and editing it instead of this file is what the hive-sync drift check exists to catch.

## Routing table

This table pins the v1 routing for every alert source. The columns are `Event source | Destination channel | Severity | Format hint`, copied verbatim from [ADR-0084](../adrs/ADR-0084-discord-operator-alerts-surface.md) D6. Severity is advisory at v1, not enforced (Info / Medium / High / Critical).

| Event source | Destination channel | Severity | Format hint |
|---|---|---|---|
| CI failure on `main` (any workflow) | `#ops-alerts` | High | `❌ {repo} / {workflow}: {commit-short} — {link-to-run}` |
| Deploy success ([ADR-0033](../adrs/ADR-0033-environment-gated-deploy-trigger-model.md)) | `#release` | Info | `🚀 {node} {tag} → {env} ({duration})` |
| Deploy failure ([ADR-0033](../adrs/ADR-0033-environment-gated-deploy-trigger-model.md)) | `#ops-alerts` + `#release` | High | `🔥 {node} {tag} → {env} FAILED — {link-to-run}` |
| NuGet publish success ([ADR-0034](../adrs/ADR-0034-public-package-distribution-and-nuget-policy.md)) | `#release` | Info | `📦 {package} {version} published to nuget.org` |
| NuGet publish failure ([ADR-0034](../adrs/ADR-0034-public-package-distribution-and-nuget-policy.md)) | `#ops-alerts` + `#release` | High | `📦❌ {package} {version} publish failed — {link-to-run}` |
| Scheduled workflow failure (cron) | `#ops-alerts` | Medium | `🕒❌ {workflow} ({schedule}) — {link-to-run}` |
| Credential rotation escalation T-30 ([ADR-0083](../adrs/ADR-0083-external-saas-credential-rotation.md)) | `#ops-alerts` | Medium | `🔑 {credential} expires in 30 days — {rotation-walkthrough-link}` |
| Credential rotation escalation T-7 ([ADR-0083](../adrs/ADR-0083-external-saas-credential-rotation.md)) | `#ops-alerts` + `#security-alerts` | High | `🔑⚠️ {credential} expires in 7 days — {rotation-walkthrough-link}` |
| Credential rotation T+0 (expired) ([ADR-0083](../adrs/ADR-0083-external-saas-credential-rotation.md)) | `#security-alerts` + `#audit-sensitive` | Critical | `🔑🔥 {credential} EXPIRED — {incident-record-link}` |
| [ADR-0044](../adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) review verdict (Approve / Request Changes / Comment) | `#agent-activity` | Info | `🐝 review on {repo}#{pr}: {verdict} — {pr-link}` |
| [ADR-0046](../adrs/ADR-0046-specialist-review-agents.md) specialist invocation | `#agent-activity` | Info | `🎯 {specialist} on {repo}#{pr}: {verdict} — {pr-link}` |
| [ADR-0014](../adrs/ADR-0014-hive-architecture-reconciliation-agent.md) hive-sync drift finding | `#hive-activity` | Medium | `🔄 hive-sync: {finding-summary} — {issue-link}` |
| Packet lifecycle transition (`active/` → `completed/`) | `#hive-activity` | Info | `✅ {packet-slug} completed — {issue-link}` |
| PR opened | `#hive-activity` | Info | `🆕 {repo}#{pr}: {title} — {pr-link}` |
| PR merged | `#hive-activity` | Info | `✔️ {repo}#{pr} merged — {pr-link}` |
| GitHub Dependabot / CodeQL High+ alert | `#security-alerts` | High | `🛡️ {repo}: {alert-summary} — {alert-link}` |
| GitHub secret-scanning hit | `#security-alerts` + `#audit-sensitive` | Critical | `🛡️🔥 secret detected in {repo} — {alert-link}` (no value) |
| SonarCloud quality gate failure (main or PR) | `#security-alerts` | Medium | `📊 SonarCloud gate failed on {repo}#{pr-or-main} — {link}` |
| CodeRabbit P0/P1 finding ([ADR-0079](../adrs/ADR-0079-multi-perspective-pr-review-stack.md)) | `#security-alerts` | High | `🐰 CodeRabbit {severity} on {repo}#{pr} — {pr-link}` |
| Azure budget 50% threshold ([ADR-0052](../adrs/ADR-0052-cost-governance-budget-alerts-and-kill-switches.md)) | `#ops-alerts` | Info | `💰 budget at 50% ({category}, ${spend}/${cap})` |
| Azure budget 75% threshold ([ADR-0052](../adrs/ADR-0052-cost-governance-budget-alerts-and-kill-switches.md)) | `#ops-alerts` | Medium | `💰 budget at 75% ({category})` |
| Azure budget 90% / 100% threshold ([ADR-0052](../adrs/ADR-0052-cost-governance-budget-alerts-and-kill-switches.md)) | `#ops-alerts` + `#security-alerts` | Critical | `💰🔥 budget at {pct}% ({category}) — kill-switch posture: {posture}` |
| App Insights internal-Grid error spike ([ADR-0045](../adrs/ADR-0045-grid-wide-error-tracking.md)) | `#ops-alerts` | High | `🐞 {node}: {error-fingerprint} firing {rate}/h — {link}` |
| Grid Health aggregator drift ([ADR-0012](../adrs/ADR-0012-grid-cicd-control-plane.md) D6) | `#ops-alerts` | Medium | `🕸️ grid-health: {drift-summary} — {issue-link}` |
| Operator-authored announcement | `#announcements` | n/a | Human-written |

**Severity is advisory at v1, not enforced.** It exists to give the operator a glance-level disposition (Info / Medium / High / Critical) and to give a future filtering layer a hook. v1 does not implement Discord role-mentions per severity.

**Tenant-facing incident pages** ([ADR-0054](../adrs/ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) D4) continue to route via Notify + PagerDuty as that ADR pins. Discord may receive a *mirror* of the same alert via the App Insights or Grid-Health rows above (so the operator sees the page land in two surfaces), but Discord is **not** a substitute for the PagerDuty escalation path for paying-tenant SEV-1/SEV-2 events. ADR-0054 is the canonical surface for tenant-facing incidents; ADR-0084 is the canonical surface for operator-internal day-to-day.

## How to add a new alert source

Per [ADR-0084](../adrs/ADR-0084-discord-operator-alerts-surface.md) D10's onboarding hook, when a new alert source is introduced anywhere in the Grid (new CI job, new scheduled workflow, new Node emitting operational events, new agent firing a non-PR-comment signal), the packet introducing it must:

1. **Add a row to the routing table above** — `Event source | Destination channel | Severity | Format hint`. The destination channel is one of the seven from ADR-0084 D2 (`#ops-alerts`, `#security-alerts`, `#agent-activity`, `#hive-activity`, `#release`, `#announcements`, `#audit-sensitive`); the severity is one of Info / Medium / High / Critical. Edit **this file**, not the ADR-0084 D6 table.
2. **Pass the specific `channel` and `severity` inputs** the source will use through `job-discord-notify.yml` in HoneyDrunk.Actions (per [ADR-0084](../adrs/ADR-0084-discord-operator-alerts-surface.md) D9) — the reusable workflow is the single Grid-side seam for GitHub-Actions emitters; emitters outside Actions use the `infrastructure/scripts/discord-notify.ps1` helper that mirrors the same contract. Ad-hoc `curl` to a webhook URL outside the workflow / helper is forbidden.
3. **Declare a volume estimate** (messages-per-day projection). If the source is projected to emit **more than 50 messages per day** on average, declare an explicit suppression rule — a per-source severity floor, a duplicate-suppression rule, or both — per [ADR-0084](../adrs/ADR-0084-discord-operator-alerts-surface.md) D8. Alert fatigue is the failure mode that makes a pager useless; pre-emptive volume budgeting prevents it.

This onboarding hook is also attached to the Node-standup procedure as the **Operator-alert routing** step (per [`constitution/node-standup.md`](./node-standup.md)), parallel to the ADR-0083 D6 external-credential-onboarding step. Any Node standup that introduces a new operational event surface runs that step before the source enters CI.
