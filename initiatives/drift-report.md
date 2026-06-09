# Hive Sync Drift Report

**Last Updated:** 2026-06-09

Fully rewritten by `hive-sync`; First Surfaced dates are sticky for persistent findings.

> **Run scope (2026-06-09):** This was a **local-file-only** pass — the `gh` CLI was
> unavailable, so no live GitHub issue/board/repo state could be queried. Categories that
> are deterministically computable from repo files were **recomputed this run**:
> **1** (invariants named in Accepted ADRs vs `constitution/invariants.md`),
> **2** (capability-matrix rows vs agent files),
> **3** (agent files vs capability-matrix rows),
> **5** (HoneyDrunk node names in Accepted ADRs vs `catalogs/nodes.json`).
> Category **4** (node GitHub repos that fail to resolve) **requires `gh repo view` and was
> NOT re-verified this run** — its prior findings are carried forward unverified below and a
> future live-`gh` pass owns re-confirming or clearing them. Categories **6, 12, 14, 15, 16**
> depend on live board state and/or `grid-health.json` reconciliation that this pass did not
> run; their prior findings are carried forward verbatim (with sticky First Surfaced dates)
> and are likewise owed a refresh by the next live-`gh` hive-sync pass.

---

## Recomputed this run (local-file)

### Category 1: invariants named in Accepted ADRs but missing from `constitution/invariants.md`

_None._ Every invariant number referenced in an Accepted ADR (including 53, 102, 103, 107, 108, 110, 111, 112) is defined in `constitution/invariants.md` (defined set: 1–53, 90–92, 99–115).

### Category 2: capability-matrix rows with no `.claude/agents/{name}.md` file

_None._ Every agent in `constitution/agent-capability-matrix.md` (scope, adr-composer, pdr-composer, netrunner, file-issues, review, node-audit, refine, site-sync, hive-sync, docs-sync) has a matching file in `.claude/agents/`.

### Category 3: agent files with no capability-matrix row

- **Item:** marketing-strategist
  - **First Surfaced:** 2026-05-30
  - **Detail:** `.claude/agents/marketing-strategist.md` exists without a capability matrix row. (`product-strategist.md` also lacks a row but is on the intentional meta-agent exclusion list; `marketing-strategist` is not, so it remains a finding.)

### Category 5: HoneyDrunk node names in Accepted ADRs missing from `catalogs/nodes.json`

