# Rotating GitHub fine-grained PATs

Covers the Grid's fine-grained GitHub Personal Access Tokens — today `GH_ISSUE_TOKEN`, `HIVE_FIELD_MIRROR_TOKEN`, and `LABELS_FANOUT_PAT` (and any future fine-grained PAT not replaced by a GitHub App). Fine-grained PATs expire at up to **366 days**. Per ADR-0083 D4.

> **What breaks if you forget:** depends on the token — `GH_ISSUE_TOKEN` expiry breaks cross-repo issue automation **and** the `external-credentials-check.yml` drift workflow itself (it reuses this token); `HIVE_FIELD_MIRROR_TOKEN` breaks the Hive field-mirror fallback; `LABELS_FANOUT_PAT` breaks Grid-wide label seeding.

## Prerequisites and identity

Log in as the GitHub user that owns the PAT (oleg). Fine-grained PATs are per-user, scoped to specific repos and permissions.

## Steps (repeat per token)

1. **Portal breadcrumb.** GitHub → your avatar → **Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens** (https://github.com/settings/tokens?type=beta).
2. **Identify the token.** Find the entry whose name matches the secret being rotated (e.g. a token named for `GH_ISSUE_TOKEN`'s purpose). Note its **Resource owner** (`HoneyDrunkStudios`), **Repository access**, and **Permissions** — you'll match them exactly.
3. **Regenerate or recreate.**
   - Easiest: open the token → **Regenerate token** → set a new expiration (max 366 days) → **Regenerate**. This keeps the same scopes.
   - Or create a new fine-grained token with **identical** Resource owner, Repository access, and Permissions; delete the old one after verification.

   **Immediately copy the new value** — GitHub will not show it again.
4. **Paste into the destination secret.** Org secret: https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions → the matching secret name → **Update** → paste → **Save**. (If the token backs a repo-level secret instead, update that repo's secret.)
5. **Smoke-test.** Trigger the consuming workflow (e.g. `seed-labels-fanout.yml` for `LABELS_FANOUT_PAT`, a file-issues run for `GH_ISSUE_TOKEN`) via `workflow_dispatch` or its normal trigger. Confirm it authenticates (a 401/403 in the logs means the new value didn't save or the scopes changed — re-check steps 3–4).
6. **Delete the old token — only after step 5 succeeds** (if you created a new one rather than regenerating in place).
7. **Close the standing rotation issue.** Open issue in `HoneyDrunk.Architecture` labeled `external-credential-rotation` titled `[Rotate] {TOKEN_NAME} — expires {previous-date}` → comment with the new date → **Close**.
8. **Open the next standing issue.** New issue `[Rotate] {TOKEN_NAME} — expires {new-date}`, labeled `external-credential-rotation`, body linking this walkthrough + the inventory row.
9. **Update the inventory row.** Edit `infrastructure/reference/sensitive-inventory.md` → the token's row → set `Current Expiration` to the new date. Commit + PR.

> **Note on `GH_ISSUE_TOKEN`:** because `external-credentials-check.yml` reuses this token, rotating it keeps the drift-detection workflow itself alive (the "watcher who watches the watcher"). Prioritize it.

## Cross-references

- [`../reference/sensitive-inventory.md`](../reference/sensitive-inventory.md) — the `GH_ISSUE_TOKEN` / `HIVE_FIELD_MIRROR_TOKEN` / `LABELS_FANOUT_PAT` rows.
- ADR-0083 D4 — the rotation-walkthrough convention this file implements.
