---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0037", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0037", "ADR-0026", "ADR-0028"]
wave: 2
initiative: adr-0037-payment-and-billing-integration
node: honeydrunk-architecture
---

# Register the HoneyDrunk.Billing Node — context folder, sector map, planned catalog edges

## Summary
Register the future `HoneyDrunk.Billing` Node in the Grid as a planned (Seed) Node per ADR-0037 D9: create the standard `repos/HoneyDrunk.Billing/` context folder (five files), add the Ops-sector entry in `constitution/sectors.md`, record `HoneyDrunk.Billing` as a planned-Node *descriptor* entry in `catalogs/nodes.json`, and record its dependency edges in `catalogs/relationships.json` (the `honeydrunk-billing` entry plus the reciprocal `consumed_by_planned` edges on Vault and Audit) — the edges ADR-0037 commits. This is the catalog-registration step that precedes the separate `HoneyDrunk.Billing` standup ADR — it does **not** scaffold the repo or author any code.

## Context
ADR-0037 D9 places a new `HoneyDrunk.Billing` Node in the **Ops** sector, adjacent to Notify / Communications / Pulse. The Node will own three package families: `HoneyDrunk.Billing.Abstractions` (the Stripe-facing downstream contracts — `IBillingMeterPipe`, `IBillingCustomerStore`, `IStripeEventHandler`, `BillingMeterEvent`, `BillingCustomerBinding`), `HoneyDrunk.Billing.Stripe` (the Stripe implementation), and `HoneyDrunk.Billing.Webhooks` (a Function App per ADR-0015).

ADR-0037's Consequences section explicitly lists the catalog edges this Node introduces: `Billing→Vault`, `Billing→Audit`, `NotifyCloud→Billing`, and future consumer-apps→Billing.

This packet registers the Node as **planned/Seed** — the same posture used for AI-sector Seed Nodes before their standup. It does **not** create the GitHub repo and does **not** scaffold any solution. ADR-0037 D2/D9 and the Follow-up Work list defer the actual Node standup (Abstractions-first, frozen contracts, contract-shape canary) to a **separate `HoneyDrunk.Billing` standup ADR** — see packet 04 of this initiative, which authors that follow-up ADR as Proposed. The standup-ADR-before-scaffold rule means no scaffold packet exists in this initiative.

Per the user's standing instruction, the scope agent does **not** reconcile `catalogs/grid-health.json`, `catalogs/contracts.json`, or `catalogs/modules.json` for a not-yet-built Node — those are reconciled by `hive-sync` once the Node is actually scaffolded under its standup ADR. This packet touches exactly two catalog files:

- `catalogs/nodes.json` — the Node *descriptor* catalog. Each entry carries identity/presentation fields only: `id`, `type`, `name`, `public_name`, `short`, `description`, `sector`, `signal`, `cluster`, `energy`, `priority`, `flow`, `tags`, `links`, `long_description`, `foundational`, `strategy_base`, `tier`, `time_pressure`, `done`, `cooldown_days`. It has **no** `consumes`, `consumed_by`, `consumed_by_planned`, `exposes`, or `blocked_by` fields — do not invent them here. Match the exact field set of an existing planned Seed Node (`honeydrunk-observe`, `honeydrunk-audit`).
- `catalogs/relationships.json` — the dependency-graph catalog (top-level key `nodes`). Each entry carries `id`, `consumes`, `consumed_by`, `consumed_by_planned`, `blocked_by`, `exposes`, `consumes_detail`. The Billing dependency edges live **here**, not in `nodes.json`. `relationships.json` already carries `consumed_by_planned` arrays for other unbuilt Nodes, so this is the established pattern.

## Scope
- `repos/HoneyDrunk.Billing/` — new context folder, five files matching the template used by `repos/HoneyDrunk.Communications/` and `repos/HoneyDrunk.Audit/`: `overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`.
- `constitution/sectors.md` — add `HoneyDrunk.Billing` to the Ops-sector listing, marked as planned/Seed.
- `catalogs/nodes.json` — add a `honeydrunk-billing` Node *descriptor* entry. Use **only** the real `nodes.json` field set (`id`, `type`, `name`, `public_name`, `short`, `description`, `sector`, `signal`, `cluster`, `energy`, `priority`, `flow`, `tags`, `links`, `long_description`, `foundational`, `strategy_base`, `tier`, `time_pressure`, `done`, `cooldown_days`). `sector: "Ops"`, `signal` set to the planned/Seed value used by `honeydrunk-observe`. Do **not** add `consumes`/`consumed_by`/`consumed_by_planned`/`exposes`/`blocked_by` here — those fields do not exist in `nodes.json`.
- `catalogs/relationships.json` — add a `honeydrunk-billing` entry to the top-level `nodes` array with `consumes: ["honeydrunk-vault", "honeydrunk-audit"]`, `consumed_by: []`, `consumed_by_planned: []`, `blocked_by: []`, an `exposes` block listing the planned contracts/packages, and a `consumes_detail` mapping. Then add `"honeydrunk-billing"` to the `consumed_by_planned` arrays of the `honeydrunk-vault` and `honeydrunk-audit` entries. The `NotifyCloud→Billing` edge is **omitted** — Notify Cloud is not yet a `relationships.json` node; `hive-sync` wires that reciprocal edge when Notify Cloud is registered (leave a one-line note in the PR description).

