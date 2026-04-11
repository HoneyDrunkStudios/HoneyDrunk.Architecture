# Event Grid Subscriptions on Key Vault (Azure Portal)

**Applies to:** ADR-0006 Tier 3.  
**Related invariants:** 20, 21, 22.

## Goal

Subscribe each Key Vault to `Microsoft.KeyVault.SecretNewVersionCreated` so secret rotation events trigger cache invalidation/refresh paths.

## Portal Breadcrumb

**Azure Portal → Key vaults → kv-hd-{service}-{env} → Events → + Event Subscription**

## Step-by-step

1. Open target vault `kv-hd-{service}-{env}`.
2. Go to **Events** → **+ Event Subscription**.
3. Configure basics:
   - Subscription name: `kv-secret-version-created-{service}-{env}`.
   - Event schema: default Event Grid schema.
4. Event types:
   - Select only `Microsoft.KeyVault.SecretNewVersionCreated`.
5. Endpoint:
   - Choose webhook/Azure Function endpoint used by consuming Node invalidation path.
   - Endpoint should be internal and authenticated (managed identity or webhook secret per rollout tiering).
6. Dead-lettering:
   - Enable dead-letter destination (Storage account/container).
7. Create subscription.
8. Complete endpoint validation handshake when prompted.

## Verification

- Event subscription status is **Provisioned**.
- Only `SecretNewVersionCreated` is selected.
- Validation handshake completed successfully.
- Dead-letter destination configured and healthy.
- Test secret version creation generates event delivery success.

## Cross references

- [ADR-0006 Tier 3](../adrs/ADR-0006-secret-rotation-and-lifecycle.md)
- [Invariant 20–22](../constitution/invariants.md)
