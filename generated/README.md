# `generated/`

Auto-generated and tool-written artifacts for the HoneyDrunk Grid. Files here are produced by Grid automation and agents; manual edits are reserved for the operator.

Contents:

- `issue-packets/` — scoped work packets (the `scope` agent writes these; `file-packets` files them as issues).
- `cost-reports/` — monthly cost reports per ADR-0052 D9. `_format.md` is the canonical format spec; `YYYY-MM.md` files are written by the Operator-side aggregator (gated on the ADR-0018 standup), or authored manually against the spec in the interim.
- `coverage-maps/` — decision-to-implementation traceability maps written by backlog-generation or reconciliation agents when an accepted ADR/PDR is broad enough that duplicate packet generation is a risk.
- Other generated surfaces (ADR drafts, incident records, post-merge audits, drift reports) land here as their owning agents come online.
