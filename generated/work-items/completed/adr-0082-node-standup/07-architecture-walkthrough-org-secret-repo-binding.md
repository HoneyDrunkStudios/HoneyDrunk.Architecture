---
name: Documentation
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "infra", "security", "adr-0082", "wave-3"]
dependencies: ["work-item:01"]
adrs: ["ADR-0082", "ADR-0011", "ADR-0014", "ADR-0034", "ADR-0044", "ADR-0083", "ADR-0084"]
accepts: ADR-0082
wave: 3
initiative: adr-0082-node-standup
node: honeydrunk-architecture
---

# Chore: Author `infrastructure/walkthroughs/org-secret-repo-binding.md` — per-secret access-binding walkthrough mandated by ADR-0082 D8

## Summary

Author the org-secret repo-binding walkthrough at `infrastructure/walkthroughs/org-secret-repo-binding.md` per ADR-0082 D7 / D8. The walkthrough names the GitHub portal click-path (Settings → Secrets → Actions → {Secret name} → Repository access → Selected repositories → Add repositories) for each org Actions secret in the per-class matrix. This is the operational complement to ADR-0082 D6 invariant clause 10 — without this step, new repos consuming `pr-core.yml` hard-fail on `SONAR_TOKEN` lookup at first PR.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0082 D8 commits the *policy* — `Selected repositories` is the default access mode for live-credential org secrets, and adding a new repo to each secret's access list is a manual org-admin action that does NOT happen automatically when the repo is created. The Audit and Notify Cloud standups discovered this the hard way: the first non-bootstrap PR after scaffold failed because `SONAR_TOKEN` substituted as empty string, and `job-sonarcloud.yml` hard-failed on auth.

The walkthrough makes this step routine and click-path-explicit so every Phase B (per-class walkthroughs 02 / 03 / 04 / 05 / 06) can reference it as the single source for the binding flow rather than duplicating the portal steps.

## Proposed Implementation

### `infrastructure/walkthroughs/org-secret-repo-binding.md` — new walkthrough

