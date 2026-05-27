---
name: Documentation
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0082", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0082", "ADR-0011", "ADR-0012", "ADR-0014", "ADR-0034", "ADR-0044", "ADR-0079", "ADR-0083", "ADR-0084"]
accepts: ADR-0082
wave: 2
initiative: adr-0082-node-standup
node: honeydrunk-architecture
---

# Chore: Author `constitution/node-standup.md` — the canonical Node standup procedure document

## Summary

Author the canonical Node standup procedure document at `constitution/node-standup.md` per ADR-0082 D1. The document is the single source future standup packets, ADRs, and AI agents reference. It captures: the three-phase prerequisite chain (D3), the eighteen mandatory steps for every Node class (D4), the class-specific steps per D2's six-class taxonomy (D5), the per-class org-secret binding matrix per D8 (the snapshot lives here, not in the ADR — future inventory passes from ADR-0083 D5/D6 update this file without ADR amendment), and pointers to the per-class walkthroughs that compose against the procedure (packets 02–06) and the org-secret binding walkthrough (packet 07).

This is the **load-bearing deliverable** of ADR-0082. Packet 00 makes the ADR canonical; this packet makes the procedure itself canonical.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

Per ADR-0082 D1, the procedure lives at `constitution/node-standup.md` so:
- Every standup packet references one source instead of re-deriving from precedent.
- AI-authored standup packets (per ADR-0044 D6) gain a procedure-adherence dimension in the ADR-0044 D3 rubric category 10 (Enterprise readiness / supportability).
- The Node-class taxonomy (six classes per D2) is committed so future standups do not re-litigate what kind of Node is being stood up.
- The drift channels named in ADR-0082's Context (the `repo-to-node.yml` mapping forgotten until commit `23a183c`, the `.honeydrunk-review.yaml` silent-disable failure mode, the contract-shape canary re-justified per Node, the public-by-default-with-carve-out memory rule) are closed by naming each as mandatory rather than discovered.

## Proposed Implementation

### `constitution/node-standup.md` — new canonical document

Create the file. Structure follows the established constitution-doc shape (see `constitution/sectors.md`, `constitution/invariants.md`, `constitution/terminology.md`):

