# Rotating `NUGET_API_KEY`

NuGet.org caps Personal API Keys at **365 days** for keys created in recent years. This walkthrough rotates `NUGET_API_KEY` before it expires. Per [ADR-0083](../../adrs/ADR-0083-external-saas-credential-rotation.md) D4.

> **What breaks if you forget:** every NuGet-shipping Node's `release.yml` silently fails to publish on its first invocation after expiry. The publish step's failure is loud (the workflow fails), but the cascading effect — **downstream package restore stalls** when consumers can't pull the new version — is the slow-burn failure that matters most. The scheduled `external-credentials-check.yml` workflow (ADR-0083 D5) mitigates this with T-30 / T-7 / T+0 escalation.

## Steps

1. **Prerequisites and identity.** Log in as the **NuGet.org admin** whose account owns the current `NUGET_API_KEY`. The key is bound to the user account, not to an org principal — NuGet.org's permission model uses package-owner-list membership, not first-class orgs, for API-key issuance.
2. **Portal breadcrumb.** Log in at https://www.nuget.org → click the username (top-right) → **API Keys** (or go directly to https://www.nuget.org/account/apikeys).
3. **Identify the existing key.** The current key is named something descriptive (`honeydrunk-grid-publish` or similar). The API Keys page lists each key with scope, expiration, and last-used date. Confirm the current production key by cross-referencing the GitHub org secret's last-updated date (GitHub → Org → Settings → Secrets and variables → Actions → `NUGET_API_KEY`).
4. **Generate the replacement key.** Click **Create**:
   - **Key Name:** `honeydrunk-grid-publish-{YYYY-MM-DD}` (today's date).
   - **Expires In:** the maximum NuGet.org allows (**365 days**).
   - **Package Owner:** the nuget.org account holding the `HoneyDrunk.*` namespace.
   - **Scopes:** **Push** (match the existing key's scopes exactly).
   - **Glob Pattern:** `HoneyDrunk.*` (match the existing key's glob — pushing without one over-scopes).

   Click **Create** and **immediately copy the new value**. NuGet.org will not show it again.
5. **Paste into the GitHub org secret.** https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions → `NUGET_API_KEY` → **Update** → paste → **Save**.
6. **Verify — smoke-test against a release.**
   - **Preferred:** wait for the next scheduled `release.yml` invocation (any Node's tag push triggers one) and confirm the publish step succeeds (a bad key returns 401).
   - **Fallback:** manually trigger `release.yml` on a Node already at a recent version — the publish step is idempotent (returns a benign "already exists", not a 401). Confirm no auth error.
7. **Delete the old key — only after step 6 succeeds.** NuGet.org → API Keys → the **previous** dated key → **Delete**. Deletion is immediate and irreversible; **never delete before verification.**
8. **Close the standing rotation issue.** Open issue in `HoneyDrunk.Architecture` labeled `external-credential-rotation` titled `[Rotate] NUGET_API_KEY — expires {previous-date}` → comment with the new date + a link to the API Keys page → **Close**.
9. **Open the next standing issue.** New issue `[Rotate] NUGET_API_KEY — expires {new-date}` (365 days out), labeled `external-credential-rotation`, body linking this walkthrough + the inventory row.
10. **Update the inventory row.** Edit `infrastructure/reference/sensitive-inventory.md` → `NUGET_API_KEY` row → set `Current Expiration` to the new date. Commit + PR.

## Why this is not automated

NuGet.org *does* expose an API for key management (`nuget.org/api/...`), so automated rotation is technically possible. ADR-0083 **D1** rules it out on cost grounds: at solo-developer scale with fewer than ten external-SaaS credentials, a per-provider rotation Node — each provider with its own auth model, rate limits, and deprecation cadence — costs more to build and maintain than manual rotation with a disciplined inventory plus the cheap drift-detection workflow. Re-evaluate if the active rotation-needing-credential count exceeds ten.

## Cross-references

- [`../reference/sensitive-inventory.md`](../reference/sensitive-inventory.md) — the `NUGET_API_KEY` row.
- [ADR-0034](../../adrs/ADR-0034-public-package-distribution-and-nuget-policy.md) — the public-package-distribution pipeline `NUGET_API_KEY` gates.
- [ADR-0083](../../adrs/ADR-0083-external-saas-credential-rotation.md) D4 — the rotation-walkthrough convention this implements.
