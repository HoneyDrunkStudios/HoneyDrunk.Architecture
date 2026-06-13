---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0053", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0053", "ADR-0033"]
accepts: ["ADR-0053"]
wave: 1
initiative: adr-0053-release-cadence
node: honeydrunk-architecture
---

# Extend `catalogs/services.json` with `environments` and codify branching/cadence conventions

## Summary
Record ADR-0053's environment topology and branching/cadence rules as catalog data and Grid conventions: extend the `catalogs/services.json` entry shape with a per-service `environments: [dev, staging, prod]` field (per ADR-0053's Consequences "Affected Nodes" line); document the branching model (D4), branch-naming convention (D5), branch-lifetime expectations (D6), merge strategy (D7), and release cadence (D9) under `infrastructure/conventions/`; and reference the branch-naming rule from `routing/execution-rules.md` (the canonical target named by ADR-0053; the file exists).

## Context
ADR-0053's "Affected Nodes" line for `HoneyDrunk.Architecture` reads: "`constitution/sectors.md` references the three environments; `catalogs/services.json` gains an `environments: [dev, staging, prod]` field per service; `routing/execution-rules.md` references the branch-naming convention per D5."

The current `catalogs/services.json` shape (per the file at edit time) carries `id`, `nodeId`, `name`, `type`, `description`, `runtime`, `hosting`, `status`. It has **no** environments field; the four currently-cataloged services (`pulse-collector`, `notify-worker`, `notify-functions`, `studios-website`) deploy to whatever environment their consumer release workflow targets without a catalog-level commitment. ADR-0053 D1 names three environments per service; the catalog should reflect that so the grid-health aggregator (ADR-0012) and the monthly cadence enforcement workflow (packet 07) have a structured data source.

**Branching/cadence conventions need a documentation home.** `infrastructure/conventions/` already carries `azure-identity-and-secrets.md`, `azure-naming-conventions.md`, and `tag-and-release-conventions.md`. The branching/cadence rules (D4–D7, D9) belong there — they are cross-cutting Grid conventions, not per-Node concerns. `routing/execution-rules.md` (the canonical execution-rules document ADR-0053 names; the file exists at edit time) gets a short cross-reference + the branch-prefix table so agents reading the routing rules see the convention without an extra hop.

This is a catalog/docs packet. No code, no .NET project.

## Scope
- `catalogs/services.json` — add an `environments: ["dev", "staging", "prod"]` field to every entry (four entries today; default the value uniformly until per-service overrides become real).
- `infrastructure/conventions/branching-and-release-cadence.md` (new) — document D4 (trunk-based), D5 (branch-naming table for both human and AI prefixes), D6 (5-day / 7-day / 30-day lifetime rule), D7 (squash-default merge strategy), D9 (per-Node release-as-needed cadence with the monthly floor).
- `infrastructure/README.md` — add the new conventions doc to the conventions index.
- `routing/execution-rules.md` — append a short "Branch naming" section per D5 with the table, cross-linking the new `infrastructure/conventions/branching-and-release-cadence.md` for full detail. (This is the canonical target named by ADR-0053; the file exists at edit time.)
- `constitution/sectors.md` — add a brief "Environments" line referencing the three environments per ADR-0053 D1.

## Proposed Implementation
1. **`catalogs/services.json`** — for every entry, add `"environments": ["dev", "staging", "prod"]`. The shape becomes:
   ```json
   {
     "id": "pulse-collector",
     "nodeId": "honeydrunk-pulse",
     "name": "Pulse.Collector",
     "type": "service",
     "description": "Deployable OTLP receiver…",
     "runtime": "net10.0",
     "hosting": "container",
     "status": "active",
     "environments": ["dev", "staging", "prod"]
   }
   ```
   The four current services (`pulse-collector`, `notify-worker`, `notify-functions`, `studios-website`) all get the same default. If a service legitimately deploys to only a subset (e.g. `studios-website` deploys directly to Vercel and does not have a `dev`/`staging` Azure environment in the same sense), call that out in the PR body and either record the subset (`["prod"]`) or leave the default and document the divergence in the service's description field. Default is the uniform set; deviations are explicit.
