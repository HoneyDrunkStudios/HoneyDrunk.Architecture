---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "infrastructure", "docs", "adr-0005", "adr-0006"]
dependencies: []
adrs: ["ADR-0005", "ADR-0006"]
wave: 1
initiative: adr-0005-0006-rollout
node: honeydrunk-architecture
---

# Feature: Architecture infra setup — portal walkthroughs + Vault.Rotation catalog registration

## Summary
Two pieces of Architecture-repo setup work for the ADR-0005/0006 rollout, bundled as one story because both are "make the Architecture repo ready for the new config/rotation world" and both land in the same repo with no code changes:

1. **Portal walkthroughs** for every piece of Azure plumbing ADR-0005 and ADR-0006 require, so the solo dev can stand up a new deployable Node end-to-end without touching CLI.
2. **Catalog registration** for the new `HoneyDrunk.Vault.Rotation` sub-Node so it shows up in routing, dependency walks, and the Grid graph.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0005 Operational Consequences and ADR-0006 New Dependencies explicitly defer portal walkthroughs to `infrastructure/` docs. The user prefers Azure Portal UI over CLI — so these walkthroughs are the actual operational contract, not nice-to-haves. Without them, no Node can actually migrate to the new bootstrap.

ADR-0006 also introduces a brand-new sub-Node (`HoneyDrunk.Vault.Rotation`). Until it is registered in `catalogs/nodes.json` and `catalogs/relationships.json`, every future scope pass will miss it and routing rules will fail to match it. This registration is small and independent of the repo scaffold work happening in the Vault.Rotation packet.

Both pieces are pure docs/JSON edits in the same repo, so a human developer would naturally get them as one sprint story.

## Part A — Portal walkthroughs

### Proposed Implementation
Add new documents under `HoneyDrunk.Architecture/infrastructure/`:

1. **`infrastructure/key-vault-creation.md`** — Portal walkthrough for creating `kv-hd-{service}-{env}`:
   - Resource group selection (`rg-hd-{service}-{env}`)
   - Name validation (24-char limit, 13-char service budget)
   - **RBAC authorization enabled, access policies disabled** (screenshot the toggle)
   - Soft delete + purge protection on
   - Networking defaults (public endpoint + firewall for now; note Private Link as future)
   - Diagnostic settings → route to `log-hd-shared-{env}` (invariant 22)

2. **`infrastructure/key-vault-rbac-assignments.md`** — Portal walkthrough for assigning:
   - `Key Vault Secrets User` to the Node's system-assigned Managed Identity (scoped to that vault only)
   - `Key Vault Secrets Officer` to the GitHub Actions OIDC federated identity (scoped to that vault only)
   - `Key Vault Secrets Officer` to `HoneyDrunk.Vault.Rotation`'s MI on every vault it rotates into
   - Verification steps: "Access control (IAM) → Check access" for each principal

3. **`infrastructure/oidc-federated-credentials.md`** — Portal walkthrough for creating OIDC federated credentials for GitHub Actions:
   - App registration → Federated credentials → Add credential → GitHub Actions preset
   - `{repo, environment}` pair per credential — one per Node per environment
   - Subject format: `repo:HoneyDrunkStudios/{RepoName}:environment:{env}`
   - No client secret issued — critical
   - How to wire the resulting client ID / tenant ID into the repo's GitHub environment secrets (these are non-secret identifiers)

4. **`infrastructure/app-configuration-provisioning.md`** — Portal walkthrough for provisioning `appcs-hd-shared-{env}`:
   - One shared instance per environment, not per Node
   - Enable Managed Identity auth
   - Create per-Node labels matching `HONEYDRUNK_NODE_ID`
   - Feature flag section setup
   - Key Vault references: how to add them and which MI is used to resolve
   - Diagnostic settings → Log Analytics
   - RBAC: `App Configuration Data Reader` to each Node MI, `App Configuration Data Owner` to CI OIDC identities

5. **`infrastructure/event-grid-subscriptions-on-keyvault.md`** — Portal walkthrough for subscribing to `Microsoft.KeyVault.SecretNewVersionCreated`:
   - On each `kv-hd-{service}-{env}` vault: Events → Add Event Subscription
   - Filter to `Microsoft.KeyVault.SecretNewVersionCreated` only
   - Endpoint: the consuming Node's webhook URL (internal, MI-auth or webhook secret per ADR-0006 Tier 3)
   - Dead-lettering config
   - Validation handshake verification

6. **`infrastructure/log-analytics-workspace-and-alerts.md`** — Portal walkthrough for:
   - Creating `log-hd-shared-{env}` Log Analytics workspace
   - Wiring KV diagnostic settings to it (cross-link to walkthrough 1)
   - Creating alert rules:
     - Secret approaching expiry (per ADR-0006 Tier 4)
     - Rotation policy failure
     - Unauthorized access attempt
     - Secret accessed by unexpected identity
   - Pointing to an Azure Monitor dashboard template for secret-age vs SLA

Cross-link all six from a new `infrastructure/README.md` index and from the existing ADR-0005 and ADR-0006 "Operational Consequences" sections via edits.

