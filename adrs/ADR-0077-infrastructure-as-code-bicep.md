# ADR-0077: Infrastructure-as-Code — Bicep (Azure-native)

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Ops / cross-cutting

## Context

The Grid runs on Azure ([ADR-0015](./ADR-0015-container-hosting-platform.md) Container Apps, Key Vault per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md), App Configuration, Service Bus per [ADR-0028](./ADR-0028-event-driven-architecture-and-messaging.md), Event Grid, Application Insights per [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md) / [ADR-0045](./ADR-0045-grid-wide-error-tracking.md), Azure Cache for Redis per [ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md), and a growing set of supporting resources). Today, infrastructure provisioning is **a mix of**:

- **Manual Azure Portal clicks** for early-stage resource creation (per-Node Vault namespaces were created this way; some Service Bus namespaces).
- **Azure CLI scripts** scattered across `repos/{Node}/` for one-off provisioning tasks.
- **No version-controlled, declarative IaC** for the Grid's overall topology.

This is the failure mode that the charter explicitly warns against drifting into ([`constitution/charter.md`](../constitution/charter.md) §"What this charter forbids" item 2 — foundation that fails to support the workshop). Today's infrastructure can be re-provisioned only by the operator, only by remembering what was done, only in a sequence that has not been captured. The bus-factor risk per [`charter-aware draft cluster 11.2`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) is acute on the infrastructure layer.

The forcing functions converging now:

- **[ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md)** needs to provision per-environment Redis instances. Without an IaC tool, that provisioning happens via Portal or ad-hoc CLI.
- **[ADR-0036](./ADR-0036-disaster-recovery-and-backup-policy.md)** committed DR posture per Node. The DR story requires the ability to **re-provision** infrastructure in a recovery region; without IaC, "re-provision in another region" is a multi-day operator effort.
- **[ADR-0033](./ADR-0033-environment-gated-deploy-trigger-model.md)** committed the environment-gated deploy model. Per-environment infrastructure parity (dev ≈ staging ≈ prod) requires declarative templates; without them, environments drift.
- **[ADR-0053](./ADR-0053-environments-branching-and-release-cadence.md)** committed the per-environment cadence. Standing up a new environment from a template is the right shape; standing it up from operator memory is the wrong shape.
- **The next major infrastructure decision (Identity Node per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md), Files Node per [ADR-0061](./ADR-0061-stand-up-honeydrunk-files-node.md), Cache Node per [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md))** each provisions Azure resources (Container Apps, Vault namespaces, possibly Postgres, possibly Storage, Redis). The compounding infrastructure surface area is about to exceed what manual / ad-hoc provisioning can sustain.

This ADR commits **Bicep** as the IaC tool for all Azure infrastructure, with a modularization strategy, naming and tagging conventions, and an explicit honest acknowledgment of the Azure-deep posture that this commitment reinforces.

The charter framing makes the Azure-deep honesty load-bearing ([`constitution/charter.md`](../constitution/charter.md) §"Build-in-public, honestly"):

> Build-in-public here means showing the **whole shape**, including … honest assessments of what's working and what isn't.

This ADR's Azure-deep commitment is honest about the lock-in cost. A vendor-exit playbook ([`governance/vendor-postures/azure.md`](../governance/vendor-postures/azure.md), authorized by [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md)) is the right complement; this ADR pre-stages the modularization that makes that playbook cheaper.

## Decision

### D1 — Bicep is the canonical IaC tool for all Azure infrastructure

**Bicep** is the IaC tool for every Azure resource the Grid provisions. Every new Azure resource — Container Apps, Key Vault, App Configuration, Service Bus namespaces, Event Grid topics, Storage Accounts, Application Insights, Azure Cache for Redis, anything else — is declared in a Bicep template, version-controlled, and applied through a deploy pipeline.

The committed shape:

- **`.bicep` files** in each Node's repo under `infra/` (or equivalent per-Node convention).
- **`HoneyDrunk.Actions`** ships a reusable deploy workflow (`job-deploy-bicep.yml`) for applying Bicep templates per-environment.
- **No manual Portal provisioning for new resources.** Existing resources grandfather under D6.
- **No raw ARM JSON.** Bicep is the .NET-language-shaped author surface for ARM; raw ARM is forbidden for new work.
- **No Azure CLI scripts as primary IaC.** CLI is permitted for experimental / exploratory work; production-bound provisioning goes through Bicep.

**Why Bicep:**

