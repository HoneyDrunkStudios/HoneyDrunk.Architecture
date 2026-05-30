# Rotating GitHub fine-grained PATs

Covers the Grid's fine-grained GitHub Personal Access Tokens. Fine-grained PATs expire at up to **366 days**. Per [ADR-0083](../../adrs/ADR-0083-external-saas-credential-rotation.md) D4.

## Which token?

| Token | Destination | Smoke-test |
|-------|-------------|-----------|
| `GH_ISSUE_TOKEN` | GitHub org secret in `HoneyDrunkStudios` (Settings → Secrets and variables → Actions) | `file-packets.yml` triggers via a packet-manifest push; its `gh issue create` call returns 401 on a bad token. Also reused by `external-credentials-check.yml`. |
| `HIVE_FIELD_MIRROR_TOKEN` | GitHub org secret in `HoneyDrunkStudios` | `hive-field-mirror.yml` scheduled run or manual `workflow_dispatch`; the GraphQL field-update call returns 401 on a bad token |
| `LABELS_FANOUT_PAT` | GitHub org secret in `HoneyDrunkStudios` | `seed-labels-fanout.yml` manual `workflow_dispatch` against one repo; the label-creation call returns 401 on a bad token |
| `INITIATIVES_SYNC_TOKEN` | GitHub org secret in `HoneyDrunkStudios` | the `hive-sync` reconciliation run (per ADR-0014); a cross-repo API call returns 401 on a bad token — *verify exact consumers* |
| `GRID_HEALTH_PAT` | GitHub org secret in `HoneyDrunkStudios` | the grid-health aggregator run (ADR-0012 D6); a cross-repo workflow-state poll returns 401 on a bad token — *verify exact consumers* |

(Any future fine-grained PAT not yet replaced by a GitHub App uses the same procedure.)

## Steps (repeat per token)

1. **Prerequisites and identity.** Log in to GitHub as the user (@tatteddev) whose account owns the PAT. Fine-grained PATs are bound to a user; the org secret holds the value, but the token belongs to a person.
2. **Portal breadcrumb.** https://github.com → avatar → **Settings** → **Developer settings** (bottom of the left sidebar) → **Personal access tokens** → **Fine-grained tokens** (https://github.com/settings/tokens?type=beta).
3. **Identify the existing token.** The page lists each fine-grained PAT with name, expiration, and resource owner (must be `HoneyDrunkStudios`). Match the name and resource-owner scope to the secret being rotated.
4. **Regenerate the replacement token.**
   - **Preferred — Regenerate in place:** open the token → **Regenerate token** → choose the maximum expiration (**366 days**) → confirm. GitHub mints a new value for the same token entity, preserving the name and every scope setting exactly.
   - **Alternative — Create new with the same scopes:** if regenerate isn't available, **Generate new token** matching the existing token's resource owner, repository access, repository permissions, organization permissions, and expiration **exactly**. More error-prone; prefer regenerate.

   Either way, **immediately copy the new value**. GitHub will not show it again.
5. **Paste into the destination.** All current PATs target `HoneyDrunkStudios` org secrets — Settings → Secrets and variables → Actions → the secret name → **Update** → paste → **Save**. (A future repo-level secret: that repo's Settings → Secrets and variables → Actions.)
6. **Verify — smoke-test per token.** Use the smoke-test from the "Which token?" table above. It is non-destructive (an empty packet-manifest push, a manual `workflow_dispatch`, or a re-run of a recent job). A 401 in the smoke-test logs means the new value didn't save — repeat step 5.
7. **Revoke the previous token — gated on step 6.** If step 4 used **Regenerate in place**, the old value was invalidated automatically — no separate revoke needed. If step 4 used **Create new**, return to the Fine-grained tokens page and **Revoke** the old token by name only after verification succeeds.
8. **Close the standing rotation issue.** Open issue in `HoneyDrunk.Architecture` labeled `external-credential-rotation` titled `[Rotate] {token-name} — expires {previous-date}` → comment with the new date + a link to the Fine-grained tokens page → **Close**.
9. **Open the next standing issue.** New issue `[Rotate] {token-name} — expires {new-date}` (366 days out), labeled `external-credential-rotation`, body linking this walkthrough + the inventory row.
10. **Update the inventory row.** Edit `infrastructure/reference/sensitive-inventory.md` → the `{token-name}` row → set `Current Expiration` to the new date. Commit + PR.

## What breaks if you forget

- **`GH_ISSUE_TOKEN`** — `file-packets.yml` can no longer file new issues from packets in `generated/issue-packets/active/`; packet filing stalls and The Hive misses new items (ADR-0008). **And** `external-credentials-check.yml` itself stops (it reuses this token) — the "watcher who watches the watcher" hole. Prioritize this one.
- **`HIVE_FIELD_MIRROR_TOKEN`** — `hive-field-mirror.yml`'s fallback path stops mirroring custom-field updates to The Hive (the GitHub App primary path may still work; the fallback hedges against the App being down/rate-limited per ADR-0014).
- **`LABELS_FANOUT_PAT`** — `seed-labels-fanout.yml` can no longer apply label-set updates across repos; repos drift from the canonical label set.
- **`INITIATIVES_SYNC_TOKEN`** — `hive-sync` reconciliation across repos breaks (verify exact consumers).
- **`GRID_HEALTH_PAT`** — grid-health aggregation across repos breaks (verify exact consumers).

## PAT-vs-GitHub-App

Per [ADR-0044](../../adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md)'s migration, every PAT here is a candidate for replacement by a **GitHub App** (cleaner identity binding, fine-grained per-installation permissions, no user-account expiration cap). When a PAT's destination workflow migrates to a GitHub App, its inventory row is **deleted** (not rotated to a longer cadence) and its standing rotation issue is closed with a `wontfix` label. **Do not delete this walkthrough** — future PATs that arise during incident response or before App migration completes reuse the same procedure.

## Cross-references

- [`../reference/sensitive-inventory.md`](../reference/sensitive-inventory.md) — the PAT rows.
- [ADR-0014](../../adrs/ADR-0014-hive-architecture-reconciliation-agent.md) — the GitHub App migration that eventually retires `HIVE_FIELD_MIRROR_TOKEN` / `INITIATIVES_SYNC_TOKEN`.
- [ADR-0044](../../adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) — the GitHub App migration that retires the OpenClaw fallback PAT eventually.
- [ADR-0083](../../adrs/ADR-0083-external-saas-credential-rotation.md) D4 — the rotation-walkthrough convention this implements.
