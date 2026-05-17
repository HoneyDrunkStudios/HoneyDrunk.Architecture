---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "infrastructure", "adr-0029", "human-only"]
dependencies: ["packet:04"]
adrs: ["ADR-0029"]
wave: 3
initiative: adr-0029-cloudflare-dns-rollout
node: honeydrunk-architecture
---

# Feature: Migrate `honeyhub.app` from GoDaddy to Cloudflare

## Summary
Migrate the apex domain `honeyhub.app` from GoDaddy to Cloudflare per the ADR-0029 rollout. Wave 3 — runs after the Studios cutover (P4) validates the transfer flow on the lowest-risk domain. Marked `human-only` for the multi-day GoDaddy-side operational sequence; agent owns verification + bookkeeping. Independent of P5a (`tatteddev.com`); the two can run in parallel.

This packet flips `honeyhub.app`'s row state in `infrastructure/reference/vendor-inventory.md`. If this is the **last** of the two P5 packets to merge, this packet also performs the **closing edit**: removes the GoDaddy row entirely, finalizes the Cloudflare row's scope, and updates the Cloudflare lock-in assessment row to reflect the consolidation. The closing-edit branch is conditional on P5a's merge state at PR-open time.

`honeyhub.app` is the future home of the HoneyHub UI per ADR-0003 (Phase 1, Proposed). This packet does not provision or wire HoneyHub — only the registrar + DNS authority transfer. HoneyHub-side wiring (subdomain records, Container App custom-domain binding, etc.) is part of the HoneyHub stand-up rollout, not this packet.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`
(Same logic as P4 / P5a — work product is portal-clicks plus catalog updates; verification record lives in Architecture.)

## Motivation
ADR-0029 §Implementation step 2: "Any other apex domain currently held at GoDaddy — one packet per domain, in increasing order of 'what depends on it.'" `honeyhub.app` is one of two remaining GoDaddy-held apex domains as of this rollout. The Studios cutover (P4) validated the transfer flow; this packet repeats the procedure for `honeyhub.app`.

`honeyhub.app` is a `.app` TLD, which has a few notable characteristics relative to `.com` for the transfer:
- `.app` enforces HSTS at the registry level (via the `.app` zone's HSTS preload entry), so **any HTTP response on this domain must come over HTTPS** — there is no http:// fallback path. Post-cutover verification must use HTTPS only.
- `.app` registry pricing is higher than `.com` at-cost. The Cloudflare Registrar transfer surfaces the at-cost fee at initiation; record the per-year cost in the PR body for cost-tracking purposes.
- Otherwise the transfer mechanics are identical to `.com`.

`honeyhub.app` may currently serve a parking page, a redirect, or no surface at all — Step 0 of the verification sequence captures the pre-cutover behavior so the post-cutover comparison is concrete.

## Proposed Implementation

### Execute the per-domain transfer

Follow [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md) end-to-end for the apex `honeyhub.app`. Domain-specific specifics for this packet:

**BIND-export checklist (verify present in Cloudflare zone before approving transfer):**

The `honeyhub.app` portfolio is not pre-flagged with third-party services in the scope-time inventory. The Human Prerequisites step requires the user to enumerate third-party services on this domain before initiating the transfer; the BIND export is the source of truth for what records actually exist. Iterate the BIND export and verify each record imports cleanly into the Cloudflare zone:

| Record category | Expected handling | Per-record decision |
|---|---|---|
| Apex (`@`) | Per current behavior (likely a parking page or redirect at this date — the future HoneyHub UI surface is wired in HoneyHub's own rollout, not this packet). | Proxied (orange) per ADR-0029 D3 default for marketing surfaces; DNS-only if the apex is purely email-serving with no HTTP surface. |
| `www` | Per current behavior. | Same as apex. |
| Email records (MX, SPF, DKIM, DMARC) | Preserve verbatim if present. | DNS-only per ADR-0029 D3. |
| Third-party verification TXT records | Preserve verbatim if present. Verify in each issuing service portal post-cutover (post-cutover smoke). | DNS-only. |
| CAA, SRV, niche records | Preserve verbatim if present. | Per record's intent. |

**Per-domain verification (in addition to the generic checklist in P3's walkthrough):**

- `whois honeyhub.app` shows Cloudflare as registrar.
- `dig +short ns honeyhub.app` returns Cloudflare nameservers only.
- Cloudflare zone for `honeyhub.app` shows Registrar Lock On.
- GoDaddy auto-renew for `honeyhub.app` is Off; any GoDaddy add-ons cancelled.
- If `honeyhub.app` serves a hosted surface (HTTPS — `.app` HSTS-preload means there is no HTTP variant), the surface resolves correctly post-cutover. If parked, no certificate-chain check is required beyond Cloudflare's default parked-domain page rendering over HTTPS.
- **`.app` HSTS verification:** `curl -vI https://honeyhub.app` returns 200 with a valid certificate chain. `curl -vI http://honeyhub.app` is expected to be redirected by the browser-level HSTS-preload behavior at clients — the registry-level HSTS does not change DNS-layer behavior, but documenting expectations matters because some toolchains assume http:// is reachable.
- **Post-cutover smoke (per [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md) §Post-cutover smoke):** mail-loop probe (only if MX records exist on `honeyhub.app`), every third-party verification record from the BIND export verified in its issuing service portal, DMARC `rua=` reachability if DMARC was configured pre-transfer.

