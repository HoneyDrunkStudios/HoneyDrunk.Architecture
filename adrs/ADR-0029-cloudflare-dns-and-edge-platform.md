# ADR-0029: Cloudflare as Registrar, Authoritative DNS, and Edge Platform

**Status:** Accepted
**Date:** 2026-05-08
**Deciders:** HoneyDrunk Studios
**Sector:** Infrastructure

> **Accepted 2026-06-07.** See [`## Acceptance`](#acceptance) and the as-built record in [`generated/work-items/completed/adr-0029-cloudflare-dns-rollout/implementation-notes.md`](../generated/work-items/completed/adr-0029-cloudflare-dns-rollout/implementation-notes.md). The realized scope was **registrar-only** — DNS authority was already on Cloudflare for two of three domains before this ADR, so the migration reduced to transferring the registration. The decision body below is preserved as written; the implementation notes record where reality diverged.

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates infrastructure and catalog obligations that must be completed as follow-up work items (do not accept and leave the catalogs stale):

- [x] Update `infrastructure/reference/vendor-inventory.md` — replace the GoDaddy row with Cloudflare (registrar), keep Cloudflare DNS/CDN row, and update the lock-in assessment to reflect the consolidation *(done in the acceptance PR — GoDaddy row removed; Cloudflare row scoped to registrar + DNS + edge; lock-in row added)*
- [~] Add `infrastructure/cloudflare-account-provisioning.md` — *descoped: the Cloudflare account already existed (and held the two zones) before this ADR; no provisioning walkthrough was authored. The as-built account posture is captured in the implementation notes.*
- [~] Add `infrastructure/cloudflare-domain-transfer.md` — *descoped: with DNS already on Cloudflare the migration was registrar-only (no zone import, no nameserver flip, no cutover smoke). The full DNS-migration walkthrough would have documented ceremony that did not occur; the as-built registrar-transfer recipe (incl. the GoDaddy "Ownership Protection" gotcha) is captured in the implementation notes instead.*
- [x] Migration packets — emitted (P4 `honeydrunkstudios.com`, P5a `tatteddev.com`, P5b `honeyhub.app`) and executed as registrar-only transfers
- [x] Scope agent flips Status → Accepted after the first domain (Studios marketing site) has cut over and the migration walkthrough lands *(flipped in this PR; "walkthrough lands" reinterpreted as the implementation-notes record, since the walkthroughs were descoped)*

## Context

The Grid currently runs with a split between **registrar** (GoDaddy) and **DNS / CDN / DDoS** (Cloudflare), per `infrastructure/reference/vendor-inventory.md` (last updated 2026-04-26). The studio holds multiple domains at GoDaddy and pays the GoDaddy retail-renewal markup on each, with the upsell-and-renewal-noise UX that goes with it. Cloudflare was already chosen for DNS, edge caching, and DDoS protection — but only for the domains that were manually configured to point their nameservers at Cloudflare. Newly registered domains, by default, sit on GoDaddy DNS until that step happens.

Several Grid concerns are starting to consolidate around the "where do public-facing surfaces resolve" question:

1. **The Studios marketing site** (`HoneyDrunk.Studios`, Next.js on Vercel) — the lowest-risk, highest-visibility domain. The vendor inventory shows Vercel as the host; DNS is the seam between the apex domain (`honeydrunkstudios.com`) and Vercel's edge.
2. **Notify Cloud** (ADR-0027, PDR-0002) — names `notify.honeydrunkstudios.com` as the customer-facing API and marketing subdomain. Container Apps custom-domain validation and TLS issuance must compose with whatever authoritative DNS the Grid runs.
3. **Status and support surfaces** — `status.honeydrunkstudios.com` (PDR-0002 §J), `support@honeydrunkstudios.com` (PDR-0002 §J).
4. **Future deployable Nodes on Container Apps** (ADR-0015) — every Container App that the Grid exposes externally needs a custom domain bound to it; the DNS validation and TLS path compose with whatever authoritative DNS provider is in use.
5. **Vault rotation cache invalidation** (ADR-0006, Invariant 21) — the existing Event Grid cache invalidation pattern is unaffected by this decision; it is a runtime-internal concern, not a DNS concern. Called out so that "edge platform" does not get conflated with "edge of the runtime."
6. **CI/CD control plane** (ADR-0012) — `HoneyDrunk.Actions` is the central place any DNS-touching workflow (cert renewal, preview environments, takedown automation) would live.

The Grid's posture across these surfaces is currently inconsistent: some domains terminate TLS at Vercel, some point straight at Azure resources, some are still on GoDaddy DNS. There has been no Grid-wide decision committing to a single registrar + DNS + edge-platform stance, and the cost of leaving that decision implicit is now compounding — every new Node with a public surface re-asks the question, every domain renewal re-pays GoDaddy markup, and there is no documented place for a Grid Node to learn how its public surface should be wired.

This ADR is the platform-of-choice decision: **what does the Grid commit to, in broad strokes, for registrar, authoritative DNS, and edge?** It is deliberately conservative about specific Cloudflare features. Workers, Pages, Tunnel, Access, and R2 are each first-class engineering commitments with their own architecture implications; they are explicitly **not** decided here. They will get their own follow-up ADRs when a Grid Node has a concrete need that justifies adopting them.

The user's framing — explicit on the prompt — is "broad in framing, conservative in scope." This ADR commits to the platform stance and defers the feature-by-feature questions.

## Decision

The Grid commits to **Cloudflare as registrar, authoritative DNS, and edge platform of choice**, with explicit scope limits. The decision is composed of three bound choices and a set of explicit non-decisions.

### D1. Cloudflare is the Grid's domain registrar

All Grid-owned domains move to Cloudflare Registrar. New domain registrations happen at Cloudflare. Existing domains at GoDaddy transfer one at a time, in the order in §Implementation.

**Why Cloudflare over GoDaddy:**

- **At-cost pricing.** Cloudflare Registrar passes the wholesale registry fee through with no markup. GoDaddy's renewal pricing is markup-stacked and gets worse on auto-renew. For a solo dev with multiple domains, the per-year savings compound.
- **API access.** Cloudflare's API is first-class and credentials are scoped tokens with per-zone permissions. GoDaddy's API is gated and frequently behind reseller-tier eligibility. The Grid's automation posture (ADR-0012's CI/CD control plane) presumes API-driven infrastructure.
- **No upsell surface.** GoDaddy's portal interleaves domain management with website-builder, hosting, and email upsells that have no place in the Grid. Cloudflare's portal is operationally narrow.
- **Lock-in posture.** Cloudflare Registrar requires that nameservers point at Cloudflare DNS. That is consistent with D2 below — for the Grid's choice this is alignment, not coupling.

