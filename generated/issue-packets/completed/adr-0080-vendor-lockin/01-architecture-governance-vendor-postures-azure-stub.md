---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0080", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0080"]
wave: 2
initiative: adr-0080-vendor-lockin
node: honeydrunk-architecture
---

# Create governance/vendor-postures/ and ship the Azure exit-playbook stub

## Summary
Create the new `governance/vendor-postures/` directory and ship `governance/vendor-postures/azure.md` as the **stub** documenting Azure's Accept (deep, intentional) posture, the cheap hedges already in place across Azure surfaces (Redis-protocol-only per ADR-0076 D3, Bicep modules by concern per ADR-0077 D2, OIDC-standard claims only per ADR-0078 D3, OTel-first emit per ADR-0040, `ISecretStore`/`IConfigProvider` per ADR-0005), and an honest per-surface exit-cost narrative. Per ADR-0080 D5 and D8, this is the **structure-and-canonical-home** packet; the full per-surface content is deferred.

## Context
ADR-0080 D5 creates `governance/vendor-postures/` as the canonical home for per-vendor governance documentation for Accept (deep, intentional) posture vendors. Azure is one of two such vendors (the other is GitHub, in packet 02). The directory does not yet exist in `HoneyDrunk.Architecture`.

The Azure surfaces the Grid currently depends on, per ADR-0080 D2:

- Container Apps (ADR-0015)
- Key Vault (ADR-0005)
- App Configuration (ADR-0005)
- Application Insights / Azure Monitor (ADR-0040, ADR-0045)
- Cache for Redis (ADR-0076)
- Bicep (ADR-0077)
- Entra External ID (ADR-0078)

Each surface carries a different exit cost (weeks per individual surface; multi-month re-platforming if exiting all surfaces together). The cheap hedges already in place at the code level for each surface — per the source ADRs — are the per-surface part of the "vendor-exit playbook" the candidate-surface document and ADR-0076/0077/0078 each cite. ADR-0080's D5 resolves the pointer by giving the playbook a canonical home; this packet ships the file.

**This is a stub at acceptance.** ADR-0080 D8 explicitly says: *"The full content of the per-vendor governance files (D5). The stubs are created with this ADR; the full content is a follow-up packet. The stub commits the structure and the canonical home; the body is filled in incrementally."* The stub commits the surfaces, postures, current hedges (cited by ADR), and exit-cost framing per ADR-0080 D2; the per-surface migration mechanics are out of scope.

This is a docs/governance packet. No code, no .NET project.

## Scope
- Create directory `governance/vendor-postures/` (does not exist today).
- Create file `governance/vendor-postures/azure.md` with the stub structure described in Proposed Implementation.

