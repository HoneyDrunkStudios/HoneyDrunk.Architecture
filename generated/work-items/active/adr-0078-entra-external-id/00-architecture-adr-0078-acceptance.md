---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "identity", "adr-0078", "wave-1"]
dependencies: []
adrs: ["ADR-0078"]
accepts: ["ADR-0078"]
wave: 1
initiative: adr-0078-entra-external-id
node: honeydrunk-identity
---

# Accept ADR-0078 — flip status, claim invariant block 93-94, add the two Entra invariants, register the initiative

## Summary

Flip ADR-0078 (End-User Identity — Microsoft Entra External ID) from Proposed to Accepted: update the ADR header, claim the reserved size-2 invariant block in `constitution/invariant-reservations.md` (default range **93-94** per the existing reservation row), add the two new invariants ADR-0078 commits in its Consequences section to `constitution/invariants.md` under a new `## End-User Identity Invariants` section, and register the `adr-0078-entra-external-id` initiative in `initiatives/active-initiatives.md`. ADR-0078 fills ADR-0060 D2's deferred vendor decision before Hearth's signup packet pulls on Identity.

## Context

ADR-0078 commits **Microsoft Entra External ID** as the identity provider for every end-user authentication surface in the Grid (consumer-app users — Hearth, Lately, Currents, Curiosities — plus Notify Cloud tenant operators). It also commits the **OIDC-standard-claims-only** discipline as the vendor-exit hedge against Entra trajectory changes. The ADR fills [ADR-0060](../../../../adrs/ADR-0060-stand-up-honeydrunk-identity-node.md) D2's deferred vendor decision before the first user-facing app (Hearth per PDR-0005) pulls on Identity.

The ADR decides:
- **D1** — Microsoft Entra External ID is the end-user IdP. Single Grid-wide Entra External ID tenant; per-application App Registrations; OAuth 2.1 with PKCE over OpenID Connect.
- **D2** — Azure AD B2C is explicitly not adopted (sunset for new tenants).
- **D3** — OIDC-standard claims only (`sub`, `iss`, `aud`, `exp`, `iat`, `nbf`, `email`, `email_verified`, `name`, `given_name`, `family_name`, `preferred_username`). Entra-proprietary claims (`oid`, `tid`, etc.) may be logged for diagnostics but are not load-bearing in application logic. This is the cheap vendor-exit hedge wired at the `IExternalIdpClaimMapper` seam.
- **D4** — `HoneyDrunk.Identity` is the seam; `HoneyDrunk.Identity.Providers.Entra` is the package that implements `IExternalIdpClaimMapper` against Entra External ID. Application code consumes Identity's contracts; never Entra's SDKs directly.
- **D5** — Token validation stays in `HoneyDrunk.Auth` per Invariant 10. Auth still issues nothing.
- **D6** — Per-application configuration shape (App Registration ID in App Configuration; tenant-issuer URL; redirect URIs; app-specific branding and user-flow customization).
- **D7** — Migration path away from Entra is bounded by the wrapping seam and the OIDC-standards-only discipline.
- **D8** — Free up to 50K MAU; per-MAU pricing thereafter is predictable.
- **D9** — Alternatives evaluated: B2C (rejected — sunset); Auth0 (rejected on cost); Clerk (strong contender; held for re-evaluation if Entra DX disappoints); Supabase Auth (rejected — self-hosts credentials); self-hosted (held as eventual destination only).
- **D10** — Out of scope: Identity Node contract surface (owned by ADR-0060), deletion fan-out workflow (owned by ADR-0060), per-app branding details, MFA enforcement policy, social-login provider enablement, tenant-scoped Entra setup details, B2B/enterprise workforce identity, API-key auth for public Grid APIs.

This is a **policy / vendor-confirmation** ADR. The concrete code — the `HoneyDrunk.Identity.Providers.Entra` adapter — lands when the first consumer-app feature packet pulls on Identity (per ADR-0060 D12 Phase 2). The infrastructure provisioning — the Entra External ID tenant, the first App Registration, custom-domain wiring — lands as later packets in this initiative.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope

- `adrs/ADR-0078-end-user-identity-entra-external-id.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `constitution/invariant-reservations.md` — confirm the size-2 ADR-0078 reservation row (default **93-94**); move it from Active Reservations to Reservation History with the merge date once the invariants land in `constitution/invariants.md` in this same PR.
- `constitution/invariants.md` — add the two new invariants under a new `## End-User Identity Invariants` section placed after `## Infrastructure-as-Code Invariants` (the ADR-0077 block; assuming ADR-0077 packet 00 has merged first — if not, anchor against `## Audit Invariants`).
- `initiatives/active-initiatives.md` — register the `adr-0078-entra-external-id` initiative with the packet checklist for this folder.
- `initiatives/roadmap.md` — add a Q2-Q3 2026 bullet (Hearth signup is the forcing function; rollout aligns with the consumer-app PDR sequence).

## Proposed Implementation

### Step 1 — Flip ADR-0078 status

Edit `adrs/ADR-0078-end-user-identity-entra-external-id.md`:
- `**Status:** Proposed` → `**Status:** Accepted`

The ADR README index has not been updated to include rows beyond ADR-0057 at file authoring time; no `adrs/README.md` row update is required here. (If the index has caught up by the time this packet executes, add the ADR-0078 row.)

### Step 2 — Claim the invariant block

Read `constitution/invariant-reservations.md`. ADR-0078's reservation row exists in the Active Reservations table with default range **93-94** (size 2). The reservation framework's "first merge wins" rule means: at edit time, confirm the row's range. If a racing ADR's packet 00 merged first and pushed ADR-0078's block upward, take the new numbers and update every `{N1}` / `{N2}` placeholder in this packet's body in lockstep with `constitution/invariants.md`. At file authoring (2026-05-24) the assignment is **{N1}=93, {N2}=94**.

After the invariants land in `constitution/invariants.md` in this same PR, **move the ADR-0078 row from Active Reservations to Reservation History** with the merge date — per the reservation file's "Reservation History (for audit)" section's documented procedure.

### Step 3 — Add the two new invariants to `constitution/invariants.md`

Introduce a new section `## End-User Identity Invariants` placed **immediately after `## Infrastructure-as-Code Invariants`** (the section ADR-0077 packet 00 adds). If ADR-0077 packet 00 has not merged yet, anchor against `## Audit Invariants` (the section ending around invariant 49 at file authoring time). Substitute `{N1}` / `{N2}` with the actual numbers from the reservation row. Mark each entry with the `(Proposed — this invariant takes effect when ADR-0078 is accepted)` qualifier; the qualifier becomes informationally accurate once ADR-0078's Status flips to Accepted in Step 1 of this same PR.

The two entries:

```markdown
## End-User Identity Invariants

{N1}. **End-user identity tokens are issued by Microsoft Entra External ID.**
    Every consumer-app user (Hearth, Lately, Currents, Curiosities, and future consumer PDRs) and every Notify Cloud tenant-operator user authenticates via a single Grid-wide Entra External ID tenant with per-application App Registrations under OAuth 2.1 with PKCE on OpenID Connect. Any other end-user IdP requires an ADR amendment. The Identity Node's `IExternalIdpClaimMapper` seam (per ADR-0060 D4) is the wrapping point; `HoneyDrunk.Identity.Providers.Entra` is the package that implements that seam against Entra. Application code consumes `HoneyDrunk.Identity`'s contracts; never `Microsoft.Identity.Web` or other Entra-specific SDKs directly. See ADR-0078 D1 / D2 (Proposed — this invariant takes effect when ADR-0078 is accepted).

{N2}. **Application code consumes OIDC-standard claims only from Entra-issued tokens.**
    The allowed claim set: `sub`, `iss`, `aud`, `exp`, `iat`, `nbf`, `email`, `email_verified`, `name`, `given_name`, `family_name`, `preferred_username`. Entra-proprietary claims (`oid`, `tid`, `idp`, `acrs`, and any other non-OIDC-standard claim) may appear in diagnostic logs but are never load-bearing in application logic — they are never branched on, never persisted as the canonical user-identity key, never used in authorization decisions. This is the cheap vendor-exit hedge: code that depends only on OIDC-standard claims migrates cleanly to any other OIDC-compliant IdP; code that depends on Entra-proprietary claims is bound to Entra specifically. The discipline at the consuming end pre-pays the migration cost if Entra's trajectory ever turns hostile (per ADR-0078 D7). See ADR-0078 D3 / D7 (Proposed — this invariant takes effect when ADR-0078 is accepted).
```