### Update `infrastructure/reference/vendor-inventory.md` (per-domain state flip + conditional closing edit)

This packet's vendor-inventory edits depend on whether P5a (`tatteddev.com`) has merged at the time this PR is opened.

**Branch A — P5a has not merged yet (this is the first P5 to land):**

1. **`Last Updated` header** — bump to today's date.
2. **GoDaddy row** — update the in-flight annotation to remove `honeyhub.app` from the remaining list:
   ```
   | GoDaddy | Domain registrar (transfer-in-flight to Cloudflare per ADR-0029; `honeydrunkstudios.com` and `honeyhub.app` migrated — `tatteddev.com` remaining) | Domain registration and management for `tatteddev.com` | Paid |
   ```
3. **Cloudflare row** — extend the active-registrar list:
   ```
   | Cloudflare | Registrar (active for `honeydrunkstudios.com`, `honeyhub.app`), authoritative DNS, CDN, DDoS protection, WAF | Domain registration, DNS management, edge caching, security | Free tier (registrar at-cost; Pro available if a future Node justifies it) |
   ```
4. **Cloudflare lock-in assessment row** — update the registrar-coverage parenthetical:
   ```
   | **Medium** | Cloudflare | Registrar (for `honeydrunkstudios.com` + `honeyhub.app` at this packet; `tatteddev.com` pending P5a) + authoritative DNS + edge for the Grid surface. (mitigations and reversibility text unchanged) |
   ```

**Branch B — P5a has already merged (this is the LAST of the two P5 packets):**

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

The agent picks the branch at PR-open time by inspecting whether the P5a PR has merged on `main`.

### Update the dispatch plan (Wave 3 status line)

Add a status line to `dispatch-plan.md` Wave 3 section recording the cutover date for `honeyhub.app`. Per ADR-0008 D7, the dispatch plan is the one exception to packet immutability — this is the supported edit.

If this is the closing-edit branch (P5a already merged), also flag in the dispatch plan that the GoDaddy account no longer holds any Grid-owned domains and the user may close the GoDaddy account at their discretion (account closure is human-only — out of scope for this packet).

### `CHANGELOG.md`
Append entries to the existing in-progress `## [Unreleased]` section under `### Changed`:

- "`honeyhub.app` migrated to Cloudflare Registrar and authoritative DNS per ADR-0029."

If closing-edit branch, also append:
- "Vendor inventory: GoDaddy row removed; Cloudflare row scope finalized (Registrar, authoritative DNS, CDN, DDoS, WAF); lock-in assessment finalized for full-Grid registrar coverage. ADR-0029 rollout complete."

## Affected Files
- `infrastructure/reference/vendor-inventory.md` (per-domain state flip; closing edit if last to merge)
- `generated/issue-packets/active/adr-0029-cloudflare-dns-rollout/dispatch-plan.md` (Wave 3 status line)
- `CHANGELOG.md`
- No code in any Node touched. No catalog graph changes.

## Boundary Check
- [x] Architecture-repo doc + dispatch-plan edit. The actual transfer is portal-clicks at GoDaddy and Cloudflare.
- [x] No code in any Node touched. No catalog graph changes.
- [x] No invariant text changes — ADR-0029 proposes none.
- [x] HoneyHub-side wiring (subdomain records under `honeyhub.app`, Container App custom-domain binding, etc.) is out of scope. That work belongs to the HoneyHub stand-up rollout (ADR-0003 follow-ups) and consumes this packet's "apex at Cloudflare" prerequisite.

## Acceptance Criteria

The agent's role is **verification + bookkeeping** (same as P4 and P5a). User owns the multi-day GoDaddy-side operational sequence.

