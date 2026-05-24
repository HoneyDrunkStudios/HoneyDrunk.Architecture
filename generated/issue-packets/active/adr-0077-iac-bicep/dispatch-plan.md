# Dispatch Plan — ADR-0077: Infrastructure-as-Code — Bicep (Azure-native)

**Initiative:** `adr-0077-iac-bicep`
**ADR:** ADR-0077 (Proposed → Accepted via packet 00)
**Sector:** Ops / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0077 commits **Bicep** as the canonical IaC tool for every Azure resource the Grid provisions, with a per-concern modularization strategy, a shared `acrhdbicep` Bicep registry distinct from the per-environment container-image ACR (`acrhdshared{env}`), naming and tagging conventions enforced by linter rules, per-environment parameter files, and an explicit grandfather posture for already-manually-provisioned resources (D6). The ADR is Azure-deep by construction (D5); modularization is the hedge against future Terraform migration cost.

This initiative delivers: ADR acceptance + the three new IaC invariants + catalog registration (Architecture); the Bicep registry ACR provisioning walkthrough and the live `acrhdbicep` resource (Architecture/Human); the `HoneyDrunk.Actions/bicep/modules/` library structure with `bicepconfig.json` linter rules, the first module set (Container App, Key Vault, App Configuration, Storage Account, Service Bus, Application Insights), the `bicep-publish.yml` reusable workflow that publishes modules on tagged releases, the `job-deploy-bicep.yml` reusable deploy workflow consumed by per-Node release workflows, the `bicep lint` PR gate added to `pr-core.yml`; and the per-Node template-scaffold pattern + the D6 import-existing-resources-to-Bicep playbook (Architecture).

