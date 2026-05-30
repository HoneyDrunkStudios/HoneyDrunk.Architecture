# Review-Agent GitHub App For Local Worker

**Applies to:** ADR-0086, ADR-0044, ADR-0005, ADR-0006.  
**Scope:** Operator-internal automation infrastructure, not a deployable Node.

## Goal

Reuse the existing ADR-0044 review-agent GitHub App for the ADR-0086 local runner framework, and store its credentials in the shared automation Key Vault:

```text
Subscription: honeydrunk-dev
Resource group: rg-hd-automation-dev
Key Vault: kv-hd-automation-dev
```

The shared vault covers local automation credentials for the runner framework, including PR review, post-merge audit, `hive-sync`, and Lore jobs. The GitHub App identity remains the review-agent App so PR timelines keep continuity with ADR-0044.

## GitHub App Audit

1. Open **GitHub -> HoneyDrunkStudios organization settings -> Developer settings -> GitHub Apps**.
2. Open the existing ADR-0044 review-agent App.
3. Verify repository permissions:
   - **Pull requests:** Read and write.
   - **Issues:** Read and write.
   - **Contents:** Read-only for review queue work. If Content write is present for ADR-0044 post-merge audit artifacts, document that scope and keep installation scope bounded.
   - **Metadata:** Read-only.
4. Verify installation scope:
   - Phase A: `HoneyDrunk.Architecture`.
   - Later phases: only repos enabled by ADR-0086 rollout packets.
5. Confirm webhook settings are not required for the ADR-0086 local worker path. Packet 08 owns review-webhook decommission and any old webhook-signing secret cleanup.

## Automation Vault

Create or verify the shared automation vault:

```text
Subscription: honeydrunk-dev
Region: East US 2
Resource group: rg-hd-automation-dev
Key Vault: kv-hd-automation-dev
Permission model: Azure role-based access control
```

The operator account that runs the local worker through `az` needs **Key Vault Secrets User** on `kv-hd-automation-dev`. The account used to seed or rotate values needs **Key Vault Secrets Officer** on the same vault.

## Secret Names

Store the GitHub App credentials with ADR-0005-style section separators:

```text
GitHub--AgentRunner--AppId
GitHub--AgentRunner--InstallationId
GitHub--AgentRunner--PrivateKey
```

Values:

- `GitHub--AgentRunner--AppId`: the GitHub App ID from the App settings page.
- `GitHub--AgentRunner--InstallationId`: the installation ID from the org installation URL.
- `GitHub--AgentRunner--PrivateKey`: the full private-key PEM, including BEGIN/END marker lines.

Do not use `review-agent-github-app-*` for new ADR-0086 runner setup. Those names were legacy ADR-0044 carryover names and are superseded by the normalized automation vault names above.

## Private-Key Rotation

1. GitHub App settings -> **Private keys** -> **Generate a private key**.
2. Copy the downloaded PEM contents into `GitHub--AgentRunner--PrivateKey`.
3. Smoke-test token minting from the local runner host.
4. Delete the downloaded PEM from disk.
5. Delete the old private key from the GitHub App only after the new key has been verified.

## Smoke Test

From a runner host with `az` logged into `honeydrunk-dev`, verify that secret reads succeed without printing values:

```powershell
az keyvault secret show --vault-name kv-hd-automation-dev --name GitHub--AgentRunner--AppId --query id -o tsv
az keyvault secret show --vault-name kv-hd-automation-dev --name GitHub--AgentRunner--InstallationId --query id -o tsv
az keyvault secret show --vault-name kv-hd-automation-dev --name GitHub--AgentRunner--PrivateKey --query id -o tsv
```

Then run the ADR-0086 runner dry run with the host config that points at `kv-hd-automation-dev`:

```powershell
pwsh ./infrastructure/workers/grid-agent-runner/scripts/Test-JobLocally.ps1 -JobId grid-review -ConfigPath ./infrastructure/workers/grid-agent-runner/config/host.psd1
```

Only run without `-DryRun` after token minting has been verified and the operator intentionally wants the worker to claim queued PRs.

## Verification Checklist

- [ ] Existing review-agent GitHub App is reused; no second review-worker App exists.
- [ ] App permissions cover `pull_requests: write`, `issues: write`, and `contents: read`.
- [ ] App installation includes `HoneyDrunk.Architecture` for Phase A.
- [ ] `kv-hd-automation-dev` exists in `rg-hd-automation-dev` under `honeydrunk-dev`.
- [ ] `GitHub--AgentRunner--AppId`, `GitHub--AgentRunner--InstallationId`, and `GitHub--AgentRunner--PrivateKey` exist in the vault.
- [ ] Local runner host can read those secrets via `az`.
- [ ] Downloaded PEM file is deleted after the private key is stored and verified.

## Cross References

- [ADR-0086](../../adrs/ADR-0086-pull-based-local-worker-grid-review-runner.md)
- [ADR-0044](../../adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md)
- [Key Vault creation](key-vault-creation.md)
- [Key Vault RBAC assignments](key-vault-rbac-assignments.md)
