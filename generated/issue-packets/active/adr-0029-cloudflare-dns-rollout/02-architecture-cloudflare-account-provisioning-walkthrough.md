---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "docs", "infrastructure", "adr-0029"]
dependencies: []
adrs: ["ADR-0029", "ADR-0005", "ADR-0006", "ADR-0012"]
wave: 1
initiative: adr-0029-cloudflare-dns-rollout
node: honeydrunk-architecture
---

# Feature: Author `infrastructure/cloudflare-account-provisioning.md` walkthrough

## Summary
Author the portal-first walkthrough for provisioning the Cloudflare account itself — account creation, hardware-key 2FA enrollment, the API token storage convention, the Free-tier posture, and the lean record-comment scheme. Lands alongside P3 in Wave 1; both are foundation docs the migration packets reference.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0029 §If Accepted requires `infrastructure/cloudflare-account-provisioning.md` to exist before the migration packets execute. The existing `infrastructure/` walkthroughs cover Azure-side provisioning (Key Vault, Container App, Function App, App Configuration, Log Analytics, OIDC, ACR, CAE) — the Grid has no Cloudflare-side equivalent yet. Without it, every future migration packet duplicates account-prep steps inline; with it, migration packets reference one canonical source.

The walkthrough is **portal-first** per the Grid's documented convention (`infrastructure/README.md`'s "Portal-First" subtitle) and the user's standing preference. CLI is appendix material only, if included at all.

The walkthrough must also document two Grid-specific conventions:
- **API token storage convention — two cases.** Cloudflare API tokens have two distinct consumers in the Grid: a deployable Node's runtime, or a GitHub Actions workflow. Each gets its own storage path. Per-Node-vault for runtime consumers; GitHub Environment secret for workflow consumers. ADR-0012 (the CI/CD control plane ADR) is the cross-link for the workflow case. No token is provisioned in this packet — both conventions are recorded.
- **Lean record-comment scheme** — per ADR-0029 D6, Cloudflare DNS record comments use `purpose=...` only. No `initiative`, `created-by-agent`, or owner noise. Mirrors the Grid's lean Azure tag scheme.

## Proposed Implementation

### New file: `infrastructure/cloudflare-account-provisioning.md`

Match the structural template used by the existing portal walkthroughs (`infrastructure/walkthroughs/key-vault-creation.md`, `infrastructure/walkthroughs/container-app-creation.md`, etc.). Sections:

1. **Goal** — one-paragraph statement of what the walkthrough produces (a Cloudflare account ready to receive the Grid's domains, with the security posture and conventions documented).

2. **Portal Breadcrumb** — `Cloudflare Dashboard → Sign Up → Profile / Security / API Tokens / DNS Record Comments`.

3. **Step-by-step — Account creation**
   - Create the account at `dash.cloudflare.com/sign-up`. Use the studio's primary email (the same email used elsewhere in the Grid for vendor accounts). Plan: Free.
   - Confirm the verification email and complete account creation.

4. **Step-by-step — Hardware-key 2FA enrollment** (mandatory per ADR-0029 §Negative Consequences mitigation)
   - Navigate to `My Profile → Authentication`.
   - Enable two-factor authentication. Enroll a hardware security key (YubiKey or equivalent) as the primary method, plus a TOTP authenticator as backup. Software-only TOTP is not sufficient on its own — the ADR's mitigation explicitly names hardware-key-backed.
   - Generate and securely store backup codes outside the Cloudflare account (1Password / equivalent). Backup codes are not stored in the Grid's Key Vaults because they predate the Vault-bootstrap chain.
   - Verify 2FA challenge by signing out and back in.

5. **Step-by-step — Account-level transfer-lock posture**
   - Cloudflare's account preferences include a default zone-creation posture; document the Grid's stance: every zone enables Registrar-level transfer lock immediately after the transfer completes (ADR-0029 §Implementation step 6). Per-zone, not account-wide — recorded at the per-domain migration packet (P4 / P5).

6. **API token convention — split by consumer (no token provisioned in this packet)**

   Cloudflare API tokens are scoped per-zone or per-purpose. **Two storage paths apply, depending on who consumes the token.** Pick one or the other; never both for the same token.

   **Case A — Token consumed by a deployable Node's runtime** (e.g., a Function or Container App that talks to the Cloudflare API at request-handling time).
     - Token name in the Cloudflare dashboard: `hd-{purpose}-{env}` (e.g., `hd-dns-readwrite-dev`).
     - Permissions: minimum required for the purpose. The Cloudflare API supports per-zone, per-permission scoping.
     - Storage: the consuming Node's per-Node Key Vault (`kv-hd-{service}-{env}`), at the secret name `Cloudflare--ApiToken` (single-purpose) or `Cloudflare--{Purpose}--ApiToken` (multi-purpose).
     - Access: through `ISecretStore` per Invariant 9 — never read from environment variables, config files, or the Cloudflare SDK directly.
     - Rotation: ADR-0006 Tier 2 (third-party rotation), ≤ 90 days. Manual rotation through the Cloudflare dashboard at v1; automation is a future ADR.
     - Cross-link: `infrastructure/walkthroughs/key-vault-creation.md` (where the secret will live), `infrastructure/walkthroughs/key-vault-rbac-assignments.md` (how the consuming Node's Managed Identity gains read access).

   **Case B — Token consumed by a GitHub Actions workflow** (e.g., a workflow in `HoneyDrunk.Actions` that updates DNS records during deployment, runs a takedown script, or rotates a downstream record at release time).
     - Token name in the Cloudflare dashboard: `hd-actions-{purpose}-{env}` (e.g., `hd-actions-dns-readwrite-prod`). Distinct from runtime tokens; the `actions-` prefix makes the consumer obvious in the Cloudflare audit log.
     - Permissions: minimum required for the workflow's purpose.
     - Storage: **GitHub Environment secret** scoped to the matching environment, named `CLOUDFLARE_API_TOKEN` (single-purpose) or `CLOUDFLARE_{PURPOSE}_API_TOKEN` (multi-purpose). The GitHub Environment is the same one the workflow already deploys against (e.g., `dev`, `stg`, `prod`) — keep one token per environment, scoped per purpose.
     - Access: read inside the workflow only, via `${{ secrets.CLOUDFLARE_API_TOKEN }}`. Do NOT mirror the token into a Key Vault — that creates two storage locations and two rotation paths for the same credential. Workflow-only tokens stay workflow-only.
     - Rotation: ADR-0006 Tier 2 (third-party rotation), ≤ 90 days. Manual rotation through the Cloudflare dashboard with a coordinated re-paste into the GitHub Environment secret.
     - Cross-link: ADR-0012 (CI/CD Control Plane) for the broader Actions secret-handling stance — environment-scoped GitHub secrets, one token per environment per purpose, never shared across environments.

   **No token is provisioned by this walkthrough.** The first packet that needs a Cloudflare API token decides Case A or Case B based on its consumer and provisions accordingly.

7. **Lean record-comment scheme** (per ADR-0029 D6)
   - Cloudflare DNS records support a free-text comment field. The Grid uses it for record purpose only.
   - Format: `purpose={record-purpose}`. Examples: `purpose=studios-apex`, `purpose=studios-www`, `purpose=notify-cloud-api`, `purpose=email-spf`, `purpose=email-dkim`, `purpose=email-dmarc`.
   - **Do not include:** `initiative`, `created-by`, `owner`, ADR identifiers, ticket numbers, dates, agent names, or free-form descriptions.
   - This mirrors the Grid's lean Azure tag scheme (env always, node for per-Node, purpose=platform-shared for shared, never `initiative`). The Cloudflare comment field is the tag-equivalent for records.

8. **Cost posture**
   - The Grid uses Cloudflare Free for DNS at v1. Per ADR-0029 D2, the Free tier covers the Grid's full DNS footprint at current and foreseeable scale.
   - Registrar pricing is at-cost (wholesale registry fee passed through with no markup) regardless of plan tier.
   - Paid Cloudflare features (Workers, Pages, Tunnel, Access, R2, Cloudflare for SaaS, advanced WAF, image optimization) are deferred per ADR-0029 D4. Each is its own follow-up ADR; do not enable any paid feature in the dashboard's setup flow without an accepting ADR.
   - If the Cloudflare dashboard offers a paid-plan upgrade prompt during account setup, decline it. Free is the correct choice.

9. **Verification**
   - Account exists at the studio's primary email.
   - 2FA: hardware key enrolled as primary, TOTP backup enrolled, backup codes stored outside the account.
   - No paid plan enabled. Account dashboard shows Free.
   - No domains added yet (per-domain transfers are P4 / P5; this walkthrough only stands the account up).
   - No API tokens provisioned (per the API token convention section — first token waits for a future ADR).

10. **Cross references**
    - [ADR-0029](../adrs/ADR-0029-cloudflare-dns-and-edge-platform.md)
    - [ADR-0005](../adrs/ADR-0005-configuration-and-secrets-strategy.md) — secret-naming convention for the future Cloudflare API token (Case A — runtime).
    - [ADR-0006](../adrs/ADR-0006-secret-rotation-and-lifecycle.md) — Tier 2 rotation cadence for the future Cloudflare API token.
    - [ADR-0012](../adrs/ADR-0012-grid-cicd-control-plane.md) — Actions secret-handling stance for the future Cloudflare API token (Case B — workflow).
    - [`cloudflare-domain-transfer.md`](cloudflare-domain-transfer.md) — generic per-domain transfer walkthrough (the natural next step after account stand-up).

### Edits to `infrastructure/README.md`

Add a new top-level section between the existing "Azure platform-shared" and "Azure per-Node" sections:

```
**Cloudflare platform (provision once for the org):**

- [Cloudflare account provisioning](cloudflare-account-provisioning.md) — Stand up the Cloudflare account, hardware-key 2FA, the API token storage convention (`Cloudflare--ApiToken` per ADR-0005), and the lean record-comment scheme.
- [Cloudflare domain transfer](cloudflare-domain-transfer.md) — Generic per-domain transfer walkthrough (GoDaddy → Cloudflare). Per-domain migration packets reference this.
```

(P3 lands the second link; this packet adds the section header and the first bullet. If P3 merges first, P2 just adds its bullet. The two are coordinated through the dispatch plan and can land in either order.)

### `CHANGELOG.md`
Append an entry to the existing in-progress `## [Unreleased]` section under `### Added`:
- "`infrastructure/cloudflare-account-provisioning.md` walkthrough — account creation, hardware-key 2FA, API token storage convention, lean record-comment scheme."

## Affected Files
- `infrastructure/cloudflare-account-provisioning.md` (new)
- `infrastructure/README.md` (new section)
- `CHANGELOG.md`

## Boundary Check
- [x] Architecture-repo doc-only change. No catalog graph changes.
- [x] No code in any Node touched. No invariant text changes (ADR-0029 proposes none).
- [x] No secret values in the walkthrough — invariant 8. Token names and conventions only.

## Acceptance Criteria
- [ ] `infrastructure/cloudflare-account-provisioning.md` exists with all sections enumerated above (Goal, Portal Breadcrumb, Account creation, Hardware-key 2FA enrollment, Account-level transfer-lock posture, API token convention, Lean record-comment scheme, Cost posture, Verification, Cross references).
- [ ] Hardware-key 2FA section explicitly names hardware-key-backed as mandatory and TOTP-only as insufficient.
- [ ] API token convention section presents both consumer cases: **Case A (runtime)** names `Cloudflare--ApiToken` (or `Cloudflare--{Purpose}--ApiToken`) in the per-Node Key Vault with `ISecretStore` access; **Case B (workflow)** names `CLOUDFLARE_API_TOKEN` (or `CLOUDFLARE_{PURPOSE}_API_TOKEN`) as a GitHub Environment secret scoped per-environment, with ADR-0012 cross-link. Both cases reference ADR-0006 Tier-2 rotation cadence (≤ 90 days). Walkthrough explicitly states no token is provisioned by this packet.
- [ ] Lean record-comment scheme section names `purpose={record-purpose}` as the only allowed comment shape and lists `initiative`, `created-by`, `owner`, ADR identifiers, ticket numbers, dates, and agent names as forbidden.
- [ ] Cost posture section names Cloudflare Free as the v1 plan, Registrar-as-at-cost regardless of plan, and lists paid features (Workers, Pages, Tunnel, Access, R2, Cloudflare for SaaS, advanced WAF, image optimization) as deferred per ADR-0029 D4.
- [ ] No secret values in the walkthrough — token names and conventions only (invariant 8).
- [ ] `infrastructure/README.md` has the new "Cloudflare platform" section with the account-provisioning bullet present (the domain-transfer bullet may be added by P3 in the same wave).
- [ ] `CHANGELOG.md` `## [Unreleased]` section has the added-entry described above.
- [ ] PR description references this packet (invariant 32).

## Human Prerequisites
- [ ] **Cloudflare account exists at the studio's primary email.** If the account does not exist yet, the user creates it through `dash.cloudflare.com/sign-up` before the walkthrough can verify against a real screen flow. (Alternative: the agent drafts the walkthrough against Cloudflare's public docs and the user verifies steps against the live portal during PR review. Either ordering works.)
- [ ] **Hardware key on hand for 2FA enrollment.** YubiKey or equivalent. Required for the walkthrough's verification step to be meaningfully reproducible. If the studio does not yet have a hardware key, that purchase is a prerequisite to closing the verification step (not a prerequisite to drafting the walkthrough).

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. Walkthroughs follow the same rule — no actual token values, account IDs, or credentials in the doc. Example token names and convention strings only.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`. The future Cloudflare API token is read through `ISecretStore`, not the Cloudflare SDK's environment-variable convention.

> **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes have no vault. The future Cloudflare API token lives in the consuming Node's vault, not in a shared vault — ADR-0005 explicitly forbids a shared vault until a real cross-Node secret appears.

> **Invariant 20:** No secret may exceed its tier's rotation SLA without an active exception. Tier 2 (third-party via rotation Function): ≤ 90 days. The future Cloudflare API token is Tier 2 and inherits the 90-day cadence.

> **Invariant 21:** Applications must never pin to a specific secret version. All secret reads resolve the latest version via `ISecretStore`. Pinning breaks Event Grid cache invalidation and rotation propagation. The future Cloudflare API token is read through `ISecretStore` with no version pin.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.

## Referenced ADR Decisions

**ADR-0029 §If Accepted:** Mandates this walkthrough exists. The packet is the direct fulfillment.

**ADR-0029 D2 (Authoritative DNS — portal-managed at v1):** "DNS records are managed through the Cloudflare dashboard, not Terraform / Pulumi / OpenTofu... Aligns with the repo's documented portal-first convention for infrastructure workflows." The walkthrough is portal-first; CLI is appendix at most.

**ADR-0029 D5 (API token handling):** "When Cloudflare API automation lands (it does not, in this ADR), tokens are scoped per-zone or per-purpose, stored in Key Vault at `Cloudflare--ApiToken` (or `Cloudflare--{Purpose}--ApiToken` when multiple tokens are needed), and accessed via `ISecretStore` (Invariant 9). Tokens carry the minimum permissions required for their use." The walkthrough records this verbatim for the runtime case (Case A) and adds the workflow-consumer split (Case B) with ADR-0012 as the cross-link — the ADR speaks to runtime consumers; workflow consumers use a different storage path because GitHub Environment secrets are the right surface for Actions workflows. The two cases together cover the full set of Cloudflare API token consumers in the Grid.

**ADR-0012 (Grid CI/CD Control Plane):** Names `HoneyDrunk.Actions` as the central place for any DNS-touching workflow and establishes the GitHub-Environment-secret pattern for workflow credentials. The Case B convention follows that pattern.

**ADR-0029 D6 (Lean record-comment scheme):** "Cloudflare DNS record comments (where used) follow the same minimal posture: record purpose only, not initiative names or owners... `purpose=studios-apex`, `purpose=notify-cloud-api`, etc. No `initiative` or `created-by-agent` noise." The lean comment scheme section records this verbatim.

**ADR-0029 §Negative Consequences (single point of compromise mitigation):** "hardware-key-backed 2FA on the Cloudflare account is mandatory at the migration packet". The walkthrough's 2FA section enforces this convention.

**ADR-0005 §Configuration and Secrets Strategy:** Provides the `kv-hd-{service}-{env}` per-Node-vault naming. Cross-link only; no copy of ADR-0005 content in the walkthrough beyond the secret name.

**ADR-0006 Tier 2 (third-party rotation):** Provides the ≤ 90 day rotation cadence for the future Cloudflare API token. Cross-link only.

## Dependencies
None. P2 and P3 are foundation walkthroughs; P1 is independent of both. The dispatch plan recommends running P2 and P3 in parallel after the Cloudflare account exists, but neither blocks the other at the packet level.

## Labels
`feature`, `tier-2`, `docs`, `infrastructure`, `adr-0029`

## Agent Handoff

**Objective:** Author the Cloudflare account provisioning walkthrough as a portal-first runbook, with the API token convention and lean record-comment scheme inlined.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Stand up the Cloudflare-side documentation surface that future migration packets consume.
- Feature: ADR-0029 Cloudflare DNS & Edge Platform Rollout, foundation wave.
- ADRs: ADR-0029 (Proposed — primary), ADR-0005 (cross-link for secret name), ADR-0006 (cross-link for rotation cadence).

**Acceptance Criteria:** As listed above.

**Dependencies:** None at the packet level. Human prerequisite: Cloudflare account exists for verification.

**Constraints:**
- **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. The walkthrough is the documentation equivalent — no actual token values, account IDs, billing IDs, or credentials in the doc. Convention strings and example token names only.
- **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`. The future Cloudflare API token is read through `ISecretStore` — the walkthrough must say so explicitly in the API token convention section.
- **Invariant 17:** One Key Vault per deployable Node per environment. The walkthrough places the future Cloudflare token in the consuming Node's vault, not a shared vault.
- **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.
- **Portal-first.** Per ADR-0029 D2 and the Grid's documented convention. CLI is appendix material at most; ideally absent.
- **Cloudflare Free is the v1 plan.** Per ADR-0029 D2. Walkthrough names the cost posture explicitly. No paid feature is enabled.
- **No token is provisioned in this packet.** The walkthrough documents the convention; no secret material lands in any vault as part of this packet.

**Key Files:**
- `infrastructure/cloudflare-account-provisioning.md` (new — the walkthrough)
- `infrastructure/README.md` (new "Cloudflare platform" section)
- `CHANGELOG.md`

**Reference Walkthroughs (style/structure to mirror):**
- `infrastructure/walkthroughs/key-vault-creation.md` (structural template — Goal / Portal Breadcrumb / Step-by-step / Verification / Cross references)
- `infrastructure/walkthroughs/oidc-federated-credentials.md` (similar shape — account-level setup with security posture)

**Contracts:** None changed. Doc-only packet.