- [ ] **(Verification)** `whois honeyhub.app` shows Cloudflare as registrar.
- [ ] **(Verification)** `dig +short ns honeyhub.app` returns Cloudflare nameservers only.
- [ ] **(Verification)** All DNS records from the GoDaddy BIND export are present in the Cloudflare zone with `purpose=...` comments per ADR-0029 D6.
- [ ] **(Verification)** Per-record proxied/DNS-only stance matches ADR-0029 D3 defaults (or a per-record exception is documented in the PR body with a one-line justification).
- [ ] **(Verification)** If `honeyhub.app` serves a hosted surface, the surface resolves correctly post-cutover over HTTPS (the `.app` TLD is HSTS-preloaded; HTTPS is the only client path). If parked, the parked behavior is acceptable unless the domain previously served custom content.
- [ ] **(Verification)** Cloudflare zone for `honeyhub.app` has Registrar Lock On.
- [ ] **(Verification)** GoDaddy-side: domain status is Transferred Out, auto-renew is Off, any GoDaddy add-ons are cancelled.
- [ ] **(Verification — post-cutover smoke)** Per [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md) §Post-cutover smoke: mail-loop probe (if MX records exist) shows DKIM + SPF + DMARC pass; every third-party verification TXT record from the BIND export verified in its issuing service portal; DMARC `rua=` reachability confirmed at T+24h and T+48h if DMARC was configured pre-transfer. Smoke results recorded in the PR body.
- [ ] **(Decision recorded in PR body)** CAA posture decision for `honeyhub.app`. Default at v1 per ADR-0029 is "no CAA record (any CA may issue)," but record the explicit per-domain decision in the PR body. If a CAA record is set, list which CAs are permitted and why.
- [ ] **(Bookkeeping — branch decision)** Inspect P5a's merge state on `main` at PR-open time. Pick Branch A (P5a not merged yet) or Branch B (P5a merged — closing edit) for the `infrastructure/reference/vendor-inventory.md` edits per the spec above. Document the chosen branch in the PR body.
- [ ] **(Bookkeeping)** `infrastructure/reference/vendor-inventory.md` updated per the chosen branch. If Branch A: GoDaddy row annotation updated, Cloudflare row's active-registrar list extended, lock-in assessment row's registrar coverage updated. If Branch B (closing): GoDaddy row removed, Cloudflare row finalized, lock-in assessment finalized.
- [ ] **(Bookkeeping)** Dispatch plan Wave 3 has a status line dated for the `honeyhub.app` cutover; if Branch B, also flags GoDaddy account closure as available at user discretion.
- [ ] **(Bookkeeping)** `CHANGELOG.md` `## [Unreleased]` section has the changed-entry for `honeyhub.app`; if Branch B, also has the rollout-complete entry.
- [ ] PR description references this packet (invariant 32).

## Human Prerequisites

- [ ] **Enumerate every external service requiring DNS records on `honeyhub.app`.** This domain was not pre-flagged with third-party services in the scope-time inventory. Sweep the studio's third-party-service portfolio: list each service that has a TXT verification, MX, CNAME, or other DNS record on `honeyhub.app` (Resend, Google Workspace / Microsoft 365 mailboxes, Stripe, Vercel, any analytics / monitoring services, any incidental services). The BIND export is the ground-truth source — the enumeration cross-references the export against the studio's known third-party-service portfolio. Capture the list in the packet's PR body before initiating the transfer. The post-cutover smoke checks each service portal-side after cutover; the list lets the smoke be exhaustive rather than discovery-based.
- [ ] **GoDaddy 2FA second factor verified working.** Sign in to `account.godaddy.com` and complete the 2FA challenge. If recovery codes were saved at enrollment, locate and confirm accessibility (1Password / equivalent). If lost, regenerate before any transfer step.
- [ ] **DNSSEC OFF at GoDaddy for `honeyhub.app`.** Verify in GoDaddy DNS settings → DNSSEC. If ON, disable and wait 24-48 hours for propagation before initiating the transfer.
- [ ] **GoDaddy account access for the unlock + auth-code retrieval.** The agent does not have GoDaddy credentials. The user signs in to `account.godaddy.com`, executes the BIND export, disables Domain Privacy, unlocks the domain, and retrieves the transfer authorization code. Cross-link: [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md) — GoDaddy-side preparation section.
- [ ] **Auth code handoff to the agent (only if the agent is performing the Cloudflare-side initiate click).** The user provides the transfer authorization code through a secure channel (1Password share, ephemeral message). The agent uses it once and does not store or log it.
- [ ] **Cloudflare Registrar payment method on file.** Same as P4 / P5a. The transfer bills the at-cost wholesale registry fee for `.app` (higher than `.com` — record the per-year fee in the PR body).
- [ ] **Multi-day wait window planned.** Each transfer takes 5-7 days, plus 24-48 hours of post-cutover smoke window. Schedule at the start of a low-change window. P5a and P5b can run in parallel — the transfers are independent.
- [ ] **Pre-cutover behavior snapshot.** If `honeyhub.app` serves a hosted surface (parking page, redirect, marketing, custom), snapshot the rendered behavior pre-cutover (over HTTPS) so the post-cutover comparison is concrete.

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. The transfer authorization code for `honeyhub.app` is single-use, handled out-of-band, and never appears in the packet body, PR body, commit messages, or chat.

