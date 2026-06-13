---
name: Architecture Catalog Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "core", "docs", "identity", "adr-0078", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0078", "ADR-0060"]
accepts: ADR-0078
wave: 1
initiative: adr-0078-entra-external-id
node: honeydrunk-identity
---

# Chore: Reflect ADR-0078 Entra vendor decision in catalogs, grid-health, and Identity context files

## Summary

Land the catalog-side consequences of ADR-0078: name **Microsoft Entra External ID** as the concrete IdP filling `IExternalIdpClaimMapper`'s provider slot in `catalogs/contracts.json` via a node-block-level `notes:` field (using `notes:` as the field name following the existing precedent in `catalogs/grid-health.json` — do not invent a new field like `provider_slot`). Register the custom-domain auth endpoint `entra-custom-domain-auth-honeydrunkstudios-com` in `catalogs/grid-health.json` so the custom-domain provisioning (landed by packet 03) has a discoverable health surface. Amend `repos/HoneyDrunk.Identity/integration-points.md` to name Entra External ID as the wrapped IdP (the file currently says "external IdP" with no vendor; ADR-0078 makes that concrete). Amend `repos/HoneyDrunk.Identity/overview.md`'s "Design Notes" to reference the OIDC-standards-only discipline (D3) and the wrapping seam (D4). All edits are additive — no contract surface changes; the catalog records the vendor confirmation that ADR-0078 commits.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0060 D2 deferred the IdP vendor decision. ADR-0078 fills that decision. The catalogs still read as if the vendor is undecided:

- `catalogs/contracts.json` `honeydrunk-identity` block describes `IExternalIdpClaimMapper` as "Provider-slot abstraction. Map external IdP claims (Entra, Clerk, etc.) to internal UserPrincipal state." That description treats Entra and Clerk as equivalent candidates. With ADR-0078 Accepted, Entra is no longer a candidate — it is the committed provider. The catalog should record that.
- `catalogs/grid-health.json` has no entry for the custom-domain auth endpoint. Packet 03 of this initiative provisions `auth.honeydrunkstudios.com` and wires it to the Entra External ID tenant; without a grid-health row, the custom-domain health surface is not discoverable.
- `repos/HoneyDrunk.Identity/integration-points.md` (authored by ADR-0060 packet 01) says "external IdP" without naming the vendor. The Identity context folder should reflect the Accepted vendor decision so any agent reading the Identity boundary docs sees the concrete provider.
- `repos/HoneyDrunk.Identity/overview.md`'s "Design Notes" section does not mention the OIDC-standards-only discipline (the vendor-exit hedge) or the per-application App Registration model.

This packet closes those gaps without changing the contract surface and without flipping anything to Accepted (ADR-0078's Status flip happens in packet 00).

## Proposed Implementation

### `catalogs/contracts.json` — add `notes:` field to `honeydrunk-identity` block

The `honeydrunk-identity` block was created by ADR-0060 packet 01. Add a node-block-level `notes:` field (parallel to `node`, `node_name`, `package`, `status`, `interfaces`) recording the IdP vendor commitment. The `notes:` field name follows the existing precedent in `catalogs/grid-health.json` — do **not** invent a `provider_slot` field. The shape:

```json
{
  "node": "honeydrunk-identity",
  "node_name": "HoneyDrunk.Identity",
  "package": "HoneyDrunk.Identity.Abstractions",
  "status": "seed",
  "notes": "IExternalIdpClaimMapper's provider slot is filled by HoneyDrunk.Identity.Providers.Entra against Microsoft Entra External ID per ADR-0078 (D1, D4). Single Grid-wide Entra External ID tenant; per-application App Registrations for each consumer app (Hearth, Lately, Currents, Curiosities) and one for Notify Cloud tenant operators; OAuth 2.1 with PKCE on OpenID Connect. OIDC-standard claims only — Entra-proprietary claims (oid, tid, idp, acrs) are diagnostic-only and never load-bearing in application logic per ADR-0078 D3 (vendor-exit hedge) and invariant 94. Token validation stays in HoneyDrunk.Auth per invariant 10; ADR-0078 D5 explicitly preserves invariant 10.",
  "interfaces": [
    // existing entries unchanged
  ]
}
```

The `interfaces` array is **not** modified — `IExternalIdpClaimMapper`'s existing entry (the "Provider-slot abstraction. Map external IdP claims (Entra, Clerk, etc.) to internal UserPrincipal state. ...") stays. The vendor confirmation is recorded at the node-block level via the new `notes:` field, not by editing the interface description. (Rationale: ADR-0060 D2's wrapping-seam architecture intentionally keeps the interface description vendor-agnostic so a future migration target — Clerk, Auth0, self-hosted — can implement the same interface; the vendor commitment is a Grid-policy fact above the interface, recorded at the node-block level.)

