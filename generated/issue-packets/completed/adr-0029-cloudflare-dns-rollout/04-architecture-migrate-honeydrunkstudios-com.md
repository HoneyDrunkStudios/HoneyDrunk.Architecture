---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "infrastructure", "adr-0029", "human-only"]
dependencies: ["packet:02", "packet:03"]
adrs: ["ADR-0029"]
wave: 2
initiative: adr-0029-cloudflare-dns-rollout
node: honeydrunk-studios
---

# Feature: Migrate `honeydrunkstudios.com` from GoDaddy to Cloudflare

## Summary
Execute the GoDaddy → Cloudflare migration for the Studios marketing domain (`honeydrunkstudios.com`), per the generic walkthrough authored in P3. This is the lowest-risk highest-visibility cutover and the trigger for flipping ADR-0029 Status → Accepted. Marked `human-only` — the multi-day GoDaddy-side operational sequence (initial unlock, auth-code retrieval, transfer approval click, GoDaddy-side cleanup) is owned by the user. The agent's role is verification, the Cloudflare-side initiate click if Cloudflare API access exists, post-transfer dig/whois/TLS verification, vendor-inventory row-state edits, and the ADR Status flip.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`
(The work product is portal-clicks plus catalog updates; the repo target is Architecture because that is where the verification record lives. No code in `HoneyDrunk.Studios` is touched — the Vercel-hosted marketing site is unaffected by the registrar/DNS-authority change.)

## Motivation
ADR-0029 §Implementation orders `honeydrunkstudios.com` first because it is the lowest-risk highest-visibility domain — Vercel-hosted static content with full TLS termination at Vercel through Cloudflare proxy. The cutover validates the end-to-end transfer flow with the smallest blast radius, then unlocks the rest of the migration sequence (P5a: `tatteddev.com`, P5b: `honeyhub.app`).

ADR-0029 also names the Studios cutover as the **Status flip trigger**: "Scope agent flips Status → Accepted after the first domain (Studios marketing site) has cut over and the migration walkthrough lands." Once this packet's verification step passes, the scope agent flips ADR-0029's Status header in the merging PR.

This packet also carries the **first vendor-inventory row-state edit** in the rollout: it expands the Cloudflare row's scope to include "Registrar (active for `honeydrunkstudios.com`)" and adds the Cloudflare row to the Vendor Lock-In Assessment. The GoDaddy row is NOT removed yet — `tatteddev.com` and `honeyhub.app` still live there until P5a and P5b complete. The closing edit (GoDaddy row removal) lands in whichever P5 packet is last to merge.

## Proposed Implementation

### Execute the per-domain transfer

Follow [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md) end-to-end for the apex `honeydrunkstudios.com`. The walkthrough is per-domain-agnostic; this packet supplies the domain-specific specifics:

**Pre-import zone (records to verify present in Cloudflare zone before approving transfer):**

| Record | Type | Target | Proxied? | `purpose` comment |
|---|---|---|---|---|
| `@` (apex) | A or CNAME (via Cloudflare CNAME flattening) | Vercel apex IP / `cname.vercel-dns.com` | Proxied (orange) | `studios-apex` |
| `www` | CNAME | `cname.vercel-dns.com` | Proxied (orange) | `studios-www` |
| `_vercel` | TXT | (Vercel domain-validation token from Vercel dashboard) | DNS-only | `studios-vercel-validation` |
| (any existing email records — MX, SPF, DKIM, DMARC) | per export | per export | DNS-only | `email-{purpose}` |
| (any existing CAA, SRV, or other niche records from the BIND export) | per export | per export | per ADR-0029 D3 default | `{appropriate-purpose}` |

The exact proxied/DNS-only choice for the apex follows ADR-0029 D3 default for "public marketing surfaces — proxied (orange-cloud). CDN, DDoS protection, and WAF default-on are the right v1 stance for static-content surfaces." Verify the Vercel-side custom-domain configuration tolerates Cloudflare proxying (it does — this is a documented standard pattern).

