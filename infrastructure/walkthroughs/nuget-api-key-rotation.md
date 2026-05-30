# Rotating `NUGET_API_KEY`

NuGet.org caps Personal API Keys at **365 days** for keys created in recent years. This walkthrough rotates `NUGET_API_KEY` before it expires. Per ADR-0083 D4.

> **What breaks if you forget:** every NuGet-shipping Node's `release.yml` silently fails to publish — breaking the ADR-0034 publishing pipeline Grid-wide and stalling downstream package restore. Highest blast radius after `SONAR_TOKEN`.

## Prerequisites and identity

Log in as the **nuget.org account** that owns the current key. The key is scoped to the `HoneyDrunk.*` package glob.

## Steps

1. **Portal breadcrumb.** Log in at https://www.nuget.org → avatar → **API Keys** (https://www.nuget.org/account/apikeys).
2. **Create the replacement key.** Click **Create**:
   - **Key Name:** `honeydrunk-grid-publish-{YYYY-MM-DD}` (dated name for readable history).
   - **Package Owner:** `HoneyDrunkStudios`.
   - **Scopes:** **Push** → *Push new packages and package versions* (match the existing key's scopes; do not over-grant).
   - **Glob Pattern:** `HoneyDrunk.*` (match the existing key's glob).
   - **Expiration:** the maximum NuGet.org allows (365 days).

   Click **Create** and **immediately copy the new key value** — NuGet.org will not show it again.
3. **Paste into the GitHub org secret.** https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions → `NUGET_API_KEY` → **Update** → paste → **Save**.
4. **Verify.** Trigger a publish: either wait for the next real `release.yml` run, or run a no-op publish smoke test against a pre-release version. Confirm the `dotnet nuget push` step authenticates (a 403 in the logs means the new key didn't save or lacks the right glob/scope — repeat steps 2–3).
5. **Delete the old key — only after step 4 succeeds.** https://www.nuget.org/account/apikeys → find the **previous** dated key → **Delete**. Never delete before verification.
6. **Close the standing rotation issue.** Open issue in `HoneyDrunk.Architecture` labeled `external-credential-rotation` titled `[Rotate] NUGET_API_KEY — expires {previous-date}` → comment with the new date → **Close**.
7. **Open the next standing issue.** New issue `[Rotate] NUGET_API_KEY — expires {new-date}`, labeled `external-credential-rotation`, body linking this walkthrough + the inventory row.
8. **Update the inventory row.** Edit `infrastructure/reference/sensitive-inventory.md` → `NUGET_API_KEY` row → set `Current Expiration` to the new date. Commit + PR.

## Cross-references

- [`../reference/sensitive-inventory.md`](../reference/sensitive-inventory.md) — the `NUGET_API_KEY` row.
- ADR-0034 — the public package distribution pipeline `NUGET_API_KEY` gates.
- ADR-0083 D4 — the rotation-walkthrough convention this file implements.