```markdown
# Org-Secret Repo Binding (GitHub Portal)

**Applies to:** ADR-0082 D6 invariant clause 10, D7, D8.
**Companion docs:**
- `constitution/node-standup.md` (per-class binding matrix lives here)
- `infrastructure/walkthroughs/sonarcloud-organization-setup.md` (one-time `SONAR_TOKEN` org provisioning)
- Per-class standup walkthroughs (`node-standup-core-dotnet.md`, `node-standup-ops-deployable-dotnet.md`, `node-standup-meta-docs.md`, `node-standup-studios-typescript.md`) — Phase B references this walkthrough for the binding step.
**Related invariants:** {N1} clause 10 (org-secret repo binding before first non-bootstrap PR), 8 (secrets never in logs — applies to careless echo of secret VALUES, not the binding metadata).

## Goal

Bind a newly-created GitHub repo to every org Actions secret its workflows reference, so the secret values resolve at workflow-execution time instead of substituting as empty string (silent failure) or hard-failing (loud failure).

GitHub does NOT auto-propagate org Actions secrets with `Selected repositories` access policy. Per ADR-0082 D8, `Selected repositories` is the Grid default for every live-credential org secret. Adding a new repo to the access list is a manual org-admin action.

## Why this step is mandatory

Without the binding:
- `${{ secrets.SONAR_TOKEN }}` substitutes as empty string in a workflow run. The downstream tool (sonar-scanner) treats the empty string as "no token" and either hard-fails (loud) or skips its analysis stage with a misleading success (silent).
- `${{ secrets.NUGET_API_KEY }}` substitutes as empty string. `dotnet nuget push` rejects the empty key and hard-fails — loud but not immediately diagnostic ("authentication failed" without a hint that the secret isn't bound).
- Same pattern for every other org secret. The failure mode is unpredictable per tool — some tools fail loud, some fail silent.

The Grid invariant 102 clause 10 binds the *second* PR — the scaffold (bootstrap) PR can introduce CI workflow files that reference secrets even before binding; the binding must complete before any *feature* PR running those workflows.

## The three GitHub access-policy menu options

At `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions/{SECRET_NAME}`:

| Option | What it means | Grid stance per ADR-0082 D8 |
|---|---|---|
| **All repositories** | Every repo in the org (public + private) can consume. | Reserved for benign org constants only (currently dormant — the Grid uses `Directory.Build.props` for shared non-credential values). Promoting a live-credential secret to this requires an ADR amendment. |
| **Private repositories** | Only private/internal repos can consume; public repos cannot. | Used for org secrets that should never reach a public repo (rare; documented per-secret). |
| **Selected repositories** | Only the explicitly enumerated repos. | **Grid default for every live-credential org secret.** Adding a new repo is a manual click. |

## Step-by-step — bind one secret to one repo

**Portal Breadcrumb:** GitHub.com → `HoneyDrunkStudios` org → Settings → Secrets and variables → Actions → org secrets table → {Secret name} → Edit → Repository access section → Select repositories → search/add the new repo → Save.

1. Sign in to GitHub as an `HoneyDrunkStudios` org owner.
2. Open `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions`.
3. In the **Organization secrets** table, click the secret name (e.g., `SONAR_TOKEN`).
4. Confirm the **Repository access** dropdown reads "Selected repositories" (this is the Grid default). If it does not, **stop** — do not edit. The access policy change requires the ADR amendment per ADR-0082 D8. Report to the operator.
5. Under "Repository access", click **Select repositories**.
6. In the popover, type the new repo's name (e.g., `HoneyDrunk.Audit`).
7. Select the repo from the autocomplete results.
8. Click **Save changes**.
9. The new repo now appears in the list under the secret. The secret value will resolve in any of that repo's workflow runs that reference `${{ secrets.{SECRET_NAME} }}`.

Repeat for every secret in the new repo's binding set (see Per-class matrix below, or `constitution/node-standup.md`'s authoritative copy).

## Per-class binding set (snapshot)

The authoritative per-class matrix lives in `constitution/node-standup.md`. Reproduce here only for quick reference; if this section drifts from `constitution/node-standup.md`, the latter wins.

- **Every Node consuming `pr-core.yml`** (so all classes except AI Seed):
  - `SONAR_TOKEN` — required by `job-sonarcloud.yml` for public repos (ADR-0011 D11). For private repos that drop `job-sonarcloud` from `pr.yml`, this secret is not consumed and not required.
- **Core .NET classes shipping packages** (Abstractions+Runtime, Runtime-only, Ops Deployable .NET when shipping Abstractions):
  - `NUGET_API_KEY` — required by `release.yml` for nuget.org publishing (ADR-0034).
- **Ops Deployable .NET emitting operator-actionable events** (ADR-0084):
  - One or more of `DISCORD_WEBHOOK_OPS_ALERTS`, `DISCORD_WEBHOOK_SECURITY`, `DISCORD_WEBHOOK_AGENT_ACTIVITY`, `DISCORD_WEBHOOK_HIVE_ACTIVITY`, `DISCORD_WEBHOOK_RELEASE`, `DISCORD_WEBHOOK_ANNOUNCEMENTS`, `DISCORD_WEBHOOK_AUDIT_SENSITIVE` — per which channels the Node emits to.
- **Any Node participating in cross-repo issue / label / project automation** (ADR-0014 hive-sync):
  - `LABELS_FANOUT_PAT`, `HIVE_FIELD_MIRROR_TOKEN`, `HIVE_APP_ID`, `HIVE_APP_PRIVATE_KEY`.
- **Any Node whose `.honeydrunk-review.yaml` has `enabled: true` and posts review results upstream** (ADR-0044):
  - `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`.
- **TypeScript SDK packages** (per the Studios/TypeScript walkthrough Phase B):
  - `NPM_TOKEN` (or OIDC-trusted-publishing equivalent once the org adopts it).

This snapshot is dated 2026-05-25. Future org-secret-inventory passes (ADR-0083 D5/D6) extend `constitution/node-standup.md`'s matrix; that update flows here at next walkthrough revision.

## Verification

After binding, the operator does NOT need to re-run any CI. The next workflow run referencing the secret will pick it up automatically (org-secret access policy changes are effective immediately for new runs).

To verify a binding without waiting for a feature PR:
1. Open any in-progress or recent PR on the new repo (or open a one-line whitespace PR if none exist yet, then close it).
2. Re-run the affected workflow job.
3. The previously-empty-string secret now resolves to its real value; the tool stage that was hard-failing or silently skipping now runs.

## What this walkthrough does NOT cover

- **Creating a new org secret.** That is a separate per-secret one-time provisioning (e.g., `sonarcloud-organization-setup.md` for `SONAR_TOKEN`). This walkthrough binds *existing* org secrets to new repos.
- **Rotating an org secret.** Rotation is ADR-0006-tier-2 territory; the secret value changes but the repo binding stays the same.
- **Per-environment secrets at the repo level.** Per-environment secrets have their own access controls and are out of scope per ADR-0082 D8 — this walkthrough is the org-level Actions-secrets surface only.
- **Promoting a secret from `Selected repositories` to `All repositories`.** That requires an ADR amendment per ADR-0082 D8; this walkthrough explicitly does not document the promotion flow.
```

## Affected Files

- `infrastructure/walkthroughs/org-secret-repo-binding.md` (new)

## NuGet Dependencies

None.

## Boundary Check

- [x] All edits in `HoneyDrunk.Architecture`.

## Acceptance Criteria

