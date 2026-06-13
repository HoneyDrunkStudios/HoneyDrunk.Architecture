---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-3", "ops", "docs", "adr-0052", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0052"]
accepts: ["ADR-0052"]
wave: 1
initiative: adr-0052-cost-governance
node: honeydrunk-architecture
---

# Create generated/cost-reports/ with the canonical monthly report format spec

## Summary
Create the `generated/cost-reports/` directory with `_format.md` documenting the canonical monthly cost-report shape per ADR-0052 D9, plus a placeholder `YYYY-MM.md` example showing every required section. Document that the runtime aggregator that auto-generates these reports is gated on ADR-0018 (Operator standup) and named in the rollout playbook (packet 09). This packet ships the format spec ahead of the aggregator so the operator can author the first manual report against a known shape if needed.

## Context
ADR-0052 D9 commits two reporting surfaces:
- **Operator Node "Cost" dashboard** — real-time control surface, lives in `HoneyDrunk.Operator` per ADR-0018 (Proposed; not yet scaffolded).
- **Architecture repo — `generated/cost-reports/YYYY-MM.md`** — monthly auto-generated review surface, committed to git so the historical record is git-tracked.

The auto-generation aggregator runs on the 1st of each month and writes the prior month's report. The aggregator itself lives in the Operator Node (D9, D13, D14 Phase 2) and waits on the ADR-0018 standup. **This packet ships the directory + format spec now** so:
- The runtime aggregator (future) has a canonical shape to write against.
- The operator can author a first manual report against the known shape if the aggregator is delayed.
- The git-tracked historical record begins from a stable shape — future automated comparisons (this month vs last, this Q vs last Q) can parse the canonical sections via heading anchors without bespoke logic.

ADR-0052 D9 specifies the report contents as **canonical sections**:
1. Executive summary — single sentence per category; single sentence for the Grid total.
2. Per-category actuals vs caps table — month-to-date, soft cap, hard cap, % of soft, % of hard, count of threshold pings fired, count of hard-cap breaches.
3. Per-tenant cost breakdown — top 25 with an "other" row aggregating the rest.
4. Per-agent cost breakdown (AI inference only) — sorted by cost descending; includes `cost per run` and `runs this month`.
5. Override log — every override with operator, reason, duration, expired-naturally-or-revoked.
6. Anomaly events — every anomaly that fired with category, magnitude, disposition.
7. Trend appendix — sparkline-style ASCII per category for the trailing 13 months.

The format is **human-first** — Markdown that reads naturally in a code review and renders cleanly on GitHub. Machine consumers parse the canonical sections via heading anchors. A future structured JSON sidecar (`YYYY-MM.json`) is named as follow-up work in ADR-0052's Follow-up Work list; this packet does not create the sidecar but reserves the file-naming convention.

**Why commit the report to the Architecture repo (D9):** the repo is the historical record of the Grid; git commit history is the cheapest audit trail. A cost report that lives in an external dashboard is a cost report that disappears when the vendor relationship changes; a cost report that lives in git survives. The added storage cost is trivial (single-digit KB per month).

**No runtime aggregator in this packet.** The aggregator is named in the playbook (packet 09) and gated on ADR-0018 (Operator standup) + Wave-4 ledger landing (packets 05/06). This packet's deliverable is purely the directory + format spec + a worked example.

## Scope
- `generated/cost-reports/` — new directory.
- `generated/cost-reports/_format.md` — the canonical format specification.
- `generated/cost-reports/EXAMPLE-YYYY-MM.md` (or named with a clearly-not-real date like `EXAMPLE.md`) — a worked example showing every section with placeholder data. The filename pattern documents the convention; the file is NOT a real report.
- `generated/README.md` — only if `generated/` does not yet exist as a documented directory; brief overview pointing at `cost-reports/`, `work-items/`, etc.