**10 packets across 6 waves**, targeting **2 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Actions`). 9 `Actor=Agent`, 1 `Actor=Human` (packet 02 — the ACR portal provisioning).

## Trigger

ADR-0077 is Proposed with no scope. The forcing functions (from the ADR's Context):

- **ADR-0076** Redis provisioning needs per-environment Cache for Redis instances — without an IaC tool, that provisioning happens via Portal or ad-hoc CLI.
- **ADR-0036** DR posture's "re-provision in recovery region" claim is a multi-day operator effort without declarative templates.
- **ADR-0033** environment-gated deploy model requires per-environment parity (dev ≈ staging ≈ prod) — only declarative templates make that enforceable.
- **ADR-0059 (Cache), ADR-0060 (Identity), ADR-0061 (Files)** are imminent Node standups; each provisions Container Apps, Vault namespaces, possibly Postgres/Storage/Redis. The compounding infrastructure surface is about to exceed what manual provisioning can sustain.

The ADR needs decomposition before the next major infrastructure provisioning event lands.

## Scope Detection

**Multi-repo.** ADR-0077 touches `HoneyDrunk.Actions` (the canonical home of the Bicep modules library `bicep/modules/`, the `bicep-publish.yml` workflow, the `job-deploy-bicep.yml` reusable deploy workflow, and the `bicep lint` PR gate per ADR-0012 — Actions is the CI/CD control plane) and `HoneyDrunk.Architecture` (acceptance, invariants, catalog registration, the ACR provisioning walkthrough, the per-Node template-scaffold pattern, the D6 import playbook). Per-Node `infra/main.bicep` templates are deliberately deferred — D6 grandfathers existing infrastructure and per-Node templates land at the first significant infrastructure touchpoint per Node, not as a campaign.

**No cascade into consuming Nodes during this initiative.** Per-Node `infra/main.bicep` adoption is the per-Node concern, executed when the Node provisions a new resource (e.g., ADR-0076 Redis provisioning for the Cache Node) or when an existing resource needs a configuration change (D6). This initiative ships the substrate; downstream Nodes consume it on demand.

## Wave Diagram

### Wave 1 (No Dependencies — governance + catalog)
- [ ] **00** — Architecture: Accept ADR-0077, claim the size-3 invariant block in `invariant-reservations.md` (`{N1}–{N3}`, currently **90–92**), add the three IaC invariants, amend invariant 35 to carve out `acrhdbicep`, register the initiative. `Actor=Agent`.
- [ ] **01** — Architecture: register the Bicep modules library, the `acrhdbicep` registry, and the `bicep-publish.yml` / `job-deploy-bicep.yml` workflows in the Grid catalogs. `Actor=Agent`. Blocked by: 00.

> **Invariant numbering.** Packet 00 claims the next free block in `constitution/invariant-reservations.md` (size 3). At dispatch-plan authoring the block is **90–92**; if a racing ADR's packet 00 merges first, the block shifts upward and every `{N*}` placeholder in packet 00 / `invariants.md` is updated together. The companion text-only amendment to invariant 35 lands in the same PR and is not a renumber.

### Wave 2 (Provision the Bicep registry — depends on Wave 1)
- [ ] **02** — Architecture: author the `bicep-registry-acr-creation.md` walkthrough and provision `acrhdbicep` in the Azure subscription. `Actor=Human`. Blocked by: 00.

### Wave 3 (Bicep substrate in Actions — depends on Wave 2)
- [ ] **03** — Actions: scaffold `bicep/modules/` library layout + `bicepconfig.json` linter rules for naming and tagging conventions (D3). `Actor=Agent`. Blocked by: 00.
- [ ] **04** — Actions: author the `bicep-publish.yml` reusable workflow that publishes modules to `acrhdbicep` on tagged releases (D2). `Actor=Agent`. Blocked by: 02, 03.

### Wave 4 (First module set — depends on Wave 3)
- [ ] **05** — Actions: author the first per-concern Bicep module set — `compute/containerApp`, `secrets/keyVault`, `secrets/appConfigurationStore`, `data/storageAccount`, `messaging/serviceBusNamespace`, `observability/applicationInsights` — and tag `modules/v1.0.0` to publish them. `Actor=Agent`. Blocked by: 03, 04.

### Wave 5 (Deploy workflow + PR gate — depends on Wave 4)
- [ ] **06** — Actions: author the `job-deploy-bicep.yml` reusable deploy workflow that applies a Node's `infra/main.bicep` with per-environment `.bicepparam` (D4). `Actor=Agent`. Blocked by: 05.
- [ ] **07** — Actions: add the `bicep lint` step to `pr-core.yml` so PRs touching any `.bicep` or `.bicepparam` file fail on linter violations (D3 enforcement). `Actor=Agent`. Blocked by: 03.

### Wave 6 (Per-Node adoption substrate — depends on Wave 1, can run in parallel with Wave 3+)
- [ ] **08** — Architecture: author the per-Node Bicep template scaffold pattern in the repo context docs — `infra/main.bicep` + `parameters.{env}.bicepparam` shape, module registry references, the executor checklist for new infrastructure work. `Actor=Agent`. Blocked by: 00.
- [ ] **09** — Architecture: author the `bicep-import-existing-resources.md` playbook for the D6 opportunistic-migration path (export to ARM, decompile to Bicep, reconcile drift, adopt). `Actor=Agent`. Blocked by: 00.

Packets within a wave run in parallel except where noted. **Packets 03 and 07 share `HoneyDrunk.Actions`** but touch different files (`bicep/` vs `.github/workflows/pr-core.yml`); they can land in parallel. **Packets 04 and 05** both extend `bicep/modules/` and share the `bicep-publish.yml` execution path — land 04 first (the workflow), then 05 (which uses it to publish the first module set). **Packet 06** consumes the modules published by 05 in its workflow inputs but does not itself need them to exist at PR time; the workflow ships idle until a per-Node release workflow calls it. **Packets 08 and 09 are independent** of all Actions work and run as early as Wave 1.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0077](./00-architecture-adr-0077-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Bicep modules + registry catalog registration](./01-architecture-bicep-catalog-registration.md) | Architecture | Agent | 1 | 00 |
| 02 | [Bicep registry ACR walkthrough + provisioning](./02-architecture-bicep-registry-acr-walkthrough.md) | Architecture | Human | 2 | 00 |
| 03 | [Bicep modules library scaffold + bicepconfig](./03-actions-bicep-modules-library-scaffold.md) | Actions | Agent | 3 | 00 |
| 04 | [bicep-publish.yml reusable workflow](./04-actions-bicep-publish-workflow.md) | Actions | Agent | 3 | 02, 03 |
| 05 | [First per-concern Bicep module set](./05-actions-bicep-first-module-set.md) | Actions | Agent | 4 | 03, 04 |
| 06 | [job-deploy-bicep.yml reusable deploy workflow](./06-actions-job-deploy-bicep-workflow.md) | Actions | Agent | 5 | 05 |
| 07 | [Add bicep lint gate to pr-core.yml](./07-actions-bicep-lint-pr-gate.md) | Actions | Agent | 5 | 03 |
| 08 | [Per-Node Bicep template scaffold pattern](./08-architecture-per-node-bicep-template-scaffold-pattern.md) | Architecture | Agent | 6 | 00 |
| 09 | [Import-existing-resources-to-Bicep playbook (D6)](./09-architecture-bicep-import-existing-resources-playbook.md) | Architecture | Agent | 6 | 00 |

## Version Bumps

- **`HoneyDrunk.Actions`** — not a versioned .NET solution; the repo ships GitHub Actions YAML + Bicep modules. The Bicep module library has its own SemVer namespace via the `modules/v{N}.{N}.{N}` git-tag pattern (D2); packet 05 ships `modules/v1.0.0`. The repo may keep a `CHANGELOG.md` for the workflow surface; if so, every Actions packet appends an entry per the repo convention.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/catalog/docs edits only.

## Cross-Cutting Concerns

### Coordination with ADR-0076 (Redis) — IMPORTANT

ADR-0076 commits Azure Cache for Redis as the cache backing and names per-environment provisioning. ADR-0077 names ADR-0076 explicitly as the first forcing function. The two should be coordinated:

- **ADR-0076's Redis provisioning is the first natural touchpoint for a per-Node Bicep template.** ADR-0076's provisioning work (when scoped) can land in two shapes: (a) a portal walkthrough (consistent with the operator's portal-over-CLI preference), or (b) a per-Node `infra/main.bicep` consuming the `data/redisCache` module — which the first module set (packet 05) does **not** include in v1.0.0 because the Cache Node standup (ADR-0059) is not yet scoped. **Recommendation:** packet 05 v1.0.0 ships the six concerns the ADR explicitly names; ADR-0076's Redis module lands as `modules/v1.1.0` once the Cache Node's provisioning work is scoped and the resource shape is concrete. Until then, ADR-0076's `dev` provisioning can take the portal route consistent with the D6 grandfather pattern (new resource, but documented as not-yet-Bicep-managed in `grid-health.json`). Do not bundle Redis into packet 05 prematurely.
- **No hard dependency.** ADR-0077 acceptance does not block on ADR-0076's acceptance, and ADR-0076's provisioning does not block on this initiative completing — the first deferral path is "provision via portal now; import to Bicep when the Cache Node's Bicep template lands per D6."

### Coordination with the Node standups (ADR-0059 Cache / ADR-0060 Identity / ADR-0061 Files)

Each of these Node standups will provision Azure resources. Per D6 and the dispatch above:

- **New infrastructure goes through Bicep from day one.** Per ADR-0077 D6: "New infrastructure goes through Bicep from day one." Each Node standup that comes after this initiative completes ships its `infra/main.bicep` + per-environment `.bicepparam` as part of the standup, consuming the modules published by packet 05.
- **Per-Node Bicep templates are scoped by the standup ADR, not by this initiative.** This initiative does not pre-author per-Node templates; doing so would couple Node-shape decisions (Postgres? Storage? region?) to an initiative whose scope is the substrate, not the per-Node infrastructure. The per-Node template lands when the standup ADR is scoped.

### Bicep registry vs container-image registry — separate ACRs

ADR-0077 D2 is explicit: the Bicep modules registry (`acrhdbicep`) is a **dedicated** Azure Container Registry, distinct from the per-environment container-image ACR (`acrhdshared{env}` per ADR-0015 and invariant 35). Reason: Bicep modules are environment-agnostic templates; a single shared registry across environments is the right shape. Per-environment image ACRs are an environment isolation concern; per-environment module ACRs would force version-bump-and-republish per environment for no security gain.

- **Packet 02** provisions `acrhdbicep` in a yet-to-be-decided resource group. Recommended: `rg-hd-platform-shared` (a new platform RG that holds non-environment-scoped resources — the Bicep registry, and any future shared substrate). The walkthrough records the RG decision.
- **Naming.** `acrhdbicep` is alphanumeric, globally unique, 11 chars — comfortably inside the 5–50 char ACR name limit. No environment suffix per its environment-agnostic role.
- **Invariant 35 amendment.** Invariant 35's existing text names `acrhdshared{env}` as "the" shared ACR — `acrhdbicep` is a literal second ACR and collides on a strict reading. Packet 00 amends invariant 35's text in the same PR that adds the new IaC invariants, explicitly carving out `acrhdbicep` as the environment-agnostic, modules-only Bicep registry. The amendment is text-only; invariant 35 keeps its number.

### Naming and tagging linter rules — committed by D3

ADR-0077 D3 commits naming and tagging conventions enforced by `bicepconfig.json` linter rules. Packet 03 ships the `bicepconfig.json` and the rule set; packet 07 wires `bicep lint` into `pr-core.yml` so the rules are enforced at PR time. The rule set must:

- Flag missing required tags (`hd:node`, `hd:env`, `hd:owner`, `hd:cost-center`, `hd:dr-tier`, `hd:adr`).
- Flag non-conformant resource names (per-resource-type prefix, `hd-` Grid identifier, `{service}` or `{node}` name within the ≤13-char service-name length rule from invariant 19, `{env}` suffix).
- Reject hardcoded secret values in templates (D7 — codifies invariant 8 extended to IaC payloads).

The rule set is a single committed `bicepconfig.json` shared across the modules library and per-Node templates; per-Node templates inherit the rule set via Bicep's config-file resolution (file-system search from the template's directory upward, picking up the first `bicepconfig.json`).

### Secrets discipline — codified in invariant 85, enforced by linter

ADR-0077 D7 commits "Bicep templates never contain secret values." Packet 00's invariant 85 codifies it; packet 03's `bicepconfig.json` flags hardcoded secret-shaped strings as a linter rule (best-effort — full secret detection is impractical, but the rule should catch the common cases: `accountKey`, `connectionString`, `password`, `apiKey` literals). The runtime enforcement is the deploy-identity scope (D7): the GitHub Actions OIDC-federated identity has rights to provision resources, not to read secret values — so even if a template accidentally referenced a secret value by name, the deploy would fail with an AAD permission error rather than leaking the secret. This is defense in depth.

### Vendor-exit posture acknowledged in D5 — no rebalancing in this initiative

ADR-0077 D5 names the Azure-deep posture explicitly. The vendor-exit playbook (named in `charter-aware draft cluster 2.1`) is **explicitly out of scope** for this initiative — it lands as a separate ADR when authored. This initiative pre-pays the part of the vendor-exit cost that modularization (D2) addresses; nothing more. Do not bundle vendor-exit work into this initiative.

### Site sync

No site-sync flag. ADR-0077 is internal Ops infrastructure substrate — no public-facing Studios website content changes.

### Deferred follow-ups (explicitly out of scope)

- **Per-Node `infra/main.bicep` adoption.** Per D6, opportunistic, at each Node's next significant infrastructure touchpoint. No campaign.
- **Existing-resource imports.** Per D6, opportunistic. The playbook (packet 09) is the substrate; the actual imports are per-Node concerns.
- **Vendor-exit playbook authoring.** Separate ADR (cluster 2.1).
- **Azure Policy / Azure Blueprints adoption.** ADR-0077 D8 explicitly defers — governance via Policy is a future concern.
- **Cost-allocation tagging beyond the D3 `hd:cost-center` baseline.** Future operational concern.
- **Bicep-generated documentation** (`--summary` output). Nice-to-have; deferred.
- **Subscription / resource-group topology decisions.** D8 defers — the current single-subscription, per-Node-RG convention stands.
- **Cloudflare IaC.** ADR-0029 governs Cloudflare; Bicep is Azure-only by construction. Cloudflare IaC (if ever) is a separate ADR.
- **DR-rehearsal exercise.** ADR-0036's DR-rehearsal is the validation event for the Bicep-driven re-provisioning path; rehearsal scheduling is its own work item, not in this initiative.

## Rollback Plan

- **Packets 00–01 (governance/catalog):** revert the PR. ADR returns to Proposed; the three invariants and the catalog entries are removed. No runtime impact.
- **Packet 02 (ACR provisioning):** `acrhdbicep` can be deleted in the portal; the walkthrough doc reverted. Low cost (Basic SKU), easily reversed. No consumer depends on it until packets 04/05 publish modules.
- **Packet 03 (modules library scaffold):** revert the PR; the `bicep/modules/` tree and `bicepconfig.json` leave the repo. No published module exists yet — clean revert.
- **Packet 04 (publish workflow):** revert the PR; `bicep-publish.yml` leaves the repo. No module has been published unless packet 05 already ran — if so, the published `modules/v1.0.0` tag in `acrhdbicep` is left in place by convention; deleting it requires an explicit ACR-side action and is normally not warranted. **Tag-immutability on ACR Basic tier is honor-system, not enforced** — the Basic SKU does not support repository-level immutability policies (a Premium-tier feature); the workflow's SemVer-bump discipline is what prevents republish-overwrite, not the registry.
- **Packet 05 (first module set):** revert the PR; the module files leave the repo. The published `modules/v1.0.0` in `acrhdbicep` stays in place by convention (tag-immutability is honor-system on Basic tier; SemVer-bump discipline is workflow-enforced — `bicep-publish.yml` refuses to overwrite an existing tag); a future republish bumps to v1.0.1 with the corrected templates rather than overwriting v1.0.0.
- **Packet 06 (deploy workflow):** revert the PR; `job-deploy-bicep.yml` leaves the repo. No per-Node release workflow calls it yet — clean revert.
- **Packet 07 (PR gate):** revert the PR; `bicep lint` is removed from `pr-core.yml`. Existing PRs that previously failed the gate now pass. No runtime impact.
- **Packets 08–09 (docs):** revert the PR; the docs are removed. No runtime impact.
- **Operational escape hatch:** if a Bicep deployment ever produces a worse-than-portal result for a specific resource, the operator can fall back to portal provisioning for that resource and document the deviation in `grid-health.json`. D6's grandfather pattern is bidirectional — manual provisioning was the prior state; Bicep is the forward state; falling back is supported until the issue is reconciled.

## Filing

Filing is automated. On push to `main`, `file-packets.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.
