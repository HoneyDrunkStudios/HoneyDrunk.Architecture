# Dispatch Plan: ADR-0029 Cloudflare DNS & Edge Platform Rollout

**Date:** 2026-05-09
**Trigger:** ADR-0029 (Cloudflare as Registrar, Authoritative DNS, and Edge Platform) proposed — consolidates registrar + DNS + edge onto Cloudflare and migrates the studio's three apex domains off GoDaddy
**Type:** Multi-packet, single repo (Architecture) for the doc/walkthrough work; per-domain migration packets are also Architecture-targeted because the work product is portal-clicks plus catalog updates, not code in any Node
**Sector:** Infrastructure
**Site sync required:** No
**Rollback plan:** Domain transfers are reversible — GoDaddy → Cloudflare can be reversed (transfer back out) at any time, and Cloudflare zones export to a standard zone file. If a cutover surfaces a problem, rollback is portal: re-point nameservers at GoDaddy / re-import the zone file. No code rollback. The ADR remains Proposed until P4's Studios-domain cutover is verified, so any showstopper before then leaves no in-flight code or board state to unwind. Per-record rollback during the post-cutover smoke window (T+0 to T+48h) is per-record at Cloudflare — re-paste the value from the BIND export — without touching the registrar.

## Summary

ADR-0029 commits the Grid to Cloudflare as registrar, authoritative DNS, and edge platform of choice — with explicit deferral of feature-by-feature questions (Workers, Pages, Tunnel, Access, R2, Cloudflare for SaaS, DNS-as-IaC). The follow-up rollout has three doc deliverables (Wave 1) and three concrete per-domain migration packets (P4 in Wave 2, P5a + P5b in Wave 3) covering the studio's three GoDaddy-held apex domains: `honeydrunkstudios.com` (Studios marketing site, P4), `tatteddev.com` (P5a), `honeyhub.app` (P5b).

- **P1** (`vendor-inventory.md` transitional annotation) — small, self-contained, lands first. Adds a "transfer-in-flight per ADR-0029" note to the GoDaddy and Cloudflare rows. Does not collapse the GoDaddy row out yet — that edit is incremental across the rollout (P4 expands Cloudflare scope; P5a / P5b flip per-domain state; whichever P5 packet is last to merge performs the closing edit that removes the GoDaddy row entirely). Catalog stays honest at every PR-merge boundary.
- **P2** (`cloudflare-account-provisioning.md`) — portal walkthrough for the Cloudflare account itself, the API token convention (split by consumer — runtime tokens in per-Node Key Vault, workflow tokens in GitHub Environment secrets per ADR-0012), and the lean record-comment scheme.
- **P3** (`cloudflare-domain-transfer.md`) — generic per-domain transfer walkthrough that P4 / P5a / P5b follow. Includes the post-cutover smoke contract (T+0 to T+48h: mail-loop probe, third-party verification record reachability, DMARC `rua=` reachability), DNSSEC pre-transfer check, and GoDaddy 2FA verification check.
- **P4** (`honeydrunkstudios.com` cutover) — Wave 2. Triggers ADR-0029 Status flip to Accepted. Vendor-inventory state-flip edits land here (Cloudflare row scope expanded to include Registrar; lock-in assessment row added). Marked `human-only` — user owns the multi-day operational sequence; agent owns verification + bookkeeping.
- **P5a** (`tatteddev.com` cutover) — Wave 3. Marked `human-only`. Conditional closing-edit branch on `vendor-inventory.md` based on P5b's merge state at PR-open time.
- **P5b** (`honeyhub.app` cutover) — Wave 3. Marked `human-only`. Conditional closing-edit branch based on P5a's merge state at PR-open time. Whichever P5 lands last removes the GoDaddy row entirely from `vendor-inventory.md`.

**Subdomain wiring is out of scope for this rollout.** Cloudflare-DNS-side wiring for `notify.honeydrunkstudios.com` is part of ADR-0027's stand-up rollout when that gets scoped — the apex-at-Cloudflare prerequisite is satisfied by P4 having merged. Same logic applies to `status.honeydrunkstudios.com` and any other future subdomain — Cloudflare-DNS records for future subdomains are scoped by the consuming Node's ADR rollout, not by this one.

If `support@honeydrunkstudios.com` mailboxes exist today, mail routing rides on the apex MX records that P4 carries through verbatim from the BIND export. PDR-0002's `support@` commitment is otherwise unaffected by this migration — the domain's MX records are part of the BIND-export-and-import workflow, and the post-cutover smoke explicitly verifies mail-loop pass-pass-pass before the migration is considered complete.

All work in this rollout is Architecture-repo-targeted: the deliverables are walkthrough docs, the vendor-inventory updates, and per-domain migration verification + bookkeeping. No code packets, no Notify / Pulse / Studios repo-side work in this rollout.

## Execution Model