## Proposed Implementation
1. **Directory creation.** Create `generated/cost-reports/` if it does not exist. (`generated/` already exists from `work-items/`.) No special permissions; just a Markdown file under a new subdirectory.
2. **`_format.md`** — the canonical format spec. Sections:
   - **Purpose.** Why this file exists; consumers (operator review, future automated comparisons, audit retrospective).
   - **Filename convention.** `YYYY-MM.md` for real monthly reports; `EXAMPLE-*.md` for documentation examples. The runtime aggregator (future, packet 09) writes the real reports.
   - **Section ordering.** The seven D9 sections in fixed order. Future tooling depends on heading anchor stability — name them as the spec.
   - **Heading anchors.** Stable level-2 headings (`## Executive Summary`, `## Per-Category Actuals vs Caps`, `## Per-Tenant Cost Breakdown`, `## Per-Agent Cost Breakdown`, `## Override Log`, `## Anomaly Events`, `## Trend Appendix`). Do not reorder or rename; future parsing depends on them.
   - **Per-category table column spec.** Document the exact column set: `Category`, `Month-To-Date`, `Soft Cap`, `Hard Cap`, `% of Soft`, `% of Hard`, `Threshold Pings Fired`, `Hard-Cap Breaches`. Money values in USD with `$` prefix and two decimals.
   - **Per-tenant table column spec.** `Tenant`, `Month-To-Date`, `% of Grid Total`, `Top Category`, `Anomaly Events`. Top 25 + "other" aggregation row. The `Tenant` column carries the opaque tenant id (ADR-0026) — never an email, never a customer-facing name. For Studio-internal / Grid-overhead events, the row is `(platform-overhead)`.
   - **Per-agent table column spec.** `Agent`, `Runs This Month`, `Month-To-Date`, `Cost Per Run`, `Top Provider`. Sorted by `Month-To-Date` descending. Applies to AI inference category only.
   - **Override log table column spec.** `Issued At`, `Category`, `Operator`, `Reason`, `Duration`, `Disposition` (`expired-naturally` / `revoked-early`).
   - **Anomaly events table column spec.** `Fired At`, `Category`, `Type` (`hour-over-hour` / `day-over-day` / `per-tenant` / `per-agent`), `Magnitude` (e.g., `8.2x hour-over-hour`), `Disposition` (`false-positive` / `real-event` / `pending-review`).
   - **Trend appendix.** ASCII sparklines (one line per category) of the trailing 13 months. Document the sparkline character set (`▁▂▃▄▅▆▇█` or whatever Unicode block characters render reliably in GitHub Markdown).
   - **Versioning.** The format itself is versioned: `_format.md` includes a `schema_version: 1` line at the top so future format changes are explicit.
   - **JSON sidecar (future).** Reserve `YYYY-MM.json` as the future structured-data sidecar; ADR-0052's Follow-up Work names it. Not created in this packet.
   - **Aggregator pointer.** "The runtime aggregator that writes these files lives in `HoneyDrunk.Operator` and runs on the 1st of each month. Until the Operator Node is scaffolded (ADR-0018), reports may be authored manually by the operator using this format. See packet 09 of the `adr-0052-cost-governance` initiative."
3. **`EXAMPLE.md` (or named `EXAMPLE-2026-04.md` or similar — pick a clearly non-future date so the file is unambiguous).** A worked example carrying every section with placeholder data. The example should be **plausibly shaped** — the AI inference category at $487 of $500 soft cap (consistent with the D2 narrative), one tenant overhead, one agent (`scope`) as the top spender, one override (a hypothetical investigative override that expired), one anomaly (a hour-over-hour spike that was a false-positive batch). The example renders cleanly in GitHub Markdown and uses every column.
4. **`generated/README.md`** — only if the directory does not already have one. Brief: the directory holds auto-generated artifacts (work items, cost reports, future ADR drift reports). Editing manually is reserved for the operator; the rest is tool-written.

## Affected Files
- `generated/cost-reports/_format.md` (new)
- `generated/cost-reports/EXAMPLE.md` (or named with a clearly non-real date — new)
- `generated/README.md` (new — only if not already present)
- Repo-level `CHANGELOG.md`

