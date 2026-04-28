# HoneyDrunk Hive GitHub App (GitHub Portal)

**Applies to:** ADR-0008 (Packet Lifecycle), ADR-0012 (Actions as CI/CD Control Plane).
**Related Actions issue:** HoneyDrunkStudios/HoneyDrunk.Actions#57.

## Goal

Provision a dedicated GitHub App that mints scoped installation tokens for the file-packets reusable workflow. Replaces the developer's PAT (`HIVE_FIELD_MIRROR_TOKEN`) so the workflow's GraphQL quota is independent of interactive `gh` activity.

## Portal Breadcrumb

**GitHub → Org Settings → Developer Settings → GitHub Apps → New GitHub App**

## Step-by-step

### 1. Create the App

1. Open the org settings, then **Developer Settings → GitHub Apps → New GitHub App**.
2. Fill in:
   - **GitHub App name:** `HoneyDrunk Hive`
   - **Description:** brief one-liner naming the App's purpose (the file-packets workflow uses this App to file issues, mirror The Hive board, and commit the manifest).
   - **Homepage URL:** `https://github.com/HoneyDrunkStudios`
   - **Callback URL:** leave empty.
   - **Setup URL:** leave empty.
3. **Webhook → Active:** **uncheck**. The App is invoked from Actions only, no webhook needed. No webhook URL or secret to provide.
4. **Repository permissions** — select these three; everything else stays *No access*:
   - `Issues`: **Read and write** (file issues + post `Blocked by` comments)
   - `Metadata`: **Read-only** (mandatory; auto-selected)
   - `Contents`: **Read and write** (commit `filed-packets.json` back to Architecture)
5. **Organization permissions:**
   - `Projects`: **Read and write** (mirror The Hive custom fields)
6. **Where can this GitHub App be installed:** **Only on this account** (`HoneyDrunkStudios`).
7. Click **Create GitHub App**.

### 2. Generate the private key

1. On the App's settings page, scroll to **Private keys** → **Generate a private key**.
2. The browser downloads a `.pem` file. Open it as text and copy the entire contents — the `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----` lines plus everything between them.
3. Note the **App ID** at the top of the settings page (a 6–7 digit integer).

The `.pem` on disk is the only copy GitHub ever shows. After you store the contents in a GitHub secret in step 4, delete the local file — keeping it around is just attack surface.

### 3. Install the App

1. From the App's settings page sidebar → **Install App** → click **Install** next to `HoneyDrunkStudios`.
2. Repository access: **All repositories** is the recommended choice for solo-dev simplicity — every current and future Grid repo is auto-covered without re-installing on each new repo. The App's least-privilege scope is enforced at the *operation* level (only Issues / Contents / Metadata / Projects, all with explicit Read or Write grants), not at the repo set.
3. Click **Install**.

If you ever need stricter per-repo scoping, choose **Only select repositories** and tick every repo that hosts a packet `target_repo` — at the time of writing: HoneyDrunk.Architecture, HoneyDrunk.Actions, HoneyDrunk.Auth, HoneyDrunk.Data, HoneyDrunk.Kernel, HoneyDrunk.Notify, HoneyDrunk.Pulse, HoneyDrunk.Standards, HoneyDrunk.Transport, HoneyDrunk.Vault, HoneyDrunk.Vault.Rotation, HoneyDrunk.Web.Rest, HoneyDrunkStudios, HoneyDrunk.AI, HoneyDrunk.Lore. Adding a new repo means coming back here to update the installation.

### 4. Provision org secrets

**GitHub → Org Settings → Secrets and variables → Actions → New organization secret**

Two secrets, both with the same access policy:

#### `HIVE_APP_ID`

- **Value:** the App ID integer from step 2.
- **Repository access:** **Selected repositories** → tick `HoneyDrunk.Architecture` and `HoneyDrunk.Actions` (only the two repos whose workflows reference the secrets).

#### `HIVE_APP_PRIVATE_KEY`

- **Value:** the full `.pem` contents from step 2, BEGIN/END markers included.
- **Repository access:** **Selected repositories** → same two repos as above.

The App is installed broadly so it can act on any repo's issues. The *secrets* only need to reach the two callers that mint App tokens — Architecture's `file-packets.yml` caller and Actions' reusable workflow. Tighter secret scope here is free defense-in-depth.

### 5. Verify

Trigger the file-packets workflow manually:

**HoneyDrunk.Architecture → Actions → File Issue Packets → Run workflow** (branch `main`).

In the run log, the **Detect auth mode** step should print:

```
Auth path: GitHub App
```

Then **Mint GitHub App installation token** runs `actions/create-github-app-token@v1` and the rest of the pipeline uses the resulting installation token for every `gh` call.

## Critical guardrails

- The private key is **the only credential** for this App. Treat it like a root password — never commit, never echo in logs, never paste into a chat. `actions/create-github-app-token@v1` masks the resulting installation token automatically.
- The **App ID is not secret** (it appears on the App's public settings page), but storing it as a secret rather than a workflow variable keeps the surface uniform — both pieces of state come from the same access policy.
- **Don't grant Repository permissions beyond Issues / Contents / Metadata** without an explicit reason. Every additional permission widens what a leaked installation token can do.
- **Don't expand the secret access policy beyond Architecture + Actions** without an explicit reason. Workflows in other repos do not need the App secrets.
- **Webhook stays disabled.** The App is server-to-server, invoked from Actions; no webhook payload ever flows.

## Rotation

Private keys can be rotated without downtime:

1. App settings → **Private keys** → **Generate a private key** (a second key).
2. Update `HIVE_APP_PRIVATE_KEY` with the new `.pem` contents.
3. Run the workflow once to confirm the new key works (`Auth path: GitHub App` line and a successful mint step).
4. Return to App settings → **Private keys** → **Delete** the old key.

A short overlap window (both keys valid simultaneously) is fine. Don't delete the old key first.

## Verification checklist

- [ ] App `HoneyDrunk Hive` exists at `https://github.com/organizations/HoneyDrunkStudios/settings/apps/honeydrunk-hive`.
- [ ] Repository permissions show exactly: `Issues: R/W`, `Metadata: R`, `Contents: R/W`.
- [ ] Organization permissions show exactly: `Projects: R/W`.
- [ ] App is installed on the org.
- [ ] `HIVE_APP_ID` and `HIVE_APP_PRIVATE_KEY` exist as **org-level Actions secrets**, scoped to Architecture + Actions only.
- [ ] A `workflow_dispatch` run of `HoneyDrunk.Architecture/.github/workflows/file-packets.yml` logs `Auth path: GitHub App` and finishes green.
- [ ] Local `.pem` file from step 2 has been deleted.

## Cross references

- [ADR-0008: Packet Lifecycle](../adrs/ADR-0008-packet-lifecycle.md)
- [ADR-0012: Actions as CI/CD Control Plane](../adrs/ADR-0012-actions-as-cicd-control-plane.md)
- [`HoneyDrunk.Actions/scripts/file-packets.sh`](https://github.com/HoneyDrunkStudios/HoneyDrunk.Actions/blob/main/scripts/file-packets.sh) — consumer of the minted token via `GH_TOKEN` and `HIVE_FIELD_MIRROR_TOKEN` env vars.
- [`HoneyDrunk.Actions/.github/workflows/file-packets.yml`](https://github.com/HoneyDrunkStudios/HoneyDrunk.Actions/blob/main/.github/workflows/file-packets.yml) — the reusable workflow that mints the App token.
