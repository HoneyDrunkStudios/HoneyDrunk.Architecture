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
