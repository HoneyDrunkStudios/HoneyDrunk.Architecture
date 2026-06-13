---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0066", "wave-1"]
dependencies: []
adrs: ["ADR-0066"]
accepts: ["ADR-0066"]
wave: 1
initiative: adr-0066-health-endpoints
node: honeydrunk-architecture
---

# Accept ADR-0066 — flip status, add health-endpoint invariants, register initiative

## Summary
Flip ADR-0066 (Health, Readiness, and Liveness Endpoint Contract) from Proposed to Accepted: update the ADR header, insert the ADR-0066 row into `adrs/README.md` (the README index currently stops at ADR-0057 — ADR-0066 is not yet listed), add the three new health-endpoint invariants ADR-0066 commits to `constitution/invariants.md`, and register the `adr-0066-health-endpoints` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0066 commits the Grid-wide health-endpoint contract: three endpoints per HTTP-fronted deployable Node (`/health/live`, `/health/ready`, `/health`), the IETF `health+json` response shape on `/health`, the empty-body 200/503 shape on the probe endpoints, the `IHealthContributor` worst-status-wins aggregation rule with criticality refinement, Container Apps probe defaults, the `ReadinessPolicy` model, the auth posture (probes anonymous, `/health` auth-required), the PII rule for contributor messages, the implementation home in `HoneyDrunk.Kernel`, and the Pulse telemetry contribution per probe outcome.

The ADR decides:
- **D1** — three endpoints uniformly named `/health/live`, `/health/ready`, `/health` (Functions-host prefix `/api/` accommodated environment-dependently).
- **D2** — probe endpoints return empty body with `200` (healthy/degraded) or `503` (unhealthy); `/health` returns IETF `application/health+json` shape with per-contributor entries.
- **D3** — the Kernel `HealthStatus` enum is the wire enum (`Healthy`/`Degraded`/`Unhealthy`), mapped to `pass`/`warn`/`fail` on the IETF body.
- **D4** — worst-status-wins aggregation across `IHealthContributor` instances; a `Degraded` from a critical contributor escalates to `Unhealthy`; a throwing contributor is treated as `Unhealthy` and the aggregator continues; `IHealthCheck` is the simpler internal-component primitive and is NOT consulted by the endpoint.
- **D5** — Container Apps probe defaults: `livenessProbe` `/health/live` 30s period 10s initial delay 3s timeout 3 failure threshold; `readinessProbe` `/health/ready` 10s period 5s initial delay 3 failure threshold; `startupProbe` `/health/live` 5s period 30 failure threshold (~150s warm-up runway). Revision health-gate at `100%` traffic requires `/health/ready` to return `200` for three consecutive periods.
- **D6** — `/health/live` and `/health/ready` are anonymous (probes cannot supply auth); `/health` is auth-required (Studios-internal, tenant-admin, or Azure Monitor scrape credential).
- **D7** — `ReadinessPolicy` enum with three values: `Required` (gates `/health/ready`; default), `OptionalReported` (appears in `/health` aggregate, does not affect `/health/ready`), `NotReadinessRelevant` (only in `/health`).
- **D8** — contributor `output` strings must not carry connection strings, secrets, tenant identifiers, or provider opaque IDs; the contributor is responsible for redaction at the report site; the `security` specialist review gains a checklist item.
- **D9** — implementation home is `HoneyDrunk.Kernel.Hosting.AspNetCore.HealthEndpoints` (runtime package, not Abstractions) with `MapHoneyDrunkHealthEndpoints`; a Functions-host helper for the Notify.Functions case; the underlying substrate is `Microsoft.Extensions.Diagnostics.HealthChecks` with a Kernel-shipped IETF response writer; `INotifyHealthContributor` in Notify is bridged via `NotifyHealthContributorAdapter` then removed.
- **D10** — probe outcomes contribute Pulse signals: counter `honeydrunk.health.probes` with `(node, endpoint, status_code, outcome)` dimensions, structured logs at Warning/Error on failure, contributor-duration histogram. Probe outcomes are NOT audit events (D10 explicit).
- **D11** — out of scope: public status page, cross-Node aggregate dashboard, per-tenant readiness, synthetic monitoring details, tenant-visible SLA signal.

