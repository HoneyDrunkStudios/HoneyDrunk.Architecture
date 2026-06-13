---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Infrastructure
labels: ["feature", "tier-2", "ops", "ci-cd", "infrastructure", "adr-0077", "wave-2"]
dependencies: ["work-item:18", "work-item:10"]
adrs: ["ADR-0077", "ADR-0012", "ADR-0082"]
wave: 2
initiative: adr-0077-iac-bicep
node: honeydrunk-infrastructure
---

# Stand up the HoneyDrunk.Infrastructure repo: baseline tree, root bicepconfig.json, and Actions-pipeline wiring

> **This is a NEW packet introduced by the ADR-0077 amendment (2026-06-02).** It has no predecessor in the 00–09 set. It scaffolds the new monorepo that the registry-drop consolidation creates.

## Summary
Bootstrap the `HoneyDrunk.Infrastructure` repository: create the `modules/` + `platform/` + `nodes/` directory tree (empty-state with READMEs), a single root `bicepconfig.json` carrying the ADR-0077 D3 naming/tagging linter rules covering all three subtrees via Bicep config-file resolution, a repo-level `README.md` and `CHANGELOG.md`, the `.honeydrunk-review.yaml` (`enabled: true`), the `pr.yml` calling `HoneyDrunk.Actions`'s `pr-core.yml`, and the consumer-side wiring stubs for the `bicep lint` gate and the `job-deploy-bicep.yml` deploy workflow. Per ADR-0077 D2 (as amended), modules are referenced by **local relative path** — there is no registry, no `bicep-publish.yml`, no `br:` syntax. This is the bootstrap PR per invariant 102.

## Context
The ADR-0077 amendment (2026-06-02) consolidates all Bicep *content* into this new repo. The repository structure:
- **`modules/`** — the seven per-concern module groups (networking, compute, identity, data, secrets, messaging, observability), moved out of `HoneyDrunk.Actions/bicep/modules/`. Actual module bodies land in packet 13; this packet creates the empty-state tree + per-concern READMEs.
- **`platform/`** — the NEW shared-foundation home (shared Container Apps Environment, shared image ACR `acrhdshared{env}`, Log Analytics, shared Service Bus namespace, networking). Actual templates land in packet 14; this packet creates the empty-state directory + README.
- **`nodes/{node}/`** — thin per-Node leaf templates (`main.bicep` + `parameters.{env}.bicepparam`), relocated out of each Node's own repo. The scaffold *pattern* is documented by packet 15; per-Node templates land per-Node at infrastructure touchpoints. This packet creates the empty-state `nodes/` directory + README explaining the leaf-template shape.

The *pipeline* stays in Actions per ADR-0012. This repo *consumes* the `bicep lint` gate and `job-deploy-bicep.yml` via `workflow_call` checkout at job runtime. Only Bicep templates and modules live here.

The root `bicepconfig.json` is single and covers all three subtrees — Bicep resolves config by searching the filesystem from a template's directory upward and picking up the first `bicepconfig.json`, so one root config governs `modules/`, `platform/`, and `nodes/{node}/` uniformly (ADR-0077 amendment "What stays unchanged" — D3).

Per invariant 102, this bootstrap PR is permitted to introduce items 7, 8, 9, 10 (the `.honeydrunk-review.yaml`, `pr.yml`, branch protection, org-secret binding) in the same commit as the rest of the scaffold; the invariant binds the *second* (first feature) PR. Items 1–5 (catalog rows + context folder + sectors row) land in packet 10 and must merge first.

## Scope
- The GitHub repo `HoneyDrunkStudios/HoneyDrunk.Infrastructure` — created by the operator (Human Prerequisite).
- `modules/{networking,compute,identity,data,secrets,messaging,observability}/README.md` — empty-state per-concern READMEs.
- `platform/README.md` — explains the shared-foundation layer.
- `nodes/README.md` — explains the per-Node leaf-template shape.
- `bicepconfig.json` (repo root) — the single linter config (D3 rules), covering all three subtrees.
- `README.md` (repo root) — repo purpose, the modules/platform/nodes model, the local-path reference convention, how to deploy (consume Actions' `job-deploy-bicep.yml`).
- `CHANGELOG.md` (repo root) — Keep a Changelog format, first `## [Unreleased]` entry recording the scaffold.
- `.honeydrunk-review.yaml` — `enabled: true`.
- `.github/workflows/pr.yml` — calls `HoneyDrunk.Actions`'s `pr-core.yml` (+ the `bicep lint` gate once packet 16 ships the reusable job; until then, reference `pr-core.yml` only and add the bicep-lint call in packet 16's consumer wiring).