> **Invariant 12:** Every shipped behavior change is reflected in `CHANGELOG.md` (and `README.md` when public surface changes). The vendor-inventory edit and the cutover both ship doc-state changes; CHANGELOG entries mandatory.

> **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. The conditional-branch logic in this packet (Branch A vs. Branch B based on P5a's merge state at PR-open time) is intentional and pre-filing-baked into the packet text — not a post-filing amendment. The branch choice is execution-time data, not packet-text data.

> **Invariant 25:** Dispatch plans are initiative narratives, not live state. The org Project board is the source of truth for in-flight work. Dispatch plans are updated at wave boundaries as historical records. The Wave 3 status-line edit in this packet is the supported per-ADR-0008-D7 dispatch-plan edit.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.

## Referenced ADR Decisions

**ADR-0029 §Implementation step 2:** "Any other apex domain currently held at GoDaddy — one packet per domain, in increasing order of 'what depends on it.'" This packet is one of two such packets (the other is P5a for `tatteddev.com`).

**ADR-0029 D1:** "All Grid-owned domains move to Cloudflare Registrar... Existing domains at GoDaddy transfer one at a time, in the order in §Implementation." `honeyhub.app` is one of the remaining-at-GoDaddy domains.

**ADR-0029 D3 (default proxy posture):** Per-record proxied vs. DNS-only choices follow these defaults; per-record exceptions documented in the PR body.

**ADR-0029 D6 (lean record comments):** `purpose=...` only.

**ADR-0029 §Negative Consequences:** Registrar Lock On enforced per domain.

**ADR-0003 (HoneyHub Phase 1, Proposed):** Names `honeyhub.app` as the future home of the HoneyHub UI. This packet does not provision or wire HoneyHub — only the registrar + DNS authority transfer. The "apex at Cloudflare" state this packet produces is the prerequisite the HoneyHub stand-up rollout consumes.

## Dependencies

- `packet:04` — `honeydrunkstudios.com` cutover. P4 validates the transfer flow on the lowest-risk domain. P5b should not execute until P4 is verified-clean. This is the Wave 2 → Wave 3 boundary.

P5a and P5b are siblings within Wave 3 — neither is wired as the other's dependency. The conditional closing-edit branch in `infrastructure/reference/vendor-inventory.md` handles the merge-order coordination at execution time.

## Labels
`feature`, `tier-2`, `infrastructure`, `adr-0029`, `human-only`

## Agent Handoff

**Objective:** Verify the GoDaddy → Cloudflare migration for `honeyhub.app` after the user-driven operational sequence completes; record the verification, perform the per-domain (Branch A) or closing (Branch B) vendor-inventory edits, and update the dispatch plan + CHANGELOG.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Migrate one of two remaining GoDaddy-held apex domains to Cloudflare. Drains GoDaddy of one more Grid-owned domain. `honeyhub.app` is the future HoneyHub UI surface (ADR-0003) but HoneyHub-side wiring is out of scope here.
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
- **Invariant 24:** The Branch A / Branch B choice is execution-time inspection of P5a's merge state on `main`. The packet text describes both branches; the PR body documents which was chosen.
- **Invariant 25:** Dispatch plan edit is the ADR-0008 D7 exception, recording the cutover date.
- **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.
- **Default proxy posture per ADR-0029 D3.** Per-record exceptions documented in the PR body with a one-line justification each.
- **Lean record comments per ADR-0029 D6.** `purpose=...` only.
- **`.app` HSTS-preload behavior.** All HTTPS-only verification. Do not assume http:// is reachable on this domain.
- **HoneyHub-side wiring out of scope.** This packet stops at "apex at Cloudflare." Subdomain records, Container App custom-domain binding, and any HoneyHub-side configuration belong to the HoneyHub stand-up rollout.

**Key Files:**
- `infrastructure/reference/vendor-inventory.md`
- `generated/issue-packets/active/adr-0029-cloudflare-dns-rollout/dispatch-plan.md`
- `CHANGELOG.md`

**Reference Walkthrough:**
- [`infrastructure/cloudflare-domain-transfer.md`](../../../../infrastructure/cloudflare-domain-transfer.md) (P3)

**Contracts:** None changed.