- **Azure-native, terse, and current.** Bicep is Microsoft's first-party DSL for ARM; supports every Azure preview resource on day one; no provider-version-lag (Terraform's `azurerm` and `azapi` providers lag Azure for preview features). For an Azure-only Grid, the lag question is moot.
- **Terseness over verbosity.** Bicep is ~50% the line count of equivalent ARM JSON and ~30-50% the line count of equivalent Terraform HCL for the same Azure surface. Less code, less to maintain, less for AI agents to author.
- **Strong tooling.** First-party VS Code extension, Bicep CLI for linting and validation, `bicep build` for ARM template compilation, integration with `az deployment` for application.
- **AI-assistance gradient.** Claude / Codex / Copilot in 2026 have meaningful pattern recognition on Bicep; the language is small and well-documented.
- **No state-file overhead.** Unlike Terraform, Bicep does not maintain a separate state file; deployment is reconciled directly against Azure's resource state. One less artifact to manage, secure, and back up.
- **Permissive license + first-party stewardship.** MIT-licensed; maintained by the Azure team directly.

The negative form: Terraform is not adopted; Pulumi is not adopted; raw ARM JSON is not adopted for new work; Azure CLI scripts are not adopted as primary IaC.

### D2 — Modularize by concern

Bicep templates are organized by **concern**, not by Node. The committed structure (shared across the Grid):

| Module group | Owns | Example resources |
|---|---|---|
| **Networking** | Virtual networks, subnets, private endpoints, NSGs, public IPs, DNS zones | `vnet`, `subnet`, `privateDnsZone`, `dnsRecord` |
| **Compute** | Container Apps environment, Container Apps, Container Apps Jobs, Function Apps | `containerAppEnvironment`, `containerApp`, `containerAppJob` |
| **Identity** | Managed identities, role assignments, RBAC scopes | `userAssignedIdentity`, `roleAssignment` |
| **Data** | SQL servers, SQL databases, Postgres servers, Cosmos accounts, Storage accounts, Redis | `sqlServer`, `sqlDatabase`, `postgresServer`, `storageAccount`, `redisCache` |
| **Secrets** | Key Vault, Key Vault secrets-as-resources, App Configuration stores | `keyVault`, `keyVaultSecret`, `appConfigurationStore` |
| **Messaging** | Service Bus namespaces, topics, subscriptions, queues, Event Grid topics | `serviceBusNamespace`, `serviceBusTopic`, `eventGridTopic` |
| **Observability** | Application Insights, Log Analytics, Action Groups, Alerts | `applicationInsights`, `logAnalyticsWorkspace`, `actionGroup` |

Each module is a Bicep file maintained in a shared canonical source location (`HoneyDrunk.Actions/bicep/modules/`) and **published to a dedicated Bicep registry on tagged release**. The registry is an Azure Container Registry (`acrhdbicep`) distinct from the per-environment container-image ACR (`acrhdshared{env}` per [ADR-0015](./ADR-0015-container-hosting-platform.md)) — Bicep modules are environment-agnostic templates, so a single shared registry across environments is the right shape. Per-Node templates consume modules via Bicep registry references (`br:`), never via cross-repo relative paths.

The publish flow:

- Module authors edit `HoneyDrunk.Actions/bicep/modules/` and tag a semantic-version release (`modules/v1.2.0` style).
- A reusable `bicep-publish` workflow in `HoneyDrunk.Actions` runs `az bicep publish` for each changed module against the target registry on tag.
- Module consumers reference the registry path with an immutable version: `br:acrhdbicep.azurecr.io/modules/{concern}/{name}:{semver}`.

Node-specific templates consume the modules via registry refs:

```bicep
// HoneyDrunk.Identity/infra/main.bicep
module identityVault 'br:acrhdbicep.azurecr.io/modules/secrets/keyVault:1.0.0' = {
  name: 'identityVault'
  params: { ... }
}

module identityApp 'br:acrhdbicep.azurecr.io/modules/compute/containerApp:1.0.0' = {
  name: 'identityApp'
  params: { ... }
}
```

The follow-up packet for this ADR (filed at acceptance time) provisions `acrhdbicep`, the publish workflow in `HoneyDrunk.Actions`, and a first set of modules covering Container Apps, Key Vault, App Configuration, Storage, Service Bus, and Application Insights.

**Why modularize by concern, not by Node:**