```markdown
# Node Standup Procedure

**Source ADR:** ADR-0082 (Canonical Node Standup Procedure).
**Related invariants:** {N1} from ADR-0082 D6, plus invariants 11, 12, 17, 19, 22, 27, 31, 32, 33, 34, 35, 36, 41, 46, 49, 52, 53.
**Edit discipline:** This document is PR-reviewed against ADR-0082. Edits that change the D2 taxonomy (the six Node classes) or the D6 invariant wording require an ADR amendment; all other edits — including extending the per-class org-secret matrix as the inventory grows (per ADR-0083 D5/D6) — land via normal PR review.

## What this document is

The canonical procedure every Grid Node standup follows. The procedure is split into:
1. A **three-phase prerequisite chain** (Phase A Architecture registration → Phase B GitHub repo creation → Phase C scaffold landing). Phases must run in order.
2. An **eighteen-step mandatory list** every Node class executes.
3. **Class-specific steps** layered on top, keyed by the Node class declared in the standup ADR's frontmatter (`node_class:` field).
4. A **per-class org-secret binding matrix** naming which org Actions secrets the new repo must be bound to before its first non-bootstrap PR merges.

### What is NOT a Node — operator-internal automation infrastructure carve-out

This procedure (and the invariant 102 binding it) applies only to artifacts that are **Nodes** under ADR-0082 D2's six-class taxonomy. Operator-internal automation infrastructure — Azure Key Vaults provisioned for agents (e.g., `kv-hd-docs-sync-prod` per ADR-0085), GitHub Apps registered for cross-repo automation, OpenClaw schedules, the home server itself (ADR-0081), credential inventories (ADR-0083 `sensitive-inventory.md`) — is governed by its own ADR and is **NOT** a Node. Invariant 102's ten-item registration checklist does not bind these artifacts: they have no `catalogs/nodes.json` row (because they are not Nodes), no `repos/{Node}/` context folder, no `.honeydrunk-review.yaml`, no `pr.yml` calling `pr-core.yml`, and no per-class org-secret matrix. Their governance lives in their owning ADR (ADR-0081, ADR-0083, ADR-0085, etc.) and the walkthroughs that owning ADR commits.

## The six Node classes (per ADR-0082 D2)

| Class | `node_class:` value | Description | Examples |
|---|---|---|---|
| Core .NET Abstractions+Runtime (default) | `core-dotnet-abstractions-runtime` | One `.Abstractions` package + one runtime/backing package; ships NuGet. | Audit, Cache, Identity, Files, Memory, Knowledge, Evals, Flow, Sim |
| Core .NET Runtime-only | `core-dotnet-runtime-only` | Single runtime package; no `.Abstractions` split. | Kernel |
| Ops Deployable .NET | `ops-deployable-dotnet` | One or more `.Abstractions` packages plus one or more deployable Services (Container Apps / Functions). | Notify, Pulse.Collector, Notify Cloud, Operator, Communications (when deployed) |
| Meta / Docs / Wiki | `meta-docs` | No NuGet, no deployable, no contract surface. The repo *is* the deliverable. | Architecture, Lore, Standards, HoneyDrunk.Prompts |
| AI Seed (scaffold-only) | `ai-seed` | Node cataloged but not yet stood up — `signal: "seed"` in `catalogs/nodes.json` with `done: false`. | The nine AI-sector Nodes prior to per-Node scaffold |
| Studios / TypeScript | `studios-typescript` | TypeScript / React / Next-style repo. | HoneyDrunk.Studios, future SDKs, future per-stack Web.UI packages |

The class is declared in the standup ADR's frontmatter; if omitted, default is `core-dotnet-abstractions-runtime`.

## The three phases (per ADR-0082 D3)

### Phase A — Architecture registration

State: in `HoneyDrunk.Architecture`, no GitHub repo yet exists.

Lands as one Architecture packet — the "context folder" packet shape (exemplars: `01-architecture-notify-cloud-context-folder.md`, `01-architecture-create-audit-context-folder.md`). Contents:
- Catalog rows in `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`.
- Sector row in `constitution/sectors.md` (signal `Seed` initially, promoted to `Live` when the scaffold lands).
- Five-file context folder at `repos/{NodeName}/` (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`).
- Standup ADR registered in `adrs/`.
- Invariant assignment if applicable (claim from `constitution/invariant-reservations.md`).

**Gate:** Phase A must merge before Phase B starts. The scaffold packet's `target_repo` will be wrong otherwise (no repo exists yet).

### Phase B — GitHub repo creation (human-only org-admin action)

State: Phase A merged; no GitHub repo for the Node yet.

Lands as one human-only chore packet — exemplar `02-architecture-create-audit-repo.md`. Contents (cannot be agent-delegated; org admin in GitHub portal):
- Repo created at correct visibility (public by default; private only with ADR-recorded carve-out — see Mandatory Step 5 below).
- Branch protection applied on `main` (PR required, `pr-core / core` required check, no force-push, no deletion).
- **Org-secret repo binding** — for every org Actions secret the repo's workflows will consume, visit `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions/{SECRET_NAME}` and add the new repo to the **Selected repositories** access list. See "Per-class org-secret matrix" below.
- Labels seeded (idempotent CLI loop in the chore packet).
- OIDC federated credential subject pattern updated in Microsoft Entra for NuGet-shipping Nodes (`repo:HoneyDrunkStudios/{NodeName}:ref:refs/tags/v*`).
- Local clone made.

