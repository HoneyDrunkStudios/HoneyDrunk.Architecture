# Wave 2 Handoff — Core Nodes Bootstrap Migration

**Date:** 2026-04-09
**From Wave:** 1 (HoneyDrunk.Vault foundation + HoneyDrunk.Actions OIDC + HoneyDrunk.Architecture docs)
**To Wave:** 2 (per-Node migration)
**Governing ADRs:** ADR-0005, ADR-0006
**Invariants:** 8, 9, 17, 18, 21, 22

## Upstream Changes (must be merged and packaged before Wave 2 starts)

### `HoneyDrunk.Vault` (new preview package, minor bump)

New public surface:

```csharp
// In the AzureKeyVault bootstrap package
public static IHoneyDrunkBuilder AddVault(this IHoneyDrunkBuilder builder);
// Reads AZURE_KEYVAULT_URI via IConfiguration. Throws in non-Development if missing.

// In the AppConfiguration provider package
public static IHoneyDrunkBuilder AddAppConfiguration(
    this IHoneyDrunkBuilder builder,
    Action<AppConfigurationOptions>? configure = null);
// Reads AZURE_APPCONFIG_ENDPOINT via IConfiguration. Labels by HONEYDRUNK_NODE_ID.

// In HoneyDrunk.Vault core
public interface ISecretCacheInvalidator
{
    void Invalidate(string secretName);
    void InvalidateAll();
}

// In HoneyDrunk.Vault.EventGrid (new package)
public static IEndpointRouteBuilder MapVaultInvalidationWebhook(
    this IEndpointRouteBuilder endpoints,
    string pattern = "/internal/vault/invalidate");
```

### `HoneyDrunk.Actions`

Reusable workflow callable from any repo:
```yaml
jobs:
  deploy:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/azure-oidc-deploy.yml@main
    with:
      client-id: ${{ vars.AZURE_CLIENT_ID }}
      tenant-id: ${{ vars.AZURE_TENANT_ID }}
      subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
      resource-group: rg-hd-<service>-<env>
      app-name: <app-service-name>
      artifact-name: <artifact>
      environment: <env>
    permissions:
      id-token: write
      contents: read
```

### `HoneyDrunk.Architecture` portal walkthroughs (available under `infrastructure/`)

- `key-vault-creation.md`
- `key-vault-rbac-assignments.md`
- `oidc-federated-credentials.md`
- `app-configuration-provisioning.md`
- `event-grid-subscriptions-on-keyvault.md`
- `log-analytics-workspace-and-alerts.md`

## What Every Wave-2 Node Must Do

1. Replace explicit vault URI / connection-string wiring in `Program.cs` with `builder.AddVault()` + `builder.AddAppConfiguration()`
2. Audit for direct `IConfiguration["..."]` secret reads — replace with `ISecretStore.GetSecretAsync(name)` using `{Provider}--{Key}` names
3. Move non-secret config to App Configuration under the Node's canonical label (matches `HONEYDRUNK_NODE_ID`)
4. Register the Event Grid invalidation webhook: `app.MapVaultInvalidationWebhook();`
5. Replace CI workflow with the reusable `azure-oidc-deploy.yml` — no `AZURE_CLIENT_SECRET`
6. Provision `kv-hd-{service}-{env}` per environment via the portal walkthrough
7. Wire `AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`, `ASPNETCORE_ENVIRONMENT`, `HONEYDRUNK_NODE_ID` as App Service application settings
8. Ensure no secret version pinning anywhere — all reads must resolve "latest"

## Acceptance Criteria (per Node)

- [ ] Program.cs uses only env-driven extensions
- [ ] Zero direct secret reads (canary test enforced)
- [ ] Provider-grouped secret naming
- [ ] App Configuration integrated with correct label
- [ ] Event Grid webhook registered and exercised by a synthetic event test
- [ ] OIDC CI pipeline green
- [ ] Vault provisioned per environment (manual + documented)
- [ ] CHANGELOG updated
- [ ] Canary + unit tests pass

## Per-Node Labels and Vault Names

| Node | App Config label | Vault name | Service name length |
|---|---|---|---|
| Auth | `honeydrunk-auth` | `kv-hd-auth-{env}` | 4 ✓ |
| Web.Rest | `honeydrunk-web-rest` | `kv-hd-webrest-{env}` | 7 ✓ |
| Data | `honeydrunk-data` | `kv-hd-data-{env}` | 4 ✓ |
| Notify | `honeydrunk-notify` | `kv-hd-notify-{env}` | 6 ✓ |
| Pulse | `pulse` | `kv-hd-pulse-{env}` | 5 ✓ |
| Studios | n/a (plain App Settings) | `kv-hd-studios-{env}` | 7 ✓ |

All within the 13-char budget (invariant 19).

## Constraints

- **Invariant 8:** No secret values in logs, traces, exceptions, telemetry
- **Invariant 9:** `ISecretStore` is the only source of secrets
- **Invariant 17:** One vault per Node per environment, RBAC only, no access policies
- **Invariant 18:** Bootstrap via env vars only — never convention, never hardcoded
- **Invariant 21:** Never pin to a specific secret version
- **Invariant 22:** Diagnostic settings to `log-hd-shared-{env}` (done during vault provisioning)