2. **`infrastructure/conventions/branching-and-release-cadence.md`** (new) — author the convention doc covering:
   - **Trunk-based branching (D4).** `main` is always deployable; every merge to `main` produces an artefact auto-deploying to `dev`. No `develop`, no permanent `release/*` or `hotfix/*` channels. `release/{node}-{semver}` permitted only for emergency hotfix isolation when `main` is mid-feature; created off the prod tag, fix merges in, tag cut, branch deleted within 7 days.
   - **Branch-naming convention (D5).** A table with the prefix → purpose → example for human prefixes (`feat/`, `fix/`, `chore/`, `docs/`, `refactor/`) and AI prefixes (`codex/`, `copilot/`, `claude/{agent-slug}-{token}`). Why branch-prefix discipline matters: ADR-0032 (PR validation) and ADR-0044 (AI-PR discipline) inspect the prefix to route the appropriate review checklist; the operator's mental model ("Codex's work or mine?") is preserved at a glance.
   - **Branch lifetime (D6).** 5-day target / 7-day stale alert (a comment on the PR) / 30-day auto-close unless `flagged-keep-open`. Forcing function: AI-authored PRs bottleneck on the single human reviewer; the lifetime budget pressures the queue toward small, focused PRs.
   - **Merge strategy (D7).** Squash by default (one PR = one commit on `main`; PR title becomes the conventional-commit message per ADR-0044 D4). Merge commits permitted only for `release/{node}-{semver}` branches (preserves hotfix audit trail). Never rebase-merge (SHA rewriting breaks external references).
   - **Release cadence (D9).** Per-Node, release-as-needed. Soft target: monthly per Live Node — either ship one prod release in the past 30 days or emit a `## [no changes this month]` CHANGELOG entry; missed months become Grid-health alerts (packet 07 enforces this). Hotfix tag format `prod-{date}-hotfix-{short-slug}`; even hotfixes get a staging step (4-hour soak per D8).
3. **`infrastructure/README.md`** — add a row for the new conventions doc in the existing conventions index.
4. **`routing/execution-rules.md`** — append a "## Branch naming" section (or merge into an existing section if one exists) with the prefix table from D5 and a cross-link to `infrastructure/conventions/branching-and-release-cadence.md` for full detail. `routing/execution-rules.md` is the canonical target named by ADR-0053; the file exists at edit time.
5. **`constitution/sectors.md`** — append a short "Environments" line: "The Grid runs three always-on environments — `dev`, `staging`, `prod` — per ADR-0053." Do not invent a topology section if `constitution/sectors.md` is structured for sectors-only content; place the line in the most appropriate existing section or, if no fit exists, add a new "Operating Topology" subsection at the file's tail.

## Affected Files
- `catalogs/services.json`
- `infrastructure/conventions/branching-and-release-cadence.md` (new)
- `infrastructure/README.md`
- `routing/execution-rules.md`
- `constitution/sectors.md`

## NuGet Dependencies
None. This packet touches only JSON and Markdown; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Catalog/docs only — the Bicep, the Actions workflows, the Quick Start template all land in later packets.

## Acceptance Criteria
- [ ] `catalogs/services.json` carries an `environments` field on every entry; the default value is `["dev", "staging", "prod"]`; any per-service deviation is recorded in the PR body and reflected in the field value
- [ ] `infrastructure/conventions/branching-and-release-cadence.md` exists covering D4 (trunk-based), D5 (full branch-naming table), D6 (5/7/30-day lifetime rule), D7 (squash-default merge), D9 (per-Node release-as-needed with monthly floor)
- [ ] `infrastructure/README.md` lists the new conventions doc in its conventions index
- [ ] `routing/execution-rules.md` carries a "## Branch naming" section with the D5 prefix table and a cross-link to the conventions doc
- [ ] `constitution/sectors.md` references the three environments
- [ ] No new top-level Node-to-Node edge created (`relationships.json` is not modified)
- [ ] No `.csproj` version bump — JSON/Markdown-only

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0053 D1 — Three environments (`dev`, `staging`, `prod`).** The Grid commits to three always-on environments; per-service catalog records this commitment.

