# Audit Reports

ADR-0043 tactical source reports land here.

The `backlog-tactical-audit` runner job writes one report per audited Node:

```text
generated/audits/{node}-{YYYY-MM-DD}.md
```

Audit reports are durable evidence that a Node was reviewed. They may exist even when no work item is created. Actionable findings become proposed packets under `generated/work-items/proposed/` with `source: tactical` and `generator: node-audit`.