**Per-domain verification (in addition to the generic checklist in P3's walkthrough):**

- `https://honeydrunkstudios.com` resolves to the Studios marketing site, certificate chain valid, content matches pre-cutover content.
- `https://www.honeydrunkstudios.com` either redirects to the apex or serves the same content (whichever the pre-cutover behavior was — this packet preserves, not changes).
- Vercel's project dashboard shows the custom-domain status as Valid / Active.
- `dig +short ns honeydrunkstudios.com` returns Cloudflare nameservers only.
- `whois honeydrunkstudios.com` shows Cloudflare as registrar.
- Cloudflare zone for `honeydrunkstudios.com` shows Registrar Lock On.
- GoDaddy auto-renew for `honeydrunkstudios.com` is Off; any GoDaddy add-ons cancelled.
- **Post-cutover smoke (per [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md) §Post-cutover smoke):** mail-loop probe pass-pass-pass, every third-party verification record from the BIND export confirmed verified in its issuing service portal, DMARC `rua=` reachability confirmed at T+24h / T+48h.

### Update `infrastructure/reference/vendor-inventory.md` (state-flip for this row, not removal)

This packet's vendor-inventory edits:

1. **`Last Updated` header** — bump to today's date.

2. **`## DNS / CDN / Domain` section** — rename to `## Domain Registrar, DNS, and Edge`. Edit both rows:

   GoDaddy row — keep, but update the in-flight annotation to reflect that `honeydrunkstudios.com` has migrated:
   ```
   | GoDaddy | Domain registrar (transfer-in-flight to Cloudflare per ADR-0029; `honeydrunkstudios.com` migrated to Cloudflare with this packet — `tatteddev.com` and `honeyhub.app` remaining) | Domain registration and management for `tatteddev.com`, `honeyhub.app` | Paid |
   ```

   Cloudflare row — flip scope to include registrar:
   ```
   | Cloudflare | Registrar (active for `honeydrunkstudios.com`), authoritative DNS, CDN, DDoS protection, WAF | Domain registration, DNS management, edge caching, security | Free tier (registrar at-cost; Pro available if a future Node justifies it) |
   ```

3. **`## Vendor Lock-In Assessment` table** — add a Cloudflare row at Medium. Place above the existing Microsoft Azure row (groups platform-wide concerns at the top):
   ```
   | **Medium** | Cloudflare | Registrar (for `honeydrunkstudios.com` at this packet; expanding to remaining domains via P5a / P5b) + authoritative DNS + edge for the Grid surface. Single point of compromise for external-surface integrity. Mitigations: hardware-key-backed 2FA on the account (mandatory at first migration), Registrar-level transfer-lock per zone, per-zone API tokens scoped narrowly. Reversibility: domain transfer-out and zone export are mechanically supported by Cloudflare; the exit door stays open. |
   ```

   GoDaddy is not added to the assessment table — it was not in the table previously, and is on track for removal once P5a / P5b drain the remaining domains.

### Flip ADR-0029 Status → Accepted

After the per-domain verification passes (all bullets above check green, including the post-cutover smoke), edit `adrs/ADR-0029-cloudflare-dns-and-edge-platform.md`:

- Change `**Status:** Proposed` → `**Status:** Accepted`.
- Append an `## Acceptance` section at the bottom:
  ```
  ## Acceptance

  Accepted on {YYYY-MM-DD} after the first domain (`honeydrunkstudios.com`) cut over to Cloudflare per the migration walkthrough authored in [`infrastructure/cloudflare-domain-transfer.md`](../infrastructure/cloudflare-domain-transfer.md). Verification recorded in the Architecture-repo PR for this packet.
  ```

This is the scope-agent-flip step the ADR's §If Accepted explicitly names. It happens in this packet's PR, not in a separate packet.

### `CHANGELOG.md`
Append entries to the existing in-progress `## [Unreleased]` section:

Under `### Changed`:
- "ADR-0029 (Cloudflare DNS & Edge Platform) accepted; `honeydrunkstudios.com` migrated to Cloudflare Registrar and authoritative DNS."
- "Vendor inventory: Cloudflare row scope flipped to include Registrar (active for `honeydrunkstudios.com`); section renamed to Domain Registrar, DNS, and Edge; Cloudflare row added to Vendor Lock-In Assessment."

## Affected Files
- `adrs/ADR-0029-cloudflare-dns-and-edge-platform.md` (Status flip + Acceptance section)
- `infrastructure/reference/vendor-inventory.md` (row scope flip, section rename, lock-in assessment row added)
- `CHANGELOG.md`

No file in the `HoneyDrunk.Studios` repo is touched. Vercel-side configuration is unchanged (the Vercel custom-domain binding works with whichever authoritative nameserver returns the validation TXT — Cloudflare returns the same record imported from the BIND export).

## Boundary Check
- [x] Architecture-repo doc + ADR Status flip. The actual transfer is portal-clicks at GoDaddy and Cloudflare — no code change in any Node.
- [x] No code in `HoneyDrunk.Studios` touched. Vercel hosting is unchanged.
- [x] No catalog graph changes. Cloudflare remains a vendor (already in vendor-inventory); not in `nodes.json` / `relationships.json`.
- [x] No invariant text changes — ADR-0029 proposes none.

## Acceptance Criteria

The agent's role on this packet is **verification + bookkeeping**, not driving the multi-day GoDaddy-side operational sequence. The user owns the unlock + auth-code retrieval + GoDaddy-side approval clicks; the agent verifies the result and writes the catalog edits.

- [ ] **(Verification)** `honeydrunkstudios.com` has been transferred to Cloudflare Registrar — `whois honeydrunkstudios.com` shows Cloudflare.
- [ ] **(Verification)** Authoritative nameservers for `honeydrunkstudios.com` are Cloudflare's — `dig +short ns honeydrunkstudios.com` returns Cloudflare hostnames only.
- [ ] **(Verification)** All DNS records from the GoDaddy BIND export (or Vercel BIND export if Vercel was authoritative pre-transfer per the Vercel mode prereq) are present in the Cloudflare zone with `purpose=...` comments per ADR-0029 D6.
- [ ] **(Verification)** Apex (`@`) and `www` records are proxied (orange-cloud) per ADR-0029 D3 default for public marketing surfaces.
- [ ] **(Verification)** Email-related records (if present in the export) are DNS-only per ADR-0029 D3.
- [ ] **(Verification)** `https://honeydrunkstudios.com` and `https://www.honeydrunkstudios.com` resolve correctly, certificate chain valid, content matches pre-cutover content. Vercel project dashboard shows the custom-domain binding as Valid / Active.
- [ ] **(Verification)** Cloudflare zone for `honeydrunkstudios.com` has Registrar Lock On.
- [ ] **(Verification)** GoDaddy-side: domain status is Transferred Out, auto-renew is Off, any GoDaddy add-ons are cancelled.
- [ ] **(Verification — post-cutover smoke)** Per [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md) §Post-cutover smoke: mail-loop probe shows DKIM + SPF + DMARC pass; every third-party verification TXT record from the BIND export verified in its issuing service portal; DMARC `rua=` reachability confirmed at T+24h and T+48h. Smoke results recorded in the PR body.
- [ ] **(Decision recorded in PR body)** CAA posture decision for `honeydrunkstudios.com`. Default at v1 per ADR-0029 is "no CAA record (any CA may issue)," but record the explicit per-domain decision in the PR body so the posture is on the record. If a CAA record is set, list which CAs are permitted and why.
- [ ] **(Bookkeeping)** ADR-0029 Status flipped from Proposed to Accepted in this packet's PR; an `## Acceptance` section appended with the date and a reference to the migration walkthrough.
- [ ] **(Bookkeeping)** `infrastructure/reference/vendor-inventory.md` updated per the spec above: section renamed, Cloudflare row scope flipped to include Registrar (active for `honeydrunkstudios.com`), GoDaddy row annotation updated to list the remaining domains (`tatteddev.com`, `honeyhub.app`), Cloudflare row added to Vendor Lock-In Assessment.
- [ ] **(Bookkeeping)** `CHANGELOG.md` `## [Unreleased]` section has both changed-entries described above.
- [ ] PR description references this packet (invariant 32).

## Human Prerequisites

The user owns the multi-day GoDaddy-side operational sequence; the agent verifies and writes catalog edits.

- [ ] **Enumerate every external service requiring DNS records on `honeydrunkstudios.com`.** Sweep the studio's third-party-service portfolio and list each service that has a TXT verification, MX, CNAME, or other DNS record on this domain (Resend, Google Workspace / Microsoft 365 mailboxes, Stripe, Vercel, any analytics / monitoring services, any future-Notify Cloud customer-domain prereqs, any incidental services). Capture the list in the packet's PR body before initiating the transfer. The post-cutover smoke (per the walkthrough) checks each service portal-side after cutover; the list lets the smoke be exhaustive rather than discovery-based.
- [ ] **Confirm Vercel domain configuration mode for `honeydrunkstudios.com`.** Sign in to Vercel → Domains → `honeydrunkstudios.com`. Record (a) the configured nameservers Vercel shows for the domain, and (b) the DNS instruction set Vercel currently displays (CNAME-mode, A-record-mode, or "use Vercel nameservers" mode). **Mode determines the BIND export source:**
  - **Mode 1 — Vercel is the authoritative nameserver.** BIND export source is **Vercel**, not GoDaddy. The migration plan changes shape: pre-transfer DNS snapshot comes from Vercel's DNS surface; the registrar transfer is GoDaddy → Cloudflare independent of where DNS is currently authoritative; post-transfer Vercel custom-domain re-validation may be needed because Vercel will see the apex now resolving through Cloudflare.
  - **Mode 2 — GoDaddy nameservers, Vercel-managed via CNAME / A pointing into Vercel's edge.** BIND export source is GoDaddy. Standard walkthrough applies.
  - **Mode 3 — Cloudflare nameservers (manual delegation pre-this-ADR).** BIND export source is Cloudflare itself. Registrar transfer brings GoDaddy → Cloudflare without DNS-authority change. This is the simplest case.
  - Document the confirmed mode in the PR body before any transfer steps. The walkthrough branches accordingly.
- [ ] **GoDaddy 2FA second factor verified working.** Sign in to `account.godaddy.com` and complete the 2FA challenge. If recovery codes were saved at enrollment, locate and confirm accessibility (1Password / equivalent). If lost, regenerate before any transfer step.
- [ ] **DNSSEC OFF at GoDaddy for `honeydrunkstudios.com`.** Verify in GoDaddy DNS settings → DNSSEC. If ON, disable and wait 24-48 hours for propagation before initiating the transfer.
- [ ] **GoDaddy account access for the unlock + auth-code retrieval.** The agent does not have GoDaddy credentials. The user signs in to `account.godaddy.com`, executes the BIND export (or Vercel-side export per mode 1), disables Domain Privacy, unlocks the domain, and retrieves the transfer authorization code. Cross-link: [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md) — GoDaddy-side preparation section.
- [ ] **Auth code handoff to the agent (only if the agent is performing the Cloudflare-side initiate click).** The user provides the transfer authorization code through a secure channel (1Password share, ephemeral message). The agent uses it once to initiate the Cloudflare-side transfer and does not store or log it. If the user is performing the Cloudflare-side click directly, this step is moot.
- [ ] **Cloudflare account is signed-in and has the Registrar feature enabled.** P2 stands the account up; this packet assumes the account exists per P2's verification step. If P2 has not landed, the user provisions the Cloudflare account first.
- [ ] **Cloudflare Registrar payment method on file.** Cloudflare Registrar bills per-year at-cost for transfers. The studio's payment method must be on file in the Cloudflare account billing settings before transfer initiation. The wholesale fee for `.com` is small (single-digit USD/year as of writing, per ICANN's wholesale fee for Verisign-managed `.com`) but not zero — confirm a card is on file.
- [ ] **Multi-day wait window planned.** Per ADR-0029 §Implementation, transfers typically take 5-7 days to complete, plus 24-48 hours of post-cutover smoke window. Schedule the GoDaddy unlock + auth-code retrieval at the start of a low-change window so the post-transfer verification + smoke can run while the studio is paying attention to the marketing site.

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. The transfer authorization code is a secret-grade credential — it must not appear in the packet body, the PR body, the verification log, or any chat surface. The agent (if it handles the code at all) receives it through an out-of-band channel and uses it once at portal time.

