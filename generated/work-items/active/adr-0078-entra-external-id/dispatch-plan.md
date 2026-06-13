# Dispatch Plan — ADR-0078 End-User Identity — Microsoft Entra External ID

**Initiative:** `adr-0078-entra-external-id`
**Sector:** Core
**Governing ADR:** [ADR-0078 — End-User Identity — Microsoft Entra External ID](../../../../adrs/ADR-0078-end-user-identity-entra-external-id.md) (Proposed 2026-05-23; flips to Accepted via packet 00 of this initiative)
**Companion ADR:** [ADR-0060 — Stand Up the HoneyDrunk.Identity Node](../../../../adrs/ADR-0060-stand-up-honeydrunk-identity-node.md) (Proposed; merged via PR #323 per the user's scoping context — packets 01 and 02 of *this* initiative reference Identity context files created by ADR-0060 packet 01 and must wait for that to land on `main`)
**Trigger:** ADR-0060 D2 deferred the IdP-vendor decision until the first user-facing consumer-app feature packet pulled on Identity. ADR-0078 commits Microsoft Entra External ID as the vendor before Hearth (PDR-0005) signup blocks. ADR-0078 also commits the OIDC-standards-only claims discipline as the cheap vendor-exit hedge.
**Type:** Single-repo (all work lands in `HoneyDrunk.Architecture`; the Entra-side provisioning is portal-based, the tracking issues live in Architecture)
**Site sync required:** No (no public-API surface change yet — when the first consumer-app feature packet pulls on Identity and ships the `HoneyDrunk.Identity.Providers.Entra` package, a site-sync follow-up may be warranted)
**Rollback plan:**
- **Pre-tenant-provisioning rollback** (before packet 03 executes): `git revert` of each PR. Packets 00, 01, 02 are independent reverts. Packet 04 (the walkthrough doc) is an independent revert.
- **Post-tenant-provisioning rollback** (after packet 03 executes): the Entra External ID tenant exists in Azure; rollback is "manually delete the tenant + App Registrations via the portal" plus revert the catalog/grid-health entries. Practical hard rollback after the tenant is created is expensive (a fresh tenant requires re-verifying the custom domain, re-seeding App Configuration, etc.); prefer fix-forward unless the rollback is for a security incident.
- **Post-first-App-Registration rollback** (after any consumer-app feature packet wires `HoneyDrunk.Identity.Providers.Entra`): rollback of the App Registration may invalidate consumer-app user sessions. Treat as forward-only past this point; address defects via fix-forward packets.
- **`file-work-items.yml` lifecycle gotcha:** after this initiative's packets have moved through The Hive, hive-sync may move source packet files from `active/` to `completed/` per invariant 37. A `git revert` only undoes code changes, not packet-file moves. If a revert is needed after lifecycle moves, restore the packet files manually as part of the revert PR.

## Summary

ADR-0078 fills ADR-0060 D2's deferred vendor decision: Microsoft Entra External ID is the end-user IdP for every consumer-app surface (Hearth, Lately, Currents, Curiosities) plus Notify Cloud tenant operators. Single Grid-wide tenant; per-application App Registrations; OAuth 2.1 with PKCE on OpenID Connect; OIDC-standard claims only consumed in application logic (vendor-exit hedge at the `IExternalIdpClaimMapper` seam).

Six packets land the work:

1. **Accept ADR-0078** — flip Status to Accepted, claim the size-2 invariant block at **93-94** (the third candidate "Auth still issues nothing" is dropped per D5 — restatement of invariant 10), add the two invariants under a new `## End-User Identity Invariants` section, register the initiative, move the reservation row from Active Reservations to Reservation History.
2. **Catalog updates** — add a node-block-level `notes:` field to `catalogs/contracts.json`'s `honeydrunk-identity` block naming Entra as the IdP provider-slot (using `notes:` per existing precedent — not a new `provider_slot` field). Add an `entra-custom-domain-auth-honeydrunkstudios-com` entry to `catalogs/grid-health.json`. Amend `repos/HoneyDrunk.Identity/integration-points.md` to name Entra. Amend `repos/HoneyDrunk.Identity/overview.md` Design Notes for the Entra commitment and OIDC-standards-only discipline.
3. **Per-application configuration shape doc** — author `repos/HoneyDrunk.Identity/entra-configuration.md` covering App Configuration key naming (`Identity:Entra:{App}:{Key}`), Vault secret naming (`entra-app-{app}-client-secret` in `kv-hd-identity-{env}`), redirect URI pattern (`https://{app}.honeydrunkstudios.com/auth/callback`), OIDC-standard claim mapping reference for the `IExternalIdpClaimMapper` Entra implementation, and the diagnostic-vs-load-bearing distinction for Entra-proprietary claims per invariant 94.
4. **Provision Entra tenant + first App Registration + custom-domain + invariant-20 exception** (human-only) — create the Grid-wide Entra External ID tenant in `rg-hd-platform-shared` (verify or create the resource group), create the first App Registration (Notify Cloud tenant operators or Hearth — human picks at provisioning time), seed App Configuration + Vault, wire the `auth.honeydrunkstudios.com` custom domain via Cloudflare CNAME per ADR-0029, log the active invariant-20 exception for the Entra client-secret rotation cadence.
5. **Entra App Registration walkthrough doc** — author `infrastructure/walkthroughs/entra-app-registration.md` capturing the repeatable portal walkthrough for adding consumer-app App Registrations (Steps 3-6 of packet 03 generalized for re-use). Bicep-based provisioning explicitly deferred until ADR-0077 follow-up.
6. **ADR-0006 Tier-2 rotation extension proposal** (follow-up placeholder) — draft an ADR amendment resolving the live invariant-20 exception. Path (a) raise the Tier-2 SLA for IdP-tenant-bound secrets; path (b) ship an `EntraAppRegistrationRotator` in `HoneyDrunk.Vault.Rotation`. User picks path at draft time.

## Wave Diagram

```
Wave 1: Acceptance + catalogs (sequential — packet 01 depends on packet 00)
   ├─ Architecture: 00-architecture-adr-0078-acceptance
   │     Blocked by: none (foundation of the initiative).
   └─ Architecture: 01-architecture-entra-catalog-updates
         Blocked by: packet 00 (catalog text cites invariant 94 by number;
                                packet 00 lands it).
         Also has cross-init Human Prerequisite: ADR-0060 packet 01 must be
         merged to main (creates the repos/HoneyDrunk.Identity/ context files
         this packet amends).

Wave 2: Per-app config shape + provisioning + walkthrough (partial parallelism)
   ├─ Architecture: 02-architecture-per-app-config-shape
   │     Blocked by: packet 00 (invariant 94 reference), packet 01 (catalog
   │                  cross-links).
   │     Also has cross-init Human Prerequisite: ADR-0060 packet 01 must be
   │     merged (this packet adds a new file in repos/HoneyDrunk.Identity/).
   ├─ Architecture: 03-architecture-provision-entra-tenant  (human-only)
   │     Blocked by: packet 00, packet 01, packet 02.
   └─ Architecture: 04-architecture-entra-app-registration-walkthrough
         Blocked by: packet 00, packet 01, packet 02.
         (Can run in parallel with packet 03 — the walkthrough captures the
         steps as a recipe; packet 03 executes the first instance.)

Wave 3: Follow-up ADR drafting
   └─ Architecture: 05-architecture-adr-0006-tier2-rotation-extension-proposal
         Blocked by: packet 03 (the invariant-20 exception must be a known
                     live concern before the resolving ADR is drafted).
```

In practice:

- Wave 1 packets 00 and 01 must land sequentially (packet 01 depends on packet 00).
- Wave 2 packets 02, 03, 04 can run in parallel after Wave 1 closes (packet 03 is human-only and runs on the user's schedule; packets 02 and 04 are doc-only and can both file in the same push).
- Wave 3 packet 05 depends on packet 03's human-only provisioning being Done (the invariant-20 exception record must exist before the ADR resolving it is drafted).

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 00 | [Accept ADR-0078, claim invariants 93-94, register initiative](./00-architecture-adr-0078-acceptance.md) | Architecture | 1 | Agent | none |
| 01 | [Catalog updates — contracts.json IdP provider-slot `notes:`, grid-health custom-domain entry, Identity context amendments](./01-architecture-entra-catalog-updates.md) | Architecture | 1 | Agent | 00 |
| 02 | [Per-application Entra configuration shape doc — App Configuration keys, Vault secret naming, OIDC claim mapping reference](./02-architecture-per-app-config-shape.md) | Architecture | 2 | Agent | 00, 01 |
| 03 | [Provision Entra tenant + first App Registration + verify/create rg-hd-platform-shared + custom-domain + invariant-20 exception (human-only)](./03-architecture-provision-entra-tenant.md) | Architecture (tracking issue) | 2 | Human | 00, 01, 02 |
| 04 | [Entra App Registration walkthrough doc (portal-based; Bicep deferred to ADR-0077 follow-up)](./04-architecture-entra-app-registration-walkthrough.md) | Architecture | 2 | Agent | 00, 01, 02 |
| 05 | [ADR-0006 Tier-2 rotation extension proposal — resolve the invariant-20 exception (follow-up placeholder)](./05-architecture-adr-0006-tier2-rotation-extension-proposal.md) | Architecture | 3 | Agent | 03 |

## Phase Mapping (ADR-0078 "Follow-up Work" → packets)

ADR-0078's Consequences §"Follow-up Work" checklist, mapped to packets:

| Checklist item | Packet |
|---|---|
| Provision the Entra External ID tenant | packet 03 |
| Provision per-application Entra App Registrations (one for Hearth, queued for the other consumer-app PDRs, one for Notify Cloud) | packet 03 (first App Registration) + packet 04 (walkthrough for subsequent App Registrations); ongoing per consumer-app feature packet |
| Ship `HoneyDrunk.Identity.Providers.Entra` package implementation per ADR-0060 Phase 2 | Not in this initiative; deferred to the first consumer-app feature packet (Hearth signup per PDR-0005 Phase 2) |
| Wire `auth.honeydrunkstudios.com` custom domain to Entra | packet 03 |
| Notify Cloud tenant-operator sign-in adopts Entra (ADR-0027 follow-up) | Not in this initiative; queued under ADR-0027 follow-up (packet 03 of *this* initiative may opt to use Notify Cloud as the first App Registration depending on what the human picks at provisioning time) |
| Bicep templates for Entra App Registration provisioning land in HoneyDrunk.Actions per ADR-0077 | Not in this initiative; queued under ADR-0077 follow-up; packet 04 records the portal-based bridge until then |
| Per-application branding configuration documented per consumer-app PDR | Not in this initiative; per-PDR concern |
| Cost-monitoring per ADR-0052 tracks Entra spend against the D8 thresholds | Not a packet in this initiative; cost-monitoring is a standing ADR-0052 governance concern; the cost baseline ($0 through MVP) is recorded in packet 03's closing comment |
| Scope agent flips Status → Accepted after the first packet declaring this ADR in `accepts:` merges | packet 00 of this initiative |

Every packet 00 carries `accepts: ADR-0078`. Per ADR-0078's "If Accepted" workflow, packet 00's merge triggers the scope agent's auto-flip mechanic for ADR-0078's Status.

## What This Initiative Does NOT Deliver

The following are explicitly out of scope for this initiative. Each becomes a separate packet at the appropriate time:

- **The `HoneyDrunk.Identity.Providers.Entra` package implementation.** Per ADR-0060 D12 Phase 2, the Entra adapter ships with the first user-facing consumer-app feature packet (Hearth signup per PDR-0005). This initiative provisions the infrastructure and writes the configuration shape; the runtime adapter is the consumer-app feature packet's scope.

- **The OAuth 2.1 with PKCE callback HTTP surface.** Per ADR-0060 D12 Phase 2/3, the deployable HTTP surface (`/auth/callback`, `/users/me`, `/.well-known/openid-configuration`) belongs to whichever consumer-app's deployable host composes `HoneyDrunk.Identity`. This initiative provisions the IdP-side endpoint via the Entra tenant; the application-side endpoint is per-consumer-app.

- **The full Identity Node deployable.** Per ADR-0060 D12 Phase 2/3, the Identity Node's Container App (`ca-hd-identity-{env}`), Key Vault (`kv-hd-identity-{env}`), and App Configuration namespace seeding belong with whichever packet first deploys an Identity-composing host. Packet 03 of *this* initiative seeds `kv-hd-platform-shared` (the Grid-wide shared Vault) as a temporary home for the Entra client secret if `kv-hd-identity-{env}` does not yet exist.

- **Bicep templates for Entra App Registration provisioning.** Queued under ADR-0077 follow-up work; packet 04 of this initiative is the portal-based bridge until Bicep's Entra resource coverage closes the gap.

- **MFA enforcement policy.** Per ADR-0078 D10, default at v1 is "optional, user-enrollable." Per-app MFA policy hardens via later per-PDR packets.

- **Social-login provider enablement (Google, Apple, GitHub).** Per ADR-0078 D10, default at v1 is "email-only." Per-app social-login enablement is per-PDR.

- **Per-application branding configuration (logos, color schemes).** Per ADR-0078 D10, per-PDR concern; lands per app at Phase 2.

- **B2B / enterprise workforce identity via Entra.** Per ADR-0078 D10, out of scope. The Grid's identity boundary is consumer / end-user.

- **API-key authentication for the public Grid APIs.** Per ADR-0027, Notify Cloud tenants authenticate API requests with API keys (a different auth surface from end-user identity); out of scope per ADR-0078 D10.

- **Multi-IdP support.** Per ADR-0078 D9's "Adopt multiple IdPs" rejected alternative, one IdP. If a future scenario forces multi-IdP, the wrapping-seam architecture (ADR-0060 D2) supports it via a second `IExternalIdpClaimMapper` implementation, but that work is not scoped here.

## Cross-ADR Dependency — ADR-0060 packet 01

Packets 01 and 02 of this initiative reference Identity context files (`repos/HoneyDrunk.Identity/overview.md`, `boundaries.md`, `integration-points.md`) that **do not yet exist**. They are authored by packet 01 of `adr-0060-identity-standup`. Per the user's scoping refinement:

- Both packets 01 and 02 of this initiative carry explicit Human Prerequisite: "ADR-0060 packet 01 must be merged to main before this packet executes."
- Without that merge, packet 01 of *this* initiative has no `repos/HoneyDrunk.Identity/integration-points.md` or `overview.md` to amend, and packet 02 has no `repos/HoneyDrunk.Identity/` folder to add `entra-configuration.md` to.
- The cross-init dependency is *temporal*, not *machine-readable*: there is no `work-item:01` cross-folder dependency in the frontmatter (the `dependencies:` schema scopes to same-folder packet references or `{Repo}#N` issue refs). The temporal coordination is handled by the human at filing time per the §Filing-Order Rule below.

## Filing-order rule (hard)

1. Push packet 00 of this initiative. Wait for it to merge so invariants 93-94 land in `constitution/invariants.md` and ADR-0078's Status flips.
2. Push packet 01 of this initiative. Wait for ADR-0060 packet 01 to also be merged before opening packet 01's PR (cross-init temporal dep; not enforced by the filing pipeline).
3. Push packets 02 and 04 in the same push (both depend on packets 00 and 01; both are doc-only; they don't conflict). Packet 03 (human-only) can also file in the same push — the chore issue lives on The Hive board and waits on the human's portal session.
4. Wait for packet 03 (human-only) to be Done — the human completes the portal walkthrough. Cross-link the closing comment to the invariant-20 exception record.
5. Push packet 05 (the ADR-0006 amendment proposal). The user picks path (a) or path (b) at draft time; the agent authors the ADR accordingly.

## Notes

- **Why packet 03 is its own item.** Entra tenant creation, App Registration setup, App Configuration seeding, Vault secret storage, Cloudflare CNAME wiring, and invariant-20 exception logging are all portal-based and cannot be delegated to an agent. Surfacing as an explicit Wave-2 work item with `Actor=Human` keeps it visible on The Hive board.
- **Why packet 03 verifies-or-creates `rg-hd-platform-shared`.** Per the scoping refinement, the resource group's existence is verified at provisioning time; if absent, create it (per memory `feedback_provision_when_needed` — provision when first needed, not pre-emptively). The Entra tenant is Grid-wide, so it belongs in a Grid-wide shared resource group, not a per-Node one.
- **Why packet 03 logs the invariant-20 exception in Log Analytics OR a Markdown file.** Per invariant 20: "Exceptions must be logged in Log Analytics." For a solo-dev shop without an established Log Analytics custom-log table, the Markdown route (`governance/exceptions/invariant-20-entra-app-secret.md`) is an acceptable structured-discoverable equivalent. Either way, the exception is discoverable.
- **Why the third candidate invariant ("Auth still issues nothing") is dropped.** ADR-0078 D5 explicitly preserves invariant 10. Restating invariant 10 as a new invariant is noise; the user's scoping refinement explicitly called this out: "size 2 — the 'Auth issues nothing' candidate is a restatement of existing invariant 10, not a new invariant."
- **Why `notes:` is the field name for the IdP provider-slot context.** Per the user's scoping refinement: "use `notes:` field (existing precedent in contracts.json); do NOT invent `provider_slot` field." The `notes:` field name follows the existing precedent in `catalogs/grid-health.json` (where node-level `notes:` is heavily used). Adding a `notes:` field to a node-block in `catalogs/contracts.json` introduces the field there following the same precedent shape; it does not invent a new field name.
- **Why packet 01 includes the `entra-custom-domain-auth-honeydrunkstudios-com` grid-health entry rather than packet 05.** Per the user's scoping refinement: "Custom-domain grid-health entry: add `entra-custom-domain-auth-honeydrunkstudios-com` to packet 01's scope (not just referenced from packet 05)." The custom-domain entry exists from the moment packet 03's provisioning lands; packet 01 registers the surface so the discovery story is correct from Wave 1.
- **Why packet 03 explicitly verifies-or-creates `rg-hd-platform-shared` with rationale.** Per the user's scoping refinement: "explicit step in packet 03 (human-only) to verify-or-create with rationale." The packet's Step 1 walks the user through the check and provides the rationale (Grid-wide shared resources live in `rg-hd-platform-shared`; per-Node resources live in `rg-hd-{service}-{env}`).
- **Why the invariant-20 exception path is option (b) — log the exception now, draft ADR-0006 extension as follow-up.** Per the user's scoping refinement: "Pick (b) and add follow-up packet placeholder for ADR-0006 Tier-2 rotation extension." Path (a) — committing to 90-day rotation — was rejected as operationally too expensive for a solo-dev shop without an `EntraAppRegistrationRotator`. Packet 05 of this initiative is the follow-up.
- **Repos public by default.** All Architecture-repo changes ship public per memory `project_repos_public_by_default`. The Entra-side credentials (tenant ID, client ID) are non-secret and are seeded in App Configuration; the client secret is in Vault and never appears in any committed file. No revenue/compliance/experiment carve-out applies.
- **No ADR numbers in docs or code comments.** Per memory `feedback_no_adr_in_docs`, the consumer-app feature packets that consume `HoneyDrunk.Identity.Providers.Entra` should not cite "ADR-0078" by number in their README narratives; the README explains what the package does. Runtime / packet-data references (catalog entries, frontmatter, this dispatch plan, the CHANGELOG, ADR text itself) are fine to cite ADRs by number.
- **No commits under CHANGELOG Unreleased.** Per memory `feedback_no_unreleased_commits`, every CHANGELOG entry in this initiative lands under the current dated SemVer section, not under `## Unreleased`.
- **No manual packet filing.** Per memory `feedback_no_manual_packet_filing`, `file-work-items.yml` auto-files on push to main. Do not run `gh issue create` against these packets. Filing happens by pushing the packet files into `generated/work-items/active/adr-0078-entra-external-id/`. The §Filing-Order Rule above governs which packets land in which push.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board AND the first consumer-app feature packet (Hearth signup) ships with the `HoneyDrunk.Identity.Providers.Entra` package wired against the Entra tenant + App Registration provisioned here, the entire `active/adr-0078-entra-external-id/` folder moves to `archive/adr-0078-entra-external-id/` in a single commit. Partial archival is forbidden.

The hive-sync agent moves individual closed packet files from `active/` to `completed/` per invariant 37 — that is per-packet lifecycle. Initiative-level archival is the post-completion sweep that follows after the whole folder reaches `Done`.

## Filing

The `file-work-items.yml` workflow in `HoneyDrunk.Architecture` triggers automatically on push to `generated/work-items/active/**/*.md`. No `gh issue create` commands in this dispatch plan — the pipeline handles filing, project-board addition, field population, and `addBlockedBy` wiring from the `dependencies:` frontmatter on each packet. Verify after push by checking The Hive (org Project #4) for the new items and their blocking edges.
