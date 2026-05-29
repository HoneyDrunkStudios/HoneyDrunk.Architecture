# Node Standup Procedure

**Source ADR:** [ADR-0082](../adrs/ADR-0082-canonical-node-standup-procedure.md) (Canonical Node Standup Procedure).

**Binding invariant:** [Invariant 102](./invariants.md) — *Node registration is mandatory before the first non-bootstrap PR merges.* Every Node repo must carry the ten registration items (three catalog rows, the five-file context folder, a sector row, the `repo-to-node.yml` mapping, `.honeydrunk-review.yaml`, a `pr.yml` calling `pr-core.yml`, branch protection on `pr-core / core`, and org-secret repo binding) before its first non-bootstrap PR merges, with the bootstrap-PR carve-out described under Phase C.

**Related invariants** (each restated inline where it appears below): 4, 12, 17, 19, 24, 26, 27, 31, 32, 33, 34, 35, 36, 38, 39, 41, 46, 49, 50, 52.

**Edit discipline:** This document is PR-reviewed against ADR-0082. Edits that change the D2 taxonomy (the six Node classes) or the invariant-102 wording require an **ADR amendment**; all other edits — including extending the per-class org-secret matrix as the org-secret inventory grows (per ADR-0083 D5/D6) — land via normal PR review. This is the same lightweight discipline that governs `constitution/sectors.md`, not ADR ceremony.

---

## What this document is

The canonical procedure every Grid Node standup follows. Before this document existed, every standup (Communications, the nine AI-sector Nodes, Audit, Notify Cloud, the Cache/Identity/Files pre-commits) re-derived its own checklist from the most recent precedent, and the drift was discovered the next time a Node was stood up. This document is the single source future standup packets, ADRs, and AI agents reference instead of re-deriving.

The procedure is split into four parts:

1. A **three-phase prerequisite chain** — Phase A (Architecture registration) → Phase B (GitHub repo creation) → Phase C (scaffold landing). The phases must run in order; the gates between them are physical (cross-repo state transitions).
2. An **eighteen-step mandatory list** every Node class executes.
3. **Class-specific steps** layered on top, keyed by the Node class declared in the standup ADR's frontmatter (`node_class:` field).
4. A **per-class org-secret binding matrix** naming which org Actions secrets the new repo must be bound to before its first non-bootstrap PR merges.

### What is NOT a Node — operator-internal automation infrastructure carve-out

