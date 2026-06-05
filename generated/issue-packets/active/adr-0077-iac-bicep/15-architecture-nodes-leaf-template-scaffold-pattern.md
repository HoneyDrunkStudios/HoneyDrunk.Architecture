---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0077", "wave-4"]
dependencies: ["packet:18", "packet:13", "packet:14"]
adrs: ["ADR-0077", "ADR-0033", "ADR-0036"]
wave: 4
initiative: adr-0077-iac-bicep
node: honeydrunk-architecture
---

# Author the nodes/{node}/ leaf-template scaffold pattern for the consolidated infra repo

> **Supersedes packet 08** (`Architecture#387`). Packet 08 authored `infrastructure/patterns/per-node-bicep-template.md` assuming per-repo `infra/` directories and `br:acrhdbicep.azurecr.io/...` registry module references. Under the ADR-0077 amendment (2026-06-02): per-Node templates live under `HoneyDrunk.Infrastructure/nodes/{node}/` (relocated out of each Node's repo) and reference modules by **local relative path** (`'../../modules/{concern}/{name}.bicep'`), not via a registry. The pattern doc is re-cut to that shape. Issue `Architecture#387` is closed as superseded by this packet.

## Summary
Author `infrastructure/patterns/node-leaf-template.md` (in `HoneyDrunk.Architecture`) — the canonical scaffold pattern the `scope` agent and operators consult when a Node needs to provision new Azure resources under the consolidated `HoneyDrunk.Infrastructure/nodes/{node}/` shape. The doc covers the `nodes/{node}/` directory layout (`main.bicep` + `parameters.{env}.bicepparam`), the **local relative path** module reference syntax, the `tags` object shape, the `secretRef` shape (D7), how leaf templates reference the `platform/` layer's exported resource IDs (packet 14, closing the hand-pasted-ARM-ID gap), the consumer-side `pr.yml` wiring for the `bicep lint` gate, and the deploy wiring for `job-deploy-bicep.yml` with ADR-0033 environment gates on the infra-deploy cadence (decoupled from application release tags).

## Context
ADR-0077 D6 (unchanged) commits "new infrastructure goes through Bicep from day one." Under the amendment, a Node's infrastructure lives under `HoneyDrunk.Infrastructure/nodes/{node}/`, not in the Node's own repo. Without a canonical pattern, each Node's leaf template would invent its layout, module-reference style, parameter shape, and deploy wiring — guaranteed drift.

The key shape changes from packet 08:
- **Location:** `HoneyDrunk.Infrastructure/nodes/{node}/`, not `{NodeRepo}/infra/`.
- **Module references:** local relative path `'../../modules/{concern}/{name}.bicep'`, not `br:acrhdbicep.azurecr.io/modules/{concern}/{name}:{semver}`.
- **Shared-resource references:** the `platform/` layer's exported resource IDs (packet 14), not hand-pasted ARM strings.
- **Deploy cadence:** infra deploys on its own cadence, decoupled from application release tags (amendment supersedes the D4 tag-coupling framing).
- **`bicepconfig.json`:** inherited from the single repo-root config (packet 11) via Bicep config-file resolution — no per-Node `bicepconfig.json`.

This is a docs packet. No code, no .NET project.

## Scope
- `infrastructure/patterns/node-leaf-template.md` (new) — the canonical leaf-template scaffold pattern.
- `infrastructure/patterns/README.md` (new or updated) — explains the `patterns/` directory and lists this pattern.
- (If packet 08's `per-node-bicep-template.md` was ever created on disk — it was not, packet 08 is unshipped — this packet writes the corrected `node-leaf-template.md` fresh; do not retain the registry-shaped predecessor.)

## Proposed Implementation
1. **Create / update `infrastructure/patterns/`** with a README listing the pattern.
2. **`infrastructure/patterns/node-leaf-template.md`** — sections:
   - **Purpose** — quote ADR-0077 D4/D6 + the amendment's `nodes/{node}/` consolidation.
   - **When to use** — every time a Node needs to provision a new Azure resource; when importing an existing manually-provisioned resource per D6 (cross-reference packet 17).
   - **`nodes/{node}/` layout:**
     ```
     nodes/{node}/
       main.bicep
       parameters.dev.bicepparam
       parameters.staging.bicepparam
       parameters.prod.bicepparam
     ```
     Note: no per-Node `bicepconfig.json` — the repo-root config (packet 11) governs via config-file resolution.
   - **`main.bicep` skeleton** — annotated example consuming modules by **local relative path** and referencing `platform/` exported IDs:
     ```bicep
     // The composed Grid tag object (ADR-0077 D3), applied uniformly.
     var tags = {
       'hd:node': nodeId
       'hd:env': env
       'hd:owner': 'honeydrunkstudios'
       'hd:cost-center': costCenter
       'hd:dr-tier': drTier
       'hd:adr': 'ADR-XXXX'  // the provisioning ADR for this Node's infra
     }

     module nodeVault '../../modules/secrets/keyVault.bicep' = {
       name: 'nodeVault'
       params: {
         service: 'identity', env: env, tags: tags, location: location
         logAnalyticsWorkspaceId: platformLogAnalyticsId  // from platform/ outputs (invariant 22)
       }
     }

     module nodeApp '../../modules/compute/containerApp.bicep' = {
       name: 'nodeApp'
       params: {
         service: 'identity', env: env, tags: tags
         containerAppEnvironmentId: platformCaeId  // from platform/ outputs (invariant 35)
         imageRef: imageRef
         envVars: [ { name: 'AZURE_KEYVAULT_URI', value: nodeVault.outputs.vaultUri } ]  // invariant 18
       }
     }
     ```
     Highlight: (a) `tags` composed once; (b) **all module references are local relative path** — no `br:`; (c) shared resources come from `platform/` exported IDs (`platformLogAnalyticsId`, `platformCaeId`), not hand-pasted ARM strings; (d) `AZURE_KEYVAULT_URI` wires invariant 18; (e) no secret value enters the template (D7).
   - **`parameters.{env}.bicepparam` skeleton** — `using './main.bicep'`, per-env values, the `platform/` exported IDs passed in (or referenced via a shared params module), no secret values.
   - **Consumer-side `pr.yml` wiring** — the `bicep lint` gate (consumed from Actions per packet 16):
     ```yaml
     bicep-lint:
       uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-bicep-lint.yml@main
     ```
   - **Deploy wiring** — `job-deploy-bicep.yml` (packet 16) per environment, with ADR-0033 `environment:` gates, on the **infra-deploy cadence** (decoupled from application release tags):
     ```yaml
     deploy-node-infra-dev:
       environment: dev
       uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-bicep.yml@main
       with:
         env: dev
         template-path: nodes/identity/main.bicep
         parameters-path: nodes/identity/parameters.dev.bicepparam
         deployment-scope: resourceGroup
         resource-group: rg-hd-identity-dev
       secrets: inherit
     ```
     Highlight: the trigger is the infra repo's own cadence (push to `main` / a manual dispatch / an infra tag), NOT the application Node's release tag — the amendment decoupled these.
   - **Tag composition reference** — each required tag and its source.
   - **What this pattern does NOT cover** — multi-region DR (per-Node, ADR-0077 D8); subscription-scoped resources beyond RG; private-link networking.
   - **Cross-references** — packet 17 (import playbook), packet 14 (`platform/` exported IDs), the module READMEs in `HoneyDrunk.Infrastructure/modules/*/README.md`.
3. **`infrastructure/patterns/README.md`** — list the pattern.

## Affected Files
- `infrastructure/patterns/README.md` (new/updated)
- `infrastructure/patterns/node-leaf-template.md` (new)

## NuGet Dependencies
None. Docs only; no .NET project.

## Boundary Check
- [x] `HoneyDrunk.Architecture` is the home for patterns/walkthroughs — routing maps exactly.
- [x] The pattern doc authors no per-Node template — per-Node leaf templates land in `HoneyDrunk.Infrastructure/nodes/{node}/` at each Node's infrastructure touchpoint.
- [x] No code change in any other repo.

## Acceptance Criteria
- [ ] `infrastructure/patterns/node-leaf-template.md` exists covering: (a) when to use, (b) the `nodes/{node}/` layout (no per-Node bicepconfig), (c) an annotated `main.bicep` skeleton with **local-relative-path** module refs and `platform/` exported-ID references, (d) a `parameters.{env}.bicepparam` skeleton with no secrets, (e) consumer-side `bicep lint` wiring, (f) `job-deploy-bicep.yml` deploy wiring with ADR-0033 env gates on the infra cadence, (g) the tag composition reference, (h) explicit out-of-scope items
- [ ] Every module reference in the doc uses the **local relative path** form `'../../modules/{concern}/{name}.bicep'` — NO `br:acrhdbicep.azurecr.io/...` anywhere
- [ ] Shared-resource references use the `platform/` layer's exported IDs (packet 14), NOT hand-pasted ARM strings — the doc states this closes the original gap
- [ ] The deploy-wiring section states infra deploys on its own cadence, decoupled from application release tags (amendment supersedes the D4 tag-coupling)
- [ ] No secret values, connection strings, instrumentation keys, or `AZURE_CREDENTIALS` JSON in any code block (invariant 8 / D7)
- [ ] The skeleton wires `AZURE_KEYVAULT_URI` (invariant 18)
- [ ] The doc cross-references packet 17 (import playbook), packet 14 (`platform/` IDs), the module READMEs
- [ ] No per-Node template is authored

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0077 amendment (2026-06-02) — `nodes/{node}/` consolidation + local-path refs.** Per-Node templates live in `HoneyDrunk.Infrastructure/nodes/{node}/`, reference modules by local relative path, reference shared resources via `platform/` exported IDs, deploy on the infra cadence decoupled from app release tags.

**ADR-0077 D4 (location + cadence amended) — per-environment deployment.** `main.bicep` + `parameters.{env}.bicepparam`, now under `nodes/{node}/`; infra deploys on its own cadence.

**ADR-0077 D6 (unchanged) — new infrastructure goes through Bicep from day one.**

**ADR-0077 D3 (unchanged) — required tags; the `tags` object composes them once.**

**ADR-0077 D7 (unchanged) — templates never contain secret values.**

**ADR-0033 — environment-gated deploys** via GitHub `environment:` approval.

**ADR-0036 — DR tiers (T0/T1/T2)** feed the `hd:dr-tier` tag.

**Invariant 18 — Vault URIs reach Nodes via environment variables** (`AZURE_KEYVAULT_URI`). **Invariant 19 — ≤13-char service names.** **Invariant 35 — shared CAE + image ACR per env** (referenced via `platform/` outputs).

## Constraints
- **Local-path references only.** Every module reference in the doc is `'../../modules/{concern}/{name}.bicep'`. No `br:` anywhere — this is the load-bearing change from packet 08.
- **Reference `platform/` exported IDs.** Shared resources come from the platform layer's outputs, not hand-pasted ARM strings.
- **Pattern, not template.** No per-Node `main.bicep` authored here.
- **No secret values in code blocks** — safe to copy-paste, no fake credentials.
- **Decoupled cadence.** State that infra deploys on its own cadence, not on application release tags.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0077`, `wave-4`

## Agent Handoff

**Objective:** Author `infrastructure/patterns/node-leaf-template.md` — the canonical `nodes/{node}/` leaf-template scaffold pattern with local-path module refs and `platform/` exported-ID references, replacing the registry-shaped packet-08 predecessor.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: One canonical reference for per-Node infra work under the consolidated repo, so each Node's leaf template is shaped consistently.
- Feature: ADR-0077 IaC — Bicep rollout (amended 2026-06-02), Wave 4.
- ADRs: ADR-0077 + 2026-06-02 amendment (primary), ADR-0033 (env gates), ADR-0036 (DR tiers), invariants 18, 19, 35.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0077 (amended) Accepted.
- `packet:13` — the modules the skeleton references exist.
- `packet:14` — the `platform/` exported IDs the skeleton references exist.

**Constraints:**
- Local-path module refs only — no `br:`.
- Reference `platform/` exported IDs, not hand-pasted ARM strings.
- Pattern, not template.
- No secrets in code blocks.
- Decoupled infra-deploy cadence.

**Key Files:**
- `infrastructure/patterns/node-leaf-template.md` (new)
- `infrastructure/patterns/README.md` (new/updated)

**Contracts:** None — docs only.