## NuGet Dependencies
None. Markdown only.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. The `generated/cost-reports/` directory is an Architecture-repo concern (the historical-record / git-as-audit-trail decision in D9).
- [x] No code change in any other repo.
- [x] No runtime aggregator in this packet — that is gated on the ADR-0018 Operator standup and named in packet 09.

## Acceptance Criteria
- [ ] `generated/cost-reports/_format.md` exists with the seven D9 canonical sections specified, heading anchors documented as stable, per-table column specs nailed down (per-category, per-tenant, per-agent, override log, anomaly events)
- [ ] `_format.md` carries `schema_version: 1` and reserves `YYYY-MM.json` as the future structured-data sidecar (not created here)
- [ ] `_format.md` points at the future runtime aggregator in `HoneyDrunk.Operator` and notes that until ADR-0018 standup, reports may be authored manually
- [ ] An `EXAMPLE.md` (or unambiguously-non-real-date file) shows every section populated with plausible placeholder data, renders cleanly in GitHub Markdown
- [ ] If `generated/` did not have a README, one was created
- [ ] Repo-level `CHANGELOG.md` carries an entry naming the new directory and format spec
- [ ] No code change; no .NET project; no edit to the catalog or budget config

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0052 D9 — Reporting surfaces.** Two surfaces: the Operator Node "Cost" dashboard (real-time control) and `generated/cost-reports/YYYY-MM.md` (monthly review surface in the Architecture repo). Both read from the same Cosmos ledger; neither is a separate accounting system. The cost-report format is canonical so future automated comparisons parse it without bespoke logic. Format lives in `generated/cost-reports/_format.md`.

**ADR-0052 D9 report contents (canonical sections).** Executive summary; per-category actuals vs caps; per-tenant; per-agent; override log; anomaly events; trend appendix. Human-first Markdown. Machine consumers parse via heading anchors. Structured JSON sidecar (`YYYY-MM.json`) reserved as follow-up.

**ADR-0052 Follow-up Work — Canonical JSON sidecar for machine consumers.** Named as follow-up; this packet reserves the filename convention but does not create the sidecar.

**ADR-0052 D5 — `TenantId` as opaque identifier.** The per-tenant table uses the opaque tenant id (ADR-0026) — never an email, never a customer-facing name.

## Constraints
- **No runtime aggregator in this packet.** Aggregator code lives in `HoneyDrunk.Operator` and is gated on ADR-0018; named in packet 09.
- **Stable heading anchors.** Once `_format.md` ships, the level-2 heading text is part of the spec; renames break future tooling. Document this expectation in the spec.
- **Schema versioning.** The format is versioned via `schema_version: 1`; future changes increment the version explicitly.
- **No real cost data in the example file.** The example uses plausible placeholder data; it is not a real monthly report.

## Labels
`feature`, `tier-3`, `ops`, `docs`, `adr-0052`, `wave-1`

## Agent Handoff

**Objective:** Create `generated/cost-reports/` with the canonical monthly report format spec (`_format.md`) and a worked example, so the future runtime aggregator (gated on ADR-0018 Operator standup) has a canonical shape to write against and the operator can author a first manual report against the spec if needed.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Ship the canonical report format ahead of the runtime aggregator, so the historical-record convention is established from the start.
- Feature: ADR-0052 Cost Governance rollout, Wave 1.
- ADRs: ADR-0052 D5/D9 (primary), ADR-0018 (Operator standup gates the aggregator), ADR-0026 (`TenantId` opaque primitive).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0052 should be Accepted before the report directory is committed.

**Constraints:**
- No runtime aggregator code; that is packet 09 (and gated on ADR-0018).
- Stable heading anchors; document the expectation.
- Example uses plausible placeholder data, never real cost data.

**Key Files:**
- `generated/cost-reports/_format.md`
- `generated/cost-reports/EXAMPLE.md`
- `generated/README.md` (if missing)
- Repo-level `CHANGELOG.md`

**Contracts:** None. Documentation only.