Three waves. Filing is un-gated — all six packets file in one pass; the `dependencies:` frontmatter wires the blocking chain at filing time.

### Wave 1 — Foundation (run first, all parallel)

Self-contained doc work. P1, P2, and P3 are independent at the packet level — none blocks the others. P2's full execution benefits from a stood-up Cloudflare account for verification (Human Prerequisite); P3 is fully self-contained.

- [ ] `HoneyDrunk.Architecture`: Add transfer-in-flight notes to GoDaddy + Cloudflare vendor-inventory rows — [`01-architecture-vendor-inventory-cloudflare-registrar.md`](01-architecture-vendor-inventory-cloudflare-registrar.md)
- [ ] `HoneyDrunk.Architecture`: Author `infrastructure/cloudflare-account-provisioning.md` — [`02-architecture-cloudflare-account-provisioning-walkthrough.md`](02-architecture-cloudflare-account-provisioning-walkthrough.md)
- [ ] `HoneyDrunk.Architecture`: Author `infrastructure/cloudflare-domain-transfer.md` — [`03-architecture-cloudflare-domain-transfer-walkthrough.md`](03-architecture-cloudflare-domain-transfer-walkthrough.md)

**Wave 1 exit criteria:**
- `vendor-inventory.md` carries transfer-in-flight annotations on both GoDaddy and Cloudflare rows (no row removal yet).
- `infrastructure/cloudflare-account-provisioning.md` merged and indexed in `infrastructure/README.md`. API token convention covers both runtime (per-Node Key Vault) and workflow (GitHub Environment secret) consumer cases.
- `infrastructure/cloudflare-domain-transfer.md` merged and indexed in `infrastructure/README.md`. Includes post-cutover smoke section (T+0 to T+48h) and DNSSEC + 2FA pre-transfer prereqs.
- A Cloudflare account exists, hardware-key-backed 2FA is configured, and the account-level transfer-lock posture matches the walkthrough.

### Wave 2 — First Cutover (run after Wave 1 walkthroughs merged)

The Studios marketing domain is the first cutover. Per ADR-0029 §Implementation, this is the lowest-risk highest-visibility domain — Vercel-hosted static content with full TLS termination at Vercel through Cloudflare proxy. This wave's packet is `human-only`: the user owns the multi-day GoDaddy-side operational sequence (BIND export, unlock, auth-code retrieval, transfer approval, GoDaddy-side cleanup) and the Vercel mode confirmation; the agent owns post-cutover verification, the post-cutover smoke result recording, vendor-inventory state-flip edits, and the ADR Status flip.

- [ ] `HoneyDrunk.Architecture`: Migrate `honeydrunkstudios.com` from GoDaddy to Cloudflare — [`04-architecture-migrate-honeydrunkstudios-com.md`](04-architecture-migrate-honeydrunkstudios-com.md)

**Wave 2 exit criteria:**
- `honeydrunkstudios.com` authoritative nameservers are Cloudflare's.
- Studios marketing site (Vercel) resolves and serves correctly through Cloudflare proxy.
- Registrar-level transfer lock enabled at Cloudflare.
- Post-cutover smoke (T+0 to T+48h) passed: mail-loop, third-party verification records, DMARC `rua=` reachability.
- Vendor-inventory state-flip landed: section renamed, Cloudflare row scope expanded to include Registrar (active for `honeydrunkstudios.com`), GoDaddy row annotation updated to list remaining domains, Cloudflare row added to lock-in assessment.
- Scope agent flips ADR-0029 Status → Accepted in P4's PR.

### Wave 3 — Remaining Apex Domains (run after Wave 2 verifies)

Both packets are `human-only` and can run in parallel — independent transfers. Each carries a conditional closing-edit branch in its vendor-inventory edits: whichever P5 packet is **last** to merge removes the GoDaddy row entirely and finalizes the Cloudflare row's scope.

- [ ] `HoneyDrunk.Architecture`: Migrate `tatteddev.com` from GoDaddy to Cloudflare — [`05a-architecture-migrate-tatteddev-com.md`](05a-architecture-migrate-tatteddev-com.md)
- [ ] `HoneyDrunk.Architecture`: Migrate `honeyhub.app` from GoDaddy to Cloudflare — [`05b-architecture-migrate-honeyhub-app.md`](05b-architecture-migrate-honeyhub-app.md)

**Wave 3 exit criteria:**
- All three Grid-owned apex domains (`honeydrunkstudios.com`, `tatteddev.com`, `honeyhub.app`) are at Cloudflare Registrar with Cloudflare authoritative DNS.
- Both Wave 3 packets passed their post-cutover smoke windows (T+0 to T+48h).
- The closing-edit-branch packet (whichever P5 was last to merge) has removed the GoDaddy row from `vendor-inventory.md`, finalized the Cloudflare row's scope as "Registrar, authoritative DNS, CDN, DDoS protection, WAF," and finalized the Cloudflare lock-in assessment row.
- Dispatch plan Wave 3 has cutover-date status lines for both `tatteddev.com` and `honeyhub.app`.
- (Optional, user-driven, out of scope for this rollout) GoDaddy account closure may proceed at user's discretion. The closing-edit branch flags this opportunity in the dispatch plan and PR body.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board and the Wave 3 exit criteria are met, the entire `active/adr-0029-cloudflare-dns-rollout/` folder is moved to `completed/adr-0029-cloudflare-dns-rollout/` in a single commit. Partial archival is forbidden.