### Acceptance Criteria — Part A
- [ ] All six documents exist under `infrastructure/`
- [ ] Each walkthrough is step-by-step portal UI instructions (no CLI as primary path; CLI optional in an appendix at most)
- [ ] Screenshots or explicit menu-path breadcrumbs for every step
- [ ] Each document cross-links ADR-0005 and/or ADR-0006 and the relevant invariants (17–22)
- [ ] `infrastructure/README.md` index lists all six with one-line summaries
- [ ] 13-char service-name constraint called out on the KV creation walkthrough
- [ ] RBAC walkthrough explicitly forbids legacy access policies with a callout box

## Part B — Vault.Rotation catalog registration

### Proposed Implementation

#### `catalogs/nodes.json`
Append a new Node entry with at minimum:
```json
{
  "id": "honeydrunk-vault-rotation",
  "type": "node",
  "name": "HoneyDrunk.Vault.Rotation",
  "public_name": "HoneyDrunk.Vault.Rotation",
  "short": "Tier-2 third-party secret rotation Function",
  "description": "Azure Function App that rotates third-party provider secrets (Resend, Twilio, OpenAI, ...) into per-Node Key Vaults on schedule. Sibling to HoneyDrunk.Vault; separate deployable.",
  "sector": "Core",
  "signal": "Seed",
  "cluster": "foundation",
  "tags": ["infrastructure", "rotation", "secrets", "functions", "azure"],
  "links": { "repo": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Vault.Rotation" }
}
```
Match the style of existing entries (see `honeydrunk-vault` block as reference). Mark `signal: "Seed"` until first deployment.

#### `catalogs/relationships.json`
Add edges:
- `honeydrunk-vault-rotation` → `honeydrunk-vault` (consumes `ISecretStore` for its own credentials)
- `honeydrunk-vault-rotation` → `honeydrunk-kernel` (standard Node runtime dependency)
- `honeydrunk-vault-rotation` → every deployable Node whose vault it writes into (dependency direction: rotator → target vaults). Enumerate from current Live deployable Nodes: auth, web-rest, data, notify, pulse (pending), actions, studios. Use the actual IDs present in `nodes.json`.

#### `routing/repo-discovery-rules.md`
Add a keyword mapping row:
```
| rotation, secret rotation, IRotator, RotationResult, third-party rotation, Vault.Rotation | HoneyDrunk.Vault.Rotation |
```

#### `repos/HoneyDrunk.Vault.Rotation/` stub
Create `overview.md`, `boundaries.md`, `active-work.md`, `invariants.md`, `integration-points.md` as minimal stubs pointing at ADR-0006 and marking the Node as "scaffolding in progress". Match the file set present in `repos/HoneyDrunk.Vault/`.

#### `initiatives/active-initiatives.md`
Add a new "Vault.Rotation Bring-Up" initiative entry pointing at the scaffold packet.

### Acceptance Criteria — Part B
- [ ] New Node entry present in `catalogs/nodes.json`, JSON valid, style matches existing entries
- [ ] `catalogs/relationships.json` includes all edges listed above, validated against existing IDs
- [ ] `routing/repo-discovery-rules.md` has the new keyword row
- [ ] `repos/HoneyDrunk.Vault.Rotation/` stub directory created with five minimal files
- [ ] `relationships.json` still forms a DAG (invariant 4)
- [ ] `initiatives/active-initiatives.md` updated with the new initiative entry

## Affected Packages
- None (docs + catalog JSON only)

## Boundary Check
- [x] Infrastructure walkthroughs and catalogs live in HoneyDrunk.Architecture per ADR-0005/0006 Affected Nodes
- [x] No code changes to any other repo
- [x] Portal-first presentation aligns with user preference
- [x] Catalog edits don't invent relationship edges beyond what ADR-0006 supports

## Referenced Invariants

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root.

> **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes (Kernel, Vault, Transport, Architecture) have no vault. See ADR-0005.

