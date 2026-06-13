---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "infrastructure", "human-only", "adr-0044", "wave-1"]
dependencies: ["work-item:01"]
adrs: ["ADR-0044"]
accepts: []
wave: 1
initiative: adr-0044-cloud-code-review
node: honeydrunk-architecture
---

# Create the cross-repo-checkout GitHub App and provision review-agent credentials in Vault

## Summary
Create a new GitHub App scoped to read `HoneyDrunkStudios/HoneyDrunk.Architecture`, provision the Anthropic API key the cloud reviewer consumes, and store both credential sets in HoneyDrunk.Vault per ADR-0005. Author the walkthrough doc that records the portal steps so the provisioning is repeatable and auditable.

## Context
ADR-0044 D2 requires the cloud-wired reviewer to check out both the target repo *and* `HoneyDrunk.Architecture` so the agent can read `constitution/invariants.md`, the catalogs, and the per-repo boundary files locally — mirroring the local Claude Code workspace layout. Cross-repo checkout needs a GitHub App token scoped to read the architecture repo. The reviewer also calls the Anthropic API, which needs an API key. ADR-0044's Operational Consequences name both as load-bearing CI infrastructure: "Anthropic API key becomes load-bearing CI infrastructure" and "a new GitHub App scoped to read `HoneyDrunk.Architecture` is created; its installation token is fetched per workflow run. Credentials in Vault."

This is the credential-and-infrastructure prerequisite for the `job-review-agent.yml` build (packet 03). It is portal-heavy: GitHub App creation, private key generation, Azure Key Vault writes, and rotation configuration are all manual. Marked `Actor=Human` because the entire work item is portal/manual provisioning with no delegable code artifact.

**Permission scope decision (developer call, 2026-05-22):** ADR-0044 D2 describes the App's checkout role as "scoped to read on the architecture repo." That covers `job-review-agent.yml`'s context-checkout need. However, packet 16's D9 post-merge audit job *commits* audit reports back into `HoneyDrunk.Architecture/generated/post-merge-audits/`, which requires `Contents: Write`. Rather than provision `Read` now and widen the App permission later (a second mid-rollout portal pass), the developer's decision is to provision **`Contents: Write` on `HoneyDrunk.Architecture` up front**. The write scope is confined to the single architecture repo; it does not reach any other repo. This packet therefore provisions one App with `Contents: Write` that serves both the read-only checkout (packets 03/06/11) and the write-back audit-commit (packet 16).

## Scope
- A new GitHub App `honeydrunk-review-checkout` (or similar) created under the HoneyDrunkStudios org, with **Contents: Write** on `HoneyDrunk.Architecture` only.
- The Anthropic API key obtained from the Anthropic console.
- HoneyDrunk.Vault (the Azure Key Vault for the Actions/CI surface) receives: the GitHub App ID, the GitHub App private key, the GitHub App installation ID, and the Anthropic API key.
- A new walkthrough doc, `infrastructure/review-agent-credentials-setup.md`, recording every portal step.

## Proposed Implementation

### GitHub App
1. Create a GitHub App under HoneyDrunkStudios: **Settings → Developer settings → GitHub Apps → New GitHub App**.
2. Permissions: **Repository → Contents: Read and write** on `HoneyDrunk.Architecture` only. No webhook needed (the App is used only for installation-token minting). The write scope is provisioned up front because the D9 post-merge audit job (packet 16) commits audit reports into `HoneyDrunk.Architecture/generated/post-merge-audits/`; provisioning `Read` now and widening later would mean a second portal pass mid-rollout. The token is still scoped to a single repo, so the blast radius of `Write` is one repo (the architecture repo itself).
3. Generate a private key (`.pem`). Note the App ID.
4. Install the App on `HoneyDrunkStudios/HoneyDrunk.Architecture` only ("Only select repositories"). Note the installation ID.

### Anthropic API key
1. Obtain an API key from the Anthropic console under a workspace dedicated to CI review spend, so cost can be tracked separately per ADR-0044 D5 ($40-100/month expected, $200/month two-month ceiling triggers an ADR amendment).

### Vault storage (per ADR-0005, invariant 9)
Store all four values as secrets in the Key Vault that serves the CI surface:
- `review-agent-github-app-id`
- `review-agent-github-app-private-key`
- `review-agent-github-app-installation-id`
- `review-agent-anthropic-api-key`

Per invariant 9, Vault is the only source of secrets — no Node reads these from env vars or config files directly. The `job-review-agent.yml` workflow (packet 03) resolves them through the GitHub Actions secrets surface populated from Vault, per the existing CI secret-resolution pattern.

### Rotation (per ADR-0006)
- The Anthropic API key is a Tier-2 third-party secret — rotation SLA ≤ 90 days (invariant 20). Configure it for rotation via the existing Tier-2 rotation path (Vault.Rotation) or, if no automated rotator exists for Anthropic, log a documented rotation-SLA exception in Log Analytics and add a calendar reminder. The walkthrough doc must state which path was taken.
- The GitHub App private key has no SLA-bound rotation but should be regenerable; document the regeneration steps.

