# Notify — Alert Routing Runbook

**Source decision:** [ADR-0054](../../../adrs/ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) D10 (per-deployable-Node runbook discipline) is the canonical owner of this runbook's full content. The complete tenant-facing alert-routing procedure lands separately under that decision's scope; this file currently carries the operator-vs-tenant boundary statement plus the cross-link below.

## Operator-internal vs tenant-facing boundary

> **This runbook covers tenant-facing alert routing.** Operator-internal alerts (CI failures, agent activity, security signals, hive-sync drift, deploy events, NuGet publishes, credential-rotation escalations, budget alerts, internal-Grid error spikes) flow via Discord per [ADR-0084](../../../adrs/ADR-0084-discord-operator-alerts-surface.md), not via Notify + PagerDuty. The two surfaces are siblings:
>
> - **Notify + PagerDuty** (this runbook): paying-tenant SEV-1 / SEV-2 incident escalation per [ADR-0054](../../../adrs/ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) D4. Phone + SMS + push to the on-call operator.
> - **Discord** ([ADR-0084](../../../adrs/ADR-0084-discord-operator-alerts-surface.md)): operator-internal day-to-day operational pager. Glanceable, categorized, mobile-and-desktop, shared-timeline.
>
> High-severity events MAY mirror across both surfaces — ADR-0084 D6 specifies which Critical-severity rows post to multiple channels including `#audit-sensitive`. The Notify + PagerDuty path is NOT replaced by Discord; both are mandatory for their respective scope. If a tenant-facing event is observed only in Discord and not in PagerDuty, that is a routing bug per the runbook in this repo, not a redirection of the canonical surface.
