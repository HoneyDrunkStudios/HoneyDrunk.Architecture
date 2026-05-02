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

# CI Change: Migrate `hive-field-mirror.yml` to GitHub App auth with PAT fallback

## Summary

`HoneyDrunk.Actions/.github/workflows/hive-field-mirror.yml` authenticates exclusively as `secrets.hive-field-mirror-token || secrets.HIVE_FIELD_MIRROR_TOKEN` — both are user PATs owned by the solo dev. Token ownership determines the rate-limit pool, so every API call this workflow makes is charged to the dev's personal user pool (5,000/hour). On 2026-04-28 the personal pool hit 5,059 used after a 12-issue ADR-0012 wave was filed, with the field-mirror workflow contributing the lion's share of the drain. Mirror the App-auth pattern that `file-packets.yml` already uses — accept `app-id` + `app-private-key` as optional secrets, mint an installation token via `actions/create-github-app-token@v1`, fall back to the existing PAT when App secrets are absent. Update every consuming caller workflow across the Grid in the same PR.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Actions` — the reusable workflow lives here.

The caller workflows in 9 consuming Grid repos (Pulse, Notify, Vault, Transport, Data, Auth, Web.Rest, Kernel, Actions itself) are updated in the same PR — the pattern is mechanical and identical across all of them, and splitting would leave callers stuck on the PAT path while the upstream is App-ready.

## Target Workflow

**File (reusable):** `.github/workflows/hive-field-mirror.yml` in `HoneyDrunk.Actions`
**Files (callers):** `.github/workflows/hive-field-mirror.yml` in:

- `HoneyDrunk.Actions`
- `HoneyDrunk.Pulse`
- `HoneyDrunk.Notify`
- `HoneyDrunk.Vault`
- `HoneyDrunk.Transport`
- `HoneyDrunk.Data`
- `HoneyDrunk.Auth`
- `HoneyDrunk.Web.Rest`
- `HoneyDrunk.Kernel`

**Family:** automation (board-mirror)

## Motivation

GitHub's GraphQL rate limit is per-token-owner. A user PAT shares one 5,000/hour pool across every interactive `gh` call, every Claude Code session, every other agent's API traffic, and every workflow that uses that PAT. A GitHub App installation token has its own 5,000/hour ceiling (scaling to 10,000 once the org crosses 16 repos), independent of all other token activity.

The `HIVE_APP_ID` + `HIVE_APP_PRIVATE_KEY` org secrets already exist (provisioned during the file-packets hardening work). The App is already installed on every Grid repo with `Issues: Read & Write`, `Metadata: Read`, `Contents: Read & Write`, and org-level `Projects: Read & Write` — the same scope shape `hive-field-mirror.yml` needs. No new App provisioning is required. The work is purely workflow-side: accept the inputs, mint the token, plumb it through.

The mirror workflow runs on `issues: [opened, labeled, unlabeled, edited]`. Every Grid issue file event triggers it. With 9 consuming repos and growing, the mirror is the single biggest persistent drain on the dev's PAT pool. App auth eliminates the contention entirely.

## Proposed Implementation

### Reusable workflow — `HoneyDrunk.Actions/.github/workflows/hive-field-mirror.yml`

Mirror the auth pattern from `file-packets.yml` (lines 41–61, 93–131, 146–147). Three changes to the `workflow_call` interface and two new steps in the job.

**1. Accept App-auth secrets as optional inputs.**

Add to the `secrets:` block under `workflow_call`:

```yaml
    secrets:
      hive-field-mirror-token:
        description: >-
          PAT with issues:read on target repos and projects:write on The Hive.
          Used when App auth is not configured. Required if neither app-id nor
          app-private-key is provided.
        required: false
      HIVE_FIELD_MIRROR_TOKEN:
        description: Legacy org/repo secret name accepted for direct workflow triggers.
        required: false
      app-id:
        description: >-
          GitHub App ID for the dedicated Hive App. When provided together with
          app-private-key, the workflow mints an installation token via
          actions/create-github-app-token and uses it for every subsequent gh
          call. Falls back to hive-field-mirror-token when either is absent.
        required: false
      app-private-key:
        description: >-
          GitHub App private key (PEM contents) paired with app-id. See app-id
          description for fallback semantics.
        required: false
