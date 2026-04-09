---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "infrastructure", "adr-0005"]
dependencies: ["vault-env-driven-add-vault-wiring", "vault-add-app-configuration-extension", "vault-event-driven-cache-invalidation"]
adrs: ["ADR-0005", "ADR-0006"]
wave: 2
initiative: adr-0005-0006-rollout
node: pulse
---

# Feature: Migrate HoneyDrunk.Pulse config bootstrap to `AZURE_KEYVAULT_URI` + `AZURE_APPCONFIG_ENDPOINT`

## Summary
Switch Pulse and Pulse.Collector to env-driven `AddVault` + `AddAppConfiguration` wiring, move sink credentials (Loki/Tempo/Mimir/PostHog/Sentry/OTLP) to `ISecretStore`, and register the Event Grid cache-invalidation webhook. Pulse is pending production deployment — this packet is the deployment gate.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Pulse`

## Motivation
Pulse.Collector is a long-running OTLP receiver and must not hold stale sink credentials. ADR-0005/0006 define the bootstrap + propagation contract; this packet brings Pulse into line before it ships to production. The sink surface is mostly third-party (PostHog, Sentry, Loki/Tempo/Mimir auth tokens) — all are Tier-2 rotation candidates.

## Proposed Implementation
- `builder.AddVault()` + `builder.AddAppConfiguration()` in both Pulse host and Pulse.Collector host
- Sink credentials as provider-grouped secrets:
  - `PostHog--ApiKey`
  - `Sentry--Dsn`
  - `Loki--BasicAuth` (or `Loki--Username` + `Loki--Password`)
  - `Tempo--BasicAuth`
  - `Mimir--BasicAuth`
  - `Otlp--Headers` (if any auth header is needed)
- Non-secret config (endpoints, sampling, batch sizes) → App Configuration label `pulse` (matches the existing `id: "pulse"` in `catalogs/nodes.json`)
- Sink implementations must resolve credentials via `ISecretStore` and honor cache invalidation — not at process start
- Webhook registration on both host flavors
- CI to OIDC workflow

## Affected Packages
- `HoneyDrunk.Pulse` (runtime)
- `HoneyDrunk.Pulse.Collector` (OTLP receiver)
- All sink packages (`HoneyDrunk.Pulse.Sinks.*`)

## Boundary Check
- [x] Sink credential handling belongs in Pulse
- [x] Telemetry responsibilities unchanged — only bootstrap surface moves

## Acceptance Criteria
- [ ] Startup uses env-driven extensions in both hosts
- [ ] Zero direct env-var secret reads in sink implementations
- [ ] Provider-grouped secret naming
- [ ] Non-secret config from App Configuration with `pulse` label
- [ ] Event Grid invalidation webhook registered in both hosts
- [ ] Rotation canary on at least one sink credential
- [ ] CI uses OIDC
- [ ] Existing tests + canary pass
- [ ] CHANGELOG updated

## Context
- ADR-0005, ADR-0006
- Invariants 8, 9, 17, 18, 21
- Active initiative: Ops Observability Pipeline (production deployment pending — this packet is the deployment gate)
- Note: `catalogs/nodes.json` Pulse entry has id `pulse` not `honeydrunk-pulse`; use `pulse` as the App Configuration label to match

## Dependencies
- Wave 1 Vault packets
- `architecture-infra-portal-walkthroughs`
- `actions-oidc-federated-credentials-workflow`

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Bring Pulse + Pulse.Collector bootstrap in line with ADR-0005/0006 before production deployment.
**Target:** HoneyDrunk.Pulse, branch from `main`
**Context:**
- Goal: ADR-0005/0006 per-Node migration wave + unblock Pulse production deployment
- Feature: Configuration/rotation rollout + Ops Observability Pipeline
- ADRs: ADR-0005, ADR-0006

**Acceptance Criteria:** As listed above

**Dependencies:** Wave 1 Vault packets merged

**Constraints:**
- Invariant 8 — telemetry sink outputs must never contain raw credentials, even during debug
- Invariant 9 — `ISecretStore` only
- Invariant 17 — `kv-hd-pulse-{env}` (5 chars)
- Invariant 21 — no version pinning

**Key Files:**
- `Program.cs` for Pulse + Pulse.Collector
- Sink projects under `HoneyDrunk.Pulse.Sinks.*`
- `appsettings*.json`
- `.github/workflows/*.yml`

**Contracts:** None changed.
