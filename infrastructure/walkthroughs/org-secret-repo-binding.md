# Org-Secret Repo Binding (GitHub Portal)

**Applies to:** ADR-0082 D6 invariant clause 10, D7, D8.
**Companion docs:**
- `constitution/node-standup.md` (the per-class binding matrix lives there — authoritative on drift)
- `infrastructure/walkthroughs/sonarcloud-organization-setup.md` (one-time `SONAR_TOKEN` org provisioning)
- The per-class standup walkthroughs (`node-standup-core-dotnet.md`, `node-standup-ops-deployable-dotnet.md`, `node-standup-meta-docs.md`, `node-standup-studios-typescript.md`) — each Phase B references this walkthrough for the binding step.
**Related invariants:** 102 clause 10 (org-secret repo binding before the first non-bootstrap PR), 8 (secret values never appear in logs — applies to careless echo of secret *values*, not to the binding metadata).

## Goal

Bind a newly-created GitHub repo to every org Actions secret its workflows reference, so the secret values resolve at workflow-execution time instead of substituting as empty string (silent failure) or hard-failing (loud failure).

GitHub does **not** auto-propagate org Actions secrets with the `Selected repositories` access policy. Per ADR-0082 D8, `Selected repositories` is the Grid default for every live-credential org secret. Adding a new repo to the access list is a manual org-admin action.

## Why this step is mandatory

Without the binding:

- `${{ secrets.SONAR_TOKEN }}` substitutes as empty string in a workflow run. The downstream tool (sonar-scanner) treats the empty string as "no token" and either hard-fails (loud) or skips its analysis stage with a misleading success (silent).
- `${{ secrets.NUGET_API_KEY }}` substitutes as empty string. `dotnet nuget push` rejects the empty key and hard-fails — loud, but not immediately diagnostic ("authentication failed" with no hint that the secret is unbound).
- The same pattern applies to every other org secret. The failure mode is unpredictable per tool — some fail loud, some fail silent.

Invariant 102 clause 10 binds the *second* PR — the scaffold (bootstrap) PR may introduce CI workflow files that reference secrets even before binding; the binding must complete before any *feature* PR runs those workflows.

## The three GitHub access-policy menu options

At `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions/{SECRET_NAME}`:

| Option | What it means | Grid stance per ADR-0082 D8 |
|---|---|---|
| **All repositories** | Every repo in the org (public + private) can consume. | Reserved for benign org constants only (currently dormant — the Grid uses `Directory.Build.props` for shared non-credential values). Promoting a live-credential secret to this requires an ADR amendment. |
| **Private repositories** | Only private/internal repos can consume; public repos cannot. | Used for org secrets that should never reach a public repo (rare; documented per-secret). |
| **Selected repositories** | Only the explicitly enumerated repos. | **Grid default for every live-credential org secret.** Adding a new repo is a manual click. |

## Step-by-step — bind one secret to one repo

**Portal breadcrumb:** GitHub.com → `HoneyDrunkStudios` org → Settings → Secrets and variables → Actions → org secrets table → {Secret name} → Edit → Repository access section → Selected repositories → search/add the new repo → Save.

1. Sign in to GitHub as an `HoneyDrunkStudios` org owner.
2. Open `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions`.
3. In the **Organization secrets** table, click the secret name (e.g. `SONAR_TOKEN`).
4. Confirm the **Repository access** dropdown reads "Selected repositories" (the Grid default). **If it reads anything else, stop — do not edit.** Changing the access policy requires the ADR amendment per ADR-0082 D8. Report to the operator.
5. Under "Repository access", click **Select repositories**.
6. In the popover, type the new repo's name (e.g. `HoneyDrunk.Audit`).
7. Select the repo from the autocomplete results.
8. Click **Save changes**.
9. The new repo now appears in the list under the secret. The value will resolve in any of that repo's workflow runs that reference `${{ secrets.{SECRET_NAME} }}`.

Repeat for every secret in the new repo's binding set (see the per-class set below, or the authoritative copy in `constitution/node-standup.md`).

## Per-class binding set (snapshot)

The authoritative per-class matrix lives in `constitution/node-standup.md`. Reproduced here only for quick reference; **if this section drifts from `constitution/node-standup.md`, the latter wins.**

- **Every Node consuming `pr-core.yml`** (so all classes except AI Seed):
  - `SONAR_TOKEN` — required by `job-sonarcloud.yml` for public repos (ADR-0011 D11). For private repos that drop `job-sonarcloud` from `pr.yml`, this secret is not consumed and not required.
- **Core .NET classes shipping packages** (Abstractions+Runtime, Runtime-only, Ops Deployable .NET when shipping Abstractions):
  - `NUGET_API_KEY` — required by `release.yml` for nuget.org publishing (ADR-0034).
- **Ops Deployable .NET emitting operator-actionable events** (ADR-0084):
  - one or more of `DISCORD_WEBHOOK_OPS_ALERTS`, `DISCORD_WEBHOOK_SECURITY`, `DISCORD_WEBHOOK_AGENT_ACTIVITY`, `DISCORD_WEBHOOK_HIVE_ACTIVITY`, `DISCORD_WEBHOOK_RELEASE`, `DISCORD_WEBHOOK_ANNOUNCEMENTS`, `DISCORD_WEBHOOK_AUDIT_SENSITIVE` — per which channels the Node emits to.
- **Any Node participating in cross-repo issue / label / project automation** (ADR-0014 hive-sync):
  - `LABELS_FANOUT_PAT`, `HIVE_FIELD_MIRROR_TOKEN`, `HIVE_APP_ID`, `HIVE_APP_PRIVATE_KEY`.
- **TypeScript SDK packages** (per the Studios/TypeScript walkthrough Phase B):
  - `NPM_TOKEN` (or the OIDC-trusted-publishing equivalent once the org adopts it).

This snapshot is dated **2026-06-02**. Future org-secret-inventory passes (ADR-0083 D5/D6) extend the matrix in `constitution/node-standup.md`; that update flows here at the next walkthrough revision.

## Verification

After binding, the operator does **not** need to re-run any CI for the policy change itself — org-secret access-policy changes are effective immediately for new runs.

To verify a binding without waiting for a feature PR:

1. Open any in-progress or recent PR on the new repo (or open a one-line whitespace PR if none exist yet, then close it).
2. Re-run the affected workflow job.
3. The previously-empty-string secret now resolves to its real value; the tool stage that was hard-failing or silently skipping now runs.

## What this walkthrough does NOT cover

- **Creating a new org secret.** That is a separate per-secret one-time provisioning (e.g. `sonarcloud-organization-setup.md` for `SONAR_TOKEN`). This walkthrough binds *existing* org secrets to new repos.
- **Rotating an org secret.** Rotation is ADR-0006 Tier-2 territory; the secret value changes but the repo binding stays the same.
- **Per-environment secrets at the repo level.** Per-environment secrets have their own access controls and are out of scope per ADR-0082 D8 — this walkthrough is the org-level Actions-secrets surface only.
- **Promoting a secret from `Selected repositories` to `All repositories`.** That requires an ADR amendment per ADR-0082 D8; this walkthrough explicitly does not document the promotion flow.
