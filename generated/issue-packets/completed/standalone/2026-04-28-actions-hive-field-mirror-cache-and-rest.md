---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-2", "ops", "automation", "ci-cd"]
dependencies: []
adrs: []
wave: 1
initiative: standalone
node: honeydrunk-actions
---

# CI Change: Cache project metadata and migrate label writes to REST in `hive-project-mirror.sh`

## Summary

`hive-project-mirror.sh` is invoked once per `issues:` event — every label add/remove, every issue body edit, every open. On every invocation it re-resolves The Hive's project ID, the full field list, and per-field option lists by calling `gh project view`, `gh project field-list`, and `gh api graphql` queries (script lines 160–271). Project + field IDs never change; option lists change only when a new Initiative slug or Wave value is introduced. This packet (a) caches the stable metadata in a JSON file checked into `HoneyDrunk.Actions` (refreshed on a weekly cron + manual dispatch) and reads from cache on every per-issue invocation, and (b) migrates the label-write paths that have a REST equivalent off GraphQL onto the separate `core` REST pool. Together these reduce per-event GraphQL points by an estimated 50–70% and shift the residual cost off whichever pool the workflow runs against.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Actions` — both files live here.

## Target Workflow

**Files modified:**

- `HoneyDrunk.Actions/scripts/hive-project-mirror.sh`
- `HoneyDrunk.Actions/.github/workflows/hive-field-mirror.yml`

**Files created:**

- `HoneyDrunk.Actions/.github/config/hive-project-metadata.json` (cached project + field IDs + option IDs)
- `HoneyDrunk.Actions/.github/workflows/refresh-hive-project-metadata.yml` (weekly cron + workflow_dispatch to refresh the cache)

**Family:** automation (board-mirror)

## Motivation

A label-mirror invocation on a typical packet performs roughly:

- 1× `gh api repos/.../issues/N` (REST — cheap, draws from the `core` pool, line 112)
- 1× `gh project view N --owner ... --format json` (GraphQL — expensive; ID lookup, line 163)
- 1× `gh project field-list N --owner ... --format json` (GraphQL — even more expensive; pulls every field with options, line 202)
- 1× `addProjectV2ItemById` mutation OR 1× `projectItems` lookup (GraphQL, lines 175 and 187)
- For Initiative options that don't yet exist: 1× field-options query + 1× `updateProjectV2Field` mutation (lines 234, 267)
- N× `updateProjectV2ItemFieldValue` mutations, one per field being mirrored (Wave, Tier, Node, Initiative, ADR, Actor — up to 6 calls, lines 282–296)

Every call charges the workflow's token pool. Steps 2 and 3 are pure metadata waste — the values they return are stable across invocations and across packets.

The Actions#57 hardening introduced `HIVE_PROJECT_METADATA_JSON` as an env-var passed from `file-packets.sh` into `hive-project-mirror.sh` (script lines 160–164 and 199–203 already handle the cached path). That works for *batch* invocations from `file-packets.sh` because the parent script can resolve once and pass to every child invocation. It does **not** work for the per-issue `hive-field-mirror.yml` path — there is no parent caching layer because every issue event is its own workflow run.

This packet generalizes the cache: persist the metadata to a JSON file in `HoneyDrunk.Actions` itself, refresh it on a schedule, read from disk on every per-event invocation. The shape of the JSON matches what `HIVE_PROJECT_METADATA_JSON` already expects, so the script's existing fast-path is reused with zero refactor.

REST migration is a smaller win, included here because the same script is the touch point. Specifically: the issue-fetch path on line 112 already uses REST (`gh api repos/.../issues/N`). Anything else that has a REST equivalent should follow suit — the `addProjectV2ItemById`, `projectItems` lookup, and `updateProjectV2ItemFieldValue` mutations are all ProjectsV2-specific and have **no REST equivalent** (Projects v2 is GraphQL-only; the legacy REST Projects API was sunset in 2022). So the REST opportunity inside `hive-project-mirror.sh` is narrower than the original framing: there is nothing to migrate inside the script. The actual REST migration is for **label writes and label reads** where the workflow currently uses GraphQL — but `hive-project-mirror.sh` does not write labels (it reads them from `ISSUE_JSON` already fetched via REST on line 112). So the "migrate label writes to REST" work in this packet reduces to: **document the constraint** in a top-of-script comment so the next agent doesn't waste effort trying.

