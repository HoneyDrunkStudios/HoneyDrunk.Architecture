# ADR-0082: Canonical Node Standup Procedure

**Status:** Accepted
**Date:** 2026-05-25
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

## Context

The Grid has stood up a new Node every few weeks for most of 2026: Communications (ADR-0019), the nine AI-sector Nodes (ADR-0016 through ADR-0025), Audit (ADR-0031), Notify Cloud (ADR-0027), and the Cache / Identity / Files / Web.UI / Cache backing / Prompts pre-commits (ADR-0058 through ADR-0078). Every one of those standups produced — out of necessity — its own *implicit* checklist, woven into per-Node packets like `02-architecture-create-audit-repo.md`, `03-audit-node-scaffold.md`, `01-architecture-notify-cloud-context-folder.md`, and `05-architecture-create-notify-cloud-repo.md`. Those packets are good. They are also where the procedure lives.

There is no canonical "new repo / new Node standup procedure" document. Each new standup re-derives the checklist from the most recent precedent (Audit copied from Operator; Notify Cloud copied from Communications; the Cache pair copied from the AI sector). When the procedure drifts — and it has, repeatedly — the drift is discovered the next time a Node is stood up, and the new packet either copies the drift forward or silently corrects it without record. Concrete drift already in the wild:

- The `.github/repo-to-node.yml` mapping in `HoneyDrunk.Actions` was added retroactively for Audit (commit `23a183c`) **after** Audit's standup packets had been filed — every standup before that had to remember to wire the mapping or accept that the `file-issues` packet routing would not find the repo.
- ADR-0044 introduced `.honeydrunk-review.yaml` as the gate for cloud-wired review (Invariant 52); ADR-0011 introduced the tier-1 branch protection check (Invariant 31). Neither rule lives in a standup-procedure document. New Nodes are expected to discover both by reading two cross-cutting ADRs.
- The contract-shape canary requirement (ADR-0016 D8, ADR-0019 D8, ADR-0031 D8 — soon to be invariant-pinned for Audit as Invariant 49) recurs in every Abstractions-owning Node's standup, freshly justified each time, rather than being a reusable step.
- The "create repo as public unless ADR-recorded carve-out" rule (memory-pinned, not constitution-pinned) appears in every standup packet without a single source.

This gap was identified during ADR-0011 acceptance work (currently in flight on branch `adr-0011-acceptance`). The acceptance pass needed to wire `sonar-project.properties` and `job-sonarcloud.yml` into every public repo per ADR-0011 D11; the natural question — "where is the canonical procedure I am extending?" — has no answer.

The cost is real. Each new Node standup pays a 30–60-minute "rediscover the procedure" tax. AI-authored standup packets (per ADR-0044 D6) have no canonical procedure to reference, so they re-derive the checklist from whichever recent ADR they happened to read, and the rubric in ADR-0044 D3 has no procedure-adherence category to check against. Future Node-class variation (Core .NET vs Studios TypeScript vs AI seed scaffold-only) gets re-litigated on every standup.

This ADR closes the gap by naming **the canonical standup procedure**, splitting it by Node class where the procedure legitimately diverges, and committing the procedure to a small set of constitution-level documents so future standup packets reference one source instead of inventing their own.

This ADR is the **process decision** for what every Grid Node standup must do. It is not a per-class walkthrough — those land as follow-ups in `infrastructure/walkthroughs/` once this ADR is Accepted. It is also not a re-litigation of ADR-0044's `.honeydrunk-review.yaml` schema, ADR-0011's tier-1 gate composition, ADR-0012's reusable-workflow factoring, ADR-0007's `.claude/agents/` location, or ADR-0008's packet/issue/board lifecycle. Those are referenced here as *inputs*; this ADR only decides which of them apply to standup and in what order.