This procedure (and invariant 102) applies only to artifacts that are **Nodes** under the D2 six-class taxonomy below. Operator-internal automation infrastructure — Azure Key Vaults provisioned for agents (e.g. `kv-hd-docs-sync-prod` per ADR-0085), GitHub Apps registered for cross-repo automation, OpenClaw schedules, the home server itself (ADR-0081), credential inventories (ADR-0083's `infrastructure/reference/sensitive-inventory.md`) — is **NOT** a Node. Invariant 102's ten-item registration checklist does not bind these artifacts: they have no `catalogs/nodes.json` row (they are not Nodes), no `repos/{Node}/` context folder, no `.honeydrunk-review.yaml`, no `pr.yml` calling `pr-core.yml`, and no per-class org-secret matrix. Their governance lives in their owning ADR (ADR-0081, ADR-0083, ADR-0085, …) and the walkthroughs that owning ADR commits.

---

## The six Node classes (per ADR-0082 D2)

Standup procedure varies by Node class. The taxonomy is closed at six classes as of 2026-05-25; a future class addition (mobile per ADR-0070 D3, Tauri desktop, Bicep-only infrastructure repos) requires a one-row amendment to ADR-0082 D2 plus a per-class walkthrough — not a new ADR.

| Class | `node_class:` value | Description | Examples |
|---|---|---|---|
| Core .NET Abstractions+Runtime (default) | `core-dotnet-abstractions-runtime` | One `.Abstractions` package + one runtime/backing package; ships NuGet. The default for substrate Nodes. | Audit, Cache, Identity, Files, Memory, Knowledge, Evals, Flow, Sim |
| Core .NET Runtime-only | `core-dotnet-runtime-only` | Single runtime package; no `.Abstractions` split. Used when the Node *is* the contract holder with no downstream compiling against shapes. | Kernel |
| Ops Deployable .NET | `ops-deployable-dotnet` | One or more `.Abstractions` packages plus one or more deployable Services (Container Apps / Functions). | Notify, Pulse.Collector, Notify Cloud, Operator, Communications (when deployed) |
| Meta / Docs / Wiki | `meta-docs` | No NuGet, no deployable, no contract surface. The repo *is* the deliverable. | Architecture, Lore, Standards, HoneyDrunk.Prompts |
| AI Seed (scaffold-only) | `ai-seed` | Node cataloged but not yet stood up — `signal: "seed"` in `catalogs/nodes.json` with `done: false`. | The nine AI-sector Nodes prior to per-Node scaffold |
| Studios / TypeScript | `studios-typescript` | TypeScript / React / Next-style repo. No NuGet, no .NET CI. | HoneyDrunk.Studios, future SDKs, future per-stack Web.UI packages |

The class is declared in the standup ADR's frontmatter (`node_class:`); if omitted, the default is `core-dotnet-abstractions-runtime`. Authoring tools surface the class for human and agent review.

---

## The three phases (per ADR-0082 D3)

Standup is not a flat checklist. It has three phases with hard prerequisite gates. Skipping a phase or running them out of order produces broken standups (filing the scaffold packet before the repo exists, wiring CI before the catalogs know the Node exists).

### Phase A — Architecture registration

**State:** in `HoneyDrunk.Architecture`; no GitHub repo for the Node yet exists.

Lands as one Architecture packet — the "context folder" packet shape (exemplars: `01-architecture-notify-cloud-context-folder.md`, the Audit context-folder packet). Contents:

- Catalog rows in `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`.
- Sector row in `constitution/sectors.md` (signal `Seed` initially, promoted to `Live` when the scaffold lands).
- Five-file context folder at `repos/{NodeName}/` (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`).
- Standup ADR registered in `adrs/` and `adrs/README.md`.
- Invariant assignment if applicable (claim a number in `constitution/invariant-reservations.md`).

**Gate:** Phase A must merge before Phase B starts. The scaffold packet's `target_repo` would otherwise point at a repo that does not exist.

### Phase B — GitHub repo creation (human-only org-admin action)

**State:** Phase A merged; no GitHub repo for the Node yet.

Lands as one human-only chore packet — exemplar `02-architecture-create-audit-repo.md`. These steps cannot be agent-delegated; they are org-admin actions in the GitHub and Entra portals:

- Repo created at correct visibility — public by default; private only with an ADR-recorded carve-out (see Mandatory Step 5).
- Branch protection applied on `main` — PR required before merge, `pr-core / core` required status check (Invariant 31: *every PR traverses the tier-1 gate before merge* — build, unit tests, analyzers, vuln scan, secret scan are required branch-protection checks delivered via `pr-core.yml`), no force-push, no deletion.
- **Org-secret repo binding** — for every org Actions secret the repo's workflows will consume, visit `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions/{SECRET_NAME}` and add the new repo to the **Selected repositories** access list. GitHub does not auto-propagate `Selected repositories`-scoped secrets to new repos. See the per-class matrix below and `infrastructure/walkthroughs/org-secret-repo-binding.md`.
- Labels seeded (idempotent CLI loop in the chore packet).
- OIDC federated credential subject pattern updated in Microsoft Entra for NuGet-shipping Nodes (`repo:HoneyDrunkStudios/{NodeName}:ref:refs/tags/v*`).
- Local clone made.

**Gate:** Phase B must complete before Phase C is *fileable* — Invariant 24 (*issue packets are immutable once filed as a GitHub Issue*) means the scaffold packet's `target_repo` must exist before its issue can be filed.

### Phase C — Scaffold landing (agent-eligible)

**State:** Phase B complete; repo exists; branch protection active; org-secrets bound; first PR not yet merged.

Lands as the scaffold packet (`03-{node}-node-scaffold.md` shape — exemplar `03-audit-node-scaffold.md`). Contents per the mandatory + class-specific lists below. After scaffold merge, `v0.1.0` may be tagged (human-pushed per Invariant 27 — *agents never push tags*) to publish first packages.

The scaffold PR is the **bootstrap PR** — it is permitted to introduce items 7 (`.honeydrunk-review.yaml`), 8 (`pr.yml`), 9 (branch-protection update for the canary), and 10 (any org-secret binding refinements) in the same commit as the rest of the scaffold. Invariant 102 binds the *second* PR (the first feature PR), not the bootstrap PR. Items 1–6 must exist before the scaffold PR — they are Phase A, and Phase A merges first per the Phase A→B gate.

### Optional Phase D — Reconciliation

Parallel to or after the scaffold: `hive-sync` per ADR-0014 reconciles `catalogs/nodes.json` / `relationships.json` / `grid-health.json` / `modules.json` / `contracts.json` / `initiatives/active-initiatives.md` / `adrs/README.md` if the standup initiative deferred those edits to hive-sync (the scope-doesn't-touch-shared-catalogs convention observed in recent initiatives).

---

## Mandatory steps — every Node class (per ADR-0082 D4)

Eighteen steps. They land across Phases A/B/C as noted in brackets. Skipping any is a procedure violation.

1. **Standup ADR exists** and references ADR-0082 as the procedure source. Shape: the ADR-0019 / ADR-0027 / ADR-0031 / ADR-0059 template (capability/decision body + "If Accepted — Required Follow-Up Work" checklist at the top), paired with a capability-driving ADR when the standup is the second of a pair. *[Phase A]*
2. **Sector assignment** in `constitution/sectors.md`. Signal `Seed` until the scaffold lands, promoted to `Live` when the first non-bootstrap PR merges. Sector membership defines the Grid's published topology — the surface the Hive and the Studios website consume. *[Phase A]*
3. **Context folder** at `repos/{NodeName}/` with all five files (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`). The five-file shape is non-negotiable — it is the surface the `review` agent and the `scope` agent load on every PR touching the Node (Invariant 33: *review-agent and scope-agent context-loading contracts are coupled* — the review agent's loaded set must be a superset of the scope agent's). *[Phase A]*
4. **Catalog entries** in `catalogs/nodes.json` (Node row with all fields — id, name, sector, signal, cluster, energy, priority, flow, tags, repo link, `long_description`, `foundational`, `strategy_base`, `tier`, `time_pressure`, `done`, `cooldown_days`), `catalogs/relationships.json` (every consumes/consumed_by edge ADR-pinned, no cycles per Invariant 4: *the dependency graph is a DAG; Kernel is always at the root*), and `catalogs/grid-health.json` (contract surface, canary expectation, DR tier per ADR-0036). Hive-sync owns the live state per Phase D. *[Phase A]*
5. **Repo created** at the correct visibility — public by default per the standing repo-visibility rule; private only with an ADR-recorded revenue/compliance/experiment carve-out (precedent: ADR-0027 D2 for Notify Cloud, the first private repo on the Grid). *[Phase B]*
6. **Branch protection on `main`** — PR required, `pr-core / core` required check (Invariant 31, restated at step under Phase B), no force-push, no deletion, signed commits not required (matches existing Grid posture). Additional required checks (`api-compatibility / abstractions-shape`, `job-sonarcloud / sonarcloud` for public repos) are added in a *follow-up* branch-protection update after the throwaway breaking-change PR confirms the canary fires post-merge — the same pattern as the Audit and AI standups. *[Phase B; follow-up update post-scaffold]*
7. **Repo-to-Node mapping** in `HoneyDrunk.Actions/.github/config/repo-to-node.yml`. Without this row, the `file-issues` packet routing and the grid-health aggregator cannot resolve issues filed against the new repo back to its Node identity (Invariant 41: *new Grid repos are added to `HoneyDrunk.Architecture/repos/` at creation time* — a repo missing from the catalog is invisible to grid observability). This has been the most frequently forgotten step (commit `23a183c` added Audit retroactively). *[Phase B or Phase C — preferably Phase B, before any issue is filed against the new repo]*
8. **Label seeding** out-of-band before the first non-bootstrap PR (Invariant 32: *agent-authored PRs must link to their packet in the PR body*; absent the link the PR carries the `out-of-band` label) — seed `feature`, `chore`, `tier-1`, `tier-2`, `tier-3`, `scaffold`, `adr-{NNNN}`, `human-only`, `out-of-band`, plus wave/initiative-specific labels. The CLI loop in the chore packet is idempotent. *[Phase B]*
9. **`.honeydrunk-review.yaml`** at the repo root with `enabled: true` or `enabled: false` explicitly declared (Invariant 52: *every non-draft PR on an `enabled` repo runs the cloud-wired `review` agent* — a repo is `enabled` when it carries `.honeydrunk-review.yaml` with `enabled: true`). A missing file is a silent disable, not a default-on — pinning the file as mandatory eliminates that failure mode. *[Phase C]*
10. **CodeRabbit integration** per ADR-0079 D2 (`.coderabbit.yaml` lands with the scaffold; the subscription is org-level — no per-repo action beyond committing the config). Optional during the ADR-0079 phased rollout if the ADR has not yet landed for the affected Node class; mandatory once the rollout phase completes. *[Phase C]*
11. **Copilot review** enabled at the org level (no per-repo action; the org-level setting per ADR-0079 D1 covers every new repo automatically). Standup procedure verifies but does not configure this. *[Phase C — verify only]*
12. **`README.md`** at the repo root and at every package directory (Invariant 12: *semantic versioning with CHANGELOG and README* — every package directory must contain a `README.md` describing purpose, installation, and public API; new projects have it from the first commit). The repo README links to the standup ADR and the `repos/{Node}/` context folder. *[Phase C]*
13. **`CHANGELOG.md`** at the repo root and at every package directory (Invariant 12, as above — the repo-level `CHANGELOG.md` next to the `.slnx` is mandatory and is the source for auto-generated release notes). The first commit's CHANGELOG carries the `## [0.1.0] - YYYY-MM-DD` entry — no `## Unreleased` at commit time. *[Phase C]*
14. **`LICENSE`** at the repo root — Grid default MIT for public repos (ADR-0039 D1); FSL-1.1-MIT for the open engines of revenue Nodes (ADR-0039 D2 / ADR-0027 D11); `LicenseRef-Proprietary` for private revenue Nodes. *[Phase C]*
15. **`.github/copilot-instructions.md`** — a per-repo file pointing back to Architecture's copilot-instructions plus any repo-specific addenda. Mirrored to OpenClaw skills per ADR-0007's Operational Addendum when applicable. *[Phase C]*
16. **`CLAUDE.md`** at the repo root if the repo is a primary dev surface (Core .NET, Ops Deployable .NET, Meta docs, Studios TypeScript — yes; AI Seed — n/a until scaffolded). Links to `repos/{Node}/overview.md`, the standup ADR, and the local-dev orchestration anchor (ADR-0065 if Aspire is involved). *[Phase C]*
17. **`pr-core.yml` CI workflow** at `.github/workflows/pr.yml` calling `HoneyDrunk.Actions`'s reusable `pr-core.yml` (ADR-0012 D1 — `HoneyDrunk.Actions` is the CI/CD control plane). The caller-side `permissions:` block follows the canonical superset pattern (ADR-0012 D5 / Invariant 39: *caller workflows declare a `permissions:` block that is a superset of the reusable workflow's declared permissions*). This is the wire for the tier-1 gate (Invariant 31). *[Phase C]*
18. **Initiative + roadmap entry** — the standup initiative added to `initiatives/active-initiatives.md`; roadmap bullet added to `initiatives/roadmap.md` (deferred to hive-sync per Phase D in current convention). *[Phase A or Phase D]*