**Note on the dropped third candidate.** ADR-0078's Consequences §Invariants subsection originally proposed a third invariant ("Auth still issues nothing"). That is a restatement of existing invariant 10 ("Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. It is not an identity provider.") per ADR-0078 D5; it is not a new constitutional rule. Block size is therefore 2, not 3, and the reservation row in `invariant-reservations.md` reserves only **93-94**.

### Step 4 — Register the initiative

Append a new entry to `initiatives/active-initiatives.md` under `## In Progress`:

```markdown
### ADR-0078 End-User Identity — Microsoft Entra External ID
**Status:** In Progress
**Scope:** Architecture, Azure portal (Entra External ID tenant + App Registrations), DNS (custom-domain)
**Initiative:** `adr-0078-entra-external-id`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Accept ADR-0078, commit Microsoft Entra External ID as the end-user IdP, claim invariant block 93-94, add the two Entra invariants (Entra IdP commitment; OIDC-standards-only claims discipline), document the per-application configuration shape, provision the Entra External ID tenant + first App Registration (Notify Cloud tenant operators + Hearth), verify-or-create the `rg-hd-platform-shared` resource group, wire the `auth.honeydrunkstudios.com` custom domain, and log the active invariant-20 exception for Entra App Registration client-secret rotation cadence.

**Tracking:**
- [ ] Architecture#NN: Accept ADR-0078, add invariants 93/94, register initiative (packet 00)
- [ ] Architecture#NN: Catalog updates — IdP provider-slot `notes:` in contracts.json, grid-health entry for `entra-custom-domain-auth-honeydrunkstudios-com`, Identity integration-points amendment naming Entra (packet 01)
- [ ] Architecture#NN: Document the per-application configuration shape — App Configuration keys, Vault secret naming, `IExternalIdpClaimMapper` Entra-vs-other mapping reference (packet 02)
- [ ] Architecture#NN: Provision Entra External ID tenant + first App Registration + verify-or-create `rg-hd-platform-shared` + custom-domain prep (packet 03 — human-only)
- [ ] Architecture#NN: Author Entra App Registration provisioning walkthrough doc (portal-based; Bicep-based provisioning queued under ADR-0077 follow-up) (packet 04)
- [ ] Architecture#NN: Follow-up — ADR-0006 Tier-2 rotation extension proposal for Entra App Registration client secrets (packet 05 — placeholder for follow-up ADR work)
```

### Step 5 — Roadmap bullet

Append to the Q2-Q3 2026 section of `initiatives/roadmap.md`:

```markdown
- [ ] **ADR-0078 End-User Identity — Microsoft Entra External ID — scoped** *(6 packets queued; packets 01/02 reference Identity context files created by ADR-0060 packet 01; packet 03 provisioning blocked on Hearth signup readiness)*
```

### Step 6 — CHANGELOG entry

Append to the current dated SemVer section of `CHANGELOG.md` (per memory `feedback_no_unreleased_commits` — no `## Unreleased` block; use the existing dated section or create a new one if this commit bumps the version):

