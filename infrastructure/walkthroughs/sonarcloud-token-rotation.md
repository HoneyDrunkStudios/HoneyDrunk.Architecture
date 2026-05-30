# Rotating `SONAR_TOKEN`

The SonarQube Cloud free plan caps Personal Access Tokens at **60 days** with no UI to extend. This walkthrough rotates `SONAR_TOKEN` before it expires. Per ADR-0083 D4.

> **What breaks if you forget:** a missed rotation produces a **silent CI degradation** — SonarCloud's check just stops posting on PRs, which you might not notice for days or weeks (ADR-0083 §Context). The scheduled `external-credentials-check.yml` workflow (ADR-0083 D5) mitigates this by nagging at T-30 / T-7 / T+0, but the rotation itself is manual.

## Prerequisites and identity

You must be logged in as the **SonarCloud org-admin user account** that owns the current `SONAR_TOKEN`. The PAT is bound to the user, not the organization — rotating away from the original admin is a separate setup flow (`sonarcloud-organization-setup.md`), not this walkthrough.

## Steps

1. **Portal breadcrumb.** Log in at https://sonarcloud.io → click your avatar (top-right) → **My Account** → **Security** tab.
2. **Identify the existing token.** The Security tab lists all PATs with issuance and expiration dates. Confirm which is the current production token by cross-referencing the GitHub org secret's last-updated date (GitHub → Org → Settings → Secrets and variables → Actions → `SONAR_TOKEN`).
3. **Generate the replacement token.** In the same Security tab, generate a new token:
   - **Name:** `honeydrunk-grid-ci-{YYYY-MM-DD}` (today's date — the dated name makes rotation history readable from the Security tab alone).
   - **Type:** User Token (matching the existing token's type).
   - **Expiration:** the **maximum the free plan allows** (60 days as of writing).
   - **Scopes:** match the existing token's scopes; do not over-grant.

   Click **Generate** and **immediately copy the new value** — SonarCloud will not show it again.
4. **Paste into the GitHub org secret.** https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions → `SONAR_TOKEN` → **Update** → paste → **Save**.
5. **Verify (non-destructive).** Open the most recent non-draft PR on any public repo (one with `.honeydrunk-review.yaml` `enabled: true`) and **Re-run failed jobs**, or push a trivial empty commit. Confirm the SonarCloud check posts within the usual 5–10 minutes. **Pass, Fail-with-findings, or Pending all mean the token authenticated.** A 401-shaped failure in the SonarCloud step logs means the new value didn't save — repeat step 4.
6. **Revoke the old token — only after step 5 succeeds.** SonarCloud → My Account → Security → find the **previous** dated token → **Revoke**. Revocation is immediate and irreversible; **never revoke before verification.**
7. **Close the standing rotation issue.** Find the open issue in `HoneyDrunk.Architecture` labeled `external-credential-rotation` titled `[Rotate] SONAR_TOKEN — expires {previous-date}`. Comment with the new expiration date + a link to the SonarCloud Security tab, then **Close** it.
8. **Open the next standing issue.** Create a new issue titled `[Rotate] SONAR_TOKEN — expires {new-date}` (the 60-day-out date), labeled `external-credential-rotation`, body linking this walkthrough and the inventory row. `external-credentials-check.yml` picks up the new date on its next run and adds `urgent` / `imminent` comments at T-30 / T-7.
9. **Update the inventory row.** Edit `infrastructure/reference/sensitive-inventory.md` → `SONAR_TOKEN` row → set `Current Expiration` to the new date. Commit + PR.

## Cross-references

- [`sonarcloud-organization-setup.md`](./sonarcloud-organization-setup.md) — initial one-time org onboarding (out of scope here).
- [`../reference/sensitive-inventory.md`](../reference/sensitive-inventory.md) — the `SONAR_TOKEN` row.
- ADR-0011 — the static-analysis surface `SONAR_TOKEN` gates.
- ADR-0083 D4 — the rotation-walkthrough convention this file implements.
