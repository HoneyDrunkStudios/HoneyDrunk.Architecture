# Dispatch Plan — ADR-0077: Infrastructure-as-Code — Bicep (Azure-native)

**Initiative:** `adr-0077-iac-bicep`
**ADR:** ADR-0077 (Proposed → Accepted via packet 18) — **amended 2026-06-02** (consolidate Bicep content into `HoneyDrunk.Infrastructure`; drop the cross-repo module registry)
**Sector:** Ops / cross-cutting
**Created:** 2026-05-24
**Re-cut:** 2026-06-02 (ADR amendment)

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries (and, here, at an ADR-amendment boundary) as a historical record. The individual packets are immutable once filed; the re-cut is expressed by **superseding** the affected packets, not by rewriting them.

## Amendment re-cut summary (2026-06-02)

ADR-0077 was amended on 2026-06-02 (the `## Amendment (2026-06-02)` block in the ADR is the source of truth). The amendment:

1. **Consolidates all Bicep *content* into a single NEW repo, `HoneyDrunk.Infrastructure`:** `modules/` (the seven per-concern groups, moved out of `HoneyDrunk.Actions`), `platform/` (NEW first-class home for shared/foundational resources — shared Container Apps Environment, shared image ACR `acrhdshared{env}`, Log Analytics, shared Service Bus, networking), and `nodes/{node}/` (thin per-Node leaf templates relocated out of each Node's repo). Modules are referenced by **local relative path**, not a registry.
2. **Drops the cross-repo module registry in full:** no `acrhdbicep` ACR, no `bicep-publish.yml`, no `modules/v{N}.{N}.{N}` SemVer-tag-publish flow, no `br:acrhdbicep.azurecr.io/...` refs.
3. **Keeps the deploy/lint *pipeline* in `HoneyDrunk.Actions`** per ADR-0012 (CI/CD control plane). `HoneyDrunk.Infrastructure` *consumes* `job-deploy-bicep.yml` and the `bicep lint` gate.
4. **Decouples infra deploys from application release tags** — infra deploys on its own cadence.
5. **Leaves invariant 35 unchanged** — the `acrhdbicep` carve-out is no longer needed (registry dropped).

**The initiative is now 3 repos:** `HoneyDrunk.Architecture` (governance/catalog/docs), `HoneyDrunk.Actions` (pipeline: deploy + lint reusable workflows), `HoneyDrunk.Infrastructure` (all Bicep content: modules + platform + nodes).

### Filing-status check (2026-06-02)

**All ten original packets (00–09) were already FILED as GitHub issues and are OPEN** (verified live via `gh` against the `filed-work-items.json` manifest):

| Original packet | Issue | State |
|---|---|---|
| 00 acceptance | `Architecture#384` | OPEN |
| 01 catalog registration | `Architecture#385` | OPEN |
| 02 registry ACR walkthrough | `Architecture#386` | OPEN |
| 03 modules library scaffold | `Actions#118` | OPEN |
| 04 publish workflow | `Actions#119` | OPEN |
| 05 first module set | `Actions#120` | OPEN |
| 06 deploy workflow | `Actions#121` | OPEN |
| 07 bicep lint PR gate | `Actions#122` | OPEN |
| 08 per-Node scaffold pattern | `Architecture#387` | OPEN |
| 09 import playbook | `Architecture#388` | OPEN |

The work has **not shipped** — ADR-0077 is still `Proposed` on `main`, and no packet PR has merged. But because the packets are filed, **invariant 24 binds: filed packets are immutable.** Therefore the re-cut **supersedes** the affected packets (new packets that obsolete the old + a `STATUS — SUPERSEDED` banner on each original); it does **not** rewrite them in place. The dispatch plan (this file) is the ADR-0008 D7 living-narrative exception and IS edited in place.

### Per-packet disposition

| Original | Disposition | Successor | Issue to close |
|---|---|---|---|
| **00** acceptance | Superseded | **18** (drops invariant-35 carve-out; rewords IaC invariants for no-registry/consolidated shape) | `Architecture#384` |
| **01** catalog registration | Superseded | **10** (new `HoneyDrunk.Infrastructure` Node registration) + **12** (Actions-side pipeline-workflows-only catalog edit; drops `acrhdbicep` grid-health entry) | `Architecture#385` |
| **02** registry ACR walkthrough | **DEAD** | residue (the `rg-hd-platform-shared` RG decision) → **14** | `Architecture#386` |
| **03** modules scaffold + `bicepconfig.json` | Superseded | **11** (tree + single root `bicepconfig.json` in the new repo) + **13** (module bodies) | `Actions#118` |
| **04** publish workflow | **DEAD** (no successor — registry dropped) | — | `Actions#119` |
| **05** first module set + `v1.0.0` tag-publish | Superseded | **13** (module authoring relocates to `HoneyDrunk.Infrastructure/modules/`; tag-publish dies) | `Actions#120` |
| **06** `job-deploy-bicep.yml` | Superseded | **16** (stays Actions-owned; inputs consume local-path templates from the infra repo, no `br:` refs, decoupled cadence) | `Actions#121` |
| **07** `bicep lint` PR gate | **UNTOUCHED** (shape-neutral; lints `.bicep`/`.bicepparam` generically; stays Actions-owned; consumed by the infra repo's `pr.yml`) | — (still `Actions#122`) | — |
| **08** per-Node scaffold pattern | Superseded | **15** (`nodes/{node}/` shape, local-path module refs, `platform/` exported-ID references) | `Architecture#387` |
| **09** import-existing-resources playbook | Superseded | **17** (re-cut for the consolidated repo; targets `nodes/{node}/`/`platform/`; local-path refs; cross-refs to 14/15/16) | `Architecture#388` |

**NEW packets (no predecessor):**
- **10** — `HoneyDrunk.Infrastructure` Node registration in the catalogs + routing rules + five-file context folder (invariant 102 Phase A).
- **11** — `HoneyDrunk.Infrastructure` repo standup / scaffold (tree, root `bicepconfig.json`, consume-Actions wiring) — the bootstrap PR.
- **14** — `platform/` shared-foundation provisioning (closes the shared-layer gap; absorbs packet 02's `rg-hd-platform-shared` residue).

> **Operator action required at filing time:** when the re-cut packets are eventually filed, the ten OPEN superseded/dead issues above should be CLOSED with a comment pointing at their successors. The scope agent does not close issues; this is an operator (or `hive-sync`) step.

## Summary

ADR-0077 commits **Bicep** as the canonical IaC tool for every Azure resource the Grid provisions, with a per-concern modularization strategy, naming and tagging conventions enforced by linter rules, per-environment parameter files, and an explicit grandfather posture for already-manually-provisioned resources (D6). The ADR is Azure-deep by construction (D5); modularization is the hedge against future Terraform migration cost.

Post-amendment, this initiative delivers: ADR acceptance + the three new IaC invariants + the new `HoneyDrunk.Infrastructure` Node registration + the Actions-pipeline catalog edit (Architecture); the `HoneyDrunk.Infrastructure` repo standup (tree + single root `bicepconfig.json` + consume-Actions wiring), the first per-concern module set (consumed by local relative path), and the NEW `platform/` shared-foundation layer (`HoneyDrunk.Infrastructure`); the `job-deploy-bicep.yml` reusable deploy workflow (inputs adjusted for local-path templates) and the `bicep lint` PR gate (unchanged) (`HoneyDrunk.Actions`); and the `nodes/{node}/` leaf-template-scaffold pattern + the D6 import-existing-resources playbook (Architecture).

**Active packets: 07 (untouched) + 10–18 (re-cut/new) = 10 packets across 4 waves, targeting 3 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Actions`, `HoneyDrunk.Infrastructure`). All `Actor=Agent`; several carry Human Prerequisites (repo creation, RG/RBAC provisioning, deploy approvals) but the code-change work is delegable. The 10 original packets (00–09) are superseded/dead/untouched per the table above.

## Trigger

ADR-0077 was Proposed; its original scope was decomposed into packets 00–09 (filed). The 2026-06-02 amendment course-corrects the location/distribution mechanics before any packet shipped. The forcing functions (from the ADR's Context) are unchanged:

- **ADR-0076** Redis provisioning needs per-environment Cache for Redis instances.
- **ADR-0036** DR posture's "re-provision in recovery region" claim.
- **ADR-0033** environment-gated deploy model requires per-environment parity.
- **ADR-0059 (Cache), ADR-0060 (Identity), ADR-0061 (Files)** imminent Node standups, each provisioning Azure resources.

The amendment additionally argues: a solo operator wants one PR per cross-Node infra change (one repo, not three); per-Node Bicep churn is low-frequency (the colocation argument is weak); whole-topology visibility + DR + a shared-resource home all favor one place; and `platform/` finally gives the shared layer a home.

## Scope Detection

**Multi-repo (now three repos).**
- **`HoneyDrunk.Architecture`** — acceptance, invariants, the new Node registration, the Actions-pipeline catalog edit, the `nodes/{node}/` scaffold pattern, the D6 import playbook.
- **`HoneyDrunk.Actions`** — the deploy + lint reusable workflows (the *pipeline* stays here per ADR-0012); only Bicep *content* moved.
- **`HoneyDrunk.Infrastructure`** (NEW) — all Bicep content: `modules/`, `platform/`, `nodes/`.

**No runtime cascade into consuming Nodes.** Bicep content is a deploy-time artifact, not a runtime dependency. Per-Node leaf templates land under `nodes/{node}/` at each Node's infrastructure touchpoint (per D6), scoped by that Node's standup ADR — not by this initiative.

## Wave Diagram

### Wave 1 (No Dependencies — governance + catalog, Architecture)
- [ ] **18** — Architecture: Accept ADR-0077 (amended), claim the size-3 invariant block, add the three IaC invariants (reworded for the no-registry/consolidated shape), register the initiative. **Do NOT amend invariant 35.** `Actor=Agent`. (Supersedes 00 / `Architecture#384`.)
- [ ] **10** — Architecture: register `HoneyDrunk.Infrastructure` as a new Node (nodes/relationships/grid-health/contracts catalogs, routing keyword row, sectors row, five-file context folder). `Actor=Agent`. Blocked by: 18. (Supersedes the Infrastructure-Node-registration scope of 01 / `Architecture#385`.)
- [ ] **12** — Architecture: register the Bicep deploy + lint reusable workflows under `honeydrunk-actions` in the catalogs; ensure no `acrhdbicep` grid-health entry. `Actor=Agent`. Blocked by: 18, 10. (Supersedes the Actions-side scope of 01 / `Architecture#385`.)

### Wave 2 (Repo standup — depends on Wave 1)
- [ ] **11** — Infrastructure: stand up the repo — `modules/`+`platform/`+`nodes/` tree, single root `bicepconfig.json` (D3 rules), repo README/CHANGELOG, `.honeydrunk-review.yaml`, `pr.yml` consuming Actions' `pr-core.yml`. Bootstrap PR. `Actor=Agent` (operator creates the repo + binds org secrets — Human Prerequisite). Blocked by: 18, 10.

### Wave 3 (Bicep content + pipeline — depends on Wave 2; Actions deploy workflow depends only on Wave 1)
- [ ] **13** — Infrastructure: author the first six per-concern modules in `modules/`, consumed by local relative path. No publish, no registry. `Actor=Agent`. Blocked by: 11. (Supersedes 03+05 / `Actions#118`+`Actions#120`.)
- [ ] **14** — Infrastructure: author the `platform/` shared-foundation templates (shared Container Apps Environment, image ACR, Log Analytics, Service Bus), exporting resource IDs; grandfather existing `dev` resources via `what-if`. `Actor=Agent` (RG/RBAC/apply are Human Prerequisites). Blocked by: 11, 13. (Absorbs packet 02's `rg-hd-platform-shared` residue.)
- [ ] **16** — Actions: author `job-deploy-bicep.yml` — reusable deploy workflow applying `HoneyDrunk.Infrastructure` templates with local-path module resolution, OIDC auth, `what-if` preflight, caller-declared env gates. No registry auth. `Actor=Agent`. Blocked by: 18. (Supersedes 06 / `Actions#121`.)
- [ ] **07** — Actions: add `bicep lint` to `pr-core.yml` (reusable `job-bicep-lint.yml`) so PRs touching `.bicep`/`.bicepparam` fail on linter/build-params violations. **UNCHANGED — still `Actions#122`, already filed.** Consumed by `HoneyDrunk.Infrastructure`'s `pr.yml` (packet 11). `Actor=Agent`. Blocked by: 18.

### Wave 4 (Patterns + import playbook — Architecture docs, depend on the content waves)
- [ ] **15** — Architecture: author the `nodes/{node}/` leaf-template scaffold pattern (`infrastructure/patterns/node-leaf-template.md`) — local-path module refs, `platform/` exported-ID references, decoupled deploy cadence. `Actor=Agent`. Blocked by: 18, 13, 14. (Supersedes 08 / `Architecture#387`.)
- [ ] **17** — Architecture: author the D6 import-existing-resources playbook (`infrastructure/patterns/bicep-import-existing-resources.md`) re-cut for the consolidated repo. `Actor=Agent`. Blocked by: 18, 15. (Supersedes 09 / `Architecture#388`.)

Packets within a wave run in parallel except where the dependency arrows say otherwise. **16 and 07 are both Actions** but touch different files (`.github/workflows/job-deploy-bicep.yml` vs `pr-core.yml`/`job-bicep-lint.yml`); they can land in parallel. **16 ships idle** — it does not need packets 13/14 to exist at author time; it activates when `HoneyDrunk.Infrastructure` calls it.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by | Replaces |
|---|--------|------|-------|------|-----------|----------|
| 18 | [Accept ADR-0077 (amended)](./18-architecture-adr-0077-acceptance.md) | Architecture | Agent | 1 | — | 00 |
| 10 | [Infrastructure Node registration](./10-architecture-infrastructure-node-registration.md) | Architecture | Agent | 1 | 18 | 01 (part) |
| 12 | [Actions pipeline catalog registration](./12-architecture-actions-pipeline-catalog-registration.md) | Architecture | Agent | 1 | 18, 10 | 01 (part) |
| 11 | [Infrastructure repo standup + scaffold](./11-infrastructure-repo-standup-and-scaffold.md) | Infrastructure | Agent | 2 | 18, 10 | new (+ 03 scaffold part) |
| 13 | [First per-concern module set](./13-infrastructure-first-module-set.md) | Infrastructure | Agent | 3 | 11 | 03, 05 |
| 14 | [platform/ shared-foundation](./14-infrastructure-platform-shared-foundation.md) | Infrastructure | Agent | 3 | 11, 13 | new (+ 02 residue) |
| 16 | [job-deploy-bicep.yml (local-path)](./16-actions-job-deploy-bicep-workflow.md) | Actions | Agent | 3 | 18 | 06 |
| 07 | [Add bicep lint gate to pr-core.yml](./07-actions-bicep-lint-pr-gate.md) | Actions | Agent | 3 | 18 | — (untouched) |
| 15 | [nodes/{node}/ leaf-template scaffold pattern](./15-architecture-nodes-leaf-template-scaffold-pattern.md) | Architecture | Agent | 4 | 18, 13, 14 | 08 |
| 17 | [Import-existing-resources playbook (D6)](./17-architecture-bicep-import-existing-resources-playbook.md) | Architecture | Agent | 4 | 18, 15 | 09 |

**Superseded / dead originals (retained on disk with `STATUS` banners; do not execute):** [00](./00-architecture-adr-0077-acceptance.md), [01](./01-architecture-bicep-catalog-registration.md), [02 DEAD](./02-architecture-bicep-registry-acr-walkthrough.md), [03](./03-actions-bicep-modules-library-scaffold.md), [04 DEAD](./04-actions-bicep-publish-workflow.md), [05](./05-actions-bicep-first-module-set.md), [06](./06-actions-job-deploy-bicep-workflow.md), [08](./08-architecture-per-node-bicep-template-scaffold-pattern.md), [09](./09-architecture-bicep-import-existing-resources-playbook.md).

> **Note on the dependency-frontmatter of the superseded originals.** The originals' `dependencies:` arrays still reference each other (`work-item:00`, `work-item:02`, etc.). They are skipped by `file-work-items.yml` (already in the manifest, line-407 "already filed" skip), so their stale deps are inert. The re-cut packets (10–18) carry correct `work-item:NN` / `Repo#N` deps among themselves.

## Version Bumps

- **`HoneyDrunk.Infrastructure`** (NEW) — not a versioned .NET solution; ships Bicep templates + GitHub Actions YAML. Carries a repo-level `CHANGELOG.md` (Keep a Changelog) for the Bicep-content surface: packet 11 seeds it (scaffold), packets 13/14 append (module set, platform layer). No module SemVer namespace — the `modules/v{N}.{N}.{N}` tag pattern is dropped with the registry; modules are versioned by git history, consumed by local relative path.
- **`HoneyDrunk.Actions`** — not a versioned .NET solution; ships GitHub Actions YAML. The repo may keep a `CHANGELOG.md` for the workflow surface; packets 16/07 append entries per the repo convention. No Bicep modules live here anymore (moved to Infrastructure).
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/catalog/docs edits only.

## Cross-Cutting Concerns

### Coordination with ADR-0076 (Redis) — IMPORTANT

ADR-0076 commits Azure Cache for Redis as the cache backing and names per-environment provisioning. ADR-0077 names ADR-0076 explicitly as the first forcing function.

- **ADR-0076's Redis provisioning is the first natural touchpoint for a per-Node leaf template under `nodes/{node}/`.** The first module set (packet 13) does **not** include a `data/redisCache` module in v1 — the Cache Node standup (ADR-0059) is not yet scoped. **Recommendation:** packet 13 ships the six concerns the ADR explicitly names; ADR-0076's Redis module lands when the Cache Node's provisioning work is scoped and the resource shape is concrete (a follow-up `modules/data/redisCache.bicep`, no version tag — local-path consumed). Until then, ADR-0076's `dev` provisioning can take the portal route consistent with the D6 grandfather pattern.
- **No hard dependency.** ADR-0077 acceptance does not block on ADR-0076's acceptance, and ADR-0076's provisioning does not block on this initiative completing.

### Coordination with the Node standups (ADR-0059 Cache / ADR-0060 Identity / ADR-0061 Files)

Each provisions Azure resources. Per D6 and the amendment:
- **New infrastructure goes through Bicep from day one** — but now lands as a per-Node leaf template under `HoneyDrunk.Infrastructure/nodes/{node}/`, not in the Node's own repo. The leaf template consumes the modules (packet 13) by local relative path and references the `platform/` exported IDs (packet 14).
- **Per-Node leaf templates are scoped by the standup ADR, not by this initiative.** This initiative ships the substrate (modules + platform + pattern + pipeline); per-Node templates land at each standup.

### Shared layer — `platform/` closes the gap (was: "Bicep registry vs container-image registry")

> **This section replaces the now-moot "Bicep registry vs container-image registry — separate ACRs" cross-cutting section.** With the cross-repo Bicep module registry dropped, there is no second ACR and no carve-out question. The only ACR remains the per-environment **container-image** registry `acrhdshared{env}` (invariant 35), now declared as a `platform/` resource.

The original ADR had a gap: the shared layer (shared Container Apps Environment, shared image ACR, Log Analytics, shared Service Bus) had no provisioning home, and Nodes consumed those resources via hand-pasted ARM resource IDs. The amendment's NEW `platform/` layer (packet 14) closes it:

- **`platform/main.bicep`** declares the shared-foundation resources and **exports their resource IDs as deploy outputs**. Per-Node leaf templates reference those exported IDs — not hand-pasted ARM strings.
- **Resource-group home.** The per-environment shared resources (`acrhdshared{env}`, `cae-hd-{env}` per invariant 35) live in `rg-hd-platform-{env}`. The amendment confirms `rg-hd-platform-shared` as the home for any environment-agnostic shared substrate. (This is the surviving residue of the dead packet 02, which had floated `rg-hd-platform-shared` for the now-dropped `acrhdbicep`.)
- **Grandfather posture (D6).** The existing `dev` platform resources (`acrhdshared{dev}`, `cae-hd-dev`) are not recreated — packet 14's template matches them and they import as a no-op via `az deployment group what-if`.
- **Invariant 35 unchanged.** No carve-out — the registry is dropped. `acrhdshared{env}` is the only ACR; the `acrhd` prefix on the (now-dead) `acrhdbicep` no longer exists anywhere.

### Local relative path module references — the registry-drop consequence

Every module reference across the initiative is `'../../modules/{concern}/{name}.bicep'` (or the appropriate relative depth). There is **no** `br:acrhdbicep.azurecr.io/...` syntax, no `bicep-publish.yml`, no `modules/v{N}.{N}.{N}` tag, and no `az acr login` in the deploy workflow. Because `modules/`, `platform/`, and `nodes/` share one repo checkout, `bicep build` resolves modules directly from the filesystem. This is the load-bearing simplification of the amendment — it must hold in every packet (11, 13, 14, 15, 16, 17).

### Naming and tagging linter rules — committed by D3 (unchanged)

A **single root `bicepconfig.json`** in `HoneyDrunk.Infrastructure` (packet 11) carries the D3 rules and covers `modules/`, `platform/`, and `nodes/` via Bicep's config-file resolution (filesystem search from a template's directory upward). The rules:
- Flag missing required tags (`hd:node`, `hd:env`, `hd:owner`, `hd:cost-center`, `hd:dr-tier`, `hd:adr`).
- Flag non-conformant resource names (per-resource-type prefix, `hd-` identifier, `{service}`/`{node}` within the ≤13-char rule of invariant 19, `{env}` suffix).
- Best-effort secret-shaped-literal detection (D7).

The `bicep lint` gate (packet 07, consumed from Actions) enforces them at PR time.

### Secrets discipline — codified in the IaC invariants, enforced by linter (unchanged)

ADR-0077 D7: "Bicep templates never contain secret values." Packet 18's `{N2}` invariant codifies it; packet 11's root `bicepconfig.json` flags hardcoded secret-shaped literals. The runtime enforcement is the deploy-identity scope (the Actions OIDC identity provisions, does not read secrets) — defense in depth.

### Vendor-exit posture acknowledged in D5 — no rebalancing in this initiative (unchanged)

Per ADR-0080 the Azure posture is "Accept (deep, intentional)" with `governance/vendor-postures/azure.md` as the canonical home. The vendor-exit playbook content is out of scope. Modularize-by-concern (D2, unchanged) is the pre-paid hedge — and consolidation into one repo does not weaken it (the per-concern module boundaries still map 1:1 to a future Terraform port).

### Site sync

No site-sync flag. ADR-0077 is internal Ops infrastructure substrate.

### Deferred follow-ups (explicitly out of scope)

- **Per-Node leaf-template adoption.** Opportunistic, at each Node's next infrastructure touchpoint (D6). No campaign.
- **Existing-resource imports.** Opportunistic (D6). Packet 17 is the playbook; actual imports are per-resource work targeting `HoneyDrunk.Infrastructure`.
- **The `data/redisCache` module** for ADR-0076 — lands when the Cache Node provisioning is scoped.
- **Networking / identity modules** — land when a consumer first needs them.
- **Vendor-exit playbook authoring.** ADR-0080 (per-surface content deferred).
- **Azure Policy / Azure Blueprints.** D8 defers.
- **Multi-region DR topology.** D8 defers; per-Node concern.
- **Cloudflare IaC.** ADR-0029; Bicep is Azure-only by construction.

## Rollback Plan

- **Packets 18 / 10 / 12 (governance/catalog):** revert the PR. ADR returns to Proposed; the three invariants, the new Node registration, and the catalog entries are removed. No runtime impact.
- **Packet 11 (repo standup):** revert the bootstrap PR; the scaffold leaves the repo. The repo itself can be archived/deleted by the operator if the initiative is abandoned. No published artifact exists (no registry).
- **Packet 13 (module set):** revert the PR; the module files leave the repo. No registry tag exists to clean up (registry dropped) — clean revert.
- **Packet 14 (platform):** revert the PR; the `platform/` templates leave the repo. **Existing live `dev` resources are untouched by a revert** — they were grandfathered (no-op import), not recreated. If a `platform/` apply already ran and changed a live resource, roll back via the captured ARM snapshot (the import playbook, packet 17, documents this).
- **Packet 16 (deploy workflow):** revert the PR; `job-deploy-bicep.yml` leaves Actions. No caller invokes it until `HoneyDrunk.Infrastructure` wires it — clean revert.
- **Packet 07 (PR gate):** revert the PR; `bicep lint` is removed from `pr-core.yml`. No runtime impact.
- **Packets 15 / 17 (docs):** revert the PR; the patterns/playbook docs are removed. No runtime impact.
- **Operational escape hatch:** D6's grandfather pattern is bidirectional — a resource that fails a Bicep apply can fall back to portal provisioning, documented in `grid-health.json`.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every **non-superseded** packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. The superseded originals (00–06, 08, 09) are already in `filed-work-items.json` and are **skipped** ("already filed" — `file-work-items.sh` line ~407); their `STATUS` banners are documentation only. Packet 07 is also already filed and skipped (unchanged). The re-cut packets (10–18) are new manifest entries and would be filed when pushed.

**This re-cut is for operator review — nothing has been filed, pushed, or had issues created.** When the operator is ready: push the folder to `main` to file packets 10–18, then CLOSE the ten OPEN superseded/dead issues (`Architecture#384/385/386/387/388`, `Actions#118/119/120/121`) with comments pointing at their successors. `Actions#122` (packet 07) stays OPEN — it is untouched.