> `Architecture: Accept ADR-0078 (End-User Identity — Microsoft Entra External ID). Status flipped to Accepted. Add invariants 93 (end-user identity tokens are issued by Microsoft Entra External ID — D1/D2) and 94 (application code consumes OIDC-standard claims only from Entra-issued tokens; vendor-exit hedge at the IExternalIdpClaimMapper seam — D3/D7) under a new ## End-User Identity Invariants section. Move ADR-0078 reservation from Active Reservations to Reservation History. Register adr-0078-entra-external-id initiative + Q2-Q3 2026 roadmap bullet. Two-invariant block (the third candidate "Auth still issues nothing" is a restatement of existing invariant 10 per D5, not a new invariant).`

## Affected Files

- `adrs/ADR-0078-end-user-identity-entra-external-id.md` (flip Status)
- `constitution/invariant-reservations.md` (move ADR-0078 row from Active Reservations to Reservation History)
- `constitution/invariants.md` (add two new invariants under new `## End-User Identity Invariants` section)
- `initiatives/active-initiatives.md` (new entry)
- `initiatives/roadmap.md` (new bullet)
- `CHANGELOG.md` (append under current dated SemVer section)

## NuGet Dependencies

None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check

- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency — IdP vendor decision is policy; the concrete adapter ships from Identity when first consumer-app pulls on it.
- [x] Block size 2 matches reservation row range 93-94. The third candidate invariant ("Auth still issues nothing") is dropped per ADR-0078 D5 — restatement of invariant 10.

## Acceptance Criteria

- [ ] ADR-0078 header reads `**Status:** Accepted`
- [ ] `constitution/invariant-reservations.md`'s ADR-0078 row is moved from Active Reservations to Reservation History with the merge date
- [ ] `constitution/invariants.md` carries the two new End-User Identity invariants (Entra IdP commitment; OIDC-standards-only claims discipline), numbered `{N1}` / `{N2}` (default **93/94**) under a new `## End-User Identity Invariants` section, each citing ADR-0078
- [ ] Invariant `{N1}` text states: end-user identity tokens are issued by Microsoft Entra External ID; references the single Grid-wide tenant + per-application App Registration model + OAuth 2.1 with PKCE on OIDC; cites ADR-0078 D1 / D2; carries the `(Proposed — this invariant takes effect when ADR-0078 is accepted)` qualifier
- [ ] Invariant `{N2}` text states: application code consumes OIDC-standard claims only; lists the allowed claim set; names Entra-proprietary claims (`oid`, `tid`, `idp`, `acrs`) as diagnostic-only; cites ADR-0078 D3 / D7; carries the `(Proposed)` qualifier
- [ ] `initiatives/active-initiatives.md` registers the `adr-0078-entra-external-id` initiative with the six-packet checklist
- [ ] `initiatives/roadmap.md` has a new Q2-Q3 2026 bullet for the initiative
- [ ] `CHANGELOG.md` carries an entry under the current dated SemVer section (not under `## Unreleased`)
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)

## Human Prerequisites

None. ADR-0078 text is already on disk; this packet flips Status and lands the constitutional restatements.

## Referenced Invariants

> **Invariant 10:** Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. **It is not an identity provider.** — Survives ADR-0078 intact. ADR-0078 D5 explicitly preserves this. The Entra-issued tokens and the Identity-issued internal tokens are both validated by Auth's existing JWKS-based `IJwtBearerValidator` path; no new validation primitive lands in Auth. This is why ADR-0078's third candidate invariant ("Auth still issues nothing") is dropped — it is a restatement of invariant 10, not a new rule.

> **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Before a packet is filed, it may be amended to fill in missing operational context without violating this rule. — Other packets in this initiative cite the invariant numbers this packet assigns. Pre-filing amendments to the other packets in this folder are permitted under invariant 24's carve-out if the assigned numbers shift via the reservation framework's first-merge-wins rule.

## Referenced ADR Decisions

**ADR-0078 D1 — Microsoft Entra External ID is the end-user IdP.** Single Grid-wide Entra External ID tenant; per-application App Registrations (one per consumer-app + one for Notify Cloud tenant operators); OAuth 2.1 with PKCE; OpenID Connect. Restated as invariant `{N1}` by this packet.