> **Invariant 18:** Vault URIs and App Configuration endpoints reach Nodes via environment variables. `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service config at deploy time. Never derived by convention, never hardcoded. See ADR-0005.

> **Invariant 19:** Service names in Azure resource naming must be ≤ 13 characters. Required to fit within Azure's 24-character Key Vault name limit (`kv-hd-{service}-{env}`). See ADR-0005.

> **Invariant 20:** No secret may exceed its tier's rotation SLA without an active exception. Tier 1 (Azure-native): ≤ 30 days. Tier 2 (third-party via rotation Function): ≤ 90 days. Certificates: auto-renewed 30 days before expiry. Exceptions must be logged in Log Analytics. See ADR-0006.

> **Invariant 21:** Applications must never pin to a specific secret version. All secret reads resolve the latest version via `ISecretStore`. Pinning breaks Event Grid cache invalidation and rotation propagation. See ADR-0006.

> **Invariant 22:** Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace. Required for rotation SLA monitoring, unauthorized access alerting, and audit. See ADR-0006.

## Referenced ADR Decisions

**ADR-0005 (Configuration and Secrets Strategy):** Per-deployable-Node Key Vaults (`kv-hd-{service}-{env}`), `{Provider}--{Key}` secret naming, Managed Identity + Azure RBAC access, three-tier config split (Key Vault for secrets, App Configuration for non-secret config, env vars for bootstrap only), and env-var-driven discovery (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`).
- **§Access:** Runtime uses system-assigned Managed Identity with `Key Vault Secrets User` on own vault only. CI uses OIDC federated credentials with `Key Vault Secrets Officer`. Local dev uses File provider or `DefaultAzureCredential` via `az login`. Access policies and client secrets are forbidden.
- **§Three-tier configuration split:** Secrets go in Key Vault, non-secret config goes in shared App Configuration (`appcs-hd-shared-{env}`) with label-per-Node partitioning, env vars are bootstrap only (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`, `ASPNETCORE_ENVIRONMENT`, `HONEYDRUNK_NODE_ID`).
- **§Operational Consequences:** CI pipelines must use OIDC. Service naming bound by 13-char ceiling. Shared App Configuration per environment required. Portal walkthroughs deferred to infrastructure docs.

**ADR-0006 (Secret Rotation and Lifecycle):** Five-tier rotation model — Azure-native rotation (≤30d), third-party rotation via `HoneyDrunk.Vault.Rotation` Function (≤90d), Event Grid cache invalidation on `SecretNewVersionCreated`, audit via Log Analytics, and deploy-blocking rotation SLAs.
- **§Tier 3:** Each Key Vault has an Event Grid subscription on `SecretNewVersionCreated`. A Function/webhook invalidates the `HoneyDrunk.Vault` cache entry. Next `ISecretStore` read fetches latest version. TTL becomes fallback, not primary mechanism. Apps must never pin to a version.
- **§Tier 4:** Diagnostic settings on every Key Vault route to shared Log Analytics. Alert rules for approaching expiry, rotation failure, unauthorized access, unexpected identity access. Dashboard for secret age vs SLA.
- **§New Dependencies:** Shared Log Analytics workspace is cross-cutting. Event Grid subscriptions must be provisioned per vault.
- **§New sub-Node:** `HoneyDrunk.Vault.Rotation` needs its own vault (`kv-hd-vaultrot-{env}`), Managed Identity, RBAC as Secrets Officer on every vault it rotates into, CI pipeline, and standard Grid scaffolding.

## Context
- ADR-0005 §Access, §Three-tier config, §Operational Consequences
- ADR-0006 §Tier 3, §Tier 4, §New dependencies, §New sub-Node
- Invariants 4, 17–22
- User preference: portal over CLI
- `catalogs/nodes.json` existing `honeydrunk-vault` entry as style reference

## Dependencies
None — pure docs and catalog edits. Unblocks every per-Node migration packet and the Vault.Rotation scaffold packet.

## Labels
`feature`, `tier-2`, `meta`, `infrastructure`, `docs`, `adr-0005`, `adr-0006`

## Agent Handoff

**Objective:** Produce the six portal walkthroughs and register the new Vault.Rotation sub-Node in catalogs and routing.
**Target:** HoneyDrunk.Architecture, branch from `main`
**Context:**
- Goal: Make the new config & rotation story operable by the solo dev via portal only, and make the Grid aware of the new sub-Node before downstream migration work begins
- Feature: Configuration/rotation rollout
- ADRs: ADR-0005 (per-deployable-Node Key Vaults, env-var bootstrap, Managed Identity + RBAC, three-tier config split), ADR-0006 (five-tier rotation model, third-party rotation via Vault.Rotation Function, Event Grid cache invalidation, Log Analytics audit, deploy-blocking SLAs)

**Acceptance Criteria:**
- [ ] As listed in Part A and Part B sections above

**Dependencies:** None — foundational docs and catalogs.

**Constraints:**
- Portal-first, CLI only as appendix
- No fabricated screenshots — if the agent can't verify UI paths, write breadcrumb text instructions instead
- Every walkthrough must terminate in a "verification" section so the user knows when it worked
- Invariant 4: `relationships.json` must remain a DAG after the new edges are added
- Don't invent relationship edges beyond what ADR-0006 supports

**Key Files:**
- `infrastructure/key-vault-creation.md` (new)
- `infrastructure/key-vault-rbac-assignments.md` (new)
- `infrastructure/oidc-federated-credentials.md` (new)
- `infrastructure/app-configuration-provisioning.md` (new)
- `infrastructure/event-grid-subscriptions-on-keyvault.md` (new)
- `infrastructure/log-analytics-workspace-and-alerts.md` (new)
- `infrastructure/README.md` (new or updated)
- `catalogs/nodes.json`
- `catalogs/relationships.json`
- `routing/repo-discovery-rules.md`
- `repos/HoneyDrunk.Vault.Rotation/overview.md` (new)
- `repos/HoneyDrunk.Vault.Rotation/boundaries.md` (new)
- `repos/HoneyDrunk.Vault.Rotation/active-work.md` (new)
- `repos/HoneyDrunk.Vault.Rotation/invariants.md` (new)
- `repos/HoneyDrunk.Vault.Rotation/integration-points.md` (new)
- `initiatives/active-initiatives.md`

**Contracts:** None (docs + catalog edits only)