```

Note that `hive-field-mirror-token` and `HIVE_FIELD_MIRROR_TOKEN` both flip from `required: true` to `required: false`. A new `Detect auth mode` step (below) enforces "at least one auth path provided" at runtime.

**2. Add `Detect auth mode` step before the existing `Resolve actions checkout ref` step.**

Copy the pattern from `file-packets.yml` lines 93–113 verbatim, with `PAT_FALLBACK` reading from either of the two PAT secret names:

```yaml
      - name: Detect auth mode
        id: auth-mode
        env:
          APP_ID: ${{ secrets.app-id }}
          APP_PRIVATE_KEY: ${{ secrets.app-private-key }}
          PAT_FALLBACK: ${{ secrets.hive-field-mirror-token || secrets.HIVE_FIELD_MIRROR_TOKEN }}
        run: |
          set -euo pipefail
          if [[ -n "${APP_ID}" && -n "${APP_PRIVATE_KEY}" ]]; then
            echo "use-app=true" >> "$GITHUB_OUTPUT"
            echo "Auth path: GitHub App"
          elif [[ -n "${PAT_FALLBACK}" ]]; then
            echo "use-app=false" >> "$GITHUB_OUTPUT"
            echo "Auth path: PAT fallback (hive-field-mirror-token)"
          else
            echo "::error::Neither GitHub App auth (app-id + app-private-key) nor hive-field-mirror-token PAT was provided"
            exit 1
          fi
```

The `if` expression on a workflow-level `if:` cannot reference the `secrets` context, so this step routes the presence test through env vars and emits a step output the App-token step can gate on. This is the same pattern the file-packets workflow uses for the same reason.

**3. Add `Mint GitHub App installation token` step gated on `auth-mode.outputs.use-app == 'true'`.**

Copy lines 115–122 from `file-packets.yml`:

```yaml
      - name: Mint GitHub App installation token
        id: app-token
        if: steps.auth-mode.outputs.use-app == 'true'
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.app-id }}
          private-key: ${{ secrets.app-private-key }}
          owner: HoneyDrunkStudios
```

The `owner:` value is hardcoded to `HoneyDrunkStudios` — the App is installed on this org and the issues being mirrored are always under it. (The file-packets workflow uses `${{ inputs.project-owner }}` for this; replicate that approach here using the existing `inputs.project-owner` so any future operator override propagates correctly.)

**Final form:**
```yaml
        with:
          app-id: ${{ secrets.app-id }}
          private-key: ${{ secrets.app-private-key }}
          owner: ${{ github.event_name == 'workflow_call' && inputs.project-owner || 'HoneyDrunkStudios' }}
```

**4. Update the existing `Mirror labels to The Hive custom fields` step's `HIVE_FIELD_MIRROR_TOKEN` env var.**

Currently (line 84):
```yaml
HIVE_FIELD_MIRROR_TOKEN: ${{ secrets.hive-field-mirror-token || secrets.HIVE_FIELD_MIRROR_TOKEN }}
```

Becomes:
```yaml
HIVE_FIELD_MIRROR_TOKEN: ${{ steps.app-token.outputs.token || secrets.hive-field-mirror-token || secrets.HIVE_FIELD_MIRROR_TOKEN }}
```

The App token wins when present; the PAT fallback chain is preserved otherwise. This matches `file-packets.yml` lines 146–147. The downstream `hive-project-mirror.sh` reads `HIVE_FIELD_MIRROR_TOKEN` (line 7 of the script) — no script-side changes needed.

### Caller workflows — 9 repos

For every caller workflow listed in **Target Workflow** above, replace the existing `secrets:` block:

```yaml
    secrets:
      hive-field-mirror-token: ${{ secrets.HIVE_FIELD_MIRROR_TOKEN }}
