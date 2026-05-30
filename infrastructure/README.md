# Infrastructure

Operational docs for Grid platform infrastructure — Azure runtime (ADR-0005,
ADR-0006, ADR-0015) and GitHub control-plane auth (ADR-0008, ADR-0012).
Walkthroughs are **portal-first**; CLI is optional appendix material only.

Organized into five folders:

- **[`walkthroughs/`](walkthroughs/)** — step-by-step provisioning runbooks
- **[`conventions/`](conventions/)** — naming/identity/release rules and standards
- **[`reference/`](reference/)** — living inventories and maps (what exists, where)
- **[`openclaw/`](openclaw/)** — OpenClaw gateway provisioning
- **[`workers/`](workers/)** — operator-machine automation such as the ADR-0086 Grid Agent Runner

---

## Walkthroughs

Listed in provisioning order — platform-shared first, per-Node second.

**GitHub platform (provision once for the org):**

- [GitHub Actions failure notifications](github-notifications.md) - Per-account GitHub notification setup for ADR-0012 D7 failed-workflow email alerts.
- [Caller workflow permissions audit](caller-permissions-audit.md) - ADR-0012 D5/GAP-3 baseline audit for reusable `HoneyDrunk.Actions` caller permissions.

- [HoneyDrunk Hive GitHub App](walkthroughs/github-app-hive-walkthrough.md) — Dedicated GitHub App that mints scoped installation tokens for the file-packets reusable workflow. Replaces the developer's PAT for control-plane work.
- [Review-Agent GitHub App for Local Worker](walkthroughs/review-agent-github-app-local-worker.md) — Reused ADR-0044 review-agent App plus `kv-hd-automation-dev` credentials for the ADR-0086 local runner framework.

**Third-party CI tooling (provision once for the org):**

- [SonarQube Cloud organization setup](walkthroughs/sonarcloud-organization-setup.md) — One-time creation of the `honeydrunkstudios` SonarQube Cloud organization, GitHub App install on 20 in-scope public repos, and `SONAR_TOKEN` GitHub org secret provisioning. Prerequisite for per-repo SonarQube Cloud onboarding (ADR-0011 rollout Wave 2+).

**Azure platform-shared (provision once per environment):**

- [Azure Provisioning Guide](walkthroughs/azure-provisioning-guide.md) — End-to-end runbook tying the walkthroughs below together for a new service.
- [Container Registry creation](walkthroughs/container-registry-creation.md) — Shared `acrhdshared{env}` (Basic SKU) in `rg-hd-platform-{env}`, admin disabled, diagnostics to shared Log Analytics.
- [Container Apps Environment creation](walkthroughs/container-apps-environment-creation.md) — Shared `cae-hd-{env}` Consumption-only environment in `rg-hd-platform-{env}`.
- [App Configuration provisioning](walkthroughs/app-configuration-provisioning.md) — Shared `appcs-hd-shared-{env}` with label partitioning, KV references, RBAC.
- [Log Analytics workspace and alerts](walkthroughs/log-analytics-workspace-and-alerts.md) — `log-hd-shared-{env}` plus SLA/security alerting.
- [OIDC federated credentials](walkthroughs/oidc-federated-credentials.md) — GitHub Actions federated credentials per `{repo, environment}`, no client secret.

**Azure per-Node:**

- [Key Vault creation](walkthroughs/key-vault-creation.md) — `kv-hd-{service}-{env}`, RBAC-only auth, naming checks, diagnostics.
- [Key Vault RBAC assignments](walkthroughs/key-vault-rbac-assignments.md) — Least-privilege RBAC for runtime MI, CI OIDC identity, Vault.Rotation MI.
- [Event Grid subscriptions on Key Vault](walkthroughs/event-grid-subscriptions-on-keyvault.md) — Vault events for `SecretNewVersionCreated` cache-invalidation paths.
- [Function App creation](walkthroughs/function-app-creation.md) — `func-hd-{service}-{env}` (Linux Consumption, .NET 10 isolated), system-assigned MI, Grid bootstrap app settings.
- [Container App creation](walkthroughs/container-app-creation.md) — `ca-hd-{service}-{env}` on the shared environment, pulling from the shared registry, system-assigned MI, Grid bootstrap env vars.

## Conventions

- [Azure Naming Conventions](conventions/azure-naming-conventions.md) — canonical resource naming rules and per-type constraints.
- [Azure Identity & Secrets](conventions/azure-identity-and-secrets.md) — OIDC, Key Vault strategy, secret naming, per-service secret lists.
- [Tag & Release Conventions](conventions/tag-and-release-conventions.md) — how git tags map to releases; NuGet `v*` lockstep vs. per-component deploy tags.
- [HoneyDrunk Workflow Standard](conventions/workflow-standard.md) — caller/reusable workflow boundaries for Grid CI, release, and deploy automation.

## Reference

- [Azure Resource Inventory](reference/azure-resource-inventory.md) — every Azure resource provisioned or planned, per environment, with status.
- [Deployment Map](reference/deployment-map.md) — services, their resources, and secret wiring at a glance.
- [Vendor Inventory](reference/vendor-inventory.md) — external vendors/accounts in use.
- [Tech Stack](reference/tech-stack.md) — languages, frameworks, and platform choices.

---

## References

- [ADR-0005: Configuration and Secrets Strategy](../adrs/ADR-0005-configuration-and-secrets-strategy.md)
- [ADR-0006: Secret Rotation and Lifecycle](../adrs/ADR-0006-secret-rotation-and-lifecycle.md)
- [ADR-0008: Packet Lifecycle](../adrs/ADR-0008-work-tracking-and-execution-flow.md)
- [ADR-0011: Code Review and Merge Flow](../adrs/ADR-0011-code-review-and-merge-flow.md)
- [ADR-0012: Actions as CI/CD Control Plane](../adrs/ADR-0012-grid-cicd-control-plane.md)
- [ADR-0015: Container Hosting Platform](../adrs/ADR-0015-container-hosting-platform.md)
- [Grid Invariants](../constitution/invariants.md) — especially invariants 17–22, 31–33, 34–36.
