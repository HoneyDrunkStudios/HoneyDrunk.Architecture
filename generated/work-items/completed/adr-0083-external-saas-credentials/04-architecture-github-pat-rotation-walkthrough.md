---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0083", "wave-2"]
dependencies: ["work-item:01"]
adrs: ["ADR-0083", "ADR-0014", "ADR-0044"]
wave: 2
initiative: adr-0083-external-saas-credentials
node: honeydrunk-architecture
---

# Author `infrastructure/walkthroughs/github-pat-rotation.md` — GitHub fine-grained PAT rotation procedure

## Summary
Author the per-provider rotation walkthrough for GitHub fine-grained Personal Access Tokens — today covering `GH_ISSUE_TOKEN`, `HIVE_FIELD_MIRROR_TOKEN`, `LABELS_FANOUT_PAT`, and any future PATs that are not replaced by GitHub Apps — per ADR-0083 D4. Parallel with packets 02 (SonarCloud) and 03 (NuGet) within Wave 2. The walkthrough is **token-class-shaped**, not per-token-shaped, because the procedure is identical across all GitHub fine-grained PATs and the walkthrough should not need a separate file for each new PAT introduced.

## Context
ADR-0083 D4 commits per-provider rotation walkthroughs. GitHub PATs are one of three mandatory first-wave walkthroughs. ADR-0083 D4 §"`github-pat-rotation.md`" specifies the scope:

