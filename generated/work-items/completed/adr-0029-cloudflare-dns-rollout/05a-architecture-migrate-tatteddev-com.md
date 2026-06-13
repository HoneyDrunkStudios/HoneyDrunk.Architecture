---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "infrastructure", "adr-0029", "human-only"]
dependencies: ["work-item:04"]
adrs: ["ADR-0029"]
wave: 3
initiative: adr-0029-cloudflare-dns-rollout
node: honeydrunk-architecture
---

# Feature: Migrate `tatteddev.com` from GoDaddy to Cloudflare

## Summary
Migrate the apex domain `tatteddev.com` from GoDaddy to Cloudflare per the ADR-0029 rollout. Wave 3 — runs after the Studios cutover (P4) validates the transfer flow on the lowest-risk domain. Marked `human-only` for the multi-day GoDaddy-side operational sequence; agent owns verification + bookkeeping. Independent of P5b (`honeyhub.app`); the two can run in parallel.

This packet flips `tatteddev.com`'s row state in `infrastructure/reference/vendor-inventory.md`. If this is the **last** of the two P5 packets to merge, this packet also performs the **closing edit**: removes the GoDaddy row entirely, finalizes the Cloudflare row's scope as "Registrar, authoritative DNS, CDN, DDoS protection, WAF" with the at-cost-Free pricing posture, and updates the Cloudflare lock-in assessment row to reflect the consolidation. The closing-edit branch is conditional on P5b's merge state at PR-open time.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`
(Same logic as P4 — work product is portal-clicks plus catalog updates; verification record lives in Architecture.)

## Motivation
ADR-0029 §Implementation step 2: "Any other apex domain currently held at GoDaddy — one packet per domain, in increasing order of 'what depends on it.'" `tatteddev.com` is one of two remaining GoDaddy-held apex domains as of this rollout. P4 validates the transfer flow; this packet repeats the procedure for `tatteddev.com` with the same operational shape and the same `human-only` posture.

The Studios cutover (P4) validated:
- The Cloudflare-side transfer initiation flow against a real domain.
- The portal-driven post-transfer verification and Registrar Lock On.
- The post-cutover smoke contract from [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md).
- The vendor-inventory row-state edit pattern.

This packet inherits all of that. The only domain-specific work is the BIND export, the third-party-services enumeration for `tatteddev.com` specifically, the per-record proxied/DNS-only decision, and the verification + smoke for this domain.

## Proposed Implementation

### Execute the per-domain transfer

Follow [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md) end-to-end for the apex `tatteddev.com`. Domain-specific specifics for this work-item:

**BIND-export checklist (verify present in Cloudflare zone before approving transfer):**

The `tatteddev.com` portfolio is not pre-flagged with third-party services in the scope-time inventory. The Human Prerequisites step requires the user to enumerate third-party services on this domain before initiating the transfer; the BIND export is the source of truth for what records actually exist. Iterate the BIND export and verify each record imports cleanly into the Cloudflare zone:

| Record category | Expected handling | Per-record decision |
|---|---|---|
| Apex (`@`) | Per current behavior — if `tatteddev.com` serves a hosted page (parking, redirect, marketing, custom-served), preserve the target. | Proxied (orange) per ADR-0029 D3 default for marketing surfaces; DNS-only if the apex is purely email-serving with no HTTP surface. |
| `www` | Per current behavior. | Same as apex. |
| Email records (MX, SPF, DKIM, DMARC) | Preserve verbatim. | DNS-only per ADR-0029 D3. |
| Third-party verification TXT records | Preserve verbatim. Verify in each issuing service portal post-cutover (post-cutover smoke). | DNS-only. |
| CAA, SRV, niche records | Preserve verbatim if present. | Per record's intent. |

