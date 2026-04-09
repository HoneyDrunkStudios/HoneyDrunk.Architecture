---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "infrastructure", "adr-0005"]
dependencies: ["vault-env-driven-add-vault-wiring", "vault-add-app-configuration-extension", "vault-event-driven-cache-invalidation"]
adrs: ["ADR-0005", "ADR-0006"]
wave: 2
initiative: adr-0005-0006-rollout
node: honeydrunk-notify
---

# Feature: Migrate HoneyDrunk.Notify config bootstrap to `AZURE_KEYVAULT_URI` + `AZURE_APPCONFIG_ENDPOINT`

## Summary
Switch Notify's Resend/Twilio/SMTP secret resolution to the new env-driven Vault bootstrap and register the Event Grid cache-invalidation webhook. Notify is the first Tier-2 rotation target — this Node must be ready before `HoneyDrunk.Vault.Rotation` ships its Resend/Twilio rotators.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Notify`

## Motivation
Notify holds the primary third-party provider credentials (Resend API key, Twilio SID/token). ADR-0006 Tier 2 rotates these via the new `HoneyDrunk.Vault.Rotation` Function. For rotation to actually reach running workers, Notify must resolve these every call via `ISecretStore` and honor Event Grid invalidation — no local caching of the raw key, no version pinning. Also Notify is pending Azure Functions deployment per active-initiatives, so this migration lands alongside the deployment bring-up.

## Proposed Implementation
- Replace startup wiring with `builder.AddVault()` + `builder.AddAppConfiguration()` in both the worker host and any Functions host
- Resend credential: `Resend--ApiKey`
- Twilio credentials: `Twilio--AccountSid`, `Twilio--AuthToken`
- SMTP credentials: `Smtp--Username`, `Smtp--Password`
- Queue connection (Azure Storage Queue): `NotifyQueueConnection` (flat — Node-internal)
- Non-secret provider defaults (from addresses, retry policies, per-channel throttles) → App Configuration label `honeydrunk-notify`
- Providers (`HoneyDrunk.Notify.Providers.Resend`, `.Twilio`, `.Smtp`) must resolve credentials on each outbound call — not cache them in options at bootstrap
- Webhook for Event Grid invalidation registered in both worker host and Functions host
- CI to OIDC workflow

## Affected Packages
- `HoneyDrunk.Notify` (runtime host + worker)
- `HoneyDrunk.Notify.Providers.Resend`
- `HoneyDrunk.Notify.Providers.Twilio`
- `HoneyDrunk.Notify.Providers.Smtp`
- Azure Functions host project (pending deployment)

## Boundary Check
- [x] All secret handling belongs in Notify's provider layer
- [x] No Transport contract change

## Acceptance Criteria
- [ ] Startup uses only env-driven extensions in both host flavors
- [ ] All provider credentials resolved through `ISecretStore` at call time, not at bootstrap
- [ ] Provider-grouped secret naming
- [ ] Non-secret config from App Configuration with Notify label
- [ ] Event Grid invalidation webhook registered
- [ ] Rotation canary: swap `Resend--ApiKey` version, invalidate, confirm next send uses the new key without process restart
- [ ] CI uses OIDC — no client secrets
- [ ] Existing integration tests still pass
- [ ] CHANGELOG updated

## Context
- ADR-0005, ADR-0006
- Invariants 8, 9, 17, 18, 21
- Active initiative: Notification Subsystem Launch (Azure Functions deployment pending — this packet is the deployment bring-up gate)

## Dependencies
- Wave 1 Vault packets
- `architecture-infra-portal-walkthroughs`
- `actions-oidc-federated-credentials-workflow`

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Make Notify's provider credentials rotation-safe and env-driven.
**Target:** HoneyDrunk.Notify, branch from `main`
**Context:**
- Goal: ADR-0005/0006 per-Node migration wave + unblock Notify Azure deployment
- Feature: Configuration/rotation rollout + Notification Subsystem Launch
- ADRs: ADR-0005, ADR-0006

**Acceptance Criteria:** As listed above

**Dependencies:** Wave 1 Vault packets merged; this Node is the canonical test case for Tier-2 rotation.

**Constraints:**
- Invariant 8 — never log Resend/Twilio/SMTP credentials, even during troubleshooting
- Invariant 9 — `ISecretStore` only
- Invariant 17 — `kv-hd-notify-{env}` (6 chars)
- Invariant 21 — no version pinning; credentials must be fetched per call or at least per invalidation boundary

**Key Files:**
- `Program.cs` (both host flavors)
- Provider projects under `HoneyDrunk.Notify.Providers.*`
- `appsettings*.json`
- `.github/workflows/*.yml`
- Azure Functions `host.json`

**Contracts:** None changed.