## Proposed Implementation
1. Create `governance/vendor-postures/` at the repo root, alongside `adrs/`, `constitution/`, `catalogs/`, etc. The directory is the canonical home per ADR-0080 D5.
2. Create `governance/vendor-postures/azure.md` with the following stub structure:

   ```markdown
   # Azure — Vendor Posture: Accept (deep, intentional)

   **Posture:** Accept (deep, intentional) per [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D2.
   **Last reviewed:** 2026-05-24 (initiative `adr-0080-vendor-lockin` packet 01).
   **Status:** Stub. Full per-surface migration mechanics deferred per ADR-0080 D8.

   ## Surfaces

   The Grid depends on Azure across the following surfaces. Each row names the surface, the source ADR, the cheap hedge already in place at the code level (the "pre-paid" part of any future migration cost), and the honest estimated exit cost.

   | Surface | Per-surface posture | Source ADR | Cheap hedge in place | Estimated exit cost |
   |---|---|---|---|---|
   | Container Apps | Accept (deep, intentional) | [ADR-0015](../../adrs/ADR-0015-container-hosting-platform.md) | Container Apps spec is OCI-standard; per-Node Dockerfiles are portable to any container platform. | Weeks. Replace the Container Apps environment, port Bicep templates for compute. |
   | Key Vault | Accept (deep, intentional) | [ADR-0005](../../adrs/ADR-0005-configuration-and-secrets-strategy.md), [ADR-0006](../../adrs/ADR-0006-secret-rotation-and-lifecycle.md) | `ISecretStore` abstraction in HoneyDrunk.Vault.Abstractions; application code never reads secrets directly per [invariant 9](../../constitution/invariants.md). | Weeks per environment. Swap the `ISecretStore` implementation to another backing (HashiCorp Vault, AWS Secrets Manager, etc.). |
   | App Configuration | Accept (deep, intentional) | [ADR-0005](../../adrs/ADR-0005-configuration-and-secrets-strategy.md) | `IConfigProvider` abstraction; application code reads through the abstraction, never direct App Configuration SDK calls. | Weeks per environment. Swap `IConfigProvider` to another backing. |
   | Application Insights / Azure Monitor | **Accept with strong hedge** | [ADR-0040](../../adrs/ADR-0040-telemetry-backend-and-retention.md), [ADR-0045](../../adrs/ADR-0045-grid-wide-error-tracking.md) | OTel-first emit per [ADR-0040](../../adrs/ADR-0040-telemetry-backend-and-retention.md); App Insights is the *backend*, not the *API*. A backend swap (Honeycomb, Grafana Cloud, self-hosted Tempo+Loki+Mimir) is an OTel exporter configuration change. Error path is a documented carve-out (App Insights SDK directly for non-OTLP fields) with `IErrorReporter` facade per [ADR-0045](../../adrs/ADR-0045-grid-wide-error-tracking.md) D3 abstracting the error backend; Sentry is the documented D11 escalation path. The "with strong hedge" qualifier names the OTel-first posture honestly: traces/metrics/logs are days-to-swap, errors are weeks because of the carve-out — this is materially different from the surfaces above where exit cost compounds with surface scope. | Days for traces/metrics/logs. Weeks if errors need a separate path. |
   | Cache for Redis | Accept (deep, intentional) | [ADR-0076](../../adrs/ADR-0076-cache-backing-azure-cache-for-redis.md) | Standard Redis protocol only per [ADR-0076](../../adrs/ADR-0076-cache-backing-azure-cache-for-redis.md) D3. No Azure-specific Cache modules consumed in application code. | Weeks. Swap managed Redis (Redis Cloud, KeyDB, Dragonfly, Valkey, self-hosted Redis on Container Apps); no code rewrite. |
   | Bicep (IaC) | Accept (deep, intentional) | [ADR-0077](../../adrs/ADR-0077-infrastructure-as-code-bicep.md) | Bicep modules organized by concern per [ADR-0077](../../adrs/ADR-0077-infrastructure-as-code-bicep.md) D2. A future Terraform port has module boundaries to mirror 1:1. | Weeks per concern. Re-author each module in the target IaC tool; the per-concern structure preserves the mental model. |
   | Entra External ID | Accept (deep, intentional) | [ADR-0078](../../adrs/ADR-0078-end-user-identity-entra-external-id.md) | OIDC-standard claims only per [ADR-0078](../../adrs/ADR-0078-end-user-identity-entra-external-id.md) D3. Entra-proprietary claims (`oid`, `tid`) are not load-bearing in application logic. | Weeks. Swap to any OIDC-compliant IdP (Auth0, Keycloak, Cognito, etc.); claim mapping work is the per-IdP migration. |

   **Total estimated exit cost (all surfaces, sequential):** multi-month re-platforming. Per-surface migration is bounded to weeks each; the multi-month framing applies if every surface is exited at once.

   ## Why Accept (deep, intentional)

   See [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) Context and D2 reasoning:

   - The productivity gain from a deep, well-understood single-vendor stack outweighs the optionality of a never-exercised second-vendor capability for a solo-dev workshop.
   - The hedges in D3 — already in place via the source ADRs — keep the per-surface migration cost bounded to weeks each.
   - The charter's many-decade horizon licenses the workshop framing over the enterprise framing; multi-cloud-by-default is a permanent tax in service of a hypothetical migration, explicitly rejected in ADR-0080's Alternatives Considered.

   ## Decision-Point Triggers

   The triggers in [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D4 apply to Azure as to every Accept-posture vendor:

   - Deprecation or material price increase on a depended-on surface (handoff to [ADR-0052](../../adrs/ADR-0052-cost-governance-budget-alerts-and-kill-switches.md)'s cost-governance threshold).
   - Sustained reliability problems — two or more incidents exceeding one hour of impact within a single calendar quarter on a depended-on surface (handoff to [ADR-0054](../../adrs/ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md)).
   - Terms change conflicts with charter — e.g. license-change patterns matching the Redis 2024 BSL/SSPL shift (handoff to [ADR-0039](../../adrs/ADR-0039-grid-open-source-license-policy.md) for OSS posture impact).
   - Mature alternative emerges and matures for twelve or more months before being considered as a serious replacement candidate.
   - Adjacent Grid decision changes the math — e.g. a future multi-region ADR, a substantially different compute model, a Node whose workload no longer fits the current vendor's tier ceiling.
   - Vendor acquisition / corporate event — Microsoft acquires, restructures, or changes strategic direction in a way that risks a depended-on surface.

   A trigger fires the **conversation**, not the migration. Outcomes: Stay / Hedge harder / Exit. All three are valid.

   ## Reviewed-and-Held Concerns

   *None at acceptance. This section logs decision-point trigger observations that were reviewed and the assessment was "stay" or "hedge harder." Empty until the first review event occurs.*

   ## Pending Per-Surface Detail

   Per [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D8, the full per-surface migration mechanics — the concrete steps for moving each surface to a named replacement, the per-surface dependency walk, the per-surface canary that proves portability — are deferred to follow-up packets when a real trigger fires. This stub commits the structure and the canonical home; the body is filled in incrementally.

   ## Source ADRs

   - [ADR-0005](../../adrs/ADR-0005-configuration-and-secrets-strategy.md) — Key Vault + App Configuration
   - [ADR-0006](../../adrs/ADR-0006-secret-rotation-and-lifecycle.md) — secret rotation lifecycle
   - [ADR-0015](../../adrs/ADR-0015-container-hosting-platform.md) — Container Apps
   - [ADR-0040](../../adrs/ADR-0040-telemetry-backend-and-retention.md) — Azure Monitor / App Insights, OTel-first
   - [ADR-0045](../../adrs/ADR-0045-grid-wide-error-tracking.md) — App Insights error tracking, `IErrorReporter` facade
   - [ADR-0076](../../adrs/ADR-0076-cache-backing-azure-cache-for-redis.md) — Cache for Redis, Redis-protocol-only
   - [ADR-0077](../../adrs/ADR-0077-infrastructure-as-code-bicep.md) — Bicep, per-concern modules
   - [ADR-0078](../../adrs/ADR-0078-end-user-identity-entra-external-id.md) — Entra External ID, OIDC-standard claims only
   - [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) — vendor posture umbrella (this file's authorizing ADR)
   ```

   The link paths above use `../../adrs/` because `governance/vendor-postures/azure.md` is two directories deep. Verify the relative-path resolution matches the repo's existing convention for inter-document links — match how `adrs/`-to-`constitution/` links are written today.

