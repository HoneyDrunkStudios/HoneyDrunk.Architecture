# Infrastructure Walkthroughs (Portal-First)

These walkthroughs are the operational runbooks for Grid platform provisioning — Azure for runtime infrastructure (ADR-0005, ADR-0006, ADR-0015) and GitHub for control-plane authentication (ADR-0008, ADR-0012). They are written **portal-first**; CLI is optional appendix material only.

## Walkthrough Index

Listed in provisioning order — platform-shared resources first, per-Node resources second.

**GitHub platform (provision once for the org):**

- [HoneyDrunk Hive GitHub App](github-app-hive-walkthrough.md) — Provision the dedicated GitHub App that mints scoped installation tokens for the file-packets reusable workflow. Replaces the developer's PAT for control-plane work.

**Azure platform-shared (provision once per environment):**

- [Container Registry creation](container-registry-creation.md) — Create the shared `acrhdshared{env}` (Basic SKU) in `rg-hd-platform-{env}` with admin disabled and diagnostics routed to shared Log Analytics.
- [Container Apps Environment creation](container-apps-environment-creation.md) — Create the shared `cae-hd-{env}` Consumption-only environment in `rg-hd-platform-{env}` with logs routed to shared Log Analytics.
- [App Configuration provisioning](app-configuration-provisioning.md) — Provision shared `appcs-hd-shared-{env}` with label partitioning, KV references, and RBAC.
- [Log Analytics workspace and alerts](log-analytics-workspace-and-alerts.md) — Provision `log-hd-shared-{env}` and configure SLA/security alerting.
- [OIDC federated credentials](oidc-federated-credentials.md) — Create GitHub Actions federated credentials per `{repo, environment}` with no client secret.

**Azure per-Node:**

- [Key Vault creation](key-vault-creation.md) — Create `kv-hd-{service}-{env}` with RBAC-only auth, naming checks, and diagnostics routing.
- [Key Vault RBAC assignments](key-vault-rbac-assignments.md) — Assign least-privilege RBAC for runtime MI, CI OIDC identity, and Vault.Rotation MI.
- [Event Grid subscriptions on Key Vault](event-grid-subscriptions-on-keyvault.md) — Subscribe vault events for `SecretNewVersionCreated` cache-invalidation paths.
- [Function App creation](function-app-creation.md) — Create `func-hd-{service}-{env}` (Linux Consumption, .NET 10 isolated) with system-assigned MI and Grid bootstrap app settings.
- [Container App creation](container-app-creation.md) — Create `ca-hd-{service}-{env}` bound to the shared environment, pulling from the shared registry, with system-assigned MI and Grid bootstrap env vars.

## References

- [ADR-0005: Configuration and Secrets Strategy](../adrs/ADR-0005-configuration-and-secrets-strategy.md)
- [ADR-0006: Secret Rotation and Lifecycle](../adrs/ADR-0006-secret-rotation-and-lifecycle.md)
- [ADR-0008: Packet Lifecycle](../adrs/ADR-0008-packet-lifecycle.md)
- [ADR-0012: Actions as CI/CD Control Plane](../adrs/ADR-0012-actions-as-cicd-control-plane.md)
- [ADR-0015: Container Hosting Platform](../adrs/ADR-0015-container-hosting-platform.md)
- [Grid Invariants](../constitution/invariants.md) — especially invariants 17–22 and 34–36.