> **Invariant 12:** Every shipped behavior change is reflected in `CHANGELOG.md` (and `README.md` when public surface changes). The vendor-inventory edit and the ADR Status flip are both shipped doc-state changes; CHANGELOG entries mandatory.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.

## Referenced ADR Decisions

**ADR-0029 §If Accepted (final bullet):** "Scope agent flips Status → Accepted after the first domain (Studios marketing site) has cut over and the migration walkthrough lands." This packet is the trigger.

**ADR-0029 §Implementation step 1:** "`honeydrunkstudios.com` (Studios marketing site, Vercel-hosted). Lowest risk — static content, established pattern, full TLS termination at Vercel through Cloudflare proxy. Cutover validates the end-to-end transfer flow with the smallest blast radius."

**ADR-0029 D3 (default proxy posture):** "Public marketing surfaces (Studios website, future status page) — proxied (orange-cloud). CDN, DDoS protection, and WAF default-on are the right v1 stance for static-content surfaces." Apex and `www` are proxied.

**ADR-0029 §Negative Consequences (single point of compromise mitigation):** "hardware-key-backed 2FA on the Cloudflare account is mandatory at the migration packet; Registrar-level transfer lock is enabled." 2FA was enrolled in P2; Registrar Lock is enabled in this packet's verification step.