```

with the App-auth shape:

```yaml
    secrets:
      app-id: ${{ secrets.HIVE_APP_ID }}
      app-private-key: ${{ secrets.HIVE_APP_PRIVATE_KEY }}
      hive-field-mirror-token: ${{ secrets.HIVE_FIELD_MIRROR_TOKEN }}
```

The PAT secret line stays — it acts as a tertiary fallback if the org-level App secrets are ever rotated and the cache is briefly empty. All three secrets are non-required at the workflow_call level, so an absent `HIVE_FIELD_MIRROR_TOKEN` org/repo secret resolves to empty without erroring. After this packet merges and runs are observed using App auth (verified via the `Auth path: GitHub App` log line), a follow-up sweep can drop the PAT fallback line entirely.

### Out of scope (deferred to packet 03)

This packet does **not** address the recursive self-trigger risk where `hive-field-mirror.yml` writes a label and that write itself fires a `labeled` event re-triggering the workflow. App auth alone gives plenty of headroom (independent 5,000/hour pool); the recursive-loop investigation lives in the standalone design packet `2026-04-28-actions-hive-field-mirror-coalesce-design.md`.

This packet does **not** add metadata caching or REST migration for label writes — those land in `2026-04-28-actions-hive-field-mirror-cache-and-rest.md`.

## Consumer Impact

**Caller workflows must pass the new App-auth secrets.** The reusable workflow is backwards-compatible (PAT path still works), but consumers that don't pass `app-id` + `app-private-key` won't get the rate-limit benefit. All 9 known consumers are updated in this PR. Any future caller created after this packet should follow the new pattern; the consumer-usage doc update is a follow-up scope item if `hive-field-mirror.yml` ever gets a section in `docs/consumer-usage.md` (it does not today).

## Breaking Change?

- [ ] Yes — consumers need to update their caller workflows
- [x] No — backward compatible (PAT path remains functional; consumers update at their leisure, but all 9 known consumers are updated in this PR)

## Key Files

- `HoneyDrunk.Actions/.github/workflows/hive-field-mirror.yml` (modified — auth path)
- `HoneyDrunk.Actions/.github/workflows/file-packets.yml` (read-only reference — the App-auth pattern being mirrored)
- `HoneyDrunk.Actions/.github/workflows/hive-field-mirror.yml` caller block (modified — Actions repo's own caller)
- `HoneyDrunk.Pulse/.github/workflows/hive-field-mirror.yml` (modified — caller)
- `HoneyDrunk.Notify/.github/workflows/hive-field-mirror.yml` (modified — caller)
- `HoneyDrunk.Vault/.github/workflows/hive-field-mirror.yml` (modified — caller)
- `HoneyDrunk.Transport/.github/workflows/hive-field-mirror.yml` (modified — caller)
- `HoneyDrunk.Data/.github/workflows/hive-field-mirror.yml` (modified — caller)
- `HoneyDrunk.Auth/.github/workflows/hive-field-mirror.yml` (modified — caller)
- `HoneyDrunk.Web.Rest/.github/workflows/hive-field-mirror.yml` (modified — caller)
- `HoneyDrunk.Kernel/.github/workflows/hive-field-mirror.yml` (modified — caller)
- `HoneyDrunk.Actions/docs/CHANGELOG.md` (append entry)
- `HoneyDrunk.Actions/scripts/hive-project-mirror.sh` (no change — reads `HIVE_FIELD_MIRROR_TOKEN` env var which now resolves to App token)

## NuGet Dependencies

None — shell + GitHub Actions YAML only.

## Acceptance Criteria

### Reusable workflow

- [ ] `.github/workflows/hive-field-mirror.yml` declares `app-id` and `app-private-key` as optional secrets in the `workflow_call` block.
- [ ] `hive-field-mirror-token` and `HIVE_FIELD_MIRROR_TOKEN` are flipped from `required: true` to `required: false`.
- [ ] A `Detect auth mode` step runs before checkout, reads all three secret types via env vars (App context cannot reference `secrets.*`), emits `use-app=true|false`, and fails fast with a clear error if no auth path is provided.
- [ ] A `Mint GitHub App installation token` step uses `actions/create-github-app-token@v1`, is gated on `steps.auth-mode.outputs.use-app == 'true'`, and uses `${{ inputs.project-owner }}` (or fallback `'HoneyDrunkStudios'`) for the `owner` input.
- [ ] The `Mirror labels to The Hive custom fields` step's `HIVE_FIELD_MIRROR_TOKEN` env reads `${{ steps.app-token.outputs.token || secrets.hive-field-mirror-token || secrets.HIVE_FIELD_MIRROR_TOKEN }}`, preferring the App token.

### Caller workflows (9 repos)

- [ ] `HoneyDrunk.Actions/.github/workflows/hive-field-mirror.yml` (caller block) passes `app-id`, `app-private-key`, and `hive-field-mirror-token` to the reusable workflow.
- [ ] `HoneyDrunk.Pulse/.github/workflows/hive-field-mirror.yml` updated identically.
- [ ] `HoneyDrunk.Notify/.github/workflows/hive-field-mirror.yml` updated identically.
- [ ] `HoneyDrunk.Vault/.github/workflows/hive-field-mirror.yml` updated identically.
- [ ] `HoneyDrunk.Transport/.github/workflows/hive-field-mirror.yml` updated identically.
- [ ] `HoneyDrunk.Data/.github/workflows/hive-field-mirror.yml` updated identically.
- [ ] `HoneyDrunk.Auth/.github/workflows/hive-field-mirror.yml` updated identically.
- [ ] `HoneyDrunk.Web.Rest/.github/workflows/hive-field-mirror.yml` updated identically.
- [ ] `HoneyDrunk.Kernel/.github/workflows/hive-field-mirror.yml` updated identically.

### Verification

- [ ] After merge, opening a label-trigger event on a test issue produces a workflow run whose log contains `Auth path: GitHub App` (the new step's success message).
- [ ] `gh api -H 'Authorization: Bearer <PAT>' rate_limit --jq .resources.graphql.remaining` against the developer's PAT shows the same value before and after a label-mirror run on a test issue, confirming the workflow no longer draws from that pool.
- [ ] The PAT fallback path still works when `HIVE_APP_ID` is unset on a test caller (verified by deliberately omitting the secret in a throwaway branch caller).
- [ ] `actionlint` passes on every modified workflow file.

### Documentation

- [ ] `HoneyDrunk.Actions/docs/CHANGELOG.md` gets a new `### Changed` entry under the next-version section: `hive-field-mirror.yml: accept app-id + app-private-key for App-auth path; PAT path remains as fallback.`
- [ ] No README or consumer-usage update needed — `hive-field-mirror.yml` is not currently documented as a consumer-facing reusable workflow (it's only invoked from auto-generated callers in the Grid, not by external repos).

## Human Prerequisites

- [ ] **None** — the GitHub App (`HIVE_APP_ID` + `HIVE_APP_PRIVATE_KEY` org secrets) was already provisioned during the file-packets hardening work (Actions#57) and is installed on every Grid repo with the scopes hive-field-mirror needs. Verify by checking org settings → Secrets → Actions: both `HIVE_APP_ID` and `HIVE_APP_PRIVATE_KEY` should be present and visible to all Grid repos.

## Dependencies

None. This packet is independently shippable. Mergeable in any order relative to the other two standalone packets in this flight (`2026-04-28-actions-hive-field-mirror-cache-and-rest.md` and `2026-04-28-actions-hive-field-mirror-coalesce-design.md`).

## Constraints

- **Mirror the file-packets pattern verbatim where possible.** Steps, env-var plumbing, and the auth-mode detection idiom are already proven there. Re-deriving means re-discovering the same edge cases.
- **Backwards compatibility is non-negotiable.** Every existing caller must keep working through the merge — the PAT fallback chain stays in place. A subsequent hygiene packet can drop it once a quarter passes with no PAT-path runs observed.
- **Hardcoded `'HoneyDrunkStudios'` is the fallback owner**, not the primary value. Use `inputs.project-owner` first to stay consistent with the rest of the workflow's parameterization.
- **No ADR cross-references in code or workflow comments.** Per the established convention (one of the user's persistent feedback items), decision context belongs in this packet and the PR description, not in YAML comments.
- **Public repo.** The App's private key is never echoed in logs, never committed, never appears in any error message. `actions/create-github-app-token@v1` handles redaction natively.
- **Don't bypass `actionlint`.** Fix lint findings rather than suppressing them.

## Referenced Pattern: Actions#57

Actions#57 (closed 2026-04-26) hardened `file-packets.yml` with the same App-auth pattern. The relevant lines in that workflow:

- Lines 41–61: `secrets:` block with `app-id` / `app-private-key` as optional, `hive-field-mirror-token` as optional fallback.
- Lines 93–113: `Detect auth mode` step routing secret presence through env vars to emit `use-app` step output.
- Lines 115–122: `Mint GitHub App installation token` step using `actions/create-github-app-token@v1`, gated on `steps.auth-mode.outputs.use-app == 'true'`.
- Lines 146–147: `GH_TOKEN` and `HIVE_FIELD_MIRROR_TOKEN` env vars on downstream steps coalesce App token first, PAT fallback second.

Replicate that pattern into `hive-field-mirror.yml`. The two workflows are structurally similar enough that the diff is essentially a copy-paste of the auth scaffolding around the existing per-issue mirror logic.

## Agent Handoff

**Objective:** Migrate `hive-field-mirror.yml` reusable workflow + 9 callers to GitHub App auth, with the existing PAT path preserved as fallback.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Actions`, branch from `main`. The 9 caller-repo edits are also part of the same logical change; either include them in the same PR if possible (cross-repo via the same author) or split into per-repo follow-up PRs explicitly listed in the main PR description.

**Context:**
- Goal: stop charging the field-mirror workflow's GraphQL traffic to the dev's personal PAT pool, which on 2026-04-28 hit 5,059/5,000 and blocked all interactive `gh` work.
- Pattern source: `HoneyDrunk.Actions/.github/workflows/file-packets.yml` lines 41–61, 93–131, 146–147 (Actions#57, closed 2026-04-26).
- This is one of three standalone packets addressing the same incident; see also the metadata-caching/REST-migration packet and the coalesce-design packet, both shippable independently.
- ADRs: none. This is CI hardening, not an architectural decision.

**Acceptance Criteria:** See `## Acceptance Criteria` above.

**Dependencies:** None.

**Constraints:**
- Mirror the file-packets pattern verbatim. Don't re-derive the auth-mode-detection idiom — copy lines 93–113 of `file-packets.yml` and adapt only the env-var names where needed.
- Workflow-level `if:` expressions cannot reference the `secrets` context. This is the reason `Detect auth mode` exists as a separate step — work around the limitation, don't fight it.
- The PAT fallback chain stays in place. `${{ steps.app-token.outputs.token || secrets.hive-field-mirror-token || secrets.HIVE_FIELD_MIRROR_TOKEN }}` is the canonical resolution order.
- No ADR cross-references in code or YAML comments.
- Public repo; the App private key never appears in logs.
- Don't bypass `actionlint` — fix findings.
- The existing `hive-project-mirror.sh` script reads `HIVE_FIELD_MIRROR_TOKEN` from env (line 7); it does not need changes for this packet — the workflow-side env-var resolution is enough.

**Key Files:** see `## Key Files` above.

**Contracts:**
- The reusable workflow's `workflow_call` interface gains two optional secrets (`app-id`, `app-private-key`) and flips two existing secrets from required to optional. No removal — pure addition + relaxation, fully backwards-compatible.
- The internal `HIVE_FIELD_MIRROR_TOKEN` env var on the mirror step is the only contract `hive-project-mirror.sh` cares about; its resolution chain changes from `secrets || legacy_secrets` to `app_token || secrets || legacy_secrets`.