## Proposed Implementation
1. **Operator creates the repo** (Human Prerequisite) and grants the standard org-secret bindings (`SONAR_TOKEN` minimum, per invariant 102 item 10).
2. **Directory tree.** Create `modules/` with the seven concern subdirectories, each with a `README.md` stub describing what that concern owns (copy the concern→owns table from ADR-0077 D2). Create `platform/` with a `README.md` describing the shared-foundation resources. Create `nodes/` with a `README.md` describing the leaf-template shape (`nodes/{node}/main.bicep` + `parameters.{env}.bicepparam`).
3. **Root `bicepconfig.json`.** Author the linter config carrying the ADR-0077 D3 rules: required tags (`hd:node`, `hd:env`, `hd:owner`, `hd:cost-center`, `hd:dr-tier`, `hd:adr`), name conventions (per-resource-type prefix + `hd-` + `{service}`/`{node}` within the ≤13-char limit per invariant 19 + `{env}` suffix), and best-effort secret-shaped-literal flagging (`accountKey`, `connectionString`, `password`, `apiKey`). Use Bicep's `analyzers.core.rules` block with project-specific severity. Document in comments that what the linter cannot express as a global rule is enforced at module-author time via `@allowed`/`@minLength`/`@maxLength`/`@description` parameter decorators. **Research the current `bicepconfig.json` schema and best practice at execution time** — Bicep evolves.
4. **Repo `README.md`** — purpose, the modules/platform/nodes model, the **local relative path** reference convention (`module x '../../modules/compute/containerApp.bicep'`), the no-registry note, and the "deploys via Actions' `job-deploy-bicep.yml`, decoupled from application release tags" cadence note.
5. **Repo `CHANGELOG.md`** — Keep a Changelog format; `## [Unreleased]` entry: "Repo scaffold: modules/, platform/, nodes/ tree; root bicepconfig.json with D3 linter rules; pr.yml consuming HoneyDrunk.Actions pr-core.yml."
6. **`.honeydrunk-review.yaml`** — `enabled: true`.
7. **`.github/workflows/pr.yml`** — call `HoneyDrunk.Actions/.github/workflows/pr-core.yml@main` with a `permissions:` block that is a superset of pr-core's declared permissions (invariant 39). Add the `bicep lint` reusable-workflow call when packet 16 ships it (cross-reference; if packet 16 has merged, wire it here).

## Affected Files
- `modules/{networking,compute,identity,data,secrets,messaging,observability}/README.md` (new)
- `platform/README.md` (new)
- `nodes/README.md` (new)
- `bicepconfig.json` (new, repo root)
- `README.md` (new, repo root)
- `CHANGELOG.md` (new, repo root)
- `.honeydrunk-review.yaml` (new)
- `.github/workflows/pr.yml` (new)

## NuGet Dependencies
None. This repo ships Bicep templates + GitHub Actions YAML; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Infrastructure`. Routing keyword row (added by packet 10) maps IaC/Bicep/platform keywords here.
- [x] The deploy/lint pipeline is NOT authored here — it stays in Actions per ADR-0012; this repo consumes it.
- [x] No runtime application code; Bicep content only.

## Acceptance Criteria
- [ ] `HoneyDrunk.Infrastructure` repo exists (operator-created)
- [ ] `modules/` has the seven per-concern subdirectories, each with a README describing its concern per ADR-0077 D2
- [ ] `platform/README.md` describes the shared-foundation layer (shared Container Apps Environment, `acrhdshared{env}` image ACR, Log Analytics, shared Service Bus, networking)
- [ ] `nodes/README.md` describes the `nodes/{node}/main.bicep` + `parameters.{env}.bicepparam` leaf-template shape and the local-path module reference convention
- [ ] A single root `bicepconfig.json` carries the D3 linter rules and is documented as covering all three subtrees via config-file resolution
- [ ] Repo `README.md` documents the modules/platform/nodes model, the local-relative-path reference convention, the no-registry note, and the decoupled-deploy-cadence note
- [ ] Repo `CHANGELOG.md` exists in Keep a Changelog format with the scaffold entry under `## [Unreleased]`
- [ ] `.honeydrunk-review.yaml` exists with `enabled: true`
- [ ] `.github/workflows/pr.yml` calls Actions' `pr-core.yml` with a superset `permissions:` block (invariant 39)
- [ ] No `acrhdbicep`, `bicep-publish.yml`, `modules/v{N}.{N}.{N}`, or `br:acrhdbicep.azurecr.io` reference appears anywhere in the repo (registry dropped)
- [ ] No actual module bodies or platform templates are authored (those land in packets 13/14)