In short: this packet's net is **(a) the cache** — the cache is the real win — **(b) a documentation note** explaining why label writes can't move to REST inside this script (Projects v2 is GraphQL-only), and **(c) a refresh workflow** that keeps the cache current.

## Proposed Implementation

### Phase 1 — Cache file shape

Create `HoneyDrunk.Actions/.github/config/hive-project-metadata.json` with this shape (matches `HIVE_PROJECT_METADATA_JSON` env var consumers already in the script):

```json
{
  "_meta": {
    "schema_version": "1.0",
    "last_refreshed_utc": "2026-04-28T00:00:00Z",
    "project_owner": "HoneyDrunkStudios",
    "project_number": 4,
    "refresh_workflow": ".github/workflows/refresh-hive-project-metadata.yml"
  },
  "project": {
    "id": "PVT_kwD..."
  },
  "fields": [
    {
      "id": "PVTSSF_lAD...",
      "name": "Wave",
      "options": [
        { "id": "abc123", "name": "Wave 1" },
        { "id": "def456", "name": "Wave 2" },
        { "id": "ghi789", "name": "Wave 3" },
        { "id": "jkl012", "name": "N/A" }
      ]
    },
    { "id": "...", "name": "Tier", "options": [...] },
    { "id": "...", "name": "Node", "options": [...] },
    { "id": "...", "name": "ADR", "options": [] },
    { "id": "...", "name": "Initiative", "options": [...] },
    { "id": "...", "name": "Actor", "options": [...] }
  ]
}
```

The shape mirrors the existing `gh project view` + `gh project field-list` outputs that the script's `jq` queries already consume. The script's existing branches at lines 160–164 and 199–203 already select between live-fetch and cached paths via `HIVE_PROJECT_METADATA_JSON`. The new cache is fed into that env var by the workflow before the script runs.

### Phase 2 — `hive-field-mirror.yml` reads the cache

In the reusable workflow, after the existing `Checkout HoneyDrunk.Actions repository` step, add a step that loads the cache file into the `HIVE_PROJECT_METADATA_JSON` env var:

```yaml
      - name: Load cached project metadata
        id: load-cache
        env:
          CACHE_PATH: ./honeydrunk-actions/.github/config/hive-project-metadata.json
        run: |
          set -euo pipefail
          if [[ ! -f "$CACHE_PATH" ]]; then
            echo "::warning::Project metadata cache not found at $CACHE_PATH; falling back to live GraphQL lookup."
            echo "use-cache=false" >> "$GITHUB_OUTPUT"
            exit 0
          fi
          # Sanity-check the schema and freshness before promoting to env.
          if ! jq -e '._meta.schema_version == "1.0"' "$CACHE_PATH" >/dev/null; then
            echo "::warning::Cache schema mismatch; falling back to live lookup."
            echo "use-cache=false" >> "$GITHUB_OUTPUT"
            exit 0
          fi
          # Hard cap: if the cache is older than 14 days, refuse it and fall back.
          # Refresh runs weekly; 14 days is one missed cron + one day of grace.
          LAST_REFRESH="$(jq -r '._meta.last_refreshed_utc' "$CACHE_PATH")"
          NOW_EPOCH="$(date -u +%s)"
          REFRESH_EPOCH="$(date -u -d "$LAST_REFRESH" +%s)"
          AGE_DAYS=$(( (NOW_EPOCH - REFRESH_EPOCH) / 86400 ))
          if (( AGE_DAYS > 14 )); then
            echo "::warning::Cache is ${AGE_DAYS} days old (max 14); falling back to live lookup. Run refresh-hive-project-metadata.yml to fix."
            echo "use-cache=false" >> "$GITHUB_OUTPUT"
            exit 0
          fi
          {
            echo "HIVE_PROJECT_METADATA_JSON<<METADATA_EOF"
            cat "$CACHE_PATH"
            echo "METADATA_EOF"
          } >> "$GITHUB_ENV"
          echo "use-cache=true" >> "$GITHUB_OUTPUT"
          echo "Loaded project metadata cache (age: ${AGE_DAYS} days)."
```