## Proposed Implementation
1. Create `repos/HoneyDrunk.Billing/` with the five standard context files. Content is derived from ADR-0037:
   - `overview.md` — the Node owns the Stripe-facing billing pipe and webhook surface; Ops sector; planned/Seed status; standup governed by the follow-up `HoneyDrunk.Billing` standup ADR (packet 04).
   - `boundaries.md` — Billing owns the Stripe mapping and the meter-events buffer; Auth owns principal identity (Auth holds no Stripe identifiers, ADR-0037 D5); Notify Cloud owns the tenant record that *stores* `stripe_customer_id` / `stripe_subscription_id`; no Node subscribes to Stripe webhooks except `HoneyDrunk.Billing.Webhooks`.
   - `invariants.md` — the three ADR-0037 billing invariants (cross-reference the canonical numbers landed by packet 00).
   - `active-work.md` — empty / "awaiting standup ADR".
   - `integration-points.md` — the edges: Billing→Vault (Stripe API keys + webhook signing secrets), Billing→Audit (Billing is Audit's second emitter after Auth), NotifyCloud→Billing (subscription state, meter ingestion, webhook-driven tier changes), future consumer-apps→Billing.
2. Add the Ops-sector row for `HoneyDrunk.Billing` in `constitution/sectors.md`, marked planned/Seed.
3. Add the `honeydrunk-billing` *descriptor* entry to `catalogs/nodes.json` — copy the field set of an existing planned Seed Node (`honeydrunk-observe`), filling in Billing-specific identity/presentation values. Do not add dependency fields here; `nodes.json` has none.
4. Add the `honeydrunk-billing` dependency entry to `catalogs/relationships.json` (top-level `nodes` array): `consumes: ["honeydrunk-vault", "honeydrunk-audit"]`, `consumed_by: []`, `consumed_by_planned: []`, `blocked_by: []`, an `exposes` block (`contracts`: `IBillingMeterPipe`, `IBillingCustomerStore`, `IStripeEventHandler`, `BillingMeterEvent`, `BillingCustomerBinding`; `packages`: `HoneyDrunk.Billing.Abstractions`, `HoneyDrunk.Billing.Stripe`, `HoneyDrunk.Billing.Webhooks`), and a `consumes_detail` mapping for Vault (Stripe API keys + webhook signing secrets) and Audit (audit emission). Then add `"honeydrunk-billing"` to the `consumed_by_planned` arrays of the `honeydrunk-vault` and `honeydrunk-audit` entries. Match the exact JSON shape of an existing `relationships.json` entry.
5. The `NotifyCloud→Billing` edge from ADR-0037's Consequences is **omitted** for now — Notify Cloud (ADR-0027, Proposed) is not yet a `relationships.json` node. Leave a one-line note in the PR description: "`hive-sync` wires the NotifyCloud→Billing edge when Notify Cloud is registered."

## Affected Files
- `repos/HoneyDrunk.Billing/overview.md` (new)
- `repos/HoneyDrunk.Billing/boundaries.md` (new)
- `repos/HoneyDrunk.Billing/invariants.md` (new)
- `repos/HoneyDrunk.Billing/active-work.md` (new)
- `repos/HoneyDrunk.Billing/integration-points.md` (new)
- `constitution/sectors.md`
- `catalogs/nodes.json`
- `catalogs/relationships.json`

## NuGet Dependencies
None. This packet touches only Markdown context files and two JSON catalogs; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new runtime dependency — the catalog edges describe planned dependencies; nothing compiles against them yet.

## Acceptance Criteria
- [ ] `repos/HoneyDrunk.Billing/` exists with all five standard context files, content derived from ADR-0037 D9 and D5
- [ ] `constitution/sectors.md` lists `HoneyDrunk.Billing` in the Ops sector, marked planned/Seed
- [ ] `catalogs/nodes.json` carries a `honeydrunk-billing` descriptor entry using only the real `nodes.json` field set (`id`, `type`, `name`, `sector`, `signal`, etc.) — with no `consumes`/`consumed_by`/`consumed_by_planned`/`exposes`/`blocked_by` fields
- [ ] `catalogs/relationships.json` carries a `honeydrunk-billing` entry with `consumes: ["honeydrunk-vault", "honeydrunk-audit"]`, an `exposes` block, and a `consumes_detail` mapping
- [ ] `honeydrunk-billing` appears in the `consumed_by_planned` arrays of the `honeydrunk-vault` and `honeydrunk-audit` entries in `catalogs/relationships.json`
- [ ] The `NotifyCloud→Billing` edge is intentionally omitted; the PR description carries the one-line note that `hive-sync` wires it when Notify Cloud is registered
- [ ] Both `catalogs/nodes.json` and `catalogs/relationships.json` remain valid JSON (parse cleanly)
- [ ] No `catalogs/grid-health.json`, `catalogs/contracts.json`, or `catalogs/modules.json` edits in this packet — those reconcile at standup
- [ ] No GitHub repo is created and no solution is scaffolded by this packet

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0037 D9 — `HoneyDrunk.Billing` Node placement.** Sector: Ops, adjacent to Notify / Communications / Pulse. The Node holds `HoneyDrunk.Billing.Abstractions` (`IBillingMeterPipe`, `IBillingCustomerStore`, `IStripeEventHandler`, `BillingMeterEvent`, `BillingCustomerBinding` — the downstream Stripe-facing surface), `HoneyDrunk.Billing.Stripe` (the Stripe implementation), and `HoneyDrunk.Billing.Webhooks` (a Function App per ADR-0015). The Kernel-level `IBillingEventEmitter` is the *upstream* interface; this Node's interfaces are the *downstream* surface. `HoneyDrunk.Billing.Cloud` is optional and may fold into Notify.Cloud.

**ADR-0037 D5 — Identity binding.** For B2B, the Notify Cloud tenant record holds `stripe_customer_id` and `stripe_subscription_id`; `TenantId` and Stripe customer are 1:1. For B2C, the consumer app's user record holds `stripe_customer_id`. Auth holds no Stripe identifiers — Auth owns principal identity, Billing owns the Stripe mapping, the binding is via `PrincipalId` keys.

**ADR-0037 Consequences — Affected Nodes / `catalogs/relationships.json`.** "gains edges: Billing→Vault, Billing→Audit, NotifyCloud→Billing, future consumer apps→Billing." Vault holds Stripe API keys and webhook signing secrets; Audit gains Billing as its second emitter (after Auth, ADR-0031). This packet records Billing→Vault and Billing→Audit in `relationships.json` now; NotifyCloud→Billing and the future consumer-app edges are deferred until those Nodes are `relationships.json` entries.

**ADR-0026 — `IBillingEventEmitter` / `BillingEvent` live in `HoneyDrunk.Kernel.Abstractions.Tenancy`.** They are not redefined by Billing — Billing's default `IBillingEventEmitter` implementation is the *real* (non-noop) emitter, but the contract is owned by Kernel.

## Constraints
- **No scaffold, no repo.** This packet registers a *planned* Node only. The `HoneyDrunk.Billing` standup — solution layout, Abstractions, Stripe implementation, webhook Function App, contract-shape canary — is governed by the separate standup ADR authored in packet 04 and is out of scope here.
- **`nodes.json` and `relationships.json` are distinct schemas.** `nodes.json` is the descriptor catalog (identity/presentation fields only). `relationships.json` is the dependency graph (`consumes`, `consumed_by`, `consumed_by_planned`, `exposes`, etc.). The dependency edges go in `relationships.json` only — `nodes.json` has no such fields, do not invent them.
- **Catalog reconciliation is `hive-sync`'s job at standup.** `grid-health.json`, `contracts.json`, and `modules.json` are not touched — there is no built Node, no `dr_tier`, no shipped contracts, no packages yet. Only `nodes.json` (descriptor) and `relationships.json` (edges) get a planned entry, matching the existing `honeydrunk-observe` precedent.
- **Notify Cloud edge omitted.** `honeydrunk-notify-cloud` is not yet a `relationships.json` node (its standup, ADR-0027, is still Proposed and the repo does not exist), so the `NotifyCloud→Billing` reciprocal edge is omitted; leave a one-line note in the PR description; `hive-sync` adds it when Notify Cloud is registered.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0037`, `wave-2`

## Agent Handoff

**Objective:** Register `HoneyDrunk.Billing` as a planned Ops-sector Node — context folder, sector map, a `nodes.json` descriptor entry, and `relationships.json` dependency edges — without scaffolding any code.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the future Billing Node visible to the Grid's routing rules and context surface so the standup ADR (packet 04) and downstream consumers have a registered Node to reference.
- Feature: ADR-0037 Payment and Billing Integration rollout, Wave 2.
- ADRs: ADR-0037 D9/D5 (primary), ADR-0026 (the Kernel-owned `IBillingEventEmitter`), ADR-0028 (Service Bus default topic).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. References the three billing invariants packet 00 lands; the context folder's `invariants.md` cross-references their canonical numbers.

**Constraints:**
- No GitHub repo, no solution scaffold — planned-Node registration only.
- `nodes.json` (descriptor: identity/presentation fields only) and `relationships.json` (dependency graph: `consumes`/`consumed_by`/`consumed_by_planned`/`exposes`) are distinct schemas. Dependency edges go in `relationships.json` only; `nodes.json` has no such fields — do not invent them.
- `grid-health.json` / `contracts.json` / `modules.json` reconcile at standup, not here.
- Match the JSON shape of `honeydrunk-observe` in `nodes.json` and an existing entry in `relationships.json`.
- The `NotifyCloud→Billing` edge is omitted — Notify Cloud is not a `relationships.json` node yet; note this in the PR.

**Key Files:**
- `repos/HoneyDrunk.Billing/` (five new context files)
- `constitution/sectors.md`
- `catalogs/nodes.json`
- `catalogs/relationships.json`

**Contracts:** None changed — this records planned contracts as catalog metadata; nothing compiles against them.
