---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Vault
labels: ["chore", "tier-2", "infrastructure", "human-only", "adr-0034", "wave-3"]
dependencies: ["packet:03"]
adrs: ["ADR-0034", "ADR-0005", "ADR-0006"]
accepts: ["ADR-0034"]
wave: 3
initiative: adr-0034-public-package-distribution
node: honeydrunk-vault
---

# Procure and seed the code-signing certificate, enable author-signing (ADR-0034 D5)

## Summary
After the BDR-0001 Sunbiz amendment lands, procure a code-signing certificate issued to the finalized "HoneyDrunk Studios" legal entity, store its private key in the Studios Key Vault, confirm the federated-OIDC access path from CI, and verify `job-publish-nuget.yml`'s conditional sign stage activates — flipping public packages from unsigned to author-signed.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Vault` — the Vault node owns the secret/certificate substrate. The certificate *material* lives in the Studios Key Vault; this packet is tracked against Vault as the responsible Node.

## Context
ADR-0034 D5 commits all published packages to author-signing with a code-signing certificate issued to "HoneyDrunk Studios" (the LLC). Per BDR-0001 the entity is mid-Sunbiz-amendment; ADR-0034 D5 holds certificate procurement until the amendment lands "so the certificate subject matches the legal entity name." Until then, `job-publish-nuget.yml` (packet 03) publishes unsigned with an explicit `Publishing UNSIGNED` log line.

ADR-0034's Operational Consequences are explicit that the unsigned state "blocks the 'remove Proposed status' gate" — except ADR-0034 is accepted (packet 00) with this as a known, recorded follow-up. This packet is that follow-up: it is the work that takes the Grid from unsigned to signed once BDR-0001 clears.

This is **`Actor=Human`** — procuring a certificate from a CA, validating the legal entity, and the portal-only Key Vault certificate import cannot be delegated to an agent. There is no code artifact for an agent to author; `job-publish-nuget.yml` (packet 03) already handles the signed path conditionally. The `human-only` label is set.

## HARD PRECONDITION — do not file or start until BDR-0001 lands
The BDR-0001 Sunbiz amendment must be **complete and the legal entity name final** before this packet runs. ADR-0034 D5: signing-cert procurement "waits on that amendment landing so the certificate subject matches the legal entity name." If the amendment has not landed, this packet stays in `active/` as a held draft and is not filed as a GitHub Issue. The `file-packets` pipeline holds it until the human confirms BDR-0001 is done.

## Scope
- Code-signing certificate — procured from a CA, subject = the finalized HoneyDrunk Studios legal entity name.
- Studios Key Vault — the certificate private key imported/stored per ADR-0005.
- Federated OIDC trust — confirmed working for the CI signing-cert fetch (the trust itself is configured as a Human Prerequisite of packet 03; this packet confirms it resolves the now-present certificate).
- Rotation — the certificate enrolled in the ADR-0006 secret/certificate lifecycle (auto-renew 30 days before expiry).
- `repos/HoneyDrunk.Vault/integration-points.md` — record the signing certificate as a Vault-managed secret.