- **A future Terraform port has module boundaries to mirror.** Per the vendor-exit posture (D5; the Grid's umbrella posture is [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) and the canonical Azure governance file is [`governance/vendor-postures/azure.md`](../governance/vendor-postures/azure.md)), if the Grid ever migrates to Terraform, the per-concern module structure maps directly onto Terraform modules. Per-Node templates would have to be unpicked into per-concern shape during the migration.
- **Cross-Node reuse.** Every Node provisions a Key Vault, a Container App, a managed identity. The per-concern module is written once; per-Node consumption is per-Node parameters.
- **Per-concern review and discipline.** Networking changes have different review concerns than data-layer changes; the module structure makes the concern explicit in the file path.

### D3 — Naming and tagging conventions enforced by Bicep linter rules

Every Bicep template enforces the Grid's existing naming and tagging conventions:

**Naming** per [Invariant 19](../constitution/invariants.md) (the `hd-` prefix convention) and per [ADR-0015](./ADR-0015-container-hosting-platform.md) (`ca-hd-{service}-{env}` for Container Apps), [ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md) (`redis-hd-{env}`), [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) (`kv-hd-{node}-{env}`):

- Per-resource-type prefix (e.g., `ca-`, `redis-`, `kv-`, `sb-`).
- `hd-` Grid identifier.
- `{service}` or `{node}` name (truncated to fit Azure's resource-name length limits).
- `{env}` environment suffix (`dev`, `staging`, `prod`).

**Tags** applied to every resource:

| Tag | Source | Example |
|---|---|---|
| `hd:node` | The Node owning the resource | `honeydrunk-identity` |
| `hd:env` | Environment | `prod` |
| `hd:owner` | Studio identifier | `honeydrunkstudios` |
| `hd:cost-center` | Cost-allocation bucket | `notify-cloud` or `core-infra` |
| `hd:dr-tier` | Per [ADR-0036](./ADR-0036-disaster-recovery-and-backup-policy.md) | `T0`, `T1`, `T2` |
| `hd:adr` | Provisioning ADR | `ADR-0060`, `ADR-0076` |

**Enforcement:** Bicep linter rules in `bicepconfig.json` flag missing required tags and non-conformant names. CI (per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md)) runs `bicep lint` and fails the PR if linter rules violate.

### D4 — Per-environment deployment

Each environment (`dev`, `staging`, `prod`) deploys from the same Bicep templates with per-environment parameter files. The committed shape:

- **`main.bicep`** — the entry-point template per Node (composes module references).
- **`parameters.{env}.bicepparam`** — per-environment parameter values (sizing, naming, regional pinning).
- **CI per-environment job** runs `az deployment group create` (or `az deployment sub create` for subscription-scoped resources) with the appropriate parameter file.

This matches the per-environment cadence per [ADR-0053](./ADR-0053-environments-branching-and-release-cadence.md) — deployments to staging trigger from a tagged commit; deployments to prod trigger from a tagged staging-validated commit. Bicep is the deploy artifact; CI is the orchestrator.

### D5 — Vendor-exit posture acknowledged

This ADR is **Azure-deep**. Bicep is Azure-only by construction; Bicep templates cannot deploy to AWS, GCP, or any other cloud. Adopting Bicep reinforces the Azure lock-in already in place per [ADR-0015](./ADR-0015-container-hosting-platform.md), [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md), [ADR-0028](./ADR-0028-event-driven-architecture-and-messaging.md), [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md), [ADR-0045](./ADR-0045-grid-wide-error-tracking.md), [ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md).

**The honest acknowledgment:**

- **The Grid is Azure-only by current design.** No multi-cloud aspiration; no multi-cloud constraint.
- **A future cloud-migration ADR would be expensive.** Migrating from Azure to AWS or GCP would require: re-authoring every Bicep template in the new cloud's IaC tool; re-implementing every Azure-specific contract backing (Key Vault, App Configuration, Service Bus, Event Grid, App Insights); re-running the entire deployment substrate. This is months-of-engineering work, not weeks.
- **The hedges this ADR pre-pays:** Modularization by concern (D2) means a Terraform port mirrors the module structure 1:1, reducing the per-module migration cost. Per-concern modules are smaller migration units than per-Node monoliths.
- **A vendor-exit playbook for Azure** (authorized by [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md); canonical home [`governance/vendor-postures/azure.md`](../governance/vendor-postures/azure.md)) is the complement. This ADR explicitly does not author the playbook (out of scope); it pre-pays the part of the migration cost that modularization addresses.

**Why this is the right trade today:**

- **Solo-dev productivity wins.** Bicep is markedly faster to author than Terraform for Azure-only workloads; the per-resource line count and the test-iteration cycle are both better.
- **No multi-cloud workload exists or is planned.** The Cyberware sector ([`charter-aware draft cluster 9`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md)) is parked; on-device / edge compute is parked. The Grid is server-side Azure and will remain so for the foreseeable future.
- **Vendor-exit cost is bounded by the modularization.** D2's per-concern module structure is the cheapest hedge against future Azure-migration cost.
- **The honesty matters more than the avoidance.** Per the charter, the Grid is built-in-public; acknowledging the Azure-deep posture explicitly is more honest than pretending otherwise via Terraform window-dressing while still being Azure-only.

### D6 — Migration from existing manual provisioning

Existing manually-provisioned resources (the early Vault namespaces, the existing Service Bus namespaces, the existing Container Apps) **are not retroactively migrated by a cross-cutting campaign**. The discipline matches the grandfather pattern from [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D9, [ADR-0074](./ADR-0074-testing-library-stack.md) D6, [ADR-0075](./ADR-0075-documentation-tooling.md) D4:

- **New infrastructure goes through Bicep from day one.**
- **Existing resources are imported to Bicep opportunistically.** When an existing resource needs a configuration change, the operator authors a Bicep template for it as part of the change. The migration path: export the existing resource to ARM JSON (`az resource show --ids ... --query properties`), decompile it to Bicep (`az bicep decompile --file resource.json`), reconcile drift between the decompiled template and the desired state, and adopt the resource into the deploy pipeline thereafter.
- **A per-Node import-to-Bicep packet** is filed when the Node's next significant infrastructure work happens; not a campaign.

The grandfather posture preserves the working state of existing infrastructure; the migration happens at natural touch points; over months, the Grid converges on Bicep-managed-everything.

### D7 — Secrets in Bicep

Bicep templates **never contain secret values**. The discipline:

- **Secrets reference Vault by URI**, never by value. Bicep templates can declare `keyVaultSecret` references — the Container App's environment variables resolve from Vault at runtime; the secret value never enters the template, the deploy pipeline, or the Azure deployment payload.
- **Parameter files do not contain secrets.** The `.bicepparam` files carry non-secret configuration only.
- **Deploy pipeline does not have secret access.** The deploy identity (the GitHub Actions OIDC-federated identity per the existing CI pattern) has rights to provision resources, not to read secret values.

This is consistent with [Invariant 8](../constitution/invariants.md) (secrets never appear in logs / traces / exceptions / telemetry) extended to IaC payloads.

### D8 — Out of scope

The following are explicitly **not** decided by this ADR:

- **Vendor-exit playbook content.** The umbrella is authorized by [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) and the canonical Azure home is [`governance/vendor-postures/azure.md`](../governance/vendor-postures/azure.md) (stub at acceptance); the full per-surface content remains deferred per ADR-0080 D8.
- **Multi-region deployment topology.** Disaster-recovery cross-region deployment is per [ADR-0036](./ADR-0036-disaster-recovery-and-backup-policy.md); the Bicep templates support per-region parameterization but the topology decision is per-Node.
- **Specific Azure Policy / Azure Blueprints adoption.** Higher-order governance via Azure Policy is a future concern; this ADR's scope is the IaC tool.
- **Cost-allocation tagging beyond D3's `hd:cost-center` baseline.** Detailed cost analytics are a future operational concern.
- **Bicep-generated documentation.** Auto-generated infrastructure docs (e.g., via Bicep's `--summary` output) are a nice-to-have; not committed here.
- **GitHub Actions Bicep deploy workflow specifics.** The workflow lands per HoneyDrunk.Actions's standard contract; the specific shape is a follow-up packet.
- **Subscription / resource-group topology.** The Grid's current subscription is a single subscription with per-Node resource groups (per the existing convention); explicit confirmation is out of scope.

## Amendment (2026-06-02) — Consolidate all Bicep content into `HoneyDrunk.Infrastructure`; drop the cross-repo module registry

**Status of the amendment:** supersedes the *location* and *distribution* mechanics of D1, D2, D4, and one item of D8. The tool choice, modularize-by-concern principle, naming/tagging rules (D3), secrets-by-URI discipline (D7), Azure-deep posture (D5), and grandfather/opportunistic-import posture (D6) are **unchanged**. ADR-0077 was still Proposed when this amendment was authored (packet 00 had not run; nothing had shipped), so this is a pre-implementation course-correction, not a migration off a shipped shape.

This amendment does **not** edit the D1–D8 prose above. The original decisions are preserved as the decision history; the deltas are recorded here and explicitly state which decisions they supersede and why.

### What changes

**All Bicep *content* consolidates into a single new repo, `HoneyDrunk.Infrastructure`.** The *pipeline* does not move — the reusable deploy and lint workflows stay in `HoneyDrunk.Actions` per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md) (Actions is the CI/CD control plane). `HoneyDrunk.Infrastructure` *consumes* `job-deploy-bicep.yml` and the `bicep lint` gate as reusable workflows; only the Bicep templates and modules live in the new repo.

Repository structure:

- **`modules/`** — the per-concern modules (networking, compute, identity, data, secrets, messaging, observability), moved out of `HoneyDrunk.Actions/bicep/modules/`. The per-concern taxonomy from D2 is unchanged; only the home changes.
- **`platform/`** — NEW first-class home for shared / foundational resources that are not owned by any single Node: the shared Container Apps Environment, the shared image ACR (`acrhdshared{env}`), Log Analytics, the shared Service Bus namespace, networking, etc. This closes a gap in the original ADR: the shared layer had no provisioning home, and Nodes consumed it via hand-pasted ARM resource IDs. `platform/` is now where those resources are declared.
- **`nodes/{node}/`** — the thin per-Node leaf templates (`main.bicep` + `parameters.{env}.bicepparam`), relocated out of each Node's own repo.

### Decisions superseded

**D1 (location only — tool choice stays).** Bicep files no longer live in "each Node's repo under `infra/`." Per-Node templates live under `nodes/{node}/` in `HoneyDrunk.Infrastructure`. Bicep remains the canonical IaC tool; only the *location* of the files changes.

**D2 (distribution mechanics dropped — modularize-by-concern stays).** Modules are still organized by concern. But because modules and their consumers now share one repo, modules are referenced by **local relative path** (e.g. `module containerApp '../../modules/compute/containerApp.bicep'`), not via a Bicep registry. The cross-repo distribution machinery existed *solely* to ship modules across repo boundaries, and is therefore dropped in full:

> **REGISTRY DROP — CONFIRMED 2026-06-02.** The following are all dropped as part of this amendment:
> - the dedicated **`acrhdbicep`** Azure Container Registry,
> - the **`bicep-publish.yml`** publish workflow,
> - the **`modules/v{N}.{N}.{N}`** SemVer-tag-to-publish flow,
> - the **`br:acrhdbicep.azurecr.io/...`** registry reference syntax.
>
> A single-repo monorepo for infra content makes a Bicep registry pure overhead. The registry existed *solely* to ship modules across repo boundaries; with `modules/`, `platform/`, and `nodes/` co-located, modules are referenced by local relative path and the registry has no remaining purpose. The operator confirmed the drop on 2026-06-02; no module consumption outside `HoneyDrunk.Infrastructure` is anticipated.

**D4 (location + cadence).** Per-environment `main.bicep` + `parameters.{env}.bicepparam` stays as the deploy shape, but lives per-Node under `nodes/{node}/` and per-platform-concern under `platform/`, rather than in Node repos. Infrastructure deploys on its **own cadence, decoupled from application release tags.** Infra and application code rarely change together; when they do, two separate deploys is acceptable. This supersedes the D4 framing that tied Bicep deployment to the application release-tag flow ("deployments to staging trigger from a tagged commit; deployments to prod trigger from a tagged staging-validated commit"); that tag-coupling was the per-Node-repo assumption and does not survive consolidation.

**D8 (one item revisited — the rest of the deferrals stand).** D8 deferred "subscription / resource-group topology." That deferral is revisited *only* insofar as the new `platform/` layer now needs a home: the recommended home is the **`rg-hd-platform-shared`** resource group already floated in the dispatch plan. All other D8 deferrals (vendor-exit playbook content, multi-region topology, Azure Policy / Blueprints, cost-allocation tagging beyond the D3 baseline, Bicep-generated docs, deploy-workflow specifics, the broader subscription topology) remain intact.

### What stays unchanged

- **D1 tool choice** — Bicep is still the canonical IaC tool.
- **D2 principle** — modularize by concern (the seven concern groups, the Terraform-port-mirrors-modules hedge).
- **D3** — naming and tagging linter rules in `bicepconfig.json`, CI-enforced. A single `bicepconfig.json` at the `HoneyDrunk.Infrastructure` root now covers `modules/`, `platform/`, and `nodes/` via Bicep's config-file resolution.
- **D5** — Azure-deep vendor posture, acknowledged honestly.
- **D6** — grandfather / opportunistic-import posture for existing manually-provisioned resources.
- **D7** — secrets-by-URI discipline; templates never carry secret values.
- **Pipeline home** — the reusable deploy and lint workflows remain in `HoneyDrunk.Actions` per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md). `HoneyDrunk.Infrastructure` consumes them.

### Rationale

- **Solo operator; one PR per cross-Node infra change.** A change that touches three Nodes' infrastructure should be one PR in one repo, not three PRs spread across three repos. Consolidation makes cross-Node infrastructure changes coherent.
- **Per-Node Bicep churn is low-frequency, so the colocation argument is weak.** The high-frequency runtime churn — feature flags, secrets, config — lives in Azure App Configuration + Key Vault per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md), **not** in Bicep. Per-Node Bicep changes (scaling tuning, occasionally adding a resource type) are infrequent, which removes the "keep infra next to the code that changes with it" argument that would otherwise favor per-Node `infra/` directories.
- **The forcing functions the original ADR cited reward one place.** Whole-topology visibility, a coherent DR re-provisioning story ([ADR-0036](./ADR-0036-disaster-recovery-and-backup-policy.md)), explicit cross-resource ordering, and an obvious shared-resource home all favor a single repo. Bus-factor and DR — the forcing functions the original ADR named — are best served by being able to reason about the whole topology in one place.
- **The shared layer finally has a home.** `platform/` closes the gap where shared/foundational resources had no provisioning home and were consumed via hand-pasted ARM resource IDs.