**ADR-0053 D4 — Trunk-based branching.** `main` is always deployable; every merge auto-deploys to `dev`; no `develop` channel; `release/{node}-{semver}` permitted only for emergency hotfix isolation when `main` is mid-feature.

**ADR-0053 D5 — Branch-naming convention.** Human prefixes: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`. AI prefixes: `codex/`, `copilot/`, `claude/{agent-slug}-{token}`. Branch-name discipline routes the PR-validation policy (ADR-0032) and the AI-PR discipline (ADR-0044) checklists.

**ADR-0053 D6 — Branch lifetime: 5-day target / 7-day stale / 30-day auto-close.** Stale-alert workflow comments at 7 days (no auto-close yet); auto-close workflow closes at 30 days unless `flagged-keep-open`.

**ADR-0053 D7 — Merge strategy.** Squash by default; merge commits for `release/{node}-{semver}` only; never rebase-merge.

**ADR-0053 D9 — Release cadence.** Per-Node release-as-needed; monthly floor enforced by "at least one prod release in past 30 days OR an explicit 'no changes this month' CHANGELOG entry." Hotfix tag format `prod-{date}-hotfix-{short-slug}`; even hotfixes get a staging step.

**ADR-0053 Consequences — Affected Nodes (Architecture).** `constitution/sectors.md` references the three environments; `catalogs/services.json` gains the `environments` field per service; `routing/execution-rules.md` references the branch-naming convention.

## Constraints
> **Invariant 4 — No circular dependencies.** Adding the `environments` field to `services.json` does not introduce a new Node-to-Node edge; `relationships.json` is untouched.

> **Invariant 11 — One repo per Node.** The conventions doc is a Grid-wide convention living in `HoneyDrunk.Architecture` (the Grid's governance home), not a per-Node doc.

- **Default uniform.** Every service entry gets `["dev", "staging", "prod"]` unless a per-service deviation is documented. Studios is the likely deviation (Vercel-hosted, not Azure-environment-bound) — record the chosen value and the rationale in the PR body.
- **Routing target is `routing/execution-rules.md`.** The file exists at edit time; append the "## Branch naming" section there as ADR-0053 specifies. Do not write to `routing/sdlc.md` as a fallback.
- **No invariant change in this packet.** The three new invariants (numbers claimed via `constitution/invariant-reservations.md`) land in packet 00.

## Labels
`feature`, `tier-2`, `meta`, `docs`, `adr-0053`, `wave-1`

## Agent Handoff

**Objective:** Record ADR-0053's environment topology in `catalogs/services.json` and codify the branching/cadence conventions in `infrastructure/conventions/` and `routing/execution-rules.md`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Keep the services catalog and the Grid's conventions accurate so packets 02–08 (and downstream consumers) read a correct topology and a documented branching rule.
- Feature: ADR-0053 Environments, Branching, and Release Cadence rollout, Wave 1.
- ADRs: ADR-0053 D1/D4/D5/D6/D7/D9 (primary), ADR-0033 (tag → environment mapping that the cadence floor leans on).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0053 should be Accepted before its topology and conventions are recorded as live data.

**Constraints:**
- Default uniform `["dev", "staging", "prod"]` per service; per-service deviation recorded in the PR body and reflected in the field value.
- Branch-prefix cross-reference goes into `routing/execution-rules.md` (it exists at edit time); do not fall back to `routing/sdlc.md`.
- No `relationships.json` edit — no new Node-to-Node edge is introduced.

**Key Files:**
- `catalogs/services.json` — new `environments` field per entry.
- `infrastructure/conventions/branching-and-release-cadence.md` — new doc.
- `infrastructure/README.md` — conventions-index update.
- `routing/execution-rules.md` — branch-prefix cross-reference.
- `constitution/sectors.md` — three-environment line.

**Contracts:** None changed.