### `catalogs/grid-health.json` — add `entra-custom-domain-auth-honeydrunkstudios-com` entry

Append a new entry to `catalogs/grid-health.json` for the custom-domain auth endpoint that packet 03 of this initiative provisions. Mirror the shape of existing infrastructure-surface entries:

```json
{
  "id": "entra-custom-domain-auth-honeydrunkstudios-com",
  "name": "Entra External ID Custom Domain — auth.honeydrunkstudios.com",
  "sector": "Core",
  "signal": "Planned",
  "version": "n/a",
  "canary_status": "none",
  "last_release": null,
  "active_blockers": [
    "Entra External ID tenant not yet provisioned (packet 03 of adr-0078-entra-external-id is human-only and blocked on Hearth signup readiness)",
    "Cloudflare CNAME for auth.honeydrunkstudios.com not yet configured (packet 03)"
  ],
  "notes": "Custom domain unifies the OAuth experience under the Grid's brand per ADR-0078 D1 / 'Operational Consequences'. Wired to a single Grid-wide Entra External ID tenant with per-application App Registrations (Hearth, Lately, Currents, Curiosities, Notify Cloud tenant operators). DNS managed via Cloudflare per ADR-0029. Provisioning + wiring is human-only (Azure portal + Cloudflare portal) — packet 03 of adr-0078-entra-external-id."
}
```

Place the entry after the existing `honeydrunk-identity` row (or at the end of the array if the array is appended-only). The custom-domain entry is a **separate health surface** from the Identity Node — the Identity Node is a library at Phase 1; the custom domain is an Azure-side resource that exists from packet 03 onward.

### `repos/HoneyDrunk.Identity/integration-points.md` — name Entra as the wrapped IdP

The file was authored by ADR-0060 packet 01. Locate the **Consumes** table row that names the external IdP (the row that currently reads something like "External IdP — credential store, sign-in, MFA, passkey, social login — wrapped via IExternalIdpClaimMapper"). Amend the row to name Entra External ID explicitly:

```markdown
| **Microsoft Entra External ID** (per ADR-0078) | Credential store, sign-in, MFA, passkey enrollment, social login, account lockout, suspicious-login throttling, brute-force protection, geo-IP signal, device fingerprinting — wrapped via `IExternalIdpClaimMapper` (the Entra implementation lives in `HoneyDrunk.Identity.Providers.Entra`; ships with the first consumer-app feature packet that pulls on Identity, per ADR-0060 D12 Phase 2). OIDC-standard claims only consumed in application logic per invariant 94 (Entra-proprietary `oid`, `tid`, etc., are diagnostic-only). |
```

If the file as authored does not have a dedicated "External IdP" row in the Consumes table (the integration-points template is per-Node and may render this as an Emits or design-notes entry instead), search for "external IdP" and amend the surrounding context to name Entra External ID, citing ADR-0078 D1 / D4. The amendment is additive — do not remove vendor-agnosticism from the interface-description level (that lives in contracts.json and is intentionally vendor-agnostic per the seam architecture).

### `repos/HoneyDrunk.Identity/overview.md` — add Design Notes reference to OIDC-standards-only discipline

The file was authored by ADR-0060 packet 01 with a "Design Notes" section covering the wrapping-seam architecture (ADR-0060 D2), user profile location (D5), and internal-token issuance discipline (D6). Append two new Design Notes entries:

```markdown
- **Microsoft Entra External ID is the committed end-user IdP** per ADR-0078 D1. Single Grid-wide tenant; per-application App Registrations for each consumer app and one for Notify Cloud tenant operators; OAuth 2.1 with PKCE on OpenID Connect. The wrapping seam (`IExternalIdpClaimMapper`) means a future migration to Clerk / Auth0 / self-hosted OpenIddict is a per-Node adapter swap, not application-code rework — see ADR-0078 D7.
- **OIDC-standard claims only consumed in application logic** per ADR-0078 D3 and invariant 94. The allowed claim set is `sub`, `iss`, `aud`, `exp`, `iat`, `nbf`, `email`, `email_verified`, `name`, `given_name`, `family_name`, `preferred_username`. Entra-proprietary claims (`oid`, `tid`, `idp`, `acrs`) may appear in diagnostic logs but are never load-bearing in application logic — the cheap vendor-exit hedge wired at the `IExternalIdpClaimMapper` seam.
```

Do not remove or rewrite the existing Design Notes entries authored by ADR-0060 packet 01. Append only.

### `CHANGELOG.md` (Architecture repo)

Append to the current dated SemVer section:

> `Architecture: Record ADR-0078 Entra vendor confirmation in catalogs. catalogs/contracts.json honeydrunk-identity block gains a node-block-level notes: field naming Microsoft Entra External ID as the IExternalIdpClaimMapper provider slot (HoneyDrunk.Identity.Providers.Entra). catalogs/grid-health.json gains an entra-custom-domain-auth-honeydrunkstudios-com entry tracking the auth.honeydrunkstudios.com custom domain provisioning (human-only via packet 03). repos/HoneyDrunk.Identity/integration-points.md Consumes row for the external IdP amended to name Entra per ADR-0078 D1/D4. repos/HoneyDrunk.Identity/overview.md Design Notes section gains two entries — Entra vendor commitment (D1) and OIDC-standards-only claims discipline (D3/D7, invariant 94). The IExternalIdpClaimMapper interface description in contracts.json stays vendor-agnostic — the seam architecture intentionally keeps it that way; vendor commitment is recorded at the node-block level.`

## Affected Files

- `catalogs/contracts.json` (add `notes:` field to the `honeydrunk-identity` block)
- `catalogs/grid-health.json` (append `entra-custom-domain-auth-honeydrunkstudios-com` entry)
- `repos/HoneyDrunk.Identity/integration-points.md` (name Entra External ID in the Consumes table row for the external IdP)
- `repos/HoneyDrunk.Identity/overview.md` (append two Design Notes entries)
- `CHANGELOG.md` (entry under current dated SemVer section)

## NuGet Dependencies

None. Architecture is a knowledge repo — no .NET projects.

## Boundary Check

- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] No code changes; catalogs + docs only.
- [x] `IExternalIdpClaimMapper` interface description is **not** modified — the seam architecture per ADR-0060 D2 / D4 intentionally keeps the interface vendor-agnostic. Vendor commitment is recorded at the node-block level via the new `notes:` field.
- [x] `notes:` field follows the existing `catalogs/grid-health.json` precedent for the field name; no new field like `provider_slot` is invented.
- [x] Identity context-file amendments are additive — no existing text is removed or rewritten.

## Acceptance Criteria