> Rotates GitHub fine-grained PATs (today: `GH_ISSUE_TOKEN`, `HIVE_FIELD_MIRROR_TOKEN`, `LABELS_FANOUT_PAT`, and any future PATs that aren't replaced by GitHub Apps). Covers: GitHub → Settings → Developer settings → Personal access tokens → Fine-grained → Regenerate the existing token with the same scopes → copy value → update destination (GitHub org secret or repo secret) → smoke-test → close the standing rotation issue → open the next → update the inventory.

PAT-vs-GitHub-App context: ADR-0014 introduced `HIVE_APP_ID` and `HIVE_APP_PRIVATE_KEY` (the GitHub App pair that replaces the `HIVE_FIELD_MIRROR_TOKEN` PAT in the primary code path). The PAT remains as a fallback per the inventory's row notes (`HIVE_FIELD_MIRROR_TOKEN` — "live PAT used by `hive-field-mirror.yml` fallback path"). The ADR-0044 GitHub App migration for OpenClaw is in progress; when it completes, the corresponding fallback PAT for OpenClaw can be retired and its inventory row deleted. This walkthrough covers the rotation case until that migration; the procedure itself does not change.

The walkthrough format follows the existing convention. The procedure is identical for all three current PATs and any new ones, so the file is one walkthrough with a "which token" parameterization at the top, not three separate files.

This is a docs packet. No code, no .NET project, no workflow.

## Scope
- Create file `infrastructure/walkthroughs/github-pat-rotation.md` with the rotation procedure covering all three current PATs.
- Verify the `Rotation Procedure` cells in `infrastructure/reference/sensitive-inventory.md` for `GH_ISSUE_TOKEN`, `HIVE_FIELD_MIRROR_TOKEN`, and `LABELS_FANOUT_PAT` rows all point at this file's relative path.

## Proposed Implementation

The walkthrough is **token-class-shaped**. Open with a "Which token?" section listing the three currently-live PATs and the per-token destination and smoke-test details:

| Token | Destination | Smoke-test |
|-------|-------------|-----------|
| `GH_ISSUE_TOKEN` | GitHub org secret in `HoneyDrunkStudios` (Settings → Secrets and variables → Actions) | `file-work-items.yml` triggers via packet manifest push; the workflow's `gh issue create` call returns 401 on a bad token |
| `HIVE_FIELD_MIRROR_TOKEN` | GitHub org secret in `HoneyDrunkStudios` | `hive-field-mirror.yml` scheduled run via OpenClaw or manual `workflow_dispatch`; the GraphQL field-update call returns 401 on a bad token |
| `LABELS_FANOUT_PAT` | GitHub org secret in `HoneyDrunkStudios` | `seed-labels-fanout.yml` manual `workflow_dispatch` against one repo; the label-creation call returns 401 on a bad token |

Then the procedure, in order:

1. **Prerequisites and identity.** Operator must be logged in to GitHub as the user whose account owns the current PAT. Fine-grained PATs are bound to a user; the org secret holds the value but the token belongs to a person.
2. **Portal breadcrumb.** https://github.com → click avatar → **Settings** → **Developer settings** (bottom of left sidebar) → **Personal access tokens** → **Fine-grained tokens**.
3. **Identify the existing token.** The page lists every fine-grained PAT with its name, expiration, and the resource owner (must be `HoneyDrunkStudios`). Confirm which token by matching the name (e.g., `grid-issue-filer` for `GH_ISSUE_TOKEN`) and the resource-owner scope.
4. **Regenerate the replacement token.** Two options:
   - **Preferred — Regenerate in place:** click the existing token → **Regenerate token** → choose the expiration (the maximum allowed, **366 days** for fine-grained tokens as of authoring) → confirm. GitHub generates a new value for the same token entity, preserving the name and all scope settings exactly.
   - **Alternative — Create new with the same scopes:** if a regenerate is not available (e.g., the token was created under a different account and ownership is being transferred), click **Generate new token** → match the existing token's resource owner, repository access, repository permissions, organization permissions, and expiration exactly. This is more error-prone; prefer regenerate.
   In either case, **immediately copy the new token value** to the OS clipboard. GitHub will not display it again.
5. **Paste into the destination.** All three current PATs target `HoneyDrunkStudios` org secrets — Settings → Secrets and variables → Actions → find the secret name → **Update** → paste the new value → **Save**. If a future PAT targets a repo-level secret instead, navigate to the repo's Settings → Secrets and variables → Actions → repo secret.
6. **Verification — smoke-test per token.** Use the per-token smoke-test from the "Which token?" table at the top of the walkthrough. The smoke-test is non-destructive: an empty packet manifest push, a manual workflow dispatch, or a re-run of a recently-failed job. A 401 in the smoke-test's logs means the new token did not save correctly; repeat step 5.
7. **Revoke the previous regenerate.** If step 4 used "Regenerate in place," the old value is automatically invalidated when the regenerate completes — no separate revoke step needed. If step 4 used "Create new with the same scopes," return to the Fine-grained tokens page and **Revoke** the old token by name. Gated on step 6's verification success.
8. **Close the standing rotation issue.** Find the open GitHub issue in `HoneyDrunk.Architecture` labeled `external-credential-rotation` with title `[Rotate] {token-name} — expires {previous-expiration-date}`. Comment with the new expiration date and the link to the Fine-grained tokens page, then **Close**.
9. **Open the next standing rotation issue.** Create a new issue with title `[Rotate] {token-name} — expires {new-expiration-date}` (the 366-day-out date) and label `external-credential-rotation`. Issue body links to this walkthrough and the inventory row.
10. **Update the inventory row.** Edit `infrastructure/reference/sensitive-inventory.md` → row matching `{token-name}` → update `Current Expiration` to the new date. Commit and PR.

Add a final **"What breaks if you forget"** per token:

- **`GH_ISSUE_TOKEN`**: the `file-work-items.yml` workflow can no longer file new GitHub issues from packets in `generated/work-items/active/`. Packet filing stalls; The Hive misses new items per ADR-0008 D7.
- **`HIVE_FIELD_MIRROR_TOKEN`**: the `hive-field-mirror.yml` fallback path stops mirroring custom field updates to The Hive (the GitHub App primary path may still work; the fallback is a hedge against the App being temporarily down or rate-limited per ADR-0014).
- **`LABELS_FANOUT_PAT`**: `seed-labels-fanout.yml` can no longer apply new label-set updates across repos — repos drift from the canonical label set.

Add a **"PAT-vs-GitHub-App"** section: per ADR-0044's migration, every PAT in this walkthrough is a candidate for replacement by a GitHub App (which has cleaner identity binding, fine-grained per-installation permissions, and no user-account expiration cap). When a PAT's destination workflow migrates to a GitHub App, its inventory row is **deleted** (not rotated to a longer cadence) and the standing rotation issue is closed with a `wontfix` label. The walkthrough should not be deleted — future PATs that arise during incident response or before App migration completes will reuse the same procedure.

Add a **"Cross-references"** section linking to:
- `infrastructure/reference/sensitive-inventory.md` (the three current PAT rows)
- ADR-0014 (the GitHub App migration that retires `HIVE_FIELD_MIRROR_TOKEN` eventually)
- ADR-0044 (the OpenClaw GitHub App migration that retires the OpenClaw fallback PAT eventually)
- ADR-0083 D4 (the rotation-walkthrough convention this implements)

## Affected Files
- `infrastructure/walkthroughs/github-pat-rotation.md` (new)
- `infrastructure/reference/sensitive-inventory.md` (verify the three current PAT rows' `Rotation Procedure` cells all point at this file)
- `CHANGELOG.md` (append to in-progress entry)

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.
- [x] Per Invariant 8, the walkthrough names tokens but never writes their values.

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/github-pat-rotation.md` exists with a "Which token?" table covering `GH_ISSUE_TOKEN`, `HIVE_FIELD_MIRROR_TOKEN`, `LABELS_FANOUT_PAT` (per-token destination + smoke-test), followed by the ten procedural steps in order
- [ ] Step 4's expiration is **366 days** (the fine-grained PAT maximum as of authoring); "Regenerate in place" is the preferred path
- [ ] Step 6 lists the per-token smoke-test from the table at the top; smoke-tests are non-destructive (empty manifest push, manual dispatch, re-run failed job)
- [ ] Step 7 calls out the regenerate-in-place auto-invalidation property — no separate revoke needed when using regenerate
- [ ] Steps 8 and 9 cite the `external-credential-rotation` label and the title-shape `[Rotate] {token-name} — expires {YYYY-MM-DD}` per ADR-0083 D3
- [ ] Step 10's inventory-update step names `infrastructure/reference/sensitive-inventory.md` and the `Current Expiration` column
- [ ] A "What breaks if you forget" section names the per-token failure mode for each of `GH_ISSUE_TOKEN`, `HIVE_FIELD_MIRROR_TOKEN`, `LABELS_FANOUT_PAT`
- [ ] A "PAT-vs-GitHub-App" section explains the retire-via-deletion path when the destination workflow migrates to a GitHub App
- [ ] A "Cross-references" section links to `sensitive-inventory.md`, ADR-0014, ADR-0044, and ADR-0083 D4
- [ ] All three current PAT rows in `infrastructure/reference/sensitive-inventory.md` have their `Rotation Procedure` cells pointing at this walkthrough's relative path
- [ ] No secret value appears in the walkthrough
- [ ] Repo-level `CHANGELOG.md` appends to the in-progress entry

## Human Prerequisites
- [ ] Operator performs the **first rotation against this walkthrough** for whichever of the three current PATs next approaches its expiration window (or, opportunistically, for any PAT the operator has not rotated in the past 6 months). Capture any procedure ambiguities or portal-UI drift in a follow-up edit.

## Referenced ADR Decisions
**ADR-0083 D4 — Per-provider rotation walkthroughs.** Live under `infrastructure/walkthroughs/`, one per rotation-needing provider — but this walkthrough is **token-class-shaped** (one file covers all GitHub fine-grained PATs), not per-token-shaped, because the procedure is identical across PATs and ADR-0083 D4 §"`github-pat-rotation.md`" explicitly groups them.

**ADR-0083 D4 §"`github-pat-rotation.md`."** The specific scope ADR-0083 commits: covers `GH_ISSUE_TOKEN`, `HIVE_FIELD_MIRROR_TOKEN`, `LABELS_FANOUT_PAT`, and any future PATs that aren't replaced by GitHub Apps.

**ADR-0083 D3 — Standing-issue label and title-shape.** `external-credential-rotation` label; `[Rotate] {token-name} — expires {YYYY-MM-DD}` title. One standing issue per PAT.

**ADR-0014 — The Hive GitHub App migration.** `HIVE_FIELD_MIRROR_TOKEN` is the live PAT fallback for the `hive-field-mirror.yml` primary GitHub App path; when the App-only path is hardened enough to retire the fallback, the PAT's inventory row is deleted.

**ADR-0044 — Cloud Code Review GitHub App.** The OpenClaw bridge migration retires the OpenClaw fallback PAT (if one exists today) on completion; the same "delete the inventory row" pattern applies.

**Invariant 8 — "Secret values never appear in logs, traces, exceptions, or telemetry."** Walkthrough names tokens but never writes their values.

## Constraints
- **Regenerate in place is preferred over create-new.** Regenerate preserves the token entity, name, and all scope settings exactly — no risk of scope drift between rotations. Create-new is the fallback only when regenerate is unavailable.
- **No separate revoke step needed for regenerate.** GitHub auto-invalidates the old value on regenerate. The walkthrough must call this out so the operator does not perform a redundant revoke that could fail loudly on the auto-invalidated token.
- **No secret values in the file.** The walkthrough names tokens and references the GitHub portal location but never writes any actual value. Invariant 8 fully preserved.
- **One walkthrough file, not three.** Per ADR-0083 D4 §"`github-pat-rotation.md`" — the file is `github-pat-rotation.md`, singular, covering all GitHub fine-grained PATs. Do not split into `gh-issue-token-rotation.md`, `hive-field-mirror-token-rotation.md`, etc.
- **"What breaks if you forget" must be per-token.** Each of the three PATs has a different downstream consumer and a different failure mode. Do not collapse into a single generic "GitHub Actions stops working" statement.
- **Include the PAT-vs-GitHub-App section.** It is load-bearing for the long-term direction: PATs are accumulating-tax; GitHub Apps are the migration target per ADR-0014 / ADR-0044. The walkthrough's existence is not a commitment to PATs forever.
- **Use 366 days as the maximum.** Fine-grained PATs cap at 366 days; the walkthrough uses the maximum to minimize rotation frequency at solo-developer scale.

## Labels
`feature`, `tier-2`, `meta`, `docs`, `adr-0083`, `wave-2`

## Agent Handoff

**Objective:** Author the GitHub fine-grained PAT rotation walkthrough per ADR-0083 D4. Token-class-shaped (one file for all current and future GitHub fine-grained PATs).

**Target:** `HoneyDrunk.Architecture`, branch from `main` after packet 01 has merged.

**Context:**
- Goal: Disciplined documented rotation for the three live GitHub PATs (`GH_ISSUE_TOKEN`, `HIVE_FIELD_MIRROR_TOKEN`, `LABELS_FANOUT_PAT`) and any future PATs that arise before the GitHub App migrations per ADR-0014 / ADR-0044 retire them.
- Feature: ADR-0083 Sensitive Inventory rollout, Wave 2.
- ADRs: ADR-0083 D4 (walkthrough convention), D3 (standing-issue label); ADR-0014 (Hive App migration retires `HIVE_FIELD_MIRROR_TOKEN` eventually); ADR-0044 (OpenClaw App migration); Invariant 8 (no secret values).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 (inventory file with the three current PAT rows and the new labels) must have merged.

**Constraints:**
- Regenerate in place > create new with the same scopes.
- No separate revoke step needed for regenerate — call this out.
- No secret values (Invariant 8 preserved).
- One walkthrough file, not three. Token-class-shaped.
- "What breaks if you forget" per token, not generic.
- Include PAT-vs-GitHub-App section.
- 366-day expiration max.

**Key Files:**
- `infrastructure/walkthroughs/github-pat-rotation.md` (new)
- `infrastructure/reference/sensitive-inventory.md` (verify all three current PAT rows' `Rotation Procedure` cells)
- `CHANGELOG.md`

**Contracts:** None changed.

**PR Body Metadata:**
- `Authorship: agent`
- `Work Item: generated/work-items/proposed/adr-0083-external-saas-credentials/04-architecture-github-pat-rotation-walkthrough.md`
