# Strategic Backlog Source - 2026-06-03

## Summary
- Decisions scanned: 31
- Decisions requiring packets: 1
- Proposed packets created: 1
- Dedupe skips: 27

## Decisions Scoped
- **ADR-0084**: Discord as the Canonical Operator-Alerts Surface -> [2026-06-03-architecture-reconcile-adr-0084-docs-sync-alert-routing-drift.md](../issue-packets/proposed/2026-06-03-architecture-reconcile-adr-0084-docs-sync-alert-routing-drift.md)

## Skipped
- **ADR-0001**: No new packet. The Node vs Service distinction is already reflected in terminology/catalog shape and no current drift signal names missing implementation.
- **ADR-0002**: No new packet. The Architecture-as-Agent-HQ decision is already the operating model for this repo and no current drift signal names missing implementation.
- **ADR-0003**: Dedupe skip. Existing packet coverage and downstream decisions cover the accepted Phase 1 direction; no new missing work item was identified.
- **ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011, ADR-0012, ADR-0014, ADR-0015, ADR-0016, ADR-0019, ADR-0026, ADR-0030, ADR-0031, ADR-0033, ADR-0043, ADR-0044, ADR-0047, ADR-0052, ADR-0079, ADR-0080, ADR-0082, ADR-0083, ADR-0086, ADR-0088**: Dedupe skip. Existing proposed, active, or completed packet coverage already references the decision and no explicit current drift signal showed missing strategic packet coverage.
- **PDR-0001**: No new packet. The accepted HoneyHub platform direction is expressed through downstream ADRs for Observe and AI routing; no concrete uncovered single-repo work item was identified in this run.
- **Proposed decisions in `initiatives/proposed-adrs.md`**: Not scoped by this strategic pass because the job objective is accepted-decision implementation coverage. Several listed Proposed ADR/PDR items already have active packet coverage or need a separate stale-proposed-decision pass with `accepts:` semantics.

## Notes For Weekly Briefing
- ADR-0084 has one proposed Architecture packet to reconcile alert-routing drift semantics for the ADR-0085 docs-sync row.
- The Proposed ADR/PDR queue still contains stale decisions that may need a separate acceptance-gating scope pass; this run did not create `accepts:` packets for still-Proposed decisions.
