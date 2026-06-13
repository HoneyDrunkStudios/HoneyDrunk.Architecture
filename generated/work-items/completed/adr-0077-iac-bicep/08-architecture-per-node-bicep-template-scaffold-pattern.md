---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0077", "wave-6"]
dependencies: ["work-item:00"]
adrs: ["ADR-0077"]
wave: 6
initiative: adr-0077-iac-bicep
node: honeydrunk-architecture
---

# Author the per-Node Bicep template scaffold pattern for new infrastructure work

> **STATUS — SUPERSEDED (2026-06-02) by packet 15.** Filed as `Architecture#387` (OPEN, unmerged). The ADR-0077 amendment (2026-06-02) relocates per-Node templates to `HoneyDrunk.Infrastructure/nodes/{node}/` (not each Node's own repo) and switches module references from `br:acrhdbicep.azurecr.io/...` (registry, dropped) to local relative path. Packet 15 re-cuts the scaffold pattern to that shape. This packet is retained for traceability; do not execute it. Close `Architecture#387` as superseded by packet 15. See `dispatch-plan.md`.

## Summary
Author `infrastructure/patterns/per-node-bicep-template.md` — the canonical scaffold pattern that the `scope` agent (and human operators) consult when a Node needs to provision new Azure resources. The doc covers the per-Node `infra/` directory layout (`main.bicep` + `parameters.{env}.bicepparam` + per-Node `bicepconfig.json`), module registry-reference syntax, the `tags` parameter shape consumed by modules from packet 05, the `secretRef` shape for any secret-shaped input, the consumer-side `pr-core.yml` wiring for the `bicep lint` gate (packet 07), the consumer-side release-workflow wiring for `job-deploy-bicep.yml` (packet 06), and the per-environment approval-gate pattern per ADR-0033. The doc is the reference the `scope` agent uses to author packets for new per-Node infrastructure work going forward.

## Context
ADR-0077 D6 commits the discipline: "New infrastructure goes through Bicep from day one." Each Node standup (ADR-0059 Cache, ADR-0060 Identity, ADR-0061 Files) — and any future Node that provisions Azure resources — will need a per-Node `infra/main.bicep` and `parameters.{env}.bicepparam`. Without a canonical pattern, each Node's executor invents the layout, the module-reference style, the parameter-file shape, and the workflow wiring independently — guaranteed drift.

This packet authors the pattern once, in the Architecture repo's `infrastructure/patterns/` directory (a new subdirectory; mirrors the existing `infrastructure/walkthroughs/` for repeatable portal procedures). The pattern doc is the canonical reference for:
- The directory layout in a Node repo (`infra/main.bicep`, `infra/parameters.dev.bicepparam`, `infra/parameters.staging.bicepparam`, `infra/parameters.prod.bicepparam`, `infra/bicepconfig.json`).
- The module reference syntax (`module identityVault 'br:acrhdbicep.azurecr.io/modules/secrets/keyVault:1.0.0' = { ... }`) and the immutable-version-pinning discipline.
- The `tags` object the modules consume — composed once per Node, applied uniformly:
  ```bicep
  var tags = {
    'hd:node': '{node}'
    'hd:env': env
    'hd:owner': 'honeydrunkstudios'
    'hd:cost-center': '{cost-center}'
    'hd:dr-tier': '{dr-tier}'
    'hd:adr': '{provisioning-ADR}'
  }
  ```
- The `secretRef` shape for module inputs that need a Vault-stored secret: `{ name: 'X', keyVaultUrl: kv.outputs.vaultUri, identity: containerApp.identity.principalId }` (never `{ password: '...' }`).
- The consumer-side `pr-core.yml` block that wires the `job-bicep-lint.yml` gate (packet 07).
- The consumer-side release-workflow block that wires `job-deploy-bicep.yml` (packet 06) with `environment:` approval gates per ADR-0033 for `staging` / `prod`.
- The Vault-bootstrap pattern: the `keyVault` module outputs the vault URI; the Container App's environment variables wire `AZURE_KEYVAULT_URI` to that URI per invariant 18.
- The DR tag (`hd:dr-tier`) selection per ADR-0036.

The pattern doc explicitly **does not** author per-Node templates for any specific Node — that is per-Node work, scoped by that Node's standup ADR or by an opportunistic-import packet (per D6, see packet 09). The pattern is the scaffold; the per-Node templates are the implementations.

The `scope` agent's instructions point to this pattern when authoring future infrastructure packets. The doc is also consumed by human operators authoring `infra/main.bicep` directly.

This is a docs packet. No code, no .NET project.

## Scope
- `infrastructure/patterns/` (new directory — sibling to `infrastructure/walkthroughs/`)
- `infrastructure/patterns/README.md` (new) — explains what the `patterns/` directory is (canonical scaffold patterns for repeatable per-Node infrastructure work; complements `walkthroughs/` which is for repeatable portal procedures).
- `infrastructure/patterns/per-node-bicep-template.md` (new) — the canonical Bicep template scaffold pattern.

## Proposed Implementation
1. **Create `infrastructure/patterns/`** alongside `infrastructure/walkthroughs/`. Add a `README.md` explaining the directory's purpose.
2. **`infrastructure/patterns/per-node-bicep-template.md`** — author the doc with these sections:
   - **Purpose** — quote ADR-0077 D4/D6 verbatim.
   - **When to use this pattern** — every time a Node needs to provision a new Azure resource (per ADR-0077 D6 "new infrastructure goes through Bicep from day one"); when importing an existing manually-provisioned resource per D6 (cross-reference packet 09's import playbook).
   - **Per-Node `infra/` layout** — the directory shape:
     ```
     infra/
       bicepconfig.json
       main.bicep
       parameters.dev.bicepparam
       parameters.staging.bicepparam
       parameters.prod.bicepparam
     ```
     Note: `bicepconfig.json` is a copy (or `# include`-style reference if Bicep supports it) of `HoneyDrunk.Actions/bicep/bicepconfig.json`; if the Bicep version supports config inheritance via a parent registry, prefer that. **Research the current best practice at execution time** and document the choice — Bicep is evolving.
   - **`main.bicep` template skeleton** — show an annotated example consuming the modules from packet 05. Annotate every block:
     ```bicep
     // The composed Grid tag object applied uniformly to every resource.
     // Required tags per ADR-0077 D3.
     var tags = {
       'hd:node': nodeId
       'hd:env': env
       'hd:owner': 'honeydrunkstudios'
       'hd:cost-center': costCenter
       'hd:dr-tier': drTier
       'hd:adr': 'ADR-XXXX'  // the provisioning ADR for this Node's infra
     }

     module identityVault 'br:acrhdbicep.azurecr.io/modules/secrets/keyVault:1.0.0' = {
       name: 'identityVault'
       params: {
         node: 'identity'
         env: env
         tags: tags
         location: location
         logAnalyticsWorkspaceId: logAnalyticsWorkspaceId  // for invariant-22 diagnostics
       }
     }

     module identityApp 'br:acrhdbicep.azurecr.io/modules/compute/containerApp:1.0.0' = {
       name: 'identityApp'
       params: {
         service: 'identity'
         env: env
         tags: tags
         containerAppEnvironmentId: containerAppEnvironmentId
         imageRef: imageRef
         envVars: [
           { name: 'AZURE_KEYVAULT_URI', value: identityVault.outputs.vaultUri }  // invariant 18
         ]
         secretRefs: []
         ingress: { external: true, targetPort: 8080 }
       }
     }
     ```
     Highlight: (a) the `tags` variable is composed once and passed to every module; (b) all module references use the `br:acrhdbicep.azurecr.io/modules/{concern}/{name}:{semver}` form — no local-path references; (c) the `AZURE_KEYVAULT_URI` env var on the Container App wires invariant 18; (d) no secret value enters the template — secrets are seeded into the Vault out-of-band (portal walkthrough or a separate seed step) and referenced by URI.
   - **`parameters.{env}.bicepparam` template skeleton** — show the shape:
     ```bicep
     using './main.bicep'

     param env = 'dev'
     param location = 'eastus'  // or whichever region this env pins to
     param nodeId = 'honeydrunk-identity'
     param costCenter = 'identity-core'
     param drTier = 'T2'
     param containerAppEnvironmentId = '/subscriptions/.../containerAppsEnvironments/cae-hd-dev'
     param logAnalyticsWorkspaceId = '/subscriptions/.../workspaces/log-hd-shared-dev'
     param imageRef = 'acrhdshareddev.azurecr.io/honeydrunk/identity:0.1.0'
     ```
     Note: per-environment parameter files differ only in their environment-specific values (env, location, the referenced shared resources by id, the image tag). No secret values; ARM resource ids are non-secret references.
   - **Consumer-side `pr-core.yml` wiring** — show the minimal block to opt into the `bicep lint` gate (packet 07):
     ```yaml
     bicep-lint:
       uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-bicep-lint.yml@main
     ```
   - **Consumer-side release-workflow wiring** — show the minimal block to deploy via `job-deploy-bicep.yml` (packet 06) per environment, with `environment:` gates per ADR-0033:
     ```yaml
     deploy-infra-dev:
       if: github.ref_type == 'tag' && contains(github.ref, '-dev')
       environment: dev
       uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-bicep.yml@main
       with:
         env: dev
         template-path: infra/main.bicep
         parameters-path: infra/parameters.dev.bicepparam
         deployment-scope: resourceGroup
         resource-group: rg-hd-{node}-dev
       secrets: inherit

     deploy-infra-staging:
       if: github.ref_type == 'tag' && contains(github.ref, '-staging')
       environment: staging  # GitHub environment approval gate
       uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-bicep.yml@main
       with:
         env: staging
         # ... etc
     ```
     Highlight: the `environment:` requirement is what gates staging / prod per ADR-0033; the `job-deploy-bicep.yml` workflow itself is scope-pure.
   - **Tag composition reference** — list each required tag from ADR-0077 D3 and where its value comes from (the node id, the env, the studio identifier, the cost center per the operator's lean tag scheme, the DR tier per ADR-0036, the provisioning ADR).
   - **What this pattern does NOT cover** — multi-region deployment (per ADR-0077 D8 — DR cross-region is per-Node, not in the pattern); subscription-scoped resources beyond resource-group creation (the `subscription` deployment-scope is supported by packet 06 but its templates are not in this pattern's example); private-link networking (deferred).
   - **Cross-references** — to packet 09's import playbook (for D6 opportunistic migration); to `infrastructure/walkthroughs/bicep-registry-acr-creation.md` (packet 02); to the per-concern module READMEs in `HoneyDrunk.Actions/bicep/modules/*/README.md`.
3. **`infrastructure/patterns/README.md`** — short doc explaining what `patterns/` is and listing the patterns it contains (initially just `per-node-bicep-template.md`).

## Affected Files
- `infrastructure/patterns/` (new directory)
- `infrastructure/patterns/README.md` (new)
- `infrastructure/patterns/per-node-bicep-template.md` (new)

## NuGet Dependencies
None. Docs-only — no .NET project.

## Boundary Check
- [x] `HoneyDrunk.Architecture` is the correct home for patterns and walkthroughs — routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] The pattern doc does not author any per-Node template — it scaffolds the pattern; per-Node templates land in per-Node repos at infrastructure touchpoints.
- [x] No code change in any other repo.

## Acceptance Criteria
- [ ] `infrastructure/patterns/` directory exists with a `README.md` explaining the directory's purpose
- [ ] `infrastructure/patterns/per-node-bicep-template.md` exists and covers: (a) when to use the pattern (per ADR-0077 D6 — new infrastructure goes through Bicep from day one), (b) the per-Node `infra/` directory layout (`main.bicep`, per-environment `.bicepparam` files, per-Node `bicepconfig.json`), (c) an annotated `main.bicep` skeleton consuming modules from packet 05 with the `tags` variable and the registry-reference syntax, (d) a `parameters.{env}.bicepparam` skeleton with no secret values, (e) the consumer-side `pr-core.yml` wiring for the `bicep lint` gate, (f) the consumer-side release-workflow wiring for `job-deploy-bicep.yml` with `environment:`-gated staging / prod per ADR-0033, (g) the tag composition reference per ADR-0077 D3, (h) explicit out-of-scope items
- [ ] Module references in the skeleton use the immutable registry-pinned form `br:acrhdbicep.azurecr.io/modules/{concern}/{name}:{semver}` — never local-path
- [ ] No secret values, connection strings, instrumentation keys, or `AZURE_CREDENTIALS` JSON appear in any code block in the doc (invariant 8 / invariant 85)
- [ ] The doc cross-references packet 02's ACR walkthrough, packet 09's import playbook, packets 06/07's workflows, and the per-concern module READMEs in `HoneyDrunk.Actions/bicep/modules/*/README.md`
- [ ] The annotated skeleton's environment variable on the Container App wires `AZURE_KEYVAULT_URI` (invariant 18)
- [ ] The doc explicitly notes what the pattern does NOT cover (multi-region DR, subscription-scoped beyond RG creation, private-link networking)
- [ ] No per-Node template is authored — patterns scaffold the pattern; per-Node templates land in per-Node repos at infrastructure touchpoints

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0077 D4 — Per-environment deployment.** `main.bicep` entry-point + `parameters.{env}.bicepparam` per-environment. The pattern doc scaffolds this shape.

**ADR-0077 D6 — Migration from existing manual provisioning.** "New infrastructure goes through Bicep from day one." The pattern is what executors follow for new infrastructure.

**ADR-0077 D3 — Naming and tagging.** Required tags `hd:node`, `hd:env`, `hd:owner`, `hd:cost-center`, `hd:dr-tier`, `hd:adr`. The pattern's `tags` variable composes them once per Node.

**ADR-0077 D7 — Secrets in Bicep.** Templates never contain secret values. The pattern's `secretRef` shape and `parameters.{env}.bicepparam` skeleton both demonstrate the discipline.

**ADR-0033 — Environment-gated deploy triggers.** Per-environment release-workflow gating via GitHub `environment:` requirement. The pattern shows the consumer-side wiring.

**ADR-0036 — DR tiers (T0/T1/T2).** The `hd:dr-tier` tag value comes from the Node's DR posture per ADR-0036.

**Invariant 18 — Vault URIs and App Configuration endpoints reach Nodes via environment variables.** The pattern's Container App env-var section wires `AZURE_KEYVAULT_URI` from the `keyVault` module's output.

**Invariant 19 — Service names in Azure resource naming must be ≤ 13 characters.** The pattern documents the constraint and the modules' `@maxLength(13)` enforcement.

## Constraints
- **Pattern, not template.** The doc is scaffold guidance; do not author any per-Node `main.bicep` here.
- **No secret values in code blocks.** Every code block in the doc must be safe to copy-paste; no embedded credentials, even fake-looking ones (no "REPLACE_ME" connection strings).
- **Registry references only.** Every module reference in the doc uses `br:acrhdbicep.azurecr.io/modules/...:{semver}` — never local-path. Reinforce that per-Node templates use registry references.
- **Cross-reference dispatch.** The doc points to the import playbook (packet 09), the ACR walkthrough (packet 02), and the workflows (packets 06/07) so executors of future per-Node infrastructure packets have a single entry point.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0077`, `wave-6`

## Agent Handoff

**Objective:** Author `infrastructure/patterns/per-node-bicep-template.md` (and the `infrastructure/patterns/` directory + README) as the canonical scaffold pattern for per-Node Bicep template work going forward.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Give the `scope` agent and human operators a single canonical reference for per-Node infrastructure work, so each new Node's `infra/main.bicep` is shaped consistently.
- Feature: ADR-0077 IaC — Bicep rollout, Wave 6.
- ADRs: ADR-0077 D3/D4/D6/D7 (primary), ADR-0033 (environment gating), ADR-0036 (DR tiers), invariants 18, 19.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0077 should be Accepted before its pattern doc lands.

**Constraints:**
- Pattern, not template — no per-Node `main.bicep` authored here.
- No secret values in any code block (invariant 8 / 85).
- Registry references only (`br:acrhdbicep.azurecr.io/...`).
- Cross-reference packet 09 (import playbook), packet 02 (ACR walkthrough), packets 06/07 (workflows).

**Key Files:**
- `infrastructure/patterns/README.md` (new)
- `infrastructure/patterns/per-node-bicep-template.md` (new)

**Contracts:** None — docs only.
