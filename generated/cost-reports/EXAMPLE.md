<!-- EXAMPLE ONLY — not a real monthly report. Placeholder data illustrating the canonical format (schema_version 1). Real reports are named YYYY-MM.md and written by the Operator-side aggregator (ADR-0052 D9). -->

# Cost Report — EXAMPLE (illustrative, not a real month)

## Executive Summary

- **AI inference:** $487.10 of $500 soft cap (97%) — within bounds, no hard-cap breaches.
- **Azure infrastructure:** $214.45 of $300 soft cap (71%) — within bounds.
- **Third-party SaaS:** $182.00 of $200 soft cap (91%) — soft-only category, no kill-switch.
- **Domain / cert / registrar:** $0.00 of $25 soft cap (0%) — no renewals this month.
- **GitHub Actions:** $38.90 of $50 soft cap (78%) — within bounds.
- **Grid total:** $922.45 against a $1,075 soft-cap sum — solvent; one anomaly fired and was dismissed as a benign batch.

## Per-Category Actuals vs Caps

| Category | Month-To-Date | Soft Cap | Hard Cap | % of Soft | % of Hard | Threshold Pings Fired | Hard-Cap Breaches |
|---|---|---|---|---|---|---|---|
| AI inference | $487.10 | $500.00 | $1500.00 | 97% | 32% | 3 (50/75/90) | 0 |
| Azure infrastructure | $214.45 | $300.00 | $800.00 | 71% | 27% | 1 (50) | 0 |
| Third-party SaaS | $182.00 | $200.00 | — | 91% | — | 3 (50/75/90) | 0 |
| Domain / cert / registrar | $0.00 | $25.00 | — | 0% | — | 0 | 0 |
| GitHub Actions | $38.90 | $50.00 | $150.00 | 78% | 26% | 2 (50/75) | 0 |

## Per-Tenant Cost Breakdown

| Tenant | Month-To-Date | % of Grid Total | Top Category | Anomaly Events |
|---|---|---|---|---|
| `(platform-overhead)` | $846.20 | 91.7% | AI inference | 1 |
| `t_7f3a9c21` | $61.25 | 6.6% | AI inference | 0 |
| `t_19b8e004` | $15.00 | 1.6% | AI inference | 0 |
| `(other)` | $0.00 | 0.0% | — | 0 |

## Per-Agent Cost Breakdown

| Agent | Runs This Month | Month-To-Date | Cost Per Run | Top Provider |
|---|---|---|---|---|
| `scope` | 142 | $221.80 | $1.56 | anthropic |
| `review` | 318 | $178.40 | $0.56 | anthropic |
| `netrunner` | 44 | $58.10 | $1.32 | openai |
| `hive-sync` | 30 | $28.80 | $0.96 | anthropic |

## Override Log

| Issued At | Category | Operator | Reason | Duration | Disposition |
|---|---|---|---|---|---|
| 2026-04-18T14:22Z | ai_inference | oleg | investigating high burn, allow tier-1 traffic only for 2h | 2h | expired-naturally |

## Anomaly Events

| Fired At | Category | Type | Magnitude | Disposition |
|---|---|---|---|---|
| 2026-04-12T09:03Z | ai_inference | hour-over-hour | 6.1x hour-over-hour | false-positive |

## Trend Appendix

```
AI inference         ▂▃▃▄▄▅▅▆▆▇▇▇█
Azure infrastructure ▃▃▄▄▄▅▅▅▆▆▆▇▇
Third-party SaaS     ▅▅▅▆▆▆▆▆▇▇▇▇▇
Domain/cert          ▁▁█▁▁▁▁▁█▁▁▁▁
GitHub Actions       ▂▂▃▃▄▄▄▅▅▅▆▆▇
```