## Dependencies

This packet depends on the foundation walkthroughs from Wave 1:

- `packet:02` — `infrastructure/cloudflare-account-provisioning.md` (Cloudflare account exists with hardware-key 2FA, the API token convention is documented for future use, the lean record-comment scheme is documented for use by this packet's record-import step).
- `packet:03` — `infrastructure/cloudflare-domain-transfer.md` (the generic per-domain procedure this packet executes, including the post-cutover smoke contract).

P1 is independent (vendor-inventory transitional annotation lands first); not a hard blocker — this packet's vendor-inventory edits compose on top of P1's annotation.

## Labels
`feature`, `tier-2`, `infrastructure`, `adr-0029`, `human-only`

## Agent Handoff

**Objective:** Verify the GoDaddy → Cloudflare migration for `honeydrunkstudios.com` after the user-driven operational sequence completes; record the verification, perform the vendor-inventory state-flip edits, and flip ADR-0029 Status to Accepted in the same PR.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: First-domain cutover for the ADR-0029 rollout. Validates the end-to-end transfer flow on the lowest-risk highest-visibility domain. Triggers ADR-0029 Status flip.
- Feature: ADR-0029 Cloudflare DNS & Edge Platform Rollout, Wave 2.
- ADR: ADR-0029 (Proposed → Accepted in this packet's PR).
- Actor: `human-only` for the multi-day operational sequence; agent owns verification + bookkeeping.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Packets 02 and 03 (foundation walkthroughs) merged on `main`.
- GoDaddy-side unlock + auth-code retrieval + transfer approval performed by the user (Human Prerequisites).
- Cloudflare account exists with payment method on file.
- Vercel mode confirmed (mode 1, 2, or 3) per Human Prerequisites.

**Constraints:**
- **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. The transfer authorization code is a single-use credential; it does not appear in the packet body, PR body, commit messages, verification log, or chat. If the agent ever handles it (Cloudflare-side initiate click only), the agent receives it out-of-band, uses it once, and discards it.
- **Invariant 12:** Every shipped behavior change is reflected in `CHANGELOG.md`. Both the cutover and the ADR acceptance ship doc-state changes; both get CHANGELOG entries.
- **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.
- **Portal-first.** The transfer is portal-clicks at GoDaddy and Cloudflare. Diagnostic CLI (`dig`, `whois`, `curl`) for verification is acceptable.
- **No Vercel-side change beyond what the confirmed mode requires.** The Vercel custom-domain binding survives the cutover unchanged in modes 2 and 3. In mode 1 (Vercel was authoritative), Vercel custom-domain re-validation may be needed post-cutover — that is anticipated and not a deviation. Any other Vercel-side configuration drift post-cutover: stop and consult the user before changing Vercel-side anything.
- **ADR Status flip happens in this packet's PR, not a follow-up.** Per the scope-agent convention (memory: "scope agent flips to Accepted after PR merge, never on first draft") — except this is the merging PR for the cutover the ADR explicitly waits on. Flip Status in the same PR, append the Acceptance section, and let the merge be the acceptance event.
- **Lean record-comment scheme.** Per ADR-0029 D6 and P2's documentation. Record comments are `purpose=...` only. No `initiative`, `created-by`, ADR identifiers, dates, or owner names in comments.
- **GoDaddy row stays.** This packet does NOT remove the GoDaddy row from `vendor-inventory.md` — only updates its annotation. The closing edit (row removal) is in whichever P5 packet is last to merge. Removing the row here while `tatteddev.com` and `honeyhub.app` still live at GoDaddy produces a stale catalog.

**Key Files:**
- `adrs/ADR-0029-cloudflare-dns-and-edge-platform.md` (Status flip + Acceptance section)
- `infrastructure/reference/vendor-inventory.md` (state-flip edits, lock-in assessment add, section rename)
- `CHANGELOG.md`

**Reference Walkthroughs:**
- [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md) (P3 — the procedure this packet's user-driven sequence executes; same path used in Acceptance Criteria for the post-cutover smoke reference)
- `infrastructure/cloudflare-account-provisioning.md` (P2 — Cloudflare-side prerequisites)

**Contracts:** None changed. Registrar + DNS authority change is invisible to consuming code.