## Notes

- **ADR-0029 acceptance gate.** The ADR explicitly defers Status → Accepted until the Studios domain cutover (P4) lands. P1, P2, and P3 file and merge against a Proposed ADR; the ADR's decisions are the working contract during the rollout. Wave 2 (P4) is the trigger for the Status flip — the scope agent flips the ADR header on the merging Studios-cutover PR.
- **Catalog state machine across the rollout.** The ADR's If-Accepted contract requires the GoDaddy row out of `vendor-inventory.md` and the Cloudflare row updated. The naive shape — collapse the row out in Wave 1 — falsifies the catalog for the multi-week transfer window because GoDaddy still holds two domains until Wave 3 completes. The chosen shape: P1 annotates (transitional), P4 expands the Cloudflare row's scope and adds the lock-in assessment row, P5a / P5b each flip their domain's state, and whichever P5 is last to merge performs the closing edit (GoDaddy row removed, Cloudflare row scope finalized). This produces an honest catalog at every PR-merge boundary.
- **No automation lands in this rollout.** Per ADR-0029 D2, DNS is portal-managed at v1. P2's API token convention is documentation-only — no token is provisioned, no automation lands. The first packet that needs a Cloudflare API token (a future ADR) provisions it per the convention's two cases: per-Node Key Vault for runtime consumers; GitHub Environment secret for workflow consumers (cross-link to ADR-0012).
- **Cloudflare Free covers the Grid's full DNS footprint** per D2. No paid Cloudflare features are adopted in this rollout. P2's walkthrough flags any paid feature mention as deferred-to-future-ADR rather than buy-now.
- **`human-only` posture for migration packets.** P4, P5a, and P5b are marked `human-only` — the multi-day GoDaddy-side operational sequence (BIND export, Domain Privacy disable, unlock, auth-code retrieval, transfer approval, GoDaddy-side cleanup) is owned by the user. The agent's role is verification (dig, whois, curl, post-cutover smoke), bookkeeping (vendor-inventory edits, dispatch-plan edits, CHANGELOG entries), and the ADR Status flip in P4. P1, P2, and P3 stay `Actor=Agent` with no `human-only` label — those are doc-authoring tasks fully within the agent's reach.
- **Lean record comments per D6.** P2 documents the Cloudflare record-comment scheme as `purpose=studios-apex`, `purpose=notify-cloud-api`, etc. — no `initiative`, `created-by-agent`, or owner noise. Mirrors the lean Azure tag scheme already in use across the Grid.
- **Subdomain wiring is the consuming Node's ADR rollout's problem.** Cloudflare-DNS-side wiring for `notify.honeydrunkstudios.com` is part of ADR-0027's stand-up rollout — the apex-at-Cloudflare prerequisite is satisfied by P4 having merged. `status.honeydrunkstudios.com` is part of whichever rollout introduces the status page. Future HoneyHub subdomains under `honeyhub.app` are part of the HoneyHub Phase 1 rollout (ADR-0003). None are scoped here.
- **`support@honeydrunkstudios.com` framing.** If `support@` mailboxes exist today, mail routing rides on the apex MX records that P4 carries through verbatim from the BIND export. PDR-0002's `support@` commitment is otherwise unaffected by this migration. The post-cutover smoke explicitly verifies mail-loop pass-pass-pass before P4 is considered complete.
- **Vercel mode confirmation is a P4 prereq.** `honeydrunkstudios.com` may be configured in Vercel one of three ways (Vercel as authoritative nameserver, GoDaddy nameservers + Vercel-managed via CNAME, or Cloudflare nameservers via manual delegation pre-this-ADR). The user confirms the mode pre-cutover; the BIND export source branches accordingly. Modes 2 and 3 follow the standard walkthrough; mode 1 changes the BIND export source to Vercel and may require Vercel custom-domain re-validation post-cutover.
- **Third-party DNS dependencies enumeration.** P4, P5a, and P5b each carry a Human Prerequisite to enumerate every external service requiring DNS records on the domain (Resend, Google Workspace, Microsoft 365, Stripe, Vercel, etc.) and capture the list in the PR body before initiating the transfer. The post-cutover smoke uses this list to be exhaustive rather than discovery-based. `tatteddev.com` and `honeyhub.app` were not pre-flagged with third-party services in the scope-time inventory — the per-domain enumeration step is explicitly required for both.