This ADR depends on ADR-0007, ADR-0008, ADR-0011 (and specifically D11's SonarCloud gate, which is the forcing example for org-secret repo binding — see D8), ADR-0012, ADR-0014 (hive-sync reconciliation and the `LABELS_FANOUT_PAT` / `HIVE_FIELD_MIRROR_TOKEN` / `HIVE_APP_ID` / `HIVE_APP_PRIVATE_KEY` org-secret stack), ADR-0034 (NuGet publishing and the `NUGET_API_KEY` org secret), ADR-0044 (and `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`), ADR-0046, [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) (org-secret inventory cross-cuts the D8 list), [ADR-0084](./ADR-0084-discord-operator-alerts-surface.md) (the seven Discord webhook org secrets that will need binding for any Node emitting operator-actionable events), and on the Audit-standup procedure as the gold-standard worked example (ADR-0031 D11 plus packets 02 and 03).

## Decision

The canonical standup procedure is defined by eight bound sub-decisions. Together they name the procedure, its source-of-truth document, the Node-class taxonomy, the mandatory-vs-optional split, the ordering and prerequisite chain, the enforceable invariant, the follow-up walkthroughs this ADR unlocks, and the org-secret access-propagation policy that gates every new repo's first non-bootstrap PR.

### D1 — One canonical procedure document, in the constitution

The canonical standup procedure lives at **`constitution/node-standup.md`** (new file, landed by this ADR's first follow-up packet). It is a single readable document — checklist plus per-class variance — that every standup packet, ADR, and AI agent references as the single source of truth.

Rejected alternate locations:

- **`routing/` (next to `execution-rules.md`, `request-types.md`, etc.).** Routing covers how an existing work item flows to its target repo. Standup is the work item that creates the target repo in the first place — a different concern. Co-locating would blur the line.
- **`infrastructure/walkthroughs/`.** Walkthroughs are operational runbooks for specific tasks (Container App creation, Key Vault provisioning, OIDC federated credentials). The per-class standup walkthroughs *will* land there (see D7), but the canonical procedure document is constitutional — it pins the rules every walkthrough composes against, the same way `constitution/invariants.md` pins the rules every ADR composes against.
- **A new top-level `standup/` folder.** Premature. One document, in the constitution, until it grows past the point where a single file is the right shape.
- **Inside an ADR's body.** This ADR is the *decision* that the procedure exists; the procedure is a living checklist that will be updated as the Grid adds Node classes (mobile, Tauri, Bicep-only infrastructure repos) without an ADR amendment per update. Edits to `constitution/node-standup.md` are governed by the same lightweight discipline that governs `constitution/sectors.md` (per-edit PR review against this ADR), not by ADR ceremony.

The document's canonical filename and location are pinned by this D1; the document's *content* is the rest of this ADR's text, reformatted as a checklist when the follow-up packet lands.

### D2 — Node-class taxonomy

Standup procedure varies by Node class. The taxonomy is committed here so future packets don't reinvent the categories. Six classes:

| Class | Description | Examples | Procedure footprint |
|---|---|---|---|
| **Core .NET Abstractions+Runtime** | One `.Abstractions` package + one runtime/backing package; ships NuGet. The default for substrate Nodes. | Audit, Cache, Identity, Files, Memory, Knowledge, Evals, Flow, Sim | Full procedure: all sections D5 a–t. |
| **Core .NET Runtime-only** | Single runtime package; no `.Abstractions` split. Used when the Node *is* the contract holder and has no downstream consumer compiling against shapes (rare; Kernel is the historical example). | Kernel | Full procedure except the contract-shape canary (D5q) is scoped to the runtime package's public surface, not an `Abstractions` package. |
| **Ops Deployable .NET** | One or more `.Abstractions` packages plus one or more deployable Services (Container Apps / Functions). Adds deployment wiring, managed identity per environment, Bicep modules. | Notify (Functions + Worker), Pulse.Collector, Notify Cloud, Operator (when deployed), Communications (when deployed) | Full procedure plus Ops addendum (D5u–y): Key Vault per environment, Container Apps wiring per ADR-0015, Bicep modules per ADR-0077, deploy workflows per ADR-0012, environment promotion per ADR-0033, health endpoints per ADR-0066. |
| **Meta / Docs / Wiki** | No NuGet, no deployable, no contract surface. The repo *is* the deliverable. | Architecture, Lore, Standards, HoneyDrunk.Prompts (per ADR-0064) | Reduced procedure: D5a–j, q (n/a), r (n/a), s (n/a), t (content-shape canary if applicable). No `.Abstractions` package, no NuGet OIDC, no managed identity, no Bicep. |
| **AI Seed (scaffold-only)** | Node cataloged but not yet stood up — `signal: "seed"` in `catalogs/nodes.json` with `done: false`. ADR-0016 through ADR-0025 created these as a wave. | The nine AI-sector Nodes prior to their per-Node scaffold packets | The taxonomy step *only*: catalog rows + `repos/{Node}/` context folder + sector row. No repo, no CI, no managed identity. Promotes to Core .NET Abstractions+Runtime when the per-Node scaffold packet lands. |
| **Studios / TypeScript** | TypeScript / React / Next-style repo. No NuGet, no .NET CI; ships static site or npm package. | HoneyDrunk.Studios, future HoneyDrunk.Web.UI per-stack packages, future SDK packages per ADR-0057 | Reduced .NET procedure (no .slnx, no Directory.Build.props, no HoneyDrunk.Standards); adds Node.js CI workflows (D5z). Per-class walkthrough lands separately (see D7). |

The taxonomy is closed at six classes for the Grid as of 2026-05-25. Future class additions (mobile apps per ADR-0070 D3, Bicep-only infra repos, Tauri desktop clients) require a one-row amendment to this D2 plus a per-class walkthrough; not a new ADR.

The class is declared in the standup ADR's frontmatter as a new optional field — `node_class: core-dotnet-abstractions-runtime` (or one of the other five values). When omitted, the default is `core-dotnet-abstractions-runtime`. Authoring tools surface the class for human and agent review.

### D3 — The procedure has three phases, with explicit prerequisite gates

Standup is not a flat checklist. It has three phases with hard prerequisite gates between them. Skipping a phase or running them out of order produces broken standups (e.g. trying to file the scaffold packet before the repo exists, or trying to wire CI before the catalogs know the Node exists).

**Phase A — Architecture registration (in `HoneyDrunk.Architecture`, no GitHub repo yet).** Catalog rows, sector membership, context folder, ADR registration, invariant assignment if applicable. Lands as one Architecture packet (the "context folder" packet in existing initiatives — e.g. `01-architecture-notify-cloud-context-folder.md`). Gate: must merge before Phase B.

**Phase B — GitHub repo creation (human-only org-admin action).** Repo created on GitHub at the correct visibility, branch protection applied, **new repo bound to each org Actions secret it consumes (per D8 — GitHub org secrets with `Selected repositories` access policy do NOT auto-propagate; the org admin must visit `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions/{SECRET_NAME}` for each org secret the new repo will consume and add the repo to its access list — minimum set for any Node consuming `pr-core.yml` is `SONAR_TOKEN` per ADR-0011 D11; conditional additions per the per-class matrix in `constitution/node-standup.md`)**, labels seeded, OIDC federated credential subject pattern updated (for NuGet-shipping Nodes), local clone made. Lands as one human-only chore packet — exemplar is `02-architecture-create-audit-repo.md`. Gate: must complete before Phase C is *fileable* (per Invariant 24 — the scaffold packet's `target_repo` must exist before the issue can be filed).

**Phase C — Scaffold landing (agent-eligible, against the now-existing repo).** First PR delivers solution layout, packages, contract surface, in-memory fixture, CI workflows, README, CHANGELOG, LICENSE, contract-shape canary, smoke test. Lands as the scaffold packet (the `03-{node}-node-scaffold.md` shape) — exemplar is `03-audit-node-scaffold.md`. After scaffold merge, `v0.1.0` may be tagged (human-pushed per Invariant 27) to publish first packages.

Optional Phase D — Reconciliation (parallel or post-scaffold): hive-sync per ADR-0014 reconciles `catalogs/nodes.json` / `relationships.json` / `grid-health.json` / `modules.json` / `contracts.json` / `initiatives/active-initiatives.md` / `adrs/README.md` if the standup initiative deferred those edits to hive-sync (per the scope-doesn't-touch-shared-catalogs rule observed in recent initiatives — see ADR-0027 packet 01's explicit deferral).

The three-phase split exists because two of the phase boundaries are physical: Phase A→B crosses from Architecture-repo state to GitHub-org state, and the human-only Phase B cannot be agent-delegated. Phase B→C crosses from "no repo" to "repo exists with target_repo populatable in frontmatter."

### D4 — Mandatory steps (every Node class)

These steps land in every standup, regardless of class. They are constitutional:

1. **Standup ADR exists** and references this ADR as the procedure source. The standup ADR follows the shape of ADR-0019, ADR-0027, ADR-0031, or ADR-0059 — capability/decision in the body, "If Accepted — Required Follow-Up Work" checklist at the top, paired with a capability-driving ADR when the standup is the second of a pair (e.g. ADR-0058 → ADR-0059, ADR-0064 → paired Prompts standup).
2. **Sector assignment** in `constitution/sectors.md` (Core / Ops / Meta / AI / Creator / etc.) — sector row added with `Signal: Seed` until the scaffold lands, then promoted to `Live` when the first non-bootstrap PR merges. Sector membership defines the Grid's published topology and is the surface the Hive and Studios website consume.
3. **Context folder** at `repos/{NodeName}/` with all five files: `overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`. The five-file shape is non-negotiable — it is the surface the `review` agent (per ADR-0011 D4 / ADR-0044 D2 / Invariant 33) and the `scope` agent (per ADR-0008) both load on every PR touching the Node.
4. **Catalog entries** in:
   - `catalogs/nodes.json` — Node row with id, name, sector, signal, cluster, energy, priority, flow, tags, repo link, `long_description`, `foundational`, `strategy_base`, `tier`, `time_pressure`, `done`, `cooldown_days`. (Hive-sync owns the live state — see D3 Phase D.)
   - `catalogs/relationships.json` — every consumes/consumed_by edge ADR-pinned. New edges land as part of the standup. No cycles (Invariant 4).
   - `catalogs/grid-health.json` — Node row reflecting contract surface, canary expectation, DR tier per ADR-0036.
5. **Repo created** at the correct visibility — public by default per the standing repo-visibility memory; private only with an ADR-recorded revenue/compliance/experiment carve-out (precedent: ADR-0027 D2 for Notify Cloud).
6. **Branch protection on `main`**: require PR before merge, require `pr-core / core` status check (per Invariant 31), no force-push, no deletion, signed commits not required (matches existing Grid posture). Additional required checks (`api-compatibility / abstractions-shape`, `job-sonarcloud / sonarcloud` for public repos) added in a *follow-up* branch-protection update after the throwaway breaking-change PR confirms the canary fires post-merge — same pattern as the Audit and AI standups.
7. **Repo-to-Node mapping** in `HoneyDrunk.Actions/.github/config/repo-to-node.yml`. Without this row the `file-issues` packet routing and the grid-health aggregator cannot resolve issues filed against the new repo back to its Node identity. This step has been the most frequently forgotten step in past standups (commit `23a183c` added Audit retroactively); committing it as mandatory in the procedure closes that drift channel.
8. **Label seeding** out-of-band before the first non-bootstrap PR (per Invariant 32 and the `02-architecture-create-{node}-repo.md` exemplar) — `feature`, `chore`, `tier-1`, `tier-2`, `tier-3`, `scaffold`, `adr-{NNNN}`, `human-only`, `out-of-band`, plus any wave/initiative-specific labels. Color choices follow the existing convention; CLI loop in the chore packet is idempotent.
9. **`.honeydrunk-review.yaml`** at the repo root with `enabled: true` (per Invariant 52 / ADR-0044 D4). The Grid-aware cloud reviewer treats a missing file as `enabled: false`, so its absence is a silent disable, not a default-on. Pinning the file as a mandatory standup artifact eliminates the silent-disable failure mode.
10. **CodeRabbit integration** — added per ADR-0079 D2 (`.coderabbit.yaml` lands with the scaffold; subscription is org-level, no per-repo action needed beyond committing the config file). Optional during the ADR-0079 phased rollout if the ADR has not yet landed for the affected Node class; mandatory once ADR-0079 is Accepted and the rollout phase is complete.
11. **Copilot review** enabled at the org level — no per-repo action; the org-level setting per ADR-0079 D1 covers every new repo automatically. Standup procedure verifies but does not configure this.
12. **`README.md`** at repo root and at every package directory per Invariant 12. Repo README links to the standup ADR and the `repos/{Node}/` context folder.
13. **`CHANGELOG.md`** at repo root and at every package directory per Invariant 12. The first commit's CHANGELOG carries the `## [0.1.0] - YYYY-MM-DD` entry — no `## Unreleased` at commit time.
14. **`LICENSE`** at repo root — Grid default MIT for public repos per ADR-0039 D1; FSL-1.1-MIT for open engines of revenue Nodes per ADR-0039 D2 / ADR-0027 D11; proprietary `LicenseRef-Proprietary` for private revenue Nodes.
15. **`.github/copilot-instructions.md`** — per-repo file pointing back to Architecture's copilot-instructions plus any repo-specific addenda. Mirrored to OpenClaw skills per ADR-0007's Operational Addendum when applicable.
16. **`CLAUDE.md`** at repo root if the repo is expected to be developed against directly by Claude Code (Core .NET and Ops Deployable .NET classes — yes; Meta docs — yes; AI Seed — n/a until scaffolded; TypeScript — yes if the repo is a primary dev surface). Contains the Claude Code context anchor — links to `repos/{Node}/overview.md`, the standup ADR, and the local-dev orchestration anchor (per ADR-0065 if Aspire is involved).
17. **`pr-core.yml` CI workflow** at `.github/workflows/pr.yml` calling `HoneyDrunk.Actions`'s reusable `pr-core.yml` per ADR-0012 D1. Caller-side `permissions:` block follows the canonical superset pattern per ADR-0012 D5. This is the wire for the tier-1 gate (Invariant 31).
18. **Initiative + roadmap entry** — standup initiative added to `initiatives/active-initiatives.md`; roadmap bullet added to `initiatives/roadmap.md` (deferred to hive-sync per D3 Phase D in current convention).

### D5 — Class-specific steps (apply per D2)

**Core .NET Abstractions+Runtime (and Runtime-only, and Ops Deployable .NET — collectively the .NET classes):**

- a. `.slnx` solution at the repo root.
- b. `Directory.Build.props` with `TargetFramework`, `Nullable`, `ImplicitUsings`, `LangVersion`, `TreatWarningsAsErrors`, shared `Version` (per Invariant 27), `Authors`, `PackageProjectUrl`, `RepositoryUrl`, `RepositoryType`, `PublishRepositoryUrl`, `IncludeSymbols`, `SymbolPackageFormat`, `GenerateDocumentationFile` — exemplar in the Audit scaffold packet's text.
- c. `HoneyDrunk.Standards` package reference with `PrivateAssets="all"` on every `.csproj` per Invariant 26. StyleCop + EditorConfig + analyzer suite. `.editorconfig` shipped from Standards.
- d. Test project layout: a `*.Tests.Unit` project on every Node; deployable Nodes also have a `*.Tests.Integration` project; HTTP-fronted Nodes also have a `*.Tests.E2E` project (Invariant 50). xUnit + NSubstitute + AwesomeAssertions + coverlet per ADR-0074.
- e. `release.yml` workflow consuming `HoneyDrunk.Actions`'s `release.yml` reusable workflow per ADR-0012 / ADR-0034; tag-triggered (`on: push: tags: [v*.*.*]`); no `secrets: inherit` — explicit named secrets only.
- f. `nightly-deps.yml` consuming `HoneyDrunk.Actions`'s reusable workflow per ADR-0009.
- g. `nightly-security.yml` consuming the reusable workflow per ADR-0009.
- h. OIDC federated credential subject pattern (`repo:HoneyDrunkStudios/{NodeName}:ref:refs/tags/v*`) added to the Grid's NuGet publishing identity in Microsoft Entra per `infrastructure/walkthroughs/oidc-federated-credentials.md`.
- i. Contract-shape canary (`api-compatibility.yml`) scoped to the Node's `.Abstractions` package(s) per ADR-0011 / ADR-0035 / the per-Node canary invariant (Invariants 46, 49, et al.). Path-filtered to `src/{Node}.Abstractions/**` and `Directory.Build.props`. The canary is a **mandatory** standup step for every .NET Node that ships an Abstractions package — not a polish item. (The throwaway-breaking-change PR confirming the canary fires post-merge is part of the human-prerequisites for the scaffold packet, not a separate step.)
- j. In-memory test fixture for the Node's primary contracts — internal to the runtime package's test project at standup per the ADR-0027 D3 precedent; cut to a `{Node}.Testing` package as a non-breaking change when a third consumer needs it.
- k. End-to-end smoke test exercising the in-memory fixture: write through the primary contract, read back through the query/observation contract, assert round-trip.
- l. `sonar-project.properties` + `job-sonarcloud.yml` for public repos per ADR-0011 D11 (SonarCloud organization onboarding walkthrough per the ADR-0011 acceptance pass being authored in the same PR as this ADR was scoped).
- m. Project board hook — new issues filed against the repo auto-add to the org Project (Hive) #4 via the repo-filter auto-add workflow per ADR-0008 D5. No per-repo configuration needed once the org-level filter is in place; standup procedure verifies the filter still covers the new repo (it does, automatically — the filter is `repo:HoneyDrunkStudios/*`).

**Ops Deployable .NET additions (Ops class only):**

- n. **Key Vault per environment** named `kv-hd-{service}-{env}` per Invariant 17 / Invariant 19 (the ≤ 13-character service-name limit). Provisioned via `infrastructure/walkthroughs/key-vault-creation.md`.
- o. **App Configuration store** per environment named `appcs-hd-{service}-{env}` per ADR-0005. Provisioned via `infrastructure/walkthroughs/app-configuration-provisioning.md`.
- p. **Managed identity** per Node per environment, system-assigned. Each Node authenticates as itself; no shared identity. Audit's standup pins this rule at ADR-0031 D5; this procedure generalizes it.
- q. **Container Apps wiring** (`ca-hd-{service}-{env}` per Invariant 34), revision mode `Multiple` per Invariant 36, shared environment `cae-hd-{env}` and shared registry `acrhdshared{env}` per Invariant 35. Provisioned via `infrastructure/walkthroughs/container-app-creation.md`.
- r. **Bicep modules** at `infra/` per ADR-0077, modularized by concern (one `.bicep` per resource family). Deployment workflow consumes `HoneyDrunk.Actions`'s `job-deploy-bicep.yml`.
- s. **Deploy trigger model** per ADR-0033: path-filtered push-to-`main` deploys `dev`; SemVer tags gate `staging`/`prod`. Per-deployable path scoping for multi-deployable repos; environment-keyed concurrency.
- t. **Health endpoints** per ADR-0066: `/health/live`, `/health/ready`, `/health` for every HTTP-fronted deployable Node.

**Meta / Docs / Wiki additions:**

- u. No NuGet publication, no `release.yml`, no OIDC federated credential. The repo *is* the deliverable.
- v. If the repo ships content (Prompts, Standards content files), a content-shape canary per the Prompts standup spec — frontmatter parses, parameters parity, no `classification: Restricted` content.

**AI Seed additions:**

- w. Phase A only. No repo, no CI, no managed identity, no scaffold packet. The Node is cataloged with `signal: "seed"` and `done: false` and waits for its per-Node scaffold packet (which lands as the regular Phase B + Phase C against the just-promoted Core .NET class).

**Studios / TypeScript additions:**

- x. No `.slnx`, no `Directory.Build.props`, no `HoneyDrunk.Standards`. Replace with `package.json`, `tsconfig.json`, ESLint/Prettier configuration matching the existing Studios repo's stack.
- y. Node.js CI workflow at `.github/workflows/pr.yml` calling a (future) `HoneyDrunk.Actions`'s `pr-typescript.yml` reusable workflow if one exists, or directly invoking `npm ci && npm run build && npm test` until that workflow is built (per ADR-0012 D4's "invoke CLIs directly" stance — wrapper marketplace actions for npm/Node are rejected for the same reasons gitleaks-action@v2 was).
- z. Web.UI design-token consumption per ADR-0071 when the package is React-stack.

### D6 — Invariant: Node registration is mandatory before the first non-bootstrap PR

A new invariant lands with this ADR:

> **Every Node repo must have, before its first non-bootstrap PR merges:**
> 1. an entry in `catalogs/nodes.json` (Node row),
> 2. a corresponding edges section in `catalogs/relationships.json`,
> 3. an entry in `catalogs/grid-health.json`,
> 4. a context folder at `repos/{NodeName}/` with all five files (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`),
> 5. a sector row in `constitution/sectors.md`,
> 6. a `repo-to-node.yml` mapping in `HoneyDrunk.Actions/.github/config/`,
> 7. a `.honeydrunk-review.yaml` at the repo root with `enabled: true` or `enabled: false` explicitly declared,
> 8. a `pr.yml` workflow calling `HoneyDrunk.Actions`'s `pr-core.yml`,
> 9. branch protection on `main` requiring the `pr-core / core` status check, **and**
> 10. **org-secret repo binding** — the org admin has bound the new repo to every org Actions secret the repo's workflows reference. Minimum set for any Node consuming `pr-core.yml` is `SONAR_TOKEN` (ADR-0011 D11). Per-class conditional additions (`NUGET_API_KEY`, `LABELS_FANOUT_PAT`, `HIVE_FIELD_MIRROR_TOKEN`, `HIVE_APP_ID`, `HIVE_APP_PRIVATE_KEY`, the ADR-0084 Discord webhook stack, `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`) follow the matrix in `constitution/node-standup.md`. GitHub does not auto-propagate org secrets with `Selected repositories` access policy, so without this step the new repo's first non-bootstrap PR consuming any of those secrets hard-fails — silently in the case of empty-string substitution, loudly for explicit-required wiring. See D8 for the full enumeration and policy.
>
> A "bootstrap PR" is the scaffold PR itself (the first PR after repo creation, landing the scaffold packet — exemplar `03-{node}-node-scaffold.md`). A bootstrap PR is permitted to introduce items 7, 8, 9, and 10 in the same commit as the rest of the scaffold; the invariant binds the *second* PR (the first feature PR). Items 1–6 must exist before the scaffold PR (they are Phase A; the scaffold is Phase C; Phase A merges first per D3's prerequisite gate).
>
> Enforcement: human review at PR time, supplemented by the `review` agent per ADR-0044 D3 category 10 (Enterprise readiness / supportability). The `node-audit` agent per ADR-0043's Tactical source surfaces missing items on a per-Node audit pass. No CI gate at this time (the catalogs and the new repo are in different repositories — a cross-repo CI gate would require a new mechanism this ADR does not commit to).

The exact wording of the invariant is committed by this D6; the invariant number is assigned by the scope agent when this ADR flips Accepted (current next available is **54** as of 2026-05-25, but the scope agent re-checks the next-available slot at acceptance time).

This invariant is **enforceable at the procedural level**, not at the build level — there is no current mechanism for one Grid repo to fail another's CI based on missing catalog entries. Enforcement therefore lives in:

1. The human-or-agent author's adherence to the standup procedure (D1).
2. The `review` agent's per-PR check against the standup ADR's `If Accepted — Required Follow-Up Work` checklist (the same checklist shape used by every existing standup ADR).
3. The `node-audit` agent's periodic audit pass (per ADR-0043's Tactical source) surfacing drift between catalogs and repo state.
4. The `hive-sync` agent's reconciliation pass (per ADR-0014 Invariant 38) catching board-vs-catalog drift.

A future CI gate — e.g. a "catalog-coherence" reusable workflow in HoneyDrunk.Actions that periodically diffs the Grid's repo list against `catalogs/nodes.json` and `repo-to-node.yml` — is an unblocked follow-up but is not committed by this ADR.

### D7 — Follow-up work this ADR unlocks

Accepting this ADR commits the procedure but not the per-class walkthroughs. The walkthroughs land as follow-up packets after acceptance, in `infrastructure/walkthroughs/`:

- **`infrastructure/walkthroughs/node-standup-core-dotnet.md`** — step-by-step for Core .NET Abstractions+Runtime and Runtime-only classes. Includes the throwaway-breaking-change PR sequence for confirming the contract-shape canary post-merge.
- **`infrastructure/walkthroughs/node-standup-ops-deployable-dotnet.md`** — adds Key Vault, App Configuration, managed identity, Container Apps, Bicep modules, deploy trigger model, health endpoints. Cross-references existing per-resource walkthroughs (`key-vault-creation.md`, `app-configuration-provisioning.md`, `container-app-creation.md`, `oidc-federated-credentials.md`).
- **`infrastructure/walkthroughs/node-standup-meta-docs.md`** — for Architecture, Lore, Standards, Prompts, and future docs/wiki repos.
- **`infrastructure/walkthroughs/node-standup-ai-seed.md`** — the smallest walkthrough: catalog rows + context folder + sector row + nothing else. Names the promotion gate from seed to Core .NET Abstractions+Runtime.
- **`infrastructure/walkthroughs/node-standup-studios-typescript.md`** — for TypeScript repos (Studios, future SDKs, future per-stack Web.UI packages).

The canonical procedure document `constitution/node-standup.md` per D1 lands first; the five walkthroughs land as five separate packets after, parallelizable. Acceptance does not block on the walkthroughs being written — the procedure is canonical the moment `constitution/node-standup.md` lands; the walkthroughs are operational runbooks that *compose* against the procedure.

A sixth walkthrough — **`infrastructure/walkthroughs/sonarcloud-org-onboarding.md`** — is also unlocked by this ADR but is the deliverable of the ADR-0011 acceptance pass (which surfaced this gap in the first place). Naming it here so the cross-reference is on record.

A seventh walkthrough — **`infrastructure/walkthroughs/org-secret-repo-binding.md`** — is the per-secret walkthrough mandated by D8 below. It names the Settings → Secrets → Actions → {Secret name} → Repository access → Selected repositories → Add repositories flow for every org Actions secret in the per-class matrix. Lands as its own follow-up packet after this ADR is Accepted.

### D8 — Org-secret access propagation is not automatic

GitHub organization Actions secrets carry a **Repository access** policy that controls which repos in the org may consume the secret. The three menu options at `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions/{SECRET_NAME}` are:

1. **All repositories** — every repo in the org, public and private.
2. **Private repositories** — every private/internal repo; public repos cannot consume the secret.
3. **Selected repositories** — only the explicitly enumerated repo list. This is the only policy that supports least-privilege scoping; adding a new repo to the access list is a **manual org-admin action** and does **not** happen automatically when a new repo is created.

(GitHub also exposes per-environment secrets at the repo level with their own access controls; those are out of scope for this D8 — this decision binds only the org-level Actions-secrets surface.)

**HoneyDrunkStudios standing policy:** `Selected repositories` is the default for org secrets containing live credentials, tokens, webhooks, or signing material — i.e. every org secret currently in use. `All repositories` is reserved for benign org constants (none currently exist; the Grid has chosen `Directory.Build.props` over org secrets for shared non-credential values, so this reservation is effectively dormant). Promoting an existing secret from `Selected repositories` to `All repositories` requires an ADR amendment.

**Org secrets requiring binding for a new Node consuming `pr-core.yml`** (as of 2026-05-25):

- **Always required** (every Node consuming `pr-core.yml` and gated by ADR-0011 D11):
  - `SONAR_TOKEN` — SonarCloud analysis token; `job-sonarcloud.yml` hard-fails without it.
- **Conditional on NuGet publishing** (any Node shipping packages per ADR-0034):
  - `NUGET_API_KEY` — nuget.org publishing key consumed by `release.yml`.
- **Conditional on issue / label / project automation** (per ADR-0014 hive-sync stack — applies to repos participating in cross-repo label fan-out and field mirroring):
  - `LABELS_FANOUT_PAT`
  - `HIVE_FIELD_MIRROR_TOKEN`
  - `HIVE_APP_ID`
  - `HIVE_APP_PRIVATE_KEY`
- **Conditional on operator-alert emission** (per [ADR-0084](./ADR-0084-discord-operator-alerts-surface.md) — applies to any Node whose workflows emit operator-actionable events):
  - `DISCORD_WEBHOOK_OPS_ALERTS`
  - `DISCORD_WEBHOOK_SECURITY`
  - `DISCORD_WEBHOOK_AGENT_ACTIVITY`
  - `DISCORD_WEBHOOK_HIVE_ACTIVITY`
  - `DISCORD_WEBHOOK_RELEASE`
  - `DISCORD_WEBHOOK_ANNOUNCEMENTS`
  - `DISCORD_WEBHOOK_AUDIT_SENSITIVE`
- **Conditional on ADR-0044 review-pipeline emission** (any Node whose `.honeydrunk-review.yaml` has `enabled: true` and which posts review results upstream):
  - `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`

This enumeration is a **moving target** — every new org secret added to the org expands the matrix. The canonical authoritative copy of the per-class binding matrix lives in `constitution/node-standup.md` (per D1); this ADR commits the *requirement* that the binding step exists and the *policy* that `Selected repositories` is the default access mode, not the snapshot of the list itself. The list above is the snapshot as of this ADR's draft date; future inventory passes (cross-cutting ADR-0083 D5/D6) update `constitution/node-standup.md` without an amendment to this ADR.

**Note on additional candidates.** Other org secrets may exist in the org (CI-only credentials, build-time tokens, etc.) that are not yet in the per-class matrix because no current Node consumes them or because their access policy is already `All repositories`. ADR-0083's inventory pass is the authoritative discovery mechanism; this ADR defers the per-secret class-membership decisions to that inventory plus the `constitution/node-standup.md` matrix.

**Enforcement.** The binding step is enforced procedurally per the Phase B insertion in D3 and the D6 invariant clause 10. There is no current CI mechanism to fail a PR on missing org-secret bindings before the workflow runs that needs them — by construction, GitHub surfaces the failure at workflow-execution time, not at PR-open time. The `review` agent's per-PR check includes a "first-PR-after-scaffold" rubric category that flags missing bindings when surfaced; the `node-audit` agent's periodic pass catches drift across all Nodes. A future CI gate that inspects org-secret repo-binding state via the GitHub API is an unblocked follow-up.

## Consequences

### Positive

- **One source for the procedure.** Every standup ADR, packet, and AI agent references `constitution/node-standup.md` instead of re-deriving from precedent.
- **Drift channels closed.** The `repo-to-node.yml` mapping, the `.honeydrunk-review.yaml` gate, the contract-shape canary, the sector row, and the standup-time catalog rows are all named as mandatory rather than discovered per-Node.
- **AI-authored standup packets get a procedure to reference.** ADR-0044 D3 rubric category 10 (Enterprise readiness / supportability) gains a concrete checklist to evaluate against; ADR-0044 D6 authorship discipline (AI-authored standup PRs are common — every AI-sector Node was a scaffold-class agent PR) gets a procedure-adherence dimension.
- **Node-class taxonomy is committed.** No more "what kind of Node is this and which precedent applies" first-principles derivation on every standup.
- **Procedure evolution is lightweight.** Updates to `constitution/node-standup.md` are PR-reviewed against this ADR; they don't require an ADR amendment unless they change the D2 taxonomy or the D6 invariant wording.
- **The Ops/Core/Meta/AI/Studios split becomes mechanically visible.** Sector membership (`constitution/sectors.md`) and Node class (`catalogs/nodes.json` `node_class` field per D2) now jointly describe what procedure applies.

### Negative

- **A new constitutional document to maintain.** `constitution/node-standup.md` joins `invariants.md`, `sectors.md`, `terminology.md`, and `ai-sector-architecture.md` as a living artifact. Maintenance cost is real but low — standup-procedure edits are infrequent.
- **The Node-class taxonomy will need amendments as the Grid grows.** Mobile apps, Tauri desktop clients, Bicep-only infrastructure repos, and Honeyclaw/OpenClaw configuration repos are all classes not yet in the taxonomy. The D2 commitment to "one-row amendment plus a per-class walkthrough" rather than a new ADR per class keeps the cost bounded.
- **The new invariant (D6) is procedural, not CI-enforced.** Accepted as the deliberate scope cut — a cross-repo CI gate is a follow-up, not a prerequisite. The four enforcement layers in D6 (author adherence, review agent, node-audit agent, hive-sync) cover the case in practice, and the `review_risk_class` field per Invariant 53 plus the `node-audit` agent's periodic pass catch slow drift.
- **Existing standup ADRs (ADR-0019, ADR-0027, ADR-0031, ADR-0059, ADR-0060, ADR-0061, ADR-0071) are not retroactively edited.** Their `If Accepted — Required Follow-Up Work` checklists remain authoritative for their respective standups. Future standup ADRs replace per-ADR re-derivation with a reference to this ADR and `constitution/node-standup.md`. Retrofitting old ADRs is explicitly out of scope.
- **The procedure formalizes some rules that were memory-pinned rather than ADR-pinned.** "Repos are public by default" was a memory; this ADR D4 step 5 elevates it to a procedural rule with the carve-out language matching the ADR-0027 D2 precedent. No new policy is being introduced — only the level at which existing policy lives.

### Affected Nodes

`HoneyDrunk.Architecture` (the only repo this ADR's follow-up packets touch directly — they land `constitution/node-standup.md`, the five per-class walkthroughs in `infrastructure/walkthroughs/`, and the D6 invariant in `constitution/invariants.md`). Every future Node standup references the resulting documents.

No relationships-graph edges change. No catalog entries land as part of this ADR (the procedure governs how future catalog entries land; this ADR adds zero of its own).

### Cascade Impact

- **`constitution/node-standup.md`** lands as new file via packet 01.
- **`constitution/invariants.md`** gains the D6 invariant (number assigned at acceptance) via packet 01.
- **`infrastructure/walkthroughs/`** gains six new files via packets 02–07 (parallelizable): five per-class node-standup walkthroughs plus `org-secret-repo-binding.md` per D8.
- **`adrs/README.md`** gains the ADR-0082 row when this ADR flips Accepted (per the standing convention — scope agent or hive-sync owns).
- **`initiatives/active-initiatives.md`** and **`initiatives/roadmap.md`** gain an entry for this initiative (hive-sync reconciles).
- **No code changes in any Node repo.** This ADR is process architecture for the Grid's standup machinery.

### Tier

This is a **Tier 3** (per `routing/request-types.md`) decision — process-architecture, cross-cutting, no direct code. The follow-up walkthrough packets are Tier 2 (documentation against a settled procedure).

## Alternatives Considered

### Embed the procedure in `constitution/invariants.md` directly

Rejected. Invariants are atomic rules ("X must never happen" / "Y must always hold"). The standup procedure is a multi-page checklist with per-class variance — embedding it as an invariant body would either bloat invariants.md or compress the procedure into a form that loses the operational detail every standup needs.

### Put the procedure in `routing/` next to `execution-rules.md` and `request-types.md`

Rejected per D1. Routing governs how a work item flows to its target repo. Standup creates the target repo. Co-locating would conflate the two.

### Make the procedure an ADR section (this ADR's Decision body), no separate document

Rejected. ADRs are decisions, not living checklists. A standup-procedure update — say, "add `coverage-baseline.json` to the mandatory list" — should not require an ADR amendment. The decision (this ADR) commits *that* the procedure exists and *where* it lives; the procedure (`constitution/node-standup.md`) commits *what* the procedure is and evolves under lighter-weight discipline.

### One walkthrough per class instead of one canonical document plus five walkthroughs

Rejected. Without the canonical document, each walkthrough re-derives the shared rules ("Invariant 17 means one Key Vault per env per service," "Invariant 31 means `pr-core / core` is a required check," "ADR-0044 D4 means `.honeydrunk-review.yaml` is mandatory"). The canonical document holds the rules once; the walkthroughs hold the per-class operational sequence.

### Defer the Node-class taxonomy (D2) until the next non-.NET Node lands

Rejected. The taxonomy is already implicit in the Grid — Studios is TypeScript, the AI-sector Nodes were Seed before scaffold, Notify is multi-deployable. Naming the classes now (six rows, closed for 2026-05-25) is cheap; deferring would mean the next non-.NET standup (per ADR-0070 D3's React Native + Expo mobile commitment, per ADR-0057's SDK packages, per ADR-0075's Docusaurus doc sites if they get their own repos) re-litigates the class boundary at standup time.

### Commit a CI-enforced cross-repo gate for the D6 invariant

Rejected for this ADR. A "catalog-coherence" reusable workflow that periodically diffs the Grid's repo list against `catalogs/nodes.json` and `repo-to-node.yml` is an attractive follow-up but introduces a new mechanism (cross-repo CI failure, periodic schedule, who-owns-the-gate) that this ADR does not need to commit to in order to land the procedure itself. The four enforcement layers in D6 are sufficient for the procedure-adherence goal at solo-developer + AI-agent scale. The CI gate is an unblocked future ADR if drift surfaces despite the procedural enforcement.

### Retrofit ADR-0019 / ADR-0027 / ADR-0031 / ADR-0059 / ADR-0060 / ADR-0061 / ADR-0071 with references to this ADR

Rejected. Existing standup ADRs' `If Accepted — Required Follow-Up Work` checklists are immutable per the ADR-discipline pattern (Accepted ADRs aren't edited substantively). Retrofitting would risk breaking the historical record of what those standups committed to at their time. Future standup ADRs reference this ADR as the procedure source; old ADRs stand as-is.

### Wait until ADR-0011 acceptance lands before drafting this ADR

Rejected. The gap was identified during ADR-0011 acceptance work; postponing the gap-closing ADR until ADR-0011 fully lands would mean every standup between now and then continues re-deriving the procedure. This ADR is drafted on a separate branch (`adr-node-standup-procedure`, off `main`) precisely so it doesn't piggyback on the in-flight ADR-0011 acceptance branch.