### Amendment consequences

- **`HoneyDrunk.Infrastructure` is a NEW Node.** It needs catalog registration (`nodes.json`, `relationships.json`, `contracts.json`) and routing-rule entries. The original packet 01 registered the substrate under `honeydrunk-actions`; that registration must be reworked for the new repo shape.
- **The existing ADR-0077 dispatch plan and several packets are now partly or fully superseded** (enumerated in the follow-up note below). They are not rewritten by this amendment; a follow-up scope pass re-cuts the dispatch plan.
- **The planned invariant-35 carve-out for `acrhdbicep` is no longer needed** (the carve-out only existed to let a second ACR coexist with `acrhdshared{env}`; with the registry dropped per the confirmed decision above, invariant 35 stands unchanged).

## Consequences

### Affected Nodes

- **HoneyDrunk.Actions** — primary affected Node. Gains `job-deploy-bicep.yml` reusable workflow; hosts the per-concern Bicep modules under `bicep/modules/`.
- **Every Node that provisions Azure resources** — owns `infra/main.bicep` and per-environment `.bicepparam` files in its repo.
- **[ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md)** Cache Node — provisions Azure Cache for Redis instances via Bicep per [ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md).
- **[ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md)** Identity — provisions Container App, Key Vault, managed identity, possibly Postgres via Bicep.
- **[ADR-0061](./ADR-0061-stand-up-honeydrunk-files-node.md)** Files — provisions Storage Account, Container App via Bicep.
- **[ADR-0015](./ADR-0015-container-hosting-platform.md)** Container Apps — existing manual provisioning grandfathers per D6; new Container Apps go through Bicep.
- **[ADR-0036](./ADR-0036-disaster-recovery-and-backup-policy.md)** DR — Bicep enables the "re-provision in recovery region" path that DR posture assumes.