**ADR-0078 D2 — Azure AD B2C is explicitly not adopted.** B2C is sunset for new tenants per Microsoft's communicated product direction; Entra External ID is the migration target.

**ADR-0078 D3 — OIDC-standard claims only.** Application code consumes the standard OIDC claim set; Entra-proprietary claims (`oid`, `tid`, etc.) may be logged for diagnostics but are never load-bearing in application logic. The cheap vendor-exit hedge. Restated as invariant `{N2}` by this packet.

**ADR-0078 D5 — Token validation stays in HoneyDrunk.Auth per Invariant 10.** This is why the third candidate invariant ("Auth still issues nothing") is dropped — restatement of invariant 10, not a new constitutional rule.

**ADR-0078 D7 — Migration path away from Entra.** The wrapping seam from ADR-0060 D2 plus the OIDC-standards-only discipline (D3) bound the migration cost. Invariant `{N2}` codifies the discipline-side half of that hedge.

## Constraints

- **Acceptance precedes flip.** ADR-0078 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers come from the reservation registry.** Read `constitution/invariant-reservations.md` and confirm the ADR-0078 row's range. At file authoring time the row's range is **93-94**. If a racing ADR's packet 00 landed first and shifted the block upward, take the new numbers and update every `{N1}` / `{N2}` placeholder in this packet body together with `constitution/invariants.md`.
- **New section, not appended to an existing one.** The two End-User Identity invariants are a new cross-cutting topic; create a `## End-User Identity Invariants` section after `## Infrastructure-as-Code Invariants` (or `## Audit Invariants` if 0077 hasn't landed yet) rather than appending to an unrelated section.
- **Block size is exactly 2.** ADR-0078 adds two new invariants. The "Auth still issues nothing" candidate restates invariant 10 per D5 and is dropped. Do not attempt to claim a size-3 block.
- **Move the reservation row to history.** The reservation file's documented procedure: once the invariants land in `constitution/invariants.md`, move the ADR-0078 row from Active Reservations to Reservation History with the merge date. Do not leave the row in both tables.

## Labels

`chore`, `tier-3`, `core`, `docs`, `identity`, `adr-0078`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0078 to Accepted; confirm the size-2 invariant block in `constitution/invariant-reservations.md` (default **93-94**); add the two End-User Identity invariants to `constitution/invariants.md` under a new section; move the reservation row from Active Reservations to Reservation History; register the initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0078 so the remaining packets in this initiative can reference its decisions as live rules, and so downstream consumer-app feature packets (Hearth signup, etc.) have a definite IdP-vendor target.
- Feature: ADR-0078 End-User Identity — Microsoft Entra External ID rollout, Wave 1, Packet 00.
- ADRs: ADR-0078 (primary), ADR-0060 (the parent standup ADR; this packet fills D2's deferred vendor decision), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**

- **Invariant 10:** Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. **It is not an identity provider.** — Survives ADR-0078 intact. This is why the "Auth still issues nothing" candidate is dropped from the constitutional restatement: invariant 10 already says it.
- **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Before a packet is filed, it may be amended to fill in missing operational context. — Other packets in this folder cite the assigned invariant numbers; pre-filing amendments are permitted under invariant 24's carve-out if the numbers shift.
- Acceptance precedes flip — ADR-0078 stays Proposed until this PR merges.
- Confirm the size-2 block from `constitution/invariant-reservations.md` at PR time; substitute `{N1}` / `{N2}` placeholders against the registry's live numbers. Defaults at scoping are 93/94.
- Move the reservation row from Active Reservations to Reservation History with the merge date once the invariants land in `constitution/invariants.md` in the same PR.
- Block size is exactly 2. Do not attempt to claim a size-3 block; the third candidate ("Auth still issues nothing") restates invariant 10.

**Key Files:**
- `adrs/ADR-0078-end-user-identity-entra-external-id.md`
- `constitution/invariant-reservations.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`
- `initiatives/roadmap.md`
- `CHANGELOG.md`

**Contracts:** None changed. This packet is governance-only.