- [ ] `catalogs/contracts.json` `honeydrunk-identity` block has a node-block-level `notes:` field naming Microsoft Entra External ID as the `IExternalIdpClaimMapper` provider slot, referencing `HoneyDrunk.Identity.Providers.Entra` as the implementing package per ADR-0078 D1 / D4, and naming the OIDC-standards-only discipline per ADR-0078 D3 + invariant 94.
- [ ] `catalogs/contracts.json` `honeydrunk-identity` block `interfaces` array is unchanged. `IExternalIdpClaimMapper`'s description stays vendor-agnostic per the seam architecture.
- [ ] `catalogs/grid-health.json` has a new `entra-custom-domain-auth-honeydrunkstudios-com` entry with `signal: "Planned"`, `version: "n/a"`, `canary_status: "none"`, active-blockers naming packet 03's provisioning + Cloudflare CNAME work, and `notes:` describing the custom-domain purpose.
- [ ] `repos/HoneyDrunk.Identity/integration-points.md` Consumes-table row for the external IdP is amended to name Microsoft Entra External ID and references ADR-0078 D1 / D4 + invariant 94. The amendment is additive — no existing rows or text are removed.
- [ ] `repos/HoneyDrunk.Identity/overview.md` Design Notes section gains two new entries — Entra vendor commitment (ADR-0078 D1) and OIDC-standards-only claims discipline (ADR-0078 D3 / D7, invariant 94). The existing Design Notes entries authored by ADR-0060 packet 01 are unchanged.
- [ ] `CHANGELOG.md` carries an entry under the current dated SemVer section describing all four edits (not under `## Unreleased`).
- [ ] `adrs/ADR-0078-end-user-identity-entra-external-id.md` is **not** modified by this packet. ADR-0078's Status is whatever packet 00 set it to.

## Human Prerequisites

- [ ] **ADR-0060 packet 01 must be merged to `main` before this packet executes.** Packet 01 of the adr-0060-identity-standup initiative creates `repos/HoneyDrunk.Identity/integration-points.md` and `repos/HoneyDrunk.Identity/overview.md`. Without those files, this packet has no Identity context files to amend. Confirmation: `ls repos/HoneyDrunk.Identity/integration-points.md` and `ls repos/HoneyDrunk.Identity/overview.md` should both succeed before this packet's PR is authored.
- [ ] Packet 00 of this initiative (ADR-0078 acceptance + invariants 93/94) must be merged so the invariant 94 reference in the new contracts.json `notes:` field, the integration-points amendment, and the overview.md Design Notes text are not forward-pointing into a not-yet-landed invariant.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — Reinforces why `HoneyDrunk.Identity.Abstractions` (the package containing `IExternalIdpClaimMapper`) stays vendor-agnostic at the interface level. The Entra-specific implementation lives in a separate runtime package (`HoneyDrunk.Identity.Providers.Entra`); the Abstractions package never references Entra SDKs.

> **Invariant 10:** Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. **It is not an identity provider.** — Survives ADR-0078 intact. The Entra-issued tokens and the Identity-issued internal tokens are both validated by Auth's existing JWKS-based `IJwtBearerValidator` path; the catalog-level vendor commitment in this packet does not weaken invariant 10.

> **Invariant 94 (Proposed — pending ADR-0078 acceptance via packet 00):** Application code consumes OIDC-standard claims only from Entra-issued tokens. The allowed claim set: `sub`, `iss`, `aud`, `exp`, `iat`, `nbf`, `email`, `email_verified`, `name`, `given_name`, `family_name`, `preferred_username`. Entra-proprietary claims (`oid`, `tid`, `idp`, `acrs`) may appear in diagnostic logs but are never load-bearing in application logic. — The cheap vendor-exit hedge codified at the `IExternalIdpClaimMapper` seam. This packet's `notes:` field text in contracts.json and the new Design Notes entries in overview.md restate this invariant inline so any agent reading the Identity context understands the discipline.

## Referenced ADR Decisions

**ADR-0078 D1 — Microsoft Entra External ID is the end-user IdP.** Single Grid-wide tenant; per-application App Registrations; OAuth 2.1 with PKCE; OpenID Connect. Restated in the new `notes:` field in `catalogs/contracts.json` and in the integration-points + overview amendments.

**ADR-0078 D3 — OIDC-standard claims only.** Application code consumes the standard OIDC claim set; Entra-proprietary claims are diagnostic-only. The cheap vendor-exit hedge. Restated as invariant 94 (landed by packet 00) and referenced in the new contracts.json `notes:` field, the integration-points amendment, and the overview.md Design Notes.

**ADR-0078 D4 — HoneyDrunk.Identity is the seam; Entra is the provider.** `HoneyDrunk.Identity.Providers.Entra` is the package that implements `IExternalIdpClaimMapper` against Entra External ID. Application code consumes Identity's contracts; never Entra's SDKs directly. The new `notes:` field names the package explicitly.