The existing `Mirror labels to The Hive custom fields` step needs no change — `hive-project-mirror.sh` already detects `HIVE_PROJECT_METADATA_JSON` and uses it instead of live-fetching (script lines 160–164 and 199–203).

The `use-cache=false` fallback path keeps the workflow correct when the cache is missing, malformed, or stale beyond the 14-day cap — the script's existing behavior (live `gh project view` + `gh project field-list`) takes over. This is the safety net for "refresh workflow has been broken for two weeks and nobody noticed."

### Phase 3 — `refresh-hive-project-metadata.yml` (new workflow)

Author a new workflow at `.github/workflows/refresh-hive-project-metadata.yml` in `HoneyDrunk.Actions`:

```yaml
name: Refresh Hive Project Metadata Cache

on:
  schedule:
    - cron: "0 6 * * 1"   # Mondays at 06:00 UTC
  workflow_dispatch: {}

permissions:
  contents: write   # commit the refreshed cache file

concurrency:
  group: refresh-hive-project-metadata
  cancel-in-progress: false

jobs:
  refresh:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Detect auth mode
        id: auth-mode
        env:
          APP_ID: ${{ secrets.HIVE_APP_ID }}
          APP_PRIVATE_KEY: ${{ secrets.HIVE_APP_PRIVATE_KEY }}
          PAT_FALLBACK: ${{ secrets.HIVE_FIELD_MIRROR_TOKEN }}
        run: |
          set -euo pipefail
          if [[ -n "${APP_ID}" && -n "${APP_PRIVATE_KEY}" ]]; then
            echo "use-app=true" >> "$GITHUB_OUTPUT"
          elif [[ -n "${PAT_FALLBACK}" ]]; then
            echo "use-app=false" >> "$GITHUB_OUTPUT"
          else
            echo "::error::No auth available"
            exit 1
          fi

      - name: Mint App token
        id: app-token
        if: steps.auth-mode.outputs.use-app == 'true'
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.HIVE_APP_ID }}
          private-key: ${{ secrets.HIVE_APP_PRIVATE_KEY }}
          owner: HoneyDrunkStudios

      - name: Refresh metadata cache
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token || secrets.HIVE_FIELD_MIRROR_TOKEN }}
          PROJECT_OWNER: HoneyDrunkStudios
          PROJECT_NUMBER: 4
          CACHE_PATH: .github/config/hive-project-metadata.json
        run: |
          set -euo pipefail
          PROJECT_JSON="$(gh project view "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json)"
          FIELDS_JSON="$(gh project field-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json)"
          NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
          jq -n \
            --arg now "$NOW" \
            --arg owner "$PROJECT_OWNER" \
            --argjson number "$PROJECT_NUMBER" \
            --argjson project "$PROJECT_JSON" \
            --argjson fields "$FIELDS_JSON" \
            '{
              _meta: {
                schema_version: "1.0",
                last_refreshed_utc: $now,
                project_owner: $owner,
                project_number: $number,
                refresh_workflow: ".github/workflows/refresh-hive-project-metadata.yml"
              },
              project: { id: $project.id },
              fields: $fields.fields
            }' > "$CACHE_PATH"

      - name: Commit cache update
        env:
          CACHE_PATH: .github/config/hive-project-metadata.json
        run: |
          set -euo pipefail
          if git diff --quiet -- "$CACHE_PATH"; then
            echo "Cache unchanged."
            exit 0
          fi
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add -- "$CACHE_PATH"
          git commit -m "chore(hive): refresh project metadata cache [skip ci]"
          git push
```

Three notes on this workflow:

1. **Token plumbing.** The refresh workflow itself uses App auth where available, exactly like every other Hive-touching workflow post-Actions#57. The PAT path is the fallback. App scopes already grant `Projects: Read` (org-level) which is sufficient for `gh project view` and `gh project field-list`.
2. **Skip-CI on the refresh commit.** `[skip ci]` in the commit message prevents the commit from triggering the `pr-core` family on `HoneyDrunk.Actions` (workflow YAML changes pass `pr-core` cheaply, but the cache file is data-only and need not).
3. **Concurrency group.** `cancel-in-progress: false` so a `workflow_dispatch` invocation right after the cron does not abort an in-flight refresh.

### Phase 4 — Script-side documentation

Add a comment block at the top of `hive-project-mirror.sh` (after the existing `set -euo pipefail` and before the variable declarations on line 4) explaining the GraphQL-only nature of Projects v2 and pointing readers at the cache mechanism:

```bash
# Projects v2 is GraphQL-only — the legacy REST Projects API was sunset in
# 2022. Field updates (updateProjectV2ItemFieldValue), item adds
# (addProjectV2ItemById), and option ensures (updateProjectV2Field) cannot be
# moved off GraphQL. To reduce per-invocation GraphQL cost, this script reads
# the project + field + option metadata from a cached JSON blob via the
# HIVE_PROJECT_METADATA_JSON env var when set. The cache is refreshed weekly
# by .github/workflows/refresh-hive-project-metadata.yml. When the env var is
# absent, the script live-fetches via gh project view + gh project field-list
# (the original behavior — preserved for standalone CLI invocation).
```

This is the "REST migration" check-box for this packet — it's a constraint discovery, not a code migration. The constraint is permanent; documenting it prevents the next person from spending an afternoon proving the same dead end.

## Consumer Impact

Cache-aware. Existing callers (the 9 caller workflows from packet `2026-04-28-actions-hive-field-mirror-app-auth.md`) need **no further changes** — the workflow-level cache load is internal to the reusable workflow. When this packet merges, every consuming repo benefits automatically on the next mirror run.

The new `refresh-hive-project-metadata.yml` is a self-contained workflow; no consumers.

## Breaking Change?

- [ ] Yes — consumers need to update their caller workflows
- [x] No — backward compatible (cache is internal; live-fetch fallback handles missing/stale cache)

## Key Files

