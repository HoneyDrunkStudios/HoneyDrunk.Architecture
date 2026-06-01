# Cost-Budgets Tuning Policy

**Source:** ADR-0052 D2, D11. Governs changes to [`cost-budgets.json`](./cost-budgets.json).

`cost-budgets.json` is **production-critical configuration**. A mis-edit can disable a kill-switch (a hard cap raised to infinity) or trigger a spurious shutdown (a hard cap dropped below current month-to-date). Treat every change to it as a production-config change.

## Two change paths — they never blur

| | Slow path (this file) | Fast path (override CLI) |
|---|---|---|
| **What** | Edit `cost-budgets.json` | `hd cost unlock <category> --reason "<text>" --duration <hours>` |
| **Surface** | Git + PR review | `HoneyDrunk.Operator` CLI (future — gated on ADR-0018 standup) |
| **Effect** | Mutates the **persistent** caps | Issues a **time-bounded** override; does **not** edit this file |
| **Audit trail** | The git history (the PR is the record) | An `IAuditLog` event per ADR-0030 (invariant 47), `sensitive=audit` tagged |
| **Use for** | Considered policy changes | Emergencies in flight |

The slow path is the **only** mechanism that mutates persistent caps. The fast path is for emergencies and is time-bounded by design.

## Rules

- **Direct database writes to `BudgetOverride` are forbidden** (invariant 106). The override CLI is the only sanctioned override path.
- **No permanent override exists.** Re-engagement after expiry is the safer default (ADR-0052 D11). If a higher cap is genuinely needed long-term, raise it here via PR — not via a standing override.
- **Cap-raise PRs must justify the change in the PR description.** The audit value is "the cap was raised on this date, by this PR, with this reasoning." A cap change without a stated reason is a documentation defect.
- **The `review` agent gates this file.** The `cost-config` review category (`.claude/agents/review.md`) treats edits here as production-config changes at `block` severity, checking: hard cap ≥ soft cap; a removed hard cap pairs with `kill_switch: "none"`; anomaly multipliers in band (hour-over-hour `[1.5, 20.0]`, day-over-day `[1.2, 10.0]`); dev-overlay caps smaller than prod; and a justification in the PR description.

## The Phase-1 multiplier is a different knob

This file carries the **D2 final-state** caps. ADR-0052 D14 Phase 1 runs intentionally loose ("$5000/$10000") so the kill-switch does not fire spuriously while baselines establish. That loosening is a **runtime multiplier in App Configuration** (`CostLedger:PhaseOneMultiplier:*`), not a different value in this file. The Phase-3 flip (multiplier -> 1) is operator-driven via App Configuration and is **out of this file's PR scope**. See ADR-0052 D14 and the `adr-0052-cost-governance` section in `initiatives/active-initiatives.md` for the flip narrative.

## Related

- [`operating-costs.md`](./operating-costs.md) — the descriptive operating-cost record this enforcement layer sits above.
- ADR-0052 — the governing decision record.
