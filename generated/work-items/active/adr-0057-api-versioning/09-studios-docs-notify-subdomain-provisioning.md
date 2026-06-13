---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Studios
labels: ["feature", "tier-2", "core", "ops", "adr-0057", "wave-4", "human-only"]
dependencies: ["work-item:00", "work-item:02"]
adrs: ["ADR-0057", "ADR-0029"]
wave: 4
initiative: adr-0057-api-versioning
node: honeydrunk-studios
---

# Provision docs.notify.honeydrunkstudios.com — Cloudflare DNS + Pages project (Studios-sector handoff)

## Summary
Per ADR-0057 §Consequences/Cross-ref Studios sector, every new API surface that ships requires a Studios-side packet to provision the docs subdomain. This packet is the first concrete instance: provision the Cloudflare DNS CNAME for `docs.notify.honeydrunkstudios.com`, create the Cloudflare Pages project `honeydrunk-docs-notify`, bind it to the `HoneyDrunk.Notify` repo, attach the custom domain, verify TLS issuance. Document the provisioning in the Studios repo (the Studios sector owns the `*.honeydrunkstudios.com` subdomains per ADR-0029). This is `Actor=Human` — Cloudflare portal work + Pages project creation are not automatable from the file-work-items pipeline. The provisioning playbook authored in packet 02 of this initiative is the operator's checklist.

## Context
ADR-0057 D15 commits docs hosting at `docs.{api}.honeydrunkstudios.com`. Per §Consequences/Cross-ref Studios sector, the Studios sector (per ADR-0029) owns the apex `honeydrunkstudios.com` and `*.honeydrunkstudios.com` subdomains. New API docs subdomains are Studios-sector responsibility. Packet 02 of this initiative authored the per-API docs-subdomain provisioning playbook at `infrastructure/walkthroughs/public-api-docs-subdomain-provisioning.md` in the Architecture repo; this packet consumes it for the first concrete instance.

`HoneyDrunk.Notify` is the first surface to ship a v1 OpenAPI spec + docs (packet 08). Its docs site lives at `docs.notify.honeydrunkstudios.com/v1/`. Without the Cloudflare DNS + Pages provisioning, packet 08's `job-publish-docs.yml` workflow runs in dry-run mode — the build succeeds, the artifact is uploaded, but no public URL serves the content. This packet flips the dry-run to real-publish for Notify.

The provisioning is **all portal work** per the user's `feedback_portal_over_cli` standing convention:
1. Cloudflare DNS — add CNAME at `docs.notify.honeydrunkstudios.com` pointing to the Pages target.
2. Cloudflare Pages — create the project, bind to repo, attach custom domain, verify TLS.

No code, no Bicep template, no script. The Studios repo documents the provisioning in its README or in a `studios/dns-records.md` (or equivalent) so the record is auditable.

This is `Actor=Human` because the entire packet is portal work. The agent has nothing to delegate. Per the user's `project_human_only_convention`, `Actor=Human` packets carry the `"human-only"` label in frontmatter; the file-work-items pipeline routes them onto The Hive with the appropriate `Actor=Human` field on the project board.

Future per-API docs subdomains (Web.Rest's `docs.web-rest.honeydrunkstudios.com`, HoneyHub's `docs.honeyhub.honeydrunkstudios.com`, future Billing's `docs.billing.honeydrunkstudios.com`, Notify Cloud's `docs.notify-cloud.honeydrunkstudios.com`) follow the same playbook in their own respective standup or follow-up packets. This packet is the **template** — its post-merge state (DNS record present, Pages project named per convention, TLS verified, documented in Studios) is the pattern subsequent provisioning packets replicate.