### Walkthrough doc
`infrastructure/review-agent-credentials-setup.md` records every step above, with the exact portal navigation, the secret names, and the rotation disposition. Cross-link it from the `job-review-agent.yml` packet (03) and the Phase-1 enablement packet (04).

## Affected Files
- `infrastructure/review-agent-credentials-setup.md` (new)

## NuGet Dependencies
None. This packet creates infrastructure and a Markdown doc; no .NET project is created or modified.

## Boundary Check
- [x] The doc lives in `HoneyDrunk.Architecture` (`infrastructure/` walkthrough docs already live here per the ADR-0011 SonarCloud-org-setup precedent).
- [x] The GitHub App and Anthropic key are org/external resources, not repo code.
- [x] Vault is the secret store per invariant 9 — no secret is committed to any repo.
- [x] `Contents: Write` is scoped to the single `HoneyDrunk.Architecture` repo — no cross-repo write reach.

## Acceptance Criteria
- [ ] A GitHub App exists under HoneyDrunkStudios with **Contents: Write** on `HoneyDrunk.Architecture` only, scoped to that single repo
- [ ] The App is installed on `HoneyDrunk.Architecture` only ("Only select repositories")
- [ ] The Anthropic API key is obtained under a CI-dedicated workspace for separable cost tracking
- [ ] All four secrets are stored in the CI-surface Key Vault with the exact names listed above
- [ ] The Anthropic API key's rotation disposition is recorded (automated rotator path, or a logged Log Analytics exception with a reminder)
- [ ] `infrastructure/review-agent-credentials-setup.md` exists and records every portal step, every secret name, and the rotation disposition
- [ ] No secret value appears in any committed file (invariant 8)

## Human Prerequisites
- [ ] Create the GitHub App in the HoneyDrunkStudios org portal and generate its private key
- [ ] Install the GitHub App on `HoneyDrunk.Architecture`
- [ ] Obtain the Anthropic API key from the Anthropic console
- [ ] Write the four secrets into the CI-surface Azure Key Vault
- [ ] Wire the secrets into the HoneyDrunk.Actions secrets surface (org or repo secrets) so `job-review-agent.yml` can resolve them — coordinate with packet 03
- [ ] Configure or document the Anthropic API key rotation per ADR-0006
- [ ] Pay any Anthropic API charges (the CI review spend is a recurring cost per ADR-0044 D5)

## Dependencies
- `work-item:01` — ADR-0044 acceptance (soft; this packet's text references ADR-0044 decisions as live rules).

## Referenced ADR Decisions

**ADR-0044 D2** — Context loading is identical to the local invocation; the workflow checks out both the target repo and `HoneyDrunk.Architecture` using a GitHub App token scoped to read the architecture repo.
**ADR-0044 D5** — Cost guardrails; expected $40-100/month, $200/month for two consecutive months triggers an ADR amendment.
**ADR-0044 Operational Consequences** — "Anthropic API key becomes load-bearing CI infrastructure. Outage halts the cloud reviewer (workflow fails gracefully). Rotation per ADR-0006." "GitHub App for cross-repo checkout — a new GitHub App scoped to read `HoneyDrunk.Architecture` is created; its installation token is fetched per workflow run. Credentials in Vault."

## Constraints
> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs.

> **Invariant 20:** No secret may exceed its tier's rotation SLA without an active exception. Tier 2 (third-party): ≤ 90 days. Exceptions must be logged in Log Analytics.

- **GitHub App permissions stay minimal** — Contents: Write on the architecture repo only. No webhook, no other repo, no other permission scope. The write scope is required for packet 16's post-merge audit-commit step; it is provisioned now to avoid a second portal pass mid-rollout.
- **Do not commit any secret.** Secret values live in Vault; CI resolves them via the GitHub Actions secrets surface.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `infrastructure`, `human-only`, `adr-0044`, `wave-1`

## Agent Handoff

**Objective:** This is an `Actor=Human` packet. Create the cross-repo-checkout GitHub App, obtain the Anthropic API key, store all four credentials in Vault, and author the walkthrough doc. No code is authored.

**Target:** `HoneyDrunk.Architecture` (for the walkthrough doc); GitHub org portal and Azure portal (for the provisioning).

**Context:**
- Goal: Provide `job-review-agent.yml` (packet 03) with the credentials it needs to check out the architecture repo and call the Anthropic API.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 1.
- ADRs: ADR-0044 (primary, D2 + Operational Consequences), ADR-0005 (Vault storage), ADR-0006 (rotation).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — ADR-0044 acceptance (soft).

**Constraints:**
- GitHub App permissions minimal: Contents: Write on `HoneyDrunk.Architecture` only (write is needed for packet 16's audit-commit; scoped to the single repo).
- Vault is the only secret store (invariant 9); no secret committed anywhere (invariant 8).
- Anthropic key rotation SLA ≤ 90 days or a logged exception (invariant 20).

**Key Files:**
- `infrastructure/review-agent-credentials-setup.md` (new)

**Contracts:** None.