- [ ] `infrastructure/walkthroughs/org-secret-repo-binding.md` exists with the structure above
- [ ] "Why this step is mandatory" section names the silent-vs-loud failure modes (empty-string substitution; tool-specific hard-fail variability)
- [ ] The three access-policy menu options (All / Private / Selected) are tabled with the Grid stance per ADR-0082 D8
- [ ] Step-by-step click-path is portal-explicit (URL → Settings → Secrets and variables → Actions → secret name → Edit → Repository access → Select repositories → Save)
- [ ] Per-class binding-set snapshot matches `constitution/node-standup.md` (packet 01) — same secrets, same conditions; if the two drift, `constitution/node-standup.md` wins
- [ ] Verification section names how to confirm a binding works without waiting for a feature PR
- [ ] "What this walkthrough does NOT cover" section is explicit (creating secrets, rotation, per-environment secrets, promoting Selected → All)
- [ ] Companion docs link `constitution/node-standup.md`, `sonarcloud-organization-setup.md`, and the five per-class standup walkthroughs
- [ ] Stop-condition is named — if the access dropdown reads anything other than "Selected repositories", the agent stops and reports to the operator (do not silently switch policy)
- [ ] Repo-level `CHANGELOG.md` updated for the new walkthrough

## Human Prerequisites

None for the walkthrough authoring itself. (The walkthrough *describes* a human portal step — the binding action itself can only be performed by an org owner. Future standup packets that reference this walkthrough have the binding as their Human Prerequisite.)

## Referenced ADR Decisions

**ADR-0082 D6 invariant clause 10** — Org-secret binding mandatory before first non-bootstrap PR.
**ADR-0082 D7** — Walkthrough unlocked by acceptance.
**ADR-0082 D8** — `Selected repositories` is the Grid default; promotion to `All repositories` requires ADR amendment.
**ADR-0011 D11** — `SONAR_TOKEN` minimum requirement for every Node consuming `pr-core.yml`.
**ADR-0014** — Hive-sync stack secrets (`LABELS_FANOUT_PAT`, `HIVE_FIELD_MIRROR_TOKEN`, `HIVE_APP_ID`, `HIVE_APP_PRIVATE_KEY`).
**ADR-0034** — `NUGET_API_KEY` for NuGet-publishing Nodes.
**ADR-0044** — `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` for review-pipeline upstream emission.
**ADR-0083 D5/D6** — Future org-secret-inventory passes update the matrix in `constitution/node-standup.md`; this walkthrough re-syncs its snapshot accordingly.
**ADR-0084** — Discord operator-alert webhook stack.

## Constraints

- **Authoritative snapshot lives in `constitution/node-standup.md`.** This walkthrough's matrix reproduces for convenience; on drift, `constitution/node-standup.md` wins and this walkthrough is updated.
- **Stop-condition on unexpected access policy.** If the dropdown does not read "Selected repositories", the agent stops — does NOT silently change the policy. ADR-0082 D8 reserves access-mode changes for ADR amendments.
- **Snapshot is dated.** The walkthrough notes 2026-05-25 as the snapshot date and ADR-0083 D5/D6 inventory passes as the update source.
- **No new secret creation.** The walkthrough binds existing secrets; new-secret provisioning is per-secret (e.g., `sonarcloud-organization-setup.md`).
- **PR body metadata.** Strict `Authorship: <enum>` + exactly one of `Work Item:` / `Out-of-band reason:`.

## Labels

`chore`, `tier-2`, `meta`, `docs`, `infra`, `security`, `adr-0082`, `wave-3`

## Agent Handoff

**Objective:** Author `infrastructure/walkthroughs/org-secret-repo-binding.md` — the portal click-path for binding a new repo to existing org Actions secrets, mandated by ADR-0082 D8 and invariant 102 clause 10.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Close the most common Phase B drift channel — the new repo's first non-bootstrap PR failing because `SONAR_TOKEN` (or another org secret) substitutes as empty string.
- Feature: ADR-0082 Canonical Node Standup Procedure, Wave 3.
- ADRs: ADR-0082 (D6, D7, D8), ADR-0011 D11, ADR-0014, ADR-0034, ADR-0044, ADR-0083 D5/D6, ADR-0084.

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 (canonical procedure doc — the authoritative matrix lives there).

**Constraints:**
- Per-class matrix reproduces for convenience; `constitution/node-standup.md` is authoritative on drift.
- Stop-condition on unexpected access policy — no silent policy change.
- Snapshot is dated 2026-05-25.
- No new-secret-creation guidance — those are per-secret walkthroughs.
- PR body carries strict `Authorship: <enum>` + exactly one of `Work Item:` / `Out-of-band reason:`.

**Key Files:**
- `infrastructure/walkthroughs/org-secret-repo-binding.md` (new)

**Contracts:** None changed.