**Per-domain verification (in addition to the generic checklist in P3's walkthrough):**

- `whois tatteddev.com` shows Cloudflare as registrar.
- `dig +short ns tatteddev.com` returns Cloudflare nameservers only.
- Cloudflare zone for `tatteddev.com` shows Registrar Lock On.
- GoDaddy auto-renew for `tatteddev.com` is Off; any GoDaddy add-ons cancelled.
- If `tatteddev.com` serves a hosted surface (HTTP / HTTPS), the surface resolves correctly post-cutover. If parked, no certificate-chain check is required; Cloudflare's default parked-domain page is acceptable unless the domain previously served custom content.
- **Post-cutover smoke (per [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md) §Post-cutover smoke):** mail-loop probe (only if MX records exist on `tatteddev.com`), every third-party verification record from the BIND export verified in its issuing service portal, DMARC `rua=` reachability if DMARC was configured pre-transfer.

### Update `infrastructure/reference/vendor-inventory.md` (per-domain state flip + conditional closing edit)

This packet's vendor-inventory edits depend on whether P5b (`honeyhub.app`) has merged at the time this PR is opened.

**Branch A — P5b has not merged yet (this is the first P5 to land):**

1. **`Last Updated` header** — bump to today's date.
2. **GoDaddy row** — update the in-flight annotation to remove `tatteddev.com` from the remaining list:
   ```
   | GoDaddy | Domain registrar (transfer-in-flight to Cloudflare per ADR-0029; `honeydrunkstudios.com` and `tatteddev.com` migrated — `honeyhub.app` remaining) | Domain registration and management for `honeyhub.app` | Paid |
   ```
3. **Cloudflare row** — extend the active-registrar list:
   ```
   | Cloudflare | Registrar (active for `honeydrunkstudios.com`, `tatteddev.com`), authoritative DNS, CDN, DDoS protection, WAF | Domain registration, DNS management, edge caching, security | Free tier (registrar at-cost; Pro available if a future Node justifies it) |
   ```
4. **Cloudflare lock-in assessment row** — update the registrar-coverage parenthetical:
   ```
   | **Medium** | Cloudflare | Registrar (for `honeydrunkstudios.com` + `tatteddev.com` at this packet; `honeyhub.app` pending P5b) + authoritative DNS + edge for the Grid surface. (mitigations and reversibility text unchanged) |
   ```

**Branch B — P5b has already merged (this is the LAST of the two P5 packets):**

This is the **closing edit**. GoDaddy is no longer holding any Grid-owned domains.

1. **`Last Updated` header** — bump to today's date.
2. **GoDaddy row** — **remove entirely** from the `## Domain Registrar, DNS, and Edge` section.
3. **Cloudflare row** — finalize scope (drop the parenthetical "active for ..." since coverage is total):
   ```
   | Cloudflare | Registrar, authoritative DNS, CDN, DDoS protection, WAF | Domain registration, DNS management, edge caching, security | Free tier (registrar at-cost; Pro available if a future Node justifies it) |
   ```
4. **Cloudflare lock-in assessment row** — finalize:
   ```
   | **Medium** | Cloudflare | Registrar + authoritative DNS + edge for the entire Grid surface. Single point of compromise for external-surface integrity. Mitigations: hardware-key-backed 2FA on the account, Registrar-level transfer-lock per zone, per-zone API tokens scoped narrowly. Reversibility: domain transfer-out and zone export are mechanically supported by Cloudflare; the exit door stays open. |
   ```

The agent picks the branch at PR-open time by inspecting whether the P5b PR has merged on `main`.

### Update the dispatch plan (Wave 3 status line)

Add a status line to `dispatch-plan.md` Wave 3 section recording the cutover date for `tatteddev.com`. Per ADR-0008 D7, the dispatch plan is the one exception to packet immutability — this is the supported edit.

If this is the closing-edit branch (P5b already merged), also flag in the dispatch plan that the GoDaddy account no longer holds any Grid-owned domains and the user may close the GoDaddy account at their discretion (account closure is human-only — out of scope for this packet).

### `CHANGELOG.md`
Append entries to the existing in-progress `## [Unreleased]` section under `### Changed`:

- "`tatteddev.com` migrated to Cloudflare Registrar and authoritative DNS per ADR-0029."

If closing-edit branch, also append:
- "Vendor inventory: GoDaddy row removed; Cloudflare row scope finalized (Registrar, authoritative DNS, CDN, DDoS, WAF); lock-in assessment finalized for full-Grid registrar coverage. ADR-0029 rollout complete."

## Affected Files
- `infrastructure/reference/vendor-inventory.md` (per-domain state flip; closing edit if last to merge)
- `generated/work-items/active/adr-0029-cloudflare-dns-rollout/dispatch-plan.md` (Wave 3 status line)
- `CHANGELOG.md`
- No code in any Node touched. No catalog graph changes.

## Boundary Check
- [x] Architecture-repo doc + dispatch-plan edit. The actual transfer is portal-clicks at GoDaddy and Cloudflare.
- [x] No code in any Node touched. No catalog graph changes.
- [x] No invariant text changes — ADR-0029 proposes none.

## Acceptance Criteria

The agent's role is **verification + bookkeeping** (same as P4). User owns the multi-day GoDaddy-side operational sequence.

- [ ] **(Verification)** `whois tatteddev.com` shows Cloudflare as registrar.
- [ ] **(Verification)** `dig +short ns tatteddev.com` returns Cloudflare nameservers only.
- [ ] **(Verification)** All DNS records from the GoDaddy BIND export are present in the Cloudflare zone with `purpose=...` comments per ADR-0029 D6.
- [ ] **(Verification)** Per-record proxied/DNS-only stance matches ADR-0029 D3 defaults (or a per-record exception is documented in the PR body with a one-line justification).
- [ ] **(Verification)** If `tatteddev.com` serves a hosted surface, the surface resolves correctly post-cutover. If parked, the parked behavior is acceptable unless the domain previously served custom content (in which case match pre-cutover behavior).
- [ ] **(Verification)** Cloudflare zone for `tatteddev.com` has Registrar Lock On.
- [ ] **(Verification)** GoDaddy-side: domain status is Transferred Out, auto-renew is Off, any GoDaddy add-ons are cancelled.
- [ ] **(Verification — post-cutover smoke)** Per [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md) §Post-cutover smoke: mail-loop probe (if MX records exist) shows DKIM + SPF + DMARC pass; every third-party verification TXT record from the BIND export verified in its issuing service portal; DMARC `rua=` reachability confirmed at T+24h and T+48h if DMARC was configured pre-transfer. Smoke results recorded in the PR body.
- [ ] **(Decision recorded in PR body)** CAA posture decision for `tatteddev.com`. Default at v1 per ADR-0029 is "no CAA record (any CA may issue)," but record the explicit per-domain decision in the PR body. If a CAA record is set, list which CAs are permitted and why.
- [ ] **(Bookkeeping — branch decision)** Inspect P5b's merge state on `main` at PR-open time. Pick Branch A (P5b not merged yet) or Branch B (P5b merged — closing edit) for the `infrastructure/reference/vendor-inventory.md` edits per the spec above. Document the chosen branch in the PR body.
- [ ] **(Bookkeeping)** `infrastructure/reference/vendor-inventory.md` updated per the chosen branch. If Branch A: GoDaddy row annotation updated, Cloudflare row's active-registrar list extended, lock-in assessment row's registrar coverage updated. If Branch B (closing): GoDaddy row removed, Cloudflare row finalized, lock-in assessment finalized.
- [ ] **(Bookkeeping)** Dispatch plan Wave 3 has a status line dated for the `tatteddev.com` cutover; if Branch B, also flags GoDaddy account closure as available at user discretion.
- [ ] **(Bookkeeping)** `CHANGELOG.md` `## [Unreleased]` section has the changed-entry for `tatteddev.com`; if Branch B, also has the rollout-complete entry.
- [ ] PR description references this packet (invariant 32).

## Human Prerequisites

- [ ] **Enumerate every external service requiring DNS records on `tatteddev.com`.** This domain was not pre-flagged with third-party services in the scope-time inventory. Sweep the studio's third-party-service portfolio: list each service that has a TXT verification, MX, CNAME, or other DNS record on `tatteddev.com` (Resend, Google Workspace / Microsoft 365 mailboxes, Stripe, Vercel, any analytics / monitoring services, any incidental services). The BIND export is the ground-truth source — the enumeration cross-references the export against the studio's known third-party-service portfolio. Capture the list in the packet's PR body before initiating the transfer. The post-cutover smoke checks each service portal-side after cutover; the list lets the smoke be exhaustive rather than discovery-based.
- [ ] **GoDaddy 2FA second factor verified working.** Sign in to `account.godaddy.com` and complete the 2FA challenge. If recovery codes were saved at enrollment, locate and confirm accessibility (1Password / equivalent). If lost, regenerate before any transfer step.
- [ ] **DNSSEC OFF at GoDaddy for `tatteddev.com`.** Verify in GoDaddy DNS settings → DNSSEC. If ON, disable and wait 24-48 hours for propagation before initiating the transfer.
- [ ] **GoDaddy account access for the unlock + auth-code retrieval.** The agent does not have GoDaddy credentials. The user signs in to `account.godaddy.com`, executes the BIND export, disables Domain Privacy, unlocks the domain, and retrieves the transfer authorization code. Cross-link: [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md) — GoDaddy-side preparation section.
- [ ] **Auth code handoff to the agent (only if the agent is performing the Cloudflare-side initiate click).** The user provides the transfer authorization code through a secure channel (1Password share, ephemeral message). The agent uses it once and does not store or log it.
- [ ] **Cloudflare Registrar payment method on file.** Same as P4 — confirmed once at the studio level; no per-domain re-confirmation needed. The transfer bills the at-cost wholesale registry fee.
- [ ] **Multi-day wait window planned.** Each transfer takes 5-7 days, plus 24-48 hours of post-cutover smoke window. Schedule at the start of a low-change window. P5a and P5b can run in parallel — the transfers are independent.
- [ ] **Pre-cutover behavior snapshot.** If `tatteddev.com` serves a hosted surface (parking page, redirect, marketing, custom), snapshot the rendered behavior pre-cutover so the post-cutover comparison is concrete.

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. The transfer authorization code for `tatteddev.com` is single-use, handled out-of-band, and never appears in the packet body, PR body, commit messages, or chat.

> **Invariant 12:** Every shipped behavior change is reflected in `CHANGELOG.md` (and `README.md` when public surface changes). The vendor-inventory edit and the cutover both ship doc-state changes; CHANGELOG entries mandatory.

> **Invariant 24:** Work items are immutable once filed as a GitHub Issue. Filing is the point of no return. The conditional-branch logic in this packet (Branch A vs. Branch B based on P5b's merge state at PR-open time) is intentional and pre-filing-baked into the packet text — not a post-filing amendment. The branch choice is execution-time data, not packet-text data.

> **Invariant 25:** Dispatch plans are initiative narratives, not live state. The org Project board is the source of truth for in-flight work. Dispatch plans are updated at wave boundaries as historical records. The Wave 3 status-line edit in this packet is the supported per-ADR-0008-D7 dispatch-plan edit.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.

## Referenced ADR Decisions

**ADR-0029 §Implementation step 2:** "Any other apex domain currently held at GoDaddy — one packet per domain, in increasing order of 'what depends on it.'" This packet is one of two such packets (the other is P5b for `honeyhub.app`).

**ADR-0029 D1:** "All Grid-owned domains move to Cloudflare Registrar... Existing domains at GoDaddy transfer one at a time, in the order in §Implementation." `tatteddev.com` is one of the remaining-at-GoDaddy domains.

**ADR-0029 D3 (default proxy posture):** Per-record proxied vs. DNS-only choices follow these defaults; per-record exceptions documented in the PR body.

**ADR-0029 D6 (lean record comments):** `purpose=...` only.

**ADR-0029 §Negative Consequences:** Registrar Lock On enforced per domain.

## Dependencies

- `work-item:04` — `honeydrunkstudios.com` cutover. P4 validates the transfer flow on the lowest-risk domain. P5a should not execute until P4 is verified-clean. This is the Wave 2 → Wave 3 boundary.

P5a and P5b are siblings within Wave 3 — neither is wired as the other's dependency. The conditional closing-edit branch in `infrastructure/reference/vendor-inventory.md` handles the merge-order coordination at execution time.

## Labels
`feature`, `tier-2`, `infrastructure`, `adr-0029`, `human-only`

## Agent Handoff

**Objective:** Verify the GoDaddy → Cloudflare migration for `tatteddev.com` after the user-driven operational sequence completes; record the verification, perform the per-domain (Branch A) or closing (Branch B) vendor-inventory edits, and update the dispatch plan + CHANGELOG.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Migrate one of two remaining GoDaddy-held apex domains to Cloudflare. Drains GoDaddy of one more Grid-owned domain.
- Feature: ADR-0029 Cloudflare DNS & Edge Platform Rollout, Wave 3.
- ADR: ADR-0029 (Accepted by P4's PR merge before this packet executes).
- Actor: `human-only` for the multi-day operational sequence; agent owns verification + bookkeeping.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- P4 merged on `main` and the Studios cutover verified-clean.
- GoDaddy-side unlock + auth-code retrieval + transfer approval performed by the user (Human Prerequisites).
- Third-party-services enumeration completed by the user (Human Prerequisites — first bullet).

**Constraints:**
- **Invariant 8:** Single-use auth code handled out-of-band; never appears in any logged surface.
- **Invariant 12:** Both the cutover and the vendor-inventory edits ship doc-state changes; CHANGELOG entries mandatory.
- **Invariant 24:** The Branch A / Branch B choice is execution-time inspection of P5b's merge state on `main`. The packet text describes both branches; the PR body documents which was chosen.
- **Invariant 25:** Dispatch plan edit is the ADR-0008 D7 exception, recording the cutover date.
- **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.
- **Default proxy posture per ADR-0029 D3.** Per-record exceptions documented in the PR body with a one-line justification each.
- **Lean record comments per ADR-0029 D6.** `purpose=...` only.

**Key Files:**
- `infrastructure/reference/vendor-inventory.md`
- `generated/work-items/active/adr-0029-cloudflare-dns-rollout/dispatch-plan.md`
- `CHANGELOG.md`

**Reference Walkthrough:**
- [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md) (P3)

**Contracts:** None changed.
