# Infrastructure Walkthroughs (Portal-First)

These walkthroughs are the operational runbooks for ADR-0005 and ADR-0006 rollout work. They are written for **Azure Portal first**; CLI is optional appendix material only.

## Walkthrough Index

- [Key Vault creation](key-vault-creation.md) — Create `kv-hd-{service}-{env}` with RBAC-only auth, naming checks, and diagnostics routing.
- [Key Vault RBAC assignments](key-vault-rbac-assignments.md) — Assign least-privilege RBAC for runtime MI, CI OIDC identity, and Vault.Rotation MI.
- [OIDC federated credentials](oidc-federated-credentials.md) — Create GitHub Actions federated credentials per `{repo, environment}` with no client secret.
- [App Configuration provisioning](app-configuration-provisioning.md) — Provision shared `appcs-hd-shared-{env}` with label partitioning, KV references, and RBAC.
- [Event Grid subscriptions on Key Vault](event-grid-subscriptions-on-keyvault.md) — Subscribe vault events for `SecretNewVersionCreated` cache-invalidation paths.
- [Log Analytics workspace and alerts](log-analytics-workspace-and-alerts.md) — Provision `log-hd-shared-{env}` and configure SLA/security alerting.

## References

- [ADR-0005: Configuration and Secrets Strategy](../adrs/ADR-0005-configuration-and-secrets-strategy.md)
- [ADR-0006: Secret Rotation and Lifecycle](../adrs/ADR-0006-secret-rotation-and-lifecycle.md)
- [Grid Invariants](../constitution/invariants.md) — especially invariants 17–22.