**ADR-0078 D5 — Token validation stays in HoneyDrunk.Auth per Invariant 10.** Auth is unchanged. No new validation primitive lands in Auth.

**ADR-0078 D7 — Migration path away from Entra.** The wrapping seam from ADR-0060 D2 plus the OIDC-standards-only discipline (D3) bound the migration cost. The catalog change in this packet does not lock the Grid into Entra at the code level; only at the policy level.

**ADR-0060 D2 — Wrap external IdP, leading candidate Entra External ID.** ADR-0078 fills D2's deferred vendor decision. The wrapping-seam architecture is preserved — `IExternalIdpClaimMapper`'s interface description in contracts.json stays vendor-agnostic.

**ADR-0060 D4 — Exposed contracts.** `IExternalIdpClaimMapper` is one of the six Identity Abstractions interfaces. Vendor confirmation is recorded above the interface (at the node-block level via the new `notes:` field), not inside the interface description.

## Dependencies

- `work-item:00` — ADR-0078 acceptance must merge first so invariants 93/94 land and the catalog text can cite invariant 94 by number.

## Labels

`chore`, `tier-2`, `core`, `docs`, `identity`, `adr-0078`, `wave-1`

## Agent Handoff

**Objective:** Record ADR-0078's Entra vendor confirmation in the catalogs and the Identity context files without changing the contract surface. Add a node-block-level `notes:` field to `catalogs/contracts.json`'s `honeydrunk-identity` block naming Entra External ID + `HoneyDrunk.Identity.Providers.Entra`. Add an `entra-custom-domain-auth-honeydrunkstudios-com` entry to `catalogs/grid-health.json`. Amend `repos/HoneyDrunk.Identity/integration-points.md` to name Entra in the external-IdP Consumes-row. Amend `repos/HoneyDrunk.Identity/overview.md` to add two Design Notes entries for the Entra commitment and the OIDC-standards-only discipline.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make ADR-0078's vendor confirmation visible in the catalogs and Identity context, so any agent reading the Identity boundary sees Entra named as the committed provider while the interface description stays vendor-agnostic per the seam architecture.
- Feature: ADR-0078 End-User Identity — Microsoft Entra External ID rollout, Wave 1, Packet 01.
- ADRs: ADR-0078 (vendor decision), ADR-0060 (the parent standup ADR that authored the Identity context files this packet amends).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 00 of this initiative (acceptance + invariants 93/94).

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — `IExternalIdpClaimMapper` lives in `HoneyDrunk.Identity.Abstractions`; the Entra-specific implementation must live in a separate runtime/provider package (`HoneyDrunk.Identity.Providers.Entra`). The catalog amendments record that boundary; do not move the vendor name into the Abstractions package's contract surface.
- **Invariant 10:** Auth tokens are validated, never issued. — Survives ADR-0078 intact; the vendor commitment in this packet does not weaken it.
- **Invariant 94 (pending packet 00):** Application code consumes OIDC-standard claims only from Entra-issued tokens. — Restated inline in the new `notes:` field and Design Notes entries.
- `IExternalIdpClaimMapper`'s interface description in `contracts.json` is **not** modified. Vendor commitment is recorded at the node-block level via the new `notes:` field, not at the interface level.
- The `notes:` field name follows the existing precedent in `catalogs/grid-health.json`. Do NOT invent a new field like `provider_slot`.
- All Identity context-file amendments are additive. Do not remove or rewrite any existing text in `integration-points.md` or `overview.md`.
- This packet does not flip any ADR Status. ADR-0078's Status is whatever packet 00 set it to.

**Key Files:**
- `catalogs/contracts.json` — add `notes:` field to `honeydrunk-identity` block
- `catalogs/grid-health.json` — append `entra-custom-domain-auth-honeydrunkstudios-com` entry
- `repos/HoneyDrunk.Identity/integration-points.md` — amend external-IdP Consumes row
- `repos/HoneyDrunk.Identity/overview.md` — append two Design Notes entries
- `CHANGELOG.md` — append under current dated SemVer section

**Contracts:** None changed. This packet records the vendor commitment in catalog metadata only.