ADR-0066 is a **policy / contract** ADR. Concrete code — the Kernel endpoint helpers, the IETF response writer, the `ReadinessPolicy` enum, the contributor execution timeout, the Functions-host helper, the Pulse.Collector amendment, the Notify amendment + follow-up, the per-Node Container Apps probe declarations, the deploy-workflow readiness-gate switch — lands in subsequent packets. Catalog updates land in packet 01. Every other packet references ADR-0066's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Invariant Numbering
ADR-0066 adds exactly **three** new invariants. The reservation block lives in `constitution/invariant-reservations.md` — read that file at packet-execution time to confirm the claimed block (size 3) and the assigned numbers `{N1}/{N2}/{N3}`. As of authoring, the ADR-0066 row in `invariant-reservations.md` claims **80, 81, 82**; if the reservation file's `next free` cursor has moved upward before this packet merges (because another ADR's packet 00 raced and won), shift this block to the new next-free sequential triple, update both `invariant-reservations.md` (move ADR-0066's row to the new range) and every `{N1}/{N2}/{N3}` placeholder in this initiative's packets. Group the three under a new `## Health Endpoint Invariants` section placed after the existing topic-grouped sections (e.g. after `## Audit Invariants`). Do not renumber any existing invariant. Never reuse a claimed number.

## Scope
- `adrs/ADR-0066-health-readiness-liveness-endpoints.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — **insert** the ADR-0066 row (and incidentally any missing intervening rows for ADR-0058 through ADR-0066 if they exist as Proposed files — the README index currently stops at ADR-0057 even though ADR files through ADR-0080 exist; at minimum, add the ADR-0066 row). Status column: Accepted.
- `constitution/invariants.md` — add the three new health-endpoint invariants as `{N1}/{N2}/{N3}` (read `constitution/invariant-reservations.md` for the claimed numbers) under a new `## Health Endpoint Invariants` section.
- `constitution/invariant-reservations.md` — confirm or shift the ADR-0066 reservation row (claimed block is currently 80–82); the row was added at packet-authoring time.
- `initiatives/active-initiatives.md` — register the `adr-0066-health-endpoints` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0066 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update `adrs/README.md`: insert a new row for ADR-0066 in numeric order. The README currently ends at the ADR-0057 row even though ADR-0058 through ADR-0080 markdown files exist in `adrs/`. **In scope for this work-item: add the ADR-0066 row as Accepted.** Inserting the other missing rows is desirable hygiene but not required to land this packet; if doing so is trivial, do it as a single index sweep, otherwise leave them for a separate README-index packet.
3. Read `constitution/invariant-reservations.md` to confirm the claimed `{N1}/{N2}/{N3}` block for ADR-0066 (currently **80, 81, 82**). If the reservation file's `next free` cursor has moved upward (another ADR's packet 00 merged ahead of this one), shift the ADR-0066 reservation row to the new contiguous triple and update every `{N1}/{N2}/{N3}` placeholder in this initiative's packets.
4. Add three new invariants to `constitution/invariants.md`, numbered `{N1}/{N2}/{N3}`, under a new `## Health Endpoint Invariants` section placed after `## Audit Invariants`. The text, taken verbatim-in-substance from ADR-0066's Consequences "Invariants" subsection:
   - **{N1} — Every HTTP-fronted deployable Node exposes `/health/live`, `/health/ready`, and `/health` via Kernel's `MapHoneyDrunkHealthEndpoints` extension (or the Functions-host equivalent), aggregating `IHealthContributor` instances per the readiness-policy model.** The path suffix is uniform across Nodes; host-imposed prefixes (e.g. Functions' `/api/`) are accommodated. The `/health` endpoint returns the IETF `application/health+json` shape; the probe endpoints return empty body with `200`/`503`. Enforced at standup; the canary surface gains a "health endpoints reachable" check. See ADR-0066 D1, D2, D9.
   - **{N2} — `/health/live` and `/health/ready` are anonymous; `/health` is auth-required.** Probe sources cannot supply auth headers, so the probe endpoints must be anonymous. `/health` is auth-gated with a **two-token posture**: tenant-bounded Notify probes (and other tenant-visible Nodes) accept a **tenant-administrator token**; cross-tenant operator probes (Studios-staff fleet checks, Operator/Agents/HoneyHub interactions across tenants) accept a **Studios-internal token**. Azure Monitor scrape credentials are accepted on either path. Enforced by the `security` specialist review (per ADR-0046) and by the per-Node host composition. See ADR-0066 D6.
   - **{N3} — `IHealthContributor` `output` strings must not carry secrets, connection strings, tenant identifiers, or other restricted-tier data per ADR-0049's data-classification taxonomy.** Redaction is the contributor implementation's responsibility at the report site. The Kernel-supplied helpers do not auto-redact. **PII enforcement aggregates contributors to Node-level only**, never per-tenant — the IETF `checks` dictionary surfaces Node-scoped contributor state, not tenant-partitioned state. The `security` specialist review checklist gains an item for contributor message review. This invariant complements (does not restate) invariant 8 ("Secret values never appear in logs, traces, exceptions, or telemetry"); the `/health` body is part of telemetry-adjacent surface but the rule is stated separately because it covers a broader class of restricted data (tenant identifiers and provider opaque IDs in addition to secrets). See ADR-0066 D8.
   - Create the new `## Health Endpoint Invariants` section. Place it after the `## Audit Invariants` section to match the file's topic-grouped sectioning convention.
5. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0066-health-readiness-liveness-endpoints.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md` (confirm or shift the ADR-0066 row; currently claims 80–82)
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0066 header reads `**Status:** Accepted`
- [ ] `adrs/README.md` carries an ADR-0066 row reflecting Accepted, placed in numeric order between ADR-0057 (or whatever the prior row currently is) and the next ADR row
- [ ] `constitution/invariant-reservations.md` carries an ADR-0066 row claiming a contiguous block of size 3 (currently `{N1}/{N2}/{N3}` = **80/81/82**); if it had to shift because of a race, the new range is reflected here and in every packet's `{N1}/{N2}/{N3}` placeholder
- [ ] `constitution/invariants.md` carries the three new health-endpoint invariants (three endpoints exposed via Kernel helper; probes anonymous and `/health` auth-required with the two-token posture; contributor messages free of secrets/connection strings/tenant identifiers/provider opaque IDs with Node-level aggregation only), numbered `{N1}/{N2}/{N3}` under a new `## Health Endpoint Invariants` section, each citing ADR-0066
- [ ] `initiatives/active-initiatives.md` registers the `adr-0066-health-endpoints` initiative with a packet checklist
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0066 D1 — Three endpoints.** `/health/live` (liveness), `/health/ready` (readiness), `/health` (full aggregate). Path scheme is fixed; Functions-host prefix `/api/` is the host's, not the Grid's.

**ADR-0066 D2 — Response shape.** Probes return empty body with `200` on healthy/degraded or `503` on unhealthy. `/health` returns IETF `application/health+json` shape with `status` (`pass`/`warn`/`fail`), `version`, `releaseId`, and per-contributor `checks` entries (`status`, `time`, optional `output`).

**ADR-0066 D6 — Auth posture.** `/health/live` and `/health/ready` are anonymous (probes cannot supply auth); `/health` is auth-required (Studios staff token, tenant-admin token, or Azure Monitor scrape credential).

**ADR-0066 D8 — PII / secrets rule.** Contributor `output` strings must not carry connection strings, secrets, tenant identifiers, provider opaque IDs. Redaction is the contributor's responsibility. The `security` specialist review gains a checklist item.

**ADR-0066 Consequences — Invariants.** ADR-0066 adds exactly three invariants (the three-endpoint exposure rule, the auth-posture rule with the tenant-admin / Studios-internal two-token model, and the contributor-message PII rule with Node-level aggregation). Reserved numbers `{N1}/{N2}/{N3}` — see `constitution/invariant-reservations.md` (currently 80/81/82).

## Constraints
- **Acceptance precedes flip.** ADR-0066 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers via reservation file.** Read `constitution/invariant-reservations.md` to confirm `{N1}/{N2}/{N3}` (currently 80/81/82). Do not renumber existing invariants. If the reservation cursor has moved before this packet merges, shift the ADR-0066 row to the new contiguous triple and update every `{N1}/{N2}/{N3}` placeholder in this initiative's packets. Never reuse a claimed number.
- **README insert, do not replace.** The ADR-0066 row is a new row; insert it in numeric order. Adding rows for the other missing ADR files (ADR-0058 through ADR-0080) is hygiene, not required to land this packet.
- **Reference invariant 8, do not restate.** Invariant `{N3}` is broader (tenant identifiers, provider opaque IDs) than invariant 8 (secrets in telemetry). Cite invariant 8 as a complementary rule; do not duplicate its text.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0066`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0066 to Accepted, add the three health-endpoint invariants to `constitution/invariants.md`, insert the README index row, and register the health-endpoints initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0066 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0066 Health, Readiness, and Liveness Endpoint Contract rollout, Wave 1.
- ADRs: ADR-0066 (primary), ADR-0008 (initiative/packet conventions), ADR-0046 (specialist review reference), ADR-0049 (data-classification reference in Invariant `{N3}`).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0066 stays Proposed until this PR merges.
- Read `constitution/invariant-reservations.md` for `{N1}/{N2}/{N3}` (claimed block is currently 80/81/82). If a race shifted the cursor, shift the ADR-0066 row to the new contiguous triple and update every `{N1}/{N2}/{N3}` placeholder in this initiative's packets. Group the three under a new `## Health Endpoint Invariants` section.
- Insert (do not replace) the ADR-0066 row in `adrs/README.md`.
- Invariant `{N3}` complements (does not restate) invariant 8.

**Key Files:**
- `adrs/ADR-0066-health-readiness-liveness-endpoints.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md` (confirm or shift the ADR-0066 row)
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
