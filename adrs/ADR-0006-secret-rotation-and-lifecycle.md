# ADR-0006: Secret Rotation and Lifecycle

**Status:** Accepted  
**Date:** 2026-04-09  
**Deciders:** HoneyDrunk Studios  
**Sector:** Infrastructure

## Context

ADR-0005 established where secrets live (`kv-hd-{service}-{env}`), how they are named, and how Nodes authenticate. It deliberately left **lifecycle** — rotation, propagation, audit, and SLAs — as a separate decision.

HoneyDrunk's posture is enterprise-grade: compliance-ready, incident-response-aware, and appropriate for a studio that hosts third-party customer data. Manual rotation is incompatible with that posture. A studio-wide, automated rotation model is needed, and the `HoneyDrunk.Vault` cache must cooperate with it so that rotated secrets actually reach running workloads quickly.

This ADR depends on ADR-0005.

## Decision

Rotation and lifecycle are implemented in five tiers. Each tier owns a distinct concern; together they form the end-to-end story.

### Tier 1 — Azure-native rotation

For any secret Azure can rotate itself, use the native Key Vault rotation policy:

- Storage account keys
- SQL connection strings
- Service Bus and Event Hubs keys
- Cosmos DB keys
- Certificates (KV auto-renewal via integrated CA or certificate policy)

Key Vault rotates on schedule and creates a new secret version. Consumers pick up the new version automatically via the mechanism described in Tier 3.

### Tier 2 — Third-party rotation Function

A new sub-Node, **`HoneyDrunk.Vault.Rotation`**, is introduced as an Azure Function App. It handles secrets for third-party providers Azure cannot rotate natively (Resend, Twilio, OpenAI, and similar).

- Trigger: Event Grid schedule or manual invocation
- Action: Call the provider API to mint a new key, write the new version to Key Vault, and disable the old version after a configured grace period
- Fallback: Where a provider has no rotation API, the Function emits a scheduled reminder and points at a documented portal runbook. The runbook still ends in a Key Vault write, so the downstream propagation path is identical regardless of whether rotation was automated or manual

Having a single shared rotation Node — rather than one per Node — keeps infrastructure duplication low.

### Tier 3 — Propagation via Event Grid cache invalidation

Each Key Vault has an Event Grid subscription on `Microsoft.KeyVault.SecretNewVersionCreated`. On event:

- A small Function or webhook invalidates the `HoneyDrunk.Vault` cache entry for that secret in the consuming Node
- The next read through `ISecretStore` fetches the latest version
- TTL becomes a **fallback**, not the primary propagation mechanism

Applications must never pin to a specific secret version. Resolving "latest" through `ISecretStore` is the only supported pattern. This makes rotation invisible to application code.

### Tier 4 — Audit and alerting

- **Diagnostic settings** on every Key Vault route logs to a shared Log Analytics workspace (`log-hd-shared-{env}`)
- **Alert rules:**
  - Secret approaching expiry
  - Rotation policy failure
  - Unauthorized access attempt
  - Secret accessed by an identity other than the expected Managed Identity
- **Azure Monitor dashboard** visualizing the age of every secret versus its rotation SLA

### Tier 5 — Rotation SLAs (as invariants)

| Secret kind | SLA | Mechanism |
|---|---|---|
| Tier-1 (Azure-native) | ≤ 30 days | KV rotation policy |
| Tier-2 (third-party) | ≤ 90 days | `HoneyDrunk.Vault.Rotation` Function |
| Certificates | Auto-renewed ≥ 30 days before expiry | KV certificate policy |

A secret older than its SLA triggers an alert and **blocks deploys** on the owning Node until resolved.

## Consequences

### New sub-Node

**`HoneyDrunk.Vault.Rotation`** must be scaffolded as a new repo / Function App. It needs:

- Its own `kv-hd-vaultrot-{env}` vault (for provider credentials used by the rotator itself)
- Its own system-assigned Managed Identity
- RBAC grants as `Key Vault Secrets Officer` on every vault it rotates into
- CI pipeline, OIDC federated credentials, and the standard Grid scaffolding

Scaffolding is explicitly **not** part of this ADR — this pass is documentation only. Delegate to the scope agent when ready.

### Code changes

`HoneyDrunk.Vault` cache must support event-driven invalidation. Today it is TTL-only. Adding an `IInvalidate` path (or equivalent) that Event Grid webhooks can call is a required follow-up.

### New dependencies

- The shared Log Analytics workspace (`log-hd-shared-{env}`) becomes a cross-cutting dependency for every deployable Node. It must exist before any Node can ship to that environment.
- Event Grid subscriptions must be provisioned per vault. This is a portal walkthrough, deferred to `infrastructure/` docs.
- Walkthrough index: [Infrastructure Walkthroughs](../infrastructure/README.md).

### New Invariants

The following invariants must be added to `constitution/invariants.md`:

20. **No secret in HoneyDrunk may exceed its tier's rotation SLA without an active exception logged in Log Analytics.**
21. **Applications must never pin to a specific secret version; they must always resolve the latest via `ISecretStore`.**
22. **Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace.**

### Operational Consequences

- Alerts for secret aging, rotation failure, and unauthorized access must be configured per environment
- Deploy pipelines must gate on SLA status before allowing a release
- The `HoneyDrunk.Vault` cache TTL is demoted from "the mechanism" to "the safety net"

## Alternatives Considered

### Manual rotation only

Rejected. Does not meet the enterprise / compliance bar the user has set. Human-scheduled rotation drifts, gets skipped, and is invisible to audit.

### TTL-only propagation

Rejected. TTL was the previous plan, and it works, but it is too slow for incident response. If a key leaks, waiting for TTL expiry is unacceptable. Event-driven invalidation cuts that window to seconds while keeping TTL as a fallback.

### Per-Node rotation Functions

Rejected. Every deployable Node running its own rotation Function duplicates infrastructure, RBAC configuration, and operational burden. One shared `HoneyDrunk.Vault.Rotation` with per-vault grants is simpler and auditable in one place.

### No audit or alerting

Rejected. Incompatible with the enterprise security posture. Without audit, rotation guarantees are aspirational rather than enforced.