**Gate:** Phase B must complete before Phase C is *fileable* (Invariant 24 — the scaffold packet's `target_repo` must exist before the issue can be filed).

### Phase C — Scaffold landing (agent-eligible)

State: Phase B complete; repo exists; branch protection active; org-secrets bound; first PR not yet merged.

Lands as the scaffold packet (`03-{node}-node-scaffold.md` shape — exemplar `03-audit-node-scaffold.md`). Contents per the mandatory + class-specific lists below. After scaffold merge, `v0.1.0` may be tagged (human-pushed per Invariant 27) to publish first packages.

The scaffold PR is the **bootstrap PR** — permitted to introduce items 7 (`.honeydrunk-review.yaml`), 8 (`pr.yml`), 9 (branch-protection update for the canary), and 10 (any org-secret binding refinements) in the same commit. The D6 invariant binds the *second* PR — the first feature PR.

### Optional Phase D — Reconciliation

Parallel or post-scaffold: hive-sync per ADR-0014 reconciles `catalogs/nodes.json` / `relationships.json` / `grid-health.json` / `modules.json` / `contracts.json` / `initiatives/active-initiatives.md` / `adrs/README.md` if the standup initiative deferred those edits to hive-sync.

## Mandatory steps — every Node class (per ADR-0082 D4)

Eighteen steps. Land across Phases A/B/C as noted. Skipping any is a procedure violation.

1. **Standup ADR exists** and references ADR-0082 as the procedure source. Shape: ADR-0019 / ADR-0027 / ADR-0031 / ADR-0059 template (capability/decision body + "If Accepted — Required Follow-Up Work" checklist at top). [Phase A]
2. **Sector assignment** in `constitution/sectors.md`. Signal `Seed` until scaffold lands; promoted to `Live` at first non-bootstrap PR merge. [Phase A]
3. **Context folder** at `repos/{NodeName}/` — all five files (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`). Surface the `review` agent (ADR-0011 D4 / ADR-0044 D2 / Invariant 33) and `scope` agent (ADR-0008) load on every PR. [Phase A]
4. **Catalog entries** in `catalogs/nodes.json` (Node row with all fields), `catalogs/relationships.json` (consumes/consumed_by edges, no cycles per Invariant 4), `catalogs/grid-health.json` (contract surface, canary expectation, DR tier per ADR-0036). [Phase A; hive-sync owns live state per Phase D]
5. **Repo created** at correct visibility. Public by default; private only with ADR-recorded revenue/compliance/experiment carve-out (precedent: ADR-0027 D2 for Notify Cloud). [Phase B]
6. **Branch protection on `main`** — PR required, `pr-core / core` required check (Invariant 31), no force-push, no deletion, signed commits not required. Additional required checks (`api-compatibility / abstractions-shape`, `job-sonarcloud / sonarcloud` for public repos) added in a *follow-up* branch-protection update after the throwaway breaking-change PR confirms the canary fires post-merge. [Phase B; follow-up update post-scaffold]
7. **Repo-to-Node mapping** in `HoneyDrunk.Actions/.github/config/repo-to-node.yml`. Most-frequently-forgotten step (commit `23a183c` added Audit retroactively). [Phase B or Phase C — preferably Phase B so it lands before any issue is filed against the new repo]
8. **Label seeding** out-of-band before first non-bootstrap PR (Invariant 32) — `feature`, `chore`, `tier-1`, `tier-2`, `tier-3`, `scaffold`, `adr-{NNNN}`, `human-only`, `out-of-band`, wave/initiative-specific labels. CLI loop in chore packet is idempotent. [Phase B]
9. **`.honeydrunk-review.yaml`** at repo root with `enabled: true` or `enabled: false` explicitly declared (Invariant 52 / ADR-0044 D4). Missing file is silent disable, not default-on. [Phase C]
10. **CodeRabbit integration** per ADR-0079 D2 (`.coderabbit.yaml` lands with scaffold; subscription is org-level). [Phase C]
11. **Copilot review** enabled at org level (no per-repo action; ADR-0079 D1). Standup verifies, does not configure. [Phase C — verify only]
12. **`README.md`** at repo root and at every package directory (Invariant 12). Repo README links to standup ADR and `repos/{Node}/` context folder. [Phase C]
13. **`CHANGELOG.md`** at repo root and at every package directory (Invariant 12). First commit carries `## [0.1.0] - YYYY-MM-DD` entry — no `## Unreleased` at commit time. [Phase C]
14. **`LICENSE`** at repo root — Grid default MIT for public repos (ADR-0039 D1); FSL-1.1-MIT for open engines of revenue Nodes (ADR-0039 D2 / ADR-0027 D11); `LicenseRef-Proprietary` for private revenue Nodes. [Phase C]
15. **`.github/copilot-instructions.md`** — per-repo file pointing back to Architecture's copilot-instructions plus repo-specific addenda. Mirrored to OpenClaw skills per ADR-0007 Operational Addendum when applicable. [Phase C]
16. **`CLAUDE.md`** at repo root if repo is a primary dev surface (Core .NET, Ops Deployable .NET, Meta docs, Studios TypeScript — yes; AI Seed — n/a). Links to `repos/{Node}/overview.md`, standup ADR, local-dev orchestration anchor (ADR-0065 if Aspire). [Phase C]
17. **`pr-core.yml` CI workflow** at `.github/workflows/pr.yml` calling `HoneyDrunk.Actions`'s reusable `pr-core.yml` (ADR-0012 D1). Caller-side `permissions:` block follows canonical superset pattern (ADR-0012 D5). Wires the tier-1 gate (Invariant 31). [Phase C]
18. **Initiative + roadmap entry** in `initiatives/active-initiatives.md` and `initiatives/roadmap.md` (deferred to hive-sync per Phase D). [Phase A or Phase D]

## Class-specific steps (per ADR-0082 D5)

### Core .NET (Abstractions+Runtime, Runtime-only, Ops Deployable) — all .NET classes

- a. `.slnx` solution at repo root.
- b. `Directory.Build.props` with `TargetFramework`, `Nullable`, `ImplicitUsings`, `LangVersion`, `TreatWarningsAsErrors`, shared `Version` (Invariant 27), `Authors`, `PackageProjectUrl`, `RepositoryUrl`, `RepositoryType`, `PublishRepositoryUrl`, `IncludeSymbols`, `SymbolPackageFormat`, `GenerateDocumentationFile`. Exemplar in Audit scaffold packet text.
- c. `HoneyDrunk.Standards` reference with `PrivateAssets="all"` on every `.csproj` (Invariant 26). StyleCop + EditorConfig + analyzer suite. `.editorconfig` shipped from Standards.
- d. Test project layout: `*.Tests.Unit` always; deployable Nodes add `*.Tests.Integration`; HTTP-fronted Nodes add `*.Tests.E2E` (Invariant 50). xUnit + NSubstitute + AwesomeAssertions + coverlet (ADR-0074).
- e. `release.yml` consuming `HoneyDrunk.Actions`'s `release.yml` reusable workflow (ADR-0012 / ADR-0034); tag-triggered; no `secrets: inherit` — explicit named secrets only.
- f. `nightly-deps.yml` consuming reusable workflow (ADR-0009).
- g. `nightly-security.yml` consuming reusable workflow (ADR-0009).
- h. OIDC federated credential subject pattern (`repo:HoneyDrunkStudios/{NodeName}:ref:refs/tags/v*`) added to Grid's NuGet publishing identity in Microsoft Entra. Walkthrough: `infrastructure/walkthroughs/oidc-federated-credentials.md`.
- i. Contract-shape canary (`api-compatibility.yml`) scoped to the Node's `.Abstractions` package(s) — mandatory standup step (not polish). Throwaway breaking-change PR post-merge confirms canary fires.
- j. In-memory test fixture for primary contracts — internal to runtime package's test project at standup (ADR-0027 D3 precedent); cut to `{Node}.Testing` package only when a third consumer needs it.
- k. End-to-end smoke test exercising the in-memory fixture.
- l. `sonar-project.properties` + `job-sonarcloud.yml` for public repos (ADR-0011 D11). One-time org onboarding lives in `infrastructure/walkthroughs/sonarcloud-organization-setup.md`.
- m. Project board hook — repo-filter auto-add is org-level (ADR-0008 D5); standup verifies but does not configure.

### Ops Deployable .NET — additional steps

- n. Key Vault per environment named `kv-hd-{service}-{env}` (Invariants 17, 19). Walkthrough: `infrastructure/walkthroughs/key-vault-creation.md`.
- o. App Configuration store per environment named `appcs-hd-{service}-{env}` (ADR-0005). Walkthrough: `infrastructure/walkthroughs/app-configuration-provisioning.md`.
- p. Managed identity per Node per environment, system-assigned (ADR-0031 D5 generalized).
- q. Container Apps wiring (`ca-hd-{service}-{env}` per Invariant 34), revision mode `Multiple` (Invariant 36), shared environment `cae-hd-{env}` and shared registry `acrhdshared{env}` (Invariant 35). Walkthrough: `infrastructure/walkthroughs/container-app-creation.md`.
- r. Bicep modules at `infra/` (ADR-0077), modularized by concern. Deployment workflow consumes `HoneyDrunk.Actions`'s `job-deploy-bicep.yml`.
- s. Deploy trigger model (ADR-0033): path-filtered push-to-`main` deploys `dev`; SemVer tags gate `staging`/`prod`. Per-deployable path scoping for multi-deployable repos; environment-keyed concurrency.
- t. Health endpoints (ADR-0066): `/health/live`, `/health/ready`, `/health` for every HTTP-fronted deployable Node.

### Meta / Docs / Wiki — additional and skipped steps

- u. No NuGet publication, no `release.yml`, no OIDC federated credential. The repo *is* the deliverable.
- v. If repo ships content (Prompts, Standards content files), content-shape canary per the Prompts standup spec — frontmatter parses, parameters parity, no `classification: Restricted` content.

### AI Seed — Phase A only

- w. Phase A only. No repo, no CI, no managed identity, no scaffold packet. Node cataloged with `signal: "seed"` and `done: false`; waits for per-Node scaffold packet (which lands as regular Phase B + Phase C against the just-promoted Core .NET class).

### Studios / TypeScript — additional and replaced steps

- x. No `.slnx`, no `Directory.Build.props`, no `HoneyDrunk.Standards`. Replace with `package.json`, `tsconfig.json`, ESLint/Prettier matching the existing Studios repo's stack.
- y. Node.js CI workflow at `.github/workflows/pr.yml` calling (future) `HoneyDrunk.Actions`'s `pr-typescript.yml` reusable workflow if one exists, or directly invoking `npm ci && npm run build && npm test` until that workflow is built (ADR-0012 D4 — wrapper marketplace actions for npm/Node are rejected).
- z. Web.UI design-token consumption per ADR-0071 when the package is React-stack.

## Per-class org-secret binding matrix (per ADR-0082 D8)

GitHub does NOT auto-propagate org Actions secrets with `Selected repositories` access policy to new repos. The org admin must visit `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions/{SECRET_NAME}` for every secret the new repo's workflows reference and add the new repo to the access list. Step-by-step: `infrastructure/walkthroughs/org-secret-repo-binding.md`.

Snapshot as of 2026-05-25 (this matrix is updated as the org-secret inventory grows — see ADR-0083 D5/D6 for the inventory pass):

| Secret | Required for | Class applicability |
|---|---|---|
| `SONAR_TOKEN` | `job-sonarcloud.yml` in `pr-core.yml` (ADR-0011 D11) | Every Node consuming `pr-core.yml` — i.e. every class except AI Seed |
| `NUGET_API_KEY` | `release.yml` (ADR-0034) | NuGet-shipping Nodes (Core .NET classes, Ops Deployable .NET when shipping Abstractions) |
| `LABELS_FANOUT_PAT` | Cross-repo label fan-out (ADR-0014) | Any Node participating in label fan-out |
| `HIVE_FIELD_MIRROR_TOKEN` | Hive board field mirroring (ADR-0014) | Any Node participating in Hive field mirroring |
| `HIVE_APP_ID` | Hive GitHub App auth (ADR-0014) | Any Node consuming Hive GitHub App auth |
| `HIVE_APP_PRIVATE_KEY` | Hive GitHub App auth (ADR-0014) | Any Node consuming Hive GitHub App auth |
| `DISCORD_WEBHOOK_OPS_ALERTS` | Operator alerts (ADR-0084) | Any Node emitting operator-actionable ops-alert events |
| `DISCORD_WEBHOOK_SECURITY` | Security alerts (ADR-0084) | Any Node emitting security-channel events |
| `DISCORD_WEBHOOK_AGENT_ACTIVITY` | Agent-activity alerts (ADR-0084) | Any Node emitting agent-activity events |
| `DISCORD_WEBHOOK_HIVE_ACTIVITY` | Hive-activity alerts (ADR-0084) | Any Node emitting hive-activity events |
| `DISCORD_WEBHOOK_RELEASE` | Release alerts (ADR-0084) | Any Node emitting release events |
| `DISCORD_WEBHOOK_ANNOUNCEMENTS` | Announcements (ADR-0084) | Any Node emitting announcement events |
| `DISCORD_WEBHOOK_AUDIT_SENSITIVE` | Audit-sensitive alerts (ADR-0084) | Any Node emitting audit-sensitive events |
| `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` | ADR-0044 review-pipeline emission upstream | Any Node whose `.honeydrunk-review.yaml` has `enabled: true` and posts review results upstream |

**Standing access-policy:** `Selected repositories` is the Grid default for live-credential org secrets. Promoting any of the above to `All repositories` requires an ADR amendment.

## Per-class walkthroughs

The operational step-by-step for each class lives in `infrastructure/walkthroughs/`:

- `node-standup-core-dotnet.md` — Core .NET Abstractions+Runtime and Runtime-only.
- `node-standup-ops-deployable-dotnet.md` — Ops Deployable .NET, adds Key Vault / App Configuration / managed identity / Container Apps / Bicep / deploy trigger / health endpoints.
- `node-standup-meta-docs.md` — Architecture, Lore, Standards, Prompts.
- `node-standup-ai-seed.md` — catalog rows + context folder + sector row only.
- `node-standup-studios-typescript.md` — TypeScript repos.
- `org-secret-repo-binding.md` — the per-secret binding flow (Phase B step).
- `sonarcloud-organization-setup.md` — already exists; one-time org onboarding for the `SONAR_TOKEN` secret.

Each walkthrough composes against this document — it does not duplicate it.
```

(The above is the canonical structure; the implementing PR fills in any prose/examples the agent judges needed to keep the document self-contained but does not invent rules beyond ADR-0082's D1–D8.)

## Affected Files

- `constitution/node-standup.md` (new)

## NuGet Dependencies

None. This packet creates a Markdown governance document; no .NET project is created or modified.

## Boundary Check

- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria

- [ ] `constitution/node-standup.md` exists with the structure above (Source ADR header, six-class taxonomy table, three-phase chain with explicit gates, eighteen mandatory steps, class-specific steps a–z, per-class org-secret binding matrix, walkthrough pointer list)
- [ ] Every mandatory and class-specific step from ADR-0082 D4/D5 is present; nothing is invented beyond ADR-0082's D1–D8
- [ ] The per-class org-secret binding matrix matches the ADR-0082 D8 snapshot as of 2026-05-25 (rows for `SONAR_TOKEN`, `NUGET_API_KEY`, the four Hive-stack secrets, the seven Discord webhook secrets, and `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`)
- [ ] The document carries an "Edit discipline" note matching ADR-0082's commitment that D2-taxonomy and D6-invariant edits require ADR amendment but other edits land via normal PR review (including matrix extensions from ADR-0083 D5/D6 inventory passes)
- [ ] The walkthrough pointer list references all six walkthroughs the rest of this initiative produces (packets 02–07) plus the existing `sonarcloud-organization-setup.md`
- [ ] Cross-references to invariants are by number with a one-line inline restatement of the relevant rule (not just "Invariant 17" — write the actual rule text alongside)
- [ ] Cross-references to ADRs are by ID plus the specific decision (e.g. "ADR-0012 D5", not just "ADR-0012")
- [ ] Repo-level `CHANGELOG.md` updated with a new entry for the new constitutional document (per invariant 12 + 27)

## Human Prerequisites

None.

## Referenced ADR Decisions

**ADR-0082 D1 — Canonical procedure document location.** `constitution/node-standup.md`. Lightweight edit discipline; ADR amendment required only for D2-taxonomy or D6-invariant-wording changes.

**ADR-0082 D2 — Six-class taxonomy.** Closed for 2026-05-25. `node_class:` frontmatter field on standup ADRs.

**ADR-0082 D3 — Three-phase chain.** Phase A → Phase B → Phase C, with optional Phase D reconciliation.

**ADR-0082 D4 — Eighteen mandatory steps.** Enumerated above.

**ADR-0082 D5 — Class-specific steps.** a–z, enumerated above.

**ADR-0082 D8 — Org-secret access propagation policy.** `Selected repositories` is the default; matrix snapshot lives in this document; ADR-0083 D5/D6 inventory passes update without ADR amendment.

## Constraints

- **Document is the deliverable, not a placeholder.** The agent fills in every section above with the actual text from ADR-0082; do not leave `{TODO}` markers or refer the reader back to the ADR for missing detail.
- **No new policy.** The document codifies ADR-0082's eight decisions. It must not invent additional rules, additional steps, or additional org secrets — anything that looks like new policy is a procedure violation; if the agent identifies a gap, it raises a Required Decision rather than authoring policy unilaterally.
- **Invariants are inlined.** Every invariant reference includes a one-line restatement of the rule text — no number-only citations in a constitutional document that future standup packets will dereference.
- **ADR references are decision-specific.** Cite "ADR-0012 D5" with a one-line summary of what D5 says, not just "see ADR-0012".
- **Per-class org-secret matrix snapshot is dated 2026-05-25.** The matrix carries a header noting the snapshot date and the source of future updates (ADR-0083 D5/D6 inventory passes).
- **One PR per repo per initiative.** This packet is the Wave-2 Architecture packet; packets 02–07 are also Architecture-targeted but in Wave 2 or 3 and each lands as its own PR.
- **PR body metadata.** Strict `Authorship: <enum>` + exactly one of `Packet:` (pointing at this packet) or `Out-of-band reason:`.

## Labels

`chore`, `tier-2`, `meta`, `docs`, `adr-0082`, `wave-2`

## Agent Handoff

**Objective:** Author `constitution/node-standup.md` as the canonical Node standup procedure document — three-phase prerequisite chain (D3), eighteen mandatory steps (D4), class-specific steps a–z (D5), per-class org-secret binding matrix (D8), pointers to per-class walkthroughs.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the procedure canonical by putting it in the constitution. The ADR (landed by packet 00) commits *that* the procedure exists; this document commits *what* it is.
- Feature: ADR-0082 Canonical Node Standup Procedure, Wave 2.
- ADRs: ADR-0082 (primary, D1–D8), plus the decision-specific references inlined in the document (ADR-0011 D11, ADR-0012 D1/D4/D5, ADR-0014, ADR-0034, ADR-0044 D4, ADR-0079 D1/D2, ADR-0083 D5/D6, ADR-0084).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 00 (acceptance) must merge first so ADR-0082 is Accepted and invariant 102 exists for cross-reference.

**Constraints:**
- Fully authored document — no `{TODO}` markers, no "see ADR-0082 for the rest".
- No invention of new policy — codify D1–D8, nothing more.
- Inline invariant text and ADR-decision summaries — number-only citations are insufficient for a constitutional document.
- Matrix carries a dated snapshot header and source-of-updates pointer.
- PR body carries strict `Authorship: <enum>` + exactly one of `Packet:` / `Out-of-band reason:`.

**Key Files:**
- `constitution/node-standup.md` (new)

**Contracts:** None changed.