- `HoneyDrunk.Actions/scripts/hive-project-mirror.sh` (modified — add docstring; no behavior change since the cache-consuming branches at lines 160–164 and 199–203 already exist from Actions#57)
- `HoneyDrunk.Actions/.github/workflows/hive-field-mirror.yml` (modified — add `Load cached project metadata` step)
- `HoneyDrunk.Actions/.github/config/hive-project-metadata.json` (new — initial population by manually running the new refresh workflow as a `workflow_dispatch` immediately after merge)
- `HoneyDrunk.Actions/.github/workflows/refresh-hive-project-metadata.yml` (new)
- `HoneyDrunk.Actions/docs/CHANGELOG.md` (append entry)

## NuGet Dependencies

None — shell + GitHub Actions YAML + JSON only.

## Acceptance Criteria

### Cache file

- [ ] `HoneyDrunk.Actions/.github/config/hive-project-metadata.json` exists with `_meta.schema_version: "1.0"`, valid `_meta.last_refreshed_utc`, `project.id`, and a populated `fields` array containing every field on The Hive (Wave, Tier, Node, ADR, Initiative, Actor, plus the default Status/Title/etc.).
- [ ] Each field entry has the same shape `gh project field-list ... --format json` returns: `id`, `name`, and (where applicable) `options[]` with `id` and `name`.
- [ ] The file is checked into `main` with the bot author after the first manual `workflow_dispatch` of the refresh workflow.

### Refresh workflow

- [ ] `.github/workflows/refresh-hive-project-metadata.yml` exists with the canonical permissions block (`contents: write` only — required to commit the refreshed JSON; no other writes), App-auth-with-PAT-fallback, weekly cron `0 6 * * 1`, and `workflow_dispatch`.
- [ ] A manual `workflow_dispatch` run produces a non-zero diff on the cache file (or "unchanged" if metadata genuinely has not changed) and pushes a `chore(hive): refresh project metadata cache [skip ci]` commit.
- [ ] If the workflow fails (auth missing, gh project view 404, etc.), it exits non-zero and emits a clear error message — does not silently leave the cache stale.
- [ ] `concurrency.group: refresh-hive-project-metadata`, `cancel-in-progress: false`.

### Mirror workflow consumes the cache

- [ ] `hive-field-mirror.yml` has a new `Load cached project metadata` step that runs after `Checkout HoneyDrunk.Actions repository` and before `Resolve issue URL`.
- [ ] The step checks the cache file's existence, schema version, and age (max 14 days), and either populates `HIVE_PROJECT_METADATA_JSON` env var or falls back with a clear `::warning::` and `use-cache=false` step output.
- [ ] When the cache is loaded, `hive-project-mirror.sh` skips `gh project view` and `gh project field-list` calls (verified by inspecting the workflow run log — those lines should be absent).
- [ ] When the cache is absent or stale, the script's existing live-fetch path runs. Verified by deliberately removing the cache file in a test branch and observing the warning + successful live run.

### Script documentation

- [ ] `scripts/hive-project-mirror.sh` has a comment block (lines 4–11 or thereabouts) explaining the Projects v2 GraphQL-only constraint, the cache mechanism, and the env-var contract.

### Verification (post-merge)

- [ ] Trigger a `labeled` event on a test issue in any consuming repo. Inspect the resulting `Hive Field Mirror` run log: `Loaded project metadata cache (age: 0 days).` should appear.
- [ ] The same run's `gh api graphql` call count drops measurably vs. a pre-merge run on a similar issue — capture before/after numbers in the PR description if possible (best-effort; not a hard gate).
- [ ] `actionlint` passes on every modified and new workflow file.
- [ ] `shellcheck` passes on `hive-project-mirror.sh` (or any pre-existing exclusions are preserved).

### Documentation

- [ ] `HoneyDrunk.Actions/docs/CHANGELOG.md` gets a new entry: `### Added — refresh-hive-project-metadata.yml weekly cache refresh; .github/config/hive-project-metadata.json. ### Changed — hive-field-mirror.yml loads cached project metadata, falling back to live GraphQL when cache is absent or stale.`
- [ ] No README update required.

## Human Prerequisites

- [ ] After merge, manually trigger the new `refresh-hive-project-metadata.yml` workflow once via `workflow_dispatch` to populate the initial cache file. The PR cannot ship the JSON itself because the cache is bot-generated; the human action is one click in the Actions tab. The mirror workflow's fallback path keeps things working in the interim.

## Dependencies

None. This packet is independently shippable. It does not require packet `2026-04-28-actions-hive-field-mirror-app-auth.md` to land first — caching reduces drain regardless of which token pool the workflow runs against. Shipping in either order is fine. Maximum benefit is achieved when both have shipped, but neither is a hard prerequisite for the other.

## Constraints

- **Projects v2 is GraphQL-only.** The legacy REST Projects API was sunset in 2022. Do not attempt to migrate `addProjectV2ItemById`, `updateProjectV2ItemFieldValue`, or `updateProjectV2Field` to REST — there is no REST endpoint for them. The only REST opportunity in this script is the issue-fetch on line 112, which is already REST.
- **The cache is data, not code.** It must not contain secrets, tokens, or any value that could change without the project owner's intent. Schema validation in the load step is the safety net.
- **14-day staleness cap.** If the refresh workflow has been broken for more than two weeks, the mirror falls back to live-fetch rather than trusting drift-prone cached data. This is non-negotiable — silent staleness is the worst failure mode.
- **App auth is preferred but not required for the refresh workflow.** The refresh runs once a week; the PAT-fallback path is acceptable if App secrets are momentarily missing.
- **`[skip ci]` on the refresh commit.** The cache file is data, not source. `pr-core` has no business running on a cache refresh.
- **No ADR cross-references in code or YAML comments.** Per the established convention.
- **Public repo.** The cache file contains GraphQL node IDs (e.g. `PVT_kwD...`) which are non-secret — these are listed in board URLs visible to anyone with read access to the project. Confirm this on first refresh and proceed.
- **Don't bypass `actionlint` or `shellcheck`.** Fix findings rather than suppressing them.

## Referenced Pattern: Actions#57

Actions#57 (closed 2026-04-26) introduced the `HIVE_PROJECT_METADATA_JSON` env-var contract that this packet's cache file feeds. The script's existing detection paths at lines 160–164 (`PROJECT_JSON` source selection) and 199–203 (`FIELDS_JSON` source selection) are the consumers. This packet does **not** modify the script's cache-consumption logic — it only feeds the env var from disk instead of from `file-packets.sh`'s in-memory resolution.

## Out of Scope

- **Cross-repo label writes** — outside this script. If any future workflow does cross-repo label writes via GraphQL, that's a separate REST-migration packet against that workflow.
- **Deleting `gh project view` / `gh project field-list` from the script entirely.** Live-fetch is the intentional fallback; do not remove it.
- **Triggering the refresh from a webhook on project field changes.** Out of scope — weekly cron is sufficient for the current rate of board change. Re-evaluate if option lists start drifting more often than weekly.

## Agent Handoff

**Objective:** Cache stable Hive project metadata in a JSON file refreshed weekly; have `hive-field-mirror.yml` read it on every per-event invocation; document the Projects-v2 GraphQL-only constraint that prevents further REST migration inside this script.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: cut per-event GraphQL cost for the Hive Field Mirror by ~50–70% by eliminating per-invocation metadata re-resolution. The cache contract already exists in `hive-project-mirror.sh` (Actions#57); this packet feeds it from disk.
- Pattern source: Actions#57 introduced `HIVE_PROJECT_METADATA_JSON` for batch invocations. This packet generalizes it to per-event invocations via a checked-in cache file refreshed by a new weekly workflow.
- This is one of three standalone packets addressing the 2026-04-28 GraphQL rate-limit incident; see also `2026-04-28-actions-hive-field-mirror-app-auth.md` and `2026-04-28-actions-hive-field-mirror-coalesce-design.md`. All three are independently shippable.
- ADRs: none. CI hardening, not architecture.

**Acceptance Criteria:** see `## Acceptance Criteria` above.

**Dependencies:** None.

**Constraints:**
- Projects v2 is GraphQL-only. Do not waste effort trying to REST-migrate the project-side mutations. The script's existing comment block (added by this packet) makes the constraint clear for future work.
- `HIVE_PROJECT_METADATA_JSON` env var is the contract. The cache file's shape must match what the script's `jq` queries already consume — verify by running the live-fetch path once, capturing its output, and using that as the cache file's initial structure.
- Schema versioning: `_meta.schema_version` is `"1.0"` from day one. Bump only on incompatible shape changes; the script's load step rejects mismatches.
- 14-day staleness cap is a hard rule, not a guideline. Silent stale data is worse than a fallback to live-fetch.
- The refresh workflow uses App auth (Actions#57 secrets `HIVE_APP_ID` / `HIVE_APP_PRIVATE_KEY`); PAT fallback is permitted.
- Initial cache population is a human one-click via `workflow_dispatch` after merge — do not attempt to seed the JSON in the same PR by hand-crafting IDs. The bot-generated commit is the source of truth.
- No ADR cross-references in code or YAML comments.
- Public repo; the cache contains node IDs which are non-secret.
- Don't bypass `actionlint` or `shellcheck`.

**Key Files:** see `## Key Files` above.

**Contracts:**
- `HIVE_PROJECT_METADATA_JSON` env-var consumed by `hive-project-mirror.sh` lines 160–164 and 199–203 — fed by the new `Load cached project metadata` step in the workflow.
- `_meta.schema_version` — string-equality check against `"1.0"` in the load step.
- `_meta.last_refreshed_utc` — ISO-8601 UTC timestamp; consumed by the staleness check; produced by `date -u +%Y-%m-%dT%H:%M:%SZ` in the refresh workflow.
- The cache file shape mirrors the existing `gh project view` + `gh project field-list` output structure — do not invent a new shape; harvest the live output and wrap it.