The Grid's domain portfolio at this ADR's date includes `honeydrunkstudios.com` and additional domains held at GoDaddy. Specific domains are enumerated in the migration walkthrough packet, not in this ADR.

### D2. Cloudflare is the Grid's authoritative DNS

All DNS records for Grid-owned domains are managed in Cloudflare. The authoritative nameservers for every Grid domain are Cloudflare's.

**Why Cloudflare for authoritative DNS:**

- **Free tier covers the Grid's full DNS footprint** at current and foreseeable scale. There is no per-zone, per-record, or per-query cost for the basic DNS service. The first time a paid feature is genuinely needed (e.g., Cloudflare for SaaS for Notify Cloud customer custom domains, deferred to a follow-up ADR), the cost is justified by a concrete consumer.
- **Uniform proxy/CDN seam.** Cloudflare's authoritative DNS and its proxy/CDN/DDoS layer are the same control plane. Toggling "proxied" on or off per record is a single click in the portal — there is no separate CDN integration step.
- **Container Apps custom-domain compatibility.** Azure Container Apps validates custom domains via a TXT record (`asuid.{subdomain}`) plus a CNAME or A record pointing at the Container App's ingress. Cloudflare DNS supports both record types natively, including the TXT-validated, CNAME-pointed pattern. The proxied vs. DNS-only choice is per-record (D3 names the default).
- **Vercel custom-domain compatibility.** Vercel validates custom domains via CNAME records for subdomains and via A/AAAA records (or CNAME at the apex through Cloudflare's CNAME flattening) at the root. Cloudflare supports all of these — including apex CNAMEs natively, rather than via a separate ALIAS record type.

**Management mode — portal-managed at v1, IaC deferred.**

DNS records are managed through the Cloudflare dashboard, not Terraform / Pulumi / OpenTofu. Rationale:

- Aligns with the repo's documented portal-first convention for infrastructure workflows ([`infrastructure/README.md`](../infrastructure/README.md)) — the same logic that applies to Azure applies to Cloudflare.
- Solo-dev scale: the DNS footprint is small enough that drift is observable by inspection in the Cloudflare dashboard. The cost of standing up Terraform state, drift detection, and a CI workflow for DNS exceeds the maintenance cost of clicking-through changes for the foreseeable Grid size.
- Cloudflare's portal change history is sufficient for solo-dev audit purposes.
- The decision is reversible. If a future ADR-driven concern (preview environments per pull request, mass migrations, multi-account governance) makes IaC concretely worth the operational cost, that is a separate ADR. Until then: portal.

When future automation needs a Cloudflare API token, it is stored in the consuming Node's per-Node vault per ADR-0005's secret-naming convention (`Cloudflare--ApiToken`). This ADR does not create or assume a shared vault — ADR-0005 explicitly forbids one until a real cross-Node secret appears, and that gating decision belongs to a follow-up ADR, not this one. No automation lands at this ADR. Manual DNS changes through the portal are the supported path at v1.

### D3. Cloudflare is the Grid's edge platform of choice — feature decisions deferred

When a Grid concern needs CDN, edge caching, DDoS protection, WAF, or edge-compute, **Cloudflare is the default consideration**. This ADR does not adopt any specific Cloudflare feature beyond proxied DNS — it commits the Grid to evaluating Cloudflare first when an edge-shaped need arises.

**Default proxy posture:**

- **Public marketing surfaces (Studios website, future status page) — proxied (orange-cloud).** CDN, DDoS protection, and WAF default-on are the right v1 stance for static-content surfaces.
- **API-shaped surfaces backed by Container Apps (e.g. `notify.honeydrunkstudios.com`) — DNS-only (grey-cloud) at v1 unless a concrete reason to proxy emerges.** Container Apps already terminates TLS, the API surface is auth-gated, and Cloudflare proxying a gRPC / HTTP/2 API surface introduces compatibility and observability questions that this ADR is not the right place to settle. When Notify Cloud's commercial launch produces concrete WAF / DDoS / customer-domain requirements, that is the ADR that flips the toggle and explains why.
- **Email-related records (MX, SPF, DKIM, DMARC) — DNS-only by definition.**

The proxied vs. DNS-only decision is per-record and revisitable; this ADR sets defaults, not invariants.

### D4. Explicit non-decisions

This ADR **does not** adopt the following Cloudflare features. Each gets its own follow-up ADR scoped to the Node that needs it:

- **Workers (edge compute).** No Grid Node currently has a workload that fits the Worker shape. Defer until a concrete use case (e.g., a pre-Container-Apps cheap edge function) materializes.
- **Pages (static hosting).** The Studios website currently runs on Vercel. Migrating to Cloudflare Pages is plausible but introduces a build-pipeline change and the Vercel-specific feature usage (currently minimal per the vendor inventory's lock-in assessment) needs a concrete inventory before commitment. Open question — flagged explicitly.
- **Tunnel (private-service exposure).** No private services that need external reach exist yet. When an admin / operator surface (HoneyHub UI per ADR-0003, internal Pulse dashboards, etc.) needs reach without a public ingress, Tunnel is a strong candidate — but this ADR does not adopt it.
- **Access (Cloudflare's identity proxy).** The Grid has `HoneyDrunk.Auth` for JWT bearer validation. Where Cloudflare Access overlaps with Auth is a non-trivial boundary question that this ADR is not the right place to answer. Defer to the first ADR that has a concrete admin / staff surface needing zero-trust reach.
- **R2 (object storage).** Notify and Pulse use Azure Blob today. R2 has cost-egress advantages but introduces a second cloud's storage primitive into the Grid. Defer until a workload's cost profile makes R2 concretely worth the cross-cloud surface.
- **Cloudflare for SaaS (customer-facing custom domains).** Notify Cloud's customer-domain story (PDR-0002 open question) is the most likely first consumer. Defer to that ADR.
- **DNS-as-IaC (Terraform / OpenTofu).** Deferred per D2.

The negative form: do not assume any feature in this list is "in" simply because Cloudflare is the platform of choice. Each feature is a per-Node engineering decision.

### D5. Cloudflare API token handling follows the existing secrets pattern

When Cloudflare API automation lands (it does not, in this ADR), tokens are scoped per-zone or per-purpose, stored in Key Vault at `Cloudflare--ApiToken` (or `Cloudflare--{Purpose}--ApiToken` when multiple tokens are needed), and accessed via `ISecretStore` (Invariant 9). Tokens carry the minimum permissions required for their use — the Cloudflare API supports per-zone, per-permission scoping, which composes well with the secret-rotation lifecycle in ADR-0006 Tier 2.

No tokens are provisioned by this ADR. The naming convention is recorded so the first packet that needs one knows where to put it.

### D6. Tag / record-comment scheme is lean

Per the Grid's lean Azure tag scheme (env always, node for per-Node, purpose=platform-shared for shared, never `initiative`), Cloudflare DNS record comments (where used) follow the same minimal posture: record purpose only, not initiative names or owners. Cloudflare does not have first-class tags on records the way Azure resources do, but the comment field exists and gets used the same way: `purpose=studios-apex`, `purpose=notify-cloud-api`, etc. No `initiative` or `created-by-agent` noise.

## Consequences

### Affected Nodes

- **`HoneyDrunk.Studios`** — first cutover. The marketing-site DNS apex (`honeydrunkstudios.com`) and `www` move authoritative DNS to Cloudflare; Vercel custom-domain integration is reconfirmed. Vercel hosting is unchanged.
- **`HoneyDrunk.Notify.Cloud`** (ADR-0027, Proposed) — the `notify.honeydrunkstudios.com` subdomain points to the Container App's ingress; DNS records are created when the Container App is provisioned. No code change in the Node; only ingress configuration.
- **`HoneyDrunk.Architecture`** — gains the two infrastructure walkthroughs (account provisioning, domain transfer) and the vendor-inventory update. No catalog-graph changes (Cloudflare is a vendor, not a Node).
- **`HoneyDrunk.Vault`** — no code change. The Cloudflare API token, when first issued, is stored in a Vault per the existing pattern (D5).
- **`HoneyDrunk.Actions`** — no code change at acceptance. Future packets that introduce DNS-touching workflows (e.g., automated zone-record updates for preview environments) compose against the documented secret name from D5.

### Operational Consequences

- **Domain renewal cost decreases** by the GoDaddy markup, per domain. Concrete annual savings are in the migration packet, not this ADR.
- **One vendor instead of two for domain + DNS.** Vendor-lock-in assessment shifts marginally — the Cloudflare row in `vendor-inventory.md` becomes higher-impact (registrar + DNS + edge), GoDaddy's row goes away. Mitigation: domain transfers are reversible (a future transfer back out is mechanically supported); DNS records are exportable as a zone file at any time; Cloudflare does not gate either direction.
- **Vercel's domain-management UX** (currently driven from inside Vercel against GoDaddy's nameservers via Cloudflare proxy) becomes simpler: a single nameserver delegation point, with all records visible in Cloudflare.
- **Per-record tagging** stays minimal per D6. Record comments document purpose only.

### New Invariants

None proposed at this ADR. Cloudflare adoption is a vendor / platform commitment, not a code-shape rule. If a downstream ADR introduces a rule (e.g., "all Grid public surfaces sit behind Cloudflare proxy unless explicitly opted out"), that ADR records its own invariant.

### Catalog Obligations

- `infrastructure/reference/vendor-inventory.md` — collapse the GoDaddy row out and update the Cloudflare row's scope to include registrar.
- No `catalogs/` changes. Cloudflare is a vendor, not a Node, and is not represented in `catalogs/nodes.json` or `catalogs/relationships.json`.

### Negative

- **Cloudflare account becomes a single point of compromise for the Grid's external surface.** A compromise of the Cloudflare account allows DNS rewriting across every Grid domain. Mitigation: hardware-key-backed 2FA on the Cloudflare account is mandatory at the migration packet; Registrar-level transfer lock is enabled; per-zone API tokens are scoped narrowly per D5.
- **Dependency on a single vendor for registrar + DNS + edge is real.** Mitigation: the lock-in is structural for any Grid that wants a cohesive edge story (the alternative — registrar at vendor A, DNS at vendor B, edge at vendor C — produces three vendor surfaces for a one-person operations posture). Cloudflare's reversibility (transfer-out, zone-export) keeps the exit door open.
- **DNS-as-portal foregoes the audit trail / drift-detection surface IaC would provide.** Mitigation per D2: at the Grid's current footprint, manual portal changes plus Cloudflare's built-in change log is sufficient. The decision is named explicitly so it can be revisited when scale changes.
- **Several feature decisions are deferred.** A reader of this ADR could reasonably want to know whether the Grid uses Workers / Pages / Tunnel / Access / R2 today — and the answer is "no, and each gets its own ADR." The negative is the proliferation of small follow-up ADRs as Cloudflare features get adopted one-at-a-time. Mitigation: that is the explicit shape this ADR chose; bundling the feature decisions would couple commitments that should remain independent.
- **Studios website on Vercel + Cloudflare DNS produces a cache-and-proxy stack the studio runs through occasionally.** Mitigation: the v1 default per D3 is proxied (orange-cloud) for static surfaces, which is the standard Cloudflare-fronts-Vercel pattern and is well-documented.

## Implementation

The migration is sketched here; full per-domain packets are scope-agent's output, not part of this ADR.

**Migration order — lowest risk first:**

1. **`honeydrunkstudios.com`** (Studios marketing site, Vercel-hosted). Lowest risk — static content, established pattern, full TLS termination at Vercel through Cloudflare proxy. Cutover validates the end-to-end transfer flow with the smallest blast radius.
2. **Any other apex domain currently held at GoDaddy** — one packet per domain, in increasing order of "what depends on it."
3. **`notify.honeydrunkstudios.com`** (Notify Cloud) — only after the apex is moved and Notify Cloud's Container App is ready. The subdomain sits under the apex once authority is at Cloudflare; no additional transfer is required.
4. **`status.honeydrunkstudios.com`** and other future subdomains — created at Cloudflare when the consuming Node ships. No migration step required after the apex moves.

**Per-domain transfer steps** (sketched; full walkthrough in the migration packet):

1. Unlock the domain at GoDaddy and request the transfer authorization code.
2. Take a full snapshot of GoDaddy DNS records (zone export) for rollback.
3. Initiate transfer at Cloudflare; pre-populate the zone with the snapshot's records.
4. Approve the transfer; wait for it to complete (typically 5–7 days, per registrar policy).
5. After transfer completion, verify nameservers, TLS, and any consumer-Node ingress.
6. Apply Registrar-level transfer lock at Cloudflare.
7. Update `infrastructure/reference/vendor-inventory.md` and the relevant Node's repo context if the domain crosses a Node boundary.

**No automation at v1** — every step is manual portal work per D2 and the user's portal-over-CLI preference.

## Alternatives Considered

### Stay on GoDaddy for the registrar; keep Cloudflare DNS-only

Rejected. Two-vendor split for "registrar over here, DNS over there" produces ongoing GoDaddy markup costs and a second portal to manage. The per-domain savings and the API quality alone make the consolidation worth the one-time transfer effort. There is no domain-portfolio reason to keep GoDaddy as registrar.

### Move to a different registrar (Namecheap, Porkbun, AWS Route 53 registrar)

Rejected. Each is a credible at-cost registrar option, but none produces the alignment with DNS + edge that Cloudflare does. Picking a different registrar would mean Cloudflare DNS keeps managing zones whose authoritative source is a different vendor's registrar lock — a strictly worse arrangement than registrar + DNS at the same control plane.

### Move authoritative DNS to Azure DNS and keep Cloudflare for proxy / WAF only

Rejected. Azure DNS is fine as a primitive but introduces a second control plane for DNS records and forces every Grid record to be created in two places (Azure DNS for authority, Cloudflare for proxy via CNAME flattening or a second zone). The integration produces more moving parts, more cost (Azure DNS hosted-zone fees vs. Cloudflare's free tier), and worse ergonomics. Cloudflare is competent as authoritative DNS; using it for both authority and proxy is the simpler arrangement.

### Adopt Cloudflare and decide the full feature set (Workers, Pages, Tunnel, Access, R2) in one ADR

Rejected. The user's explicit framing is "broad in framing, conservative in scope." Each feature has its own engineering implications, and adopting them all at once couples commitments that should be independent. Forcing the question now would either over-adopt (commit to Tunnel before there is an admin surface that needs it) or under-decide (handwave each feature without a real evaluation). The follow-up-ADR-per-feature shape lets each adoption be justified by the Node that needs it.

### Manage DNS as IaC (Terraform / OpenTofu / Pulumi) from day one

Rejected at v1. The repo's portal-first convention for infrastructure workflows ([`infrastructure/README.md`](../infrastructure/README.md)) applies to Cloudflare for the same reason it applies to Azure: at solo-dev scale with a small footprint, the operational cost of standing up IaC state, drift detection, and a CI lane for DNS exceeds the maintenance cost of clicking through portal changes. Cloudflare's change log is sufficient audit at this scale. Revisit if the Grid's DNS footprint or the team shape changes — but not as part of this ADR.

### Migrate the Studios website to Cloudflare Pages as part of this ADR

Rejected. Pages is a credible Vercel alternative, but the migration is a separate engineering decision: it touches the Next.js build pipeline, requires re-evaluation of any Vercel-specific runtime features (preview deployments, edge functions), and produces a cutover that is independent of registrar + DNS. Bundling it into this ADR would couple the broad platform-choice decision to a hosting migration that deserves its own evaluation. Flagged as an open question for a future ADR.

### Adopt Cloudflare Tunnel for `HoneyDrunk.Auth` admin surfaces or HoneyHub now

Rejected. There is no admin surface in production that needs Tunnel today. ADR-0003 (HoneyHub Phase 1) is the most likely first consumer, and that decision is appropriately scoped to the HoneyHub stand-up work — not to a registrar / DNS ADR.

## Open Questions

Items that should become their own ADRs or packets later:

- **Vercel vs. Cloudflare Pages for the Studios website.** Per D4. Migration is plausible but unbundled from this ADR.
- **Cloudflare Access vs. HoneyDrunk.Auth for staff / admin surfaces.** Per D4. The boundary between Cloudflare's identity proxy and the Grid's Auth Node is non-trivial and waits for a concrete admin-surface ADR.
- **Cloudflare Tunnel for private services.** Per D4. Waits for the first private surface that needs external reach.
- **Cloudflare for SaaS for Notify Cloud customer-facing custom domains.** Per D4 and PDR-0002 §Open Questions. Likely first paid-feature consumer.
- **R2 vs. Azure Blob for object storage.** Per D4. Cost-driven; waits for a workload whose egress profile makes R2 worth the cross-cloud surface.
- **DNS-as-IaC.** Per D2. Revisit when the DNS footprint, contributor count, or audit requirements change.
- **Workers as a pre-Container-Apps cheap edge layer.** Per D4. Waits for a concrete workload whose shape is wrong for Container Apps but right for Workers.

## Acceptance

Accepted on 2026-06-07 after all three Grid-owned apex domains — `honeydrunkstudios.com`, `tatteddev.com`, and `honeyhub.app` — were moved to Cloudflare Registrar with Cloudflare authoritative DNS, and the GoDaddy registrar relationship was wound down (all GoDaddy auto-renewals cancelled).

**Realized scope was registrar-only, not a DNS migration.** The Cloudflare account already existed and was already authoritative DNS for `honeydrunkstudios.com` and `tatteddev.com` before this ADR (set up during the retired ADR-0044 Tunnel work). What remained was transferring the *registration* off GoDaddy. Because the zones were already on Cloudflare, the registrar transfers touched no DNS records and caused no downtime — D1 was the substantive work; D2 was largely already true. `honeyhub.app` was parked at GoDaddy and was first onboarded as a Cloudflare zone, then transferred.

D3 (edge proxy posture), D4 (deferred features), D5 (API token handling — no token provisioned), and D6 (lean record comments) are accepted as written and unchanged in practice.

## Implementation Notes

As-built record (decided ➜ as-built deltas, the registrar-transfer recipe, and the GoDaddy email-billing finding): [`generated/work-items/completed/adr-0029-cloudflare-dns-rollout/implementation-notes.md`](../generated/work-items/completed/adr-0029-cloudflare-dns-rollout/implementation-notes.md).