## Proposed Work (human-executed)
1. Confirm BDR-0001 has landed and the legal entity name is final.
2. Procure a code-signing (Authenticode) certificate from a CA, with subject matching the finalized "HoneyDrunk Studios" entity name. (CA validation has a 1–3 week lead time per ADR-0034's Alternatives section.)
3. Import the certificate (with private key) into the Studios Key Vault as a certificate object, per ADR-0005's per-Node Key Vault model. The private key never leaves Vault and never lands on a developer laptop (ADR-0034 D5).
4. Verify the federated-OIDC path from `job-publish-nuget.yml` (packet 03) can fetch the certificate — run a publish of a test/canary package and confirm the workflow's sign stage activates (the `Publishing UNSIGNED` log line no longer appears; the package is author-signed).
5. Enroll the certificate in the ADR-0006 lifecycle: certificates auto-renew 30 days before expiry; route the Key Vault's diagnostic settings to the shared Log Analytics workspace (invariant 22) if not already.
6. Update `repos/HoneyDrunk.Vault/integration-points.md` to record the signing certificate as a Vault-managed secret with its rotation posture.

## NuGet Dependencies
None. This packet has no .NET project — `job-publish-nuget.yml` (packet 03) already implements the signed path conditionally. This packet provisions the certificate that activates that path.

## Boundary Check
- [x] The certificate material belongs in the Studios Key Vault — Vault is the only source of secrets (invariant 9). Correct ownership.
- [x] No code change in any repo — the signed code path already exists (packet 03).
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] BDR-0001 confirmed landed; the legal entity name is final
- [ ] A code-signing certificate with subject = the finalized HoneyDrunk Studios entity name is procured
- [ ] The certificate (with private key) is stored in the Studios Key Vault; the private key never left Vault and is not on any developer laptop
- [ ] A test/canary package publish through `job-publish-nuget.yml` produces an **author-signed** package — the `Publishing UNSIGNED` log line no longer appears
- [ ] The certificate is enrolled in the ADR-0006 lifecycle (auto-renew 30 days before expiry); the Key Vault diagnostics route to the shared Log Analytics workspace
- [ ] `repos/HoneyDrunk.Vault/integration-points.md` records the signing certificate as a Vault-managed secret
- [ ] The ADR-0034 "remove Proposed status" gate note (Operational Consequences) is satisfiable — the unsigned-publish window is closed

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] BDR-0001 Sunbiz amendment must be complete (this is the packet's HARD PRECONDITION).
- [ ] Code-signing certificate procured from a CA — note the 1–3 week CA validation lead time (ADR-0034 Alternatives: "Skip signing until external customers actually exist — Rejected").
- [ ] Certificate imported into the Studios Key Vault via the Azure portal.
- [ ] The federated-OIDC trust between GitHub Actions and the Studios Key Vault (configured as a packet 03 prerequisite) confirmed to resolve the certificate.

## Referenced ADR Decisions
**ADR-0034 D5 — Package signing.** All published packages are author-signed with a code-signing certificate issued to "HoneyDrunk Studios" (the LLC). Per BDR-0001 the entity is mid-Sunbiz-amendment; signing-cert procurement waits on that amendment landing so the certificate subject matches the legal entity name. Until then, packages publish unsigned. Repository signing (nuget.org server-side) is unconditionally enabled in parallel. The signing certificate's private key lives in the Studios Key Vault (per ADR-0005); CI accesses it via federated OIDC, never as a stored secret. Rotation follows ADR-0006's secret lifecycle. No long-lived signing PAT, no key on a developer laptop.

**ADR-0034 Operational Consequences.** "Until D5 signing lands, unsigned packages will produce a yellow warning in `dotnet restore` for security-conscious consumers. This is acceptable for the Proposed → Accepted window but blocks the 'remove Proposed status' gate." Procuring the certificate is named explicitly under Follow-up Work: "Procure the code-signing certificate after Sunbiz amendment lands (BDR-0001)."

**ADR-0006 — Secret rotation and lifecycle.** Certificates are auto-renewed 30 days before expiry.

## Constraints
> **Invariant 9 — Vault is the only source of secrets.** The signing certificate's private key lives in the Studios Key Vault. No Node reads it from environment variables, config files, or a laptop.

> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The certificate private key is never echoed; only its name/identifier may be traced.

> **Invariant 20 — No secret may exceed its tier's rotation SLA.** Certificates are auto-renewed 30 days before expiry; enroll the signing certificate accordingly.

> **Invariant 22 — Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace.** Confirm the Studios Key Vault holding the certificate satisfies this.

- **Do not start before BDR-0001 lands** — the certificate subject must match the final legal entity name. A cert issued to a soon-to-be-renamed entity is wasted procurement spend and lead time.
- **The private key never leaves Vault** — no export to a laptop, no long-lived signing PAT.

## Labels
`chore`, `tier-2`, `infrastructure`, `human-only`, `adr-0034`, `wave-3`

## Agent Handoff

**Objective:** Procure the code-signing certificate (subject = finalized HoneyDrunk Studios entity), store it in the Studios Key Vault, and verify `job-publish-nuget.yml`'s sign stage flips public packages from unsigned to author-signed.

**Target:** Tracked against `HoneyDrunk.Vault`; the work is human-executed (portal + CA procurement). `Actor=Human` — `human-only` label set.

**Context:**
- Goal: Close the unsigned-publish window ADR-0034 D5 opens; satisfy the "remove Proposed status" gate.
- Feature: ADR-0034 Public Package Distribution rollout, Wave 3 (signing).
- ADRs: ADR-0034 (D5 primary), ADR-0005 (Key Vault model), ADR-0006 (certificate auto-renewal), BDR-0001 (entity finalization — the hard precondition).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` — `job-publish-nuget.yml` (hard — the workflow with the conditional sign stage must exist; this packet provisions the certificate that activates it).

**Constraints:**
- HARD PRECONDITION — do not file or start until BDR-0001 lands.
- The private key never leaves Vault; no long-lived signing PAT.
- The certificate subject must match the final legal entity name.

**Key Files:**
- `repos/HoneyDrunk.Vault/integration-points.md` (the only file artifact — records the certificate as a Vault-managed secret).

**Contracts:** None changed — no code, no runtime contract. This packet provisions the certificate the existing packet-03 sign stage consumes.