3. Do **not** create `governance/vendor-postures/github.md` in this packet — it lands in packet 02.
4. Do **not** create any `governance/vendor-postures/README.md` or other index file in this packet. ADR-0080 D5 names `governance/vendor-postures/` as the canonical home; an index file is not required and inventing one would be scope creep. If the operator later wants an index, that is its own follow-up packet.

## Affected Files
- `governance/vendor-postures/` (new directory)
- `governance/vendor-postures/azure.md` (new file)

## NuGet Dependencies
None. This packet creates a new directory and one new Markdown file; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `governance/vendor-postures/` directory exists at the repo root
- [ ] `governance/vendor-postures/azure.md` exists with the stub structure from Proposed Implementation: header (posture/last-reviewed/status), Surfaces table covering all seven Azure surfaces (Container Apps, Key Vault, App Configuration, App Insights/Azure Monitor, Cache for Redis, Bicep, Entra External ID) with per-surface-posture + source-ADR cite + cheap-hedge + estimated-exit-cost per row; App Insights/Azure Monitor row carries the **Accept with strong hedge** posture (the OTel-first emit and Sentry escalation are the named hedge), every other surface row carries Accept (deep, intentional); Why Accept reasoning, Decision-Point Triggers (the six from ADR-0080 D4), Reviewed-and-Held Concerns (empty placeholder), Pending Per-Surface Detail note, Source ADRs reference list
- [ ] All ADR cross-link relative paths resolve from `governance/vendor-postures/azure.md` (two directories deep — `../../adrs/...`)
- [ ] The file is explicitly named a **stub** in the Status line and the Pending Per-Surface Detail note — full per-surface migration mechanics deferred per ADR-0080 D8
- [ ] No `governance/vendor-postures/github.md` created in this packet (lands in packet 02)
- [ ] No `governance/vendor-postures/README.md` or index file created (not authorized by ADR-0080 D5)
- [ ] No edits to ADR-0076, ADR-0077, ADR-0078, or any other ADR file (cross-link footnotes land in packet 03)
- [ ] No edits to `constitution/invariants.md` (invariants land in packet 00)
- [ ] No edits to `catalogs/*.json` (no catalog packet in this initiative)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0080 D5 — Per-vendor exit-playbook stubs.** For Accept (deep, intentional) vendors — Azure and GitHub — create placeholder per-vendor governance files under `governance/vendor-postures/{vendor}.md`. Documents the lock-in honestly: every surface depended on, the exit cost per surface, the cheap hedges already in place. The file is a stub at this ADR's acceptance; the full content lives in a follow-up packet.