## Human Prerequisites
- [ ] Create the GitHub repository `HoneyDrunkStudios/HoneyDrunk.Infrastructure` (org-admin, portal/CLI). The agent cannot create repos.
- [ ] Bind the new repo to the org Actions secrets its workflows reference — minimum `SONAR_TOKEN` for any `pr-core.yml` consumer (invariant 102 item 10). GitHub does not auto-propagate `Selected repositories` org secrets, so without this the first non-bootstrap PR consuming `SONAR_TOKEN` hard-fails.
- [ ] Set branch protection on `main` requiring the `pr-core / core` status check (invariant 102 item 9).

## Referenced ADR Decisions
**ADR-0077 amendment (2026-06-02) — consolidation + registry drop.** All Bicep content in this repo: `modules/` (per-concern, moved from Actions), `platform/` (NEW shared-foundation home), `nodes/{node}/` (thin leaf templates relocated from Node repos). Modules referenced by local relative path. No registry: `acrhdbicep`, `bicep-publish.yml`, SemVer-tag-publish, and `br:` refs are all dropped. The deploy/lint pipeline stays in Actions (ADR-0012); this repo consumes it. Infra deploys on its own cadence, decoupled from application release tags.

**ADR-0077 D3 (unchanged) — naming/tagging linter rules in `bicepconfig.json`.** A single root `bicepconfig.json` covers `modules/`, `platform/`, and `nodes/` via Bicep's config-file resolution.

**ADR-0012 — Actions is the CI/CD control plane.** The pipeline (deploy + lint reusable workflows) lives in Actions; this repo consumes them via `workflow_call`.

**Invariant 102 (ADR-0082) — bootstrap PR.** This is the bootstrap (scaffold) PR; it may introduce items 7–10 in the same commit. Items 1–6 land in packet 10 and must merge first.

**Invariant 39 (ADR-0012 D5) — caller permissions superset.** `pr.yml` must declare a `permissions:` block that is a superset of `pr-core.yml`'s declared permissions.

## Constraints
- **Local-path references only.** Every future module reference is `'../../modules/{concern}/{name}.bicep'`. No `br:` syntax, no registry, no `bicep-publish.yml`. This is the load-bearing consequence of the registry drop.
- **Single root `bicepconfig.json`.** One config at the repo root, covering all three subtrees. Do not author per-subtree configs.
- **Empty-state scaffold only.** No module bodies, no platform templates, no per-Node leaf templates in this packet — those are packets 13/14 and per-Node touchpoints.
- **Pipeline stays in Actions.** Do not author `job-deploy-bicep.yml` or a bicep-lint job here — consume them from Actions.

## Labels
`feature`, `tier-2`, `ops`, `ci-cd`, `infrastructure`, `adr-0077`, `wave-2`

## Agent Handoff

**Objective:** Scaffold the `HoneyDrunk.Infrastructure` monorepo — `modules/`+`platform/`+`nodes/` tree (empty-state + READMEs), root `bicepconfig.json` (D3 rules), repo README/CHANGELOG, `.honeydrunk-review.yaml`, and `pr.yml` consuming Actions' `pr-core.yml`. Local-path module refs only; no registry.

**Target:** `HoneyDrunk.Infrastructure`, branch from `main` (bootstrap PR).

**Context:**
- Goal: Stand up the new IaC-content monorepo the ADR-0077 amendment creates, with the pipeline consumed from Actions.
- Feature: ADR-0077 IaC — Bicep rollout (amended 2026-06-02), Wave 2.
- ADRs: ADR-0077 + 2026-06-02 amendment (primary), ADR-0012 (pipeline in Actions), ADR-0082 (invariant 102 bootstrap).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0077 (amended) Accepted.
- `work-item:10` — Node registration (invariant-102 Phase-A catalog rows must precede the bootstrap PR).

**Constraints:**
- Local-path module references only — no registry, no `bicep-publish.yml`, no `br:`.
- Single root `bicepconfig.json` covering all three subtrees.
- Empty-state scaffold only; module bodies/platform templates land in packets 13/14.
- Pipeline stays in Actions; consume it.

**Key Files:**
- `bicepconfig.json` (root), `README.md` (root), `CHANGELOG.md` (root)
- `modules/*/README.md`, `platform/README.md`, `nodes/README.md`
- `.honeydrunk-review.yaml`, `.github/workflows/pr.yml`

**Contracts:** None — the consumable Bicep surfaces (`modules/`, `platform/`, `nodes/`) are created empty-state here; bodies land in packets 13/14.