_None._ Both `HoneyDrunk.Infrastructure` (named in ADR-0077, Accepted/amended) and `HoneyDrunk.HoneyHub` (named in ADR-0091/0092/0093, Accepted) are now present in `catalogs/nodes.json`, so neither surfaces. All other `HoneyDrunk.*` names appearing in Accepted ADR text are deliberate false positives and were excluded:

  - `HoneyDrunk.Billing` (ADR-0037/0052) — explicitly a *future* Node, not yet committed; correctly absent.
  - `HoneyDrunk.CostLedger` (ADR-0052) — *future* promotion-path Node ("not created at v1"); correctly absent.
  - `HoneyDrunk.Tenancy` / `HoneyDrunk.Tenancy.Abstractions` (ADR-0026) — explicitly a **rejected** alternative.
  - `HoneyDrunk.OperatorBus` (ADR-0084) — explicitly a **rejected** alternative.
  - `HoneyDrunk.CIConfig` (ADR-0012) — explicitly a **rejected** alternative.
  - `HoneyDrunk.Web` / `HoneyDrunk.Web.UI` (ADR-0091/0071) — placeholder name **rejected** in favor of `HoneyDrunk.HoneyHub`; `HoneyDrunk.Web.UI` is governed by the still-**Proposed** ADR-0071.
  - `HoneyDrunk.Prompts` (ADR-0064, referenced in Accepted ADR-0082's class table) — governed by the still-**Proposed** ADR-0064; correctly absent until that ADR is Accepted.
  - `HoneyDrunk.Telemetry.OpenTelemetry`, `*.Tests`, `*.Abstractions`, `*.slnx`, etc. — file paths / sub-package artifacts, not standalone Nodes.

---

## Carried forward — NOT re-verified this run (needs live `gh`)

### Category 4: node GitHub repo missing

> _Carried forward unverified from the 2026-06-05 report. `gh repo view` was unavailable this
> run; a future live-`gh` pass owns re-confirming or clearing each entry._

- **Item:** HoneyDrunk.Evals
  - **First Surfaced:** 2026-05-25
  - **Detail:** `gh repo view` could not resolve this repo (last checked prior run).
- **Item:** HoneyDrunk.Sim
  - **First Surfaced:** 2026-05-25
  - **Detail:** `gh repo view` could not resolve this repo (last checked prior run).
- **Item:** HoneyDrunk.Studios
  - **First Surfaced:** 2026-05-25
  - **Detail:** `gh repo view` could not resolve this repo (last checked prior run).

---

## Carried forward — live-state / grid-health categories (out of scope this run)

> _These categories depend on live board state and/or `grid-health.json` reconciliation that
> this local-file pass did not run. Preserved verbatim with sticky First Surfaced dates; owed
> a refresh by the next live-`gh` hive-sync pass._

- **Category 6: grid-health node missing from compatibility matrix**
  - **Item:** honeydrunk-actions
  - **First Surfaced:** 2026-05-25
  - **Detail:** Hive-sync does not auto-add compatibility rows.
- **Category 6: grid-health node missing from compatibility matrix**
  - **Item:** honeydrunk-agents
  - **First Surfaced:** 2026-05-25
  - **Detail:** Hive-sync does not auto-add compatibility rows.
- **Category 6: grid-health node missing from compatibility matrix**
  - **Item:** honeydrunk-ai
  - **First Surfaced:** 2026-05-25
  - **Detail:** Hive-sync does not auto-add compatibility rows.
- **Category 6: grid-health node missing from compatibility matrix**
  - **Item:** honeydrunk-architecture
  - **First Surfaced:** 2026-05-25
  - **Detail:** Hive-sync does not auto-add compatibility rows.
- **Category 6: grid-health node missing from compatibility matrix**
  - **Item:** honeydrunk-audit
  - **First Surfaced:** 2026-05-25
  - **Detail:** Hive-sync does not auto-add compatibility rows.
- **Category 6: grid-health node missing from compatibility matrix**
  - **Item:** honeydrunk-capabilities
  - **First Surfaced:** 2026-05-25
  - **Detail:** Hive-sync does not auto-add compatibility rows.
- **Category 6: grid-health node missing from compatibility matrix**
  - **Item:** honeydrunk-evals
  - **First Surfaced:** 2026-05-25
  - **Detail:** Hive-sync does not auto-add compatibility rows.
- **Category 6: grid-health node missing from compatibility matrix**
  - **Item:** honeydrunk-flow
  - **First Surfaced:** 2026-05-25
  - **Detail:** Hive-sync does not auto-add compatibility rows.
- **Category 6: grid-health node missing from compatibility matrix**
  - **Item:** honeydrunk-knowledge
  - **First Surfaced:** 2026-05-25
  - **Detail:** Hive-sync does not auto-add compatibility rows.
- **Category 6: grid-health node missing from compatibility matrix**
  - **Item:** honeydrunk-lore
  - **First Surfaced:** 2026-05-25
  - **Detail:** Hive-sync does not auto-add compatibility rows.
- **Category 6: grid-health node missing from compatibility matrix**
  - **Item:** honeydrunk-memory
  - **First Surfaced:** 2026-05-25
  - **Detail:** Hive-sync does not auto-add compatibility rows.
- **Category 6: grid-health node missing from compatibility matrix**
  - **Item:** honeydrunk-operator
  - **First Surfaced:** 2026-05-25
  - **Detail:** Hive-sync does not auto-add compatibility rows.
- **Category 6: grid-health node missing from compatibility matrix**
  - **Item:** honeydrunk-sim
  - **First Surfaced:** 2026-05-25
  - **Detail:** Hive-sync does not auto-add compatibility rows.
- **Category 6: grid-health node missing from compatibility matrix**
  - **Item:** honeydrunk-standards
  - **First Surfaced:** 2026-05-25
  - **Detail:** Hive-sync does not auto-add compatibility rows.
- **Category 6: grid-health node missing from compatibility matrix**
  - **Item:** honeydrunk-studios
  - **First Surfaced:** 2026-05-25
  - **Detail:** Hive-sync does not auto-add compatibility rows.
- **Category 12: unmapped or novel service status mapping**
  - **Item:** honeydrunk-pulse: mapped novel status blocked
  - **First Surfaced:** 2026-05-25
  - **Detail:** mapped novel status blocked
- **Category 14: current-focus drift**
  - **Item:** ADR-0015 focus row still shows incomplete rollout
  - **First Surfaced:** 2026-06-05
  - **Detail:** ADR-0015 is now 5/5 closed after Notify#3, Notify#4, and Pulse#3 closed on 2026-06-04; `current-focus.md` is netrunner-owned.
- **Category 14: current-focus drift**
  - **Item:** ADR-0033 focus row still marked Open
  - **First Surfaced:** 2026-06-03
  - **Detail:** ADR-0033 auto-flipped to Accepted and all three accepting packet issues are closed; `current-focus.md` is netrunner-owned.
- **Category 15: alert-routing-table drift**
  - **Item:** live-only: [ADR-0043](../adrs/ADR-0043-continuous-backlog-generation-strategy.md) opportunistic Scout backlog source run | `#hive-activity` | Info | `backlog-scout: {recommendation}, {packets-created} packets — {report-or-pr-link}`
  - **First Surfaced:** 2026-06-05
  - **Detail:** Row exists in `constitution/alert-routing.md` but not ADR-0084 D6.
- **Category 15: alert-routing-table drift**
  - **Item:** live-only: [ADR-0043](../adrs/ADR-0043-continuous-backlog-generation-strategy.md) strategic backlog source run | `#hive-activity` | Info | `backlog-strategic: {packets-created} proposed packets — {report-or-pr-link}`
  - **First Surfaced:** 2026-06-05
  - **Detail:** Row exists in `constitution/alert-routing.md` but not ADR-0084 D6.
- **Category 15: alert-routing-table drift**
  - **Item:** live-only: [ADR-0043](../adrs/ADR-0043-continuous-backlog-generation-strategy.md) tactical node-audit backlog source run | `#hive-activity` | Info | `backlog-tactical: {node} audit, {findings-count} findings, {packets-created} packets — {report-or-pr-link}`
  - **First Surfaced:** 2026-06-05
  - **Detail:** Row exists in `constitution/alert-routing.md` but not ADR-0084 D6.
- **Category 15: alert-routing-table drift**
  - **Item:** live-only: [ADR-0043](../adrs/ADR-0043-continuous-backlog-generation-strategy.md) urgent reactive operational packet | `#ops-alerts` | High | `backlog-urgent-ops: {summary} — {urgent-briefing-or-pr-link}`
  - **First Surfaced:** 2026-06-05
  - **Detail:** Row exists in `constitution/alert-routing.md` but not ADR-0084 D6.
- **Category 15: alert-routing-table drift**
  - **Item:** live-only: [ADR-0043](../adrs/ADR-0043-continuous-backlog-generation-strategy.md) urgent reactive security packet | `#security-alerts` | High | `backlog-urgent-security: {summary} — {urgent-briefing-or-pr-link}`
  - **First Surfaced:** 2026-06-05
  - **Detail:** Row exists in `constitution/alert-routing.md` but not ADR-0084 D6.
- **Category 15: alert-routing-table drift**
  - **Item:** live-only: [ADR-0043](../adrs/ADR-0043-continuous-backlog-generation-strategy.md) weekly backlog briefing generated | `#hive-activity` | Info | `backlog-briefing: {new-proposed-count} proposed, top-3 ready — {briefing-or-pr-link}`
  - **First Surfaced:** 2026-06-05
  - **Detail:** Row exists in `constitution/alert-routing.md` but not ADR-0084 D6.
- **Category 15: alert-routing-table drift**
  - **Item:** live-only: [ADR-0085](../adrs/ADR-0085-grid-wide-documentation-currency-agent.md) docs-sync run report | `#hive-activity` | Info | `docs-sync: {summary-counts} — {report-or-pr-link}`
  - **First Surfaced:** 2026-06-03
  - **Detail:** Row exists in `constitution/alert-routing.md` but not ADR-0084 D6.
- **Category 16: ADR-0043 backlog-source drift**
  - **Item:** PDR-0001 has no implementation packet coverage
  - **First Surfaced:** 2026-06-05
  - **Detail:** Accepted decision has no proposed, active, or completed packet referencing it through `adrs:`; backlog-generation jobs own packet creation.

---

## Flagged this run — README index Date divergence (D8, needs human/live decision)

- **Item:** ADR-0029 README Date column (`2026-06-07`) ≠ frontmatter `**Date:** 2026-05-08`
  - **First Surfaced:** 2026-06-09
  - **Detail:** `adrs/README.md` shows the ADR-0029 row with Date `2026-06-07` (the **acceptance-event** date noted in the ADR body), but the file's `**Date:**` frontmatter field is `2026-05-08` (the **authoring** date). D8's deterministic rule is to reconcile the README Date column to frontmatter, which would set it to `2026-05-08`. This pass **did not auto-change it** because the divergence is semantically meaningful (authoring vs acceptance date) and pre-existing — a human or the next live pass should decide whether the README index column tracks authoring dates (sync to `2026-05-08`) or acceptance dates (then ADR-0029 frontmatter `**Date:**` is the field that is stale). ADR-0091/0092/0093 README Status/Date columns were already correct (Accepted / correct dates); no other README row diverged.