**ADR-0080 D2 — Per-vendor posture table.** Azure is Accept (deep, intentional) at the vendor level. At the per-surface level the App Insights / Azure Monitor surface carries **Accept with strong hedge** because OTel-first emit (ADR-0040) reduces backend swap to a configuration change for traces/metrics/logs (days), with the error path as a documented carve-out (weeks via `IErrorReporter` and Sentry as the D11 escalation per ADR-0045 D3). Every other Azure surface (Container Apps, Key Vault, App Configuration, Cache for Redis, Bicep, Entra External ID) carries Accept (deep, intentional). The cheap hedges already in place: standard Redis protocol only (ADR-0076 D3), OIDC-standard claims only (ADR-0078 D3), Bicep modules per concern (ADR-0077 D2), OTel-first telemetry emit (ADR-0040 post-PR-164), `ISecretStore`/`IConfigProvider` abstractions (ADR-0005/ADR-0006). Estimated exit cost: multi-month re-platforming if exiting all surfaces; weeks per individual surface (days for App Insights traces/metrics/logs given the OTel hedge).

**ADR-0080 D4 — Decision-point triggers.** Six triggers cause a posture re-evaluation conversation: deprecation/material price increase, sustained reliability problems (two or more incidents exceeding one hour of impact within a single calendar quarter), terms-change conflicts with charter, mature alternative emerging (twelve-month maturation period), adjacent Grid decision changing the math, vendor acquisition/corporate event. The trigger fires a conversation, not a migration. Outcomes: Stay / Hedge harder / Exit.

**ADR-0080 D8 — Out of scope.** "The full content of the per-vendor governance files (D5). The stubs are created with this ADR; the full content is a follow-up packet."

**Invariant 89 (added by packet 00, referenced here) — "Accept (deep, intentional)" posture vendors have a per-vendor governance file under `governance/vendor-postures/{vendor}.md`.**

## Constraints
- **Stub, not full content.** The file is explicitly a stub per ADR-0080 D8. The structure (surfaces, postures, current hedges, exit-cost ranges, triggers) is committed; the per-surface migration mechanics are deferred. Do not invent per-surface migration steps that ADR-0080 does not author.
- **Cite, do not restate, source ADRs.** Every per-surface row in the Surfaces table cites the source ADR by link; the hedge text is a one-line summary, not a copy of the source ADR's full hedge discussion. The reader follows the link for the source ADR's depth.
- **Match relative-path convention.** `governance/vendor-postures/azure.md` is two directories deep; ADR cross-links use `../../adrs/{ADR-file}`. Verify against how `adrs/` content links to `constitution/` files today.
- **Do not create a `README.md` for the directory.** ADR-0080 D5 names `governance/vendor-postures/` as the canonical home; an index is not authorized.
- **Do not edit any ADR or invariant in this packet.** ADR-0076/0077/0078 cross-link footnotes land in packet 03; invariants land in packet 00.
- **The Reviewed-and-Held Concerns section is intentionally empty.** It is a placeholder for future trigger-event entries per ADR-0080 D4's "Stay" outcome. The empty section is the correct state at acceptance.

## Labels
`feature`, `tier-2`, `meta`, `docs`, `adr-0080`, `wave-2`

## Agent Handoff

**Objective:** Create the new `governance/vendor-postures/` directory and ship the Azure stub at `governance/vendor-postures/azure.md` per ADR-0080 D5.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Establish the canonical home for per-vendor Accept-posture governance documentation, and resolve the "vendor-exit playbook" footnote pointers from ADR-0076/0077/0078 to a real artifact.
- Feature: ADR-0080 Vendor Lock-In Posture rollout, Wave 2.
- ADRs: ADR-0080 D5 (primary — creates the directory and stub structure), ADR-0080 D2 (the per-surface Azure posture and hedges), ADR-0080 D4 (the triggers section), ADR-0080 D8 (the stub-vs-full-content scoping). Source ADRs for each Azure surface: ADR-0005, ADR-0006, ADR-0015, ADR-0040, ADR-0045, ADR-0076, ADR-0077, ADR-0078.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0080 must be Accepted (and the three vendor-posture invariants in place) before its D5 substrate ships.

**Constraints:**
- Stub only — full per-surface migration mechanics deferred per ADR-0080 D8.
- Cite, do not restate, source ADRs.
- No `README.md` for the new directory.
- No edits to any ADR, invariant, or catalog file in this packet.

**Key Files:**
- `governance/vendor-postures/` (new)
- `governance/vendor-postures/azure.md` (new)

**Contracts:** None changed.