### Invariants

The following are proposed for `constitution/invariants.md` (numbering finalized at acceptance):

- **New Azure infrastructure is provisioned via Bicep.** Manual Portal provisioning of new resources is a boundary violation. Existing resources are grandfathered per D6.
- **Bicep templates never contain secret values.** Secrets reference Vault by URI. (Codifies D7; extends [Invariant 8](../constitution/invariants.md).)
- **Bicep templates apply the Grid naming and tagging conventions per D3.** Linter-enforced; CI gate fails on violation.

### Operational Consequences

- **The Grid's infrastructure becomes reproducible.** "How do I stand up a new dev environment?" goes from "remember every Portal click" to "run the deploy workflow with `env=dev`."
- **DR posture becomes operational.** The "re-provision in recovery region" step in [ADR-0036](./ADR-0036-disaster-recovery-and-backup-policy.md)'s playbook is a single command, not an operator-memory exercise.
- **Bus-factor risk on infrastructure shrinks materially.** A future collaborator (or the operator's future self after a long absence) can reason about the Grid's infrastructure from the templates, not from operator memory.
- **CI cost increases marginally.** Per-PR `bicep lint` and per-deploy `az deployment` runs add minutes to pipeline time; cost is negligible.
- **The Azure-deep posture is now documented.** Honest acknowledgment per D5. Future cloud-migration decisions are made with the cost transparency they deserve.
- **Per-environment infrastructure parity is enforceable.** Drift between dev / staging / prod is now visible (the templates are the same; the parameter files differ).
- **Module-by-concern modularization pre-pays the vendor-exit cost.** A future Terraform port (if ever) maps to the existing module structure; less re-architecture.

### Follow-up Work

- Ship `job-deploy-bicep.yml` reusable workflow in HoneyDrunk.Actions.
- Author the per-concern Bicep modules library under `HoneyDrunk.Actions/bicep/modules/`.
- Per-Node Bicep templates land as part of each Node's scaffolding (or are added at the first significant infrastructure touchpoint per D6).
- ~~Author the vendor-exit playbook for Azure per [`charter-aware draft cluster 2.1`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) (separate ADR).~~ **Resolved 2026-05-24:** authorized by [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md); the Azure canonical home is [`governance/vendor-postures/azure.md`](../governance/vendor-postures/azure.md). Full per-surface content remains deferred per ADR-0080 D8.
- Bicep linter configuration (`bicepconfig.json`) carries the naming + tagging rules per D3.
- Existing infrastructure imports happen opportunistically per D6.
- DR-rehearsal exercise (per [ADR-0036](./ADR-0036-disaster-recovery-and-backup-policy.md)) validates the Bicep-driven re-provisioning path.
- Watch list: Bicep stewardship continues (first-party Microsoft); Bicep language evolves; the Terraform `azapi` provider's coverage trajectory if a future cloud-migration is ever considered.

## Alternatives Considered

### Terraform

Considered. Terraform is the industry-default IaC tool; multi-cloud-capable; broad community; HCL is well-known.

Rejected per D1. (a) Azure-only Grid does not benefit from multi-cloud; the abstraction tax is paid for capability we do not use. (b) Terraform's Azure providers (`azurerm` and `azapi`) lag Azure's preview features by weeks to months; Bicep ships day-of with new Azure capabilities. (c) Terraform's state-file management is an operational burden — securing state, backing it up, locking it across concurrent runs, recovering from corrupted state — that Bicep does not have. (d) HCL is more verbose than Bicep for equivalent Azure resources. (e) AI-assistance gradient on Bicep in 2026 is meaningful and growing.

Held as the candidate destination if the Grid ever migrates off Azure. The per-concern modularization (D2) pre-pays the migration cost.

### Pulumi

Considered. Pulumi is programmatic IaC (TypeScript, C#, Python, Go); first-class .NET support; multi-cloud-capable.

Rejected. (a) Programmatic IaC's benefits (full programming language for templates) are valuable in narrow scenarios (templates that need complex logic) but the Grid's templates do not need that — they are declarative resource declarations with per-environment parameters. The full-language power is paid-for tax. (b) Adds another toolchain (Pulumi CLI, Pulumi state backend, possibly Pulumi-cloud-hosted state) on top of the existing .NET toolchain. (c) State-file concerns similar to Terraform. (d) Bicep's terseness wins for Azure-only declarative authoring; Pulumi's programmatic surface is less terse for the same Azure resource.

### Raw ARM JSON

Considered. ARM JSON is what Bicep compiles to; could be hand-authored.

Rejected on verbosity. ARM templates are ~2x the line count of equivalent Bicep for the same Azure resource. Hand-authored ARM is the right answer for nothing; Bicep is what Microsoft recommends and what AI tools support.

### Azure CLI scripts as primary IaC

Considered. The Grid already has some CLI-based provisioning; extending it Grid-wide would minimize new tooling.

Rejected. Imperative shell scripts have known IaC failure modes — non-idempotent, hard to dry-run, hard to compare against current state, no declarative diff. CLI is permitted for experimental work but not as production-bound IaC. Bicep (or any declarative IaC) is the right substrate.

### Azure Blueprints

Considered. Azure Blueprints is a higher-order grouping over ARM / Bicep for governance-shaped provisioning.

Not adopted at v1. Azure Blueprints' value props (policy assignment, RBAC enforcement at the subscription level) are governance-shaped and overkill for the Grid's single-subscription, solo-dev posture. Reconsidered if the Grid ever moves to a multi-subscription topology.

### Crossplane (Kubernetes-native multi-cloud control plane)

Considered. Crossplane lets Kubernetes deploy and manage cloud resources declaratively.

Rejected. The Grid is not on Kubernetes (per [ADR-0015](./ADR-0015-container-hosting-platform.md)'s Container Apps choice, not AKS). Adopting Crossplane would require running Kubernetes for the sole purpose of using Crossplane's IaC capability — a massive tooling expansion for marginal benefit.

### Adopt both Bicep (for Azure) and Terraform (for non-Azure / future-cloud)

Considered. The argument: hedge the Azure lock-in by maintaining Terraform alongside.

Rejected as premature complexity. The Grid does not have non-Azure infrastructure to manage; maintaining Terraform alongside Bicep for hypothetical future use is exactly the architecture-as-procrastination failure mode the charter warns against. If a future workload requires non-Azure infrastructure, the Terraform decision is made then with concrete requirements; today, single-tool IaC is the right substrate.

### Skip the ADR; let each Node pick its IaC tool

Considered. The argument: IaC is a per-Node concern.

Rejected. Per-Node tool choice produces three IaC tools across five Nodes; cross-Node infrastructure decisions (shared Container Apps environments, shared App Configuration stores, shared monitoring) become impossible to express coherently. The Grid's IaC substrate is Grid-shaped; the tool should be too.

### Defer until a forcing function (a real DR rehearsal, a real new-environment standup, a real bus-factor event)

Considered. The argument: IaC is operationally valuable but not urgent; defer to when the value is concrete.

Rejected per [ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md), [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md), and [ADR-0061](./ADR-0061-stand-up-honeydrunk-files-node.md)'s near-term provisioning demands. Three Nodes are imminently going to provision Azure infrastructure; without the ADR, they each pick (or manually provision) independently. The right time to commit the IaC tool is before the next major provisioning event, not after.

## References

- [`constitution/charter.md`](../constitution/charter.md) — workshop pragmatism, vendor-exit honesty, foundation-investment license, bus-factor concern
- [`constitution/invariants.md`](../constitution/invariants.md) — invariants 8 (secrets discipline), 17 (per-Node Vault namespaces), 19 (naming convention), 34 (Container Apps naming)
- [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) — Vault namespaces (provisioned via Bicep)
- [ADR-0012](./ADR-0012-grid-cicd-control-plane.md) — CI control plane (hosts Bicep deploy workflow)
- [ADR-0015](./ADR-0015-container-hosting-platform.md) — Container Apps (provisioned via Bicep)
- [ADR-0028](./ADR-0028-event-driven-architecture-and-messaging.md) — Service Bus / Event Grid (provisioned via Bicep)
- [ADR-0029](./ADR-0029-cloudflare-dns-and-edge-platform.md) — Cloudflare (separate IaC; out of Bicep scope by construction)
- [ADR-0033](./ADR-0033-environment-gated-deploy-trigger-model.md) — environment-gated deploys (Bicep is the deploy artifact)
- [ADR-0036](./ADR-0036-disaster-recovery-and-backup-policy.md) — DR (Bicep enables re-provisioning)
- [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md) — App Insights (provisioned via Bicep)
- [ADR-0045](./ADR-0045-grid-wide-error-tracking.md) — App Insights for error tracking (provisioned via Bicep)
- [ADR-0053](./ADR-0053-environments-branching-and-release-cadence.md) — per-environment cadence
- [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md), [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md), [ADR-0061](./ADR-0061-stand-up-honeydrunk-files-node.md) — Node standups requiring infrastructure provisioning
- [ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md) — Redis provisioning (first major Bicep-managed resource)
- [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) — vendor lock-in posture umbrella (resolves the future-playbook footnote)
- [`governance/vendor-postures/azure.md`](../governance/vendor-postures/azure.md) — Azure exit-playbook canonical home (stub at acceptance; full per-surface content deferred)
- [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 2.1 — vendor-exit playbook surfacing observation (resolved by ADR-0080)
- [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 11.2 — bus-factor concern (this ADR addresses the infrastructure layer)
