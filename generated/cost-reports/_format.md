# Monthly Cost Report — Canonical Format

`schema_version: 1`

**Source:** ADR-0052 D9. Governs every `generated/cost-reports/YYYY-MM.md`.

## Purpose

The monthly cost report is the operator's **review surface** (the real-time control surface is the Operator Node "Cost" dashboard per ADR-0052 D9). Reports are committed to this repo so the historical record is git-tracked — git commit history is the cheapest audit trail, and a report that lives in git survives a vendor relationship changing.

Consumers: operator monthly review; future automated comparisons (this month vs last, this quarter vs last); incident retrospectives.

## Filename convention

- `YYYY-MM.md` — a real monthly report (e.g. `2026-05.md`), written by the runtime aggregator.
- `EXAMPLE*.md` — documentation examples only; never real data.
- `YYYY-MM.json` — **reserved** for the future structured-data sidecar (ADR-0052 Follow-up Work). Not created yet; the Markdown surface is canonical for humans, the JSON for tools.

## Aggregator

The runtime aggregator that writes these files lives in `HoneyDrunk.Operator` and runs on the 1st of each month, writing the prior month's report. **Until the Operator Node is scaffolded (ADR-0018), reports may be authored manually** by the operator using this format. See packet 09 of the `adr-0052-cost-governance` initiative (the rollout playbook) for the gating.

## Section ordering (fixed)

The seven sections appear in this order with these **stable level-2 headings** — do not reorder or rename; future parsing depends on the anchors:

1. `## Executive Summary`
2. `## Per-Category Actuals vs Caps`
3. `## Per-Tenant Cost Breakdown`
4. `## Per-Agent Cost Breakdown`
5. `## Override Log`
6. `## Anomaly Events`
7. `## Trend Appendix`

## Table column specs

Money values are USD with a `$` prefix and two decimals.

**Per-Category Actuals vs Caps:** `Category` | `Month-To-Date` | `Soft Cap` | `Hard Cap` | `% of Soft` | `% of Hard` | `Threshold Pings Fired` | `Hard-Cap Breaches`

**Per-Tenant Cost Breakdown:** `Tenant` | `Month-To-Date` | `% of Grid Total` | `Top Category` | `Anomaly Events`. Top 25 by cost descending, plus an aggregating `(other)` row. `Tenant` is the opaque tenant id (ADR-0026) — never an email, never a customer-facing name. Studio-internal / Grid-overhead events roll up as `(platform-overhead)`.

**Per-Agent Cost Breakdown** (AI inference category only): `Agent` | `Runs This Month` | `Month-To-Date` | `Cost Per Run` | `Top Provider`. Sorted by `Month-To-Date` descending.

**Override Log:** `Issued At` | `Category` | `Operator` | `Reason` | `Duration` | `Disposition` (`expired-naturally` / `revoked-early`).

**Anomaly Events:** `Fired At` | `Category` | `Type` (`hour-over-hour` / `day-over-day` / `per-tenant` / `per-agent`) | `Magnitude` (e.g. `8.2x hour-over-hour`) | `Disposition` (`false-positive` / `real-event` / `pending-review`).

**Trend Appendix:** one ASCII sparkline per category over the trailing 13 months, using the Unicode block set `▁▂▃▄▅▆▇█` (renders reliably in GitHub Markdown).

## Versioning

This format is versioned via the `schema_version` line at the top. Future format changes increment it explicitly so parsers can branch on the version.
