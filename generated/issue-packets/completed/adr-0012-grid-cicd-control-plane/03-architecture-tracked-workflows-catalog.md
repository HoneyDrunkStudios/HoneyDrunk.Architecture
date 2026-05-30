---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "catalog", "adr-0012", "wave-1"]
dependencies: []
adrs: ["ADR-0012", "ADR-0008"]
wave: 1
initiative: adr-0012-grid-cicd-control-plane
node: honeydrunk-architecture
---

# Feature: Add `tracked_workflows` to repo catalog for grid-health aggregator consumption

## Summary
Extend `catalogs/grid-health.json` with a `tracked_workflows` array on every repo entry, listing the workflow filenames the grid-health aggregator (D6) should poll for run state. The aggregator (packet 04) reads this catalog at runtime; without it, every repo defaults to the same canonical list (`nightly-security.yml`, `nightly-deps.yml`) and repo-specific scheduled workflows (Notify accessibility, Pulse weekly governance, etc.) are invisible. Per ADR-0012 invariant 41 (post-acceptance numbering, see packet 01), new Grid repos are added to the catalog at creation time including their `tracked_workflows`.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0012 D6 specifies the aggregator polls "tracked workflows ... `nightly-security.yml`, `nightly-deps.yml`, `publish.yml`, and any repo-specific scheduled workflow the repo's catalog entry declares under a new `tracked_workflows` key." The ADR text refers to a per-repo JSON file under `HoneyDrunk.Architecture/repos/*.json`, but the actual repo catalog in this repo lives at `catalogs/grid-health.json` (per the 2026-04-12 catalog additions) and the per-repo folders under `repos/{Name}/` hold markdown context docs (`overview.md`, `boundaries.md`, etc.), not JSON. The ADR text was written against an earlier draft of the layout; this packet lands the `tracked_workflows` data in `catalogs/grid-health.json` where the JSON-shaped catalog already lives, which is where the aggregator (packet 04) will read it from.

This packet is the load-bearing prerequisite for the aggregator. Packet 04 is hard-blocked by this one — without `tracked_workflows`, the aggregator has no list to iterate over.

## Scope

A bulk edit to one file in the Architecture repo. No code. No secrets.

### `catalogs/grid-health.json`

Add a `tracked_workflows` array on every repo entry under the `nodes` array. The array contents are determined per-repo based on the workflows that actually exist in `.github/workflows/` of each repo, restricted to **scheduled** workflows (workflows whose `on:` trigger includes `schedule:` — `pull_request` and `push` triggers are excluded; `pr-core.yml` is explicitly excluded per ADR-0012 D6 because its state is per-PR, not time-scheduled).

The per-repo `tracked_workflows` content was verified at scope-time (2026-04-26) by listing `.github/workflows/` for every repo in the local CoreWorkspace and intersecting with the ADR's canonical list (`nightly-security.yml`, `nightly-deps.yml`, `publish.yml`, plus repo-specific scheduled workflows like `weekly-deps.yml`, `weekly-governance.yml`, `nightly-accessibility.yml`).

**Two findings from that verification — both load-bearing for this table:**

1. **9 of 10 Live repos use `weekly-deps.yml`, not `nightly-deps.yml`.** The dependency-scan cron landed grid-wide as a Monday-only weekly job (cron `0 3 * * 1`). Only `HoneyDrunk.Data` carries both `weekly-deps.yml` and `nightly-deps.yml` (transitional). The previous draft of this table used `nightly-deps.yml` for every Live repo; that was wrong.
2. **`publish.yml` is canonical per ADR-0012 D6 and exists in every Live repo's `.github/workflows/`.** The previous draft of this table omitted `publish.yml` from every row; it must be present everywhere it actually exists.