---

## Class-specific steps (per ADR-0082 D5)

### Core .NET (Abstractions+Runtime, Runtime-only, Ops Deployable) — all .NET classes

- **a.** `.slnx` solution at the repo root.
- **b.** `Directory.Build.props` with `TargetFramework`, `Nullable`, `ImplicitUsings`, `LangVersion`, `TreatWarningsAsErrors`, a shared `Version` (Invariant 27: *all projects in a solution share one version and move together*), `Authors`, `PackageProjectUrl`, `RepositoryUrl`, `RepositoryType`, `PublishRepositoryUrl`, `IncludeSymbols`, `SymbolPackageFormat`, `GenerateDocumentationFile`. Exemplar in the Audit scaffold packet text.
- **c.** `HoneyDrunk.Standards` reference with `PrivateAssets="all"` on every `.csproj` (Invariant 26: *issue packets for .NET work must include an explicit NuGet Dependencies section, and `HoneyDrunk.Standards` must be explicitly listed on every new .NET project*). StyleCop + EditorConfig + analyzer suite; `.editorconfig` shipped from Standards.
- **d.** Test project layout — a `*.Tests.Unit` project always; deployable Nodes also add `*.Tests.Integration`; HTTP-fronted Nodes also add `*.Tests.E2E` (Invariant 50: *every Node has a `*.Tests.Unit` project; deployable Nodes also have a `*.Tests.Integration`; HTTP-fronted Nodes also have a `*.Tests.E2E`; a missing required tier is a CI gate failure*). xUnit + NSubstitute + AwesomeAssertions + coverlet (ADR-0074).
- **e.** `release.yml` consuming `HoneyDrunk.Actions`'s `release.yml` reusable workflow (ADR-0012 / ADR-0034); tag-triggered (`on: push: tags: [v*.*.*]`); no `secrets: inherit` — explicit named secrets only.
- **f.** `nightly-deps.yml` consuming the reusable workflow (ADR-0009).
- **g.** `nightly-security.yml` consuming the reusable workflow (ADR-0009).
- **h.** OIDC federated credential subject pattern (`repo:HoneyDrunkStudios/{NodeName}:ref:refs/tags/v*`) added to the Grid's NuGet publishing identity in Microsoft Entra. Walkthrough: `infrastructure/walkthroughs/oidc-federated-credentials.md`.
- **i.** Contract-shape canary (`api-compatibility.yml`) scoped to the Node's `.Abstractions` package(s), path-filtered to `src/{Node}.Abstractions/**` and `Directory.Build.props` (Invariant 46 is the AI-Node instance of this rule: *the CI must include a contract-shape canary that fails the build on shape drift without a corresponding version bump*; Invariant 49 is the Audit instance). This is a **mandatory** standup step for every .NET Node shipping an Abstractions package — not a polish item. The throwaway breaking-change PR confirming the canary fires post-merge is part of the human prerequisites for the scaffold packet.
- **j.** In-memory test fixture for the Node's primary contracts — internal to the runtime package's test project at standup (ADR-0027 D3 precedent); cut to a `{Node}.Testing` package as a non-breaking change only when a third consumer needs it.
- **k.** End-to-end smoke test exercising the in-memory fixture: write through the primary contract, read back through the query/observation contract, assert round-trip.
- **l.** `sonar-project.properties` + `job-sonarcloud.yml` for public repos (ADR-0011 D11 — SonarCloud is the tier-2 gate on public repos). One-time org onboarding lives in `infrastructure/walkthroughs/sonarcloud-organization-setup.md`; the per-repo `SONAR_TOKEN` binding is in the org-secret matrix below.
- **m.** Project board hook — new issues filed against the repo auto-add to the org Project (Hive #4) via the repo-filter auto-add workflow (ADR-0008 D5). The filter is org-level (`repo:HoneyDrunkStudios/*`); standup verifies coverage but configures nothing.

### Ops Deployable .NET — additional steps

- **n.** **Key Vault per environment** named `kv-hd-{service}-{env}` (Invariant 17: *one Key Vault per deployable Node per environment, Azure RBAC enabled, access policies forbidden*; Invariant 19: *service names in Azure resource naming must be ≤ 13 characters*). Walkthrough: `infrastructure/walkthroughs/key-vault-creation.md`.
- **o.** **App Configuration store** per environment named `appcs-hd-{service}-{env}` (ADR-0005). Walkthrough: `infrastructure/walkthroughs/app-configuration-provisioning.md`.
- **p.** **Managed identity** per Node per environment, system-assigned — each Node authenticates as itself; no shared identity (ADR-0031 D5, generalized).
- **q.** **Container Apps wiring** (`ca-hd-{service}-{env}` per Invariant 34: *containerized deployable Nodes run on Azure Container Apps, named `ca-hd-{service}-{env}`, one per Node per environment, system-assigned Managed Identity*), revision mode `Multiple` (Invariant 36: *Container App revision mode is `Multiple` with explicit traffic splitting — single-revision mode removes the rollback seam*), shared environment `cae-hd-{env}` and shared registry `acrhdshared{env}` (Invariant 35: *one shared Container Apps Environment and one shared Azure Container Registry serve every containerized Node within an environment*). Walkthrough: `infrastructure/walkthroughs/container-app-creation.md`.
- **r.** **Bicep modules** at `infra/` (ADR-0077), modularized by concern (one `.bicep` per resource family). Deployment workflow consumes `HoneyDrunk.Actions`'s `job-deploy-bicep.yml`.
- **s.** **Deploy trigger model** (ADR-0033): path-filtered push-to-`main` deploys `dev`; SemVer tags gate `staging`/`prod`. Per-deployable path scoping for multi-deployable repos; environment-keyed concurrency.
- **t.** **Health endpoints** (ADR-0066): `/health/live`, `/health/ready`, `/health` for every HTTP-fronted deployable Node.

### Meta / Docs / Wiki — additional and skipped steps

- **u.** No NuGet publication, no `release.yml`, no OIDC federated credential. The repo *is* the deliverable. Of the mandatory eighteen, steps 5–9, 12–15, 17, 18 apply; the .NET-specific a–m do not.
- **v.** If the repo ships content (Prompts, Standards content files), a content-shape canary per the Prompts standup spec — frontmatter parses, parameter parity holds, no `classification: Restricted` content.

### AI Seed — Phase A only

- **w.** Phase A only. No repo, no CI, no managed identity, no scaffold packet. The Node is cataloged with `signal: "seed"` and `done: false` and waits for its per-Node scaffold packet, which lands as a regular Phase B + Phase C against the just-promoted Core .NET class.

### Studios / TypeScript — additional and replaced steps

- **x.** No `.slnx`, no `Directory.Build.props`, no `HoneyDrunk.Standards`. Replace with `package.json`, `tsconfig.json`, and ESLint/Prettier configuration matching the existing Studios repo's stack.
- **y.** Node.js CI workflow at `.github/workflows/pr.yml` calling a (future) `HoneyDrunk.Actions` `pr-typescript.yml` reusable workflow if one exists, or directly invoking `npm ci && npm run build && npm test` until that workflow is built (ADR-0012 D4 / Invariant 38: *reusable workflows invoke tool CLIs directly — wrapping a tool in a third-party marketplace action is forbidden for any tool with a stable CLI*; npm/Node wrappers are rejected for the same reasons as gitleaks-action@v2).
- **z.** Web.UI design-token consumption per ADR-0071 when the package is React-stack.

---

## Per-class org-secret binding matrix (per ADR-0082 D8)

GitHub does **not** auto-propagate org Actions secrets with the `Selected repositories` access policy to new repos. The org admin must visit `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions/{SECRET_NAME}` for every secret the new repo's workflows reference and add the new repo to the access list. Without this step, the new repo's first non-bootstrap PR consuming any of those secrets hard-fails — silently for empty-string substitution, loudly for explicit-required wiring. Step-by-step: `infrastructure/walkthroughs/org-secret-repo-binding.md`.

**Snapshot as of 2026-05-25.** This matrix is updated as the org-secret inventory grows — the authoritative inventory pass lives in ADR-0083 D5/D6, and those updates land here via normal PR review (no ADR amendment).

| Secret | Required for | Class applicability |
|---|---|---|
| `SONAR_TOKEN` | `job-sonarcloud.yml` invoked from `pr-core.yml` (ADR-0011 D11) — hard-fails without it | Every Node consuming `pr-core.yml` — i.e. every class except AI Seed |
| `NUGET_API_KEY` | `release.yml` nuget.org publishing (ADR-0034) | NuGet-shipping Nodes (the Core .NET classes; Ops Deployable .NET when it ships Abstractions) |
| `LABELS_FANOUT_PAT` | Cross-repo label fan-out (ADR-0014 hive-sync stack) | Any Node participating in cross-repo label fan-out |
| `HIVE_FIELD_MIRROR_TOKEN` | Hive board field mirroring (ADR-0014) | Any Node participating in Hive field mirroring |
| `HIVE_APP_ID` | Hive GitHub App auth (ADR-0014) | Any Node consuming Hive GitHub App auth |
| `HIVE_APP_PRIVATE_KEY` | Hive GitHub App auth (ADR-0014) | Any Node consuming Hive GitHub App auth |
| `DISCORD_WEBHOOK_OPS_ALERTS` | Operator ops-alert events (ADR-0084) | Any Node emitting operator-actionable ops-alert events |
| `DISCORD_WEBHOOK_SECURITY` | Security-channel events (ADR-0084) | Any Node emitting security events |
| `DISCORD_WEBHOOK_AGENT_ACTIVITY` | Agent-activity events (ADR-0084) | Any Node emitting agent-activity events |
| `DISCORD_WEBHOOK_HIVE_ACTIVITY` | Hive-activity events (ADR-0084) | Any Node emitting hive-activity events |
| `DISCORD_WEBHOOK_RELEASE` | Release events (ADR-0084) | Any Node emitting release events |
| `DISCORD_WEBHOOK_ANNOUNCEMENTS` | Announcement events (ADR-0084) | Any Node emitting announcement events |
| `DISCORD_WEBHOOK_AUDIT_SENSITIVE` | Audit-sensitive events (ADR-0084) | Any Node emitting audit-sensitive events |
| `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` | ADR-0044 review-pipeline upstream emission | Any Node whose `.honeydrunk-review.yaml` has `enabled: true` and posts review results upstream |

**Standing access-policy:** `Selected repositories` is the Grid default for org secrets containing live credentials, tokens, webhooks, or signing material — i.e. every org secret currently in use. `All repositories` is reserved for benign org constants (none currently exist). Promoting any secret from `Selected repositories` to `All repositories` requires an ADR amendment.

---

## Per-class walkthroughs

The operational step-by-step for each class lives in `infrastructure/walkthroughs/`. Each walkthrough composes against this document — it does not duplicate the rules.

- `node-standup-core-dotnet.md` — Core .NET Abstractions+Runtime and Runtime-only, including the throwaway-breaking-change PR sequence that confirms the contract-shape canary post-merge.
- `node-standup-ops-deployable-dotnet.md` — Ops Deployable .NET, adding Key Vault, App Configuration, managed identity, Container Apps, Bicep modules, deploy trigger model, and health endpoints.
- `node-standup-meta-docs.md` — Architecture, Lore, Standards, Prompts, and future docs/wiki repos.
- `node-standup-ai-seed.md` — the smallest walkthrough: catalog rows + context folder + sector row, plus the promotion gate from seed to Core .NET.
- `node-standup-studios-typescript.md` — TypeScript repos (Studios, future SDKs, future per-stack Web.UI packages).
- `org-secret-repo-binding.md` — the per-secret Settings → Secrets → Actions → {Secret} → Selected repositories → Add repositories flow (the Phase B binding step).
- `sonarcloud-organization-setup.md` — already exists; the one-time SonarCloud org onboarding behind the `SONAR_TOKEN` secret.