## Scope
- **Cloudflare DNS** — add a CNAME record at `docs.notify.honeydrunkstudios.com` (the per-domain root of `honeydrunkstudios.com` is Cloudflare-managed per ADR-0029) pointing to the Cloudflare Pages target (`honeydrunk-docs-notify.pages.dev` once the Pages project is created).
- **Cloudflare Pages** — create a new Pages project named `honeydrunk-docs-notify`. Bind to the `HoneyDrunkStudios/HoneyDrunk.Notify` repo on the `main` branch. Build configuration:
  - Build command: matches what `job-publish-docs.yml` (packet 05) emits — typically `npm run build` from the `docs/` directory.
  - Output directory: `docs/build/` (Docusaurus default within the per-API repo's `docs/` directory).
  - Environment variables: none beyond the build defaults.
- **Custom domain** — attach `docs.notify.honeydrunkstudios.com` to the Pages project. Cloudflare-managed TLS certificate auto-issuance; verify the cert is live.
- **Access policy** — leave as none (public docs per packet 02's playbook default).
- **Documentation** — in the Studios repo, append an entry to `studios/dns-records.md` (or the equivalent existing convention) noting: the CNAME, the Pages project name, the bound repo + branch, the custom domain, the public access posture, the cross-link to packet 02's playbook + ADR-0057 D15.
- **Verification** — `curl -I https://docs.notify.honeydrunkstudios.com/` returns 200 (or the meta-refresh redirect to `/v1/` per packet 05's workflow); the TLS certificate is Cloudflare-issued; the v1 narrative + reference pages load when packet 08's first real-publish tag push completes.
- **`HoneyDrunk.Studios/README.md`** — link to the new dns-records.md entry from any existing docs-subdomains or infrastructure section.

## Proposed Implementation
This packet is **Actor=Human** — the operator performs each step in the portal and records the outcome. The packet body is a checklist the operator follows.

1. **Cloudflare DNS** — log into the Cloudflare dashboard; navigate to the `honeydrunkstudios.com` zone; under DNS → Records, click **Add record**:
   - Type: CNAME
   - Name: `docs.notify`
   - Target: `honeydrunk-docs-notify.pages.dev` (this target does not exist yet — create the Pages project first per step 2, then come back and finalize the DNS target; Cloudflare allows the DNS record to be created with a placeholder target and updated)
   - Proxy status: Proxied (orange cloud ON) — TLS at the edge per ADR-0029
   - TTL: Auto
   - Save.
2. **Cloudflare Pages** — navigate to Workers & Pages → Create application → Pages → Connect to Git:
   - Select the `HoneyDrunkStudios/HoneyDrunk.Notify` repo.
   - Branch: `main`.
   - Project name: `honeydrunk-docs-notify` (this is the Pages project name; the resulting `*.pages.dev` URL is `honeydrunk-docs-notify.pages.dev`).
   - Build settings:
     - Framework preset: Docusaurus.
     - Build command: leave default or match `npm run build`.
     - Build output directory: `docs/build/`.
     - Root directory (advanced): `docs/` (Cloudflare runs the build from this subdirectory).
   - Save and deploy. The first deploy will likely fail or be empty until packet 08 ships the `docs/` scaffold + an OpenAPI spec to render — that's expected; the project provisioning is what matters here.
3. **Custom domain attachment** — in the Pages project's Custom domains tab → **Set up a custom domain** → enter `docs.notify.honeydrunkstudios.com` → Cloudflare verifies the DNS record (the CNAME from step 1) and provisions the cert. Wait for the cert to issue (typically <5 minutes).
4. **Verification** — `curl -I https://docs.notify.honeydrunkstudios.com/` returns a 200 (or 301/302 redirect — both are acceptable; the meta-refresh from packet 05's root index redirects to `/v1/`). The TLS certificate is Cloudflare-issued (check via `openssl s_client -connect docs.notify.honeydrunkstudios.com:443 -servername docs.notify.honeydrunkstudios.com`). If packet 08's first publish has not yet occurred, the deployed content is the Cloudflare placeholder "no deployments yet" page — that is acceptable until packet 08's `notify-api-v1.0.0` tag push completes.
5. **Documentation in `HoneyDrunk.Studios/`** — append to `studios/dns-records.md` (or the existing equivalent — `infrastructure/dns/` or similar; match the existing convention; if no such file exists, create `studios/dns-records.md` with a header section and this first entry):
   ```markdown
   ## docs.notify.honeydrunkstudios.com

   - **Purpose:** Public docs for `HoneyDrunk.Notify` per ADR-0057 D15.
   - **DNS:** CNAME at `docs.notify` in the `honeydrunkstudios.com` Cloudflare zone, proxied, pointing to `honeydrunk-docs-notify.pages.dev`.
   - **Cloudflare Pages project:** `honeydrunk-docs-notify`.
   - **Bound repo / branch:** `HoneyDrunkStudios/HoneyDrunk.Notify` / `main`.
   - **Build:** Docusaurus from `docs/` subdirectory; output `docs/build/`.
   - **Access:** Public.
   - **TLS:** Cloudflare-managed.
   - **Provisioned:** 2026-MM-DD (PR #).
   - **Cross-references:** ADR-0057 D15, ADR-0029 (Cloudflare DNS), packet 02 of `adr-0057-api-versioning` initiative (provisioning playbook).
   ```
6. **`HoneyDrunk.Studios/README.md`** — link to `studios/dns-records.md` from any existing infrastructure or docs section.
7. **Re-run packet 08's publication workflow** — once provisioning is verified, the operator (or a follow-up agent) re-runs the `job-publish-docs.yml` workflow on the existing `notify-api-v1.0.0` tag (`gh workflow run release-api.yml -R HoneyDrunkStudios/HoneyDrunk.Notify --ref notify-api-v1.0.0`) to deploy the Notify docs for real. The workflow now finds the Pages project; the deploy succeeds.

## Affected Files
- **Cloudflare portal state** (DNS record + Pages project) — not file-tracked.
- `HoneyDrunk.Studios/studios/dns-records.md` (new or appended-to)
- `HoneyDrunk.Studios/README.md` (link added if applicable)
- `HoneyDrunk.Studios/CHANGELOG.md` (dated, versioned entry recording the provisioning)

## NuGet Dependencies
None. Portal work + docs.

## Boundary Check
- [x] Cloudflare DNS + Pages provisioning per ADR-0029 + ADR-0057 D15. Studios sector owns `*.honeydrunkstudios.com` subdomains.
- [x] No code change in any other repo.
- [x] No new abstraction or contract.
- [x] Follows the playbook authored in packet 02.

## Acceptance Criteria
- [ ] CNAME record at `docs.notify.honeydrunkstudios.com` exists in Cloudflare DNS, proxied, pointing to `honeydrunk-docs-notify.pages.dev`
- [ ] Cloudflare Pages project `honeydrunk-docs-notify` exists, bound to `HoneyDrunkStudios/HoneyDrunk.Notify` / `main`, with Docusaurus build config and `docs/build/` output
- [ ] Custom domain `docs.notify.honeydrunkstudios.com` is attached to the Pages project with verified Cloudflare-managed TLS
- [ ] `curl -I https://docs.notify.honeydrunkstudios.com/` returns 200 (or a 301/302 to `/v1/`)
- [ ] `HoneyDrunk.Studios/studios/dns-records.md` (or the equivalent existing file) documents the new subdomain with the fields in step 5
- [ ] `HoneyDrunk.Studios/README.md` links to the dns-records entry if a related section exists
- [ ] `HoneyDrunk.Studios/CHANGELOG.md` records the provisioning in a dated, versioned entry (no `[Unreleased]`)
- [ ] Packet 08's publication workflow re-runs successfully on the existing `notify-api-v1.0.0` tag (once packet 11's credentials are also seeded — the docs portion of the workflow uses the `CLOUDFLARE_API_TOKEN` from packet 11)

## Human Prerequisites
- [ ] **Cloudflare account access** with permission to edit DNS records in the `honeydrunkstudios.com` zone and to create Pages projects on the HoneyDrunk Studios account.
- [ ] **GitHub App permission** for Cloudflare Pages to read the `HoneyDrunk.Notify` repo (the connect-to-Git step requires authorizing the Cloudflare GitHub App on the org; one-time consent per organization).
- [ ] **Packet 02's playbook is the canonical reference** — `infrastructure/walkthroughs/public-api-docs-subdomain-provisioning.md` in the Architecture repo.
- [ ] **This packet is `Actor=Human`** — the agent cannot perform portal work. The operator follows the checklist and records the outcome.

## Referenced ADR Decisions
**ADR-0057 D15 — Per-API docs site composition + hosting.** `docs.{api}.honeydrunkstudios.com`. Per-major path prefix. Scalar + Docusaurus composition (packet 05's workflow builds; this packet provides the hosting target).

**ADR-0057 §Consequences/Cross-ref Studios sector.** "The docs subdomains are managed under the Studios sector (per ADR-0029's marketing/docs surface ownership). Each new API surface that ships requires a Studios-side packet to provision the docs subdomain."

**ADR-0029 (referenced) — Cloudflare DNS rollout.** Cloudflare-managed zone for `honeydrunkstudios.com`; CNAME + Pages target convention.

**Packet 02 of this initiative (referenced) — Per-API docs-subdomain provisioning playbook.** This packet consumes the playbook for the first concrete instance.

## Constraints
- **Portal-only.** No Bicep / CLI / scripts. Per the user's `feedback_portal_over_cli` standing convention.
- **Public access default.** No Cloudflare Access policy on the Notify docs subdomain.
- **Build from `docs/` subdirectory.** Notify's Docusaurus scaffold (per packet 08) lives at `HoneyDrunk.Notify/docs/`; Pages builds from there.
- **No autoscale / paid tier.** Cloudflare Pages free tier is sufficient per the user's `feedback_default_cheapest_azure_tier` rule extended to vendor SaaS.
- **This packet is the template** for subsequent per-API docs-subdomain provisioning. Future provisioning packets (Web.Rest's, HoneyHub's, future Billing's, Notify Cloud's) follow the same shape.
- **Re-run of packet 08's workflow** completes the loop — once the Pages project + credentials exist, the workflow publishes for real.
- **No `Unreleased` CHANGELOG.**

## Labels
`feature`, `tier-2`, `core`, `ops`, `adr-0057`, `wave-4`, `human-only`

## Agent Handoff

**Objective:** First concrete docs-subdomain provisioning per ADR-0057 D15 + ADR-0029. Cloudflare DNS CNAME + Pages project + custom domain + TLS verification for `docs.notify.honeydrunkstudios.com`. Document in Studios. This is `Actor=Human` — entirely portal work.

**Target:** `HoneyDrunk.Studios`, branch from `main` for the documentation commit; Cloudflare portal for the actual provisioning.

**Context:**
- Goal: Flip packet 08's docs publication from dry-run to real. First concrete instance of the per-API docs-subdomain pattern.
- Feature: ADR-0057 rollout, Wave 4 (Studios-side provisioning paired with the Notify Phase 2 pilot).
- ADRs: ADR-0057 D15 + §Consequences/Cross-ref Studios sector (primary); ADR-0029 (Cloudflare DNS).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0057 Accepted.
- `work-item:02` — provisioning playbook authored.
- Coordinates with `work-item:08` (Notify Phase 2) but does not strictly block it — packet 08 ships in dry-run, this packet flips it to real on re-run.

**Constraints:**
- `Actor=Human` — portal work; no agent delegation.
- Cloudflare account access required.
- Public access default.
- Pages free tier.
- Template for future per-API instances.
- No `Unreleased` CHANGELOG.

**Key Files:**
- `HoneyDrunk.Studios/studios/dns-records.md`
- `HoneyDrunk.Studios/README.md` (link only)
- `HoneyDrunk.Studios/CHANGELOG.md`
- Cloudflare portal state (DNS + Pages — not file-tracked)

**Contracts:** None.