The verified table (filenames as they exist in each repo's `.github/workflows/` at scope-time):

| Repo entry id | `tracked_workflows` |
|---|---|
| `honeydrunk-kernel` | `["nightly-security.yml", "publish.yml", "weekly-deps.yml"]` |
| `honeydrunk-transport` | `["nightly-security.yml", "publish.yml", "weekly-deps.yml"]` |
| `honeydrunk-vault` | `["nightly-security.yml", "publish.yml", "weekly-deps.yml"]` |
| `honeydrunk-vault-rotation` | `["publish.yml"]` (currently has only `deploy.yml`, `publish.yml`, `validate-pr.yml`; no nightly-security yet — verify at execution time) |
| `honeydrunk-auth` | `["nightly-security.yml", "publish.yml", "weekly-deps.yml"]` |
| `honeydrunk-web-rest` | `["nightly-security.yml", "publish.yml", "weekly-deps.yml"]` |
| `honeydrunk-data` | `["nightly-deps.yml", "nightly-security.yml", "publish.yml", "weekly-deps.yml"]` (transitional — both `nightly-deps.yml` and `weekly-deps.yml` are present in this repo today; verify whether the transition has completed before this packet ships) |
| `pulse` | `["nightly-security.yml", "publish.yml", "weekly-deps.yml"]` |
| `honeydrunk-notify` | `["nightly-security.yml", "publish.yml", "weekly-deps.yml"]` |
| `honeydrunk-communications` | `[]` (Seed — repo not yet scaffolded; empty array signals "Missing" in aggregator until scaffolded) |
| `honeydrunk-actions` | `["nightly-accessibility.yml", "nightly-deps.yml", "nightly-security.yml", "weekly-governance.yml"]` (Actions hosts the workflows; `nightly-deps.yml` lives here as the canonical scheduled job; `publish.yml` does not exist in Actions because Actions does not produce a NuGet artifact) |
| `honeydrunk-architecture` | `[]` (only `file-packets.yml` and `initiatives-sync.yml` exist; neither is on a `schedule:` trigger today — both are `workflow_dispatch`/`workflow_run`) |
| `honeydrunk-studios` | `[]` (`.github/workflows/` is empty at scope-time — no scaffolded workflows) |
| `honeydrunk-lore` | `[]` (Seed — repo not yet scaffolded) |
| `honeydrunk-agents` | `[]` (Seed) |
| `honeydrunk-ai` | `[]` (Seed) |
| `honeydrunk-memory` | `[]` (Seed) |
| `honeydrunk-knowledge` | `[]` (Seed) |
| `honeydrunk-evals` | `[]` (Seed) |
| `honeydrunk-capabilities` | `[]` (Seed) |
| `honeydrunk-flow` | `[]` (Seed) |
| `honeydrunk-operator` | `[]` (Seed) |
| `honeydrunk-sim` | `[]` (Seed) |

**Verification mandate at execution time.** The table above was compiled by intersecting each repo's local `.github/workflows/` listing with the ADR canonical set. Live state may have moved between scope-time (2026-04-26) and execution time. Before committing, the executing agent **must re-verify** each Live-signal repo's workflow set via `gh api repos/HoneyDrunkStudios/{name}/contents/.github/workflows` and update any row whose contents have shifted (e.g. `HoneyDrunk.Data` finishing its `nightly-deps.yml` → `weekly-deps.yml` transition; `HoneyDrunk.Vault.Rotation` adding `nightly-security.yml`). Seed-signal repos with no scaffold get `[]` regardless. The aggregator (packet 04) treats `[]` as "no workflows declared, repo is in pre-scaffold state" — it does not error.

**Sort order convention.** Within each `tracked_workflows` array, entries are alphabetically sorted by filename. This is for readability and diff stability; the aggregator (packet 04) is order-independent.

**The `pr-core.yml` workflow is excluded from every entry** per ADR-0012 D6: its state is per-PR not time-scheduled and belongs on the PR surface (per ADR-0011 D1). Note that the live per-repo callers are typically named `pr.yml` (not `pr-core.yml`) — they `uses:` the reusable `pr-core.yml` from `HoneyDrunk.Actions`. Neither `pr.yml` nor the called `pr-core.yml` belongs in `tracked_workflows` for the same reason.

**Other workflows seen in the local listing that are excluded from `tracked_workflows`:**
- `hive-field-mirror.yml` — fires on `issues`/`project_card` events, not on `schedule:`. Out of scope for grid-health.
- `deploy.yml` / `deploy-functions.yml` — fire on release or workflow-dispatch, not on `schedule:`. Their state belongs on the deployment surface, not on grid-health.
- `validate-pr.yml` — Vault.Rotation's PR validator; per-PR, same exclusion as `pr.yml`.
- `file-packets.yml`, `initiatives-sync.yml` — Architecture-only orchestration workflows; not scheduled, no canonical health surface need today.

### `_meta.schema_version` bump

The `_meta` block at the top of `grid-health.json` carries `"schema_version": "1.0"`. Bump to `"1.1"` since the schema is additively extended. Update `_meta.updated` to the merge date and append a one-line `_meta.changelog` (or similar; if no changelog field exists today, add one as a string array under `_meta` with one entry: `["1.1: added tracked_workflows per repo for ADR-0012 grid-health aggregator"]`).

### `catalogs/README.md` (if exists; otherwise skip)

If `catalogs/README.md` documents the grid-health.json schema, update it to describe the `tracked_workflows` field. If it does not exist, skip — do not create a new file in this packet.

## Affected Files
- `catalogs/grid-health.json` — `tracked_workflows` array added to every repo entry; `_meta.schema_version` bumped to `1.1`; `_meta.updated` set to merge date; `_meta.changelog` (or equivalent) updated
- `catalogs/README.md` — schema description updated (only if file exists)
- `CHANGELOG.md` (repo root) — one-line entry

## NuGet Dependencies
None. JSON catalog edit only.

## Boundary Check
- [x] Single-repo, single-file edit (plus optional README touch).
- [x] No new contract surface; the `tracked_workflows` array is data, not code.
- [x] No invariants are added by this packet — invariant 41 (catalog-creation requirement) lands in packet 01.

## Acceptance Criteria
- [ ] `catalogs/grid-health.json` parses as valid JSON after the edit (CI's existing JSON validation must pass).
- [ ] Every repo entry under `nodes` has a `tracked_workflows` array. Each Live-signal repo's array contains exactly the **scheduled** workflow filenames present in that repo's `.github/workflows/` directory at execution time, intersected with the ADR canonical set (`nightly-security.yml`, `nightly-deps.yml`, `weekly-deps.yml`, `weekly-governance.yml`, `nightly-accessibility.yml`, `publish.yml`). Seed-signal repos have `[]`.
- [ ] Every Live-signal repo whose `.github/workflows/` contains `publish.yml` lists `publish.yml` in its `tracked_workflows` array (per ADR-0012 D6 canonical set).
- [ ] Live-signal repos that use `weekly-deps.yml` (the Monday-only cron `0 3 * * 1`) list `weekly-deps.yml`, **not** `nightly-deps.yml`. Repos using both during a transition list both.
- [ ] `_meta.schema_version` reads `"1.1"`.
- [ ] `_meta.updated` is the merge date in `YYYY-MM-DD` format.
- [ ] `pr-core.yml` does not appear in any `tracked_workflows` array (per ADR-0012 D6).
- [ ] `pr.yml`, `validate-pr.yml`, `hive-field-mirror.yml`, `deploy*.yml`, `file-packets.yml`, `initiatives-sync.yml` do not appear in any `tracked_workflows` array (none are scheduled).
- [ ] `honeydrunk-actions` entry contents match the actual scheduled workflows in `HoneyDrunk.Actions/.github/workflows/` at execution time. (At scope-time those were `nightly-accessibility.yml`, `nightly-deps.yml`, `nightly-security.yml`, `weekly-governance.yml` — verify before committing.)
- [ ] `honeydrunk-studios` entry reflects the actual `.github/workflows/` contents at execution time. At scope-time (2026-04-26) this directory was empty; if Studios scaffolds a scheduled workflow before this packet ships, list it.
- [ ] Within each `tracked_workflows` array, entries are alphabetically sorted by filename.
- [ ] Repo-level `CHANGELOG.md` updated with a one-line entry referencing ADR-0012 and this packet.

## Human Prerequisites
None. The catalog edit is fully delegable.

## Referenced Invariants

> **Invariant 41 (post-acceptance numbering — see packet 01):** New Grid repos are added to `HoneyDrunk.Architecture/repos/` at creation time. The grid-health aggregator reads the repo catalog to know which repos to poll; a repo missing from the catalog is invisible to grid observability. This invariant re-mandates the existing ADR-0008 / architecture-repo convention from the CI/CD visibility angle. See ADR-0012 D6.

This packet is the data-side of invariant 41 — it ensures every existing repo has a `tracked_workflows` declaration before the aggregator goes live.

## Referenced ADR Decisions

**ADR-0012 D6 (Grid Health aggregator, tracked workflows):** "For each repo, fetches the latest run of each tracked workflow ... Tracked workflows are: `nightly-security.yml`, `nightly-deps.yml`, `publish.yml`, and any repo-specific scheduled workflow the repo's catalog entry declares under a new `tracked_workflows` key. `pr-core.yml` is **excluded** because its state is per-PR, not time-scheduled, and belongs on the PR surface (ADR-0011 D1)."

**ADR-0008 (Work tracking via the repo catalog):** The Architecture repo's `catalogs/` directory is the canonical home for JSON-shaped Grid metadata. `grid-health.json` already lives there and is the natural extension point for `tracked_workflows`. Adding a separate per-repo JSON file (as the ADR-0012 draft text suggested) would fragment the catalog without payoff; this packet consolidates by extending the existing file.

**ADR-0012 D6 (Stale / Missing classification):** A `tracked_workflows` entry that has never run produces a `Missing` classification in the aggregator output. This is intentional and is the catch for "workflow declared but never fired" — exactly the symptom the caller-permissions bug from the triggering incident produced.

## Dependencies
- Soft-blocked by packet 01 (acceptance) for invariant 41 numbering. May draft in parallel; cross-reference finalized post-01.
- **Hard-blocks packet 04** (grid-health aggregator). The aggregator reads `tracked_workflows` directly; without it, the aggregator has no work to do.

## Labels
`feature`, `tier-2`, `meta`, `catalog`, `adr-0012`, `wave-1`

## Agent Handoff

**Objective:** Land `tracked_workflows` data on every repo entry in `grid-health.json` so packet 04's aggregator has a list to poll.
**Target:** HoneyDrunk.Architecture, branch from `main`

**Context:**
- Goal: Provide the catalog data the grid-health aggregator (packet 04) consumes.
- Feature: ADR-0012 Grid CI/CD Control Plane, D6 aggregator support.
- ADRs: ADR-0012 (D6 source), ADR-0008 (catalog convention).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Soft-blocked by packet 01.
- **Hard-blocks packet 04.**

**Constraints:**
- **Verify against live state.** The table in this packet is the scope agent's best estimate. Before committing, the executing agent must verify each Live-signal repo's `.github/workflows/` directory via `gh api` (the agent has `gh` available in cloud execution). Divergences are corrected in the same PR — the verification is a load-bearing step, not optional.
- **Exclude `pr-core.yml`.** Per ADR-0012 D6 and ADR-0011 D1, PR validation is a per-PR concern, not a scheduled-workflow concern. Do not include it.
- **Empty array semantics.** `[]` is the explicit "no scheduled workflows declared" state. The aggregator (packet 04) treats `[]` as a non-error — Seed-signal repos that have not been scaffolded yet legitimately have nothing to track. Do not collapse `[]` to `null` or omit the key.
- **JSON validity.** A trailing comma or invalid escape will break the existing JSON validation in CI. Run `python -c "import json; json.load(open('catalogs/grid-health.json'))"` (or equivalent) locally before pushing.

**Key Files:**
- `catalogs/grid-health.json` — the file being edited.
- `catalogs/README.md` — schema doc, update only if it exists.
- `catalogs/nodes.json` — reference for repo-id-to-name mapping (do not edit).

**Contracts:** No code or schema-API contracts. The schema-version bump is documentary.
