# Program: NovOutbox

**Governing PDR:** [PDR-0002: NovOutbox — First Commercial Product on the Grid](../../pdrs/PDR-0002-notify-as-a-service-first-commercial-product.md) — Proposed
**Status:** Forming
**Roadmap thread:** [NovOutbox](../roadmap.md) (Q2-Q4 2026, the Grid's first commercial trial) · **Current-focus rows:** #6-#9
**Kill criteria / gates:** PDR-0002 §K 90-day decision-point (extend / maintenance / sunset) + the §K hard rule (revert the multi-tenant wrapper if it compromises internal Grid use)
**Last updated:** 2026-06-13

Naming note: **NovOutbox** supersedes the earlier customer-facing names **HoneyDrunk Notify** and **Notify Cloud**. This tracker keeps the historical `notify-cloud.md` filename for link stability until a separate cleanup pass renames paths. Technical references to `HoneyDrunk.Notify.Cloud` remain proposed internal Node/repo placeholders, not customer-facing product names.

Context: NovOutbox is the multi-tenant SaaS over `HoneyDrunk.Notify`. It is **re-sequenced behind [ADR-0077](../../adrs/ADR-0077-infrastructure-as-code-bicep.md)** (its prod cloud bring-up rides ADR-0077's reproducible Bicep provisioning) and **hard-gated on ADR-0019** (Communications scaffold + Notify refactor — without it the Pro tier is hollow). This tracker is a **backfill scaffold** per [ADR-0089](../../adrs/ADR-0089-program-tier-for-multi-adr-product-efforts.md), reflecting PDR-0002 at authoring; it is fleshed out as the program activates.

## Phase Roadmap

Phase spine from PDR-0002 §Rollout (dates on `roadmap.md`).

| Phase | Goal | Decisions in phase | State |
|-------|------|--------------------|-------|
| P1 — Dependency unblock | Notify on Container Apps (staging) + Resend + queue backend; ADR-0019 both halves Accepted | ADR-0015 deploy; ADR-0019 | In progress |
| P2 — Notify multi-tenant primitives | Gateway-layer middleware: tenant auth, per-tenant rate limits, billing emission, per-tenant Vault scoping (dispatch path unchanged) | Grid multi-tenant primitives ADR | Not started |
| P3 — NovOutbox scaffold | `HoneyDrunk.Notify.Cloud` repo standup + packages (`.Abstractions`/`.Cloud`/`.Client`/`.Billing.Stripe`/`.Web`); Stripe metered billing (test); SDK 0.1.0-preview | ADR-0027 Node standup; Stripe billing/SDK | Not started |
| P4 — Soft launch | 10–20 beta tenants; manual provisioning; Stripe test mode | — (ops) | Not started |
| P5 — Public launch (~2026-09-15) | Stripe live; Free + Starter + Pro tiers; signup flow | — (ops) | Not started |
| P6 — Decision-point review (~2026-12-15) | Apply §K matrix: extend / maintenance / sunset | — (decision) | Not started |

## ADR Dependency Map

| Decision | Status | Depends on | Unblocks | Phase |
|----------|--------|------------|----------|-------|
| **ADR-0015** Container Apps rollout (staging/prod deploy) | accepted (dev done; prod rides ADR-0077) | ADR-0077 reproducible provisioning (build→build) | NovOutbox scaffold | P1 |
| **ADR-0019** Communications scaffold + Notify refactor (intake/routing split) | needed (Proposed; **hard prerequisite**) | — | multi-tenant primitives; Pro-tier wedge | P1 |
| **Grid multi-tenant primitives ADR** (gateway middleware: tenant context, rate limits, billing, per-tenant Vault) | needed | ADR-0019 *accepted* (decision→decision) | ADR-0027 scaffold | P2 |
| **ADR-0027** Stand up the NovOutbox wrapper Node (`HoneyDrunk.Notify.Cloud` repo + packages, pending technical rename decision) | needed (Proposed) | multi-tenant primitives *shipped* | Stripe billing; SDK; Web | P3 |
| **Stripe billing + SDK** (`.Billing.Stripe`, `.Client`) | needed | ADR-0027 | soft launch | P3 |

**Status legend:** `needed → drafting → accepted → implemented`, or `gated`.

## Child Initiatives

| Initiative | Governing ADR | active-initiatives link | Hive |
|------------|---------------|-------------------------|------|
| Notify + Pulse dev deploy | ADR-0015 | active-initiatives.md (5/5 closed, dev) | — |
| _(others created as their ADRs accept)_ | — | — | — |

## Status Rollup

NovOutbox is in **P1 (dependency unblock)**. The Notify dev deploy (ADR-0015) shipped, ADR-0077's IaC work is treated as done enough for this lane, and the commercial PDR-0002 remains **Proposed**. The immediate priority is no longer generic cloud substrate; it is the lane decision and first-beta path: record the go/slip decision by 2026-06-23, file the missing ADR-0027 scaffold packet, accept or amend the wrapper Node path, and narrow tenant/billing/API work to the first beta tenant. **Next action:** record the go/slip decision, then file `06-notify-cloud-node-scaffold.md` so the Node standup can execute.
